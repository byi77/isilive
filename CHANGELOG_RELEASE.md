# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.407`.

Version 0.9.407: Roster rows show each player's class color at a glance, and ready-check results fade in and count down until they clear.

<!-- highlights-reviewed-for: 0.9.407 -->

Highlights:
- **A livelier roster.** Every row now starts with a thin stripe in the player's class color (grey for players who are offline or left), and hovering a row fades its highlight in. Ready-check colors fade in instead of snapping on, and after the check a slim bar under each row counts down the 20 seconds until the ready/not-ready marking clears.
- **See your chest at a glance.** The M+ timer now shows a slim timeline with +3 and +2 marks in the color of the chest you can still reach, and dims the ones you can't. The killtracker bar stays calm blue until forces are done and turns green at 100%, glides to new values instead of jumping, and writes percentages the way your language does. Battle res and Bloodlust icons show a cooldown swipe, and an empty battle res greys out.
- **Clearer states everywhere.** Locked, cooling-down and blocked actions, notice types, the death counter and the title-bar lock now use real icons instead of letters. Notices fade in so you notice them, offline players and players who left are dimmed as a whole row, world markers show their localized name and a hover highlight, and Settings use clean flat checkboxes. Turning on reduced motion now also calms the death alert.
- **Read notice types at a glance and find Settings faster.** Information, warnings, and portal actions now have distinct markers and a brief fade when a notice appears or changes status; an optional setting disables decorative fades and portal pulses. Ten always-visible Settings buttons jump directly to the chosen controls. Display settings show scale and opacity in a live preview and can restore their own defaults without resetting unrelated preferences.
- **Never miss a stuck pet again.** When your pet gets stuck and the game shows the red "No path available for your pet" message, isiLive now says "Check your pet!" (German clients: "Achte auf deinen Begleiter!") right away, so a pet stranded behind a pull no longer quietly halves your damage. It works in every client language, repeats at most every 5 seconds, and can be switched off under Sounds, where a preview button lets you hear it.
