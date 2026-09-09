#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quattro Pi 5 - Desktop & Repository Integrator
# Target: Raspberry Pi 5 (Arch Linux ARM)
# ==============================================================================
# Clones Omarchy repository (branch 'quattro') into /opt/omarchy, links binaries,
# seeds Omarchy Quattro dotfiles, themes, and configs into /home/omarchy/.config
# and /etc/skel, configures Pi 5 VideoCore VII GPU env for sway-compatible Wayland compositors,
# and configures SDDM autologin.
#
# Usage:
#   sudo ./clone_omarchy_repo.sh [TARGET_ROOT]
# ==============================================================================

set -euo pipefail

TARGET_ROOT="${1:-/}"
OMARCHY_REPO_URL="${OMARCHY_REPO_URL:-https://github.com/omacom/omarchy.git}"
OMARCHY_BRANCH="${OMARCHY_BRANCH:-master}"
# Optional: pin to a specific commit for reproducible builds.
# Leave empty to always pull the latest commit on OMARCHY_BRANCH.
OMARCHY_PIN_SHA="${OMARCHY_PIN_SHA:-}"
OMARCHY_INSTALL_DIR="${TARGET_ROOT}/opt/omarchy"
USERNAME="omarchy"
USER_HOME="${TARGET_ROOT}/home/${USERNAME}"
SKEL_DIR="${TARGET_ROOT}/etc/skel"

echo "=== [Omarchy Quattro] Desktop & Repository Provisioning ==="
echo "Target root: ${TARGET_ROOT}"
echo "Omarchy directory: ${OMARCHY_INSTALL_DIR}"

# ------------------------------------------------------------------------------
# 1. Clone or update Omarchy Quattro repository
# ------------------------------------------------------------------------------
echo "[+] Syncing Omarchy repository (branch: ${OMARCHY_BRANCH})..."
mkdir -p "${TARGET_ROOT}/opt"

if [[ -d "${OMARCHY_INSTALL_DIR}/.git" ]]; then
    echo "    Repository already present at ${OMARCHY_INSTALL_DIR}. Updating branch ${OMARCHY_BRANCH} from ${OMARCHY_REPO_URL}..."
    git -C "${OMARCHY_INSTALL_DIR}" fetch --depth 1 origin "${OMARCHY_BRANCH}"
    git -C "${OMARCHY_INSTALL_DIR}" checkout -B "${OMARCHY_BRANCH}" "origin/${OMARCHY_BRANCH}"
    git -C "${OMARCHY_INSTALL_DIR}" reset --hard "origin/${OMARCHY_BRANCH}"
else
    echo "    Cloning ${OMARCHY_REPO_URL} (${OMARCHY_BRANCH}) into ${OMARCHY_INSTALL_DIR}..."
    rm -rf "${OMARCHY_INSTALL_DIR}"
    git clone --depth 1 --branch "${OMARCHY_BRANCH}" "${OMARCHY_REPO_URL}" "${OMARCHY_INSTALL_DIR}"
fi

# Optional SHA pinning for reproducible builds
if [[ -n "${OMARCHY_PIN_SHA}" ]]; then
    echo "    Pinning Omarchy checkout to SHA ${OMARCHY_PIN_SHA}..."
    git -C "${OMARCHY_INSTALL_DIR}" checkout "${OMARCHY_PIN_SHA}"
fi
RESOLVED_SHA="$(git -C "${OMARCHY_INSTALL_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"
echo "    Resolved Omarchy commit: ${RESOLVED_SHA}"

# Ensure proper permissions across /opt/omarchy
chmod -R a+rX "${OMARCHY_INSTALL_DIR}"

# Ensure /usr/share/omarchy points to /opt/omarchy only if not already provided as a directory by the package
if [[ ! -d "${TARGET_ROOT}/usr/share/omarchy" || -L "${TARGET_ROOT}/usr/share/omarchy" ]]; then
    mkdir -p "${TARGET_ROOT}/usr/share"
    ln -snf /opt/omarchy "${TARGET_ROOT}/usr/share/omarchy"
fi

# Set system Omarchy configuration
mkdir -p "${TARGET_ROOT}/etc/environment.d"
echo "OMARCHY_PATH=/usr/share/omarchy" >> "${TARGET_ROOT}/etc/environment"
echo "OMARCHY_PATH=/usr/share/omarchy" > "${TARGET_ROOT}/etc/environment.d/10-omarchy.conf"

mkdir -p "${TARGET_ROOT}/etc/profile.d"
cat <<'EOF' > "${TARGET_ROOT}/etc/profile.d/omarchy.sh"
# Omarchy Quattro system profile
export OMARCHY_PATH=/usr/share/omarchy
if [ -d "${OMARCHY_PATH}/bin" ]; then
    case ":${PATH}:" in
        *:"${OMARCHY_PATH}/bin":*) ;;
        *) export PATH="${OMARCHY_PATH}/bin:${PATH}" ;;
    esac
fi
EOF
chmod 0644 "${TARGET_ROOT}/etc/profile.d/omarchy.sh"

# ------------------------------------------------------------------------------
# 2. Link Omarchy binaries in /opt/omarchy/bin/ to /usr/local/bin/ (fallback only)
# ------------------------------------------------------------------------------
if [[ ! -x "${TARGET_ROOT}/usr/bin/omarchy" && -d "${OMARCHY_INSTALL_DIR}/bin" ]]; then
    echo "[+] Linking Omarchy binaries to /usr/local/bin (fallback mode)..."
    mkdir -p "${TARGET_ROOT}/usr/local/bin"
    chmod +x "${OMARCHY_INSTALL_DIR}/bin"/* 2>/dev/null || true
    for bin_path in "${OMARCHY_INSTALL_DIR}/bin"/*; do
        if [[ -f "${bin_path}" && -x "${bin_path}" ]]; then
            bin_name="$(basename "${bin_path}")"
            ln -sf "/opt/omarchy/bin/${bin_name}" "${TARGET_ROOT}/usr/local/bin/${bin_name}"
        fi
    done
    echo "    Linked $(find "${OMARCHY_INSTALL_DIR}/bin" -mindepth 1 -maxdepth 1 | wc -l) Omarchy binaries."
else
    echo "[+] Packaged /usr/bin/omarchy is present — skipping /usr/local/bin symlinks to prevent binary shadowing."
fi

# NOTE: No compositor shim is installed here. Sway ships its own
# /usr/bin/sway; SDDM selects it via the sway.desktop wayland session
# entry. Hyprland, when ALARM catches up, would be selected via its
# own desktop file (created if `pacman -S hyprland` lands a binary).

# ------------------------------------------------------------------------------
# 3. Seed Omarchy Quattro dotfiles, configs, and themes
# ------------------------------------------------------------------------------
echo "[+] Seeding Omarchy dotfiles and configurations..."

mkdir -p "${SKEL_DIR}/.config"
mkdir -p "${USER_HOME}/.config"
mkdir -p "${SKEL_DIR}/.local/share/applications"
mkdir -p "${USER_HOME}/.local/share/applications"
mkdir -p "${TARGET_ROOT}/usr/share/applications"

# Copy base configs from /opt/omarchy/config
if [[ -d "${OMARCHY_INSTALL_DIR}/config" ]]; then
    echo "    Copying config trees to /etc/skel and ${USER_HOME}..."
    cp -a "${OMARCHY_INSTALL_DIR}/config/." "${SKEL_DIR}/.config/"
    cp -a "${OMARCHY_INSTALL_DIR}/config/." "${USER_HOME}/.config/"
fi

# Copy shell and user defaults from /opt/omarchy/default
if [[ -d "${OMARCHY_INSTALL_DIR}/default" ]]; then
    # Bash defaults
    if [[ -f "${OMARCHY_INSTALL_DIR}/default/bashrc" ]]; then
        cp "${OMARCHY_INSTALL_DIR}/default/bashrc" "${SKEL_DIR}/.bashrc"
        cp "${OMARCHY_INSTALL_DIR}/default/bashrc" "${USER_HOME}/.bashrc"
    fi

    # XCompose
    if [[ -f "${OMARCHY_INSTALL_DIR}/default/xcompose" ]]; then
        cp "${OMARCHY_INSTALL_DIR}/default/xcompose" "${SKEL_DIR}/.XCompose"
        cp "${OMARCHY_INSTALL_DIR}/default/xcompose" "${USER_HOME}/.XCompose"
    fi

    # Fontconfig
    if [[ -d "${OMARCHY_INSTALL_DIR}/default/fontconfig/conf.avail" ]]; then
        mkdir -p "${TARGET_ROOT}/usr/share/fontconfig/conf.avail"
        mkdir -p "${TARGET_ROOT}/etc/fonts/conf.d"
        cp -a "${OMARCHY_INSTALL_DIR}/default/fontconfig/conf.avail/." "${TARGET_ROOT}/usr/share/fontconfig/conf.avail/"
        ln -sf /usr/share/fontconfig/conf.avail/50-omarchy.conf "${TARGET_ROOT}/etc/fonts/conf.d/50-omarchy.conf" 2>/dev/null || true
    fi

    # Fonts
    if [[ -d "${OMARCHY_INSTALL_DIR}/default/fonts" ]]; then
        mkdir -p "${TARGET_ROOT}/usr/share/fonts/omarchy"
        cp -a "${OMARCHY_INSTALL_DIR}/default/fonts/." "${TARGET_ROOT}/usr/share/fonts/omarchy/"
    fi

    # UWSM environment defaults
    if [[ -d "${OMARCHY_INSTALL_DIR}/default/uwsm/env.d" ]]; then
        mkdir -p "${TARGET_ROOT}/usr/share/uwsm/env.d"
        cp -a "${OMARCHY_INSTALL_DIR}/default/uwsm/env.d/." "${TARGET_ROOT}/usr/share/uwsm/env.d/"
    fi

    # Wayland sessions
    if [[ -d "${OMARCHY_INSTALL_DIR}/default/wayland-sessions" ]]; then
        mkdir -p "${TARGET_ROOT}/usr/share/wayland-sessions"
        cp -a "${OMARCHY_INSTALL_DIR}/default/wayland-sessions/." "${TARGET_ROOT}/usr/share/wayland-sessions/"
    fi
fi

# Applications desktop entries
if [[ -d "${OMARCHY_INSTALL_DIR}/applications" ]]; then
    cp -a "${OMARCHY_INSTALL_DIR}/applications/." "${SKEL_DIR}/.local/share/applications/" 2>/dev/null || true
    cp -a "${OMARCHY_INSTALL_DIR}/applications/." "${USER_HOME}/.local/share/applications/" 2>/dev/null || true
    cp -a "${OMARCHY_INSTALL_DIR}/applications/." "${TARGET_ROOT}/usr/share/applications/" 2>/dev/null || true
fi

# Generate default webapps desktop entries (ChatGPT, Discord, YouTube, GitHub, etc.)
if [[ -f "${OMARCHY_INSTALL_DIR}/install/packaging/webapps.sh" ]]; then
    echo "    Generating default Omarchy webapp launchers..."
    HOME="${USER_HOME}" bash "${OMARCHY_INSTALL_DIR}/install/packaging/webapps.sh" 2>/dev/null || true
    HOME="${SKEL_DIR}" bash "${OMARCHY_INSTALL_DIR}/install/packaging/webapps.sh" 2>/dev/null || true
fi

# Icons & Pixmaps
mkdir -p "${TARGET_ROOT}/usr/share/pixmaps"
mkdir -p "${TARGET_ROOT}/usr/share/icons/hicolor/256x256/apps"
if [[ -f "${OMARCHY_INSTALL_DIR}/icon.png" ]]; then
    cp "${OMARCHY_INSTALL_DIR}/icon.png" "${TARGET_ROOT}/usr/share/pixmaps/omarchy.png"
    cp "${OMARCHY_INSTALL_DIR}/icon.png" "${TARGET_ROOT}/usr/share/icons/hicolor/256x256/apps/omarchy.png"
fi

# Ensure all system applications and icon directories are world-readable
chmod -R a+rX "${TARGET_ROOT}/usr/share/applications" "${TARGET_ROOT}/usr/share/pixmaps" "${TARGET_ROOT}/usr/share/icons" 2>/dev/null || true


# ------------------------------------------------------------------------------
# 4. Themes Seeding and Activation (Tokyo Night Default)
# ------------------------------------------------------------------------------
echo "[+] Seeding themes and setting Tokyo Night default..."
if [[ -d "${OMARCHY_INSTALL_DIR}/themes" ]]; then
    mkdir -p "${TARGET_ROOT}/usr/share/omarchy/themes"
    cp -a "${OMARCHY_INSTALL_DIR}/themes/." "${TARGET_ROOT}/usr/share/omarchy/themes/"

    for dest in "${USER_HOME}" "${SKEL_DIR}"; do
        mkdir -p "${dest}/.config/omarchy/themes"
        cp -a "${OMARCHY_INSTALL_DIR}/themes/." "${dest}/.config/omarchy/themes/"

        mkdir -p "${dest}/.local/state/omarchy/current"
        echo "Tokyo Night" > "${dest}/.local/state/omarchy/current/theme.name"
        ln -snf "/opt/omarchy/themes/tokyo-night" "${dest}/.local/state/omarchy/current/theme"

        # Background selection
        if [[ -f "${OMARCHY_INSTALL_DIR}/themes/tokyo-night/backgrounds/1-quattro.webp" ]]; then
            ln -snf "/opt/omarchy/themes/tokyo-night/backgrounds/1-quattro.webp" "${dest}/.local/state/omarchy/current/background"
        elif [[ -f "${OMARCHY_INSTALL_DIR}/themes/tokyo-night/backgrounds/0-winding-road.webp" ]]; then
            ln -snf "/opt/omarchy/themes/tokyo-night/backgrounds/0-winding-road.webp" "${dest}/.local/state/omarchy/current/background"
        fi

        # Btop theme link
        mkdir -p "${dest}/.config/btop/themes"
        ln -snf "${dest}/.local/state/omarchy/current/theme/btop.theme" "${dest}/.config/btop/themes/current.theme" 2>/dev/null || true
    done
fi

# ------------------------------------------------------------------------------
# 5. Pi 5 VideoCore VII GPU environment (sway-compatible)
# ------------------------------------------------------------------------------
echo "[+] Configuring Pi 5 VideoCore VII GPU environment (sway-compatible)..."

# No pi5.lua or envs.lua injection: sway reads no custom Pi 5 config.
# Pi 5 VideoCore VII acceleration is handled via /etc/environment.d/10-pi5-gpu.conf
# and the Mesa v3d driver default.

# System-wide GPU environment configurations.
# Sway-applicable vars only. AQ_* / WLR_NO_HARDWARE_CURSORS / WLR_RENDERER are
# wlroots-only and read by sway; the rest are general Wayland env.
mkdir -p "${TARGET_ROOT}/etc/environment.d"
cat <<'EOF' > "${TARGET_ROOT}/etc/environment.d/10-pi5-gpu.conf"
# Omarchy Quattro Pi 5 VideoCore VII Environment (Hyprland / Aquamarine + Sway)
AQ_DRM_DEVICES=/dev/dri/card1:/dev/dri/card0
AQ_NO_MODIFIERS=1
MESA_LOADER_DRIVER_OVERRIDE=v3d
LIBGL_ALWAYS_SOFTWARE=0
WLR_RENDERER=gles2
WLR_NO_HARDWARE_CURSORS=1
EGL_PLATFORM=wayland
QT_QPA_PLATFORM=wayland;xcb
GDK_BACKEND=wayland,x11,*
ELECTRON_OZONE_PLATFORM_HINT=wayland
EOF

mkdir -p "${TARGET_ROOT}/usr/share/uwsm/env.d"
cat <<'EOF' > "${TARGET_ROOT}/usr/share/uwsm/env.d/15-pi5-gpu"
export AQ_DRM_DEVICES=/dev/dri/card1:/dev/dri/card0
export AQ_NO_MODIFIERS=1
export MESA_LOADER_DRIVER_OVERRIDE=v3d
export LIBGL_ALWAYS_SOFTWARE=0
export WLR_RENDERER=gles2
export WLR_NO_HARDWARE_CURSORS=1
export EGL_PLATFORM=wayland
export QT_QPA_PLATFORM=wayland;xcb
export GDK_BACKEND=wayland,x11,*
export ELECTRON_OZONE_PLATFORM_HINT=wayland
EOF

cat <<'EOF' > "${TARGET_ROOT}/etc/profile.d/10-pi5-gpu.sh"
# Raspberry Pi 5 GPU environment
export AQ_DRM_DEVICES=/dev/dri/card1:/dev/dri/card0
export AQ_NO_MODIFIERS=1
export MESA_LOADER_DRIVER_OVERRIDE=v3d
export LIBGL_ALWAYS_SOFTWARE=0
export WLR_RENDERER=gles2
export WLR_NO_HARDWARE_CURSORS=1
EOF
chmod 0644 "${TARGET_ROOT}/etc/profile.d/10-pi5-gpu.sh"

# Ensure user local share omarchy symlinks exist
mkdir -p "${USER_HOME}/.local/share" "${SKEL_DIR}/.local/share"
ln -snf /usr/share/omarchy "${USER_HOME}/.local/share/omarchy"
ln -snf /usr/share/omarchy "${SKEL_DIR}/.local/share/omarchy"

# ------------------------------------------------------------------------------
# 6. SDDM Autologin, Session, and Theme Configuration
# ------------------------------------------------------------------------------
echo "[+] Configuring SDDM (theme: omarchy, session: omarchy, autologin: omarchy)..."
mkdir -p "${TARGET_ROOT}/etc/sddm.conf.d"
mkdir -p "${TARGET_ROOT}/usr/share/sddm/themes"

# Install Omarchy SDDM Theme
if [[ -d "${OMARCHY_INSTALL_DIR}/default/sddm/omarchy" ]]; then
    mkdir -p "${TARGET_ROOT}/usr/share/sddm/themes/omarchy"
    cp -a "${OMARCHY_INSTALL_DIR}/default/sddm/omarchy/." "${TARGET_ROOT}/usr/share/sddm/themes/omarchy/"
fi

# SDDM Wayland & Compositor Drop-in
cat <<'EOF' > "${TARGET_ROOT}/etc/sddm.conf.d/10-wayland.conf"
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
SessionDir=/usr/share/wayland-sessions:/usr/local/share/wayland-sessions
EOF

# SDDM Theme Drop-in
cat <<'EOF' > "${TARGET_ROOT}/etc/sddm.conf.d/10-theme.conf"
[Theme]
Current=omarchy
ThemeDir=/usr/share/sddm/themes
EOF

# SDDM Autologin Drop-in
cat <<'EOF' > "${TARGET_ROOT}/etc/sddm.conf.d/20-autologin.conf"
[Autologin]
User=omarchy
Session=omarchy
Relogin=false
EOF

# Ensure Omarchy and Hyprland wayland-sessions exist
mkdir -p "${TARGET_ROOT}/usr/share/wayland-sessions"
if [[ -f "${OMARCHY_INSTALL_DIR}/default/wayland-sessions/omarchy.desktop" ]]; then
    cp -a "${OMARCHY_INSTALL_DIR}/default/wayland-sessions/omarchy.desktop" "${TARGET_ROOT}/usr/share/wayland-sessions/"
fi
if [[ -x "${TARGET_ROOT}/usr/bin/Hyprland" && ! -f "${TARGET_ROOT}/usr/share/wayland-sessions/hyprland.desktop" ]]; then
    cat <<'EOF' > "${TARGET_ROOT}/usr/share/wayland-sessions/hyprland.desktop"
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF
fi

# Harden SDDM PAM: remove conflicting gnome-keyring locks
if [[ -f "${TARGET_ROOT}/etc/pam.d/sddm" ]]; then
    sed -i '/-auth.*pam_gnome_keyring\.so/d' "${TARGET_ROOT}/etc/pam.d/sddm" || true
    sed -i '/-password.*pam_gnome_keyring\.so/d' "${TARGET_ROOT}/etc/pam.d/sddm" || true
fi

# ------------------------------------------------------------------------------
# 7. Finalize User Permissions
# ------------------------------------------------------------------------------
echo "[+] Finalizing home directory permissions on ${USER_HOME}..."
if id -u "${USERNAME}" >/dev/null 2>&1 && [[ -d "${USER_HOME}" ]]; then
    chown -R "${USERNAME}:${USERNAME}" "${USER_HOME}"
    chmod 750 "${USER_HOME}"
fi

echo "[✓] Omarchy Quattro desktop integration completed successfully!"
