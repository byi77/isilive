# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.315`.

Highlights:
- New movable demo simulation tablet: `/isilive testall` opens it automatically
  and `/isilive sim` toggles it manually. Buttons run local preview scenarios
  for notices, group-full simulation, ready-checks, M+ timer / forces, combat
  cooldowns, portal navigator, Share Keys cooldown, death/sound/TTS previews,
  stats, LFG bonus markers, and cleanup.
- Fixed the Share Keys button cooldown label flickering between the timer and
  the plain button text during UI refreshes.
- Expanded demo mode: the full preview now also shows ready-check hold row
  colors, a mirrored Share Keys cooldown, death-alert/TTS previews, and the
  ready-check-complete sound, then clears those preview states on exit.
- Optional spoken (text-to-speech) death alerts: a new Sounds toggle speaks the alert through your system voice instead of playing the recorded file, with switches to include the player name and to announce the class (e.g. "Hunter died") instead of the role.
- Spoken death alerts now cover damage dealers too; the big red on-screen warning still appears only for tank and healer and always shows the role-only text without a name.
- New tank / healer death alert (0.9.309): a big red animated on-screen warning with a sound ("Tank died" / "Healer died") when the tank or healer dies during an active M+ run — including your own death.
- New ready-check completion sound (0.9.309): plays once when all five party members are ready, with its own Sounds settings toggle and preview button.
- Fixed the share-keys button getting stuck in an endless cooldown loop in groups (0.9.309): a sync echo loop between clients kept re-locking the button; the loop is broken and a mirrored lock is no longer re-broadcast.
