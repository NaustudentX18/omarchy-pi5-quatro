# Changelog

All notable changes to Omarchy Quatro are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/); versioning is MAJOR.MINOR.
## [1.0.2] — 2026-09-08

The "boots to a working desktop" release. Every failure seen on real hardware
with v1.0.0/v1.0.1 is fixed and covered by a build-time verification gate.

### Fixed

- **MBR disk signature byte order**: the 0x1974beef signature was written as
  raw bytes `19 74 be ef`; the kernel reads it little-endian (`efbe7419`), so
  `root=PARTUUID=1974beef-02` never resolved and v1.0.0/v1.0.1 hung at the
  initramfs (black screen, no SSH). Signature is now written reversed and the
  build asserts `blkid` PARTUUIDs match cmdline.txt before shipping.
- **First-boot resize**: `cloud-utils-growpart` does not exist in Arch Linux
  ARM repos, so the rootfs never grew past 12 GB. The resizer now uses
  `sfdisk` (util-linux, always present) with a prompt-proof `parted` fallback.
- **SDDM launched Xorg on a Wayland-only image** ("Could not start Display
  server on vt 2" → black screen with a live, SSH-able system). The autologin
  config now forces `DisplayServer=wayland`.

### Changed

- **sway replaces Hyprland as the default compositor** (same Omarchy-style
  stack: waybar, fuzzel, mako, swaybg, foot). Reason: the ALARM repos are in a
  desync where `hyprland` requires `libaquamarine.so=13` but the published
  `aquamarine` provides soname 14, and the `hyprtoolkit` dependency chain is
  unpublished — Hyprland is currently uninstallable on Arch Linux ARM. Switch
  back with `sudo pacman -Syu hyprland aquamarine` once the repos sync.
- `git` and `parted` added to the image; post-chroot verification now fails
  the build loudly if sway, the session file, autologin.conf, chromium, sshd
  or kernel8.img are missing.

### Added

- Baked-in sway config (Omarchy keybinds, waybar, fuzzel, mako) and the
  tokyo-night cityscape wallpaper for the `omarchy` user.

[1.0.2]: https://github.com/NaustudentX18/omarchy-pi5-quatro/releases/tag/v1.0.2
## [1.0.0] — 2026-09-07

First public release. Built and verified natively on a Raspberry Pi 5 (8 GB).

### Added

- Complete bootable Arch Linux ARM image builder for Pi 5 (`build_pi5_image.sh`, steps 1–9,
  loop-device based, PARTUUID-deterministic with disk signature `0x1974beef`)
- Omarchy-style Hyprland desktop: SDDM autologin, waybar, fuzzel, mako, swaybg,
  foot + alacritty, grim/slurp, xdg portals, polkit agent
- Chromium browser and OpenSSH server baked into the image; `sshd` enabled at first boot
- 16K-page Pi 5 kernel (`linux-rpi-16k`, kver 6.18.x-rpi-16k) with mesa/Vulkan VideoCore VII support
- PCIe Gen 3 NVMe tuning (`pciex1_gen=3`) and I²C bus enablement in `config.txt`
- Argon ONE / NEO 5 I²C fan daemon (`argononed.service`) with stepped fan curve
- First-boot rootfs auto-resize (`rpi-resizerootfs.service`, via `cloud-utils-growpart`)
- ZRAM compressed swap + Pi 5 VM sysctl profile
- Default user `omarchy` (sudo NOPASSWD), hostname `omarchy-pi5`
- Raspberry Pi Imager custom OS list (`pi-imager-os-list.json`) with real SHA-256 hashes
- Docker-based build alternative (`build_docker.sh`, x86 cross-build needs host binfmt)

### Fixed

- ALARM `linux-rpi-16k` installs the kernel as `/boot/kernel8.img` and its own `config.txt`
  clobbers the tuned one — post-chroot re-injection added
- Base `linux-aarch64` kernel and `uboot-raspberrypi` removed before 16k kernel install (conflicts)
- pacman 7 Landlock download sandbox disabled inside chroot (`DisableSandbox`)
- Dangling `/etc/resolv.conf` symlink in ALARM rootfs handled before DNS copy
- fstab mounts boot at `/boot` (matches where firmware, DTBs, kernel and initramfs live)
- SDDM theme conflict resolved (single `omarchy` theme selection wins)
- Audited and verified end-to-end: loop-mount checks for kernel, initramfs, fstab, user,
  sudoers, smbus2, growpart, and enabled services before every release

[1.0.0]: https://github.com/NaustudentX18/omarchy-pi5-quatro/releases/tag/v1.0.0
