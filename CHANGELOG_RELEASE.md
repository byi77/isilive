# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.435`.

Version 0.9.435: roster follows party spec and role switches.

<!-- highlights-reviewed-for: 0.9.435 -->

Highlights:
- **Spec and role switches.** When a party member changes spec, isiLive
  re-inspects them at once; the role of the spec they play wins over a stale
  group role, so Mark-T/H no longer marks a healer who went damage.
- **Exact-name role marking.** Mark-T/H targets each player by exact name and
  returns to your own target right after each marker.
- **Combat-safe layout changes.** Switching to V or H in combat hides Mark-T/H
  at once; size and anchors catch up after combat.
- **Test mode and combat.** Test mode cannot start in combat and ends when
  combat begins, leaving the window open with your real group.
- **M+ timer reload recovery.** Reloading during a key restores its timer,
  level, time limit and death data from live APIs. Finished runs stay cleared.
