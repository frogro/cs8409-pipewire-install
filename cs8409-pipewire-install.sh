#!/usr/bin/env bash
set -euo pipefail

# cs8409-pipewire-install.sh — PipeWire + WirePlumber (rev3-guards)
# - Entfernt altes APT-Pinning gegen PipeWire (falls vorhanden)
# - Installiert pipewire, pipewire-pulse, pipewire-alsa, wireplumber (+ utils)
# - Startet headless user@UID.service, räumt User-Masken (/dev/null Symlinks) auf
# - Enable: pipewire.socket, pipewire-pulse.socket, wireplumber.service
# - Disable: pulseaudio.service/.socket
# - GUARD: Wenn User-Bus erreichbar → sofort starten + prüfen; sonst Hinweis "reboot/login"

msg(){ printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err(){ printf "\033[1;31m[✗] %s\033[0m\n" "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

ORIG_USER=""
for a in "${@}"; do
  case "$a" in
    --orig-user=*) ORIG_USER="${a#*=}";;
  esac
done

# --- self-escalate if not root
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  ORIG_USER="${USER}"
  if ! have sudo; then err "sudo not found. Please run this script with sudo."; exit 1; fi
  msg "Re-executing with sudo for system changes…"
  exec sudo -E bash "$0" "--orig-user=${ORIG_USER}"
fi

# --- now root
if [[ -z "${ORIG_USER}" ]]; then
  ORIG_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
fi
if [[ "${ORIG_USER}" == "root" || -z "${ORIG_USER}" ]]; then
  warn "Could not detect a non-root target user. Using: root"
fi

# helpers
start_user_manager(){
  local user="$1" uid
  uid=$(id -u "$user")
  loginctl enable-linger "$user" >/dev/null 2>&1 || true
  systemctl start "user@${uid}.service" || true
  sleep 0.5
}
userctl(){ local user="$1"; shift; systemctl --user --machine="${user}@" "$@"; }
user_bus_ok(){
  local user="$1"
  userctl "$user" show-environment >/dev/null 2>&1
}
rm_user_mask_symlinks(){
  local user="$1" home d
  home=$(eval echo "~${user}")
  d="${home}/.config/systemd/user"
  [[ -d "$d" ]] || return 0
  for unit in pipewire.service pipewire.socket pipewire-pulse.service pipewire-pulse.socket wireplumber.service pulseaudio.service pulseaudio.socket; do
    if [[ -L "$d/$unit" ]] && [[ "$(readlink -f "$d/$unit")" == "/dev/null" ]]; then
      msg "Remove user mask symlink: $d/$unit"
      rm -f "$d/$unit" || true
    fi
  done
}
pactl_user(){
  local user="$1"; shift
  local uid xdg pulse; uid=$(id -u "$user"); xdg="/run/user/${uid}"; pulse="${xdg}/pulse"
  sudo -u "$user" XDG_RUNTIME_DIR="$xdg" PULSE_RUNTIME_PATH="$pulse" "$@"
}

ensure_packages(){
  # evtl. APT-Pinning gegen PipeWire aufheben
  if [[ -f /etc/apt/preferences.d/no-pipewire-audio.pref ]]; then
    warn "Found APT pin blocking PipeWire → removing"
    rm -f /etc/apt/preferences.d/no-pipewire-audio.pref
  fi
  if have apt-get; then
    msg "Installing packages: pipewire, pipewire-pulse, pipewire-alsa, wireplumber, pulseaudio-utils, alsa-utils …"
    DEBIAN_FRONTEND=noninteractive apt-get update -y || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      pipewire pipewire-pulse pipewire-alsa wireplumber pulseaudio-utils alsa-utils || true
  else
    warn "apt-get not found — install PipeWire + WirePlumber + ALSA utils manually."
  fi
}

alsa_init_once(){
  msg "Running 'alsactl init' once …"
  if have alsactl; then alsactl init || true; else warn "alsactl not found; skipping ALSA init."; fi
}

enable_user_services(){
  local user="$1"
  msg "Configuring user services for ${user} …"
  start_user_manager "$user"
  rm_user_mask_symlinks "$user"
  userctl "$user" daemon-reload || true

  # Enable PipeWire stack; disable PulseAudio daemon
  userctl "$user" unmask pipewire.service pipewire.socket pipewire-pulse.service pipewire-pulse.socket wireplumber.service || true
  userctl "$user" enable pipewire.socket pipewire-pulse.socket wireplumber.service || true
  userctl "$user" disable --now pulseaudio.service pulseaudio.socket || true
}

start_and_verify_if_possible(){
  local user="$1"
  if user_bus_ok "$user"; then
    msg "User bus reachable → starting PipeWire stack now"
    # kleine Aufräumaktion: evtl. Blockierer lösen
    fuser -k /dev/snd/* 2>/dev/null || true

    # Start/Restart services
    userctl "$user" start  pipewire.socket pipewire-pulse.socket || true
    userctl "$user" restart wireplumber.service || true
    userctl "$user" start  pipewire.service   || true
    sleep 1

    echo "--- CHECK pactl ---"
    if pactl_user "$user" pactl info >/dev/null 2>&1; then
      pactl_user "$user" pactl info | egrep 'Name des Servers|Version des Servers|Standard-Ziel' || true
    else
      warn "pipewire-pulse not ready yet → restarting sockets"
      userctl "$user" restart pipewire-pulse.socket || true
      sleep 1
      pactl_user "$user" pactl info | egrep 'Name des Servers|Standard-Ziel' || true
    fi

    echo "--- CHECK wpctl ---"
    if have wpctl && wpctl status >/dev/null 2>&1; then
      wpctl status | sed -n '/Audio/,/Video/p'
    else
      warn "wpctl cannot connect yet (PipeWire). If this persists, re-login or reboot."
    fi
  else
    warn "No reachable user bus. Services are enabled but will start after reboot/login."
    echo "Run after login (as ${user}):"
    echo "  systemctl --user daemon-reload"
    echo "  systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service"
    echo "  systemctl --user disable --now pulseaudio.service pulseaudio.socket || true"
    echo "  pactl info | egrep 'Name des Servers|Standard-Ziel'"
    echo "  wpctl status | sed -n '/Audio/,/Video/p'"
  fi
}

main(){
  ensure_packages
  alsa_init_once
  enable_user_services "${ORIG_USER}"
  start_and_verify_if_possible "${ORIG_USER}"

  msg "Done. If you didn't have a user session, please reboot or log out/in to apply."
  read -rp "Reboot now? (y/n) " ans || true
  case "${ans:-n}" in
    [Yy]* ) reboot ;;
    * ) echo "Reboot skipped. Log out/in to start PipeWire user services if they aren't running yet." ;;
  esac
}

main "$@"
