# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.326`.

Highlights:
- The ready-check-complete `BttF_Tinkle.wav` asset is now mono 44.1 kHz
  16-bit PCM, cutting that bundled WAV roughly in half while keeping the same
  in-game sound path.
- The Battle Res fallback sound `RoosterChickenCalls.ogg` is now tracked and
  packaged, so the fallback can actually play if WoW rejects the primary
  `ChickenAlarm.ogg` asset.
- Leaving a party instance now clears stale Mythic+ timer and BR/BL
  ready-sound state, so Bloodlust-ready reminders do not continue outside the
  dungeon.
- Player-hover group-bonus tooltips now use neutral group-bonus wording
  instead of the old `isiLive Bonus` prefix.
- isiLive now targets the live WoW 12.0.7 interface only; the older 12.0.5
  TOC compatibility marker was removed.
- The active M+ killtracker row now shows the current death count directly
  behind the dungeon/key name.
- Dungeon-entry refreshes no longer fire stale Battle Res-ready or
  Bloodlust-ready alerts.
- Roster green-heart mouseovers now show the concrete class-buff details and
  include BR/BL as tooltip-only utility.
- Native WoW text-to-speech death alerts are disabled; death-alert audio now
  uses only the bundled static WAV files.
- Tank and healer death WAVs have separate Sounds settings toggles and preview
  buttons.
- `TankDied.wav` and `HealerDied.wav` were trimmed to one spoken announcement,
  so previews and runtime alerts no longer repeat the phrase from a single
  playback.
- Repeated `Tank died` / `Healer died` role callbacks are de-duplicated before
  playing a second immediate alert.
- The shared same-sound spam window is temporarily disabled for death-WAV
  diagnosis.
- Damage-dealer deaths remain tracked for death counters and tooltips, but do
  not play audio because no bundled DPS death WAV exists.
- Accepted-invite target chat now uses the same verified listing payload as the
  center notice and avoids stale duplicate dungeon lines from older queue state.
