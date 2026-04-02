#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/paths.sh"

log() { printf '[device] %s\n' "$*"; }

if [[ "$(uname -s)" != "Linux" ]]; then
  log "This command is for Linux only"
  exit 1
fi

if [[ ! -x "${KANATA_RUNTIME_BIN}" ]]; then
  log "kanata binary not found at ${KANATA_RUNTIME_BIN}"
  exit 1
fi

if [[ ! -f "${KANATA_CONFIG_BASE}" ]]; then
  log "Base config not found at ${KANATA_CONFIG_BASE}. Run 'kanata-tool setup' first."
  exit 1
fi

cp "${KANATA_CONFIG_BASE}" "${KANATA_CONFIG_RUNTIME}"
"${KANATA_RUNTIME_BIN}" --cfg "${KANATA_CONFIG_RUNTIME}" --check
log "Copied base config to ${KANATA_CONFIG_RUNTIME}"
