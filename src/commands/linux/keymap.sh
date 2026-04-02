#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/paths.sh"
source "${SCRIPT_DIR}/../../lib/keymap.sh"

reload_if_running() {
  if ! command -v systemctl >/dev/null 2>&1; then
    keymap_log "systemctl not found; keymap updated without reload"
    return
  fi

  if systemctl --user is-active --quiet kanata.service; then
    if systemctl --user restart kanata.service; then
      keymap_log "Reloaded kanata.service"
      return
    fi
    keymap_log "Failed to reload kanata.service; keymap file was updated"
    return
  fi

  keymap_log "kanata.service is not running; keymap updated only"
}

main() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    keymap_log "This command is for Linux only"
    exit 1
  fi

  keymap_prepare_runtime

  case "${1:-}" in
    "")
      keymap_edit_runtime
      ;;
    --init)
      [[ $# -eq 1 ]] || { keymap_log "Usage: kanata-tool keymap [--init | --file <file> | --print]"; exit 1; }
      keymap_validate_and_install "${KANATA_CONFIG_BASE}"
      ;;
    --file)
      [[ $# -eq 2 ]] || { keymap_log "Usage: kanata-tool keymap --file <file>"; exit 1; }
      [[ -f "${2}" ]] || { keymap_log "File not found: ${2}"; exit 1; }
      keymap_validate_and_install "${2}"
      ;;
    --print)
      [[ $# -eq 1 ]] || { keymap_log "Usage: kanata-tool keymap [--init | --file <file> | --print]"; exit 1; }
      cat "${KANATA_CONFIG_RUNTIME}"
      exit 0
      ;;
    *)
      keymap_log "Unknown option: ${1}"
      keymap_log "Usage: kanata-tool keymap [--init | --file <file> | --print]"
      exit 1
      ;;
  esac

  reload_if_running
}

main "$@"
