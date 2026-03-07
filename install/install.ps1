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
$KanataVersion = if ($env:KANATA_VERSION) { $env:KANATA_VERSION } else { "v1.8.1" }

function Write-Log([string]$Message) {
  Write-Host "[install] $Message"
}

function Get-Arch {
  $rawArch = $env:PROCESSOR_ARCHITEW6432
  if (-not $rawArch) {
    $rawArch = $env:PROCESSOR_ARCHITECTURE
  }

  switch -Regex ($rawArch) {
    "ARM64" { return "arm64" }
    "AMD64|X86_64" { return "x64" }
    default { throw "Unsupported Windows architecture: $rawArch" }
  }
}

function Download-KanataExe {
  param(
    [Parameter(Mandatory = $true)][string]$Arch,
    [Parameter(Mandatory = $true)][string]$Destination
  )

  $apiUrl = "https://api.github.com/repos/jtroo/kanata/releases/tags/$KanataVersion"
  Write-Log "Downloading kanata release metadata: $KanataVersion"
  $release = Invoke-RestMethod -Uri $apiUrl
  $asset = $release.assets |
    Where-Object { $_.name -match "windows" -and $_.name -match $Arch -and $_.name -match "\.zip$" } |
    Select-Object -First 1

  if (-not $asset) {
    throw "No windows/$Arch zip asset found for $KanataVersion"
  }

  $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("kanata-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
  $zipPath = Join-Path $tmpRoot "kanata.zip"
  $extractDir = Join-Path $tmpRoot "extract"

  try {
    Write-Log ("Downloading {0}" -f $asset.browser_download_url)
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    $preferred = Get-ChildItem -Path $extractDir -Recurse -File -Filter "kanata.exe" | Select-Object -First 1
    if (-not $preferred) {
      $preferred = Get-ChildItem -Path $extractDir -Recurse -File -Filter "kanata*.exe" |
        Where-Object { $_.Name -notmatch "gui" } |
        Select-Object -First 1
    }
    if (-not $preferred) {
      throw "Could not find kanata executable in downloaded archive."
    }

    Copy-Item $preferred.FullName $Destination -Force
    Write-Log ("Downloaded kanata.exe for {0}" -f $Arch)
  } finally {
    if (Test-Path $tmpRoot) {
      Remove-Item -Path $tmpRoot -Recurse -Force
    }
  }
}

if (-not (Test-Path $ConfigSource)) {
  throw "Missing config file: $ConfigSource"
}

New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
$arch = Get-Arch
$BundledExe = Join-Path $RepoRoot ("bin\windows\{0}\kanata.exe" -f $arch)

if ($KanataExePath -and (Test-Path $KanataExePath)) {
  Copy-Item $KanataExePath $KanataExe -Force
  Write-Log "Copied kanata.exe from parameter path"
} elseif (Test-Path $BundledExe) {
  Copy-Item $BundledExe $KanataExe -Force
  Write-Log ("Copied bundled kanata.exe for {0}" -f $arch)
} elseif (Get-Command kanata.exe -ErrorAction SilentlyContinue) {
  $existing = (Get-Command kanata.exe).Source
  Copy-Item $existing $KanataExe -Force
  Write-Log "Copied kanata.exe from PATH"
} else {
  Download-KanataExe -Arch $arch -Destination $KanataExe
}

Copy-Item $ConfigSource $ConfigDest -Force
Write-Log "Config installed to $ConfigDest"

& $KanataExe --cfg $ConfigDest --check
if ($LASTEXITCODE -ne 0) {
  throw "Config validation failed."
}

Write-Log "Config validation succeeded"
