#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quattro v1.0.6 in-place update — Full Parity & Usability Release
#
# Fixes on existing installs:
#   1. Binary un-shadowing: removes stale 3.8.5 symlinks from /usr/local/bin
#      and deletes /etc/omarchy.conf so the full 429+ v4.0.2 commands take effect.
#   2. Installs missing upstream parity packages: openai-codex-desktop,
#      perplexity, visual-studio-code-bin, typora, usage, imv, hyprland-preview-share-picker.
#   3. Installs Flatpak layer with Flathub remote, Obsidian, and Pinta.
#   4. Installs Spotify webapp launcher with desktop icon for 100% app parity.
#   5. Configures remote Ollama acceleration over Tailscale (100.127.91.97:11434).
#   6. Walker terminal execution: sets terminal = "alacritty -e" in config.toml.
#   7. Unhides btop in launcher so it is directly searchable in Walker / Apps.
#   8. Chromium extension tilde expansion in chromium-flags.conf.
#   9. Super + D keybinding for direct Walker app launcher in Hyprland.
#  10. Headless monitor fallback safeguard in omarchy-hyprland-monitor-watch.
#  11. Disables bt-agent crash loop.
#
# Usage:
#   sudo ./v1.0.6-update.sh
# ==============================================================================
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Run as root: sudo $0" >&2
    exit 1
fi

echo "[*] Omarchy Quattro v1.0.6 update — full parity & usability release"
echo "------------------------------------------------------------------"

# 1. Un-shadow v4.0.2 binaries
echo "[+] Resolving binary shadowing (un-shadowing v4.0.2 AI suite)..."
rm -f /etc/omarchy.conf
find /usr/local/bin -type l -name 'omarchy*' -delete

# 2. Install missing upstream parity packages
echo "[+] Installing upstream parity packages (AI desktop apps, tools)..."
pacman -S --needed --noconfirm --overwrite '/usr/share/applications/*' \
    openai-codex-desktop perplexity visual-studio-code-bin typora \
    usage imv hyprland-preview-share-picker 2>&1 || echo "[!] Pacman install warning"

# 3. Flatpak layer: Flathub, Obsidian, Pinta
echo "[+] Configuring Flatpak layer and installing Obsidian & Pinta..."
pacman -S --needed --noconfirm flatpak 2>&1 || true
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
flatpak install -y flathub md.obsidian.Obsidian com.github.PintaProject.Pinta || true

# 4. Spotify webapp launcher for full parity
echo "[+] Configuring Spotify webapp launcher..."
mkdir -p /home/omarchy/.local/share/applications/icons /etc/skel/.local/share/applications/icons
curl -sL https://cdn.iconscout.com/icon/free/png-512/free-spotify-icon-download-in-svg-png-gif-file-formats--logo-social-media-pack-logos-icons-226458.png -o /home/omarchy/.local/share/applications/icons/Spotify.png 2>/dev/null || true
cp /home/omarchy/.local/share/applications/icons/Spotify.png /etc/skel/.local/share/applications/icons/ 2>/dev/null || true
cat << 'SPOTIFY_EOF' | tee /home/omarchy/.local/share/applications/Spotify.desktop > /etc/skel/.local/share/applications/Spotify.desktop
[Desktop Entry]
Version=1.0
Name=Spotify
Comment=Spotify Music Streaming
Exec=omarchy-launch-webapp https://open.spotify.com/
Terminal=false
Type=Application
Icon=/home/omarchy/.local/share/applications/icons/Spotify.png
StartupNotify=true
Categories=AudioVideo;Audio;Player;Music;
SPOTIFY_EOF
chmod +x /home/omarchy/.local/share/applications/Spotify.desktop /etc/skel/.local/share/applications/Spotify.desktop
chown -R omarchy:omarchy /home/omarchy/.local/share/applications 2>/dev/null || true
update-desktop-database /home/omarchy/.local/share/applications 2>/dev/null || true

# 5. Remote Ollama host configuration over Tailscale
echo "[+] Configuring Tailscale remote Ollama host in /etc/environment..."
grep -q "OLLAMA_HOST" /etc/environment 2>/dev/null || echo "OLLAMA_HOST=http://100.127.91.97:11434" >> /etc/environment

# 6. Walker terminal configuration
echo "[+] Configuring Walker terminal runner..."
for cfg in /home/omarchy/.config/walker/config.toml /etc/skel/.config/walker/config.toml; do
    if [ -f "$cfg" ]; then
        if ! grep -q 'terminal =' "$cfg"; then
            sed -i '1s/^/terminal = "alacritty -e"\n/' "$cfg"
        fi
    fi
done

# 7. Unhide btop in launcher
echo "[+] Unhiding btop in launcher..."
sed -i '/^btop$/d' /usr/share/omarchy/default/omarchy/launcher.hides 2>/dev/null || true
sed -i '/^btop$/d' /home/omarchy/.local/share/omarchy/default/omarchy/launcher.hides 2>/dev/null || true

# 8. Fix Chromium flags tilde expansion
echo "[+] Fixing Chromium flags tilde expansion..."
for cfg in /home/omarchy/.config/chromium-flags.conf /etc/skel/.config/chromium-flags.conf; do
    if [ -f "$cfg" ]; then
        sed -i 's|~/.local|/home/omarchy/.local|g' "$cfg"
    fi
done

# 9. Add Super+D keybinding
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

# 10. Disable crashing bt-agent.service
echo "[+] Disabling bt-agent service..."
systemctl --user --global disable bt-agent.service 2>/dev/null || true
pkill -f bt-agent 2>/dev/null || true

# 11. Headless monitor fallback safeguard
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
echo "[✓] Omarchy Quattro v1.0.6 update successfully applied!"
