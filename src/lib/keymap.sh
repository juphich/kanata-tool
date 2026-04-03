#!/usr/bin/env bash
set -euo pipefail

KEYMAP_TMP_FILE=""

keymap_log() {
  printf '[keymap] %s\n' "$*"
}

keymap_require_setup() {
  if [[ ! -x "${KANATA_RUNTIME_BIN}" ]]; then
    keymap_log "kanata binary not found at ${KANATA_RUNTIME_BIN}. Run 'kanata-tool setup' first."
    exit 1
  fi

  if [[ ! -f "${KANATA_CONFIG_BASE}" ]]; then
    keymap_log "Base config not found at ${KANATA_CONFIG_BASE}. Run 'kanata-tool setup' first."
    exit 1
  fi
}

keymap_cleanup() {
  if [[ -n "${KEYMAP_TMP_FILE}" && -f "${KEYMAP_TMP_FILE}" ]]; then
    rm -f "${KEYMAP_TMP_FILE}"
  fi
}

keymap_prepare_runtime() {
  keymap_require_setup
  mkdir -p "${KANATA_CONFIG_DIR}"
  if [[ ! -f "${KANATA_CONFIG_RUNTIME}" ]]; then
    cp "${KANATA_CONFIG_BASE}" "${KANATA_CONFIG_RUNTIME}"
  fi
}

keymap_validate_and_install() {
  local source_file="$1"
  KEYMAP_TMP_FILE="$(mktemp)"
  cp "${source_file}" "${KEYMAP_TMP_FILE}"

  if ! ${KANATA_RUN_PREFIX:-} "${KANATA_RUNTIME_BIN}" --cfg "${KEYMAP_TMP_FILE}" --check; then
    keymap_log "Validation failed. Keeping existing keymap."
    rm -f "${KEYMAP_TMP_FILE}"
    KEYMAP_TMP_FILE=""
    exit 1
  fi

  mv "${KEYMAP_TMP_FILE}" "${KANATA_CONFIG_RUNTIME}"
  KEYMAP_TMP_FILE=""
  keymap_log "Updated keymap: ${KANATA_CONFIG_RUNTIME}"
}

keymap_select_editor() {
  if [[ -n "${VISUAL:-}" ]]; then
    printf '%s\n' "${VISUAL}"
    return
  fi

  if [[ -n "${EDITOR:-}" ]]; then
    printf '%s\n' "${EDITOR}"
    return
  fi

  if command -v editor >/dev/null 2>&1; then
    printf '%s\n' "editor"
    return
  fi

  if command -v vi >/dev/null 2>&1; then
    printf '%s\n' "vi"
    return
  fi

  keymap_log "No editor found. Set VISUAL or EDITOR."
  exit 1
}

keymap_edit_runtime() {
  local editor
  editor="$(keymap_select_editor)"
  KEYMAP_TMP_FILE="$(mktemp)"
  cp "${KANATA_CONFIG_RUNTIME}" "${KEYMAP_TMP_FILE}"
  trap keymap_cleanup EXIT
  # shellcheck disable=SC2086
  ${editor} "${KEYMAP_TMP_FILE}"
  keymap_validate_and_install "${KEYMAP_TMP_FILE}"
  trap - EXIT
}
