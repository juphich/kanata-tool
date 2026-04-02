#!/usr/bin/env bash
set -euo pipefail

log() { printf '[fetch-kanata] %s\n' "$*"; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing required command: $1"
    exit 1
  fi
}

VERSION="${KANATA_VERSION:-}"
OUTPUT_DIR=""
PLATFORM=""
ARCH=""
DESTINATION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --arch)
      ARCH="$2"
      shift 2
      ;;
    --destination)
      DESTINATION="$2"
      shift 2
      ;;
    *)
      log "Unknown argument: $1"
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"
if [[ -z "${OUTPUT_DIR}" ]]; then
  OUTPUT_DIR="${REPO_ROOT}"
fi

require_cmd curl
require_cmd jq
require_cmd unzip
require_cmd mktemp

if [[ -z "${VERSION}" ]]; then
  VERSION="$(curl -fsSL "https://api.github.com/repos/jtroo/kanata/releases/latest" | jq -r '.tag_name')"
  if [[ -z "${VERSION}" || "${VERSION}" == "null" ]]; then
    log "Failed to resolve latest kanata release tag"
    exit 1
  fi
  log "Resolved latest kanata version: ${VERSION}"
fi

API_URL="https://api.github.com/repos/jtroo/kanata/releases/tags/${VERSION}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT INT TERM

RELEASE_JSON="${TMP_DIR}/release.json"
curl -fsSL "${API_URL}" -o "${RELEASE_JSON}"

list_assets() {
  jq -r '.assets[] | [.name, .browser_download_url] | @tsv' "${RELEASE_JSON}"
}

find_asset() {
  local os="$1"
  local arch="$2"
  local assets patterns pat line name url
  assets="$(list_assets)"

  case "${os}/${arch}" in
    linux/x64)
      patterns='
^kanata-linux(-binaries)?-x64.*\.zip$
^linux-binaries-x64.*\.zip$
^kanata_linux(_cmd_allowed)?_x64$
^kanata_cmd_allowed$
^kanata$
'
      ;;
    macos/x64)
      patterns='
^kanata-macos(-binaries)?-x64.*\.zip$
^macos-binaries-x64.*\.zip$
^kanata_macos_x64$
^kanata_cmd_allowed$
^kanata$
'
      ;;
    macos/arm64)
      patterns='
^kanata-macos(-binaries)?-arm64.*\.zip$
^macos-binaries-arm64.*\.zip$
^kanata_macos_arm64$
^kanata_cmd_allowed$
^kanata$
'
      ;;
    windows/x64)
      patterns='
^kanata-windows(-binaries)?-x64.*\.zip$
^windows-binaries-x64.*\.zip$
^kanata\.exe$
^kanata_winIOv2\.exe$
^kanata_wintercept_cmd_allowed\.exe$
^kanata_[^/]*\.exe$
'
      ;;
    windows/arm64)
      patterns='
^kanata-windows(-binaries)?-arm64.*\.zip$
^windows-binaries-arm64.*\.zip$
^kanata_[^/]*arm64[^/]*\.exe$
'
      ;;
    *)
      return 1
      ;;
  esac

  while IFS= read -r pat; do
    [[ -n "${pat}" ]] || continue
    while IFS=$'\t' read -r name url; do
      if printf '%s' "${name}" | tr '[:upper:]' '[:lower:]' | grep -Eq "$(printf '%s' "${pat}" | tr '[:upper:]' '[:lower:]')"; then
        printf '%s\t%s\n' "${name}" "${url}"
        return 0
      fi
    done <<< "${assets}"
  done <<< "${patterns}"

  return 1
}

pick_entry() {
  local archive="$1"
  local os="$2"
  local entries
  entries="$(unzip -Z1 "${archive}" | tr -d '\r')"

  case "${os}" in
    linux)
      while IFS= read -r pat; do
        local found
        found="$(printf '%s\n' "${entries}" | grep -E "${pat}" | head -n1 || true)"
        if [[ -n "${found}" ]]; then
          printf '%s\n' "${found}"
          return 0
        fi
      done <<'EOF'
(^|/)kanata_linux_cmd_allowed_x64$
(^|/)kanata_linux_x64$
(^|/)kanata_cmd_allowed$
(^|/)kanata$
EOF
      ;;
    macos)
      while IFS= read -r pat; do
        local found
        found="$(printf '%s\n' "${entries}" | grep -E "${pat}" | head -n1 || true)"
        if [[ -n "${found}" ]]; then
          printf '%s\n' "${found}"
          return 0
        fi
      done <<'EOF'
(^|/)kanata_macos_(arm64|x64)$
(^|/)kanata_cmd_allowed$
(^|/)kanata$
EOF
      ;;
    windows)
      while IFS= read -r pat; do
        local found
        found="$(printf '%s\n' "${entries}" | grep -E "${pat}" | head -n1 || true)"
        if [[ -n "${found}" ]]; then
          printf '%s\n' "${found}"
          return 0
        fi
      done <<'EOF'
(^|/)kanata\.exe$
(^|/)kanata_cmd_allowed\.exe$
(^|/)kanata_[^/]*\.exe$
EOF
      ;;
  esac

  return 1
}

fetch_one() {
  local os="$1"
  local arch="$2"
  local dest="$3"
  local asset name url archive entry

  asset="$(find_asset "${os}" "${arch}" || true)"
  if [[ -z "${asset}" ]]; then
    log "No matching ${os}/${arch} asset found in ${VERSION}"
    exit 1
  fi
  IFS=$'\t' read -r name url <<< "${asset}"

  mkdir -p "$(dirname "${dest}")"
  if [[ "${name}" == *.zip ]]; then
    archive="${TMP_DIR}/${os}-${arch}.zip"
    log "Downloading ${os}/${arch} archive ${name}"
    curl -fsSL "${url}" -o "${archive}"

    entry="$(pick_entry "${archive}" "${os}" || true)"
    if [[ -z "${entry}" ]]; then
      log "Could not select a binary entry from ${archive}"
      exit 1
    fi

    unzip -p "${archive}" "${entry}" > "${dest}"
  else
    log "Downloading ${os}/${arch} binary ${name}"
    curl -fsSL "${url}" -o "${dest}"
  fi
  if [[ "${os}" != "windows" ]]; then
    chmod +x "${dest}"
  fi
  log "Installed ${os}/${arch} binary -> ${dest}"
}

if [[ -n "${DESTINATION}" && ( -z "${PLATFORM}" || -z "${ARCH}" ) ]]; then
  log "--destination requires --platform and --arch"
  exit 1
fi

if [[ -n "${PLATFORM}" || -n "${ARCH}" ]]; then
  if [[ -z "${PLATFORM}" || -z "${ARCH}" ]]; then
    log "Both --platform and --arch are required together"
    exit 1
  fi

  case "${PLATFORM}/${ARCH}" in
    linux/x64)
      fetch_one linux x64 "${DESTINATION:-${OUTPUT_DIR}/bin/linux/x64/kanata}"
      ;;
    macos/x64)
      fetch_one macos x64 "${DESTINATION:-${OUTPUT_DIR}/bin/macos/x64/kanata}"
      ;;
    macos/arm64)
      fetch_one macos arm64 "${DESTINATION:-${OUTPUT_DIR}/bin/macos/arm64/kanata}"
      ;;
    windows/x64)
      fetch_one windows x64 "${DESTINATION:-${OUTPUT_DIR}/bin/windows/x64/kanata.exe}"
      ;;
    windows/arm64)
      fetch_one windows arm64 "${DESTINATION:-${OUTPUT_DIR}/bin/windows/arm64/kanata.exe}"
      ;;
    *)
      log "Unsupported platform/arch: ${PLATFORM}/${ARCH}"
      exit 1
      ;;
  esac
else
  fetch_one linux x64 "${OUTPUT_DIR}/bin/linux/x64/kanata"
  fetch_one macos x64 "${OUTPUT_DIR}/bin/macos/x64/kanata"
  fetch_one macos arm64 "${OUTPUT_DIR}/bin/macos/arm64/kanata"
  fetch_one windows x64 "${OUTPUT_DIR}/bin/windows/x64/kanata.exe"
  fetch_one windows arm64 "${OUTPUT_DIR}/bin/windows/arm64/kanata.exe"
fi

log "Done (version=${VERSION})"
