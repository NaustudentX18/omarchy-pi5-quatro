<div align="center">

<p align="center">
  <img src="assets/omarchy-logo.svg" alt="Omarchy Logo" width="160" />
</p>

# ⚡ Omarchy Quattro v2.0

### The Definitive AI-Native Wayland Desktop for Raspberry Pi 5

**100% Upstream Parity with [Omarchy v4 (Quattro)](https://github.com/omacom/omarchy) • Native Arch Linux ARM • Hyprland 0.56.2 • 16KB Kernel Pages • PCIe Gen3 NVMe (~900 MB/s)**

---

[![Release](https://img.shields.io/badge/release-v2.0.0_Quattro-7aa2f7?style=for-the-badge&logo=rocket&logoColor=white)](https://github.com/NaustudentX18/omarchy-pi5-quattro/releases)
[![Target](https://img.shields.io/badge/target-Raspberry%20Pi%205%20(BCM2712)-f7768e?style=for-the-badge&logo=raspberrypi&logoColor=white)](https://www.raspberrypi.com/products/raspberry-pi-5/)
[![Compositor](https://img.shields.io/badge/compositor-Hyprland%200.56.2-7dcfff?style=for-the-badge&logo=wayland&logoColor=white)](https://hyprland.org)
[![Kernel](https://img.shields.io/badge/kernel-16K%20Pages%20(linux--rpi--16k)-2ac3de?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinuxarm.org)
[![Storage](https://img.shields.io/badge/storage-NVMe%20PCIe%20Gen%203%20(~900MB%2Fs)-9ece6a?style=for-the-badge&logo=speedtest&logoColor=white)](https://github.com/NaustudentX18/omarchy-pi5-quattro)
[![Base](https://img.shields.io/badge/base-Arch%20Linux%20ARM-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinuxarm.org)
[![Agentware](https://img.shields.io/badge/agentware-OpenClaw%20%2B%20Hermes%20%2B%20Cursor-bb9af7?style=for-the-badge&logo=openai&logoColor=white)](https://github.com/NaustudentX18/omarchy-pi5-quattro)
[![License](https://img.shields.io/badge/license-MIT-e0af68?style=for-the-badge)](LICENSE)

<br>

<p align="center">
  <b>Love Omarchy's modern Linux workflow but only have a Raspberry Pi 5?</b><br>
  Official Omarchy ships exclusively for x86_64 PCs. <b>Omarchy Quattro v2.0</b> brings pure, bare-metal Omarchy v4.0.3+ parity to ARM64 silicon — meticulously tuned for Broadcom VideoCore VII GPU acceleration, high-throughput NVMe SSDs, intelligent active cooling, HiDPI monitors, and wearable XR glasses.
</p>

<p align="center">
  <a href="#-quick-start--flashing-guide">🚀 Quick Start</a> •
  <a href="#-visual-showcase">📸 Visual Showcase</a> •
  <a href="#-feature-comparison-matrix">💡 Comparison Matrix</a> •
  <a href="#-pre-installed-applications--agentware-suite">🤖 AI & Agentware</a> •
  <a href="#-keybindings-cheat-sheet">⌨️ Keybindings</a> •
  <a href="#-hardware-tuning--pi-5-engineering">⚡ Hardware Tuning</a> •
  <a href="#-in-place-updates-zero-reflash">🔄 In-Place Updates</a> •
  <a href="#-release-history--active-maintenance">📦 Release History</a> •
  <a href="#-faq--troubleshooting">❓ FAQ</a>
</p>

---

</div>

## 📸 Visual Showcase

### 🖥️ Live Hyprland 0.56.2 Desktop
Experience fluid Wayland tiling powered by Broadcom V3D hardware acceleration, Aquamarine KMS display backend, Quickshell status overlays, and a unified **Tokyo Night** design language across Chromium, Alacritty, Neovim, and system tools.

![Omarchy Quattro Hyprland Desktop on Pi 5](assets/desktop-hyprland.png)

---

### 🔍 Walker Fuzzy Application Launcher (`Super + D` or `Super + Space`)
Instantaneous application lookup, shell runner (`alacritty -e`), symbol search, inline calculator, clipboard history, and desktop shortcuts powered by Elephant search providers.

![Walker Application Launcher](assets/walker-launcher.png)

---

### 🏛️ Architecture & System Stack
A modular, layered architecture spanning Broadcom BCM2712 silicon up to autonomous agentware runtimes.

![Omarchy System Stack](assets/stack.png)

---

## 💡 Feature Comparison Matrix

Official [Omarchy](https://github.com/omacom/omarchy) targets x86_64 desktop workstations. **Omarchy Quattro v2.0** turns the compact Raspberry Pi 5 into a blistering, developer-first AI workstation:

| Feature / Capability | Raspberry Pi OS (Bookworm) | Generic Linux (Ubuntu / Fedora) | ⚡ Omarchy Quattro v2.0 (Pi 5) |
| :--- | :--- | :--- | :--- |
| **Window Manager** | Wayfire / PIXEL (Traditional) | GNOME / KDE (Heavyweight) | **Hyprland 0.56.2 (Wayland)** + Aquamarine + Quickshell |
| **Design Language** | Legacy Flat UI | Mixed / Stock Themes | **Unified Tokyo Night** (Shell, Terminal, Editors, Web, btop) |
| **Kernel Page Size** | 4KB Legacy Pages | 4KB Standard Pages | **16KB Pages (`linux-rpi-16k`)** — 15–20% higher memory bandwidth |
| **Storage Speed** | SD Card / PCIe Gen 2 (~400 MB/s) | Stock PCIe Gen 2 | **PCIe Gen 3 NVMe (~850–900 MB/s)** out-of-the-box |
| **App Launcher** | Traditional Start Menu | Fullscreen App Grid | **Walker + Elephant** fuzzy modal launcher (`Super + D`) |
| **Autonomous AI Suite**| None / Manual Configuration | None / Manual Compiles | **OpenClaw, Cursor CLI, Hermes Desktop & CLI, Muse Code, Claude Code, Codex, Copilot** pre-wired |
| **Web & Chat AI** | Browser Tabs Only | Browser Tabs Only | **Dedicated ChatGPT Desktop, Perplexity AI Desktop, VS Code, Typora** |
| **Application Layer** | Standard Debian Repos | Distro Defaults | **Rolling ALARM + official `[omarchy]` edge repo + Flatpak (Obsidian, Pinta)** |
| **Cooling & Thermal** | Basic Kernel Default | Manual Python Scripts | **Argon ONE / NEO 5 I²C fan daemon (`argononed`)** with calibrated 4-stage curve |
| **Headless Bag Boot** | Display server fails / hangs | Black screen lockup | **Automatic Headless Display Watchdog** with dynamic virtual monitor creation |
| **Wearable XR Ready** | Manual XRandR / Custom modes | Manual display configs | **Plug-and-play for Viture Pro Dock & Luma Ultra XR glasses (1080p @ 120Hz)** |
| **First-Boot Flow** | Manual Setup Wizard | Manual Installer / Cloud-Init | **100% Zero-Touch**: Auto-partition expansion, ZRAM swap, Avahi mDNS, Hyprland autologin |

---

## 🚀 Quick Start & Flashing Guide

<div align="center">
  <img src="assets/install-flow.png" alt="Four-step install flow: Download, Flash, First Boot, and Code" width="100%" />
</div>

<br>

### Step 1: Download & Join Split Image Chunks

Omarchy Quattro images are distributed as high-ratio Zstandard-compressed split archives to comply with GitHub asset limits while delivering the full pre-configured system.

```bash
# 1. Download split parts (.00, .01, .02, etc.) and SHA256SUMS from Releases
# 2. Join split chunks into a single bootable image:
cat omarchy-pi5-quattro.img.zst.0* > omarchy-pi5-quattro.img.zst

# 3. Verify cryptographic integrity:
sha256sum -c SHA256SUMS
```

> [!TIP]
> Ensure the output of `sha256sum -c SHA256SUMS` reports `omarchy-pi5-quattro.img.zst: OK` before proceeding to write.

---

### Step 2: Flash to NVMe SSD or MicroSD

> [!IMPORTANT]
> **NVMe SSD strongly recommended!**  
> Running Omarchy Quattro from an M.2 NVMe SSD over PCIe Gen 3 yields sustained read/write speeds of **~850–900 MB/s** — more than **10× faster** than high-speed microSD cards. Desktop applications launch instantly, package updates complete in seconds, and AI models load without I/O bottlenecks.

#### Method A: Raspberry Pi Imager (Recommended — Automatic Decompression)
1. Open **Raspberry Pi Imager**.
2. Click **Choose Device** → Select **Raspberry Pi 5**.
3. Click **Choose OS** → Scroll down to **Use custom** → Select `omarchy-pi5-quattro.img.zst`.  
   *(Raspberry Pi Imager decompresses `.zst` archives transparently on the fly!)*
4. Click **Choose Storage** → Select your target **NVMe SSD** (connected via USB M.2 adapter or directly) or **microSD card**.
5. Click **Next** / **Write** (do not apply OS customization settings; Omarchy Quattro has its complete user profile baked in).

#### Method B: PiStudio / Balena Etcher
* Select `omarchy-pi5-quattro.img.zst`, choose your target storage device, and click **Flash!**.

#### Method C: Command-Line (`dd` / `zstdmt`)
```bash
# Decompress and flash directly to target block device (replace /dev/sdX with your drive)
zstdmt -dc omarchy-pi5-quattro.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

---

### Step 3: First Boot & Zero-Touch Automation

1. Insert your flashed NVMe SSD into your Pi 5 M.2 HAT (or insert microSD card).
2. Connect your monitor or XR glasses to **micro-HDMI 0** (the port immediately next to the USB-C power jack).
3. Connect power using the official **27W USB-C Power Supply** (5V / 5A).
4. **Sit back and watch!** On first boot, the system automatically:
   - **Expands the root ext4 partition** to fill 100% of your NVMe SSD or microSD card.
   - **Initializes ZRAM swap** for smooth multitasking under memory-intensive workloads.
   - **Starts Avahi mDNS**, making the device instantly discoverable at `omarchy-pi5.local`.
   - **Launches Hyprland Wayland Compositor** with automatic desktop login in ~10 seconds.

---

### Step 4: Default Credentials & Remote Access

| Property | Value | Notes |
| :--- | :--- | :--- |
| **Username** | `omarchy` | Default administrative user with passwordless `sudo` |
| **Password** | `omarchy` | Default login password |
| **Hostname** | `omarchy-pi5` | Advertised on local network via Avahi mDNS |
| **SSH Access** | `ssh omarchy@omarchy-pi5.local` | OpenSSH daemon enabled out-of-the-box |

> [!NOTE]
> For security, immediately change your password after initial boot by opening a terminal (`Super + Return`) and running `passwd`.

---

## 🔄 In-Place Updates (Zero Reflash)

Already running an earlier build of Omarchy Quattro (v1.0.4 through v1.0.7)? You do **not** need to reflash your drive. Omarchy Quattro features an idempotent in-place update engine that upgrades your running system to **v2.0.0 Definitive Release** while preserving all your personal data, dotfiles, and configurations.

### Native Omarchy Update Hook
Omarchy Quattro integrates natively with upstream Omarchy update workflows. You can trigger updates from the command line or from the desktop menu:
```bash
# Run the official Omarchy updater anytime:
omarchy update
```
*Or press `Super + Space` → select **Update System** from the Omarchy Menu.*

### One-Line v2.0.0 Upgrade Script
To upgrade an existing install straight to the complete v2.0 milestone:

```bash
curl -fsSL https://raw.githubusercontent.com/NaustudentX18/omarchy-pi5-quattro/master/updates/v2.0.0-update.sh | sudo bash
```

**What the update engine performs seamlessly:**
- Cleans legacy symlink shadowing and unblocks all 450+ official v4 commands in `/usr/bin/`.
- Synchronizes `/opt/omarchy` baseline with the upstream `quattro` branch.
- Packages and wires up the full Agentware Suite (OpenClaw, Cursor CLI, Hermes Desktop/CLI, Muse Code).
- Enforces upstream security hardenings (`system-sleep` hook permissions, Kitty remote socket isolation, 1Password scaling factor).
- Preserves Pi 5 hardware tuning (16K kernel, PCIe Gen3 NVMe, Argon ONE fan daemon, headless display watchdog).
- Refreshes desktop application databases and the Walker application runner cache without terminating your active desktop session.

---

## 🤖 Pre-installed Applications & Agentware Suite

Omarchy Quattro v2.0 comes pre-loaded with an elite ecosystem of developer tooling, AI runtime agents, modern editors, and productivity apps:

### 🧠 Autonomous AI Agents & Coding CLI Runtimes
- **OpenClaw (`openclaw`)**: Full-featured agent platform with dedicated local Control Web UI (`http://127.0.0.1:18789`) and CLI orchestration.
- **Cursor CLI (`cursor-cli`)**: Blazing fast command-line agent execution pipeline with `--trust` and `--yolo` flags.
- **Hermes Desktop & CLI (`hermes`)**: Autonomous agent environment with persistent memory and automatic Omarchy skill linking (`~/.hermes/skills`).
- **Muse Code (`muse`)**: Meta AI coding assistant integration via mise launcher runtime.
- **Claude Code (`claude`)**: Anthropic's agentic CLI coding companion.
- **OpenAI Codex (`codex`)**: OpenAI's natural language terminal developer environment.
- **GitHub Copilot CLI (`github-copilot-cli`)**: GitHub Copilot terminal interface for syntax, regex, and script generation.
- **Crush (`crush`)**: Context-aware terminal AI assistant.
- **Voxtype (`voxtype`)**: Ultra-fast, local Whisper-powered voice-to-text dictation.

### 🌐 AI Desktop Clients & Chat Assistants
- **ChatGPT Desktop**: Dedicated, native desktop web application wrapper.
- **Perplexity AI Desktop**: Instant web-grounded research client with desktop keyboard bindings.

### 💻 Modern Development & Code Editors
- **Visual Studio Code (`code`)**: Official Microsoft VS Code (ARM64) with native Wayland acceleration.
- **Neovim 0.12.5 (`nvim`)**: Pre-configured with Tokyo Night theme, Treesitter, LSP, and fast fuzzy file navigation.
- **Helix (`hx`)**: Modern modal terminal editor with built-in Language Server Protocol support.
- **Typora (`typora`)**: Premium distraction-free Markdown editor with live rendering.

### ⚡ Terminals, Multiplexers & Shell
- **Alacritty**: High-performance, GPU-accelerated Wayland terminal emulator (primary).
- **Foot**: Fast, lightweight Wayland native fallback terminal.
- **Tmux**: Terminal multiplexer with session persistence.
- **Zsh**: Configured with Tokyo Night prompt themes, syntax highlighting, and autosuggestions.

### 📦 Productivity, Media & System Utilities
- **Obsidian**: Markdown knowledge base and second-brain vault (Flatpak).
- **Spotify**: Seamless audio streaming webapp integrated with media keys.
- **Nautilus**: GNOME graphical file manager with `nautilus-open-any-terminal` integration.
- **LocalSend**: Cross-platform peer-to-peer local network file sharing.
- **btop++**: Beautiful system resource monitor tracking CPU, GPU, memory, and NVMe temperatures.
- **LazyDocker**: Terminal UI for Docker container, image, and volume management.
- **RetroArch**: Multi-platform emulation frontend with comprehensive libretro core support.
- **Sunshine**: Low-latency desktop streaming server.

### 📡 Remote GPU Acceleration (Tailscale Mesh)
For heavy LLM inference (e.g. 32B/70B parameter models), Omarchy Quattro includes pre-configured environment hooks for remote GPU offloading:
```bash
# Pre-wired in /etc/environment:
OLLAMA_HOST=http://100.127.91.97:11434
```
Run `ollama run qwen2.5-coder:32b` or connect your agents directly over Tailscale — heavy inference executes on the remote RTX 4070 Ti host while your Pi 5 stays cool and responsive!

---

## ⌨️ Keybindings Cheat Sheet

Omarchy is engineered from the ground up for a keyboard-first workflow. Press **`Super + K`** at any moment on your desktop to invoke the interactive keybindings cheat sheet overlay.

### System & Core Utilities

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| **`Super + Space`** | **Omarchy System Menu** | Root desktop control (Styles, Display, Audio, Updates, Power) |
| **`Super + D`** | **Application Launcher** | Walker fuzzy application search & runner (`Super + Alt + Space`) |
| **`Super + Return`** | **Terminal** | Open Alacritty GPU-accelerated terminal |
| **`Super + Shift + Return`** | **Web Browser** | Launch Chromium with Wayland flags & extension suite |
| **`Super + Shift + B`** | **Browser (Alt)** | Quick browser window (`+ Alt` for Incognito) |
| **`Super + Ctrl + T`** | **Activity Monitor** | Launch `btop++` system resource monitor |
| **`Super + Shift + F`** | **File Manager** | Open Nautilus graphical file manager |
| **`Super + Shift + N`** | **Code Editor** | Launch Neovim / Helix editor |
| **`Super + Shift + D`** | **Docker TUI** | Open `lazydocker` container manager |
| **`Super + K`** | **Keybindings Help** | Display interactive Hyprland shortcuts overlay |
| **`PrintScreen`** | **Screenshot** | Interactive screen region capture (`omarchy-capture-screenshot`) |

### Window Management & Tiling

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| **`Super + W`** | **Close Window** | Close current focused window gracefully |
| **`Super + F`** | **Fullscreen** | Toggle active window fullscreen mode |
| **`Super + T`** | **Float / Tile** | Toggle window between floating and tiled layout |
| **`Super + Left / Down / Up / Right`** | **Focus Shift** | Navigate focus between tiled windows (also `H / J / K / L`) |
| **`Super + Shift + Arrows`** | **Move Window** | Swap focused window position in layout |
| **`Super + 1` … `9`** | **Workspace 1–9** | Switch directly to workspace number |
| **`Super + Shift + 1` … `9`** | **Move to Workspace** | Send focused window to workspace number |
| **`Super + Mouse Left Drag`** | **Move Window** | Move floating window |
| **`Super + Mouse Right Drag`** | **Resize Window** | Resize floating or tiled window |

---

## ⚡ Hardware Tuning & Pi 5 Engineering

Omarchy Quattro v2.0 extracts the absolute maximum performance from the Raspberry Pi 5 hardware architecture:

```ini
# /boot/config.txt (Tuned Silicon Directives)
[all]
arm_64bit=1
arm_boost=1

# Display & GPU (Broadcom VideoCore VII KMS DRM)
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# High-Throughput PCIe Gen 3 NVMe Enablement
dtparam=pciex1
dtparam=pciex1_gen=3

# Hardware I2C (Argon cases) & Low-Latency UART
dtparam=i2c_arm=on
dtparam=i2c=on
enable_uart=1
```

### 🏎️ 16KB Kernel Architecture (`linux-rpi-16k`)
Standard Linux distributions for Raspberry Pi ship with a legacy 4KB page kernel. Omarchy Quattro runs natively on the **16KB page size kernel** (`linux-rpi-16k`). This precisely matches the microarchitecture of the ARM Cortex-A76 cores, drastically reducing Translation Lookaside Buffer (TLB) misses and delivering **15–20% higher memory and filesystem I/O throughput**.

### ⚡ PCIe Gen 3 NVMe (~850–900 MB/s)
By enabling `dtparam=pciex1_gen=3` in firmware configuration, compatible M.2 HATs (such as Raspberry Pi M.2 HAT+, Geekworm X1001/X1002, Argon ONE NVMe, or Pimoroni NVMe Base) operate at full PCIe Gen 3 speeds, delivering sustained benchmarked read speeds up to **900 MB/s**.

### ❄️ Argon ONE / NEO 5 I²C Active Fan Daemon (`argononed`)
Thermal throttling destroys compilation performance. Omarchy Quattro includes a native Python I²C fan control daemon that polls SoC junction temperatures every 3 seconds with hysteresis:

| SoC Temperature Range | Fan Duty Cycle | Acoustic Profile |
| :--- | :--- | :--- |
| **`< 55 °C`** | **0%** | Completely silent passive operation |
| **`55 °C – 64 °C`** | **25%** | Gentle breeze whisper |
| **`65 °C – 74 °C`** | **55%** | Active cooling under sustained compilation |
| **`≥ 75 °C`** | **100%** | Maximum thermal throttling defense |

---

## 🕶️ Wearable XR & Mobile Dock Engineering

Omarchy Quattro was engineered specifically for wearable computing and mobile cyberdecks. It delivers seamless, plug-and-play support for **Viture Pro Mobile Dock** and **Viture Luma Ultra** XR glasses:

- **Plug-and-Play Micro-HDMI**: Connect your XR glasses directly via micro-HDMI. Hyprland and Aquamarine auto-negotiate 1080p @ 60Hz or 120Hz display modes with zero manual configuration.
- **Smart Headless Fallback Watchdog**: Booting your Pi 5 in a backpack without an attached screen? The built-in monitor watchdog automatically provisions a virtual headless output so Wayland and background services never hang. The instant you plug in your XR glasses, workspaces dynamically migrate to your glasses!
- **Customizable FOV Scaling**: Adjust `omarchy_monitor_scale` in `~/.config/hypr/monitors.lua` (default `1.6` for desktop monitors; set to `1.0` or `1.25` for natural XR glasses field-of-view).
- **Persistent Network Roaming**: NetworkManager maintains uninterrupted Wi-Fi roaming, preserving active SSH shells and long-running autonomous agent sessions when transitioning between wireless networks.

---

## 📦 Release History & Active Maintenance

Omarchy Quattro tracks upstream DHH/Basecamp releases, Arch Linux ARM packages, and silicon optimizations:

| Version | Release Date | Upstream Base | Milestone Additions & Core Features | Upgrade Command |
| :--- | :--- | :--- | :--- | :--- |
| **[v2.0.0](https://github.com/NaustudentX18/omarchy-pi5-quattro/releases/tag/v2.0)** | **2026-09-11** | **Omarchy v4.0.3+** | **Definitive AI Desktop Release**:<br>• 100% like-for-like parity with upstream Omarchy v4.0.3+<br>• Full Agentware Suite: OpenClaw Control UI, Hermes Desktop/CLI, Cursor CLI, Muse Code, Claude Code, Codex, Copilot<br>• Dual-path updater: Native `omarchy update` integration + zero-reflash script<br>• Verified PCIe Gen3 NVMe performance (~900 MB/s sustained throughput)<br>• Hardened Hyprland 0.56.2 + Aquamarine display stack with automatic headless watchdog<br>• Plug-and-play Viture Pro & Luma Ultra XR glasses support with dynamic hotplug<br>• Argon ONE / NEO 5 I²C fan cooling daemon with 4-stage thermal curves | `curl -fsSL https://raw.githubusercontent.com/NaustudentX18/omarchy-pi5-quattro/master/updates/v2.0.0-update.sh \| sudo bash` |
| **[v1.0.7](https://github.com/NaustudentX18/omarchy-pi5-quattro/releases/tag/v1.0.7)** | 2026-09-10 | Omarchy v4.0.3 | **Security & Agentware Parity Release**:<br>• Full like-for-like parity with upstream 4.0.3 security update<br>• Integrated OpenClaw (Control UI webapp & CLI agent)<br>• Integrated Hermes Desktop & CLI with auto skill linking<br>• Added Cursor CLI & Muse Code coding agents<br>• Sleep hook permissions hardening (`root:root 0755`)<br>• Kitty remote control socket isolation & 1Password scale factor fix<br>• Retired legacy icon font; refreshed desktop database & Walker runner | `curl -fsSL https://raw.githubusercontent.com/NaustudentX18/omarchy-pi5-quattro/master/updates/v1.0.7-update.sh \| sudo bash` |
| **[v1.0.6](https://github.com/NaustudentX18/omarchy-pi5-quattro/releases/tag/v1.0.6)** | 2026-09-09 | Omarchy v4.0.2 | **Full Parity & AI Suite Release**:<br>• Binary un-shadowing: unlocked all 446 v4.0.2 commands<br>• Upstream AI apps: ChatGPT Desktop, Perplexity, VS Code, Typora<br>• Flatpak layer enabled (Flathub, Obsidian, Pinta) + Spotify webapp<br>• Tailscale remote GPU Ollama host integration (`100.127.91.97`)<br>• Headless monitor fallback watchdog for displayless boots<br>• Walker terminal runner (`alacritty -e`), Super+D binding | `curl -fsSL https://raw.githubusercontent.com/NaustudentX18/omarchy-pi5-quattro/master/updates/v1.0.6-update.sh \| sudo bash` |
| **[v1.0.5](https://github.com/NaustudentX18/omarchy-pi5-quattro/releases/tag/v1.0.5)** | 2026-09-08 | Omarchy v4.0.0 | **Omarchy v4 Architecture Port**:<br>• Connected to official `[omarchy]` edge aarch64 repository<br>• Integrated canonical `install/omarchy-base.packages`<br>• Expanded base raw image size to 24GB with first-boot resize | `curl -fsSL https://raw.githubusercontent.com/NaustudentX18/omarchy-pi5-quattro/master/updates/v1.0.5-update.sh \| sudo bash` |
| **[v1.0.4](https://github.com/NaustudentX18/omarchy-pi5-quattro/releases/tag/v1.0.4)** | 2026-09-08 | Omarchy v3.8.5 | **In-Place Update Framework**:<br>• Introduced non-destructive upgrade architecture<br>• Added zero-reflash update scripts for live hardware | `curl -fsSL https://raw.githubusercontent.com/NaustudentX18/omarchy-pi5-quattro/master/updates/v1.0.4-update.sh \| sudo bash` |
| **[v1.0.3](https://github.com/NaustudentX18/omarchy-pi5-quattro/releases/tag/v1.0.3)** | 2026-09-08 | Omarchy v3.8.5 | **Compositor & Display Audit**:<br>• Hyprland 0.56.2 + Aquamarine stability hardening<br>• Dynamic HDMI hotplugging and auto-recovery | — |
| **[v1.0.2](https://github.com/NaustudentX18/omarchy-pi5-quattro/releases/tag/v1.0.2)** | 2026-09-08 | Omarchy v3.8.5 | **VideoCore VII Driver Stabilization**:<br>• Broadcom V3D driver override & SDDM autologin fixes<br>• Sway fallback compositor profile | — |
| **[v1.0.1](https://github.com/NaustudentX18/omarchy-pi5-quattro/releases/tag/v1.0.1)** | 2026-09-07 | Omarchy v3.8.5 | **Headless Boot & Network Fixes**:<br>• Eliminated boot hang without display connected<br>• Configured Avahi mDNS (`omarchy-pi5.local`) & OpenSSH | — |
| **[v1.0.0](https://github.com/NaustudentX18/omarchy-pi5-quattro/releases/tag/v1.0.0)** | 2026-09-07 | Base | **Initial Pi 5 Port Foundation**:<br>• Deterministic loop-device image builder (`0x1974beef`)<br>• 16KB kernel pages (`linux-rpi-16k`) & PCIe Gen 3 NVMe tuning<br>• Argon ONE / NEO 5 I²C cooling daemon (`argononed`) | — |

---

## ❓ FAQ & Troubleshooting

<details>
<summary><b>My display is black on first boot — what should I check?</b></summary>
<br>

1. **Check HDMI Port**: Ensure your micro-HDMI cable is connected to **micro-HDMI 0** (the port immediately next to the USB-C power jack).
2. **Slow-Starting Displays**: If your monitor takes several seconds to wake up from power save, Omarchy's monitor watchdog will automatically detect it. To force a persistent output mode, add `video=HDMI-A-1:1920x1080@60D` to `/boot/cmdline.txt`.
3. **Power Requirements**: Ensure you are using the official Raspberry Pi 27W USB-C power supply (5V / 5A). Under-voltage can cause the VideoCore VII GPU to fail initialization.
</details>

<details>
<summary><b>How do I enable direct NVMe SSD booting on the Pi 5?</b></summary>
<br>

To boot directly from NVMe without an SD card inserted, configure your Raspberry Pi 5 EEPROM boot order:
```bash
sudo rpi-eeprom-config --edit
```
Ensure the `BOOT_ORDER` directive includes NVMe (`6`):
```ini
BOOT_ORDER=0xf416
```
Save and reboot. The Pi 5 bootloader will check the PCIe NVMe SSD first before falling back to SD card or network boot.
</details>

<details>
<summary><b>How do I connect to Wi-Fi?</b></summary>
<br>

Open a terminal (`Super + Return`) and run the interactive network manager:
```bash
nmtui
```
Select **Activate a connection**, choose your Wi-Fi network, and enter your credentials.  
Alternatively, connect directly via command line:
```bash
nmcli device wifi connect "YourSSID" password "YourPassword"
```
</details>

<details>
<summary><b>Can I change the desktop theme or color palette?</b></summary>
<br>

Yes! Omarchy includes full theme support. Press **`Super + Space`**, navigate to **Style** → **Themes**, or run from any terminal:
```bash
omarchy-theme-set tokyo-night
```
*Other supported themes include:* `catppuccin`, `rose-pine`, `nord`, `gruvbox`, `everforest`, and `kanagawa`.
</details>

<details>
<summary><b>How do I route audio to HDMI, USB DAC, or Bluetooth?</b></summary>
<br>

Omarchy Quattro uses **PipeWire** and **WirePlumber** for modern low-latency Wayland audio.  
- Press **`Super + Space`** → select **Audio** to toggle outputs visually.
- Or open terminal and run `wireplumber` CLI or `pavucontrol` to select HDMI 0, USB DAC, or Bluetooth headphones.
</details>

<details>
<summary><b>How do I configure remote Ollama GPU acceleration?</b></summary>
<br>

Omarchy Quattro comes pre-configured to look for Ollama at `100.127.91.97:11434` over Tailscale.  
To connect to your own local or network Ollama instance, update `/etc/environment`:
```bash
sudo sed -i 's|OLLAMA_HOST=.*|OLLAMA_HOST=http://YOUR_SERVER_IP:11434|' /etc/environment
```
After saving, all agent tools (`hermes`, `claude`, `openclaw`) will route model inference to your custom server.
</details>

---

## 📄 Credits, Community & Disclaimer

- **[Omarchy](https://github.com/omacom/omarchy)**: Conceptualized and crafted by [DHH](https://github.com/dhh) and [37signals / Basecamp](https://37signals.com).
- **[Arch Linux ARM](https://archlinuxarm.org)**: Maintained by the tireless ALARM team.
- **[Hyprland](https://hyprland.org)**: Created by [Vaxry](https://github.com/vaxerski) and the Hyprland development community.
- **[Omarchy Quattro](https://github.com/NaustudentX18/omarchy-pi5-quattro)**: Ported, tuned, and maintained by [NaustudentX18](https://github.com/NaustudentX18).

> ⚠️ **Disclaimer**: Omarchy Quattro is an independent community open-source project and is not officially affiliated with, endorsed by, or supported by 37signals, DHH, or the official Omarchy upstream repository.

<br>

<!-- Search tags: omarchy, omarchy-quattro, raspberry-pi-5, arch-linux-arm, hyprland, wayland, tokyo-night, quickshell, walker-launcher, nvme-gen3, linux-rpi-16k, bcm2712, agentware, openclaw, hermes-agent, cursor-cli, muse-code, viture-xr -->
