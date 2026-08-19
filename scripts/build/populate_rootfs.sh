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

# 6. Menjalankan builder BusyBox jika ada
BUILD_BUSYBOX_SCRIPT="${SCRIPT_DIR}/build_busybox.sh"
if [ -x "${BUILD_BUSYBOX_SCRIPT}" ]; then
    echo "[*] Menjalankan BusyBox build pipeline..."
    "${BUILD_BUSYBOX_SCRIPT}"
fi

# 7. Menjalankan builder util-linux jika ada
BUILD_UTIL_LINUX_SCRIPT="${SCRIPT_DIR}/build_util_linux.sh"
if [ -x "${BUILD_UTIL_LINUX_SCRIPT}" ]; then
    echo "[*] Menjalankan util-linux build pipeline..."
    "${BUILD_UTIL_LINUX_SCRIPT}"
fi

# 8. Menjalankan builder eudev jika ada
BUILD_EUDEV_SCRIPT="${SCRIPT_DIR}/build_eudev.sh"
if [ -x "${BUILD_EUDEV_SCRIPT}" ]; then
    echo "[*] Menjalankan eudev build pipeline..."
    "${BUILD_EUDEV_SCRIPT}"
fi

# 9. Menjalankan builder iwd jika ada
BUILD_IWD_SCRIPT="${SCRIPT_DIR}/build_iwd.sh"
if [ -x "${BUILD_IWD_SCRIPT}" ]; then
    echo "[*] Menjalankan iwd build pipeline..."
    "${BUILD_IWD_SCRIPT}"
fi

# 10. Menyalin konfigurasi iwd ke rootfs
if [ -f "${PROJECT_ROOT}/configs/network/iwd-main.conf" ]; then
    echo "[*] Memasang konfigurasi iwd ke rootfs..."
    mkdir -p "${ROOTFS_DIR}/etc/iwd"
    cp -f "${PROJECT_ROOT}/configs/network/iwd-main.conf" "${ROOTFS_DIR}/etc/iwd/main.conf"
fi

# 11. Mengaktifkan service iwd di Runit
if [ -d "${CONFIG_RUNIT}/sv/iwd" ]; then
    echo "[*] Menyalin dan mengaktifkan service iwd..."
    cp -r "${CONFIG_RUNIT}/sv/iwd" "${ROOTFS_DIR}/etc/sv/"
    chmod +x "${ROOTFS_DIR}/etc/sv/iwd/run" 2>/dev/null || true
    ln -sf "/etc/sv/iwd" "${ROOTFS_DIR}/etc/runit/runsvdir/default/iwd" 2>/dev/null || true
fi

# 12. Menjalankan builder dhcpcd jika ada
BUILD_DHCPCD_SCRIPT="${SCRIPT_DIR}/build_dhcpcd.sh"
if [ -x "${BUILD_DHCPCD_SCRIPT}" ]; then
    echo "[*] Menjalankan dhcpcd build pipeline..."
    "${BUILD_DHCPCD_SCRIPT}"
fi

# 13. Menyalin konfigurasi dhcpcd ke rootfs
if [ -f "${PROJECT_ROOT}/configs/network/dhcpcd.conf" ]; then
    echo "[*] Memasang konfigurasi dhcpcd ke rootfs..."
    cp -f "${PROJECT_ROOT}/configs/network/dhcpcd.conf" "${ROOTFS_DIR}/etc/dhcpcd.conf"
fi

# 14. Mengaktifkan service dhcpcd di Runit
if [ -d "${CONFIG_RUNIT}/sv/dhcpcd" ]; then
    echo "[*] Menyalin dan mengaktifkan service dhcpcd..."
    cp -r "${CONFIG_RUNIT}/sv/dhcpcd" "${ROOTFS_DIR}/etc/sv/"
    chmod +x "${ROOTFS_DIR}/etc/sv/dhcpcd/run" 2>/dev/null || true
    ln -sf "/etc/sv/dhcpcd" "${ROOTFS_DIR}/etc/runit/runsvdir/default/dhcpcd" 2>/dev/null || true
fi

# 15. Menjalankan builder xbps jika ada
BUILD_XBPS_SCRIPT="${SCRIPT_DIR}/build_xbps.sh"
if [ -x "${BUILD_XBPS_SCRIPT}" ]; then
    echo "[*] Menjalankan xbps build pipeline..."
    "${BUILD_XBPS_SCRIPT}"
fi

# 16. Menyalin konfigurasi repositori xbps ke rootfs
if [ -f "${PROJECT_ROOT}/configs/network/xbps-repos.conf" ]; then
    echo "[*] Memasang konfigurasi repositori xbps ke rootfs..."
    mkdir -p "${ROOTFS_DIR}/etc/xbps.d"
    cp -f "${PROJECT_ROOT}/configs/network/xbps-repos.conf" "${ROOTFS_DIR}/etc/xbps.d/00-repository-main.conf"
fi

# 17. Menjalankan builder/setup xbps-src / void-packages jika ada
BUILD_XBPS_SRC_SCRIPT="${SCRIPT_DIR}/build_xbps_src.sh"
if [ -x "${BUILD_XBPS_SRC_SCRIPT}" ]; then
    echo "[*] Menjalankan xbps-src / void-packages setup pipeline..."
    "${BUILD_XBPS_SRC_SCRIPT}"
fi

# 18. Menjalankan builder Bash jika ada
BUILD_BASH_SCRIPT="${SCRIPT_DIR}/build_bash.sh"
if [ -x "${BUILD_BASH_SCRIPT}" ]; then
    echo "[*] Menjalankan Bash build pipeline..."
    "${BUILD_BASH_SCRIPT}"
fi

# 19. Menjalankan builder X.Org Server jika ada
BUILD_XORG_SERVER_SCRIPT="${SCRIPT_DIR}/build_xorg_server.sh"
if [ -x "${BUILD_XORG_SERVER_SCRIPT}" ]; then
    echo "[*] Menjalankan X.Org Server build pipeline..."
    "${BUILD_XORG_SERVER_SCRIPT}"
fi

# 20. Menjalankan builder xfdesktop jika ada
BUILD_XFDESKTOP_SCRIPT="${SCRIPT_DIR}/build_xfdesktop.sh"
if [ -x "${BUILD_XFDESKTOP_SCRIPT}" ]; then
    echo "[*] Menjalankan xfdesktop build pipeline..."
    "${BUILD_XFDESKTOP_SCRIPT}"
fi

# 21. Memasang script installer AQJ OS ke /sbin/aqj-install
INSTALLER_SCRIPT="${PROJECT_ROOT}/scripts/install/installer.sh"
if [ -f "${INSTALLER_SCRIPT}" ]; then
    echo "[*] Memasang AQJ OS installer ke /sbin/aqj-install..."
    mkdir -p "${ROOTFS_DIR}/sbin"
    cp -f "${INSTALLER_SCRIPT}" "${ROOTFS_DIR}/sbin/aqj-install"
    chmod +x "${ROOTFS_DIR}/sbin/aqj-install"
fi

# 22. Ringkasan
echo "-----------------------------------------------------------------"
echo "[✓] RootFS, Runit, Glibc, BusyBox, util-linux, eudev, iwd, dhcpcd, xbps, void-packages, Bash, X.Org Server, xfdesktop, dan aqj-install pipeline sukses disiapkan!"
echo "    Lokasi RootFS: ${ROOTFS_DIR}"
echo "================================================================="




