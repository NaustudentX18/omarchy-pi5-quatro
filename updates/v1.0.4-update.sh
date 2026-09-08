#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quatro v1.0.4 in-place update
#
# Applies ONLY the v1.0.4 deltas to an existing v1.0.x install — no reflash,
# no NVMe extraction. Safe to re-run (idempotent).
#
# What it does:
#   1. Installs zram-generator + avahi + nss-mdns (the v1.0.4 additions)
#   2. Ensures /etc/systemd/zram-generator.conf (4 GB zstd swap) exists
#   3. Activates zram swap immediately (no reboot needed; persists at boot)
#   4. Enables + starts avahi-daemon  -> box announces itself as
#      `omarchy-pi5.local` on the LAN
#   5. Wires mdns4_minimal into nsswitch.conf so the Pi resolves other
#      machines' .local hostnames
#
# Why: v1.0.0–v1.0.3 shipped WITHOUT zram-generator installed, so the
# `systemd-zram-setup@zram0` enable line never worked (its unit template has
# no [Install] section — activation is the generator's job at boot) and the
# boxes ran with no swap. avahi/mDNS was added in v1.0.4.
#
# Usage:
#   sudo ./v1.0.4-update.sh          # apply the v1.0.4 fix set only
#   sudo ./v1.0.4-update.sh --full   # also run a full `pacman -Syu` first
# ==============================================================================
set -euo pipefail

FULL_UPGRADE=0
[ "${1:-}" = "--full" ] && FULL_UPGRADE=1

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Run as root: sudo $0" >&2
    exit 1
fi
if ! command -v pacman &>/dev/null; then
    echo "[!] This script targets Arch Linux ARM (Omarchy Quatro). pacman not found." >&2
    exit 1
fi

echo "[*] Omarchy Quatro v1.0.4 update — zram swap + avahi mDNS"
echo "-----------------------------------------------------------"

# --- 1. Packages --------------------------------------------------------------
echo "[+] Installing zram-generator, avahi, nss-mdns ..."
if [ "$FULL_UPGRADE" -eq 1 ]; then
    echo "[+] --full: running full system upgrade first ..."
    pacman -Syu --noconfirm --needed zram-generator avahi nss-mdns
else
    # Fix-set only: sync DBs, install just the three packages.
    # (Partial-upgrade caveat: run --full occasionally to stay current.)
    pacman -Sy --noconfirm --needed zram-generator avahi nss-mdns
fi

# --- 2. zram-generator.conf ---------------------------------------------------
ZRAM_CONF=/etc/systemd/zram-generator.conf
if [ ! -f "$ZRAM_CONF" ]; then
    echo "[+] Writing $ZRAM_CONF (4 GB zstd swap, priority 100) ..."
    mkdir -p /etc/systemd
    cat > "$ZRAM_CONF" <<'EOF'
# Omarchy Quatro Pi 5 — 4 GB compressed swap in RAM (zstd).
# Spares the NVMe from swap writes; priority 100 beats any disk swap.
[zram0]
zram-size = 4096
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
else
    echo "[=] $ZRAM_CONF already present"
fi

# --- 3. Activate zram now (no reboot) -----------------------------------------
# NOTE: systemd-zram-setup@zram0 is startable but NOT enableable (its template
# unit ships without [Install]); at boot the zram-generator activates the swap
# from the conf automatically. daemon-reload so the running systemd sees the
# freshly installed generator + conf.
systemctl daemon-reload
if ! swapon --show=NAME --noheadings 2>/dev/null | grep -q '^/dev/zram0$'; then
    echo "[+] Activating zram swap (systemd-zram-setup@zram0) ..."
    systemctl start systemd-zram-setup@zram0.service
else
    echo "[=] /dev/zram0 already active"
fi

# --- 4. avahi mDNS -------------------------------------------------------------
echo "[+] Enabling + starting avahi-daemon (announces omarchy-pi5.local) ..."
systemctl enable --now avahi-daemon.service

# --- 5. nsswitch.conf: resolve other .local hosts ------------------------------
if grep -q '^hosts:' /etc/nsswitch.conf && ! grep -q '^hosts:.*mdns' /etc/nsswitch.conf; then
    sed -i -E '/^hosts:/ s/(resolve|dns)/mdns4_minimal [NOTFOUND=return] \1/' /etc/nsswitch.conf
    echo "[+] nsswitch.conf: mdns4_minimal wired in"
else
    echo "[=] nsswitch.conf already has mDNS"
fi

# --- Verify --------------------------------------------------------------------
echo ""
echo "[*] Verification:"
if swapon --show=NAME,SIZE --noheadings 2>/dev/null | grep -q '^/dev/zram0'; then
    echo "    PASS: zram swap active: $(swapon --show=NAME,SIZE --noheadings | grep '^/dev/zram0')"
else
    echo "    FAIL: /dev/zram0 not active — check journalctl -u systemd-zram-setup@zram0"
fi
if systemctl is-active --quiet avahi-daemon.service; then
    echo "    PASS: avahi-daemon active — this box is now http://omarchy-pi5.local"
else
    echo "    FAIL: avahi-daemon not running — check journalctl -u avahi-daemon"
fi

echo ""
echo "[*] Done. Swap + mDNS survive reboot (generator + enabled unit)."
echo "[*] From other machines: ssh omarchy@omarchy-pi5.local"
