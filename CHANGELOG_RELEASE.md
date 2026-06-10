# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.304`.

Highlights:
- Added a Sound output channel setting with `Master` as the default and optional `SFX` routing for built-in isiLive alerts.
- Kept hard-coded built-in sound playback fail-closed to `Master` unless the saved user setting explicitly selects `SFX`.
- Added deterministic coverage for sound-channel routing, Settings UI persistence, DB schema validation, and localized Sound settings.
