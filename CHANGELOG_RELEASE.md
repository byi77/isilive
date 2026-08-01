# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.361`.

Highlights:
- **The demo simulator now follows the user's real UI layout.** It prefers a
  12 px dock on the right of the actual M+ window, uses a verified alternate
  side when the current resolution has no room, and reflows after the M+ window
  or viewport changes. It can be detached or docked again without resizing the
  M+ UI. Readable category tabs, textual statuses, a prominent full preview,
  and a separate reset replace the dense code grid.
- **The full M+ roster no longer touches the leader controls.** The lower rows
  are stacked more tightly to separate the fifth player from Ready Check and
  the countdown buttons without increasing the window height. The first demo
  start after a reload now keeps that same height instead of briefly growing.
- **Expired Mythic+ forces data now fails closed.** MDT-derived mob percentages
  disappear once their verified lifetime ends or the snapshot date cannot be
  trusted, instead of remaining visible indefinitely.
- **Transient scenario API failures no longer erase live progress.** The
  killtracker keeps its last verified forces snapshot until Blizzard returns
  readable data again.
- **Generated forces snapshots are reproducible.** Each snapshot records the
  exact 40-character MDT source commit, and the maintenance gates reject
  missing or abbreviated provenance.
