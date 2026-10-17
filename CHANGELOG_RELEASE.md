# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.436`.

Version 0.9.436: back-to-back death announcements and a stats box that fits long values.

<!-- highlights-reviewed-for: 0.9.436 -->

Highlights:
- **Every tank and healer death is announced.** A healer dying right after the
  tank is no longer muted; the two announcements play one after the other.
- **Stats box fits long values.** A mastery above 100% shows in full and the
  box widens instead of clipping the number or shifting the row.
- **Spec and role switches.** When a party member changes spec, isiLive
  re-inspects them at once; the role of the spec they play wins over a stale
  group role, so Mark-T/H no longer marks a healer who went damage.
- **Exact-name role marking.** Mark-T/H targets each player by exact name and
  returns to your own target right after each marker.
- **Combat-safe layout changes.** Switching to V or H in combat hides Mark-T/H
  at once; size and anchors catch up after combat.
