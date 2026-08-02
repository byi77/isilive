# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.364`.

Highlights:
- **Modernized every isiLive surface.** The shared cool blue/slate hierarchy
  now covers title chrome, actions, M+ run blocks, notices, Settings, ESC
  shortcuts, compact LFG markers, nameplates, tooltips and death alerts. The
  redundant title `BETA` label is gone while Settings retains its beta notice;
  header separators and lower run blocks share their intended bounds.
- **Polished the complete title row.** M+, H, V and all utility controls share
  one vertically centered integer anchor. Every isiLive-owned window uses a
  compact slate `×`, with red shown only on hover or press.
- **Restored coherent transparency.** Background Opacity once again governs
  the title, portal tiles, BR/BL, timer and forces surfaces live, while their
  semantic tint remains subtle.
- **Improved Stats Box readability.** Distinct per-stat colors are restored;
  German now uses `Beweg`, `Krit`, `Tempo`, `Meist`, `Versa` and `Haltb`. Those
  labels and the close-button danger colors now come from the shared locale and
  color tables, so translation and palette checks can see them.
- **All local release gates pass.** The current development tree contains 2,309
  passing deterministic scenarios, 92.52% total line coverage
  (`36,314 / 39,248`), and no production file below 80% coverage.
