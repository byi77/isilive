param()

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Read-Text([string]$Path) {
  return [System.IO.File]::ReadAllText((Resolve-Path $Path).Path, $utf8NoBom)
}

function Write-Text([string]$Path, [string]$Text) {
  [System.IO.File]::WriteAllText((Resolve-Path $Path).Path, $Text, $utf8NoBom)
}

function Update-TrackedFile([string]$Path, [scriptblock]$Updater) {
  $current = Read-Text $Path
  $updated = & $Updater $current
  if ($updated -ne $current) {
    Write-Text $Path $updated
    & git add -- $Path
    if ($LASTEXITCODE -ne 0) {
      throw "git add failed for $Path"
    }
    Write-Host "synced $Path"
    return $true
  }
  return $false
}

$tocText = Read-Text "isiLive.toc"
if ($tocText -notmatch '(?m)^## Version:\s*(\S+)\s*$') {
  throw "Could not resolve addon version from isiLive.toc"
}

$version = $matches[1]
$currentDate = Get-Date -Format "yyyy-MM-dd"
$changed = $false

$changed = Update-TrackedFile "README.md" {
  param($text)
  $next = $text
  $next = $next -replace '(?m)^(Current documented baseline:\s*)`[^`]+`(\.)$', ('${1}' + '`' + $version + '`' + '${2}')
  $next = $next -replace '(?m)^(## Use Case / Logic Baseline \(v)[^)]+(\))$', ('${1}' + $version + '${2}')
  $next = $next -replace '(?m)^(Documented on\s+)`[^`]+`(\s+as runtime behavior baseline \()`[^`]+`(\) for validation checks\.)$', ('${1}' + '`' + $currentDate + '`' + '${2}' + '`' + $version + '`' + '${3}')
  return $next
} -or $changed

$changed = Update-TrackedFile "ARCHITECTURE.md" {
  param($text)
  $next = $text
  $next = $next -replace '(?m)^(Version baseline:\s*)`[^`]+`$', ('${1}' + '`' + $version + '`')
  $next = $next -replace '(?m)^(Last updated:\s*)`[^`]+`$', ('${1}' + '`' + $currentDate + '`')
  $next = $next -replace '(?m)(\| isiLive\s+v)\d+\.\d+\.\d+(\s+Open/Close CTRL-F9 \[H\]\[V\]\[M\]\[M2\]\[X\]\|)', ('${1}' + $version + '${2}')
  return $next
} -or $changed

$changed = Update-TrackedFile "USECASES.md" {
  param($text)
  $next = $text
  $next = $next -replace '(?m)^(Version baseline:\s*)`[^`]+`$', ('${1}' + '`' + $version + '`')
  $next = $next -replace '(?m)^(Last updated:\s*)`[^`]+`$', ('${1}' + '`' + $currentDate + '`')
  return $next
} -or $changed

$changed = Update-TrackedFile "isiLive_texts.lua" {
  param($text)
  $next = $text
  $next = $next -replace '(?m)^(\s*TITLE = "isiLive v)\d+\.\d+\.\d+(",)$', ('${1}' + $version + '${2}')
  return $next
} -or $changed

if ($changed) {
  Write-Host "release baseline sync complete for $version"
} else {
  Write-Host "release baseline already aligned with $version"
}
