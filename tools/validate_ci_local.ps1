param(
  [switch]$InstallLuaRocksDeps
)

$ErrorActionPreference = "Stop"

function Write-Step($message) {
  Write-Host ""
  Write-Host "==> $message"
}

function Invoke-CheckedCommand($label, $command) {
  Write-Step $label
  Invoke-Expression $command
  if ($LASTEXITCODE -ne 0) {
    throw "$label failed with exit code $LASTEXITCODE"
  }
}

function Assert-Command($name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    throw "Required command '$name' was not found in PATH."
  }
  return $cmd.Source
}

function Initialize-LuaRocksEnvironment {
  $luarocksPathOutput = & luarocks path
  if ($LASTEXITCODE -ne 0) {
    throw "luarocks path failed with exit code $LASTEXITCODE"
  }

  foreach ($line in ($luarocksPathOutput -split "`r?`n")) {
    if ($line -match '^SET\s+([A-Z_]+)=(.*)$') {
      [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
    }
  }
}

function Test-LuaModule($moduleName) {
  & lua -e "require('$moduleName')"
  return $LASTEXITCODE -eq 0
}

Push-Location (Resolve-Path (Join-Path $PSScriptRoot ".."))
try {
  Assert-Command "lua" | Out-Null
  Assert-Command "stylua" | Out-Null
  Assert-Command "luacheck" | Out-Null
  Assert-Command "luarocks" | Out-Null

  Write-Step "Local toolchain"
  & lua -v
  if ($LASTEXITCODE -ne 0) {
    throw "lua -v failed with exit code $LASTEXITCODE"
  }

  $luaVersion = (& lua -e "print(_VERSION)") | Select-Object -First 1
  if ($luaVersion -ne "Lua 5.1") {
    Write-Warning "GitHub Actions uses Lua 5.1, local preflight currently runs with $luaVersion."
  }

  if ($InstallLuaRocksDeps) {
    Invoke-CheckedCommand "Install LuaRocks dependency: luacheck" "luarocks install luacheck 1.2.0-1"
    Invoke-CheckedCommand "Install LuaRocks dependency: luafilesystem" "luarocks install luafilesystem 1.8.0-1"
  }

  Initialize-LuaRocksEnvironment

  if (-not (Test-LuaModule "lfs")) {
    throw "LuaFileSystem ('lfs') is missing for local Lua. Run: luarocks install luafilesystem 1.8.0-1"
  }

  Invoke-CheckedCommand "StyLua (check)" "stylua --check ."
  Invoke-CheckedCommand "Luacheck" 'luacheck --exclude-files ".luarocks/**" -- .'

  Write-Step "Lua Syntax Check"
  $luaFiles = Get-ChildItem -Recurse -File -Filter *.lua | Where-Object {
    $_.FullName -notlike "*\.luarocks\*"
  }

  foreach ($file in $luaFiles) {
    Write-Host "Checking $($file.FullName)"
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
      $bytes = $bytes[3..($bytes.Length - 1)]
    }
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
      [System.IO.File]::WriteAllBytes($tmp, $bytes)
      & lua -e "assert(loadfile([[$tmp]]))"
      if ($LASTEXITCODE -ne 0) {
        throw "Lua syntax check failed for $($file.FullName)"
      }
    } finally {
      Remove-Item $tmp -ErrorAction SilentlyContinue
    }
  }

  $env:ISILIVE_MAX_FILE_LINES = "3200"
  $env:ISILIVE_MAX_FUNCTION_LINES = "420"
  Invoke-CheckedCommand "Lua Metrics Check" "lua tools/lua_metrics_check.lua"
  Invoke-CheckedCommand "Deterministic Usecase + Rules Logic Validation" "lua tools/validate_usecases.lua"

  Write-Host ""
  Write-Host "Local CI preflight passed."
} finally {
  Pop-Location
}
