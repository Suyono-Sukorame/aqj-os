#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - xbps Build & Staging Script (X Binary Package System)
# ==============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
XBPS_DIR="${PROJECT_ROOT}/xbps"
BUILD_DIR="${XBPS_DIR}/build"
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
echo "  AQJ OS - xbps Build Pipeline (X Binary Package System)"
echo "================================================================="
echo "Project Root : ${PROJECT_ROOT}"
echo "xbps Source  : ${XBPS_DIR}"
echo "RootFS Target: ${STAGING_ROOTFS}"
echo "Jobs (CPU)   : ${JOBS}"
echo "================================================================="

# 1. Verifikasi Direktori Source Code xbps
if [[ ! -d "${XBPS_DIR}" ]]; then
    echo "ERROR: Direktori xbps tidak ditemukan di ${XBPS_DIR}!" >&2
    exit 1
fi

# Clean flag check
if [[ "${1:-}" == "--clean" ]]; then
    echo "[+] Membersihkan direktori build xbps..."
    rm -rf "${BUILD_DIR}"
    (cd "${XBPS_DIR}" && make distclean 2>/dev/null || true)
fi

# 2. Pengecekan OS Host
OS_TYPE="$(uname -s)"
if [[ "${OS_TYPE}" != "Linux" ]]; then
    echo "================================================================="
    echo "  [PERHATIAN] OS Host Terdeteksi: ${OS_TYPE}"
    echo "  Kompilasi xbps memerlukan lingkungan Linux x86_64."
    echo "  Silakan jalankan script ini di dalam Docker/Container/VM Linux"
    echo "  dengan toolchain GCC, OpenSSL, zlib, & Make untuk mengompilasi."
    echo "================================================================="
    echo "[+] Repositori xbps sukses diverifikasi di:"
    echo "    ${XBPS_DIR}"
    exit 0
fi

# 3. Konfigurasi xbps (configure langsung tersedia, tidak perlu autogen)
echo "[+] Mengonfigurasi xbps..."
(
    cd "${XBPS_DIR}"
    ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --sbindir=/sbin \
        --enable-rpath
)

# 4. Kompilasi xbps
echo "[+] Memulai kompilasi xbps (make -j${JOBS})..."
make -C "${XBPS_DIR}" -j"${JOBS}"

# 5. Instalasi ke Staging RootFS
echo "[+] Memasang xbps ke staging rootfs (${STAGING_ROOTFS})..."
make -C "${XBPS_DIR}" install DESTDIR="${STAGING_ROOTFS}"

echo "================================================================="
echo "  Kompilasi & Pemasangan xbps Selesai dengan Sukses!"
echo "================================================================="
