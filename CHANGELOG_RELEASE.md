# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.368`.

Highlights:
- **Fixed the missing ESC menu addon shortcuts.** On WoW 12.0 the addon panel
  could vanish entirely whenever the current character name was unavailable,
  which hid every shortcut that was enabled for the current character only.
  The shortcuts are back, and the click path still verifies everything before
  it runs.
- **Modernized every isiLive surface.** The shared cool blue/slate hierarchy
  now covers title chrome, actions, M+ run blocks, notices, Settings, ESC
  shortcuts, compact LFG markers, nameplates, tooltips and death alerts. The
  redundant title `BETA` label is gone while Settings retains its beta notice.
  M+, H, V and all utility controls share one vertically centered anchor, and
  every isiLive-owned window uses a compact slate `×` that turns red only on
  hover or press.
- **Restored coherent transparency.** Background Opacity once again governs
  the title, portal tiles, BR/BL, timer and forces surfaces live, while their
  semantic tint remains subtle.
- **Improved Stats Box readability.** Distinct per-stat colors are restored;
  German now uses `Beweg`, `Krit`, `Tempo`, `Meist`, `Versa` and `Haltb`. Those
  labels and the close-button danger colors now come from the shared locale and
  color tables, so translation and palette checks can see them.
- **Hardened runtime safety across several code audits, and all local release
  gates pass.** Every masked-value check now runs through one shared, fully
  guarded helper instead of thirteen private copies, removing a crash path in
  the Group Finder queue code. The VIP Death Knight helper is covered by the
  startup guards instead of failing silently, and version strings received from
  other players are stripped of UI markup before they reach the roster tooltip.
  Twelve deterministic simulators that no pipeline had been running are now
  executed by every build, enforced by a new gate. Nothing changes on screen.
  The current development tree contains 2,311 passing deterministic scenarios,
  around 92.5% total line coverage, and no production file below 80% coverage.
