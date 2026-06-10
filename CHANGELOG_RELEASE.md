# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.305`.

Highlights:
- Fixed ESC Addons shortcuts for addons that Blizzard reports as character-scoped enabled (`Some` / state `1`) after isiLive verifies the current character.
- Kept global `Some` enable-state values fail-closed when no concrete current-character query is available.
- Added deterministic coverage for character-scoped ESC Addons shortcut visibility and slash dispatch.
