# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.365`.

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
- **All local release gates pass.** The current development tree contains 2,310
  passing deterministic scenarios, 92.53% total line coverage
  (`36,312 / 39,245`), and no production file below 80% coverage.
