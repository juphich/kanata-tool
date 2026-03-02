#!/usr/bin/env bash
set -euo pipefail

KANATA_VERSION="v1.8.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CFG_SRC="${REPO_ROOT}/config/kanata.kbd"
KANATA_BIN_DIR="${HOME}/.local/bin"
KANATA_BIN="${KANATA_BIN_DIR}/kanata"
CFG_DST_DIR="${HOME}/.config/kanata"
CFG_BASE_DST="${CFG_DST_DIR}/kanata.base.kbd"
CFG_DST="${CFG_DST_DIR}/kanata.kbd"
DEVICE_SELECTION_FILE="${CFG_DST_DIR}/device-selection.env"

LINUX_DEVICE_MODE="auto"
LINUX_DEVICE_VALUE=""

log() { printf '[install] %s\n' "$*"; }

escape_for_kanata_string() {
  local raw="${1}"
  raw="${raw//\\/\\\\}"
  raw="${raw//\"/\\\"}"
  printf '%s' "${raw}"
}

install_binary_linux() {
  local arch
  arch="$(uname -m)"
  mkdir -p "${KANATA_BIN_DIR}"

  if [[ "${arch}" == "x86_64" && -x "${REPO_ROOT}/bin/kanata_linux_x64" ]]; then
    cp "${REPO_ROOT}/bin/kanata_linux_x64" "${KANATA_BIN}"
    chmod +x "${KANATA_BIN}"
    log "Bundled Linux binary installed to ${KANATA_BIN}"
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

  log "No compatible bundled binary found for arch=${arch}."
  log "Install kanata manually, then rerun this script."
  exit 1
}

install_binary_macos() {
  mkdir -p "${KANATA_BIN_DIR}"
  if command -v kanata >/dev/null 2>&1; then
    local existing
    existing="$(command -v kanata)"
    cp "${existing}" "${KANATA_BIN}"
    chmod +x "${KANATA_BIN}"
    log "Copied existing kanata from ${existing}"
    return
  fi

  log "kanata binary not found on macOS."
  log "Install kanata (${KANATA_VERSION}) first, then rerun this script."
  exit 1
}

install_config() {
  mkdir -p "${CFG_DST_DIR}"
  cp "${CFG_SRC}" "${CFG_BASE_DST}"
  cp "${CFG_BASE_DST}" "${CFG_DST}"
  log "Base config installed to ${CFG_BASE_DST}"
}

render_linux_config() {
  local mode="${1}"
  local value="${2:-}"

  if grep -Eq '^[[:space:]]*\(defcfg' "${CFG_BASE_DST}"; then
    cp "${CFG_BASE_DST}" "${CFG_DST}"
    log "Base config already has defcfg; skipped Linux device injection"
    return
  fi

  case "${mode}" in
    auto)
      cp "${CFG_BASE_DST}" "${CFG_DST}"
      ;;
    name)
      {
        printf '(defcfg\n'
        printf '  linux-dev-names-include (\n'
        printf '    "%s"\n' "$(escape_for_kanata_string "${value}")"
        printf '  )\n'
        printf ')\n\n'
        cat "${CFG_BASE_DST}"
      } > "${CFG_DST}"
      ;;
    path)
      {
        printf '(defcfg\n'
        printf '  linux-dev %s\n' "${value}"
        printf ')\n\n'
        cat "${CFG_BASE_DST}"
      } > "${CFG_DST}"
      ;;
    *)
      log "Unknown Linux device mode: ${mode}"
      exit 1
      ;;
  esac
}

save_linux_device_selection() {
  {
    printf 'LINUX_DEVICE_MODE=%q\n' "${LINUX_DEVICE_MODE}"
    printf 'LINUX_DEVICE_VALUE=%q\n' "${LINUX_DEVICE_VALUE}"
  } > "${DEVICE_SELECTION_FILE}"
}

select_linux_device() {
  if [[ ! -t 0 ]]; then
    log "Non-interactive shell detected; using auto device detection"
    LINUX_DEVICE_MODE="auto"
    LINUX_DEVICE_VALUE=""
    return
  fi

  log "Available keyboard devices:"
  "${KANATA_BIN}" --list || true
  echo
  echo "Select device setup mode:"
  echo "  1) Auto-detect all keyboards (default)"
  echo "  2) Select by keyboard device name"
  echo "  3) Select by /dev/input/eventX path"

  local choice
  read -r -p "Choice [1-3, default 1]: " choice
  choice="${choice:-1}"

  case "${choice}" in
    1)
      LINUX_DEVICE_MODE="auto"
      LINUX_DEVICE_VALUE=""
      ;;
    2)
      read -r -p "Enter keyboard device name exactly as listed: " LINUX_DEVICE_VALUE
      if [[ -z "${LINUX_DEVICE_VALUE}" ]]; then
        log "Empty device name is not allowed"
        exit 1
      fi
      LINUX_DEVICE_MODE="name"
      ;;
    3)
      read -r -p "Enter /dev/input/eventX path: " LINUX_DEVICE_VALUE
      if [[ ! "${LINUX_DEVICE_VALUE}" =~ ^/dev/input/event[0-9]+$ ]]; then
        log "Invalid device path: ${LINUX_DEVICE_VALUE}"
        exit 1
      fi
      LINUX_DEVICE_MODE="path"
      ;;
    *)
      log "Invalid choice: ${choice}"
      exit 1
      ;;
  esac

  render_linux_config "${LINUX_DEVICE_MODE}" "${LINUX_DEVICE_VALUE}"
  save_linux_device_selection
  log "Configured Linux device mode: ${LINUX_DEVICE_MODE}"
  log "Runtime config installed to ${CFG_DST}"
}

install_linux_service() {
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
  if [[ ! -f "${CFG_SRC}" ]]; then
    log "Missing config file: ${CFG_SRC}"
    exit 1
  fi

  case "$(uname -s)" in
    Linux)
      install_binary_linux
      install_config
      select_linux_device
      if command -v systemctl >/dev/null 2>&1; then
        install_linux_service
      else
        log "systemctl not found; skipped autostart setup"
      fi
      ;;
    Darwin)
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

  "${KANATA_BIN}" --cfg "${CFG_DST}" --check
  log "Config validation succeeded"
}

main "$@"
