# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.352`.

Highlights:
- Added a unified admin debug namespace, `/isilive debug <topic> [verb ...]`,
  covering runtime/queue/error/teleport/season/hearthstone debugging. Old
  commands keep working unchanged.
- Consolidated scattered UI colors into a single named-token table with a
  build gate preventing new ones from creeping back in — no visual change.
- **Midnight Season 2 is armed for automatic selection.** isiLive now switches
  to the Season 2 dungeon set on its own, as soon as the game reports the new
  challenge maps. Nothing changes while Season 1 is live, and no addon update
  is needed on season day.
