$ErrorActionPreference = "Stop"

. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "lib\paths.ps1")

function Write-Log([string]$Message) {
  Write-Host "[start] $Message"
}

if (-not (Test-Path $Script:KanataRuntimeBin)) {
  throw "kanata.exe not found: $Script:KanataRuntimeBin. Run 'kanata-tool setup' first."
}

if (-not (Test-Path $Script:KanataConfigRuntime)) {
  throw "Config not found: $Script:KanataConfigRuntime. Run 'kanata-tool setup' first."
}

$runCommand = "`"$Script:KanataRuntimeBin`" --cfg `"$Script:KanataConfigRuntime`""
Set-ItemProperty -Path $Script:KanataRunKey -Name $Script:KanataRunValueName -Value $runCommand

$existing = Get-Process -Name "kanata" -ErrorAction SilentlyContinue
if (-not $existing) {
  Start-Process -FilePath $Script:KanataRuntimeBin -ArgumentList @("--cfg", $Script:KanataConfigRuntime) -WindowStyle Hidden
  Write-Log "Started kanata process"
} else {
  Write-Log "kanata process already running"
}

Write-Log "Autostart entry is set"
