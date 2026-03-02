#!/usr/bin/env bash
set -euo pipefail

KANATA_BIN="${HOME}/.local/bin/kanata"
CFG_DIR="${HOME}/.config/kanata"
CFG_BASE="${CFG_DIR}/kanata.base.kbd"
CFG_RUNTIME="${CFG_DIR}/kanata.kbd"
DEVICE_SELECTION_FILE="${CFG_DIR}/device-selection.env"

log() { printf '[select-device] %s\n' "$*"; }

escape_for_kanata_string() {
  local raw="${1}"
  raw="${raw//\\/\\\\}"
  raw="${raw//\"/\\\"}"
  printf '%s' "${raw}"
}

render_linux_config() {
  local mode="${1}"
  local value="${2:-}"

  if grep -Eq '^[[:space:]]*\(defcfg' "${CFG_BASE}"; then
    cp "${CFG_BASE}" "${CFG_RUNTIME}"
    log "Base config already has defcfg; skipped Linux device injection"
    return
  fi

  case "${mode}" in
    auto)
      cp "${CFG_BASE}" "${CFG_RUNTIME}"
      ;;
    name)
      {
        printf '(defcfg\n'
        printf '  linux-dev-names-include (\n'
        printf '    "%s"\n' "$(escape_for_kanata_string "${value}")"
        printf '  )\n'
        printf ')\n\n'
        cat "${CFG_BASE}"
      } > "${CFG_RUNTIME}"
      ;;
    path)
      {
        printf '(defcfg\n'
        printf '  linux-dev %s\n' "${value}"
        printf ')\n\n'
        cat "${CFG_BASE}"
      } > "${CFG_RUNTIME}"
      ;;
    *)
      log "Unknown mode: ${mode}"
      exit 1
      ;;
  esac
}

main() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    log "This script is for Linux only"
    exit 1
  fi

  if [[ ! -x "${KANATA_BIN}" ]]; then
    log "kanata binary not found at ${KANATA_BIN}"
    exit 1
  fi

  if [[ ! -f "${CFG_BASE}" ]]; then
    log "Base config not found at ${CFG_BASE}. Run install/install.sh first."
    exit 1
  fi

  log "Available keyboard devices:"
  "${KANATA_BIN}" --list || true
  echo
  echo "Select device setup mode:"
  echo "  1) Auto-detect all keyboards (default)"
  echo "  2) Select by keyboard device name"
  echo "  3) Select by /dev/input/eventX path"

  local choice mode value
  read -r -p "Choice [1-3, default 1]: " choice
  choice="${choice:-1}"

  case "${choice}" in
    1)
      mode="auto"
      value=""
      ;;
    2)
      read -r -p "Enter keyboard device name exactly as listed: " value
      if [[ -z "${value}" ]]; then
        log "Empty device name is not allowed"
        exit 1
      fi
      mode="name"
      ;;
    3)
      read -r -p "Enter /dev/input/eventX path: " value
      if [[ ! "${value}" =~ ^/dev/input/event[0-9]+$ ]]; then
        log "Invalid device path: ${value}"
        exit 1
      fi
      mode="path"
      ;;
    *)
      log "Invalid choice: ${choice}"
      exit 1
      ;;
  esac

  render_linux_config "${mode}" "${value}"
  {
    printf 'LINUX_DEVICE_MODE=%q\n' "${mode}"
    printf 'LINUX_DEVICE_VALUE=%q\n' "${value}"
  } > "${DEVICE_SELECTION_FILE}"

  "${KANATA_BIN}" --cfg "${CFG_RUNTIME}" --check
  log "Saved to ${CFG_RUNTIME}"
}

main "$@"
