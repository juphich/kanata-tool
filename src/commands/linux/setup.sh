#!/usr/bin/env bash
set -euo pipefail

KANATA_VERSION="${KANATA_VERSION:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/paths.sh
source "${SCRIPT_DIR}/../../lib/paths.sh"
# shellcheck source=../../lib/linux-runtime.sh
source "${SCRIPT_DIR}/../../lib/linux-runtime.sh"
CFG_SRC="${KANATA_TOOL_CONFIG_DIR}/kanata.kbd"

log() { printf '[setup] %s\n' "$*"; }

download_kanata_binary() {
  local arch="$1"
  if [[ ! -f "${KANATA_TOOL_SCRIPTS_DIR}/fetch-kanata-binaries.sh" ]]; then
    log "Missing fetch script: ${KANATA_TOOL_SCRIPTS_DIR}/fetch-kanata-binaries.sh"
    exit 1
  fi

  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    log "Download requirements are not met (need: curl jq unzip)"
    exit 1
  fi

  log "Downloading kanata binary (${KANATA_VERSION})"
  bash "${KANATA_TOOL_SCRIPTS_DIR}/fetch-kanata-binaries.sh" \
    --version "${KANATA_VERSION}" \
    --platform linux \
    --arch "${arch}" \
    --destination "${KANATA_RUNTIME_BIN}"
}

install_binary_linux() {
  local arch fetch_arch
  arch="$(uname -m)"
  mkdir -p "${KANATA_RUNTIME_BIN_DIR}"

  case "${arch}" in
    x86_64)
      fetch_arch="x64"
      ;;
    *)
      fetch_arch=""
      ;;
  esac

  if [[ -z "${fetch_arch}" ]]; then
    log "Unsupported Linux arch=${arch}."
    exit 1
  fi

  download_kanata_binary "${fetch_arch}"
  chmod +x "${KANATA_RUNTIME_BIN}"
  log "Installed Linux binary to ${KANATA_RUNTIME_BIN}"
}

install_config() {
  mkdir -p "${KANATA_CONFIG_DIR}"
  cp "${CFG_SRC}" "${KANATA_CONFIG_BASE}"
  cp "${KANATA_CONFIG_BASE}" "${KANATA_CONFIG_RUNTIME}"
  log "Config installed to ${KANATA_CONFIG_RUNTIME}"
}

install_linux_service() {
  mkdir -p "${KANATA_SYSTEMD_USER_DIR}"
  cp "${KANATA_TOOL_AUTOSTART_DIR}/linux/kanata.service" "${KANATA_SYSTEMD_SERVICE}"
  if linux_runtime_systemd_usable && systemctl --user daemon-reload && systemctl --user enable --now kanata.service; then
    log "systemd user service enabled"
    return 0
  fi

  log "systemctl --user is present but not usable; skipped autostart setup"
  return 1
}

main() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    log "This command is for Linux only"
    exit 1
  fi

  if [[ ! -f "${CFG_SRC}" ]]; then
    log "Missing config file: ${CFG_SRC}"
    exit 1
  fi

  install_binary_linux
  install_config
  if command -v systemctl >/dev/null 2>&1; then
    if ! install_linux_service; then
      "${KANATA_RUNTIME_BIN}" --cfg "${KANATA_CONFIG_RUNTIME}" --check
      linux_runtime_start_manual
      log "Started kanata without systemd user service"
      log "Autostart was not configured because systemctl --user is unavailable"
      exit 0
    fi
  else
    log "systemctl not found; skipped autostart setup"
    "${KANATA_RUNTIME_BIN}" --cfg "${KANATA_CONFIG_RUNTIME}" --check
    linux_runtime_start_manual
    log "Started kanata without systemd"
    exit 0
  fi

  "${KANATA_RUNTIME_BIN}" --cfg "${KANATA_CONFIG_RUNTIME}" --check
  log "Config validation succeeded"
}

main "$@"
