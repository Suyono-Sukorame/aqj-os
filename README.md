# AQJ OS Project

Proyek pengembangan Distribusi Linux kustom **AQJ OS** berbasis kernel **Linux 7.1.8**.

---

## Struktur Direktori

```text
aqj-os/
├── branding/               # Asset logo, wallpaper, dan tema AQJ OS
├── configs/
│   ├── boot/               # Konfigurasi Bootloader & Kernel (.config)
│   ├── network/            # Konfigurasi Jaringan & Firewall
│   ├── runit/              # Service Init Script (runit / sysvinit)
│   └── ssh/                # Konfigurasi SSH Daemon
├── iso/                    # Output ISO Bootable & Kernel image
├── kernel/
│   ├── tarballs/           # Archival tarball source code kernel (linux-7.1.8.tar.gz)
│   ├── patches/            # Patch kustom kernel (.patch)
│   └── build/              # Workdir ekstraksi & kompilasi kernel
├── packages/               # Paket software pendukung AQJ OS
├── rootfs/                 # Root Filesystem Staging Area
└── scripts/
    ├── build/
    │   └── build_kernel.sh # Script otomatisasi kompilasi kernel
    ├── chroot/             # Script chroot environment
    └── install/            # Script installer AQJ OS
```

---

## Cara Membangun Kernel Linux

### 1. Menyiapkan & Mengompilasi Kernel
Jalankan script pembangun kernel:

```bash
./scripts/build/build_kernel.sh
```

Jika ingin membersihkan build sebelumnya dan mengulang dari ekstraksi bersih:

```bash
./scripts/build/build_kernel.sh --clean
```

> **Catatan Kompilasi**: Jika dijalankan di macOS (Darwin), script akan mengekstrak source dan mengecek konfigurasi `.config`. Untuk kompilasi penuh menjadi binary `bzImage` / `vmlinuz` dan modul kernel, jalankan script ini di dalam Container Linux (Docker/Podman/OrbStack) atau VM Linux x86_64.
