#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - xfdesktop 4.20.2 Build & Staging Script
# ==============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARBALL_PATH="${PROJECT_ROOT}/packages/tarballs/xfdesktop.tar.bz2"
PACKAGES_BUILD_DIR="${PROJECT_ROOT}/packages/build"
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
echo "  AQJ OS - xfdesktop Build Pipeline (XFCE Desktop Manager)"
echo "================================================================="
echo "Project Root : ${PROJECT_ROOT}"
echo "Tarball      : ${TARBALL_PATH}"
echo "RootFS Target: ${STAGING_ROOTFS}"
echo "Jobs (CPU)   : ${JOBS}"
echo "================================================================="

# 1. Verifikasi File Tarball xfdesktop
if [[ ! -f "${TARBALL_PATH}" ]]; then
    echo "ERROR: File tarball xfdesktop tidak ditemukan di ${TARBALL_PATH}!" >&2
    exit 1
fi

# 2. Persiapan Folder Build
mkdir -p "${PACKAGES_BUILD_DIR}" "${STAGING_ROOTFS}"

# 3. Ekstraksi Source Code xfdesktop
EXTRACTED_DIR=$(tar -tf "${TARBALL_PATH}" | head -n 1 | cut -f1 -d"/")
if [[ -z "${EXTRACTED_DIR}" ]]; then
    EXTRACTED_DIR="xfdesktop-4.20.2"
fi

SRC_DIR="${PACKAGES_BUILD_DIR}/${EXTRACTED_DIR}"

# Clean flag check
if [[ "${1:-}" == "--clean" ]]; then
    echo "[+] Membersihkan direktori build xfdesktop..."
    rm -rf "${SRC_DIR}"
fi

if [[ ! -d "${SRC_DIR}" ]]; then
    echo "[+] Mengekstrak ${TARBALL_PATH} ke ${PACKAGES_BUILD_DIR}..."
    tar -xjf "${TARBALL_PATH}" -C "${PACKAGES_BUILD_DIR}"
else
    echo "[i] Source code xfdesktop sudah diekstrak di ${SRC_DIR}."
fi

# 4. Pengecekan OS Host
OS_TYPE="$(uname -s)"
if [[ "${OS_TYPE}" != "Linux" ]]; then
    echo "================================================================="
    echo "  [PERHATIAN] OS Host Terdeteksi: ${OS_TYPE}"
    echo "  Kompilasi xfdesktop memerlukan lingkungan Linux x86_64."
    echo "  Silakan jalankan script ini di dalam Docker/Container/VM Linux"
    echo "  dengan toolchain GCC, GTK3/4, libxfce4ui, & Make."
    echo "================================================================="
    echo "[+] Ekstraksi xfdesktop sukses disiapkan di:"
    echo "    ${SRC_DIR}"
    exit 0
fi

# 5. Konfigurasi xfdesktop
echo "[+] Mengonfigurasi xfdesktop..."
(
    cd "${SRC_DIR}"
    ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --disable-static \
        --enable-gio-unix \
        --enable-notifications
)

# 6. Kompilasi xfdesktop
echo "[+] Memulai kompilasi xfdesktop (make -j${JOBS})..."
make -C "${SRC_DIR}" -j"${JOBS}"

# 7. Instalasi ke Staging RootFS
echo "[+] Memasang xfdesktop ke staging rootfs (${STAGING_ROOTFS})..."
make -C "${SRC_DIR}" install DESTDIR="${STAGING_ROOTFS}"

echo "================================================================="
echo "  Kompilasi & Pemasangan xfdesktop Selesai dengan Sukses!"
echo "================================================================="
