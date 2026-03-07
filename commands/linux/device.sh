#!/usr/bin/env bash
set -euo pipefail

KANATA_BIN="${HOME}/.local/bin/kanata"
CFG_DIR="${HOME}/.config/kanata"
CFG_BASE="${CFG_DIR}/kanata.base.kbd"
CFG_RUNTIME="${CFG_DIR}/kanata.kbd"

log() { printf '[device] %s\n' "$*"; }

if [[ "$(uname -s)" != "Linux" ]]; then
  log "This command is for Linux only"
  exit 1
fi

if [[ ! -x "${KANATA_BIN}" ]]; then
  log "kanata binary not found at ${KANATA_BIN}"
  exit 1
fi

if [[ ! -f "${CFG_BASE}" ]]; then
  log "Base config not found at ${CFG_BASE}. Run 'kanata-tool setup' first."
  exit 1
fi

cp "${CFG_BASE}" "${CFG_RUNTIME}"
"${KANATA_BIN}" --cfg "${CFG_RUNTIME}" --check
log "Copied base config to ${CFG_RUNTIME}"
