# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.353`.

Highlights:
- Hardened unit, identity, class, specialization, map, status, and role reads
  against WoW Secret Values; protected data now stays unresolved.
- Made addon-sync sends transactional and retry-safe, and prevented malformed
  or unknown payloads from establishing peer trust.
- Preserved verified pending queue-join information across informational LFG
  event noise so the join message is consumed exactly once after grouping.
- Removed the obsolete owned-keystone-link API path. Clickable links now come
  only from verified bag hyperlinks, with a safe plain-text fallback.
- **Midnight Season 2 is armed for automatic selection.** isiLive now switches
  to the Season 2 dungeon set on its own, as soon as the game reports the new
  challenge maps. Nothing changes while Season 1 is live, and no addon update
  is needed on season day.
