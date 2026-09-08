#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quatro - Raspberry Pi 5 Master Image Builder
# Orchestrator for pristine Arch Linux ARM aarch64 image generation
# Target Device: Raspberry Pi 5 (8GB RAM, NVMe PCIe Gen3, Argon ONE / NEO 5)
# ==============================================================================

set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
log_step()    { echo -e "\n${BOLD}${BLUE}=== Step $* ===${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/work"
CACHE_DIR="${SCRIPT_DIR}/cache"
OUTPUT_DIR="${SCRIPT_DIR}/output"
MNT_DIR="${WORK_DIR}/mnt"

IMAGE_BASE="omarchy-pi5-quatro"
IMAGE_FILE="${WORK_DIR}/${IMAGE_BASE}.img"
IMAGE_SIZE="12G"
BOOT_SIZE_MIB=512

# Deterministic MBR Disk Signature (0x1974beef)
# Produces PARTUUIDs: 1974beef-01 (boot) and 1974beef-02 (root)
DISK_SIGNATURE_HEX="1974beef"
BOOT_PARTUUID="${DISK_SIGNATURE_HEX}-01"
ROOT_PARTUUID="${DISK_SIGNATURE_HEX}-02"

# Arch Linux ARM pristine base rootfs URLs
ARCH_ARM_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz"
ARCH_ARM_FALLBACK="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
ROOTFS_TARBALL="${CACHE_DIR}/ArchLinuxARM-rpi-aarch64-latest.tar.gz"

# Options
SKIP_COMPRESS=0
FAST_COMPRESS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-compress)
            SKIP_COMPRESS=1
            shift
            ;;
        --fast-compress)
            FAST_COMPRESS=1
            shift
            ;;
        --help|-h)
            echo "Usage: sudo $0 [OPTIONS]"
            echo "Options:"
            echo "  --skip-compress    Skip .zst and .xz compression (faster local test)"
            echo "  --fast-compress    Use fast compression levels for quick testing"
            echo "  --help, -h         Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

LOOP_DEV=""

# Cleanup handler on exit or error
cleanup() {
    local exit_code=$?
    log_info "Running cleanup trap (Exit code: ${exit_code})..."

    # Unmount pseudo filesystems inside chroot if mounted
    if [ -d "${MNT_DIR}" ]; then
        for mp in "${MNT_DIR}/tmp/setup" "${MNT_DIR}/run" "${MNT_DIR}/sys" "${MNT_DIR}/proc" "${MNT_DIR}/dev/pts" "${MNT_DIR}/dev" "${MNT_DIR}/boot"; do
            if mountpoint -q "$mp" 2>/dev/null; then
                log_info "Unmounting $mp..."
                umount -lf "$mp" || true
            fi
        done

        if mountpoint -q "${MNT_DIR}" 2>/dev/null; then
            log_info "Unmounting root mount: ${MNT_DIR}..."
            umount -lf "${MNT_DIR}" || true
        fi
    fi

    # Detach loop device if attached
    if [ -n "${LOOP_DEV}" ] && losetup -a | grep -q "${LOOP_DEV}"; then
        log_info "Detaching loopback device ${LOOP_DEV}..."
        losetup -d "${LOOP_DEV}" || true
    fi

    if [ ${exit_code} -eq 0 ]; then
        log_success "Build completed cleanly."
    else
        log_error "Build process aborted or failed with exit code ${exit_code}."
    fi
}

trap cleanup EXIT INT TERM

# ==============================================================================
# Step 1: Tool check & workspace initialization
# ==============================================================================
log_step "1: Tool Check & Workspace Initialization"

if [ "$(id -u)" -ne 0 ]; then
    log_error "This script requires root privileges to configure loopback devices and partitions."
    log_error "Please run with: sudo $0"
    exit 1
fi

REQUIRED_TOOLS=(parted losetup mkfs.vfat mkfs.ext4 tar curl sha256sum)
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    log_error "Missing required tools: ${MISSING_TOOLS[*]}"
    log_error "Please install them via apt or pacman before proceeding."
    exit 1
fi

# Check optional compression and zeroing tools
if ! command -v zstd &>/dev/null && [ $SKIP_COMPRESS -eq 0 ]; then
    log_warn "zstd not found on host. Installing or skipping zstd compression."
fi
if ! command -v xz &>/dev/null && [ $SKIP_COMPRESS -eq 0 ]; then
    log_warn "xz not found on host. Installing or skipping xz compression."
fi
if ! command -v zerofree &>/dev/null; then
    log_warn "zerofree not found on host; will use standard zero-fill fallback for clean blocks."
fi

# Multi-arch support check
HOST_ARCH="$(uname -m)"
if [ "$HOST_ARCH" != "aarch64" ]; then
    log_info "Host architecture is ${HOST_ARCH}. Checking for QEMU aarch64 emulation..."
    if ! command -v qemu-aarch64-static &>/dev/null && [ ! -f /usr/bin/qemu-aarch64-static ]; then
        log_error "Cross-building on ${HOST_ARCH} requires qemu-user-static (qemu-aarch64-static)."
        exit 1
    fi
fi

# Prepare workspace directories
mkdir -p "${WORK_DIR}" "${CACHE_DIR}" "${OUTPUT_DIR}" "${MNT_DIR}"
log_success "Workspace initialized at ${WORK_DIR}"

# ==============================================================================
# Step 2: Download pristine Arch Linux ARM aarch64 base rootfs
# ==============================================================================
log_step "2: Download Pristine Arch Linux ARM Base Rootfs"

if [ -f "${ROOTFS_TARBALL}" ] && [ -s "${ROOTFS_TARBALL}" ]; then
    log_info "Cached base rootfs found at ${ROOTFS_TARBALL} ($(du -h "${ROOTFS_TARBALL}" | awk '{print $1}'))"
else
    log_info "Downloading pristine Arch Linux ARM rootfs from ${ARCH_ARM_URL}..."
    if ! curl -L --fail --retry 3 --retry-delay 5 -C - -o "${ROOTFS_TARBALL}" "${ARCH_ARM_URL}"; then
        log_warn "Primary URL failed. Attempting fallback URL: ${ARCH_ARM_FALLBACK}..."
        curl -L --fail --retry 3 --retry-delay 5 -C - -o "${ROOTFS_TARBALL}" "${ARCH_ARM_FALLBACK}"
    fi
    log_success "Rootfs download complete: $(du -h "${ROOTFS_TARBALL}" | awk '{print $1}')"
fi

# Validate tarball integrity
if ! gzip -t "${ROOTFS_TARBALL}" 2>/dev/null; then
    log_error "Downloaded rootfs tarball is corrupted. Removing and aborting."
    rm -f "${ROOTFS_TARBALL}"
    exit 1
fi
log_success "Rootfs tarball integrity verified."

# ==============================================================================
# Step 3: Disk image creation (12GB sparse) & partitioning
# ==============================================================================
log_step "3: Disk Image Creation (12GB Sparse) & Partitioning"

log_info "Creating 12GB sparse image file: ${IMAGE_FILE}..."
rm -f "${IMAGE_FILE}"
truncate -s "${IMAGE_SIZE}" "${IMAGE_FILE}"

log_info "Partitioning disk image (MBR/msdos layout)..."
# Partition 1: FAT32 512MB (Boot/Firmware), offset 4MiB to 516MiB
# Partition 2: Linux ext4 (Rootfs), 516MiB to 100%
parted -s "${IMAGE_FILE}" mklabel msdos
parted -s "${IMAGE_FILE}" mkpart primary fat32 4MiB 516MiB
parted -s "${IMAGE_FILE}" set 1 boot on
parted -s "${IMAGE_FILE}" mkpart primary ext4 516MiB 100%

# Write deterministic 32-bit MBR Disk Identifier — value 0x1974beef at byte offset 440.
# MBR signatures are stored LITTLE-ENDIAN on disk: to make the u32 value read back as
# 0x1974beef (matching cmdline.txt / fstab PARTUUIDs 1974beef-01/02), the bytes must be
# written reversed: ef be 74 19. (v1.0.0 wrote 19 74 be ef -> kernel saw efbe7419-xx,
# root=PARTUUID=1974beef-02 never resolved, first boot hung at initramfs: black screen.)
printf '\xef\xbe\x74\x19' | dd of="${IMAGE_FILE}" bs=1 seek=440 count=4 conv=notrunc status=none
log_success "Disk partitioned with PARTUUID: boot=${BOOT_PARTUUID}, root=${ROOT_PARTUUID}"

# ==============================================================================
# Step 4: Formatting & loopback mounting
# ==============================================================================
log_step "4: Formatting & Loopback Mounting"

LOOP_DEV=$(losetup -Pf --show "${IMAGE_FILE}")
log_info "Attached ${IMAGE_FILE} to ${LOOP_DEV}"

# Wait for kernel partition notifications
udevadm settle || sleep 1

BOOT_PART="${LOOP_DEV}p1"
ROOT_PART="${LOOP_DEV}p2"

if [ ! -b "${BOOT_PART}" ] || [ ! -b "${ROOT_PART}" ]; then
    log_error "Partition devices ${BOOT_PART} or ${ROOT_PART} not found!"
    exit 1
fi

log_info "Formatting boot partition (${BOOT_PART}) as FAT32..."
mkfs.vfat -F 32 -n "BOOT_OMP" "${BOOT_PART}"

log_info "Formatting root partition (${ROOT_PART}) as ext4..."
mkfs.ext4 -F -L "ROOT_OMP" -O ^metadata_csum_seed "${ROOT_PART}"

log_info "Mounting filesystems..."
mount "${ROOT_PART}" "${MNT_DIR}"
mkdir -p "${MNT_DIR}/boot"
mount "${BOOT_PART}" "${MNT_DIR}/boot"

log_success "Filesystems formatted and mounted at ${MNT_DIR}"

# ==============================================================================
# Step 5: Rootfs extraction with --numeric-owner
# ==============================================================================
log_step "5: Rootfs Extraction with --numeric-owner"

log_info "Extracting Arch Linux ARM rootfs (preserving numeric UIDs/GIDs)..."
tar -xpf "${ROOTFS_TARBALL}" -C "${MNT_DIR}" --numeric-owner
sync
log_success "Rootfs extracted successfully."

# ==============================================================================
# Step 6: Inject Pi 5 bootloader files (config.txt, cmdline.txt, fstab)
# ==============================================================================
log_step "6: Inject Pi 5 Bootloader Files & Hardware Config"

log_info "Injecting Raspberry Pi 5 config.txt..."
CONFIG_TXT="${WORK_DIR}/omarchy-config.txt"
cat << 'EOF' > "${CONFIG_TXT}"
# ==============================================================================
# Omarchy Quatro - Raspberry Pi 5 Bootloader Configuration
# Optimized for Broadcom BCM2712 Cortex-A76 & PCIe Gen 3 NVMe SSDs
# ==============================================================================

[all]
arm_64bit=1
arm_boost=1

# Display & Graphics (KMS DRM Driver for Wayland/Hyprland)
dtoverlay=vc4-kms-v3d
max_framebuffers=2
disable_overscan=1

# Hardware Buses (I2C enabled for Argon ONE / NEO 5 case fans)
dtparam=i2c_arm=on
dtparam=i2c=on
dtparam=spi=on
enable_uart=1

# PCIe Gen 3 Enablement for High-Speed NVMe SSDs (Crucial, Samsung, WD)
# Maximizes throughput to ~850-900 MB/s sequential transfer rates
dtparam=pciex1
dtparam=pciex1_gen=3

# Camera and Display auto-detection
camera_auto_detect=1
display_auto_detect=1

[pi5]
# Raspberry Pi 5 16k Kernel & Initramfs
kernel=kernel8.img
initramfs initramfs-linux.img followkernel
EOF
cp "${CONFIG_TXT}" "${MNT_DIR}/boot/config.txt"


log_info "Injecting cmdline.txt with PARTUUID=${ROOT_PARTUUID}..."
echo "root=PARTUUID=${ROOT_PARTUUID} rw rootwait console=serial0,115200 console=tty1 fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory quiet" > "${MNT_DIR}/boot/cmdline.txt"

if [ -f "${SCRIPT_DIR}/config/fstab" ]; then
    log_info "Injecting /etc/fstab from config/fstab template..."
    sed -e "s/@BOOT_PARTUUID@/${BOOT_PARTUUID}/g" \
        -e "s/@ROOT_PARTUUID@/${ROOT_PARTUUID}/g" \
        "${SCRIPT_DIR}/config/fstab" > "${MNT_DIR}/etc/fstab"
else
    log_info "Generating /etc/fstab with PARTUUIDs..."
    cat << EOF > "${MNT_DIR}/etc/fstab"
# /etc/fstab: static file system information
# <file system>             <mount point>  <type>  <options>                   <dump> <pass>
PARTUUID=${BOOT_PARTUUID}  /boot          vfat    defaults,flush,noatime      0      2
PARTUUID=${ROOT_PARTUUID}  /              ext4    defaults,noatime,commit=60  0      1
tmpfs                       /tmp           tmpfs   nodev,nosuid                0      0
EOF
fi

log_success "Bootloader configuration and /etc/fstab successfully injected."

# ==============================================================================
# Step 7: Chroot execution
# ==============================================================================
log_step "7: Chroot Execution & System Customization"

# Bind mount pseudo filesystems
mount --bind /dev "${MNT_DIR}/dev"
mount --bind /dev/pts "${MNT_DIR}/dev/pts"
mount -t proc proc "${MNT_DIR}/proc"
mount -t sysfs sys "${MNT_DIR}/sys"
mount -t tmpfs tmpfs "${MNT_DIR}/run"

# Configure DNS for network access in chroot
rm -f "${MNT_DIR}/etc/resolv.conf"
cp -L /etc/resolv.conf "${MNT_DIR}/etc/resolv.conf"

# Copy QEMU user binary if cross-compiling
if [ "$HOST_ARCH" != "aarch64" ]; then
    log_info "Copying qemu-aarch64-static into target rootfs..."
    cp "$(command -v qemu-aarch64-static || echo /usr/bin/qemu-aarch64-static)" "${MNT_DIR}/usr/bin/qemu-aarch64-static"
fi

# Prepare payload directory inside chroot
CHROOT_SETUP_DIR="${MNT_DIR}/tmp/setup"
mkdir -p "${CHROOT_SETUP_DIR}"

# Copy package list, helper scripts, and swarm module directories
if [ -f "${SCRIPT_DIR}/desktop/packages.list" ]; then
    cp "${SCRIPT_DIR}/desktop/packages.list" "${CHROOT_SETUP_DIR}/packages.list"
fi

for mod in scripts argon resize system_tuning config boot desktop; do
    if [ -d "${SCRIPT_DIR}/${mod}" ]; then
        cp -r "${SCRIPT_DIR}/${mod}" "${CHROOT_SETUP_DIR}/"
    fi
done

# Create in-chroot provisioning script
cat << 'EOF_CHROOT' > "${CHROOT_SETUP_DIR}/provision.sh"
#!/usr/bin/env bash
set -euo pipefail

# Logging helpers — the outer build script's log_* functions do NOT exist
# inside this chroot script (learned 2026-09-08: bare log_success here made
# the build die with exit 127 AFTER a fully successful kernel install).
log_error()   { echo "[ERROR] $*" >&2; }
log_success() { echo "[SUCCESS] $*"; }
log_info()    { echo "[INFO] $*"; }
log_warn()    { echo "[WARN] $*"; }

echo "======================================================================"
echo "[+] Starting In-Chroot Provisioning for Omarchy Quatro Pi 5..."
echo "======================================================================"

# 1. Pacman Key Initialization
echo "[+] Initializing Pacman keyring..."
pacman-key --init
pacman-key --populate archlinuxarm

# Configure pacman parallel downloads & mirrorlist
# pacman 7's Landlock download sandbox cannot work inside a chroot — disable it
grep -q '^DisableSandbox' /etc/pacman.conf || sed -i 's/^\[options\]/[options]\nDisableSandbox/' /etc/pacman.conf

sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

# 2. System update & Kernel installation
echo "[+] Updating system packages..."
pacman -Syu --noconfirm

echo "[+] Installing Raspberry Pi 5 16k Kernel & Bootloader..."
# linux-rpi-16k conflicts with the base generic kernel — remove it first.
# Only removed when actually installed; genuine pacman errors abort the build
# (set -e) instead of being masked by `|| true`.
if pacman -Q linux-aarch64 &>/dev/null; then
    pacman -R --noconfirm linux-aarch64
fi
if pacman -Q uboot-raspberrypi &>/dev/null; then
    pacman -R --noconfirm uboot-raspberrypi
fi
pacman -S --noconfirm --needed \
    linux-rpi-16k \
    linux-rpi-16k-headers \
    raspberrypi-bootloader \
    firmware-raspberrypi

# Hard check: kernel must actually be installed (§2.3 — never silently skip)
if [ ! -s /boot/kernel8.img ]; then
    log_error "/boot/kernel8.img missing after linux-rpi-16k install — kernel install failed"
    exit 1
fi
KERNEL_SIZE=$(stat -c %s /boot/kernel8.img)
if [ "$KERNEL_SIZE" -lt 1048576 ]; then
    log_error "/boot/kernel8.img is only ${KERNEL_SIZE} bytes (< 1 MB) — install likely failed"
    exit 1
fi
log_success "linux-rpi-16k kernel installed (kernel8.img: ${KERNEL_SIZE} bytes)"

# Ensure Pi 5 Device Tree Blob (bcm2712-rpi-5-b.dtb) is in /boot
if [ ! -f /boot/bcm2712-rpi-5-b.dtb ]; then
    echo "[+] Locating bcm2712-rpi-5-b.dtb DTB..."
    DTB_SRC=$(find /boot /usr/lib/modules -name "bcm2712-rpi-5-b.dtb" 2>/dev/null | head -n 1 || true)
    if [ -n "$DTB_SRC" ]; then
        cp -f "$DTB_SRC" /boot/bcm2712-rpi-5-b.dtb
        echo "[+] Placed DTB at /boot/bcm2712-rpi-5-b.dtb"
    fi
fi

# 3. Package installation from desktop/packages.list
if [ -f /tmp/setup/packages.list ]; then
    echo "[+] Reading packages from /tmp/setup/packages.list..."
    # Filter comments and empty lines
    PKGS_TO_INSTALL=()
    while IFS= read -r line || [ -n "$line" ]; do
        pkg=$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [ -n "$pkg" ]; then
            PKGS_TO_INSTALL+=("$pkg")
        fi
    done < /tmp/setup/packages.list

    if [ ${#PKGS_TO_INSTALL[@]} -gt 0 ]; then
        echo "[+] Installing ${#PKGS_TO_INSTALL[@]} desktop packages..."
        pacman -S --noconfirm --needed "${PKGS_TO_INSTALL[@]}" || {
            echo "[!] Batch installation had missing packages. Attempting individual install..."
            for p in "${PKGS_TO_INSTALL[@]}"; do
                pacman -S --noconfirm --needed "$p" || echo "[!] Notice: Skipped unavailable package: $p"
            done
        }
    fi
fi

# 4. User creation & Sudo configuration
echo "[+] Creating default 'omarchy' user..."
if ! id -u omarchy &>/dev/null; then
    useradd -m -s /bin/bash -G wheel,video,audio,input,storage,network,power omarchy
    echo "omarchy:omarchy" | chpasswd
    echo "root:omarchy" | chpasswd
fi

# Allow wheel group passwordless sudo
mkdir -p /etc/sudoers.d
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/010_wheel_nopasswd
chmod 0440 /etc/sudoers.d/010_wheel_nopasswd

# 5. Omarchy Quatro Clone & Desktop Integration
echo "[+] Setting up Omarchy Quatro environment..."
if [ -f /tmp/setup/desktop/clone_omarchy_repo.sh ]; then
    echo "[+] Executing desktop/clone_omarchy_repo.sh..."
    bash /tmp/setup/desktop/clone_omarchy_repo.sh / || true
else
    echo "[!] Fallback: Creating local Omarchy structure..."
    mkdir -p /opt/omarchy/bin /home/omarchy/.config
fi

# Setup SDDM Wayland session configuration
mkdir -p /etc/sddm.conf.d
cat << 'SDDM_EOF' > /etc/sddm.conf.d/autologin.conf
[General]
DisplayServer=wayland

[Theme]
Current=omarchy

[Wayland]
EnableHiDPI=true

[Autologin]
User=omarchy
Session=sway.desktop
SDDM_EOF

# 5b. Sway session config + wallpaper for the omarchy user (out-of-box desktop)
if id omarchy >/dev/null 2>&1; then
    mkdir -p /home/omarchy/.config/sway /home/omarchy/.local/share/omarchy
    cat << 'SWAYCFG_EOF' > /home/omarchy/.config/sway/config
# Omarchy Quatro - sway session
set $mod Mod4
set $term foot
set $menu fuzzel
output * bg /home/omarchy/.local/share/omarchy/wallpaper.jpg fill
bindsym $mod+Return exec $term
bindsym $mod+d exec $menu
bindsym $mod+Shift+q kill
bindsym $mod+Shift+e exec swaynag -t warning -m "Exit sway?" -B "Exit" "swaymsg exit"
exec waybar
exec mako
exec foot --server
SWAYCFG_EOF
    chown omarchy:omarchy /home/omarchy/.config/sway/config
    # Wallpaper is vendored in the repo (desktop/wallpaper.jpg) and staged into
    # the chroot at /tmp/setup/desktop/ — no build-time network dependency.
    if install -D -m 644 -o omarchy -g omarchy \
        /tmp/setup/desktop/wallpaper.jpg /home/omarchy/.local/share/omarchy/wallpaper.jpg 2>/dev/null; then
        echo "[+] wallpaper installed from vendored asset"
    else
        curl -fsSL --max-time 60 -o /home/omarchy/.local/share/omarchy/wallpaper.jpg \
            "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/tokyo-night/backgrounds/5-oma-cityscape.jpg" \
            && chown omarchy:omarchy /home/omarchy/.local/share/omarchy/wallpaper.jpg \
            || echo "[!] wallpaper unavailable (non-fatal)"
    fi
fi

# Set default hostname
echo "omarchy-pi5" > /etc/hostname
cat << 'HOSTS_EOF' > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   omarchy-pi5.localdomain omarchy-pi5
HOSTS_EOF

# 6. Argon ONE / NEO 5 Fan & Power Daemon Integration
echo "[+] Integrating Argon ONE / NEO 5 daemon..."
if [ -f /tmp/setup/argon/argononed.py ]; then
    cp /tmp/setup/argon/argononed.py /usr/local/bin/argononed.py
    chmod +x /usr/local/bin/argononed.py
elif [ -f /tmp/setup/scripts/argononed.py ]; then
    cp /tmp/setup/scripts/argononed.py /usr/local/bin/argononed.py
    chmod +x /usr/local/bin/argononed.py
fi

if [ -f /tmp/setup/argon/argononed.service ]; then
    cp /tmp/setup/argon/argononed.service /etc/systemd/system/argononed.service
elif [ -f /tmp/setup/scripts/argononed.service ]; then
    cp /tmp/setup/scripts/argononed.service /etc/systemd/system/argononed.service
fi

# 7. First-Boot NVMe Auto-Resize Service Integration
echo "[+] Integrating first-boot NVMe auto-resize service..."
if [ -f /tmp/setup/resize/rpi-resizerootfs.sh ]; then
    cp /tmp/setup/resize/rpi-resizerootfs.sh /usr/local/bin/rpi-resizerootfs.sh
    chmod +x /usr/local/bin/rpi-resizerootfs.sh
elif [ -f /tmp/setup/scripts/rpi-resizerootfs.sh ]; then
    cp /tmp/setup/scripts/rpi-resizerootfs.sh /usr/local/bin/rpi-resizerootfs.sh
    chmod +x /usr/local/bin/rpi-resizerootfs.sh
fi

if [ -f /tmp/setup/resize/rpi-resizerootfs.service ]; then
    cp /tmp/setup/resize/rpi-resizerootfs.service /etc/systemd/system/rpi-resizerootfs.service
elif [ -f /tmp/setup/scripts/rpi-resizerootfs.service ]; then
    cp /tmp/setup/scripts/rpi-resizerootfs.service /etc/systemd/system/rpi-resizerootfs.service
fi

# 8. 8GB RAM ZRAM & sysctl Tuning
echo "[+] Configuring ZRAM swap and kernel sysctl tuning..."
if [ -f /tmp/setup/system_tuning/zram-generator.conf ]; then
    mkdir -p /etc/systemd
    cp /tmp/setup/system_tuning/zram-generator.conf /etc/systemd/zram-generator.conf
elif [ -f /tmp/setup/scripts/zram-generator.conf ]; then
    mkdir -p /etc/systemd
    cp /tmp/setup/scripts/zram-generator.conf /etc/systemd/zram-generator.conf
fi

if [ -f /tmp/setup/system_tuning/99-pi5-sysctl.conf ]; then
    mkdir -p /etc/sysctl.d
    cp /tmp/setup/system_tuning/99-pi5-sysctl.conf /etc/sysctl.d/99-pi5-sysctl.conf
elif [ -f /tmp/setup/scripts/99-pi5-tuning.conf ]; then
    mkdir -p /etc/sysctl.d
    cp /tmp/setup/scripts/99-pi5-tuning.conf /etc/sysctl.d/99-pi5-tuning.conf
fi

# 8b. I2C & smbus2 for Argon daemon (python-smbus2 is AUR-only; install via pip)
echo "[+] Installing smbus2 for argononed..."
pacman -S --noconfirm --needed python-pip || echo "[!] python-pip unavailable"
pip install --break-system-packages --quiet smbus2 || echo "[!] smbus2 install failed - fan daemon will run without I2C"
mkdir -p /etc/modules-load.d
echo "i2c-dev" > /etc/modules-load.d/i2c-dev.conf

# 9. Service Enablement
echo "[+] Ensuring systemd services are enabled..."
systemctl enable sddm.service || true
systemctl enable NetworkManager.service || true
systemctl enable sshd.service || true
systemctl enable bluetooth.service || true
systemctl enable argononed.service || true
systemctl enable rpi-resizerootfs.service || true
systemctl enable systemd-zram-setup@zram0.service || true

# Set permissions for omarchy user home
chown -R omarchy:omarchy /home/omarchy

# Clean package cache inside chroot
pacman -Scc --noconfirm || true

echo "[+] In-Chroot Provisioning Complete!"
EOF_CHROOT

chmod +x "${CHROOT_SETUP_DIR}/provision.sh"

log_info "Executing chroot provisioning..."
chroot "${MNT_DIR}" /bin/bash /tmp/setup/provision.sh

# Cleanup setup files inside chroot
rm -rf "${MNT_DIR}/tmp/setup"
if [ -f "${MNT_DIR}/usr/bin/qemu-aarch64-static" ] && [ "$HOST_ARCH" != "aarch64" ]; then
    rm -f "${MNT_DIR}/usr/bin/qemu-aarch64-static"
fi

log_success "Chroot execution and customization completed."

# ==============================================================================
# Re-inject config.txt: linux-rpi-16k pkg ships its own /boot/config.txt that
# overwrites ours during chroot install — ours must win (PCIe Gen3, I2C, KMS).
if [ -f "${CONFIG_TXT}" ]; then
    cp "${CONFIG_TXT}" "${MNT_DIR}/boot/config.txt"
    log_info "config.txt re-injected post-chroot (package overwrite defence)."
fi

# Hard guard: refuse to continue if kernel install silently failed.
[[ -s "${MNT_DIR}/boot/kernel8.img" ]] || { log_error "kernel8.img missing after install — refusing to continue"; exit 1; }
KERNEL_SIZE=$(stat -c %s "${MNT_DIR}/boot/kernel8.img")
[[ $KERNEL_SIZE -gt 1048576 ]] || { log_error "kernel8.img too small (${KERNEL_SIZE} bytes) — install failed"; exit 1; }
log_success "kernel8.img present (${KERNEL_SIZE} bytes)"

# ==============================================================================
# Step 7b: Post-provision verification — FAIL LOUDLY.
# v1.0.0 shipped a broken MBR signature; v1.0.1 shipped without a working
# desktop (hyprland unresolvable in ALARM repos, autologin.conf not forced to
# DisplayServer=wayland). Neither may ever ship silently again.
# ==============================================================================
log_info "Verifying critical image contents..."
VERIFY_FAILURE=0

# 1. PARTUUID: what blkid resolves for p2 must equal cmdline.txt root=
IMG_ROOT_PARTUUID="$(blkid -s PARTUUID -o value "${LOOP_DEV}p2" 2>/dev/null)"
CMDLINE_ROOT="$(sed -n 's/.*root=\([^ ]*\).*/\1/p' "${MNT_DIR}/boot/cmdline.txt" | head -n1)"
if [ -z "${CMDLINE_ROOT}" ]; then
    log_error "cmdline.txt has no root= parameter"
    VERIFY_FAILURE=1
elif [[ "${CMDLINE_ROOT}" != PARTUUID=* ]]; then
    log_error "cmdline.txt root='${CMDLINE_ROOT}' is not PARTUUID= form; verification requires PARTUUID rooting"
    VERIFY_FAILURE=1
elif [ -z "${IMG_ROOT_PARTUUID}" ] || [ "${IMG_ROOT_PARTUUID}" != "${CMDLINE_ROOT#PARTUUID=}" ]; then
    log_error "PARTUUID mismatch: image p2='${IMG_ROOT_PARTUUID}' cmdline root='${CMDLINE_ROOT}'"
    VERIFY_FAILURE=1
else
    log_success "PARTUUID match: ${IMG_ROOT_PARTUUID}"
fi

# 2. Critical files
CRITICAL_FILES=(
    "${MNT_DIR}/usr/bin/sway"
    "${MNT_DIR}/usr/share/wayland-sessions/sway.desktop"
    "${MNT_DIR}/etc/sddm.conf.d/autologin.conf"
    "${MNT_DIR}/usr/lib/chromium/chromium"
    "${MNT_DIR}/usr/bin/sshd"
    "${MNT_DIR}/boot/kernel8.img"
    "${MNT_DIR}/boot/bcm2712-rpi-5-b.dtb"
    "${MNT_DIR}/boot/start4.elf"
    "${MNT_DIR}/boot/fixup4.dat"
    "${MNT_DIR}/boot/initramfs-linux.img"
    "${MNT_DIR}/boot/config.txt"
)
for f in "${CRITICAL_FILES[@]}"; do
    if [ ! -e "$f" ]; then
        log_error "Missing critical file: $f"
        VERIFY_FAILURE=1
    fi
done

# config.txt must carry the Pi 5 KMS overlay and PCIe Gen3 dtparam after
# re-injection (anchored match: must be a real directive line, not a comment).
grep -q '^dtoverlay=vc4-kms-v3d' "${MNT_DIR}/boot/config.txt" || {
    log_error "config.txt missing vc4-kms-v3d overlay"
    VERIFY_FAILURE=1
}
grep -q 'pciex1_gen=3' "${MNT_DIR}/boot/config.txt" || {
    log_error "config.txt missing pciex1_gen=3"
    VERIFY_FAILURE=1
}

# cmdline.txt must not request plymouth splash (plymouth not installed)
if grep -q "splash" "${MNT_DIR}/boot/cmdline.txt"; then
    log_error "cmdline.txt contains 'splash' but plymouth is not installed"
    VERIFY_FAILURE=1
fi

# 3. Autologin must force the Wayland display server (else SDDM runs X, absent here)
grep -q "DisplayServer=wayland" "${MNT_DIR}/etc/sddm.conf.d/autologin.conf" 2>/dev/null || {
    log_error "autologin.conf missing 'DisplayServer=wayland'"
    VERIFY_FAILURE=1
}

if [ $VERIFY_FAILURE -ne 0 ]; then
    log_error "IMAGE VERIFICATION FAILED — refusing to ship a broken image. Fix and rebuild."
    exit 1
fi
log_success "Image verification passed."

# Step 8: Image cleanup, zerofree block zeroing, unmounting, loop teardown
# ==============================================================================
log_step "8: Image Cleanup, Zerofree Block Zeroing, and Unmounting"

# Truncate machine-id so systemd generates unique ID on first boot
truncate -s 0 "${MNT_DIR}/etc/machine-id"
rm -f "${MNT_DIR}/etc/resolv.conf"

# Sync file buffers
sync

log_info "Unmounting pseudo filesystems and partitions..."
umount -lf "${MNT_DIR}/run" || true
umount -lf "${MNT_DIR}/sys" || true
umount -lf "${MNT_DIR}/proc" || true
umount -lf "${MNT_DIR}/dev/pts" || true
umount -lf "${MNT_DIR}/dev" || true
umount -lf "${MNT_DIR}/boot" || true
umount -lf "${MNT_DIR}" || true

sync

# Block zeroing on rootfs ext4 partition to optimize archive compression ratio
log_info "Zeroing unallocated filesystem blocks for maximum compression..."
if command -v zerofree &>/dev/null; then
    log_info "Running zerofree on ${ROOT_PART}..."
    zerofree -v "${ROOT_PART}" || log_warn "zerofree returned non-zero; continuing."
else
    log_info "zerofree not present. Mounting and filling free space with zeros via dd..."
    mount "${ROOT_PART}" "${MNT_DIR}"
    dd if=/dev/zero of="${MNT_DIR}/zero.fill" bs=1M status=none || true
    sync
    rm -f "${MNT_DIR}/zero.fill"
    sync
    umount "${MNT_DIR}"
fi

# Detach loop device
log_info "Detaching loopback device ${LOOP_DEV}..."
losetup -d "${LOOP_DEV}"
LOOP_DEV=""

log_success "Image unmounted and loopback device detached cleanly."

# ==============================================================================
# Step 9: Multi-threaded compression to .img.zst and .img.xz, sha256 checksums
# ==============================================================================
log_step "9: Multi-Threaded Compression & SHA256 Checksums"

cd "${OUTPUT_DIR}"
rm -f "${IMAGE_BASE}.img.zst" "${IMAGE_BASE}.img.xz" SHA256SUMS

if [ $SKIP_COMPRESS -eq 1 ]; then
    log_info "Compression skipped per --skip-compress flag."
    cp "${IMAGE_FILE}" "${OUTPUT_DIR}/${IMAGE_BASE}.img"
    sha256sum "${IMAGE_BASE}.img" > SHA256SUMS
else
    ZSTD_LEVEL="-19"
    XZ_LEVEL="-9"
    if [ $FAST_COMPRESS -eq 1 ]; then
        ZSTD_LEVEL="-3"
        XZ_LEVEL="-1"
        log_info "Using fast compression levels (zstd -3, xz -1)..."
    fi

    # Zstandard multi-threaded compression (.img.zst)
    if command -v zstd &>/dev/null; then
        log_info "Compressing ${IMAGE_BASE}.img to .img.zst (multi-threaded, level ${ZSTD_LEVEL})..."
        zstd -T0 ${ZSTD_LEVEL} -f "${IMAGE_FILE}" -o "${OUTPUT_DIR}/${IMAGE_BASE}.img.zst"
        log_success "Created: ${OUTPUT_DIR}/${IMAGE_BASE}.img.zst ($(du -h "${OUTPUT_DIR}/${IMAGE_BASE}.img.zst" | awk '{print $1}'))"
    else
        log_warn "zstd command not found; skipping .img.zst generation."
    fi

    # XZ multi-threaded compression (.img.xz)
    if command -v xz &>/dev/null; then
        log_info "Compressing ${IMAGE_BASE}.img to .img.xz (multi-threaded, level ${XZ_LEVEL})..."
        xz -T0 ${XZ_LEVEL} -k -c "${IMAGE_FILE}" > "${OUTPUT_DIR}/${IMAGE_BASE}.img.xz"
        log_success "Created: ${OUTPUT_DIR}/${IMAGE_BASE}.img.xz ($(du -h "${OUTPUT_DIR}/${IMAGE_BASE}.img.xz" | awk '{print $1}'))"
    else
        log_warn "xz command not found; skipping .img.xz generation."
    fi

    log_info "Generating SHA256 checksums..."
    sha256sum ${IMAGE_BASE}.img.* > SHA256SUMS || true
    cat SHA256SUMS
fi

echo ""
echo "======================================================================"
echo -e "${GREEN}${BOLD}OMARCHY QUATRO PI 5 IMAGE BUILD COMPLETE!${NC}"
echo "Output Directory: ${OUTPUT_DIR}"
ls -lh "${OUTPUT_DIR}"
echo "======================================================================"
