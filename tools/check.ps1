param(
  [switch]$InstallLuaRocksDeps
)

$scriptPath = Join-Path $PSScriptRoot "run_local_ci.ps1"
& $scriptPath @PSBoundParameters
