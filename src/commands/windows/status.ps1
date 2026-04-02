$ErrorActionPreference = "Stop"

. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "lib\paths.ps1")

function Write-Status([string]$Message) {
  Write-Host "[status] $Message"
}

Write-Status "Platform: Windows"
Write-Status "kanata binary: $Script:KanataRuntimeBin"
Write-Status "base config: $Script:KanataConfigBase"
Write-Status "runtime config: $Script:KanataConfigRuntime"
Write-Status "autostart key: $Script:KanataRunKey\$Script:KanataRunValueName"

Write-Status ("binary installed: " + ($(if (Test-Path $Script:KanataRuntimeBin) { "yes" } else { "no" })))
Write-Status ("base config installed: " + ($(if (Test-Path $Script:KanataConfigBase) { "yes" } else { "no" })))
Write-Status ("runtime config installed: " + ($(if (Test-Path $Script:KanataConfigRuntime) { "yes" } else { "no" })))

$running = Get-Process -Name "kanata" -ErrorAction SilentlyContinue
Write-Status ("service running: " + ($(if ($running) { "yes" } else { "no" })))

$autostart = Get-ItemProperty -Path $Script:KanataRunKey -Name $Script:KanataRunValueName -ErrorAction SilentlyContinue
Write-Status ("autostart enabled: " + ($(if ($autostart) { "yes" } else { "no" })))
