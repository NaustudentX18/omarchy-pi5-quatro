#!/usr/bin/env bash
# ==============================================================================
# install_resize.sh - Install First-Boot Auto-Resize Service
# Omarchy Quatro Pi 5 Agent Swarm
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_TARGET="/usr/local/bin/rpi-resizerootfs.sh"
SERVICE_TARGET="/etc/systemd/system/rpi-resizerootfs.service"

echo "=================================================================="
echo " Omarchy Quatro Pi 5: Installing Auto-Resize Rootfs Service"
echo "=================================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This installation script must be run as root (sudo $0)" >&2
    exit 1
fi

echo "[1/3] Installing resize script to $BIN_TARGET..."
install -m 0755 "${SCRIPT_DIR}/rpi-resizerootfs.sh" "$BIN_TARGET"

echo "[2/3] Installing systemd unit to $SERVICE_TARGET..."
install -m 0644 "${SCRIPT_DIR}/rpi-resizerootfs.service" "$SERVICE_TARGET"

echo "[3/3] Enabling rpi-resizerootfs.service..."
# Ensure completion flag is absent so it triggers on first boot
rm -f /etc/rpi-resizerootfs.done

if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    systemctl daemon-reload
    systemctl enable rpi-resizerootfs.service
    echo "      rpi-resizerootfs.service enabled."
else
    echo "      Enabling via systemd multi-user.target symlink (offline/chroot mode)..."
    mkdir -p /etc/systemd/system/multi-user.target.wants
    ln -sf "$SERVICE_TARGET" /etc/systemd/system/multi-user.target.wants/rpi-resizerootfs.service
fi

echo "=================================================================="
echo " Auto-resize rootfs service successfully armed for first boot!"
echo "=================================================================="
