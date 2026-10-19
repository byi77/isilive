# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.440`.

Version 0.9.440: the Bloodlust timer and all Bloodlust alerts work inside keys again.

<!-- highlights-reviewed-for: 0.9.440 -->

Highlights:
- **Bloodlust timer works in keys again.** isiLive now reads your
  Sated/Exhaustion debuff the way WoW 12.x still allows inside a key, so the
  countdown, the 10-second warning and the ready alerts appear instead of "--".
- **Bloodlust in 10 seconds.** A new voice alert announces Bloodlust 10 seconds
  before your Sated/Exhaustion runs out (own toggle, on by default).
- **Bloodlust ready, every time.** Inside a key the ready alert and its
  60-second reminder now keep playing until Bloodlust is used again, also
  with the isiLive window closed and while other debuffs cannot be read.
- **Quieter Grand Expedition Yak.** A separate VIP toggle mutes the voices of
  its two vendors.
- **Every tank and healer death is announced.** A healer dying right after the
  tank is no longer muted; the two announcements play one after the other.
