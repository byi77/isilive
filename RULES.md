# Rules

## Coding
- Keep processing disabled while the window is hidden.
- Keep slash command behavior backward-compatible unless explicitly changed.
- Prefer additive changes over breaking refactors.
- Support target is WoW patch `12.0+` only.
- Treat `<12.0` as unsupported/incompatible; do not add legacy compatibility code.

## Season Scope
- This addon is locked to **The War Within Season 3 (TWW S3)** dungeon/teleport data only.
- Do not merge, copy, or backport dungeon pools, map IDs, or teleport spell IDs from any other season (`TWW S1/S2`, Dragonflight, Shadowlands, etc.).
- `isiLive_season_data.lua` must only contain the active TWW S3 pool.
- Any season-data edit must be explicitly labeled as `TWW S3` in both `CHANGELOG.md` and `README.md`.
- If an external change conflicts with this scope, reject it and keep the TWW S3 mapping.

## Localization
- All user-facing text must use the localization table.
- Use English as fallback for unsupported locales.

## Performance
- Avoid work in `OnUpdate` unless strictly needed.
- Clear queues when entering standby states.

## Documentation
- Update `README.md` for every user-visible behavior change.
- Keep examples and slash commands in sync with the code.
- Keep active UI labels in docs synchronized with localization keys (for example README feature list and ARCHITECTURE ASCII sketch).
- Update `CHANGELOG.md` for every functional/code change.
- Add changelog entries with explicit date (`YYYY-MM-DD`).
- Update `ARCHITECTURE.md` when module boundaries or runtime flow changes.
- Update `USECASES.md` when functional behavior/use-case flows change.
- Keep `RELEASE.md` quality-gate commands aligned with the actual project gates.

## Validation
- Run all local quality gates before release commits:
- `stylua --check .`
- `luacheck --exclude-files ".luarocks/**" -- .`
- Lua syntax parse for all `.lua` files (`luac -p`)
- `lua tools/lua_metrics_check.lua`
- `lua tools/validate_usecases.lua`
- For behavioral fixes, add or update deterministic coverage in `tools/validate_usecases.lua`.
- If a gate fails, fix root cause and rerun the full gate set (no partial-pass release).

## Release Hygiene
- Bump version in `isiLive.toc` for functional changes.
- Validate addon loads without Lua errors after edits.

## Versioning
- Use `MAJOR.MINOR.PATCH` (SemVer-light), e.g. `0.9.1`.
- While project is pre-1.0, keep releases in `0.x.y`.
- `PATCH` bump (`0.9.1 -> 0.9.2`): bug fixes, no user-facing feature addition.
- `MINOR` bump (`0.9.2 -> 0.10.0`): new features, new commands, new UI controls, backward-compatible behavior.
- `MAJOR` bump (`0.x -> 1.0.0` or `1.x -> 2.0.0`): breaking changes or incompatible migration.
- Every functional change must update:
- `isiLive.toc` version
- `CHANGELOG.md` entry with explicit date (`YYYY-MM-DD`)
- `README.md` when user-visible behavior/commands/install changed

## Open Items
- (add your project-specific rules here)
