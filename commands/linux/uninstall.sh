#!/usr/bin/env bash
set -euo pipefail

KANATA_BIN="${HOME}/.local/bin/kanata"
CFG_DIR="${HOME}/.config/kanata"
SYSTEMD_SERVICE="${HOME}/.config/systemd/user/kanata.service"

log() { printf '[uninstall] %s\n' "$*"; }

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user disable --now kanata.service >/dev/null 2>&1 || true
  rm -f "${SYSTEMD_SERVICE}"
  systemctl --user daemon-reload
  log "Removed systemd user service"
fi

rm -f "${KANATA_BIN}"
rm -rf "${CFG_DIR}"
log "Removed kanata binary and config"
