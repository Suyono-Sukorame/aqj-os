#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - Root Filesystem (RootFS) Populator & Runit Integrator
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CONFIG_RUNIT="${PROJECT_ROOT}/configs/runit"
ROOTFS_DIR="${PROJECT_ROOT}/rootfs"

echo "================================================================="
echo "           AQJ OS - RootFS Populator & Runit Setup"
echo "================================================================="
echo "Project Root : ${PROJECT_ROOT}"
echo "RootFS Dir   : ${ROOTFS_DIR}"
echo "-----------------------------------------------------------------"

# 1. Membuat direktori Standar FHS Linux minimal
echo "[*] Membuat direktori FHS dasar di ${ROOTFS_DIR}..."
mkdir -p "${ROOTFS_DIR}"/{bin,sbin,etc,proc,sys,dev,tmp,run,var,lib,lib64,usr/{bin,sbin,lib,lib64},mnt,root,home}
mkdir -p "${ROOTFS_DIR}/var"/{log,run,tmp,spool}
mkdir -p "${ROOTFS_DIR}/etc/ld.so.conf.d"

# Modifikasi izin direktori transient
chmod 1777 "${ROOTFS_DIR}/tmp" "${ROOTFS_DIR}/var/tmp" 2>/dev/null || true

# 2. Menyalin konfigurasi Runit
echo "[*] Menyalin berkas konfigurasi Runit..."
mkdir -p "${ROOTFS_DIR}/etc/runit"
mkdir -p "${ROOTFS_DIR}/etc/runit/runsvdir/default"
mkdir -p "${ROOTFS_DIR}/etc/sv"

if [ -d "${CONFIG_RUNIT}" ]; then
    # Copy stage 1, 2, 3, ctrlaltdel, hostname
    for file in 1 2 3 ctrlaltdel hostname; do
        if [ -f "${CONFIG_RUNIT}/${file}" ]; then
            cp -f "${CONFIG_RUNIT}/${file}" "${ROOTFS_DIR}/etc/runit/"
        fi
    done

    # Set executable flags pada stage 1, 2, 3, ctrlaltdel
    chmod +x "${ROOTFS_DIR}/etc/runit/1" "${ROOTFS_DIR}/etc/runit/2" "${ROOTFS_DIR}/etc/runit/3" "${ROOTFS_DIR}/etc/runit/ctrlaltdel" 2>/dev/null || true

    # Copy hostname ke /etc/hostname
    if [ -f "${CONFIG_RUNIT}/hostname" ]; then
        cp -f "${CONFIG_RUNIT}/hostname" "${ROOTFS_DIR}/etc/hostname"
    fi

    # Copy services jika ada
    if [ -d "${CONFIG_RUNIT}/sv" ]; then
        cp -r "${CONFIG_RUNIT}/sv/"* "${ROOTFS_DIR}/etc/sv/" 2>/dev/null || true
        
        # Set executable pada script run
        find "${ROOTFS_DIR}/etc/sv" -type f -name "run" -exec chmod +x {} + 2>/dev/null || true
        
        # Buat symlink service ke default runsvdir
        echo "[*] Mengaktifkan default services (getty-tty1, getty-tty2)..."
        for sv_name in getty-tty1 getty-tty2; do
            if [ -d "${ROOTFS_DIR}/etc/sv/${sv_name}" ]; then
                ln -sf "/etc/sv/${sv_name}" "${ROOTFS_DIR}/etc/runit/runsvdir/default/${sv_name}"
            fi
        done
    fi

    # Buat symlink current -> default jika belum ada
    ln -sf "default" "${ROOTFS_DIR}/etc/runit/runsvdir/current"
fi

# 3. Membuat symlink /sbin/init -> runit / runit-init
echo "[*] Menyiapkan symlink /sbin/init..."
ln -sf "/sbin/runit-init" "${ROOTFS_DIR}/sbin/init" 2>/dev/null || true
ln -sf "/etc/runit/1" "${ROOTFS_DIR}/sbin/runit-stage1" 2>/dev/null || true

# 4. Membikin file konfigurasi fstab minimal jika belum ada
if [ ! -f "${ROOTFS_DIR}/etc/fstab" ]; then
    echo "[*] Membuat /etc/fstab minimal..."
    cat << 'EOF' > "${ROOTFS_DIR}/etc/fstab"
# /etc/fstab: AQJ OS static file system information
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
proc            /proc           proc    defaults        0       0
sysfs           /sys            sysfs   defaults        0       0
devtmpfs        /dev            devtmpfs defaults       0       0
devpts          /dev/pts        devpts  gid=5,mode=620  0       0
tmpfs           /dev/shm        tmpfs   defaults        0       0
tmpfs           /run            tmpfs   mode=0755       0       0
tmpfs           /tmp            tmpfs   defaults        0       0
EOF
fi

# 5. Menjalankan builder Glibc jika ada
BUILD_GLIBC_SCRIPT="${SCRIPT_DIR}/build_glibc.sh"
if [ -x "${BUILD_GLIBC_SCRIPT}" ]; then
    echo "[*] Menjalankan Glibc build pipeline..."
    "${BUILD_GLIBC_SCRIPT}"
fi

# 6. Ringkasan
echo "-----------------------------------------------------------------"
echo "[✓] RootFS, konfigurasi Runit, dan Glibc pipeline sukses disiapkan!"
echo "    Lokasi RootFS: ${ROOTFS_DIR}"
echo "================================================================="

