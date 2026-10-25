# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.454`.

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

<!-- highlights-reviewed-for: 0.9.454 -->

Highlights:
- **Cross-realm calls fixed.** Battle res, Bloodlust and Power Infusion
  announcements from isiLive users on another realm show up again; in mixed
  pug groups they were silently lost.
- **Pace at a glance.** The killtracker bar shows the spent time as a strip
  in the timer's colour; the gap to the forces is green while you lead the
  clock and red while you fall behind.
- **Time to kill (TTK).** During a Mythic+ fight your target shows roughly
  how many seconds it has left, inside its health bar and in the killtracker
  line, for bosses, minibosses and casters. Good for deciding whether a
  cooldown, stop or target swap is still worth it and when to start your
  burst. Preview it on a training dummy with `/isilive ttktest`.
- **Time pace.** A line under the killtracker bar shows whether the key is on
  time: compared with your own slowest timed run on that dungeon and key
  level, or as a finish forecast.
- **Modern flags and role badges.** Language flags are sharp, rounded badges
  with correct designs; the roster shows new subtle tank, healer and damage
  badges, centered between spec and flag.
