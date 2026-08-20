#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - util-linux Build & Staging Script
# ==============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARBALL_PATH="${PROJECT_ROOT}/packages/tarballs/util-linux.tar.gz"
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
echo "  AQJ OS - util-linux Build Pipeline"
echo "================================================================="
echo "Project Root : ${PROJECT_ROOT}"
echo "Tarball      : ${TARBALL_PATH}"
echo "RootFS Target: ${STAGING_ROOTFS}"
echo "Jobs (CPU)   : ${JOBS}"
echo "================================================================="

# 1. Verifikasi File Tarball util-linux
if [[ ! -f "${TARBALL_PATH}" ]]; then
    echo "ERROR: File tarball util-linux tidak ditemukan di ${TARBALL_PATH}!" >&2
    exit 1
fi

# 2. Persiapan Folder Build
mkdir -p "${PACKAGES_BUILD_DIR}" "${STAGING_ROOTFS}"

# 3. Ekstraksi Source Code util-linux
EXTRACTED_DIR=$(set +o pipefail; tar -tf "${TARBALL_PATH}" | head -n 1 | cut -f1 -d"/")
if [[ -z "${EXTRACTED_DIR}" ]]; then
    EXTRACTED_DIR="util-linux-2.41"
fi

SRC_DIR="${PACKAGES_BUILD_DIR}/${EXTRACTED_DIR}"

# Clean flag check
if [[ "${1:-}" == "--clean" ]]; then
    echo "[+] Membersihkan direktori build util-linux..."
    rm -rf "${SRC_DIR}"
fi

if [[ ! -d "${SRC_DIR}" ]]; then
    echo "[+] Mengekstrak ${TARBALL_PATH} ke ${PACKAGES_BUILD_DIR}..."
    tar -xzf "${TARBALL_PATH}" -C "${PACKAGES_BUILD_DIR}"
else
    echo "[i] Source code util-linux sudah diekstrak di ${SRC_DIR}."
fi

# 4. Pengecekan OS Host
OS_TYPE="$(uname -s)"
if [[ "${OS_TYPE}" != "Linux" ]]; then
    echo "================================================================="
    echo "  [PERHATIAN] OS Host Terdeteksi: ${OS_TYPE}"
    echo "  Kompilasi util-linux memerlukan lingkungan Linux x86_64."
    echo "  Silakan jalankan script ini di dalam Docker/Container/VM Linux"
    echo "  dengan toolchain GCC & Make untuk mengompilasi binary secara utuh."
    echo "================================================================="
    echo "[+] Ekstraksi util-linux sukses disiapkan di:"
    echo "    ${SRC_DIR}"
    exit 0
fi

# 5. Konfigurasi util-linux
echo "[+] Mengonfigurasi util-linux..."
(
    cd "${SRC_DIR}"
    ./configure \
        --prefix=/usr \
        --exec-prefix=/usr \
        --bindir=/bin \
        --sbindir=/sbin \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --without-python \
        --disable-liblastlog2 \
        --disable-pam-lastlog2 \
        --disable-use-tty-group \
        --disable-makeinstall-chown \
        --disable-makeinstall-setuid
)

# 6. Kompilasi util-linux
echo "[+] Memulai kompilasi util-linux (make -j${JOBS})..."
make -C "${SRC_DIR}" -j"${JOBS}"

# 7. Instalasi ke Staging RootFS
echo "[+] Memasang util-linux ke staging rootfs (${STAGING_ROOTFS})..."
make -C "${SRC_DIR}" install DESTDIR="${STAGING_ROOTFS}"

echo "================================================================="
echo "  Kompilasi & Pemasangan util-linux Selesai dengan Sukses!"
echo "================================================================="
