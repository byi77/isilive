# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.296`.

Highlights:
- Added GitHub Release ZIP publishing for WowUp Hub with the required top-level `isiLive/` folder.
- Kept Wago publishing manual while preserving CurseForge and WowUp as the automated stable release targets.
- Replaced the legacy CurseForge packager trigger with a direct upload of the already-built release ZIP.
- Restored stable releases to tag-push-only triggering so GitHub Actions lists release runs under `isiLive_release_*`.
- Bumped the TOC and documentation version basis to `0.9.296`.
- Updated the release-gate scenario baseline to 1938 deterministic scenarios.
