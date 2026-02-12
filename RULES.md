# Rules

## Coding
- Keep processing disabled while the window is hidden.
- Keep slash command behavior backward-compatible unless explicitly changed.
- Prefer additive changes over breaking refactors.
- Support target is WoW patch `12.0+` only.
- Treat `<12.0` as unsupported/incompatible; do not add legacy compatibility code.

## Localization
- All user-facing text must use the localization table.
- Use English as fallback for unsupported locales.

## Performance
- Avoid work in `OnUpdate` unless strictly needed.
- Clear queues when entering standby states.

## Documentation
- Update `README.md` for every user-visible behavior change.
- Keep examples and slash commands in sync with the code.
- Update `CHANGELOG.md` for every functional/code change.
- Add changelog entries with explicit date (`YYYY-MM-DD`).

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
