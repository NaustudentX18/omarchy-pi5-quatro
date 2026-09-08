#!/usr/bin/env python3
"""
argononed.py - Argon ONE V3 / NEO 5 Fan and Power Button Daemon
Omarchy Quatro Pi 5 Agent Swarm

Features:
- Communicates with Argon MCU over I2C at address 0x1a (using smbus2 / smbus).
- Controls fan speed via PWM according to Omarchy thermal curve:
    - Below 50°C:   0% (Fan OFF)
    - 50°C - 59°C: 25%
    - 60°C - 69°C: 55%
    - >= 70°C:    100%
- Monitors Argon power button pulse signals on BCM GPIO 4 (Argon ONE V3 / NEO 5):
    - Pulse 10-50 ms (double tap):       Graceful Reboot
    - Pulse 2500-3500 ms (3-second hold): Graceful Shutdown / Poweroff
- Sends power-off signal to Argon MCU (register 0x86 / 0xFF) on system shutdown.
- Resilient to missing hardware (dry-run/test mode supported, error throttling).
"""

import argparse
import glob
import logging
import os
import signal
import subprocess
import sys
import threading
import time

# -----------------------------------------------------------------------------
# Configuration Constants
# -----------------------------------------------------------------------------
ARGON_I2C_ADDR = 0x1A       # Default I2C address for Argon MCU
REG_FAN_DUTY_CYCLE = 0x80   # Argon V3 / NEO 5 fan speed register (0-100%)
REG_POWER_CTRL = 0x86       # Argon V3 / NEO 5 power cut signal register
VAL_POWER_CUT = 0x01        # Signal Argon MCU to cut power after OS halt
LEGACY_POWER_CUT = 0xFF     # Legacy Argon V1/V2 raw byte power cut signal

THERMAL_ZONE_PATH = "/sys/class/thermal/thermal_zone0/temp"
FALLBACK_THERMAL_PATH = "/sys/devices/virtual/thermal/thermal_zone0/temp"
GPIO_POWER_BUTTON_PIN = 4   # BCM 4 (Header Pin 7)

POLL_INTERVAL_SEC = 3.0     # Temperature sampling interval
HYSTERESIS_TEMP = 1.0       # Temperature hysteresis to prevent fan speed jitter

# Power-button pulse windows (ms). Calibrated against Argon ONE V3 / NEO 5
# documentation: short double-tap pulses reboot, ~3s sustained hold powers off.
PULSE_REBOOT_MIN_MS = 10.0
PULSE_REBOOT_MAX_MS = 50.0
PULSE_SHUTDOWN_MIN_MS = 2500.0
PULSE_SHUTDOWN_MAX_MS = 3500.0
# Once a shutdown command has been dispatched, ignore further button events
# for this many seconds so mechanical bounce / spurious edges cannot re-trigger
# reboot/shutdown while systemd is halting the system.
SHUTDOWN_HYSTERESIS_SEC = 5.0

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [argononed] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("argononed")


# -----------------------------------------------------------------------------
# Hardware Abstraction: I2C Communication
# -----------------------------------------------------------------------------
def get_smbus():
    """Import and return smbus2 or smbus module if available."""
    try:
        import smbus2 as smbus
        return smbus
    except ImportError:
        try:
            import smbus
            return smbus
        except ImportError:
            logger.warning("Neither smbus2 nor smbus is installed.")
            return None


class ArgonI2CController:
    """Manages I2C communication with Argon ONE V3 / NEO 5 MCU."""

    def __init__(self, bus_num=1, dry_run=False):
        self.bus_num = bus_num
        self.dry_run = dry_run
        self.bus = None
        self.use_v3_registers = True
        self._init_bus()

    def _init_bus(self):
        if self.dry_run:
            logger.info("Operating in DRY-RUN mode. I2C commands will be simulated.")
            return

        smbus_mod = get_smbus()
        if smbus_mod is None:
            logger.error("No SMBus library available. Running in degraded mode.")
            return

        for bus_id in [self.bus_num, 0]:
            try:
                self.bus = smbus_mod.SMBus(bus_id)
                self.bus_num = bus_id
                logger.info("Successfully opened I2C bus /dev/i2c-%d", bus_id)
                return
            except Exception as err:
                logger.debug("Could not open /dev/i2c-%d: %s", bus_id, err)

        logger.warning("Failed to open I2C bus. Hardware may not be connected.")

    def set_fan_speed(self, speed_pct: int) -> bool:
        """
        Set fan speed percentage (0-100).
        Attempts Argon V3 / NEO 5 register 0x80 first, falls back to direct byte.
        """
        speed = max(0, min(100, int(speed_pct)))

        if self.dry_run:
            logger.debug("[DRY-RUN] Set Argon fan speed: %d%%", speed)
            return True

        if self.bus is None:
            self._init_bus()
            if self.bus is None:
                return False

        try:
            if self.use_v3_registers:
                try:
                    self.bus.write_byte_data(ARGON_I2C_ADDR, REG_FAN_DUTY_CYCLE, speed)
                    return True
                except (OSError, IOError) as err:
                    logger.debug("V3 register write failed, attempting legacy write: %s", err)
                    self.use_v3_registers = False

            # Legacy fallback
            self.bus.write_byte(ARGON_I2C_ADDR, speed)
            return True
        except (OSError, IOError) as err:
            logger.debug("I2C write to Argon MCU at 0x%02x failed: %s", ARGON_I2C_ADDR, err)
            return False

    def signal_poweroff(self):
        """Send power-cut command to Argon MCU so it cuts power after system halt."""
        if self.dry_run:
            logger.info("[DRY-RUN] Sent power-off signal to Argon MCU")
            return

        if self.bus is None:
            return

        try:
            if self.use_v3_registers:
                try:
                    self.bus.write_byte_data(ARGON_I2C_ADDR, REG_POWER_CTRL, VAL_POWER_CUT)
                    logger.info("Sent V3 power-off command (0x%02x -> 0x%02x)", REG_POWER_CTRL, VAL_POWER_CUT)
                    return
                except Exception:
                    pass

            self.bus.write_byte(ARGON_I2C_ADDR, LEGACY_POWER_CUT)
            logger.info("Sent legacy power-off command (0x%02x)", LEGACY_POWER_CUT)
        except Exception as err:
            logger.debug("Failed to send power-off signal to MCU: %s", err)

    def close(self):
        if self.bus is not None:
            try:
                self.bus.close()
            except Exception:
                pass
            self.bus = None


# -----------------------------------------------------------------------------
# Thermal Reading & Fan Curve Calculation
# -----------------------------------------------------------------------------
def read_cpu_temp() -> float:
    """
    Read CPU temperature in degrees Celsius from sysfs thermal zone.
    Returns None if reading fails.
    """
    for path in [THERMAL_ZONE_PATH, FALLBACK_THERMAL_PATH]:
        if os.path.exists(path):
            try:
                with open(path, "r") as fp:
                    content = fp.read().strip()
                    temp_mc = int(content)
                    return temp_mc / 1000.0
            except Exception as err:
                logger.debug("Error reading %s: %s", path, err)

    # Fallback to vcgencmd measure_temp if available
    try:
        out = subprocess.check_output(["vcgencmd", "measure_temp"], universal_newlines=True, stderr=subprocess.DEVNULL)
        # Output format: temp=48.2'C
        val_str = out.strip().replace("temp=", "").replace("'C", "")
        return float(val_str)
    except Exception:
        pass

    return None


def calculate_fan_speed(temp_c: float) -> int:
    """
    Calculate fan speed percentage according to Omarchy thermal curve:
      - below 50°C:   0%
      - 50°C - 59°C: 25%
      - 60°C - 69°C: 55%
      - >= 70°C:    100%
    """
    if temp_c is None:
        # Failsafe: if temp cannot be determined, keep fan at 55%
        return 55

    if temp_c < 50.0:
        return 0
    elif temp_c < 60.0:
        return 25
    elif temp_c < 70.0:
        return 55
    else:
        return 100


# -----------------------------------------------------------------------------
# Power Button Monitoring (BCM GPIO 4)
# -----------------------------------------------------------------------------
class ArgonPowerButtonMonitor(threading.Thread):
    """
    Monitors pulse events from Argon MCU on BCM GPIO 4.

    Argon ONE V3 / NEO 5 power-button pulse timing protocol
    (per Argon40 documentation):
      - 10 ms - 50 ms (double-tap):            -> Graceful Reboot
      - 2500 ms - 3500 ms (3-second hold):    -> Graceful Shutdown

    After a shutdown command fires, the monitor enters a 5-second hysteresis
    window during which further button events are ignored to prevent bounce
    or spurious edges from re-triggering actions while the system is halting.
    """

    def __init__(self, dry_run=False):
        super().__init__(daemon=True, name="ArgonPowerButtonThread")
        self.dry_run = dry_run
        self.running = True
        self.chip = None
        self.line_req = None
        # Monotonic deadline; while "now" is before this, _handle_pulse() drops
        # any incoming edge. Set after a shutdown command is dispatched.
        self.shutdown_lock_until = None

    def _find_rp1_gpiochip(self):
        """Find the Raspberry Pi 5 RP1 GPIO chip or fallback."""
        try:
            import gpiod
            # First search by label pinctrl-rp1 (Pi 5 40-pin header)
            for path in sorted(glob.glob("/dev/gpiochip*")):
                try:
                    chip = gpiod.Chip(path)
                    info = chip.get_info()
                    if "rp1" in info.label.lower() or "pinctrl" in info.label.lower():
                        chip.close()
                        return path
                    chip.close()
                except Exception:
                    continue
        except Exception:
            pass

        # Fallback paths
        for candidate in ["/dev/gpiochip4", "/dev/gpiochip0"]:
            if os.path.exists(candidate):
                return candidate
        return None

    def run(self):
        logger.info("Initializing Argon power button monitor on BCM GPIO %d...", GPIO_POWER_BUTTON_PIN)
        chippath = self._find_rp1_gpiochip()
        if not chippath:
            logger.warning("No suitable GPIO chip found. Power button monitoring disabled.")
            return

        logger.info("Using GPIO chip %s for power button monitoring", chippath)

        try:
            import gpiod
            # Test for libgpiod v2 API
            if hasattr(gpiod, "request_lines"):
                self._run_gpiod_v2(gpiod, chippath)
            else:
                self._run_gpiod_v1(gpiod, chippath)
        except ImportError:
            logger.warning("python3-libgpiod is not installed. Power button monitoring disabled.")
        except Exception as err:
            logger.error("Power button monitor encountered error: %s", err)

    def _run_gpiod_v2(self, gpiod, chippath):
        """libgpiod v2 event loop."""
        config = {
            GPIO_POWER_BUTTON_PIN: gpiod.LineSettings(
                direction=gpiod.line.Direction.INPUT,
                edge_detection=gpiod.line.Edge.BOTH,
                bias=gpiod.line.Bias.PULL_UP,
            )
        }

        try:
            with gpiod.request_lines(chippath, consumer="argononed", config=config) as request:
                self.line_req = request
                rising_time = None

                while self.running:
                    # Wait for edge events with timeout to allow thread exit
                    if not request.wait_edge_events(timeout=2.0):
                        continue

                    for event in request.read_edge_events():
                        now = time.monotonic()
                        if event.event_type == event.Type.RISING_EDGE:
                            rising_time = now
                        elif event.event_type == event.Type.FALLING_EDGE and rising_time is not None:
                            pulse_ms = (now - rising_time) * 1000.0
                            rising_time = None
                            self._handle_pulse(pulse_ms)
        except Exception as err:
            logger.warning("gpiod request_lines failed: %s. Button monitoring inactive.", err)

    def _run_gpiod_v1(self, gpiod, chippath):
        """libgpiod v1 legacy event loop."""
        try:
            chip = gpiod.Chip(chippath)
            self.chip = chip
            line = chip.get_line(GPIO_POWER_BUTTON_PIN)
            line.request(
                consumer="argononed",
                type=gpiod.LINE_REQ_EV_BOTH_EDGES,
                flags=gpiod.LINE_REQ_FLAG_BIAS_PULL_UP,
            )

            rising_time = None
            while self.running:
                if line.event_wait(2):
                    event = line.event_read()
                    now = time.monotonic()
                    if event.type == gpiod.LineEvent.RISING_EDGE:
                        rising_time = now
                    elif event.type == gpiod.LineEvent.FALLING_EDGE and rising_time is not None:
                        pulse_ms = (now - rising_time) * 1000.0
                        rising_time = None
                        self._handle_pulse(pulse_ms)

            line.release()
            chip.close()
        except Exception as err:
            logger.warning("gpiod v1 line request failed: %s. Button monitoring inactive.", err)

    def _handle_pulse(self, pulse_ms: float):
        """Interpret an Argon power-button pulse and dispatch the matching action.

        Pulse windows (per Argon ONE V3 / NEO 5 protocol):
          - PULSE_REBOOT_MIN_MS .. PULSE_REBOOT_MAX_MS     -> systemctl reboot
          - PULSE_SHUTDOWN_MIN_MS .. PULSE_SHUTDOWN_MAX_MS -> systemctl poweroff
        Anything outside those bands is logged at debug and dropped.
        """
        now = time.monotonic()

        # Hysteresis: drop any pulse while a recent shutdown is still latching.
        # Without this, mechanical bounce / spurious edges after a 3s hold can
        # immediately re-trigger reboot before systemd finishes halting.
        if self.shutdown_lock_until is not None and now < self.shutdown_lock_until:
            logger.debug(
                "Pulse %.1f ms ignored during shutdown lockout (%.1fs remaining).",
                pulse_ms, self.shutdown_lock_until - now,
            )
            return

        logger.info("Argon power button pulse detected: %.1f ms", pulse_ms)

        # Pulse 10 ms - 50 ms: Reboot requested (double-tap).
        if PULSE_REBOOT_MIN_MS <= pulse_ms <= PULSE_REBOOT_MAX_MS:
            logger.warning(
                "Action: REBOOT requested by Argon power button (double-tap, %.1f ms)",
                pulse_ms,
            )
            if self.dry_run:
                logger.info("[DRY-RUN] System reboot simulated.")
            else:
                subprocess.run(["systemctl", "reboot"], check=False)

        # Pulse 2500 ms - 3500 ms: Shutdown requested (3-second hold).
        elif PULSE_SHUTDOWN_MIN_MS < pulse_ms <= PULSE_SHUTDOWN_MAX_MS:
            logger.warning(
                "Action: SHUTDOWN requested by Argon power button (3s hold, %.1f ms)",
                pulse_ms,
            )
            if self.dry_run:
                logger.info("[DRY-RUN] System shutdown simulated.")
            else:
                # Lock out further events while systemd powers off so that
                # button bounce cannot trigger an immediate reboot.
                self.shutdown_lock_until = now + SHUTDOWN_HYSTERESIS_SEC
                subprocess.run(["systemctl", "poweroff"], check=False)

        else:
            # Pulse outside either recognised band; log so mis-wiring or
            # contact bounce is visible in debug logs without spamming INFO.
            logger.debug(
                "Pulse %.1f ms outside recognised %.0f-%.0f / %.0f-%.0f ms windows; ignoring.",
                pulse_ms,
                PULSE_REBOOT_MIN_MS, PULSE_REBOOT_MAX_MS,
                PULSE_SHUTDOWN_MIN_MS, PULSE_SHUTDOWN_MAX_MS,
            )

    def stop(self):
        self.running = False


# -----------------------------------------------------------------------------
# Main Daemon Logic
# -----------------------------------------------------------------------------
class ArgonDaemon:
    """Argon Fan & Power Daemon controller."""

    def __init__(self, dry_run=False, bus_num=1):
        self.dry_run = dry_run
        self.i2c = ArgonI2CController(bus_num=bus_num, dry_run=dry_run)
        self.btn_monitor = ArgonPowerButtonMonitor(dry_run=dry_run)
        self.running = True
        self.current_speed = -1
        self.last_temp = None

        # Setup signal handlers
        signal.signal(signal.SIGINT, self._handle_signal)
        signal.signal(signal.SIGTERM, self._handle_signal)

    def _handle_signal(self, signum, frame):
        sig_name = "SIGTERM" if signum == signal.SIGTERM else "SIGINT"
        logger.info("Received %s. Shutting down daemon...", sig_name)
        self.running = False

    def start(self):
        logger.info("Starting Argon ONE V3 / NEO 5 Fan & Power Daemon...")
        self.btn_monitor.start()

        # Initial speed check
        temp = read_cpu_temp()
        target_speed = calculate_fan_speed(temp)
        self.current_speed = target_speed
        self.last_temp = temp
        self.i2c.set_fan_speed(target_speed)
        logger.info("Initial CPU Temp: %.1f°C | Fan Speed: %d%%", temp if temp else 0.0, target_speed)

        # Main control loop
        while self.running:
            try:
                time.sleep(POLL_INTERVAL_SEC)
                temp = read_cpu_temp()
                if temp is None:
                    continue

                target_speed = calculate_fan_speed(temp)

                # Apply hysteresis when dropping fan speed to prevent oscillation
                if target_speed < self.current_speed:
                    # Only decrease if temperature has dropped clearly below boundary
                    if self.last_temp is not None and (self.last_temp - temp) < HYSTERESIS_TEMP:
                        target_speed = self.current_speed

                if target_speed != self.current_speed:
                    logger.info("CPU Temp: %.1f°C -> Setting Fan Speed: %d%%", temp, target_speed)
                    if self.i2c.set_fan_speed(target_speed):
                        self.current_speed = target_speed

                self.last_temp = temp
            except Exception as err:
                logger.error("Unexpected error in daemon loop: %s", err)
                time.sleep(5.0)

        # Cleanup on exit
        self.cleanup()

    def cleanup(self):
        logger.info("Cleaning up and stopping Argon daemon...")
        self.btn_monitor.stop()

        # Instruct Argon MCU to signal power off to case power supply
        self.i2c.signal_poweroff()

        # Turn off or reset fan
        self.i2c.set_fan_speed(0)
        self.i2c.close()
        logger.info("Argon daemon stopped cleanly.")


# -----------------------------------------------------------------------------
# Entrypoint & CLI Options
# -----------------------------------------------------------------------------
def parse_args():
    parser = argparse.ArgumentParser(
        description="Argon ONE V3 / NEO 5 Fan and Power Button Daemon"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Run without writing to I2C or issuing shutdown/reboot commands",
    )
    parser.add_argument(
        "--test",
        action="store_true",
        help="Perform a single CPU temperature read, display fan curve mapping, and exit",
    )
    parser.add_argument(
        "--bus",
        type=int,
        default=1,
        help="I2C bus number (default: 1)",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable debug logging output",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    if args.verbose:
        logger.setLevel(logging.DEBUG)

    if args.test:
        temp = read_cpu_temp()
        speed = calculate_fan_speed(temp)
        print("--- Argon ONE V3 / NEO 5 Thermal Test ---")
        if temp is not None:
            print(f"Current CPU Temperature: {temp:.2f}°C")
            print(f"Calculated Fan Duty Cycle: {speed}%")
        else:
            print("Failed to read CPU temperature from sysfs / vcgencmd.")
            print(f"Default Failsafe Fan Duty Cycle: {speed}%")
        print("Thermal Curve Reference:")
        print("  < 50°C   ->   0%")
        print("  50-59°C  ->  25%")
        print("  60-69°C  ->  55%")
        print("  >= 70°C  -> 100%")
        sys.exit(0)

    daemon = ArgonDaemon(dry_run=args.dry_run, bus_num=args.bus)
    daemon.start()


if __name__ == "__main__":
    main()
