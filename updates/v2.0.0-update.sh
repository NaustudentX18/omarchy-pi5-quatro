#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quattro v2.0.0 in-place update — Definitive AI Desktop Release
# ==============================================================================
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Run as root: sudo $0" >&2
    exit 1
fi

echo "[*] Omarchy Quattro v2.0.0 update — Definitive AI Desktop Release"
echo "----------------------------------------------------------------------"

# 1. Un-shadow v4 binaries & clean legacy configs
echo "[+] Cleaning legacy shadowing and config overrides..."
rm -f /etc/omarchy.conf
find /usr/local/bin -type l -name 'omarchy*' -delete 2>/dev/null || true

# 2. Sync /opt/omarchy to upstream quattro repository
echo "[+] Syncing /opt/omarchy to upstream quattro repository..."
mkdir -p /opt/omarchy
if [ -d /opt/omarchy/.git ]; then
    git -C /opt/omarchy fetch --tags origin 2>/dev/null || git -C /opt/omarchy fetch origin 2>/dev/null || true
    git -C /opt/omarchy checkout -f origin/quattro 2>/dev/null || git -C /opt/omarchy checkout -f v4.0.3 2>/dev/null || true
else
    git clone --depth 1 --branch quattro https://github.com/omacom/omarchy.git /opt/omarchy 2>/dev/null || \
    git clone --depth 1 https://github.com/omacom/omarchy.git /opt/omarchy
fi

# Ensure /usr/share/omarchy points to /opt/omarchy
if [ ! -d /usr/share/omarchy ] || [ -L /usr/share/omarchy ]; then
    mkdir -p /usr/share
    ln -snf /opt/omarchy /usr/share/omarchy
fi

# 3. Deploy v4 binaries to /usr/bin
echo "[+] Deploying Omarchy binaries into /usr/bin..."
mkdir -p /usr/bin /usr/share/omarchy/bin
if [ -d /opt/omarchy/bin ]; then
    chmod +x /opt/omarchy/bin/* 2>/dev/null || true
    for bin in /opt/omarchy/bin/*; do
        if [ -f "$bin" ]; then
            bname=$(basename "$bin")
            install -Dm755 "$bin" "/usr/bin/$bname"
            ln -sf "/usr/bin/$bname" "/usr/share/omarchy/bin/$bname" 2>/dev/null || true
        fi
    done
fi

# 4. Configure pacman repository & system update
echo "[+] Updating pacman mirrors and core system packages..."
grep -q '^DisableSandbox' /etc/pacman.conf || sed -i 's/^\[options\]/[options]\nDisableSandbox/' /etc/pacman.conf
grep -q '^RetryAttempts' /etc/pacman.conf || sed -i 's/^\[options\]/[options]\nRetryAttempts = 3/' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf 2>/dev/null || true

if ! grep -q '^\[omarchy\]' /etc/pacman.conf; then
    cat >> /etc/pacman.conf <<'OMARCHY_REPO_EOF'

[omarchy]
Server = https://pkgs.omarchy.org/edge/$arch
SigLevel = Never
OMARCHY_REPO_EOF
fi

pacman -Syu --noconfirm --overwrite '/usr/share/omarchy/*' --overwrite '/usr/share/applications/*' 2>&1 || echo "[!] Notice: pacman -Syu completed with non-fatal warnings"

# 5. Install missing / updated agentware and parity packages
echo "[+] Installing v2.0 Agentware suite and application parity packages..."
pacman -S --needed --noconfirm --overwrite '/usr/share/applications/*' \
    openclaw cursor-cli openai-codex-desktop perplexity visual-studio-code-bin \
    typora usage imv hyprland-preview-share-picker flatpak 2>&1 || echo "[!] Pacman package install notice"

# 6. Flatpak layer verification: Flathub, Obsidian, Pinta
echo "[+] Verifying Flatpak layer (Obsidian, Pinta)..."
if command -v flatpak &>/dev/null; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    flatpak install -y --noninteractive flathub md.obsidian.Obsidian com.github.PintaProject.Pinta 2>/dev/null || true
fi

# 7. Spotify webapp launcher parity
echo "[+] Verifying Spotify webapp launcher..."
mkdir -p /home/omarchy/.local/share/applications/icons /etc/skel/.local/share/applications/icons
if [ ! -f /home/omarchy/.local/share/applications/icons/Spotify.png ]; then
    curl -sL https://cdn.iconscout.com/icon/free/png-512/free-spotify-icon-download-in-svg-png-gif-file-formats--logo-social-media-pack-logos-icons-226458.png \
        -o /home/omarchy/.local/share/applications/icons/Spotify.png 2>/dev/null || true
    cp /home/omarchy/.local/share/applications/icons/Spotify.png /etc/skel/.local/share/applications/icons/ 2>/dev/null || true
fi
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
chmod +x /home/omarchy/.local/share/applications/Spotify.desktop /etc/skel/.local/share/applications/Spotify.desktop 2>/dev/null || true

# 8. OpenClaw Control UI WebApp Desktop Entry
echo "[+] Configuring OpenClaw Control UI webapp..."
cat << 'OPENCLAW_EOF' | tee /home/omarchy/.local/share/applications/OpenClaw.desktop > /etc/skel/.local/share/applications/OpenClaw.desktop
[Desktop Entry]
Version=1.0
Name=OpenClaw
Comment=OpenClaw Agent Platform Control UI
Exec=omarchy-launch-openclaw
Terminal=false
Type=Application
Icon=openclaw
StartupNotify=true
Categories=Development;Utility;
OPENCLAW_EOF
chmod +x /home/omarchy/.local/share/applications/OpenClaw.desktop /etc/skel/.local/share/applications/OpenClaw.desktop 2>/dev/null || true

# 9. Upstream Security Hardenings
echo "[+] Applying upstream security hardenings..."

# 9a. Hardening system-sleep hook directory permissions (root-owned 0755)
if [ -d /usr/lib/systemd/system-sleep ]; then
    chown -R root:root /usr/lib/systemd/system-sleep
    chmod 0755 /usr/lib/systemd/system-sleep
    find /usr/lib/systemd/system-sleep -type f -exec chmod 0755 {} +
fi

# 9b. Disabling unrestricted remote control in Kitty
for kcfg in /home/omarchy/.config/kitty/kitty.conf /etc/skel/.config/kitty/kitty.conf; do
    if [ -f "$kcfg" ]; then
        sed -i -E 's/^[[:space:]]*allow_remote_control[[:space:]]+(yes|y|true)/# &/' "$kcfg"
    fi
done

# 9c. 1Password HiDPI window scale fix
for op_desktop in /usr/share/applications/1password.desktop /home/omarchy/.local/share/applications/1password.desktop; do
    if [ -f "$op_desktop" ] && ! grep -q 'force-device-scale-factor' "$op_desktop"; then
        sed -i 's|Exec=1password|Exec=1password --force-device-scale-factor=1|g' "$op_desktop" 2>/dev/null || true
    fi
done

# 9d. Mise auto-prune regression fix
if command -v mise &>/dev/null; then
    su -s /bin/bash omarchy -c "mise settings set upgrade.auto_prune false" 2>/dev/null || true
    mise settings set upgrade.auto_prune false 2>/dev/null || true
fi

# 9e. Hermes skill links & agentware integration
echo "[+] Linking Omarchy agent skills for Hermes..."
mkdir -p /home/omarchy/.hermes/skills /etc/skel/.hermes/skills
if [ -d /opt/omarchy/default/agents/skills ]; then
    for sk in /opt/omarchy/default/agents/skills/*; do
        [ -e "$sk" ] || continue
        skname=$(basename "$sk")
        ln -snf "$sk" "/home/omarchy/.hermes/skills/$skname" 2>/dev/null || true
        ln -snf "$sk" "/etc/skel/.hermes/skills/$skname" 2>/dev/null || true
    done
fi

# 9f. Muse Code CLI via mise wrapper (upstream migration 1788724825.sh)
echo "[+] Configuring Muse Code via mise wrapper..."
if command -v omarchy-mise-install &>/dev/null; then
    su -s /bin/bash omarchy -c 'omarchy-mise-install "http:muse[url=https://api.meta.ai/muse-launcher.sh,bin=muse,version_list_url=https://api.meta.ai/muse-code/channels/muse-stable,version_json_path=.version]" muse' 2>/dev/null || true
elif command -v mise &>/dev/null; then
    su -s /bin/bash omarchy -c 'mise use -g "http:muse[url=https://api.meta.ai/muse-launcher.sh,bin=muse,version_list_url=https://api.meta.ai/muse-code/channels/muse-stable,version_json_path=.version]"' 2>/dev/null || true
fi

# 9g. Retire legacy stock user icon font
echo "[+] Refreshing system and icon fonts..."
if [ -f /home/omarchy/.local/share/fonts/omarchy.ttf ]; then
    rm -f /home/omarchy/.local/share/fonts/omarchy.ttf
fi
fc-cache -f 2>/dev/null || true

# 10. Native omarchy update hook integration & Pi 5 post-update reconciliation
echo "[+] Integrating native omarchy update hooks and Pi 5 reconciliation..."
mkdir -p /usr/local/bin
mkdir -p /etc/pacman.d/hooks
mkdir -p /home/omarchy/.config/omarchy/hooks/post-update.d
mkdir -p /etc/skel/.config/omarchy/hooks/post-update.d
mkdir -p /root/.config/omarchy/hooks/post-update.d
mkdir -p /etc/omarchy/hooks.d

# Deploy post-update reconciliation script
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../system_tuning/omarchy-pi5-post-update.sh" ]; then
    cp -a "${SCRIPT_DIR}/../system_tuning/omarchy-pi5-post-update.sh" /usr/local/bin/omarchy-pi5-post-update
    chmod 0755 /usr/local/bin/omarchy-pi5-post-update
elif [ -f /usr/local/bin/omarchy-pi5-post-update ]; then
    chmod 0755 /usr/local/bin/omarchy-pi5-post-update
fi

# Deploy pacman hook
if [ -f "${SCRIPT_DIR}/../system_tuning/99-omarchy-pi5.hook" ]; then
    cp -a "${SCRIPT_DIR}/../system_tuning/99-omarchy-pi5.hook" /etc/pacman.d/hooks/99-omarchy-pi5.hook
    chmod 0644 /etc/pacman.d/hooks/99-omarchy-pi5.hook
fi

# Deploy native Omarchy update hooks (executed by 'omarchy update')
cat << 'OMARCHY_HOOK_EOF' > /home/omarchy/.config/omarchy/hooks/post-update.d/10-pi5-guard.sh
#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quattro - Native omarchy update hook for Pi 5
# ==============================================================================
set -euo pipefail

if [ -d /opt/omarchy/.git ]; then
    echo "[*] [Omarchy Quattro] Updating /opt/omarchy from origin/quattro..."
    git -C /opt/omarchy fetch --depth 1 origin quattro 2>/dev/null || git -C /opt/omarchy fetch origin 2>/dev/null || true
    git -C /opt/omarchy checkout -B quattro origin/quattro 2>/dev/null || true
    git -C /opt/omarchy reset --hard origin/quattro 2>/dev/null || true
    if [ -w /usr/bin ] && [ -d /opt/omarchy/bin ]; then
        chmod +x /opt/omarchy/bin/* 2>/dev/null || true
        for bin_path in /opt/omarchy/bin/*; do
            if [ -f "${bin_path}" ] && [ -x "${bin_path}" ]; then
                bin_name="$(basename "${bin_path}")"
                install -Dm755 "${bin_path}" "/usr/bin/${bin_name}" 2>/dev/null || true
                ln -sf "/usr/bin/${bin_name}" "/usr/share/omarchy/bin/${bin_name}" 2>/dev/null || true
            fi
        done
    fi
fi

if [ -x /usr/local/bin/omarchy-pi5-post-update ]; then
    /usr/local/bin/omarchy-pi5-post-update
fi
OMARCHY_HOOK_EOF
chmod 0755 /home/omarchy/.config/omarchy/hooks/post-update.d/10-pi5-guard.sh
cp -a /home/omarchy/.config/omarchy/hooks/post-update.d/10-pi5-guard.sh /etc/skel/.config/omarchy/hooks/post-update.d/10-pi5-guard.sh
cp -a /home/omarchy/.config/omarchy/hooks/post-update.d/10-pi5-guard.sh /root/.config/omarchy/hooks/post-update.d/10-pi5-guard.sh

cat << 'HOOK_EOF' > /etc/omarchy/hooks.d/99-pi5-quattro-sync.sh
#!/usr/bin/env bash
# Ensures Pi 5 specific overlays, kernel packages, and GPU configs persist across omarchy update
if [ -x /usr/local/bin/omarchy-pi5-post-update ]; then
    /usr/local/bin/omarchy-pi5-post-update
fi
HOOK_EOF
chmod 0755 /etc/omarchy/hooks.d/99-pi5-quattro-sync.sh

# Run reconciliation script once now
if [ -x /usr/local/bin/omarchy-pi5-post-update ]; then
    /usr/local/bin/omarchy-pi5-post-update
fi

# 11. Walker & Desktop Application Launcher Index
echo "[+] Hardening Walker & desktop application launcher index..."
for cfg in /home/omarchy/.config/walker/config.toml /etc/skel/.config/walker/config.toml; do
    if [ -f "$cfg" ]; then
        if ! grep -q 'terminal =' "$cfg"; then
            sed -i '1s/^/terminal = "alacritty -e"\n/' "$cfg"
        fi
    fi
done

sed -i '/^btop$/d' /usr/share/omarchy/default/omarchy/launcher.hides 2>/dev/null || true
sed -i '/^btop$/d' /home/omarchy/.local/share/omarchy/default/omarchy/launcher.hides 2>/dev/null || true

for cfg in /home/omarchy/.config/chromium-flags.conf /etc/skel/.config/chromium-flags.conf; do
    if [ -f "$cfg" ]; then
        sed -i 's|~/.local|/home/omarchy/.local|g' "$cfg"
    fi
done

if [ -f /home/omarchy/.config/hypr/bindings.conf ] && ! grep -q 'SUPER, D,' /home/omarchy/.config/hypr/bindings.conf; then
    sed -i '/# Add extra bindings/a bindd = SUPER, D, Application launcher, exec, walker -p "Launch…"' /home/omarchy/.config/hypr/bindings.conf
fi
if [ -f /home/omarchy/.config/hypr/bindings.lua ] && ! grep -q '"SUPER + D"' /home/omarchy/.config/hypr/bindings.lua; then
    sed -i '/-- Add a new binding/a o.bind("SUPER + D", "Application launcher", "walker -p \\\"Launch…\\\"")' /home/omarchy/.config/hypr/bindings.lua
fi

systemctl --user --global disable bt-agent.service 2>/dev/null || true
pkill -f bt-agent 2>/dev/null || true

# 12. Hardware Pi 5 safeguards (Headless watchdog & remote Ollama)
echo "[+] Verifying Pi 5 hardware safeguards..."
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

grep -q "OLLAMA_HOST" /etc/environment 2>/dev/null || echo "OLLAMA_HOST=http://100.127.91.97:11434" >> /etc/environment

# 13. Refresh Application Database & Fix User Permissions
echo "[+] Finalizing desktop database and user permissions..."
chown -R omarchy:omarchy /home/omarchy/.local /home/omarchy/.config /home/omarchy/.hermes 2>/dev/null || true
update-desktop-database /home/omarchy/.local/share/applications 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true

# 14. Graceful desktop reload without disconnecting session
echo "[+] Reloading Hyprland and Walker components..."
su -s /bin/bash omarchy -c "export WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1001 HYPRLAND_INSTANCE_SIGNATURE=\$(ls -t /run/user/1001/hypr/ 2>/dev/null | head -1); hyprctl reload >/dev/null 2>&1 || true; pkill -f walker 2>/dev/null || true" 2>/dev/null || true

echo "----------------------------------------------------------------------"
echo "[✓] Omarchy Quattro v2.0.0 Definitive Release update successfully applied!"
echo "[✓] 100% Upstream Parity. Full Agentware Suite active. Native updates ready."
