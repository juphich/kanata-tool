#!/usr/bin/env bash
set -euo pipefail

INSTALL_ROOT="${KANATA_TOOL_HOME:-${HOME}/.local/share/kanata-tool}"
BIN_DIR="${HOME}/.local/bin"
CLI_WRAPPER="${BIN_DIR}/kanata-tool"
INIT_SCRIPT="${INSTALL_ROOT}/init.sh"
MARKER="# added by kanata-tool installer"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_SH="${BASH_SOURCE[0]}"
INSTALLER_COPY_SOURCE="${INSTALLER_SH}"
POWERSHELL_INSTALLER_COPY_SOURCE=""
SOURCE_DIR=""
PACKAGE_README=""
PRESERVE_CONFIG=0
DEV_VERSION="0.0.0-dev"
INIT_SCRIPT_SOURCE="\${HOME}/.local/share/kanata-tool/init.sh"
KANATA_TOOL_REPO="${KANATA_TOOL_REPO:-juphich/kanata-tool}"
KANATA_TOOL_RELEASE_API="${KANATA_TOOL_RELEASE_API:-https://api.github.com/repos/${KANATA_TOOL_REPO}/releases/latest}"
KANATA_TOOL_RELEASE_TAG_API_BASE="${KANATA_TOOL_RELEASE_TAG_API_BASE:-https://api.github.com/repos/${KANATA_TOOL_REPO}/releases/tags}"
BOOTSTRAP_VERSION=""
BOOTSTRAP_TMP_DIR=""

log() { printf '[install] %s\n' "$*"; }
warn() { printf '[install] %s\n' "$*" >&2; }
error_exit() { printf '[install] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --from-dir <path>    Install files from a local payload directory
  --version <version>  Download and install a specific release
  --preserve-config    Preserve existing runtime keymap during setup
  --uninstall          Remove kanata-tool and runtime files
  -h, --help           Show this help
EOF
}

require_bootstrap_command() {
  local missing=()
  for cmd in curl jq tar sha256sum; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      missing+=("${cmd}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    error_exit "Missing install requirements: ${missing[*]}"
  fi
}

bootstrap_download() {
  local url="$1"
  local destination="$2"

  curl -fsSL "${url}" -o "${destination}"
}

bootstrap_asset_url() {
  local metadata_file="$1"
  local asset_name="$2"

  jq -er --arg name "${asset_name}" '.assets[] | select(.name == $name) | .browser_download_url' "${metadata_file}"
}

bootstrap_verify_checksum() {
  local checksum_file="$1"
  local archive_name="$2"
  local archive_path="$3"
  local expected actual

  expected="$(awk -v name="${archive_name}" '$2 == name { print $1; found = 1 } END { if (!found) exit 1 }' "${checksum_file}")" || {
    error_exit "Checksum entry not found for ${archive_name}"
  }
  actual="$(sha256sum "${archive_path}" | awk '{ print $1 }')"

  if [[ "${expected}" != "${actual}" ]]; then
    error_exit "Checksum mismatch for ${archive_name}"
  fi
}

bootstrap_cleanup() {
  if [[ -n "${BOOTSTRAP_TMP_DIR}" && -d "${BOOTSTRAP_TMP_DIR}" ]]; then
    rm -rf "${BOOTSTRAP_TMP_DIR}"
  fi
}

bootstrap_source_dir() {
  local version="$1"
  local metadata_file archive_name checksum_name installer_name powershell_installer_name archive_url checksum_url installer_url powershell_installer_url archive_path checksum_path installer_path powershell_installer_path payload_dir

  require_bootstrap_command

  BOOTSTRAP_TMP_DIR="$(mktemp -d)"
  trap bootstrap_cleanup EXIT
  metadata_file="${BOOTSTRAP_TMP_DIR}/release.json"
  checksum_name="SHA256SUMS"
  installer_name="install.sh"
  powershell_installer_name="install.ps1"

  if [[ -z "${version}" ]]; then
    if [[ -n "${KANATA_TOOL_LATEST_VERSION:-}" ]]; then
      version="${KANATA_TOOL_LATEST_VERSION}"
      curl -fsSL "${KANATA_TOOL_RELEASE_TAG_API_BASE}/${version}" -o "${metadata_file}"
    else
      curl -fsSL "${KANATA_TOOL_RELEASE_API}" -o "${metadata_file}"
      version="$(jq -er '.tag_name' "${metadata_file}")"
    fi
  else
    curl -fsSL "${KANATA_TOOL_RELEASE_TAG_API_BASE}/${version}" -o "${metadata_file}"
  fi

  archive_name="kanata-tool-${version}.tar.gz"
  archive_url="$(bootstrap_asset_url "${metadata_file}" "${archive_name}")" || {
    error_exit "Release asset not found: ${archive_name}"
  }
  checksum_url="$(bootstrap_asset_url "${metadata_file}" "${checksum_name}")" || {
    error_exit "Release asset not found: ${checksum_name}"
  }
  installer_url="$(bootstrap_asset_url "${metadata_file}" "${installer_name}")" || {
    error_exit "Release asset not found: ${installer_name}"
  }
  powershell_installer_url="$(bootstrap_asset_url "${metadata_file}" "${powershell_installer_name}")" || {
    error_exit "Release asset not found: ${powershell_installer_name}"
  }

  archive_path="${BOOTSTRAP_TMP_DIR}/${archive_name}"
  checksum_path="${BOOTSTRAP_TMP_DIR}/${checksum_name}"
  installer_path="${BOOTSTRAP_TMP_DIR}/${installer_name}"
  powershell_installer_path="${BOOTSTRAP_TMP_DIR}/${powershell_installer_name}"
  log "Downloading ${archive_name}"
  bootstrap_download "${archive_url}" "${archive_path}"
  log "Downloading ${checksum_name}"
  bootstrap_download "${checksum_url}" "${checksum_path}"
  bootstrap_download "${installer_url}" "${installer_path}"
  bootstrap_download "${powershell_installer_url}" "${powershell_installer_path}"
  chmod +x "${installer_path}"
  INSTALLER_COPY_SOURCE="${installer_path}"
  POWERSHELL_INSTALLER_COPY_SOURCE="${powershell_installer_path}"
  bootstrap_verify_checksum "${checksum_path}" "${archive_name}" "${archive_path}"

  tar -xzf "${archive_path}" -C "${BOOTSTRAP_TMP_DIR}"
  payload_dir="${BOOTSTRAP_TMP_DIR}/kanata-tool-${version}"
  [[ -d "${payload_dir}" ]] || error_exit "Extracted payload not found: ${payload_dir}"
  SOURCE_DIR="${payload_dir}"
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

  return 1
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
      --version)
        [[ $# -ge 2 ]] || error_exit "--version requires a value"
        BOOTSTRAP_VERSION="$2"
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
    if [[ -n "${BOOTSTRAP_VERSION}" ]]; then
      bootstrap_source_dir "${BOOTSTRAP_VERSION}"
    else
      detect_default_source_dir || bootstrap_source_dir ""
    fi
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
  cp "${INSTALLER_COPY_SOURCE}" "${INSTALL_ROOT}/install.sh"
  if [[ -n "${POWERSHELL_INSTALLER_COPY_SOURCE}" && -f "${POWERSHELL_INSTALLER_COPY_SOURCE}" ]]; then
    cp "${POWERSHELL_INSTALLER_COPY_SOURCE}" "${INSTALL_ROOT}/install.ps1"
  elif [[ -f "${SCRIPT_DIR}/install.ps1" ]]; then
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
