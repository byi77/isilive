# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.386`.

<!-- highlights-reviewed-for: 0.9.386 -->

Highlights:
- **Reloading inside a Mythic+ key no longer loses the ESC-menu shortcuts.**
  They stayed gone until the next client restart. Secure buttons may not be
  rebuilt during combat, and, as it turns out, not while a key is running
  either -- so a reload in a dungeon always rebuilt the panel in a blocked
  state. The refresh was queued for later and then thrown away before it could
  ever be applied. The queue now survives what could not be applied, and the
  shortcuts come back on their own as soon as neither combat nor a key blocks
  them -- at the latest when the ESC menu is next opened.
- **Power Infusion is announced again when you receive it.** WoW 12.1 masks the
  aura fields the tracker read, and it masks them exactly where Power Infusion
  matters: inside restricted instances. A second, independent path now asks
  Blizzard directly whether you carry the buff. When the caster is readable the
  name still appears; when it is not, the message goes out without one rather
  than inventing it. Both paths share a latch, so it never arrives twice.
- **The ESC panel closes the game menu once a travel or mount shortcut fires.**
  There is no ESC press left that could cancel the hearthstone or mount cast.
  During combat lockdown the menu stays open, because hiding it is not allowed
  there.
- **Season 2 is the active season, and mob percentages are back in Mythic+.**
  They had disappeared for everyone on S2 keys: the season carried no enemy
  forces data at all, so every S2 dungeon was left without values. The bundled
  database now covers all 8 S2 dungeons with 145 mobs. Season 1 stays fully
  usable as the manual fallback -- everything except mob percentages.
- **The Mythic+ display got a round of polish.** The portal navigator no longer
  clips its outer slots, the enemy-forces nameplate sits directly on the plate
  without a surface of its own, and its refreshes are coalesced into one pass
  per 0.25 s instead of one per scrap of key progress -- a sweep that became
  markedly more expensive in 12.1.
