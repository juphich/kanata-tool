$ErrorActionPreference = "Stop"

$KanataExe = Join-Path $env:LOCALAPPDATA "kanata\bin\kanata.exe"
$ConfigRuntime = Join-Path $env:APPDATA "kanata\kanata.kbd"
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunValueName = "kanata"

function Write-Log([string]$Message) {
  Write-Host "[start] $Message"
}

if (-not (Test-Path $KanataExe)) {
  throw "kanata.exe not found: $KanataExe. Run 'kanata-tool setup' first."
}

if (-not (Test-Path $ConfigRuntime)) {
  throw "Config not found: $ConfigRuntime. Run 'kanata-tool setup' first."
}

$runCommand = "`"$KanataExe`" --cfg `"$ConfigRuntime`""
Set-ItemProperty -Path $RunKey -Name $RunValueName -Value $runCommand

$existing = Get-Process -Name "kanata" -ErrorAction SilentlyContinue
if (-not $existing) {
  Start-Process -FilePath $KanataExe -ArgumentList @("--cfg", $ConfigRuntime) -WindowStyle Hidden
  Write-Log "Started kanata process"
} else {
  Write-Log "kanata process already running"
}

Write-Log "Autostart entry is set"
