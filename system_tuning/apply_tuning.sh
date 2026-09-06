#!/usr/bin/env bash
# ==============================================================================
# apply_tuning.sh - Install & Apply 8GB RAM + ZRAM Tuning for Pi 5
# Omarchy Quatro Pi 5 Agent Swarm
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=================================================================="
echo " Omarchy Quatro Pi 5: Applying 8GB RAM & NVMe System Tuning"
echo "=================================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This script must be run as root (sudo $0)" >&2
    exit 1
fi

# Step 1: Install zram-generator configuration
echo "[1/3] Installing zram-generator configuration..."
mkdir -p /etc/systemd
install -m 0644 "${SCRIPT_DIR}/zram-generator.conf" "/etc/systemd/zram-generator.conf"

# Step 2: Install kernel sysctl parameters
echo "[2/3] Installing sysctl tuning (/etc/sysctl.d/99-pi5-sysctl.conf)..."
mkdir -p /etc/sysctl.d
install -m 0644 "${SCRIPT_DIR}/99-pi5-sysctl.conf" "/etc/sysctl.d/99-pi5-sysctl.conf"

# Step 3: Apply sysctl configuration immediately
echo "[3/3] Applying sysctl parameters..."
sysctl -p /etc/sysctl.d/99-pi5-sysctl.conf

# Reload systemd generator if running
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    echo "      Reloading systemd daemon..."
    systemctl daemon-reload
    if systemctl is-enabled systemd-zram-setup@zram0.service >/dev/null 2>&1; then
        systemctl restart systemd-zram-setup@zram0.service || true
    fi
fi

echo "=================================================================="
echo " System tuning successfully applied:"
echo "   - ZRAM: 4GB swap device with zstd compression"
echo "   - vm.swappiness = 100"
echo "   - vm.vfs_cache_pressure = 50"
echo "   - vm.dirty_background_ratio = 5"
echo "   - vm.dirty_ratio = 10"
echo "=================================================================="
