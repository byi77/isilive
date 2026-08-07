# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.371`.

Highlights:
- **Fixed the enemy-forces database, which shipped a second season's dungeons.**
  The upstream source now publishes two seasons in one folder, and the
  generator was not filtering by season, so `0.9.370` shipped a 16-dungeon
  database stamped as Season 1. The generator now filters by season and refuses
  to write an incomplete database. Every Season 1 mob value is unchanged, and
  automatic Season 2 selection was never affected.
- **isiLive now runs a reduced profile outside Mythic+.** In a raid or any
  group larger than five it switches off completely, and in the open world,
  normal, heroic, timewalking, delves, torghast, and follower dungeons it keeps
  the group display and group sync but stops the kick sync, the cooldown
  tracker, and the last-run DPS snapshot. Mythic dungeons — including a key
  dungeon before the keystone goes in — get the full feature set as before.
- **Fixed timewalking dungeons being labelled "Mythic".** The status line
  contradicted itself, and the dungeon-entry notice never appeared. Timewalking
  now has its own label in all eight languages.
- **Fixed the "you are not in a group" chat error** that could appear while in
  an automatic instance group, for example an LFG timewalking run.
- **Hardened runtime safety across several code audits, and all local release
  gates pass.** Every masked-value check now runs through one shared, fully
  guarded helper instead of thirteen private copies, removing a crash path in
  the Group Finder queue code. The VIP Death Knight helper is covered by the
  startup guards instead of failing silently, and version strings received from
  other players are stripped of UI markup before they reach the roster tooltip.
  Twelve deterministic simulators that no pipeline had been running are now
  executed by every build, enforced by a new gate. Nothing changes on screen.
  The current development tree contains 2,337 passing deterministic scenarios,
  around 92.5% total line coverage, and no production file below 80% coverage.
