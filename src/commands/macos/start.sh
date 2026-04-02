#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/paths.sh"

log() { printf '[start] %s\n' "$*"; }

if [[ ! -f "${KANATA_LAUNCH_AGENT}" ]]; then
  log "LaunchAgent not found: ${KANATA_LAUNCH_AGENT}"
  exit 1
fi

launchctl load "${KANATA_LAUNCH_AGENT}" >/dev/null 2>&1 || true
log "Started launchd agent"
