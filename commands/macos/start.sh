#!/usr/bin/env bash
set -euo pipefail

log() { printf '[start] %s\n' "$*"; }

AGENT="${HOME}/Library/LaunchAgents/com.kanata.plist"
if [[ ! -f "${AGENT}" ]]; then
  log "LaunchAgent not found: ${AGENT}"
  exit 1
fi

launchctl load "${AGENT}" >/dev/null 2>&1 || true
log "Started launchd agent"
