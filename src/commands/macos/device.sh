#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/paths.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/keymap.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/device.sh"
# shellcheck disable=SC2034
KANATA_RUN_PREFIX="sudo"

usage() {
  cat <<'EOF'
Usage: kanata-tool device [option]

Options:
  --list          List keyboards detected by kanata and selection status
  --config        Interactively add or remove a keyboard
  --add <id>      Add keyboard by device id/path
  --remove <id>   Remove keyboard by device id/path
EOF
}

reload_if_running() {
  local uid launchd_domain launchd_service
  uid="$(id -u)"
  launchd_domain="gui/${uid}"
  launchd_service="${launchd_domain}/com.kanata"

  if pgrep -x kanata >/dev/null 2>&1; then
    launchctl bootout "${launchd_domain}" "${KANATA_LAUNCH_AGENT}" >/dev/null 2>&1 || true
    if launchctl bootstrap "${launchd_domain}" "${KANATA_LAUNCH_AGENT}" >/dev/null 2>&1; then
      launchctl kickstart -k "${launchd_service}" >/dev/null 2>&1 || true
      device_log "launch agent를 다시 시작했습니다"
      return
    fi
    device_log "설정은 반영됐지만 launch agent 재시작에 실패했습니다"
    return
  fi

  device_log "kanata가 실행 중이 아니어서 설정만 갱신했습니다"
}

cmd_list() {
  device_require_runtime
  device_print_entries
}

cmd_add() {
  local target_id="${1:-}"
  local entry suggestion _num name _id source _selected

  [[ -n "${target_id}" ]] || { usage >&2; exit 1; }
  device_require_runtime
  entry="$(device_lookup_entry_by_id "${target_id}")" || {
    device_log "잘못된 id 입니다: ${target_id}"
    if suggestion="$(device_suggest_id "${target_id}")"; then
      device_log "혹시 이 id를 의미하셨나요?: ${suggestion}"
    fi
    exit 1
  }
  IFS=$'\t' read -r _num name _id source _selected <<< "${entry}"
  local status
  if device_add_source "${source}"; then
    status=0
  else
    status=$?
  fi
  if [[ ${status} -eq 10 ]]; then
    return 0
  fi
  [[ ${status} -eq 0 ]] || exit "${status}"
  reload_if_running
  device_log "등록 대상: ${name}"
}

cmd_remove() {
  local target_id="${1:-}"
  local entry suggestion _num name _id source _selected

  [[ -n "${target_id}" ]] || { usage >&2; exit 1; }
  device_require_runtime
  entry="$(device_lookup_entry_by_id "${target_id}")" || {
    device_log "잘못된 id 입니다: ${target_id}"
    if suggestion="$(device_suggest_id "${target_id}")"; then
      device_log "혹시 이 id를 의미하셨나요?: ${suggestion}"
    fi
    exit 1
  }
  IFS=$'\t' read -r _num name _id source _selected <<< "${entry}"
  local status
  if device_remove_source "${source}"; then
    status=0
  else
    status=$?
  fi
  if [[ ${status} -eq 10 ]]; then
    return 0
  fi
  [[ ${status} -eq 0 ]] || exit "${status}"
  reload_if_running
  device_log "제거 대상: ${name}"
}

cmd_config() {
  local action target_num target_id
  local entry _num _name _id _source _selected

  device_require_runtime

  if [[ ! -t 0 || ! -t 1 ]]; then
    device_log "대화형 환경이 아닙니다. 'kanata-tool device --add <id>' 또는 'kanata-tool device --remove <id>'를 사용하세요"
    exit 1
  fi

  while true; do
    printf 'kanata device 설정\n'
    printf '명령 목록\n'
    printf '1. view devices    2.add device    3. remove device    4. quit\n'
    printf '명령선택 : '
    read -r action
    printf '\n'

    case "${action}" in
      1)
        device_print_entries
        ;;
      2)
        device_print_entries
        printf '추가할 기기 번호를 입력하세요: '
        read -r target_num
        entry="$(device_lookup_entry_by_num "${target_num}")" || {
          device_log "잘못된 번호입니다: ${target_num}"
          continue
        }
        IFS=$'\t' read -r _num _name _id _source _selected <<< "${entry}"
        target_id="${_id}"
        cmd_add "${target_id}"
        ;;
      3)
        device_print_entries
        printf '삭제할 기기 번호를 입력하세요: '
        read -r target_num
        entry="$(device_lookup_entry_by_num "${target_num}")" || {
          device_log "잘못된 번호입니다: ${target_num}"
          continue
        }
        IFS=$'\t' read -r _num _name _id _source _selected <<< "${entry}"
        target_id="${_id}"
        cmd_remove "${target_id}"
        ;;
      4)
        break
        ;;
      *)
        device_log "알 수 없는 작업입니다: ${action}"
        ;;
    esac

    printf '\n'
  done
}

main() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    device_log "이 명령은 macOS 전용입니다"
    exit 1
  fi

  trap device_cleanup EXIT

  case "${1:-}" in
    --list)
      [[ $# -eq 1 ]] || { usage >&2; exit 1; }
      cmd_list
      ;;
    --config)
      [[ $# -eq 1 ]] || { usage >&2; exit 1; }
      cmd_config
      ;;
    --add)
      [[ $# -eq 2 ]] || { usage >&2; exit 1; }
      cmd_add "$2"
      ;;
    --remove)
      [[ $# -eq 2 ]] || { usage >&2; exit 1; }
      cmd_remove "$2"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
