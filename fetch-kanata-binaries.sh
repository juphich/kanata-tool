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
    *)
      log "Unknown argument: $1"
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
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

find_asset_url() {
  local os="$1"
  local arch="$2"
  jq -r --arg os "${os}" --arg arch "${arch}" '
    .assets[]
    | select(.name | ascii_downcase | test($os))
    | select(.name | ascii_downcase | test($arch))
    | select(.name | ascii_downcase | test("\\.zip$"))
    | .browser_download_url
  ' "${RELEASE_JSON}" | head -n1
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
  local url archive entry

  url="$(find_asset_url "${os}" "${arch}")"
  if [[ -z "${url}" ]]; then
    log "No matching ${os}/${arch} asset found in ${VERSION}"
    exit 1
  fi

  archive="${TMP_DIR}/${os}-${arch}.zip"
  log "Downloading ${os}/${arch} from ${url}"
  curl -fsSL "${url}" -o "${archive}"

  entry="$(pick_entry "${archive}" "${os}" || true)"
  if [[ -z "${entry}" ]]; then
    log "Could not select a binary entry from ${archive}"
    exit 1
  fi

  mkdir -p "$(dirname "${dest}")"
  unzip -p "${archive}" "${entry}" > "${dest}"
  if [[ "${os}" != "windows" ]]; then
    chmod +x "${dest}"
  fi
  log "Installed ${os}/${arch} binary -> ${dest}"
}

fetch_one linux x64 "${OUTPUT_DIR}/bin/linux/x64/kanata"
fetch_one macos x64 "${OUTPUT_DIR}/bin/macos/x64/kanata"
fetch_one macos arm64 "${OUTPUT_DIR}/bin/macos/arm64/kanata"
fetch_one windows x64 "${OUTPUT_DIR}/bin/windows/x64/kanata.exe"
fetch_one windows arm64 "${OUTPUT_DIR}/bin/windows/arm64/kanata.exe"

log "Done (version=${VERSION})"
