# Rules

## Coding
- Keep processing disabled while the window is hidden.
- Keep slash command behavior backward-compatible unless explicitly changed.
- Prefer additive changes over breaking refactors.
- Support target is WoW patch `12.0+` only.
- Treat `<12.0` as unsupported/incompatible; do not add legacy compatibility code.
- Keep RIO delta activation tied to delayed post-run refresh success (not immediate key-end event timing).
- Keep `CHALLENGE_MODE_COMPLETED`/`CHALLENGE_MODE_RESET` processing active while main window is hidden so post-run refresh/delta flow remains reliable.

## Season Scope
- This addon is season-open; active runtime season data is selected only via `SeasonData.ACTIVE_SEASON_ID`.
- `isiLive_season_data.lua` may contain multiple season entries (`active` + prepared future seasons), but only one season ID is active at runtime.
- Season switch rule: never switch `ACTIVE_SEASON_ID` until the target season mapping is complete (`mapToTeleport`, `displayOrder`, `shortCodesByLocale`, `challengeMapAliases`) and validated.
- Documentation rule: season-data edits must explicitly name the active season ID and prepared-next season status in `README.md` and `CHANGELOG.md`.
- Current planning baseline: `tww_s3` remains active; `midnight_s1` is prepared/inactive until concrete IDs are complete.

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
- Keep roster display format in docs synchronized with runtime (`RIO` delta prefix format `(+X)RIO`, non-negative only).
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
- `lua tools/validate_rules_logic.lua`
- `lua tools/validate_usecases.lua`
- Keep enforceable usecase/rule contracts in `RULES_LOGIC.md` with stable `RULE-ID` blocks.
- Mark only production-enforced contracts as `Status: active` and map each to exact deterministic test names.
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
