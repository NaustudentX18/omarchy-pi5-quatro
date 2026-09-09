#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quatro v1.0.6 in-place update — Usability & Hardening Patch
#
# Fixes on existing installs:
#   1. Walker terminal execution: sets terminal = "alacritty -e" in config.toml
#   2. Unhides btop in launcher so it is directly searchable in Walker / Apps
#   3. Chromium extension tilde expansion in chromium-flags.conf
#   4. Super + D keybinding for direct Walker app launcher in Hyprland
#   5. Headless monitor fallback safeguard in omarchy-hyprland-monitor-watch
#   6. Disables bt-agent crash loop
#
# Usage:
#   sudo ./v1.0.6-update.sh
# ==============================================================================
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Run as root: sudo $0" >&2
    exit 1
fi

echo "[*] Omarchy Quatro v1.0.6 update — usability & hardening patch"
echo "------------------------------------------------------------"

# 1. Walker terminal configuration
echo "[+] Configuring Walker terminal runner..."
for cfg in /home/omarchy/.config/walker/config.toml /etc/skel/.config/walker/config.toml; do
    if [ -f "$cfg" ]; then
        if ! grep -q 'terminal =' "$cfg"; then
            sed -i '1s/^/terminal = "alacritty -e"\n/' "$cfg"
        fi
    fi
done

# 2. Unhide btop in launcher
echo "[+] Unhiding btop in launcher..."
sed -i '/^btop$/d' /usr/share/omarchy/default/omarchy/launcher.hides 2>/dev/null || true
sed -i '/^btop$/d' /home/omarchy/.local/share/omarchy/default/omarchy/launcher.hides 2>/dev/null || true

# 3. Fix Chromium flags tilde expansion
echo "[+] Fixing Chromium flags tilde expansion..."
for cfg in /home/omarchy/.config/chromium-flags.conf /etc/skel/.config/chromium-flags.conf; do
    if [ -f "$cfg" ]; then
        sed -i 's|~/.local|/home/omarchy/.local|g' "$cfg"
    fi
done

# 4. Add Super+D keybinding
echo "[+] Configuring Super+D keybinding in Hyprland..."
if [ -f /home/omarchy/.config/hypr/bindings.conf ]; then
    if ! grep -q 'SUPER, D,' /home/omarchy/.config/hypr/bindings.conf; then
        sed -i '/# Add extra bindings/a bindd = SUPER, D, Application launcher, exec, walker -p "Launch…"' /home/omarchy/.config/hypr/bindings.conf
    fi
fi
if [ -f /home/omarchy/.config/hypr/bindings.lua ]; then
    if ! grep -q '"SUPER + D"' /home/omarchy/.config/hypr/bindings.lua; then
        sed -i '/-- Add a new binding/a o.bind("SUPER + D", "Application launcher", "walker -p \\\"Launch…\\\"")' /home/omarchy/.config/hypr/bindings.lua
    fi
fi

# 5. Disable crashing bt-agent.service
echo "[+] Disabling bt-agent service..."
systemctl --user --global disable bt-agent.service 2>/dev/null || true
pkill -f bt-agent 2>/dev/null || true

# 6. Headless monitor fallback safeguard
echo "[+] Installing headless fallback safeguard..."
if [ -f /usr/bin/omarchy-hyprland-monitor-watch ] && ! grep -q 'ensure_monitor()' /usr/bin/omarchy-hyprland-monitor-watch; then
    cat << 'WATCH_PATCH' >> /usr/bin/omarchy-hyprland-monitor-watch

# Pi 5 headless fallback safeguard
ensure_monitor() {
  local monitors
  monitors=$(hyprctl monitors all -j 2>/dev/null)
  if [[ "$monitors" == "[]" || -z "$monitors" ]]; then
    hyprctl output create headless >/dev/null 2>&1
  fi
}
cleanup_headless_on_physical() {
  local monitors has_headless has_physical
  monitors=$(hyprctl monitors all -j 2>/dev/null)
  has_headless=$(jq 'any(.[]; .name | startswith("HEADLESS"))' <<<"$monitors" 2>/dev/null)
  has_physical=$(jq 'any(.[]; (.name | startswith("HEADLESS") | not) and .disabled != true)' <<<"$monitors" 2>/dev/null)
  if [[ "$has_headless" == "true" && "$has_physical" == "true" ]]; then
    for h in $(jq -r '.[] | select(.name | startswith("HEADLESS")) | .name' <<<"$monitors"); do
      hyprctl output remove "$h" >/dev/null 2>&1
    done
  fi
}
ensure_monitor
WATCH_PATCH
fi

chmod +x /home/omarchy/.config/walker/config.toml 2>/dev/null || true
echo "[✓] Update complete! Reloading Hyprland..."
su -s /bin/bash omarchy -c "export WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1001 HYPRLAND_INSTANCE_SIGNATURE=\$(ls -t /run/user/1001/hypr/ 2>/dev/null | head -1); hyprctl reload >/dev/null 2>&1 || true; pkill -f walker 2>/dev/null || true" 2>/dev/null || true
echo "[✓] All done!"
