# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.325`.

Highlights:
- isiLive is marked compatible with WoW 12.0.5 and 12.0.7 via TOC
  interfaces `120005` and `120007`.
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
