# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.362`.

Highlights:
- **Maintenance release with unchanged player-facing behavior.** Existing UI,
  settings, LFG markers, notices, and demo controls keep their public behavior.
- **Group Finder internals are now easier to maintain.** Verified listing
  resolution, bonus evaluation, and Blizzard search/applicant frame hooks have
  focused ownership with deterministic regression coverage.
- **Notice and ESC-menu composition are more focused.** Portal Navigator
  rendering and generic ESC-panel construction now live behind their existing
  compatible facades.
- **All local release gates pass.** The release baseline contains 2,296 passing
  deterministic scenarios, 92.46% total line coverage, and no production file
  below 80% coverage.
