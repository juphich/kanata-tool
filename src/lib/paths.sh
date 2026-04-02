#!/usr/bin/env bash

if [[ -n "${KANATA_TOOL_HOME:-}" ]]; then
  _kanata_tool_home="${KANATA_TOOL_HOME}"
else
  _paths_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  _kanata_tool_home="$(cd "${_paths_dir}/.." && pwd)"
fi

export KANATA_TOOL_HOME="${_kanata_tool_home}"
export KANATA_TOOL_BIN_DIR="${KANATA_TOOL_HOME}/bin"
export KANATA_TOOL_COMMANDS_DIR="${KANATA_TOOL_HOME}/commands"
export KANATA_TOOL_CONFIG_DIR="${KANATA_TOOL_HOME}/config"
export KANATA_TOOL_AUTOSTART_DIR="${KANATA_TOOL_HOME}/autostart"
export KANATA_TOOL_BUNDLED_BIN_DIR="${KANATA_TOOL_HOME}/bundled-bin"
export KANATA_TOOL_SCRIPTS_DIR="${KANATA_TOOL_HOME}/scripts"
export KANATA_RUNTIME_BIN_DIR="${HOME}/.local/bin"
export KANATA_RUNTIME_BIN="${KANATA_RUNTIME_BIN_DIR}/kanata"
export KANATA_CONFIG_DIR="${HOME}/.config/kanata"
export KANATA_CONFIG_BASE="${KANATA_CONFIG_DIR}/kanata.base.kbd"
export KANATA_CONFIG_RUNTIME="${KANATA_CONFIG_DIR}/kanata.kbd"
export KANATA_SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
export KANATA_SYSTEMD_SERVICE="${KANATA_SYSTEMD_USER_DIR}/kanata.service"
export KANATA_LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
export KANATA_LAUNCH_AGENT="${KANATA_LAUNCH_AGENTS_DIR}/com.kanata.plist"
