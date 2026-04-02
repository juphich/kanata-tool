#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/paths.sh
source "${SCRIPT_DIR}/../../lib/paths.sh"
# shellcheck source=../../lib/linux-runtime.sh
source "${SCRIPT_DIR}/../../lib/linux-runtime.sh"

if linux_runtime_systemd_usable; then
  systemctl --user start kanata.service
  linux_runtime_log "Started kanata.service"
else
  linux_runtime_start_manual
fi
