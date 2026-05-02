#!/usr/bin/env bash
set -euo pipefail

KANATA_VERSION="${KANATA_VERSION:-}"
PRESERVE_CONFIG="${KANATA_TOOL_PRESERVE_CONFIG:-0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/paths.sh"
CFG_SRC="${KANATA_TOOL_CONFIG_DIR}/macos/kanata.kbd"

log() { printf '[setup] %s\n' "$*"; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --preserve-config)
        PRESERVE_CONFIG=1
        ;;
      *)
        log "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
  done
}

check_prerequisites() {
  local missing=()
  for cmd in curl jq unzip; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      missing+=("${cmd}")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log "Missing required tools: ${missing[*]}"
    log "Please install them before running setup (e.g. brew install ${missing[*]})"
    exit 1
  fi

}

download_kanata_binary() {
  local arch="$1"
  if [[ ! -f "${KANATA_TOOL_SCRIPTS_DIR}/fetch-kanata-binaries.sh" ]]; then
    log "Missing fetch script: ${KANATA_TOOL_SCRIPTS_DIR}/fetch-kanata-binaries.sh"
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
  log "Base config installed to ${KANATA_CONFIG_BASE}"

  if [[ "${PRESERVE_CONFIG}" == "1" && -f "${KANATA_CONFIG_RUNTIME}" ]]; then
    log "Runtime config preserved at ${KANATA_CONFIG_RUNTIME}"
    return 0
  fi

  cp "${KANATA_CONFIG_BASE}" "${KANATA_CONFIG_RUNTIME}"
  log "Runtime config installed to ${KANATA_CONFIG_RUNTIME}"
}

install_sudoers() {
  local user
  user="$(id -un)"
  printf '%s ALL=(ALL) NOPASSWD: %s\n' "${user}" "${KANATA_RUNTIME_BIN}" \
    | sudo tee /etc/sudoers.d/kanata >/dev/null
  sudo chmod 440 /etc/sudoers.d/kanata
  log "sudoers entry installed: /etc/sudoers.d/kanata"
}

install_launchagent() {
  mkdir -p "${KANATA_LAUNCH_AGENTS_DIR}"
  cp "${KANATA_TOOL_AUTOSTART_DIR}/macos/com.kanata.plist" "${KANATA_LAUNCH_AGENT}"
  launchctl unload "${KANATA_LAUNCH_AGENT}" >/dev/null 2>&1 || true
  launchctl load "${KANATA_LAUNCH_AGENT}"
  log "launchd agent loaded"
}

main() {
  parse_args "$@"

  if [[ "$(uname -s)" != "Darwin" ]]; then
    log "This command is for macOS only"
    exit 1
  fi

  check_prerequisites

  if [[ ! -f "${CFG_SRC}" ]]; then
    log "Missing config file: ${CFG_SRC}"
    exit 1
  fi

  install_binary_macos
  install_config
  install_sudoers
  install_launchagent

  "${KANATA_RUNTIME_BIN}" --cfg "${KANATA_CONFIG_RUNTIME}" --check
  log "Config validation succeeded"
}

main "$@"
