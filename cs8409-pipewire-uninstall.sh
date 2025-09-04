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

stop_disable_user_services() {
  local user="${SUDO_USER:-$(id -un)}"
  msg "Stopping/disabling user services (pipewire, pipewire-pulse, wireplumber) for $user …"
  if [[ -n "$user" && "$user" != "root" ]]; then
    su - "$user" -c 'systemctl --user disable --now pipewire pipewire-pulse wireplumber' || true
  fi
  systemctl --user disable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
}

main(){
  require_root
  stop_disable_user_services
  msg "Uninstall complete (services stopped/disabled). Reboot recommended."
}

main "$@"
