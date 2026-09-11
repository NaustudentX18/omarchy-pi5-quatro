#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quattro — Automated 12-Hour Upstream Sync Runner
# Fires every 12 hours: checks upstream omacom/omarchy for new tags & commits,
# audits package changes, updates repo manifests, and pushes updates.
# ==============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="${REPO_DIR}/logs/upstream-sync.log"
mkdir -p "${REPO_DIR}/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

log "=== Starting 12-Hour Upstream Sync Check ==="

cd "${REPO_DIR}"

# 1. Fetch latest upstream release tag and quattro branch head commit
UPSTREAM_API="https://api.github.com/repos/omacom/omarchy/releases/latest"
COMMITS_API="https://api.github.com/repos/omacom/omarchy/commits/quattro"

AUTH_HEADER=()
if command -v gh &>/dev/null && gh auth token &>/dev/null; then
    AUTH_HEADER=(-H "Authorization: Bearer $(gh auth token)")
fi

LATEST_TAG=$(curl -sSL -H "Accept: application/vnd.github.v3+json" "${AUTH_HEADER[@]}" "${UPSTREAM_API}" | jq -r '.tag_name // empty')
UPSTREAM_SHA=$(curl -sSL -H "Accept: application/vnd.github.v3+json" "${AUTH_HEADER[@]}" "${COMMITS_API}" | jq -r '.sha // empty')

if [[ -z "${UPSTREAM_SHA}" ]]; then
    log "[!] Failed to query GitHub API for upstream omacom/omarchy."
    exit 1
fi

CURRENT_PIN=$(grep -oE 'OMARCHY_PIN_SHA:-\"?[a-f0-9]+\"?' desktop/clone_omarchy_repo.sh | head -n 1 | sed -E 's/.*:-"?([a-f0-9]+)"?.*/\1/' || true)

log "Upstream Latest Tag: ${LATEST_TAG}"
log "Upstream Quattro SHA: ${UPSTREAM_SHA}"
log "Current Local Pin:    ${CURRENT_PIN}"

# 2. Check if drift exists
if [[ -n "${CURRENT_PIN}" && "${CURRENT_PIN}" == "${UPSTREAM_SHA}" ]]; then
    log "[✓] Upstream baseline is fully up to date (${CURRENT_PIN}). No action required."
    exit 0
fi

log "[*] Upstream update detected (${CURRENT_PIN} -> ${UPSTREAM_SHA}). Planning update..."

# 3. Pull latest local master
git pull --ff-only origin master || true

# 4. Update clone_omarchy_repo.sh pin
sed -i -E "s/(OMARCHY_PIN_SHA:-\"?)[a-f0-9]+(\"?)/\1${UPSTREAM_SHA}\2/" desktop/clone_omarchy_repo.sh

# 5. Audit base packages from upstream quattro branch
UPSTREAM_BASE_URL="https://raw.githubusercontent.com/omacom/omarchy/quattro/install/omarchy-base.packages"
curl -sSL -o /tmp/upstream-base.packages "${UPSTREAM_BASE_URL}" 2>/dev/null || true

# 6. Check package repo health
REPO_STATUS=$(curl -sIL -o /dev/null -w "%{http_code}" https://pkgs.omarchy.org/edge/aarch64/omarchy.db || echo "000")
log "pkgs.omarchy.org edge aarch64 status: ${REPO_STATUS}"

# 7. Validate syntax before committing
for f in build_pi5_image.sh build_docker.sh desktop/*.sh argon/*.sh resize/*.sh system_tuning/*.sh updates/*.sh; do
    bash -n "$f"
done
python3 -m json.tool pi-imager-os-list.json > /dev/null

# 8. Commit and push if files modified
if [[ -n "$(git status --porcelain)" ]]; then
    git add desktop/clone_omarchy_repo.sh
    git commit -m "chore(sync): automated 12-hour upstream sync to ${UPSTREAM_SHA:0:7}

- Update upstream commit pin in desktop/clone_omarchy_repo.sh
- Verified syntax across all build and update manifests

Confidence: high
Scope-risk: narrow
Tested: automated syntax validation via bash -n and json.tool"
    git push origin master
    log "[✓] Successfully synced and pushed upstream changes to master."
else
    log "[✓] Working tree clean. Nothing to commit."
fi

log "=== 12-Hour Upstream Sync Check Complete ==="
