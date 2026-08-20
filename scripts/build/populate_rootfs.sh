#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - Root Filesystem (RootFS) Populator & Runit Integrator
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CONFIG_RUNIT="${PROJECT_ROOT}/configs/runit"
ROOTFS_DIR="${PROJECT_ROOT}/rootfs"
CLEAN_ARG="${1:-}"

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
    "${BUILD_GLIBC_SCRIPT}" ${CLEAN_ARG}
fi

# Sanitize glibc ld scripts - remove absolute prefixes so linker uses LIBRARY_PATH search
if [ -f "${ROOTFS_DIR}/usr/lib/libc.so" ]; then
    sed -i 's|/lib64/||g; s|/usr/lib/||g' "${ROOTFS_DIR}/usr/lib/libc.so" 2>/dev/null || true
fi
if [ -f "${ROOTFS_DIR}/usr/lib/libm.so" ]; then
    sed -i 's|/lib64/||g; s|/usr/lib/||g' "${ROOTFS_DIR}/usr/lib/libm.so" 2>/dev/null || true
fi

# Export rootfs lib paths so all downstream builds (busybox, util-linux, etc.) find our glibc.
# Do NOT touch /lib64 or /usr/lib — that would break the container's own glibc and tools.
export LIBRARY_PATH="${ROOTFS_DIR}/lib64:${ROOTFS_DIR}/usr/lib${LIBRARY_PATH:+:${LIBRARY_PATH}}"
export PKG_CONFIG_LIBDIR="${ROOTFS_DIR}/usr/lib/pkgconfig:${ROOTFS_DIR}/usr/share/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="${ROOTFS_DIR}"
export CPPFLAGS="-I${ROOTFS_DIR}/usr/include"
export LDFLAGS="-L${ROOTFS_DIR}/lib64 -L${ROOTFS_DIR}/usr/lib -Wl,-rpath-link,${ROOTFS_DIR}/lib64 -Wl,-rpath-link,${ROOTFS_DIR}/usr/lib"
echo "[i] LIBRARY_PATH set to: ${LIBRARY_PATH}"

# 6. Menjalankan builder BusyBox jika ada
BUILD_BUSYBOX_SCRIPT="${SCRIPT_DIR}/build_busybox.sh"
if [ -x "${BUILD_BUSYBOX_SCRIPT}" ]; then
    echo "[*] Menjalankan BusyBox build pipeline..."
    "${BUILD_BUSYBOX_SCRIPT}" ${CLEAN_ARG}
fi

# 7. Menjalankan builder util-linux jika ada
BUILD_UTIL_LINUX_SCRIPT="${SCRIPT_DIR}/build_util_linux.sh"
if [ -x "${BUILD_UTIL_LINUX_SCRIPT}" ]; then
    echo "[*] Menjalankan util-linux build pipeline..."
    "${BUILD_UTIL_LINUX_SCRIPT}" ${CLEAN_ARG}
fi

# 8. Menjalankan builder eudev jika ada
BUILD_EUDEV_SCRIPT="${SCRIPT_DIR}/build_eudev.sh"
if [ -x "${BUILD_EUDEV_SCRIPT}" ]; then
    echo "[*] Menjalankan eudev build pipeline..."
    "${BUILD_EUDEV_SCRIPT}" ${CLEAN_ARG}
fi

# 9. Menjalankan builder iwd jika ada
BUILD_IWD_SCRIPT="${SCRIPT_DIR}/build_iwd.sh"
if [ -x "${BUILD_IWD_SCRIPT}" ]; then
    echo "[*] Menjalankan iwd build pipeline..."
    "${BUILD_IWD_SCRIPT}" ${CLEAN_ARG}
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
    "${BUILD_DHCPCD_SCRIPT}" ${CLEAN_ARG}
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
    "${BUILD_XBPS_SCRIPT}" ${CLEAN_ARG}
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
    "${BUILD_XBPS_SRC_SCRIPT}" ${CLEAN_ARG}
fi

# 18. Menjalankan builder Bash jika ada
BUILD_BASH_SCRIPT="${SCRIPT_DIR}/build_bash.sh"
if [ -x "${BUILD_BASH_SCRIPT}" ]; then
    echo "[*] Menjalankan Bash build pipeline..."
    "${BUILD_BASH_SCRIPT}" ${CLEAN_ARG}
fi

# 19. Menjalankan builder X.Org Server jika ada
BUILD_XORG_SERVER_SCRIPT="${SCRIPT_DIR}/build_xorg_server.sh"
if [ -x "${BUILD_XORG_SERVER_SCRIPT}" ]; then
    echo "[*] Menjalankan X.Org Server build pipeline..."
    "${BUILD_XORG_SERVER_SCRIPT}" ${CLEAN_ARG}
fi

# 20. Menjalankan builder xfdesktop jika ada
BUILD_XFDESKTOP_SCRIPT="${SCRIPT_DIR}/build_xfdesktop.sh"
if [ -x "${BUILD_XFDESKTOP_SCRIPT}" ]; then
    echo "[*] Menjalankan xfdesktop build pipeline..."
    "${BUILD_XFDESKTOP_SCRIPT}" ${CLEAN_ARG}
fi

# 21. Memasang script installer AQJ OS (CLI & GUI Wizard)
INSTALLER_SCRIPT="${PROJECT_ROOT}/scripts/install/installer.sh"
GUI_INSTALLER_SCRIPT="${PROJECT_ROOT}/scripts/install/gui_installer.py"
DESKTOP_ENTRY="${PROJECT_ROOT}/branding/aqj-installer.desktop"

mkdir -p "${ROOTFS_DIR}/sbin" "${ROOTFS_DIR}/usr/share/applications" "${ROOTFS_DIR}/root/Desktop" "${ROOTFS_DIR}/home/aqj/Desktop"

if [ -f "${INSTALLER_SCRIPT}" ]; then
    echo "[*] Memasang AQJ OS CLI installer ke /sbin/aqj-install..."
    cp -f "${INSTALLER_SCRIPT}" "${ROOTFS_DIR}/sbin/aqj-install"
    chmod +x "${ROOTFS_DIR}/sbin/aqj-install"
fi

if [ -f "${GUI_INSTALLER_SCRIPT}" ]; then
    echo "[*] Memasang AQJ OS GUI Wizard installer ke /sbin/aqj-install-gui..."
    cp -f "${GUI_INSTALLER_SCRIPT}" "${ROOTFS_DIR}/sbin/aqj-install-gui"
    chmod +x "${ROOTFS_DIR}/sbin/aqj-install-gui"
fi

if [ -f "${DESKTOP_ENTRY}" ]; then
    echo "[*] Memasang pintasan Desktop Installer di XFCE..."
    cp -f "${DESKTOP_ENTRY}" "${ROOTFS_DIR}/usr/share/applications/aqj-installer.desktop"
    cp -f "${DESKTOP_ENTRY}" "${ROOTFS_DIR}/root/Desktop/aqj-installer.desktop"
    cp -f "${DESKTOP_ENTRY}" "${ROOTFS_DIR}/home/aqj/Desktop/aqj-installer.desktop"
    chmod +x "${ROOTFS_DIR}/root/Desktop/aqj-installer.desktop" "${ROOTFS_DIR}/home/aqj/Desktop/aqj-installer.desktop" 2>/dev/null || true
fi

# 22. Ringkasan
echo "-----------------------------------------------------------------"
echo "[✓] RootFS, Runit, Glibc, BusyBox, util-linux, eudev, iwd, dhcpcd, xbps, void-packages, Bash, X.Org Server, xfdesktop, dan aqj-install-gui pipeline sukses disiapkan!"
echo "    Lokasi RootFS: ${ROOTFS_DIR}"
echo "================================================================="




