# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.447`.

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

<!-- highlights-reviewed-for: 0.9.447 -->

Highlights:
- **Navigation for accepted invites.** The invite card names the dungeon's
  zone with entrance coordinates and mentions when the season portal room has
  a portal to it.
- **One German announcer voice.** Ten concise voice alerts share the approved
  male voice, clear pronunciation and consistent loudness. Existing effects
  have matching loudness; the complete German voice pack is about 115 KiB.
- **Your own dungeon best in Group Finder.** Search results show your current
  character's best level for that dungeon this season (`You: +14`), picked
  like the Blizzard Mythic+ tab, with or without Premade Groups Filter.
- **New markers.** Glossy green plus signs mark useful group bonuses; a blue connection
  arrow marks other isiLive users.
- **Bloodlust lockouts read directly.** The Sated/Exhaustion debuff is queried
  by spell ID, so countdowns and ready alerts keep working when WoW blocks
  aura lists. The ten-second warning, ready alert and 60-second reminder also
  work with the main window hidden; the warning has its own toggle.
