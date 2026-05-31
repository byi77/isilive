# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.291`.

Highlights:
- Added a separate default-enabled `Sound: Battle Res Ready` alert that plays the new `sounds/BattleRezReady.wav` TTS asset once when Battle Resurrection recovers from zero available charges.
- Added a separate default-enabled `Sound: Bloodlust Ready` alert that plays the new `sounds/BloodlustReady.wav` TTS asset once when the observed Bloodlust/Heroism/Time Warp exhaustion aura expires.
- Suppressed Bloodlust-ready and Battle-Res-ready TTS cycles during key-end/key-abort CD refreshes so later world or zone refreshes cannot announce stale readiness.
- Kept event-driven Bloodlust-ready and Battle-Res-ready refreshes active while the main UI is hidden, without enabling the hidden CD polling ticker.
- Fixed Bloodlust-ready expiry detection for visible in-key play by scanning `UNIT_AURA` removal payloads that no longer carry a stable `spellId`.
- Suppressed the accepted-invite/group-join Center Notice after `/reload` when the current group matches the verified reload roster mirror.
- The accepted-invite/group-join Center Notice now appends an exact `+N` from the verified LFG group title to the dungeon row when no separate key level was available.
- Bumped the TOC and documentation version basis to `0.9.291`.
- Updated the release-gate scenario baseline to 1938 deterministic scenarios.
