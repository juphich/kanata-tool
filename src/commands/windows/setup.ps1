param(
  [string]$KanataExePath = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "lib\paths.ps1")
$ConfigSource = Join-Path $Script:KanataToolConfigDir "windows\kanata.kbd"
$KanataVersion = if ($env:KANATA_VERSION) { $env:KANATA_VERSION } else { $null }

function Write-Log([string]$Message) {
  Write-Host "[setup] $Message"
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

  if (-not $KanataVersion) {
    $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/jtroo/kanata/releases/latest"
    $KanataVersion = $latest.tag_name
  }

  $apiUrl = "https://api.github.com/repos/jtroo/kanata/releases/tags/$KanataVersion"
  Write-Log "Downloading kanata release metadata: $KanataVersion"
  $release = Invoke-RestMethod -Uri $apiUrl
  if ($Arch -eq "x64") {
    $asset = $release.assets |
      Where-Object {
        $_.name -match 'windows.*x64.*\.zip$' -or
        $_.name -match '^kanata\.exe$' -or
        $_.name -match '^kanata_winIOv2\.exe$' -or
        $_.name -match '^kanata_wintercept_cmd_allowed\.exe$'
      } |
      Select-Object -First 1
  } else {
    $asset = $release.assets |
      Where-Object {
        $_.name -match 'windows.*arm64.*\.zip$' -or
        $_.name -match 'arm64.*\.exe$'
      } |
      Select-Object -First 1
  }

  if (-not $asset) {
    throw "No windows/$Arch asset found for $KanataVersion"
  }

  $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("kanata-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
  $zipPath = Join-Path $tmpRoot "kanata.zip"
  $extractDir = Join-Path $tmpRoot "extract"

  try {
    Write-Log ("Downloading {0}" -f $asset.browser_download_url)
    if ($asset.name -match '\.zip$') {
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
    } else {
      Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $Destination
    }
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

New-Item -ItemType Directory -Path $Script:KanataRuntimeBinDir -Force | Out-Null
New-Item -ItemType Directory -Path $Script:KanataConfigDir -Force | Out-Null
$arch = Get-Arch

if ($KanataExePath -and (Test-Path $KanataExePath)) {
  Copy-Item $KanataExePath $Script:KanataRuntimeBin -Force
  Write-Log "Copied kanata.exe from parameter path"
} else {
  Download-KanataExe -Arch $arch -Destination $Script:KanataRuntimeBin
}

Copy-Item $ConfigSource $Script:KanataConfigBase -Force
Copy-Item $Script:KanataConfigBase $Script:KanataConfigRuntime -Force
Write-Log "Config installed to $Script:KanataConfigRuntime"

& $Script:KanataRuntimeBin --cfg $Script:KanataConfigRuntime --check
if ($LASTEXITCODE -ne 0) {
  throw "Config validation failed."
}

$runCommand = "`"$Script:KanataRuntimeBin`" --cfg `"$Script:KanataConfigRuntime`""
Set-ItemProperty -Path $Script:KanataRunKey -Name $Script:KanataRunValueName -Value $runCommand
Write-Log "Registered autostart in HKCU Run"

Get-Process -Name "kanata" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process -FilePath $Script:KanataRuntimeBin -ArgumentList @("--cfg", $Script:KanataConfigRuntime) -WindowStyle Hidden
Write-Log "Started kanata process"
Write-Log "Config validation succeeded"
