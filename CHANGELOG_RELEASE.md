# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.360`.

Highlights:
- **Expired Mythic+ forces data now fails closed.** MDT-derived mob percentages
  disappear once their verified lifetime ends or the snapshot date cannot be
  trusted, instead of remaining visible indefinitely.
- **Transient scenario API failures no longer erase live progress.** The
  killtracker keeps its last verified forces snapshot until Blizzard returns
  readable data again.
- **Generated forces snapshots are reproducible.** Each snapshot records the
  exact 40-character MDT source commit, and the maintenance gates reject
  missing or abbreviated provenance.
- **Coverage failures can no longer hide behind warnings.** Local and GitHub
  checks now fail when LuaCov cannot read a referenced source.
- **Sound ownership is clearer and smaller.** Static sound definitions now live
  in a dedicated registry while playback behavior remains unchanged.
