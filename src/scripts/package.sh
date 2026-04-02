#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_DIR="$(cd "${SRC_DIR}/.." && pwd)"
DIST_DIR="${PROJECT_DIR}/dist"
VERSION="${1:-$(date '+%Y.%m.%d')}"
PACKAGE_NAME="kanata-tool-${VERSION}"
TMP_DIR="$(mktemp -d)"
PKG_DIR="${TMP_DIR}/${PACKAGE_NAME}"

log() { printf '[package] %s\n' "$*"; }

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${PKG_DIR}" "${DIST_DIR}"

for item in autostart bin bundled-bin commands config lib scripts install.sh install.ps1; do
  cp -R "${SRC_DIR}/${item}" "${PKG_DIR}/"
done

cp "${PROJECT_DIR}/README.md" "${PKG_DIR}/README.md"

chmod +x "${PKG_DIR}/install.sh" "${PKG_DIR}/bin/kanata-tool" "${PKG_DIR}/scripts/package.sh" "${PKG_DIR}/scripts/fetch-kanata-binaries.sh"
chmod +x "${PKG_DIR}/commands/linux/"*.sh "${PKG_DIR}/commands/macos/"*.sh

tar -czf "${DIST_DIR}/${PACKAGE_NAME}.tar.gz" -C "${TMP_DIR}" "${PACKAGE_NAME}"
if command -v zip >/dev/null 2>&1; then
  (cd "${TMP_DIR}" && zip -qr "${DIST_DIR}/${PACKAGE_NAME}.zip" "${PACKAGE_NAME}")
  (
    cd "${DIST_DIR}"
    sha256sum "${PACKAGE_NAME}.tar.gz" "${PACKAGE_NAME}.zip" > SHA256SUMS
  )
else
  (
    cd "${DIST_DIR}"
    sha256sum "${PACKAGE_NAME}.tar.gz" > SHA256SUMS
  )
fi

log "Created ${DIST_DIR}/${PACKAGE_NAME}.tar.gz"
if [[ -f "${DIST_DIR}/${PACKAGE_NAME}.zip" ]]; then
  log "Created ${DIST_DIR}/${PACKAGE_NAME}.zip"
fi
log "Created ${DIST_DIR}/SHA256SUMS"
