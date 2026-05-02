#!/usr/bin/env bash
set -euo pipefail

KANATA_VERSION="${KANATA_VERSION:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/paths.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/linux-runtime.sh"
CFG_SRC="${KANATA_TOOL_CONFIG_DIR}/linux/kanata.kbd"

log() { printf '[setup] %s\n' "$*"; }
LINUX_PERMISSIONS_CHANGED=0

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

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

ensure_linux_group() {
  local group="$1"
  if getent group "${group}" >/dev/null 2>&1; then
    return 0
  fi

  run_as_root groupadd --system "${group}"
  log "Created ${group} group"
}

ensure_user_in_group() {
  local user="$1"
  local group="$2"
  if id -nG "${user}" | tr ' ' '\n' | grep -Fxq "${group}"; then
    return 0
  fi

  run_as_root usermod -aG "${group}" "${user}"
  LINUX_PERMISSIONS_CHANGED=1
  log "Added ${user} to ${group} group"
}

install_linux_permissions() {
  local target_user rules_file modules_file
  target_user="${SUDO_USER:-${USER:-}}"
  if [[ -z "${target_user}" ]]; then
    target_user="$(id -un)"
  fi

  if [[ "${EUID}" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    log "sudo not found; skipped Linux device permission setup"
    log "Run as root later: groupadd -f input; groupadd -f uinput; usermod -aG input,uinput ${target_user}"
    return 0
  fi

  if [[ "${EUID}" -ne 0 ]] && ! sudo -v; then
    log "sudo authentication failed; skipped Linux device permission setup"
    return 0
  fi

  ensure_linux_group input
  ensure_linux_group uinput
  ensure_user_in_group "${target_user}" input
  ensure_user_in_group "${target_user}" uinput

  rules_file="/etc/udev/rules.d/99-kanata-tool.rules"
  modules_file="/etc/modules-load.d/uinput.conf"

  printf '%s\n' \
    'KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput", TAG+="uaccess"' \
    'SUBSYSTEM=="input", KERNEL=="event*", MODE="0660", GROUP="input", TAG+="uaccess"' \
    | run_as_root tee "${rules_file}" >/dev/null
  log "Installed udev rules: ${rules_file}"

  printf '%s\n' 'uinput' | run_as_root tee "${modules_file}" >/dev/null
  run_as_root modprobe uinput 2>/dev/null || true
  if command -v udevadm >/dev/null 2>&1; then
    run_as_root udevadm control --reload-rules || true
    run_as_root udevadm trigger --subsystem-match=input || true
  fi

  if [[ "${LINUX_PERMISSIONS_CHANGED}" -eq 1 ]]; then
    log "Group membership changed; log out and back in before starting kanata"
  fi
}

install_linux_service() {
  local start_now="${1:-1}"
  mkdir -p "${KANATA_SYSTEMD_USER_DIR}"
  cp "${KANATA_TOOL_AUTOSTART_DIR}/linux/kanata.service" "${KANATA_SYSTEMD_SERVICE}"
  if [[ "${start_now}" -eq 0 ]]; then
    if linux_runtime_systemd_usable && systemctl --user daemon-reload && systemctl --user enable kanata.service; then
      log "systemd user service enabled; start deferred until next login"
      return 0
    fi
  elif linux_runtime_systemd_usable && systemctl --user daemon-reload && systemctl --user enable --now kanata.service; then
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
  install_linux_permissions
  if command -v systemctl >/dev/null 2>&1; then
    if ! install_linux_service "$((1 - LINUX_PERMISSIONS_CHANGED))"; then
      "${KANATA_RUNTIME_BIN}" --cfg "${KANATA_CONFIG_RUNTIME}" --check
      if [[ "${LINUX_PERMISSIONS_CHANGED}" -eq 0 ]]; then
        linux_runtime_start_manual
        log "Started kanata without systemd user service"
      fi
      log "Autostart was not configured because systemctl --user is unavailable"
      exit 0
    fi
  else
    log "systemctl not found; skipped autostart setup"
    "${KANATA_RUNTIME_BIN}" --cfg "${KANATA_CONFIG_RUNTIME}" --check
    if [[ "${LINUX_PERMISSIONS_CHANGED}" -eq 0 ]]; then
      linux_runtime_start_manual
      log "Started kanata without systemd"
    fi
    exit 0
  fi

  "${KANATA_RUNTIME_BIN}" --cfg "${KANATA_CONFIG_RUNTIME}" --check
  log "Config validation succeeded"
}

main "$@"
