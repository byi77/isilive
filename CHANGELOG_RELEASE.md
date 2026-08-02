# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.363`.

Highlights:
- **Modernized main window.** A shared cool blue/slate design system now
  unifies title chrome, column headers, toolbar controls and action states;
  Ready Check and Countdown are visually primary while all dimensions and
  secure behavior remain unchanged. Portals, BR/BL, timer and forces now read
  as one M+ run zone; Center Notice and Portal Navigator share the same card
  chrome, with verified localized navigation labels visible again. The Stats
  Box restores a distinct fixed color per stat; Settings, ESC shortcuts,
  compact LFG markers, nameplates, tooltips and death alerts complete the same
  hierarchy without changing their data logic.
- **Polished M+ geometry.** The redundant main-title `BETA` label is gone while
  Settings retains the beta notice. Both blue header separators use identical
  8 px bounds, and actions, portals, timers and enemy forces share one right
  edge in the 500 px M+ layout.
- **Group Finder internals are now easier to maintain.** Verified listing
  resolution, bonus evaluation, and Blizzard search/applicant frame hooks have
  focused ownership with deterministic regression coverage.
- **Notice and ESC-menu composition are more focused.** Portal Navigator
  rendering and generic ESC-panel construction now live behind their existing
  compatible facades.
- **All local release gates pass.** The current development tree contains 2,306
  passing deterministic scenarios, 92.46% total line coverage
  (`36,152 / 39,102`), and no production file below 80% coverage.
