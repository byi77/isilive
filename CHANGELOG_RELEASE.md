# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.422`.

Version 0.9.422: Hardened against masked game values in keys, so the BR display, pet interrupts and death alerts keep working without errors.

<!-- highlights-reviewed-for: 0.9.422 -->

Highlights:
- **Safer in restricted keys.** When the game masks battle-res charges, pet spell IDs or a player's death state, isiLive no longer errors: the BR row shows "BR: --" instead of a guessed number, and the death watch skips the unreadable tick.
- **Slash commands fixed.** `/isilive settings` opens the settings panel again, and `/isilive resetui` also resets the settings and ESC panel backgrounds.
- **Reliable after raids and keys.** Leaving a raid that had shrunk to five players reopens the window again, Refresh picks up a key swapped mid-fight, and clicking Re-Sync right after a key no longer hides the RIO change.
- **Quieter when idle.** isiLive stops its per-frame and timer work while there is nothing to do, also while a group member is out of inspect range, and the first death in a key no longer builds the alert window mid-fight.
- **Mythic 0 support is back.** In a mythic dungeon before the key is inserted, the BR/Bloodlust display, the tank and healer death alerts and the BR/Bloodlust announces had silently stayed off since 0.9.340; they work again.