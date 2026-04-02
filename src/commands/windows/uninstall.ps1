$ErrorActionPreference = "Stop"

. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "lib\paths.ps1")

function Write-Log([string]$Message) {
  Write-Host "[uninstall] $Message"
}

Get-Process -Name "kanata" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Log "Stopped running kanata processes"

if (Get-ItemProperty -Path $Script:KanataRunKey -Name $Script:KanataRunValueName -ErrorAction SilentlyContinue) {
  Remove-ItemProperty -Path $Script:KanataRunKey -Name $Script:KanataRunValueName -ErrorAction SilentlyContinue
  Write-Log "Removed autostart registry entry"
}

if (Test-Path (Split-Path -Parent $Script:KanataRuntimeBinDir)) {
  Remove-Item -Path (Split-Path -Parent $Script:KanataRuntimeBinDir) -Recurse -Force
}

if (Test-Path $Script:KanataConfigDir) {
  Remove-Item -Path $Script:KanataConfigDir -Recurse -Force
}

Write-Log "Removed kanata binary and config"
