#!/bin/sh
set -eu

log() {
  printf '[remote-install] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing required command: $1"
    exit 1
  fi
}

download() {
  url="$1"
  out="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url"
    return
  fi

  log "curl or wget is required"
  exit 1
}

PROJECT_PATH="${KANATA_GITLAB_PROJECT:-jp-env/kanata-settings}"
REF="${KANATA_REF:-main}"
PROJECT_NAME="${PROJECT_PATH##*/}"
REF_URL="$(printf '%s' "${REF}" | sed 's|/|%2F|g')"
ARCHIVE_URL="${KANATA_ARCHIVE_URL:-https://gitlab.com/${PROJECT_PATH}/-/archive/${REF_URL}/${PROJECT_NAME}-${REF}.tar.gz}"

require_cmd tar
require_cmd mktemp
require_cmd bash

TMP_DIR="$(mktemp -d)"
ARCHIVE_PATH="${TMP_DIR}/kanata-settings.tar.gz"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT INT TERM

log "Downloading ${PROJECT_PATH}@${REF}"
download "${ARCHIVE_URL}" "${ARCHIVE_PATH}"

log "Extracting archive"
tar -xzf "${ARCHIVE_PATH}" -C "${TMP_DIR}"

REPO_DIR=""
for d in "${TMP_DIR}"/*; do
  if [ -d "$d" ] && [ -f "$d/install/install.sh" ]; then
    REPO_DIR="$d"
    break
  fi
done

if [ -z "${REPO_DIR}" ]; then
  log "Could not find install/install.sh in downloaded archive"
  exit 1
fi

log "Running installer"
bash "${REPO_DIR}/install/install.sh" "$@"
