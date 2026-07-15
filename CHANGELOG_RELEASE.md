# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.347`.

Highlights:
- Restored accepted-invite dungeon detection for every supported Mythic+
  dungeon, including Algeth'ar Academy.
- Kept Midnight's restricted LFG group-name payload out of reusable protected
  event slots while preserving the allocation-free dispatcher hot path.
- Added deterministic coverage for the exact Academy activity-to-map mapping
  and the restricted LFG event boundary.
- Kept Midnight Season 1 active and the prepared Season 2 dataset inactive;
  optional MDT forces remain independent from manual Season 2 activation.
