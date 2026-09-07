# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.387`.

<!-- highlights-reviewed-for: 0.9.387 -->

Highlights:
- **Power Infusion is announced exactly once when you receive it.** Your own
  client sees the buff and the casting priest's addon message arrives moments
  later; only the local paths knew about each other, so the chat line, the
  sound and the center alert all came twice. Recognising both reports as one
  cast is the hard part, because 12.1 hides the caster from your client inside
  instances and the two sides spell names differently. Priests from different
  realms stay apart, the same cast under two different names is recognised,
  and when it genuinely cannot tell, it announces rather than staying silent.
- **The per-run RIO delta only appears when the data behind it arrived.** It
  was also shown after every refresh attempt had failed, and after you left the
  group before the refresh ran -- computed against the pre-run values, and
  indistinguishable from a real number.
- **The enemy-forces tracker keeps what it has confirmed.** WoW 12.1 can mask
  the kill count inside a key, and a confirmed 40% then became a synthetic 0%.
  The last verified reading now stands until a readable one arrives, and the
  count, total and percentage always move together. A quick second pull also
  keeps its own numbers instead of being cleared by the previous pull's timer.
- **Reloading inside a Mythic+ key no longer loses the ESC-menu shortcuts.**
  They stayed gone until the next client restart, because a reload in a
  dungeon always rebuilt that panel in a blocked state and the queued refresh
  was thrown away before it could be applied. It now survives until it can run.
- **Season 2 is the active season, and mob percentages are back in Mythic+.**
  They had disappeared for everyone on S2 keys: the season carried no enemy
  forces data at all, so every S2 dungeon was left without values. The bundled
  database now covers all 8 S2 dungeons with 145 mobs. Season 1 stays fully
  usable as the manual fallback -- everything except mob percentages.
