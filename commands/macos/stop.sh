#!/usr/bin/env bash
set -euo pipefail

log() { printf '[stop] %s\n' "$*"; }

AGENT="${HOME}/Library/LaunchAgents/com.kanata.plist"
launchctl unload "${AGENT}" >/dev/null 2>&1 || true
log "Stopped launchd agent"
