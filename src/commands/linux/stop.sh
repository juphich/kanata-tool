#!/usr/bin/env bash
set -euo pipefail

log() { printf '[kanata-tool] %s\n' "$*"; }

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user stop kanata.service
  log "Stopped kanata.service"
else
  log "systemctl not found"
  exit 1
fi
