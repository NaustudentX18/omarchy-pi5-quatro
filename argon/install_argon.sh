#!/usr/bin/env bash
# ==============================================================================
# install_argon.sh - Distro-aware installation script for Argon ONE V3 / NEO 5
#                    daemon. Supports apt, pacman, dnf, and pip-fallback.
# Omarchy Quattro Pi 5 Agent Swarm
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_TARGET="/usr/local/bin/argononed.py"
SERVICE_TARGET="/etc/systemd/system/argononed.service"

echo "=================================================================="
echo " Omarchy Quattro Pi 5: Installing Argon ONE V3 / NEO 5 Daemon"
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

# Step 2: Install / verify Python dependencies (distro-aware)
# Detect package manager so the script works on Debian/Ubuntu (apt), Arch /
# ALARM (pacman), Fedora/RHEL (dnf), and any distro lacking native packages
# via a pip last-resort fallback.
echo "[2/5] Verifying Python prerequisites..."

if command -v apt-get >/dev/null 2>&1; then
    PM="apt"
elif command -v pacman >/dev/null 2>&1; then
    PM="pacman"
elif command -v dnf >/dev/null 2>&1; then
    PM="dnf"
else
    PM="pip"
fi
echo "      Detected package manager: ${PM}"

# Translate a logical Python package name into the distro-native one.
resolve_pkg() {
    # $1 = logical name (smbus2 | libgpiod)
    case "$PM:$1" in
        apt:smbus2)    echo "python3-smbus2" ;;
        apt:libgpiod)  echo "python3-libgpiod" ;;
        pacman:smbus2) echo "python-smbus2" ;;
        pacman:libgpiod) echo "python-libgpiod" ;;
        dnf:smbus2)    echo "python3-smbus2" ;;
        dnf:libgpiod)  echo "python3-libgpiod" ;;
        pip:smbus2)    echo "smbus2" ;;
        pip:libgpiod)  echo "" ;;  # pip cannot ship libgpiod's C library
        *)             echo "" ;;  # unknown combo: treat as unresolvable
    esac
}

install_pkgs() {
    case "$PM" in
        apt)
            apt-get update -qq && apt-get install -y -qq "$@"
            ;;
        pacman)
            pacman -S --noconfirm --needed "$@"
            ;;
        dnf)
            dnf install -y "$@"
            ;;
        pip)
            # Last-resort fallback for distros without native packages.
            # --break-system-packages is required on PEP 668 systems
            # (Debian 12+, Ubuntu 23.04+, Arch/ALARM with externally-managed
            # python). On ALARM specifically the python-smbus2 package is
            # usually preferred; the pip fallback exists for sandboxes.
            pip install --break-system-packages "$@"
            ;;
        *)
            # Unreachable via the detection block above (PM is one of the
            # four), but kept as a guard so unknown managers fall back to pip.
            pip install --break-system-packages "$@"
            ;;
    esac
}

MISSING_PKGS=()

# smbus2 (I2C master library)
if ! python3 -c "import smbus2" >/dev/null 2>&1; then
    PKG="$(resolve_pkg smbus2)"
    [ -n "$PKG" ] && MISSING_PKGS+=("$PKG")
fi

# gpiod (libgpiod Python bindings, required for power-button monitoring)
if ! python3 -c "import gpiod" >/dev/null 2>&1; then
    PKG="$(resolve_pkg libgpiod)"
    if [ -n "$PKG" ]; then
        MISSING_PKGS+=("$PKG")
    elif [ "$PM" = "pip" ]; then
        echo "      [WARN] gpiod Python bindings require libgpiod C library;"
        echo "             install python3-libgpiod / python-libgpiod manually."
    fi
fi

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo "      Installing required packages via ${PM}: ${MISSING_PKGS[*]}..."
    install_pkgs "${MISSING_PKGS[@]}" || {
        echo "      [WARN] ${PM} install returned non-zero. Continuing if packages exist."
    }
else
    echo "      All required Python libraries (smbus2, gpiod) are present."
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
echo " Package manager: ${PM}"
echo "=================================================================="
