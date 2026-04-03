#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/paths.sh"

log() { printf '[status] %s\n' "$*"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  log "This command is for macOS only"
  exit 1
fi

log "Platform: macOS"
log "kanata binary: ${KANATA_RUNTIME_BIN}"
log "base config: ${KANATA_CONFIG_BASE}"
log "runtime config: ${KANATA_CONFIG_RUNTIME}"
log "launch agent: ${KANATA_LAUNCH_AGENT}"

if [[ -x "${KANATA_RUNTIME_BIN}" ]]; then
  log "binary installed: yes"
else
  log "binary installed: no"
fi

if [[ -f "${KANATA_CONFIG_BASE}" ]]; then
  log "base config installed: yes"
else
  log "base config installed: no"
fi

if [[ -f "${KANATA_CONFIG_RUNTIME}" ]]; then
  log "runtime config installed: yes"
else
  log "runtime config installed: no"
fi

service_pid=""
service_exit=""
if launchctl_out="$(launchctl list com.kanata 2>/dev/null)"; then
  service_pid="$(printf '%s\n' "${launchctl_out}" | awk '/"PID"/ {gsub(/[^0-9]/,"",$NF); print $NF}')"
  service_exit="$(printf '%s\n' "${launchctl_out}" | awk '/"LastExitStatus"/ {gsub(/[^0-9-]/,"",$NF); print $NF}')"
fi

if [[ -n "${service_pid}" && "${service_pid}" != "0" ]]; then
  log "service running: yes (pid=${service_pid})"
elif [[ -n "${service_exit}" && "${service_exit}" != "0" ]]; then
  log "service running: no (crash loop — last exit status=${service_exit})"
  log "check logs: /tmp/kanata.err.log"
else
  log "service running: no"
fi

if [[ -f "${KANATA_LAUNCH_AGENT}" ]]; then
  log "autostart enabled: yes"
else
  log "autostart enabled: no"
fi
