#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - GNU Bash 5.3 Build & Staging Script
# ==============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARBALL_PATH="${PROJECT_ROOT}/packages/tarballs/bash.tar.gz"
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
echo "  AQJ OS - GNU Bash Build Pipeline"
echo "================================================================="
echo "Project Root : ${PROJECT_ROOT}"
echo "Tarball      : ${TARBALL_PATH}"
echo "RootFS Target: ${STAGING_ROOTFS}"
echo "Jobs (CPU)   : ${JOBS}"
echo "================================================================="

# 1. Verifikasi File Tarball Bash
if [[ ! -f "${TARBALL_PATH}" ]]; then
    echo "ERROR: File tarball Bash tidak ditemukan di ${TARBALL_PATH}!" >&2
    exit 1
fi

# 2. Persiapan Folder Build
mkdir -p "${PACKAGES_BUILD_DIR}" "${STAGING_ROOTFS}"

# 3. Ekstraksi Source Code Bash
EXTRACTED_DIR=$(set +o pipefail; tar -tf "${TARBALL_PATH}" | head -n 1 | cut -f1 -d"/")
if [[ -z "${EXTRACTED_DIR}" ]]; then
    EXTRACTED_DIR="bash-5.3"
fi

SRC_DIR="${PACKAGES_BUILD_DIR}/${EXTRACTED_DIR}"

# Clean flag check
if [[ "${1:-}" == "--clean" ]]; then
    echo "[+] Membersihkan direktori build Bash..."
    rm -rf "${SRC_DIR}"
fi

if [[ ! -d "${SRC_DIR}" ]]; then
    echo "[+] Mengekstrak ${TARBALL_PATH} ke ${PACKAGES_BUILD_DIR}..."
    tar -xzf "${TARBALL_PATH}" -C "${PACKAGES_BUILD_DIR}"
else
    echo "[i] Source code Bash sudah diekstrak di ${SRC_DIR}."
fi

# 4. Pengecekan OS Host
OS_TYPE="$(uname -s)"
if [[ "${OS_TYPE}" != "Linux" ]]; then
    echo "================================================================="
    echo "  [PERHATIAN] OS Host Terdeteksi: ${OS_TYPE}"
    echo "  Kompilasi GNU Bash memerlukan lingkungan Linux x86_64."
    echo "  Silakan jalankan script ini di dalam Docker/Container/VM Linux"
    echo "  dengan toolchain GCC & Make untuk mengompilasi binary secara utuh."
    echo "================================================================="
    echo "[+] Ekstraksi Bash sukses disiapkan di:"
    echo "    ${SRC_DIR}"
    exit 0
fi

# 5. Konfigurasi Bash
echo "[+] Mengonfigurasi GNU Bash..."
(
    cd "${SRC_DIR}"
    ./configure \
        --prefix=/usr \
        --bindir=/bin \
        --sbindir=/sbin \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --with-installed-readline \
        --without-bash-malloc
)

# 6. Kompilasi Bash
echo "[+] Memulai kompilasi GNU Bash (make -j${JOBS})..."
make -C "${SRC_DIR}" -j"${JOBS}"

# 7. Instalasi ke Staging RootFS
echo "[+] Memasang GNU Bash ke staging rootfs (${STAGING_ROOTFS})..."
make -C "${SRC_DIR}" install DESTDIR="${STAGING_ROOTFS}"
ln -sf /bin/bash "${STAGING_ROOTFS}/bin/sh" 2>/dev/null || true

echo "================================================================="
echo "  Kompilasi & Pemasangan GNU Bash Selesai dengan Sukses!"
echo "================================================================="
