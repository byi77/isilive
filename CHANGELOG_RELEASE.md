# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.505`.

Version 0.9.505: with Plater the enemy forces percentage sits right next to
the health bar again instead of offset to the top left, and it stays there
after you change its position in the settings. The X and Y offsets now also
move the text towards the bar; your current position is kept. The time pace
badge is half transparent, so the forces fill shows through.

Version 0.9.504: the killtracker shows at a glance whether the key makes it:
a badge reads ON TIME (green), CLOSE (yellow) or TOO SLOW (red) with the
margin to the time limit. During a fight it turns grey with a pause sign, so
you see the value is frozen until the pull's kills are counted. A running key
no longer shows the dungeon name on the bar.

Version 0.9.503: the forces and time forecast in a key start from fresh values
for all eight season dungeons, until your own learned routes and runs take
over.

Version 0.9.502: the talent and loot check card highlights your active
loadout and loot spec again (gold frame and label, in both designs), and the
reset confirmation no longer leaves its style on other game dialogs after a
design switch.

Version 0.9.501: bug fixes from an audit. Power Infusion calls from group
members no longer cause an error, the M+ timer comes back after you walk out of
a running key and back in, the minimap button keeps its position after a
reload, the window lock is restored on login, and the simulation tablet no
longer leaves demo data behind in real play.

Version 0.9.500: isiLive is now also listed in the addon menu behind the
minimap's addon button: left click opens or closes the window, right click
opens the settings. This release ships everything since 0.9.477, including
the new Modern design.

Version 0.9.479: Modern is now the isiLive design for everyone. Every user is
switched to it once on the next start; you can still go back under Settings >
General > Design or with `/isilive design classic`, and the switch now applies
at once (during combat after `/reload`). Modern gets rounded windows, cards and
buttons with a soft shadow, round Battle Res and Bloodlust icons, a calmer
ready check and a symmetric layout. The window now keeps the same margin on
both sides and even gaps between its blocks, in Classic as well.

Version 0.9.478: a new optional Modern design for the isiLive window, chosen
under Settings > General > Design or with `/isilive design modern` (takes
effect after `/reload`). It brings calm graphite surfaces, borderless buttons,
portal tiles with readable short codes, a timer that leads with the elapsed
time and shows only the chest level still in reach, and a glassy forces bar.
Classic stayed exactly as before.

Version 0.9.477: voice announcements follow the isiLive language instead of the
game client, and switching the language takes effect at once without a reload.
The download is much smaller: documentation screenshots are no longer packed
and the English announcements ship as compact Ogg files.

Version 0.9.476: the killtracker bar no longer runs ahead during a pull and falls
back afterwards; the pull is now coloured inside the real forces. The time pace
turns red only when the forecast finish is past the time limit. Banner text is
white, and the row label reads `M+Tracker`.

Version 0.9.475: the M+ killtracker shows how a key ended as a banner over the
whole row: timed, over time, abandoned or group left, for up to 60 seconds. The
pre-key dungeon and key level use the same banner style, in gold. The demo has
a button for every banner.

Version 0.9.474: isiLive texts, dungeon names and abbreviations follow the
isiLive language instead of the game client: German in German, English in every
other language. Open cards switch at once, also in the demo.

Version 0.9.473: the time forecast now combines the whole run and the last four
minutes, so one big pull no longer swings it. If you tank, your own tanked runs
set the forces targets.

Version 0.9.472: forces targets start with measured values on seven of the eight
season dungeons, until you have runs of your own.

Version 0.9.471: the killtracker shows how much enemy forces are still needed
before the next boss ("Needs x% more in this section", next to the TTK), also
during a pull. Start values work before you have runs of your own, the last
section always targets 100%, ticks mark all coming sections, and the display
survives a reload.

Version 0.9.470: audit fixes across sync, roster, key history, inspect, talent
and loot check and LFG targets. With sync off, isiLive no longer posts your key
when a group member asks for it. Devourer counts as Intellect and magic damage
in the LFG bonus check.

Version 0.9.469: the talent and loot check writes its steps (dungeon entry,
switches, commit result, OK) into the runtime log.

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

<!-- highlights-reviewed-for: 0.9.505 -->

Highlights:
- **Nameplate forces work with Plater.** The enemy forces percentage follows
  Plater's health bar instead of hanging offset at the top left, and the X/Y
  offsets now move it in both directions.
- **Clear on-time badge.** The killtracker bar says in one word whether the
  key makes it: ON TIME, CLOSE or TOO SLOW, with the margin to the time
  limit. During a fight it turns grey with a pause sign while the value waits
  for the pull's kills.
- **New Modern design, now the default.** Calm graphite surfaces, rounded
  windows, cards and buttons with a soft shadow, round Battle Res and Bloodlust
  icons, readable portal tiles, a timer that leads with the elapsed time and a
  glassy forces bar. Everyone is switched to Modern once; Classic stays
  available under Settings > General > Design or `/isilive design classic`, and
  the switch applies at once outside combat.
- **Voice announcements in your isiLive language.** Spoken alerts now follow
  the isiLive language instead of the game client, and a language switch takes
  effect at once. The download is several megabytes smaller: screenshots stay
  out of the package and the English announcements are compact Ogg files.
- **Coloured item level and rating.** The roster and its tooltip colour each
  item level by this season's Mythic+ reward tiers (epic, rare, uncommon,
  poor) and each Mythic+ rating with Blizzard's own score colour, so
  undergeared applicants stand out. Item levels fill in faster: inspects by
  other addons are reused, and group members running Details! report theirs
  without an inspect.
