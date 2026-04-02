param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:KANATA_TOOL_HOME = if ($env:KANATA_TOOL_HOME) {
  $env:KANATA_TOOL_HOME
} else {
  Split-Path -Parent $ScriptDir
}
$CommandsDir = Join-Path $env:KANATA_TOOL_HOME "commands"
$IsWindowsHost = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$IsMacHost = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)
$IsLinuxHost = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)

function Show-Usage {
  Write-Host "Usage: kanata-tool <command>"
  Write-Host ""
  Write-Host "Commands:"
  Write-Host "  setup      Install kanata binary/config and autostart"
  Write-Host "  uninstall  Remove kanata binary/config and autostart"
  Write-Host "  device     Reset runtime config from base config"
  Write-Host "  keymap     Edit or replace the runtime keymap"
  Write-Host "  status     Show runtime and service status"
  Write-Host "  start      Start kanata service/agent/process"
  Write-Host "  stop       Stop kanata service/agent/process"
}

if (-not $Args -or $Args.Count -lt 1) {
  Show-Usage
  exit 1
}

$Command = $Args[0]
$Rest = if ($Args.Count -gt 1) { $Args[1..($Args.Count - 1)] } else { @() }

if ($Command -in @("-h", "--help", "help")) {
  Show-Usage
  exit 0
}

if ($Command -notin @("setup", "uninstall", "device", "keymap", "status", "start", "stop")) {
  Write-Error "Unknown command: $Command"
  Show-Usage
  exit 1
}

if ($IsWindowsHost) {
  if ($Command -eq "uninstall" -and $env:KANATA_TOOL_UNINSTALL_RUNTIME_ONLY -ne "1") {
    & (Join-Path $env:KANATA_TOOL_HOME "install.ps1") -Uninstall
    exit $LASTEXITCODE
  }
  $WindowsScript = Join-Path (Join-Path $CommandsDir "windows") "$Command.ps1"
  if (-not (Test-Path $WindowsScript)) {
    throw "Command script not found: $WindowsScript"
  }
  & $WindowsScript @Rest
  exit $LASTEXITCODE
}

$unixPlatform = if ($IsMacHost) { "macos" } elseif ($IsLinuxHost) { "linux" } else { $null }
if (-not $unixPlatform) {
  throw "Unsupported platform."
}
$bash = if (Get-Command bash -ErrorAction SilentlyContinue) { "bash" } else { throw "bash not found" }
$installScript = Join-Path $env:KANATA_TOOL_HOME "install.sh"
if ($Command -eq "uninstall" -and $env:KANATA_TOOL_UNINSTALL_RUNTIME_ONLY -ne "1") {
  & $bash $installScript "--uninstall"
  exit $LASTEXITCODE
}
$UnixScript = Join-Path (Join-Path $CommandsDir $unixPlatform) "$Command.sh"
if (-not (Test-Path $UnixScript)) {
  throw "Command script not found: $UnixScript"
}

& $bash $UnixScript @Rest
exit $LASTEXITCODE
