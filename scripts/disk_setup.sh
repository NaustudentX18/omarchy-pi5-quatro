#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quatro Pi 5 - Disk Image Setup Script
# Component: Infrastructure & Hardware Configuration
# 
# Purpose:
#   Automates creation, partitioning, loop binding, filesystem formatting,
#   PARTUUID resolution, placeholder substitution, and clean mounting/unmounting
#   for the Raspberry Pi 5 Omarchy system image.
#
# Requirements Handled:
#   1. Sparse raw image allocation (configurable size, default 12GB).
#   2. DOS/MBR partition table:
#      - Partition 1: 512MB FAT32 boot partition with bootable flag enabled.
#      - Partition 2: ext4 Linux root partition spanning remaining space.
#   3. Loop device binding with 'losetup -Pf'.
#   4. Formatting:
#      - Boot: mkfs.vfat -F 32 -n BOOT
#      - Root: mkfs.ext4 -F -L ROOT
#   5. blkid PARTUUID querying and placeholder substitution:
#      - @ROOT_PARTUUID@ in cmdline.txt
#      - @BOOT_PARTUUID@ and @ROOT_PARTUUID@ in config/fstab
#   6. Clean, robust mounting and unmounting functions.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Script & Project Paths
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_IMAGE_PATH="${PROJECT_DIR}/omarchy-pi5-quatro.img"
DEFAULT_IMAGE_SIZE="12G"
DEFAULT_BOOT_SIZE="512M"
DEFAULT_MOUNT_DIR="/mnt/omarchy-pi5"
BOOT_DIR="${PROJECT_DIR}/boot"
CONFIG_DIR="${PROJECT_DIR}/config"

# Configurable variables
IMAGE_PATH="${IMAGE_PATH:-${DEFAULT_IMAGE_PATH}}"
IMAGE_SIZE="${IMAGE_SIZE:-${DEFAULT_IMAGE_SIZE}}"
BOOT_SIZE="${BOOT_SIZE:-${DEFAULT_BOOT_SIZE}}"
MOUNT_DIR="${MOUNT_DIR:-${DEFAULT_MOUNT_DIR}}"
ACTIVE_LOOP_DEV=""
CLEANUP_ON_EXIT=1
KEEP_MOUNTED=0

# ------------------------------------------------------------------------------
# Formatting & Logging Helpers
# ------------------------------------------------------------------------------
if [[ -t 1 ]]; then
    COLOR_RESET="\033[0m"
    COLOR_BOLD="\033[1m"
    COLOR_RED="\033[31m"
    COLOR_GREEN="\033[32m"
    COLOR_YELLOW="\033[33m"
    COLOR_BLUE="\033[34m"
    COLOR_CYAN="\033[36m"
else
    COLOR_RESET=""
    COLOR_BOLD=""
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_CYAN=""
fi

log_info()    { echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"; }
log_success() { echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"; }
log_warn()    { echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*" >&2; }
log_err()     { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2; }
log_step()    { echo -e "\n${COLOR_BOLD}${COLOR_CYAN}==> $*${COLOR_RESET}"; }

# ------------------------------------------------------------------------------
# Privilege and Dependency Checks
# ------------------------------------------------------------------------------
require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_err "This operation requires root privileges."
        log_err "Please run with sudo: sudo $0 $*"
        exit 1
    fi
}

check_dependencies() {
    local missing=()
    local tools=("truncate" "sfdisk" "losetup" "mkfs.vfat" "mkfs.ext4" "blkid" "sed")
    for tool in "${tools[@]}"; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            missing+=("${tool}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_err "Missing required system utilities: ${missing[*]}"
        log_err "Please install them via: apt-get update && apt-get install -y dosfstools e2fsprogs util-linux"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Cleanup & Signal Trapping
# ------------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    if [[ ${CLEANUP_ON_EXIT} -eq 1 && ${exit_code} -ne 0 ]]; then
        log_warn "Error encountered (exit code: ${exit_code}). Running emergency cleanup..."
        if [[ -d "${MOUNT_DIR}" ]]; then
            unmount_partitions "${MOUNT_DIR}" || true
        fi
        if [[ -n "${ACTIVE_LOOP_DEV}" && -b "${ACTIVE_LOOP_DEV}" ]]; then
            detach_loop "${ACTIVE_LOOP_DEV}" || true
        fi
    fi
}
trap cleanup EXIT INT TERM

# ------------------------------------------------------------------------------
# Core Step 1: Sparse Image Allocation
# ------------------------------------------------------------------------------
allocate_sparse_image() {
    local target_img="$1"
    local size="$2"

    log_step "Allocating sparse raw disk image: ${target_img} (${size})"
    mkdir -p "$(dirname "${target_img}")"

    if [[ -f "${target_img}" ]]; then
        log_warn "Target image file already exists: ${target_img}"
        log_info "Overwriting existing image..."
        rm -f "${target_img}"
    fi

    truncate -s "${size}" "${target_img}"

    local apparent_size disk_usage
    apparent_size=$(ls -lh "${target_img}" | awk '{print $5}')
    disk_usage=$(du -h "${target_img}" | awk '{print $1}')

    log_success "Sparse image allocated successfully."
    log_info "  Virtual/Apparent Size: ${apparent_size}"
    log_info "  Actual Disk Usage:     ${disk_usage} (sparse)"
}

# ------------------------------------------------------------------------------
# Core Step 2: MBR Partition Table Creation
# ------------------------------------------------------------------------------
partition_mbr() {
    local target_img="$1"
    local boot_size="$2"

    log_step "Writing DOS/MBR partition table to: ${target_img}"

    # Layout:
    #   Partition 1: size=${boot_size}, type=c (W95 FAT32 LBA), bootable flag (*)
    #   Partition 2: remaining space,   type=83 (Linux ext4)
    sfdisk "${target_img}" <<EOF
label: dos
,${boot_size},c,*
,,83
EOF

    log_success "DOS/MBR partition table written."
    log_info "Partition structure:"
    sfdisk -d "${target_img}" | grep -E '^/.*type=' || true
}

# ------------------------------------------------------------------------------
# Core Step 3: Loop Device Binding with losetup -Pf
# ------------------------------------------------------------------------------
attach_loop() {
    require_root
    local target_img="$1"

    log_step "Binding image to loop device with partition scanning: losetup -Pf"

    local loop_dev
    loop_dev=$(losetup -Pf --show "${target_img}")

    if [[ -z "${loop_dev}" || ! -b "${loop_dev}" ]]; then
        log_err "Failed to attach image via losetup."
        exit 1
    fi

    ACTIVE_LOOP_DEV="${loop_dev}"
    log_success "Loop device bound: ${loop_dev}"

    # Wait for partition nodes (/dev/loopXp1 and /dev/loopXp2)
    local boot_part="${loop_dev}p1"
    local root_part="${loop_dev}p2"

    if command -v udevadm >/dev/null 2>&1; then
        udevadm settle || true
    fi

    local retry=0
    while [[ ! -b "${boot_part}" || ! -b "${root_part}" ]]; do
        if [[ ${retry} -ge 20 ]]; then
            if command -v partx >/dev/null 2>&1; then
                partx -u "${loop_dev}" || true
            fi
            if [[ ! -b "${boot_part}" || ! -b "${root_part}" ]]; then
                log_err "Partition devices ${boot_part} and ${root_part} failed to appear in /dev."
                exit 1
            fi
            break
        fi
        sleep 0.2
        retry=$((retry + 1))
    done

    log_info "  Boot partition device: ${boot_part}"
    log_info "  Root partition device: ${root_part}"

    echo "${loop_dev}"
}

# ------------------------------------------------------------------------------
# Core Step 4: Filesystem Formatting
# ------------------------------------------------------------------------------
format_partitions() {
    require_root
    local loop_dev="$1"
    local boot_part="${loop_dev}p1"
    local root_part="${loop_dev}p2"

    log_step "Formatting partitions:"
    log_info "  Boot Partition (${boot_part}): mkfs.vfat -F 32 -n BOOT"
    log_info "  Root Partition (${root_part}): mkfs.ext4 -F -L ROOT"

    mkfs.vfat -F 32 -n BOOT "${boot_part}"
    mkfs.ext4 -F -L ROOT "${root_part}"

    log_success "Partitions formatted successfully."
}

# ------------------------------------------------------------------------------
# Core Step 5: Query PARTUUIDs with blkid
# ------------------------------------------------------------------------------
query_partuuids() {
    local loop_dev="$1"
    local boot_part="${loop_dev}p1"
    local root_part="${loop_dev}p2"

    local boot_partuuid=""
    local root_partuuid=""

    # Bypass cache with -c /dev/null
    boot_partuuid=$(blkid -c /dev/null -s PARTUUID -o value "${boot_part}" 2>/dev/null || true)
    root_partuuid=$(blkid -c /dev/null -s PARTUUID -o value "${root_part}" 2>/dev/null || true)

    # Fallback to sfdisk label-id if needed
    if [[ -z "${boot_partuuid}" || -z "${root_partuuid}" ]]; then
        local disk_id
        disk_id=$(sfdisk -d "${loop_dev}" 2>/dev/null | grep -E '^label-id:' | awk '{print $2}' | sed 's/^0x//')
        if [[ -n "${disk_id}" ]]; then
            boot_partuuid="${disk_id}-01"
            root_partuuid="${disk_id}-02"
        fi
    fi

    if [[ -z "${boot_partuuid}" || -z "${root_partuuid}" ]]; then
        log_err "Failed to query PARTUUIDs for ${boot_part} and ${root_part}."
        exit 1
    fi

    echo "${boot_partuuid}" "${root_partuuid}"
}

# ------------------------------------------------------------------------------
# Core Step 6: Placeholder Substitution
# ------------------------------------------------------------------------------
substitute_placeholders() {
    local boot_partuuid="$1"
    local root_partuuid="$2"
    local cmdline_file="$3"
    local fstab_file="$4"

    log_step "Performing PARTUUID placeholder substitution"
    log_info "  Resolved BOOT_PARTUUID = ${boot_partuuid}"
    log_info "  Resolved ROOT_PARTUUID = ${root_partuuid}"

    if [[ -f "${cmdline_file}" ]]; then
        log_info "Updating ${cmdline_file} (@ROOT_PARTUUID@ -> ${root_partuuid})..."
        sed -i "s/@ROOT_PARTUUID@/${root_partuuid}/g" "${cmdline_file}"
        log_success "cmdline.txt content:"
        cat "${cmdline_file}"
        echo ""
    else
        log_warn "cmdline file not found: ${cmdline_file}"
    fi

    if [[ -f "${fstab_file}" ]]; then
        log_info "Updating ${fstab_file} (@BOOT_PARTUUID@ and @ROOT_PARTUUID@)..."
        sed -i \
            -e "s/@BOOT_PARTUUID@/${boot_partuuid}/g" \
            -e "s/@ROOT_PARTUUID@/${root_partuuid}/g" \
            "${fstab_file}"
        log_success "fstab content:"
        cat "${fstab_file}"
    else
        log_warn "fstab file not found: ${fstab_file}"
    fi
}

# ------------------------------------------------------------------------------
# Core Step 7: Clean Mounting and Unmounting
# ------------------------------------------------------------------------------
mount_partitions() {
    require_root
    local loop_dev="$1"
    local target_mount_dir="$2"
    local boot_part="${loop_dev}p1"
    local root_part="${loop_dev}p2"

    log_step "Mounting partitions to: ${target_mount_dir}"

    local root_mnt="${target_mount_dir}/root"
    local boot_mnt="${target_mount_dir}/boot"

    mkdir -p "${root_mnt}"
    mkdir -p "${boot_mnt}"

    # Mount root partition first
    log_info "Mounting root partition (${root_part}) to ${root_mnt}..."
    mount "${root_part}" "${root_mnt}"

    # Mount boot partition to both ${target_mount_dir}/boot and root/boot/firmware
    mkdir -p "${root_mnt}/boot/firmware"
    log_info "Mounting boot partition (${boot_part}) to ${root_mnt}/boot/firmware..."
    mount "${boot_part}" "${root_mnt}/boot/firmware"

    # Convenience mount to ${target_mount_dir}/boot
    log_info "Mounting boot partition (${boot_part}) to ${boot_mnt}..."
    mount "${boot_part}" "${boot_mnt}"

    log_success "All partitions mounted cleanly."
}

unmount_partitions() {
    require_root
    local target_mount_dir="$1"

    log_step "Unmounting partitions under: ${target_mount_dir}"

    if [[ ! -d "${target_mount_dir}" ]]; then
        log_info "Mount directory ${target_mount_dir} does not exist. Nothing to unmount."
        return 0
    fi

    # Flush all filesystem buffers
    sync

    # Find and unmount all mountpoints under target_mount_dir in reverse hierarchy order
    local active_mounts
    if command -v findmnt >/dev/null 2>&1; then
        active_mounts=$(findmnt -rn -o TARGET -R "${target_mount_dir}" 2>/dev/null | tail -n +2 | tac || true)
    else
        active_mounts=$(grep " ${target_mount_dir}" /proc/mounts | awk '{print $2}' | sort -r || true)
    fi

    for mp in ${active_mounts}; do
        if mountpoint -q "${mp}" 2>/dev/null; then
            log_info "Unmounting ${mp}..."
            umount "${mp}" || umount -l "${mp}"
        fi
    done

    # Check top-level directories
    for sub in "${target_mount_dir}/root/boot/firmware" "${target_mount_dir}/boot" "${target_mount_dir}/root"; do
        if mountpoint -q "${sub}" 2>/dev/null; then
            log_info "Unmounting ${sub}..."
            umount "${sub}" || umount -l "${sub}"
        fi
    done

    if mountpoint -q "${target_mount_dir}" 2>/dev/null; then
        log_info "Unmounting base directory ${target_mount_dir}..."
        umount "${target_mount_dir}" || umount -l "${target_mount_dir}"
    fi

    sync
    log_success "Unmount completed successfully."
}

detach_loop() {
    require_root
    local loop_dev="$1"

    log_step "Detaching loop device: ${loop_dev}"

    if [[ -b "${loop_dev}" ]]; then
        sync
        losetup -d "${loop_dev}"
        log_success "Loop device ${loop_dev} detached."
    else
        log_warn "Device ${loop_dev} is not a valid block device."
    fi

    if [[ "${ACTIVE_LOOP_DEV}" == "${loop_dev}" ]]; then
        ACTIVE_LOOP_DEV=""
    fi
}

# ------------------------------------------------------------------------------
# Helper: Install boot configuration and fstab into mounted filesystem
# ------------------------------------------------------------------------------
install_and_substitute_configs() {
    local target_mount_dir="$1"
    local boot_partuuid="$2"
    local root_partuuid="$3"

    log_step "Installing configuration files into mounted image"

    local boot_dest="${target_mount_dir}/boot"
    local root_dest="${target_mount_dir}/root"

    # Install boot configuration files
    if [[ -f "${BOOT_DIR}/config.txt" ]]; then
        log_info "Copying config.txt to boot partition..."
        cp -p "${BOOT_DIR}/config.txt" "${boot_dest}/config.txt"
        if [[ -d "${root_dest}/boot/firmware" ]]; then
            cp -p "${BOOT_DIR}/config.txt" "${root_dest}/boot/firmware/config.txt"
        fi
    else
        log_warn "Source config.txt not found in ${BOOT_DIR}"
    fi

    if [[ -f "${BOOT_DIR}/cmdline.txt" ]]; then
        log_info "Copying cmdline.txt to boot partition and substituting @ROOT_PARTUUID@..."
        cp -p "${BOOT_DIR}/cmdline.txt" "${boot_dest}/cmdline.txt"
        substitute_placeholders "${boot_partuuid}" "${root_partuuid}" "${boot_dest}/cmdline.txt" ""

        if [[ -d "${root_dest}/boot/firmware" ]]; then
            cp -p "${boot_dest}/cmdline.txt" "${root_dest}/boot/firmware/cmdline.txt"
        fi
    else
        log_warn "Source cmdline.txt not found in ${BOOT_DIR}"
    fi

    # Install fstab into rootfs /etc/fstab
    if [[ -f "${CONFIG_DIR}/fstab" ]]; then
        log_info "Installing fstab into rootfs /etc/fstab and substituting PARTUUIDs..."
        mkdir -p "${root_dest}/etc"
        cp -p "${CONFIG_DIR}/fstab" "${root_dest}/etc/fstab"
        substitute_placeholders "${boot_partuuid}" "${root_partuuid}" "" "${root_dest}/etc/fstab"
    else
        log_warn "Source fstab not found in ${CONFIG_DIR}"
    fi
}

# ------------------------------------------------------------------------------
# Helper: Show image / loop status
# ------------------------------------------------------------------------------
show_status() {
    local target_img="$1"

    log_step "Inspecting Disk Image Status: ${target_img}"

    if [[ ! -f "${target_img}" ]]; then
        log_warn "Image file does not exist: ${target_img}"
        return 0
    fi

    local apparent_size disk_usage
    apparent_size=$(ls -lh "${target_img}" | awk '{print $5}')
    disk_usage=$(du -h "${target_img}" | awk '{print $1}')

    echo "Image Path:          ${target_img}"
    echo "Apparent Size:       ${apparent_size}"
    echo "Actual Disk Usage:   ${disk_usage}"

    echo -e "\nPartition Table (MBR):"
    sfdisk -l "${target_img}"

    local disk_id
    disk_id=$(sfdisk -d "${target_img}" 2>/dev/null | grep -E '^label-id:' | awk '{print $2}' | sed 's/^0x//')
    if [[ -n "${disk_id}" ]]; then
        echo -e "\nCalculated PARTUUIDs:"
        echo "  Boot (p1): ${disk_id}-01"
        echo "  Root (p2): ${disk_id}-02"
    fi

    echo -e "\nAssociated Loop Devices:"
    losetup -j "${target_img}" || true
}

# ------------------------------------------------------------------------------
# Full Automation Pipeline
# ------------------------------------------------------------------------------
run_pipeline() {
    require_root
    check_dependencies

    log_step "Starting Full Omarchy Pi 5 Disk Setup Pipeline"
    log_info "Target Image:     ${IMAGE_PATH}"
    log_info "Image Size:       ${IMAGE_SIZE}"
    log_info "Boot Partition:   ${BOOT_SIZE}"
    log_info "Mount Directory:  ${MOUNT_DIR}"

    # Step 1: Allocate sparse image
    allocate_sparse_image "${IMAGE_PATH}" "${IMAGE_SIZE}"

    # Step 2: Write MBR partition table
    partition_mbr "${IMAGE_PATH}" "${BOOT_SIZE}"

    # Step 3: Attach loop device with -Pf
    local loop_dev
    loop_dev=$(attach_loop "${IMAGE_PATH}")

    # Step 4: Format partitions
    format_partitions "${loop_dev}"

    # Step 5: Query PARTUUIDs via blkid
    local partuuids
    partuuids=$(query_partuuids "${loop_dev}")
    local boot_partuuid root_partuuid
    read -r boot_partuuid root_partuuid <<< "${partuuids}"

    log_info "Discovered PARTUUIDs:"
    log_info "  BOOT_PARTUUID = ${boot_partuuid}"
    log_info "  ROOT_PARTUUID = ${root_partuuid}"

    # Step 6: Mount filesystems
    mount_partitions "${loop_dev}" "${MOUNT_DIR}"

    # Step 7: Populate configurations and perform substitution
    install_and_substitute_configs "${MOUNT_DIR}" "${boot_partuuid}" "${root_partuuid}"

    # Step 8: Clean unmount (unless requested to keep mounted)
    if [[ ${KEEP_MOUNTED} -eq 1 ]]; then
        log_info "Keep-mounted flag set; leaving partitions mounted at ${MOUNT_DIR}"
        log_info "Loop device ${loop_dev} remains active."
        CLEANUP_ON_EXIT=0
    else
        unmount_partitions "${MOUNT_DIR}"
        detach_loop "${loop_dev}"
        log_success "Image creation, formatting, substitution, and cleanup finished successfully."
    fi

    show_status "${IMAGE_PATH}"
}

# ------------------------------------------------------------------------------
# CLI Help & Usage
# ------------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $0 [command] [options]

Commands:
  all (default)      Run complete pipeline: allocate, partition, attach, format,
                     query PARTUUIDs, mount, substitute configs, unmount, detach.
  allocate           Allocate sparse image file only.
  partition          Write DOS/MBR partition table to image file.
  attach             Bind image to loop device with 'losetup -Pf'.
  format             Format boot (vfat FAT32) and root (ext4) on loop device.
  query              Query PARTUUIDs from loop device or image.
  substitute         Substitute @BOOT_PARTUUID@ and @ROOT_PARTUUID@ into files.
  mount              Mount boot and root partitions to target directory.
  unmount | umount   Safely unmount partitions under target directory.
  detach             Detach loop device.
  status             Display image, partition, and loop device status.
  help, -h, --help   Show this help message.

Options:
  -i, --image <path>       Target image path (default: ${DEFAULT_IMAGE_PATH})
  -s, --size <size>        Image size (default: ${DEFAULT_IMAGE_SIZE})
  -b, --boot-size <size>   Boot partition size (default: ${DEFAULT_BOOT_SIZE})
  -m, --mount-dir <dir>    Mount directory (default: ${DEFAULT_MOUNT_DIR})
  -l, --loop <dev>         Loop device to use (for format, mount, query, detach)
  --keep-mounted           Keep filesystems mounted and loop attached after 'all'
  --boot-partuuid <uuid>   Specify BOOT PARTUUID manually for substitute
  --root-partuuid <uuid>   Specify ROOT PARTUUID manually for substitute
  --cmdline-file <path>    Target cmdline.txt for substitution
  --fstab-file <path>      Target fstab for substitution

Examples:
  # Run complete setup with defaults (12GB sparse image):
  sudo $0

  # Custom size and image path:
  sudo $0 all -s 16G -i /path/to/custom.img

  # Allocate and partition only (can run without root):
  $0 allocate -s 12G -i custom.img
  $0 partition -i custom.img

  # Inspect status:
  $0 status -i custom.img

  # Clean unmount:
  sudo $0 unmount -m /mnt/omarchy-pi5
EOF
}

# ------------------------------------------------------------------------------
# Main Entry Point & Argument Parsing
# ------------------------------------------------------------------------------
main() {
    local command="all"
    local opt_loop=""
    local opt_boot_partuuid=""
    local opt_root_partuuid=""
    local opt_cmdline_file=""
    local opt_fstab_file=""

    if [[ $# -gt 0 ]]; then
        case "$1" in
            all|allocate|partition|attach|format|query|substitute|mount|unmount|umount|detach|status)
                command="$1"
                shift
                ;;
            -h|--help|help)
                usage
                exit 0
                ;;
            -*)
                # Treat as option for default 'all' command
                command="all"
                ;;
            *)
                log_err "Unknown command: $1"
                usage
                exit 1
                ;;
        esac
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--image)
                IMAGE_PATH="$2"
                shift 2
                ;;
            -s|--size)
                IMAGE_SIZE="$2"
                shift 2
                ;;
            -b|--boot-size)
                BOOT_SIZE="$2"
                shift 2
                ;;
            -m|--mount-dir)
                MOUNT_DIR="$2"
                shift 2
                ;;
            -l|--loop)
                opt_loop="$2"
                shift 2
                ;;
            --keep-mounted)
                KEEP_MOUNTED=1
                shift
                ;;
            --boot-partuuid)
                opt_boot_partuuid="$2"
                shift 2
                ;;
            --root-partuuid)
                opt_root_partuuid="$2"
                shift 2
                ;;
            --cmdline-file)
                opt_cmdline_file="$2"
                shift 2
                ;;
            --fstab-file)
                opt_fstab_file="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_err "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done

    check_dependencies

    case "${command}" in
        all)
            run_pipeline
            ;;
        allocate)
            allocate_sparse_image "${IMAGE_PATH}" "${IMAGE_SIZE}"
            ;;
        partition)
            partition_mbr "${IMAGE_PATH}" "${BOOT_SIZE}"
            ;;
        attach)
            require_root
            CLEANUP_ON_EXIT=0
            attach_loop "${IMAGE_PATH}"
            ;;
        format)
            require_root
            if [[ -z "${opt_loop}" ]]; then
                log_err "Please specify loop device with -l / --loop <device>"
                exit 1
            fi
            format_partitions "${opt_loop}"
            ;;
        query)
            if [[ -n "${opt_loop}" ]]; then
                query_partuuids "${opt_loop}"
            else
                local disk_id
                disk_id=$(sfdisk -d "${IMAGE_PATH}" 2>/dev/null | grep -E '^label-id:' | awk '{print $2}' | sed 's/^0x//')
                if [[ -n "${disk_id}" ]]; then
                    echo "BOOT_PARTUUID=${disk_id}-01"
                    echo "ROOT_PARTUUID=${disk_id}-02"
                else
                    log_err "Could not determine PARTUUID from ${IMAGE_PATH}."
                    exit 1
                fi
            fi
            ;;
        substitute)
            local b_uuid="${opt_boot_partuuid}"
            local r_uuid="${opt_root_partuuid}"

            if [[ -z "${b_uuid}" || -z "${r_uuid}" ]]; then
                if [[ -n "${opt_loop}" ]]; then
                    read -r b_uuid r_uuid <<< "$(query_partuuids "${opt_loop}")"
                elif [[ -f "${IMAGE_PATH}" ]]; then
                    local disk_id
                    disk_id=$(sfdisk -d "${IMAGE_PATH}" 2>/dev/null | grep -E '^label-id:' | awk '{print $2}' | sed 's/^0x//')
                    b_uuid="${disk_id}-01"
                    r_uuid="${disk_id}-02"
                fi
            fi

            if [[ -z "${b_uuid}" || -z "${r_uuid}" ]]; then
                log_err "Please provide PARTUUIDs via --boot-partuuid and --root-partuuid or specify --image / --loop"
                exit 1
            fi

            local cmdline_target="${opt_cmdline_file:-${BOOT_DIR}/cmdline.txt}"
            local fstab_target="${opt_fstab_file:-${CONFIG_DIR}/fstab}"
            substitute_placeholders "${b_uuid}" "${r_uuid}" "${cmdline_target}" "${fstab_target}"
            ;;
        mount)
            require_root
            if [[ -z "${opt_loop}" ]]; then
                log_err "Please specify loop device with -l / --loop <device>"
                exit 1
            fi
            CLEANUP_ON_EXIT=0
            mount_partitions "${opt_loop}" "${MOUNT_DIR}"
            ;;
        unmount|umount)
            require_root
            unmount_partitions "${MOUNT_DIR}"
            ;;
        detach)
            require_root
            if [[ -z "${opt_loop}" ]]; then
                log_err "Please specify loop device with -l / --loop <device>"
                exit 1
            fi
            detach_loop "${opt_loop}"
            ;;
        status)
            show_status "${IMAGE_PATH}"
            ;;
    esac
}

main "$@"
