# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.285`.

Highlights:
- Added a verified group-join fallback for the accepted-invite center notice so the portal button can still appear when Blizzard does not deliver the expected `inviteaccepted` status event.
- Split normal `/isilive help` from administrative/support commands via `/isilive admin`.
- Removed the obsolete roster column-guide setting and ignore stale saved guide data.
- Updated deterministic coverage for kick extra cooldown expiry and the new center-notice fallback.
