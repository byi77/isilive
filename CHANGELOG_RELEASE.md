# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.420`.

Version 0.9.420: The window comes back after a raid that shrank, Refresh always reads your current key, and the RIO change shows after an early Re-Sync.

<!-- highlights-reviewed-for: 0.9.420 -->

Highlights:
- **Reliable after raids and keys.** Leaving a raid that had shrunk to five players reopens the window again, Refresh picks up a key swapped mid-fight, and clicking Re-Sync right after a key no longer hides the RIO change.
- **Quieter when idle.** isiLive stops its per-frame and timer work while there is nothing to do, and the first death in a key no longer builds the alert window mid-fight.
- **No flicker after a key.** Group members no longer briefly show as "no isiLive" when a key ends, and the group exchanges far fewer messages at that moment.
- **Fresh enemy-forces data.** Mob percentages stay available with an updated database.
- **Mythic 0 support is back.** In a mythic dungeon before the key is inserted, the BR/Bloodlust display, the tank and healer death alerts and the BR/Bloodlust announces had silently stayed off since 0.9.340; they work again.