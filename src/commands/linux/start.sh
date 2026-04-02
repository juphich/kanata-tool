#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/paths.sh"
source "${SCRIPT_DIR}/../../lib/linux-runtime.sh"

if linux_runtime_systemd_usable; then
  systemctl --user start kanata.service
  linux_runtime_log "Started kanata.service"
else
  linux_runtime_start_manual
fi
