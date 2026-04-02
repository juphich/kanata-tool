#!/usr/bin/env bash
set -euo pipefail

KANATA_VERSION="${KANATA_VERSION:-v1.8.1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/paths.sh"
CFG_SRC="${KANATA_TOOL_CONFIG_DIR}/kanata.kbd"
FETCH_ATTEMPTED=0

log() { printf '[setup] %s\n' "$*"; }

attempt_fetch_bundled_binaries() {
  local arch="$1"
  if [[ "${FETCH_ATTEMPTED}" -eq 1 ]]; then
    return
  fi
  FETCH_ATTEMPTED=1

  if [[ ! -f "${KANATA_TOOL_SCRIPTS_DIR}/fetch-kanata-binaries.sh" ]]; then
    return
  fi

  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    log "Bundled binary missing and fetch requirements are not met (need: curl jq unzip)"
    return
  fi

  log "Attempting to download bundled kanata binaries (${KANATA_VERSION})"
  if bash "${KANATA_TOOL_SCRIPTS_DIR}/fetch-kanata-binaries.sh" --version "${KANATA_VERSION}" --output-dir "${KANATA_TOOL_HOME}" --platform macos --arch "${arch}"; then
    log "Downloaded bundled binaries"
  else
    log "Failed to fetch bundled binaries"
  fi
}

install_binary_macos() {
  local arch bundled fetch_arch
  arch="$(uname -m)"
  mkdir -p "${KANATA_RUNTIME_BIN_DIR}"

  case "${arch}" in
    x86_64)
      bundled="${KANATA_TOOL_BUNDLED_BIN_DIR}/macos/x64/kanata"
      fetch_arch="x64"
      ;;
    arm64)
      bundled="${KANATA_TOOL_BUNDLED_BIN_DIR}/macos/arm64/kanata"
      fetch_arch="arm64"
      ;;
    *)
      bundled=""
      fetch_arch=""
      ;;
  esac

  if [[ -n "${bundled}" && ! -x "${bundled}" ]]; then
    attempt_fetch_bundled_binaries "${fetch_arch}"
  fi

  if [[ -n "${bundled}" && -x "${bundled}" ]]; then
    cp "${bundled}" "${KANATA_RUNTIME_BIN}"
    chmod +x "${KANATA_RUNTIME_BIN}"
    log "Bundled macOS binary installed to ${KANATA_RUNTIME_BIN}"
    return
  fi

  if command -v kanata >/dev/null 2>&1; then
    local existing
    existing="$(command -v kanata)"
    cp "${existing}" "${KANATA_RUNTIME_BIN}"
    chmod +x "${KANATA_RUNTIME_BIN}"
    log "Copied existing kanata from ${existing}"
    return
  fi

  log "No compatible bundled binary found for macOS arch=${arch}."
  log "Run fetch-kanata-binaries.sh or install kanata (${KANATA_VERSION}) first, then rerun this command."
  exit 1
}

install_config() {
  mkdir -p "${KANATA_CONFIG_DIR}"
  cp "${CFG_SRC}" "${KANATA_CONFIG_BASE}"
  cp "${KANATA_CONFIG_BASE}" "${KANATA_CONFIG_RUNTIME}"
  log "Config installed to ${KANATA_CONFIG_RUNTIME}"
}

install_launchagent() {
  mkdir -p "${KANATA_LAUNCH_AGENTS_DIR}"
  cp "${KANATA_TOOL_AUTOSTART_DIR}/macos/com.kanata.plist" "${KANATA_LAUNCH_AGENT}"
  launchctl unload "${KANATA_LAUNCH_AGENT}" >/dev/null 2>&1 || true
  launchctl load "${KANATA_LAUNCH_AGENT}"
  log "launchd agent loaded"
}

main() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log "This command is for macOS only"
    exit 1
  fi

  if [[ ! -f "${CFG_SRC}" ]]; then
    log "Missing config file: ${CFG_SRC}"
    exit 1
  fi

  install_binary_macos
  install_config
  install_launchagent

  "${KANATA_RUNTIME_BIN}" --cfg "${KANATA_CONFIG_RUNTIME}" --check
  log "Config validation succeeded"
}

main "$@"
