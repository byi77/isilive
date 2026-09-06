# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.381`.

Highlights:
- **Hardened the group sync against out-of-range values from other players.**
  Numbers received over the addon channel are range-checked so a broken or
  hostile group member cannot publish a value that renders into everyone's
  roster and breaks the column layout. Keystones and player stats were already
  covered; the target keystone level and the DPS value had been missed. Both
  are now bounded, and out-of-range values are dropped rather than trimmed to
  the limit, so nothing invented is ever displayed.
- **Fixed the tank/healer role markers marking the wrong player during combat.**
  Clicking a role icon marks that player by name, and the macro behind it can
  only be rewritten outside combat. When a row changed occupant mid-fight — a
  death re-sorts the rows, someone swaps role, a player leaves the group — the
  button kept pointing at the previous occupant and stayed clickable for the
  rest of the pull. The marker now disappears instead of marking the wrong
  player, and comes back as soon as combat ends. World markers are unaffected.
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
- **Hardened runtime safety across several code audits, and all local release
  gates pass.** Optional instance APIs now reject missing, failing, and secret
  metadata through one shared guarded reader. Every masked-value check now runs
  through one shared, fully
  guarded helper instead of thirteen private copies, removing a crash path in
  the Group Finder queue code. The VIP Death Knight helper is covered by the
  startup guards instead of failing silently, and version strings received from
  other players are stripped of UI markup before they reach the roster tooltip.
  Twelve deterministic simulators that no pipeline had been running are now
  executed by every build, enforced by a new gate. Nothing changes on screen.
  The current development tree contains 2,337 passing deterministic scenarios,
  around 92.5% total line coverage, and no production file below 80% coverage.
