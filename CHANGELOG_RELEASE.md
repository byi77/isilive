# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.369`.

Highlights:
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
- **Modernized every isiLive surface.** The shared cool blue/slate hierarchy
  now covers title chrome, actions, M+ run blocks, notices, Settings, ESC
  shortcuts, compact LFG markers, nameplates, tooltips and death alerts. The
  redundant title `BETA` label is gone while Settings retains its beta notice.
  M+, H, V and all utility controls share one vertically centered anchor, and
  every isiLive-owned window uses a compact slate `×` that turns red only on
  hover or press.
- **Hardened runtime safety across several code audits, and all local release
  gates pass.** Every masked-value check now runs through one shared, fully
  guarded helper instead of thirteen private copies, removing a crash path in
  the Group Finder queue code. The VIP Death Knight helper is covered by the
  startup guards instead of failing silently, and version strings received from
  other players are stripped of UI markup before they reach the roster tooltip.
  Twelve deterministic simulators that no pipeline had been running are now
  executed by every build, enforced by a new gate. Nothing changes on screen.
  The current development tree contains 2,328 passing deterministic scenarios,
  around 92.5% total line coverage, and no production file below 80% coverage.
