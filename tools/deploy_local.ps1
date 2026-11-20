# Deploys the isiLive working tree into the local WoW AddOns folder.
#
# The repo lives outside WoW (C:\Git\isilive); WoW only gets the addon files.
# Excludes come from the .pkgmeta "ignore:" list (same set as the CurseForge
# package) plus local dev artifacts. Uses robocopy /MIR, so files removed from
# the repo also disappear from AddOns. Never creates junctions or symlinks
# (Battle.net's loose-files check reacts badly to them).
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\deploy_local.ps1
#   ... -Target "D:\Games\World of Warcraft\_retail_\Interface\AddOns\isiLive"
#   ... -WhatIf      # only list what would change

[CmdletBinding()]
param(
    [string]$Target = "C:\World of Warcraft\_retail_\Interface\AddOns\isiLive",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path.TrimEnd('\')

if (-not (Test-Path (Join-Path $repo "isiLive.toc"))) {
    throw "isiLive.toc not found in $repo"
}
if ($Target.TrimEnd('\') -ieq $repo) {
    throw "Target equals the repo folder"
}
if ((Split-Path $Target -Leaf) -ne "isiLive") {
    throw "Target must end in \isiLive (got $Target)"
}

# --- excludes -------------------------------------------------------------
$ignore = @()
$inIgnore = $false
foreach ($line in Get-Content (Join-Path $repo ".pkgmeta")) {
    if ($line -match '^\S') { $inIgnore = ($line -match '^ignore:') ; continue }
    if ($inIgnore -and $line -match '^\s*-\s*(.+?)\s*$') { $ignore += $Matches[1] }
}
$ignore += @(
    ".git", ".pkgmeta", ".luarc.json", ".luarocks", "build", "node_modules",
    "CHANGELOG_RELEASE.md", "luacov.report.out", "luacov.stats.out",
    "luacheck_output.txt"
)
$ignore = $ignore | Select-Object -Unique

$xd = @(); $xf = @()
foreach ($item in $ignore) {
    $full = Join-Path $repo $item
    if ($item -notmatch '[\*\?]' -and (Test-Path $full -PathType Container)) {
        $xd += $full
    } else {
        $xf += $item
    }
}

# --- copy -----------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $Target | Out-Null
$rcArgs = @($repo, $Target, "/MIR", "/COPY:DAT", "/DCOPY:DAT", "/R:2", "/W:1",
          "/NP", "/NJH", "/NDL")
if ($xd) { $rcArgs += "/XD"; $rcArgs += $xd }
if ($xf) { $rcArgs += "/XF"; $rcArgs += $xf }
if ($WhatIf) { $rcArgs += "/L" }

& robocopy @rcArgs
$rc = $LASTEXITCODE
if ($rc -ge 8) { throw "robocopy failed (exit $rc)" }

# robocopy /MIR never purges excluded names from the target; remove leftovers
# at the top level (e.g. from a former in-place checkout).
foreach ($item in $ignore) {
    Get-ChildItem -Path $Target -Filter $item -Force -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($WhatIf) { Write-Host "would remove $($_.FullName)" }
            else { Remove-Item $_.FullName -Recurse -Force }
        }
}

if ($WhatIf) { Write-Host "[dry run] nothing changed" }
else { Write-Host "[OK] deployed $repo -> $Target" }
