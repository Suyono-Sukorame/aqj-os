#!/bin/sh
# ==============================================================================
# AQJ OS - Interactive CLI OS Installer (aqj-install)
# ==============================================================================
set -eu

echo "================================================================="
echo "               AQJ OS - System Installer (aqj-install)"
echo "================================================================="
echo " Selamat datang di Installer Resmi AQJ OS!"
echo " Skrip ini akan memandu Anda memasang AQJ OS ke Drive/SSD Anda."
echo "================================================================="

# Pengecekan user root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Skrip installer ini harus dijalankan sebagai pengguna root!" >&2
    exit 1
fi

echo ""
echo "[1/6] Mendeteksi Drive & Partisi yang Tersedia:"
echo "-----------------------------------------------------------------"
if command -v lsblk >/dev/null 2>&1; then
    lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT
else
    fdisk -l 2>/dev/null || echo "Info: fdisk tidak tersedia."
fi
echo "-----------------------------------------------------------------"

printf "\nMasukkan nama drive target (contoh: /dev/sda atau /dev/nvme0n1): "
read -r TARGET_DISK

if [ -z "${TARGET_DISK}" ] || [ ! -b "${TARGET_DISK}" ]; then
    echo "ERROR: Drive target ${TARGET_DISK} tidak valid atau tidak ditemukan!" >&2
    exit 1
fi

echo ""
echo "PERHATIAN KRUSIAL:"
echo "Seluruh data pada drive ${TARGET_DISK} akan DIHAPUS dan DIFORMAT!"
printf "Apakah Anda yakin ingin melanjutkan instalasi ke ${TARGET_DISK}? (y/N): "
read -r CONFIRM

if [ "${CONFIRM}" != "y" ] && [ "${CONFIRM}" != "Y" ]; then
    echo "[!] Instalasi dibatalkan oleh pengguna."
    exit 0
fi

MOUNT_DIR="/mnt/aqj-target"
mkdir -p "${MOUNT_DIR}"

echo ""
echo "[2/6] Mempartisi Drive ${TARGET_DISK}..."
# Otomatisasi skema partisi BIOS/GPT sederhana (1 partisi ext4)
if command -v sfdisk >/dev/null 2>&1; then
    echo "label: dos" | sfdisk "${TARGET_DISK}"
    echo ",,83,*" | sfdisk "${TARGET_DISK}"
fi

# Tentukan nama partisi root
if echo "${TARGET_DISK}" | grep -q "nvme"; then
    ROOT_PART="${TARGET_DISK}p1"
else
    ROOT_PART="${TARGET_DISK}1"
fi

echo ""
echo "[3/6] Mengonfigurasi & Format Filesystem (${ROOT_PART})..."
mkfs.ext4 -F "${ROOT_PART}"

echo ""
echo "[4/6] Mount & Menyalin Berkas Sistem AQJ OS..."
mount "${ROOT_PART}" "${MOUNT_DIR}"

# Menyalin berkas dari live system ke partisi target
cp -a /bin /sbin /usr /lib* /etc /var /opt /root "${MOUNT_DIR}/" 2>/dev/null || true
mkdir -p "${MOUNT_DIR}/dev" "${MOUNT_DIR}/proc" "${MOUNT_DIR}/sys" "${MOUNT_DIR}/run" "${MOUNT_DIR}/tmp" "${MOUNT_DIR}/mnt" "${MOUNT_DIR}/boot"

# Salin kernel & initramfs jika ada
if [ -d "/boot" ]; then
    cp -a /boot/* "${MOUNT_DIR}/boot/" 2>/dev/null || true
fi

echo ""
echo "[5/6] Memasang Bootloader Limine & Mengonfigurasi System..."
# Pasang Limine MBR jika biner limine tersedia
if command -v limine >/dev/null 2>&1; then
    limine bios-install "${TARGET_DISK}" 2>/dev/null || true
fi

# Berkas fstab dasar
cat << EOF > "${MOUNT_DIR}/etc/fstab"
# /etc/fstab: Static file system information for AQJ OS
# <file system>             <mount point>   <type>      <options>       <dump>  <pass>
${ROOT_PART}                /               ext4        errors=remount-ro 0       1
proc                        /proc           proc        nosuid,noexec,nodev 0     0
sysfs                       /sys            sysfs       nosuid,noexec,nodev 0     0
devtmpfs                    /dev            devtmpfs    mode=0755,nosuid    0     0
EOF

# Set Hostname default
echo "aqj-os" > "${MOUNT_DIR}/etc/hostname"

echo ""
echo "[6/6] Selesai & Unmount..."
umount "${MOUNT_DIR}" 2>/dev/null || true

echo "================================================================="
echo " [✓] Instalasi AQJ OS pada drive ${TARGET_DISK} Selesai dengan Sukses!"
echo " Silakan reboot PC/VM Anda dan cabut media installer ISO."
echo "================================================================="
