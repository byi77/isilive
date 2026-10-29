# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.468`.

Version 0.9.468: the talent and loot check shows your active loadout and
loot spec without a verdict; which saved loadout is right is your call. The
accepted-invite card lists Talents and Loot under Loadout, the loadout name in
gold.

Version 0.9.467: the talent and loot check reads at a glance (one line per check
with a tick or cross on the accepted-invite card), counts a talent switch only
once it has gone through and flags unsaved talent changes; the portal hint is
shorter, and the simulation tablet shows every card with your real data.

Version 0.9.466: redesigned center notice cards. A header band with a
coloured category chip and the isiLive mark, quieter field rows, a calm
pulsing warning strip and a framed portal tile; the portal navigator uses the
same header.

Version 0.9.465: item level and Mythic+ rating in the roster are coloured by
season tier; item levels arrive faster (other addons' inspects are reused,
Details! users are read via LibOpenRaid), and isiLive no longer inspects while
your own inspect window is open.

Version 0.9.464: new talent and loot check before the key. Entering a
season dungeon in a group shows your talent loadout and loot spec next to
what you confirmed for that dungeon and spec, with one-click switches; a
full match is a green chat line, and the accepted-invite card gets a
"Loadout" row.

Version 0.9.463: the killtracker keeps the dungeon and key level on its bar
after you enter the dungeon, while the key runs and after it ends, until you
leave the dungeon.

Version 0.9.462: the paused time pace keeps its green or red colour from before
the pull instead of turning grey.

Version 0.9.461: the paused time pace reads "Pause" in front of the value,
and the setting description explains the fight pause.

Version 0.9.460: the killtracker time pace holds its value during a fight,
dimmed grey, and updates once the pull's kills are counted.

Version 0.9.459: an accepted LFG invite keeps its dungeon in the window and
the chat line, also with several open applications or when accepted in combat;
a /reload during the demo no longer switches the nameplate forces display.

Version 0.9.458: before the key the killtracker bar glows gold with a light
sweep and the pulsing target dungeon and key level; during the key the
dungeon stays on the progress bar.

Version 0.9.457: the killtracker shows `100%` cleanly, time pace sits on
the bar as a +/- delta, and the target dungeon pulses until the key starts.

Version 0.9.456: safer sync retries and payload validation, reliable key-owner
selection, inspect retries without lost stats, and stricter TTK combat/target state.

Version 0.9.455: reliable forces/time pace learning, TTK recovery
after reload or enabling during a fight, raid suppression, and stable larger
TTK nameplate text.

Version 0.9.454: Battle res, Bloodlust and Power Infusion calls from group
members on another realm reach you again; a fresh install starts in your game
language. The source code is no longer open source (free to use, not to copy).

Version 0.9.453: spent time and the forces/time gap on the killtracker bar;
time to kill inside the target's health bar, for important enemies only.

Version 0.9.452: the invite card shows a sharp dungeon picture from the
Adventure Guide instead of the blurry, enlarged teleport icon.

Version 0.9.451: time to kill for your target above its nameplate and in the
killtracker line, plus a time-pace line that tells you whether the key is on
time.

Version 0.9.450: the "Target dungeon" chat line no longer repeats when you
enter the dungeon.

Version 0.9.449: sharper, modern language flags and new
role badges (tank, healer, damage) that match the isiLive look.

Version 0.9.448: the invite navigation shows only the zone and, when the
portal room has a portal there, a second line to use it.

Version 0.9.447: the navigation row of the accepted-invite card is visible
again; center cards show up to six rows.

Version 0.9.446: the 60-second Bloodlust-ready reminder gets a sound preview
in the settings; the demo mode shows the invite navigation row, isiLive
markers on group members and spec-accurate bonus markers.

Version 0.9.445: the accepted-invite card shows where the dungeon is (zone,
entrance coordinates, portal room hint); Group Finder best matches the Blizzard
Mythic+ tab; long roster names keep their markers visible.

Version 0.9.444: ten German voice alerts now share one clear male voice and
consistent loudness; existing effects have matching loudness. Compact Ogg
files replace the German WAV recordings. English voice recordings are unchanged.

Version 0.9.443: clearer, consistent spec short labels in the roster.

Version 0.9.442: leaner, more useful diagnostic logs for bug reports; logging
off costs no extra work.

Version 0.9.441: your own dungeon best in Group Finder, new bonus and isiLive
markers, and a Bloodlust lockout follow-up.

Version 0.9.440: the Bloodlust timer and all Bloodlust alerts work inside keys again.

<!-- highlights-reviewed-for: 0.9.468 -->

Highlights:
- **Redesigned center notice cards.** Every card now opens with a header band:
  a category chip in the card's colour, the isiLive mark on the right and the
  headline below. Field rows are separated by hairlines, warnings sit on a red
  strip that pulses calmly (steady with reduced motion), and the portal button
  is a framed tile. The portal navigator shares the same header.
- **Coloured item level and rating.** The roster and its tooltip colour each
  item level by this season's Mythic+ reward tiers (epic, rare, uncommon,
  poor) and each Mythic+ rating with Blizzard's own score colour, so
  undergeared applicants stand out. Item levels fill in faster: inspects by
  other addons are reused, and group members running Details! report theirs
  without an inspect.
- **Talent and loot check before the key.** Entering a season dungeon in a
  group shows your active talent loadout and loot spec, with one-click
  switches to every saved loadout and loot spec; which one is right is your
  call. The accepted-invite card lists Talents and Loot under Loadout, the
  loadout name in gold, and a switch counts only once it has really gone
  through.
- **Cleaner killtracker.** Before the key the empty bar glows gold with a
  slow light sweep and the target dungeon and key level pulse on it, so you
  see at a glance which key the group is about to run; during the key the
  dungeon stays on the progress bar. Complete forces read `100%`.
- **Time to kill (TTK).** During a Mythic+ fight your target shows roughly
  how many seconds it has left, inside its health bar and under the
  killtracker bar, for bosses, minibosses and casters. Good for deciding whether a
  cooldown, stop or target swap is still worth it and when to start your
  burst. Preview it on a training dummy with `/isilive ttktest`.
