#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - Bootable ISO Builder Script (Limine Bootloader + Linux Kernel 7.1.8)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

LIMINE_DIR="${PROJECT_ROOT}/limine"
CONFIG_BOOT="${PROJECT_ROOT}/configs/boot"
ISO_DIR="${PROJECT_ROOT}/iso"
STAGING_DIR="${ISO_DIR}/staging"
KERNEL_IMAGE="${ISO_DIR}/vmlinuz-7.1.8"
OUTPUT_ISO="${ISO_DIR}/aqj-os-7.1.8-x86_64.iso"

echo "================================================================="
echo "               AQJ OS - ISO Builder (Limine Boot)"
echo "================================================================="
echo "Project Root: ${PROJECT_ROOT}"
echo "Output ISO  : ${OUTPUT_ISO}"
echo "-----------------------------------------------------------------"

# 1. Periksa ketersediaan tool dasar
if ! command -v xorriso &> /dev/null; then
    echo "[!] Warning: 'xorriso' tidak ditemukan di sistem."
    echo "    Untuk membuat file .iso di Linux/macOS, install xorriso terlebih dahulu:"
    echo "    - macOS: brew install xorriso"
    echo "    - Debian/Ubuntu: sudo apt-get install xorriso"
fi

# 2. Periksa ketersediaan Limine source
if [ ! -d "${LIMINE_DIR}" ]; then
    echo "[X] Error: Direktori Limine tidak ditemukan di ${LIMINE_DIR}!"
    exit 1
fi

# 3. Cek ketersediaan binary / stage files Limine
HAS_LIMINE_STAGE=true
for file in limine-bios-cd.bin limine-uefi-cd.bin; do
    if [ ! -f "${LIMINE_DIR}/${file}" ]; then
        HAS_LIMINE_STAGE=false
        break
    fi
done

if [ "${HAS_LIMINE_STAGE}" = "false" ]; then
    if [ -f "${LIMINE_DIR}/Makefile" ] || [ -f "${LIMINE_DIR}/configure" ]; then
        echo "[*] Mencoba mengompilasi Limine host binary dari source..."
        (
            cd "${LIMINE_DIR}"
            if [ -f "./configure" ]; then
                ./configure --enable-bios --enable-uefi-x86-64 || true
                make -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)" || true
            fi
        )
    else
        echo "[!] Catatan: Limine stage files (limine-bios-cd.bin, limine-uefi-cd.bin) belum dikompilasi."
        echo "    Jalankan kompilasi Limine di lingkungan Linux/Container (make -C limine)."
    fi
fi

# 3.5 Jalankan initramfs builder jika ada
BUILD_INITRAMFS_SCRIPT="${SCRIPT_DIR}/build_initramfs.sh"
if [ -x "${BUILD_INITRAMFS_SCRIPT}" ]; then
    echo "[*] Menjalankan initramfs builder pipeline..."
    "${BUILD_INITRAMFS_SCRIPT}"
fi

# 4. Buat direktori Staging ISO
echo "[*] Menyiapkan struktur direktori ISO Staging..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}/boot/limine"
mkdir -p "${STAGING_DIR}/EFI/BOOT"

# Menyalin initramfs.img dari iso/ atau iso/boot/ jika ada
if [ -f "${ISO_DIR}/initramfs.img" ]; then
    echo "[*] Menyalin initramfs.img ke ISO staging..."
    cp -f "${ISO_DIR}/initramfs.img" "${STAGING_DIR}/boot/initramfs.img"
fi


# 5. Salin konfigurasi Limine
if [ -f "${CONFIG_BOOT}/limine.conf" ]; then
    echo "[*] Menyalin configs/boot/limine.conf ke ISO..."
    cp "${CONFIG_BOOT}/limine.conf" "${STAGING_DIR}/boot/limine/limine.conf"
else
    echo "[!] Warning: configs/boot/limine.conf tidak ditemukan! Membuat konfigurasi default..."
    cat << 'EOF' > "${STAGING_DIR}/boot/limine/limine.conf"
timeout: 5
default_entry: 1
graphics: yes

/AQJ OS (Linux 7.1.8)
    protocol: linux
    kernel_path: boot():/boot/vmlinuz-7.1.8
    initrd_path: boot():/boot/initramfs.img
    cmdline: quiet loglevel=3 rw root=/dev/ram0 console=tty1
EOF
fi

# 6. Salin Kernel Linux jika ada
if [ -f "${KERNEL_IMAGE}" ]; then
    echo "[*] Menyalin Kernel Linux 7.1.8 (${KERNEL_IMAGE})..."
    cp "${KERNEL_IMAGE}" "${STAGING_DIR}/boot/vmlinuz-7.1.8"
else
    echo "[!] Catatan: Kernel image (${KERNEL_IMAGE}) belum dikompilasi."
    echo "    Membuat placeholder kernel untuk verifikasi struktur..."
    touch "${STAGING_DIR}/boot/vmlinuz-7.1.8"
    touch "${STAGING_DIR}/boot/initramfs.img"
fi

# 7. Salin berkas-berkas Bootloader Limine (BIOS & UEFI stage files)
echo "[*] Menyalin berkas boot stage Limine..."
for file in limine-bios.sys limine-bios-cd.bin limine-uefi-cd.bin; do
    if [ -f "${LIMINE_DIR}/${file}" ]; then
        cp "${LIMINE_DIR}/${file}" "${STAGING_DIR}/boot/limine/"
    fi
done

if [ -f "${LIMINE_DIR}/BOOTX64.EFI" ]; then
    cp "${LIMINE_DIR}/BOOTX64.EFI" "${STAGING_DIR}/EFI/BOOT/BOOTX64.EFI"
fi
if [ -f "${LIMINE_DIR}/BOOTIA32.EFI" ]; then
    cp "${LIMINE_DIR}/BOOTIA32.EFI" "${STAGING_DIR}/EFI/BOOT/BOOTIA32.EFI"
fi

# 8. Menjalankan xorriso untuk membuat ISO Bootable (Hybrid BIOS + UEFI)
if command -v xorriso &> /dev/null; then
    echo "[*] Mengompilasi ISO Bootable dengan xorriso..."
    if [ -f "${STAGING_DIR}/boot/limine/limine-bios-cd.bin" ]; then
        xorriso -as mkisofs -b boot/limine/limine-bios-cd.bin \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
            --efi-boot boot/limine/limine-uefi-cd.bin \
            -efi-boot-part --efi-boot-image --protective-msdos-label \
            "${STAGING_DIR}" -o "${OUTPUT_ISO}"

        if [ -f "${LIMINE_DIR}/limine" ]; then
            echo "[*] Memasang Limine BIOS Boot Record pada ISO..."
            "${LIMINE_DIR}/limine" bios-install "${OUTPUT_ISO}"
        fi
        echo "[✓] Sukses! ISO AQJ OS telah dibuat di: ${OUTPUT_ISO}"
    else
        xorriso -as mkisofs "${STAGING_DIR}" -o "${OUTPUT_ISO}"
        echo "[✓] ISO Staging dibuat di: ${OUTPUT_ISO}"
        echo "    (Catatan: Untuk ISO bootable penuh, kompilasi berkas binary Limine terlebih dahulu)."
    fi
else
    echo "[!] Staging ISO telah siap di: ${STAGING_DIR}"
    echo "    Silakan install 'xorriso' untuk membundel file menjadi ${OUTPUT_ISO}"
fi

echo "================================================================="
