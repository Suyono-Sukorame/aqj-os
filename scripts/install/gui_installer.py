#!/usr/bin/env python3
# ==============================================================================
# AQJ OS - GUI Wizard Installer (aqj-install-gui)
# ==============================================================================
import os
import sys
import json
import subprocess
import threading
import tkinter as tk
from tkinter import ttk, messagebox

# Color Palette (AQJ OS Modern Dark Theme)
BG_DARK = "#1e1e2e"
FG_LIGHT = "#cdd6f4"
ACCENT_BLUE = "#89b4fa"
ACCENT_GREEN = "#a6e3a1"
ACCENT_RED = "#f38ba8"
CONTAINER_BG = "#313244"
TEXT_SUB = "#bac2de"

class AQJInstallerApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("AQJ OS System Installer")
        self.geometry("640x480")
        self.resizable(False, False)
        self.configure(bg=BG_DARK)

        # Style configuration
        self.style = ttk.Style(self)
        self.style.theme_use("clam")
        
        # Configure styles
        self.style.configure(".", background=BG_DARK, foreground=FG_LIGHT, font=("Sans", 10))
        self.style.configure("TFrame", background=BG_DARK)
        self.style.configure("Card.TFrame", background=CONTAINER_BG, relief="flat")
        self.style.configure("Header.TLabel", font=("Sans", 16, "bold"), foreground=ACCENT_BLUE, background=BG_DARK)
        self.style.configure("SubHeader.TLabel", font=("Sans", 11), foreground=TEXT_SUB, background=BG_DARK)
        self.style.configure("Primary.TButton", font=("Sans", 10, "bold"), background=ACCENT_BLUE, foreground="#11111b")
        self.style.map("Primary.TButton", background=[("active", "#74c7ec")])
        self.style.configure("Danger.TButton", font=("Sans", 10, "bold"), background=ACCENT_RED, foreground="#11111b")

        # Installer State
        self.selected_disk = tk.StringVar()
        self.hostname_var = tk.StringVar(value="aqj-os")
        self.username_var = tk.StringVar(value="aqj")
        self.password_var = tk.StringVar(value="aqj123")
        self.timezone_var = tk.StringVar(value="Asia/Jakarta")
        self.disks_info = {}

        # Container Frame for Wizard Steps
        self.container = ttk.Frame(self)
        self.container.pack(fill="both", expand=True, padx=24, pady=20)

        self.frames = {}
        for StepClass in (WelcomeStep, DiskStep, ConfigStep, InstallStep):
            step_name = StepClass.__name__
            frame = StepClass(parent=self.container, controller=self)
            self.frames[step_name] = frame
            frame.grid(row=0, column=0, sticky="nsew")

        self.show_frame("WelcomeStep")

    def show_frame(self, step_name):
        frame = self.frames[step_name]
        if hasattr(frame, "on_show"):
            frame.on_show()
        frame.tkraise()

    def get_available_disks(self):
        disks = []
        self.disks_info = {}
        try:
            cmd = ["lsblk", "-J", "-o", "NAME,SIZE,MODEL,TYPE,MOUNTPOINT"]
            res = subprocess.run(cmd, capture_output=True, text=True, check=True)
            data = json.loads(res.stdout)
            for dev in data.get("blockdevices", []):
                if dev.get("type") == "disk":
                    name = "/dev/" + dev.get("name", "")
                    size = dev.get("size", "N/A")
                    model = dev.get("model", "Generic Drive").strip() or "Generic Storage"
                    display_str = f"{name} ({size}) - {model}"
                    disks.append(display_str)
                    self.disks_info[display_str] = name
        except Exception as e:
            # Fallback parsing if lsblk json not available
            try:
                out = subprocess.check_output("lsblk -d -n -o NAME,SIZE,TYPE", shell=True, text=True)
                for line in out.strip().split("\n"):
                    parts = line.split()
                    if len(parts) >= 3 and parts[2] == "disk":
                        name = "/dev/" + parts[0]
                        size = parts[1]
                        display_str = f"{name} ({size}) - Storage Drive"
                        disks.append(display_str)
                        self.disks_info[display_str] = name
            except Exception:
                pass
        return disks

# Step 1: Welcome Screen
class WelcomeStep(ttk.Frame):
    def __init__(self, parent, controller):
        super().__init__(parent)
        self.controller = controller

        lbl_header = ttk.Label(self, text="Selamat Datang di AQJ OS", style="Header.TLabel")
        lbl_header.pack(anchor="w", pady=(10, 4))

        lbl_sub = ttk.Label(self, text="AQJ OS - Linux 7.1.8 Custom Distribution", style="SubHeader.TLabel")
        lbl_sub.pack(anchor="w", pady=(0, 20))

        card = ttk.Frame(self, style="Card.TFrame")
        card.pack(fill="both", expand=True, padx=4, pady=10)

        info_text = (
            "Installer GUI ini akan memandu Anda memasang AQJ OS ke Drive/SSD PC atau Virtual Machine Anda.\n\n"
            "Fitur Instalasi AQJ OS:\n"
            "  • Kernel Linux 7.1.8 kustom berkinerja tinggi\n"
            "  • Bootloader Limine (Dukungan BIOS & UEFI)\n"
            "  • Runit Init Service & Desktop Environment XFCE\n"
            "  • Paket Manajemen XBPS & Installer Otomatis\n\n"
            "Klik tombol 'Lanjut' di bawah ini untuk memulai pemilihan drive target."
        )
        lbl_info = tk.Label(card, text=info_text, bg=CONTAINER_BG, fg=FG_LIGHT, font=("Sans", 10), justify="left", wraplength=550)
        lbl_info.pack(padx=20, pady=20, anchor="w")

        btn_frame = ttk.Frame(self)
        btn_frame.pack(fill="x", side="bottom", pady=10)

        btn_next = ttk.Button(btn_frame, text="Lanjut ➔", style="Primary.TButton", command=lambda: controller.show_frame("DiskStep"))
        btn_next.pack(side="right")

# Step 2: Disk Selection
class DiskStep(ttk.Frame):
    def __init__(self, parent, controller):
        super().__init__(parent)
        self.controller = controller

        lbl_header = ttk.Label(self, text="[1/3] Pilih Drive Target", style="Header.TLabel")
        lbl_header.pack(anchor="w", pady=(10, 4))

        lbl_sub = ttk.Label(self, text="Pilih drive/SSD tempat AQJ OS akan dipasang", style="SubHeader.TLabel")
        lbl_sub.pack(anchor="w", pady=(0, 15))

        card = ttk.Frame(self, style="Card.TFrame")
        card.pack(fill="both", expand=True, padx=4, pady=10)

        lbl_select = tk.Label(card, text="Daftar Storage Drive Terdeteksi:", bg=CONTAINER_BG, fg=ACCENT_BLUE, font=("Sans", 10, "bold"))
        lbl_select.pack(anchor="w", padx=15, pady=(15, 5))

        self.disk_combo = ttk.Combobox(card, textvariable=self.controller.selected_disk, state="readonly", font=("Sans", 10))
        self.disk_combo.pack(fill="x", padx=15, pady=10)

        lbl_warn = tk.Label(
            card,
            text="⚠️ PERHATIAN: Seluruh data pada drive yang dipilih akan diformat bersih!",
            bg=CONTAINER_BG,
            fg=ACCENT_RED,
            font=("Sans", 9, "bold"),
            justify="left"
        )
        lbl_warn.pack(anchor="w", padx=15, pady=(10, 15))

        btn_frame = ttk.Frame(self)
        btn_frame.pack(fill="x", side="bottom", pady=10)

        btn_back = ttk.Button(btn_frame, text="⬅ Kembali", command=lambda: controller.show_frame("WelcomeStep"))
        btn_back.pack(side="left")

        btn_next = ttk.Button(btn_frame, text="Lanjut ➔", style="Primary.TButton", command=self.next_step)
        btn_next.pack(side="right")

    def on_show(self):
        disks = self.controller.get_available_disks()
        self.disk_combo["values"] = disks
        if disks and not self.controller.selected_disk.get():
            self.disk_combo.current(0)

    def next_step(self):
        if not self.controller.selected_disk.get():
            messagebox.showerror("Error", "Silakan pilih drive target terlebih dahulu!")
            return
        self.controller.show_frame("ConfigStep")

# Step 3: User & System Configuration
class ConfigStep(ttk.Frame):
    def __init__(self, parent, controller):
        super().__init__(parent)
        self.controller = controller

        lbl_header = ttk.Label(self, text="[2/3] Pengaturan Sistem & Pengguna", style="Header.TLabel")
        lbl_header.pack(anchor="w", pady=(10, 4))

        lbl_sub = ttk.Label(self, text="Konfigurasi nama komputer, username, dan password", style="SubHeader.TLabel")
        lbl_sub.pack(anchor="w", pady=(0, 15))

        card = ttk.Frame(self, style="Card.TFrame")
        card.pack(fill="both", expand=True, padx=4, pady=10)

        # Form Entries
        grid_frame = tk.Frame(card, bg=CONTAINER_BG)
        grid_frame.pack(fill="both", expand=True, padx=15, pady=15)

        tk.Label(grid_frame, text="Hostname PC:", bg=CONTAINER_BG, fg=FG_LIGHT, font=("Sans", 10)).grid(row=0, column=0, sticky="w", pady=8)
        ent_host = ttk.Entry(grid_frame, textvariable=controller.hostname_var)
        ent_host.grid(row=0, column=1, sticky="ew", padx=10, pady=8)

        tk.Label(grid_frame, text="Username Baru:", bg=CONTAINER_BG, fg=FG_LIGHT, font=("Sans", 10)).grid(row=1, column=0, sticky="w", pady=8)
        ent_user = ttk.Entry(grid_frame, textvariable=controller.username_var)
        ent_user.grid(row=1, column=1, sticky="ew", padx=10, pady=8)

        tk.Label(grid_frame, text="Password User & Root:", bg=CONTAINER_BG, fg=FG_LIGHT, font=("Sans", 10)).grid(row=2, column=0, sticky="w", pady=8)
        ent_pass = ttk.Entry(grid_frame, textvariable=controller.password_var, show="*")
        ent_pass.grid(row=2, column=1, sticky="ew", padx=10, pady=8)

        tk.Label(grid_frame, text="Timezone Sistem:", bg=CONTAINER_BG, fg=FG_LIGHT, font=("Sans", 10)).grid(row=3, column=0, sticky="w", pady=8)
        cb_tz = ttk.Combobox(grid_frame, textvariable=controller.timezone_var, values=["Asia/Jakarta", "Asia/Makassar", "Asia/Jayapura", "UTC"], state="readonly")
        cb_tz.grid(row=3, column=1, sticky="ew", padx=10, pady=8)

        grid_frame.columnconfigure(1, weight=1)

        btn_frame = ttk.Frame(self)
        btn_frame.pack(fill="x", side="bottom", pady=10)

        btn_back = ttk.Button(btn_frame, text="⬅ Kembali", command=lambda: controller.show_frame("DiskStep"))
        btn_back.pack(side="left")

        btn_next = ttk.Button(btn_frame, text="Mulai Instalasi ➔", style="Primary.TButton", command=self.confirm_install)
        btn_next.pack(side="right")

    def confirm_install(self):
        disk_str = self.controller.selected_disk.get()
        target_dev = self.controller.disks_info.get(disk_str, disk_str)

        msg = (
            f"Apakah Anda yakin ingin memulai instalasi AQJ OS?\n\n"
            f"Drive Target : {target_dev}\n"
            f"Hostname     : {self.controller.hostname_var.get()}\n"
            f"Username     : {self.controller.username_var.get()}\n"
            f"Timezone     : {self.controller.timezone_var.get()}\n\n"
            f"⚠️ SELURUH DATA PADA DRIVE {target_dev} AKAN DIHAPUS PERMANEN!"
        )
        if messagebox.askyesno("Konfirmasi Instalasi", msg, icon="warning"):
            self.controller.show_frame("InstallStep")

# Step 4: Installation Progress
class InstallStep(ttk.Frame):
    def __init__(self, parent, controller):
        super().__init__(parent)
        self.controller = controller

        lbl_header = ttk.Label(self, text="[3/3] Memasang AQJ OS...", style="Header.TLabel")
        lbl_header.pack(anchor="w", pady=(10, 4))

        self.lbl_status = ttk.Label(self, text="Menyiapkan proses instalasi...", style="SubHeader.TLabel")
        self.lbl_status.pack(anchor="w", pady=(0, 15))

        card = ttk.Frame(self, style="Card.TFrame")
        card.pack(fill="both", expand=True, padx=4, pady=10)

        self.pbar = ttk.Progressbar(card, mode="determinate", maximum=100)
        self.pbar.pack(fill="x", padx=20, pady=(30, 15))

        self.txt_log = tk.Text(card, bg="#11111b", fg=FG_LIGHT, font=("Monospace", 9), height=10, state="disabled")
        self.txt_log.pack(fill="both", expand=True, padx=20, pady=(0, 20))

        self.btn_finish = ttk.Button(self, text="Reboot Komputer Now", style="Primary.TButton", command=self.reboot_system, state="disabled")
        self.btn_finish.pack(side="bottom", pady=10)

    def log_message(self, msg):
        self.txt_log.config(state="normal")
        self.txt_log.insert("end", msg + "\n")
        self.txt_log.see("end")
        self.txt_log.config(state="disabled")

    def on_show(self):
        self.pbar["value"] = 0
        threading.Thread(target=self.run_installation, daemon=True).start()

    def run_installation(self):
        disk_str = self.controller.selected_disk.get()
        target_dev = self.controller.disks_info.get(disk_str, disk_str)
        hostname = self.controller.hostname_var.get()
        username = self.controller.username_var.get()
        password = self.controller.password_var.get()

        self.log_message(f"[*] Target Drive: {target_dev}")
        self.log_message(f"[*] Hostname: {hostname}, User: {username}")
        self.pbar["value"] = 10
        self.lbl_status.config(text="Mempartisi dan mengonfigurasi drive...")

        cmd = [
            "aqj-install",
            "--non-interactive",
            "--disk", target_dev,
            "--hostname", hostname,
            "--username", username,
            "--password", password
        ]

        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            for line in proc.stdout:
                line_str = line.strip()
                if line_str:
                    self.log_message(line_str)
                    if "[1/6]" in line_str:
                        self.pbar["value"] = 20
                    elif "[2/6]" in line_str:
                        self.pbar["value"] = 35
                    elif "[3/6]" in line_str:
                        self.pbar["value"] = 50
                    elif "[4/6]" in line_str:
                        self.pbar["value"] = 75
                    elif "[5/6]" in line_str:
                        self.pbar["value"] = 90
                    elif "[6/6]" in line_str:
                        self.pbar["value"] = 100

            proc.wait()
            if proc.returncode == 0:
                self.pbar["value"] = 100
                self.lbl_status.config(text="[✓] Instalasi AQJ OS Selesai dengan Sukses!")
                self.log_message("\n==================================================")
                self.log_message("[✓] Instalasi AQJ OS telah selesai!")
                self.log_message("Silakan reboot komputer/VM Anda.")
                self.btn_finish.config(state="normal")
            else:
                self.lbl_status.config(text="❌ Instalasi Gagal! Periksa log kesalahan.")
                self.log_message(f"\n[ERROR] Skrip installer mengembalikan kode error {proc.returncode}")
        except Exception as e:
            self.lbl_status.config(text="❌ Kesalahan Eksekusi Installer")
            self.log_message(f"\n[EXCEPTION] {e}")

    def reboot_system(self):
        os.system("reboot || systemctl reboot || shutdown -r now")

if __name__ == "__main__":
    if os.geteuid() != 0:
        print("ERROR: Skrip GUI Installer harus dijalankan sebagai root (sudo)!", file=sys.stderr)
        sys.exit(1)
    app = AQJInstallerApp()
    app.mainloop()
