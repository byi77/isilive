param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("release", "pre-release")]
  [string]$Mode
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
  throw "Blocked: $Message"
}

function Test-RepoTagExists([string]$Tag) {
  if ($env:CHECK_TAG_EXISTS -and $env:CHECK_TAG_EXISTS -ne "true") {
    return
  }

  if ([string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
    Fail "missing GITHUB_TOKEN for manual tag validation"
  }
  if ([string]::IsNullOrWhiteSpace($env:GITHUB_REPOSITORY)) {
    Fail "missing GITHUB_REPOSITORY for manual tag validation"
  }

  $tagUrl = "https://api.github.com/repos/$($env:GITHUB_REPOSITORY)/git/ref/tags/$Tag"
  try {
    Invoke-WebRequest -Uri $tagUrl -Headers @{
      Authorization = "Bearer $($env:GITHUB_TOKEN)"
      Accept        = "application/vnd.github+json"
    } -Method Get | Out-Null
  } catch {
    Fail "manual release_tag does not exist in repo ($Tag)"
  }
}

function Assert-ReleaseTrigger {
  switch ($env:EVENT_NAME) {
    "push" {
      if ($env:REF -notlike "refs/tags/isiLive_release_*") {
        Fail "only refs/tags/isiLive_release_* may trigger release"
      }
    }
    "workflow_dispatch" {
      if ($env:MANUAL_CONFIRM -ne "true") {
        Fail "confirm_release must be true for manual release"
      }

      if ($env:MANUAL_TAG -notlike "isiLive_release_*") {
        Fail "release_tag must start with isiLive_release_"
      }

      Test-RepoTagExists -Tag $env:MANUAL_TAG
    }
    default {
      Fail "unsupported event $($env:EVENT_NAME)"
    }
  }
}

function Assert-PreReleaseTrigger {
  switch ($env:EVENT_NAME) {
    "push" {
      if ($env:REF -notlike "refs/tags/isiLive_alpha_*" -and $env:REF -notlike "refs/tags/isiLive_beta_*") {
        Fail "only refs/tags/isiLive_alpha_* or refs/tags/isiLive_beta_* may trigger pre-release"
      }
    }
    "workflow_dispatch" {
      if ($env:MANUAL_CONFIRM -ne "true") {
        Fail "confirm_release must be true for manual pre-release"
      }

      switch ($env:MANUAL_CHANNEL) {
        "alpha" {
          if ($env:MANUAL_TAG -notlike "isiLive_alpha_*") {
            Fail "channel alpha requires tag prefix isiLive_alpha_"
          }
        }
        "beta" {
          if ($env:MANUAL_TAG -notlike "isiLive_beta_*") {
            Fail "channel beta requires tag prefix isiLive_beta_"
          }
        }
        default {
          Fail "unknown channel $($env:MANUAL_CHANNEL)"
        }
      }

      Test-RepoTagExists -Tag $env:MANUAL_TAG
    }
    default {
      Fail "unsupported event $($env:EVENT_NAME)"
    }
  }
}

if ([string]::IsNullOrWhiteSpace($env:EVENT_NAME)) {
  Fail "missing EVENT_NAME"
}

switch ($Mode) {
  "release" { Assert-ReleaseTrigger }
  "pre-release" { Assert-PreReleaseTrigger }
}
