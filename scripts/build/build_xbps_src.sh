#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - xbps-src / void-packages Setup Script
# ==============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARBALL_PATH="${PROJECT_ROOT}/packages/tarballs/void-packages.tar.gz"
PACKAGES_DIR="${PROJECT_ROOT}/packages"
VOID_PACKAGES_DIR="${PACKAGES_DIR}/void-packages"

echo "================================================================="
echo "  AQJ OS - xbps-src / void-packages Setup Pipeline"
echo "================================================================="
echo "Project Root       : ${PROJECT_ROOT}"
echo "Tarball            : ${TARBALL_PATH}"
echo "void-packages Dir  : ${VOID_PACKAGES_DIR}"
echo "================================================================="

# 1. Verifikasi File Tarball void-packages
if [[ ! -f "${TARBALL_PATH}" ]]; then
    echo "ERROR: File tarball void-packages tidak ditemukan di ${TARBALL_PATH}!" >&2
    exit 1
fi

# Clean flag check
if [[ "${1:-}" == "--clean" ]]; then
    echo "[+] Membersihkan direktori void-packages..."
    rm -rf "${VOID_PACKAGES_DIR}"
fi

# 2. Ekstraksi void-packages
if [[ ! -d "${VOID_PACKAGES_DIR}" ]]; then
    echo "[+] Mengekstrak ${TARBALL_PATH}..."
    TEMP_EXTRACT_DIR="${PACKAGES_DIR}/void-packages-temp"
    rm -rf "${TEMP_EXTRACT_DIR}"
    mkdir -p "${TEMP_EXTRACT_DIR}"
    tar -xzf "${TARBALL_PATH}" -C "${TEMP_EXTRACT_DIR}" 2>/dev/null || true

    # Pindahkan dari void-packages-master ke packages/void-packages
    INSIDE_DIR=$(set +o pipefail; ls "${TEMP_EXTRACT_DIR}" | head -n 1)
    if [[ -n "${INSIDE_DIR}" && -d "${TEMP_EXTRACT_DIR}/${INSIDE_DIR}" ]]; then
        mv "${TEMP_EXTRACT_DIR}/${INSIDE_DIR}" "${VOID_PACKAGES_DIR}"
    else
        mv "${TEMP_EXTRACT_DIR}" "${VOID_PACKAGES_DIR}"
    fi
    rm -rf "${TEMP_EXTRACT_DIR}"
else
    echo "[i] Source tree void-packages sudah siap di ${VOID_PACKAGES_DIR}."
fi

# 3. Pengaturan Permissions & Konfigurasi etc/conf
echo "[+] Menyiapkan hak akses executable pada xbps-src..."
chmod +x "${VOID_PACKAGES_DIR}/xbps-src" 2>/dev/null || true

if [[ ! -f "${VOID_PACKAGES_DIR}/etc/conf" ]]; then
    echo "[+] Menyiapkan etc/conf default untuk AQJ OS (x86_64)..."
    mkdir -p "${VOID_PACKAGES_DIR}/etc"
    cat << 'EOF' > "${VOID_PACKAGES_DIR}/etc/conf"
# ==============================================================================
# xbps-src configuration - AQJ OS
# ==============================================================================

# Target Machine Architecture
XBPS_TARGET_MACHINE=x86_64

# Number of parallel jobs
XBPS_MAKEJOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Disable strict chroot breakout checks during local builds
XBPS_ALLOW_CHROOT_BREAKOUT=1
EOF
fi

# 4. Pengecekan OS Host
OS_TYPE="$(uname -s)"
if [[ "${OS_TYPE}" != "Linux" ]]; then
    echo "================================================================="
    echo "  [PERHATIAN] OS Host Terdeteksi: ${OS_TYPE}"
    echo "  Kompilasi paket menggunakan xbps-src memerlukan lingkungan Linux x86_64."
    echo "  Silakan jalankan ./xbps-src di dalam Docker/Container/VM Linux."
    echo "================================================================="
fi

echo "================================================================="
echo "  Setup xbps-src / void-packages Selesai dengan Sukses!"
echo "  Lokasi: ${VOID_PACKAGES_DIR}"
echo "================================================================="
