#!/usr/bin/env bash
set -euo pipefail

INSTALL_ROOT="${KANATA_TOOL_HOME:-${HOME}/.local/share/kanata-tool}"
BIN_DIR="${HOME}/.local/bin"
CLI_WRAPPER="${BIN_DIR}/kanata-tool"
INIT_SCRIPT="${INSTALL_ROOT}/init.sh"
MARKER="# added by kanata-tool installer"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_SH="${BASH_SOURCE[0]}"
SOURCE_DIR=""
PACKAGE_README=""
PRESERVE_CONFIG=0
DEV_VERSION="0.0.0-dev"
INIT_SCRIPT_SOURCE="\${HOME}/.local/share/kanata-tool/init.sh"

log() { printf '[install] %s\n' "$*"; }
warn() { printf '[install] %s\n' "$*" >&2; }
error_exit() { printf '[install] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --from-dir <path>    Install files from a local payload directory
  --preserve-config    Preserve existing runtime keymap during setup
  --uninstall          Remove kanata-tool and runtime files
  -h, --help           Show this help
EOF
}

detect_default_source_dir() {
  if [[ -d "${SCRIPT_DIR}/bin" && -d "${SCRIPT_DIR}/commands" ]]; then
    SOURCE_DIR="${SCRIPT_DIR}"
    return 0
  fi

  if [[ -d "${SCRIPT_DIR}/src/bin" && -d "${SCRIPT_DIR}/src/commands" ]]; then
    SOURCE_DIR="$(cd "${SCRIPT_DIR}/src" && pwd)"
    return 0
  fi

  error_exit "No payload directory found. Use --from-dir <path>."
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from-dir)
        [[ $# -ge 2 ]] || error_exit "--from-dir requires a path"
        [[ -d "$2" ]] || error_exit "Source directory not found: $2"
        SOURCE_DIR="$(cd "$2" && pwd)"
        shift
        ;;
      --preserve-config)
        PRESERVE_CONFIG=1
        ;;
      --uninstall)
        perform_uninstall
        exit 0
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error_exit "Unknown option: $1"
        ;;
    esac
    shift
  done

  if [[ -z "${SOURCE_DIR}" ]]; then
    detect_default_source_dir
  fi
  PACKAGE_README="${SOURCE_DIR}/README.md"
}

require_source_item() {
  local item="$1"
  if [[ ! -e "${SOURCE_DIR}/${item}" ]]; then
    error_exit "Missing source item: ${SOURCE_DIR}/${item}"
  fi
}

detected_shell="$(basename "${SHELL:-sh}")"
case "${detected_shell}" in
  zsh) profiles="${HOME}/.zshrc" ;;
  bash) profiles="${HOME}/.bashrc ${HOME}/.bash_profile" ;;
  *) profiles="${HOME}/.profile" ;;
esac

case "${detected_shell}" in
  zsh|bash) source_line="[[ -s \"${INIT_SCRIPT_SOURCE}\" ]] && source \"${INIT_SCRIPT_SOURCE}\"  ${MARKER}" ;;
  *) source_line="[ -s \"${INIT_SCRIPT_SOURCE}\" ] && . \"${INIT_SCRIPT_SOURCE}\"  ${MARKER}" ;;
esac

remove_profile_entries() {
  local profile tmp trimmed_tmp
  for profile in ${profiles}; do
    [[ -f "${profile}" ]] || continue
    if grep -q "${MARKER}" "${profile}" 2>/dev/null; then
      tmp="$(mktemp)"
      trimmed_tmp="$(mktemp)"
      grep -v "${MARKER}" "${profile}" > "${tmp}"
      awk '
        { lines[NR] = $0 }
        $0 ~ /[^[:space:]]/ { last = NR }
        END {
          for (i = 1; i <= last; i++) {
            print lines[i]
          }
        }
      ' "${tmp}" > "${trimmed_tmp}"
      mv "${trimmed_tmp}" "${profile}"
      rm -f "${tmp}"
      log "Removed profile entry from ${profile}"
    fi
  done
}

run_runtime_uninstall() {
  local dispatcher
  dispatcher="${INSTALL_ROOT}/bin/kanata-tool"
  if [[ -x "${dispatcher}" ]]; then
    KANATA_TOOL_HOME="${INSTALL_ROOT}" KANATA_TOOL_UNINSTALL_RUNTIME_ONLY=1 \
      bash "${dispatcher}" uninstall || true
  fi
}

perform_uninstall() {
  run_runtime_uninstall
  rm -f "${CLI_WRAPPER}"
  rm -rf "${INSTALL_ROOT}"
  remove_profile_entries
  log "Removed ${CLI_WRAPPER}"
  log "Removed ${INSTALL_ROOT}"
  log "Clean uninstall completed"
}

install_tree() {
  local item
  for item in autostart bin commands config scripts lib; do
    require_source_item "${item}"
  done

  rm -rf "${INSTALL_ROOT}"
  mkdir -p "${INSTALL_ROOT}" "${INSTALL_ROOT}/bin" "${BIN_DIR}"
  cp -R "${SOURCE_DIR}/autostart" "${INSTALL_ROOT}/"
  cp -R "${SOURCE_DIR}/commands" "${INSTALL_ROOT}/"
  cp -R "${SOURCE_DIR}/config" "${INSTALL_ROOT}/"
  cp -R "${SOURCE_DIR}/scripts" "${INSTALL_ROOT}/"
  cp -R "${SOURCE_DIR}/lib" "${INSTALL_ROOT}/"
  cp "${SOURCE_DIR}/bin/kanata-tool" "${INSTALL_ROOT}/bin/kanata-tool"
  cp "${SOURCE_DIR}/bin/kanata-tool.ps1" "${INSTALL_ROOT}/bin/kanata-tool.ps1"
  cp "${SOURCE_DIR}/bin/kanata-tool.cmd" "${INSTALL_ROOT}/bin/kanata-tool.cmd"
  cp "${INSTALLER_SH}" "${INSTALL_ROOT}/install.sh"
  if [[ -f "${SCRIPT_DIR}/install.ps1" ]]; then
    cp "${SCRIPT_DIR}/install.ps1" "${INSTALL_ROOT}/install.ps1"
  fi
  if [[ -f "${SOURCE_DIR}/VERSION" ]]; then
    cp "${SOURCE_DIR}/VERSION" "${INSTALL_ROOT}/VERSION"
  else
    printf '%s\n' "${DEV_VERSION}" > "${INSTALL_ROOT}/VERSION"
  fi
  chmod +x "${INSTALL_ROOT}/install.sh" "${INSTALL_ROOT}/bin/kanata-tool"
  chmod +x "${INSTALL_ROOT}/commands/linux/"*.sh "${INSTALL_ROOT}/commands/macos/"*.sh
  if [[ -f "${INSTALL_ROOT}/scripts/fetch-kanata-binaries.sh" ]]; then
    chmod +x "${INSTALL_ROOT}/scripts/fetch-kanata-binaries.sh"
  fi
}

write_wrapper() {
  cat > "${CLI_WRAPPER}" <<EOF
#!/bin/sh
exec "${INSTALL_ROOT}/bin/kanata-tool" "\$@"
EOF
  chmod +x "${CLI_WRAPPER}"
}

write_init() {
  cat > "${INIT_SCRIPT}" <<'EOF'
export PATH="$HOME/.local/bin:$PATH"
EOF
  chmod +x "${INIT_SCRIPT}"
}

register_profiles() {
  local profile
  for profile in ${profiles}; do
    [[ -f "${profile}" ]] || touch "${profile}"
    if grep -q "${MARKER}" "${profile}" 2>/dev/null; then
      log "Profile already configured: ${profile}"
      continue
    fi
    printf '\n%s\n' "${source_line}" >> "${profile}"
    log "Updated profile: ${profile}"
  done
}

print_reload_hint() {
  local profile
  log "To use the updated PATH in the current shell, run one of:"
  for profile in ${profiles}; do
    [[ -f "${profile}" ]] || continue
    printf '  source %s\n' "${profile}"
  done
  log "Or open a new terminal session and run: kanata-tool status"
}

check_macos_prerequisites() {
  if ! systemextensionsctl list 2>/dev/null | grep -q "Karabiner-DriverKit-VirtualHIDDevice"; then
    error_exit "Karabiner-Elements is required but not detected.
  Install it first: brew install --cask karabiner-elements
  Then allow the system extension in: System Settings > Privacy & Security."
  fi
}

main() {
  parse_args "$@"

  if [[ "$(uname -s)" == "Darwin" ]]; then
    check_macos_prerequisites
  fi

  install_tree
  write_wrapper
  write_init
  register_profiles

  log "Installed management CLI to ${CLI_WRAPPER}"
  if [[ "${PRESERVE_CONFIG}" == "1" ]]; then
    KANATA_TOOL_HOME="${INSTALL_ROOT}" bash "${INSTALL_ROOT}/bin/kanata-tool" setup --preserve-config
  else
    KANATA_TOOL_HOME="${INSTALL_ROOT}" bash "${INSTALL_ROOT}/bin/kanata-tool" setup
  fi

  [[ -f "${PACKAGE_README}" ]] && log "Installed from package in ${SOURCE_DIR}"
  log "Installation completed"
  print_reload_hint
}

main "$@"
