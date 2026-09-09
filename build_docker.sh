#!/usr/bin/env bash
# ==============================================================================
# Omarchy Quattro - Docker Container Build Runner
# Executes image build in a privileged, isolated container environment
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_TAG="omarchy-pi5-builder:latest"

# Terminal color codes
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()    { echo -e "${CYAN}[DOCKER BUILDER]${NC} $*"; }
log_success() { echo -e "${GREEN}[DOCKER BUILDER]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[DOCKER BUILDER]${NC} $*"; }
log_error()   { echo -e "${RED}[DOCKER BUILDER ERROR]${NC} $*" >&2; }

# Verify Docker availability
if ! command -v docker &>/dev/null; then
    log_error "Docker is not installed or not found on PATH."
    log_error "Please install Docker or use native sudo ./build_pi5_image.sh."
    exit 1
fi

if ! docker info &>/dev/null; then
    log_error "Cannot connect to Docker daemon. Is docker.service running?"
    log_error "Try: sudo systemctl start docker"
    exit 1
fi

# Build Docker builder image
log_info "Building container image '${IMAGE_TAG}'..."
docker build -t "${IMAGE_TAG}" -f "${SCRIPT_DIR}/Dockerfile" "${SCRIPT_DIR}"
log_success "Builder container image ready."

# Check if running interactively
DOCKER_TTY_FLAGS=()
if [ -t 0 ] && [ -t 1 ]; then
    DOCKER_TTY_FLAGS=(-it)
fi

log_info "Launching build inside privileged container..."
log_info "Workspace mounted at: /workspace"

docker run --rm ${DOCKER_TTY_FLAGS[@]+"${DOCKER_TTY_FLAGS[@]}"} \
    --privileged \
    --net=host \
    -v /dev:/dev \
    -v /lib/modules:/lib/modules:ro \
    -v "${SCRIPT_DIR}:/workspace" \
    "${IMAGE_TAG}" "$@"

log_success "Containerized build completed successfully!"
