#!/usr/bin/env bash
set -euo pipefail

msg()  { printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[✗] %s\033[0m\n" "$*"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    err "Please run as root (sudo)."
    exit 1
  fi
}

have_cmd(){ command -v "$1" >/dev/null 2>&1; }

SWITCH_TO_PULSEAUDIO=0
for a in "$@"; do
  case "$a" in
    --switch-to-pulseaudio) SWITCH_TO_PULSEAUDIO=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: sudo ./uninstall.sh [--switch-to-pulseaudio]
  --switch-to-pulseaudio   Stoppt PipeWire & aktiviert PulseAudio (falls installiert).
EOF
      exit 0
      ;;
    *)
      err "Unknown argument: $a"
      exit 2
      ;;
  esac
done

disable_pipewire_for_user() {
  local user="$1"
  su - "$user" -c 'systemctl --user disable --now pipewire pipewire-pulse wireplumber'  >/dev/null 2>&1 || true
  su - "$user" -c 'systemctl --user mask pipewire-pulse.socket pipewire-pulse.service' >/dev/null 2>&1 || true
  su - "$user" -c 'systemctl --user mask pipewire.service wireplumber.service'        >/dev/null 2>&1 || true
}

enable_pulseaudio_for_user() {
  local user="$1"
  if have_cmd pulseaudio || [[ -f "/usr/lib/systemd/user/pulseaudio.service" || -f "/lib/systemd/user/pulseaudio.socket" || -f "/lib/systemd/user/pulseaudio.service" || -f "/lib/systemd/user/pulseaudio.socket" ]]; then
    su - "$user" -c 'systemctl --user unmask pulseaudio.service pulseaudio.socket' >/dev/null 2>&1 || true
    su - "$user" -c 'systemctl --user enable --now pulseaudio.socket pulseaudio.service' >/dev/null 2>&1 || true
    su - "$user" -c 'pulseaudio --check 2>/dev/null || pulseaudio --start' >/dev/null 2>&1 || true
  else
    warn "PulseAudio scheint nicht installiert zu sein – überspringe Umschaltung."
  fi
}

main() {
  require_root

  local user="${SUDO_USER:-$(id -un)}"
  if [[ -z "$user" || "$user" == "root" ]]; then
    user="$(logname 2>/dev/null || true)"
    [[ -z "$user" ]] && user="$(id -un)"
  fi
  msg "Deaktivieren/Stoppen von PipeWire für User: $user"

  disable_pipewire_for_user "$user"
  systemctl --user disable --now pipewire pipewire-pulse wireplumber >/dev/null 2>&1 || true
  systemctl --user mask pipewire-pulse.socket pipewire-pulse.service pipewire.service wireplumber.service >/dev/null 2>&1 || true

  if (( SWITCH_TO_PULSEAUDIO )); then
    msg "Umschalten auf PulseAudio (falls vorhanden) …"
    enable_pulseaudio_for_user "$user"
  fi

  msg "Fertig. Bitte ab- und wieder anmelden (oder reboot), damit die Audio-Session sauber neu startet."
  warn "Hinweis: Falls 'Failed to connect to bus' erschien, lag kein User-D-Bus vor. Das ist harmlos."
}

main "$@"
