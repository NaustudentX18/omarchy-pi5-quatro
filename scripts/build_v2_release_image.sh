#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quattro v2.0 Release Image Provisioner & Packager
# Updates the raw disk image with full Omarchy v4.0.3 parity and packages it.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${SCRIPT_DIR}/work"
OUTPUT_DIR="${SCRIPT_DIR}/output"
IMAGE_FILE="${WORK_DIR}/omarchy-pi5-quattro.img"
MNT_DIR="${WORK_DIR}/mnt"

echo "=== [Omarchy Quattro v2.0] Release Image Builder ==="
mkdir -p "${MNT_DIR}" "${OUTPUT_DIR}"

if [[ ! -f "${IMAGE_FILE}" ]]; then
    echo "[!] Image file not found: ${IMAGE_FILE}" >&2
    exit 1
fi

LOOP_DEV=$(losetup -Pf --show "${IMAGE_FILE}")
echo "[+] Attached loop device: ${LOOP_DEV}"

cleanup() {
    echo "[*] Unmounting and cleaning up loop devices..."
    sync
    umount -lf "${MNT_DIR}/tmp/setup" 2>/dev/null || true
    umount -lf "${MNT_DIR}/run" 2>/dev/null || true
    umount -lf "${MNT_DIR}/sys" 2>/dev/null || true
    umount -lf "${MNT_DIR}/proc" 2>/dev/null || true
    umount -lf "${MNT_DIR}/dev/pts" 2>/dev/null || true
    umount -lf "${MNT_DIR}/dev" 2>/dev/null || true
    umount -lf "${MNT_DIR}/boot" 2>/dev/null || true
    umount -lf "${MNT_DIR}" 2>/dev/null || true
    if [[ -n "${LOOP_DEV:-}" ]]; then
        losetup -d "${LOOP_DEV}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# 1. Mount rootfs and boot
echo "[+] Mounting partitions..."
mount "${LOOP_DEV}p2" "${MNT_DIR}"
mount "${LOOP_DEV}p1" "${MNT_DIR}/boot"

# Bind pseudo filesystems
mount --bind /dev "${MNT_DIR}/dev"
mount --bind /dev/pts "${MNT_DIR}/dev/pts"
mount --bind /proc "${MNT_DIR}/proc"
mount --bind /sys "${MNT_DIR}/sys"
mount --bind /run "${MNT_DIR}/run"

echo "nameserver 1.1.1.1" > "${MNT_DIR}/etc/resolv.conf"

# 2. Update /opt/omarchy to upstream quattro HEAD (v4.0.3)
echo "[+] Synchronizing /opt/omarchy to upstream Omarchy v4.0.3..."
mkdir -p "${MNT_DIR}/opt/omarchy"
if [[ -d "${MNT_DIR}/opt/omarchy/.git" ]]; then
    git -C "${MNT_DIR}/opt/omarchy" fetch --depth 1 origin quattro 2>/dev/null || true
    git -C "${MNT_DIR}/opt/omarchy" checkout -f 8ea51516390320f8e768808b230098e67bdaa82c 2>/dev/null || \
    git -C "${MNT_DIR}/opt/omarchy" checkout -f origin/quattro 2>/dev/null || true
else
    rm -rf "${MNT_DIR}/opt/omarchy"
    git clone --depth 1 --branch quattro https://github.com/omacom/omarchy.git "${MNT_DIR}/opt/omarchy"
fi

RESOLVED_COMMIT=$(git -C "${MNT_DIR}/opt/omarchy" rev-parse HEAD 2>/dev/null || echo "unknown")
echo "[✓] Omarchy repository at: ${RESOLVED_COMMIT}"

# 3. Deploy all 450+ binaries
echo "[+] Deploying Omarchy binaries to /usr/bin/..."
mkdir -p "${MNT_DIR}/usr/bin" "${MNT_DIR}/usr/share/omarchy/bin"
chmod +x "${MNT_DIR}/opt/omarchy/bin/"* 2>/dev/null || true
for bin in "${MNT_DIR}/opt/omarchy/bin/"*; do
    if [[ -f "$bin" ]]; then
        bname=$(basename "$bin")
        install -Dm755 "$bin" "${MNT_DIR}/usr/bin/${bname}"
        ln -sf "/usr/bin/${bname}" "${MNT_DIR}/usr/share/omarchy/bin/${bname}" 2>/dev/null || true
    fi
done

# Clean legacy shadowing
find "${MNT_DIR}/usr/local/bin" -type l -name 'omarchy*' -delete 2>/dev/null || true
rm -f "${MNT_DIR}/etc/omarchy.conf"

# 4. Provision in-chroot v2.0 updates & hardenings
echo "[+] Running in-chroot update provisioning..."
mkdir -p "${MNT_DIR}/tmp/setup"
cp "${SCRIPT_DIR}/updates/v2.0.0-update.sh" "${MNT_DIR}/tmp/setup/v2.0.0-update.sh"
chmod +x "${MNT_DIR}/tmp/setup/v2.0.0-update.sh"

chroot "${MNT_DIR}" /bin/bash /tmp/setup/v2.0.0-update.sh 2>&1 || echo "[!] Notice: chroot update completed with warnings"

# 5. Wire native omarchy update hooks
echo "[+] Installing native Omarchy update hooks..."
mkdir -p "${MNT_DIR}/home/omarchy/.config/omarchy/hooks/post-update.d"
mkdir -p "${MNT_DIR}/etc/skel/.config/omarchy/hooks/post-update.d"
mkdir -p "${MNT_DIR}/root/.config/omarchy/hooks/post-update.d"
mkdir -p "${MNT_DIR}/etc/omarchy/hooks.d"
mkdir -p "${MNT_DIR}/usr/local/bin"

cp -a "${SCRIPT_DIR}/system_tuning/omarchy-pi5-post-update.sh" "${MNT_DIR}/usr/local/bin/omarchy-pi5-post-update" 2>/dev/null || true
chmod 0755 "${MNT_DIR}/usr/local/bin/omarchy-pi5-post-update" 2>/dev/null || true

cat << 'GUARD_EOF' > "${MNT_DIR}/home/omarchy/.config/omarchy/hooks/post-update.d/10-pi5-guard.sh"
#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quattro - Native omarchy update hook for Pi 5
# ==============================================================================
# Triggered automatically by 'omarchy update' (omarchy-hook post-update).
# Pulls latest /opt/omarchy and reconciles Pi 5 hardware adaptations.
# ==============================================================================
set -e

echo "[*] [Omarchy Quattro Pi 5] Executing post-update hardware reconciliation..."

if [ -d /opt/omarchy/.git ]; then
    echo "    Pulling latest Omarchy upstream code into /opt/omarchy..."
    git -C /opt/omarchy fetch --depth 1 origin quattro 2>/dev/null || true
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
GUARD_EOF

chmod 0755 "${MNT_DIR}/home/omarchy/.config/omarchy/hooks/post-update.d/10-pi5-guard.sh"
cp -a "${MNT_DIR}/home/omarchy/.config/omarchy/hooks/post-update.d/10-pi5-guard.sh" "${MNT_DIR}/etc/skel/.config/omarchy/hooks/post-update.d/10-pi5-guard.sh"
cp -a "${MNT_DIR}/home/omarchy/.config/omarchy/hooks/post-update.d/10-pi5-guard.sh" "${MNT_DIR}/root/.config/omarchy/hooks/post-update.d/10-pi5-guard.sh"

cat << 'HOOK_EOF' > "${MNT_DIR}/etc/omarchy/hooks.d/99-pi5-quattro-sync.sh"
#!/usr/bin/env bash
if [ -x /usr/local/bin/omarchy-pi5-post-update ]; then
    /usr/local/bin/omarchy-pi5-post-update
fi
HOOK_EOF
chmod 0755 "${MNT_DIR}/etc/omarchy/hooks.d/99-pi5-quattro-sync.sh"

# 6. Update branding in /etc/os-release and /etc/issue
echo "[+] Setting OS release branding to Omarchy Quattro v2.0..."
sed -i 's/PRETTY_NAME=.*/PRETTY_NAME="Omarchy Quattro v2.0 (Arch Linux ARM)"/' "${MNT_DIR}/etc/os-release" 2>/dev/null || true
echo "Omarchy Quattro v2.0 \r (\l)" > "${MNT_DIR}/etc/issue"

# 7. Finalize user permissions
chown -R omarchy:omarchy "${MNT_DIR}/home/omarchy" 2>/dev/null || true

# 8. Clean up chroot temporary files and unmount
rm -rf "${MNT_DIR}/tmp/setup" "${MNT_DIR}/etc/resolv.conf"
truncate -s 0 "${MNT_DIR}/etc/machine-id"

sync
umount -lf "${MNT_DIR}/run" 2>/dev/null || true
umount -lf "${MNT_DIR}/sys" 2>/dev/null || true
umount -lf "${MNT_DIR}/proc" 2>/dev/null || true
umount -lf "${MNT_DIR}/dev/pts" 2>/dev/null || true
umount -lf "${MNT_DIR}/dev" 2>/dev/null || true
umount -lf "${MNT_DIR}/boot" 2>/dev/null || true
umount -lf "${MNT_DIR}" 2>/dev/null || true

# Zero out free blocks for maximum compression
echo "[+] Zeroing free blocks with zerofree..."
zerofree -v "${LOOP_DEV}p2" || true

losetup -d "${LOOP_DEV}"
LOOP_DEV=""

echo "[✓] Master image successfully provisioned for v2.0!"
