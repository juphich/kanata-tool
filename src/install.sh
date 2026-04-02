#!/usr/bin/env bash
set -euo pipefail

INSTALL_ROOT="${KANATA_TOOL_HOME:-${HOME}/.local/share/kanata-tool}"
BIN_DIR="${HOME}/.local/bin"
CLI_WRAPPER="${BIN_DIR}/kanata-tool"
INIT_SCRIPT="${INSTALL_ROOT}/init.sh"
MARKER="# added by kanata-tool installer"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_README="${SCRIPT_DIR}/README.md"
INIT_SCRIPT_SOURCE="${INIT_SCRIPT}"

log() { printf '[install] %s\n' "$*"; }
warn() { printf '[install] %s\n' "$*" >&2; }
error_exit() { printf '[install] %s\n' "$*" >&2; exit 1; }

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
  local profile tmp
  for profile in ${profiles}; do
    [[ -f "${profile}" ]] || continue
    if grep -q "${MARKER}" "${profile}" 2>/dev/null; then
      tmp="$(mktemp)"
      grep -v "${MARKER}" "${profile}" > "${tmp}"
      mv "${tmp}" "${profile}"
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
  rm -rf "${INSTALL_ROOT}"
  mkdir -p "${INSTALL_ROOT}" "${INSTALL_ROOT}/bin" "${BIN_DIR}"
  cp -R "${SCRIPT_DIR}/autostart" "${INSTALL_ROOT}/"
  cp -R "${SCRIPT_DIR}/commands" "${INSTALL_ROOT}/"
  cp -R "${SCRIPT_DIR}/config" "${INSTALL_ROOT}/"
  cp -R "${SCRIPT_DIR}/bundled-bin" "${INSTALL_ROOT}/"
  cp -R "${SCRIPT_DIR}/scripts" "${INSTALL_ROOT}/"
  cp -R "${SCRIPT_DIR}/lib" "${INSTALL_ROOT}/"
  cp "${SCRIPT_DIR}/bin/kanata-tool" "${INSTALL_ROOT}/bin/kanata-tool"
  cp "${SCRIPT_DIR}/bin/kanata-tool.ps1" "${INSTALL_ROOT}/bin/kanata-tool.ps1"
  cp "${SCRIPT_DIR}/bin/kanata-tool.cmd" "${INSTALL_ROOT}/bin/kanata-tool.cmd"
  cp "${SCRIPT_DIR}/install.sh" "${INSTALL_ROOT}/install.sh"
  if [[ -f "${SCRIPT_DIR}/install.ps1" ]]; then
    cp "${SCRIPT_DIR}/install.ps1" "${INSTALL_ROOT}/install.ps1"
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

main() {
  if [[ "${1:-}" == "--uninstall" ]]; then
    perform_uninstall
    exit 0
  fi

  install_tree
  write_wrapper
  write_init
  register_profiles

  log "Installed management CLI to ${CLI_WRAPPER}"
  KANATA_TOOL_HOME="${INSTALL_ROOT}" bash "${INSTALL_ROOT}/bin/kanata-tool" setup

  [[ -f "${PACKAGE_README}" ]] && log "Installed from package in ${SCRIPT_DIR}"
  log "Installation completed"
}

main "$@"
