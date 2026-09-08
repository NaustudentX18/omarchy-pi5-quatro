#!/usr/bin/env bash
# ==============================================================================
# rpi-resizerootfs.sh - First-Boot Root Filesystem Auto-Resize
# Omarchy Quatro Pi 5 Agent Swarm
#
# Detects root partition (/dev/nvme0n1p2, /dev/sda2, /dev/mmcblk0p2, etc.)
# Expands partition using growpart (with parted fallback) to fill entire disk (e.g. 512GB NVMe SSD)
# Runs resize2fs to expand ext4 filesystem to full partition capacity
# Disables itself after successful first-boot run
# ==============================================================================
set -euo pipefail

LOG_TAG="rpi-resizerootfs"
DONE_FLAG="/etc/rpi-resizerootfs.done"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${LOG_TAG}] $*"
}

log "Starting first-boot root filesystem auto-expansion..."

# 1. Check if already completed
if [ -f "$DONE_FLAG" ]; then
    log "Resize flag $DONE_FLAG already present. Nothing to do."
    exit 0
fi

# 2. Require root permissions
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] ${LOG_TAG} must be executed as root." >&2
    exit 1
fi

# 3. Detect root partition device
ROOT_DEV="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
if [ -z "$ROOT_DEV" ] || [ "$ROOT_DEV" = "/dev/root" ]; then
    # Try resolving via df if findmnt returned /dev/root or empty
    ROOT_DEV="$(df --output=source / | tail -n 1)"
fi

# Resolve canonical path in case of symlinks (e.g. /dev/disk/by-...)
ROOT_DEV="$(readlink -f "$ROOT_DEV" 2>/dev/null || echo "$ROOT_DEV")"

if [ ! -b "$ROOT_DEV" ]; then
    log "ERROR: Could not resolve valid root block device (got '$ROOT_DEV')."
    exit 1
fi

log "Detected active root device: $ROOT_DEV"

# 4. Determine parent disk block device and partition number
PARENT_DISK=""
PART_NUM=""

if command -v lsblk >/dev/null 2>&1; then
    PARENT_DISK="$(lsblk -no PKNAME "$ROOT_DEV" 2>/dev/null | head -n 1 || true)"
    PART_NUM="$(lsblk -no PARTN "$ROOT_DEV" 2>/dev/null | head -n 1 || true)"
fi

# Fallback parsing if lsblk didn't supply parent disk or partition number
if [ -z "$PARENT_DISK" ] || [ -z "$PART_NUM" ]; then
    if [[ "$ROOT_DEV" =~ ^/dev/(nvme[0-9]+n[0-9]+)p([0-9]+)$ ]]; then
        PARENT_DISK="${BASH_REMATCH[1]}"
        PART_NUM="${BASH_REMATCH[2]}"
    elif [[ "$ROOT_DEV" =~ ^/dev/(mmcblk[0-9]+)p([0-9]+)$ ]]; then
        PARENT_DISK="${BASH_REMATCH[1]}"
        PART_NUM="${BASH_REMATCH[2]}"
    elif [[ "$ROOT_DEV" =~ ^/dev/([a-zA-Z0-9_-]+)([0-9]+)$ ]]; then
        PARENT_DISK="${BASH_REMATCH[1]}"
        PART_NUM="${BASH_REMATCH[2]}"
    fi
fi

if [ -z "$PARENT_DISK" ] || [ -z "$PART_NUM" ]; then
    log "ERROR: Unable to parse parent disk and partition index for $ROOT_DEV."
    exit 1
fi

DISK_DEV="/dev/${PARENT_DISK}"
log "Parent disk: ${DISK_DEV}, Partition: ${PART_NUM}"

if [ ! -b "$DISK_DEV" ]; then
    log "ERROR: Parent disk ${DISK_DEV} is not a valid block device."
    exit 1
fi

# 5. Expand partition to 100% of the disk
# sfdisk (util-linux, always present) is primary. parted is fallback.
# NOTE: parted -s prompts for confirmation on in-use partitions (aborts in
# scripts), and cloud-utils-growpart does not exist in Arch Linux ARM repos —
# both learned the hard way in v1.0.0/v1.0.1 first-boot failures.
GROW_SUCCESS=0

if command -v sfdisk >/dev/null 2>&1; then
    log "Attempting partition expansion using sfdisk ${DISK_DEV} partition ${PART_NUM}..."
    set +e
    SFDISK_OUT="$(printf ', +\n' | sfdisk --no-reread --force -N "${PART_NUM}" "${DISK_DEV}" 2>&1)"
    SFD_STATUS=$?
    set -e
    log "${SFDISK_OUT}"
    if [ $SFD_STATUS -eq 0 ]; then
        log "sfdisk successfully expanded partition."
        GROW_SUCCESS=1
    else
        log "sfdisk warning (code $SFD_STATUS)."
    fi
fi

# Fallback to parted if sfdisk failed
if [ $GROW_SUCCESS -eq 0 ]; then
    if command -v parted >/dev/null 2>&1; then
        log "Attempting partition expansion using parted ${DISK_DEV} resizepart ${PART_NUM} 100%..."
        set +e
        printf 'Yes\n' | parted ---pretend-input-tty "$DISK_DEV" resizepart "$PART_NUM" 100% 2>&1 || true
        set -e
    else
        log "WARNING: Neither sfdisk nor parted is installed."
    fi
fi

# 6. Inform kernel and udev of partition table changes
log "Informing kernel of updated partition table..."
if command -v partx >/dev/null 2>&1; then
    partx -u "$ROOT_DEV" 2>/dev/null || true
fi
if command -v partprobe >/dev/null 2>&1; then
    partprobe "$DISK_DEV" 2>/dev/null || true
fi
udevadm settle 2>/dev/null || sleep 2

# 7. Resize filesystem to fill partition
FSTYPE="$(findmnt -n -o FSTYPE / 2>/dev/null || blkid -s TYPE -o value "$ROOT_DEV" 2>/dev/null || echo "ext4")"
log "Filesystem type on / is '${FSTYPE}'"

case "$FSTYPE" in
    ext2|ext3|ext4)
        log "Executing resize2fs on ${ROOT_DEV}..."
        resize2fs "$ROOT_DEV"
        log "resize2fs finished successfully."
        ;;
    btrfs)
        log "Executing btrfs filesystem resize max /..."
        btrfs filesystem resize max /
        ;;
    xfs)
        log "Executing xfs_growfs /..."
        xfs_growfs /
        ;;
    *)
        log "Unrecognized filesystem '${FSTYPE}', attempting resize2fs as fallback..."
        resize2fs "$ROOT_DEV" || true
        ;;
esac

# 8. Mark complete and disable first-boot service
log "Writing completion marker to $DONE_FLAG..."
touch "$DONE_FLAG"

if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    log "Disabling rpi-resizerootfs.service..."
    systemctl disable rpi-resizerootfs.service 2>/dev/null || true
fi

NEW_SIZE="$(df -h / | awk 'NR==2 {print $2}')"
log "Root filesystem expansion complete! New root volume capacity: ${NEW_SIZE}"
exit 0
