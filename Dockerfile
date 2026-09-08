# ==============================================================================
# Dockerfile for Omarchy Quatro Pi 5 Image Builder
# Provides an isolated, reproducible rootfs packaging environment
# ==============================================================================

# NOTE: Pin to a digest (debian:trixie-slim@sha256:...) for byte-reproducible builds.
# Tracking tag is acceptable for now; revisit before next release.
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    parted \
    dosfstools \
    e2fsprogs \
    util-linux \
    udev \
    tar \
    curl \
    wget \
    ca-certificates \
    zstd \
    xz-utils \
    zerofree \
    qemu-user-static \
    binfmt-support \
    coreutils \
    findutils \
    grep \
    sed \
    gzip \
    bzip2 \
    procps \
    git \
    && rm -rf /var/lib/apt/lists/*

# NOTE: apt packages not pinned; rebuilds may install different versions.
# For reproducibility, capture versions with `apt-cache policy <pkg>` after update, pin with pkg=version.

WORKDIR /workspace

ENTRYPOINT ["/bin/bash", "/workspace/build_pi5_image.sh"]
CMD []
