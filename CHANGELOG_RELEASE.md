# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.417`.

Version 0.9.417: Mythic 0 utilities work again, the sync switch is fully honored, and less idle work while the window is closed.

<!-- highlights-reviewed-for: 0.9.417 -->

Highlights:
- **Mythic 0 support is back.** In a mythic dungeon before the key is inserted, the BR/Bloodlust display, the tank and healer death alerts and the BR/Bloodlust announces had silently stayed off since 0.9.340; they work again.
- **Sync off means off.** With group sync switched off, isiLive no longer answers other players' hellos.
- **Buttons keep their size.** With Russian or a custom font, button labels no longer shrink step by step after a long label.
- **Talented kick cooldowns are shown correctly.** The kick column used to fall back to the untalented cooldown on every kick (for example Pummel or Counterspell with their cooldown talents); the talent reduction now stays applied.
- **A closed window costs nothing.** While the main window is hidden the roster is no longer rebuilt for every sync message or cooldown update; it renders once when you open the window.
