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

Tag format used by workflow:

```powershell
git tag isiLive_X.Y.Z
git push origin isiLive_X.Y.Z
```

Example:

```powershell
git tag isiLive_0.9.15
git push origin isiLive_0.9.15
```

## 5) Verify GitHub Actions

Check Actions tab:

1. `Lua Check` (quality-gate) must pass.
2. `Release` workflow should trigger on the pushed tag.

## 6) Verify CurseForge Package

After `Release` succeeds, verify on CurseForge:

1. New file exists for the release tag.
2. Version shown matches TOC version.
3. Changelog/release notes look correct.

## Notes

- CI already excludes `.luarocks/` from lint/syntax checks.
- Packaging ignores non-user files via `.pkgmeta`.
- If VS Code diagnostics look stale, run:
  - `Developer: Reload Window`
  - `Lua: Restart Language Server`
