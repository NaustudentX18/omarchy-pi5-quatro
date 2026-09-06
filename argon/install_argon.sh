#!/usr/bin/env bash
# ==============================================================================
# install_argon.sh - Install Argon ONE V3 / NEO 5 Daemon & Service
# Omarchy Quatro Pi 5 Agent Swarm
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_TARGET="/usr/local/bin/argononed.py"
SERVICE_TARGET="/etc/systemd/system/argononed.service"

echo "=================================================================="
echo " Omarchy Quatro Pi 5: Installing Argon ONE V3 / NEO 5 Daemon"
echo "=================================================================="

# Check root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This installation script must be run as root (sudo $0)" >&2
    exit 1
fi

# Step 1: Ensure hardware I2C is enabled in boot configuration
echo "[1/5] Checking Raspberry Pi I2C configuration..."
BOOT_CONFIG=""
if [ -f "/boot/firmware/config.txt" ]; then
    BOOT_CONFIG="/boot/firmware/config.txt"
elif [ -f "/boot/config.txt" ]; then
    BOOT_CONFIG="/boot/config.txt"
fi

if [ -n "$BOOT_CONFIG" ]; then
    if ! grep -q "^dtparam=i2c_arm=on" "$BOOT_CONFIG" && ! grep -q "^dtparam=i2c=on" "$BOOT_CONFIG"; then
        echo "      Enabling dtparam=i2c_arm=on in $BOOT_CONFIG..."
        echo "dtparam=i2c_arm=on" >> "$BOOT_CONFIG"
    else
        echo "      I2C parameter already present in $BOOT_CONFIG."
    fi
else
    echo "      [WARN] No boot config.txt found (custom image build environment)."
fi

# Step 2: Install / verify Python dependencies if apt is available
echo "[2/5] Verifying Python prerequisites..."
if command -v apt-get >/dev/null 2>&1; then
    MISSING_PKGS=()
    if ! python3 -c "import smbus2, smbus" >/dev/null 2>&1; then
        MISSING_PKGS+=(python3-smbus2)
    fi
    if ! python3 -c "import gpiod" >/dev/null 2>&1; then
        MISSING_PKGS+=(python3-libgpiod)
    fi

    if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
        echo "      Installing required packages: ${MISSING_PKGS[*]}..."
        apt-get update -qq && apt-get install -y -qq "${MISSING_PKGS[@]}" || {
            echo "      [WARN] apt-get install returned non-zero. Continuing if packages exist."
        }
    else
        echo "      All required Python libraries (smbus2/smbus, libgpiod) are present."
    fi
fi

# Step 3: Install daemon executable
echo "[3/5] Installing daemon to $BIN_TARGET..."
install -m 0755 "${SCRIPT_DIR}/argononed.py" "$BIN_TARGET"

# Step 4: Install systemd service unit
echo "[4/5] Installing systemd unit to $SERVICE_TARGET..."
install -m 0644 "${SCRIPT_DIR}/argononed.service" "$SERVICE_TARGET"

# Step 5: Reload systemd and enable service
echo "[5/5] Activating argononed.service..."
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    systemctl daemon-reload
    systemctl enable argononed.service
    echo "      argononed.service enabled successfully."
    
    # Try starting or restarting if possible
    if systemctl is-active --quiet argononed.service; then
        systemctl restart argononed.service
        echo "      argononed.service restarted."
    else
        systemctl start argononed.service || echo "      [INFO] Service enabled; will start upon hardware init."
    fi
else
    echo "      [INFO] systemd not running (chroot or offline image). Service enabled via symlink."
    mkdir -p /etc/systemd/system/multi-user.target.wants
    ln -sf "$SERVICE_TARGET" /etc/systemd/system/multi-user.target.wants/argononed.service
fi

echo "=================================================================="
echo " Argon ONE V3 / NEO 5 Daemon successfully installed!"
echo " Thermal curve: <50C:0% | 50-59C:25% | 60-69C:55% | >=70C:100%"
echo " Power button: Double-tap -> Reboot | 3s hold -> Shutdown"
echo "=================================================================="
