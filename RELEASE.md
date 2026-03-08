# Release Runbook

This is the canonical release flow for `isiKeyMPlus` (repository/tag prefix remains `isiLive_*`).

## 1) Update Version + Docs

1. Update TOC version in `isiLive.toc`:
   - `## Version: x.y.z`
2. Add a new entry at the top of `CHANGELOG.md`.
3. Update `README.md` for user-visible behavior/layout changes.
4. If season data was touched, verify docs explicitly state active `ACTIVE_SEASON_ID` and prepared-next season status (`README.md` + `CHANGELOG.md`).
5. If runtime flow or UI behavior changed, update `ARCHITECTURE.md` and `USECASES.md`.
6. If UI labels changed, verify `README.md` and `ARCHITECTURE.md` use the current button text.
7. If maintenance/runbook expectations changed, sync `WARTUNG.md` and keep `.pkgmeta` packaging ignores aligned.

## 2) Local Quality Gate

Run before committing:

```powershell
stylua --check .
luacheck --exclude-files ".luarocks/**" -- .
lua tools/lua_metrics_check.lua
lua tools/validate_rules_logic.lua
lua tools/validate_architecture_rules.lua
lua tools/validate_usecases.lua
```

Expected: lint/style/metrics/usecase/rules checks pass.

`tools/validate_rules_logic.lua` validates active contracts from `RULES_LOGIC.md` against deterministic test names.
`tools/validate_architecture_rules.lua` validates active architecture contracts from `ARCHITECTURE_RULES.md` against deterministic test names.
`tools/validate_usecases.lua` is mandatory for release gating, runs both rule validators first, and then validates 221 deterministic scenarios across 24 modules (architecture/queue/highlight/event-handlers/event-handler lifecycles/queue-flow/spell-utils/teleport/group/event-utils/locale/sync/guards/inspect/test-mode/leader-watch/refresh/commands/runtime-log/runtime-state/roster/roster-panel/status/ui).

Windows note: if metrics fail with missing LuaRocks modules (`lfs`, `luacheck.decoder`, `luacheck.parser`), set `LUA_PATH` and `LUA_CPATH` to your LuaRocks `share/lua/5.4` and `lib/lua/5.4` paths before running the metrics check.

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
git tag isiLive_release_0.9.66
git push origin isiLive_release_0.9.66
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
- Packaging ignores non-user files via `.pkgmeta` (including `.github/`, docs like `README.md`/`ARCHITECTURE.md`/`USECASES.md`/`WARTUNG.md`/`TODO_RENAME.md`, and dev-only folders `tools/` + `testmodul/`).
- If VS Code diagnostics look stale, run:
  - `Developer: Reload Window`
  - `Lua: Restart Language Server`
