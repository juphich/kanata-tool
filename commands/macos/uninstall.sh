#!/usr/bin/env bash
set -euo pipefail

KANATA_BIN="${HOME}/.local/bin/kanata"
CFG_DIR="${HOME}/.config/kanata"
MAC_AGENT="${HOME}/Library/LaunchAgents/com.kanata.plist"

log() { printf '[uninstall] %s\n' "$*"; }

launchctl unload "${MAC_AGENT}" >/dev/null 2>&1 || true
rm -f "${MAC_AGENT}"
log "Removed launchd agent"

rm -f "${KANATA_BIN}"
rm -rf "${CFG_DIR}"
log "Removed kanata binary and config"
