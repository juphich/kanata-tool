$ErrorActionPreference = "Stop"

$KanataExe = Join-Path $env:LOCALAPPDATA "kanata\bin\kanata.exe"
$Config = Join-Path $env:APPDATA "kanata\kanata.kbd"
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$ValueName = "kanata"

if (-not (Test-Path $KanataExe)) {
  throw "kanata.exe not found: $KanataExe"
}

if (-not (Test-Path $Config)) {
  throw "config not found: $Config"
}

$Command = "`"$KanataExe`" --cfg `"$Config`""
Set-ItemProperty -Path $RunKey -Name $ValueName -Value $Command
Write-Host "[autostart] Registered kanata in HKCU Run"
