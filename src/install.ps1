param(
  [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallRoot = Join-Path $env:LOCALAPPDATA "kanata-tool"
$BinDir = Join-Path $InstallRoot "bin"
$Marker = "added by kanata-tool installer"

function Write-Log([string]$Message) {
  Write-Host "[install] $Message"
}

function Get-PathEntries {
  $current = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not $current) {
    return @()
  }
  return $current -split ";" | Where-Object { $_ }
}

function Set-UserPath([string[]]$Entries) {
  [Environment]::SetEnvironmentVariable("Path", ($Entries -join ";"), "User")
}

function Add-PathEntry([string]$Entry) {
  $entries = Get-PathEntries
  if ($entries -contains $Entry) {
    return
  }
  Set-UserPath ($entries + $Entry)
  Write-Log "Added $Entry to user PATH"
}

function Remove-PathEntry([string]$Entry) {
  $entries = Get-PathEntries | Where-Object { $_ -ne $Entry }
  Set-UserPath $entries
  Write-Log "Removed $Entry from user PATH"
}

function Install-Tree {
  New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
  Copy-Item (Join-Path $ScriptDir "bin") $InstallRoot -Recurse -Force
  Copy-Item (Join-Path $ScriptDir "commands") $InstallRoot -Recurse -Force
  Copy-Item (Join-Path $ScriptDir "config") $InstallRoot -Recurse -Force
  Copy-Item (Join-Path $ScriptDir "autostart") $InstallRoot -Recurse -Force
  Copy-Item (Join-Path $ScriptDir "scripts") $InstallRoot -Recurse -Force
  Copy-Item (Join-Path $ScriptDir "lib") $InstallRoot -Recurse -Force
  Copy-Item (Join-Path $ScriptDir "install.ps1") $InstallRoot -Force
  Copy-Item (Join-Path $ScriptDir "install.sh") $InstallRoot -Force
}

function Invoke-RuntimeUninstall {
  $dispatcher = Join-Path $BinDir "kanata-tool.ps1"
  if (Test-Path $dispatcher) {
    $env:KANATA_TOOL_HOME = $InstallRoot
    $env:KANATA_TOOL_UNINSTALL_RUNTIME_ONLY = "1"
    & $dispatcher uninstall
    Remove-Item Env:KANATA_TOOL_UNINSTALL_RUNTIME_ONLY -ErrorAction SilentlyContinue
  }
}

if ($Uninstall) {
  Invoke-RuntimeUninstall
  if (Test-Path $InstallRoot) {
    Remove-Item $InstallRoot -Recurse -Force
    Write-Log "Removed $InstallRoot"
  }
  Remove-PathEntry $BinDir
  exit 0
}

Install-Tree
Add-PathEntry $BinDir
$env:KANATA_TOOL_HOME = $InstallRoot
& (Join-Path $BinDir "kanata-tool.ps1") setup
Write-Log "Installation completed"
Write-Log "To use the updated PATH in the current shell, open a new PowerShell or terminal session."
Write-Log "After reopening the shell, run: kanata-tool status"
