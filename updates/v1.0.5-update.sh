#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quattro v1.0.5 in-place update — LIKE-FOR-LIKE Omarchy v4 parity
#
# Brings an existing v1.0.x install up to v1.0.5 parity without a reflash:
#   1. Adds the [omarchy] pacman repo (pkgs.omarchy.org/edge/aarch64)
#   2. Installs everything v1.0.5 bakes in:
#      - upstream's omarchy-base.packages (from your /opt/omarchy clone)
#      - omarchy-repo extras: their tooling (tensaku, omacalc, herdr, ...),
#        AI CLIs (claude-code, codex, crush, copilot, cursor),
#        walker + elephant + quickshell launcher stack, retroarch/libretro,
#        yaru themes, mise, openclaw, sunshine, wayfreeze, ...
#      - Hyprland stack from the omarchy repo (resolves against ALARM
#        aquamarine!) — installed but sway STAYS your default session
#   3. Carries the v1.0.4 fixes too: zram-generator swap + avahi mDNS
#      (safe to run on a v1.0.4 box — everything is idempotent)
#
# Usage:
#   sudo ./v1.0.5-update.sh          # parity set only
#   sudo ./v1.0.5-update.sh --full   # + full pacman -Syu first
# ==============================================================================
set -euo pipefail

FULL_UPGRADE=0
[ "${1:-}" = "--full" ] && FULL_UPGRADE=1

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Run as root: sudo $0" >&2
    exit 1
fi
command -v pacman &>/dev/null || { echo "[!] Arch Linux ARM only (pacman not found)" >&2; exit 1; }

echo "[*] Omarchy Quattro v1.0.5 update — full Omarchy v4 parity"
echo "------------------------------------------------------------"

# --- 1. [omarchy] repo ---------------------------------------------------------
if ! grep -q '^\[omarchy\]' /etc/pacman.conf; then
    cat >> /etc/pacman.conf <<'OMARCHY_REPO_EOF'

[omarchy]
Server = https://pkgs.omarchy.org/edge/$arch
SigLevel = Never
OMARCHY_REPO_EOF
    echo "[+] [omarchy] repo added to /etc/pacman.conf"
else
    echo "[=] [omarchy] repo already configured"
fi

# --- 2. Sync -------------------------------------------------------------------
if [ "$FULL_UPGRADE" -eq 1 ]; then
    pacman -Syu --noconfirm
else
    pacman -Sy --noconfirm
fi

# --- 3. v1.0.4 fixes (idempotent on v1.0.4 boxes) -------------------------------
pacman -S --needed --noconfirm zram-generator avahi nss-mdns
if [ ! -f /etc/systemd/zram-generator.conf ]; then
    cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = 4096
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
fi
systemctl daemon-reload
swapon --show=NAME --noheadings 2>/dev/null | grep -q '^/dev/zram0$' \
    || systemctl start systemd-zram-setup@zram0.service || true
systemctl enable --now avahi-daemon.service
if grep -q '^hosts:' /etc/nsswitch.conf && ! grep -q '^hosts:.*mdns' /etc/nsswitch.conf; then
    sed -i -E '/^hosts:/ s/(resolve|dns)/mdns4_minimal [NOTFOUND=return] \1/' /etc/nsswitch.conf
fi

# --- 4. Upstream parity set ------------------------------------------------------
OMARCHY_REPO_PKGS="omarchy-keyring omarchy-zsh omarchy-nvim omacalc omacut omawrite ttfx tobi-try tensaku herdr aether asdcontrol cliamp mise-bin walker elephant-all quickshell-git xdg-terminal-exec yaru-icon-theme yaru-gtk-theme ttf-ia-writer ttf-jetbrains-mono-nerd-basic tzupdate ufw-docker localsend hyprland-preview-share-picker claude-code crush-bin openai-codex-bin github-copilot-cli cursor-cli voxtype-bin omarchy-walker omarchy-settings omarchy-audio-tuner omasnap omatrack omazed strata schist-bin once-bin dbxcli-bin bun-bin openclaw nautilus-open-any-terminal wayfreeze sunshine retroarch retroarch-joypad-autoconfig-git libretro-cap32-git libretro-database-git libretro-fbneo-git libretro-vice-x128-git libretro-vice-x64-git libretro-vice-x64dtv-git libretro-vice-x64sc-git libretro-vice-xcbm2-git libretro-vice-xcbm5x0-git libretro-vice-xpet-git libretro-vice-xplus4-git libretro-vice-xscpu64-git libretro-vice-xvic-git"
BASE_PKGS=""
[ -f /opt/omarchy/install/omarchy-base.packages ] && \
    BASE_PKGS=$(grep -vE '^\s*(#|$)' /opt/omarchy/install/omarchy-base.packages)

echo "[+] Installing parity set (this is the big one — grab a coffee)..."
FAILED_PKGS=""
for p in $BASE_PKGS $OMARCHY_REPO_PKGS; do
    case "$p" in
        usage|dotnet-runtime|qemu-user-static-binfmt) continue;;  # no aarch64 pkg
    esac
    pacman -S --needed --noconfirm "$p" >/dev/null 2>&1 \
        || { echo "[!] unavailable: $p"; FAILED_PKGS="$FAILED_PKGS $p"; }
done

# --- 5. Hyprland stack (optional session; sway stays default) --------------------
echo "[+] Installing Hyprland stack (omarchy repo build)..."
pacman -S --needed --noconfirm hyprland hyprland-guiutils hyprshade hyprpm hyprtoolkit xdg-desktop-portal-hyprland \
    || echo "[!] Hyprland stack incomplete — sway stays your session"
pacman -S --needed --noconfirm omarchy \
    || echo "[=] 'omarchy' meta blocked on uwsm (no aarch64 pkg) — deps already installed"

# --- Verify -----------------------------------------------------------------------
echo ""
echo "[*] Verification:"
swapon --show=NAME --noheadings 2>/dev/null | grep -q '^/dev/zram0' \
    && echo "    PASS: zram swap active" || echo "    FAIL: zram not active"
systemctl is-active --quiet avahi-daemon.service \
    && echo "    PASS: avahi — you are omarchy-pi5.local" || echo "    FAIL: avahi down"
for c in tensaku walker quickshell claude mise; do
    command -v "$c" >/dev/null && echo "    PASS: $c" || echo "    MISS: $c"
done
command -v Hyprland >/dev/null \
    && echo "    PASS: Hyprland (pick it in SDDM; sway stays default)" || echo "    MISS: Hyprland"
echo ""
echo "[*] Done. Unavailable count:$(echo $FAILED_PKGS | wc -w)"
