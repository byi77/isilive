# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.423`.

Version 0.9.423: The stats box matches the character sheet, and tooltips, LFG flags and settings dropdowns behave correctly.

<!-- highlights-reviewed-for: 0.9.423 -->

Highlights:
- **Stats box matches the character sheet.** Crit, Versatility, Leech, Speed and Avoidance use the same values as your character sheet, Devourer Demon Hunters see Intellect, and in keys the percentages stay visible. Player tooltips no longer show a "?? ??" language line, LFG flags appear without a new search, and settings dropdowns close with the window.
- **Safer in restricted keys.** When the game masks battle-res charges, pet spell IDs or a player's death state, isiLive no longer errors: the BR row shows "BR: --" instead of a guessed number, and the death watch skips the unreadable tick.
- **Slash commands fixed.** `/isilive settings` opens the settings panel again, and `/isilive resetui` also resets the settings and ESC panel backgrounds.
- **Reliable after raids and keys.** Leaving a raid that had shrunk to five players reopens the window again, Refresh picks up a key swapped mid-fight, and clicking Re-Sync right after a key no longer hides the RIO change.
- **Quieter when idle.** isiLive stops its per-frame and timer work while there is nothing to do, also while a group member is out of inspect range, and the first death in a key no longer builds the alert window mid-fight.
