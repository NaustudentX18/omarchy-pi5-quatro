# Omarchy Quattro Pi 5 Desktop Integration

This directory contains the provisioning scripts and package manifests for deploying the **Omarchy Quattro** desktop environment on **Raspberry Pi 5** (BCM2712 / VideoCore VII) under **Arch Linux ARM (aarch64)**.

---

## 📁 Manifest of Provisioning Files

| File | Purpose |
|------|---------|
| [`packages.list`](file:///home/pi/projects/omarchy-pi5-quatro/desktop/packages.list) | Comprehensive Arch Linux ARM package manifest covering Display, Compositor, VideoCore VII GPU, PipeWire Audio, Networking, Bluetooth, Shell tools, and Fonts. |
| [`setup_omarchy_user.sh`](file:///home/pi/projects/omarchy-pi5-quatro/desktop/setup_omarchy_user.sh) | User creation script: provisions user `omarchy` (password `omarchy`) in groups `wheel, video, audio, input, storage, seat`, configures passwordless sudo in `/etc/sudoers.d/10-omarchy`, and enforces home permissions. |
| [`clone_omarchy_repo.sh`](file:///home/pi/projects/omarchy-pi5-quatro/desktop/clone_omarchy_repo.sh) | Clones `omarchy` repo (branch `quattro`) to `/opt/omarchy`, links 450+ binaries to `/usr/local/bin`, seeds dotfiles/themes (Tokyo Night default) to `/home/omarchy` and `/etc/skel`, injects Pi 5 VideoCore VII Hyprland environment parameters, and configures SDDM autologin. |
| [`install_desktop.sh`](file:///home/pi/projects/omarchy-pi5-quatro/desktop/install_desktop.sh) | Master orchestrator script that runs package installation, user provisioning, repository integration, and systemd service enablement. |

---

## 🎨 Omarchy Quattro Desktop Stack

- **Compositor**: Hyprland (Wayland) + Waybar + SDDM (theme: `omarchy`)
- **GPU Driver**: Broadcom VideoCore VII (`v3d` / `vc4-kms-v3d`) via Mesa and `vulkan-broadcom`
- **Audio**: PipeWire + WirePlumber + `pipewire-pulse` + `pipewire-alsa`
- **Shell**: Zsh / Bash with Fastfetch, Eza, Bat, Fzf, Ripgrep, Neovim, Tmux
- **Default Theme**: Tokyo Night Quattro with custom background wallpaper (`1-quattro.webp`)

---

## ⚡ Raspberry Pi 5 VideoCore VII Hyprland Optimizations

To ensure tear-free hardware-accelerated rendering and avoid scanout/modifier negotiation issues on Broadcom VideoCore VII (v3d 7.1), the following parameters are seeded into `/etc/environment.d/10-pi5-gpu.conf`, `/usr/share/uwsm/env.d/15-pi5-gpu`, `/opt/omarchy/default/hypr/pi5.lua`, and user configs:

- `WLR_DRM_NO_MODIFIERS=0`: Disables DRM modifier negotiation mismatches.
- `AQ_NO_MODIFIERS=0`: Aquamarine backend equivalent.
- `AQ_DRM_DEVICES=/dev/dri/card0`: Designates primary KMS VideoCore VII card.
- `WLR_NO_HARDWARE_CURSORS=1` & `cursor:no_hardware_cursors = true`: Prevents cursor flickering and DRM overlay corruption.
- `MESA_LOADER_DRIVER_OVERRIDE=v3d`: Enforces Broadcom V3D Gallium3D Mesa driver.
- `LIBGL_ALWAYS_SOFTWARE=0`: Enforces hardware 3D rendering.
- `WLR_RENDERER=gles2`: GLES2 compositor pipeline for VideoCore VII.

---

## 🚀 Execution Guide

### Direct / Chroot Provisioning
```bash
# Provision inside live system or target root
sudo ./desktop/install_desktop.sh [/path/to/target/root]

# Or execute stages individually:
sudo pacman -S --needed - < <(grep -v '^#' desktop/packages.list | grep -v '^[[:space:]]*$')
sudo ./desktop/setup_omarchy_user.sh [/path/to/target/root]
sudo ./desktop/clone_omarchy_repo.sh [/path/to/target/root]
```
