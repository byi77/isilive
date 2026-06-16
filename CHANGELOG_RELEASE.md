# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.322`.

Highlights:
- Native WoW text-to-speech death alerts are disabled; death-alert audio now
  uses only the bundled static WAV files.
- Tank and healer death WAVs have separate Sounds settings toggles and preview
  buttons.
- `TankDied.wav` and `HealerDied.wav` were trimmed to one spoken announcement,
  so previews and runtime alerts no longer repeat the phrase from a single
  playback.
- Repeated `Tank died` / `Healer died` role callbacks are de-duplicated before
  playing a second immediate alert.
- The shared sound spam window now drops repeated playback of the same sound
  key for 3 seconds.
- Damage-dealer deaths remain tracked for death counters and tooltips, but do
  not play audio because no bundled DPS death WAV exists.
