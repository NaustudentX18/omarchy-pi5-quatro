#!/usr/bin/env bash
# ==============================================================================
# omarchy-pi5-post-update: Re-asserts Pi 5 hardware safeguards & configurations
# Target: Raspberry Pi 5 (Arch Linux ARM)
# ==============================================================================
# Triggered automatically after pacman or omarchy updates to guarantee that
# upstream package updates never overwrite Pi 5 hardware adaptations.
# ==============================================================================
set -euo pipefail

echo "[*] [Omarchy Quattro] Running Pi 5 post-update reconciliation..."

# 0. Sync /opt/omarchy from upstream quattro if git repository is present
if [ -d /opt/omarchy/.git ]; then
    echo "    Syncing /opt/omarchy from origin/quattro..."
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

# 1. Re-assert Headless monitor fallback safeguard in /usr/bin/omarchy-hyprland-monitor-watch
if [ -f /usr/bin/omarchy-hyprland-monitor-watch ] && ! grep -q 'ensure_monitor()' /usr/bin/omarchy-hyprland-monitor-watch; then
    echo "    Re-asserting headless monitor fallback in omarchy-hyprland-monitor-watch..."
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

# 2. Re-assert Walker terminal runner (Alacritty for TUIs)
for cfg in /home/omarchy/.config/walker/config.toml /etc/skel/.config/walker/config.toml; do
    if [ -f "$cfg" ]; then
        if ! grep -q 'terminal =' "$cfg"; then
            echo "    Setting Walker terminal runner to alacritty -e in $cfg..."
            sed -i '1s/^/terminal = "alacritty -e"\n/' "$cfg"
        fi
    fi
done

# 3. Re-assert btop unhidden in launcher
sed -i '/^btop$/d' /usr/share/omarchy/default/omarchy/launcher.hides 2>/dev/null || true
sed -i '/^btop$/d' /home/omarchy/.local/share/omarchy/default/omarchy/launcher.hides 2>/dev/null || true

# 4. Enforce clean binary precedence: remove stale /etc/omarchy.conf and legacy shadowing
rm -f /etc/omarchy.conf
find /usr/local/bin -type l -name 'omarchy*' -delete 2>/dev/null || true

# 5. Ensure Tailscale remote Ollama host in /etc/environment
grep -q "OLLAMA_HOST" /etc/environment 2>/dev/null || echo "OLLAMA_HOST=http://100.127.91.97:11434" >> /etc/environment

# 6. Ensure Super+D keybinding in Hyprland
if [ -f /home/omarchy/.config/hypr/bindings.conf ] && ! grep -q 'SUPER, D' /home/omarchy/.config/hypr/bindings.conf; then
    sed -i '/# Add extra bindings/a bindd = SUPER, D, Application launcher, exec, walker -p "Launch…"' /home/omarchy/.config/hypr/bindings.conf 2>/dev/null || true
fi
if [ -f /home/omarchy/.config/hypr/bindings.lua ] && ! grep -q 'SUPER + D' /home/omarchy/.config/hypr/bindings.lua; then
    sed -i '/-- Add a new binding/a o.bind("SUPER + D", "Application launcher", "walker -p \\\"Launch…\\\"")' /home/omarchy/.config/hypr/bindings.lua 2>/dev/null || true
fi

# 7. Ensure bt-agent crash loop remains disabled
systemctl --user --global disable bt-agent.service 2>/dev/null || true

# 8. Ensure Chromium flags tilde expansion
for cfg in /home/omarchy/.config/chromium-flags.conf /etc/skel/.config/chromium-flags.conf; do
    if [ -f "$cfg" ]; then
        sed -i 's|~/.local|/home/omarchy/.local|g' "$cfg" 2>/dev/null || true
    fi
done

# 9. Ensure Argon active cooling fan daemon is active
systemctl is-active --quiet argononed.service || systemctl enable --now argononed.service 2>/dev/null || true

echo "[*] [Omarchy Quattro] Pi 5 post-update reconciliation complete."
