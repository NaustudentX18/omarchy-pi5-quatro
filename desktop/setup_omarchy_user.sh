#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quatro Pi 5 - User Provisioning Script
# Target: Raspberry Pi 5 (Arch Linux ARM)
# ==============================================================================
# Provisions the primary user 'omarchy' with sudo privileges, hardware groups,
# and shell configurations for the Omarchy Quatro desktop environment.
#
# Usage:
#   sudo ./setup_omarchy_user.sh [TARGET_ROOT]
# ==============================================================================

set -euo pipefail

TARGET_ROOT="${1:-/}"
USERNAME="omarchy"
PASSWORD="omarchy"
GROUPS="wheel,video,audio,input,storage,seat"
DEFAULT_SHELL="/bin/zsh"
FALLBACK_SHELL="/bin/bash"

# Helper for executing commands directly or inside target root
run_in_target() {
    if [[ "${TARGET_ROOT}" == "/" ]]; then
        "$@"
    else
        chroot "${TARGET_ROOT}" "$@"
    fi
}

echo "=== [Omarchy Quatro] Initializing User Provisioning ==="
echo "Target root: ${TARGET_ROOT}"

# Ensure root privileges if modifying local system
if [[ "${TARGET_ROOT}" == "/" && "${EUID}" -ne 0 ]]; then
    echo "[-] Error: setup_omarchy_user.sh must be run as root or with sudo when targeting /" >&2
    exit 1
fi

# Ensure required target directories exist
mkdir -p "${TARGET_ROOT}/etc/sudoers.d"
mkdir -p "${TARGET_ROOT}/home"

# ------------------------------------------------------------------------------
# 1. Ensure required system and hardware groups exist
# ------------------------------------------------------------------------------
echo "[+] Checking and creating required hardware & system groups..."
IFS=',' read -ra GROUP_ARRAY <<< "${GROUPS}"
for grp in "${GROUP_ARRAY[@]}"; do
    if ! run_in_target getent group "${grp}" >/dev/null 2>&1; then
        echo "    Creating missing group: ${grp}"
        run_in_target groupadd -r "${grp}" || run_in_target groupadd "${grp}" || true
    fi
done

# ------------------------------------------------------------------------------
# 2. Determine default shell
# ------------------------------------------------------------------------------
USER_SHELL="${FALLBACK_SHELL}"
if [[ -x "${TARGET_ROOT}${DEFAULT_SHELL}" ]]; then
    USER_SHELL="${DEFAULT_SHELL}"
elif run_in_target command -v zsh >/dev/null 2>&1; then
    USER_SHELL="$(run_in_target command -v zsh)"
fi
echo "[+] Selected default user shell: ${USER_SHELL}"

# Ensure shell is listed in /etc/shells
if [[ -f "${TARGET_ROOT}/etc/shells" ]]; then
    if ! grep -qxF "${USER_SHELL}" "${TARGET_ROOT}/etc/shells"; then
        echo "${USER_SHELL}" >> "${TARGET_ROOT}/etc/shells"
    fi
fi

# ------------------------------------------------------------------------------
# 3. Create or update user 'omarchy'
# ------------------------------------------------------------------------------
if run_in_target id -u "${USERNAME}" >/dev/null 2>&1; then
    echo "[+] User '${USERNAME}' already exists. Updating groups and shell..."
    run_in_target usermod -aG "${GROUPS}" -s "${USER_SHELL}" "${USERNAME}"
else
    echo "[+] Creating user '${USERNAME}'..."
    run_in_target useradd -m -s "${USER_SHELL}" -G "${GROUPS}" "${USERNAME}"
fi

# ------------------------------------------------------------------------------
# 4. Set user password
# ------------------------------------------------------------------------------
echo "[+] Setting password for '${USERNAME}'..."
echo "${USERNAME}:${PASSWORD}" | run_in_target chpasswd

# ------------------------------------------------------------------------------
# 5. Configure Passwordless Sudoers for Wheel
# ------------------------------------------------------------------------------
echo "[+] Configuring sudoers rule (/etc/sudoers.d/10-omarchy)..."
SUDOERS_FILE="${TARGET_ROOT}/etc/sudoers.d/10-omarchy"

cat <<'EOF' > "${SUDOERS_FILE}"
# ==============================================================================
# Omarchy Quatro Pi 5 - Sudoers configuration
# Allows members of the wheel group and omarchy to execute any command without password
# ==============================================================================
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
omarchy ALL=(ALL:ALL) NOPASSWD: ALL
EOF

chmod 0440 "${SUDOERS_FILE}"

# Validate sudoers syntax if visudo is available
if run_in_target command -v visudo >/dev/null 2>&1; then
    if [[ "${TARGET_ROOT}" == "/" ]]; then
        visudo -cf "${SUDOERS_FILE}" >/dev/null
    else
        run_in_target visudo -cf /etc/sudoers.d/10-omarchy >/dev/null || true
    fi
fi

# ------------------------------------------------------------------------------
# 6. Configure User Home Permissions and Standard Directories
# ------------------------------------------------------------------------------
HOME_DIR="${TARGET_ROOT}/home/${USERNAME}"
echo "[+] Enforcing home directory permissions on ${HOME_DIR}..."

mkdir -p "${HOME_DIR}/.config"
mkdir -p "${HOME_DIR}/.local/share"
mkdir -p "${HOME_DIR}/.local/state"
mkdir -p "${HOME_DIR}/.cache"

# Set secure ownership and permissions
run_in_target chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}"
chmod 750 "${HOME_DIR}"

echo "[✓] Omarchy user provisioning completed successfully!"
