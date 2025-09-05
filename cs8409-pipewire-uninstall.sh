#!/usr/bin/env bash
set -euo pipefail

msg() { printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err() { printf "\033[1;31m[✗] %s\033[0m\n" "$*"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    err "Please run as root (sudo)."
    exit 1
  fi
}

disable_user_services() {
  local user="${SUDO_USER:-$(id -un)}"
  msg "Stopping/disabling user services (pipewire, pipewire-pulse, wireplumber) for $user …"
  if [[ -n "$user" && "$user" != "root" ]]; then
    su - "$user" -c 'systemctl --user disable --now pipewire pipewire-pulse wireplumber' || true
  fi
  systemctl --user disable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
}

remove_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    msg "Removing packages: pipewire, pipewire-pulse, wireplumber, pulseaudio-utils, alsa-utils …"
    DEBIAN_FRONTEND=noninteractive apt-get remove -y pipewire pipewire-pulse wireplumber pulseaudio-utils alsa-utils || true
    # Optional: auch `apt-get autoremove -y` laufen lassen
  else
    warn "apt-get not found — please remove PipeWire/WirePlumber/ALSA utilities manually for your distro."
  fi
}

main(){
  require_root
  disable_user_services
  remove_packages
  msg "Uninstall complete. A reboot is recommended."
}

main "$@"
