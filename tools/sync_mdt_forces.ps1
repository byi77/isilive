param(
  [string]$Season = "midnight_s1",
  [string]$MdtRepo = "https://github.com/Nnoggie/MythicDungeonTools",
  [switch]$NoPull
)

$ErrorActionPreference = "Stop"

function Write-Step($message) {
  Write-Host ""
  Write-Host "==> $message"
}

function Assert-Command($name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    throw "Required command '$name' was not found in PATH."
  }
  return $cmd.Source
}

# --- Locate repo root (this script lives in <repo>/tools/)
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $repoRoot

try {
  Assert-Command git | Out-Null
  Assert-Command lua | Out-Null

  $cacheDir = Join-Path $repoRoot "tools/cache"
  $mdtDir   = Join-Path $cacheDir "mdt"
  $outFile  = Join-Path $repoRoot "data/isiLive_mplus_forces.lua"

  if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir | Out-Null
  }

  if (-not (Test-Path (Join-Path $mdtDir ".git"))) {
    Write-Step "cloning MDT into $mdtDir"
    git clone --depth=1 $MdtRepo $mdtDir
    if ($LASTEXITCODE -ne 0) { throw "git clone failed ($LASTEXITCODE)" }
  } elseif (-not $NoPull) {
    Write-Step "refreshing MDT clone"
    git -C $mdtDir fetch --depth=1 origin
    if ($LASTEXITCODE -ne 0) { throw "git fetch failed ($LASTEXITCODE)" }
    git -C $mdtDir reset --hard origin/HEAD
    if ($LASTEXITCODE -ne 0) { throw "git reset failed ($LASTEXITCODE)" }
  } else {
    Write-Step "using existing MDT clone (NoPull)"
  }

  $sourceCommit = (& git -C $mdtDir rev-parse HEAD).Trim()
  if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch "^[0-9a-fA-F]{40}$") {
    throw "Could not resolve the exact MDT source commit."
  }

  $dataDir = Join-Path $repoRoot "data"
  if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir | Out-Null
  }

  Write-Step "generating $outFile"
  & lua "tools/sync_mdt_forces.lua" "--season=$Season" "--mdt=tools/cache/mdt" "--source_commit=$sourceCommit" "--out=data/isiLive_mplus_forces.lua"
  if ($LASTEXITCODE -ne 0) { throw "sync_mdt_forces.lua failed ($LASTEXITCODE)" }

  Write-Host ""
  Write-Host "[OK] MPlus forces DB updated: $outFile"
}
finally {
  Pop-Location
}
