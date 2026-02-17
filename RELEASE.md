# Release Runbook

This is the canonical release flow for `isiLive`.

## 1) Update Version + Changelog

1. Update TOC version in `isiLive.toc`:
   - `## Version: x.y.z`
2. Add a new entry at the top of `CHANGELOG.md`.

## 2) Local Quality Gate

Run before committing:

```powershell
stylua .
luacheck .
```

Expected: `0 warnings / 0 errors`.

## 3) Commit + Push

```powershell
git add -A
git commit -m "Bump version to x.y.z"
git push origin main
```

## 4) Create Release Tag

Stable tag format used by `Release` workflow:

```powershell
git tag isiLive_release_X.Y.Z
git push origin isiLive_release_X.Y.Z
```

Pre-release tag formats used by `Pre-Release (Alpha/Beta)` workflow:

```powershell
git tag isiLive_alpha_X.Y.Z
git push origin isiLive_alpha_X.Y.Z
git tag isiLive_beta_X.Y.Z
git push origin isiLive_beta_X.Y.Z
```

Example:

```powershell
git tag isiLive_release_0.9.29
git push origin isiLive_release_0.9.29
```

## 5) Verify GitHub Actions

Check Actions tab:

1. `Lua Check` (quality-gate) must pass.
2. `Release` workflow should trigger only for `isiLive_release_*`.
3. `Pre-Release (Alpha/Beta)` should trigger only for `isiLive_alpha_*` / `isiLive_beta_*`.

## 6) Verify CurseForge Package

After `Release` succeeds, verify on CurseForge:

1. New file exists for the release tag.
2. Version shown matches TOC version.
3. Changelog/release notes look correct.

## 7) Wago Publish

- No automated Wago publish workflow is configured in this repository.
- Publish/update on Wago manually after CurseForge/GitHub release is confirmed.

## Notes

- CI already excludes `.luarocks/` from lint/syntax checks.
- Packaging ignores non-user files via `.pkgmeta`.
- If VS Code diagnostics look stale, run:
  - `Developer: Reload Window`
  - `Lua: Restart Language Server`
