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
- Fixed in-key ready announcements to fire from the observed tracker countdown: Bloodlust-ready now sees an already-observed aura tick down to zero, and Battle-Res-ready can fire when the displayed BRes cooldown reaches zero.
- Re-rendered the ready TTS assets with a louder normalized English voice; Battle-Res-ready now uses the phonetic `Battleretz ready!` prompt.
- Routed visible combat-utility UI rescans through the same CD-tracker transition path as the ready alerts, so the displayed Battle-Res cooldown reaching zero can trigger the Battle-Res-ready TTS during the key.
- Kept the first available Battle-Res state directly after key start silent, then announced every later observed Battle-Res recovery.
- Added Bloodlust-ready reminders every 60 seconds while Bloodlust remains unused after the first ready TTS.
- Disarmed Bloodlust-ready reminders and Battle-Res-ready transitions whenever the M+ timer is no longer running, so key-end or dungeon-leave refreshes cannot start delayed ready announcements.
- Routed isiLive sound playback through the `Master` audio channel, matching DBM's configured alert channel.
- Added Play buttons beside every sound setting so users can preview each configured audio cue.
- Suppressed the accepted-invite/group-join Center Notice after `/reload` when the current group matches the verified reload roster mirror.
- The accepted-invite/group-join Center Notice now appends an exact `+N` from the verified LFG group title to the dungeon row when no separate key level was available.
- Bumped the TOC and documentation version basis to `0.9.291`.
- Updated the release-gate scenario baseline to 1942 deterministic scenarios.
