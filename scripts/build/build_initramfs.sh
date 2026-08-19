#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - Initramfs Builder Script
# ==============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOTFS_DIR="${PROJECT_ROOT}/rootfs"
ISO_DIR="${PROJECT_ROOT}/iso"
INITRAMFS_OUT="${ISO_DIR}/initramfs.img"

echo "================================================================="
echo "           AQJ OS - Initramfs Builder Pipeline"
echo "================================================================="
echo "Project Root  : ${PROJECT_ROOT}"
echo "RootFS Source : ${ROOTFS_DIR}"
echo "Output Archive: ${INITRAMFS_OUT}"
echo "-----------------------------------------------------------------"

# 1. Verifikasi Direktori RootFS
if [[ ! -d "${ROOTFS_DIR}" ]]; then
    echo "ERROR: Direktori RootFS tidak ditemukan di ${ROOTFS_DIR}!" >&2
    exit 1
fi

mkdir -p "${ISO_DIR}" "${ISO_DIR}/boot"

# 2. Mengompresi RootFS menjadi arsip initramfs.img (cpio + gzip)
echo "[*] Membuat arsip initramfs dari RootFS..."
(
    cd "${ROOTFS_DIR}"
    find . -mindepth 1 | cpio -H newc -o 2>/dev/null | gzip -9 > "${INITRAMFS_OUT}"
)

# Menyalin juga ke iso/boot/initramfs.img untuk konsistensi Limine
cp -f "${INITRAMFS_OUT}" "${ISO_DIR}/boot/initramfs.img"

INITRAMFS_SIZE=$(ls -lh "${INITRAMFS_OUT}" | awk '{print $5}')

echo "-----------------------------------------------------------------"
echo "[✓] Initramfs sukses dibuat!"
echo "    Lokasi Output: ${INITRAMFS_OUT}"
echo "    Ukuran Berkas: ${INITRAMFS_SIZE}"
echo "================================================================="
