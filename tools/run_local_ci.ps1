param(
  [switch]$InstallLuaRocksDeps
)

$scriptPath = Join-Path $PSScriptRoot "validate_ci_local.ps1"
& $scriptPath @PSBoundParameters
