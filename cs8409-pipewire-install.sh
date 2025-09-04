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

have_cmd(){ command -v "$1" >/dev/null 2>&1; }

ensure_packages() {
  if have_cmd apt-get; then
    msg "Installing packages: pipewire, pipewire-pulse, wireplumber, pulseaudio-utils, alsa-utils …"
    DEBIAN_FRONTEND=noninteractive apt-get update -y || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y pipewire pipewire-pulse wireplumber pulseaudio-utils alsa-utils || true
  else
    warn "apt-get not found — please install PipeWire + WirePlumber + ALSA utilities manually for your distro."
  fi
}

enable_user_services() {
  local user="${SUDO_USER:-$(id -un)}"
  msg "Enabling and starting user services (pipewire, pipewire-pulse, wireplumber) for $user …"
  if [[ -n "$user" && "$user" != "root" ]]; then
    su - "$user" -c 'systemctl --user enable --now pipewire pipewire-pulse wireplumber' || true
  fi
  # In case we're in a root login session with user services available:
  systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
}

alsa_init_once() {
  # Initialize ALSA controls (helps bring up mixer paths for CS8409)
  msg "Running 'alsactl init' once …"
  if have_cmd alsactl; then
    alsactl init || true
  else
    warn "alsactl not found; skipping ALSA init."
  fi
}

main(){
  require_root
  ensure_packages
  enable_user_services
  alsa_init_once
  msg "Done. Please reboot to ensure user sessions pick up the PipeWire stack cleanly."
}

main "$@"
