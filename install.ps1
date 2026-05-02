param(
  [switch]$Uninstall,
  [string]$FromDir = "",
  [switch]$PreserveConfig
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallerPath = $MyInvocation.MyCommand.Path
$SourceDir = if ($FromDir) {
  (Resolve-Path $FromDir).Path
} elseif (Test-Path (Join-Path $ScriptDir "bin")) {
  $ScriptDir
} elseif (Test-Path (Join-Path $ScriptDir "src\bin")) {
  (Resolve-Path (Join-Path $ScriptDir "src")).Path
} else {
  ""
}
$InstallRoot = Join-Path $env:LOCALAPPDATA "kanata-tool"
$BinDir = Join-Path $InstallRoot "bin"
$Marker = "added by kanata-tool installer"
$DevVersion = "0.0.0-dev"

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

function Assert-SourceItem([string]$Item) {
  if (-not $SourceDir) {
    throw "No payload directory found. Use -FromDir <path>."
  }

  $path = Join-Path $SourceDir $Item
  if (-not (Test-Path $path)) {
    throw "Missing source item: $path"
  }
}

function Install-Tree {
  @("bin", "commands", "config", "autostart", "scripts", "lib") | ForEach-Object {
    Assert-SourceItem $_
  }

  New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
  Copy-Item (Join-Path $SourceDir "bin") $InstallRoot -Recurse -Force
  Copy-Item (Join-Path $SourceDir "commands") $InstallRoot -Recurse -Force
  Copy-Item (Join-Path $SourceDir "config") $InstallRoot -Recurse -Force
  Copy-Item (Join-Path $SourceDir "autostart") $InstallRoot -Recurse -Force
  Copy-Item (Join-Path $SourceDir "scripts") $InstallRoot -Recurse -Force
  Copy-Item (Join-Path $SourceDir "lib") $InstallRoot -Recurse -Force
  Copy-Item $InstallerPath (Join-Path $InstallRoot "install.ps1") -Force
  if (Test-Path (Join-Path $ScriptDir "install.sh")) {
    Copy-Item (Join-Path $ScriptDir "install.sh") $InstallRoot -Force
  }
  $versionFile = Join-Path $SourceDir "VERSION"
  if (Test-Path $versionFile) {
    Copy-Item $versionFile $InstallRoot -Force
  } else {
    Set-Content -Path (Join-Path $InstallRoot "VERSION") -Value $DevVersion -Encoding ASCII
  }
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
if ($PreserveConfig) {
  & (Join-Path $BinDir "kanata-tool.ps1") setup -PreserveConfig
} else {
  & (Join-Path $BinDir "kanata-tool.ps1") setup
}
Write-Log "Installation completed"
Write-Log "To use the updated PATH in the current shell, open a new PowerShell or terminal session."
Write-Log "After reopening the shell, run: kanata-tool status"
