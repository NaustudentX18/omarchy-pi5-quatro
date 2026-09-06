# Omarchy Quatro — Arch Linux ARM for Raspberry Pi 5

[![Target](https://img.shields.io/badge/Target-Raspberry%20Pi%205%20(BCM2712)-red.svg)](#architecture-overview)
[![Kernel](https://img.shields.io/badge/Kernel-linux--rpi--16k-blue.svg)](#16k-page-size-kernel)
[![Desktop](https://img.shields.io/badge/Desktop-Hyprland%20Wayland-brightgreen.svg)](#wayland--hyprland-desktop-stack)
[![PCIe](https://img.shields.io/badge/Storage-PCIe%20Gen%203%20NVMe-orange.svg)](#pcie-gen-3-nvme-throughput)
[![Cooling](https://img.shields.io/badge/Thermal-Argon%20ONE%20%2F%20NEO%205-purple.svg)](#argon-one--neo-5-thermal-management)

**Omarchy Quatro** is a high-performance Arch Linux ARM workstation distribution engineered specifically for the **Raspberry Pi 5** (8GB RAM) operating directly off high-speed **NVMe SSDs** (M.2 HATs, Argon ONE V3 M.2, Argon NEO 5 M.2).

It combines pristine Arch Linux ARM aarch64 rolling stability with the fluid **Hyprland Wayland compositor**, full hardware acceleration, custom active cooling daemons, 16k page-size kernel optimization, and first-boot partition auto-expansion.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
  - [16k Page-Size Kernel](#16k-page-size-kernel)
  - [PCIe Gen 3 NVMe Throughput](#pcie-gen-3-nvme-throughput)
  - [Argon ONE / NEO 5 Thermal Management](#argon-one--neo-5-thermal-management)
  - [8GB RAM & ZRAM Memory Tuning](#8gb-ram--zram-memory-tuning)
  - [Wayland / Hyprland Desktop Stack](#wayland--hyprland-desktop-stack)
  - [First-Boot NVMe Auto-Resize](#first-boot-nvme-auto-resize)
- [Quickstart: Flashing to 512GB NVMe SSD](#quickstart-flashing-to-512gb-nvme-ssd)
  - [Prerequisites & Pi 5 EEPROM Boot Order](#prerequisites--pi-5-eeprom-boot-order)
  - [Method 1: Raspberry Pi Imager (Custom OS List)](#method-1-raspberry-pi-imager-custom-os-list)
  - [Method 2: High-Speed Direct Flashing with bmaptool](#method-2-high-speed-direct-flashing-with-bmaptool)
  - [Method 3: Raw dd / Decompression Stream](#method-3-raw-dd--decompression-stream)
- [Building the Image from Source](#building-the-image-from-source)
  - [Method A: Docker Privileged Container (Recommended)](#method-a-docker-privileged-container-recommended)
  - [Method B: Native Host Execution](#method-b-native-host-execution)
  - [Build Options & Flags](#build-options--flags)
- [Repository Structure](#repository-structure)
- [Default System Credentials & Configuration](#default-system-credentials--configuration)

---

## Architecture Overview

### 16k Page-Size Kernel
Standard Linux distributions for 64-bit ARM use 4KB memory page sizes. The Broadcom BCM2712 Cortex-A76 processor on the Raspberry Pi 5 achieves significantly higher memory bandwidth and reduced TLB (Translation Lookaside Buffer) thrashing with **16KB page sizes**.
Omarchy Quatro packages `linux-rpi-16k` and `raspberrypi-bootloader`, delivering up to **20-30% faster memory-intensive operations** and enhanced I/O performance.

### PCIe Gen 3 NVMe Throughput
The Pi 5 features an external PCIe 2.0 x1 connector that reliably supports **PCIe Gen 3.0** speeds on high-grade M.2 HATs and enclosures (such as the Argon ONE V3 NVMe Case, Pimoroni NVMe Base, Pineberry Pi HatDrive, and Waveshare M.2 HAT).
In `/boot/config.txt`:
```ini
dtparam=pciex1
dtparam=pciex1_gen=3
```
This increases data bus bandwidth from ~450 MB/s (Gen 2) to **~850–900 MB/s sequential read/write** on modern M.2 drives (e.g., Crucial P3/P310, WD Black SN770, Samsung 980).

### Argon ONE / NEO 5 Thermal Management
For aluminum enclosures like the **Argon ONE V2/V3** and **Argon NEO 5**, the image includes an automated I2C thermal control daemon:
- Target: `/dev/i2c-1` at bus address `0x1a`
- Service: `argononed.service` running `/usr/local/bin/argononed.py`
- Step curve:
  - `< 55°C`: 0% (Silent passive cooling)
  - `55°C – 65°C`: 30% Fan Speed
  - `65°C – 75°C`: 60% Fan Speed
  - `>= 75°C`: 100% Fan Speed

### 8GB RAM & ZRAM Memory Tuning
To eliminate swapping stalls while keeping latency at near-zero, Omarchy Quatro provides:
- **ZRAM Compressed Swap**: Powered by `systemd-zram-generator` allocating half of physical RAM as an in-memory swap pool compressed with `zstd`.
- **Custom VM sysctl tuning** (`/etc/sysctl.d/99-pi5-tuning.conf`):
  - `vm.swappiness = 180`: Actively uses compressed ZRAM before discarding file-backed caches.
  - `vm.watermark_boost_factor = 0`: Prevents preemptive kswapd reclaim stutter.
  - `vm.watermark_scale_factor = 125`: Maintains buffer headroom for sudden large memory allocations.
  - `vm.page-cluster = 0`: Zero sequential read clustering penalty for RAM swaps.

### Wayland / Hyprland Desktop Stack
- **Compositor**: Hyprland (dynamic tiling Wayland compositor with smooth animations and blur).
- **Display Manager**: SDDM configured with automatic Wayland session login into `hyprland.desktop`.
- **Status Bar & UI**: Waybar, Fuzzel application launcher, Foot / Kitty terminal emulators, Mako notifications, and Swaybg wallpaper engine.
- **Audio Stack**: PipeWire with `pipewire-pulse`, `wireplumber`, and ALSA integration.

### First-Boot NVMe Auto-Resize
The pre-built raw image is created at a compact 12GB sparse size. On initial boot, the one-shot `rpi-resizerootfs.service` executes:
1. Inspects the active root partition device (e.g. `/dev/nvme0n1p2`).
2. Expands the partition boundary to 100% of the drive geometry using `parted`.
3. Runs an online `resize2fs` to instantly claim the full NVMe capacity (e.g. 512GB, 1TB).
4. Unregisters and disables itself permanently.

---

## Quickstart: Flashing to 512GB NVMe SSD

### Prerequisites & Pi 5 EEPROM Boot Order
Before booting directly from NVMe with no SD card inserted, confirm your Pi 5 bootloader EEPROM is configured to prioritize NVMe:

```bash
# Check current boot order
rpi-eeprom-config

# Ensure BOOT_ORDER includes NVMe (6) before or after SD (1):
# 0xf61 = Try NVMe first, then SD card fallback
# 0xf16 = Try SD card first, then NVMe
```

If needed, update the EEPROM config:
```bash
sudo rpi-eeprom-config --edit
# Set: BOOT_ORDER=0xf61
# Set: PCIE_PROBE=1
```

---

### Method 1: Raspberry Pi Imager (Custom OS List)

Raspberry Pi Imager can load the provided `pi-imager-os-list.json` definition directly:

1. Launch Raspberry Pi Imager with the custom repository argument:
   ```bash
   rpi-imager --repo file:///home/pi/projects/omarchy-pi5-quatro/pi-imager-os-list.json
   ```
2. Under **Operating System**, select:
   - **Omarchy Quatro - Arch Linux ARM (Pi 5 NVMe)**
3. Under **Storage**, choose your 512GB NVMe drive (attached via USB-NVMe enclosure or adapter).
4. Click **Next** / **Write**.
5. Once written and verified, insert the NVMe drive into your Pi 5 M.2 HAT and boot!

Alternatively, select **Use custom** in Raspberry Pi Imager and select the uncompressed `.img` or compressed `.img.xz` file directly.

---

### Method 2: High-Speed Direct Flashing with bmaptool

`bmaptool` is the fastest method to flash sparse raw disk images, skipping empty blocks automatically:

```bash
# Decompress image if working with .zst
zstd -d -k output/omarchy-pi5-quatro.img.zst

# Generate block map
bmaptool create -o output/omarchy-pi5-quatro.img.bmap output/omarchy-pi5-quatro.img

# Flash to target NVMe SSD (replace /dev/sdX or /dev/nvmeXn1 with your drive)
sudo bmaptool copy output/omarchy-pi5-quatro.img /dev/nvme0n1
```

---

### Method 3: Raw dd / Decompression Stream

To stream a compressed image directly to the target NVMe drive without decompressing to host storage first:

#### From `.img.zst` (Zstandard):
```bash
zstdcat output/omarchy-pi5-quatro.img.zst | sudo dd of=/dev/nvme0n1 bs=4M status=progress conv=fsync
```

#### From `.img.xz` (XZ):
```bash
xzcat output/omarchy-pi5-quatro.img.xz | sudo dd of=/dev/nvme0n1 bs=4M status=progress conv=fsync
```

---

## Building the Image from Source

### Method A: Docker Privileged Container (Recommended)

Building inside the container avoids host dependency drift, requires no local package installations, and runs in an isolated rootfs environment.

```bash
cd /home/pi/projects/omarchy-pi5-quatro

# Make runners executable
chmod +x build_docker.sh build_pi5_image.sh scripts/*.sh scripts/*.py

# Start containerized build
./build_docker.sh
```

### Method B: Native Host Execution

Run directly on the Pi 5 host (Debian/Arch) with root privileges:

```bash
cd /home/pi/projects/omarchy-pi5-quatro

# Ensure required tools are installed:
# Debian: sudo apt install parted dosfstools e2fsprogs tar curl zstd xz-utils zerofree
# Arch:   sudo pacman -S parted dosfstools e2fsprogs tar curl zstd xz zerofree

# Run build orchestrator
sudo ./build_pi5_image.sh
```

### Build Options & Flags

The build orchestrator supports the following options:

| Flag | Description |
|---|---|
| `--skip-compress` | Skips `.img.zst` and `.img.xz` multi-threaded compression (ideal for local testing). |
| `--fast-compress` | Uses fast compression levels (`zstd -3`, `xz -1`) for rapid packaging iteration. |
| `--help` | Displays usage summary and available flags. |

Example:
```bash
# Rapid test build skipping high-ratio compression
sudo ./build_pi5_image.sh --fast-compress
```

---

## Repository Structure

```
/home/pi/projects/omarchy-pi5-quatro/
├── build_pi5_image.sh          # Master image orchestrator (Steps 1–9)
├── build_docker.sh             # Privileged Docker container runner
├── Dockerfile                  # Containerized build environment
├── pi-imager-os-list.json      # Raspberry Pi Imager OS list entry
├── README.md                   # Complete documentation and user guide
├── boot/
│   ├── config.txt              # Pi 5 PCIe Gen 3, I2C, 16k kernel config
│   └── cmdline.txt             # Kernel command line with deterministic PARTUUID
├── desktop/
│   └── packages.list           # Curated Arch Linux ARM package manifest
└── scripts/
    ├── argononed.py            # Argon ONE / NEO 5 I2C fan daemon
    ├── argononed.service       # Systemd unit for cooling daemon
    ├── rpi-resizerootfs.sh     # First-boot online NVMe rootfs auto-expander
    ├── rpi-resizerootfs.service# Systemd one-shot service for expansion
    ├── zram-generator.conf     # ZRAM compressed RAM swap config
    └── 99-pi5-tuning.conf      # Kernel and VM sysctl performance parameters
```

---

## Default System Credentials & Configuration

| Parameter | Default Value | Notes |
|---|---|---|
| **Default User** | `omarchy` | Created with standard user groups (`wheel,video,audio,...`) |
| **User Password** | `omarchy` | Please change on first login (`passwd omarchy`) |
| **Root Password** | `omarchy` | Please change on first login (`passwd root`) |
| **Sudo Privileges** | `NOPASSWD: ALL` | Configured in `/etc/sudoers.d/010_wheel_nopasswd` |
| **Default Hostname** | `omarchy-pi5` | Configured in `/etc/hostname` |
| **Display Session** | `hyprland.desktop` | Automatically loaded by SDDM on boot |
| **Network Manager** | Active | Connect via `nmtui`, `nmcli`, or the Waybar network applet |
| **Audio Server** | PipeWire | Native WirePlumber session management |

---

*Omarchy Quatro is an open-source system initiative designed for power users running Raspberry Pi 5 hardware.*
