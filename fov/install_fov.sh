#!/usr/bin/env bash
# ==============================================================================
# install_fov.sh — Install omarchy-fov overlay (Hyprland 0.56+ lua eval path)
# Omarchy Quattro Pi 5 — fixes issue #2
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_ROOT="${1:-/}"
BIN_TARGET="${TARGET_ROOT}/usr/local/bin/omarchy-fov"
CONF_TARGET="${TARGET_ROOT}/etc/omarchy-fov.conf"
UNIT_NAME="omarchy-fov.service"

echo "=================================================================="
echo " Omarchy Quattro Pi 5: Installing omarchy-fov (Hyprland 0.56+)"
echo " Target root: ${TARGET_ROOT}"
echo "=================================================================="

if [[ "${TARGET_ROOT}" == "/" && "$(id -u)" -ne 0 ]]; then
  echo "[ERROR] Run as root when installing to live system (sudo $0)" >&2
  exit 1
fi

echo "[1/4] Installing daemon to ${BIN_TARGET}..."
install -d "$(dirname "${BIN_TARGET}")"
install -m 0755 "${SCRIPT_DIR}/omarchy-fov" "${BIN_TARGET}"

echo "[2/4] Installing system defaults to ${CONF_TARGET}..."
install -d "$(dirname "${CONF_TARGET}")"
if [[ -f "${CONF_TARGET}" ]]; then
  echo "      Keeping existing ${CONF_TARGET} (not overwriting user edits)."
else
  install -m 0644 "${SCRIPT_DIR}/omarchy-fov.conf" "${CONF_TARGET}"
fi

# Seed user config template without clobbering
for home in "${TARGET_ROOT}/home/omarchy" "${TARGET_ROOT}/etc/skel"; do
  if [[ -d "${home}" ]] || [[ "${home}" == */skel ]]; then
    mkdir -p "${home}/.config/omarchy"
    if [[ ! -f "${home}/.config/omarchy/fov.conf" ]]; then
      cat > "${home}/.config/omarchy/fov.conf" <<'USERCONF'
# User FOV overrides (optional). Sourced after /etc/omarchy-fov.conf.
# Example:
# PROFILE_luma="60 60 96 96"
# WAYBAR_NAMESPACE=omarchy-bar
USERCONF
    fi
  fi
done

echo "[3/4] Installing user systemd unit..."
# Prefer user unit (Hyprland session); also drop a template under /etc/skel
UNIT_SRC="${SCRIPT_DIR}/omarchy-fov.service"
for unit_dir in \
  "${TARGET_ROOT}/home/omarchy/.config/systemd/user" \
  "${TARGET_ROOT}/etc/skel/.config/systemd/user" \
  "${TARGET_ROOT}/usr/lib/systemd/user"
do
  mkdir -p "${unit_dir}"
  install -m 0644 "${UNIT_SRC}" "${unit_dir}/${UNIT_NAME}"
done

echo "[4/4] Enabling omarchy-fov.service for user omarchy (when possible)..."
if [[ "${TARGET_ROOT}" == "/" ]] && id -u omarchy >/dev/null 2>&1; then
  if command -v systemctl >/dev/null 2>&1; then
    # Enable lingering so user services can start at boot without login race
    loginctl enable-linger omarchy 2>/dev/null || true
    sudo -u omarchy XDG_RUNTIME_DIR="/run/user/$(id -u omarchy)" \
      systemctl --user daemon-reload 2>/dev/null || true
    sudo -u omarchy XDG_RUNTIME_DIR="/run/user/$(id -u omarchy)" \
      systemctl --user enable --now omarchy-fov.service 2>/dev/null \
      || echo "      [INFO] Unit installed; enable after graphical login: systemctl --user enable --now omarchy-fov"
  fi
  # SUPER+F11 binding (lua + conf) if missing
  for bindfile in /home/omarchy/.config/hypr/bindings.lua /home/omarchy/.config/hypr/bindings.conf; do
    if [[ -f "${bindfile}" ]] && ! grep -q 'omarchy-fov' "${bindfile}"; then
      if [[ "${bindfile}" == *.lua ]]; then
        printf '\no.bind("SUPER + F11", "Toggle FOV profile", "omarchy-fov toggle")\n' >> "${bindfile}"
      else
        printf '\nbindd = SUPER, F11, Toggle FOV profile, exec, omarchy-fov toggle\n' >> "${bindfile}"
      fi
      echo "      Added SUPER+F11 binding in ${bindfile}"
    fi
  done
else
  echo "      Offline/chroot install — enable after first boot:"
  echo "        systemctl --user enable --now omarchy-fov"
fi

echo "=================================================================="
echo " omarchy-fov installed. Verify on device:"
echo "   omarchy-fov status"
echo "   omarchy-fov luma && hyprctl monitors -j | jq -c '.[0].reserved'"
echo "=================================================================="
