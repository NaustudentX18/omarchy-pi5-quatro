# Argon ONE V3 / NEO 5 Fan & Power Management Subsystem
**Omarchy Quatro Pi 5 Agent Swarm**

## Overview
This subsystem provides comprehensive hardware integration for the **Argon ONE V3** and **Argon NEO 5** cases on Raspberry Pi 5 (BCM2712).

## Hardware Interface
- **I2C Slave Address**: `0x1a` (Bus 1 default: `/dev/i2c-1`)
- **Duty Cycle Register (V3 / NEO 5)**: `0x80` (Value range: `0` to `100`)
- **Power Cut Control Register**: `0x86` (Value: `0x01` signals MCU to cut power after OS halt)
- **Power Button GPIO**: BCM Pin 4 (`pinctrl-rp1` line 4, header Pin 7)

## Thermal Curve
The daemon continuously samples `/sys/class/thermal/thermal_zone0/temp` and adjusts fan PWM:
- **Below 50°C**: `0%` (Fan completely silent / OFF)
- **50°C - 59°C**: `25%` (Whisper quiet)
- **60°C - 69°C**: `55%` (Moderate cooling)
- **>= 70°C**: `100%` (Maximum airflow)

## Power Button Pulse Protocol
The Argon case MCU interprets button events and pulses BCM GPIO 4:
- **Double Tap (10 ms - 50 ms pulse)**: Triggers graceful system reboot (`systemctl reboot`).
- **Hold for 3s (2500 ms - 3500 ms pulse)**: Triggers graceful system shutdown (`systemctl poweroff`).

After a shutdown command fires, the daemon enters a 5-second hysteresis window
during which subsequent button events are ignored, preventing contact bounce from
re-triggering actions while the system is halting.

## Files
- `argononed.py`: Production-grade Python 3 daemon using `smbus2`/`smbus` and `gpiod`. Includes thermal hysteresis, error throttling, dry-run, and test mode.
- `argononed.service`: Systemd service unit configured for automatic startup on boot.
- `install_argon.sh`: Standalone deployment script for live or chroot installation.

## Manual Testing
```bash
# Test thermal read and fan curve calculation:
python3 /home/pi/projects/omarchy-pi5-quatro/argon/argononed.py --test

# Run daemon in dry-run mode with verbose logging:
python3 /home/pi/projects/omarchy-pi5-quatro/argon/argononed.py --dry-run -v
```
