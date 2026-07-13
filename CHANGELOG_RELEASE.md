# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.345`.

Highlights:
- Consolidated manually maintained season data into one normalized manifest.
  LFG mappings, portal metadata, display data, level gates, portal-room slots,
  MDT directory selection, and the verified prepared S2 IDs now derive from the
  same dungeon records.
- Fixed account-wide dungeon portal reuse for alts through live-confirmed
  persisted unlocks and limited the level-90 tooltip gate to new Midnight dungeons.
- Kept Midnight Season 1 active; the prepared Season 2 data is not switched on
  by this release.
- Prepared manual Season 2 activation independently from optional MDT forces;
  mismatched forces data stays hidden while Blizzard dungeon progress remains available.
- Standardized the source-code license to unmodified MIT and published the
  current, explicitly unresolved provenance status of mixed-origin bundled media.
