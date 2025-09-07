# Linux PipeWire with PulseAudio compatibility + WirePlumber Setup for Macs with Cirrus CS8409
![Tested on iMac 2019](https://img.shields.io/badge/Tested%20on-iMac%202019-2b90ff?logo=apple&logoColor=white&style=flat-square)
[![ShellCheck](https://img.shields.io/github/actions/workflow/status/frogro/cs8409-alsa-install/main.yml?branch=main&label=ShellCheck<br/>&logo=gnu-bash&logoColor=white&style=flat-square)](https://github.com/frogro/cs8409-alsa-install/actions/workflows/main.yml)

This repository provides a **one-click installer** that sets up **PipeWire with PulseAudio compatibility + WirePlumber** on compatible Mac models such as **iMac and MacBook devices** using the **Cirrus Logic CS8409** audio device.

✅ Verified on **iMac 21.5-inch 4K Late 2019**. Other CS8409-based Macs may also be supported.<br/>✅ Verified on Debian 12 (Bookworm) and Debian 13 (Trixie). Other Linux distributions or versions — especially Debian-based ones such as Ubuntu or Linux Mint — may also work, but have not been tested.

> **Important:** This repository does **not** build or install the kernel driver itself.  
> Install the driver first via: [frogro/cs8409-dkms-wrapper](https://github.com/frogro/cs8409-dkms-wrapper).

## What it does (and nothing more)

- Removes any APT pinning against PipeWire
- Installs **PipeWire stack** (`pipewire`, `pipewire-pulse`, `pipewire-alsa`, `wireplumber`) + `pulseaudio-utils`, `alsa-utils`
- Runs `alsactl init` once
- In the user scope:
  - Enables `pipewire.socket`, `pipewire-pulse.socket`, `wireplumber.service`
  - Disables `pulseaudio.service`, `pulseaudio.socket`
  - Removes mask symlinks from `~/.config/systemd/user/`
- Starts user manager (`user@UID.service`) headless for systemctl access
- Immediately starts and verifies services (if user bus reachable)
- Uses `pactl` (PulseAudio API on PipeWire) and `wpctl` (native PipeWire) for verification
- Ends with reboot/logout prompt

**Result:**  
- Active profile: **ALSA + PipeWire 0.3.65 + WirePlumber + pipewire-pulse**  
- `pactl info` → `Server Name: PulseAudio (on PipeWire 0.3.65)`

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
sudo chmod +x cs8409-pipewire-*.sh
sudo ./cs8409-pipewire-install.sh
reboot
```

## Verify after login
```bash
systemctl --user is-active pipewire.socket pipewire-pulse.socket wireplumber.service
# expected: all "active"
pactl info | egrep 'Server Name'
# expected: "Server Name: PulseAudio (on PipeWire …)"
wpctl status | sed -n '/Audio//Video/p'
# expected: your internal + HDMI devices, and default sink set (e.g. "Internes Audio Analog Stereo")
```

## Uninstall
Script uninstalls the PipeWire + WirePlumber profile set up by the installer:  
- disables/stops/unmasks PipeWire/WirePlumber user services,
- cleans up mask symlinks,
- re-enables PulseAudio user services (socket-activated).

```bash
sudo ./cs8409-pipewire-uninstall.sh 
reboot
```
## Notes

- Please review before use on production systems.
- Experimental — feedback and pull requests are welcome.

