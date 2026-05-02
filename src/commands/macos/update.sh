#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/paths.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/update.sh"

usage() {
  cat <<'EOF'
Usage: kanata-tool update [options]

Options:
  --check    Check whether a newer kanata-tool release is available
  --version <version>
             Install a specific kanata-tool release
EOF
}

main() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    update_log "This command is for macOS only"
    exit 1
  fi

  case "${1:-}" in
    --check)
      update_check
      ;;
    --version)
      [[ $# -ge 2 ]] || {
        update_log "--version requires a value"
        exit 1
      }
      update_install "$2"
      ;;
    -h|--help|help)
      usage
      ;;
    "")
      update_install
      ;;
    *)
      update_log "Unknown option: $1"
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
