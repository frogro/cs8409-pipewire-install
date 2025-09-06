#!/usr/bin/env bash
set -euo pipefail

# cs8409-config-uninstall.sh — revert config to near-stock (no GRUB, no service flips)
# - Entfernt NUR unsere Dateien:
#     /etc/asound.conf
#     /etc/modprobe.d/cs8409.conf
#     /etc/modprobe.d/blacklist-generic.conf
#     /etc/modprobe.d/blacklist-sof.conf
#     /etc/apt/preferences.d/no-pipewire-audio.pref
# - Keine Änderungen an GRUB
# - Keine Änderungen an User-Services (Pulse/PipeWire)
# - Lädt HDA-Treiber neu, speichert ALSA-State
# - Fragt am Ende nach Reboot

msg(){ printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err(){ printf "\033[1;31m[✗] %s\033[0m\n" "$*"; }

[[ $EUID -eq 0 ]] || { err "Please run as root (sudo)."; exit 1; }

msg "Remove our ALSA system defaults (/etc/asound.conf)"
rm -f /etc/asound.conf

msg "Remove cs8409 modprobe options"
/bin/rm -f /etc/modprobe.d/cs8409.conf

msg "Remove our blacklist files (generic & SOF)"
/bin/rm -f /etc/modprobe.d/blacklist-generic.conf \
         /etc/modprobe.d/blacklist-sof.conf

PIN=/etc/apt/preferences.d/no-pipewire-audio.pref
if [[ -f "$PIN" ]]; then
  msg "Remove APT pin (no-pipewire-audio.pref)"
  rm -f "$PIN"
fi

msg "Reload snd_hda_intel and store ALSA state"
modprobe -r snd_hda_intel 2>/dev/null || true
modprobe snd_hda_intel  || true
alsactl store          || true

msg "Cleanup done. A reboot is recommended."

read -rp "Do you want to reboot now? (y/n) " ans || true
case "${ans:-n}" in
  [Yy]* ) reboot ;;
  * ) echo "Reboot skipped. Please reboot later to apply kernel/module changes."; ;;
esac
