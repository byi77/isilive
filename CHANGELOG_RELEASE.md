# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.293`.

Highlights:
- Suppressed Bloodlust-ready and Battle-Res-ready sound cycles after leaving the group, even if the local Mythic+ timer still reports a stale running state.
- Stopped Bloodlust-ready reminders from repeating every 60 seconds while the player is solo after leaving a group.
- Suppressed delayed queued `INSTANCE_CHAT` addon-sync dispatches after leaving an instance group, preventing repeated Blizzard "not in a group" system messages.
- Bumped the TOC and documentation version basis to `0.9.293`.
- Updated the release-gate scenario baseline to 1948 deterministic scenarios.
