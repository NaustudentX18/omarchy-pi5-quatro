#!/usr/bin/env bash
# ==============================================================================
# v2.0.1 FOV hotfix — ship omarchy-fov Hyprland 0.56+ lua eval path (issue #2)
# Safe to run on live Omarchy Quattro Pi 5 installs (v2.0.0+).
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/NaustudentX18/omarchy-pi5-quattro/master/updates/v2.0.1-fov-update.sh | sudo bash
# ==============================================================================
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

REPO_RAW="${OMARCHY_PI5_RAW:-https://raw.githubusercontent.com/NaustudentX18/omarchy-pi5-quattro/master}"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "[*] Fetching fov overlay from ${REPO_RAW}/fov ..."
mkdir -p "${TMP}/fov"
for f in omarchy-fov omarchy-fov.conf omarchy-fov.service install_fov.sh README.md; do
  curl -fsSL "${REPO_RAW}/fov/${f}" -o "${TMP}/fov/${f}"
done
chmod +x "${TMP}/fov/omarchy-fov" "${TMP}/fov/install_fov.sh"

# Keep a local copy so post-update can reassert later
install -d /usr/local/share/omarchy-pi5-quattro/fov
cp -a "${TMP}/fov/." /usr/local/share/omarchy-pi5-quattro/fov/

bash /usr/local/share/omarchy-pi5-quattro/fov/install_fov.sh /

# Also refresh post-update script if present upstream path is available
if curl -fsSL "${REPO_RAW}/system_tuning/omarchy-pi5-post-update.sh" -o /usr/local/bin/omarchy-pi5-post-update 2>/dev/null; then
  chmod 0755 /usr/local/bin/omarchy-pi5-post-update
  echo "[*] Refreshed /usr/local/bin/omarchy-pi5-post-update"
fi

echo "[✓] FOV hotfix installed. As user omarchy, run:"
echo "    omarchy-fov status"
echo "    systemctl --user enable --now omarchy-fov"
