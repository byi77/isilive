# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.434`.

Version 0.9.434: exact-name role marking, combat-safe V/H switch and test mode.

<!-- highlights-reviewed-for: 0.9.434 -->

Highlights:
- **Exact-name role marking.** Mark-T/H targets each player by exact name and
  returns to your own target right after each marker.
- **Combat-safe layout changes.** Switching to V or H in combat hides Mark-T/H
  at once; size and anchors catch up after combat.
- **Test mode and combat.** Test mode cannot start in combat and ends when
  combat begins, leaving the window open with your real group.
- **M+ timer reload recovery.** Reloading during a key restores its timer,
  level, time limit and death data from live APIs. Finished runs stay cleared.
- **DK helpers in isiBlightfallTracker.** Soul Reaper/Putrefy crosses, the ghoul
  reminder and horse-sound muting are configured there; isiLive keeps them off.
