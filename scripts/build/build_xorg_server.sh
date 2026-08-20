#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - X.Org Server Build & Staging Script
# ==============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARBALL_PATH="${PROJECT_ROOT}/packages/tarballs/xorg-server.tar.gz"
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
echo "  AQJ OS - X.Org Server Build Pipeline (Display Server)"
echo "================================================================="
echo "Project Root : ${PROJECT_ROOT}"
echo "Tarball      : ${TARBALL_PATH}"
echo "RootFS Target: ${STAGING_ROOTFS}"
echo "Jobs (CPU)   : ${JOBS}"
echo "================================================================="

# 1. Verifikasi File Tarball X.Org Server
if [[ ! -f "${TARBALL_PATH}" ]]; then
    echo "ERROR: File tarball X.Org Server tidak ditemukan di ${TARBALL_PATH}!" >&2
    exit 1
fi

# 2. Persiapan Folder Build
mkdir -p "${PACKAGES_BUILD_DIR}" "${STAGING_ROOTFS}"

# 3. Ekstraksi Source Code X.Org Server
EXTRACTED_DIR=$(set +o pipefail; tar -tf "${TARBALL_PATH}" | head -n 1 | cut -f1 -d"/")
if [[ -z "${EXTRACTED_DIR}" ]]; then
    EXTRACTED_DIR="xorg-server-21.1.24"
fi

SRC_DIR="${PACKAGES_BUILD_DIR}/${EXTRACTED_DIR}"

# Clean flag check
if [[ "${1:-}" == "--clean" ]]; then
    echo "[+] Membersihkan direktori build X.Org Server..."
    rm -rf "${SRC_DIR}"
fi

if [[ ! -d "${SRC_DIR}" ]]; then
    echo "[+] Mengekstrak ${TARBALL_PATH} ke ${PACKAGES_BUILD_DIR}..."
    tar -xzf "${TARBALL_PATH}" -C "${PACKAGES_BUILD_DIR}"
else
    echo "[i] Source code X.Org Server sudah diekstrak di ${SRC_DIR}."
fi

# 4. Pengecekan OS Host
OS_TYPE="$(uname -s)"
if [[ "${OS_TYPE}" != "Linux" ]]; then
    echo "================================================================="
    echo "  [PERHATIAN] OS Host Terdeteksi: ${OS_TYPE}"
    echo "  Kompilasi X.Org Server memerlukan lingkungan Linux x86_64."
    echo "  Silakan jalankan script ini di dalam Docker/Container/VM Linux"
    echo "  dengan toolchain GCC, Meson, Ninja, & Pustaka X11."
    echo "================================================================="
    echo "[+] Ekstraksi X.Org Server sukses disiapkan di:"
    echo "    ${SRC_DIR}"
    exit 0
fi

# 5. Konfigurasi X.Org Server (Meson/Ninja)
echo "[+] Mengonfigurasi X.Org Server..."
(
    cd "${SRC_DIR}"
    if [[ -f "meson.build" ]]; then
        meson setup build \
            --prefix=/usr \
            --sysconfdir=/etc \
            --localstatedir=/var \
            -Dxorg=true \
            -Dxwayland=false \
            -Dglamor=true \
            -Dudev=true \
            -Dsystemd_logind=false
        ninja -C build -j"${JOBS}"
        DESTDIR="${STAGING_ROOTFS}" ninja -C build install
    else
        ./configure \
            --prefix=/usr \
            --sysconfdir=/etc \
            --localstatedir=/var \
            --enable-xorg \
            --disable-xwayland \
            --disable-systemd-logind
        make -j"${JOBS}"
        make install DESTDIR="${STAGING_ROOTFS}"
    fi
)

echo "================================================================="
echo "  Kompilasi & Pemasangan X.Org Server Selesai dengan Sukses!"
echo "================================================================="
