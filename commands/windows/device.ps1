$ErrorActionPreference = "Stop"

$KanataExe = Join-Path $env:LOCALAPPDATA "kanata\bin\kanata.exe"
$ConfigDir = Join-Path $env:APPDATA "kanata"
$ConfigBase = Join-Path $ConfigDir "kanata.base.kbd"
$ConfigRuntime = Join-Path $ConfigDir "kanata.kbd"

function Write-Log([string]$Message) {
  Write-Host "[device] $Message"
}

if (-not (Test-Path $KanataExe)) {
  throw "kanata.exe not found: $KanataExe. Run 'kanata-tool setup' first."
}

if (-not (Test-Path $ConfigBase)) {
  throw "Base config not found: $ConfigBase. Run 'kanata-tool setup' first."
}

Copy-Item $ConfigBase $ConfigRuntime -Force
& $KanataExe --cfg $ConfigRuntime --check
if ($LASTEXITCODE -ne 0) {
  throw "Config validation failed."
}

Write-Log "Copied base config to $ConfigRuntime"
