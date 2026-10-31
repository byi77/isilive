# CurseForge-Uebersicht

Diese Datei ist die gepflegte Vorlage fuer die manuelle CurseForge-Projektbeschreibung.
Der Release-Workflow aktualisiert nur die Release Notes (`CHANGELOG_RELEASE.md`), nicht die
dauerhafte CurseForge-Overview im Projektprofil.

## Warum nicht nur README?

CurseForge rendert die dauerhafte Projektbeschreibung je nach Editor/Ansicht nicht wie GitHub.
In der beobachteten CurseForge-Ansicht werden Markdown-Ueberschriften, Fett-Markierung,
Markdown-Bilder und HTML-Tags als sichtbarer Text ausgegeben. Fuer diese Overview ist deshalb
Plain Text mit klaren visuellen Markern die belastbare Variante.

- keine Markdown-Syntax in der Copy/Paste-Vorlage
- keine HTML-Tags wie `<p>` oder `<img>`
- Screenshots ueber den CurseForge-Medieneditor hochladen/einfuegen
- kurze, starke Abschnittsbloecke mit farbigen Unicode-Markern

## Pflegehinweis

Nach sichtbaren Aenderungen an Feature-Positionierung, Screenshots oder Versionsbaseline:

1. README-Topbereich aktualisieren.
2. Den Copy/Paste-Bereich unten bei Bedarf synchronisieren.
3. CurseForge-Projektbeschreibung manuell mit dem Bereich zwischen `START` und `ENDE`
   aktualisieren; die Marker selbst nicht mitkopieren.
4. Screenshot-Platzhalter im CurseForge-Editor durch echte CurseForge-Medien ersetzen.
5. Keine Markdown-Bildlinks, Shields-Badges oder HTML einfuegen, solange CurseForge diese Ansicht
   als Klartext rendert.

Empfohlene Medienpositionen im CurseForge-Editor:

- beim Platzhalter im Kopfbereich: `isiLive_MPlus_annotated.png`
- nach `GREEN PLUS SIGNS`: `isiLive_LFGBuffRating.png`
- nach `ONE WINDOW`: `isiLive_MPlus_ui.png`
- nach `PORTAL GRID`: `isiLive_PortalNavigator.png`

## Copy/Paste fuer CurseForge START

isiLive
The colorful Mythic+ command center for World of Warcraft.

🟦 WoW 12.1.5 Midnight Retail
🟩 Mythic+ Command Center
🟧 Automatic Setup
🟪 Version 0.9.474

isiLive turns group prep, LFG decisions, dungeon portals, enemy forces, cooldowns, death tracking, and key sharing into one compact window.

[SCREENSHOT: isiLive_MPlus_annotated.png]

New in 0.9.474: isiLive texts, dungeon names and abbreviations follow the isiLive language instead of the game client: German in German, English in every other language. Open cards switch at once, also in the demo.
New in 0.9.473: a steadier time forecast that combines the whole run, the last four minutes and the dungeon's time curve, so one big pull no longer swings it.
New in 0.9.472: forces targets for all eight season dungeons from your first key on.
New in 0.9.471: the killtracker shows how much enemy forces are still needed before the next boss ("Needs x% more in this section"), also during a pull, and ticks on the bar mark all coming sections.
A shared modern UI hierarchy runs across the main window, Mythic+ run surfaces, notices, Stats Box, Settings, ESC shortcuts, compact Group Finder markers, nameplates, tooltips, and death alerts. Runtime data, secure actions, and automatic Midnight Season 2 selection remain unchanged.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WHY USE isiLive?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🟩 GREEN PLUS SIGNS: better LFG decisions
Instantly see useful, non-stacking group buffs in Blizzard LFG search results, applicant rows, and your active roster.

🟦 ONE WINDOW: group, keys, cooldowns, forces, portals
See spec, role, language, key, item level, Raider.IO, last-run DPS, interrupt state, leader marker, isiLive peer marker, green group-bonus plus signs, and ghost rows after leavers.

🟨 LIVE FORCES: pull planning while the key is running
Track enemy forces, pull prediction, nameplate percentages, tooltip percentages, and combat-end refresh from the bundled MDT-synced database.
Section targets show how much forces you still need before the next boss: the text under the bar reads "Needs x% more in this section", also during a pull, and turns off once the section is reached. The pull counter turns green when the running pull has reached the target.
Start values work for all eight season dungeons from your first key. Your own completed keys replace them, your tanked runs first if you tank, and the last section always targets 100%. The display survives a reload.
MDT-dependent mob details are shown only when the bundled database exactly matches the active season; Blizzard's overall dungeon progress remains available independently.

⏱️ TIME TO KILL: how long your target still lives
During a Mythic+ fight, isiLive shows in your target's nameplate health bar roughly how many seconds it has left, on a dark plate that stays readable among damage numbers, and repeats it as TTK in the killtracker line.
Use it to decide whether a cooldown, an interrupt stop or a target swap is still worth it, to time your burst for the end of a pack or boss, and to see which mob in a pull is about to die.
The estimate follows how fast the mob has been losing health so far and counts down smoothly between hits. Bloodlust, target swaps or immunity phases change the pace, so treat it as a guide, not an exact timer.
By default it shows for bosses, minibosses and casters only, recognised from game data rather than nameplate colours, so it works with Blizzard nameplates, Plater, Platynator or any colour profile; a setting shows it for every enemy instead.
Switch it on or off in the Display settings; /isilive ttktest previews it on a training dummy.

⏳ TIME PACE: is the key on time?
The killtracker bar shows the spent time as a strip in the timer's colour. The gap between forces and time is tinted green while your forces lead the clock and red while the clock leads, so you see the pace without reading numbers.
A +/- time delta on the right end of the killtracker bar compares your run with your own slowest timed run on the same dungeon and key level, the slowest pace that still made the timer. Green means you are ahead of it, red means behind.
Without such a run yet, it shows a finish forecast against the time limit, combined from the whole run, the last four minutes and the dungeon's time curve, so one big pull does not swing it. Reference runs are learned automatically from your completed keys.
During a fight the delta pauses: it holds the value from the pull with "Pause" in front, in the colour it had at the pull, and updates once the pull's kills are counted. Without the pause it would drift late mid-pull and snap back when the mobs die.

🧩 TALENT AND LOOT CHECK: ready before the key
Entering a dungeon of the active Mythic+ season in a group, before the key starts, shows a card with your active talent loadout and loot specialization. Confirm it once with "OK - remember" per character, spec and dungeon; on later visits any difference is flagged in red.
Every saved loadout and every loot spec can be switched with one click out of combat. When everything matches, a green chat line replaces the card, and the accepted-invite card shows the same status in its "Loadout" row. Switch it off in the settings if you do not need it.

🟪 PORTAL GRID: current season travel in one place
Open the right dungeon portal from one compact grid. Cooldowns, ready states, and verified LFG target highlights stay visible at a glance.

🟥 RED ALERTS: deaths and run utility
Tank and healer deaths during active Mythic+ keys trigger a large on-screen warning and bundled audio; German alerts use one clear voice with consistent loudness. Battle Res, Bloodlust, ready sounds, and death counts stay visible where you need them.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WHAT isiLive GIVES YOU
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Better LFG scanning with green class-bonus plus signs.
✅ One compact Mythic+ roster with key, item level, Raider.IO, DPS, language, role, and interrupt state.
✅ Automatic key, target, stats, DPS, location, and kick sync between isiLive users, routed through verified party or instance chat channels.
✅ Verified Mythic+ target handling that highlights portals only from clear LFG activity/map context and leaves ambiguous data unresolved.
✅ A talent and loot check before the key, remembered per dungeon and spec, with one-click loadout and loot spec switches.
✅ A current-season portal grid with cooldowns and verified target highlighting.
✅ Live enemy-forces tracking through a bottom bar, pull prediction, section targets before each boss, nameplates, and mob tooltips.
✅ Time to kill in your target's nameplate and in the killtracker line, so you know how long a mob or boss still lives.
✅ Time pace on the killtracker bar: on time or behind, measured against your own slowest timed run or a combined finish forecast, paused during fights.
✅ Battle Res, Bloodlust, ready sounds, and tracked death counts in the main M+ view.
✅ Voice alert the moment your pet gets stuck and reports no path to follow you.
✅ Voice alert on incoming group invites, repeated every 5 seconds until you answer.
✅ Voice alert when you are removed from the group, in parties and raids.
✅ Optional raid alerts: incoming summon, stuck pet and lead transfer, each switchable for raids.
✅ A large red tank/healer death alert during active keys.
✅ Optional VIP helpers: mount sound mutes for Astral Aurochs, Grand Expedition Yak (plus a separate mute for its two chatty vendors), and Trader's Gilded Brutosaur, a default-off Bloodlust button debuff warning for verified BL class and pet buttons plus a separated DK block with Soul Reaper / Putrefy warnings, Riders horse sound mute, and a movable localized missing-ghoul reminder.
✅ Optional support tools: ESC-menu shortcuts, Hearthstone and verified Dalaran travel, player stats box with distinct colors and corrected compact German labels, nameplate controls, runtime logs, UI lock, and demo simulation tablet.
✅ Coherent UI controls: live full-window background opacity, centered title controls, and one compact close style across every isiLive-owned window.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BUILT FOR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🟢 Mythic+ players
🟢 Premade groups
🟢 LFG runs
🟢 Players who want fast decisions without opening five extra panels

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SOURCE AND LICENSE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

isiLive is free to download and use. The source code is public but not open source: copying, reusing or redistributing it requires written permission. Versions before 0.9.454 remain under the MIT License they were released with.
Bundled library and media provenance is documented transparently in the public repository; unknown mixed-origin asset mappings remain explicitly unresolved instead of being guessed.

No setup required. Install, join a 5-player group, and isiLive opens automatically.

## Copy/Paste fuer CurseForge ENDE
