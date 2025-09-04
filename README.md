# PipeWire Setup for Macs with Cirrus CS8409 (Minimal)

This repository provides a **one-click installer** that sets up **PipeWire** with **WirePlumber** and **pipewire‑pulse** on compatible Mac models such as **iMac and MacBook devices** using the **Cirrus Logic CS8409** audio device.

✅ Verified on **iMac 21.5-inch 4K Late 2019**. Other CS8409-based Macs may also be supported.

> **Important:** This repository does **not** build or install the kernel driver itself.  
> Install the driver first via: [frogro/cs8409-dkms-wrapper](https://github.com/frogro/cs8409-dkms-wrapper).

## What it does (and nothing more)

1) Installs only the essentials: `pipewire`, `pipewire-pulse`, `wireplumber`, `alsa-utils` (APT-based systems).  
2) Enables and starts the **user** services: `pipewire`, `pipewire-pulse`, `wireplumber`.  
3) Initializes ALSA once via `alsactl init` (to bring up the CS8409 paths).

No custom config files are created.

## Usage

### Option A: Clone
```bash
git clone https://github.com/frogro/cs8409-pipewire-install.git
cd cs8409-pipewire-install
chmod +x cs8409-pipewire-install.sh cs8409-pipewire-uninstall.sh
sudo ./cs8409-pipewire-install.sh
reboot
```

### Option B: Download only
```bash
wget https://raw.githubusercontent.com/frogro/cs8409-pipewire-install/main/cs8409-pipewire-install.sh
wget https://raw.githubusercontent.com/frogro/cs8409-pipewire-install/main/cs8409-pipewire-uninstall.sh
chmod +x cs8409-pipewire-*.sh
sudo ./cs8409-pipewire-install.sh
reboot
```

## Verify after login
```bash
systemctl --user --no-pager status pipewire pipewire-pulse wireplumber
pactl info | grep -E 'Server Name|Default.*Sample'
```

## Uninstall (minimal)
Stops/disables the user services (does **not** remove packages):
```bash
sudo ./cs8409-pipewire-uninstall.sh
reboot
```
