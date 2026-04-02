#!/usr/bin/env bash
set -euo pipefail

KANATA_VERSION="${KANATA_VERSION:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/paths.sh"
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
    --platform macos \
    --arch "${arch}" \
    --destination "${KANATA_RUNTIME_BIN}"
}

install_binary_macos() {
  local arch fetch_arch
  arch="$(uname -m)"
  mkdir -p "${KANATA_RUNTIME_BIN_DIR}"

  case "${arch}" in
    x86_64)
      fetch_arch="x64"
      ;;
    arm64)
      fetch_arch="arm64"
      ;;
    *)
      fetch_arch=""
      ;;
  esac

  if [[ -z "${fetch_arch}" ]]; then
    log "Unsupported macOS arch=${arch}."
    exit 1
  fi

  download_kanata_binary "${fetch_arch}"
  chmod +x "${KANATA_RUNTIME_BIN}"
  log "Installed macOS binary to ${KANATA_RUNTIME_BIN}"
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
