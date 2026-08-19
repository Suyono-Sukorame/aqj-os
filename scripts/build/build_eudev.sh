#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - eudev Build & Staging Script
# ==============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EUDEV_DIR="${PROJECT_ROOT}/eudev"
BUILD_DIR="${EUDEV_DIR}/build"
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
echo "  AQJ OS - eudev Build Pipeline (Device Manager)"
echo "================================================================="
echo "Project Root : ${PROJECT_ROOT}"
echo "eudev Source : ${EUDEV_DIR}"
echo "RootFS Target: ${STAGING_ROOTFS}"
echo "Jobs (CPU)   : ${JOBS}"
echo "================================================================="

# 1. Verifikasi Direktori Source Code eudev
if [[ ! -d "${EUDEV_DIR}" ]]; then
    echo "ERROR: Direktori eudev tidak ditemukan di ${EUDEV_DIR}!" >&2
    exit 1
fi

# Clean flag check
if [[ "${1:-}" == "--clean" ]]; then
    echo "[+] Membersihkan direktori build eudev..."
    rm -rf "${BUILD_DIR}"
fi

# 2. Pengecekan OS Host
OS_TYPE="$(uname -s)"
if [[ "${OS_TYPE}" != "Linux" ]]; then
    echo "================================================================="
    echo "  [PERHATIAN] OS Host Terdeteksi: ${OS_TYPE}"
    echo "  Kompilasi eudev memerlukan lingkungan Linux x86_64."
    echo "  Silakan jalankan script ini di dalam Docker/Container/VM Linux"
    echo "  dengan toolchain GCC & Make untuk mengompilasi binary secara utuh."
    echo "================================================================="
    echo "[+] Repositori eudev sukses diverifikasi di:"
    echo "    ${EUDEV_DIR}"
    exit 0
fi

# 3. Autogen & Out-of-Tree Build Setup
echo "[+] Menyiapkan skrip autotools (autogen.sh)..."
(
    cd "${EUDEV_DIR}"
    if [[ -x "./autogen.sh" ]]; then
        ./autogen.sh
    fi
)

mkdir -p "${BUILD_DIR}"

# 4. Konfigurasi eudev
echo "[+] Mengonfigurasi eudev..."
(
    cd "${BUILD_DIR}"
    "${EUDEV_DIR}/configure" \
        --prefix=/usr \
        --sysconfdir=/etc \
        --sbindir=/sbin \
        --bindir=/bin \
        --libdir=/usr/lib \
        --disable-manpages \
        --disable-static
)

# 5. Kompilasi eudev
echo "[+] Memulai kompilasi eudev (make -j${JOBS})..."
make -C "${BUILD_DIR}" -j"${JOBS}"

# 6. Instalasi ke Staging RootFS
echo "[+] Memasang eudev ke staging rootfs (${STAGING_ROOTFS})..."
make -C "${BUILD_DIR}" install DESTDIR="${STAGING_ROOTFS}"

echo "================================================================="
echo "  Kompilasi & Pemasangan eudev Selesai dengan Sukses!"
echo "================================================================="
