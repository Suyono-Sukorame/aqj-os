#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - iwd (iNet Wireless Daemon) Build & Staging Script
# ==============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IWD_DIR="${PROJECT_ROOT}/iwd"
BUILD_DIR="${IWD_DIR}/build"
STAGING_ROOTFS="${PROJECT_ROOT}/rootfs"
CONFIG_RUNIT="${PROJECT_ROOT}/configs/runit"

# Deteksi Jumlah Core CPU
if command -v nproc &>/dev/null; then
    JOBS=$(nproc)
elif command -v sysctl &>/dev/null; then
    JOBS=$(sysctl -n hw.ncpu)
else
    JOBS=4
fi

echo "================================================================="
echo "  AQJ OS - iwd Build Pipeline (iNet Wireless Daemon)"
echo "================================================================="
echo "Project Root : ${PROJECT_ROOT}"
echo "iwd Source   : ${IWD_DIR}"
echo "RootFS Target: ${STAGING_ROOTFS}"
echo "Jobs (CPU)   : ${JOBS}"
echo "================================================================="

# 1. Verifikasi Direktori Source Code iwd
if [[ ! -d "${IWD_DIR}" ]]; then
    echo "ERROR: Direktori iwd tidak ditemukan di ${IWD_DIR}!" >&2
    exit 1
fi

# Clean flag check
if [[ "${1:-}" == "--clean" ]]; then
    echo "[+] Membersihkan direktori build iwd..."
    rm -rf "${BUILD_DIR}"
fi

# 2. Pengecekan OS Host
OS_TYPE="$(uname -s)"
if [[ "${OS_TYPE}" != "Linux" ]]; then
    echo "================================================================="
    echo "  [PERHATIAN] OS Host Terdeteksi: ${OS_TYPE}"
    echo "  Kompilasi iwd memerlukan lingkungan Linux x86_64."
    echo "  Silakan jalankan script ini di dalam Docker/Container/VM Linux"
    echo "  dengan toolchain GCC, ELL (Embedded Linux Library), & Make."
    echo "================================================================="
    echo "[+] Repositori iwd sukses diverifikasi di:"
    echo "    ${IWD_DIR}"
    exit 0
fi

# 3. Bootstrap Autotools
echo "[+] Menyiapkan autotools (./bootstrap)..."
(
    cd "${IWD_DIR}"
    if [[ -x "./bootstrap" ]]; then
        ./bootstrap
    elif [[ -x "./autogen.sh" ]]; then
        ./autogen.sh
    fi
)

mkdir -p "${BUILD_DIR}"

# 4. Konfigurasi iwd
echo "[+] Mengonfigurasi iwd..."
(
    cd "${BUILD_DIR}"
    export PKG_CONFIG_LIBDIR="${PKG_CONFIG_LIBDIR:-}:/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig"
    unset PKG_CONFIG_SYSROOT_DIR
    "${IWD_DIR}/configure" \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --libexecdir=/usr/lib/iwd \
        --disable-external-ell \
        --disable-manual-pages \
        --disable-systemd-service \
)

# 5. Kompilasi iwd
echo "[+] Memulai kompilasi iwd (make -j${JOBS})..."
make -C "${BUILD_DIR}" -j"${JOBS}"

# 6. Instalasi ke Staging RootFS
echo "[+] Memasang iwd ke staging rootfs (${STAGING_ROOTFS})..."
make -C "${BUILD_DIR}" install DESTDIR="${STAGING_ROOTFS}"

echo "================================================================="
echo "  Kompilasi & Pemasangan iwd Selesai dengan Sukses!"
echo "================================================================="
