$ErrorActionPreference = "Stop"

$KanataExe = Join-Path $env:LOCALAPPDATA "kanata\bin\kanata.exe"
$KanataDir = Join-Path $env:LOCALAPPDATA "kanata"
$ConfigDir = Join-Path $env:APPDATA "kanata"
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunValueName = "kanata"

function Write-Log([string]$Message) {
  Write-Host "[uninstall] $Message"
}

Get-Process -Name "kanata" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Log "Stopped running kanata processes"

if (Get-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue) {
  Remove-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
  Write-Log "Removed autostart registry entry"
}

if (Test-Path $KanataDir) {
  Remove-Item -Path $KanataDir -Recurse -Force
}

if (Test-Path $ConfigDir) {
  Remove-Item -Path $ConfigDir -Recurse -Force
}

Write-Log "Removed kanata binary and config"
