#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quatro Pi 5 - Master Desktop Provisioning Orchestrator
# Target: Raspberry Pi 5 (Arch Linux ARM)
# ==============================================================================
# NOTE: This script is NOT called by build_pi5_image.sh. The build orchestrates
# provisioning inline (chroot + clone_omarchy_repo.sh + services). This file is
# kept for the standalone path: chroot into an existing ALARM rootfs and run
# this script to layer the Omarchy Quatro desktop on top.
#
# For the build path, see build_pi5_image.sh step 7.
# ----------------------------------------------------------------------
# Automates the entire desktop provisioning flow:
# 1. Installs desktop & media packages from packages.list via pacman
# 2. Configures 'omarchy' user, groups, and sudoers via setup_omarchy_user.sh
# 3. Clones Omarchy Quattro, links binaries, seeds configs, and tunes VC7 GPU via clone_omarchy_repo.sh
# 4. Enables critical system services (sddm, NetworkManager, bluetooth)
#
# Usage:
#   sudo ./install_desktop.sh [TARGET_ROOT] [--skip-packages]
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_ROOT="${1:-/}"
SKIP_PACKAGES=0

for arg in "$@"; do
    if [[ "${arg}" == "--skip-packages" ]]; then
        SKIP_PACKAGES=1
    fi
done

echo "======================================================================"
echo " Omarchy Quatro Pi 5 - Desktop Provisioning"
echo " Target Root: ${TARGET_ROOT}"
echo " Script Dir:  ${SCRIPT_DIR}"
echo "======================================================================"

run_in_target() {
    if [[ "${TARGET_ROOT}" == "/" ]]; then
        "$@"
    else
        chroot "${TARGET_ROOT}" "$@"
    fi
}

# ------------------------------------------------------------------------------
# 1. Package Installation
# ------------------------------------------------------------------------------
if [[ "${SKIP_PACKAGES}" -eq 0 ]]; then
    echo "[Step 1/4] Installing Arch Linux ARM packages from packages.list..."
    PACKAGES_FILE="${SCRIPT_DIR}/packages.list"
    if [[ ! -f "${PACKAGES_FILE}" ]]; then
        echo "[-] Error: packages.list not found at ${PACKAGES_FILE}" >&2
        exit 1
    fi

    # Filter out comments and blank lines
    mapfile -t PKG_LIST < <(grep -v '^#' "${PACKAGES_FILE}" | grep -v '^[[:space:]]*$')

    echo "    Installing ${#PKG_LIST[@]} packages via pacman..."
    if [[ "${TARGET_ROOT}" == "/" ]]; then
        pacman -Syu --needed --noconfirm "${PKG_LIST[@]}"
    else
        pacman --sysroot "${TARGET_ROOT}" -Sy --needed --noconfirm "${PKG_LIST[@]}" || \
            run_in_target pacman -Sy --needed --noconfirm "${PKG_LIST[@]}"
    fi
else
    echo "[Step 1/4] Skipping package installation as requested (--skip-packages)."
fi

# ------------------------------------------------------------------------------
# 2. User & Sudoers Setup
# ------------------------------------------------------------------------------
echo "[Step 2/4] Setting up 'omarchy' user and permissions..."
"${SCRIPT_DIR}/setup_omarchy_user.sh" "${TARGET_ROOT}"

# ------------------------------------------------------------------------------
# 3. Omarchy Quattro Repo Clone & Desktop Configuration
# ------------------------------------------------------------------------------
echo "[Step 3/4] Cloning Omarchy Quattro repo, linking binaries, and tuning GPU..."
"${SCRIPT_DIR}/clone_omarchy_repo.sh" "${TARGET_ROOT}"

# ------------------------------------------------------------------------------
# 4. Enable System Services
# ------------------------------------------------------------------------------
echo "[Step 4/4] Enabling system services (SDDM, NetworkManager, Bluetooth)..."
SERVICES=(
    sddm.service
    NetworkManager.service
    bluetooth.service
)

for svc in "${SERVICES[@]}"; do
    echo "    Enabling ${svc}..."
    run_in_target systemctl enable "${svc}" 2>/dev/null || true
done

echo "======================================================================"
echo "[✓] Omarchy Quatro Pi 5 desktop provisioning finished successfully!"
echo "    Reboot to start the Omarchy Quatro sway desktop environment."
echo "======================================================================"
