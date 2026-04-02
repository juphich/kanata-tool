$ErrorActionPreference = "Stop"

. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "lib\paths.ps1")

function Write-Log([string]$Message) {
  Write-Host "[device] $Message"
}

if (-not (Test-Path $Script:KanataRuntimeBin)) {
  throw "kanata.exe not found: $Script:KanataRuntimeBin. Run 'kanata-tool setup' first."
}

if (-not (Test-Path $Script:KanataConfigBase)) {
  throw "Base config not found: $Script:KanataConfigBase. Run 'kanata-tool setup' first."
}

Copy-Item $Script:KanataConfigBase $Script:KanataConfigRuntime -Force
& $Script:KanataRuntimeBin --cfg $Script:KanataConfigRuntime --check
if ($LASTEXITCODE -ne 0) {
  throw "Config validation failed."
}

Write-Log "Copied base config to $Script:KanataConfigRuntime"
