#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/linux-runtime.sh
source "${SCRIPT_DIR}/../../lib/linux-runtime.sh"

if linux_runtime_systemd_usable; then
  systemctl --user stop kanata.service
  linux_runtime_log "Stopped kanata.service"
else
  linux_runtime_stop_manual
fi
