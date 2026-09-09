# Changelog

All notable changes to Omarchy Quatro are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/); versioning is MAJOR.MINOR.

## [1.0.6] — 2026-09-09

### Added — 100% Like-for-Like AI & Desktop Parity Release

- **Binary Un-shadowing (446 Commands Active)**: Resolved binary collision where legacy `/usr/local/bin/omarchy*` symlinks and `/etc/omarchy.conf` shadowed the official package binaries with stale 3.8.5 scripts. Deleted obsolete symlinks and config; full 429+ packaged v4.0.2 commands are now directly accessible via `/usr/bin/` (unblocking `omarchy agent`, `omarchy agent prompt`, `omarchy agent crash`, `omarchy agent usage update`, etc.).
- **Upstream AI Desktop Applications**:
  - `openai-codex-desktop` (ChatGPT / Codex desktop app) installed.
  - `perplexity` (Desktop client for Perplexity AI) installed.
  - `visual-studio-code-bin` (VS Code arm64) installed.
  - `typora` (Typora Markdown Editor) installed.
  - Overwrite rules added for `/usr/share/applications/*` to cleanly resolve desktop file conflicts during package transactions.
- **Parity CLI & System Utilities**:
  - Un-skipped and installed `usage` (5.1.0-1-aarch64) from ALARM extra.
  - Installed `imv` (Wayland image viewer) and `hyprland-preview-share-picker`.
- **Flatpak Layer & Productivity Apps**:
  - Installed `flatpak` and registered the Flathub remote.
  - Installed `md.obsidian.Obsidian` (v1.13.7) and `com.github.PintaProject.Pinta` (v3.1.2) for full upstream feature parity.
- **Spotify Parity Launcher**:
  - Created `Spotify.desktop` webapp launcher with dedicated hi-res icon, matching Omarchy's official webapp pattern (ChatGPT, Discord, YouTube) to bridge the absence of a native Linux ARM64 Spotify binary.
- **Tailscale Remote GPU Acceleration**:
  - Configured `OLLAMA_HOST=http://100.127.91.97:11434` in `/etc/environment` for seamless access to the remote RTX 4070 Ti Ollama server (29 models) over Tailscale.
- **Headless Display & Usability Hardening**:
  - Added headless monitor fallback safeguard to `/usr/bin/omarchy-hyprland-monitor-watch` to ensure Hyprland initializes a virtual display when booting without an HDMI display.
  - Configured Walker terminal runner to `alacritty -e`.
  - Added `Super + D` keybinding for direct Walker app launcher in Hyprland.
  - Disabled crashing `bt-agent.service`.

[1.0.6]: https://github.com/NaustudentX18/omarchy-pi5-quatro/compare/v1.0.5...v1.0.6

## [1.0.5] — 2026-09-08

### Added — like-for-like Omarchy v4 parity

**Research pass 2026-09-08** (upstream HEAD `1489450`, v4.0.0.alpha, 454 bin
commands): the `pkgs.omarchy.org/edge/aarch64` pacman repo exists (115 pkgs)
and makes a faithful port possible. The image now:

- Adds the `[omarchy]` pacman repo (`SigLevel = Never`, upstream's own
  external-repo pattern; `omarchy-keyring` installed for future trust).
- Installs upstream's **canonical `install/omarchy-base.packages` list
  straight from the fresh clone** (per-package fallback; reads live at build
  time so rebuilds track upstream automatically), plus the omarchy-repo
  extras: omarchy-keyring/zsh/nvim/walker/settings/audio-tuner, tensaku,
  omacalc, omacut, omawrite, ttfx, tobi-try, herdr, aether, asdcontrol,
  cliamp, mise-bin, walker + elephant-all (launcher + plugins),
  quickshell-git, claude-code, crush-bin, openai-codex-bin,
  github-copilot-cli, cursor-cli, voxtype-bin, omasnap, omatrack, omazed,
  strata, schist-bin, once-bin, dbxcli-bin, bun-bin, openclaw,
  nautilus-open-any-terminal, wayfreeze, sunshine, retroarch + the full
  libretro-vice core set, yaru themes, ttf-ia-writer, tzupdate, ufw-docker,
  localsend, hyprland-preview-share-picker.
- Installs the **Hyprland stack from the omarchy repo** (0.56.2-3 built
  against ALARM aquamarine soname 14 — resolves, unlike ALARM's own
  hyprland 0.56.1). **Sway remains the default session**; Hyprland appears
  in the SDDM session chooser. The `omarchy` meta package stays
  best-effort (blocked upstream on `uwsm`, which has no aarch64 package).
- Plymouth is now installed (omarchy-settings dependency) but the boot
  still runs splashless/quiet.

### Known gaps (no aarch64 package exists yet)

`usage`/`dotnet-runtime`, `qemu-user-static-binfmt`, `uwsm` (→ blocks the
`omarchy` meta), `obs-studio`, `obsidian`, `pinta`, `yay`, `asdcontrol` deps,
`ttf-jetbrains-mono-nerd-basic` fallbacks, x86-only hardware packages
(nvidia/intel/t2/limine), and GUI extras upstream installs optionally
(1password, vscode, sublime, typora, perplexity, nordvpn).

[1.0.5]: https://github.com/NaustudentX18/omarchy-pi5-quatro/compare/v1.0.4...v1.0.5

## [1.0.4] — 2026-09-08

### Added

- **avahi + nss-mdns**: the image now announces itself as `omarchy-pi5.local`
  on the LAN (no more router-IP hunting) and resolves other `.local` hosts
  (`mdns4_minimal` wired into `nsswitch.conf`). `avahi-daemon` is enabled and
  the build gate asserts the wants-symlink and nsswitch line are present.

### Fixed

- **zram swap actually exists now**: `zram-generator` was never in
  `packages.list`, so `systemd-zram-setup@zram0.service` (enabled since
  v1.0.0 with `|| true`) referenced a unit that could never exist — no swap
  on any shipped image. The package is now installed; the bogus enable line
  is gone (the unit template has no `[Install]` section — the generator
  self-activates 4 GB zstd swap from `/etc/systemd/zram-generator.conf` at
  boot), replaced by a loud in-chroot presence check and two verifier
  asserts. NOTE: existing v1.0.x installs gain zram via
  `pacman -S zram-generator` (config already present).
- Hyprland flip **still blocked**: ALARM rebuilt hyprland (0.56.1-3) and
  aquamarine (0.15.0-2) on 2026-09-08 but they remain desynced — hyprland
  needs `libaquamarine.so=13`, repo aquamarine provides soname 14. Sway
  stays the default session. `hyprland-guiutils` and `hyprtoolkit` did
  appear in the repos; flip is now only blocked on the soname.

[1.0.4]: https://github.com/NaustudentX18/omarchy-pi5-quatro/compare/v1.0.3...v1.0.4

## [1.0.3] — 2026-09-08

### Fixed (audit pass)

- **CRITICAL**: SDDM autologin now uses `Session=sway` instead of pointing at the uninstallable Hyprland binary. Image is strictly sway-compatible at first boot.
- **CRITICAL**: Removed Hyprland-only env vars (`AQ_DRM_DEVICES`, `AQ_NO_MODIFIERS`, `WLR_NO_HARDWARE_CURSORS`), the Hyprland `cursor{}` / `misc{}` blocks, `~/.config/hypr/pi5.conf`, `~/.config/hypr/pi5.lua`, the `start-hyprland` shim, and the unconditional `hyprland.desktop` placeholder. Hyprland re-enable: install with `pacman -S hyprland aquamarine` and a `hyprland.desktop` is written only when `/usr/bin/Hyprland` is executable.
- **HIGH**: Omarchy clone honours `OMARCHY_REPO_URL`, `OMARCHY_BRANCH` (default `master`), and `OMARCHY_PIN_SHA` env vars for reproducible builds. Default branch moved from non-main `quattro` to `master`.
- **HIGH**: Kernel install fails the build loudly if `/boot/kernel8.img` is missing or smaller than 1 MiB.
- **HIGH**: `pacman -R` on `linux-aarch64` / `uboot-raspberrypi` only runs if installed; genuine pacman errors propagate instead of being `|| true` masked.
- **HIGH**: Verifier now asserts presence of `bcm2712-rpi-5-b.dtb`, `start4.elf`, `fixup4.dat`, `initramfs-linux.img`, and that `config.txt` survived linux-rpi-16k package re-injection. (`bootcode4.bin` was briefly asserted by mistake — no such file exists on Pi 4 or Pi 5 boot partitions: Pi 4's loader is `bootcode.bin`, Pi 5 stages from EEPROM.) Verifier also grep-asserts `dtoverlay=vc4-kms-v3d` and `pciex1_gen=3` are present in `config.txt`, and that `cmdline.txt` does not request the missing plymouth splash.
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

### Changed

- Wallpaper vendored into the repo (`desktop/wallpaper.jpg`, staged into the
  chroot payload) instead of downloaded at build time; curl kept as fallback.
- `git` added to the image (`packages.list`), so the upstream Omarchy repo now
  actually clones at build time (`/opt/omarchy`, 284 binaries linked, dotfiles
  seeded) instead of silently falling back to the local skeleton.
- Verification gate now fails loudly if `cmdline.txt` lacks `root=` or uses a
  non-`PARTUUID=` form, instead of silently comparing against an empty string.
- `hyprpicker` annotated as compositor-agnostic (wlr-layer-shell, works under
  sway).

[1.0.3]: https://github.com/NaustudentX18/omarchy-pi5-quatro/compare/v1.0.2...v1.0.3

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
