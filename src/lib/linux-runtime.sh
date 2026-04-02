#!/usr/bin/env bash
set -euo pipefail

linux_runtime_log() {
  printf '[kanata-tool] %s\n' "$*"
}

linux_runtime_systemd_usable() {
  command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1
}

linux_runtime_running() {
  pgrep -x kanata >/dev/null 2>&1
}

linux_runtime_start_manual() {
  if linux_runtime_running; then
    linux_runtime_log "kanata process already running"
    return 0
  fi

  nohup "${KANATA_RUNTIME_BIN}" --cfg "${KANATA_CONFIG_RUNTIME}" >/dev/null 2>&1 &
  disown || true
  linux_runtime_log "Started kanata process"
}

linux_runtime_stop_manual() {
  if linux_runtime_running; then
    pkill -x kanata || true
    linux_runtime_log "Stopped kanata process"
    return 0
  fi

  linux_runtime_log "kanata process is not running"
}
