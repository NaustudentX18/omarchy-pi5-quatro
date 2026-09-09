# Contributing to Omarchy Quattro

Thanks for helping make Omarchy on the Pi 5 better! This is a young project and
every kind of contribution helps.

## Ways to help

- **Flash reports** — "flashed v1.0.0, booted fine on drive X / case Y" issues are gold.
  They build the compatibility matrix in the README.
- **Real screenshots** — Hyprland desktop shots on actual hardware (share config-free crops, no personal data).
- **Hardware reports** — NVMe drives, HATs, enclosures, Argon variants: what works, what doesn't.
- **Package suggestions** — anything missing vs upstream Omarchy? Open an issue before PRing a manifest change.
- **Build fixes** — the build script is battle-tested but only on one host; hardening welcome.

## Ground rules

1. **One intent per PR.** Every change traces to a stated goal — no drive-by refactors.
2. **Test on hardware.** If you change `build_pi5_image.sh` or anything under `desktop/`,
   `argon/`, `resize/`, or `system_tuning/`, run a full build and boot the result.
   Include the output image's SHA-256 and your hardware in the PR description.
3. **Keep the manifest lean.** Every package costs image size and boot time; justify additions.
4. **Shell style:** `bash -n` clean, `shellcheck` clean where practical, `set -euo pipefail` mindset.
5. Be excellent to each other.

## Building a test image

```bash
git clone https://github.com/NaustudentX18/omarchy-pi5-quattro.git
cd omarchy-pi5-quattro
sudo ./build_pi5_image.sh --fast-compress   # ~16 min on a Pi 5
```

Then flash `output/omarchy-pi5-quattro.img.zst` with Raspberry Pi Imager ("Use custom") and boot it.

## Reporting bugs

Open an issue with: Pi 5 RAM variant, drive model, HAT/case, host OS used for flashing,
the exact command/steps, and the SHA-256 of the image you flashed. Logs (`journalctl -b`)
beat guesses every time.
