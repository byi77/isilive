# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.349`.

Highlights:
- **Midnight Season 2 is armed for automatic selection.** isiLive now switches
  to the Season 2 dungeon set on its own, as soon as the game reports the new
  challenge maps. Nothing changes while Season 1 is live, and no addon update
  is needed on season day.
- Added WoW `12.1.0` to the supported interface versions alongside `12.0.7`.
- Fixed the season maintenance tooling so a season that ships before its
  optional enemy-forces database no longer blocks a manual season switch.
- Moved the portal-room detection into the season data file, so a future
  portal room can be updated in one place instead of in the UI code.
