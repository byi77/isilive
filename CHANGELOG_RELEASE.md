# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.433`.

Version 0.9.433: combat-safe layout changes and M+ timer recovery after reload.

<!-- highlights-reviewed-for: 0.9.433 -->

Highlights:
- **Combat-safe layout changes.** Mark-T/H visibility, size and anchors update
  after combat; hidden windows apply the latest layout when reopened.
- **M+ timer reload recovery.** Reloading during a key restores its timer,
  level, time limit and death data from live APIs. Finished runs stay cleared.
- **Mark-T/H button.** One click marks the tank (Blue Square) and the healer
  (Green Triangle); right-click clears both. A missing role is simply skipped.
- **Re-Sync in the title bar.** Re-Sync is now a small icon button between the
  V and settings buttons (M and M+ layouts) and counts down its cooldown.
- **DK helpers in isiBlightfallTracker.** Soul Reaper/Putrefy crosses, the ghoul
  reminder and horse-sound muting are configured there; isiLive keeps them off.
