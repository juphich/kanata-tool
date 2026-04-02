#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/paths.sh"

log() { printf '[uninstall] %s\n' "$*"; }

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user disable --now kanata.service >/dev/null 2>&1 || true
  rm -f "${KANATA_SYSTEMD_SERVICE}"
  systemctl --user daemon-reload
  log "Removed systemd user service"
fi

rm -f "${KANATA_RUNTIME_BIN}"
rm -rf "${KANATA_CONFIG_DIR}"
log "Removed kanata binary and config"
