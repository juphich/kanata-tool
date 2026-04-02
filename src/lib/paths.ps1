$Script:KanataToolHome = if ($env:KANATA_TOOL_HOME) {
  $env:KANATA_TOOL_HOME
} else {
  Split-Path -Parent $PSScriptRoot
}

$Script:KanataToolBinDir = Join-Path $Script:KanataToolHome "bin"
$Script:KanataToolCommandsDir = Join-Path $Script:KanataToolHome "commands"
$Script:KanataToolConfigDir = Join-Path $Script:KanataToolHome "config"
$Script:KanataToolAutostartDir = Join-Path $Script:KanataToolHome "autostart"
$Script:KanataToolBundledBinDir = Join-Path $Script:KanataToolHome "bundled-bin"
$Script:KanataToolScriptsDir = Join-Path $Script:KanataToolHome "scripts"
$Script:KanataInstallRoot = Join-Path $env:LOCALAPPDATA "kanata-tool"
$Script:KanataRuntimeBinDir = Join-Path $env:LOCALAPPDATA "kanata\bin"
$Script:KanataRuntimeBin = Join-Path $Script:KanataRuntimeBinDir "kanata.exe"
$Script:KanataConfigDir = Join-Path $env:APPDATA "kanata"
$Script:KanataConfigBase = Join-Path $Script:KanataConfigDir "kanata.base.kbd"
$Script:KanataConfigRuntime = Join-Path $Script:KanataConfigDir "kanata.kbd"
$Script:KanataRunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$Script:KanataRunValueName = "kanata"
