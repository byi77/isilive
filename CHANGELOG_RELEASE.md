# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.346`.

Highlights:
- Removed the Mythic+ timer's permanent 10 Hz frame poll while keeping each
  consumed timer snapshot current through protected Blizzard API reads.
- Replaced visible full-roster timer rerenders with targeted cooldown, ready,
  Mythic+ and killtracker updates.
- Reduced combat-event allocation, periodic nameplate scans, repeated StatsBox
  and roster layout work, and disabled-log string formatting.
- Kept Midnight Season 1 active and the prepared Season 2 dataset inactive;
  optional MDT forces remain independent from manual Season 2 activation.
- Preserved the explicitly unresolved provenance status of mixed-origin bundled
  media and extended the inventory to cover bundled MP3 files.
