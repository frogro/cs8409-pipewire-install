#!/usr/bin/env bash
set -euo pipefail

# cs8409-pipewire-install.sh — PipeWire + WirePlumber sauber einrichten
# - Kann als normaler User oder mit sudo gestartet werden
# - Eskaliert selbst mit sudo für Systemschritte (Pakete, loginctl, etc.)
# - Aktiviert user services für den "Original-User" (auch wenn via sudo gestartet)
# - Robust gegen "Failed to connect to bus": nutzt Linger + Retry
# - Fragt am Ende nach Reboot

msg(){ printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn(){ printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err(){ printf "\033[1;31m[✗] %s\033[0m\n" "$*"; }

ORIG_USER=""
# --- parse optional internal flag
for a in "${@}"; do
  case "$a" in
    --orig-user=*) ORIG_USER="${a#*=}";;
  esac
done

# --- self-escalate if not root
if [[ $EUID -ne 0 ]]; then
  # figure out original user once
  ORIG_USER="${USER}"
  if ! command -v sudo >/dev/null 2>&1; then
    err "sudo not found. Please run this script with sudo."
    exit 1
  fi
  msg "Re-executing with sudo for system changes…"
  exec sudo -E bash "$0" "--orig-user=${ORIG_USER}"
fi

# at this point we are root
if [[ -z "${ORIG_USER}" ]]; then
  ORIG_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
fi
if [[ "${ORIG_USER}" == "root" || -z "${ORIG_USER}" ]]; then
  warn "Could not detect a non-root target user. Using: root"
fi

have(){ command -v "$1" >/dev/null 2>&1; }

ensure_packages() {
  if have apt-get; then
    msg "Installing packages: pipewire, pipewire-pulse, wireplumber, pulseaudio-utils, alsa-utils …"
    DEBIAN_FRONTEND=noninteractive apt-get update -y || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      pipewire pipewire-pulse wireplumber pulseaudio-utils alsa-utils || true
  else
    warn "apt-get not found — install PipeWire + WirePlumber + ALSA utils manually."
  fi
}

enable_user_services() {
  local user="$1"
  msg "Configuring user services for ${user} …"

  # 1) Try direct: is a user systemd session reachable?
  if sudo -u "$user" systemctl --user show-environment >/dev/null 2>&1; then
    :
  else
    # 2) Enable linger to spawn a per-user systemd (even without active login)
    warn "User systemd session not reachable; enabling linger for $user and retrying…"
    loginctl enable-linger "$user" >/dev/null 2>&1 || true
    sleep 0.5
  fi

  # Retry after linger
  if sudo -u "$user" systemctl --user show-environment >/dev/null 2>&1; then
    msg "Enabling PipeWire stack and disabling PulseAudio for ${user}"
    sudo -u "$user" systemctl --user unmask pipewire.service pipewire.socket \
      pipewire-pulse.service pipewire-pulse.socket wireplumber.service || true
    sudo -u "$user" systemctl --user enable --now \
      pipewire.socket pipewire-pulse.socket wireplumber.service || true
    sudo -u "$user" systemctl --user disable --now \
      pulseaudio.service pulseaudio.socket || true
  else
    # 3) Final fallback: give clear instructions
    warn "Still no user systemd available for ${user}.
After logging into a graphical session, run:
  systemctl --user unmask pipewire.service pipewire.socket \\
    pipewire-pulse.service pipewire-pulse.socket wireplumber.service
  systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
  systemctl --user disable --now pulseaudio.service pulseaudio.socket"
  fi
}

alsa_init_once() {
  msg "Running 'alsactl init' once …"
  if have alsactl; then
    alsactl init || true
  else
    warn "alsactl not found; skipping ALSA init."
  fi
}

main(){
  ensure_packages
  alsa_init_once
  enable_user_services "$ORIG_USER"

  msg "Done. PipeWire + WirePlumber should be active after reboot or next login."
  read -rp "Do you want to reboot now? (y/n) " ans || true
  case "${ans:-n}" in
    [Yy]* ) reboot ;;
    * ) echo "Reboot skipped. Please reboot or log out/in to apply user services." ;;
  esac
}

main "$@"
