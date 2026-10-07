# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.416`.

Version 0.9.416: Less idle and burst work in keys, raids and the open world, plus a correct talented kick cooldown.

<!-- highlights-reviewed-for: 0.9.416 -->

Highlights:
- **Talented kick cooldowns are shown correctly.** The kick column used to fall back to the untalented cooldown on every kick (for example Pummel or Counterspell with their cooldown talents); the talent reduction now stays applied.
- **A closed window costs nothing.** While the main window is hidden the roster is no longer rebuilt for every sync message or cooldown update; it renders once when you open the window.
- **Quieter group sync.** Repeated hellos from known group members no longer trigger a full state broadcast every time, and other addons' messages are ignored before any isiLive work.
- **Lighter raids and pulls.** Roster changes inside a running raid skip the party-only handlers, the killtracker only repaints when forces or pace actually change, and healers no longer re-resolve their spec on every cast.
