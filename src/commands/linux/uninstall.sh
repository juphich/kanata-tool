#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/paths.sh"

log() { printf '[uninstall] %s\n' "$*"; }

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user disable --now kanata.service >/dev/null 2>&1 || true
  rm -f "${KANATA_SYSTEMD_SERVICE}"
  systemctl --user daemon-reload
  log "Removed systemd user service"
fi

rm -f "${KANATA_RUNTIME_BIN}"
rm -rf "${KANATA_CONFIG_DIR}"
log "Removed kanata binary and config"

if [[ "${EUID}" -eq 0 ]] || command -v sudo >/dev/null 2>&1; then
  run_as_root rm -f /etc/udev/rules.d/99-kanata-tool.rules /etc/modules-load.d/uinput.conf
  if command -v udevadm >/dev/null 2>&1; then
    run_as_root udevadm control --reload-rules || true
  fi
  log "Removed Linux device permission files"
else
  log "sudo not found; skipped Linux device permission cleanup"
fi
