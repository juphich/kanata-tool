$ErrorActionPreference = "Stop"

function Write-Log([string]$Message) {
  Write-Host "[stop] $Message"
}

$running = Get-Process -Name "kanata" -ErrorAction SilentlyContinue
if ($running) {
  $running | Stop-Process -Force
  Write-Log "Stopped kanata process"
} else {
  Write-Log "kanata process is not running"
}
