param(
  [string]$KanataExePath = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
$ConfigSource = Join-Path $RepoRoot "config\kanata.kbd"
$InstallDir = Join-Path $env:LOCALAPPDATA "kanata"
$BinDir = Join-Path $InstallDir "bin"
$KanataExe = Join-Path $BinDir "kanata.exe"
$ConfigDir = Join-Path $env:APPDATA "kanata"
$ConfigDest = Join-Path $ConfigDir "kanata.kbd"

function Write-Log([string]$Message) {
  Write-Host "[install] $Message"
}

if (-not (Test-Path $ConfigSource)) {
  throw "Missing config file: $ConfigSource"
}

New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null

if ($KanataExePath -and (Test-Path $KanataExePath)) {
  Copy-Item $KanataExePath $KanataExe -Force
  Write-Log "Copied kanata.exe from parameter path"
} elseif (Get-Command kanata.exe -ErrorAction SilentlyContinue) {
  $existing = (Get-Command kanata.exe).Source
  Copy-Item $existing $KanataExe -Force
  Write-Log "Copied kanata.exe from PATH"
} else {
  throw "kanata.exe not found. Provide -KanataExePath or install kanata first."
}

Copy-Item $ConfigSource $ConfigDest -Force
Write-Log "Config installed to $ConfigDest"

& $KanataExe --cfg $ConfigDest --check
if ($LASTEXITCODE -ne 0) {
  throw "Config validation failed."
}

Write-Log "Config validation succeeded"
