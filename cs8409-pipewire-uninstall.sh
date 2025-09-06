#!/usr/bin/env bash
set -euo pipefail

# cs8409-pipewire-uninstall.sh — revert PipeWire + WirePlumber profile (no GRUB changes)
# - Disables/stops/unmasks pipewire*, wireplumber user units
# - Removes ~/.config/systemd/user/* mask symlinks to /dev/null
# - Re-enables PulseAudio user units (socket-activated)
# - Optional: --purge removes pipewire*, wireplumber
#
# Usage: sudo ./cs8409-pipewire-uninstall.sh [--purge]

msg(){ printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err(){ printf "\033[1;31m[✗] %s\033[0m\n" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then exec sudo -E bash "$0" "$@"; fi

PURGE=0
[[ "${1:-}" == "--purge" ]] && PURGE=1

U=${SUDO_USER:-$(logname 2>/dev/null || echo ${USER})}
uid=$(id -u "$U")
HOME_DIR=$(eval echo "~$U")

start_user_manager(){
  loginctl enable-linger "$U" >/dev/null 2>&1 || true
  systemctl start "user@${uid}.service" || true
  sleep 0.4
}
userctl(){ systemctl --user --machine="${U}@" "$@"; }

rm_user_mask_symlinks(){
  local d="${HOME_DIR}/.config/systemd/user"
  [[ -d "$d" ]] || return 0
  for unit in pipewire.service pipewire.socket pipewire-pulse.service pipewire-pulse.socket wireplumber.service pulseaudio.service pulseaudio.socket; do
    if [[ -L "$d/$unit" ]] && [[ "$(readlink -f "$d/$unit")" == "/dev/null" ]]; then
      msg "Removing mask symlink: $d/$unit"
      rm -f "$d/$unit" || true
    fi
  done
}

# 1) User services: stop/disable/unmask PipeWire stack
start_user_manager
msg "Disabling PipeWire/WirePlumber user services"
userctl disable --now pipewire.service pipewire.socket pipewire-pulse.service pipewire-pulse.socket wireplumber.service || true
userctl unmask pipewire.service pipewire.socket pipewire-pulse.service pipewire-pulse.socket wireplumber.service || true
rm_user_mask_symlinks

# 2) Restore PulseAudio user services (enabled; start if bus reachable)
msg "Re-enabling PulseAudio user services (socket-activated)"
userctl unmask pulseaudio.service pulseaudio.socket || true
userctl enable pulseaudio.socket pulseaudio.service || true
userctl start  pulseaudio.socket || true

# 3) Optional package purge
if [[ $PURGE -eq 1 ]]; then
  msg "Purging PipeWire packages"
  DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y \
    pipewire pipewire-alsa pipewire-pulse pipewire-audio wireplumber || true
fi

msg "Done. Log out/in (or reboot) to ensure a clean user session."
