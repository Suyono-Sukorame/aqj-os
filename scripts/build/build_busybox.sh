#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - BusyBox Build & Staging Script
# ==============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARBALL_PATH="${PROJECT_ROOT}/packages/tarballs/busybox.tar.gz"
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
echo "  AQJ OS - BusyBox Build Pipeline"
echo "================================================================="
echo "Project Root : ${PROJECT_ROOT}"
echo "Tarball      : ${TARBALL_PATH}"
echo "RootFS Target: ${STAGING_ROOTFS}"
echo "Jobs (CPU)   : ${JOBS}"
echo "================================================================="

# 1. Verifikasi File Tarball BusyBox
if [[ ! -f "${TARBALL_PATH}" ]]; then
    echo "ERROR: File tarball BusyBox tidak ditemukan di ${TARBALL_PATH}!" >&2
    exit 1
fi

# 2. Persiapan Folder Build
mkdir -p "${PACKAGES_BUILD_DIR}" "${STAGING_ROOTFS}"

# 3. Ekstraksi Source Code BusyBox
EXTRACTED_DIR=$(set +o pipefail; tar -tf "${TARBALL_PATH}" | head -n 1 | cut -f1 -d"/")
if [[ -z "${EXTRACTED_DIR}" ]]; then
    EXTRACTED_DIR="busybox"
fi

SRC_DIR="${PACKAGES_BUILD_DIR}/${EXTRACTED_DIR}"

# Clean flag check
if [[ "${1:-}" == "--clean" ]]; then
    echo "[+] Membersihkan direktori build BusyBox..."
    rm -rf "${SRC_DIR}"
fi

if [[ ! -d "${SRC_DIR}" ]]; then
    echo "[+] Mengekstrak ${TARBALL_PATH} ke ${PACKAGES_BUILD_DIR}..."
    tar -xzf "${TARBALL_PATH}" -C "${PACKAGES_BUILD_DIR}"
else
    echo "[i] Source code BusyBox sudah diekstrak di ${SRC_DIR}."
fi

# 4. Pengecekan OS Host
OS_TYPE="$(uname -s)"
if [[ "${OS_TYPE}" != "Linux" ]]; then
    echo "================================================================="
    echo "  [PERHATIAN] OS Host Terdeteksi: ${OS_TYPE}"
    echo "  Kompilasi BusyBox memerlukan lingkungan Linux x86_64."
    echo "  Silakan jalankan script ini di dalam Docker/Container/VM Linux"
    echo "  dengan toolchain GCC & Make untuk mengompilasi binary secara utuh."
    echo "================================================================="
    echo "[+] Ekstraksi BusyBox sukses disiapkan di:"
    echo "    ${SRC_DIR}"
    exit 0
fi

# 5. Konfigurasi BusyBox (defconfig)
echo "[+] Mengonfigurasi BusyBox (make defconfig)..."
make -C "${SRC_DIR}" defconfig

# 6. Kompilasi BusyBox
echo "[+] Memulai kompilasi BusyBox (make -j${JOBS})..."
make -C "${SRC_DIR}" -j"${JOBS}"

# 7. Instalasi & Pembuatan Symlink ke Staging RootFS
echo "[+] Memasang BusyBox dan symlink ke staging rootfs (${STAGING_ROOTFS})..."
make -C "${SRC_DIR}" install CONFIG_PREFIX="${STAGING_ROOTFS}"

echo "================================================================="
echo "  Kompilasi & Pemasangan BusyBox Selesai dengan Sukses!"
echo "================================================================="
