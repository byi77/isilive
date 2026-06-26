# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.336`.

Highlights:
- Unholy Death Knights can now enable default-off VIP warnings for Soul Reaper
  and Putrefy. The warnings use only the local Dark Transformation cast and
  verified actionbar spell IDs, and the Settings toggles stay visible even on
  non-DK characters.
- Mythic+ death counters now reset immediately after dungeon completion,
  challenge abort, or party-instance exit, matching the existing M+ timer and
  BR/BL timer cleanup.
- Power Infusion alerts are now shared with isiLive peers when the local
  verified priest casts PI on a verified recipient, using addon sync instead
  of target-based guessing.
- Protected/secret Power Infusion `spellId` values now fail closed instead of
  aborting repeated `UNIT_AURA` dispatch.
- Power Infusion text alerts now have their own Settings toggle; disabling it
  keeps verified PI detection fail-closed but suppresses the local chat line and
  local center alert.
- The local Power Infusion recipient now has a separate received-sound toggle
  with English/German WAV assets and a Settings preview button.
- Power Infusion detection now reports verified priest/recipient names locally,
  and the local recipient gets the same red animated center alert style as the
  tank/healer death warning.
- Demo mode now includes a Power Infusion preview in the full feature preview
  and simulation tablet.
- Midnight Season 2 preparation has started: `midnight_s2` is scaffolded but
  inactive until verified Blizzard IDs and Mythic+ forces data are available.
- isiLive still targets the live WoW 12.0.7 interface; 12.1.0 is not marked
  live in the TOC yet.
- Incoming summons can now repeat the `Portal.ogg` cue every 5 seconds while
  the local player's summon remains verifiably pending; the repeat loop has its
  own default-on Sound setting.
- German clients now use German static WAV announcements for tank death, healer
  death, Battle Res ready, and Bloodlust ready; English and all other locales
  keep the existing English WAVs.
- German clients also get a spoken incoming-summon cue ("Beschwoerung aktiv");
  all other locales continue to use `Portal.ogg`.
- On-screen death-alert text is now uppercase: German clients show `TANK TOT`
  / `HEILER TOT`, while English and fallback locales show `TANK DIED` /
  `HEALER DIED`.
- New Sound settings can mute only your own tank-death or healer-death WAV
  alert without disabling the on-screen warning, death counters, or alerts for
  other group members.
- Those own-death sound settings now sit below their matching tank/healer
  parent setting, and Sound preview buttons use a texture play icon instead of
  a font glyph.
- Compact vertical `V` layout now uses short leader labels (`RC`, `CD10`,
  `CD0`), hides Share Keys there, removes the tool headers, and places world
  markers in two tight columns.
- The ESC Travel panel now includes a Dalaran shortcut that only appears when
  the Dalaran Hearthstone toy is verified as owned.
- Settings localization was audited: prepared French, Spanish, Portuguese,
  Italian, Russian, and Turkish Settings fallbacks were translated, with tests
  preventing unmarked English fallback text in prepared Settings locales.
- Queue/LFG target handling now keeps ambiguous single-struct activityID lists
  unresolved instead of selecting the first concrete candidate.
- UI layout hardening now covers rich center notices with long wrapped fields,
  title-bar text budgets, demo simulation tablet growth/clamping, death-alert
  wrapping, and sound-preview play tooltips.
- The optional Player Stats Box now keeps wider live stat values, including
  Stamina rows without a percent value, inside the value column instead of
  clipping them.
- Raid LFG accepts no longer show an isiLive center notice, avoiding irrelevant
  "Unknown dungeon" messages for non-Mythic+ content.
- If raid mode hides an already-open isiLive window, the window now reopens
  automatically when the group returns to party size; windows that were already
  closed stay closed.
- The README / addon listing overview has been redesigned around the actual
  tool experience: clearer Mythic+ command-center positioning, colorful
  feature signals, stronger "why use it" highlights, and a screenshot section
  for the main surfaces.
- The ready-check-complete `BttF_Tinkle.wav` asset is now mono 44.1 kHz
  16-bit PCM, cutting that bundled WAV roughly in half while keeping the same
  in-game sound path.
- The Battle Res fallback sound `RoosterChickenCalls.ogg` is now tracked and
  packaged, so the fallback can actually play if WoW rejects the primary
  `ChickenAlarm.ogg` asset.
- Leaving a party instance now clears stale Mythic+ timer and BR/BL
  ready-sound state, so Bloodlust-ready reminders do not continue outside the
  dungeon.
- Player-hover group-bonus tooltips now use neutral group-bonus wording
  instead of the old `isiLive Bonus` prefix.
- isiLive now targets the live WoW 12.0.7 interface only; the older 12.0.5
  TOC compatibility marker was removed.
- The active M+ killtracker row now shows the current death count directly
  behind the dungeon/key name.
- Dungeon-entry refreshes no longer fire stale Battle Res-ready or
  Bloodlust-ready alerts.
- Roster green-heart mouseovers now show the concrete class-buff details and
  include BR/BL as tooltip-only utility.
- Native WoW text-to-speech death alerts are disabled; death-alert audio now
  uses only the bundled static WAV files.
- Tank and healer death WAVs have separate Sounds settings toggles and preview
  buttons.
- `TankDied.wav` and `HealerDied.wav` were trimmed to one spoken announcement,
  so previews and runtime alerts no longer repeat the phrase from a single
  playback.
- Repeated `Tank died` / `Healer died` role callbacks are de-duplicated before
  playing a second immediate alert.
- The shared same-sound spam window is temporarily disabled for death-WAV
  diagnosis.
- Damage-dealer deaths remain tracked for death counters and tooltips, but do
  not play audio because no bundled DPS death WAV exists.
- Accepted-invite target chat now uses the same verified listing payload as the
  center notice and avoids stale duplicate dungeon lines from older queue state.
