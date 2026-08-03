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

function Replace-Required(
  [string]$Text,
  [string]$Pattern,
  [string]$Replacement,
  [string]$Label
) {
  $regex = [regex]::new($Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  $count = $regex.Matches($Text).Count
  if ($count -ne 1) {
    throw "Expected exactly one $Label marker, found $count"
  }
  return $regex.Replace($Text, $Replacement, 1)
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
  $next = Replace-Required $next '^(!\[isiLive )\d+\.\d+\.\d+(\]\(https://img\.shields\.io/badge/isiLive-)\d+\.\d+\.\d+(-1E90FF\?style=for-the-badge\))$' ('${1}' + $version + '${2}' + $version + '${3}') "README badge"

  # The current-version paragraph is prose: "Version `X.Y.Z` is <what changed>".
  # Rewriting only the number here silently attributes the OLD release's
  # description to the NEW version -- that shipped once, when 0.9.366 was
  # labelled as the ESC-menu fix that actually belonged to 0.9.365, and it
  # pushed 0.9.365 out of the listed history entirely. The script cannot know
  # what the new version did, so per the No-Guess contract in AGENTS.md it
  # fails closed and asks for the sentence instead of inventing it.
  $paragraphPattern = [regex]::new('^Version `(\d+\.\d+\.\d+)` is ', [System.Text.RegularExpressions.RegexOptions]::Multiline)
  $paragraphMatch = $paragraphPattern.Match($next)
  if (-not $paragraphMatch.Success) {
    throw "Could not find the README current-version paragraph (expected a line starting with 'Version ``X.Y.Z`` is ')"
  }
  $documentedVersion = $paragraphMatch.Groups[1].Value
  if ($documentedVersion -ne $version) {
    throw @"
README current-version paragraph still describes $documentedVersion, but isiLive.toc is now $version.
Write the new leading sentence yourself, then re-run this script:

  Version ``$version`` is <what changed in $version>. Version ``$documentedVersion`` is <existing text>...

Only the badge is updated automatically; the paragraph is prose and must stay accurate.
"@
  }

  return $next
} -or $changed

$changed = Update-TrackedFile "CHANGELOG_RELEASE.md" {
  param($text)
  return Replace-Required $text '^(Current version:\s*)`\d+\.\d+\.\d+`(\.)$' ('${1}' + '`' + $version + '`' + '${2}') "release-stub version"
} -or $changed

$changed = Update-TrackedFile "docs/ARCHITECTURE.md" {
  param($text)
  $next = $text
  $next = Replace-Required $next '^(Versionsbasis:\s*)`\d+\.\d+\.\d+`$' ('${1}' + '`' + $version + '`') "architecture version"
  $next = Replace-Required $next '^(Zuletzt aktualisiert:\s*)`\d{4}-\d{2}-\d{2}`$' ('${1}' + '`' + $currentDate + '`') "architecture date"
  $next = Replace-Required $next '^(\| isiLive v)\d+\.\d+\.\d+(\s+Open/Close CTRL-F9\b)' ('${1}' + $version + '${2}') "architecture UI title"
  return $next
} -or $changed

$changed = Update-TrackedFile "docs/USECASES.md" {
  param($text)
  $next = $text
  $next = Replace-Required $next '^(Versionsbasis:\s*)`\d+\.\d+\.\d+`$' ('${1}' + '`' + $version + '`') "usecase version"
  $next = Replace-Required $next '^(Zuletzt aktualisiert:\s*)`\d{4}-\d{2}-\d{2}`$' ('${1}' + '`' + $currentDate + '`') "usecase date"
  return $next
} -or $changed

if ($changed) {
  Write-Host "release baseline sync complete for $version"
} else {
  Write-Host "release baseline already aligned with $version"
}
