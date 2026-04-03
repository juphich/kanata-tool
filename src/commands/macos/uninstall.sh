#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/paths.sh"

log() { printf '[uninstall] %s\n' "$*"; }

launchctl unload "${KANATA_LAUNCH_AGENT}" >/dev/null 2>&1 || true
rm -f "${KANATA_LAUNCH_AGENT}"
log "Removed launchd agent"

rm -f "${KANATA_RUNTIME_BIN}"
rm -rf "${KANATA_CONFIG_DIR}"
log "Removed kanata binary and config"

if [[ -f /etc/sudoers.d/kanata ]]; then
  sudo rm -f /etc/sudoers.d/kanata
  log "Removed sudoers entry"
fi
