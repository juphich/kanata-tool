param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$KeymapArgs
)

$ErrorActionPreference = "Stop"

. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "lib\paths.ps1")
. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "lib\keymap.ps1")

function Reload-IfRunning {
  $running = Get-Process -Name "kanata" -ErrorAction SilentlyContinue
  if (-not $running) {
    Write-KeymapLog "kanata is not running; keymap updated only"
    return
  }

  $running | Stop-Process -Force
  Start-Process -FilePath $Script:KanataRuntimeBin -ArgumentList @("--cfg", $Script:KanataConfigRuntime) -WindowStyle Hidden
  Write-KeymapLog "Reloaded kanata process"
}

Ensure-KeymapRuntime

switch ($KeymapArgs.Count) {
  0 {
    Edit-KeymapRuntime
  }
  1 {
    if ($KeymapArgs[0] -eq "--print") {
      Get-Content $Script:KanataConfigRuntime
      exit 0
    }
    if ($KeymapArgs[0] -ne "--init") {
      throw "Usage: kanata-tool keymap [--init | --file <file> | --print]"
    }
    Set-KeymapFromFile $Script:KanataConfigBase
  }
  2 {
    if ($KeymapArgs[0] -ne "--file") {
      throw "Usage: kanata-tool keymap --file <file>"
    }
    if (-not (Test-Path $KeymapArgs[1])) {
      throw "File not found: $($KeymapArgs[1])"
    }
    Set-KeymapFromFile $KeymapArgs[1]
  }
  default {
    throw "Usage: kanata-tool keymap [--init | --file <file> | --print]"
  }
}

Reload-IfRunning
