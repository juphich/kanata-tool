#!/usr/bin/env bash
set -euo pipefail

DEVICE_TMP_FILE=""

device_log() {
  printf '[device] %s\n' "$*"
}

device_cleanup() {
  if [[ -n "${DEVICE_TMP_FILE}" && -f "${DEVICE_TMP_FILE}" ]]; then
    rm -f "${DEVICE_TMP_FILE}"
  fi
}

device_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

device_require_runtime() {
  keymap_prepare_runtime
}

device_cfg_key() {
  case "$(uname -s)" in
    Linux) printf 'linux-dev-names-include\n' ;;
    Darwin) printf 'macos-dev-names-include\n' ;;
    *) return 1 ;;
  esac
}

device_source_from_entry() {
  local name="$1"
  local id="$2"

  case "$(uname -s)" in
    Linux) printf '%s\n' "${name}" ;;
    Darwin) printf '%s\n' "${name}" ;;
    *) return 1 ;;
  esac
}

device_quote_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "${value}"
}

device_build_cfg_line() {
  local cfg_key="$1"
  shift || true

  if [[ $# -eq 0 ]]; then
    return 0
  fi

  local item
  printf '  %s (\n' "${cfg_key}"
  for item in "$@"; do
    printf '    %s\n' "$(device_quote_string "${item}")"
  done
  printf '  )'
}

device_parse_cfg_payload() {
  local payload
  payload="$(device_trim "$1")"

  if [[ "${payload}" == \(*\) ]]; then
    payload="${payload#\(}"
    payload="${payload%\)}"
    while [[ "${payload}" =~ \"(([^\"\\]|\\.)*)\" ]]; do
      local raw="${BASH_REMATCH[1]}"
      raw="${raw//\\\\/__DEVICE_ESC_BS__}"
      raw="${raw//\\\"/\"}"
      raw="${raw//__DEVICE_ESC_BS__/\\}"
      printf '%s\n' "${raw}"
      payload="${payload#*"${BASH_REMATCH[0]}"}"
    done
    return 0
  fi

  local parsed="" escape=0 char
  local i
  for ((i = 0; i < ${#payload}; i++)); do
    char="${payload:i:1}"
    if (( escape )); then
      parsed+="${char}"
      escape=0
      continue
    fi
    case "${char}" in
      \\)
        escape=1
        ;;
      :)
        printf '%s\n' "${parsed}"
        parsed=""
        ;;
      *)
        parsed+="${char}"
        ;;
    esac
  done

  if [[ -n "${parsed}" ]]; then
    printf '%s\n' "${parsed}"
  fi
}

device_current_sources() {
  local cfg_key line payload in_defcfg=0 skip_block=0
  cfg_key="$(device_cfg_key)"

  while IFS= read -r line; do
    if (( skip_block )); then
      payload="$(device_trim "${line}")"
      if [[ "${payload}" =~ ^\"(([^\"\\]|\\.)*)\"$ ]]; then
        local raw="${BASH_REMATCH[1]}"
        raw="${raw//\\\\/__DEVICE_ESC_BS__}"
        raw="${raw//\\\"/\"}"
        raw="${raw//__DEVICE_ESC_BS__/\\}"
        printf '%s\n' "${raw}"
        continue
      fi
      if [[ "${payload}" =~ ^\)$ ]]; then
        skip_block=0
      fi
      continue
    fi

    if (( ! in_defcfg )); then
      if [[ "${line}" =~ ^\(defcfg([[:space:]]|\)|$) ]]; then
        in_defcfg=1
      fi
      continue
    fi

    if [[ "${line}" =~ ^[[:space:]]*\)$ ]]; then
      break
    fi

    if [[ "${line}" =~ ^[[:space:]]*${cfg_key}([[:space:]]+)(.*)$ ]]; then
      payload="${BASH_REMATCH[2]}"
      if [[ "${payload}" == *"("* && "${payload}" != *")"* ]]; then
        skip_block=1
        continue
      else
        device_parse_cfg_payload "${payload}"
        return 0
      fi
    fi
  done < "${KANATA_CONFIG_RUNTIME}"
}

device_has_source() {
  local target="$1"
  shift || true
  local item
  for item in "$@"; do
    if [[ "${item}" == "${target}" ]]; then
      return 0
    fi
  done
  return 1
}

device_run_list_raw() {
  # shellcheck disable=SC2086
  ${KANATA_RUN_PREFIX:-} "${KANATA_RUNTIME_BIN}" --list
}

device_emit_entry() {
  local num="$1"
  local name="$2"
  local id="$3"
  local vendor_product="$4"
  local source="$5"
  local selected="$6"

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${num}" "${name}" "${id}" "${vendor_product}" "${source}" "${selected}"
}

device_collect_entries() {
  local raw name="" id="" vendor_product="" source line num=1 in_entry=0
  local -a selected_sources=()
  local default_all=1
  local in_table=0 hash vendor_id product_id product_key
  while IFS= read -r line; do
    selected_sources+=("${line}")
  done < <(device_current_sources || true)
  if [[ ${#selected_sources[@]} -gt 0 ]]; then
    default_all=0
  fi

  while IFS= read -r raw; do
    raw="$(device_trim "${raw}")"
    [[ -n "${raw}" ]] || continue

    [[ "${raw}" == "Available keyboard devices:" ]] && continue
    [[ "${raw}" == "Found "* ]] && continue
    [[ "${raw}" == "Configuration example:" ]] && break
    [[ "${raw}" =~ ^==+$ ]] && {
      in_table=1
      continue
    }
    [[ "${raw}" =~ ^[-[:space:]]+$ ]] && continue
    [[ "${raw}" =~ ^hash[[:space:]]+vendor_id[[:space:]]+product_id[[:space:]]+product_key$ ]] && {
      in_table=1
      continue
    }

    if (( in_table )) && [[ "${raw}" =~ ^(0x[0-9A-Fa-f]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)([[:space:]]+(.*))?$ ]]; then
      hash="${BASH_REMATCH[1]}"
      vendor_id="${BASH_REMATCH[2]}"
      product_id="${BASH_REMATCH[3]}"
      product_key="$(device_trim "${BASH_REMATCH[5]:-}")"
      if [[ -n "${product_key}" ]]; then
        name="${product_key}"
        id="${hash}"
      else
        name="${hash}"
        id="${hash}"
      fi
      vendor_product="${vendor_id} (0x$(printf '%X' "${vendor_id}")), Product ID: ${product_id} (0x$(printf '%X' "${product_id}"))"
      if [[ -n "${product_key}" ]]; then
        source="${product_key}"
      else
        source="${hash}"
      fi
      if [[ "${default_all}" == "1" ]]; then
        device_emit_entry "${num}" "${name}" "${id}" "${vendor_product}" "${source}" "all"
      elif device_has_source "${source}" "${selected_sources[@]}"; then
        device_emit_entry "${num}" "${name}" "${id}" "${vendor_product}" "${source}" "yes"
      else
        device_emit_entry "${num}" "${name}" "${id}" "${vendor_product}" "${source}" "no"
      fi
      num=$((num + 1))
      continue
    fi

    if [[ "${raw}" =~ ^[0-9]+\.\ \"(.*)\"$ ]]; then
      if (( in_entry )) && [[ -n "${name}" ]]; then
        source="$(device_source_from_entry "${name}" "${id}")"
        if [[ "${default_all}" == "1" ]]; then
          device_emit_entry "${num}" "${name}" "${id}" "${vendor_product}" "${source}" "all"
        elif device_has_source "${source}" "${selected_sources[@]}"; then
          device_emit_entry "${num}" "${name}" "${id}" "${vendor_product}" "${source}" "yes"
        else
          device_emit_entry "${num}" "${name}" "${id}" "${vendor_product}" "${source}" "no"
        fi
        num=$((num + 1))
      fi
      name="${BASH_REMATCH[1]}"
      id=""
      vendor_product=""
      in_entry=1
      continue
    fi

    if (( in_entry )) && [[ "${raw}" =~ ^Path:[[:space:]]*(.*)$ ]]; then
      id="$(device_trim "${BASH_REMATCH[1]}")"
      continue
    fi

    if (( in_entry )) && [[ "${raw}" =~ ^Vendor[[:space:]]ID:[[:space:]]*(.*)$ ]]; then
      vendor_product="$(device_trim "${BASH_REMATCH[1]}")"
      continue
    fi
  done < <(device_run_list_raw)

  if (( in_entry )) && [[ -n "${name}" ]]; then
    source="$(device_source_from_entry "${name}" "${id}")"
    if [[ "${default_all}" == "1" ]]; then
      device_emit_entry "${num}" "${name}" "${id}" "${vendor_product}" "${source}" "all"
    elif device_has_source "${source}" "${selected_sources[@]}"; then
      device_emit_entry "${num}" "${name}" "${id}" "${vendor_product}" "${source}" "yes"
    else
      device_emit_entry "${num}" "${name}" "${id}" "${vendor_product}" "${source}" "no"
    fi
  fi
}

device_name_priority() {
  local name="$1"
  case "${name}" in
    *Keyboard*) printf '2\n' ;;
    *Consumer\ Control*|*System\ Control*) printf '0\n' ;;
    *) printf '1\n' ;;
  esac
}

device_parse_vendor_product_ids() {
  local vendor_product="$1"
  local vid="" pid=""

  if [[ "${vendor_product}" =~ ^([0-9]+)[[:space:]]+\(0x[0-9A-Fa-f]+\),[[:space:]]+Product[[:space:]]+ID:[[:space:]]+([0-9]+)[[:space:]]+\(0x[0-9A-Fa-f]+\)$ ]]; then
    vid="${BASH_REMATCH[1]}"
    pid="${BASH_REMATCH[2]}"
  fi

  printf '%s\t%s\n' "${vid}" "${pid}"
}

device_collect_entries_filtered() {
  local line
  local -a passthrough_lines=()
  local -a vendor_products=()
  local -a best_lines=()
  local -a best_priorities=()
  local num name id vendor_product source selected priority current_priority
  local i found_index sorted_vendor_product

  while IFS=$'\t' read -r num name id vendor_product source selected; do
    if [[ -z "${vendor_product}" ]]; then
      passthrough_lines+=("${name}"$'\t'"${id}"$'\t'"${source}"$'\t'"${selected}")
      continue
    fi

    priority="$(device_name_priority "${name}")"
    found_index=""
    if (( ${#vendor_products[@]} > 0 )); then
      for i in "${!vendor_products[@]}"; do
        if [[ "${vendor_products[${i}]}" == "${vendor_product}" ]]; then
          found_index="${i}"
          break
        fi
      done
    fi

    if [[ -z "${found_index}" ]]; then
      vendor_products+=("${vendor_product}")
      best_priorities+=("${priority}")
      best_lines+=("${name}"$'\t'"${id}"$'\t'"${source}"$'\t'"${selected}")
      continue
    fi

    current_priority="${best_priorities[${found_index}]:--1}"
    if (( priority > current_priority )); then
      best_priorities[${found_index}]="${priority}"
      best_lines[${found_index}]="${name}"$'\t'"${id}"$'\t'"${source}"$'\t'"${selected}"
    fi
  done < <(device_collect_entries)

  num=1
  if (( ${#passthrough_lines[@]} > 0 )); then
    for line in "${passthrough_lines[@]}"; do
      IFS=$'\t' read -r name id source selected <<< "${line}"
      printf '%s\t%s\t%s\t%s\t%s\n' "${num}" "${name}" "${id}" "${source}" "${selected}"
      num=$((num + 1))
    done
  fi

  if (( ${#vendor_products[@]} > 0 )); then
    while IFS= read -r sorted_vendor_product; do
      [[ -n "${sorted_vendor_product}" ]] || continue
      for i in "${!vendor_products[@]}"; do
        [[ "${vendor_products[${i}]}" == "${sorted_vendor_product}" ]] || continue
        line="${best_lines[${i}]}"
        break
      done
      IFS=$'\t' read -r name id source selected <<< "${line}"
      printf '%s\t%s\t%s\t%s\t%s\n' "${num}" "${name}" "${id}" "${source}" "${selected}"
      num=$((num + 1))
    done < <(printf '%s\n' "${vendor_products[@]}" | sort)
  fi
}

device_lookup_entry_by_num() {
  local target_num="$1"
  local entry_num
  while IFS=$'\t' read -r entry_num _name _id _source _selected; do
    if [[ "${entry_num}" == "${target_num}" ]]; then
      printf '%s\t%s\t%s\t%s\t%s\n' "${entry_num}" "${_name}" "${_id}" "${_source}" "${_selected}"
      return 0
    fi
  done < <(device_collect_entries_filtered)
  return 1
}

device_lookup_entry_by_id() {
  local target_id="$1"
  local entry_num name id source selected
  while IFS=$'\t' read -r entry_num name id source selected; do
    if [[ "${id}" == "${target_id}" ]]; then
      printf '%s\t%s\t%s\t%s\t%s\n' "${entry_num}" "${name}" "${id}" "${source}" "${selected}"
      return 0
    fi
  done < <(device_collect_entries_filtered)
  return 1
}

device_suggest_id() {
  local target_id="$1"
  local ids=()
  local _num _name id _source _selected
  local best

  while IFS=$'\t' read -r _num _name id _source _selected; do
    ids+=("${id}")
  done < <(device_collect_entries_filtered)

  [[ ${#ids[@]} -gt 0 ]] || return 1

  best="$(
    printf '%s\n' "${ids[@]}" | awk -v target="${target_id}" '
      function min3(a, b, c) {
        m = a
        if (b < m) m = b
        if (c < m) m = c
        return m
      }
      function levenshtein(s, t,    n, m, i, j, cost, a, b, c) {
        n = length(s)
        m = length(t)
        for (i = 0; i <= n; i++) d[i, 0] = i
        for (j = 0; j <= m; j++) d[0, j] = j
        for (i = 1; i <= n; i++) {
          for (j = 1; j <= m; j++) {
            cost = (substr(s, i, 1) == substr(t, j, 1)) ? 0 : 1
            a = d[i - 1, j] + 1
            b = d[i, j - 1] + 1
            c = d[i - 1, j - 1] + cost
            d[i, j] = min3(a, b, c)
          }
        }
        return d[n, m]
      }
      {
        score = levenshtein(target, $0)
        if (best_line == "" || score < best_score) {
          best_score = score
          best_line = $0
        }
      }
      END {
        if (best_line != "") print best_line
      }
    '
  )"

  [[ -n "${best}" ]] || return 1
  printf '%s\n' "${best}"
}

device_lookup_entry_by_source() {
  local target_source="$1"
  local num name id source selected
  while IFS=$'\t' read -r num name id source selected; do
    if [[ "${source}" == "${target_source}" ]]; then
      printf '%s\t%s\t%s\t%s\t%s\n' "${num}" "${name}" "${id}" "${source}" "${selected}"
      return 0
    fi
  done < <(device_collect_entries_filtered)
  return 1
}

device_print_entries() {
  local num name id source selected found=0
  local entry_num raw_name raw_id raw_vendor_product raw_source raw_selected
  local vid pid
  local -a rows=()
  local num_width=0 name_width=0 vid_width=0 pid_width=0

  while IFS=$'\t' read -r num name id source selected; do
    vid=""
    pid=""
    while IFS=$'\t' read -r entry_num raw_name raw_id raw_vendor_product raw_source raw_selected; do
      if [[ "${raw_source}" == "${source}" ]]; then
        IFS=$'\t' read -r vid pid <<< "$(device_parse_vendor_product_ids "${raw_vendor_product}")"
        break
      fi
    done < <(device_collect_entries)
    rows+=("${num}"$'\t'"${selected}"$'\t'"${name}"$'\t'"${vid:--}"$'\t'"${pid:--}"$'\t'"${id:--}")
    (( ${#num} > num_width )) && num_width=${#num}
    (( ${#name} > name_width )) && name_width=${#name}
    (( ${#vid} > vid_width )) && vid_width=${#vid}
    (( ${#pid} > pid_width )) && pid_width=${#pid}
    found=1
  done < <(device_collect_entries_filtered)

  if [[ "${found}" == "0" ]]; then
    device_log "감지된 키보드가 없습니다"
    return 0
  fi

  local row mark
  local name_pad
  for row in "${rows[@]}"; do
    IFS=$'\t' read -r num selected name vid pid id <<< "${row}"
    if [[ "${selected}" == "all" ]]; then
      mark="[*]"
    elif [[ "${selected}" == "yes" ]]; then
      mark="[v]"
    else
      mark="[ ]"
    fi
    name_pad=$((name_width - ${#name}))
    printf "%*s. %-3s \"%s\"%*s  vid:%-${vid_width}s  pid:%-${pid_width}s  id:%s\n" \
      "${num_width}" "${num}" "${mark}" "${name}" "${name_pad}" "" "${vid}" "${pid}" "${id}"
  done
}

device_replace_cfg_sources() {
  local cfg_key line new_line in_defcfg=0 skip_block=0 pending_blank_before_close=0
  cfg_key="$(device_cfg_key)"
  shift || true
  new_line="$(device_build_cfg_line "${cfg_key}" "$@")"
  DEVICE_TMP_FILE="$(mktemp)"

  while IFS= read -r line; do
    if (( skip_block )); then
      if [[ "${line}" == *")"* ]]; then
        skip_block=0
      fi
      continue
    fi

    if (( ! in_defcfg )); then
      printf '%s\n' "${line}" >> "${DEVICE_TMP_FILE}"
      if [[ "${line}" =~ ^\(defcfg([[:space:]]|\)|$) ]]; then
        in_defcfg=1
      fi
      continue
    fi

    if [[ "${line}" =~ ^[[:space:]]*${cfg_key}([[:space:]]+|$) ]]; then
      pending_blank_before_close=1
      if [[ "${line}" == *"("* && "${line}" != *")"* ]]; then
        skip_block=1
      fi
      continue
    fi

    if (( in_defcfg )) && [[ -z "$(device_trim "${line}")" ]]; then
      pending_blank_before_close=1
      continue
    fi

    if [[ "${line}" =~ ^[[:space:]]*\)$ ]]; then
      if [[ -n "${new_line}" ]]; then
        printf '\n' >> "${DEVICE_TMP_FILE}"
        printf '%s\n' "${new_line}" >> "${DEVICE_TMP_FILE}"
      else
        pending_blank_before_close=0
      fi
      printf '%s\n' "${line}" >> "${DEVICE_TMP_FILE}"
      in_defcfg=0
      continue
    fi

    pending_blank_before_close=0
    printf '%s\n' "${line}" >> "${DEVICE_TMP_FILE}"
  done < "${KANATA_CONFIG_RUNTIME}"

  keymap_validate_and_install "${DEVICE_TMP_FILE}"
  rm -f "${DEVICE_TMP_FILE}"
  DEVICE_TMP_FILE=""
}

device_apply_sources() {
  local -a updated_sources=("$@")
  device_replace_cfg_sources _ignored "${updated_sources[@]}"
}

device_add_source() {
  local target_source="$1"
  local -a current_sources=()
  local item

  while IFS= read -r item; do
    current_sources+=("${item}")
  done < <(device_current_sources || true)

  if (( ${#current_sources[@]} > 0 )); then
    if device_has_source "${target_source}" "${current_sources[@]}"; then
      device_log "이미 등록된 키보드입니다"
      return 10
    fi
  fi

  current_sources+=("${target_source}")
  device_replace_cfg_sources "$(device_cfg_key)" "${current_sources[@]}"
  return 0
}

device_remove_source() {
  local target_source="$1"
  local -a current_sources=()
  local -a updated_sources=()
  local item found=0

  while IFS= read -r item; do
    current_sources+=("${item}")
  done < <(device_current_sources || true)

  if (( ${#current_sources[@]} > 0 )); then
    for item in "${current_sources[@]}"; do
      if [[ "${item}" == "${target_source}" ]]; then
        found=1
        continue
      fi
      updated_sources+=("${item}")
    done
  fi

  if [[ "${found}" == "0" ]]; then
    device_log "등록되지 않은 키보드입니다"
    return 10
  fi

  if [[ ${#updated_sources[@]} -eq 0 ]]; then
    device_replace_cfg_sources "$(device_cfg_key)"
    return 0
  fi

  device_replace_cfg_sources "$(device_cfg_key)" "${updated_sources[@]}"
  return 0
}
