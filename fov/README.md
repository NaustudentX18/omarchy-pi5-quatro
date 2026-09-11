# Omarchy FOV — XR reserved margins (Hyprland 0.56+)

**Omarchy Quattro Pi 5** overlay fixing [issue #2](https://github.com/NaustudentX18/omarchy-pi5-quattro/issues/2).

## Problem

On Hyprland 0.56+ with `hyprland.lua` as the active entry point, legacy:

```bash
hyprctl keyword monitor "HDMI-A-1,addreserved,$t,$b,$l,$r"
```

fails with `keyword can't work with non-legacy parsers. Use eval.` Daemons that hide stderr look successful while SUPER+F11 / luma/compact/subtle do nothing.

## Fix

Apply margins through the lua monitor API:

```bash
hyprctl eval "hl.monitor({ output = 'HDMI-A-1', reserved = { top = N, right = R, bottom = B, left = L } })"
```

### Gotchas (verified on Hyprland 0.56.2)

- Named `reserved` fields: L/R/B are absolute; **top is additive** with layer-shell (e.g. `omarchy-bar` at y=0). To land on target top `T`, send `top = max(T - bar_height, 0)`.
- Integer `reserved = N` expands unevenly once the bar is present.
- `addreserved` is not a valid `hl.monitor` field.
- `hl.config({ monitor = { "... addreserved ..." } })` can return ok and still be a no-op.

The daemon auto-detects bar height via `hyprctl layers` (`WAYBAR_NAMESPACE`, default `omarchy-bar`) with fallback `30`.

## Files

| Path | Role |
| :--- | :--- |
| `omarchy-fov` | CLI + daemon (`full` / `subtle` / `luma` / `compact` / `toggle` / `status` / `daemon`) |
| `omarchy-fov.conf` | System defaults → `/etc/omarchy-fov.conf` |
| `omarchy-fov.service` | User systemd unit |
| `install_fov.sh` | Live or chroot installer |

User overrides: `~/.config/omarchy/fov.conf` (sourced after system conf).

## Install

```bash
sudo ./install_fov.sh
# or from repo root after checkout:
sudo bash fov/install_fov.sh
```

Image builds / `omarchy update` reassert via `omarchy-pi5-post-update`.

## Verify

```bash
omarchy-fov status
omarchy-fov compact && hyprctl monitors -j | jq -c '.[0].reserved'
omarchy-fov subtle && hyprctl monitors -j | jq -c '.[0].reserved'
omarchy-fov full && hyprctl monitors -j | jq -c '.[0].reserved'
```
