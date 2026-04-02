#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/paths.sh"

log() { printf '[status] %s\n' "$*"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  log "This command is for macOS only"
  exit 1
fi

log "Platform: macOS"
log "kanata binary: ${KANATA_RUNTIME_BIN}"
log "base config: ${KANATA_CONFIG_BASE}"
log "runtime config: ${KANATA_CONFIG_RUNTIME}"
log "launch agent: ${KANATA_LAUNCH_AGENT}"

if [[ -x "${KANATA_RUNTIME_BIN}" ]]; then
  log "binary installed: yes"
else
  log "binary installed: no"
fi

if [[ -f "${KANATA_CONFIG_BASE}" ]]; then
  log "base config installed: yes"
else
  log "base config installed: no"
fi

if [[ -f "${KANATA_CONFIG_RUNTIME}" ]]; then
  log "runtime config installed: yes"
else
  log "runtime config installed: no"
fi

if pgrep -x kanata >/dev/null 2>&1; then
  log "service running: yes"
else
  log "service running: no"
fi

if [[ -f "${KANATA_LAUNCH_AGENT}" ]]; then
  log "autostart enabled: yes"
else
  log "autostart enabled: no"
fi
