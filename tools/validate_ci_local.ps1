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

function Invoke-LuaRocksCommand($label, $name, [string[]]$arguments) {
  Write-Step $label

  $command = Get-Command $name -ErrorAction Stop
  $path = $command.Source
  $extension = [System.IO.Path]::GetExtension($path)

  if ([string]::IsNullOrEmpty($extension)) {
    & lua $path @arguments
  } else {
    & $path @arguments
  }

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
  $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $processInfo.FileName = "lua"
  $processInfo.Arguments = "-e `"require('$moduleName')`""
  $processInfo.UseShellExecute = $false
  $processInfo.RedirectStandardOutput = $true
  $processInfo.RedirectStandardError = $true

  $process = [System.Diagnostics.Process]::Start($processInfo)
  $process.WaitForExit()
  return $process.ExitCode -eq 0
}

function Add-ToolLuaPath {
  $toolLuaPath = (Join-Path $PSScriptRoot "?.lua")
  $currentLuaPath = [System.Environment]::GetEnvironmentVariable("LUA_PATH", "Process")
  if ([string]::IsNullOrEmpty($currentLuaPath)) {
    [System.Environment]::SetEnvironmentVariable("LUA_PATH", $toolLuaPath, "Process")
  } elseif (-not ($currentLuaPath -split ";" | Where-Object { $_ -eq $toolLuaPath })) {
    [System.Environment]::SetEnvironmentVariable("LUA_PATH", "$toolLuaPath;$currentLuaPath", "Process")
  }
}

Push-Location (Resolve-Path (Join-Path $PSScriptRoot ".."))
try {
  $styluaCachePath = Join-Path $PSScriptRoot "cache\stylua"
  if (Test-Path $styluaCachePath) {
    $env:PATH = "$styluaCachePath;$PSScriptRoot;$env:PATH"
  } else {
    $env:PATH = "$PSScriptRoot;$env:PATH"
  }

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
    Write-Warning "GitHub Actions uses Lua 5.1, local preflight runs with $luaVersion. The test runner bridges unpack/table.unpack for both versions; pure 5.1-syntax regressions (e.g. loadfile-env, integer-division //) still require a green CI run to catch."
  }

  if ($InstallLuaRocksDeps) {
    Invoke-CheckedCommand "Install LuaRocks dependency: luacheck" "luarocks install luacheck 1.2.0-1"
    Invoke-CheckedCommand "Install LuaRocks dependency: luafilesystem" "luarocks install luafilesystem 1.8.0-1"
    Invoke-CheckedCommand "Install LuaRocks dependency: luacov" "luarocks install luacov 0.15.0-1"
  }

  Initialize-LuaRocksEnvironment

  if (-not (Test-LuaModule "luacov")) {
    throw "LuaCov ('luacov') is missing. Install it with 'luarocks install luacov 0.15.0-1'."
  }
  Assert-Command "luacov" | Out-Null

  if (-not (Test-LuaModule "lfs")) {
    Add-ToolLuaPath
    if (-not (Test-LuaModule "lfs")) {
      throw "LuaFileSystem ('lfs') is missing and tools/lfs_compat.lua could not be loaded."
    }
    Write-Warning "LuaFileSystem ('lfs') is missing for local Lua; using tools/lfs_compat.lua for project checks."
  }

  Invoke-CheckedCommand "StyLua (check)" "stylua --check ."
  Invoke-LuaRocksCommand "Luacheck" "luacheck" @("--exclude-files", ".luarocks/**", "--", ".")

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
  Invoke-CheckedCommand "Locale Drift Check" "lua tools/check_locale_drift.lua"
  Invoke-CheckedCommand "Hardcoded Strings Check" "lua tools/check_hardcoded_strings.lua"
  Invoke-CheckedCommand "UI Color Tokens Check" "lua tools/check_ui_color_tokens.lua"
  Invoke-CheckedCommand "Sound Channel Check" "lua tools/check_sound_channel.lua"
  Invoke-CheckedCommand "Chat Color Safety Check" "lua tools/check_chat_color_safety.lua"
  Invoke-CheckedCommand "WoW 12.0 API Compliance Check" "lua tools/check_wow_api_compliance.lua"
  Invoke-CheckedCommand "Format String Consistency Check" "lua tools/check_format_string_consistency.lua"
  Invoke-CheckedCommand "Secret Value Guards Check" "lua tools/check_secret_value_guards.lua"
  Invoke-CheckedCommand "Addon Message Size Check" "lua tools/check_addon_message_size.lua"
  Invoke-CheckedCommand "Button Label Length Check" "lua tools/check_button_label_length.lua"
  Invoke-CheckedCommand "TOC File List Check" "lua tools/check_toc_file_list.lua"
  Invoke-CheckedCommand "Dead Locale Keys Check" "lua tools/check_dead_locale_keys.lua"
  Invoke-CheckedCommand "Settings Default Pattern Check" "lua tools/check_settings_default_pattern.lua"
  Invoke-CheckedCommand "M+ Forces DB Lifetime" "lua tools/check_mplus_db_lifetime.lua"
  Invoke-CheckedCommand "Season Intake Check" "lua tools/check_season_intake.lua"
  Invoke-CheckedCommand "Nameplate Key-Start Simulator" "lua tools/simulate_nameplate_keystart.lua all"
  Invoke-CheckedCommand "CTL Wire-Order Simulator" "lua tools/simulate_ctl_wire_order.lua"
  Invoke-CheckedCommand "SavedVariables Reload Simulator" "lua tools/simulate_savedvariables_reload.lua"
  Invoke-CheckedCommand "Key-Start Lifecycle Simulator" "lua tools/simulate_key_start_lifecycle.lua"
  Invoke-CheckedCommand "Hidden-Sync Reload Simulator" "lua tools/simulate_hidden_sync_reload.lua"
  Invoke-CheckedCommand "Raid-Party Cycle Simulator" "lua tools/simulate_raid_party_cycle.lua"
  Invoke-CheckedCommand "LFG Join Target Chain Simulator" "lua tools/simulate_lfg_join_target_chain.lua"
  Invoke-CheckedCommand "Multi-Invite Target Chain Simulator" "lua tools/simulate_multi_invite_target_chain.lua"
  Invoke-CheckedCommand "Leader-Handoff Cascade Simulator" "lua tools/simulate_leader_handoff_cascade.lua"
  Invoke-CheckedCommand "Challenge-Mode Taint Sequence Simulator" "lua tools/simulate_challenge_mode_taint_sequence.lua"
  Invoke-CheckedCommand "Keystone-Link Bag-Scan Lifecycle Simulator" "lua tools/simulate_keystone_link_bag_scan_lifecycle.lua"
  Invoke-CheckedCommand "Reload-Storm Simulator" "lua tools/simulate_reload_storm.lua"
  Invoke-CheckedCommand "Key-Completion Lifecycle Simulator" "lua tools/simulate_key_completion_lifecycle.lua"
  Invoke-CheckedCommand "Multi-Peer Convergence Simulator" "lua tools/simulate_multi_peer_convergence.lua"
  Invoke-CheckedCommand "Cross-Realm Realm-Suffix Simulator" "lua tools/simulate_cross_realm_realm_suffix.lua"
  Invoke-CheckedCommand "Version-Skew Simulator" "lua tools/simulate_version_skew.lua"
  Invoke-CheckedCommand "Combat-Lockdown Defer-and-Replay Simulator" "lua tools/simulate_combat_lockdown_settings.lua"
  Invoke-CheckedCommand "Role-Marker Macro Simulator" "lua tools/simulate_role_marker_macro.lua"
  Invoke-CheckedCommand "M+ Timer Lifecycle Simulator" "lua tools/simulate_mplus_timer_lifecycle.lua"
  Invoke-CheckedCommand "Deterministic Usecase + Rules Logic Validation" "lua tools/validate_usecases.lua"
  Remove-Item -LiteralPath "luacov.stats.out", "luacov.report.out" -ErrorAction SilentlyContinue
  Invoke-CheckedCommand "Coverage Run" "lua -lluacov tools/validate_usecases.lua"
  Invoke-LuaRocksCommand "Coverage Report" "luacov" @()
  Invoke-CheckedCommand "Coverage Summary" "lua tools/coverage_summary.lua luacov.report.out"
  Invoke-CheckedCommand "Coverage Threshold (>=80% per file)" "lua tools/coverage_below.lua 80 luacov.report.out"
  Invoke-CheckedCommand "Coverage Threshold (>=88% total)" "lua tools/coverage_total_gate.lua 88 luacov.report.out"

  Write-Host ""
  Write-Host "Local CI preflight passed."
} finally {
  Pop-Location
}
