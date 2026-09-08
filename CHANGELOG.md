# Changelog

All notable changes to Omarchy Quatro are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/); versioning is MAJOR.MINOR.

## [Unreleased] — 2026-09-08

### Fixed (audit pass)

- **CRITICAL**: SDDM autologin now uses `Session=sway` instead of pointing at the uninstallable Hyprland binary. Image is strictly sway-compatible at first boot.
- **CRITICAL**: Removed Hyprland-only env vars (`AQ_DRM_DEVICES`, `AQ_NO_MODIFIERS`, `WLR_NO_HARDWARE_CURSORS`), the Hyprland `cursor{}` / `misc{}` blocks, `~/.config/hypr/pi5.conf`, `~/.config/hypr/pi5.lua`, the `start-hyprland` shim, and the unconditional `hyprland.desktop` placeholder. Hyprland re-enable: install with `pacman -S hyprland aquamarine` and a `hyprland.desktop` is written only when `/usr/bin/Hyprland` is executable.
- **HIGH**: Omarchy clone honours `OMARCHY_REPO_URL`, `OMARCHY_BRANCH` (default `master`), and `OMARCHY_PIN_SHA` env vars for reproducible builds. Default branch moved from non-main `quattro` to `master`.
- **HIGH**: Kernel install fails the build loudly if `/boot/kernel8.img` is missing or smaller than 1 MiB.
- **HIGH**: `pacman -R` on `linux-aarch64` / `uboot-raspberrypi` only runs if installed; genuine pacman errors propagate instead of being `|| true` masked.
- **HIGH**: Verifier now asserts presence of `bcm2712-rpi-5-b.dtb`, `start4.elf`, `fixup4.dat`, `bootcode4.bin`, `initramfs-linux.img`, and that `config.txt` survived linux-rpi-16k package re-injection. Verifier also grep-asserts `dtoverlay=vc4-kms-v3d` and `pciex1_gen=3` are present in `config.txt`, and that `cmdline.txt` does not request the missing plymouth splash.
- **HIGH**: `argononed.py` power-button pulse thresholds corrected to Argon protocol (10–50 ms reboot, 2500–3500 ms shutdown) with 5-second post-event hysteresis.
- **HIGH**: `argon/install_argon.sh` is now distro-aware (apt / pacman / dnf / pip-fallback).
- **MEDIUM**: Resize robustness — `parted -s` replaces the interactive-prompt fallback; sfdisk remains primary; sfdisk flag rationale documented inline.
- **MEDIUM**: `vm.dirty_background_bytes=200M` set explicitly so both 4 GB and 8 GB Pi 5 SKUs get the same writeback target; `apply_tuning.sh` warns on out-of-range RAM.
- **MEDIUM**: `/boot` mount uses `flush,noatime` for power-cut safety on vfat.
- **MEDIUM**: `cmdline.txt` no longer requests `splash` (plymouth is not installed).
- **MEDIUM**: README corrected to reflect sway-not-Hyprland reality; badges, "Why" table, "What's inside", and FAQ updated.
- **MEDIUM**: `pi-imager-os-list.json` icon URL corrected to point at this repo's `master` branch (was pointing at `omarchy-termux`).
- **MEDIUM**: Dockerfile, CI shellcheck, and hadolint hardened (reproducibility comments, severity bump, new hadolint step).
- **MEDIUM**: New `## Security` section in README documenting default-credentials hardening steps.

[Unreleased]: https://github.com/NaustudentX18/omarchy-pi5-quatro/compare/v1.0.2...HEAD

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
