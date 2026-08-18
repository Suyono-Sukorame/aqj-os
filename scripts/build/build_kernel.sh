#!/usr/bin/env bash
# ==============================================================================
# Script Pembangun Linux Kernel untuk AQJ OS
# Versi Kernel: 7.1.8
# ==============================================================================

set -euo pipefail

# Konfigurasi Path & Versi
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KERNEL_VERSION="7.1.8"
TARBALL_PATH="${PROJECT_ROOT}/kernel/tarballs/linux-${KERNEL_VERSION}.tar.gz"
BUILD_DIR="${PROJECT_ROOT}/kernel/build"
SRC_DIR="${BUILD_DIR}/linux-${KERNEL_VERSION}"
CONFIG_SRC="${PROJECT_ROOT}/configs/boot/kernel-${KERNEL_VERSION}.config"
PATCHES_DIR="${PROJECT_ROOT}/kernel/patches"
OUTPUT_BOOT_DIR="${PROJECT_ROOT}/iso/boot"
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
echo "  AQJ OS - Kernel Build Pipeline (Linux ${KERNEL_VERSION})"
echo "================================================================="
echo "Project Root : ${PROJECT_ROOT}"
echo "Kernel Tar   : ${TARBALL_PATH}"
echo "Build Dir    : ${BUILD_DIR}"
echo "Jobs (CPU)   : ${JOBS}"
echo "================================================================="

# 1. Verifikasi File Tarball Kernel
if [[ ! -f "${TARBALL_PATH}" ]]; then
    echo "ERROR: File kernel tarball tidak ditemukan di ${TARBALL_PATH}!" >&2
    exit 1
fi

# 2. Persiapan Folder Build
mkdir -p "${BUILD_DIR}" "${OUTPUT_BOOT_DIR}" "${STAGING_ROOTFS}"

# Clean flag check
if [[ "${1:-}" == "--clean" ]]; then
    echo "[+] Membersihkan folder build..."
    rm -rf "${SRC_DIR}"
fi

# 3. Ekstraksi Source Kernel
if [[ ! -d "${SRC_DIR}" ]]; then
    echo "[+] Mengekstrak ${TARBALL_PATH}..."
    tar -xzf "${TARBALL_PATH}" -C "${BUILD_DIR}"
else
    echo "[i] Source kernel sudah diekstrak di ${SRC_DIR}. Melewati ekstraksi."
fi

# 4. Pengaplikasian Patch (jika ada)
if [[ -d "${PATCHES_DIR}" ]] && compgen -G "${PATCHES_DIR}/*.patch" > /dev/null; then
    echo "[+] Mengaplikasikan patch kustom dari ${PATCHES_DIR}..."
    for patch_file in "${PATCHES_DIR}"/*.patch; do
        echo "    Applying ${patch_file}..."
        patch -p1 -d "${SRC_DIR}" < "${patch_file}" || true
    done
fi

# 5. Menyiapkan Konfigurasi Kernel (.config)
if [[ -f "${CONFIG_SRC}" ]]; then
    echo "[+] Menyalin file konfigurasi ${CONFIG_SRC} ke .config..."
    cp "${CONFIG_SRC}" "${SRC_DIR}/.config"
else
    echo "[!] Konfigurasi kustom tidak ditemukan di ${CONFIG_SRC}. Menggunakan default defconfig..."
    make -C "${SRC_DIR}" defconfig
fi

# 6. Pengecekan Lingkungan Sistem
OS_TYPE="$(uname -s)"
if [[ "${OS_TYPE}" != "Linux" ]]; then
    echo "================================================================="
    echo "  [PERHATIAN] OS Host Terdeteksi: ${OS_TYPE}"
    echo "  Kompilasi kernel Linux memerlukan lingkungan Linux."
    echo "  Silakan jalankan script ini di dalam Docker/VM Linux atau"
    echo "  gunakan cross-compiler toolchain untuk target Linux x86_64."
    echo "================================================================="
    echo "[+] Lingkungan awal kernel Linux 7.1.8 berhasil disiapkan di ${SRC_DIR}."
    exit 0
fi

# 7. Kompilasi Kernel di Lingkungan Linux
echo "[+] Memulai kompilasi kernel Linux (make bzImage -j${JOBS})..."
make -C "${SRC_DIR}" olddefconfig
make -C "${SRC_DIR}" -j"${JOBS}" bzImage
make -C "${SRC_DIR}" -j"${JOBS}" modules

# 8. Menyalin Hasil Kompilasi
if [[ -f "${SRC_DIR}/arch/x86/boot/bzImage" ]]; then
    echo "[+] Menyalin bzImage ke ${OUTPUT_BOOT_DIR}/vmlinuz-${KERNEL_VERSION}..."
    cp "${SRC_DIR}/arch/x86/boot/bzImage" "${OUTPUT_BOOT_DIR}/vmlinuz-${KERNEL_VERSION}"
    cp "${SRC_DIR}/System.map" "${OUTPUT_BOOT_DIR}/System.map-${KERNEL_VERSION}"
fi

echo "[+] Memasang modul kernel ke staging rootfs (${STAGING_ROOTFS})..."
make -C "${SRC_DIR}" INSTALL_MOD_PATH="${STAGING_ROOTFS}" modules_install

echo "================================================================="
echo "  Kompilasi Kernel Linux ${KERNEL_VERSION} Selesai dengan Sukses!"
echo "  Output Kernel : ${OUTPUT_BOOT_DIR}/vmlinuz-${KERNEL_VERSION}"
echo "================================================================="
