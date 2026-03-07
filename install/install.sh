#!/usr/bin/env bash
set -euo pipefail

# Shared paths for install artifacts and config files.
KANATA_VERSION="${KANATA_VERSION:-v1.8.1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CFG_SRC="${REPO_ROOT}/config/kanata.kbd"
KANATA_BIN_DIR="${HOME}/.local/bin"
KANATA_BIN="${KANATA_BIN_DIR}/kanata"
CFG_DST_DIR="${HOME}/.config/kanata"
CFG_BASE_DST="${CFG_DST_DIR}/kanata.base.kbd"
CFG_DST="${CFG_DST_DIR}/kanata.kbd"
FETCH_ATTEMPTED=0

log() { printf '[install] %s\n' "$*"; }

attempt_fetch_bundled_binaries() {
  if [[ "${FETCH_ATTEMPTED}" -eq 1 ]]; then
    return
  fi
  FETCH_ATTEMPTED=1

  if [[ ! -x "${REPO_ROOT}/build/fetch-kanata-binaries.sh" ]]; then
    return
  fi

  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    log "Bundled binary missing and fetch requirements are not met (need: curl jq unzip)"
    return
  fi

  log "Attempting to download bundled kanata binaries (${KANATA_VERSION})"
  if bash "${REPO_ROOT}/build/fetch-kanata-binaries.sh" --version "${KANATA_VERSION}" --output-dir "${REPO_ROOT}"; then
    log "Downloaded bundled binaries"
  else
    log "Failed to fetch bundled binaries"
  fi
}

install_binary_linux() {
  # Linux binary resolution order:
  # 1) Bundled binary in this repo: bin/linux/<arch>/kanata
  # 2) Legacy bundled x86_64 binary: bin/kanata_linux_x64
  # 3) Existing kanata from PATH
  # 4) Fail and ask user to build/fetch binaries
  local arch
  local bundled
  arch="$(uname -m)"
  mkdir -p "${KANATA_BIN_DIR}"

  case "${arch}" in
    x86_64) bundled="${REPO_ROOT}/bin/linux/x64/kanata" ;;
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
    log "Bundled Linux binary installed to ${KANATA_BIN}"
    return
  fi

  if [[ "${arch}" == "x86_64" && -x "${REPO_ROOT}/bin/kanata_linux_x64" ]]; then
    cp "${REPO_ROOT}/bin/kanata_linux_x64" "${KANATA_BIN}"
    chmod +x "${KANATA_BIN}"
    log "Legacy bundled Linux binary installed to ${KANATA_BIN}"
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

  log "No compatible bundled binary found for Linux arch=${arch}."
  log "Run build/fetch-kanata-binaries.sh or install kanata manually, then rerun this script."
  exit 1
}

install_binary_macos() {
  # macOS binary resolution order:
  # 1) Bundled binary in this repo: bin/macos/<arch>/kanata
  # 2) Existing kanata from PATH
  # 3) Fail and ask user to build/fetch binaries
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
  log "Run build/fetch-kanata-binaries.sh or install kanata (${KANATA_VERSION}) first, then rerun this script."
  exit 1
}

install_config() {
  # Keep an immutable-looking base copy and a runtime copy with the same content.
  # No config rendering/injection is performed here.
  mkdir -p "${CFG_DST_DIR}"
  cp "${CFG_SRC}" "${CFG_BASE_DST}"
  cp "${CFG_BASE_DST}" "${CFG_DST}"
  log "Config installed to ${CFG_DST}"
}

install_linux_service() {
  # Install and enable systemd user service for auto-start on login (Linux).
  local service_dir service_file
  service_dir="${HOME}/.config/systemd/user"
  service_file="${service_dir}/kanata.service"
  mkdir -p "${service_dir}"
  cp "${REPO_ROOT}/autostart/linux/kanata.service" "${service_file}"
  systemctl --user daemon-reload
  systemctl --user enable --now kanata.service
  log "systemd user service enabled"
}

install_macos_launchagent() {
  # Install launchd agent for auto-start on login (macOS).
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
  # Hard fail early if repository config is missing.
  if [[ ! -f "${CFG_SRC}" ]]; then
    log "Missing config file: ${CFG_SRC}"
    exit 1
  fi

  case "$(uname -s)" in
    Linux)
      # Linux flow: install binary -> copy config -> install systemd service.
      install_binary_linux
      install_config
      if command -v systemctl >/dev/null 2>&1; then
        install_linux_service
      else
        log "systemctl not found; skipped autostart setup"
      fi
      ;;
    Darwin)
      # macOS flow: install binary -> copy config -> install launch agent.
      install_binary_macos
      install_config
      cp "${CFG_BASE_DST}" "${CFG_DST}"
      install_macos_launchagent
      ;;
    *)
      log "Unsupported OS: $(uname -s)"
      exit 1
      ;;
  esac

  # Validate final runtime config before finishing.
  "${KANATA_BIN}" --cfg "${CFG_DST}" --check
  log "Config validation succeeded"
}

main "$@"
