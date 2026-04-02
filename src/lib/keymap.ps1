Set-StrictMode -Version Latest

function Write-KeymapLog([string]$Message) {
  Write-Host "[keymap] $Message"
}

function Assert-KeymapSetup {
  if (-not (Test-Path $Script:KanataRuntimeBin)) {
    throw "kanata.exe not found: $Script:KanataRuntimeBin. Run 'kanata-tool setup' first."
  }

  if (-not (Test-Path $Script:KanataConfigBase)) {
    throw "Base config not found: $Script:KanataConfigBase. Run 'kanata-tool setup' first."
  }
}

function Ensure-KeymapRuntime {
  Assert-KeymapSetup
  New-Item -ItemType Directory -Path $Script:KanataConfigDir -Force | Out-Null
  if (-not (Test-Path $Script:KanataConfigRuntime)) {
    Copy-Item $Script:KanataConfigBase $Script:KanataConfigRuntime -Force
  }
}

function Test-KeymapFile([string]$Path) {
  & $Script:KanataRuntimeBin --cfg $Path --check
  if ($LASTEXITCODE -ne 0) {
    throw "Config validation failed."
  }
}

function Set-KeymapFromFile([string]$SourcePath) {
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("kanata-keymap-" + [guid]::NewGuid().ToString("N") + ".kbd")
  try {
    Copy-Item $SourcePath $tmp -Force
    Test-KeymapFile $tmp
    Move-Item $tmp $Script:KanataConfigRuntime -Force
    Write-KeymapLog "Updated keymap: $Script:KanataConfigRuntime"
  } finally {
    if (Test-Path $tmp) {
      Remove-Item $tmp -Force
    }
  }
}

function Get-KeymapEditor {
  if ($env:VISUAL) { return $env:VISUAL }
  if ($env:EDITOR) { return $env:EDITOR }
  return "notepad.exe"
}

function Edit-KeymapRuntime {
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("kanata-keymap-" + [guid]::NewGuid().ToString("N") + ".kbd")
  try {
    Copy-Item $Script:KanataConfigRuntime $tmp -Force
    $editor = Get-KeymapEditor
    Start-Process -FilePath $editor -ArgumentList @($tmp) -Wait
    Set-KeymapFromFile $tmp
  } finally {
    if (Test-Path $tmp) {
      Remove-Item $tmp -Force
    }
  }
}
