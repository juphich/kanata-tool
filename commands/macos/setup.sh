#!/usr/bin/env bash
set -euo pipefail

KANATA_VERSION="${KANATA_VERSION:-v1.8.1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CFG_SRC="${REPO_ROOT}/config/kanata.kbd"
KANATA_BIN_DIR="${HOME}/.local/bin"
KANATA_BIN="${KANATA_BIN_DIR}/kanata"
CFG_DST_DIR="${HOME}/.config/kanata"
CFG_BASE_DST="${CFG_DST_DIR}/kanata.base.kbd"
CFG_DST="${CFG_DST_DIR}/kanata.kbd"
FETCH_ATTEMPTED=0

log() { printf '[setup] %s\n' "$*"; }

attempt_fetch_bundled_binaries() {
  if [[ "${FETCH_ATTEMPTED}" -eq 1 ]]; then
    return
  fi
  FETCH_ATTEMPTED=1

  if [[ ! -x "${REPO_ROOT}/fetch-kanata-binaries.sh" ]]; then
    return
  fi

  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    log "Bundled binary missing and fetch requirements are not met (need: curl jq unzip)"
    return
  fi

  log "Attempting to download bundled kanata binaries (${KANATA_VERSION})"
  if bash "${REPO_ROOT}/fetch-kanata-binaries.sh" --version "${KANATA_VERSION}" --output-dir "${REPO_ROOT}"; then
    log "Downloaded bundled binaries"
  else
    log "Failed to fetch bundled binaries"
  fi
}

install_binary_macos() {
  local arch bundled
  arch="$(uname -m)"
  mkdir -p "${KANATA_BIN_DIR}"

  case "${arch}" in
    x86_64) bundled="${REPO_ROOT}/bin/macos/x64/kanata" ;;
    arm64) bundled="${REPO_ROOT}/bin/macos/arm64/kanata" ;;
    *)
      bundled=""
      ;;
  esac

  if [[ -n "${bundled}" && ! -x "${bundled}" ]]; then
    attempt_fetch_bundled_binaries
  fi

  if [[ -n "${bundled}" && -x "${bundled}" ]]; then
    cp "${bundled}" "${KANATA_BIN}"
    chmod +x "${KANATA_BIN}"
    log "Bundled macOS binary installed to ${KANATA_BIN}"
    return
  fi

  if command -v kanata >/dev/null 2>&1; then
    local existing
    existing="$(command -v kanata)"
    cp "${existing}" "${KANATA_BIN}"
    chmod +x "${KANATA_BIN}"
    log "Copied existing kanata from ${existing}"
    return
  fi

  log "No compatible bundled binary found for macOS arch=${arch}."
  log "Run fetch-kanata-binaries.sh or install kanata (${KANATA_VERSION}) first, then rerun this command."
  exit 1
}

install_config() {
  mkdir -p "${CFG_DST_DIR}"
  cp "${CFG_SRC}" "${CFG_BASE_DST}"
  cp "${CFG_BASE_DST}" "${CFG_DST}"
  log "Config installed to ${CFG_DST}"
}

install_launchagent() {
  local agent_dir agent_file
  agent_dir="${HOME}/Library/LaunchAgents"
  agent_file="${agent_dir}/com.kanata.plist"
  mkdir -p "${agent_dir}"
  cp "${REPO_ROOT}/autostart/macos/com.kanata.plist" "${agent_file}"
  launchctl unload "${agent_file}" >/dev/null 2>&1 || true
  launchctl load "${agent_file}"
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

  "${KANATA_BIN}" --cfg "${CFG_DST}" --check
  log "Config validation succeeded"
}

main "$@"
