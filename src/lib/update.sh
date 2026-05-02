#!/usr/bin/env bash

KANATA_TOOL_REPO="${KANATA_TOOL_REPO:-juphich/kanata-tool}"
KANATA_TOOL_RELEASE_API="${KANATA_TOOL_RELEASE_API:-https://api.github.com/repos/${KANATA_TOOL_REPO}/releases/latest}"
KANATA_TOOL_RELEASE_TAG_API_BASE="${KANATA_TOOL_RELEASE_TAG_API_BASE:-https://api.github.com/repos/${KANATA_TOOL_REPO}/releases/tags}"

update_log() { printf '[update] %s\n' "$*"; }

update_current_version() {
  local version_file="${KANATA_TOOL_HOME}/VERSION"
  if [[ -f "${version_file}" ]]; then
    sed -n '1p' "${version_file}"
    return 0
  fi

  printf 'unknown\n'
}

update_normalize_version() {
  local version="$1"
  version="${version#v}"
  version="${version#V}"
  printf '%s\n' "${version}"
}

update_version_core() {
  local version
  version="$(update_normalize_version "$1")"
  if [[ "${version}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    printf '%s.%s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
    return 0
  fi

  return 1
}

update_version_gt() {
  local left right left_major left_minor left_patch right_major right_minor right_patch
  left="$(update_version_core "$1")" || return 1
  right="$(update_version_core "$2")" || return 1

  IFS=. read -r left_major left_minor left_patch <<< "${left}"
  IFS=. read -r right_major right_minor right_patch <<< "${right}"

  if (( left_major > right_major )); then return 0; fi
  if (( left_major < right_major )); then return 1; fi
  if (( left_minor > right_minor )); then return 0; fi
  if (( left_minor < right_minor )); then return 1; fi
  (( left_patch > right_patch ))
}

update_version_eq() {
  local left right
  left="$(update_version_core "$1")" || return 1
  right="$(update_version_core "$2")" || return 1
  [[ "${left}" == "${right}" ]]
}

update_latest_version() {
  if [[ -n "${KANATA_TOOL_LATEST_VERSION:-}" ]]; then
    printf '%s\n' "${KANATA_TOOL_LATEST_VERSION}"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    update_log "Could not check for updates: missing requirements (need: curl jq)"
    return 1
  fi

  curl -fsSL "${KANATA_TOOL_RELEASE_API}" 2>/dev/null | jq -er '.tag_name'
}

update_require_install_requirements() {
  local missing=()
  for cmd in curl jq tar sha256sum; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      missing+=("${cmd}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    update_log "Missing update requirements: ${missing[*]}"
    return 1
  fi
}

update_release_metadata() {
  local version="$1"
  if [[ -n "${KANATA_TOOL_RELEASE_METADATA_FILE:-}" ]]; then
    cat "${KANATA_TOOL_RELEASE_METADATA_FILE}"
    return 0
  fi

  curl -fsSL "${KANATA_TOOL_RELEASE_TAG_API_BASE}/${version}" 2>/dev/null
}

update_asset_url() {
  local metadata_file="$1"
  local asset_name="$2"
  jq -er --arg name "${asset_name}" '.assets[] | select(.name == $name) | .browser_download_url' "${metadata_file}"
}

update_download() {
  local url="$1"
  local destination="$2"

  if [[ "${url}" == file://* ]]; then
    cp "${url#file://}" "${destination}"
    return 0
  fi

  curl -fsSL "${url}" -o "${destination}"
}

update_verify_checksum() {
  local checksum_file="$1"
  local archive_name="$2"
  local archive_path="$3"
  local expected actual

  expected="$(awk -v name="${archive_name}" '$2 == name { print $1; found = 1 } END { if (!found) exit 1 }' "${checksum_file}")" || {
    update_log "Checksum entry not found for ${archive_name}"
    return 1
  }
  actual="$(sha256sum "${archive_path}" | awk '{ print $1 }')"

  if [[ "${expected}" != "${actual}" ]]; then
    update_log "Checksum mismatch for ${archive_name}"
    return 1
  fi
}

update_find_installer() {
  if [[ -x "${KANATA_TOOL_INSTALLER_SH:-}" ]]; then
    printf '%s\n' "${KANATA_TOOL_INSTALLER_SH}"
    return 0
  fi

  if [[ -x "${KANATA_TOOL_HOME}/install.sh" ]]; then
    printf '%s\n' "${KANATA_TOOL_HOME}/install.sh"
    return 0
  fi

  update_log "Installer not found: ${KANATA_TOOL_HOME}/install.sh"
  return 1
}

update_install() {
  local requested_version="${1:-}" version metadata_file archive_name checksum_name tmp_dir archive_path checksum_path archive_url checksum_url payload_dir installer

  update_require_install_requirements || return 1

  if [[ -n "${requested_version}" ]]; then
    version="${requested_version}"
  else
    if ! version="$(update_latest_version)"; then
      update_log "Could not resolve latest release"
      return 1
    fi
  fi

  archive_name="kanata-tool-${version}.tar.gz"
  checksum_name="SHA256SUMS"
  tmp_dir="$(mktemp -d)"
  cleanup_update_tmp() {
    rm -rf "${tmp_dir}"
  }

  metadata_file="${tmp_dir}/release.json"
  if ! update_release_metadata "${version}" > "${metadata_file}"; then
    update_log "Could not load release metadata for ${version}"
    cleanup_update_tmp
    return 1
  fi

  if ! archive_url="$(update_asset_url "${metadata_file}" "${archive_name}")"; then
    update_log "Release asset not found: ${archive_name}"
    cleanup_update_tmp
    return 1
  fi
  if ! checksum_url="$(update_asset_url "${metadata_file}" "${checksum_name}")"; then
    update_log "Release asset not found: ${checksum_name}"
    cleanup_update_tmp
    return 1
  fi

  archive_path="${tmp_dir}/${archive_name}"
  checksum_path="${tmp_dir}/${checksum_name}"
  update_log "Downloading ${archive_name}"
  if ! update_download "${archive_url}" "${archive_path}"; then
    update_log "Could not download ${archive_name}"
    cleanup_update_tmp
    return 1
  fi
  update_log "Downloading ${checksum_name}"
  if ! update_download "${checksum_url}" "${checksum_path}"; then
    update_log "Could not download ${checksum_name}"
    cleanup_update_tmp
    return 1
  fi

  if ! update_verify_checksum "${checksum_path}" "${archive_name}" "${archive_path}"; then
    cleanup_update_tmp
    return 1
  fi

  if ! tar -xzf "${archive_path}" -C "${tmp_dir}"; then
    update_log "Could not extract ${archive_name}"
    cleanup_update_tmp
    return 1
  fi
  payload_dir="${tmp_dir}/kanata-tool-${version}"
  if [[ ! -d "${payload_dir}" ]]; then
    update_log "Extracted payload not found: ${payload_dir}"
    cleanup_update_tmp
    return 1
  fi

  if ! installer="$(update_find_installer)"; then
    cleanup_update_tmp
    return 1
  fi
  update_log "Installing ${version}"
  if ! bash "${installer}" --from-dir "${payload_dir}" --preserve-config; then
    update_log "Install failed for ${version}"
    cleanup_update_tmp
    return 1
  fi
  update_log "Updated to ${version}"
  cleanup_update_tmp
}

update_check() {
  local current latest
  current="$(update_current_version)"
  if ! latest="$(update_latest_version)"; then
    update_log "Could not check for updates: network or release API unavailable"
    return 1
  fi

  update_log "Current version: ${current}"
  update_log "Latest version:  ${latest}"

  if ! update_version_core "${current}" >/dev/null 2>&1; then
    update_log "Could not compare installed version: ${current}"
    return 1
  fi
  if ! update_version_core "${latest}" >/dev/null 2>&1; then
    update_log "Could not compare latest version: ${latest}"
    return 1
  fi

  if update_version_eq "${latest}" "${current}"; then
    update_log "Already up to date"
  elif update_version_gt "${latest}" "${current}"; then
    update_log "Update available: ${latest}"
    update_log "Run: kanata-tool update"
  else
    update_log "Installed version is newer than latest release"
  fi
}
