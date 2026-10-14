# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.431`.

Version 0.9.431: WoW Retail 12.1.5 compatibility metadata.

<!-- highlights-reviewed-for: 0.9.431 -->

Highlights:
- **WoW Retail 12.1.5.** The addon now declares TOC interface `120105`.
- **DK button warnings.** Configure Soul Reaper and Putrefy crosses in
  isiBlightfallTracker; isiLive no longer draws a second warning.
- **Ghoul and horse helpers.** The missing-ghoul reminder and Riders of the
  Apocalypse horse-sound muting are also configured in isiBlightfallTracker.
- **Settings preserved.** isiLive keeps the old implementation and saved values,
  but disables its runtime and controls to prevent duplicate effects. The tracker
  imports existing choices and the ghoul position once when isiLive is loaded.
