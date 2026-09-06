# First-Boot Root Filesystem Auto-Resize Subsystem
**Omarchy Quatro Pi 5 Agent Swarm**

## Overview
This subsystem automatically detects and expands the root partition and ext4 filesystem to occupy 100% of the underlying physical storage media (e.g. 512GB NVMe SSD, SD card, or USB drive) on first system boot.

## Features
- **Dynamic Device Detection**: Detects active root device (`/dev/nvme0n1p2`, `/dev/sda2`, `/dev/mmcblk0p2`, etc.) via `findmnt` and `readlink`.
- **Partition Geometry Expansion**: Utilizes `growpart` with automatic `parted` fallback to grow partition boundaries.
- **Kernel Table Refresh**: Notifies kernel via `partx` and `partprobe` and waits for udev synchronization.
- **Online Filesystem Growth**: Invokes `resize2fs` (or filesystem-appropriate tool) online on mounted root.
- **Self-Disabling Mechanism**: Drops marker file `/etc/rpi-resizerootfs.done` and disables the systemd service unit so it executes strictly once.

## Files
- `rpi-resizerootfs.sh`: Root filesystem expander shell script.
- `rpi-resizerootfs.service`: Systemd oneshot unit configured with `ConditionPathExists=!/etc/rpi-resizerootfs.done`.
- `install_resize.sh`: Standalone installation script for live system or chroot environment.
