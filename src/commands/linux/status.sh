#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/paths.sh"

log() { printf '[status] %s\n' "$*"; }

if [[ "$(uname -s)" != "Linux" ]]; then
  log "This command is for Linux only"
  exit 1
fi

log "Platform: Linux"
log "kanata binary: ${KANATA_RUNTIME_BIN}"
log "base config: ${KANATA_CONFIG_BASE}"
log "runtime config: ${KANATA_CONFIG_RUNTIME}"
log "systemd service: ${KANATA_SYSTEMD_SERVICE}"

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

if command -v systemctl >/dev/null 2>&1; then
  if systemctl --user is-active --quiet kanata.service; then
    log "service running: yes"
  else
    log "service running: no"
  fi

  if systemctl --user is-enabled --quiet kanata.service >/dev/null 2>&1; then
    log "autostart enabled: yes"
  else
    log "autostart enabled: no"
  fi
else
  log "service running: unknown (systemctl not found)"
  log "autostart enabled: unknown (systemctl not found)"
fi
