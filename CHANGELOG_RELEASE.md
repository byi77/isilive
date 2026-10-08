# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.425`.

Version 0.9.425: roster tooltips lay out once, cache verified language lookups,
and localize key details without broken sync-debug fallback labels.

<!-- highlights-reviewed-for: 0.9.425 -->

Highlights:
- **Lighter, localized roster tooltips.** Tooltip contents are measured once per completed render. Verified player-language lookups are cached, key details follow your UI language, and missing sync-debug labels no longer show `%s`.
- **Target dungeon recognized.** Entering the dungeon your group queued for now clears the queue target and the teleport highlight, and group members on this version who already stand inside get the portal icon in the roster. Until now these checks compared two different kinds of map IDs and never matched.
- **Stats box matches the character sheet.** Crit, Versatility, Leech, Speed and Avoidance use the same values as your character sheet, Devourer Demon Hunters see Intellect, and in keys the percentages stay visible. Player tooltips no longer show a "?? ??" language line, LFG flags appear without a new search, and settings dropdowns close with the window.
- **Safer in restricted keys.** When the game masks battle-res charges, pet spell IDs or a player's death state, isiLive no longer errors: the BR row shows "BR: --" instead of a guessed number, and the death watch skips the unreadable tick.
- **Reliable after raids and keys.** Leaving a raid that had shrunk to five players reopens the window again, Refresh picks up a key swapped mid-fight, and clicking Re-Sync right after a key no longer hides the RIO change.
