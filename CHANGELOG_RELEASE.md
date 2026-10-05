# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.413`.

Version 0.9.413: Less idle work and stronger M+ lifecycle regression coverage.

<!-- highlights-reviewed-for: 0.9.413 -->

Highlights:
- **Less work while playing solo.** Closed Settings skip item-cache refreshes, a disabled Stats Box stops collecting live stats, and the solo main window suspends inspection. Visible Settings combine item-event bursts into one Hearthstone-selector update.
- **Raid transitions stop background work.** Forces polling and inspection stop on raid entry; the forces ticker resumes on party return without discarding verified run data.
- **Stress-tested M+ lifecycle.** Ten additional deterministic scenarios cover up to 30,000-event bursts, five minutes of visible/hidden key activity, duplicate and invalid sync packets, unavailable APIs, completion/reset and group transitions. Local Lua tests do not establish the cause of the reported in-game frame spike.
