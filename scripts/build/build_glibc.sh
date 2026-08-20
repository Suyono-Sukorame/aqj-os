#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - Glibc 2.44 Build & Staging Script
# ==============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GLIBC_VERSION="2.44"
TARBALL_PATH="${PROJECT_ROOT}/packages/tarballs/glibc-${GLIBC_VERSION}.tar.gz"
PACKAGES_BUILD_DIR="${PROJECT_ROOT}/packages/build"
SRC_DIR="${PACKAGES_BUILD_DIR}/glibc-${GLIBC_VERSION}"
BUILD_DIR="/tmp/aqj-os-build/glibc-${GLIBC_VERSION}"
STAGING_ROOTFS="${PROJECT_ROOT}/rootfs"

# Deteksi Jumlah Core CPU
if command -v nproc &>/dev/null; then
    JOBS=$(nproc)
elif command -v sysctl &>/dev/null; then
    JOBS=$(sysctl -n hw.ncpu)
else
    JOBS=4
fi

echo "================================================================="
echo "  AQJ OS - Glibc Build Pipeline (GNU C Library ${GLIBC_VERSION})"
echo "================================================================="
echo "Project Root : ${PROJECT_ROOT}"
echo "Tarball      : ${TARBALL_PATH}"
echo "Build Dir    : ${BUILD_DIR}"
echo "RootFS Target: ${STAGING_ROOTFS}"
echo "Jobs (CPU)   : ${JOBS}"
echo "================================================================="

# 1. Verifikasi File Tarball Glibc
if [[ ! -f "${TARBALL_PATH}" ]]; then
    echo "ERROR: File tarball Glibc tidak ditemukan di ${TARBALL_PATH}!" >&2
    exit 1
fi

# 2. Persiapan Folder Build
mkdir -p "${PACKAGES_BUILD_DIR}" "${STAGING_ROOTFS}"

# Fast-skip if glibc is already installed and not --clean
if [[ -f "${STAGING_ROOTFS}/lib64/libc.so.6" && -f "${STAGING_ROOTFS}/usr/lib/libc_nonshared.a" && "${1:-}" != "--clean" ]]; then
    echo "[i] Glibc ${GLIBC_VERSION} sudah terpasang di ${STAGING_ROOTFS}. Melewati kompilasi ulang."
    
    # Fix GNU ld script absolute path issue (relative paths so linker uses search path)
    if [[ -f "${STAGING_ROOTFS}/usr/lib/libc.so" ]]; then
        sed -i 's|/lib64/||g; s|/usr/lib/||g' "${STAGING_ROOTFS}/usr/lib/libc.so" 2>/dev/null || true
    fi
    if [[ -f "${STAGING_ROOTFS}/usr/lib/libm.so" ]]; then
        sed -i 's|/lib64/||g; s|/usr/lib/||g' "${STAGING_ROOTFS}/usr/lib/libm.so" 2>/dev/null || true
    fi

    # Export rootfs library paths without touching /lib64 (which would break container's own glibc)
    export LIBRARY_PATH="${STAGING_ROOTFS}/lib64:${STAGING_ROOTFS}/usr/lib:${LIBRARY_PATH:-}"
    export PKG_CONFIG_LIBDIR="${STAGING_ROOTFS}/usr/lib/pkgconfig:${STAGING_ROOTFS}/usr/share/pkgconfig"
    echo "[i] LIBRARY_PATH set to: ${LIBRARY_PATH}"
    exit 0
fi

# Clean flag check
if [[ "${1:-}" == "--clean" ]]; then
    echo "[+] Membersihkan direktori build glibc..."
    rm -rf "${SRC_DIR}"
fi

# 3. Ekstraksi Source Code Glibc
if [[ ! -d "${SRC_DIR}" ]]; then
    echo "[+] Mengekstrak ${TARBALL_PATH}..."
    tar -xzf "${TARBALL_PATH}" -C "${PACKAGES_BUILD_DIR}"
else
    echo "[i] Source code Glibc sudah diekstrak di ${SRC_DIR}."
fi

# 4. Membuat Out-of-Tree Build Directory
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 5. Pengecekan OS Host
OS_TYPE="$(uname -s)"
if [[ "${OS_TYPE}" != "Linux" ]]; then
    echo "================================================================="
    echo "  [PERHATIAN] OS Host Terdeteksi: ${OS_TYPE}"
    echo "  Kompilasi GNU C Library (Glibc) memerlukan lingkungan Linux x86_64."
    echo "  Silakan jalankan script ini di dalam Docker/Container/VM Linux"
    echo "  dengan toolchain GCC & Make untuk mengompilasi binary secara utuh."
    echo "================================================================="
    echo "[+] Ekstraksi dan direktori build Glibc ${GLIBC_VERSION} sukses disiapkan di:"
    echo "    ${BUILD_DIR}"
    exit 0
fi

# 6. Konfigurasi Out-of-Tree Glibc
echo "[+] Mengonfigurasi Glibc (${GLIBC_VERSION})..."
(
    cd "${BUILD_DIR}"
    "${SRC_DIR}/configure" \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --disable-werror \
        --enable-kernel=4.19 \
        --enable-stack-protector=strong \
        libc_cv_slibdir=/lib64
)

# 7. Kompilasi Glibc
echo "[+] Memulai kompilasi Glibc (make PARALLELMFLAGS=-j${JOBS})..."
make -C "${BUILD_DIR}" PARALLELMFLAGS="-j${JOBS}"

# 8. Instalasi ke Staging RootFS
echo "[+] Memasang Glibc ke staging rootfs (${STAGING_ROOTFS})..."
make -C "${BUILD_DIR}" install DESTDIR="${STAGING_ROOTFS}"

# Fix GNU ld script absolute path issue (relative paths so linker uses search path)
if [[ -f "${STAGING_ROOTFS}/usr/lib/libc.so" ]]; then
    sed -i 's|/lib64/||g; s|/usr/lib/||g' "${STAGING_ROOTFS}/usr/lib/libc.so" 2>/dev/null || true
fi
if [[ -f "${STAGING_ROOTFS}/usr/lib/libm.so" ]]; then
    sed -i 's|/lib64/||g; s|/usr/lib/||g' "${STAGING_ROOTFS}/usr/lib/libm.so" 2>/dev/null || true
fi

# Set LIBRARY_PATH so downstream builds find our glibc without touching /lib64
export LIBRARY_PATH="${STAGING_ROOTFS}/lib64:${STAGING_ROOTFS}/usr/lib:${LIBRARY_PATH:-}"
export PKG_CONFIG_LIBDIR="${STAGING_ROOTFS}/usr/lib/pkgconfig:${STAGING_ROOTFS}/usr/share/pkgconfig"
echo "[i] LIBRARY_PATH set to: ${LIBRARY_PATH}"

echo "================================================================="
echo "  Kompilasi & Pemasangan Glibc ${GLIBC_VERSION} Selesai dengan Sukses!"
echo "================================================================="
