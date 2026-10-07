# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.418`.

Version 0.9.418: Group members keep their isiLive status after a key, and the enemy-forces data is refreshed.

<!-- highlights-reviewed-for: 0.9.418 -->

Highlights:
- **No flicker after a key.** Group members no longer briefly show as "no isiLive" when a key ends, and the group exchanges far fewer messages at that moment.
- **Fresh enemy-forces data.** Mob percentages stay available with an updated database.
- **Mythic 0 support is back.** In a mythic dungeon before the key is inserted, the BR/Bloodlust display, the tank and healer death alerts and the BR/Bloodlust announces had silently stayed off since 0.9.340; they work again.
- **Sync off means off.** With group sync switched off, isiLive no longer answers other players' hellos.
- **Talented kick cooldowns are shown correctly.** The kick column used to fall back to the untalented cooldown on every kick (for example Pummel or Counterspell with their cooldown talents); the talent reduction now stays applied.
