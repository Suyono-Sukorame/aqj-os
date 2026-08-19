# ==============================================================================
# AQJ OS - Official Linux x86_64 Build Environment
# ==============================================================================
FROM --platform=linux/amd64 debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Install toolchain dan pustaka pembangun lengkap
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    make \
    bison \
    flex \
    autoconf \
    automake \
    libtool \
    pkg-config \
    meson \
    ninja-build \
    python3 \
    python3-pip \
    xorriso \
    cpio \
    gzip \
    bzip2 \
    tar \
    bc \
    libssl-dev \
    libelf-dev \
    libell-dev \
    libncurses-dev \
    libglib2.0-dev \
    libudev-dev \
    libxcb1-dev \
    rsync \
    git \
    curl \
    ca-certificates \
    gettext \
    file \
    kmod \
    dosfstools \
    syslinux \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["/bin/bash"]
