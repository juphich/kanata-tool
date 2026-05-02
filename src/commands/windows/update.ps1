$ErrorActionPreference = "Stop"

. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "lib\paths.ps1")

$Repo = if ($env:KANATA_TOOL_REPO) { $env:KANATA_TOOL_REPO } else { "juphich/kanata-tool" }
$ReleaseApi = if ($env:KANATA_TOOL_RELEASE_API) {
  $env:KANATA_TOOL_RELEASE_API
} else {
  "https://api.github.com/repos/$Repo/releases/latest"
}
$ReleaseTagApiBase = if ($env:KANATA_TOOL_RELEASE_TAG_API_BASE) {
  $env:KANATA_TOOL_RELEASE_TAG_API_BASE
} else {
  "https://api.github.com/repos/$Repo/releases/tags"
}

function Write-UpdateLog([string]$Message) {
  Write-Host "[update] $Message"
}

function Show-Usage {
  Write-Host "Usage: kanata-tool update [options]"
  Write-Host ""
  Write-Host "Options:"
  Write-Host "  --check    Check whether a newer kanata-tool release is available"
  Write-Host "  --version <version>"
  Write-Host "             Install a specific kanata-tool release"
}

function Get-CurrentVersion {
  $versionFile = Join-Path $Script:KanataToolHome "VERSION"
  if (Test-Path $versionFile) {
    return (Get-Content $versionFile -TotalCount 1)
  }

  return "unknown"
}

function Normalize-Version([string]$Version) {
  return ($Version -replace '^[vV]', '')
}

function Get-VersionCore([string]$Version) {
  $normalized = Normalize-Version $Version
  if ($normalized -match '^([0-9]+)\.([0-9]+)\.([0-9]+)') {
    return [int[]]@([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
  }

  return $null
}

function Compare-VersionCore([string]$Left, [string]$Right) {
  $leftCore = Get-VersionCore $Left
  $rightCore = Get-VersionCore $Right
  if (-not $leftCore -or -not $rightCore) {
    throw "Cannot compare versions: $Left, $Right"
  }

  for ($i = 0; $i -lt 3; $i++) {
    if ($leftCore[$i] -gt $rightCore[$i]) { return 1 }
    if ($leftCore[$i] -lt $rightCore[$i]) { return -1 }
  }

  return 0
}

function Get-LatestVersion {
  if ($env:KANATA_TOOL_LATEST_VERSION) {
    return $env:KANATA_TOOL_LATEST_VERSION
  }

  $release = Invoke-RestMethod -Uri $ReleaseApi
  return $release.tag_name
}

function Get-ReleaseMetadata([string]$Version) {
  if ($env:KANATA_TOOL_RELEASE_METADATA_FILE) {
    return (Get-Content $env:KANATA_TOOL_RELEASE_METADATA_FILE -Raw | ConvertFrom-Json)
  }

  return (Invoke-RestMethod -Uri "$ReleaseTagApiBase/$Version")
}

function Get-AssetUrl($Release, [string]$AssetName) {
  $asset = $Release.assets | Where-Object { $_.name -eq $AssetName } | Select-Object -First 1
  if (-not $asset) {
    throw "Release asset not found: $AssetName"
  }

  return $asset.browser_download_url
}

function Save-UpdateAsset([string]$Url, [string]$Destination) {
  if ($Url.StartsWith("file://")) {
    Copy-Item $Url.Substring(7) $Destination -Force
    return
  }

  Invoke-WebRequest -Uri $Url -OutFile $Destination
}

function Assert-Checksum([string]$ChecksumPath, [string]$ArchiveName, [string]$ArchivePath) {
  $entry = Get-Content $ChecksumPath |
    ForEach-Object {
      $parts = $_ -split '\s+'
      if ($parts.Count -ge 2 -and $parts[1] -eq $ArchiveName) {
        $parts[0]
      }
    } |
    Select-Object -First 1

  if (-not $entry) {
    throw "Checksum entry not found for $ArchiveName"
  }

  $actual = (Get-FileHash -Algorithm SHA256 -Path $ArchivePath).Hash.ToLowerInvariant()
  if ($entry.ToLowerInvariant() -ne $actual) {
    throw "Checksum mismatch for $ArchiveName"
  }
}

function Get-InstallerPath {
  if ($env:KANATA_TOOL_INSTALLER_PS1 -and (Test-Path $env:KANATA_TOOL_INSTALLER_PS1)) {
    return $env:KANATA_TOOL_INSTALLER_PS1
  }

  $installer = Join-Path $Script:KanataToolHome "install.ps1"
  if (Test-Path $installer) {
    return $installer
  }

  throw "Installer not found: $installer"
}

function Invoke-UpdateInstall([string]$RequestedVersion = "") {
  $version = $RequestedVersion
  if (-not $version) {
    try {
      $version = Get-LatestVersion
    } catch {
      Write-UpdateLog "Could not resolve latest release"
      exit 1
    }
  }

  $archiveName = "kanata-tool-$version.zip"
  $checksumName = "SHA256SUMS"
  $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("kanata-tool-update-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null

  try {
    try {
      $release = Get-ReleaseMetadata $version
    } catch {
      Write-UpdateLog "Could not load release metadata for $version"
      exit 1
    }

    try {
      $archiveUrl = Get-AssetUrl $release $archiveName
      $checksumUrl = Get-AssetUrl $release $checksumName
    } catch {
      Write-UpdateLog $_.Exception.Message
      exit 1
    }

    $archivePath = Join-Path $tmpRoot $archiveName
    $checksumPath = Join-Path $tmpRoot $checksumName

    Write-UpdateLog "Downloading $archiveName"
    try {
      Save-UpdateAsset $archiveUrl $archivePath
    } catch {
      Write-UpdateLog "Could not download $archiveName"
      exit 1
    }

    Write-UpdateLog "Downloading $checksumName"
    try {
      Save-UpdateAsset $checksumUrl $checksumPath
    } catch {
      Write-UpdateLog "Could not download $checksumName"
      exit 1
    }

    try {
      Assert-Checksum $checksumPath $archiveName $archivePath
    } catch {
      Write-UpdateLog $_.Exception.Message
      exit 1
    }

    try {
      Expand-Archive -Path $archivePath -DestinationPath $tmpRoot -Force
    } catch {
      Write-UpdateLog "Could not extract $archiveName"
      exit 1
    }

    $payloadDir = Join-Path $tmpRoot "kanata-tool-$version"
    if (-not (Test-Path $payloadDir)) {
      Write-UpdateLog "Extracted payload not found: $payloadDir"
      exit 1
    }

    try {
      $installer = Get-InstallerPath
    } catch {
      Write-UpdateLog $_.Exception.Message
      exit 1
    }

    Write-UpdateLog "Installing $version"
    & $installer -FromDir $payloadDir -PreserveConfig
    if (-not $? -or ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0)) {
      Write-UpdateLog "Install failed for $version"
      exit 1
    }

    Write-UpdateLog "Updated to $version"
  } finally {
    if (Test-Path $tmpRoot) {
      Remove-Item $tmpRoot -Recurse -Force
    }
  }
}

function Invoke-UpdateCheck {
  $current = Get-CurrentVersion
  try {
    $latest = Get-LatestVersion
  } catch {
    Write-UpdateLog "Could not check for updates: network or release API unavailable"
    exit 1
  }

  Write-UpdateLog "Current version: $current"
  Write-UpdateLog "Latest version:  $latest"

  if (-not (Get-VersionCore $current)) {
    Write-UpdateLog "Could not compare installed version: $current"
    exit 1
  }
  if (-not (Get-VersionCore $latest)) {
    Write-UpdateLog "Could not compare latest version: $latest"
    exit 1
  }

  $comparison = Compare-VersionCore $latest $current
  if ($comparison -eq 0) {
    Write-UpdateLog "Already up to date"
  } elseif ($comparison -gt 0) {
    Write-UpdateLog "Update available: $latest"
    Write-UpdateLog "Run: kanata-tool update"
  } else {
    Write-UpdateLog "Installed version is newer than latest release"
  }
}

if (-not $args -or $args.Count -lt 1) {
  Invoke-UpdateInstall
  exit 0
}

switch ($args[0]) {
  "--check" {
    Invoke-UpdateCheck
  }
  "--version" {
    if ($args.Count -lt 2) {
      Write-UpdateLog "--version requires a value"
      exit 1
    }
    Invoke-UpdateInstall $args[1]
  }
  "-h" {
    Show-Usage
  }
  "--help" {
    Show-Usage
  }
  "help" {
    Show-Usage
  }
  default {
    Write-UpdateLog "Unknown option: $($args[0])"
    Show-Usage
    exit 1
  }
}
