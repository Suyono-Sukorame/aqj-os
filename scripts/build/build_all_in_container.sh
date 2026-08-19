#!/usr/bin/env bash
# ==============================================================================
# AQJ OS - Master Container Builder (One-Click Full ISO Generation)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
IMAGE_NAME="aqj-os-builder:latest"
CONTAINER_NAME="aqj-os-builder-run"

echo "================================================================="
echo "       AQJ OS - Master Container Build Pipeline (Linux x86_64)"
echo "================================================================="
echo "Project Root : ${PROJECT_ROOT}"
echo "Docker Image : ${IMAGE_NAME}"
echo "-----------------------------------------------------------------"

# Help flag check
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Penggunaan: ./scripts/build/build_all_in_container.sh [--clean]"
    echo ""
    echo "Opsi:"
    echo "  --clean    Membersihkan direktori build sebelum kompilasi penuh."
    echo "  --help     Menampilkan pesan bantuan ini."
    exit 0
fi

# 1. Deteksi Container Engine (docker / podman / orb)
CONTAINER_CLI=""
if command -v docker &>/dev/null; then
    CONTAINER_CLI="docker"
elif command -v orb &>/dev/null; then
    CONTAINER_CLI="orb"
elif command -v podman &>/dev/null; then
    CONTAINER_CLI="podman"
else
    echo "ERROR: Docker / Podman / OrbStack tidak ditemukan pada sistem Host Anda!" >&2
    echo "Silakan install Docker Desktop atau OrbStack untuk menjalankan kompilasi kontainer." >&2
    exit 1
fi

echo "[*] Menggunakan Container Engine: ${CONTAINER_CLI}"

# 2. Build Docker Image (jika belum ada)
if ! ${CONTAINER_CLI} image inspect "${IMAGE_NAME}" &>/dev/null; then
    echo "[*] Mem-build Docker Image '${IMAGE_NAME}' dari Dockerfile.builder..."
    ${CONTAINER_CLI} build --platform linux/amd64 -t "${IMAGE_NAME}" -f "${PROJECT_ROOT}/Dockerfile.builder" "${PROJECT_ROOT}"
else
    echo "[i] Docker Image '${IMAGE_NAME}' sudah tersedia."
fi

# 3. Parameter tambahan
CLEAN_ARG=""
if [[ "${1:-}" == "--clean" ]]; then
    CLEAN_ARG="--clean"
fi

# 4. Jalankan kompilasi penuh di dalam Kontainer Linux
echo "[*] Meluncurkan Kontainer Linux untuk kompilasi penuh 12 komponen..."
echo "-----------------------------------------------------------------"

${CONTAINER_CLI} run --rm \
    --platform linux/amd64 \
    --name "${CONTAINER_NAME}" \
    -v "${PROJECT_ROOT}:/workspace" \
    "${IMAGE_NAME}" \
    /bin/bash -c "
        set -euo pipefail
        echo '[1/4] Kompilasi Linux Kernel 7.1.8...'
        ./scripts/build/build_kernel.sh ${CLEAN_ARG}

        echo '[2/4] Kompilasi & Staging RootFS (12 Komponen Biner ELF)...'
        ./scripts/build/populate_rootfs.sh ${CLEAN_ARG}

        echo '[3/4] Mengompresi Initramfs...'
        ./scripts/build/build_initramfs.sh

        echo '[4/4] Mem-build Bootable Live ISO dengan Limine Bootloader...'
        ./scripts/build/build_iso.sh
    "

echo "================================================================="
echo " [✓] Kompilasi Penuh AQJ OS Selesai dengan Sukses!"
echo " Berkas Live ISO: ${PROJECT_ROOT}/iso/aqj-os-7.1.8-x86_64.iso"
echo "================================================================="
