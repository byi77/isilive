# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.355`.

Highlights:
- **Tank and healer death alerts no longer go silent for a whole session.**
  Entering or leaving a tracked dungeon run without a keystone could leave the
  alert context stuck, so warnings stopped firing inside the dungeon — or kept
  firing out in the open world.
- **`/isilive errorlog` now really only collects isiLive errors.** The filter
  previously matched its own frames, so other addons' errors filled the log and
  pushed out isiLive's own. Foreign errors are now rejected before any stack
  trace is built, which also removes the cost during another addon's error
  storm.
- Error-log entries no longer lose their newest items after a `/reload`. The
  buffer now orders by a timestamp that survives reloads and relogs.
- **Group-finder features now work in every client language.** Three of them
  recognised text by matching German and English wording and silently did
  nothing everywhere else — hiding the bonus badge on "promotion offered" rows
  (broken even in English), finding the member section in group tooltips, and
  removing the Proving Grounds block from applicant tooltips. As part of that,
  group-bonus markers can no longer land on the listing title instead of the
  member row.
- **Midnight Season 2 is armed for automatic selection.** isiLive now switches
  to the Season 2 dungeon set on its own, as soon as the game reports the new
  challenge maps. Nothing changes while Season 1 is live, and no addon update
  is needed on season day.
