#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/paths.sh"

log() { printf '[stop] %s\n' "$*"; }

launchctl unload "${KANATA_LAUNCH_AGENT}" >/dev/null 2>&1 || true
log "Stopped launchd agent"
