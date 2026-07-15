# Changelog

## 2026-07-15 - Version 0.9.346 (patch)

- Removed per-event argument-table and closure allocation from protected event
  dispatch while preserving nested dispatch and traceback reporting.
- Replaced visible one-second full roster rerenders with targeted CD, ready, and
  Mythic+ row refreshes; hidden event-driven Mythic+ pre-rendering remains.
- Removed the Mythic+ timer's permanent 10 Hz frame poll; live snapshots now
  sample Blizzard's elapsed timer only when a consumer reads them.
- Limited periodic kill-tracker nameplate work to active overlays, moved the
  roster system-option watcher from permanent `OnUpdate` work to a visible-only
  owned ticker, and skipped unchanged StatsBox and roster layout mutations.
- Avoided eager diagnostic string formatting when runtime logging is disabled,
  added deterministic performance-contract coverage, and documented bundled
  MP3 files in the unresolved asset-provenance inventory.

## 2026-07-13 - Version 0.9.345 (patch)

- Made Season Intake Markdown parsing deterministic across Lua 5.1 and 5.4 by
  consuming table delimiters in every pattern match, with regression coverage
  for exact row and column preservation.
- Standardized the project license to unmodified MIT, added an explicit public
  asset-provenance register for unresolved mixed-origin sound and texture
  files, and made the public agent runbook standalone.
- Removed five unused historical screenshots, documented the retained public
  Center Notice mockup, moved experimental Warcraft Logs TimePace research to
  the private workspace, and promoted the passing M+ timer lifecycle simulator
  into local and GitHub CI.
- Corrected the duplicate death-alert usecase identifier from `UC-24` to
  `UC-28` and consolidated the season-change checklist into one public runbook.

- Added the public `docs/SAISON_WECHSEL.md` runbook with a reusable checklist
  for verified intake, manifest preparation, optional Forces generation,
  activation approval, in-game checks, documentation, and full local CI.

- Consolidated manually maintained season configuration into
  `data/isiLive_seasons.lua`. Each dungeon now owns its ChallengeMapID,
  portal spells, LFG activity IDs, display order, localized names, short
  codes, optional level gate, portal-room placement, and verification
  metadata in one record. Runtime lookup tables, LFG detection, the portal
  navigator, and MDT directory selection derive from that manifest; the
  generated expiring Forces payload remains separate. Added deterministic
  runtime and architecture coverage for the single-source contract.

- Fixed dungeon portal availability for lower-level alts by persisting only
  live-confirmed configured portal spells for account-wide reuse. This avoids
  character-local false Spellbook results on alts. Locked tooltips now describe
  the +10 unlock as account-wide, and only explicitly marked new Midnight
  dungeons show the level-90 requirement; returning dungeons no longer inherit
  it. (2026-07-13)
- Disabled automatic selection for `midnight_s2` and allowed an explicit
  manual S2 activation before its optional MDT forces database is available.
  Blizzard scenario progress remains visible in that state, while MDT-backed
  nameplate percentages, mob tooltip lines, and DB-total fallbacks stay hidden
  until the bundled forces database exactly matches the active season.
- Hardened Forces readiness for auto-detected seasons with positive NPC IDs,
  counts, valid season-map ownership, and per-map NPC coverage. Missing German
  short-code tables now also block green display readiness.
- Made the daily MDT availability inspector continue past invalid text hits,
  describe its result as structural availability instead of unprovable NPC
  completeness, and reuse/reopen its marker-stable issue across all pages.
- Added an out-of-combat season-selection retry for map updates that arrived
  while protected UI mutation was blocked.
- Completed the prepared Midnight Season 2 display metadata with English and
  German dungeon names, default and German short codes, and an explicit
  ascending map-ID display order.
- Changed the MDT Season 2 preview into a daily fail-closed Forces availability
  monitor. It opens or updates a stable GitHub issue only after all eight
  dungeons expose exact map IDs, positive totals, and positive NPC Forces data;
  textual placeholders no longer trigger a notification.
- Added fail-closed automatic season selection on login and challenge-map
  updates. A switch now requires an exact Blizzard challenge-map-set match,
  complete display readiness, and a matching non-expired Mythic+ forces DB.
- Documented that official MDT `6.1.20` does not yet contain usable Season 2
  forces data: its only new-season file is an incomplete Murder Row scaffold.
- Recorded all eight verified Midnight Season 2 ChallengeMapID-to-castable-
  portal-spell mappings while keeping `midnight_s1` active and Season 2
  readiness independent from the optional Mythic+ forces data.
- Added deterministic coverage that pins every approved Season 2 dungeon
  portal mapping and prevents triggered instant teleport subspells from
  replacing the castable portal spells.

## 2026-07-12 - Version 0.9.344 (patch)

- Recorded verified PTR Mythic+ LFG activity IDs for all eight prepared Midnight
  Season 2 dungeons and the verified Ruby Life Pools portal spell in the
  fail-closed Season Intake.
- Captured observed outside and inside instance context for the available PTR
  dungeons without promoting LFG, instance, or player-best map IDs to unresolved
  ChallengeMapIDs.
- Documented the future Season 2 portal-room layout while keeping
  `midnight_s1` active until the explicit manual season switch.
- Expanded deterministic Season Intake coverage for all eight LFG activity IDs,
  the Ruby Life Pools portal, and the current `0/8 verified, 8/8 partial` gate.

## 2026-07-10 - Version 0.9.343 (patch)

- Pinned every external GitHub Action to an immutable full commit SHA, added
  weekly Dependabot maintenance for those pins, and kept readable major-version
  comments beside each reference.
- Sandboxed freshly cloned MDT dungeon sources during Forces generation: the
  loader no longer inherits `_G`, rejects bytecode and oversized files, and
  enforces an instruction limit before a write-capable workflow can consume the
  generated data.
- Restored the documented 800-entry runtime-log cap, compacted oversized legacy
  rings to their newest entries, and made filtered diagnostics search the full
  retained ring instead of silently ignoring entries older than 500 lines.
- Added Blizzard ready, not-ready, and waiting icons to roster Ready Check rows,
  including the 20-second result hold, so status is no longer communicated by
  background color alone.
- Excluded the root maintenance `TODO.md` from both CurseForge and GitHub/WowUp
  packages and pinned the identical exclusion with deterministic tests.
- Updated the stable and pre-release workflows from `actions/checkout@v4` to
  the repository-wide v5 baseline and added a workflow regression gate.
- Hardened the composition boundaries found by the end-to-end architecture
  audit: RuntimeSetup now requires separately constructed group, event,
  leader-watch, slash-command, and gate contexts without root fallbacks or a
  self-referential event context.
- Removed the production `_factoryCtx` escape hatch, introduced the explicit
  `RosterUI` facade for cross-layer UI dependencies, and prohibited Logic and
  Factory modules from reading the private roster implementation registry.
- Made the Lua metrics gate verify every warning-level production file against
  the documented refactoring watchlist and split the 420-line combined
  status/operational initializer into bounded ownership phases.
- Restored the shared one-second duplicate guard for identical sound files and
  SoundKits in the same output channel and spam scope, with deterministic
  boundary coverage at exactly one second.
- Added the real CI coverage run and both coverage thresholds to the local full
  preflight, including a parity test so the local wrapper can no longer report
  success before the GitHub-equivalent coverage gates finish.
- Reduced `CHANGELOG_RELEASE.md` to three current user-facing highlights and
  pinned its documented three-to-five-highlight budget in the architecture
  suite.
- Guarded the remaining optional `C_Map`, `UnitExists`, and `GetInstanceInfo`
  consumers so missing WoW APIs now fail closed instead of resolving through
  bare globals.
- Added explicit ownership and cancellation for the binding, kick, and combat
  utility polling tickers; hidden notices, teleport cooldown text, and the
  disabled stats box now release their frame-update handlers.
- Repaired the real ChatThrottleLib FIFO simulator, made the nameplate simulator
  default to its documented `all` mode, and added the CTL wire-order probe to
  both local and GitHub CI.
- Split optional-global boundary checks out of the large architecture scenario
  module and added runtime lifecycle coverage for ticker and `OnUpdate`
  transitions.
- Hardened incoming sync trust boundaries: state payloads now require party or
  instance-chat delivery, only ACK remains whisper-compatible, and BR/PI
  casters must match Blizzard's message sender.
- Rejected non-finite sync and SavedVariables numbers, invalid persisted frame
  anchors, and corrupted reload-mirror values before they can reach runtime
  formatting or UI state.
- Removed the minimap button's idle frame polling and corrected combat fade to
  use the current `rosterLayoutMode` instead of a retired setting name.

## 2026-07-05 - Version 0.9.342 (patch)

- Added `/isilive s2d` as a short alias for the existing Season diagnostics
  dump, keeping `/isilive seasondump` and `/il seasondump` intact.
- Recorded the first 12.1.0 PTR Season Intake findings for Midnight Season 2:
  Murder Row and Den of Nalorakk now carry observed PTR instance/map context as
  candidates, and Ruby Life Pools has verified portal spell `393256` (`Pfad
  des Nestverteidigers`) while its unavailable dungeon, challenge, and LFG IDs
  remain unresolved.
- Fixed group-chat and AddOn-sync channel routing for verified dungeon-finder
  instance groups such as timewalking runs: isiLive now uses `INSTANCE_CHAT`
  for verified instance groups, keeps `PARTY` for verified normal groups, and
  fails closed when neither group channel is verifiable.
- Updated deterministic Season Intake coverage to match the current
  pre-activation progress: 0/8 verified, 1 partial, 2 candidate, 5 unresolved.
- Updated deterministic instance-group chat and sync coverage; the current
  usecase baseline is `2162 passed, 0 failed`.
- Bumped the TOC and documentation baselines to `0.9.342`.

## 2026-06-30 - Version 0.9.341 (patch)

- Added local season-prep diagnostics for the next Season transition: `/isilive
  seasondump` prints observed Season, instance, challenge, LFG, and Forces DB
  data, while `/isilive hearthdump` prints verified known Hearthstone toy data.
  Missing Blizzard APIs are reported as unavailable instead of guessed.
- Tightened the M+ Forces DB release gate so the generated Forces dataset must
  match the active Season ID, preventing a future Season switch from shipping
  with stale Season data.
- Added read-only GitHub Actions inspectors for season readiness and MDT
  next-season preview artifacts; MDT preview discoveries now open or update a
  GitHub issue for manual verification.
- Added `docs/SEASON_INTAKE.md`, a deterministic intake validator, and a daily
  issue-updating workflow so pre-activation season IDs can be collected with
  source/date metadata without activating the season.
- Bumped the TOC and documentation baselines to `0.9.341`.

## 2026-06-28 - Version 0.9.340 (patch)

- Fixed the Kick tracker heartbeat so the hidden keep-alive still syncs for
  grouped clients, including verified automatic instance groups, but solo
  clients no longer run the 0.5s Kick scan/sync loop.
- Cleaned up fallback callback signatures in DeathWatch and Power Infusion
  tracking so Lua diagnostics no longer report redundant callback parameters.

## 2026-06-28 - Version 0.9.339 (patch)

- Added a hidden non-M+ party-run utility context: verified normal, heroic, and
  other tracked non-challenge party dungeons can now keep selected utility
  features active, while isiLive remains documented and branded as a Mythic+
  tool. Battle-resurrection/Bloodlust display, BR/Lust combat announces,
  DeathWatch, and non-challenge DPS capture may use the verified context; M+
  timers, Forces, RIO deltas, key levels, portal targets, and ready-sound
  reminders remain M+-only.
- Added deterministic coverage for the verified tracked-party-run RuntimeState,
  event lifecycle, CD tracker UI gate, combat announce gate, and DeathWatch
  factory gate. Ingame validation for the hidden non-M+ utility context is still
  pending and remains the deciding release check for the feature.
- The hidden party-run utility context now treats automatic dungeon finder
  instance groups as a valid grouped UI context via
  `IsInGroup(LE_PARTY_CATEGORY_INSTANCE)`, so BR/Bloodlust display is not tied
  to the normal party category only.
- Reordered the VIP settings so the Bloodlust button warning is a top-level VIP
  option directly below the Trader's Gilded Brutosaur mute, followed by a thin
  blue separator before the DK-specific settings.
- Added Marksmanship Hunter `Harrier's Cry` / `Schrei des Hetzers`
  (`466904`) to the verified Bloodlust spell lists for M+ Lust announces and
  the VIP Bloodlust button debuff warning.
- Documented the ingame Mage validation for Time Warp action buttons: the live
  button resolved to spell ID `80353`, so the unresolved external variant
  `428941` stays out of the verified Bloodlust spell lists. Drums remain
  intentionally excluded from the VIP Bloodlust button warning.

## 2026-06-28 - Version 0.9.338 (patch)

- Added a default-off VIP Bloodlust button debuff warning for BL classes. While
  the local player has a verified Sated/Exhaustion debuff, verified Bloodlust
  class or pet action buttons receive the shared red cross overlay; drums and
  unverified name/icon fallbacks are intentionally ignored.
- Added deterministic coverage for the Bloodlust button warning controller,
  default-off DB/schema state, VIP settings order, runtime event forwarding,
  factory wiring, and the new active rule contract. Usecase baseline is now
  `2137 passed, 0 failed`.
- Fixed VIP DK Soul Reaper / Putrefy warnings sometimes not appearing when
  `PLAYER_REGEN_ENABLED` fired during the 30-second Dark Transformation delay;
  regen now hides only currently visible overlays and leaves the scheduled
  warning intact. The actionbutton resolver also accepts verified secure
  `action` attributes before resolving spell or macro spell IDs.
- Fixed self-posted Share Keys chat output falling back to plain text when the
  verified bag link for Keystone item `180653` is exposed as an item hyperlink;
  isiLive now keeps that Blizzard-provided link clickable instead of rebuilding
  a non-clickable label.
- Fixed the VIP DK missing-ghoul reminder not refreshing on pet changes by
  forwarding the registered `UNIT_PET` event to the DK assist controller as well
  as the kick tracker.
- Fixed the VIP DK missing-ghoul reminder text always falling back to
  `SUMMON GHOUL` by wiring the active locale getter into the DK assist
  controller; the prepared locale tables already contain the warning text for
  every supported locale.
- Bumped the TOC and documentation baselines to `0.9.338`.

## 2026-06-27 - Version 0.9.337 (patch)

- Added a default-off VIP DK child setting that mutes only the fixed Riders of
  the Apocalypse horse summon sound file IDs.
- Added a default-off VIP DK child setting for a movable missing-ghoul reminder
  that uses Blizzard's `nopet` state driver and saves its own position.
- Bumped the TOC and documentation baselines to `0.9.337`.

## 2026-06-27 - Version 0.9.336 (patch)

- Added default-off VIP options for Unholy Death Knights that show red Soul
  Reaper and Putrefy warnings during the last 15 seconds before Dark
  Transformation is expected to be ready, using only the local Dark
  Transformation cast and verified actionbar spell IDs. The Settings toggles
  remain visible even when the current character is not a Death Knight.
- Bumped the TOC and documentation baselines to `0.9.336`.

## 2026-06-26 - Version 0.9.335 (patch)

- Fixed stale Mythic+ death-counter UI after dungeon completion, challenge
  abort, or party-instance exit by resetting DeathWatch on the same lifecycle
  path that clears the M+ timer and BR/BL timers, then immediately rerendering
  visible UI.
- Bumped the TOC and documentation baselines to `0.9.335`.

## 2026-06-25 - Version 0.9.334 (patch)

- Added isiLive peer sync for verified Power Infusion announces, using the
  already verified aura caster and recipient without target-based guessing.
- Fixed the Power Infusion aura path so protected/secret `spellId` values fail
  closed instead of aborting repeated `UNIT_AURA` dispatch.
- Bumped the TOC and documentation baselines to `0.9.334`.

## 2026-06-23 - Version 0.9.333 (patch)

- Added a Settings text-alert toggle for Power Infusion, default on: when
  disabled, verified PI detection remains fail-closed but the local chat line
  and local center alert stay silent.
- Added a static Power Infusion received sound for the local recipient, with a
  separate Settings toggle, English/German WAV assets, locale labels, and sound
  preview support.
- Added PI to demo mode: the full feature preview and simulation tablet can now
  trigger the local Power Infusion chat and center-alert preview through the same
  announce hook as runtime PI detection.
- Aligned the Power Infusion Settings label with the existing BR/BL chat toggles
  across all prepared locales.

## 2026-06-23 - Version 0.9.332 (patch)

- Added verified Power Infusion recipient detection from `UNIT_AURA`: local
  chat now reports the verified priest and recipient, and the local player gets
  the same red animated center alert style as the tank/healer death warning
  when they personally receive PI.
- Kept PI fail-closed: missing or non-priest aura sources do not guess a caster
  or recipient, and repeated aura updates are deduplicated.
- Tightened the PI path for raid and unresolved-name cases: raid mode does not
  process PI aura events, and missing caster/recipient names no longer fall back
  to unit tokens.
- Bumped the TOC and documentation baselines to `0.9.332`.

## 2026-06-21 - Version 0.9.331 (patch)

- Tracked the German localized spoken sound assets for release packaging, so
  the `deDE` WAV announcements are included by the git-file-based CurseForge
  and WowUp package builds.
- Uppercased the on-screen death-alert role text: German clients show
  `TANK TOT` / `HEILER TOT`, while English and fallback locales show
  `TANK DIED` / `HEALER DIED`.
- Added separate Settings toggles for muting only your own tank-death or
  healer-death WAV alert, while keeping the on-screen warning, death counters,
  and other players' tank/healer death sounds active.
- Nested those own tank/healer death sound toggles directly below their
  matching global tank/healer death sound setting and replaced the preview
  play glyph with a texture icon so WoW fonts no longer render it as a square.

## 2026-06-21 - Version 0.9.330 (patch)

- Prepared an inactive `midnight_s2` SeasonData scaffold for Midnight Season 2
  with the announced dungeon rotation, while keeping `midnight_s1` as the
  active runtime season.
- Kept the TOC interface on live WoW `120007`; 12.1.0 is only prepared and is
  not marked as the supported live interface yet.
- Added deterministic coverage that the prepared `midnight_s2` scaffold stays
  inactive and readiness-blocked until verified map IDs, portal spell IDs, LFG
  activity IDs, and forces data exist.
- Updated the README, usecase, and maintenance documentation to show the active
  Season 1 state and the prepared-but-unverified Season 2 state explicitly.
- Renamed the compact H-mode leader button labels from `CD` / `CD 0` to
  `CD10` / `CD0`, while keeping `RC` for ready checks, and updated the
  architecture sketch to match.
- Matched the compact V-mode leader button labels to H mode (`RC`, `CD10`,
  `CD0`) and hid the `Share Keys` button from the V layout.
- Removed the `M+Management` / `Marker` headers from V mode and changed the
  V-mode world markers from one vertical stack into two compact vertical
  columns with four markers each.
- Tightened the compact V-mode spacing and frame height so the action buttons
  and marker columns sit closer together with less empty panel area, then
  reduced the V frame width and action-button footprint further.
- Moved compact V-mode content into the removed header space, kept short
  leader labels stable during localization refreshes, restored a small bottom
  pad, and shifted the marker columns closer to the right edge.
- Added a Dalaran travel shortcut to the ESC Travel panel. It binds the
  Dalaran Hearthstone toy (`140192`) only when ownership is verified and
  refreshes after `TOYS_UPDATED` when the toy cache warms up.
- Fixed the German Sound settings refresh for the incoming-summon repeat
  toggle so its label and description no longer fall back to English.
- Added German static spoken WAV assets for tank death, healer death, Battle
  Res ready, and Bloodlust ready alerts. `deDE` clients now use the German
  files while English and all other client locales keep the existing English
  WAVs.
- Added a German incoming-summon announcement (`Portal_deDE.wav`,
  "Beschwoerung aktiv") for `deDE` clients while every other locale keeps the
  existing `Portal.ogg` cue.
- Audited Settings localization: prepared French, Spanish, Portuguese, Italian,
  Russian, and Turkish Settings fallbacks were translated without rewriting
  existing non-English translations, and deterministic coverage prevents
  unmarked English fallback text in prepared Settings locales.

## 2026-06-19 - Version 0.9.329 (patch)

- Added an incoming-summon reminder loop: when the local player's summon is
  verifiably pending, the `Portal.ogg` cue repeats every 5 seconds until the
  summon is accepted, declined, no longer pending, or raid suppression applies.
- Added a default-on Sound setting to disable only the incoming-summon repeat
  loop while keeping the immediate incoming-summon sound toggle separate.
- Widened the standalone Player Stats Box value column so larger live stat
  values, including Stamina rows without a percent value, stay inside the value
  column instead of clipping.
- Added deterministic coverage for the Stamina no-percent layout path and
  updated the active StatsBox rule mapping.
- Fixed architecture documentation drift by updating the architecture rules
  baseline, moving misplaced controller rows back into the controller-boundary
  table, and recording the large-module split watchlist.
- Hardened optional LFG/notice UI hooks to resolve `CreateFrame`, `C_Timer`,
  `hooksecurefunc`, and `C_Spell` through guarded `_G` lookups, with
  deterministic architecture coverage.
- Extended the optional WoW-global hardening across timer and spell lookups in
  runtime, refresh, status, demo, killtrack, teleport, and primary factory
  paths, and promoted the large-module watchlist to an active architecture
  contract.
- Hardened UI layout budgets for rich center notices, the main-frame title bar,
  the demo simulation tablet, death-alert text, and sound-preview buttons so
  long localized text and growing preview actions cannot overlap fixed controls.
- Re-applied screen clamping after demo simulation tablet height changes and
  prevented explicit rich-notice `maxHeight` values from clipping verified
  wrapped field content.
- Kept ambiguous single-struct Queue/LFG `activityIDs` unresolved instead of
  falling back to the first concrete candidate.
- Guarded the main-frame title budget against Secret-Value-masked
  `GetStringWidth()` results by routing width reads through the shared safe
  FontString measurement helper.
- Tightened the main-frame title bar fallback budgets and compacted the title
  row so the addon title no longer pushes the version label away, the full
  version stays readable next to the BETA badge, and the row aligns with the
  M+/H/V mode buttons.
- Moved the M+/H/V mode buttons into the right title-bar button group and gave
  them the same framed warm-gold title-bar chrome as settings, lock, and close.
- Hid the standalone Stats Box value/percent separator while keeping the value
  and percent columns aligned.
- Suppressed Bloodlust-ready announcements after challenge aborts even when the
  local M+ timer snapshot is still stale-running during the aura removal refresh.
- Ran the full local CI preflight after the 0.9.329 audit/fix pass; final
  result: `Local CI preflight passed`, with `2082` usecase scenarios passing.
- Registered `docs/CURSEFORGE_OVERVIEW.md` as a maintained project document.
- Bumped the TOC and documentation baselines to `0.9.329`.

## 2026-06-19 - Version 0.9.328 (patch)

- Removed the Raid LFG accepted-invite center notice, so Raid accepts no
  longer show an irrelevant `Unknown dungeon` message.
- Restored the main window after leaving raid mode only when raid mode hid an
  already-visible window; windows that were already closed stay closed.
- Updated the CurseForge overview, README, architecture, usecase, and release
  documentation baselines to `0.9.328`.

## 2026-06-19 - Version 0.9.327 (patch)

- Refreshed the README overview for addon listing use with a clearer Mythic+
  command-center positioning, colorful feature signals, stronger user-facing
  highlights, and a screenshot section for the main tool surfaces.
- Updated the release documentation baseline to `0.9.327`.

## 2026-06-18 - Version 0.9.326 (patch)

- Converted `BttF_Tinkle.wav` from stereo to mono while keeping it as a
  44.1 kHz 16-bit PCM WAV, reducing the ready-check-complete asset size.
- Added `RoosterChickenCalls.ogg` to the tracked sound whitelist so the
  Battle Res alert fallback asset is packaged with releases.
- Fixed Bloodlust-ready reminders continuing outside dungeons after leaving a
  party instance by resetting stale Mythic+ timer and BR/BL ready-sound state.
- Removed the older WoW 12.0.5 TOC compatibility marker; isiLive now targets
  the live 12.0.7 interface only.
- Updated deterministic packaging coverage so packaged sound fallback assets
  must stay trackable through `.gitignore`.
- Renamed the player-hover group-bonus tooltip prefix from `isiLive Bonus` to
  neutral group-bonus wording.
- Bumped the TOC and documentation baselines to `0.9.326`.

## 2026-06-17 - Version 0.9.325 (patch)

- Listed both supported Retail TOC interfaces, `120005` and `120007`, so
  isiLive remains loadable on WoW 12.0.5 clients while also being marked
  compatible with WoW 12.0.7.
- Added the active Mythic+ death count directly behind the active dungeon/key
  name in the M+ killtracker row and reset the DeathWatch visible counters on
  the same completion/reset boundaries as the M+ and BR/BL timers.
- Suppressed Bloodlust-ready and Battle-Res-ready alerts on party-instance
  entry refreshes without resetting an already active Mythic+ timer.
- Added the concrete class buff behind roster green-heart markers to the
  player mouseover tooltip, for example `+2% Mastery`, and included BR/BL
  there without counting them as green-heart markers.
- Updated the stable Release workflow to translate comma-separated TOC
  interfaces into multiple CurseForge `gameVersionNames`.
- Bumped the TOC and documentation baselines to `0.9.325`.

## 2026-06-16 - Version 0.9.323 (patch)

- Bumped the TOC interface to `120007` for WoW 12.0.7 compatibility.
- Bumped the TOC and documentation baselines to `0.9.323`.

## 2026-06-16 - Version 0.9.322 (patch)

- Disabled the native WoW text-to-speech path (`C_VoiceChat.SpeakText`) and
  removed the spoken-alert settings from the Sounds panel.
- Death-alert audio now uses only the bundled static WAV files for tank and
  healer deaths; damage-dealer deaths remain tracked but do not play audio
  without a bundled WAV asset.
- Death-alert role announcements now drop immediate duplicate tank or healer
  callbacks, so `Tank died` and `Healer died` each fire only once per direct
  repeated role event.
- Temporarily disabled the shared same-sound spam window so death-WAV playback
  can be tested without duplicate suppression.
- Normalized `TankDied.wav` and `HealerDied.wav` to louder 44.1 kHz 16-bit PCM
  assets and pinned that format in deterministic coverage.
- Added a narrow Tank/Healer death-sound diagnostic that reports the
  `PlaySoundFile` failure reason, channel, and asset path when the red on-screen
  warning appears but the WAV cannot be started.
- Split the death-alert sound settings into separate Tank died and Healer died
  WAV toggles while keeping the visual death-alert gate unchanged.
- Trimmed `TankDied.wav` and `HealerDied.wav` to a single spoken announcement
  so the sound preview and runtime alert no longer repeat the phrase from one
  file playback.
- Fixed accepted-invite target-dungeon chat so it uses the same verified LFG
  listing level as the Center Notice instead of waiting for later roster or
  sync state that can surface a different key level.
- Hardened accepted-invite target resolution so a new accepted `mapID` cannot
  be paired with a stale `latestQueueDungeonName` from a previous queue/listing
  context, preventing duplicate chat output where the first line names the old
  dungeon.
- The validator baseline is now `2060` scenarios.
- Bumped the TOC and documentation baselines to `0.9.322`.

## 2026-06-14 - Version 0.9.321 (patch)

- Paused spoken death TTS for 30 seconds after two different players die in
  consecutive DeathWatch death edges. The second death starts the pause
  immediately, later deaths during the fixed window do not extend it, and
  tank/healer on-screen warnings still render.
- Added deterministic coverage for the DeathWatch burst pause and the factory
  path that suppresses paused TTS without falling back to a recorded WAV when
  spoken alerts are enabled.
- Restored the framed `+3` / `+2` / `+1` M+ timer badges with enough width to
  avoid `...`, widened the timer value slots for five-character times, and
  moved the visible death-time penalty from the M+ timer row into the skull
  tooltip.
- Damage-dealer spoken death alerts now announce the resolved class by default
  (for example `Hunter died`) and the local player's own death no longer
  produces a spoken TTS alert.
- Spoken death-alert modifiers now default player-name announcements to off,
  and the player-name and class-name toggles are mutually exclusive in settings
  and runtime fallback handling.
- The validator baseline is now `2064` scenarios.
- Bumped the TOC and documentation baselines to `0.9.321`.

## 2026-06-13 - Version 0.9.320 (patch)

- Added a hover tooltip to the skull in the M+ timer row. It now lists tracked
  per-player deaths as `Name Count`, sorted alphabetically by player name.
- Added deterministic coverage for the M+ skull death-breakdown ordering.
- The validator baseline is now `2058` scenarios.
- Bumped the TOC and documentation baselines to `0.9.320`.

## 2026-06-13 - Version 0.9.319 (patch)

- Added per-player Mythic+ death tracking from the existing DeathWatch path.
  Players with tracked deaths now get a skull marker next to their roster name;
  repeated deaths show the count, and the row tooltip shows the exact total.
- Death counts stay visible after key completion, key abort, and group leave on
  existing active or ghost roster rows until a new key starts or the UI reloads.
- Added deterministic coverage for DeathWatch count lifetime, suppressed DPS
  TTS deaths still incrementing the counter, roster skull markers, and tooltip
  death totals.
- The validator baseline is now `2057` scenarios.
- Bumped the TOC and documentation baselines to `0.9.319`.

## 2026-06-13 - Version 0.9.318 (patch)

- Reset visible M+ utility timers on key completion or abort: the M+ timer
  snapshot, Battle Res cooldown display, and Bloodlust cooldown display now
  return to placeholders immediately and stay reset while no key is running.
- Added deterministic coverage for CD tracker runtime clearing, challenge
  lifecycle reset options, and visible out-of-key BR/BL rescan suppression.
- The validator baseline is now `2053` scenarios.
- Bumped the TOC and documentation baselines to `0.9.318`.

## 2026-06-13 - Version 0.9.317 (patch)

- Suppressed damage-dealer spoken death alerts once both the tank and healer
  are already dead, while keeping the tank/healer alerts and earlier DPS TTS
  announcements intact.
- Added deterministic DeathWatch coverage for the tank-dead plus healer-dead
  DPS suppression path.
- The validator baseline is now `2051` scenarios.
- Bumped the TOC and documentation baselines to `0.9.317`.

## 2026-06-13 - Version 0.9.316 (patch)

- Removed Spanish, Portuguese, and Italian from the Settings language selector
  while keeping the prepared locale tables and realm-language flag handling
  available for validation and display paths.
- Shortened the German Settings default-layout `Last Used` button label to
  `Zuletzt`.
- Fixed the Settings nameplate preview so its overlay frame and text stay
  parented inside the Settings panel instead of being reparented to `UIParent`.
- Added deterministic Settings coverage for the reduced language selector.
- The validator baseline is now `2050` scenarios.
- Bumped the TOC and documentation baselines to `0.9.316`.

## 2026-06-13 - Version 0.9.315 (patch)

- Demo mode exit now stops active preview sound handles and active TTS playback
  immediately via the shared sound registry stop helper.
- Added a dedicated local incoming-summon sound button to the demo simulation
  tablet and strengthened deterministic coverage for the group-full, tank-dead,
  healer-dead, incoming-summon, and cleanup paths.
- The validator baseline is now `2049` scenarios.
- Bumped the TOC and documentation baselines to `0.9.315`.

## 2026-06-13 - Version 0.9.314 (patch)

- Fixed the demo simulation tablet hover tooltips mutating the hovered button
  into a tooltip frame, which could resize or visually hide the button under
  the cursor.
- Added deterministic coverage proving simulator hover uses the dedicated
  private tooltip frame and leaves button dimensions untouched; the validator
  baseline is now `2048` scenarios.
- Bumped the TOC and documentation baselines to `0.9.314`.

## 2026-06-13 - Version 0.9.313 (patch)

- Added a movable demo simulation tablet that appears during `/isilive testall`
  and can also be toggled with `/isilive sim`.
- The tablet exposes local preview buttons for accepted-invite notices, group
  full simulation, joined-target notices, non-Mythic dungeon warnings,
  ready-check states, M+ timer / kill tracker data, combat cooldowns, portal
  navigator, nameplate forces, Share Keys cooldown, death alerts, sound / TTS,
  stats box, LFG bonus markers, and cleanup.
- Added an Ampel-style status dot to every simulator button. Red entries are
  visible no-ops for rule-blocked flows such as the removed pre-accept invite
  hint; simulator buttons never send real chat posts or group actions.
- Added deterministic coverage for the tablet UI, `/isilive sim`, and the
  `testall` show / exit hide contract. Updated rule 57 and the demo usecase;
  the validator baseline is now `2047` scenarios.
- Bumped the TOC and documentation baselines to `0.9.313`.

## 2026-06-13 - Version 0.9.312 (patch)

- Fixed the Share Keys button flickering between its cooldown label and the
  plain button label while a lock is active. Localization and layout refreshes
  now re-render the active cooldown text instead of overwriting it.
- Added deterministic coverage for the cooldown label surviving localization
  and layout refreshes, and mapped it to the Share Keys spam-protection rule.
- Bumped the TOC and documentation baselines to `0.9.312`.

## 2026-06-13 - Version 0.9.311 (patch)

- Expanded demo mode so the full preview also exercises the recent sound and
  alert surfaces: ready-check hold row colors, a mirrored Share Keys cooldown,
  the tank death-alert preview, the damage-dealer TTS-only death path, the
  ready-check-complete sound, and the spoken TTS preview.
- Demo mode now temporarily enables the related sound / TTS preview settings
  and restores the user's previous values on exit, matching the existing
  temporary handling for notice and display demo settings.
- Added cleanup for the demo Share Keys cooldown so leaving demo mode does not
  leave the live button in a preview lock.
- Updated `RULES_LOGIC` rule 57 and `USECASES.md` so the demo-mode contract
  covers the new preview surfaces; the validator baseline remains `2042`
  scenarios.
- Bumped the TOC and documentation baselines to `0.9.311`.

## 2026-06-13 - Version 0.9.310 (patch)

- Added optional spoken (text-to-speech) death alerts: a new Sounds toggle
  (`ttsAnnouncementsEnabled`, default off) speaks the death alert through your
  system text-to-speech voice (`C_VoiceChat.SpeakText`) instead of playing the
  recorded sound file. It follows your Blizzard accessibility voice and speech
  rate and therefore bypasses the Master / Sound Effects channel, fails closed
  to the recorded file when no system voice is available, and obeys the same
  one-second spam window as the other cues.
- Added two spoken-alert modifiers: "say the player name" (`ttsAnnounceName`,
  default on) includes the player name, and "say the class" (`ttsAnnounceClass`,
  default off) announces the class (for example "Hunter died") instead of the
  group role. With names off the alert is role/class only (for example "Tank
  died").
- Extended spoken death alerts to damage dealers. Detection now fires for tank,
  healer and damage dealers, but the big red on-screen warning stays limited to
  tank and healer and always shows the role-only text without a name. A
  damage-dealer death produces a spoken announcement only (there is no recorded
  file for it, so it stays silent when spoken alerts are off).
- Updated `RULES_LOGIC` rule 80 (on-screen warning limited to tank/healer,
  detection covers damage dealers) and rule 83 (spoken-alert name/class
  contract); the validator baseline is now `2042` scenarios.
- Bumped the TOC and documentation baselines to `0.9.310`.

## 2026-06-12 - Version 0.9.309 (patch)

- Fixed the share-keys button being stuck in an endless cooldown loop. Two
  clients used to answer each other's hello-ack fan-outs forever (the
  fan-out hello bypasses the 8 s rate limit), backing up the addon-message
  send queue by ~30 seconds; the stale mirrored `SKCD` locks then kept
  re-locking the button right after its own cooldown expired. Incoming
  HELLOs with source `hello-ack` / `reqsync-ack` no longer trigger another
  ack fan-out (the join bootstrap is unaffected: the joiner broadcasts its
  own snapshot and a delayed sync request itself).
- The share-keys cooldown mirror now only broadcasts locally owned locks
  (own click or a received share-keys request). A lock that was itself set
  or extended by a peer's `SKCD` mirror loses local ownership and is never
  re-broadcast, so the lock can no longer reflect between clients.
- Added `RULES_LOGIC` rule 82 (hello-ack loop breaker) and extended rule 53
  with the SKCD ownership contract; both are pinned by new deterministic
  scenarios, including an end-to-end sender-receiver reflection test across
  the real wiring and buttons.
- Added the ready-check-complete sound: `BttF_Tinkle.wav` plays once when all
  five valid ready-check participants are marked ready during an active
  ready-check.
- Added a Sounds settings toggle and preview button for the new ready-check
  completion sound; it follows the configured `Master` / `SFX` sound output
  channel.
- Added the tank / healer death alert: a big red frameless on-screen warning
  ("Tank died" / "Healer died") with a scale-punch animation and a sound
  alert fires when the tank or the healer dies during an active M+ run. The
  local player's own death alerts as well.
- Death detection is edge-triggered per GUID via `UNIT_HEALTH` for the player
  and party1-4: exactly one alert per death, a revive re-arms the edge,
  challenge lifecycle events reset the flags, and roster updates drop flags of
  departed players. DPS deaths, disconnects, and out-of-key states stay
  silent; raid mode keeps the whole path suppressed.
- Added the death-alert sound assets `TankDied.wav` / `HealerDied.wav` to the
  sound registry on the `Master` channel; a single new settings toggle in the
  Sounds section (`deathAlertEnabled`, default on) gates the on-screen text and
  both sound files together, with a preview button.
- Split the locale string tables into per-language files
  (`locale/isiLive_texts_<tag>.lua` plus shared common blocks in
  `locale/isiLive_texts_common.lua`); `locale/isiLive_texts.lua` is now a slim
  aggregator with a standalone loadfile fallback for the locale tools. The
  drift, dead-keys, format-consistency, and button-label gates plus the test
  harness follow the new layout.
- Added `RULES_LOGIC` rule 80 with twelve deterministic death-alert scenarios
  and rule 81 for the ready-check-complete sound gate.
- Bumped the TOC and documentation baselines to `0.9.309`.

## 2026-06-11 - Version 0.9.308 (patch)

- Added roster buff-rating hearts: roster names now show the same compact green
  class-bonus markers as Group Finder rows when a verified roster class/spec
  provides relevant non-utility buffs for the current character.
- Reused the existing Group Finder buff-rating setting for roster hearts and
  refresh the roster immediately when the setting is toggled.
- Added deterministic coverage for roster heart rendering and the disabled
  setting path.
- Hid the Re-Sync button in the compact vertical `V` layout while keeping it
  available in the other layouts.
- Bumped the TOC and documentation baselines to `0.9.308`.
- Updated the release-gate scenario baseline to `2001` deterministic scenarios.

## 2026-06-11 - Version 0.9.307 (patch)

- Hardened the kick tracker cooldown chain: observed local interrupt casts now
  reconcile against exact Blizzard cooldown data after the cast event, so
  talent- and pet-sensitive cooldowns can be refined without waiting for the
  next broad cooldown refresh.
- Kept the fail-closed behavior for early cooldown reads: an inactive or not
  yet updated exact cooldown payload no longer clears an already observed kick
  cooldown.
- Added deterministic coverage for observed-cast cooldown refinement, early
  inactive cooldown reads, and the factory post-cast reconcile path.

## 2026-06-11 - Version 0.9.306 (patch)

- Added group-wide mirroring of the Share Keys button cooldown: peers with a
  running lock announce the remaining seconds as a new `SKCD:<remain>` sync
  payload during the hello-ack / REQSYNC state fan-out, so freshly joined
  group members start with the same lock instead of immediately re-triggering
  a redundant `SHAREKEYS` wave.
- Receivers apply mirrored locks with max-merge semantics: a remote remaining
  time can extend the local lock but never shorten it, and is clamped to the
  local 30s debounce window. Older clients ignore the unknown payload, so the
  sync protocol version stays at `2`.
- Closed the click-path double-post gap: the share-keys response path now also
  honours the running button cooldown, so an incoming `SHAREKEYS` shortly
  after a local click no longer re-posts the own keystone a second time.
- Added deterministic coverage for the SKCD sender, parser (clamping and
  self-echo), runtime fan-out, button max-merge, and an end-to-end
  sender-to-receiver wire-bytes chain; extended active rule 53 accordingly.
- Added `tools/simulate_ctl_wire_order.lua`: drives the share-keys click
  sequence through the real embedded ChatThrottleLib (not a mock) and pins the
  wire order on idle and congested networks — synchronous SHAREKEYS-first on
  idle, chat-line-first inversion under congestion (cosmetic only, the
  receiver chain is order-independent), ALERT overtaking foreign BULK backlog,
  and FIFO inside the ISILIVE pipe.
- Bumped the TOC and documentation baselines to `0.9.306`.
- Updated the release-gate scenario baseline to `1996` deterministic scenarios.

## 2026-06-10 - Version 0.9.305 (patch)

- Fixed ESC Addons shortcuts so Blizzard's character-scoped enabled state
  (`Some` / state `1`) counts as active only after isiLive verifies and passes
  the current character to the enable-state query.
- Kept global `Some` enable-state values fail-closed without a concrete
  current-character source.
- Added deterministic regression coverage for character-scoped ESC Addons
  shortcut visibility and slash dispatch.
- Bumped the TOC and documentation baselines to `0.9.305`.
- Updated the release-gate scenario baseline to `1984` deterministic scenarios.

## 2026-06-10 - Version 0.9.304 (patch)

- Added a Sound output channel selector to the Settings sound section. Built-in
  isiLive alerts continue to default to `Master`, and users can explicitly
  switch them to `SFX`.
- Added `soundOutputChannel` schema validation with fail-closed fallback to
  `Master` for invalid values.
- Updated the sound-channel gate so hard-coded `SFX` playback remains blocked
  while the persisted user setting is allowed.
- Added localized Sound settings text for all prepared locale tables.
- Added active rule 78 for selectable sound-channel behavior and deterministic
  coverage for SoundUtils routing, Settings persistence, Locale strings, and DB
  schema validation.
- Fixed the factory/runtime wiring so the `ADDON_LOADED` SavedVariables
  re-apply path calls the real `ApplyDBSettings` callback instead of a
  file-load-time no-op, and pinned that reload path with active rule 79.
- Fixed the M+ forces nameplate Settings preview so re-enabling the nameplate
  display mode restores the unchanged percent text immediately instead of
  waiting for another option, such as remaining-needed, to change the rendered
  text.
- Fixed the Share Keys sender chain so the lightweight `SHAREKEYS` addon
  request is dispatched before the visible own-key group chat line, preventing
  the local chat post from getting ahead of peer cooldown/reply coordination.
- Documented the live-log diagnosis: receiver handling was already healthy
  when Bircan triggered the share, while the failing local/Aby clicks only
  proved local dispatch acceptance and own chat output, with no observed
  `SHAREKEYS` self-echo or peer reply in the captured logs.
- Added button-level Share Keys trace output and deterministic coverage for the
  dispatch-before-chat ordering.
- Allowed `sounds/Portal.ogg` through the repository sound whitelist so the
  incoming-summon sound asset is tracked and included in the shared WowUp and
  CurseForge release ZIP.
- Added deterministic architecture coverage that keeps the Portal sound
  trackable, matching the release workflow's `git ls-files` packaging source.
- Bumped the TOC and documentation baselines to `0.9.304`.
- Updated the release-gate scenario baseline to `1983` deterministic scenarios.

## 2026-06-09 - Version 0.9.303 (patch)

- Disabled the isiLive AddOn sync send channel while `IsInRaid()` is active,
  so Share Keys and all other isiLive sync buckets fail closed in raid groups
  instead of resolving a raid transport channel.
- Kept Share Keys on ChatThrottleLib `ALERT` priority for the supported
  non-raid channels, with `INSTANCE_CHAT` preferred inside instance groups
  and `PARTY` used for normal groups.
- Added deterministic coverage for the full Share Keys sender/receiver chain:
  button click, local chat output, `SHAREKEYS` dispatch, receiver processing,
  receiver chat output, remote cooldown, and runtime trace logging.
- Added raid transport regression coverage proving the sync channel resolves
  to `nil` in raids and `Sync.SendShareKeysRequest()` does not publish there.
- Bumped the TOC and documentation baselines to `0.9.303`.
- Updated the release-gate scenario baseline to `1977` deterministic scenarios.

## 2026-06-08 - Version 0.9.302 (patch)

- Fixed ESC Addons shortcuts so external addon slash handlers run only after
  the Game Menu is observed closed, and mirror Blizzard's slash dispatch
  signature by passing the default chat edit box to verified handlers.
- Added deterministic coverage that the close-before-slash path is shared by
  supported external addons, not only SimC.
- Bumped the TOC and documentation baselines to `0.9.302`.
- Updated the release-gate scenario baseline to `1973` deterministic scenarios.

## 2026-06-08 - Version 0.9.301 (patch)

- Removed all root-level repository screenshot PNGs from both release package
  paths: CurseForge `.pkgmeta` and the GitHub/WowUp release ZIP builder now
  exclude the same screenshot asset set.
- Added deterministic architecture coverage that compares the CurseForge and
  WowUp package exclusion lists, so future package-content changes must keep
  both release artifacts aligned.
- Added active rule 77 documenting that CurseForge and WowUp packages must
  contain the same shipped addon content, with technical build-only metadata
  allowed to differ only when it is not part of the user package.
- Bumped the TOC and documentation baselines to `0.9.301`.
- Updated the release-gate scenario baseline to `1970` deterministic scenarios.

## 2026-06-07 - Version 0.9.300 (patch)

- Hardened all external ESC Addons shortcuts against slower late slash-handler
  registration after a verified addon load by retrying the exact registered
  alias across a bounded short window, while still avoiding chat-edit fallbacks
  or guessed internals.
- Added a Sound setting for disabling the 60-second Bloodlust-ready reminder
  loop while keeping the first Bloodlust-ready alert independently controlled;
  the reminder loop remains enabled by default and is covered by deterministic
  runtime and Settings tests.
- Suppressed Lua language-server diagnostics in the local LuaFileSystem
  compatibility shim for validation tooling without changing addon runtime
  behavior.

## 2026-06-07 - Version 0.9.299 (patch)

- Reorganized the Blizzard Settings panel into clearer thematic sections:
  Beta notice first, then General, ESC Menu, Display, Behavior, Nameplates,
  Sounds, Chat Announcements, Administrative, and VIP Guest Settings last.
- Moved ESC shortcut and Hearthstone controls into their own ESC Menu block.
- Moved Portal Navigator from General into Display extras, next to the minimap
  button, and added a thin separator before the Group Finder display controls.
- Moved Blizzard Advanced Combat Logging and Damage Meter reset toggles from
  General into Administrative, ahead of the debug-log controls.
- Updated English and German Settings section hints for the new grouping while
  keeping locale keys aligned across all prepared locale tables.
- Added deterministic coverage for the Settings section order.

## 2026-06-03 - Version 0.9.298 (patch)

- Fixed roster role assignment after inspected spec changes by deriving a
  verified role from Blizzard's inspected specialization role API, so specs
  like Retribution render as DPS and Blood renders as tank even when
  `UnitGroupRolesAssigned` is stale.
- Aligned center notice layers with the main M+ UI frame and removed the
  Portal Navigator's hard `DIALOG` strata, so all isiLive center windows share
  the same UI layer basis.
- Restyled the Portal Navigator header to match the rich center notice cards:
  `Portal - Navigation` cyan eyebrow, larger left-aligned
  `isiLive - Midnight Season One M+ Navigator` gold headline, and blue
  separator.
- Fixed the demo-mode Portal Navigator layout so it passes the same blue
  eyebrow and season title as the live navigator layout.
- Moved the Portal Navigator header separator and portal crescent downward so
  the blue line no longer intersects the larger gold season title.
- Fixed M+ forces percentage anchoring with Platynator by resolving the
  visible Platynator health widget on the real nameplate before falling back to
  Blizzard `UnitFrame.healthBar`, so the Settings preview and live runtime use
  the same anchor semantics.
- Pinned Plater anchoring through Plater-style `unitFrame.healthBar`, matching
  Plater's documented unit-frame member path.
- Added nameplate diagnostics for the selected runtime anchor source, including
  the Platynator health-widget path.
- Bumped the TOC and documentation baselines to `0.9.298`.

## 2026-06-02 - Version 0.9.297 (patch)

- Fixed in-key BR/Bloodlust peer announcements by allowing `CHAT_MSG_ADDON`
  sync payloads through the combat event gate, so incoming `BRLUST` messages
  are no longer dropped during active pulls.
- Fixed the local BR/Bloodlust sender path by using the running M+ timer as a
  verified in-key source when the active challenge map API is masked, and by
  treating owned pet Bloodlust casts as the local player's announcement.
- Stabilized M+ forces nameplate percentage anchoring by rendering the overlay
  above the plate level and enforcing a small edge gap even when the saved X/Y
  offsets are zero.
- Restored the M+ forces nameplate default to the compact per-mob percentage
  only; the remaining-needed suffix is now opt-in again and existing default
  values migrate back to the compact display.
- Fixed M+ forces nameplate size and position settings under external
  nameplate addons by anchoring to an observed healthbar child when available
  while keeping the overlay independent from external nameplate scaling.
- Hardened the Battle Res combat sound path with a verified separate
  `RoosterChickenCalls.ogg` fallback if WoW rejects the primary BR asset,
  while keeping the working Bloodlust sound path on `BoxingArenaSound.ogg`.
- Fixed Battle Res-ready detection by scanning directly observed known BR spell
  IDs instead of only Rebirth, and by triggering the ready TTS once when the
  displayed BR charge count increases.
- Reworked Bloodlust-ready detection around the CD row display transition:
  after an in-key Bloodlust countdown expires, the row now stays on `00:00`
  instead of falling back to `BL: --`, and the ready TTS follows that displayed
  ready transition. `BL: --` is reserved for missing context such as no running
  key, no group, or an explicit reset/key-end discard.

## 2026-06-02 - Version 0.9.296 (patch)

- Refreshed the README feature highlights and expanded the Group Finder
  buff-rating hearts section with the player-aware relevance and dedup rules.
- Added a stable-release GitHub asset ZIP for WowUp Hub with the required
  top-level `isiLive/` folder while leaving Wago publishing manual.
- Moved the GitHub release asset upload before the CurseForge auto-packager
  trigger and added short CurseForge trigger retries, so WowUp publishing is
  not blocked by a transient CurseForge trigger response.
- Replaced the legacy CurseForge remote packager trigger with a direct
  BigWigs packager upload using the official CurseForge upload API route, so
  GitHub Actions no longer depends on the Cloudflare-blocked website trigger.
- Replaced the BigWigs CurseForge upload step with a direct upload of the
  already-built release ZIP, including explicit CurseForge `gameVersionNames`
  metadata derived from the TOC interface version.
- Restored the stable `Release` workflow to tag-push-only triggering, so
  GitHub Actions lists stable release runs under the `isiLive_release_*` tag
  again instead of `main`.
- Bumped the TOC and documentation version basis to `0.9.296`.
- Updated the release-gate scenario baseline to `1938` deterministic scenarios.

## 2026-06-02 - Version 0.9.295 (patch)

- Clarified internal leader-hint comments so they no longer imply that the
  played key must belong to the group leader; the runtime still treats leader
  state only as a verified disambiguation hint and fails closed otherwise.
- Removed one stale tooltip-only regression test for the long-deprecated
  `Runs together` row; the bounded stats persistence contract remains covered
  by the direct DB/statistics scenarios, and the current validator baseline is
  `1938` deterministic scenarios.
- Audited the active logic and architecture contracts, then completed the
  `ARCHITECTURE.md`
  active-contract list for all 11 enforced architecture rules.
- Removed the dormant pre-accept LFG invite-hint frame, its dead frame-bridge
  surface, the stale standalone simulator, and the helper-only branch tests;
  the active accepted-invite and group-join Center Notice paths remain covered.
- Audited the full Share Keys chain and corrected the standalone addon-message
  throttle simulator to expect the current `SHAREKEYS` `ALERT` priority.
- Bumped the TOC and documentation version basis to `0.9.295`.
- Updated the release-gate scenario baseline to `1938` deterministic scenarios.

## 2026-06-02 - Version 0.9.294 (patch)

- Restored Battle-Res-ready and Bloodlust-ready alerts by wiring the production
  factory context to the live group-state source used by the ready-sound gate.
- Kept M+ forces nameplate percentages rendering from bundled DB data when the
  ScenarioInfo progress API is unavailable; ScenarioInfo remains fallback-only.
- Fixed M+ forces nameplate placement so RIGHT/LEFT positions align the text
  directly beside the health bar instead of centering it inside the overlay
  frame, which pushed larger values away from the plate.
- Bumped the TOC and documentation version basis to `0.9.294`.
- Updated the release-gate scenario baseline to `1938` deterministic scenarios.

## 2026-06-01 - Version 0.9.293 (patch)

- Suppressed Bloodlust-ready and Battle-Res-ready sound cycles after leaving the
  group, even if the local Mythic+ timer still reports a stale running state,
  so Bloodlust-ready reminders no longer repeat every 60 seconds while solo.
- Suppressed queued `INSTANCE_CHAT` addon-sync dispatches after leaving an
  instance group, preventing repeated Blizzard "not in a group" system messages
  from delayed ChatThrottleLib sends.
- Bumped the TOC and documentation version basis to `0.9.293`.
- Updated the release-gate scenario baseline to `1948` deterministic scenarios.

## 2026-06-01 - Version 0.9.292 (patch)

- Fixed the M+ forces nameplate percentage font size after WoW or an internal
  nameplate refresh reasserted the inherited FontObject height. The render path
  now verifies the actual FontString height before trusting the dirty cache, so
  the configured nameplate font-size setting is restored without requiring a
  reload.
- Changed the StatsBox durability row default to off, so visible refreshes skip
  durability API reads unless the user enables that detail row.
- Added a subtle value/percent separator, stronger primary-stat highlight,
  unlocked hover affordance, and stat-colored row tint backgrounds to the
  borderless StatsBox while keeping the fixed palette and stable column layout.
- Localized only the sound-settings labels and descriptions for the prepared
  `frFR`, `esES`, `ptBR`, `itIT`, `ruRU`, and `trTR` locale tables; other
  prepared-locale areas may still intentionally use English fallback text.
- Removed the pre-accept LFG invite hint window, including its settings toggle,
  SavedVariable default, factory wiring, and ingame demo preview, while keeping
  the accepted-invite and group-join target Center Notices.
- Bumped the TOC and documentation version basis to `0.9.292`.
- Updated the release-gate scenario baseline to `1946` deterministic scenarios.

## 2026-05-31 - Version 0.9.291 (patch)

- Added a separate default-enabled `Sound: Battle Res Ready` alert that plays
  the new `sounds/BattleRezReady.wav` TTS asset once when Battle Resurrection
  recovers from zero available charges.
- Added a separate default-enabled `Sound: Bloodlust Ready` alert that plays
  the new `sounds/BloodlustReady.wav` TTS asset once when the observed
  Bloodlust/Heroism/Time Warp exhaustion aura expires.
- Suppressed Bloodlust-ready and Battle-Res-ready TTS cycles during
  key-end/key-abort CD refreshes so later world or zone refreshes cannot
  announce stale readiness.
- Kept event-driven Bloodlust-ready and Battle-Res-ready refreshes active while
  the main UI is hidden, without enabling the hidden CD polling ticker.
- Fixed Bloodlust-ready expiry detection for visible in-key play by scanning
  `UNIT_AURA` removal payloads that no longer carry a stable `spellId`.
- Fixed in-key ready announcements to fire from the observed tracker countdown:
  Bloodlust-ready now sees an already-observed aura tick down to zero, and
  Battle-Res-ready can fire when the displayed BRes cooldown reaches zero even
  before a later charge refresh.
- Re-rendered the ready TTS assets with a louder normalized English voice; the
  Battle-Res-ready file now uses the phonetic `Battleretz ready!` prompt for a
  clearer in-game pronunciation.
- Routed visible combat-utility UI rescans through the same CD-tracker
  transition path as the ready alerts, so the displayed Battle-Res cooldown
  reaching zero can trigger the Battle-Res-ready TTS during the key.
- Kept the first available Battle-Res state directly after key start silent,
  then announced every later observed Battle-Res recovery.
- Added Bloodlust-ready reminders every 60 seconds while Bloodlust remains
  unused after the first ready TTS.
- Disarmed Bloodlust-ready reminders and Battle-Res-ready transitions whenever
  the M+ timer is no longer running, so key-end or dungeon-leave refreshes
  cannot start delayed ready announcements.
- Routed isiLive sound playback through the `Master` audio channel, matching
  DBM's configured alert channel and making the ready TTS alerts less dependent
  on a low Sound Effects slider.
- Added Play buttons beside every sound setting so users can preview each
  configured audio cue without changing whether that cue is enabled.
- Suppressed the accepted-invite/group-join Center Notice after `/reload` when
  the current group matches the verified reload roster mirror.
- The accepted-invite/group-join Center Notice now appends an exact `+N` from
  the verified LFG group title to the dungeon row when no separate key level
  was available.
- Renamed the accepted-invite/group-join notice row from `Group` to `Title`,
  matching the raw LFG listing title shown in that field.
- Bumped the TOC and documentation version basis to `0.9.291`.
- Updated the release-gate scenario baseline to `1942` deterministic scenarios.

## 2026-05-30 - Version 0.9.290 (patch)

### UI

- Bumped the TOC and documentation version basis to `0.9.290`.
- Fixed Cyrillic LFG leader names in Center Notice payload fields by switching
  affected FontStrings to the WoW Cyrillic-capable font when the concrete text
  contains Cyrillic UTF-8 bytes, independent of the configured addon locale.
- Restored the recorded baseline font for reused dynamic FontStrings once a
  later payload no longer contains Cyrillic text.
- Extended the same readable-font path to addon-owned roster rows, private
  tooltips, teleport empty-state text, and killtracker dungeon labels while
  leaving Blizzard-owned windows untouched.
- Modernized the pre-accept `isiLiveInviteHintFrame` into the same info-card
  visual language and now renders verified Dungeon, Group, Leader, and Source
  rows for the currently visible `LFGListInviteDialog`.
- Added the modern `isiLiveInviteHintFrame` to the ingame demo preview with
  fixed demo Dungeon, Group, Leader, and Source rows and demo-exit cleanup.
- Kept the demo `isiLiveInviteHintFrame` on a fixed high-priority demo anchor
  so it is not reanchored under live fallback frames or covered by other demo
  notices.
- Enlarged the center-notice portal button status text so the ready `Portal`
  label and active cooldown timer remain readable over dungeon icons.
- Removed the redundant `BL:` prefix from the active Bloodlust tracker countdown
  so the combat utility row mirrors the compact Battle Res timer style.
- Added the started keystone level beside the active dungeon name on the lower
  M+ killtracker row, sourced only from `MplusTimer`'s started-key snapshot.
- Refreshed the lower M+ killtracker row immediately when demo mode injects its
  active key preview, so the demo also shows the dungeon plus started key level.
- Reset the visible M+ timer row immediately on `CHALLENGE_MODE_COMPLETED` and
  `CHALLENGE_MODE_RESET`, including a direct CD-tracker refresh so completed or
  aborted keys cannot leave stale timer values on screen.
- Added language flags to LFG applicant rows, sourced from the concrete
  applicant member realm, and hid the flag when that source is unresolved.
- Restored the applicant name anchor whenever a reusable Blizzard applicant row
  loses its language flag, and allowed applicant flags to render from a parent
  texture owner when the member row itself cannot create textures.
- Moved applicant buff-rating hearts to the right of the class badge so they
  do not sit under Blizzard's badge artwork.
- Forced applicant buff-rating hearts to render only as real textures from
  `media/heart_bonus_green.tga`, removing the old FontString texture-markup
  fallback that could display the wrong symbol in Blizzard applicant rows.
- Fixed visible LFG applicant rows that exposed `button.Members` without
  reliably firing the global member-update hook, so green bonus-heart textures
  are applied directly from the hooked applicant button.
- Fixed applicant bonus-heart textures being clipped in Blizzard layouts where
  the role icon sits outside the member-name frame by anchoring fallback markers
  to the visible name field instead of the role column.
- Resolved localized applicant class names through Blizzard's class-name tables
  so bonus hearts still render when `GetApplicantMemberInfo` returns localized
  class text instead of an English class token.
- Extended the active Cyrillic-font, killtracker keylevel, and M+-timer reset
  rule coverage, added applicant-row LFG coverage, and updated the release-gate
  baseline to `1918` deterministic scenarios.

## 2026-05-29 - Version 0.9.288 (patch)

### UI

- Bumped the TOC and documentation version basis to `0.9.288`.
- Modernized the accepted-invite center notice portal action into a wide
  right-side button area while keeping the actual spell icon square and
  centered.
- Reworked the accepted-invite center notice into the selected modern info-card
  layout with a localized eyebrow, left-aligned title/content column, blue
  separator, muted field labels, and reserved text width beside the portal
  action area.
- Reworked the Timeways Portal Navigator into a five-position crescent layout:
  outer-left `Skyreach`, inner-left `Pit of Saron`, center `Heaven`
  (`Unoccupied`), inner-right `Algeth'ar Academy`, and outer-right
  `Seat of the Triumvirate`.
- The occupied Portal Navigator entries now render the verified teleport spell
  icons from `Teleport.GetTeleportInfoByMapID`; the empty center `Heaven`
  placeholder stays muted and icon-free.
- Removed the rendered Portal Navigator direction helper labels and the center
  `Unoccupied` detail text so the view focuses on the portal icons and
  destination names.
- Corrected the accepted-invite Center Notice to match the mockup field set
  again: `Dungeon`, `Group`, `Leader`, and `Source`, with a wider card and a
  smaller visible portal-button background around the larger dungeon icon.
- Kept the accepted LFG listing title available after invite acceptance so the
  group-join fallback notice can still render the `Group` and `Leader` rows.
- Added the same `Group` / `Leader` identity rows for the player's own active
  LFG key listing, with a distinct `LFG key search` title/source instead of
  labeling that path as an accepted invite.
- Aligned the Center Notice portal action area dynamically to the rich text
  block from title top to the last field row, moved cooldown text off the icon
  center, and hid the portal button explicitly when the notice closes.
- Added a small localized `Portal` ready label in the Center Notice portal
  action area; an active cooldown still replaces it with the remaining time.
- Reworked the non-Mythic dungeon-entry Center Notice from the old red
  single-line warning into the same rich info-card layout, with dungeon/raid
  name, difficulty, hint, and source rows while keeping M+ keystone entries
  suppressed.
- The non-Mythic dungeon-entry hint row now renders as a dominant blinking red
  warning so `Not a Mythic+ dungeon` / `Nicht auf Mythisch+` stands out inside
  the rich Center Notice.
- Increased the rich Center Notice label gutter so field values start farther
  to the right in both accepted-invite and non-Mythic dungeon-entry notices.
- Restyled the shared close button with a darker red panel, warm gold border,
  subtle red glow, and WoW panel close textures so the window chrome better
  matches the current isiLive theme.
- Added the non-Mythic dungeon-entry Center Notice to the demo preview cycle
  after the accepted-invite portal preview, guarded so delayed demo callbacks do
  not fire after demo exit.
- Corrected the demo preview data for the modern notices: the Portal Navigator
  now uses verified teleport icon metadata, and the accepted-invite Center
  Notice keeps the full `Dungeon`, `Group`, `Leader`, and `Source` field set
  visible longer before the non-Mythic preview replaces it.
- Changed the demo preview to render the accepted-invite portal Center Notice
  and the non-Mythic dungeon-entry Center Notice in separate demo-only frames
  so both can be inspected at the same time.
- Added deterministic layout and status coverage for the five portal positions
  and updated the release-gate baseline to `1901` scenarios.

## 2026-05-28 - Version 0.9.287 (patch)

### LFG

- Removed the abandoned experimental LFG invite-list modules
  (`logic/isiLive_invites.lua`, `ui/isiLive_invite_list.lua`), TOC entries,
  guards, locale strings, and obsolete scenario file.
- Kept the active LFGDetect invite/accepted-notice path intact and added
  architecture coverage that the removed invite-list modules stay absent.
- Enlarged the accepted-invite centerbox portal button, moved it into the
  right-side action area, and removed the redundant teleport header text plus
  its unused locale key.
- Added a separate `Group-join target notice` setting for the verified
  group-join fallback center notice, independent from `Accepted-invite notice`.
- Tightened the Portal Navigator window height and anchored both portal rows
  from the top so the notice no longer carries excessive empty space at the
  bottom.
- Added the active headline-title rule: Center Notice and Portal Navigator
  titles must start with `isiLive - ` and render in the shared warm gold
  title color.
- Added Leech to the StatsBox demo rows so enabling demo mode no longer hides
  that stat while preview data is active.
- Stopped the StatsBox demo preview from overriding the user's font-size
  offset, so enabling demo mode no longer scales the box larger.
- Demo mode now temporarily enables both `Accepted-invite notice` and
  `Group-join target notice` so both notice previews remain visible even when
  the user's normal settings are disabled, then restores those settings on
  demo exit.
- Added StatsBox detail settings for Leech, Speed, Durability, Stamina, and
  Avoidance, plus a display mode for values and percentages together or each on
  its own.
- The StatsBox now reads Stamina, Durability, and Avoidance from direct live
  APIs only; percent-only mode hides rows without a verified percent instead of
  inventing one.
- Added subtle one-pixel child-group separators inside the settings panel while
  keeping the existing blue separators for major topic changes.
- Removed the StatsBox-internal separator again so the StatsBox base controls
  and detail controls read as one coherent block.
- Fixed the Settings language selector layout so the language buttons sit below
  the description text instead of overlapping it.
- Made Settings section headers larger and more dominant with the shared warm
  gold title color.
- Documented the next thematic Settings ordering for General, ESC menu,
  Display subgroups, Behavior, Nameplates, Sounds, Chat, and Administrative
  actions.
- Updated the current release-gate scenario baseline to `1892` scenarios.

## 2026-05-27 - Version 0.9.285 (patch)

### LFG / Center Notice

- Added a verified group-join fallback for the accepted-invite center notice so
  the dungeon summary and clickable portal button still render when Blizzard
  does not deliver the expected direct LFG invite-accepted callback.
- The fallback only uses the verified local queue target and stays silent
  without a resolved target, keeping the no-guess contract intact.
- Direct invite-accepted rendering suppresses the group-join fallback for that
  join cycle so the center notice cannot be shown twice.

### Commands / Settings

- Split the public slash-command surface into normal help and an explicit
  `/isilive admin` support surface for diagnostic and preview commands.
- Removed obsolete public command entries for runtime start/stop/pause/resume,
  language switching, legacy test mode, and lead-transfer helpers.
- Removed the obsolete roster column-guide setting from schema, settings UI,
  locale strings, and tests. Stale saved values are ignored.

### Kick Tracker

- Tightened deterministic coverage for Protection Paladin Avenger's Shield as
  an extra interrupt source and its cooldown-expiry cleanup path.

### Release Metadata

- Bumped the TOC and documented baselines to `0.9.285`.
- Updated the release validation baseline to `1889` scenarios.

## 2026-05-27 - Version 0.9.284 (patch)

### Settings

- Renamed the LFG class-bonus setting to **Group Finder: Buff rating hearts**,
  kept it enabled by default, and expanded the description to explain the
  1/2/3/4-heart rating.
- The setting description now shows fixed-size green heart texture examples on
  separate lines for the one-, two-, three-, and four-plus-buff states.
- Added German strings for deDE, kept English fallback text for prepared
  locales by default, and accepted post-edited translations such as ruRU.
- Integrated the ruRU translation help from @Hubbotu with thanks, adapted to
  the current fixed-size `media/heart_bonus_green.tga` buff-rating description.
- Made locale-to-language flag resolution use a static lookup so roster
  tooltips cannot spend time rebuilding the locale map during hover rendering.
- Updated the validator baseline to `1892` scenarios.

## 2026-05-27 - Version 0.9.283 (patch)

### Ready Check

- Hardened the Readycheck secure macro button by wiring `/readycheck` on the
  default, left-click, and right-click secure attributes and registering both
  mouse-up and mouse-down clicks.

### Release Metadata

- Bumped the TOC and documented baselines to `0.9.283`.
- Confirmed the validator baseline remains `1890` scenarios.

## 2026-05-26 - Version 0.9.282 (patch)

Fixes two in-game UI regressions found during the 0.9.281 test pass and adds
deterministic Unicode coverage for Share Keys sender handling.

### Ready Check

- The Readycheck button now keeps Blizzard's secure macro click handler intact;
  isiLive logging hooks onto the click instead of replacing the secure
  `OnClick` script. Countdown buttons remain regular Lua actions.

### LFG Group Bonus Indicators

- Applicant member rows now render class-bonus hearts as real green texture
  markers next to the role icon instead of FontString texture markup, avoiding
  distorted or white glyphs on recycled Blizzard applicant rows.

### Share Keys

- Added regression coverage proving `SHAREKEYS` requests from UTF-8 sender names
  such as `Kürshad-Blackmoore` and Cyrillic `Name-Realm` pairs trigger the same
  response path as ASCII senders.
- Added matching self-echo coverage so non-ASCII local player names still
  suppress their own echoed `SHAREKEYS` payload without guessing aliases.
- Confirmed the observed `K?rshad` runtime-log text is SavedVariables log
  sanitization only; the raw sender bytes remain intact for sync parsing.

### Release Metadata

- Bumped the TOC and documented baselines to `0.9.282`.
- Updated the validator baseline to `1890` scenarios.

## 2026-05-26 - Version 0.9.281 (patch)

Improves Settings readability and expands demo mode into a full logical preview
of the current feature surfaces.

### Demo Mode

- Demo/test mode now enables the current preview surfaces together: M+ timer,
  combat cooldowns, bottom forces tracker, Statsbox, Portal Navigator,
  accepted-invite center notice with portal, M+ forces nameplate/tooltip demo,
  and Group Finder bonus markers.
- Demo feature toggles are temporary: entering demo mode snapshots user
  settings, applies demo-only overrides, and leaving demo mode restores the
  previous values, including unset fields.
- The nameplate forces demo no longer overrides the user's percent format,
  position, font size, or offsets while previewing demo values.
- Statsbox can render explicit demo rows only while demo mode supplies them;
  clearing demo mode returns collection to the live Blizzard API path.

### LFG Accepted Invite Notice

- The accepted M+ invite center notice now includes the same verified target
  dungeon as a clickable portal button when the accepted LFG listing supplies a
  concrete activity or map ID.
- The embedded portal button uses the strict activity/map-to-spell resolver;
  listings without a verified context still render the info card without
  inventing a teleport target.
- When both activity and verified map context are present, the center notice
  now resolves the portal button from the verified map first so unresolved
  activity data cannot hide a valid portal.

### Settings

- Settings descriptions now render below every option row with a wider
  wrapping text region, including checkboxes, sliders, dropdowns, and option
  selectors.
- Settings labels now use controlled row wrapping across checkboxes, sliders,
  dropdowns, and option selectors, with long words allowed to break inside the
  available settings width instead of overflowing.
- Wrapped slider, dropdown, and option labels now reserve their measured height
  before rendering descriptions, preventing label and description overlap.
- The reset UI position action moved from Display into the administrative reset
  area with the other recovery actions.
- All settings sections now carry translation-ready description keys. German
  text is localized; all other locales carry English placeholders.
- Stats-box settings descriptions now use locale keys as well, so German
  Settings no longer fall back to English text there.
- German Settings now name the player stats controls `Statsbox`.
- The settings description test now verifies below-option anchors, readable
  width, label and description wrapping, locale refresh behavior, and all
  supported control types.

### Release Metadata

- Bumped the TOC and documented baselines to `0.9.281`.
- Updated the validator baseline to `1888` scenarios.

## 2026-05-25 - Version 0.9.278 (patch)

Updates the LFG class-bonus data and marker counting so the compact Group
Finder signal reflects current non-stacking group buffs.

### LFG Group Bonus Indicators

- Updated Hunter's Mark to the current `+3% Dmg taken` label and Arcane
  Intellect to `+3% Int`, with German text for the German addon locale and
  English prepared for all other locales.
- Treats Devotion Aura and Atrophic Poison like PI, Bloodlust, and Battle Res:
  they may appear in tooltip details but do not create compact green markers.
- Counts compact search-result markers by unique relevant non-stacking bonus,
  so duplicate providers of the same buff add only one marker.
- Added deterministic coverage for utility-only Paladin/Rogue handling,
  Marksmanship Hunter Bloodlust, and duplicate Shaman mastery providers.

### Release Metadata

- Bumped the TOC and documented baselines to `0.9.278`.
- Updated the validator baseline to `1882` scenarios.

## 2026-05-25 - Version 0.9.277 (patch)

Stabilizes the LFG group-bonus marker placement for Blizzard's default
Group Finder rows and completes the release documentation baseline for the
class-bonus feature.

### LFG Group Bonus Indicators

- Moved compact green search-result bonus markers to a right-aligned anchor
  inside the Blizzard search-result row, so the display no longer depends on
  third-party class-badge addons.
- Kept the compact score limited to relevant non-utility group bonuses for
  the logged-in character; Battle Res, Bloodlust, Power Infusion, and similar
  utility notes stay out of the marker count.
- Preserved applicant-row bonus markers next to the role badge and tooltip
  bonus details for listed class/spec lines.

### Release Metadata

- Bumped the TOC and documented baselines to `0.9.277`.
- Updated the validator baseline to `1880` scenarios.

## 2026-05-25 - Version 0.9.276 (patch)

Fixes the incoming-summon sound path for Retail clients that surface the
summon dialog through status updates, and ships the documented baseline for
the new LFG group-bonus indicators.

### Incoming Summon Sound

- Registered `INCOMING_SUMMON_CHANGED` alongside the existing
  `CONFIRM_SUMMON` path so incoming summon dialogs can trigger the bundled
  `sounds/Portal.ogg` cue when Retail reports the summon through the status API.
- The new path is scoped to `unitTarget == "player"` and only plays when
  `C_IncomingSummon.IncomingSummonStatus("player")` equals
  `Enum.SummonStatus.Pending`.
- Kept raid suppression intact and fail-closed when the pending summon enum is
  unavailable, instead of guessing a numeric status.

### LFG Group Bonus Indicators

- Added optional LFG bonus hints for applicant rows and search-result tooltips,
  including class buffs, major utility markers, Battle Res, Bloodlust, and
  Augmentation Evoker damage utility.
- The display respects the logged-in player's relevant primary stat profile and
  can be toggled from settings.
- German addon locale uses German bonus labels; all other locales are prepared
  with English fallback text.

### Release Metadata

- Bumped the TOC and documented baselines to `0.9.276`.
- Updated the validator baseline to `1872` scenarios.

## 2026-05-25 - Version 0.9.275 (patch)

Fixes ESC Addons shortcut visibility for per-character addon enable states
and ships the release baseline for the post-0.9.274 CI/test split.

### ESC Addons Panel

- Scoped supported external addon shortcut visibility to the current character's
  enable state instead of treating the global `Some` state as active.
- Prevents shortcuts from appearing for addons that are installed and enabled on
  another character but disabled on the current character, which could leave the
  button visible while `LoadAddOn` fails with a disabled target.
- Added deterministic coverage for current-character enabled shortcuts and the
  "enabled only on another character" fail-closed path.

### CI / Test Hygiene

- Split the game-menu addon scenarios into a focused test module so the Lua
  metrics hard file-size gate stays green without changing runtime behavior.
- Kept the scenario registry explicit so the existing usecase validator still
  executes the moved coverage.

### Release Metadata

- Bumped the TOC and documented baselines to `0.9.275`.
- Updated the validator baseline to `1851` scenarios.

## 2026-05-24 - Version 0.9.274 (patch)

Splits the large UI orchestration files into focused modules and pins the new
architecture contracts with deterministic coverage.

### Architecture Cleanup

- Reduced the legacy UI entrypoints to thin namespace shims and moved main-frame,
  ESC game-menu, travel, mount, action, and Settings section responsibilities
  into focused modules.
- Kept the TOC order, test harness registration, and architecture usecases in
  lockstep with the split module graph.
- Added architecture rules for hidden-gate config builders, secure mutation
  audits, CI wrapper parity, and runtime setup context bundles.

### Stats Box

- Widened the standalone Stats Box percent column enough for `(999.99%)`, so
  values above `100.00%` stay on one line.
- Kept short and large percent rows aligned through a stable compact minimum
  width and added deterministic regression coverage.

### Release Metadata

- Bumped the TOC and documented baselines to `0.9.274`.
- Updated the validator baseline to `1848` scenarios.

## 2026-05-24 - Version 0.9.273 (patch)

Adds the Settings-driven Hearthstone travel selection, VIP guest mount sound
muting, and the matching deterministic coverage.

### Hearthstone Selection

- Added a Settings dropdown for `random-owned`, the default Hearthstone item,
  and specific owned Hearthstone toys.
- Refreshes the selectable list on toy and item-info updates, keeps
  covenant/race-gated toys hidden until ownership is verified, and avoids
  numeric fallback display for unresolved names.
- Shows client-localized toy names for the German addon locale and verified
  English names for all other addon languages.
- Applies the selected Hearthstone to the ESC travel button and defers secure
  action attribute updates while combat lockdown or active keydown would block
  them.

### VIP Guest Sounds

- Added VIP Guest Settings mute toggles for Astral Aurochs, Grand Expedition
  Yak, and Trader's Gilded Brutosaur mount sounds.
- Applies verified sound file ID sets through Blizzard's `MuteSoundFile` and
  `UnmuteSoundFile` APIs on login/reload and immediate Settings changes.
- Migrated the legacy Astral Aurochs enabled flag into the new muted SavedVariable
  shape and added persisted defaults for all three toggles.

### Settings / Localization

- Localized the Hearthstone selection and VIP sound Settings strings.
- Widened the Hearthstone dropdown to prevent label wrapping in the Settings
  canvas.

### Release Metadata

- Bumped the TOC and documented baselines to `0.9.273`.
- Updated the validator baseline to `1841` scenarios.

## 2026-05-23 - Version 0.9.272 (patch)

Fixes combat-lockdown taint in leader-management button refreshes and syncs
release metadata.

### Ready Check

- Deferred secure ready-check button enable/alpha updates while combat lockdown
  is active, preventing `ADDON_ACTION_BLOCKED` from `Button:SetEnabled()`.
- Applied pending leader-button state on `PLAYER_REGEN_ENABLED`, so non-leader
  disabled/dimmed state is restored after combat.
- Added deterministic taint coverage and regen-handler coverage, and mapped
  both tests to the active secure-button combat rule.

### Release Metadata

- Bumped the TOC and documented baselines to `0.9.272`.
- Updated the validator baseline to `1830` scenarios.

## 2026-05-22 - Version 0.9.271 (patch)

Tightens the Share Keys cooldown chain for all isiLive users and sends the
request with higher addon-message priority.

### Share Keys

- Remote isiLive clients now start the 30-second Share Keys button cooldown for
  every valid incoming `SHAREKEYS` request, even when they have no own key to
  post.
- Kept the own-key chat reply attempt intact, but decoupled button lockout from
  the reply result.
- Sent `SHAREKEYS` addon messages through ChatThrottleLib with `ALERT` priority
  to reduce peer response delay.
- Updated deterministic coverage and the active rule 53 mapping for the new
  cooldown contract.

### Release Metadata

- Bumped the TOC and documented baselines to `0.9.271`.
- Kept the validator baseline at `1828` scenarios.

## 2026-05-22 - Version 0.9.270 (patch)

Fixes the ready-check action button for combat lockdown and syncs release
metadata.

### Ready Check

- Replaced the insecure `DoReadyCheck()` click path with a preconfigured
  secure macro action using `/readycheck`.
- Kept leader-only enablement and existing management-button layout behavior
  intact while allowing the button to work under combat lockdown when Blizzard
  permits the secure action.
- Added deterministic coverage that the ready-check button is a secure macro
  action and does not call the protected function directly.

### Release Metadata

- Bumped the TOC and documented baselines to `0.9.270`.
- Updated the validator baseline to `1828` scenarios.

## 2026-05-22 - Version 0.9.269 (patch)

Hardens the ESC Addons shortcut dispatch and syncs release documentation.

### ESC Addons Panel

- Kept shortcut visibility fail-closed: supported external addon buttons appear
  only when the target addon is installed and enabled.
- External shortcuts verify-load load-on-demand targets before dispatch and then
  call the registered `SlashCmdList` handler directly.
- Removed chat-edit fallback behavior from the shortcut contract; failed or
  missing handlers stay silent instead of writing slash text such as `/mdt` into
  chat.
- Added deterministic coverage for repeated shortcut clicks and handler-failure
  fail-closed behavior, and mapped those tests to active rule 67.

### Release Metadata

- Bumped the TOC and documented baselines to `0.9.269`.
- Updated the validator baseline to `1827` scenarios.

## 2026-05-21 - Version 0.9.268 (patch)

Stabilizes the standalone Stats Box value column for compact stat layouts.

### Stats Box

- Kept the values column at its compact minimum width even when current text
  measurements are narrower, so four-digit primary stats such as `2052` do not
  force row-specific percent-column shifts.
- Added deterministic coverage for mixed three- and four-digit stat rows.
- Updated the active StatsBox rule and user-facing docs to document the stable
  value-column contract.

## 2026-05-21 - Version 0.9.267 (patch)

Adds verified mount shortcuts to the ESC menu.

### ESC Mounts Panel

- Added a localized `Mounts` panel below the existing `Travel` ESC panel.
- Added secure macro shortcuts for favorite mount, auction-house Brutosaur, and
  repair Yak; buttons are shown only when the mount/favorite availability is
  verified through `C_MountJournal` and the localized spell name is verified
  through Blizzard spell APIs.
- The favorite shortcut now casts a verified favorite mount's own spell instead
  of relying on the global random-favorite spell name.
- Corrected the auction-house mount shortcut icon to the verified
  `inv_misc_food_lunchbox_devilsaur` FileDataID.
- Kept the panel mounted as a `GameMenuFrame` child and covered the placement,
  fail-closed visibility, and combat-open behavior with deterministic tests.

## 2026-05-21 - Version 0.9.266 (patch)

Fixes the standalone Stats Box under tainted secret width measurements and
accepts the Russian locale improvements from pull request #21.

### Stats Box

- FontString width measurements that are masked as Secret Values are now
  ignored instead of being coerced or compared in Lua.
- Refreshes keep the last trusted fitted text layout; first-time tainted
  refreshes use compact fixed fallback columns instead of the old wide box.
- Other UI text-fitting paths now route through the same guarded width helper,
  so future direct `GetStringWidth()` arithmetic is caught by the Secret Value
  gate.
- Added deterministic coverage and updated the active StatsBox rule mapping for
  the secret width measurement path.

### Russian Locale

- Accepted pull request #21 from `Hubbotu` with Russian text abbreviations for
  ESC-menu and Settings labels.
- Updated the Russian Arkantine, Hearthstone, Spellbook, ReloadUI, and
  default-layout labels exactly as submitted.
- Thank you to `Hubbotu` for the contribution.

## 2026-05-21 - Version 0.9.265 (patch)

Fixes sound cues, Settings layout/localization refresh, and ESC addon shortcut
visibility.

### Sound Cues

- Incoming summon now plays the bundled `sounds/Portal.ogg` asset directly
  instead of depending on a client-specific SoundKit constant.
- Bloodlust sound now also fires from the observed player Sated/Exhaustion aura
  onset, so the sound can play when the local player receives Bloodlust even if
  the CombatEvents self-cast announce path is not the source.
- Added deterministic coverage for the UNIT_AURA sound handoff and the
  one-shot aura-onset playback gate.

### Settings UI

- Default-layout option buttons now fit localized labels such as German
  `Zuletzt verwendet`, preventing the next V/H/M+ button from overlapping.
- Behavior-section auto-show/hide and raid notes are refreshed when the addon
  language changes, so German and other non-English settings no longer retain
  the previous English text.
- Added deterministic coverage for localized option-button sizing and behavior
  note refresh across all supported addon locales.

### ESC Addons Panel

- Addon shortcut buttons now appear for supported addons that are installed and
  enabled, even if the target addon is still load-on-demand and not yet loaded.
- Clicking a shortcut loads the target addon first and only then invokes its
  registered slash alias; failed loads or missing slash aliases remain
  fail-closed.
- The isiLive shortcut now opens the isiLive Settings panel through the direct
  Settings opener instead of trying to self-load or depending on slash dispatch.
- Updated the active ESC addon panel rule and deterministic rule-to-test mapping
  to match the installed-and-enabled visibility contract.

## 2026-05-21 - Version 0.9.264 (patch)

Adds an ESC-menu Addons shortcut panel.

### ESC Addons Panel

- Added a third ESC overlay panel to the left of the Travel panel with the
  `Addons` header.
- Added shortcut buttons for MDT, MRT, DBM, BigWigs, Details, SimC, and
  Platynator.
- Buttons are created only when the corresponding addon is installed, enabled,
  and already loaded in the current UI run.
- Clicks use registered slash aliases instead of guessed runtime internals.

## 2026-05-21 - Version 0.9.262 (patch)

Fixes the Settings default-layout selector spacing.

### Settings Layout

- The default-layout label now uses the full Settings text width.
- The V/H/M+ option buttons now sit on a separate row with clear vertical
  spacing below the label.
- Added deterministic coverage for the selector row spacing.

## 2026-05-21 - Version 0.9.261 (patch)

Closes German Settings translation gaps.

### Settings Localization

- Reworded German Settings labels that still used avoidable English terms.
- Localized the minimap button tooltip instead of hard-coding English click
  hints.
- Added deterministic coverage for the localized minimap tooltip and verified
  locale drift/dead-key checks.

## 2026-05-21 - Version 0.9.260 (patch)

Persists the current group target key through the reload roster mirror.

### Reload Roster Mirror Target Key

- The reload roster mirror now stores the verified current group target key
  alongside the member snapshot, bound to the same exact group signature.
- Restoring a matching mirror seeds the target dungeon map, name, and accepted
  key level back into the status target path before roster-owner fallbacks can
  overwrite it.
- Added deterministic coverage for target-key save/restore and updated the
  active reload mirror rule mapping.

## 2026-05-21 - Version 0.9.259 (patch)

Tightens the standalone player Stats Box background to the rendered text.

### Stats Box Fit

- The Stats Box now measures its visible label, value, and percent text columns
  after rendering and resizes the frameless background to those text bounds plus
  compact padding.
- Height now follows the number of visible stat rows instead of retaining empty
  vertical space.
- Added deterministic coverage and updated the active StatsBox rule mapping for
  the fit-to-rendered-text contract.

## 2026-05-21 - Version 0.9.258 (patch)

Corrects the title-bar Settings shortcut placement and spacing.

### Title Bar Settings Shortcut Follow-Up

- Moved the gear button to the left of the `L` lock button.
- Shifted the M+/H/V layout switcher group left so it no longer overlaps the
  Settings, lock, and close controls.
- Added deterministic coverage for the corrected title-bar order and shifted
  layout-button anchors.

## 2026-05-21 - Version 0.9.257 (patch)

Adds a direct Settings shortcut to the main isiLive title bar.

### Title Bar Settings Shortcut

- Added a gear button directly to the right of the title-bar `L` lock button;
  left-click opens the isiLive Blizzard Settings category.
- Kept the shortcut available for all main layouts because M+, H, and V share
  the same main-frame title bar.
- Added localized tooltip strings and deterministic UI coverage for the
  title-bar button placement and settings opener wiring.

## 2026-05-21 - Version 0.9.256 (patch)

Fixes Settings audit findings around exposed numeric ranges and long localized
slider labels.

### Settings Audit

- Aligned the Nameplate font-size Settings slider with the DB schema range:
  the UI now exposes the full valid `8..28` range instead of stopping at `24`.
- Added deterministic coverage that the upper schema value `28` persists
  through Settings refresh and remains visible on the slider.
- Width-constrained Settings slider labels and enabled word wrapping so long
  localized labels stay in the left label column instead of overlapping the
  slider track.
- Added a layout regression test for long slider-label text.

Tests: Settings default-pattern, SavedVariables reload, live-apply,
combat-lockdown, locale, hardcoded-string, TOC, architecture-rule, and full
usecase gates pass. Usecase count is now 1796.

## 2026-05-21 - Version 0.9.255 (patch)

Restores the default-off auto-close contract and migrates legacy combined
auto-close settings without guessing from ambiguous SavedVariables.

### Auto-Close Default and Legacy Migration

- Restored the active default-off contract for `autoCloseOnKeyStart`: fresh
  installs and untouched SavedVariables now only close the main UI on key
  start when the split field is explicitly `true`.
- Added schema migration version 2 for pre-split legacy saves with
  `autoCloseMainFrame=true` and no split fields. Those saves now migrate to
  explicit `autoCloseOnKeyStart=true` and `autoCloseOnSoloChange=true`, then
  clear the old combined field.
- Kept ambiguous saves fail-closed: if split fields already exist, the
  runtime treats them as the authoritative persisted choice instead of
  guessing from the old legacy field.

Tests: added `DBSchema.Sanitize migrates legacy autoCloseMainFrame into split
auto-close fields`, updated the active auto-close rule mappings, and kept the
settings/default-pattern and SavedVariables reload simulators aligned. Usecase
count is now 1795.

## 2026-05-21 - Version 0.9.254 (patch)

Fixes the wired `SHAREKEYS` receive path so remote key-share requests use the
same runtime dependencies as the local button flow.

### Share Keys Wiring

- The event-handler config now receives the wired own-keystone chat sender,
  runtime trace hooks, and share-keys cooldown trigger from controller wiring.
- Remote `SHAREKEYS` addon messages now call the same own-key party-chat
  closure as the local share-key flow instead of falling back to a no-op.
- Receiving clients only trigger the 30 second button lock after that own-key
  party post succeeds, preserving the fail-closed spam-protection contract.

### Tests

- Added deterministic coverage that `Sync.SendShareKeysRequest()` produces the
  real `SHAREKEYS` addon payload and that the wired receive path processes
  exactly that prefix, payload, and channel.
- Updated the active share-keys spam-protection rule mapping for the new
  send/receive alignment test.
- Usecase count is now 1794.

## 2026-05-20 - Version 0.9.253 (patch)

Adds an optional standalone player stats box and prevents movable isiLive
windows from being dragged outside the WoW screen.

### Player Stats Box

- Added a separate player stats box that is independent from the M+, H, and V
  main UI layouts.
- The box starts disabled by default and can be enabled in Settings.
- The primary stat uses exact class/spec resolution only: fixed-primary
  classes use the live class token, while hybrid classes require an exact live
  specialization ID.
- Visible labels are fixed short English labels (`Str`, `Agi`, `Int`, `Crit`,
  `Haste`, `Mast`, `Vers`, `Leech`, `Speed`) without locale variants.
- Values and percentages are right-aligned, use a fixed Blizzard-like color
  palette, and keep a dark contrast shadow without an outline.
- Settings now include independent controls for enable/disable, lock,
  background opacity, and a relative font-size slider from `-3` to `+3`.
- The box stores its own position in `statsBoxPosition` and never mutates the
  main-window position.

### Movable UI Clamp

- Main UI, Center Notice, Portal Navigator, and Stats Box now clamp their
  movable frames to the WoW screen edge, so users cannot drag those windows
  outside the game view.
- The minimap button remains on its existing minimap-circle drag logic instead
  of being treated as a normal movable window.

### Tests

- Added deterministic coverage for live-only Stats Box values, secret-value
  formatting safety, fixed labels, alignment, color palette, font scaling,
  locking, default-off behavior, and independent saved position.
- Added deterministic coverage that every free movable isiLive window is
  screen-clamped.
- Usecase count is now 1793.

## 2026-05-19 - Version 0.9.252 (patch)

Improves reload roster restoration, fixes secure M+Marker worldmarker actions,
and adds explicit SHAREKEYS runtime tracing.

### Reload Roster Mirror

- Reload roster snapshots now persist verified group display data separately
  from volatile runtime state and restore it only when the current player group
  signature matches the saved signature.
- Incomplete or mismatched reload mirrors are cleared fail-closed instead of
  being used as guessed roster state. Kick state remains excluded from the
  reload mirror.

### SHAREKEYS Runtime Trace

- Applied sync messages now log whether a `SHAREKEYS` request was detected.
- Runtime handling now emits explicit `[SHAREKEYS]` receive, reply-result, and
  cooldown-trigger traces when a peer asks for key sharing.

### M+Marker

- M+Marker buttons now set the native `worldmarker` secure-action attributes
  directly on each button (`type` and `marker`) and keep left/right click
  behavior in `action1` / `action2`. This matches the secure WorldMarker path
  instead of relying only on button-suffixed marker attributes.
- M+Marker secure buttons are now lifted above sibling overlay frames, matching
  the defensive layering already used for tank/healer role-marker buttons.

### Tests

- Tightened deterministic coverage for M+Marker secure attributes and attached
  it to the active M+Marker WorldMarker rule.
- Added deterministic coverage for reload roster mirror validation and
  fail-closed clearing.
- Added deterministic coverage for `SHAREKEYS` sync detection and runtime trace
  handling.

## 2026-05-18 - Version 0.9.251 (patch)

Fixes wrapped dungeon-portal cooldown displays and tightens no-guess wording
around runtime resolution.

### Teleport Cooldowns

- Teleport cooldown start times that imply multiple complete 8-hour portal
  windows are now normalized to the current cooldown-cycle remainder before
  formatting. The visible cooldown frame is anchored at the current session time
  with that verified remainder, so short client sessions do not collapse the
  display to ready. This turns wrapped values such as `1195:02` into the
  current-cycle remainder (`03:02`) instead of showing an impossible value, a
  misleading full `08:00`, or no cooldown at all.

### No-Guess Contract

- Clarified that an explicitly parseable `+N` in the LFG group title is an
  accepted listing source for the key level, while free-form title text without
  that marker remains unresolved.
- Renamed peer-kick remaining-time helpers from interpolation terminology to
  deterministic decay terminology; the runtime still only subtracts elapsed
  time from a received, verified peer cooldown payload.

### Tests

- Added deterministic coverage for wrapped teleport cooldown start times being
  normalized to the current cooldown cycle and for the Teleport UI applying the
  visible cooldown frame from that normalized remainder. Both are attached to
  the active no-guess rule.
  Usecase count is now 1774.

## 2026-05-18 - Version 0.9.250 (patch)

Fixes Russian roster column headers after the `ruRU` locale rollout.

### Locale UI

- Shortened the Russian iLvl and kick column headers to fit their fixed roster
  columns.
- Roster column headers now use the same Cyrillic-capable ruRU font override
  and deterministic single-line font fitting as the localized action buttons,
  so long localized headers cannot visually run into adjacent columns.

### Tests

- Added deterministic coverage for ruRU header fitting and attached it to the
  active ruRU font rendering rule.
  Usecase count is now 1772.

## 2026-05-18 - Version 0.9.249 (patch)

Allows longer localized main-button labels without forcing translators to
over-abbreviate every full-width action, and folds in the contributed
Russian locale update.

### Sync

- KICK payloads with both multi-kick extras and a primary spell ID now keep
  `:E:` before `:S:`, preserving mixed-version compatibility for older peers
  that read extras from `parts[4]/parts[5]`.
- TARGET sync now carries verified opaque Blizzard keystone level markup as an
  optional `:LT:` suffix when no numeric level exists. Free-form title text is
  still dropped instead of becoming a guessed level.

### Locale UI

- The ruRU locale now uses Cyrillic translations for the addon UI strings and
  localized language display names instead of transliterated placeholders.
  Thanks to ZamestoTV / Hubbotu for contributing the Russian translation.
- When the addon language is set to `ruRU`, main-window labels and fitted
  roster/action buttons now switch to a Cyrillic-capable WoW font so Russian
  text renders correctly even on non-Russian WoW clients.
- Flat roster/action button labels now refit their font size to the fixed
  button width, restoring the base font before every text update and shrinking
  only as far as the minimum readable size when needed.
- The experimental open LFG invite-list window is no longer exposed or wired
  at runtime. Its Settings toggle and SavedVariables field were removed after
  live testing did not show a reliable Blizzard-supported multi-invite list
  surface.
- Hidden main-window state now keeps `LFG_LIST_APPLICATION_STATUS_UPDATED`
  blocked for queue and invite-list processing; visible positive status events
  still follow the regular LFGDetect and queue-capture path.

### Tests

- Replaced the legacy 14-character locale gate for full-width action buttons
  with key-presence coverage plus deterministic font-fit scenarios for short,
  long, post-shrink, and ruRU Cyrillic-font labels.
- Added regression coverage for mixed-version KICK suffix ordering and
  verified TARGET `levelText` propagation, plus Settings, DB-schema, gate, and
  event-handler coverage that keeps the experimental LFG invite-list disabled.
  Usecase count is now 1771.

## 2026-05-16 - Version 0.9.247 (patch)

Cleans up the M+ killtracker pre-key level cell, repositions the
active-key dungeon name on the progress bar, and tightens the Share Keys
success signal.

### M+ KillTracker

- Pre-key level cell now only renders the numeric `+N`; raw LFG title
  scraps (group-leader notes, unprocessed Blizzard keystone markup) no
  longer leak into the level position.
- Active-key dungeon name moved on top of the progress bar (left-aligned,
  outlined, with a subtle contrast label) so the bar stays the dominant
  element while the dungeon label stays legible.

### Share Keys

- `SendShareKeysRequest()` now reports success only when the `SHAREKEYS`
  addon message dispatch actually succeeds. Failed dispatch attempts no
  longer look like a successful peer broadcast to the button/cooldown
  chain.

## 2026-05-15 - Version 0.9.246 (patch)

Fixes M+ target display and enemy-forces freshness in the bottom tracker.

### M+ target and portal highlight

- The portal highlight resolver now receives the verified local target map
  from the LFG/target-dungeon path before falling back to synced peer
  targets.
- After an LFG invite target announce, the bottom M+ killtracker shows
  the verified dungeon and key level as right-aligned pre-key text, with
  the level rendered separately so the percentage slot cannot overwrite
  the dungeon.
- Blizzard keystone title markup (`|Kk...|k`) is now preserved as an
  exact level source for the pre-key Killtracker text and status target
  info when no numeric `+N` can be parsed.
- The Target-Dungeon chat announce is queued until the group join is
  observed, so it prints after Blizzard's group-forming messages instead
  of being buried before them.
- Once the key starts, the row suppresses the pre-key text and returns to
  the enemy-forces percentage display; active percentage rows may keep
  the verified dungeon name dimmed below the bar as context.

### Killtracker live forces refresh

- `PLAYER_REGEN_ENABLED` now re-reads Blizzard's live scenario forces
  before notifying the UI, so completed pulls are committed immediately
  instead of waiting for the next combat start.
- The active KillTrack ticker also refreshes live scenario data before
  UI/nameplate updates, keeping the bottom tracker and nameplate
  remaining-count suffix aligned.

### Tests

- `Factory primary highlight forwards local target map to shared resolver`
- `UpdateKillTrackRow renders verified target key as right-aligned combined text before challenge start`
- `UpdateKillTrackRow renders verified Blizzard level markup before challenge start`
- `UpdateKillTrackRow suppresses target key after challenge start until percent data is active`
- `factory_controllers.status: GetStatusTargetDungeonInfo carries LFG level markup when numeric level is unresolved`
- `LFGDetect direct-push waits for GROUP_ROSTER_UPDATE when IsInGroup is transient false`
- `PLAYER_REGEN_ENABLED refreshes live forces before the next pull starts`
- `refresh ticker callback reads live forces and notifies subscribers while state is active`
- `factory_controllers: GetActiveChallengeMapID returns nil for secret values`

## 2026-05-15 - Version 0.9.245 (patch)

Rolls up the 2026-05-15 key-start notice-replay work plus a
follow-up belt-and-suspenders guard for the recovery branch.

### Key-start closes the accepted-invite notice window

- The challenge-mode-start handler now forwards `CHALLENGE_MODE_START`
  to `LFGDetect.HandleEvent`. The new branch sets
  `acceptedInviteNoticeBlockedUntilReset = true` without clearing
  `detectedMapID` / `activeInviteLeader` / `activeInviteTitleLevel`,
  so target-dungeon resolution keeps working but a late LFG-event
  replay (Blizzard occasionally re-emits `inviteaccepted` after the
  group has settled, e.g. on cross-realm joins) can no longer
  re-render the "Einladung angenommen" Center Notice.
- `MaybeShowAcceptedInviteNotice` honours the new flag with an
  early return + `notice_skip_after_key_start` log line.
- The flag is cleared only by `ClearAllStateImpl` (group-leave or
  explicit full reset). Key-end paths
  (`CHALLENGE_MODE_COMPLETED` / `CHALLENGE_MODE_RESET` /
  `PARTY_LEADER_CHANGED`) intentionally keep it set: a pre-formed
  group's next run is not a fresh invite cycle.
- `lastShownNoticeSearchResultID` is no longer cleared in
  `ClearAcceptedInviteListingIdentity`; the new flag carries the
  guarantee and clearing the marker there would only weaken it.

### Recovery branch refuses to rebuild from the live API alone

[game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua) — the
GROUP_ROSTER_UPDATE recovery branch now requires at least one
cached `pendingInvites` table entry before it asks
`ResolveAcceptedPendingInvite` for an answer. Without this guard
the post-key-start sequence had a remaining theoretical leak:

1. `CHALLENGE_MODE_START` sets the blocker (above).
2. Same handler calls `ctx.checkIfEnteredTargetDungeon()`.
3. `currentMapID == targetMapID` → `LFGDetect.ClearAllState()`.
4. `ClearAllStateImpl` wipes `pendingInvites`,
   `lastShownNoticeSearchResultID` AND
   `acceptedInviteNoticeBlockedUntilReset`.
5. A late `GROUP_ROSTER_UPDATE` (sub-zone settle / roster refresh
   after dungeon entry) re-enters the recovery branch; the live
   LFG application may still report `inviteaccepted` for the
   already-consumed searchResultID; `ResolveInviteEntry` rebuilds
   an entry from scratch; without the guard the Notice + direct-
   push chat would fire a second time.

With the guard, `ResolveAcceptedPendingInvite` is only consulted
when there is at least one real cached pendingInvites table entry
to anchor the resolution. An empty cache → no live-API fallback,
straight to the `CheckActiveGroup` own-listing path. The
sentinel-only / negative-status case (`false` entries from
`OnInviteDeclined`) keeps its existing `CheckActiveGroup` fallback
because those are not table values either.

### Direct-push carries the exact Blizzard keystone markup

- New helper `ResolveEntryTitleLevelText(entry)` returns
  `entry.groupName` verbatim **only** when it matches
  `^|Kk%d+|k$` (anchor-strict). Free-form titles like
  `"+12 Push"` or `"+12 Entspannt"` are rejected so the chat
  line never inherits descriptive marketing text.
- `MaybeFireTargetDungeonChatFromAccept` forwards `levelText`
  alongside `level`; the dedupe marker is set whenever either is
  resolvable.
- `AnnounceTargetDungeonFromPayload` accepts the markup as a
  fallback when `payload.level` is nil, validates the anchor
  again, and emits the chat line with the raw markup appended
  after the dungeon name. The WoW chat frame decodes the markup
  client-side to the familiar `+N`, so the user reads exactly
  what the Center Notice / Blizzard invite popup already
  rendered, without any descriptive title fragments leaking in.

### Tests

- `Event handlers forward challenge start to LFGDetect` — dispatch
  contract.
- `AcceptedInviteNotice does not replay after challenge start` —
  the late-replay sequence: `invited` → `inviteaccepted` →
  `CHALLENGE_MODE_START` → `inviteaccepted` replay → Notice fires
  exactly once.
- `AcceptedInviteNotice does not replay via GROUP_ROSTER_UPDATE
  recovery after ClearAllState` — pins the new recovery guard:
  even with the live LFG API still reporting
  `inviteaccepted` for the consumed searchResultID, the
  post-`ClearAllState` recovery branch cannot rebuild a Notice.
- `LFGDetect direct-push carries exact Blizzard keystone level
  markup` — anchor-strict markup forwarded as `levelText`.
- `Status AnnounceTargetDungeonFromPayload emits exact Blizzard
  keystone level markup` — chat line composes
  `"Target Dungeon: <name> |Kk584|k"` and locks out the
  level-less resolver fallback.

Usecase count rises from 1715 to 1720.

## 2026-05-15 - Version 0.9.244 (patch)

Fixes the race that produced the `Gruppe: Unbekannt` Center Notice
(plus a stale or missing chat-line) when Blizzard delivered
`GROUP_ROSTER_UPDATE` **before** `LFG_LIST_APPLICATION_STATUS_UPDATED
=inviteaccepted` — a real-world ordering for delisted-listing
accepts and high-latency cross-realm groups.

### Race-sequence reconstruction

Reconstructed from the in-game byte-dump (vorfall 2026-05-15):

1. Bewerbung → `invited` event → `pendingInvites[id]` populated
   with the listing snapshot taken at `invited` time
   (`info.name = "|Kk584|k"`, leader, mapID, …). Snapshot is
   sound.
2. Accept → Blizzard's roster signal **arrives first**.
   `GROUP_ROSTER_UPDATE` handler's recovery branch (in
   [game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua))
   sets `detectedMapID` / `activeInviteLeader` /
   `activeInviteTitleLevel` / `acceptedInviteSearchResultID` from
   the cached `pendingInvites[id]`, **consumes** the cache entry
   (`pendingInvites[id] = nil`), and fires the highlight update.
   Before 0.9.244, however, it did **not** fire the post-accept
   Notice nor the direct-push chat — those were tied to the later
   `OnInviteAccepted` only.
3. `inviteaccepted` lands now → `OnInviteAccepted` reads
   `pendingInvites[id]` = nil → falls back to a fresh
   `ResolveInviteEntry(searchResultID)` → the API has by then
   delisted the listing and returns minimal data, the title slot
   collapses to `_G.UNKNOWN` ("Unbekannt"). Notice renders that
   placeholder.

### Fix — recovery branch fires the post-accept hooks itself

- The recovery branch in `LFGDetect.HandleEvent("GROUP_ROSTER_UPDATE")`
  now calls `MaybeShowAcceptedInviteNotice(entry, resultID)` and
  `MaybeFireTargetDungeonChatFromAccept(entry, resultID)` directly
  after the state-set, so the Notice + chat use the **still-sound**
  cached entry. The same recovery branch also routes
  `activeInviteTitleLevel` through `ResolveEntryTitleLevel(entry)`
  for consistency with the 0.9.241 helper (covers entry.titleLevel
  divergence vs. entry.groupName).
- New module-local `lastFiredTargetDungeonChatSearchResultID`,
  mirror of the existing `lastShownNoticeSearchResultID`, used by
  `MaybeFireTargetDungeonChatFromAccept` to suppress a duplicate
  fire when the (late) `inviteaccepted` event re-enters the same
  path. Reset in `ClearAllStateImpl` and
  `ClearAcceptedInviteListingIdentity` alongside the notice marker
  so a legitimate next-cycle accept for the same listing renders
  again.
- The dedupe marker is set **only** when the call carried a
  resolved level. Calls that exited at the status-controller
  level-less bail (0.9.243 contract) leave the marker untouched —
  so a later trigger that does carry a level can still fire
  through. Asymmetric on purpose: successful pushes lock further
  repeats out, ineffectual ones do not.

### What the user sees now

| Sequence | Notice | Chat |
| --- | --- | --- |
| `inviteaccepted` first (normal) | renders once via `OnInviteAccepted` (no change vs. 0.9.243) | direct-push fires when level resolvable, resolver fallback otherwise (no change vs. 0.9.243) |
| `GROUP_ROSTER_UPDATE` first (race) | renders once via the recovery branch with the still-cached entry (no more `Gruppe: Unbekannt`) | direct-push fires once with the cached level (or bails for `\|Kk…\|k`-encoded titles → resolver supplies +N) |
| Late `inviteaccepted` after recovery | suppressed by `lastShownNoticeSearchResultID` (no Doppel-Notice) | suppressed by `lastFiredTargetDungeonChatSearchResultID` when the recovery fire carried a level |

### Tests

- New `LFGDetect GROUP_ROSTER_UPDATE recovery fires target-dungeon-chat
  callback once` pins the full race contract in one sequence:
  `invited` → `GROUP_ROSTER_UPDATE` → callback fires once with
  `mapID/level/leader/searchResultID`; the subsequent
  `inviteaccepted` is silently deduped.

- The "Status target dungeon chat" rule now lists the new test as
  required, so future audits keep the contract enforced.

Usecase count rises from 1714 to 1715.

## 2026-05-15 - Version 0.9.243 (patch)

Diagnosis-driven revert and re-architecture of the keystone-level
extraction for the chat target-dungeon announce. The 0.9.242 hotfix
("Pattern C: parse `|Kk(%d+)|k` as the level") turned out to be
**wrong** once a full byte-dump of `info` ran on the live client:

```
name (string) = "+12 Entspannt"
              bytes [124,75,107,53,56,52,124,107]
                  = "|Kk584|k"
```

The digits inside `|Kk<...>|k` are NOT the keystone level — they
are an opaque session-internal lookup index. The same listing
renders as "Unbekannt" when the client cache has not yet resolved
the ID (e.g. for a freshly-delisted listing) and as "+12 Entspannt"
once the entry is present. Reading `<id>` as the level produced
nonsense values (`|Kk584|k` → 584, out of 1..40 range → nil; the
parse never recovered the actual `+12`). There is no documented
Lua API to invoke Blizzard's lookup-table decoder.

### Pattern C reverted

- `ParseTitleKeyLevel` rolls back to the pre-0.9.242 Pattern A / B
  set (plain "+N" and "N+"). For Blizzard's pipe markup the parser
  now correctly returns nil — no false level invented from the
  opaque ID.
- `ResolveEntryTitleLevel` keeps its 0.9.241 contract (use
  `entry.titleLevel` if valid, otherwise re-parse `entry.groupName`)
  but the re-parse now also returns nil for the markup shape, so
  the direct-push payload arrives with `level = nil` instead of a
  bogus number.

### Direct-push bails on level=nil

- `AnnounceTargetDungeonFromPayload` returns early when
  `payload.level` is nil. No chat line emitted, no
  `levelAnnouncedTargetDungeonName` lock-in set. The user wants
  exactly `Ziel-Dungeon: <Name> +<N>` in chat — never a level-less
  placeholder, never any of the descriptive text that the listing
  title carries ("Entspannt", "Push", "Lernen"). Bailing out
  intentionally yields control to the resolver-driven path
  (`MaybeAnnounceTargetDungeonChat` via UpdateStatusLine), which
  supplies the level from the roster-owner key, the LFG-title
  hint, or the synced target after GROUP_ROSTER_UPDATE has settled.

### What the user sees now

| Listing shape | Notice "Dungeon" row | Chat line |
| --- | --- | --- |
| Plain text `"+13 Push"` | `Maisarakavernen +13` | `Ziel-Dungeon: Maisarakavernen +13` (direct push) |
| Pipe markup `\|Kk584\|k` | `Maisarakavernen` (no +N — Notice keeps its "Gruppe:" row for the decoded title) | `Ziel-Dungeon: Maisarakavernen +13` (resolver from roster-owner key) |
| No level anywhere | `Maisarakavernen` | `Ziel-Dungeon: Maisarakavernen` (resolver fallback after 3 s defer) |

Notice and chat are now **consistent** wherever a level is
ascertainable, and the chat line is uniformly the compact
`Dungeon +N` form — no descriptive title fragments leak in.

### Tests

- Removed `renders without +N when level is nil` — the old contract
  ("emit anyway, just without +N") is exactly what the user
  rejected.
- Added `bails out without emitting or locking when level is nil`
  pins the new contract: level-less direct-push stays silent, does
  not poison the lock-in, and the resolver path takes over with the
  roster-owner level.

- Pattern C assertions removed.
- New assertions on the `ResolveEntryTitleLevel` helper pin the
  Blizzard-markup contract: `|Kk584|k` resolves to nil (no false
  level), but a mixed `"+12 |Kk999|k"` still picks up the plain
  text `+12` via Pattern A.

Usecase count stays at 1714.

## 2026-05-14 - Version 0.9.242 (patch)

In-game data finally explained the recurring "chat / notice shows
dungeon name without `+N`" bug class that survived 0.9.236 (3 s
defer), 0.9.238 (race guards), 0.9.239 (identity drops), 0.9.240
(direct-push), and 0.9.241 (lock-in protection + synced-only gate).
Diagnosed with a byte-level debug print on a fresh accept:

```
entry.titleLevel=nil entry.groupName="+12"
len=8 bytes=[124,75,107,49,50,124,107,…]
```

The bytes decode to `|Kk12|k…` — a Blizzard pipe-markup
encoding that the chat frame **renders** as the familiar "+12" with
keystone coloring, but raw Lua string operations see no literal `+`
byte at all. Every Pattern-A / Pattern-B match in
`ParseTitleKeyLevel` therefore failed silently, and the
0.9.241-introduced `ResolveEntryTitleLevel` recovery helper still
fell back through to `nil` because re-parsing the same markup with
the same patterns produced the same miss. The Center Notice line
"Gruppe: +12" looked correct only because it printed the markup
verbatim to the chat frame — which then rendered it as "+12".

### Pattern C — Blizzard `|Kk<N>|k` keystone-level markup

- `ParseTitleKeyLevel` learns a third pattern: `|Kk(%d+)|k`.
  Runs alongside Pattern A so a listing title that mixes plain
  text (`"+13"`) and markup (`"|Kk13|k"`) still picks the highest
  valid match. Pattern C is the only path that fires on
  modern level-only titles where the leader typed "+12" and the
  API rewrote it into the markup form.
- Confirmed against the bytes captured in-game
  (`[124,75,107,49,50,124,107]` → `12`) and against the helper's
  recovery path so `entry.titleLevel=nil + entry.groupName=<markup>`
  resolves correctly through `ResolveEntryTitleLevel`.

### Rollup of the 0.9.241-era helper work

The `ResolveEntryTitleLevel` helper introduced in commit
`88360b7` (defensive groupName re-parse on every consumer) is now
the active recovery path for Pattern C — `entry.titleLevel=nil`
arrives at the consumers, the helper re-parses
`entry.groupName`, Pattern C extracts the level from the markup,
and the Center Notice / direct-push chat / resolver hint all
emit the same `+N`.

Routing through the helper for:

- `MaybeShowAcceptedInviteNotice` — notice payload `level`
- `MaybeFireTargetDungeonChatFromAccept` — chat payload `level`
- `OnInviteAccepted` body — `activeInviteTitleLevel` state-set
  (LFG-title hint that the resolver-driven
  `MaybeAnnounceTargetDungeonChat` falls back to)

### Telemetry

- `ResolveEntryTitleLevel` emits a `title_level_fallback` log
  entry whenever the recovery path actually fires (e.g. markup-only
  titles). Cheap, no PII (LFG titles are public listings), gives
  the next user-reported divergence concrete data instead of
  guesswork. The 2026-05-14 vorfall was diagnosed in two screenshot
  rounds because the byte dump went straight to the chat frame —
  this log makes the same data persistent.

### Tests

- Existing `ResolveEntryTitleLevel recovers level from groupName
  when titleLevel is nil` extended with three Pattern C assertions:
  - Raw byte string `[124,75,107,49,50,124,107]` resolves to `12`
    (pins the exact in-game capture).
  - `"|Kk13|k Competitive"` (markup + trailing text) resolves
    to `13`.
  - `"+12 |Kk13|k"` (mixed plain + markup) resolves to `13`
    (highest-match-wins still applies).

Usecase count rises from 1713 to 1714.

## 2026-05-14 - Version 0.9.241 (patch)

Release rollup of two 2026-05-14 follow-ups to the 0.9.240
direct-push target-dungeon chat work. Both bugs surfaced the same
class of failure — the chat target-dungeon line said the wrong
thing (missing `+N`, wrong dungeon entirely) while the Center
Notice / status frame rendered correctly — but for different
reasons.

### Fix 1 — IsInGroup race after invite-accept

In-game report: Center Notice shows `Die Himmelsnadel +13`, chat
shows `Ziel-Dungeon: Die Himmelsnadel` (no `+13`). Two coupled
IsInGroup misuses formed the race:

1. The factory wired the direct-push callback with a
   `SetTargetDungeonChatEnabledFn(() -> IsInGroup() == true)` gate.
   Blizzard sends `LFG_LIST_APPLICATION_STATUS_UPDATED=inviteaccepted`
   before the matching `GROUP_ROSTER_UPDATE`, so `IsInGroup()` is
   still false in that window (the `ClearDetectedState` guard in
   [game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua) already
   documents the same race). The gate silenced the direct push on
   every accept where the roster signal lagged.
2. [logic/isiLive_event_handlers_queue.lua](../logic/isiLive_event_handlers_queue.lua)
   runs `RefreshTargetStatusAfterInviteAccepted` *synchronously*
   right after the LFG-detect handler returns. That triggers
   `ctx.updateStatusLine()` → `MaybeAnnounceTargetDungeonChat` while
   `IsInGroup()` is still false; the old `isInGroup() ~= true`
   branch hit `ResetTargetDungeonChatState` and wiped the
   `levelAnnouncedTargetDungeonName` the direct push had just set.
   The subsequent `GROUP_ROSTER_UPDATE`-driven pass then re-fired
   through the resolver chain — usually without `+N` because the
   LFG-title hint had aged out.

Fix:

- [factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua):
  the `SetTargetDungeonChatEnabledFn(() -> IsInGroup() == true)`
  setter is removed from the production wiring. The
  `LFGDetect.SetTargetDungeonChatEnabledFn` API itself stays (tests
  still cover the gate semantics) but the production wiring installs
  the callback without it. The chat line is a local `print()` (not
  `SendChatMessage`), so requiring group membership at the moment
  of accept has no protocol-level justification.
- [ui/isiLive_status.lua](../ui/isiLive_status.lua):
  `MaybeAnnounceTargetDungeonChat` is reordered to resolve
  `ResolveConcreteTargetDungeonInfo` *before* the IsInGroup guard.
  Real group-leave still resets through the `info=nil` branch (no
  roster / queue / synced target ⇒ no target info). The IsInGroup
  branch now protects the lock-in: when
  `state.levelAnnouncedTargetDungeonName` is already set, only the
  deferred-announce bookkeeping clears; the lock-in itself survives
  the transient flicker.

### Fix 2 — synced-only chat false positives

In-game report after Fix 1: a manual `/invite` (no own LFG search
on the player's side) produced chat lines like `Ziel-Dungeon:
Maisarakavernen`, then flipped to `Ziel-Dungeon: Grube von Saron`
when a roster member left. Only the third line, drawn from the
group's own LFG listing (`Akademie von Algeth'ar +12`), matched
what the player actually saw.

Root cause: `GetStatusTargetDungeonInfo` falls back to
`ResolveSyncedTargetInfo` when `ResolveLocalStatusTargetMapID`
yields nil (no own queue, no active joined key, no detectedMapID
from a fresh LFG accept). The synced-target consensus is fine for
the status frame — it is informational, "this is what some peer is
currently broadcasting" — but it is NOT a semantic "this is the
dungeon the group has decided to play" signal: the value flips
whenever the broadcasting member changes. The chat announce should
not surface that flip.

Fix:

- [ui/isiLive_status.lua](../ui/isiLive_status.lua):
  `MaybeAnnounceTargetDungeonChat` now consults a new
  `deps.hasLocalTargetSource` callback after the lock-in match and
  before emitting / deferring. When `hasLocalTargetSource()` returns
  false, the deferred-announce bookkeeping is cleared and the
  function returns silent. The lock-in itself is NOT touched (the
  status frame still renders the synced target as informational; a
  later `AnnounceTargetDungeonFromPayload` via LFG-accept still
  bypasses the gate because direct push emits through
  `EmitTargetDungeonAnnouncement`, not through the resolver path).
- [factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua):
  wires `hasLocalTargetSource = ctx.ResolveLocalStatusTargetMapID()
  ~= nil`. Mirrors the existing resolver — own queue / active joined
  key / detectedMapID (LFG accept) light it up, synced-only does not.

### Tests

Usecase count rises from 1702 (post-0.9.240) to 1705.

- Rewrote `lock-in resets when group leaves` on the real `info=nil`
  reset path (the mocked `targetInfo` is cleared alongside
  `inGroup=false`, matching how the live resolver collapses to nil
  when the roster is empty).
- New `preserves the lock-in during transient IsInGroup=false`
  pins the LFG-accept race window: direct push fires, `IsInGroup`
  flips false, the synchronous status refresh runs — the chat line
  stays quiet, the next `GROUP_ROSTER_UPDATE` pass stays quiet too.
- New `suppresses the announce when only a synced peer target is
  available` covers all four branches: synced-only stays silent,
  name flip across roster changes stays silent, a local trigger
  appearing later opens the gate, and direct-push bypasses the
  gate regardless.

- New `direct-push fires even while IsInGroup() is transient false`
  pins the production wiring: callback set, no
  `SetTargetDungeonChatEnabledFn`, `IsInGroup()=false` — the
  callback must still fire and carry the listing's `+N`.

- Phase 5 (`leave + rejoin must allow a fresh announce`) realigned
  with the real group-leave sequence: `ClearAllState` clears the
  LFG-detect identity slots, `isInGroup`/`numMembers` flip back to
  the unjoined state, and a real `GROUP_ROSTER_UPDATE` follows the
  fresh accept on rejoin. Mirrors how the live client signals a
  group-leave; the previous test simulated only `IsInGroup=false`
  without the roster collapse, which the new lock-in protection
  would (correctly) refuse to honour.

## 2026-05-14 - Version 0.9.240 (patch)

Architectural fix for the recurring "chat target-dungeon line surfaces
the wrong / no +N" class of bugs. After 0.9.236 (3 s defer), 0.9.238
(declined_delisted post-accept guard + sole-`"player"` race guard),
0.9.239 (generalised sole-match race guard + identity drops on
key-end / leader-change), yet another in-game report (`Terrasse der
Magister +13` invite, no member in the roster held that key at all)
made it clear that piling more guards onto the resolver chain was
treating symptoms, not the cause.

The Center Notice has always been right: it reads
`entry.titleLevel` directly from the LFG search-result payload
synchronously inside `OnInviteAccepted`. The chat path was going the
long way around — `GetStatusTargetDungeonInfo` -> LFG-title hint ->
roster owner -> synced target, plus a 3 s deferred re-evaluation —
and every one of those sources had its own way of either being not
populated yet at announce time or being stained later by an
unrelated event.

This release adds a direct-push hook that feeds the chat the same
`entry.titleLevel` the notice already drew, with no resolver chain
between accept and announce. Guarantee: when the notice shows `+N`,
the chat shows `+N` — they share the payload now.

### New direct-push hook in lfg_detect

- New `targetDungeonChatCallback` / `targetDungeonChatEnabledFn`
  module-local slots plus their `SetTargetDungeonChatCallback` /
  `SetTargetDungeonChatEnabledFn` setters.
- New helper `MaybeFireTargetDungeonChatFromAccept(entry,
  searchResultID)` that forwards `{mapID, level=entry.titleLevel,
  leaderName, groupName, searchResultID}` to the callback. Silent
  no-op when the callback is unwired (early-load races, tests) or
  the enabled gate returns false.
- `OnInviteAccepted` calls the helper right after the existing
  `MaybeShowAcceptedInviteNotice` call — same payload, same call
  frame.

### New direct-push entry point on the status controller

- New `controller.AnnounceTargetDungeonFromPayload(payload)` method.
  Takes `{name, level}` directly (the factory pre-resolves
  `mapID -> name` via `ResolveAcceptedInviteDungeonName` so the
  status controller does not need its own teleport lookup) and emits
  the announce through the existing `EmitTargetDungeonAnnouncement`
  helper. That helper sets the `levelAnnouncedTargetDungeonName`
  lock-in flag as a side effect, so the subsequent
  `UpdateStatusLine`-driven `MaybeAnnounceTargetDungeonChat` call
  finds the dungeon already announced and stays silent.
- Guards against non-table payloads, missing / blank `name`,
  zero / negative `level` (treated as level-less), and the lock-in
  already being set for the same name.

### Factory wiring

- After `statusController` is created, the factory wires the LFG-
  detect callback to a closure that pre-resolves the dungeon name
  via the existing `ResolveAcceptedInviteDungeonName` helper (same
  source the post-accept notice uses) and then forwards
  `{name, level}` to `statusController.AnnounceTargetDungeonFromPayload`.
- No `IsInGroup` gate (corrected by the follow-up below). The direct
  push fires deterministically on every accept event; the Center
  Notice path has no IsInGroup gate either, and the chat line is a
  local `print()` (not `SendChatMessage`), so requiring group
  membership at the moment of accept has no protocol-level
  justification.

### Why the resolver chain stays

The resolver-driven `MaybeAnnounceTargetDungeonChat` path is **not**
removed — it still serves three trigger sources the direct push
cannot cover:

- Manual `/invite` groups (no LFG context).
- Peer-sync target updates (a peer's announced target dungeon
  changes, no local invite event).
- Pre-formed groups starting a different key with no fresh accept.

For those paths the 3 s defer + sole-match race guard + identity-
clears on key-end / leader-change continue to apply. The direct-push
hook short-circuits **only** the LFG-accept trigger, which is the
one path where the listing payload carries the authoritative level.

### Tests

7 new regression tests; usecase count rises from 1695 to 1702.

- `AnnounceTargetDungeonFromPayload emits the +N line and sets the
  lock-in` — pins the happy path and the no-second-fire.
- `... renders without +N when level is nil` — listing without a
  `"+N"` marker.
- `... is a no-op for invalid payloads` — nil / non-table / blank
  name / whitespace-only name.
- `... locks out the resolver-driven path` — direct push first, then
  a subsequent resolver-driven `MaybeAnnounceTargetDungeonChat` must
  stay silent because the lock-in is set.

- `OnInviteAccepted fires the target-dungeon-chat callback with the
  listing payload` — `level == entry.titleLevel`,
  `leaderName / groupName / searchResultID` propagated.
- `direct-push respects the enabled gate` — `enabledFn=false`
  silences the callback.
- `direct-push surfaces level=nil when the listing has no +N
  marker` — propagates absence cleanly.

### Follow-up 2026-05-14 — IsInGroup race after invite-accept

In-game report after the initial 0.9.240 push: `Die Himmelsnadel +13`
in the Center Notice but `Ziel-Dungeon: Die Himmelsnadel` (no `+13`)
in the chat. The direct-push hook was wired, the resolver chain was
bypassed, yet the level still went missing.

Root cause: two coupled IsInGroup misuses formed a race.

1. **Factory gate fired too early.** The initial wiring guarded
   the direct push with `IsInGroup() == true`. Blizzard sends
   `LFG_LIST_APPLICATION_STATUS_UPDATED=inviteaccepted` *before* the
   matching `GROUP_ROSTER_UPDATE`, so `IsInGroup()` is still false in
   that window (the `ClearDetectedState` guard in
   [game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua) already
   documents the same race). The gate silenced the callback on every
   accept where the roster signal lagged behind the accept event.
2. **Resolver-side reset erased the lock-in.**
   [logic/isiLive_event_handlers_queue.lua](../logic/isiLive_event_handlers_queue.lua)
   runs `RefreshTargetStatusAfterInviteAccepted` *synchronously* right
   after the LFG-detect handler returns. That calls
   `ctx.updateStatusLine()` → `MaybeAnnounceTargetDungeonChat` while
   `IsInGroup()` is still false, and the old `isInGroup() ~= true`
   branch hit `ResetTargetDungeonChatState` and wiped the
   `levelAnnouncedTargetDungeonName` that the direct push had just
   set. The subsequent `GROUP_ROSTER_UPDATE`-driven pass then re-fired
   the announce through the resolver chain — usually without `+N`
   because the LFG-title hint had aged out by then.

The combination meant the direct push either never fired (gate
silenced it) or fired but was immediately undone (lock-in wiped). The
Center Notice reads `entry.titleLevel` synchronously and has no such
gate, so it always rendered correctly — that is why the two surfaces
disagreed.

Fix:

- [factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua):
  the `SetTargetDungeonChatEnabledFn(function() return IsInGroup() ==
  true end)` setter is removed from the production wiring. The
  `LFGDetect.SetTargetDungeonChatEnabledFn` API itself stays
  (tests still cover the gate semantics) but the production wiring
  installs the callback without it. The earlier "Factory wiring"
  block above is now accurate.
- [ui/isiLive_status.lua](../ui/isiLive_status.lua):
  `MaybeAnnounceTargetDungeonChat` is reordered to resolve
  `ResolveConcreteTargetDungeonInfo` *before* the IsInGroup guard.
  Real group-leave still resets through the `info=nil` branch (no
  roster / queue / synced target ⇒ no target info). The IsInGroup
  branch now protects the lock-in: when
  `state.levelAnnouncedTargetDungeonName` is already set (direct push
  has fired), only the deferred-announce bookkeeping clears; the
  lock-in itself survives the transient flicker.

Test changes; usecase count rises from 1702 to 1704.

- "lock-in resets when group leaves" rewritten on the real `info=nil`
  reset path (the mocked `targetInfo` is now cleared alongside
  `inGroup=false`, matching how the live resolver collapses to nil
  when the roster is empty).
- New `preserves the lock-in during transient IsInGroup=false` pins
  the LFG-accept race window: direct push fires, `IsInGroup` flips
  false, the synchronous status refresh runs — the chat line stays
  quiet, the next `GROUP_ROSTER_UPDATE` pass stays quiet too.

- New `direct-push fires even while IsInGroup() is transient false`
  pins the production wiring: callback set, no `SetTargetDungeonChat-
  EnabledFn`, `IsInGroup()=false` — the callback must still fire and
  carry the listing's `+N`.

### Follow-up 2026-05-14 — synced-only chat false positives

In-game report after the IsInGroup race fix: a manual `/invite`
(without any LFG search on the player's side) still produced chat
lines like `Ziel-Dungeon: Maisarakavernen`, then flipped to `Ziel-
Dungeon: Grube von Saron` when a roster member left. Only the third
line (`Akademie von Algeth'ar +12`), drawn from the group's own LFG
listing, matched what the player actually saw.

Root cause: `GetStatusTargetDungeonInfo` falls back to
`ResolveSyncedTargetInfo` when `ResolveLocalStatusTargetMapID`
yields nil (no own queue, no active joined key, no detectedMapID
from a fresh LFG accept). The synced-target consensus is fine for
the status frame — it is informational, "this is what some peer is
currently broadcasting" — but it is NOT a semantic "this is the
dungeon the group has decided to play" signal: the value flips
whenever the broadcasting member changes. The chat announce should
not surface that flip.

Fix:

- [ui/isiLive_status.lua](../ui/isiLive_status.lua):
  `MaybeAnnounceTargetDungeonChat` now consults a new
  `deps.hasLocalTargetSource` callback after the lock-in match and
  before emitting / deferring. When `hasLocalTargetSource()` returns
  false, the deferred-announce bookkeeping is cleared and the
  function returns silent. The lock-in itself is NOT touched (the
  status frame still renders the synced target as informational; a
  later AnnounceTargetDungeonFromPayload via LFG-accept still
  bypasses the gate because direct push emits through
  EmitTargetDungeonAnnouncement, not through the resolver path).
- [factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua):
  wires `hasLocalTargetSource = ctx.ResolveLocalStatusTargetMapID()
  ~= nil`. Mirrors the existing resolver — own queue / active
  joined key / detectedMapID (LFG accept) light it up, synced-only
  does not.

- New `suppresses the announce when only a synced peer target is
  available` covers all four branches: synced-only target stays
  silent, name flip across roster changes stays silent, a local
  trigger appearing later opens the gate, and direct-push bypasses
  the gate regardless.

Usecase count rises from 1704 to 1705.

## 2026-05-13 - Version 0.9.239 (patch)

Three follow-up fixes to the 0.9.238 LFG-edge-case audit. All three
belong to the same bug class — the accepted-invite identity inside
(`activeInviteLeader`, `activeInviteTitleLevel`, `detectedMapID`,
`acceptedInviteSearchResultID`, `pendingAcceptedInviteMapID`) used to
be either too permissive at capture time or too sticky across group
lifetime, and downstream consumers (status target-dungeon resolver,
roster owner resolver, chat announce) surfaced "+N" or
wrong-owner-name values that did not match the listing the player
actually accepted. Usecase count rises from 1691 to 1695.

### Fix 1b extended — race guard generalised beyond `"player"`

The initial 0.9.238 race guard only refused `"player"` as the
unique-owner-search sole match in a multi-member group. A second
in-game report (Grube von Saron screenshot uploaded between patches)
showed the same class of bug with a **party member** as the lone
match: Vladax's own POS +14 surfaced for a listing whose owner had
POS +13. LibKeystone-style cross-addon mirroring makes other members'
own keys visible just as instantly as the player's own one, so the
player-only guard left the door open for every other roster member.

`ResolveActiveKeyOwnerUnit` in
now generalises the guard: when the caller did **not** supply a
preferred-owner hint AND the roster has ≥2 non-ghost members AND the
unique-owner search found exactly one match, return nil regardless of
who the match was. Solo / 1-man rosters and the boost-applicant case
(hint provided but not present in the roster) keep their existing
best-effort resolution. The 0.9.238 spec ("refuses 'player' as the
lone match") is now a special case of this generalised rule.

Test changes in

- Renamed "returns unique key owner" to "refuses unique-owner fallback
  in a multi-member group without a hint" with the new spec.
- Kept "refuses 'player' as the lone match" as the canonical pin.
- New: "refuses a non-player lone match in a multi-member group" pins
  the Grube-von-Saron screenshot scenario.
- Solo + ghost-only-siblings tests unchanged.
- Removed the contradicting "picks a non-player unique owner normally"
  pin — that behaviour is now explicitly forbidden when no hint is
  supplied.
- Existing "hint with unknown leader falls back to unique owner" stays
  grün: a provided hint means the boost-applicant path is allowed to
  surface a lone non-hint owner.

### Fix 1c — Accepted-invite identity survives a key-end

After `CHALLENGE_MODE_COMPLETED` (or `_RESET`), the LFG listing that
brought the group together is no longer authoritative for whatever
key the group decides to play next: a pre-formed-group continuation
is not a fresh LFG invite. Letting `activeInviteTitleLevel` bleed
into the next key surfaced the previous listing's "+N" on the new
dungeon (e.g. a +13 hint from a just-finished POS run leaking into a
follow-up NPX +15 run).

A new helper `ClearAcceptedInviteListingIdentity` in
clears exactly the accepted-invite identity slots
(`detectedMapID`, `activeInviteLeader`, `activeInviteTitleLevel`,
`acceptedInviteSearchResultID`, `pendingAcceptedInviteMapID`) and
leaves `pendingInvites` / `lastQueueMapID` untouched.
`HandleChallengeModeCompletedOrReset` in
now calls `handleLFGDetectEvent(event)` in lockstep with the existing
`handleMplusTimerEvent / handleKillTrackEvent /
handleCombatEventsEvent` chain so the clear lands deterministically
at the same point.

`ClearAllStateImpl` (group-leave) remains the **only** thing that
also drops `pendingInvites` — Fix 1c clears only the accepted-invite
identity.

### Fix 1d — Accepted-invite identity survives a leader change

When the group's leader hands off (or drops the group while staying
as a member), `activeInviteLeader` still names the *original* listing
leader. Downstream resolvers used that name as the LFG-leader hint,
so even a correct `UnitIsGroupLeader` fallback could not run for the
new leader.

`PARTY_LEADER_CHANGED` in
now also forwards to `handleLFGDetectEvent("PARTY_LEADER_CHANGED")`,
which calls `ClearAcceptedInviteListingIdentity`. The helper is a
no-op when no listing identity was captured to begin with, so
pre-formed groups stay quiet (no spurious clear-state log entries).

### Tests for Fix 1c + 1d

Four new regression tests in

- CHALLENGE_MODE_COMPLETED clears the accepted-invite identity.
- CHALLENGE_MODE_RESET clears the accepted-invite identity.
- PARTY_LEADER_CHANGED clears stale activeInviteLeader / -TitleLevel.
- PARTY_LEADER_CHANGED is a no-op when no listing identity was
  captured (pre-formed-group case).

## 2026-05-13 - Version 0.9.238 (patch)

Four bug fixes around LFG group-join edge cases and one settings default
change. All four were observed in-game, each one falsifying an
assumption the addon used to make. Local usecase count rises from 1683
to 1691.

### Fix 1 — Target-dungeon chat surfaces the player's own +N after group fills

After accepting an LFG invite, the chat target-dungeon announce
sometimes rendered "+15" instead of the listing's "+12" — visibly
inconsistent with the Center Notice (which carries the listing's level
directly from the LFG payload). Two independent root causes converged:

**Cause A**: in
`OnInviteDeclined` nulled `activeInviteLeader` /
`activeInviteTitleLevel` / `detectedMapID` /
`acceptedInviteSearchResultID` for the **accepted** search-result ID as
soon as Blizzard fired `declined_delisted` / `declined_full` for it.
Blizzard fires exactly that the moment the LFG group fills and the
listing is removed from search — post-accept cleanup, not a real
decline. With the state cleared, `GetStatusTargetDungeonInfo` lost its
authoritative level source (the LFG-title hint) and degraded to the
resolver's fallback chain. The post-accept negative-status events for
the accepted search-result ID are now ignored; state only clears via
`ClearAllStateImpl` (group-leave / explicit reset).

**Cause B**: in
`ResolveActiveKeyOwnerUnit`'s unique-owner fallback happily returned
`"player"` when only the player's own key matched the target dungeon
in the roster. Right after `GROUP_ROSTER_UPDATE` only the player's own
key is locally cached; the leader's key arrives a roundtrip later via
sync. If the `UnitIsGroupLeader` hint fallback also did not nail down
a preferred owner during that window, the unique-owner search picked
`"player"` and downstream consumers surfaced the player's own +N. The
fallback now treats a sole "player" match in a group of 2+ non-ghost
members as a race symptom and returns nil so the deferred announce
waits for a real source. Solo / 1-man scenarios keep resolving to
"player" correctly. (0.9.239 generalises this guard to lone matches on
*any* roster member — see the 0.9.239 entry above.)

Both causes are pinned by new regression tests:

- [testmodul/isilive_test_scenarios_lfg_detect.lua](../testmodul/isilive_test_scenarios_lfg_detect.lua):
  - `declined_delisted` on the accepted searchResultID keeps the state,
    `ClearAllState` is the only thing that drops it.
  - `declined_full` on the accepted searchResultID keeps the state.
  - `declined_delisted` for an invite that was never accepted still
    clears state (regression pin for the existing path).
- [testmodul/isilive_test_scenarios_keysync.lua](../testmodul/isilive_test_scenarios_keysync.lua):
  - Multi-member group with "player" as sole key match → `nil`.
  - Solo roster with "player" as sole key match → `"player"`.
  - Ghost-only siblings don't count toward headcount, solo fallback
    still resolves.

### Fix 2 — `autoCloseOnKeyStart` default-ON

The "auto-close the addon UI when the M+ keystone starts" toggle
flipped from default-OFF to default-ON, so the addon UI gets out of the
way during a pull unless the user explicitly opts out in Settings.

Touch points:

- [core/isiLive_db_schema.lua](../core/isiLive_db_schema.lua) — schema
  default flipped to `true`.
- [factory/isiLive_factory.lua](../factory/isiLive_factory.lua) —
  `ResolveAutoCloseOnKeyStartEnabled` rewritten as
  `not (... == false)` (Pattern A in the codebase, same shape as
  `ResolveAutoShowMainFrameOnStartupEnabled`). The legacy migration
  condition was rewritten from `~= true` to `== nil` so the migration
  detects exactly the pre-split persisted state and the
  `check_settings_default_pattern` gate doesn't see it as a default-OFF
  read.
- [ui/isiLive_settings.lua](../ui/isiLive_settings.lua) — both checkbox
  read sites (the getter at the checkbox definition and the
  `panel.Refresh()` call) now use `~= false` so the UI matches the
  resolver behaviour.

Existing user behaviour:

- User never touched the setting → default-ON, UI auto-closes on key
  start.
- User explicitly enabled → unchanged, still ON.
- User explicitly disabled → unchanged, opt-out is respected.

Test updates: `isilive_test_scenarios_factory_resolvers.lua`,
`isilive_test_scenarios_group.lua`,
`isilive_test_scenarios_ui_settings.lua`. The savedvariables-reload
simulator's "default-OFF Pattern B" demo moved from
`autoCloseOnKeyStart` to `autoCloseOnSoloChange` (still default-OFF) so
the simulator keeps exercising both pattern shapes.

### Fix 3 — Raid Center Notice failed silently after 0.9.237

Companion to Fix 1: the Raid invite-accept Center Notice (added in
0.9.237) used the same `acceptedInviteSearchResultID` state that Fix 1
now guards. The raid notice path itself was not directly affected, but
the state-machine shape is now uniform across both pipelines —
`acceptedInviteSearchResultID` only clears on group-leave, never on a
post-accept negative status update for the accepted listing.

### Fix 4 — GROUP_ROSTER_UPDATE dropped during sustained combat (Delves)

Reported in-game: in a Delve, a third player got invited mid-run, joined
the group, but never appeared in the addon's roster — until the end-boss
was killed. The Delve keeps the player in combat for the whole run, and
GROUP_ROSTER_UPDATE was registered with `combat=false` in the event
registry — so the gate dropped the event the moment a new member joined.
Blizzard does not re-fire GROUP_ROSTER_UPDATE; the next refresh only
arrived when some unrelated combat-end-adjacent event (boss-kill loot
flow, member moving slot, etc.) happened to trigger a fresh
GROUP_ROSTER_UPDATE.

[core/isiLive_bootstrap.lua](../core/isiLive_bootstrap.lua) now marks
GROUP_ROSTER_UPDATE as `combat=true`. The handler chain
(`HandleGroupRosterUpdate` in
[logic/isiLive_group.lua](../logic/isiLive_group.lua) →
`UpdatePartyMembersInRoster` → `updateUI()`) only touches Lua tables
plus the FontString-driven main frame; no secure / taint-sensitive
code is reachable, so it is safe to run during InCombatLockdown.

Pinned by a new test in
("Bootstrap gate allows GROUP_ROSTER_UPDATE during combat (Delves
member-join fix)") which drives the gate with `isInCombat()=true` and
asserts the event reaches the dispatcher.

## 2026-05-13 - Version 0.9.237 (patch)

Raid Center Notice support: invite accept + raid entry both surface in
the same UI the M+ flow already uses, on a separate, isolated pipeline
so the M+ logic stays untouched.

### Why a separate pipeline (Option 2)

The M+ detection path
([game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua))
filters every LFG activity through
`MapIDFromActivityID` with `isMythicPlusActivity == true`. That filter
exists deliberately: without it, a Raid LFG invite would mutate
`pendingInvites`, `detectedMapID`, `activeInviteLeader`,
`activeInviteTitleLevel`, fire `TriggerHighlightUpdate`, and feed the
chat "Target Dungeon" announce — none of which apply to Raid content.

The Raid invite notice the user noticed was missing was the visible
symptom of that filter: Raid listings never reached
`MaybeShowAcceptedInviteNotice` because their resolver path bailed
out at `MapIDFromActivityID`.

A direct lift of the filter would re-introduce all the M+-only side
effects for Raid. The clean fix is a separate, parallel resolver that
the M+ pipeline never sees:

### Raid invite-accept Center Notice

`MapIDFromRaidActivityID` is a new file-local resolver that mirrors
the M+ resolver but inverts the activity filter: it accepts only
`isMythicPlusActivity ~= true` listings with `categoryID == 3`
(Blizzard's Raid category). `ResolveRaidInviteEntry` builds a payload
(mapID, leaderName, groupName, comment) — no `titleLevel`, no
`activityID`, because the Raid notice has no use for either.

`OnInviteAccepted` now falls through to the Raid resolver only when
the M+ resolver returned nothing. On a Raid hit it fires a new
`acceptedRaidInviteNoticeCallback` and stops — `detectedMapID`,
`activeInviteLeader`, `activeInviteTitleLevel`,
`acceptedInviteSearchResultID`, `pendingAcceptedInviteMapID` are not
touched, and `TriggerHighlightUpdate` is not called. The only
side effect is the notice render.

The factory wires `RenderAcceptedRaidInviteNotice` in
to the new callback. It uses the same Center Notice frame and layout
as the M+ notice, with a separate title key
(`INVITE_ACCEPTED_RAID_NOTICE_TITLE`) so the user can tell the two
apart, no teleport-button section (no Raid teleport spells), and no
"+N" headline (Raid listings have no keystone level). The
`acceptedInviteNoticeEnabled` toggle in `IsiLiveDB` controls both
notices through a single user-facing switch.

### Raid entry Center Notice with difficulty label

`GetDungeonDifficultyLabel` in
gained a `raid` branch that maps the four current Blizzard raid
difficulties (LFR 17, Normal 14, Heroic 15, Mythic 16) to localized
label strings. Legacy 10-man / 25-man / original LFR IDs are not
mapped — those raids are no longer reachable through the current
group finder.

`MaybeShowNonMythicDungeonEntryNotice` was extended to fire for
every raid difficulty including Mythic Raid: the suppress rule is
now "M+ keystone in a party dungeon" only, not "any Mythic". For
raids the notice uses the new `RAID_ENTERED` template ("Raid
betreten: …") and keeps the default brand color rather than the
red accent the non-Mythic-dungeon warning uses — raid entry is
informational, not a warning.

`BuildDungeonContextSignature` now generates signatures for both
`party` and `raid` instances so the existing enter/leave bookkeeping
applies unchanged.

### Locale additions (all 8 languages)

- `INVITE_ACCEPTED_RAID_NOTICE_TITLE` — title for the Raid invite
  notice ("isiLive – Raid-Einladung angenommen" / "Raid invite
  accepted" / …).
- `DUNGEON_DIFF_RAID_LFR / _NORMAL / _HEROIC / _MYTHIC` — difficulty
  labels.
- `DUNGEON_DIFF_RAID_UNKNOWN` — fallback when the raid difficulty ID
  is not in the map.
- `RAID_ENTERED` — entry-notice template ("Raid betreten: %s" /
  "Entered raid: %s" / …).

### Factory metric guard

`InitializeFactoryPrimaryControllers` would have crossed the 420-line
hard limit with the new Raid wiring inline. The four
accepted-invite callbacks (M+ render + enabled, Raid render +
enabled) are extracted into `WireAcceptedInviteNoticeCallbacks` so
the calling function stays under the gate; behaviour is identical to
inline wiring.

### Test follow-up

15 new test cases pinning the Raid pipeline isolation and the Raid
Center Notice rendering. No production behaviour change. Usecase count
rises from 1668 to 1683.

- `AcceptedRaidInviteNotice fires for a Raid LFG listing with categoryID=3`
  — asserts the Raid callback fires, the M+ callback does not, the
  payload carries mapID / leaderName / groupName / comment / searchResultID,
  carries neither level nor activityID, and crucially that
  `detectedMapID`, `activeInviteLeader`, `activeInviteTitleLevel` stay
  nil and the highlight callback is not invoked.
- `AcceptedRaidInviteNotice ignores non-Raid categories even when isMythicPlusActivity is false`
  — categoryID 4 (PvP-style) listing with `isMythicPlusActivity=false`
  must not slip through either pipeline.
- `AcceptedRaidInviteNotice is suppressed when the enabled gate returns false`
  — Raid notice respects the
  `IsiLiveDB.acceptedInviteNoticeEnabled` toggle through its own
  `SetAcceptedRaidInviteNoticeEnabledFn`.
- `AcceptedRaidInviteNotice stays silent when the callback was never registered`
  — the Raid path does not raise when the factory has not wired its
  callback yet (early-load safety).

- `Status GetDungeonDifficultyLabel returns localized raid labels for difficulties 14/15/16/17`
  — pins the four current Blizzard raid difficulty mappings plus the
  contract `isMythic=false`, `inDungeon=true`, `instanceType="raid"`.
- `Status GetDungeonDifficultyLabel falls back to DUNGEON_DIFF_RAID_UNKNOWN for unmapped raid IDs`
  — legacy 40-man / 10-man / 25-man IDs fall through to the generic
  "Raid" label and keep `inDungeon=true` so leave-bookkeeping fires.
- `Status MaybeShowNonMythicDungeonEntryNotice fires for every raid difficulty with the raid template`
  — drives the four-difficulty enter sequence and asserts the
  `RAID_ENTERED` template + the absence of the red warning accent
  (raid entry is informational, not a warning).
- `Status MaybeShowNonMythicDungeonEntryNotice still suppresses M+ keystone entries`
  — regression pin: party + active ChallengeMode mapID still produces
  zero notices (the addon's main UI already surfaces M+ context).
- `Status MaybeShowNonMythicDungeonEntryNotice still warns on non-mythic party dungeon (unchanged)`
  — backward-compat pin: non-mythic party dungeon entry keeps the
  warning prefix and the red text accent.

- `BuildAcceptedRaidInviteFields renders dungeon row WITHOUT level suffix`
  — Raid payload renders dungeon + group + description + role rows,
  the dungeon row carries no "+N".
- `BuildAcceptedRaidInviteFields ignores a stray level on the payload`
  — defensive: even a leaked `payload.level` does not produce a "+N".
- `BuildAcceptedRaidInviteFields drops optional rows when sources are missing`
  — no group + no comment + NONE role leaves only the dungeon row.
- `RenderAcceptedRaidInviteNotice is a no-op for non-table payload` /
  `is a no-op when ShowCenterNotice is missing` — safety guards.
- `RenderAcceptedRaidInviteNotice forwards payload + raid title to ShowCenterNotice`
  — asserts the Raid title key, no teleport-button wiring (mapName /
  activityID args nil), `frameWidth=540`, `persistent=true`, the
  resolved dungeon name without "+N", and the role row matches the
  player's role.

The test-side locale tables in both
`isilive_test_scenarios_status.lua` and
`isilive_test_scenarios_factory_controllers_helpers.lua` were
extended with the new Raid keys so the controller can resolve them
during the assertions.

## 2026-05-13 - Version 0.9.236 (patch)

> **Superseded for the LFG-accept path by [Version 0.9.240](#2026-05-14---version-09240-patch).**
> The "Why the defer and not a direct push from `OnInviteAccepted`?" section
> below documents the contract as it stood on 2026-05-13. Two further
> in-game reports between 0.9.237 and 0.9.240 made it clear that the
> deferred wait could not reliably close the race for the LFG-listing
> path (the resolver chain itself surfaced the wrong / no level even
> within the 3 s window). 0.9.240 replaces the defer for the LFG-accept
> trigger with a direct push that reuses `entry.titleLevel` from the
> listing payload. The defer + resolver chain stays in place for the
> three remaining trigger sources it actually serves (manual `/invite`,
> peer-sync, pre-formed groups) — see the "Why the resolver chain stays"
> section of the 0.9.240 entry.

Bug fix: when the user accepted an LFG invite, the Center Notice showed
"Dungeon + N" immediately (the level comes directly from the LFG listing
payload) but the chat line "isiLive: Ziel-Dungeon: …" was emitted without
the "+N" suffix, because the resolver-driven sources for the level
(LFG-title hint, roster owner, peer sync) had not landed yet at the
moment the first status-line update fired.

### `MaybeAnnounceTargetDungeonChat` waits up to 3 s for the level

`MaybeAnnounceTargetDungeonChat` in
used a two-sighting-then-announce-level-less rule which guaranteed exactly
one chat line per accept but locked the dungeon name in even before the
level could resolve. Once locked, a follow-up status update carrying
"+N" was suppressed — the Notice and the chat ended up disagreeing.

The flow is now deferred:

1. First sighting WITH level → announce immediately with "+N", set the
   lock-in, done.
2. First sighting WITHOUT level → record the time, schedule a forced
   re-evaluation `TARGET_DUNGEON_LEVEL_WAIT_SECONDS` later (3.0 s), stay
   silent.
3. A later status update during the wait carrying the level → falls into
   path 1, the deferred fallback never fires because the lock-in is set.
4. The scheduled re-evaluation runs after the timeout with the level
   still unresolved → announce level-less as the fallback.

3 s comfortably covers the typical 100–500 ms LFG payload plus the peer-
sync roundtrip on slow connections, and stays well below 5 s so the user
never perceives the announce as "missing". The `levelAnnouncedTargetDungeonName`
lock continues to suppress downstream level flickers (downgrade / nil)
exactly as before.

State that survives across the wait:

- `pendingTargetDungeonAnnouncementName` and
  `pendingTargetDungeonAnnouncementAt` replace the old
  `pendingLevelLessTargetDungeonName` / `levelLessTargetDungeonAnnounced`
  two-sighting bookkeeping.
- `levelAnnouncedTargetDungeonName` continues as the single lock-in flag,
  set by both the "+N" and the level-less fallback so neither path can
  trigger a duplicate.
- `ResetTargetDungeonChatState` (group-leave / no-target) wipes all three
  so the next key for the same dungeon name announces afresh.

A `getTime` dependency was added to the Status controller defaults so the
timeout comparison has a clean unit-test surface; production reads it
from the global `GetTime()`.

### Test updates

- `"Status target dungeon chat defers the level-less announce and fires once the level resolves"`
  replaces the old "announces grouped key once and resets after target
  clears" test. It drives the deferred path with explicit `getTime` and
  `timerAfter` mocks: no print on a level-less sighting, exactly one
  print with "+14" once the level resolves, no duplicate when the
  deferred timer fires late.
- `"Status target dungeon chat falls back to a level-less announce once the deferred wait elapses"`
  is new: it pins the timeout fallback by advancing the mocked clock past
  the wait window and then firing the captured timer callback.
- `RULE-TARGET-DUNGEON-CHAT-DEDUP` in
  [docs/RULES_LOGIC.md](RULES_LOGIC.md)
  was updated to reference the two new tests and notes the 3-second
  deferred-wait window.

### Why the defer and not a direct push from `OnInviteAccepted`?

The Center Notice and the chat announce live on two separate trigger
chains, and the WoW event order is what produces the visible "Notice
has +N, chat does not":

- The **Notice** is rendered synchronously inside the LFG handler.
  `OnInviteAccepted` in
  [game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua)
  sets `activeInviteTitleLevel = entry.titleLevel` and then calls
  `MaybeShowAcceptedInviteNotice(entry, ...)` in the same call frame.
  The Notice reads the level directly from the LFG payload — it never
  goes through the resolver.
- The **chat** announce is driven by `UpdateStatusLine`, which hangs off
  unrelated events (GROUP_ROSTER_UPDATE, ZONE_CHANGED,
  INSTANCE_CONTEXT_CHANGED …). Internally it queries
  `lfgDetect.GetActiveInviteTitleLevel()` via the resolver chain in
  `GetStatusTargetDungeonInfo`.

In the failing in-game trace, `GROUP_ROSTER_UPDATE` fired **before**
`LFG_LIST_APPLICATION_STATUS_UPDATED` (`inviteaccepted`). At that point
`activeInviteTitleLevel` was still `nil`, so the resolver returned
`info.level = nil` and the chat went out level-less. The LFG event
followed and set the level — but the chat had already been emitted.

A direct push from `OnInviteAccepted` (calling `UpdateStatusLine`
right after the level is set) would close this race for the LFG path
specifically. It is deliberately not done here: the 3 s defer covers
all other "level resolves a bit late" cases (peer-sync roundtrip,
manual `/invite` with no LFG context, roster-owner inspect delay)
with one mechanism, and the user-visible cost — chat appears up to
3 s after the Notice — is acceptable. A future push-on-accept can be
layered on top without changing the defer contract.

## 2026-05-13 - Version 0.9.235 (patch)

Bug fix: the READY_CHECK row background bled through the H and V
compact layouts.

### `readyCheckBackground` rendered behind the toolbar in H / V

In the expanded layout each roster row carries a `hoverFrame` that
hosts three textures: the alternating-row tint, the hover highlight,
and `readyCheckBackground` (the colored ready / declined / hold tint
applied by `ApplyRowReadyCheckDisplay`). In H and V layouts the row
content itself is gone — only the management / tool buttons render —
and the FontStrings (`row.spec`, `row.name`, …) are hidden individually
by `UpdateCollapseState` in
[ui/isiLive_roster_layout.lua](../ui/isiLive_roster_layout.lua).

`row.hoverFrame` itself was left visible by `UpdateCollapseState`,
only its mouse handling was disabled (`EnableMouse(show)`). The
`readyCheckBackground` child is shown by `RefreshReadyCheckStateImpl`
in
whenever a READY_CHECK fires, with no layoutMode gating. So during —
and during the hold phase after — a check, the colored background
rendered through what should have been an empty toolbar surface.

`UpdateCollapseState` now also drives `SetVisible(row.hoverFrame,
show)`, so the whole subtree (background + altBg + highlight) follows
the row's overall visibility. The `RenderRosterImpl` path was already
doing the same explicit hoverFrame Hide on `isCollapsed` — the two
paths are now consistent.

## 2026-05-13 - Version 0.9.234 (patch)

Stage B of the performance audit: two micro-wins on top of 0.9.233.
No behaviour change.

### RenderRosterImpl: drop `touchedRowSlots` set, clear sequentially

used to track every refilled slot in a `touchedRowSlots` lookup and
then run a `pairs(memberRows)` cleanup pass to clear the untouched
ones. `memberRows` is keyed sequentially (1..N) and only ever
extended, and the render loop always fills slots in order from
index 1 upward — so the cleanup pass is just `[index, #memberRows]`.

The lookup table allocation and the `pairs` traversal are gone;
the cleanup now runs as a small numeric `for` loop. The raid-mode
short-circuit higher up in the function gets the same treatment for
consistency.

### CombatEvents.ShouldDedup: in-line expiry for the recent map

keyed each cast on `sourceName|spellID` and stored its timestamp in
`recent`. `controller.Reset()` cleared the whole map on
`CHALLENGE_MODE_*`, but between those events entries lived forever
even after they fell out of the 3 s dedup window. In long sessions
that hopped raids without entering a key, the map could grow
indefinitely.

`ShouldDedup` now sweeps expired entries (`now - prevWhen >=
DEDUP_WINDOW_SECONDS`) on every miss, before writing the new
timestamp. Net effect: the map size is bounded by the number of
*currently active* casters within the last 3 s, not the cumulative
history.

### Test follow-up

Two test-side hygiene fixes follow the 0.9.234 production changes (no
production behaviour change):

- The roster-panel coverage test for the shrink-cleanup branch in
  `RenderRosterImpl` is renamed from "Roster render touchedRowSlots"
  to "Roster render shrink cleanup". `touchedRowSlots` no longer
  exists after the sequential-cleanup refactor; the test still pins
  the same intent (5-member render → 3-member render must clear only
  orphaned slots).
- A new regression test in
  [testmodul/isilive_test_scenarios_combat_events.lua](../testmodul/isilive_test_scenarios_combat_events.lua)
  covers the in-line expiry sweep: it drives five distinct
  `caster|spell` entries into `recent`, jumps past the 3 s window,
  and asserts that the next `ShouldDedup` miss reaps the expired
  entries. Without this, a later refactor could silently restore the
  unbounded-growth behaviour.
- A tiny `_Test_GetRecentSize()` helper on the `CombatEvents`
  controller exposes the live map size for the new test. The `_Test_`
  prefix makes any accidental production-side caller immediately
  visible in review; production paths never read it.

Usecase count rises from 1666 to 1667.

## 2026-05-13 - Version 0.9.233 (patch)

Stage A of the Notice / CombatEvents OnUpdate cleanup that followed
the 0.9.232 hot-path audit. Three center-notice OnUpdate handlers and
one combat-event API hit have been moved off the per-frame path.

### CenterNotice frame OnUpdate: deferred-state drain moved to PLAYER_REGEN_ENABLED

The center-notice OnUpdate handler in
polled three `pendingTeleportButton*` fields every render frame so it
could apply the button mutations that `SetCenterNoticeTeleportButton*`
had captured during combat lockdown. With the notice visible, that was
60–144 nil-checks per second for state that only changes at the
combat-end edge.

The polling block has been extracted into
`ApplyPendingCenterNoticeTeleportButtonState(state)` and exposed on the
controller as `ApplyPendingTeleportButtonState()`. The
`tryRestoreCenterNoticeTeleportButton` callback in
— which already fires on `PLAYER_REGEN_ENABLED` — now drains the
pending state exactly once on the regen-enabled edge. The OnUpdate
handler keeps only the blink animation and the `endsAt` auto-hide
check.

### CenterNotice teleport-button OnUpdate: 0.1 s accumulator

The teleport-button OnUpdate in
called `getTeleportCooldownRemaining` + `formatCooldownSeconds` +
`SetText` on every render frame even though the cooldown text only
needs sub-second resolution. The handler now uses the same 0.1 s
accumulator pattern as `game/isiLive_mplus_timer.lua`, dropping the
work rate from 60–144 Hz down to 10 Hz.

### LFG invite-hint OnUpdate: Position() throttled to 0.2 s

The invite-hint OnUpdate in
re-anchored itself against the LFG popup every render frame. The
dialog itself never moves faster than the user can drag it, so a
0.2 s accumulator suffices. `endsAt` and the dialog-mismatch hide
check stay per-frame so the hint disappears snappily when the popup
closes.

### CombatEvents: isInKey() result cached across casts

`HandleUnitSpellcastSucceeded` in
called the configured `isInKey()` (default:
`pcall(C_ChallengeMode.GetActiveChallengeMapID)`) on every single
UNIT_SPELLCAST_SUCCEEDED, including the hundreds-per-second self-cast
spam during an AoE pull where the answer cannot change between casts.

A file-local `cachedInKey` value now memoises the result. The cache
is invalidated in `controller.Reset()`, which the central
`HandleEvent` dispatcher already calls on `CHALLENGE_MODE_START` /
`CHALLENGE_MODE_COMPLETED` / `CHALLENGE_MODE_RESET` — exactly the
three events at which the underlying API value can transition. Net
effect: one pcall at the start of each key instead of one per cast.

### Simulator updates

previously flipped its `inKey.value` lambda mid-test without firing
the matching `CHALLENGE_MODE_*` event. That was an artificial
construct — in production the live API result only changes when one
of those events fires — and it broke the new `cachedInKey` memoise.
The simulator now mirrors production by firing
`CHALLENGE_MODE_RESET` before the toggle-off and `CHALLENGE_MODE_START`
before the toggle-on, so the controller picks up the new value on
its next API check.

## 2026-05-12 - Version 0.9.232 (patch)

Performance audit: five hot paths trimmed across the event pipeline and
the mob-nameplate render so an active M+ pull no longer drives 600+
pcalls/sec and 75+ full roster renders/sec for state that effectively
only changes at ~10 Hz.

### UNIT_AURA filtered against `unitAuraUpdateInfo`

`HandleUnitAuraEvent` in
previously called `ctx.updateCdTracker()` on every player UNIT_AURA fire,
which during combat triggered the 40-slot HARMFUL `pcall(GetAuraDataByIndex)`
scan in
on each DoT tick, proc refresh and stack change — easily 15–20× per
second in an M+ pull.

A new module-level helper `UnitAuraUpdateRequiresCdScan` consults the
event's second arg (`unitAuraUpdateInfo`) and short-circuits when none of
the six tracked Sated/Exhaustion debuff IDs appears in `addedAuras` and
the payload is not a full update. Conservative fallback: scan on
`isFullUpdate=true` or when the payload is missing, so `/reload`,
zone transitions and login still resync.

The Sated-ID list (`LUST_SATED_AURA_IDS`) mirrors the constant in
`isiLive_cd_tracker.lua` and is kept in sync at the file level so the
event filter and the scan agree on which IDs are load-bearing.

### SPELL_UPDATE_COOLDOWN / SPELL_UPDATE_CHARGES coalesced

Both events are notorious spam channels — every GCD start/end, every
charge regen tick, every item cooldown change in combat. The runtime
handlers `HandleSpellUpdateCooldownEvent` and
`HandleSpellUpdateChargesEvent` used to fire their downstream chain
(kick-tracker cache + teleport-button refresh, or full CD-tracker scan)
unthrottled on each event.

The new module-level builder `BuildSpellCooldownCoalescer` returns a
fresh closure pair per call so per-controller pending flags stay
isolated. Each handler sets a `pending` flag and schedules the
downstream dispatch via `C_Timer.After(0.1, ...)`; further events
within the 100 ms window are dropped. When no `C_Timer` is available
(test harness) the handler falls through to a synchronous dispatch so
the existing branch tests still observe the call in-tick.

### CdTracker 1 s ticker scan-gated

The 1 Hz ticker in
called `UpdateCdTracker()` every second while the main frame was shown,
even outside an M+ key with no active Bloodlust/Exhaustion countdown.
With the frame open in town that burned ~41 pcalls + a full
`RefreshCdTracker` every second for state that could not change.

The ticker now gates the work on (a) `MplusTimer.GetTimerData().running`
being true, or (b) the CD-tracker reporting an active Lust countdown
(`GetLustInfo().remain > 0`). Idle frames in town no longer poll
anything.

### Mob-nameplate `RefreshAll`: preallocated tokens + dirty checks

`mobNameplate.RefreshAll()` is subscribed to KillTrack updates
([factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua))
and therefore runs on every `SCENARIO_CRITERIA_UPDATE` (i.e. every mob
kill in M+) plus the KillTrack 0.5 s ticker. The loop in
allocated 40 fresh string concatenations (`"nameplate" .. i`) per call
and then re-applied font, frame size and text on every plate.

Three targeted dirty-tracking changes:

1. `NAMEPLATE_UNIT_TOKENS` is a module-level array built once at load
   so `RefreshAll` indexes the pre-allocated tokens instead of building
   them every call.
2. `ApplyFont` caches `fontString._lastFontSize`. The
   `SetFontObject` / `SetFont` / `SetTextHeight` chain runs only when
   the resolved size actually differs from the previous call. The
   `SetAppearance({fontSize})` settings path still triggers a fresh
   `SetFont` because the size value changes — verified by the existing
   `_setFontCallCount` test.
3. `ApplyFrameSizeForFont` caches `frame._lastSizeW / _lastSizeH`;
   `SetSize` only fires on actual dimension changes.
4. `SetText` on the percent FontString gates on
   `frame.text._lastText ~= text`, so repeated `RefreshAll` calls with
   unchanged percent text do not touch the FontString.

### Test changes

- `testmodul/isilive_test_scenarios_event_combat_startup.lua`:
  rewrote the existing UNIT_AURA scenario to validate the new filter
  contract: `isFullUpdate=true` and nil-payload trigger a scan;
  empty-payload / added-non-Sated-ID skip; added-Sated-ID triggers a
  scan. No other UNIT_AURA tests in the suite were affected.

All other behaviour stays intact — the `UpdateCdTracker → UpdateUI`
pin in `factory_secondary` still holds because `UpdateCdTracker` is now
just called less often, not changed internally.

### Secret-Value hardening on the new dirty-caches

In-game testing inside an active M+ keystone surfaced two Secret-Value
crashes that the initial dirty-cache implementations did not anticipate:

1. `UnitAuraUpdateRequiresCdScan` in
   [logic/isiLive_event_handlers_runtime.lua](../logic/isiLive_event_handlers_runtime.lua)
   inspected `aura.spellId` from `addedAuras` with
   `type(spellId) == "number"` followed by a direct
   `LUST_SATED_AURA_IDS[spellId]` lookup. In tainted M+/boss context the
   aura payload can carry Secret Values whose `type()` lies and reports
   `"number"`, but every table-index operation against the value raises
   `"attempted to index a table that cannot be indexed with secret keys"`.
   The whole lookup is now wrapped in pcall, mirroring the long-standing
   defence in `game/isiLive_cd_tracker.lua:ScanLust`.
2. `frame.text._lastText` cache in
   [ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua)
   stored the `text` output of `BuildText`, which concatenates the
   `percentString` returned by `C_ScenarioInfo.GetUnitCriteriaProgressValues`.
   In an active key that percent string can itself be a Secret string,
   poisoning `_lastText` and crashing the next compare. Both the
   compare-read and the cache-write are now pcall-guarded; the cache only
   stores the new value when a self-compare confirms it is safe.

Lesson recorded in the relevant code comments: any cache that holds a
value sourced from a WoW API needs pcall on both compare-read and
compare-write in 12.0+. `type()` is not a sufficient gate.

## 2026-05-11 - Version 0.9.231 (patch)

Cosmetic: the AddOn-list entry now reads as a three-color block instead
of a pale seven-step gradient that was invisible against the AddOn-list
background.

### TOC Title: `isi` default, `Live` dodgerblue, dropped plain-text suffix

`## Title:` was a linear gradient from `4da6ff` (pastel blue) to
`ffe633` (yellow) across seven letters PLUS a plain-text ` v0.9.XXX`
version suffix at the end. The AddOn list rendered the entry as plain
default-yellow because WoW's TOC title renderer falls back to plain
text as soon as the title string contains ANY plain-text outside
`|c...|r` color tag pairs — the trailing ` v0.9.230` after the last
`|r` disabled the entire color stack.

Three changes:

1. Title is now `isi|cff1e90ffLive|r`: the `isi` prefix is plain text
   (so it falls through to whatever default color the FontString uses
   — yellow in the AddOn list, accent-gold in the Settings canvas
   header), and only `Live` is explicitly colored dodgerblue
   (`#1e90ff`).
2. Plain-text version suffix removed from `## Title:`. The version
   itself is still authoritative in `## Version:` and `CHANGELOG_RELEASE.md`.
3. The plain `isi` prefix doubles as a sort-key fix: WoW sorts
   AddOn-list and Settings-sidebar entries by the raw title string.
   If the title starts with `|c...` the sort key begins with `|`
   (ASCII 0x7C), pushing the entry below every A-Z entry. A plain
   alphabetic prefix makes the sort key start with the letter, so
   the entry lands in the expected I-section.

### Blizzard Settings UI: same brand title

The Blizzard Settings sidebar entry (`RegisterCanvasLayoutCategory`) and
the canvas title-bar `FontString` both used to render the plain string
`"isiLive"` in default white / accent-gold. Both now use the same
`ISILIVE_BRAND_TITLE` constant — `isi` plain text + `Live` in dodgerblue
— so the AddOn appears with the same brand title in:

- the AddOn list (TOC `## Title:`)
- the Settings sidebar (Escape → Options → AddOns → isiLive)
- the Settings canvas header (the H1 at the top of the panel)

The canvas title-bar keeps its existing `ACCENT_GOLD` default so the
plain `isi` segment renders in the historical brand color, and the
embedded `|cff1e90ff...|r` in the title string colors only the `Live`
segment dodgerblue.
([ui/isiLive_settings.lua](../ui/isiLive_settings.lua))

Chat brand-prefix (`|cff4da6ffisiLive|r`) in
is left unchanged — it stays single-color blue for chat-line consistency.

No behaviour or test changes. ([isiLive.toc](../isiLive.toc), [ui/isiLive_settings.lua](../ui/isiLive_settings.lua))

## 2026-05-11 - Version 0.9.230 (patch)

UX polish on the post-accept Center Notice based on live testing feedback:
duplicate teleport button removed, auto-hide timer dropped in favour of
explicit dismissal.

### Notice no longer renders its own teleport button

The notice card used to carry a "Zum Dungeon teleportieren:" header above
a duplicate teleport-spell icon. The main M+ UI already highlights the
matching teleport button for the accepted dungeon, so a second button
inside the notice was pure visual redundancy. `RenderAcceptedInviteNotice`
now passes `dungeonName = nil` and `activityID = nil` to
`ShowCenterNotice`; `ConfigureCenterNoticeTeleportButton` early-returns
when both are absent, so neither the button nor its header label render.
The notice card collapses to title + four field rows (Dungeon, Gruppe,
Beschreibung, Rolle). ([factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua))

The `INVITE_ACCEPTED_NOTICE_TELEPORT_HEADER` locale key is removed from
all eight language tables — no longer referenced. The
`showOptions.teleportLabel` slot in `Notice.CreateCenterNotice` stays
available for other potential consumers.

### Notice is now persistent (no auto-hide)

The previous 12 s auto-hide window kept producing too-short visibility
windows during a busy invite sequence; the notice flickered away while
the player was still acting on the LFG popup. The notice now passes
`persistent = true` to `ShowCenterNotice`; it stays open until the user
right-clicks the frame, presses the red X, or another `ShowCenterNotice`
call replaces the content. ([factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua))

### Coverage

- `RegisterAcceptedInviteNoticeHelpers` test
  `RenderAcceptedInviteNotice forwards a populated payload` asserts the
  new contract: `mapName / activityID = nil`, `opts.teleportLabel = nil`,
  `opts.persistent = true`, no `holdTime`.
- 1659 / 1659 usecase scenarios pass; full local CI preflight
  (stylua, luacheck, syntax, metrics, locale, usecases, rules-logic) green.

## 2026-05-11 - Version 0.9.229 (patch)

Third follow-up on the post-accept Center Notice live testing — the previous
v0.9.228 fixes made the notice fire correctly for M+ invites, but it
flickered for ~1 second and then vanished. The Status controller's
non-Mythic dungeon-entry warning owned a leave-path that called
`hideCenterNotice()` unconditionally on every non-dungeon
`INSTANCE_CONTEXT_CHANGED` / `PLAYER_ENTERING_WORLD` / `OWNED_KEY_CONTEXT`
event, and one of those fires reliably right after `inviteaccepted`.

### Fix: leave-dungeon hide path no longer kills foreign notices

`MaybeShowNonMythicDungeonEntryNotice` now tracks ownership of the
shared center-notice frame via a `state.nonMythicNoticeShown` flag.
The leave-dungeon branch only calls `deps.hideCenterNotice()` when the
flag is set (= this controller actually rendered the warning), and
clears the flag afterwards. Other notice consumers (Accepted-Invite,
Lead-Transfer, Test-Mode) keep their notices for the full duration
they configured. ([ui/isiLive_status.lua](../ui/isiLive_status.lua))

### Coverage uplift

- `RegisterDungeonDifficultyTests` gains two scenarios: hide is NOT
  called when the controller never showed its own warning, and hide
  IS called exactly once on real dungeon-leave when the controller's
  own warning is up.
- 1659 / 1659 usecase scenarios pass; full local CI preflight
  (stylua, luacheck, syntax, metrics, locale, usecases, rules-logic) green.

## 2026-05-11 - Version 0.9.228 (patch)

Two regressions in the post-accept Center Notice pipeline from v0.9.223/224
that surfaced in live testing. Both have regression scenarios.

### Fix: Raid LFG invites no longer trigger the M+ Center Notice

`MapIDFromActivityID` accepted every LFG activity that exposed a positive
`mapID`, including Raid, PvP, Scenario and Heroic listings. When the
player accepted a Raid LFG invite, the listing's mapID flowed through
`pendingInvites` → `OnInviteAccepted` → Center Notice and the chat
"Target Dungeon" announce — both Mythic+-only paths. The notice rendered
with a fallback "Unknown dungeon" label (because the Raid mapID is not
in the Teleport DB) but should never have appeared at all.

Filter on `info.isMythicPlusActivity == true` before accepting the mapID
from `C_LFGList.GetActivityInfoTable`. Activities in the static
`ACTIVITY_TO_MAP` table are unaffected; all eight active-season entries
are M+ dungeons. ([game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua))

### Fix: M+ accept after group-leave no longer silently drops

When the player held two parallel LFG applications, the group-leave
reset (`ClearAllStateImpl`) swept every pending invite into the
`suppressedInviteAccepts` bucket. The next `inviteaccepted` event for
the still-open M+ application then found `entry == nil` AND the
suppressed guard set, skipped the `ResolveInviteEntry` fallback, and
returned with `mapID == nil`. No Center Notice, no chat announce,
no teleport highlight. Reproduction:

1. User has parallel Raid + M+ LFG applications.
2. Raid leader invites; user accepts → joins raid.
3. User leaves the raid → `GROUP_ROSTER_UPDATE` (no members) →
   `ClearAllStateImpl` → M+ pending invite promoted to suppressed.
4. M+ leader invites; user accepts → `inviteaccepted` arrives but
   `OnInviteAccepted` is silently no-op.

`ClearAllStateImpl` now drops `pendingInvites` without promoting any
entries to `suppressedInviteAccepts`. The suppressed bucket is reserved
for its original purpose: the `decline → stray accept` race for the same
`searchResultID` (still set inside `OnInviteDeclined`).
([game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua))

### Coverage uplift

- `RegisterLFGDetectAcceptedInviteNoticeTests` Test G: mock activity
  with `isMythicPlusActivity = false` must not trigger the notice or
  populate `detectedMapID`.
- Test H: `invited` → `GROUP_ROSTER_UPDATE` (no members) →
  `inviteaccepted` must still resolve via the API fallback.
- Existing "group leave clears all state" test in
  `RegisterLFGDetectQueueStateTests` rewritten: the late accept after
  the leave must now re-resolve, not stay silent.
- 1657 / 1657 usecase scenarios pass; full local CI preflight
  (stylua, luacheck, syntax, metrics, locale, usecases, rules-logic) green.

## 2026-05-11 - Version 0.9.227 (patch)

Full-codebase review pass: 13 fixes plus one frozen-timer carry-over from
the previous patch series. Most are taint-defensive (`pcall` wraps around
Blizzard APIs that other call sites already guarded) or race fixes in
event-driven state machines (ready-check, spec-cache, LFG recovery,
roster ghost handling). No new features, no UI changes a user would
notice, except the BR/Lust announce now fires exactly once for the
caster.

### State-machine race fixes

- **LFG recovery branch was permanently neutralised after the first
  decline in a push-lobby session.** `OnInviteDeclined` writes
  `pendingInvites[id] = false` (a sentinel that survives the lifetime
  of the application so the same invite can't be re-accepted), and the
  GROUP_ROSTER_UPDATE race-recovery used `next(pendingInvites) == nil`
  to mean "no invites left to wait for". `next()` happily returns
  false-valued keys though, so once any decline arrived the recovery
  fallback to `CheckActiveGroup()` was skipped for the rest of that
  group session. Walk the table explicitly and only fall back when no
  table-shaped (= unresolved) entry remains. Restores the ffda54b
  determinism patch's effectiveness in push-lobby spam.
  ([game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua))

- **Stale ready-check marks at M+ start.**
  `HandleChallengeModeStart` flipped `readyCheckActive=false` but left
  `readyCheckReadyUnits` / `readyCheckDeclinedUnits` /
  `readyCheckHoldUntil` populated. If a READY_CHECK landed seconds
  before the key start and READY_CHECK_FINISHED never fired between
  the two events (observed when the leader insta-starts), per-unit
  marks carried into the run and showed in the roster panel. Reuse
  the existing `ResetReadyCheckDeclinedTracking` helper.
  ([logic/isiLive_event_handlers_challenge.lua](../logic/isiLive_event_handlers_challenge.lua))

- **Player spec column went empty after login.**
  `PLAYER_SPECIALIZATION_CHANGED` frequently fires before the first
  `GROUP_ROSTER_UPDATE` during the PLAYER_LOGIN handshake.
  `RefreshPlayerSpecCache` silently returned false because `roster.player`
  did not exist yet, and the change was never re-tried — the spec
  column then stayed blank until the next user-driven spec switch. Re-run
  the helper right after `handleGroupRosterUpdate` so the pending change
  lands as soon as the player's row is built.
  ([logic/isiLive_event_handlers_runtime.lua](../logic/isiLive_event_handlers_runtime.lua))

- **Ghosts leaked into the owner-key fallback and the RIO baseline.**
  The leader-resolution path already filtered `info.isGhost`, but the
  any-member-consensus fallback (used when `UnitIsGroupLeader` is
  unavailable) and `CaptureRioBaselineSnapshot` iterated the full
  roster including ghosts of members who had already left. Subsequent
  RIO delta calculations then showed deltas for non-present players.
  ([factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua))

### Sync / chat correctness

- **BR/Lust announce fired twice for the caster.**
  `BroadcastCombatAnnounce` already renders the announce locally before
  sending the wire message. `CHAT_MSG_ADDON` echoes back to the sender,
  so without a `senderKey ~= selfKey` guard the BRLUST branch returned
  a second `combatAnnounce` for the caster's own cast — the line printed
  twice and `PlayBattleRes` / `PlayBloodlust` played back-to-back. Other
  self-receive branches (KEY/STATS/DPS/LOC/TARGET/KICK) write the caster's
  own data into their own peer slot, which is benign — the data is
  correct either way. BRLUST is the only branch whose return value
  triggers a side effect outside the sync cache.
  ([logic/isiLive_sync.lua](../logic/isiLive_sync.lua))

- **LFG-flags name-realm split broke for US realm Area-52.**
  `SplitNameRealm` used the greedy `^(.+)-(.+)$` pattern, so
  `"Player-Area-52"` resolved to `("Player-Area", "52")` instead of
  `("Player", "Area-52")`. The four other name-realm splitters in the
  codebase all consume the first dash only — bring this one in line.
  ([ui/isiLive_lfg_flags.lua](../ui/isiLive_lfg_flags.lua))

### Settings / DB

- **Legacy users got both nameplate AND tooltip M+-forces displays at
  the same time.** Pre-nameplate users only ever persisted
  `mplusForcesEstimate=true`. `DBSchema.Sanitize` now fills the schema
  default `mobNameplateEnabled=true` before `ApplyDBSettings` runs, so
  both flags end up true and both modules activate. The settings UI
  enforces mutual exclusion through the display-mode selector — any
  both-true state is uniquely a legacy collision. Detect it and clear
  `mobNameplateEnabled` to honour the prior tooltip-only choice.
  ([factory/isiLive_factory.lua](../factory/isiLive_factory.lua))

### WoW 12.0+ taint defense

- **Five Blizzard-API call sites that other code paths already wrap
  in `pcall` were calling directly.** In tainted contexts (M+ keys,
  encounters) any of these can raise and tear down the addon's
  event-dispatch chain:
  - `controller_wiring.sendAck` — `C_ChatInfo.SendAddonMessage` WHISPER
    for ACKs.
  - `queue.CaptureQueueJoinFromApplications` —
    `C_LFGList.GetApplications`. Sibling call in
    `game/isiLive_lfg_detect.lua` already had the guard.
  - `status.GetDungeonDifficultyLabel` — `GetInstanceInfo` and
    `C_ChallengeMode.GetActiveChallengeMapID`.
  - `factory_controllers.IsInPartyInstance` — `GetInstanceInfo`.
  - `units.GetUnitRoleOrSpec` / `units.GetPlayerSpecName` —
    `GetSpecialization`, `GetSpecializationRole`, `GetSpecializationInfo`.
  Happy path unchanged; on raise we now bail out the way other call
  sites already do.

### UI lifecycle

- **Teleport buttons leaked frame references on every re-build.**
  `BuildButtonsInternal` cleared the `buttons` table without hiding
  the previous frames first. The old buttons stayed parented to
  `mainFrame` with their secure attributes intact, leaking ghost
  frames after any re-build (layout change, locale switch). The
  `HideExistingButtons` helper was already defined a few lines above
  — just call it.
  ([ui/isiLive_teleport_ui.lua](../ui/isiLive_teleport_ui.lua))

### Data hygiene

- **`LUST_SATED_IDS` mixed Bloodlust cast IDs with the actual debuff
  IDs.** `ScanLust` scans HARMFUL auras, so the cast IDs (2825 Bloodlust,
  32182 Heroism, 80353 Time Warp, 264667 Primal Rage, 390386, 178207,
  230935, 256740, 381301, 16045) could never match — they exist as
  helpful buffs, not debuffs. Kept only the six real debuff IDs
  (57723 Exhaustion, 57724 Sated, 80354 Temporal Displacement,
  264689 Fatigued, 390435 Ancient Hysteria Exhaustion, 95809 Insanity)
  with per-ID comments.
  ([game/isiLive_cd_tracker.lua](../game/isiLive_cd_tracker.lua))

### Trace correctness

- **Keystone trace log was useless.** Two trace lines in the
  send-own-keystone path called `#roster` on a unit-token-keyed hash
  map (always 0) and deref'd `snapshot.mapID/.level` on a multi-return
  result (always nil). Memberless logs and nil/nil snapshots made the
  trace impossible to interpret. Switched to a `pairs()` count and
  multi-return unpack.
  ([factory/isiLive_controller_wiring.lua](../factory/isiLive_controller_wiring.lua))

### Stability

- **Death-penalty display flickered 75s -> 0 -> 75s.**
  `C_ChallengeMode.GetDeathCount` can momentarily return nil for
  `timeLost` mid-key (secret-value masking on tainted reads). The
  previous code fell back to 0 on every transient mask. Only overwrite
  when the API returned a real number.
  ([game/isiLive_mplus_timer.lua](../game/isiLive_mplus_timer.lua))

- **Post-completion M+ timer snapshot didn't clear on zone change.**
  Carried over from the previous patch series — clears the frozen
  state on `PLAYER_ENTERING_WORLD` so the timer no longer shows the
  last run's numbers after leaving the dungeon.
  ([game/isiLive_mplus_timer.lua](../game/isiLive_mplus_timer.lua))

### Code-base notes

- **Documented a deliberate API-isolation pattern that recurring
  reviewers kept flagging as a bug.** The runtime `ShowCenterNotice`
  drops `dungeonName` / `activityID` on purpose: the factory wrapper
  layer threads them through when a teleport button on the notice is
  wanted, while the runtime path must not. Locked in by the
  "strips dungeon context" contract test in
  `testmodul/isilive_test_scenarios_ui_frame_bridge.lua`.
  ([factory/isiLive_frame_bridge.lua](../factory/isiLive_frame_bridge.lua))

## 2026-05-11 - Version 0.9.226 (patch)

Bug fix for the "Ziel-Dungeon" chat announcement and post-accept Center
Notice when the player has several parallel LFG applications pending. In
practice that's the 95 % case — players apply to 3–5 listings for the same
dungeon at different key levels (and often to siblings for different
dungeons too). Until now the chat could surface a non-accepted listing's
dungeon name or key level, while the portal-icon highlight stayed correct.

### Root cause

`LFGDetect.HandleEvent("GROUP_ROSTER_UPDATE")` carries a race-recovery
branch for the case where `GROUP_ROSTER_UPDATE` arrives **before** the
`LFG_LIST_APPLICATION_STATUS_UPDATED("inviteaccepted")` event sets the
authoritative state. That branch used `next(pendingInvites)` to fish out
an entry — Lua table iteration order is **defined as unspecified**, so
with N parallel pending invites the resolver picked 1-of-N at random,
**guessing** which invite the player had just accepted. The wrong entry
was then *consumed* (`pendingInvites[resultID] = nil`), so the real
`inviteaccepted` arriving shortly after could no longer find its
`pendingInvites` entry — `ResolveInviteEntry` re-resolved live against
a frequently delisted `C_LFGList.GetSearchResultInfo` and bailed,
leaving `detectedMapID`, `activeInviteLeader` and
`activeInviteTitleLevel` stuck on the guessed values.

The UI portal highlight stayed correct because it routes through a
different code path (direct `lfgDetect.GetDetectedMapID()` → spell-by-mapID
lookup) and re-fires from `OnInviteAccepted` independently of the racy
branch.

### Fix

Two new helpers in [game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua)
replace the `next()`-shortcut with a strictly deterministic 3-stage
resolver:

1. **Authoritative WoW API lookup** — `FindAcceptedSearchResultID` calls
   `C_LFGList.GetApplications` and iterates `GetApplicationInfo` for the
   one application whose `appStatus == "inviteaccepted"`. Single source
   of truth from Blizzard; `pcall`-guarded and case-normalized so 12.0+
   taint or casing variations are handled the same as the existing
   `HandleApplicationStatus` path. Returns the API-named `searchResultID`.
2. **Unambiguous-single fallback** — `ResolveAcceptedPendingInvite` only
   uses `pendingInvites` when **exactly one** entry exists. With a single
   candidate there is nothing to guess.
3. **Defer** — multiple pending entries + API silent → return nil, do
   nothing for this tick. The subsequent explicit `inviteaccepted` event
   arrives with its own authoritative `searchResultID` and recovers via
   the existing `OnInviteAccepted` path. `pendingInvites` is never
   speculatively consumed.

When the API names a `searchResultID` for which `OnInvited` was never
seen (very short listings), the resolver falls back to live
`ResolveInviteEntry(searchResultID)` rather than fabricating values.

### Tests

- New end-to-end simulator `tools/simulate_multi_invite_accept_race.lua`
  exercises the real `LFGDetect` module through the real event
  dispatcher across five cases:
  - Three pending invites, API names ID 3 as accepted → resolver picks
    ID 3 deterministically; the other two `pendingInvites` entries
    survive (verified by a follow-up `inviteaccepted` for ID 2 that
    transitions cleanly to its dungeon/level).
  - Single pending + API silent → unambiguous fallback fires.
  - Three pending + API silent → defer; resolver state stays `nil`; the
    real `inviteaccepted` then sets the right state.
  - API names a `searchResultID` outside `pendingInvites` → live
    re-resolution via `C_LFGList.GetSearchResultInfo`.
  - Regression: single-apply + GROUP_ROSTER_UPDATE first + API
    unavailable still resolves (the original safety-net intent).
- The existing `tools/simulate_multi_invite_target_chain.lua` (level-
  flicker / chat-lock end-to-end) continues to pass unchanged — the new
  resolver is additive, the title-level lock-in stays intact.



Bug fix for the M+ timer box in the combat-utility tracker row. After a
key ended (success or out-of-time) the timer kept showing the final
`+3/+2/+1` cutoff values until the player either started another key,
reloaded the UI (`/reload`) or relogged. Zoning out of the dungeon did
not clear the stale snapshot.

### Root cause

`CHALLENGE_MODE_COMPLETED` runs `StopTimer(true)` in
[game/isiLive_mplus_timer.lua](../game/isiLive_mplus_timer.lua), which sets
`running=false, completed=true` and unhooks the per-tick `OnUpdate`. The
timer value, time limits and death-penalty counters stay frozen so the
final result is visible while the group is still in the dungeon. The UI
in [ui/isiLive_roster_panel_cd_row.lua](../ui/isiLive_roster_panel_cd_row.lua)
keeps rendering the timer box as long as `data.running or data.completed`
is true — and `completed` was never cleared on a natural zone exit. Only
`CHALLENGE_MODE_RESET` (manual key abandon from the keystone podium)
wiped the state.

### Fix

- New `PLAYER_ENTERING_WORLD` branch in `MplusTimer.HandleEvent` clears
  the frozen post-completion snapshot (`completed=false`, `timer=0`,
  `timeLimit=0`, `timeLimits={0,0,0}`, `deaths=0`, `deathTimeLost=0`)
  the next time the player zones. The branch is gated on
  `state.completed and not state.running`, so a mid-key `PEW` (UI reload
  while still inside the dungeon) does not abort an active timer.
- [logic/isiLive_event_handlers_runtime.lua](../logic/isiLive_event_handlers_runtime.lua)
  dispatches `PLAYER_ENTERING_WORLD` to the M+ timer alongside the
  existing KillTrack dispatch — same site, one extra line, no new event
  registration.
- Three new scenarios in `testmodul/isilive_test_scenarios_mplus_timer.lua`
  cover the three relevant states: `PEW` after `COMPLETED` clears the
  snapshot, `PEW` mid-key is a no-op, `PEW` on a fresh idle state is a
  no-op. The behaviour is gated by the new `RULE-MPLUS-TIMER-PEW-RESET`
  in [docs/RULES_LOGIC.md](RULES_LOGIC.md).

## 2026-05-10 - Version 0.9.225 (patch)

Bug fix for the Travel-panel Hearthstone button. After switching to another
character on the same WoW account, the button could stay stuck on the regular
Hearthstone item (item:6948) for the entire session — clicking did nothing on
characters that did not carry that item in their bags.

### Root cause

`UI.EnsureSecondPanelUI` is invoked from `ApplyLocalizationToUI`, which runs
from the `ADDON_LOADED` handler in [logic/isiLive_event_handlers_runtime.lua](../logic/isiLive_event_handlers_runtime.lua).
At that point the account-wide toy collection cache is often not yet warm:
`PlayerHasToy(...)` returns `false` for every hearthstone toy ID, so the
setup loop fell through to the `type=item, item=item:6948` fallback. The
panel state is cached for the whole session — the toy list was never
rebuilt, even after `TOYS_UPDATED` fired moments later.

### Fix

- New `CollectOwnedHearthstoneToys()` helper in [ui/isiLive_ui.lua](../ui/isiLive_ui.lua)
  centralises the `PlayerHasToy` scan.
- A static `hearthstoneToysEventFrame` registers `TOYS_UPDATED` and rebinds
  the secure button to a random owned toy as soon as the cache is available
  (combat-lockdown guarded, matches the existing housing-button pattern).
- The `PreClick` hook now also rebuilds the toy pool lazily when it is
  still empty — so the very first click after a cold login self-heals the
  button instead of casting the missing item fallback.



Visual rework of the post-accept Center Notice introduced in v0.9.223. The
previous subline-stack layout (small "Beigetreten" header + center text +
small group line + teleport button) was too unobtrusive in live testing and
got missed. The notice now uses a structured info card: title bar with
separator, label/value field rows, and a teleport section header above
the button.

### Center Notice rich layout (info card)

When the player accepts an LFG invite, the notice renders as a focused 540px
card with a clear visual hierarchy:

```
┌─────────────────────────────────────┐
│ isiLive - Einladung angenommen   [X]│   <- title (orange-red, GameFontNormalLarge)
│ ─────────────────────────────────── │   <- gold-tint separator (1px)
│  Dungeon:    Akademie v. Algeth'ar +13│   <- label (gold) / value (warm white)
│  Gruppe:     +13 Push-Lobby         │
│  Beschreibung: Achiever 2.5k io     │
│  Rolle:      Schaden                │
│  Zum Dungeon teleportieren:         │   <- teleport section header (gold)
│              [TP-Icon]              │
└─────────────────────────────────────┘
```

- **Title bar + separator**: a leading "isiLive - Einladung angenommen"
  header (warm orange-red, `GameFontNormalLarge`+2pt) sits above a 1px gold-
  tint separator, mirroring the PortalNavigator visual language.
- **Label / value field rows**: pre-allocated 4 rows in `Notice.CreateCenterNotice`,
  rendered in fixed order: Dungeon, Gruppe, Beschreibung, Rolle. Optional
  rows (Beschreibung, Rolle) are dropped when their source is missing —
  never filled with `-` or "Unknown" placeholders. Beschreibung sources
  `info.comment` from the LFG listing; Rolle uses `Units.GetUnitRole("player")`
  which prefers `GetSpecializationRole` over `UnitGroupRolesAssigned` so the
  spec switch is reflected immediately.
- **Teleport section**: localized "Zum Dungeon teleportieren:" label above
  the existing teleport button. Same activityID-resolved teleport spell as
  before — only the surrounding chrome changed.
- **Compact 540px frame**: the rich card resizes the notice frame to 540px
  for the duration of the accepted-invite render. Other notice consumers
  (Lead Transfer, Non-Mythic-Entry, Test Mode) reset to the 680px default
  on their next Show — no cross-contamination.

### Notice API extension

`ShowCenterNotice` learned three orthogonal modes selected per Show call:

- **Legacy single-line** (Lead Transfer, Non-Mythic-Entry): just `message`.
  Unchanged.
- **Stack mode** (`showOptions.sublineTop` / `sublineBottom`): introduced in
  v0.9.223, still available, no consumers in this release.
- **Rich mode** (`showOptions.title` / `fields` / `teleportLabel`): new.
  Hides the regular text body and the sublines, renders the structured
  card via pre-allocated FontStrings + a separator texture.

`showOptions.frameWidth` was added so rich consumers can resize the frame
without touching the default 680px banner width used by legacy notices.

### LFG-Detect: `info.comment` propagation

`ResolveInviteEntry` now also captures the listing's free-form description
field (`info.comment` from `C_LFGList.GetSearchResultInfo`) and threads it
through `OnInviteAccepted` -> `acceptedInviteNoticeCallback` payload.
`pendingInvites[searchResultID]` is still the single source of truth for
the rendered content; sibling-listing comments cannot leak into the notice.

### Locale changes (8 languages)

Removed (no longer used by any consumer):

- `INVITE_ACCEPTED_NOTICE_SUBLINE_TOP`
- `INVITE_ACCEPTED_NOTICE_GROUP`

Added:

- `INVITE_ACCEPTED_NOTICE_TITLE` ("isiLive - Einladung angenommen")
- `INVITE_ACCEPTED_NOTICE_LABEL_DUNGEON` / `_GROUP` / `_DESCRIPTION` / `_ROLE`
- `INVITE_ACCEPTED_NOTICE_TELEPORT_HEADER` ("Zum Dungeon teleportieren:")
- `ROLE_NAME_TANK` / `ROLE_NAME_HEALER` / `ROLE_NAME_DAMAGE`

Kept:

- `INVITE_ACCEPTED_NOTICE_HEADLINE_WITH_LEVEL` / `_NO_LEVEL` (now used for
  the Dungeon-row value, not the headline).
- `SETTINGS_ACCEPTED_INVITE_NOTICE_ENABLED`.

### Coverage uplift

- New `RegisterLFGDetectAcceptedInviteNoticeTests` D2 scenario: `info.comment`
  flows through to the payload when present, and stays `nil` when absent.
- New `RegisterCenterNoticeRichLayoutTests` (5 scenarios): primitives exposed,
  rich Show renders all four slots, frameWidth resizes the frame, transition
  rich -> legacy hides rich primitives, fields-only renders without title.
- 1631 / 1631 usecase scenarios pass; full local CI preflight (stylua,
  luacheck, syntax, metrics, locale, usecases, rules-logic) green.

## 2026-05-10 - Version 0.9.223 (minor)

Re-introduces the post-accept Center Notice that was removed in v0.9.211 when
the dead-code `logic/isiLive_queue_flow.lua` was deleted. The notice now
fires from the LFG-detect layer, sources its data exclusively from the
accepted invite's `pendingInvites` entry, and renders a modern two-line
layout (subline + headline + group subline + teleport button) using the
existing `ShowCenterNotice` infrastructure.

### Center Notice after accepted LFG invite (re-activated, modernised)

When the player accepts an LFG invite, a center-screen notice now appears
showing the dungeon name and key level (e.g. `Windrunner Spire +15`) plus
the LFG group title and a teleport button. The notice auto-hides after
12 seconds or on right-click.

- **Multi-invite correctness**: when the player holds parallel LFG invites
  (push lobbies routinely post `+12 / +13 / +14` for the same dungeon, or
  totally different dungeons), the notice payload comes from the exact
  `searchResultID` the player accepted. Sibling listings — including ones
  that get delisted or declined right after the accept — cannot influence
  the rendered content. The same `acceptedInviteSearchResultID` guard that
  e39f98c (v0.9.213) introduced for the chat announce now also gates the
  notice.
- **Level source has zero guessing**: the level comes straight from
  `entry.titleLevel` (the `+N` parsed from the accepted listing's group
  title). When the title carries no `+N` marker (`"chill spire run"`),
  the notice renders the headline without `+N`. It does **not** fall
  through to roster-owner key levels or synced-target levels — that path
  belongs to the post-accept chat announce, not the notice. The two
  channels stay separate so the notice can never lock onto a sibling
  listing's level via roster sync.
- **Modern stack layout**: `ShowCenterNotice` learned an optional
  `showOptions.sublineTop` / `showOptions.sublineBottom` mode that
  renders three text rows (small gold subline + large warm-white
  headline + small grey group subline) plus the teleport button below.
  The legacy single-line layout used by lead-transfer, non-mythic-entry,
  and test-mode notices is unchanged — both paths share the same frame
  and the same close/right-click semantics.
- **New setting**: `acceptedInviteNoticeEnabled` (default on), separate
  from the existing pre-accept `inviteHintEnabled` toggle so the two
  UX stages can be controlled independently. Live-read per trigger,
  no `/reload` needed.
- **Wiring**: `LFGDetect.SetAcceptedInviteNoticeCallback` /
  `SetAcceptedInviteNoticeEnabledFn` injected from the factory next to
  the existing `SetInviteHintCallback` block. `ResolveInviteEntry` now
  also returns the listing's primary `activityID` so the notice's
  teleport button can be wired without a second API roundtrip.

### Coverage uplift

- `testmodul/isilive_test_scenarios_lfg_detect.lua`:
  `RegisterLFGDetectAcceptedInviteNoticeTests` adds 6 scenarios covering
  the multi-invite race (same-dungeon different-level, different-dungeon
  parallel invites), sibling-decline-after-accept, missing `+N` in title,
  toggle-off, and missing-callback wiring.
- `testmodul/isilive_test_scenarios_ui_notice_branches.lua`:
  `RegisterCenterNoticeSublineTests` adds 5 scenarios for the new
  subline layout (default-hidden, render-both-sublines, legacy-single-line
  preserved, reset between consecutive Show calls, empty-string
  treated as absent).
- 1625 / 1625 usecase scenarios pass; full local CI preflight (stylua,
  luacheck, syntax, metrics, locale, usecases, rules-logic) green.

## 2026-05-09 - Version 0.9.222 (patch)

Internal refactor and routine M+ data refresh. No user-facing changes; all
prior behavior is preserved (1614/1614 usecase scenarios pass, full local CI
preflight green).

### M+ forces database refreshed from MDT 6.1.2

The auto-sync workflow (`tools/sync_mdt_forces.ps1`) regenerated
[data/isiLive_mplus_forces.lua](../data/isiLive_mplus_forces.lua) against
upstream MythicDungeonTools 6.1.2. Tooltip / nameplate forces overlays
follow the latest mob counts and dungeon totals; lifetime stamp pushed
forward to keep the `tools/check_mplus_db_lifetime.lua` gate green.

### Long functions in keysync and kick_tracker split into focused helpers

`logic/isiLive_keysync.lua::ApplyKnownKeyToRosterEntry` was 174 LOC of
inline branches for key/stats/dps/loc/kick backfill plus kick-extras
interpolation and drift detection. The body is now five `BackfillKey` /
`BackfillStats` / `BackfillDps` / `BackfillLoc` / `BackfillKick` helpers
plus six pure sub-helpers (`InterpolateKickRemain`, `InterpolateKickExtras`,
`DidExtrasChange`, `ClearKickFields`, `ApplyHasNoKick`, `ApplyActiveKick`,
`ResolveElapsedSinceReceived`); the main function shrinks to 22 LOC.

`game/isiLive_kick_tracker.lua::CreateController` (408 LOC closure) gets
five pure helpers extracted to module scope: `IsExtraKickSpellForClass`,
`LookupExtraKickCd`, `ApplyTalentCdReduction`, `ForEachActiveTalentDefinition`,
`CollectActiveExtras`. `ScanOwnTalents` collapses from ~54 LOC to ~14
via the iterator-callback pattern. `CreateController` itself drops to 312 LOC.

- **Refactor** ([logic/isiLive_keysync.lua](../logic/isiLive_keysync.lua),
  [game/isiLive_kick_tracker.lua](../game/isiLive_kick_tracker.lua))
  — semantically identical; all condition flips use De-Morgan equivalence
  (`A ~= a or B ~= b` ↔ `not (A == a and B == b)`).
- **Verification** — `tools/validate_usecases.lua` 1614/1614 pass,
  `tools/validate_ci_local.ps1` (stylua, luacheck, syntax, metrics, locale
  drift, M+ DB lifetime, usecases) all green; pure helpers are now
  callable from tests without instantiating a controller.

### Interrupt-audit skill reference refreshed for Midnight values

The `interrupt-audit` skill's reference table in
(canonical source in the workspace repo) had stale CD values for two
specs that no longer matched the in-game tooltip:

- Solar Beam (Druid Balance) `60s` → `45s` (Midnight value).
- Quell (Evoker, all specs) `20s` → `18s` (Midnight value).
- Holy Paladin (spec 65) and Mistweaver Monk (spec 270) split out as
  no-interrupt specs (matches `NO_INTERRUPT_SPEC_IDS` in
  `kick_tracker.lua`).
- Demo Warlock Axe Toss spell ID corrected to player-facing `119914`
  (pet-cast event ID `89766` noted as comment).

The live `SPEC_DATA` table already had the correct Midnight values; only
the audit-skill reference was lagging.

## 2026-05-06 - Version 0.9.221 (patch)

Bug fix to the kick-tracker base cooldown for Mage Counterspell, plus a large
internal test-coverage push (no other runtime changes).

### Mage Counterspell base cooldown corrected to the in-game tooltip value

`SPEC_DATA[62/63/64].cd` was set to `20` with comment "Counterspell (20s base)",
but the in-game spell tooltip is `25` seconds. The talent *Geistesgegenwärtig*
(spellID 382297) reduces Counterspell by 5 seconds, taking it from 25 → 20.
`CD_REDUCTION_DEFS[382297]` already had `reduction = 5` with comment "Counterspell
25→20", so the two sources were inconsistent.

In real WoW, `GetSpellBaseCooldown(2139)` returns 25000ms and overrides the
SPEC_DATA value at runtime via `ReadBaseCd`, so the tooltip user saw the correct
number. The SPEC_DATA fallback (kick-tracker without talent-scan path or with a
mocked `GetSpellBaseCooldown`) was wrong.

- **Fix** ([game/isiLive_kick_tracker.lua](../game/isiLive_kick_tracker.lua)) —
  `cd = 20` → `cd = 25` across all three Mage specs; comment updated to
  "25s base; talent 382297 reduces to 20".
- **Test** ([testmodul/isilive_test_scenarios_kick_tracker.lua](../testmodul/isilive_test_scenarios_kick_tracker.lua))
  — `GetSpellBaseCooldown` mock for spell 2139 returns 25000ms (matches real WoW).

Per the CLAUDE.md tooltip rule: external interrupt-tracker addons are not
authoritative; the in-game spell tooltip is.

### Refactor — LFGDetect activityIDs guard inline (LSP fix, behaviour unchanged)

`ResolveInviteEntry` ([game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua))
tracked an intermediate `hasActivityIDs` boolean that the Lua language server
could not flow-narrow through. Inlining the guard at the call sites and switching
the two mutually-exclusive activityIDs / activityID branches to `if / elseif`
restores flow-narrowing without changing runtime behaviour.

### Branch-coverage push — 88.72% → 91.35%

Targeted branch tests across 19 files; no production changes apart from the two
items above. Highlights — every file moved out of the bottom of the per-file
coverage list:

- `logic/isiLive_events.lua`: 80.00% → 92.73%
- `ui/isiLive_teleport_debug.lua`: 80.92% → 97.37%
- `ui/isiLive_roster_panel_render.lua`: 80.72% → 86.65%
- `logic/isiLive_commands.lua`: 81.62% → 92.89%
- `ui/isiLive_mob_nameplate.lua`: 81.54% → 84.84%
- `game/isiLive_season_data.lua`: 81.67% → 99.39%
- `ui/isiLive_ui_common.lua`: 82.02% → 84.74%
- `logic/isiLive_test_mode.lua`: 82.48% → 99.27%
- `logic/isiLive_queue.lua`: 82.56% → 84.20%
- `logic/isiLive_inspect.lua`: 83.33% → 95.00%
- `game/isiLive_spell_utils.lua`: 83.75% → 100.00%
- `logic/isiLive_event_handlers_runtime.lua`: 84.60% → 90.85%
- `locale/isiLive_locale.lua`: 84.80% → 93.14%
- `logic/isiLive_event_handlers_challenge.lua`: 85.23% → 90.93%
- `core/isiLive_error_log.lua`: 85.29% → 93.38%
- `game/isiLive_killtrack.lua`: 86.54% → 93.75%
- `ui/isiLive_roster_panel_cd_row.lua`: 86.22% → 97.24%
- `logic/isiLive_keysync.lua`: 87.16% → 92.36%
- `game/isiLive_lfg_detect.lua`: 89.25% → 92.20%

Total usecase scenarios: 1614 (was 1454).

## 2026-05-05 - Version 0.9.220 (patch)

Follow-up to v0.9.219: pure intra-role spec swaps (e.g. Mage Arcane → Frost, both DAMAGER) updated the cached spec name but skipped the `updateUI` call because `RefreshRosterRoles` only fires `updateUI` when the role itself changed. Result: the spec column kept showing the old spec name until the next full GROUP_ROSTER_UPDATE.

- **Fix** ([logic/isiLive_event_handlers_runtime.lua](../logic/isiLive_event_handlers_runtime.lua)) — `RefreshPlayerSpecCache` now returns a boolean indicating whether `info.spec` changed; `HandlePlayerSpecializationChangedEvent` calls `ctx.updateUI()` whenever the spec changed even if the role stayed the same. The role-flip path keeps its existing `updateUI` from `RefreshRosterRoles`, so a Druid Balance → Guardian swap still renders both updates without a double refresh that matters.
- **Test**: new branch test "PLAYER_SPECIALIZATION_CHANGED triggers updateUI on intra-role spec swap (Arcane → Frost)" pins the bug. Total usecase scenarios: 1454 (was 1453).

## 2026-05-05 - Version 0.9.219 (patch)

Two roster bugs that surfaced under the WoW 12.0+ secret-value / secret-token regression chain: the cached role + spec did not follow live in-game changes, and the role-marker click failed on the local-realm player because the `/target` macro carried a home-realm suffix that WoW cannot resolve.

### Live role + spec refresh on `PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_ROLES_ASSIGNED`, `ROLE_CHANGED_INFORM`

Switching specs (e.g. Druid Balance → Guardian, Death Knight Unholy → Blood) or flipping the assigned group role via right-click portrait / `/role` previously did not update the cached `info.role` and `info.spec` on the roster row — only the next full `GROUP_ROSTER_UPDATE` (which does NOT fire on role-only or spec-only changes) would refresh it.

- **Three new event registrations** ([core/isiLive_bootstrap.lua](../core/isiLive_bootstrap.lua)) — `PLAYER_ROLES_ASSIGNED` (LFG role-check finalisation), `ROLE_CHANGED_INFORM` (real-time in-group role flip via right-click portrait / `/role`), and routing `PLAYER_SPECIALIZATION_CHANGED` (already registered) through the same role-refresh path. All three are `hidden = true` so the cache stays warm even when the main frame is closed.
- **`Units.GetUnitRole` prefers spec role for `"player"`** ([game/isiLive_units.lua](../game/isiLive_units.lua)) — `UnitGroupRolesAssigned` does not auto-update on a pure spec switch (Druid Balance → Guardian keeps the assigned role at DAMAGER), so the active spec is now authoritative for the local player. Other party slots keep `UnitGroupRolesAssigned` because their spec is only known after an inspect cycle.
- **Shared role-refresh path** ([logic/isiLive_event_handlers_runtime.lua](../logic/isiLive_event_handlers_runtime.lua)) — `RefreshRosterRoles` and `RefreshPlayerSpecCache` extracted as module-scope helpers so `RuntimeLifecycle.BuildHandlers` stays under the 420-line metrics gate after the new dispatch wiring. `_refreshQueued`-guarded spec write so the inspect pipeline keeps ownership of spec writes for that cycle.
- **Wiring**: `ctx.getUnitRole` + `ctx.getPlayerSpecName` flow through `event_handlers` / `controller_wiring` with optional/no-op defaults so existing tests keep working without per-fixture wiring.
- **Tests**: 8 new branch tests in [testmodul/isilive_test_scenarios_event_handlers_runtime_branches.lua](../testmodul/isilive_test_scenarios_event_handlers_runtime_branches.lua) (`PLAYER_ROLES_ASSIGNED` happy path, ghost skip, raid bail-out, no-change-no-UI, `ROLE_CHANGED_INFORM` share, `PLAYER_SPECIALIZATION_CHANGED` role+spec refresh, `_refreshQueued` guard) plus 2 `Units.GetUnitRole` tests pinning the spec-prefer-for-player rule and the keep-group-role-for-others rule. Architecture / config-builder / event-utils gates pinned for the new `allowWhenHidden` entries. Total usecase scenarios: 1453 (was 1442).

### Role-marker click home-realm strip

Clicking the tank/healer role icon on your own row produced "Das könnt Ihr im Moment nicht tun" when no other unit was targeted, and silently marked the previously-selected unit when one was. Repro: solo Tank on home realm, click own row's role icon — the macro `/target Pinto-Twisting Nether\n/tm 6\n/targetlasttarget` fails to acquire Pinto because `/target` cannot resolve a local-realm unit when the realm suffix is included.

- **Root cause**: [game/isiLive_units.lua](../game/isiLive_units.lua) fills `info.realm` with `GetRealmName()` for the local player when `UnitFullName` returns a blank realm — needed for sync-key stability — but that string then leaked into the role-marker `/target` macro via the shared `BuildQualifiedName` helper. WoW's `/target` slash command does not acquire local-realm units when the realm suffix is present, especially when the realm name contains spaces ("Twisting Nether").
- **New helper** `StringUtils.BuildSlashTargetName(name, realm, homeRealm?)` ([core/isiLive_string_utils.lua](../core/isiLive_string_utils.lua)) — strips the realm suffix when it matches the home realm, falling back to the WoW global `GetRealmName()` when no `homeRealm` arg is passed so callers don't have to thread it through.
- **Macro builder** in [ui/isiLive_roster_panel_render.lua](../ui/isiLive_roster_panel_render.lua) switched from `BuildQualifiedName` to `BuildSlashTargetName`. Cross-realm units still keep the `-Realm` suffix; only the home-realm match strips. The whisper code path in `hoverFrame.OnMouseUp` is intentionally untouched — WoW's whisper parser tolerates the home-realm suffix in practice; can be migrated later if needed.
- **Tests**: 5 new `StringUtils` tests (home-realm strip with and without spaces in realm name, cross-realm keep, blank-realm short-circuit, `GetRealmName` fallback, nil-name guard). New simulator scenario 6b in [tools/simulate_role_marker_macro.lua](../tools/simulate_role_marker_macro.lua) — `GetRealmName` mocked to "Stormrage", roster mixes home-realm tank (must drop suffix) + cross-realm healer (must keep suffix) to pin both branches.

## 2026-05-05 - Version 0.9.218 (patch)

Restores the tank/healer role-icon click in the roster after the WoW 12.0.5 secret-unit-token regression, and ships the previously-staged SavedVariables hardening (schema sanitizer + always-on Lua-error capture + size-guard) in the same release.

### Role-marker click: target by character name, never by unit token

The tank/healer role-icon click stopped working after WoW 12.0.5 because the secure macro used a unit token (`/target party1`) to switch target before marking. Patch 12.0.5 turned `partyN` / `raidN` / boss / target-of-target into "secret unit tokens" — the token-based slash command silently fails from secure macros, so `/tm 6` ended up marking the previous target (invisible to the user). Symptom: click did nothing.

- **Macro now targets by character name** with optional `-Realm` suffix — same shape as the existing whisper code in `hoverFrame.OnMouseUp`. Source is `entry.info.name` + `entry.info.realm`, never `entry.unit`. WoW's slash-command name parser is not in the 12.0.5 restriction scope, so `/target Felix-Tichondrius` keeps working where `/target party1` doesn't.
- **UTF-8 names pass through byte-for-byte** — `Müller`, `Sébastien`, `Юрий`, `José`, `Çağrı`, `Lucía` etc. ride straight through the slash command without normalisation. Covers every locale in the EU/RU LFG server pool.
- **Defensive frame-level layering**: `roleButton:SetFrameLevel(mainFrame:GetFrameLevel() + 10)` in `CreateMemberRow`. Previously `roleButton` and `hoverFrame` were siblings of `mainFrame` with default frame level (both end up at +1) — at identical strata + level, hit-test tie-break is unstable on 12.0+, and the `hoverFrame` only handles RightButton in `OnMouseUp` (LeftButton would fall through silently).
- **Empty/missing-name guard**: `info.name` empty → no macro is set at all (no partial `/target \n/tm 6\n…` that would mark the previous target).
- **Tests/Sims:** rewritten [tools/simulate_role_marker_macro.lua](../tools/simulate_role_marker_macro.lua) — 6 scenarios covering same-realm baseline, cross-realm `-Realm` suffix, UTF-8 byte-level pass-through across deDE/frFR/esES/ptBR/itIT/ruRU/trTR, hard ban on `/target party*` / `/target raid*` / `/target target` etc., empty-name guard, and `type1=type2="macro"` wiring. The two taint scenarios in [testmodul/isilive_test_scenarios_taint.lua](../testmodul/isilive_test_scenarios_taint.lua) now assert `/target Felix\n/tm 6\n/targetlasttarget` (TANK) and `/target Anna-Tichondrius\n/tm 4\n/targetlasttarget` (HEALER cross-realm). Total usecase scenarios: 1434 (was 1429).
- **Documentation:** [CLAUDE.md](../CLAUDE.md) section `Role-marker click feature: target by character name, never by unit token` records the patch-version regression chain (12.0.0 protected `SetRaidTarget`, 12.0.1 `/tm [@partyN]` broken in dungeons, 12.0.5 secret unit tokens), the bug history (v0.9.203 / v0.9.208 / 2026-05), the hard rule against regressing to `entry.unit`, and the defensive frame-level requirement.

### SavedVariables hardening

Hardens `IsiLiveDB` against corruption-on-load and introduces a versioned migration framework so future schema changes (rename / remove / type-change of any setting) survive the upgrade path without user action.

- **New: centralized schema sanitizer + migration framework ([core/isiLive_db_schema.lua](../core/isiLive_db_schema.lua)):**
  - One `DBSchema.Sanitize(IsiLiveDB, logFn)` call replaces the per-field defensive defaults that previously lived inline (`IsiLiveDB.position = IsiLiveDB.position or {...}`, per-read `type(IsiLiveDB.uiScale) == "number"` checks, etc.). Hook-point: [logic/isiLive_event_handlers_runtime.lua](../logic/isiLive_event_handlers_runtime.lua) `HandleAddonLoadedEvent`, immediately after `IsiLiveDB = IsiLiveDB or {}`.
  - Schema declares the **current** shape of each persistent field: type (boolean / number / string / table), default (value or factory), optional `min`/`max` for numbers, optional `enum` for strings, optional nested `fields` sub-schema for tables.
  - Sanitizer self-heals: missing fields get defaults, wrong-typed fields get reset, out-of-range numbers get clamped, invalid enum values get reset, nested tables (`position.point/relativePoint/x/y`) get validated recursively. Closes the v0.9.208-era crash class where a partially-broken `position` table (e.g. `point=nil`) caused `mainFrame:SetPoint(nil, ...)`.
  - Unknown fields are **never** deleted — preserves user data across version downgrades and manual edits.
  - Every correction logs through `ctx.logRuntimeTrace("[DBSCHEMA] ...")` so we see in the runtime log if any user comes in with a corrupted SavedVariables.
- **New: versioned migration framework for cross-version schema changes:**
  - `db.__schemaVersion` stamps the last applied schema version. A `MIGRATIONS[N]` table holds step functions for transitions from older shapes to current shape (renames, removals, type changes, splits).
  - Each step runs at most once per user. After successful application, `db.__schemaVersion` is bumped to `LATEST_SCHEMA_VERSION`.
  - When changing a setting between versions (e.g. v0.9.222 → v0.9.223 renames `oldField` → `newField`), the developer adds one entry to `MIGRATIONS` and bumps `LATEST_SCHEMA_VERSION` — every existing user gets their saved value migrated on next load, no user action needed.
  - Initial `LATEST_SCHEMA_VERSION = 1` (no migrations yet; framework is pre-installed for the first cross-version change).
- **Schema coverage:** ~35 fields across position/anchor, UI scale, locale + sync, auto-show / auto-close, combat behaviour, roster layout, ESC menu strips, minimap, LFG flags, mob nameplate / forces overlay, sound cues, chat announces, persistent runtime caches (`rioBaseline`, `stats.playerLastRunByCharacter`). Runtime-only fields (`queueDebug`, `runtimeLogEnabled`, `runtimeLogLevel`) are intentionally outside the schema since they get reset at `ADDON_LOADED` regardless of saved value.
- **Tests:** [testmodul/isilive_test_scenarios_db_schema.lua](../testmodul/isilive_test_scenarios_db_schema.lua) — 25 scenarios covering empty-db defaults, idempotency, type-error repair, range clamping, enum validation, nested-table recursion, partially-broken `position` repair, user-set preservation, unknown-field preservation, isolated default references (no cross-user contamination), schema-version stamping, log-callback delivery, and non-table input safety. Total usecase scenarios: 1411 (was 1386).
- **Documentation:** new "SavedVariables Schema" section in [docs/ARCHITECTURE.md](ARCHITECTURE.md) explains the sanitizer + migration pattern, including a concrete example of how to author a v0.9.222 → v0.9.223 field rename.

- **New: always-on Lua-error capture ([core/isiLive_error_log.lua](../core/isiLive_error_log.lua)):**
  - Hooks `geterrorhandler()` / `seterrorhandler()` chain-of-responsibility style — the previous handler (BugSack, `!BugGrabber`, Blizzard's `BasicScriptErrors`) is ALWAYS forwarded first; we are an additional subscriber, never a replacement.
  - Captures only errors that mention "isiLive" in their message OR stack trace — Plater / WeakAuras / Blizzard UI errors are filtered out.
  - Dedups identical errors via `count++` instead of appending duplicates: an error storm in a single combat tick produces 1 entry with `count=200`, not 200 separate entries.
  - Hard-capped ring buffer of 100 distinct errors. Visible in-game via new slash command `/isilive errorlog` (status), `/isilive errorlog [N]` (show last N), `/isilive errorlog clear` (empty buffer).
  - Always-on, no opt-in. Independent of `runtimeLogEnabled`. Persisted in `IsiLiveDB.errorLog`, survives `/reload` and account-wide login.
  - Defensive capture: every internal step is `pcall`-wrapped so an error in the error logger itself cannot cause a secondary cascade.
- **New: SavedVariables size-guard via schema `maxMapEntries`:**
  - Prevents `IsiLiveDB` from growing unbounded via panic-mode map-trim. When a map-typed field exceeds its cap, the schema sanitizer drops first-fit entries until at cap; the trim action is logged via `[DBSCHEMA] trimmed ...`.
  - Caps applied: `errorLog` ≤ 200 (Schema safety net; ErrorLog module enforces 100), `rioBaseline` ≤ 5000 (lifetime cross-realm players), `stats.playerLastRunByCharacter` ≤ 5000 (per-character run stats). The existing `runtimeLog` (800) and `queueDebugLog` (400) ring buffers are already capped at the LogBuffer layer.
  - Realistic users should never hit these caps. Trimming surfaces a real bug upstream (infinite append in a loop) and keeps the SavedVariables file under ~3MB even in pathological cases instead of letting it grow to gigabyte scale.
- **Tests:** [testmodul/isilive_test_scenarios_error_log.lua](../testmodul/isilive_test_scenarios_error_log.lua) — 18 scenarios covering capture filter (Plater errors filtered out, isiLive errors caught via message OR stack-frame match), dedup (50 identical → 1 entry × 50 count), MAX_ENTRIES cap (150 distinct → ≤ 100), chain-of-responsibility (previous handler always called), `Install()` idempotency, `GetTail` / `Clear` / `GetCount` API, missing-globals safety, and schema-integrated trim for `errorLog`, `rioBaseline`, `stats.playerLastRunByCharacter`. Total usecase scenarios: 1429 (was 1411).

## 2026-05-05 - Version 0.9.217 (patch)

CI/test hygiene — four new end-to-end simulators that close known gaps in the SHAREKEYS / sync wire-format coverage and the combat-lockdown defer-and-replay lifecycle. No runtime or UI changes.

- **New end-to-end simulators (`tools/simulate_*.lua`), wired into `.github/workflows/lua-check.yml`:**
  - **[tools/simulate_multi_peer_convergence.lua](../tools/simulate_multi_peer_convergence.lua)** — 1 SHAREKEYS sender + 4 independent receiver controllers (each loads its own `ContextHelpers` / `Sync` module set, so per-peer `lastKeystoneAt` cooldowns and `Sync` dedupe state cannot bleed across peers). 5 scenarios / 51 checks: convergence (4 chats, one per peer), cooldown isolation (peer1 already on cooldown does not block peer2-4), self-echo on one of four, re-trigger after 35s succeeds for all, re-trigger within 5s blocks all. Pre-existing roundtrip simulator only pinned 1 receiver.
  - **[tools/simulate_cross_realm_realm_suffix.lua](../tools/simulate_cross_realm_realm_suffix.lua)** — pins `Sync.NormalizePlayerKey` across real EU/US realm formats: "Tarren Mill" (space), "Aman'Thul" (apostrophe), "Twisting-Nether" (dash), "Hyjal" (clean), "Area 52" (digit + space). Phase A: every realm-form variant (explicit name+realm, name-realm suffix, server-stripped) collapses to the same key. Phase B: full `ProcessAddonMessage` SHAREKEYS roundtrip across cross-realm pairs. Phase C: self-echo detected even when the server already stripped the apostrophe in the sender suffix (`Player-AmanThul` matches `Player + Aman'Thul`). 28 checks. Closes the silent-bug class where a normalization mismatch between sender's `"Name-Realm"` string and receiver's `(UnitName, GetRealmName)` tuple would either bypass or incorrectly trigger the self-echo guard.
  - **[tools/simulate_version_skew.lua](../tools/simulate_version_skew.lua)** — pins HELLO/ACK parser tolerance ahead of 1.0 ship, when 0.9.180-0.9.215 clients will coexist with 1.0.x for weeks. 6 phases / 65 checks: HELLO across 8 variants (old, current, future protocol, forward-compat extra fields, no protocol field, garbage protocol, empty version), ACK across 4 variants (HELLO/ACK asymmetry — ACK never carries protocolVersion), mixed-version group with 3 peers (no state overwrite), in-place version bump, ACK after HELLO preserves stored protocolVersion, SHAREKEYS works without prior handshake.
  - **[tools/simulate_combat_lockdown_settings.lua](../tools/simulate_combat_lockdown_settings.lua)** — pins the `PLAYER_REGEN_DISABLED` -> defer-queue -> `PLAYER_REGEN_ENABLED` -> drain lifecycle through the real EventHandlers controller. Producer closures (Bindings.ApplyHotkeyBindings, MainFrame visibility / height / width) queue during `InCombatLockdown=true`; the real `HandlePlayerRegenEnabledEvent` drain in [logic/isiLive_event_handlers_runtime.lua:452-486](../logic/isiLive_event_handlers_runtime.lua#L452-L486) consumes the queue. 8 phases / 49 checks: empty-queue no-op, single pending source drains in isolation, multiple pending sources drain together, raid mode clamps `pendingMainFrameVisible=true` to `false` (RULES_LOGIC rule 2), raid mode skips `pendingMainFrameHeight`/`Width` drain (early-return after visibility branch — pending state retained for next non-raid cycle), cycle isolation (drained state does not survive a subsequent regen-enabled), re-entry into combat starts with a clean queue, regen-disabled hooks (KillTrack notification only, no kick-tracker double-fire). Closes the gap between the per-handler branch tests in `testmodul/isilive_test_scenarios_event_handlers_runtime_branches.lua` and a true end-to-end combat cycle.

- **Two production-tolerance findings pinned (no fix needed; behavior is intentional but subtle):**
  - `SplitPayload` uses `gmatch("([^:]+)")` — empty fields collapse. `HELLO::2:1000:hello` splits to `{HELLO, 2, 1000, hello}` with the empty version slot gone, so subsequent fields shift by one. The wire format does not throw on a malformed empty field but the field semantics shift; the simulator now pins this exact behavior so a future strict-empty-preserving split surfaces here.
  - `ACK:` (empty version) yields `peerAddonVersion = nil` (not `""`) because `parts[2]` is missing after the collapse, and `SetPlayerHelloAckInfo` is correctly skipped via the `peerAddonVersion ~= ""` guard.

- **Documentation updates:**
  - `docs/ARCHITECTURE.md` Section 4 (static checks) lists all three new simulators.
  - `docs/WARTUNG.md` Section 3.6 (Sync / ChatThrottleLib) cross-references the SHAREKEYS test surface.

## 2026-05-05 - Version 0.9.216 (patch)

Incoming-summon audio cue now actually plays.

- **Bugfix: `portal_available` sound silently no-op'd in-game ([core/isiLive_sound_utils.lua](../core/isiLive_sound_utils.lua)):**
  - Repro: someone summons you outside of a raid → no audio cue, even though the helper, settings checkbox, and `CONFIRM_SUMMON` event wiring all fired correctly.
  - Root cause: registry referenced `Interface\AddOns\isiLive\sounds\Portal.ogg`, an OGG that has never existed in the repo. WoW's `PlaySoundFile` silently fails on missing assets, so nothing was audible and no error was raised.
  - Fix: switched the entry from a custom OGG to Blizzard's built-in soundkit `SOUNDKIT.UI_GROUP_FINDER_RECEIVE_APPLICATION` (a soft UI ping). The name is resolved through `_G.SOUNDKIT[name]` at play time so the entry stays patch-stable if Blizzard ever renames the constant.
  - Added `SoundUtils.PlaySoundKit(id, channel)` helper with the same spam-protection mechanic as `Play()`, keyed separately so file- and kit-based sounds do not collide.

- **Test coverage: closes the gap that let the missing-file regression slip through:**
  - New end-to-end simulator [tools/simulate_sound_playback.lua](../tools/simulate_sound_playback.lua) drives every helper through the real `SoundUtils` module and verifies each call resolves to either an existing OGG on disk or a numeric `SOUNDKIT` id. The previous architecture test only stubbed `PlaySoundFile` and asserted on the registry mapping — it could not detect a missing asset.
  - Architecture test now mocks `PlaySound` + `SOUNDKIT` and asserts that `portal_available` routes through `PlaySound` with the resolved kit id, plus an explicit assert on `portalEntry.soundKit`.

## 2026-05-05 - Version 0.9.215 (patch)

Battle Res audio cue now ships with an asset.

- **Sound: Battle Res now plays the ChickenAlarm asset ([core/isiLive_sound_utils.lua](../core/isiLive_sound_utils.lua)):**
  - Previously the battle-res sound entry shipped with `file = ""` (silent until an asset was configured). The helper, settings checkbox, and combat-event detection were all wired, only the asset was missing.
  - Wired `battle_res.file` to `Interface\AddOns\isiLive\sounds\ChickenAlarm.ogg`. Default-enabled, SFX channel, controllable via the existing "Sound alert on Battle Res" setting.
  - `.gitignore` whitelist extended (`!sounds/ChickenAlarm.ogg`) so the asset is tracked and packaged into the CurseForge build.

- **Test coverage:** architecture sound-registry test now asserts the new BR asset path and that BR + BL both play their configured assets when enabled.

## 2026-05-04 - Version 0.9.214 (patch)

Two user-facing fixes plus a long-pending audio cue.

- **Bugfix: Nameplates section header / hint stayed in English on a German UI ([ui/isiLive_settings.lua](../ui/isiLive_settings.lua)):**
  - Repro: switch to deDE (or open Settings before the language is fully applied). The Nameplates section showed `Nameplates` / `Enemy forces overlay on Mythic+ nameplates.` instead of `Namensplaketten` / `Gegnerkraft-Anzeige auf Mythic+ Namensplaketten.`.
  - Root cause: `RefreshSettingsControls` (the live-relabel pass) covered all 7 other section headers/hints but missed `nameplatesHeader`, `nameplatesHint`, and the `nameplatesExternalWarn` Plater/Platynator note. Once built, those labels never refreshed.
  - Fix: 3 additional refresh blocks, exact build-order position (between Display and Behavior). Same pattern as the other sections, supports all 8 locale tables.

- **Sound: Bloodlust now plays the BoxingArenaSound asset ([core/isiLive_sound_utils.lua](../core/isiLive_sound_utils.lua)):**
  - Previously the bloodlust sound entry shipped with `file = ""` (silent until an asset was configured). The helper, settings checkbox, and combat-event detection were all wired, only the asset was missing.
  - Wired `bloodlust.file` to `Interface\AddOns\isiLive\sounds\BoxingArenaSound.ogg`. Default-enabled, SFX channel, controllable via the existing "Sound alert on Bloodlust" setting.

- **Test coverage:** architecture sound-registry test now asserts the new BL asset path; the "BR + BL silent without configured assets" assertion split — BR remains silent (still no asset), BL counted in the play tally.

## 2026-05-04 - Version 0.9.213 (patch)

CI/test hygiene release — no runtime or UI changes. Bundles 11 commits that landed on `main` after v0.9.212 and tightens the simulator suite toward strict end-to-end discipline.

- **New end-to-end simulators (`tools/simulate_*.lua`):**
  - HELLO/ACK/REQSYNC handshake (full peer discovery + roster sync).
  - SHAREKEYS roundtrip (sender → receiver → roster update).
  - High-priority path coverage: kick-tracker extras, killtrack lifecycle, role-marker macro.
  - Medium-priority: M+ timer lifecycle, settings live-apply, savedvariables-reload.
  - Lower-priority: LFG-invite hint dialog binding, inspect pipeline, secret-value pipeline, addon-message throttle, sender/receiver flow.
  - Existing simulators (key-start, key-completion, ready-check, leader-handoff, lfg-join, multi-invite, raid-party-cycle, reload-storm, hidden-sync-reload, nameplate-keystart, ready-check-frame-overrides) tightened to true E2E semantics — removed shortcut paths, asserts now check the full observable result instead of intermediate state.

- **CI gate additions (`.github/workflows/lua-check.yml`, `tools/check_settings_default_pattern.lua`):**
  - New static gate enforcing the settings-default pattern (catches drift from the established register/read/write convention before review).
  - Convention round-trip simulator wired into the lua-check workflow.
  - `tools/validate_ci_local.ps1` covers the same gate locally.

- **Lint cleanups:**
  - Dropped colon-syntax `self` on KillTrack ticker `Cancel` stub and role-marker frame mock NoOp methods (luacheck warnings).
  - Shortened an over-120-char assert message in the lfg_join simulator.

- **Test scenarios:** `testmodul/isilive_test_scenarios_architecture.lua` now asserts the new gate is registered.

Net diff: 30 files, +6046 / -351 — all under `tools/`, `testmodul/`, and `.github/workflows/`. No `game/`, `ui/`, `core/`, `logic/`, `factory/`, or root `.lua` files touched.

## 2026-05-03 - Version 0.9.212 (patch)

Two WoW 12.0 (Midnight) compatibility fixes plus dead-code cleanup. Both bugs share the same root cause: WoW retail's API surface in 12.0 differs from TWW (`C_Item.GetAverageItemLevel` removed, `C_PaperDollInfo.GetInspectItemLevel(party*)` returns 0 unconditionally, party addon messages inside instances arrive on `INSTANCE_CHAT` instead of `PARTY`), and isiLive's older code paths still assumed pre-12.0 behavior.

- **Bugfix: own iLvl never showed in the roster row ([logic/isiLive_group.lua](../logic/isiLive_group.lua), [logic/isiLive_inspect.lua](../logic/isiLive_inspect.lua), [factory/isiLive_factory_frame_bridge.lua](../factory/isiLive_factory_frame_bridge.lua)):**
  - Repro: log in solo or in a group with own player visible. The "iLvl" column for your own row stayed `-` until you pressed Re-Sync (which, by accident, walked a different code path).
  - Three compounding causes in 12.0:
    1. `C_PaperDollInfo.GetInspectItemLevel("player")` returns `0` in 12.0 even when `INSPECT_READY` fires for self — the inspect-pipeline path could never fill `roster.player.ilvl`.
    2. `OnInspectReady` then *overwrote* the prior value with that `0`/`nil`, also clobbering party member values between successful inspects.
    3. The solo-roster-builder (`EnsureSoloPlayerRoster`) bypassed `UpdatePlayerEntry` entirely and hard-coded `ilvl = nil`.
  - Fix: `UpdatePlayerEntry` and `EnsureSoloPlayerRoster` now read the local `C_Item.GetAverageItemLevel` (with legacy `GetAverageItemLevel` fallback for 12.0 where `C_Item.GetAverageItemLevel` was removed) directly via the new exported `KeySync.ResolveAverageItemLevel`, set `_localIlvlFresh = true` so sync-backfill cannot overwrite it, and run the read even while `_refreshQueued` is true. `OnInspectReady` now skips writing when the API returns 0/nil and falls back to the local resolver for the player unit, preserving existing values.
  - Wiring: `getOwnAverageItemLevel` flows from `KeySync.ResolveAverageItemLevel` through `factory_frame_bridge.lua → factory.lua → controller_wiring.lua` into both the group module (player row) and the inspect controller (`OnInspectReady` fallback).

- **Bugfix: party-member keystones did not appear inside M+ keys ([logic/isiLive_sync.lua](../logic/isiLive_sync.lua)):**
  - Repro: enter an M+ key with members who only have RaiderIO (or any LibKeystone-using addon) but no isiLive. Their `Key` column stayed `-` for the entire run.
  - Root cause: the LibKeystone protocol implementation in [logic/isiLive_sync.lua](../logic/isiLive_sync.lua) hard-coded the `"PARTY"` channel on both ends — `Sync.SendLibKeystoneRequest` and `Sync.SendLibKeystonePartyData` sent on `"PARTY"` (silently dropped by the WoW server inside instances), and `ProcessLibKeystoneMessage` rejected anything that wasn't `"PARTY"` (so `INSTANCE_CHAT` arrivals from peers were filtered out). The bug had been latent since the LibKeystone interop commit on 2026-04-09 (24 days); only the combination of "inside an instance + at least one peer without isiLive" surfaced it.
  - Fix: both senders now mirror `Sync.GetAddonSyncChannel`'s instance-aware logic and pick `"INSTANCE_CHAT"` when `IsInGroup(LE_PARTY_CATEGORY_INSTANCE)` is true, otherwise `"PARTY"`. The receive filter in `ProcessLibKeystoneMessage` accepts both `"PARTY"` and `"INSTANCE_CHAT"` (still rejects `"RAID"`, `"GUILD"`, `"WHISPER"` per LibKeystone spec). The ISILIVE prefix already had this right since v0.9.14 — only the LibKeystone path drifted.

- **Cleanup: removed two duplicate `SendChatMessage` fallback blocks ([factory/isiLive_controller_wiring.lua](../factory/isiLive_controller_wiring.lua), [ui/isiLive_roster_panel.lua](../ui/isiLive_roster_panel.lua)):**
  - Both `sendOwnKeystoneToChat` (reactive: triggered by an incoming `SHAREKEYS` ISILIVE message) and the `Keys teilen` button onClick (active: user-initiated) had a defensive fallback that called raw `_G.SendChatMessage(line, "PARTY")` if `ContextHelpers.SendPartyChatMessage` was missing. The TOC guarantees `ContextHelpers` is loaded before either caller, so the fallback was dead code in production — but it hard-coded `"PARTY"` and would have re-introduced the same instance-channel bug if it ever did trigger.
  - Both fallbacks deleted; both call sites now go through `ContextHelpers.SendPartyChatMessage` directly. Net delete: ~50 lines including the obsolete fallback test.

- **Test coverage:**
  - 3 new tests in `testmodul/isilive_test_scenarios_group.lua` (player iLvl direct read, nil fallback, runs under `_refreshQueued`).
  - 2 new tests in `testmodul/isilive_test_scenarios_inspect.lua` (player fallback in `OnInspectReady`, no-overwrite-with-0 for party members).
  - 2 new tests + 1 extended test in `testmodul/isilive_test_scenarios_sync.lua` (LibKeystone send routes to `INSTANCE_CHAT` inside instance group; `ProcessLibKeystoneMessage` accepts `INSTANCE_CHAT`).
  - 1 obsolete test removed (`sendOwnKeystoneToChat falls back to _G.SendChatMessage when ContextHelpers.SendPartyChatMessage is missing`).
  - Total: 1380 → 1386 deterministic unit tests, all green.

## 2026-05-03 - Version 0.9.211 (patch)

Bug fixes (settings preview, locale switch coverage, WoW 12.0 Secret-Value hardening), one new user feature (LFG invite hint above the Blizzard invite dialog with a settings toggle), nine new static-analysis CI gates, five new lifecycle simulators, and ~500 lines of dead code removed (the unloaded `QueueFlow` module + 8 orphan locale keys).

- **Bugfix: nameplate X/Y-offset preview was inert ([ui/isiLive_settings.lua](../ui/isiLive_settings.lua), [ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua)):**
  - Repro: open the settings panel, drag the X-offset or Y-offset slider for the nameplate-percent preview. The "Test Mob" preview did not move.
  - Two compounding causes: (1) the X/Y offset slider callbacks called only `config.onMobNameplateChange()` and not `controls.nameplatePreviewUpdate()` like the position selector did, so the in-panel preview never re-rendered; (2) `UpdatePreview` itself ignored `mobNameplateXOffset`/`mobNameplateYOffset` and used hard-coded ±4px padding, so even if it had re-rendered the offsets would have been ignored.
  - Fix: both X and Y offset slider callbacks now invoke `nameplatePreviewUpdate()`. `UpdatePreview` reads `db.mobNameplateXOffset`/`mobNameplateYOffset` and feeds them straight to `SetPoint(xo, yo)` — same semantics as `ApplyPosition` in [ui/isiLive_mob_nameplate.lua:329-340](../ui/isiLive_mob_nameplate.lua#L329-L340), so what the user sees in preview matches what the live nameplate does in keys.

- **Bugfix: `mobNameplateEnabled` migration skipped legacy users ([factory/isiLive_factory.lua](../factory/isiLive_factory.lua)):**
  - Repro: a user from the pre-nameplate-overlay era (had only set `mplusForcesEstimate`) gets a fresh `mobNameplateEnabled` default of `nil` rather than `true`, so the M+ forces percent stays hidden until they manually toggle it.
  - Root cause: the migration guard required BOTH `mobNameplateEnabled == nil AND mplusForcesEstimate == nil`, so any prior tooltip-mode setting blocked the new default.
  - Fix: drop the second condition and force `mplusForcesEstimate = false` alongside, since the three display modes (off/tooltip/nameplate) are mutually exclusive.

- **Bugfix: language-switch confirmation always said "English" for it/ru/tr ([factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua)):**
  - Repro: `/isilive lang it` (or `ru` / `tr`) prints "Language set to English." instead of the localized confirmation, even though the locale switch itself works correctly.
  - Root cause: the `langMsgKey` switch covered only enUS/deDE/frFR/esES/ptBR — itIT/ruRU/trTR fell through to the `LANG_SET_EN` default. The matching `LANG_SET_IT/RU/TR` locale keys were defined in all 8 locale tables but never referenced.
  - Fix: extend the switch with the three missing branches. The `check_dead_locale_keys.lua` gate (introduced in this release) flagged the orphan keys, which led to discovering the bug.

- **Hardening: WoW 12.0 Secret-Value guards in `Units.GetUnitRole` / `Units.GetUnitNameAndRealm` and `Status.BuildStatusLineText` ([game/isiLive_units.lua](../game/isiLive_units.lua), [ui/isiLive_status.lua](../ui/isiLive_status.lua)):**
  - In M+ tainted contexts WoW masks return values as Secret Values; equality checks on them raise tainted-compare errors. `UnitGroupRolesAssigned`, `UnitIsUnit`, `UnitFullName`, `UnitName`, and `C_ChallengeMode.GetActiveChallengeMapID` are now wrapped in `pcall` + `rawget(_G, ...)` lookups that fail closed to nil/`"NONE"` rather than crashing the addon path.
  - Detected by the new `check_secret_value_guards.lua` gate, which inspects every direct call against the watched API surface.

- **Feature: LFG invite hint above the Blizzard invite dialog ([game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua), [ui/isiLive_notice.lua](../ui/isiLive_notice.lua), [factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua), [ui/isiLive_settings.lua](../ui/isiLive_settings.lua), [locale/isiLive_texts.lua](../locale/isiLive_texts.lua)):**
  - When `LFG_LIST_APPLICATION_STATUS_UPDATED == "invited"` arrives (Blizzard opens its `LFGListInviteDialog`), a yellow 420×64px popup floats above the dialog with a two-line label: headline = localized dungeon name `+<key level>`, sub-line = the raw group title from `info.name` so lobby conventions ("no jail", "achiever", etc.) stay readable. Auto-hide after 8 seconds.
  - Data resolution reuses the existing `Notice.CreateInviteHint` frame (latent since v0.9.87 but never triggered) plus `Teleport.GetTeleportInfoByMapID` for the dungeon name — same source as the post-accept "Ziel-Dungeon" status-line chat, so both stay in lockstep.
  - New `SETTINGS_INVITE_HINT_ENABLED` checkbox in the settings panel (default on); the toggle is read live each invite, no `/reload` needed.

- **Dead-code cleanup: unloaded `QueueFlow` module + 8 orphan locale keys ([logic/isiLive_queue_flow.lua](removed), [locale/isiLive_texts.lua](../locale/isiLive_texts.lua)):**
  - `logic/isiLive_queue_flow.lua` had been written for a v0.9.27 refactor but never added to `isiLive.toc`. Tests loaded it directly via `loadfile`, so they stayed green for 9 months while WoW never executed the code. Production used a parallel inline implementation in `factory_controllers.AnnounceQueuedGroupJoin`.
  - Removed: the module (105 lines), the dedicated test file (~120 lines), `Fixtures.BuildQueueFlowController`, the legacy-parity test in `isilive_test_scenarios_status.lua` (~125 lines), and 5 manifest references.
  - Plus 8 orphan locale keys × 8 languages = 96 lines: `BTN_GAMEMENU_CHARACTER`, `INVITE_HINT_DUNGEON`, `INVITE_HINT_GROUP`, `INVITE_HINT_UNKNOWN_DUNGEON`, `LEAD_GAINED`, `MODE_LAYOUT_M`, `PORTAL_NAVIGATOR_TEXT`, `RAID_GROUP_HIDDEN` (the InviteHint keys were re-introduced for the new feature above).
  - Found via the new `check_toc_file_list.lua` and `check_dead_locale_keys.lua` gates.

- **Dead-code cleanup pass 2: dead `IsiLiveDB.showDpsColumn` and `IsiLiveDB.markersLeaderOnly` settings toggles ([ui/isiLive_settings.lua](../ui/isiLive_settings.lua), [factory/isiLive_factory.lua](../factory/isiLive_factory.lua), [logic/isiLive_event_handlers_runtime.lua](../logic/isiLive_event_handlers_runtime.lua), [locale/isiLive_texts.lua](../locale/isiLive_texts.lua)):**
  - Found via a manual SavedVariables-field lifecycle audit (write/read cross-reference, distinguishing settings-mirror reads from behavior reads). Both fields had a full Read/Write surface — settings-panel toggle, factory hook, ADDON_LOADED hard-force — but no behavior-reader: the `roster_panel_render.lua` renderer reads from a `FORCE_SHOW_DPS_COLUMN = true` constant (DPS column always shown), and the leader-only marker filter no longer exists in production code.
  - Both controls were already gated behind `SHOW_DPS_COLUMN_SETTING = false` / `SHOW_MARKERS_LEADER_ONLY_SETTING = false` flags, so the dead toggles were never user-visible — pure code residue across 233 lines in 8 files: 2 feature flags, both toggle-create blocks (Create / Refresh / ApplyLocalization), 2 factory hooks, 2 ADDON_LOADED hard-forces, 16 locale strings (2 keys × 8 languages), 4 obsolete tests, opts-pipeline entries, factory-composition list entries.
  - The `FORCE_SHOW_DPS_COLUMN` constant in the renderer stays — it is intentional configuration (DPS column is always rendered), no longer DB-bound.
  - Surfaced a gap in the existing static-analysis gates: a write+read presence count alone misses dead behavior surfaces. Future audits should distinguish settings-mirror reads (toggle just reads its own DB value to display its own check state) from behavior reads (production code consuming the value to change behavior).

- **New static-analysis CI gates (9):**
  - **[tools/check_sound_channel.lua](../tools/check_sound_channel.lua)** — pins CLAUDE.md sound-channel rule: every `PlaySoundFile` / `defaultChannel` uses `"SFX"`, never `"Master"`.
  - **[tools/check_chat_color_safety.lua](../tools/check_chat_color_safety.lua)** — verhindert `|cff…[…]|r`-ohne-`|H`-hyperlink Pattern in Files, die `SendChatMessage` aufrufen (WoW server silently drops those).
  - **[tools/check_wow_api_compliance.lua](../tools/check_wow_api_compliance.lua)** — pins WoW 12.0 (Midnight) restrictions: `COMBAT_LOG_EVENT_UNFILTERED`, `CombatLogGetCurrentEventInfo`, `C_MythicPlus.GetOwnedKeystoneLink`, tooltip sync-version regressions.
  - **[tools/check_format_string_consistency.lua](../tools/check_format_string_consistency.lua)** — pins format-specifier multiset across all 8 locale tables; catches translator-introduced `%s`/`%d` mismatches that would crash `string.format` only in the offending language.
  - **[tools/check_secret_value_guards.lua](../tools/check_secret_value_guards.lua)** — heuristic linter for direct `UnitGUID`/`UnitName`/`UnitFullName`/`UnitReaction`/`UnitClass`/`UnitIsGroupLeader`/`UnitGroupRolesAssigned`/`UnitIsUnit`/`UnitIsVisible`/`GetActiveChallengeMapID`/`CombatLogGetCurrentEventInfo` calls without `pcall` / `IsSecretValue` / short-circuit guards.
  - **[tools/check_addon_message_size.lua](../tools/check_addon_message_size.lua)** — runtime-load Sync, dispatch every `Sync.Send*` with worst-case args (24-char realm + player names, 8-entry kick extras, max-digit numerics), assert `#payload <= 245` (10 bytes headroom under the 255-byte WoW server-drop limit).
  - **[tools/check_button_label_length.lua](../tools/check_button_label_length.lua)** — pins CLAUDE.md "≤ 14 chars for full-width action buttons" rule across 192 BTN_* keys × 8 locales (with `_SHORT`/`_hModeText` short-limit ≤ 6).
  - **[tools/check_toc_file_list.lua](../tools/check_toc_file_list.lua)** — bidirectional consistency check between `isiLive.toc` and on-disk Lua files (catches dead references and untracked production files).
  - **[tools/check_dead_locale_keys.lua](../tools/check_dead_locale_keys.lua)** — flags every enUS key that has no production reference. Caught the LANG_SET it/ru/tr bug above.
  - All nine wired into [tools/validate_ci_local.ps1](../tools/validate_ci_local.ps1), [.github/workflows/lua-check.yml](../.github/workflows/lua-check.yml), [.github/workflows/sync-mplus-forces.yml](../.github/workflows/sync-mplus-forces.yml), with drift-protection asserts in [testmodul/isilive_test_scenarios_architecture.lua](../testmodul/isilive_test_scenarios_architecture.lua).

- **New lifecycle simulators (5):**
  - **[tools/simulate_hidden_sync_reload.lua](../tools/simulate_hidden_sync_reload.lua)** — UI hidden + group + `/reload` must keep `Sync.ProcessAddonMessage` ingesting KEY/STATS/DPS/LOC/TARGET/KICK/HELLO/REQSYNC. 36 checks across two sessions plus state-isolation between them.
  - **[tools/simulate_raid_party_cycle.lua](../tools/simulate_raid_party_cycle.lua)** — full Party → Raid → Party transition matrix: roster reset, RIO/inspect/queue cleanup on raid entry, hello suppression in raid, `clearKnownUsers` on return. 31 checks.
  - **[tools/simulate_lfg_join_target_chain.lua](../tools/simulate_lfg_join_target_chain.lua)** — LFG-Apply → Invite-Accepted → group fills 5/5 announces queue join exactly once (no double-spam, leader-suppression, idempotent capture, no stale announce after leave+rejoin). 14 checks.
  - **[tools/simulate_reload_storm.lua](../tools/simulate_reload_storm.lua)** — 3 sequential `/reload` cycles + repeated `MobNameplate.SetEnabled(true)` storms within one session pin idempotency invariants (no doubled `RegisterEvent`, no doubled `OnEvent` handler, no extra `CreateFrame` allocations on toggle). 30 checks.
  - **[tools/simulate_key_completion_lifecycle.lua](../tools/simulate_key_completion_lifecycle.lua)** — symmetric counterpart to the existing key-start simulator: pins `CHALLENGE_MODE_COMPLETED` / `CHALLENGE_MODE_RESET` post-key side effects (timer/KillTrack/CombatEvents dispatch, `notifyPostChallengeSync`, status-line refresh, delayed post-run refresh schedule, raid hard-off, in-time vs depleted vs back-to-back keys). 47 checks across 6 scenarios.

- **Extended simulator: `simulate_nameplate_keystart.lua`** — 4 new scenarios: `secret_guid` (Secret-Value GUID forces API fallback), `api_only` (no MDT DB, scenario API delivers percent), `secret_mapid` (Secret-Value `GetActiveChallengeMapID` short-circuits to API path), `format_no_percent` (showPercent=false hides overlay despite valid data).

- **Coverage uplift: ui/isiLive_ui.lua + ui/isiLive_notice.lua ([testmodul/isilive_test_scenarios_ui_branches.lua](../testmodul/isilive_test_scenarios_ui_branches.lua), [testmodul/isilive_test_scenarios_ui_notice_branches.lua](../testmodul/isilive_test_scenarios_ui_notice_branches.lua)):**
  - 9 new MainFrame branch tests: controller API surface, raid-suppress + combat-defer for `SetVisible`/`ToggleVisibility`, `SetHeightSafe`/`SetWidthSafe` combat-defer, drag-storm `OnDragStop` → `SavePosition` writes IsiLiveDB.position, locked-drag no-op, mid-drag lock finalizes the position.
  - 8 new Notice branch tests: `Notice.CreateInviteHint` anchor-resolution chain (LFGListInviteDialog → LFGDungeonReadyDialog → globalMainFrame → UIParent), OnUpdate auto-hide, `Notice.CreatePortalNavigatorNotice` right-click-hide / left-click-no-op / close-button-click.
  - Both target files moved out of the bottom-10 coverage hot-spots.

- **Doc-Sync ([README.md](../README.md), [docs/ARCHITECTURE.md](ARCHITECTURE.md), [docs/USECASES.md](USECASES.md), [CHANGELOG_RELEASE.md](../CHANGELOG_RELEASE.md), [isiLive.toc](../isiLive.toc)):**
  - Version baseline bumped to `0.9.211`.
  - Validator baseline updated to `1375` deterministic usecase scenarios.

- **Tests:**
  - Added 4 LFGDetect InviteHint scenarios in [testmodul/isilive_test_scenarios_lfg_detect.lua](../testmodul/isilive_test_scenarios_lfg_detect.lua), 9 MainFrame branch tests in [testmodul/isilive_test_scenarios_ui_branches.lua](../testmodul/isilive_test_scenarios_ui_branches.lua), 8 Notice branch tests in [testmodul/isilive_test_scenarios_ui_notice_branches.lua](../testmodul/isilive_test_scenarios_ui_notice_branches.lua), plus expanded architecture-drift asserts covering the 9 new static gates and 5 new simulators across both GitHub workflows + the local preflight.
  - `lua tools/validate_usecases.lua` passed locally with `1375 passed, 0 failed`.

## 2026-05-02 - Version 0.9.210 (patch)

- **Nameplate M+ forces overlay now starts enabled and can show dungeon remainder ([factory/isiLive_factory.lua](../factory/isiLive_factory.lua), [ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua), [ui/isiLive_settings.lua](../ui/isiLive_settings.lua), [factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua)):**
  - Fresh installs now default the enemy-nameplate M+ percent overlay to enabled, so the per-mob contribution is visible in keys without a manual toggle.
  - A new settings checkbox controls the optional remaining-needed suffix. It defaults to enabled and renders values like `1.20%/24.34%` when KillTrack has verified active-run data for the same map.
  - The remainder calculation uses the existing KillTrack `rawCount`/`total` or `percent`/`total` data and fails closed to the per-mob value only when the active map or total cannot be verified.
  - KillTrack updates now refresh active nameplates, so the displayed remainder follows live enemy-count progress.

- **Full-group sound cue ([logic/isiLive_group.lua](../logic/isiLive_group.lua), [factory/isiLive_controller_wiring.lua](../factory/isiLive_controller_wiring.lua), [locale/isiLive_texts.lua](../locale/isiLive_texts.lua)):**
  - The former group-join sound now fires only once when a real party update completes the 5-player group, instead of firing for every newly seen party member.
  - Fixed the runtime wiring so the sound callback created by controller wiring actually reaches the group controller.
  - Settings labels now describe the full-group cue while keeping the existing saved setting key for compatibility.

- **Sound routing cleanup and prepared combat sound toggles ([core/isiLive_sound_utils.lua](../core/isiLive_sound_utils.lua), [logic/isiLive_event_handlers_runtime.lua](../logic/isiLive_event_handlers_runtime.lua), [ui/isiLive_teleport_ui.lua](../ui/isiLive_teleport_ui.lua), [ui/isiLive_notice.lua](../ui/isiLive_notice.lua), [ui/isiLive_settings.lua](../ui/isiLive_settings.lua)):**
  - `sounds/Portal.ogg` now belongs to incoming player summons via `CONFIRM_SUMMON`, covering meeting-stone and warlock summon confirmations for the local player.
  - Teleport-grid and center-notice refreshes no longer play Portal.ogg when a dungeon portal becomes ready or highlighted.
  - Added default-enabled settings toggles for Battle Res and Bloodlust sounds. Their registry entries intentionally keep an empty asset path until the sound files are available, so no missing-file playback is attempted.

- **LFG target-dungeon announce is faster and avoids duplicate level-less/levelled spam ([game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua), [logic/isiLive_event_handlers_queue.lua](../logic/isiLive_event_handlers_queue.lua), [ui/isiLive_status.lua](../ui/isiLive_status.lua)):**
  - Invite acceptance now resolves the accepted search-result payload directly, including activity map and title `+N` when available, instead of waiting for a later group/listing refresh.
  - The target-dungeon chat line may still post without a key level when no reliable level source exists, but it no longer posts a level-less line and then repeats the same dungeon with `+N` once the title level arrives.

- **Doc-Sync ([README.md](../README.md), [docs/ARCHITECTURE.md](ARCHITECTURE.md), [docs/USECASES.md](USECASES.md), [docs/RELEASE.md](RELEASE.md), [CHANGELOG_RELEASE.md](../CHANGELOG_RELEASE.md), [isiLive.toc](../isiLive.toc)):**
  - Version baseline bumped to `0.9.210`.
  - Validator baseline updated to `1361` deterministic usecase scenarios.

- **Tests:**
  - Added deterministic coverage for nameplate remaining-percent rendering, map mismatch suppression, settings persistence, KillTrack-to-nameplate refresh wiring, LFG invite-accepted resolution, immediate invite status refresh, duplicate target-dungeon chat suppression, full-group sound gating, incoming-summon sound routing, silent teleport refreshes, prepared BR/Bloodlust sound settings, and sound callback wiring.
  - `lua tools/validate_usecases.lua` passed locally with `1361 passed, 0 failed`.

## 2026-05-01 - Version 0.9.209 (patch)

- **Code review hardening: target resolution, map lookups, and dead fallbacks ([game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua), [logic/isiLive_highlight.lua](../logic/isiLive_highlight.lua), [factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua), [ui/isiLive_roster.lua](../ui/isiLive_roster.lua), [ui/isiLive_roster_panel.lua](../ui/isiLive_roster_panel.lua)):**
  - LFG invite acceptance now captures `activeInviteLeader` and `activeInviteTitleLevel` even when the same map was already detected through the own-listing path, preventing same-map races from dropping the authoritative `+N` title hint.
  - Same-map invite acceptance now refreshes consumers immediately after capturing the invite metadata, so status text, sync snapshots, and teleport UI do not wait for a later unrelated refresh.
  - Same-map invite acceptance now also arms the pending-accepted-invite guard, so a transient active-listing drop before `GROUP_ROSTER_UPDATE` cannot clear the accepted target, leader hint, or title level.
  - Player-map lookups in highlight resolution and target-dungeon clearing are wrapped in `pcall`, so transient Blizzard API errors fail closed instead of aborting the event path.
  - Removed the unused `Roster.HasFullSync` runtime export/wiring and the duplicated local Keystone announce fallback in the roster panel; Keystone chat text now flows through `ContextHelpers.BuildOwnKeystoneAnnounceLine`.
  - Removed stale `hasFullSync` test-fixture parameters so the deleted runtime contract cannot be accidentally masked by tests.
  - Tests added for the same-map invite title race and refresh callback, `GetBestMapForUnit` error handling in highlight/factory target paths, stale LOC fallback clearing, and conflicting/partially unresolved LFG activity-map resolution.
  - Documentation baselines synced to the `0.9.209` TOC version across `README.md`, `docs/ARCHITECTURE.md`, `docs/USECASES.md`, `docs/RELEASE.md`, and `CHANGELOG_RELEASE.md`.

## 2026-04-30 - Version 0.9.208 (patch)

LFG group title `+N` is now the authoritative source for the played key level in the "Ziel-Dungeon" announce and the sync payload, fixing a regression where joining a premade produced two or three back-to-back announces with shifting key levels (e.g. "+13" → "+14" within seconds). Nameplate / tooltip / LFG-flags / tooltip-flags settings now actually survive a `/reload` — the apply step was running before SavedVariables had restored, so the user's saved values never reached the live modules. The other reload-mid-key bug — half-loaded roster with empty Key / iLvl / RIO columns until the key ends — is fixed by letting the inspect queue dispatch out of combat and triggering a one-shot peer-data request after `/reload` is detected. And the tank/healer role-icon click placing markers on the row's player works again after the 0.9.203 macro form regressed it.

- **Bugfix: duplicate "Ziel-Dungeon" announces after LFG-invite-accept ([factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua)):**
  - Repro: accept a premade invite for, say, "Terrasse der Magister +13" while a roster member happens to own a higher key for the same dungeon. The chat would show "Ziel-Dungeon: Terrasse der Magister" → "Ziel-Dungeon: Terrasse der Magister +13" → "Ziel-Dungeon: Terrasse der Magister +14" as roster/sync data settled, even though only one of those is the key actually being played.
  - Root cause: `GetStatusTargetDungeonInfo` resolved the level in the order roster-owner → synced-target → LFG-title-hint (last resort). The roster-owner's `keyLevel` is whichever key that member happens to carry — not necessarily the key the group was formed for. Once a higher-level key surfaced via roster sync, the announce signature flipped and `MaybeAnnounceTargetDungeonChat` re-fired.
  - Fix: invert the priority. The LFG group title is the only field that always carries the played key level (boost runs, leader-is-not-key-owner, multiple members with different keys). New order in both `GetStatusTargetDungeonInfo` (local announce) and `SendOwnTargetSnapshot` (sync payload to peers): LFG-title `+N` → roster-owner key level → synced-target level. Once the invite is accepted, `activeInviteTitleLevel` locks in the level for the whole group session and later roster/sync updates can no longer flip the announce signature.
  - Sync payload mirrors the local resolution so peers that joined by `/invite` (and therefore have no local title hint) still receive the correct level over the sync channel rather than an arbitrary roster-owner level.
  - Tests: 4 new scenarios in [testmodul/isilive_test_scenarios_factory_controllers_status_helpers.lua](../testmodul/isilive_test_scenarios_factory_controllers_status_helpers.lua) covering title-overrides-roster, title-overrides-synced, title-missing-falls-back-to-roster, and `SendOwnTargetSnapshot` mirroring the title-level.

- **Bugfix: nameplate / tooltip / flag settings reverted to defaults after every `/reload` ([factory/isiLive_factory.lua](../factory/isiLive_factory.lua), [factory/isiLive_controller_wiring.lua](../factory/isiLive_controller_wiring.lua), [logic/isiLive_event_handlers.lua](../logic/isiLive_event_handlers.lua), [logic/isiLive_event_handlers_runtime.lua](../logic/isiLive_event_handlers_runtime.lua)):**
  - Repro: enable "Anzeige Nameplates" in Settings (sets `IsiLiveDB.mobNameplateEnabled = true`), `/reload`, the toggle is off again and the overlay does not render. Same surface for `lfgFlagsEnabled`, `tooltipFlagsEnabled`, `mplusForcesEstimate` and the per-control `mobNameplate*` defaults — anything the live modules read at addon-init time silently snapped back to the fresh-install default.
  - Root cause: WoW restores SavedVariables AFTER the addon's lua files run, but BEFORE `ADDON_LOADED` fires. `Factory.InitializeAddon` was applying flags to MobNameplate/MobTooltip/LFGFlags/RosterInternal at lua-file-load time — `IsiLiveDB` was still nil at that moment, so `local db = IsiLiveDB or {}` produced an empty local table, the migration wrote defaults into it, and the modules got `SetEnabled(false)` / `SetAppearance({fontSize=14, ...})` / etc. with those defaults. By the time SavedVariables restored the user's actual values into IsiLiveDB, the modules had already locked in the defaults and nobody re-applied them.
  - Fix: extract the migration + apply step into `ctx.ApplyDBSettings()` and call it twice. The first call (file-load, unchanged behaviour) keeps fresh installs sane; the second call runs from `HandleAddonLoadedEvent` after WoW has restored IsiLiveDB, so the user's saved flags reach `MobNameplate.SetEnabled(true)` and friends. Plumbing: `factory.lua` opts → `controller_wiring.lua` → `event_handlers.lua` ctx → `event_handlers_runtime.lua` HandleAddonLoadedEvent.
  - Tests: 6 new scenarios in [testmodul/isilive_test_scenarios_ui_settings.lua](../testmodul/isilive_test_scenarios_ui_settings.lua) covering the full save→Refresh roundtrip for `mobNameplateFontSize`, `mobNameplateShowPercent`, `mobNameplatePosition`, `mobNameplateXOffset`/`mobNameplateYOffset`, the displayMode selector, and a session-1→save→session-2 simulation that asserts the saved `mobNameplateEnabled = true` is NOT reverted on reload.

- **Bugfix: post-`/reload`-mid-key roster stuck half-loaded — empty Key / iLvl / RIO columns ([factory/isiLive_factory.lua](../factory/isiLive_factory.lua), [factory/isiLive_controller_wiring.lua](../factory/isiLive_controller_wiring.lua), [logic/isiLive_event_handlers.lua](../logic/isiLive_event_handlers.lua), [logic/isiLive_event_handlers_runtime.lua](../logic/isiLive_event_handlers_runtime.lua)):**
  - Repro: `/reload` while a Mythic+ key is running. Self row is filled (own data is locally available), but every other party member shows `-` for Key, iLvl and RIO and never recovers until the key ends.
  - Two compounding root causes during active challenge mode: (1) `InspectLoop` hard-skipped `inspectController.OnUpdate()` whenever `GetActiveChallengeMapID()` was set, so enqueued inspects for ilvl/RIO/spec never dispatched; (2) `RunFullRefresh` is gated off during M+ per `RULE-REFRESH-NO-CHALLENGE`, so no peer-data request ever went out — peers kept running but had no signal to re-broadcast their keys to the reloader.
  - Fix part 1: replace the InspectLoop challenge-mode skip with `InCombatLockdown()`. Inspects pause during pulls (frame-impact protection stays) but flow during dungeon downtime, so a `/reload` mid-key populates ilvl/RIO/spec without waiting for the key to end.
  - Fix part 2: add a one-shot bootstrap in `HandlePlayerEnteringWorldEvent`. When `wasInPartyInstance == nil` (post-`/reload` signature) AND `isInChallengeMode`, fire `ctx.sendRefreshRequest(true)` after the roster rebuild — peers reply via REQSYNC + LibKeystone with their keys/RIO immediately, even though the manual Re-Sync button stays correctly disabled per the documented rule.
  - Plumbing: wire `sendRefreshRequest` through `BuildEventHandlersDepsFromContext` → `ConfigureEventHandlers` → ctx so the runtime event handler can reach it. The deeper rule (no `RunFullRefresh` during M+) is intentionally untouched.
- **Bugfix: tank/healer role-icon click no longer placed Blue Square / Green Triangle ([ui/isiLive_roster_panel_render.lua](../ui/isiLive_roster_panel_render.lua), [testmodul/isilive_test_scenarios_taint.lua](../testmodul/isilive_test_scenarios_taint.lua)):**
  - Repro: click the tank or healer role icon in a roster row; nothing happens (or the marker lands on whatever was previously targeted instead of the row's player).
  - Regression introduced in 0.9.203 (commit 722b7ee) — the secure macro had been changed from `/target party1` to `/target [@party1]` as speculative "hardening" against future Blizzard unit-token tightening. The `[@unit]` form is a valid targeting conditional for `/cast` / `/use`, but `/target` does not parse it as a unit selector — the result is that `/target` resolves to nothing and the next `/tm 6` then marks whatever the previous target was.
  - Fix: revert to the bare-form `/target unit` (e.g. `/target party1\n/tm 6\n/targetlasttarget`) for both type1 (apply marker) and type2 (clear marker) macrotext on TANK and HEALER rows. The test helper `FindSecureRoleButton` plus the four assertion strings in the role-button taint scenarios were rolled back to match.

## 2026-04-30 - Version 0.9.207 (patch)

Restored the random-hearthstone behaviour in the ESC panel: each click now rolls a different owned hearthstone toy instead of always firing the same one.

- **Bugfix: ESC-panel "Hearthstone" entry always cast the same toy ([ui/isiLive_ui.lua](../ui/isiLive_ui.lua)):**
  - The secure-button setup walked `HEARTHSTONE_TOY_IDS` with `ipairs` and `break`-ed on the first owned toy. The button was wired exactly once at panel-creation time, so every later click cast that one toy forever — the previously-shipped random selection never re-rolled.
  - Fix: collect all owned hearthstones into `button._hearthstoneOwnedToys` and re-pick on every click via a `PreClick` hook. The first attribute write at button creation is also seeded with `math.random(1, #ownedToys)` so the very first cast is non-deterministic, not just subsequent ones. When two or more toys are owned, the new pick is forced to differ from the current attribute value via a small `repeat … until pick ~= current` loop, avoiding "the same toy twice in a row" surprises.
  - Combat-safe: `InCombatLockdown()` short-circuits the re-roll so we do not attempt to rewrite a secure attribute mid-combat (which would taint the click). The previously-bound toy stays active in that case and the click still works.
  - Item-fallback unchanged: when the player owns none of the listed toys the button keeps its `item:6948` (classic Hearthstone) fallback so the entry is still functional on fresh accounts.

- **Doc-Sync ([README.md](../README.md), [docs/ARCHITECTURE.md](ARCHITECTURE.md), [docs/USECASES.md](USECASES.md), [CHANGELOG_RELEASE.md](../CHANGELOG_RELEASE.md)):** Versionsbasis bumped to 0.9.207.

- **Tests:** 1333 → 1333 (the secure-button PreClick path runs against the live `SetAttribute` API and is exercised in-game; no test-harness scenario added for it). Stylua, validate_usecases, validate_rules_logic, validate_architecture_rules all clean. Local CI preflight passed.

## 2026-04-29 - Version 0.9.206 (patch)

Stops filtering Secret-Value unit data so the M+ forces nameplate text actually renders inside keystones, hardens the data path against tainted-compare crashes, scales the host frame to fit larger fonts, and switches the fresh-install default to OFF to avoid colliding with other nameplate addons.

- **Bugfix: nameplate text never rendered inside M+ keystones ([ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua)):**
  - WoW 12.0 returns `UnitGUID`, `UnitName` and `C_ScenarioInfo.GetUnitCriteriaProgressValues` as Secret Values for hostile units in the M+ tainted-code context. Our `IsEligibleUnit` and downstream guards filtered those Secret Values out before render — the per-mob percent overlay therefore could never appear in a key (`/il npstate` reported `count=0`). The font-size slider only seemed broken because there was no FontString to size in the first place.
  - Fix: the data path passes Secret Values straight through to the FontString. WoW's renderer can still display the masked text (only Lua-side reads are blocked). `ResolveMobContributionFromDB` now keeps `NpcIdFromGuid`'s pre-existing `IsSecretValue` guard so a secret GUID gracefully falls through to the API path; the API call result is forwarded as-is. `BuildText` wraps the `..` concatenation in a `pcall` so any rare runtime errors on protected string ops fail soft instead of bubbling.
  - Companion bugfix: removed two lingering `guid == ""` / `percentString == ""` literal compares that crashed with `attempt to compare local '...' (a secret string value, while execution tainted by 'isiLive')` once the Secret Values reached them.
  - Test "MobNameplate hides text when percentString is a Secret Value" inverted to "renders Secret-Valued percentString through to the FontString" to match the new contract; the GUID-secret test now verifies the API-fallback render path works when the DB lookup naturally fails for a secret GUID.

- **Feature: `/il nptest` debug overlay + `/il npstate` diagnostic dump ([ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua), [logic/isiLive_commands.lua](../logic/isiLive_commands.lua), [factory/isiLive_config_builders.lua](../factory/isiLive_config_builders.lua), [core/isiLive_bootstrap.lua](../core/isiLive_bootstrap.lua)):**
  - `/il nptest [percent]` toggles a fake-percent overlay on every hostile nameplate (default `1.23`). Bypasses `IsChallengeModeActive` and the forces DB / API lookups so the slider, position selector and X/Y offsets can be verified outside a key. Re-uses the live `RefreshAll` + `ApplyFont` + `ApplyFrameSizeForFont` paths so what the user sees in test mode matches what they would see in a real key.
  - `/il npstate [unit]` (defaults to `target`) dumps the diagnostic state at every gate: API gates, GUID/Name + their secret status, DB lookup result, API result, resolved percent / text, and a per-frame breakdown via the new `MobNameplate.DumpFrames()` helper (every active frame's `unit`, `frameShown`, frame size, FontString height, current text). Secret-Value fields are redacted to `<secret>` so chat-copy plugins do not strip the line.

- **Polish: pin nameplate font size against FontObject re-assertion + scale frame to font ([ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua)):**
  - The percent FontString was created inheriting from `GameFontNormalOutline`, whose `.height = 12` re-asserts on internal refresh paths and reverts our `SetFont(file, size, flags)` call. `ApplyFont` now detaches the inheritance via `pcall(SetFontObject, fontString, nil)` before the SetFont call and re-pins the height with `SetTextHeight(size)` as a belt-and-suspenders.
  - New `ApplyFrameSizeForFont(frame, size)` helper resizes the host frame proportionally (`height = max(20, size + 6)`, `width = max(80, size * 4)`) so a 24-pt percent text cannot get clipped against the previously hardcoded 80×20 rectangle. Both `CreateOrGetFrame` (initial layout) and `UpdateNameplate` (per-update refresh) call it so size changes from the slider take effect on the next nameplate update without re-creation.
  - Strata bumped to `TOOLTIP` + `SetFrameLevel(1000)` + `SetDrawLayer("OVERLAY", 7)` so third-party nameplate addons (Plater / Platynator) cannot occlude the percent text with their plate art.

- **Polish: sensible nameplate defaults persisted on first run ([factory/isiLive_factory.lua](../factory/isiLive_factory.lua), [ui/isiLive_settings.lua](../ui/isiLive_settings.lua), [ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua)):**
  - Fresh installs (both legacy keys nil) now persist `mobNameplateEnabled = false`. The nameplate overlay is intentionally OFF on first run so we never produce a duplicate display when the user already runs another nameplate addon that shows per-mob M+ count. They opt in explicitly via the settings panel.
  - First run also writes sane fallbacks for `mobNameplateShowPercent`, `mobNameplateFontSize` (now `14`, was `12` — too small to read on default UI scale), `mobNameplatePosition`, `mobNameplateXOffset`, `mobNameplateYOffset`. Without this the slider/selector/offsets showed `nil` until the user manually nudged each control.
  - All hardcoded `or 12` font-size fallbacks across factory, settings panel and the module itself bumped to `or 14` so module default and DB default stay in sync.

- **Hardening: leader-only resolution stays even when `UnitIsGroupLeader` is unavailable ([factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua)):**
  - Both `ResolveActiveKeyOwnerUnit` and `ResolveSyncedTargetInfo` already preferred the LFG-invite leader hint; this release adds a `UnitIsGroupLeader`-based fallback when the LFG hint is not captured (pre-formed groups, post-zone-transition state reset). Stops a random group member's higher-level key from being announced as the played key.

- **Doc-Sync ([README.md](../README.md), [docs/ARCHITECTURE.md](ARCHITECTURE.md), [docs/USECASES.md](USECASES.md), [CHANGELOG_RELEASE.md](../CHANGELOG_RELEASE.md)):** Versionsbasis bumped to 0.9.206.

- **Tests:** 1322 → 1322 (two existing nameplate scenarios inverted to the new render-through-Secret-Value contract; no net change in scenario count). Stylua, validate_usecases, validate_rules_logic, validate_architecture_rules all clean. Local CI preflight passed.

## 2026-04-29 - Version 0.9.205 (patch)

Added an out-of-key debug overlay for the M+ forces nameplate text so the size slider can be verified live without a key run.

- **Feature: `/il nptest` toggles a fake-percent debug overlay on every hostile nameplate ([ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua), [logic/isiLive_commands.lua](../logic/isiLive_commands.lua), [factory/isiLive_config_builders.lua](../factory/isiLive_config_builders.lua), [core/isiLive_bootstrap.lua](../core/isiLive_bootstrap.lua)):**
  - New module-local state (`testMode`, `testPercent` defaulting to `"1.23"`) and `MobNameplate.SetTestMode(flag, percent)` / `IsTestMode()` accessors. When `testMode` is on, `UpdateNameplate` bypasses the `IsChallengeModeActive` and `HasProgressAPI` guards (the namplate-API guard + `IsEligibleUnit` hostile/neutral filter still apply) and renders the `testPercent` directly. The module is auto-enabled if it was off so the events get registered before the first refresh.
  - Slash-command `/il nptest` toggles on/off; `/il nptest <number>` (e.g. `/il nptest 24`) sets the rendered percent. Wired through `Bootstrap.RegisterSlashCommands` → `Commands.RegisterSlashCommands` → `ConfigBuilders.BuildSlashCommandsOpts.toggleNameplateTestMode` (closure that calls `addonTable.MobNameplate.SetTestMode`). Returns the resulting state so the chat output can confirm ON / OFF.
  - Lets the size slider, position selector and X/Y offset sliders be verified without queuing a key.

- **Doc-Sync ([README.md](../README.md), [docs/ARCHITECTURE.md](ARCHITECTURE.md), [docs/USECASES.md](USECASES.md), [CHANGELOG_RELEASE.md](../CHANGELOG_RELEASE.md)):** Versionsbasis bumped to 0.9.205.

- **Tests:** 1322 → 1322 (no new scenarios; the `nptest` slash command is a thin closure around the existing `MobNameplate.SetEnabled` + `RefreshAll` paths already covered by the nameplate test suite). Stylua, validate_usecases, validate_rules_logic, validate_architecture_rules all clean. Local CI preflight passed.

## 2026-04-29 - Version 0.9.204 (patch)

Pinned the M+ forces nameplate font size against FontObject re-assertion so the size slider's value actually renders, and scaled the host frame to fit larger fonts.

- **Bugfix: nameplate percent text rendered tiny regardless of `mobNameplateFontSize` ([ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua)):**
  - The percent FontString was created with `CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")` — i.e. inheriting from a FontObject whose `.height = 12`. On some Blizzard internal refresh paths the FontObject re-asserts its inherited size after our `SetFont(file, size, flags)` call, so the slider's value (e.g. 24) appeared to take effect once but was silently reverted to 12 on the next render. Symptom: the text was visibly there but stayed at the template size, the size slider in Settings did not change anything, and the strata bump from 0.9.203 only fixed visibility (not size).
  - Fix: `ApplyFont` now detaches the FontObject template via `pcall(SetFontObject, fontString, nil)` before calling `SetFont`, then re-pins the height with `SetTextHeight(size)` as a belt-and-suspenders. Once the inheritance is severed the size argument sticks across refreshes.
  - The host frame size also scales with the font now (`height = max(20, size + 6)`, `width = max(80, size * 4)`) via the new `ApplyFrameSizeForFont(frame, size)` helper, so a 24-pt "99.9%" cannot get clipped against the previously hardcoded 80×20 rectangle. Both `CreateOrGetFrame` (initial layout) and `UpdateNameplate` (per-update refresh) call it, so size changes from the slider take effect on the next nameplate update without needing a re-creation.

- **Doc-Sync ([README.md](../README.md), [docs/ARCHITECTURE.md](ARCHITECTURE.md), [docs/USECASES.md](USECASES.md), [CHANGELOG_RELEASE.md](../CHANGELOG_RELEASE.md)):** Versionsbasis bumped to 0.9.204.

- **Tests:** 1322 → 1322 (existing nameplate scenarios continue to pass — the FontObject-detach + SetTextHeight calls are guarded by `pcall` so the assertion target `font.size = N` still resolves through the SetFont path the harness mocks). Stylua, validate_usecases, validate_rules_logic, validate_architecture_rules all clean. Local CI preflight passed.

## 2026-04-29 - Version 0.9.203 (patch)

Hardened active-key resolution against same-dungeon level conflicts in mixed groups, added a free-form group-title fallback for the level hint, kept the ready-check initiator from being auto-promoted to declined, and lifted the M+ forces nameplate text above third-party plate addons.

- **Bugfix: status announce surfaced a random member's higher-level key instead of the leader's played key ([factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua)):**
  - `ResolveSyncedTargetInfo` previously folded every roster member's broadcast target into a consensus value with a conflict guard. When the leader did not run isiLive (no broadcast) but a different member who happened to own a higher-level key for the same dungeon did, the consensus accepted the random member's value — chat showed `Ziel-Dungeon: Windläuferturm +16` for what was actually a played +13.
  - Fix: leader-only resolution. When `UnitIsGroupLeader` resolves a roster unit, only that unit's synced target counts; if the leader has no synced target, fail closed instead of polling other members. The legacy any-member consensus path stays intact for the no-leader fallback (solo, API unavailable).
  - `ctx.ResolveActiveKeyOwnerUnit` gets the same hardening: when no LFG-leader hint is captured (pre-formed groups, or after the invite-accepted state was cleared by zone transitions), the current group leader's name from `UnitIsGroupLeader` is used as the disambiguation hint so the unique-owner scan cannot pick the random higher-key member.

- **Feature: parse a free-form key-level hint out of the LFG group title ([game/isiLive_lfg_detect.lua](../game/isiLive_lfg_detect.lua), [factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua)):**
  - `OnInvited` now reads `info.name` (the leader's free-form LFG group title) alongside the activity ID and runs `ParseTitleKeyLevel(title)` to pull out a `+N` / `N+` hint (clamped to 1..40, picks the highest match so descriptive prefixes like "+12 / +13 swap" still resolve to the played level). The hint sits on `pendingInvites[id].titleLevel` until `OnInviteAccepted` promotes it to a new module-level `activeInviteTitleLevel`. Public accessor `LFGDetect.GetActiveInviteTitleLevel()` exposes it; all reset paths (`OnInviteDeclined`, `ClearDetectedState`, `ClearAllStateImpl`) drop it alongside the existing leader hint.
  - `GetStatusTargetDungeonInfo` consults the title hint as a third-stage fallback after roster-owner key + synced target both fail to supply a level. Result: groups whose leader does not run isiLive — where addon sync would never resolve a level — still get the announce in the form `Ziel-Dungeon: Windläuferturm +13` because most LFG leaders encode the level in their group title.

- **Bugfix: ready-check initiator wrongly promoted to declined on `READY_CHECK_FINISHED` ([logic/isiLive_event_handlers_challenge.lua](../logic/isiLive_event_handlers_challenge.lua)):**
  - Blizzard does not fire `READY_CHECK_CONFIRM` for the player who started the ready check (they are implicit), so `PromoteUnansweredReadyCheckUnitsToDeclined` flagged the initiator as "no confirm received" and the 20-second hold rendered their row red. In M+ groups this is typically the leader / active key holder — the most prominent row.
  - Fix: new helper `MarkReadyCheckInitiatorReady(ctx, initiatorName)` runs in the `READY_CHECK` handler, looks up the initiator in the roster by name (with realm split for cross-realm `Name-Realm` form), and pre-marks them as ready in `readyCheckReadyUnits` before the finish promotion runs. Initiator's row stays green during the hold.

- **Bugfix: M+ forces nameplate percent occluded by third-party nameplate addons ([ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua)):**
  - The percent overlay sat on `MEDIUM` strata, which third-party nameplate addons (Plater / Platynator) typically render on TOOLTIP-1 / HIGH. Result: text invisible behind their plate art even though the size slider had been raised to 24.
  - Fix: bumped to `TOOLTIP` strata + `SetFrameLevel(1000)` + `SetDrawLayer("OVERLAY", 7)` on the FontString. The custom font size (set via `pcall(fontString.SetFont, fontString, file, size, flags)` on our own FontString) was always honored — the visibility was the missing piece.

- **Doc-Sync ([README.md](../README.md), [docs/ARCHITECTURE.md](ARCHITECTURE.md), [docs/USECASES.md](USECASES.md), [CHANGELOG_RELEASE.md](../CHANGELOG_RELEASE.md)):** Versionsbasis bumped to 0.9.203.

- **Tests:** 1322 → 1322 (no new scenarios; status-announce expectations + role-button macro expectations from 0.9.202 still hold). Stylua, validate_usecases, validate_rules_logic, validate_architecture_rules all clean. Local CI preflight passed.

## 2026-04-29 - Version 0.9.202 (patch)

Critical wiring fix for the runtime event handler deps, READY_CHECK_CONFIRM boolean parity, immediate target-dungeon announce after invite-accept, and a hardened tank/healer role-button macro.

- **Bugfix: runtime event handlers received `nil` deps after the v0.9.201 ctx-injection refactor ([factory/isiLive_factory.lua](../factory/isiLive_factory.lua)):**
  - The 0.9.201 architecture pass routed dispatch through `ctx.handle*Event` callbacks but only forwarded the lowercase callback fields onto the runtime-setup ctx. `BuildEventHandlersDepsFromContext` reads the **PascalCase** module fields (`HandleKickTrackerEvent`, `GetReadyCheckReadyUntil`, `ShowCombatAnnounce`, `TriggerShareKeysCooldown`, `GetCombatLogEventInfo`, `RestoreBgAlpha`, `UpdateCdTracker`, the `modules` table, and the full readycheck-hold getter/setter set) directly off the ctx — so they came back as `nil` and silently broke dungeon detection, killtrack, M+ timer, readycheck hold persistence, BR/Lust announce, key-share cooldown and CD tracker.
  - Fix: forward all PascalCase fields explicitly in `FinalizeFactoryRuntime` so the ctx surface is symmetric with what `BuildEventHandlersDepsFromContext` consumes.

- **Bugfix: `READY_CHECK_CONFIRM` ignored Blizzard's boolean status form ([logic/isiLive_event_handlers_challenge.lua](../logic/isiLive_event_handlers_challenge.lua)):**
  - Blizzard fires the `confirmed` arg as a boolean (`true` / `false`); the previous handler only matched the string forms (`"ready"` / `"notready"`) used by the test simulator, so live confirmations fell straight through to the generic-refresh branch and the per-row ready/declined background never updated.
  - Fix: accept boolean, numeric (`1` / `0`) and string forms in both branches. The "no value" fall-through to a generic refresh stays intact.

- **Feature: target-dungeon chat announce fires on invite-accept, not only after key-sync ([logic/isiLive_event_handlers_runtime.lua](../logic/isiLive_event_handlers_runtime.lua), [ui/isiLive_status.lua](../ui/isiLive_status.lua)):**
  - Previously the "Target Dungeon: X +Y" chat announce required a peer's key-sync to land first — the announce fired late, sometimes minutes after invite-accept. The dungeon name should appear immediately when the invite resolves; the level follows once the sync arrives.
  - Fix: `GROUP_ROSTER_UPDATE` now triggers `updateStatusLine()` after the roster settles (skipped in raid mode so the suppression contract for background hooks stays intact). `BuildTargetDungeonAnnouncementText` accepts a missing/zero level: it announces the dungeon name in yellow on its own; once the level resolves via the sync flow, a second announce fires with `+level` appended.
  - Regression tests in [testmodul/isilive_test_scenarios_status.lua](../testmodul/isilive_test_scenarios_status.lua) cover the level-less invite announce, the level-augmented re-announce after sync, and a fresh announce after target clear.

- **Hardening: tank/healer role-button macros use the `[@unit]` conditional form ([ui/isiLive_roster_panel_render.lua](../ui/isiLive_roster_panel_render.lua)):**
  - The role-marker macros (`/target tank → /tm 6` for Blue Square, `/target healer → /tm 4` for Green Triangle) used the bare `/target party1` form. Switched to `/target [@party1]` so the targeting condition is parsed by the macro engine instead of relying on the raw unit name lookup — more resilient against future Blizzard tightening of the unit-token API.
  - Test helper `FindSecureRoleButton` updated to match the new `[@unit]` macro format. Existing assertions cover both the type1/type2 macrotext payloads and the secure-action-button surface.

- **Tests:** 1322 → 1322 (modified status-announce expectations + role-button macro expectations + helper match pattern, no new scenarios). Stylua, validate_usecases, validate_rules_logic, validate_architecture_rules all clean.

## 2026-04-28 - Version 0.9.201 (patch)

Test-mode preview completeness, kick-label localization parity, and an architecture pass that decouples logic-layer event handlers from direct game-module access.

- **Bugfix: ingame test mode now fills the full combat preview ([factory/isiLive_factory_controllers.lua](../factory/isiLive_factory_controllers.lua), [logic/isiLive_demo.lua](../logic/isiLive_demo.lua)):**
  - The `/isilive test` / `/isilive testall` preview already populated the roster, RIO delta, ghost row, M+ timer and combat cooldown row, but the lower M+ forces tracker stayed empty because `KillTrack.SetDemoData` was never called from the test-mode entry path.
  - Fix: entering test mode now sets demo data for the M+ timer, CD tracker and bottom forces tracker together, and exiting test mode clears all three demo overrides. The demo roster also includes a Paladin extra-kick cooldown so the multi-kick tooltip path is visible in the preview.
  - New rule `RULE-TESTMODE-DEMO-MODULE-VOLLSTAENDIG` (#57) in [docs/RULES_LOGIC.md](RULES_LOGIC.md) and a UC-07 amendment in [docs/USECASES.md](USECASES.md).
  - Regression tests cover the full factory path and the dummy-roster multi-kick payload.

- **Bugfix: Kick ready label no longer flickers between English and localized text ([ui/isiLive_roster_panel.lua](../ui/isiLive_roster_panel.lua)):**
  - The full roster render used the localized `SYNC_KICK_READY` label (`bereit` in deDE), while the dedicated kick-column refresh path called the same render helper without `getL` and fell back to hardcoded English `ready`.
  - Fix: `RefreshKickColumn()` now passes `getL`, so full renders and lightweight kick refreshes use the same localized label. The local `SetKickCellText` fallback signature was widened to 3 parameters so the IDE diagnostic at the call site is silenced.
  - `RULE-KICK-UI-UND-SYNC` (#50) reworded to mention the localized `SYNC_KICK_READY` text instead of the hardcoded English string.

- **Architecture: route game-layer event handling through injected `ctx` callbacks ([logic/isiLive_event_handlers*](../logic/), [factory/isiLive_controller_wiring.lua](../factory/isiLive_controller_wiring.lua)):**
  - LFG-detect, kill-track, combat-events, kick-tracker, mplus-timer and leader-watch dispatch flows now run via `ctx.handle*Event` callbacks wired through `ControllerWiring` instead of grepping `addonTable.*` from the lifecycle handlers. Default no-op stubs (`function(_event, ...) end`) keep optional callers safe.
  - Five new event-stub files get a per-file `ignore = { "212" }` in `.luacheckrc` — vararg cannot be underscore-prefixed, but the stubs intentionally accept the WoW event vararg signature so live handlers can drop in without call-site arity checks.

- **Architecture: remove logic→ui leak in `ADDON_LOADED` bg-alpha restore ([logic/isiLive_event_handlers_runtime.lua](../logic/isiLive_event_handlers_runtime.lua), [ui/isiLive_ui_common.lua](../ui/isiLive_ui_common.lua), [factory/isiLive_factory_frame_bridge.lua](../factory/isiLive_factory_frame_bridge.lua)):**
  - The runtime lifecycle handler used to reach `addonTable.UICommon` directly to mirror `IsiLiveDB.bgAlpha` into the `BG_PRIMARY` palette and repaint main / panel / settings backdrops. The panel/settings branches were also dead code since `BuildContext` never propagates `ctx.panelUI` / `ctx.settingsPanel` into the EventHandlers ctx.
  - Replaced with `UICommon.ApplyBgAlpha(frames, alpha)` (single helper for palette + paints) and a `ctx.restoreBgAlpha` bridge wired through `ControllerWiring`. Result: `logic/`, `core/`, `game/`, `locale/` have zero `addonTable.UI*` reaches.

- **Architecture: centralize runtime event dispatch ([logic/isiLive_event_handlers_runtime.lua](../logic/isiLive_event_handlers_runtime.lua)):**
  - Final cleanup pass on the runtime event handler so `OnEvent` is the single dispatch point — no more parallel direct-call paths into per-event handlers.

- **Tests: cover `touchedRowSlots` branch in `RenderRosterImpl` ([testmodul/isilive_test_scenarios_roster_panel_render.lua](../testmodul/isilive_test_scenarios_roster_panel_render.lua)):**
  - Two new scenarios (5-member render that touches all slots, 3→2 group-shrink that leaves one untouched slot) restore the 80% per-file coverage gate after the readycheck-hold fix in 0.9.200.

- **Doc-Sync ([README.md](../README.md), [docs/ARCHITECTURE.md](ARCHITECTURE.md), [docs/USECASES.md](USECASES.md)):** Versionsbasis bumped to 0.9.201, validator baseline updated to 1322 usecase scenarios.

- **Tests:** 1320 → 1322 (+2 testmode demo scenarios). Stylua, luacheck, locale-drift, validate_usecases, validate_rules_logic, validate_architecture_rules all clean. Local CI preflight passed.

## 2026-04-28 - Version 0.9.200 (patch)

Two roster-UI audit fixes shipped together (0.9.199 was an internal stepping-stone release that never reached CurseForge — its share-keys fix is included here as well):

- **Bugfix: ghost roster rows lost their last-known DPS after a group disband ([logic/isiLive_keysync.lua](../logic/isiLive_keysync.lua)):**
  - Symptom: after the group disbanded post-run, the UI kept showing each former member as a gray "ghost" row with name + ilvl + rio, but the DPS cell went blank — even though it had been populated seconds earlier.
  - Root cause: an asymmetry in `ApplyKnownKeyToRosterEntry`. The ilvl/rio update branches only WRITE on incoming sync data and never reset on an empty cache (so they survive a `clearKnownUsers()` wipe), but the `syncDps` branch had a `elseif info.syncDps ~= nil then info.syncDps = nil` else-reset that fired on every render-pass against the now-empty sync cache, nuking the cached value.
  - Fix: the syncDps reset branch now skips ghosts (`elseif info.syncDps ~= nil and not info.isGhost then`). Active members keep the existing reset behavior; ghosts retain their last-known sync DPS — symmetric to ilvl/rio.
  - Regression tests in [testmodul/isilive_test_scenarios_keysync.lua](../testmodul/isilive_test_scenarios_keysync.lua): ghost keeps syncDps after sync wipe (with ilvl/rio symmetry baseline); active member still gets syncDps cleared (the existing behavior is not regressed by the ghost guard).

- **Bugfix: ready-check status background flickered out 1–2s after `READY_CHECK_FINISHED` ([ui/isiLive_roster_panel_render.lua](../ui/isiLive_roster_panel_render.lua)):**
  - Symptom: after a ready check, each row briefly showed the green/red hold background (per the 20-second persistence rule) and then the background disappeared on the next generic UI rerender (e.g. triggered by `GROUP_ROSTER_UPDATE` / `INSPECT_READY` / a `CHAT_MSG_ADDON` sync update) — long before the 20s hold expiry.
  - Root cause: `RenderRosterImpl` opened with an unconditional `ClearMemberRow` loop over every member row. `ClearMemberRow` hides `row.hoverFrame`, and `row.readyCheckBackground` is created as a child of that hoverFrame. The subsequent re-render loop did call `hoverFrame:Show()` and `ApplyRowReadyCheckDisplay` for the active rows, but the brief parent-Hide → child-`SetColorTexture` → child-`Show` cycle in WoW's frame system left the background-layer texture stuck on its hidden state for the new frame paint.
  - Fix: only clear the row slots that the re-render does NOT refill. A `touchedRowSlots` table tracks which `memberRows[i]` got reused by `orderedRoster`; the cleanup loop now runs AFTER the re-render and only on untouched slots (the group-shrink case). Active members never see a parent-Hide between the FINISHED-time hold render and the next generic render → the readyCheck-hold background stays visible for the full 20-second window.
  - Reproduction: offline via `lua tools/simulate_ready_check_frame_overrides.lua` (frame-mock simulator). Pre-fix Phase 3b shows 5 `Background:Hide` calls between `RefreshReadyCheckStateImpl` and `RenderRosterImpl`; post-fix the Hide calls are gone (10 calls instead of 15, no hide → show → hide → show oscillation).

- **Cleanup: dead `_readyCheckLingerSeq` counter removed ([logic/isiLive_event_handlers_challenge.lua](../logic/isiLive_event_handlers_challenge.lua)):**
  - One-line set in the `READY_CHECK` handler that was never read anywhere — leftover from an earlier ready-check linger experiment.

- **Tooling: two new offline ready-check simulators ([tools/simulate_ready_check_lifecycle.lua](../tools/simulate_ready_check_lifecycle.lua), [tools/simulate_ready_check_frame_overrides.lua](../tools/simulate_ready_check_frame_overrides.lua)):**
  - The lifecycle simulator drives `READY_CHECK` → `READY_CHECK_CONFIRM` → `READY_CHECK_FINISHED` and prints the resulting `BuildDisplayData` background per row across the 20-second hold window.
  - The frame-overrides simulator goes one level deeper: it mocks `row.readyCheckBackground` with a Show/Hide/SetColorTexture recorder and runs `RefreshReadyCheckStateImpl` followed by `RenderRosterImpl`, surfacing exactly which frame call sequence the hold goes through. This is what pinpointed the parent-Hide → child-Show ordering bug above.

- **Tests:** 1317 → 1319 (+2 ghost DPS regression scenarios on top of the 19 share-keys scenarios already shipped in 0.9.199 below). Stylua, validate_usecases, validate_rules_logic, validate_architecture_rules all clean. Local CI preflight passed.

## 2026-04-28 - Version 0.9.199 (patch, internal — superseded by 0.9.200, never released to CurseForge)

- **Bugfix: Share-Keys receivers no longer post their own key after a `SHAREKEYS` broadcast ([logic/isiLive_keysync.lua](../logic/isiLive_keysync.lua)):**
  - Root cause: `GetOwnedKeystoneSnapshot` returned `nil, nil` whenever `C_MythicPlus.GetOwnedKeystoneLevel` / `C_MythicPlus.GetOwnedKeystoneChallengeMapID` came back empty, which is the typical state on a receiver client right after a `SHAREKEYS` sync (the per-client keystone cache has not been populated yet). Symptom matched the open `[KEYSTONE] aborted reason=no_line` case in [todo.md](../todo.md): the sender's "Share Keys" button worked, but other isiLive clients in the group never posted their own key.
  - Fix: `GetOwnedKeystoneSnapshot` now falls back to a bag scan on item ID `180653` and parses `mapID`/`level` directly from the `|Hkeystone:180653:<mapID>:<level>:…|h` link. Symmetric to the existing link-fallback in `ContextHelpers.BuildKeystoneChatLink`. The C_MythicPlus API is still preferred when it returns a valid (mapID, level); the bag scan only runs when the API yields empty.
  - Safety: `C_Container.GetContainerItemLink` is classified `AllowedWhenUntainted` per warcraft.wiki — safe to call in combat and during a Mythic+ keystone from untainted callers (the button click is a hardware event; `CHAT_MSG_ADDON` dispatch is not protected). No button-lock or combat gate required.
  - Reproduction: offline via `lua tools/simulate_sender_receiver.lua share_pipeline` — Scenario 4 (`snapshot_missing`) shows the pre-fix `abort_reason=no_line`.
  - Regression tests in [testmodul/isilive_test_scenarios_keysync.lua](../testmodul/isilive_test_scenarios_keysync.lua) cover the bag-scan fallback in five blocks (19 tests total for the share-keys path):
    - **Snapshot resolution** (4): API empty + bag has key, API absent + bag has key, both empty → nil, both populated → API has precedence.
    - **API edge cases** (4): C_MythicPlus absent, level=0, mapID=0, API throws — all must trigger bag fallback.
    - **Bag iteration** (3): keystone in reagent bag (bagID=5), keystone in mid-bag (bagID=3) skipping empty bags, multiple keystones → first-found is returned deterministically.
    - **Defensive guards** (3): partial C_Container API → safe nil; pcall failure on `GetContainerNumSlots` / `GetContainerItemID` → continues scanning.
    - **Malformed bag links** (3): missing mapID/level in pattern, encoded `mapID=0`, encoded `level=0` — all reject, snapshot stays nil.
    - **End-to-end + sender/receiver parity** (2): bag-scan snapshot → `BuildOwnKeystoneAnnounceLine` produces a sendable line embedding the real `|Hkeystone:` hyperlink; sender path and receiver path produce **byte-identical** output for identical inputs (proof there is only one implementation, so the historical sender-side fixes — bag-scan link, no `|cff…|r` wrap around bare brackets — apply to the receiver automatically); plain-text fallback path also stays compliant with the no-color-around-brackets server-filter rule.

- **Tooling: offline share-keys pipeline simulator ([tools/simulate_sender_receiver.lua](../tools/simulate_sender_receiver.lua)):**
  - New `share_pipeline` mode exercises the seven realistic build/send permutations of `BuildOwnKeystoneAnnounceLine` + `SendPartyChatMessage` (owned-link API hit, bag-scan hit, plain-text fallback, snapshot missing, not-in-group, send failure with and without `C_ChatInfo` fallback) and prints which abort reason each scenario surfaces. Lets us reproduce share-keys regressions without an in-game live trace.

- **Tests:** 1298 → 1317 (15 keysync share-keys regression scenarios + 4 from the initial fix). Stylua, validate_usecases, validate_rules_logic, validate_architecture_rules all clean.

## 2026-04-28 - Version 0.9.198 (patch)

- **Bugfix: debug-log checkboxes ignored the live state ([ui/isiLive_settings.lua](../ui/isiLive_settings.lua)):**
  - `ResolveSettingsOptions` swallowed two more getters: `getQueueDebugEnabled` and `getRuntimeLogEnabled`. Effect: the "Queue Debug Log" and "Runtime Log" checkboxes always rendered unchecked when the settings panel was opened, even when the loggers were actively capturing (e.g. after `/isilive log start` or after a previous toggle in the same session). The toggles themselves worked (`onQueueDebugToggle` / `onRuntimeLogToggle` were in the resolver), only the displayed state was broken. `Refresh()` ([:2243-2248](../ui/isiLive_settings.lua#L2243)) was affected too.
  - Fix: two lines in the resolver, plus `_settingKey` markers on both checkbox frames so they are reachable via the standard test-iteration pattern.
  - Regression test in [testmodul/isilive_test_scenarios_ui_settings.lua](../testmodul/isilive_test_scenarios_ui_settings.lua) verifies that both checkboxes mirror their getter result on initial render.

- **Bugfix: chat-announce checkboxes were not resynced after a reset ([ui/isiLive_settings.lua](../ui/isiLive_settings.lua)):**
  - `Refresh()` updated the labels for `chatAnnounceBR` and `chatAnnounceLust` but never called `check:SetChecked(db.…)`. As a result, after `/isilive reset` (DB → defaults) the checkboxes visually lagged behind the DB until the settings panel was reopened. Every other checkbox in the panel follows the `SetChecked`-in-Refresh pattern.
  - Fix: two `SetChecked` calls in `RefreshSettingsControls`. Regression test: flip DB value → `Refresh()` → checkbox reflects the new value.

- **Dead locale keys removed ([locale/isiLive_texts.lua](../locale/isiLive_texts.lua), [testmodul/isilive_test_scenarios_ui.lua](../testmodul/isilive_test_scenarios_ui.lua), [testmodul/isilive_test_scenarios_ui_settings.lua](../testmodul/isilive_test_scenarios_ui_settings.lua)):**
  - `SETTINGS_MPLUS_FORCES` ("Mythic+: Show enemy forces in tooltip") removed from all 8 languages — old tooltip checkbox label, replaced by the 3-way display-mode selector, no longer referenced anywhere.
  - `SETTINGS_DEFAULT_OPEN_UI_M` ("M") removed from all 8 languages — the default-layout selector now only offers `LAST` / `V` / `H` / `M2`; the plain "M" mode was retired. Stale stub localizations in both UI test files (9 occurrences total) cleaned up alongside.

- **Tests:** 1296 → 1298 (two new regression scenarios). Stylua, luacheck, locale-drift, validate_usecases, validate_rules_logic, validate_architecture_rules all clean.

## 2026-04-28 - Version 0.9.197 (patch)

- **Bugfix: nameplate settings only applied after `/reload` ([ui/isiLive_settings.lua](../ui/isiLive_settings.lua)):**
  - `ResolveSettingsOptions` did not forward the `onMobNameplateChange` callback. Effect: slider / checkbox / selector inputs in the nameplate section (display-mode, show-percent, font-size, position) wrote to SavedVariables but `MobNameplate.SetAppearance` / `SetFormat` / `SetEnabled` were never invoked live — changes only became visible after `/reload` (factory init reads the DB once in [factory/isiLive_factory.lua](../factory/isiLive_factory.lua)). Reproduced by the user with Platynator while trying to change the font size of the forces-% overlay.
  - Fix: one line (`onMobNameplateChange = opts.onMobNameplateChange`) in the resolver. All four nameplate controls now apply immediately.
  - Regression test in [testmodul/isilive_test_scenarios_ui_settings.lua](../testmodul/isilive_test_scenarios_ui_settings.lua): a slider drag must invoke `onMobNameplateChange` exactly once.
  - Coverage list in [testmodul/isilive_test_scenarios_factory_composition.lua](../testmodul/isilive_test_scenarios_factory_composition.lua) extended with `onMobNameplateChange` so the path is exercised by the composition test as well.

- **Dead locale keys removed ([locale/isiLive_texts.lua](../locale/isiLive_texts.lua)):**
  - `SETTINGS_NAMEPLATE_FORCES` ("Mythic+: Show enemy forces on nameplates") removed from all 8 languages — never referenced, leftover from the original checkbox UI before the 3-way display-mode selector replaced it.

- **Nameplate position fine-tuning ([ui/isiLive_settings.lua](../ui/isiLive_settings.lua), [locale/isiLive_texts.lua](../locale/isiLive_texts.lua)):**
  - Two new sliders below the Position selector: `SETTINGS_NAMEPLATE_X_OFFSET` and `SETTINGS_NAMEPLATE_Y_OFFSET` (range -50..+50 px, step 1, default 0). The DB keys `mobNameplateXOffset` / `mobNameplateYOffset` are now reachable without `/run IsiLiveDB.…` — previously the factory read them in [factory/isiLive_factory.lua](../factory/isiLive_factory.lua) and forwarded them to `MobNameplate.SetAppearance`, but no UI control set them, so they were always `0`.
  - Locale keys (`SETTINGS_NAMEPLATE_X_OFFSET` / `SETTINGS_NAMEPLATE_Y_OFFSET`) added in all 8 languages; drift gate clean.
  - `Refresh()` in the settings UI resyncs the slider labels and values on language change.

- **Tests:** 1294 -> 1296 (two new scenarios). Stylua, luacheck, locale-drift, validate_usecases, validate_rules_logic, and validate_architecture_rules all clean.

## 2026-04-27 - Version 0.9.196 (minor)

- **Boss-target overlay fully removed ([ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua), [ui/isiLive_roster_panel_kill_row.lua](../ui/isiLive_roster_panel_kill_row.lua), [ui/isiLive_settings.lua](../ui/isiLive_settings.lua), [factory/isiLive_factory.lua](../factory/isiLive_factory.lua), `data/isiLive_mplus_boss_targets.lua` deleted):**
  - The optional `next` / `end` boss-target remainder in the mob-nameplate overlay (`+24%` / `+47%` extra) and the three-color boss markers on the killtracker bar (gray/yellow/green) are completely removed. The per-mob forces contribution (`+1.50%`) on nameplates and the forces bar itself (fill + pull predictor + % text) remain unchanged.
  - Settings dropdown "Remainder display (off/next/end)" removed; 32 related locale strings (`SETTINGS_NAMEPLATE_BOSS_TARGET_MODE*`) dropped from all 8 languages, drift gate stays clean.
  - `data/isiLive_mplus_boss_targets.lua` deleted along with the TOC entry, the factory resolver `ResolveMobNameplateBossTargetMode`, the `bossTargetMode` parameter of `MobNameplate.SetFormat`, the `killTrackBossMarkers` pool, and 6 boss-target test scenarios.
  - SavedVariable keys `mobNameplateBossTargetMode`, `mobNameplateShowBossTarget`, `bossTargetsOverride[mapID]` are ignored from this version onward (no migration code; old values remain in `IsiLiveDB` but are no longer read by the new code).
  - Docs updated accordingly: UC-19 in [docs/USECASES.md](USECASES.md) removed, UC-18 (nameplate overlay) reduced to the remaining per-mob contribution, ARCHITECTURE.md layer overview de-emphasized.

- **Stale TWW references migrated to Midnight ([game/isiLive_kick_tracker.lua](../game/isiLive_kick_tracker.lua), [logic/isiLive_sync.lua](../logic/isiLive_sync.lua), [testmodul/isilive_test_scenarios_kick_tracker.lua](../testmodul/isilive_test_scenarios_kick_tracker.lua), [docs/RULES_LOGIC.md](RULES_LOGIC.md)):**
  - 3 code comments in the kick tracker (`since TWW`, `current TWW`) and the extras-cap comment in `Sync.ProcessAddonMessage` had the predecessor expansion name removed — the addon has been running on patch 12.0 against Midnight, "TWW values" as a comment was factually wrong.
  - Test name `KickTracker reports no interrupt for Holy Paladin (lost Rebuke since TWW)` renamed to `(no Rebuke in Midnight)`; the paired mapping in `RULES_LOGIC.md` (RULE-KICKTRACKER-PERSOENLICHER-INTERRUPT) updated, otherwise the rule validator would no longer find the test.
  - 10 historical CHANGELOG entries with `TWW S3` / `TWW Season 3` / `TWW values` / `The War Within` generalized to `Season 3` / `Midnight`.

- **LuaLS diagnostics cleanup (multiple sites):**
  - `Assert.NotNil(...)` calls in [testmodul/isilive_test_scenarios_mob_nameplate.lua](../testmodul/isilive_test_scenarios_mob_nameplate.lua) and [testmodul/isilive_test_scenarios_tank_helper.lua](../testmodul/isilive_test_scenarios_tank_helper.lua) now capture the return value so LuaLS narrows `eventFrame` / `tankButton` / `collapseButton` / `horizontalCollapseButton` away from `nil` — follows the idiom from commit `fdf0857`.
  - `KickController` `@class` annotation in [testmodul/isilive_test_scenarios_kick_tracker.lua](../testmodul/isilive_test_scenarios_kick_tracker.lua) now lists `Scan` as a `@field` so the Avenger's-Shield extras-expiry test no longer flags `kickController.Scan()` as an undefined field.
  - [ui/isiLive_settings.lua](../ui/isiLive_settings.lua) preview update: `preview.overlay:GetFont()` may return `nil` as `fontPath` — guarded with a `Fonts\\FRIZQT__.TTF` fallback (same default as `ApplyFont` in the nameplate module).
  - Trailing blank line between `end)` and `end` from a deleted test block fixed (Stylua gate failure).

- **Factory cleanup ([factory/isiLive_factory.lua](../factory/isiLive_factory.lua)):**
  - Dead `showCount` / `showTotal` arguments to `MobNameplate.SetFormat` removed from the `onMobNameplateChange` callback. `SetFormat` was simplified during the boss-target strip and now only reads `showPercent`. The matching DB keys (`mobNameplateShowCount` / `mobNameplateShowTotal`) were never set anywhere — pure leftover from an older un-shipped feature stub.

- **Third-party attributions cleaned up (`data/isiLive_mplus_boss_targets.lua` deleted, [ui/isiLive_ui.lua](../ui/isiLive_ui.lua), [docs/CHANGELOG.md](CHANGELOG.md)):**
  - The boss-target data file (previously attributed to an external community dataset) is gone with the feature strip anyway.
  - The source comment for the 32 Hearthstone toy item IDs in [ui/isiLive_ui.lua:93](../ui/isiLive_ui.lua#L93) was switched from the reference-to-another-addon form to a generic "WoW item database" note; the list of IDs itself remains unchanged.
  - Dead Markdown link to a non-existent CurseForge URL in a historical v0.9.193 entry in [docs/CHANGELOG.md](CHANGELOG.md) reduced to plain text, plus two other clunky-hyphenated phrases ("external-interrupt-tracker-extraKicks model") rewritten in readable form.

- **History scrub (4 filter-repo runs, all 497 commits rewritten):** Earlier mentions of external addon names removed from the entire repo history — working tree and full history are now free of such references outside the explicitly allowed list (LibKS / LibKeystone / MDT / Raider.IO / ChatThrottleLib / Plater / Platynator / DBM / BigWigs / WeakAuras / BugGrabber / `Lib*` / `AceComm*` / `MinimapButton*`). Consequence: every SHA from `0.9.116` onward has changed; all 94 release tags were force-pushed. Four backup bundles are stored at `d:/Git/isilive-pre-*-2026-04-27.bundle`.

- **Tests:** 1092 → 1086 (six boss-target scenarios deleted, all others unchanged green). Stylua, locale-drift, M+ forces DB lifetime, validate_usecases, validate_rules_logic, validate_architecture_rules all clean.

## 2026-04-26 - Version 0.9.195 (patch)

- **Code-review followups from the 0.9.194 audit ([logic/isiLive_sync.lua](../logic/isiLive_sync.lua), [logic/isiLive_keysync.lua](../logic/isiLive_keysync.lua)):**
  - **H1 numeric sort of the extras pieces** in the KICK payload: previously `table.sort(pieces)` sorted lexicographically, which would have produced inconsistent ordering for spell IDs of different lengths (e.g. 1766 Rogue Kick vs 119914 Demo Warlock Axe Toss). Now sorted by numeric `sid` value so the dedup hash stays deterministic regardless of `pairs()` iteration order. The real case with 5–6 digit spell IDs was OK in practice, but numeric sort is more future-proof.
  - **M5 defense-in-depth: 8-entry extras cap on receive**. `Sync.ProcessAddonMessage` caps parsing of the `:E:` suffix at 8 entries. Realistic max in Midnight is 1–2 extras (Prot Pala Avenger's Shield, Demo Warlock pet swap); a malformed or hostile peer can no longer push arbitrary entries through and trigger a memory spike. The cap is conservative relative to the real case.
  - **M3 drift threshold rationale** in `keysync.lua` as a comment block: extras use a 0.6 s threshold vs 0.05 s for the primary `cooldownRemain`. Rationale: extras (typically 30 s CDs) are talent / pet-swap interrupts; sub-second drift is not visible in the tooltip and not worth the re-render. Primary cooldowns, in contrast, drive the bright kick column and need tight sync.

- **Tests:**
  - `KillTrack.SetDebugLogger(nil) clears the sink so subsequent drift events are silently swallowed` — verifies that after `SetDebugLogger(nil)` no further drift messages arrive, even when a new drift key (total change) would overcome the repeat-suppression cache.
  - `Sync ProcessAddonMessage caps extras list at 8 entries (defense-in-depth)` — sends 12 entries, asserts exactly 8 are stored.
  - `Sync multi-kick roundtrip: SendKick payload feeds back through ProcessAddonMessage to the peer entry` — full E2E pipeline verification: sender payload is produced, played back through `ProcessAddonMessage` as if received by a peer, and the stored peer state contains both extras with unchanged remain values. Closes a test-coverage gap from the 0.9.194 code review.
  - `MobNameplate ApplyFont falls back to default font when GameFontNormalOutline is missing` — simulates a runtime without Blizzard's FontObject, verifies that `SetFont` is still called with the configured `fontSize=14`, `Fonts\\FRIZQT__.TTF` fallback file and `OUTLINE` fallback flags.
  - 1088 / 1088 → 1092 / 1092. Stylua, luacheck, hardcoded-strings clean. Pure robustness / test patch, no user-visible behavior change.

## 2026-04-26 - Version 0.9.194 (minor)

- **Multi-kick tracking for specs with additional interrupts ([game/isiLive_kick_tracker.lua](../game/isiLive_kick_tracker.lua), [logic/isiLive_sync.lua](../logic/isiLive_sync.lua), [logic/isiLive_keysync.lua](../logic/isiLive_keysync.lua), [ui/isiLive_roster_tooltip.lua](../ui/isiLive_roster_tooltip.lua)):**
  - Until now the KickTracker tracked exactly one interrupt spell per spec. Classes with talent-bonus kicks (Prot Paladin Avenger's Shield) had that spell invisible in the roster even though it counts in encounters. Conservatively limited to a class allowlist instead of treating every class with potential multi-spell tracking generically.
  - The new `CLASS_INTERRUPT_LIST` currently lists `PALADIN = {96231, 31935}` (Rebuke + Avenger's Shield) and `WARLOCK = {19647, 119914}` (Spell Lock + Axe Toss). Other classes are explicitly not listed; their spec switch still goes through `RefreshSpec` on `PLAYER_SPECIALIZATION_CHANGED`.
  - **OnCast path** in `KickTracker` is now two-stage: 1) primary match as before, 2) fallback to `FindExtraKickSpell(spellID)` which iterates `CLASS_INTERRUPT_LIST`. On a hit, `extras[spellID] = {cd, cdEnd}` is set without touching the primary. CD comes from the `EXTRA_KICK_CD` lookup with a fallback to a SPEC_DATA search for cross-spec spells. `Scan()` automatically purges expired entries so `GetKickInfo().extras` only ever returns live CDs. `ResolvePlayerClass` caches the class via `UnitClass("player")` once in the constructor (then immune to test `WithGlobals` sandbox resets).
  - **Sync payload extension** ([logic/isiLive_sync.lua](../logic/isiLive_sync.lua)): `KICK:<state>:<remain>` → optional `KICK:<state>:<remain>:E:<spellID,remain>;<spellID,remain>`. Backwards-compatible: older isiLive peers don't parse `parts[4]/parts[5]` and ignore the suffix. Newer peers extract extras via `gmatch("[^;]+")`. An empty extras map does not append the `:E:` suffix so the common single-kick case wastes no bytes.
  - **Factory handshake** ([factory/isiLive_factory_kick_tracker.lua](../factory/isiLive_factory_kick_tracker.lua)): the existing SendKick path now forwards `info.extras` to `Sync.SendKick({extras=…})` and simultaneously to `Sync.SetPlayerKickInfo(self, …, extras)` so the local display sees its own extras immediately without a round-trip via the addon channel.
  - **Peer state** ([logic/isiLive_keysync.lua](../logic/isiLive_keysync.lua)): `ApplyKnownKeyToRosterEntry` interpolates extras analogous to the primary remain (subtract elapsed time from `receivedAtGetTime`), filters expired ones out, and persists the map as `info.syncKickExtras` on the roster entry. Drift detection (>0.6 s) triggers a UI refresh.
  - **Roster tooltip** ([ui/isiLive_roster_tooltip.lua](../ui/isiLive_roster_tooltip.lua)): the existing `ShowRosterInfoTooltip` function now shows a localized "Extra kicks:" header right after the RIO line, followed by one line per extra formatted as `  <SpellName>: <remain>s`. The SpellName comes from `C_Spell.GetSpellName(spellID)` (with a pcall guard), falling back to `Spell <ID>` if the API is missing. The header is localized in 8 languages (`TOOLTIP_KICK_EXTRAS_HEADER`); the format string itself (language-neutral, SpellName is auto-localized by Blizzard) is annotated with `-- i18n-ok`.
  - **Known constraint documented**: Demonology Warlock Inner Demons (both pets at the same time, Axe Toss + Spell Lock on CD in parallel) is currently **not** handled as multi-kick because `Spell Lock 19647` is listed in `SPEC_DATA[266].spells` as an alternative primary (for the pet-switch case with Felhunter without Felguard). Reducing that array to one spell would break the pet-switch path. Future work if Inner Demons tracking is requested.

- **Tests:**
  - 4 new scenarios in [testmodul/isilive_test_scenarios_kick_tracker.lua](../testmodul/isilive_test_scenarios_kick_tracker.lua):
    - `KickTracker tracks Avenger's Shield as an extra kick for Protection Paladin` (class lookup + extras map populated)
    - `KickTracker drops expired extras on Scan` (clock advance + Scan cleanup)
    - `KickTracker ignores casts of non-class-interrupt spells` (random spellID 999999 → false)
    - Plus implicit: existing OnCast tests still green.
  - 2 new sync scenarios in [testmodul/isilive_test_scenarios_sync.lua](../testmodul/isilive_test_scenarios_sync.lua):
    - `Sync SendKick appends extras suffix when multi-kick extras are on cooldown` (single + multiple + empty cases, sorted + ';' separated)
    - `Sync ProcessAddonMessage parses KICK extras suffix and stores it on the peer` (round-trip + backwards-compat: absent suffix clears stored extras)
  - 1086 / 1086 → 1088 / 1088. Stylua, luacheck, hardcoded-strings clean.

## 2026-04-25 - Version 0.9.193 (patch)

- **Kick-tracker spec data aligned with current Midnight reality ([game/isiLive_kick_tracker.lua](../game/isiLive_kick_tracker.lua)):**
  - Cross-check against current in-game tooltip values and spec registries surfaced four discrepancies we had missed (notably the Mistweaver fix after the corresponding class tuning).
  - **Two heal specs were incorrectly carrying an interrupt:**
    1. **Spec 65 (Holy Paladin)** was mapped to `spellID=96231` (Rebuke). Holy Paladin no longer has Rebuke in Midnight; until now we tracked `ready` / cooldown for Holy Paladins in the roster even though the spell doesn't exist. Now `noKick=true`, in line with the priest heal specs.
    2. **Spec 270 (Mistweaver Monk)** was mapped to `spellID=116705` (Spear Hand Strike). MW cannot cast Spear Hand Strike — the spell is Brewmaster/Windwalker only. Now `noKick=true`, in line with Restoration Druid.
  - **Three CDs were stale** (Midnight values shifted relative to our original table):
    3. **Balance Druid (102) Solar Beam** `60s` → `45s`
    4. **Mage Counterspell (62/63/64)** `25s` → `20s` (base CD; the `Presence of Mind` talent in `CD_REDUCTION_DEFS` reduces it to 15 instead of 20)
    5. **Evoker Quell (1467/1468/1473)** `20s` → `18s` (base CD; the `Interwoven Threads` talent in `CD_REDUCTION_DEFS` reduces it to 16.2)
  - **Demonology Warlock (266) pet interrupt** was mapped to `spellID=89766` (raw pet-cast event ID for Felguard's Axe Toss). The player-facing spell ID shown in the tooltip is `119914`. Switched to 119914; 89766 stays as a pure combat-log event ID that we no longer need in SPEC_DATA.
  - `NO_INTERRUPT_SPEC_IDS` is now complete: `{105 Resto Druid, 256 Disc Priest, 257 Holy Priest, 65 Holy Paladin, 270 Mistweaver Monk}`. All 5 healer specs without an interrupt are now explicitly `noKick`.

- **Tests:**
  - `mappedSpecs` list in [testmodul/isilive_test_scenarios_kick_tracker.lua](../testmodul/isilive_test_scenarios_kick_tracker.lua) drops 65 + 270 (now in `noKickSpecs`), Demo Warlock spellID switched to 119914. The `GetSpellBaseCooldown` mock now returns 45000 ms for Solar Beam, 20000 ms for Counterspell, 18000 ms for Quell, 30000 ms for Axe Toss.
  - Specific Holy Paladin test renamed and rewritten: `KickTracker resolves Holy Paladin to Rebuke` → `KickTracker reports no interrupt for Holy Paladin (no Rebuke in Midnight)`. Asserts `info.hasKick == false` and `info.spellID == nil`.
  - Demo Warlock test now asserts `info.spellID == 119914` with the adjusted mock.
  - `RULE-KICKTRACKER-PERSOENLICHER-INTERRUPT` in [docs/RULES_LOGIC.md](../docs/RULES_LOGIC.md) follows the renamed test along, summary extended with the 5-spec healer list.

## 2026-04-25 - Version 0.9.192 (test)

- **Test coverage: explicit SetFont verification for the nameplate font-size wiring ([testmodul/isilive_test_scenarios_mob_nameplate.lua](../testmodul/isilive_test_scenarios_mob_nameplate.lua)):**
  - Background: 0.9.185 fixed the font-size bug (slider value was persisted into `appearance.fontSize` but never applied to the FontString) via the `ApplyFont` helper. The corresponding test scenario at the time (`MobNameplate SetAppearance during enabled=true re-applies font size`), however, only checked in-memory state persistence, not whether `SetFont` was actually called on the FontString with the new size. Between 0.9.185 and 0.9.191 a refactor could silently break the wiring without any test failing.
  - Mock infrastructure extended:
    - `MakeFontString()` now has `SetFont(file, size, flags)` which records `_font = {file, size, flags}` and a `_setFontCallCount`, so tests can verify that and how often `SetFont` was called.
    - New `MakeGameFontNormalOutline()` helper provides a deterministic stand-in for the global `GameFontNormalOutline` FontObject with `GetFont()` (default `Fonts\\FRIZQT__.TTF`, 10, `OUTLINE`). `BuildEnv` injects it via `globals.GameFontNormalOutline` so `ApplyFont`'s template lookup works in tests.
  - 3 new scenarios:
    1. **`MobNameplate ApplyFont calls SetFont with the configured fontSize on initial frame creation`** — `SetAppearance({fontSize=22})` BEFORE `SetEnabled(true)` + `_Test_UpdateNameplate` → `frame.text._font.size == 22`. Verifies that the initial frame picks up the persisted value, not the module default of 12.
    2. **`MobNameplate SetAppearance({fontSize}) during enabled re-applies SetFont with the new size`** — initial render with default 12 → snapshot `_setFontCallCount` → `SetAppearance({fontSize=19})` mid-key → `_setFontCallCount` must be > snapshot AND `_font.size == 19`. Verifies that slider changes apply without `/reload`.
    3. **`MobNameplate font-size pipeline is unaffected by Plater being loaded`** — mock for `IsAddOnLoaded("Plater")` and `C_AddOns.IsAddOnLoaded("Plater")` returns true, then `SetAppearance({fontSize=16})` + `SetEnabled(true)` + update → frame exists, is shown, `_font.size == 16`. Locks in the architectural invariant that Plater soft-detection lives exclusively in the settings UI, NOT in the nameplate module; a refactor introducing "Plater loaded → module disabled" would break this test.
  - 1080 / 1080 → 1083 / 1083 scenarios. Stylua, luacheck, hardcoded-strings clean. Pure test patch, no production-code change.

## 2026-04-24 - Version 0.9.191 (minor)

- **M+ killtracker: DB-total fallback + drift warning + boss-target markers on the progress bar ([game/isiLive_killtrack.lua](../game/isiLive_killtrack.lua), [ui/isiLive_roster_panel_kill_row.lua](../ui/isiLive_roster_panel_kill_row.lua)):**
  - Consistency anchor with the nameplate / tooltip path (0.9.186): the killtracker still reads `total` primarily from `cInfo.totalQuantity` (Blizzard API takes precedence because `rawCount` comes from the same source — mixing API `rawCount` + DB `total` would produce off-by-fraction percentages after a patch drift). But: if API `totalQuantity` is missing (Secret-Value taint, nil return, <= 0), the killtracker falls back to `addonTable.MPlusForces.dungeonTotal[mapID].total` instead of switching off completely. Without the fallback, the tracker would lose its display on a temporary API quirk; with the fallback, it stays live as long as the DB knows the dungeon.
  - Drift detection: when API total and DB total both exist but differ, the killtracker surfaces it once into the runtime log via a new `KillTrack.SetDebugLogger` hook (`[KILLTRACK] mapID=X total drift: api=Y db=Z (using api; check tools/sync_mdt_forces.lua)`). A `lastDriftKey` cache suppresses re-spam on repeated identical drifts. This way we can tell live whether Blizzard changed the `dungeonTotalCount` between MDT refreshes — the symptom would be systematically wrong percentages.
  - `KillTrack.GetData()` now additionally returns `mapID` (from `state.mapID`, set in `ReadLiveData`, cleared on `CHALLENGE_MODE_COMPLETED` / `CHALLENGE_MODE_RESET`). Required for the UI boss-target lookup.
  - **Boss-target markers on the forces progress bar** ([ui/isiLive_roster_panel_kill_row.lua](../ui/isiLive_roster_panel_kill_row.lua)): vertical 1 px lines at the boss-target thresholds from `data/isiLive_mplus_boss_targets.lua` (e.g. Skyreach `{28.07, 52.2, 60.09, 100}`). Pre-allocated pool of 8 marker textures per row (currently max 4 bosses per dungeon, 8 is headroom). Per render: position computed from current container width × target/100, re-positioning on layout switches automatic via the `OnSizeChanged` trigger of the existing bar-refresh pipeline.
  - **Marker color coding** three states based on `accumulated` (cumulative `state.percent`) and `pullPct` (`pull.pullPercent`):
    - **Gray** (`0.6, 0.6, 0.65, 0.9`) — boss target is beyond the current pull (default, "not yet reachable")
    - **Yellow** (`1.0, 0.85, 0.2, 0.9`) — current pull will push cumulative over the boss target ("if this pull goes through, the boss is unlocked"). Criterion: `pct < target <= pct + pullPct`.
    - **Green** (`0.2, 0.85, 0.3, 0.9`) — boss target already exceeded by cumulative ("boss already unlocked"). Criterion: `pct >= target`.
  - User overrides for the boss targets via `IsiLiveDB.bossTargetsOverride[mapID]` are honored (same resolve logic as in the nameplate from 0.9.183).

- **Tests:**
  - 6 new scenarios in [testmodul/isilive_test_scenarios_killtrack.lua](../testmodul/isilive_test_scenarios_killtrack.lua):
    - `KillTrack.GetData exposes the active challenge mapID for downstream consumers`
    - `KillTrack.GetData clears mapID on CHALLENGE_MODE_COMPLETED`
    - `KillTrack falls back to MPlusForces.dungeonTotal when API totalQuantity is missing` (API nil → DB value used, percent computes 25/596 × 100)
    - `KillTrack ignores DB total when API total is present and uses API-total instead` (API total 450 vs DB total 596 — API wins, percent based on 450)
    - `KillTrack debug logger fires once on API/DB total drift, then suppresses repeats` (drift-logger hook + `lastDriftKey` suppression)
    - `KillTrack stays inactive when API total is missing and DB has no entry for the mapID` (mapID=99999 with no DB entry → state stays at 0)
  - Usecase total 1074 → 1080.

## 2026-04-24 - Version 0.9.190 (patch)

- **CI: bumped 2 more Actions - the 0.9.189 v4-->v5 bump was not enough for `actions/upload-artifact` and `leafo/gh-actions-luarocks`; both v5 releases were still on Node 20:**
  - Live annotation from the 0.9.189 workflow: `Node.js 20 actions are deprecated. The following actions are running on Node.js 20 and may not work as expected: actions/upload-artifact@v5, leafo/gh-actions-luarocks@v5`. Unlike `actions/checkout` and `JohnnyMorganz/stylua-action` (where v5 is the Node 24 transition release), these two needed another major bump:
    - `actions/upload-artifact` v5 -> v6 (in [.github/workflows/lua-check.yml](../.github/workflows/lua-check.yml))
    - `leafo/gh-actions-luarocks` v5 -> v6 (kept synchronized in both workflows)
  - `leafo/gh-actions-lua@v12`, `actions/checkout@v5`, and `JohnnyMorganz/stylua-action@v5` stay unchanged; the 0.9.189 workflow annotation no longer listed them as Node 20 warnings.
  - If v6 still emits warnings: 0.9.191 will bump further to v7 / v6.1. These bumps are iterative because without the live runner annotation it is not clear which major version actually contains the Node 24 transition (some maintainers do not publish release notes for that).

## 2026-04-24 - Version 0.9.189 (patch)

- **CI: bumped all GitHub Actions to Node.js 24-capable versions ([.github/workflows/lua-check.yml](../.github/workflows/lua-check.yml), [.github/workflows/sync-mplus-forces.yml](../.github/workflows/sync-mplus-forces.yml)):**
  - Background: workflow annotations had reported `Node.js 20 actions are deprecated` for days. Deadlines: 2026-06-02 (force Node 24) / 2026-09-16 (Node 20 removed from the runner). Applied a conservative one-major bump to the first Node 24-capable major version for each action, with less risk than jumping to the latest-latest release (e.g. checkout@v6.0.2 may include additional breaking changes; v5 is the Node 24 transition version):
    - `actions/checkout` v4 -> v5 (Node 24 transition release)
    - `actions/upload-artifact` v4 -> v5
    - `JohnnyMorganz/stylua-action` v4 -> v5
    - `leafo/gh-actions-lua` v11 -> v12
    - `leafo/gh-actions-luarocks` v4 -> v5
  - Both workflows (push CI and weekly MDT DB auto-refresh) are kept synchronized.
  - The architecture test in [testmodul/isilive_test_scenarios_architecture.lua](../testmodul/isilive_test_scenarios_architecture.lua) that asserted `uses: JohnnyMorganz/stylua-action@v4` as a snippet was updated to `@v5`.
  - Tests: 1074 / 1074 green locally. The actual action-version changes only take effect on the first GitHub Actions run (push); if a v5 action has breaking changes, the next push will show it.

## 2026-04-24 - Version 0.9.188 (minor)

- **New CI gate against hardcoded strings in `ui/` and `logic/` ([tools/check_hardcoded_strings.lua](../tools/check_hardcoded_strings.lua)):**
  - Motivation: `tools/check_locale_drift.lua` only checks drift between the 8 locale tables, not the UI code itself. If someone writes `tooltip:AddLine("Click to mark unit")` without `L.<KEY>` indirection, it slips through - exactly what 0.9.187 had to audit manually (12 locations). The new gate catches that automatically during preflight.
  - Heuristic: scans all `*.lua` files under `ui/` and `logic/`, looking for lines with `:AddLine(` / `:SetText(` / `:SetTitle(` / `:SetTooltipText(`. Per line, it extracts all `"..."` literals, first stripping two patterns that should not be flagged: `<expr> or "literal"` (Lua nil-coalesce idiom where the string IS the fallback) and WoW markup `|cff......`/`|r`/`|T...|t`/`|A...|a`/`|H...|h`. It then tokenizes the remaining literals into alphabetic sequences >=4 characters and flags every sequence not present in the small whitelist (`ilvl`, `rio`, `isilive`, `npcid`, `brez`, `mythic`, plus the 8 locale tags).
  - Inline override: `-- i18n-ok` (or `-- i18n: ok`) at the end of the line silences the gate for genuinely language-neutral content (brand names, icon labels). Use sparingly - the preferred solution is `L.<KEY>`.
  - Wiring: `tools/validate_ci_local.ps1` and `.github/workflows/lua-check.yml` run the gate between `Locale Drift Check` and `M+ Forces DB Lifetime`. The weekly `.github/workflows/sync-mplus-forces.yml` trigger (auto MDT refresh) mirrors it as well. Architecture tests in [testmodul/isilive_test_scenarios_architecture.lua](../testmodul/isilive_test_scenarios_architecture.lua) assert both gate snippets, so the gate cannot silently drop out of the pipeline.
  - The initial run found **3 real hits** (after improving the heuristic from an initial 49 false positives via markup stripping + or-fallback detection):
    1. [ui/isiLive_roster_panel.lua:803](../ui/isiLive_roster_panel.lua) `ui.kickHeader:SetText("Kick")` -> replaced with `L.COL_KICK or "Kick"`. New locale key `COL_KICK` in all 8 languages with the identical value "Kick" (gaming term, language-neutral, but now consistently routed through the locale system).
    2. [ui/isiLive_roster_panel_kill_row.lua:32](../ui/isiLive_roster_panel_kill_row.lua) `label:SetText("|cff888888M+Killtracker|r")` -> annotated with `-- i18n-ok` (brand name of our kill-tracker module).
    3. [ui/isiLive_roster_panel_render.lua:358](../ui/isiLive_roster_panel_render.lua) `cell:SetText("|cff44ff44ready|r")` (sync-kick status indicator) -> replaced with `cell:SetText("|cff44ff44" .. readyText .. "|r")`, with `readyText` from new locale key `SYNC_KICK_READY`. DE: "bereit", FR: "pret", ES: "listo", PT/IT: "pronto", RU: "gotov", TR: "hazir"; enUS stays "ready". The `SetKickCellText` signature gained a `getL` parameter (analogous to `CreateMemberRow` from 0.9.187), and the caller in `RenderRosterImpl` passes `state.getL` through.
  - The existing `Architecture kick tracker uses lightweight kick-column refresh hooks` architecture scenario assertion was moved from the hardcoded `cell:SetText("|cff44ff44ready|r")` expectation to the new `cell:SetText("|cff44ff44" .. readyText .. "|r")` pattern.

## 2026-04-24 - Version 0.9.187 (patch)

- **Localization: 12 previously hardcoded English strings now translated in all 8 languages + "forces" -> "Fortschritt" (DE) and matching equivalents ([locale/isiLive_texts.lua](../locale/isiLive_texts.lua)):**
  - User-reported gap: despite deDE locale being selected, several hover tooltips stayed in English because their strings were embedded directly in UI code and never passed through the locale table. The `check_locale_drift` gate therefore stayed green - it only compares the 8 locale tables against each other, not UI-code call sites.
  - Introduced 12 new locale keys (in all 8 languages enUS/deDE/frFR/esES/ptBR/itIT/ruRU/trTR, with ASCII accent stripping / ruRU transliteration):
    - `TOOLTIP_MOB_PROGRESS_LINE` - the mouseover line for M+ enemy forces. User request: remove "forces", use "Fortschritt" (DE) instead. enUS `"+%d progress (%.2f%% of %d)"`, deDE `"+%d Fortschritt (%.2f%% von %d)"`, frFR `"+%d progression (%.2f%% sur %d)"`, esES `"+%d progreso (%.2f%% de %d)"`, ptBR `"+%d progresso (%.2f%% de %d)"`, itIT `"+%d progresso (%.2f%% di %d)"`, ruRU `"+%d progress (%.2f%% iz %d)"`, trTR `"+%d ilerleme (%.2f%% / %d)"`. The `%d/%.2f/%d` order is identical in all languages so the drift tool accepts the placeholder counts as synchronized.
    - `TOOLTIP_LEVEL_FMT` / `TOOLTIP_CLASS_FMT` / `TOOLTIP_ILVL_FMT` / `TOOLTIP_RIO_FMT` - the 4 info lines in the roster hover tooltip. iLvl and Rio remain the same in all languages as gaming-community terms; only "Level" and "Class" are translated (Stufe / Klasse in DE, Niveau / Classe in FR, etc.).
    - `TOOLTIP_WORLDMARKER_TITLE_FMT` / `TOOLTIP_WORLDMARKER_LCLICK` / `TOOLTIP_WORLDMARKER_RCLICK` - hover hints over the 8 world-marker buttons to the right of the roster.
    - `TOOLTIP_ROLE_MARKER_TITLE` / `TOOLTIP_ROLE_MARKER_HINT` / `TOOLTIP_ROLE_MARKER_TANK` / `TOOLTIP_ROLE_MARKER_HEALER` - the 4-line legend above the role-marker button on each roster row.
  - Converted 12 call sites: [ui/isiLive_mob_tooltip.lua:123](../ui/isiLive_mob_tooltip.lua), [ui/isiLive_roster_tooltip.lua:764+770+775+778](../ui/isiLive_roster_tooltip.lua), [ui/isiLive_roster_panel_chrome.lua:418+420+421](../ui/isiLive_roster_panel_chrome.lua), [ui/isiLive_roster_panel_render.lua:156+158+159+160](../ui/isiLive_roster_panel_render.lua). Every location uses the established fallback pattern `type(L.KEY) == "string" and L.KEY or "<english literal>"`, preserving English output as fallback if a module scenario runs without locale injection.
  - New module interface `MobTooltip.SetLocaleGetter(fn)` in [ui/isiLive_mob_tooltip.lua](../ui/isiLive_mob_tooltip.lua), parallel to `SetEnabled` and `Register`. The module previously had no locale wiring at all; factory init in [factory/isiLive_factory.lua:338](../factory/isiLive_factory.lua) now calls `mobTooltip.SetLocaleGetter(ctx.GetL)` before `Register`, making the module react to runtime language changes (the tooltip is rebuilt on every hover anyway).
  - [ui/isiLive_roster_panel_render.lua](../ui/isiLive_roster_panel_render.lua) `CreateMemberRow` signature extended with a `getL` parameter (new 4th arg). The call site in `RenderRosterImpl` passes `state.getL`, which is already wired through the status controller. The role-marker OnEnter closure uses the parameter via closure capture.

- **Tests:**
  - Existing `testmodul/isilive_test_scenarios_mob_tooltip.lua` scenarios check via `tooltipLines[1]:find("1.16")` and `:find("+5")` - both substrings still exist in the new format, so no test change was needed.
  - 1074 / 1074 scenarios green.

## 2026-04-24 - Version 0.9.186 (minor)

- **Nameplate enemy-forces overlay now uses the bundled MDT-synced DB as the source of truth ([ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua), [data/isiLive_mplus_forces.lua](../data/isiLive_mplus_forces.lua)):**
  - User-reported bug: "der zeigt den gesamtfortschritt in % an, die was der mob an prozent bringt" - the percentage shown over nameplates was the cumulative dungeon progress instead of what each individual mob contributes. Root cause is Blizzard's `C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)` API: its `percentString` return, which originally exposed the per-mob contribution, in some 12.0+ protected contexts returns the cumulative forces progress instead. The [gerritalex.de Midnight nameplate writeup](https://gerritalex.de/blog/nameplates-in-midnight) referenced in v0.9.182 already hinted that the API's guarantees around this field were fragile.
  - Fix: the nameplate now computes the per-mob percentage **deterministically from the addon's bundled `data/isiLive_mplus_forces.lua` DB** - the same authoritative source already used by the mouseover tooltip ([ui/isiLive_mob_tooltip.lua](../ui/isiLive_mob_tooltip.lua)) since v0.9.140. New internal helpers `NpcIdFromGuid(guid)` and `ResolveMobContributionFromDB(unit, mapID)` parse `UnitGUID(unit)` for the NPC id, look up `MPlusForces.byNpcId[npcId]` for the mob's raw forces count, and divide by `MPlusForces.dungeonTotal[mapID].total` to get `% = count / total * 100`. Returns `"%.2f"`-formatted percent plus `rawCount`, so the nameplate renders exactly `"1.16%"` for a Chakram Master in Skyreach regardless of any cumulative-progress taint in the live API.
  - API fallback preserved: when the DB lacks the NPC (fresh patch mob before the weekly MDT auto-refresh ships a new DB), the module falls back to the old `C_ScenarioInfo.GetUnitCriteriaProgressValues` path with the v0.9.184 IsSecretValue guard. This means the fix is strictly additive - no dungeon loses coverage, and the next scheduled DB refresh closes any new NPC gap automatically.
  - Secret-Value ordering observed throughout: `type(guid) -> IsSecretValue(guid) -> guid == ""` on `UnitGUID` returns, `:match` called only after the guards pass, `activeMapID` passed as a plain number-or-nil into the DB lookup.

- **Styled target-dungeon chat announcement: blue `isiLive` brand prefix, yellow dungeon + key-level ([factory/isiLive_factory_frame_bridge.lua](../factory/isiLive_factory_frame_bridge.lua), [ui/isiLive_status.lua](../ui/isiLive_status.lua)):**
  - User feedback on our chat announcement `isiLive: Ziel-Dungeon: Nexuspunkt Xenas +10`: we should colour the brand prefix and the dungeon/key token so it stands out in the combat log.
  - New helper `ctx.PrintHighlighted(msg)` in `factory_frame_bridge.lua` prefixes with `|cff4da6ffisiLive|r:` (the same brand blue used in the TOC title colour). Regular `ctx.Print` stays plain so existing log-heavy paths (runtime trace, debug lines, etc.) do not become harder to scan. RuntimeLog tap is shared so highlighted announcements still land in the support log.
  - `BuildTargetDungeonAnnouncementText` in `ui/isiLive_status.lua` now wraps the dungeon-name + key-level portion in `|cffffd200...|r` (Blizzard's system yellow). The locale templates (`STATUS_TARGET_DUNGEON_TEXT` across 8 languages) are **not** touched - the colour codes sit around the interpolated `%s`, so every translation picks up the highlight automatically without a locale bump. Rendered output: `<blue>isiLive</blue>: Ziel-Dungeon: <yellow>Nexuspunkt Xenas +10</yellow>`. The secondary status-line renderer (which also uses `STATUS_TARGET_DUNGEON_TEXT`) is unaffected because it calls `BuildStatusLineText` with the plain `name +level` format, not `BuildTargetDungeonAnnouncementText`.
  - `MaybeAnnounceTargetDungeonChat` routes through `deps.printHighlighted` when provided, falling back to `deps.printFn` so the function stays safe for legacy callers and for the existing status-scenario test fixtures. `factory/isiLive_factory_controllers.lua` wires `printHighlighted = ctx.PrintHighlighted` into the `statusController` deps table right next to `printFn`.

- **Mouseover tooltip "Forces" line re-worded for clarity ([ui/isiLive_mob_tooltip.lua](../ui/isiLive_mob_tooltip.lua)):**
  - Old format `"Forces: 1.16% (+5)"` was ambiguous under the "is this my current progress or what the mob brings" reading that the nameplate bug above surfaced. Switched to `"+5 forces (1.16% of 431)"` which front-loads the raw count, then explains the percentage as a fraction of the dungeon total. Same source values (`count` from `MPlusForces.byNpcId[npcId].count`, `total` from `MPlusForces.dungeonTotal[mapID].total`), only the template string changes. No locale change - the word "forces" stays English across all locales because it is the in-game term (`UI-ERROR-FORCES`, `C_ScenarioInfo.GetCriteriaInfo().description`).

- **Tests:**
  - Status scenario `Status target dungeon chat announces grouped key once and resets after target clears` updated to assert the yellow-highlighted form `"Target Dungeon: |cffffd200Ara-Kara +14|r"`. The `BuildStatusLineText`-based scenarios stay unchanged because the status-line renderer is still plain.
  - 1074 / 1074 use-case scenarios pass.

## 2026-04-24 - Version 0.9.185 (minor)

- **Nameplate font-size setting now actually changes the font size on screen ([ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua)):**
  - Bug introduced in v0.9.182: the `mobNameplateFontSize` slider (range 8-24, default 12) in Settings wrote to `IsiLiveDB.mobNameplateFontSize` and the factory forwarded it to `MobNameplate.SetAppearance({fontSize = …})`, which persisted it in the module-local `appearance.fontSize` field. But the module **never called `SetFont` / `SetTextHeight` on the FontString**, so the rendered text kept the default size of the `GameFontNormalOutline` template (~10 px) regardless of the user's slider value. User reported `mobNameplateFontSize = 19` on disk but tiny rendered text in-game.
  - New local helper `ApplyFont(fontString)` reads `GameFontNormalOutline:GetFont()` for the template's font-file + flags, then calls `fontString:SetFont(file, appearance.fontSize, flags)`. Falls back to `Fonts\FRIZQT__.TTF` + `OUTLINE` if the template lookup fails. Both resolutions are `pcall`-wrapped to survive 12.0 Secret-Value / protected-context edge cases. Called in two places: once in `CreateOrGetFrame` (new frames pick up the current size) and once in `UpdateNameplate` right before `SetText` (existing frames re-apply the current size on every update, so `SetAppearance({fontSize = …})` during an active key takes effect on the next `RefreshAll` instead of requiring `/reload`).

- **Secret-Value ordering audit on [ui/isiLive_roster_tooltip.lua](../ui/isiLive_roster_tooltip.lua) - fixes 6 latent 12.0 taint paths:**
  - Same class of bug as the v0.9.184 nameplate hotfix: `x == ""` / `x ~= ""` evaluated **before** `IsSecretValue(x)` on values returned from Blizzard tooltip / unit APIs. BugGrabber reports from older sessions (pre-0.9.184) showed exactly this pattern triggering on `tooltipUnit`, `tooltipData.unitToken`, and `UnitTokenFromGUID` returns. These paths were untainted in the user's latest session, but only because the specific mob/tooltip call-chain did not hit a protected context; a different encounter could re-trigger the same crash.
  - Introduced a module-local `IsSecretValue(v)` helper (same pattern as [ui/isiLive_mob_tooltip.lua](../ui/isiLive_mob_tooltip.lua) / [ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua)): reads `issecretvalue` via `rawget(_G, …)` so the check itself never taints. Exposed on `addonTable._RosterInternal.IsSecretValue` for test access. A comment block above the helper documents the ordering invariant explicitly: `type()`, `rawget`, and the Secret-check itself are the only operations guaranteed non-tainting on Secret Values.
  - Fixed 6 call sites in `ResolveBlizzardTooltipUnit` (the `preferTooltipDataOnly` path, `tooltip.GetUnit` via pcall, `tooltip.unit` field, `tooltipData.unitToken` on both the direct path and the `tooltipData.lines` iteration, `UnitTokenFromGUID(guid)` via pcall), plus 2 call sites in `ResolveBlizzardTooltipLanguageTagFromTooltipData` (the `guid`/`healthGUID` fallback and the `realmLocale` return from LibRealmInfo). Each reorders the conjunction to `type() → not IsSecretValue() → ~= ""`, so the Secret check blocks the subsequent comparison short-circuits at the `~=` / `==` boundary.

- **"Clear" buttons for the two on-reload debug logs in Settings → Debug ([ui/isiLive_settings.lua](../ui/isiLive_settings.lua), [factory/isiLive_factory.lua](../factory/isiLive_factory.lua)):**
  - The two `/reload`-reset logs (Queue Debug, Runtime Log) have always been clearable via chat (`/isilive qdebug clear`, `/isilive log clear`), but the Settings panel only exposed the enable/disable toggles. Added two dedicated action buttons directly beneath each toggle in the Debug section, wired through new factory callbacks `onClearQueueDebugLog` / `onClearRuntimeLog` that call the existing `ctx.clearQueueDebugLog` / `ctx.clearRuntimeLog` dispatchers under the hood. Use-case: a support helper asks the user to "clear the log and repro", the user opens Settings and clicks the button instead of typing a slash-command.
  - 2 new locale keys per language (`SETTINGS_QUEUE_DEBUG_CLEAR`, `SETTINGS_RUNTIME_LOG_CLEAR`) across all 8 supported languages (enUS, deDE, frFR, esES, ptBR, itIT, ruRU, trTR) in [locale/isiLive_texts.lua](../locale/isiLive_texts.lua). Refresh-on-language-change path updated in `RefreshSettingsControls` so a mid-session locale switch re-applies the button labels. No `SavedVariables` migration - the buttons are pure dispatchers, they don't persist anything of their own.

- **Coverage ramp for [ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua) (0.9.182 module): +13 scenarios, 1061 → 1074:**
  - The new nameplate overlay module shipped in v0.9.182 was functionally tested but had significant defensive-path coverage gaps (69 % per luacov). Added 13 new scenarios in [testmodul/isilive_test_scenarios_mob_nameplate.lua](../testmodul/isilive_test_scenarios_mob_nameplate.lua) exercising paths that were previously only data-flow-reachable:
    - All 4 `ApplyPosition` anchor branches (`LEFT`/`RIGHT`/`TOP`/`BOTTOM`) assert the exact `SetPoint(framePoint, nameplate, nameplatePoint)` anchor pair used in each mode, plus a 5th scenario for an unknown position string that must fall back to `"CENTER"` anchored to `"CENTER"`.
    - `CreateFrame` fails with a raised error inside the `pcall`: `SetEnabled(true)` must swallow and not create any nameplate frame.
    - `UnitReaction` returns a Secret-Valued reaction: the IsSecretValue guard in v0.9.184 must route through the "treat as eligible" path instead of tripping the hostile-vs-friendly comparison.
    - `NAME_PLATE_UNIT_REMOVED` exercised by driving the real `OnEvent(frame, eventName, arg1)` handler attached via `SetScript`, instead of the earlier indirect `SetEnabled(false)` proxy - asserts the specific unit's pool entry is dropped while other frames remain in the pool.
    - `SetFormat` during `enabled = true` triggers `RefreshAll`, demonstrated by flipping `showPercent = false` with `bossTargetMode = "off"` and confirming the single active frame hides (no visible parts).
    - `SetAppearance({fontSize = 19})` during `enabled = true` persists the new size in module state (verified via `_Test_GetState`), covering the new font-size re-apply path from this release.
    - `ResolveBossRemainder` with `mode = "off"` hits the early-return branch - verifies the frame text is just the percent without `+X%`.
    - `GetActiveChallengeMapID` with a Secret-Valued `mapID` return: the v0.9.184 fix must drop the boss-target remainder cleanly. Asserted against a 999999-mapID mock that has `[secret]` in its DB but IsSecretValue returning `true`.
    - `ResolveScenarioProgress` with Secret-Valued `numCriteria` from `GetStepInfo().numCriteria`: must abort the criteria iteration before the `<= 0` comparison, so the frame still renders the percent part but drops the remainder.
  - No test counts changed in other suites. Stylua + luacheck pass on the new file. Usecase total 1061 → 1074.

## 2026-04-24 - Version 0.9.184 (patch)

- **Hotfix: 12.0 Secret-Value taint crash on nameplates during an active key ([ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua)):**
  - Live bug reported by user: `595x ui/isiLive_mob_nameplate.lua:230: attempt to compare local 'guid' (a secret string value, while execution tainted by 'isiLive')`. Root cause: in `IsEligibleUnit`, the `guid == ""` comparison was evaluated **before** the `IsSecretValue(guid)` check. In 12.0-Midnight the `UnitGUID(unit)` return for some protected nameplate slots comes back as a Secret-Valued string — `type()` still returns `"string"` (safe), but the `==` operator on a Secret-String taints the execution stack and raises `ADDON_ACTION_FORBIDDEN`. Same pattern already fixed in [ui/isiLive_mob_tooltip.lua](../ui/isiLive_mob_tooltip.lua) in v0.9.180, but the brand-new nameplate module introduced in v0.9.182 reintroduced it.
  - Fix: `IsSecretValue(guid)` is now evaluated **before** `guid == ""` on line 230 (`IsEligibleUnit`). Short-circuit `or` guarantees the comparison is only reached once the Secret-Value check has ruled out a tainted GUID.
  - **Preventive audit** of the rest of the module found three analogous ordering mistakes on paths that did not crash in this report but could under different scenario shapes:
    - `GetActiveChallengeMapID()` — `mapID <= 0` before `IsSecretValue(mapID)`. A Secret-Valued numeric `mapID` would have tainted the comparison before the guard ran. Reordered to Secret-check first.
    - `ResolveScenarioProgress()` — `numCriteria <= 0` before `IsSecretValue(numCriteria)`. Same class of bug. Reordered, and moved the `tonumber()` conversion to after the Secret-check so we operate on the raw field.
    - `BuildText(percentString, ...)` — `percentString ~= ""` before `not IsSecretValue(percentString)`. The caller already Secret-checks `percentString` on line 344 before calling `BuildText`, so this path never crashed in practice, but the defensive ordering inside `BuildText` itself is now correct so the function is safe under any caller.
  - Root-cause class documented as "Secret-Value ordering invariant": any value coming through `pcall` from a Blizzard API in a protected context must be `IsSecretValue`-checked **before** any `==`, `~=`, `<`, `<=`, `>`, `>=`, `..`, or `string.match` / `string.format` operation. `type()`, `rawget`, and the Secret-check itself (`issecretvalue(v)` via `rawget`) are the only operations that are guaranteed non-tainting on Secret Values.
  - 1061/1061 use-case scenarios pass. No test changes: the existing `MobNameplate hides text when UnitGUID is a Secret Value` scenario exercises the logical path, but the Lua test harness cannot simulate runtime-taint on a primitive string (Lua metatables on strings are not customizable for `__eq` in 5.1 without global `debug.setmetatable` hacks), so the ordering invariant is preserved via code review. A future audit task in [todo.md](../todo.md) could lift the invariant into a lint rule if the need for recurrence-prevention grows.

## 2026-04-24 - Version 0.9.183 (patch)

- **Defaults for fresh installations recalibrated to "Nameplate / remainder display off / font size 12 / position right" (matching the settings screenshot):**
  - `format.bossTargetMode` default `"next"` -> `"off"` in [ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua), with the factory helper `ResolveMobNameplateBossTargetMode` fallback changed as well. All 3 fallback sites in [ui/isiLive_settings.lua](../ui/isiLive_settings.lua) (`NormalizeBossTargetMode`, `ResolveBossTargetModeFromDB`, reset path) were moved consistently.
  - `appearance.fontSize` default `10` -> `12` in all 4 fallback sites (module, initial factory wiring, factory onChange, settings getter, settings setter, preview reader, refresh hook).
  - M+ forces display mode for a completely empty SavedVariables DB: previously `mplusForcesEstimate ~= false` (nil -> true -> "tooltip"). New behavior: an explicit one-time migration during factory init writes `mobNameplateEnabled = true, mplusForcesEstimate = false` into the DB when both keys are `nil`; after that, all code paths read the persisted values. Existing users keep their mode: anyone who installed 0.9.181 with `mplusForcesEstimate == true` (explicitly enabled via settings toggle) stays on "tooltip".
  - `ResolveMplusForcesModeFromDB(db)` in the settings getter was made stricter: `db.mplusForcesEstimate == true` instead of `~= false`. This removes the implicit default-on behavior; the choice must be explicit in the DB. The factory-init migration ensures that the default state is actually persisted there.

- **Persistence fix: the position selector was not resynchronized with the DB during `panel.Refresh()` (e.g. after a language change or category switch).**
  - `controls.nameplatePosition.UpdateHighlight()` was missing from [ui/isiLive_settings.lua](../ui/isiLive_settings.lua) `RefreshSettingsControls`. The 4 position buttons could therefore show stale highlight states after a refresh while `db.mobNameplatePosition` was correct in the background.
  - Added now, analogous to `nameplateDisplayMode.UpdateHighlight()` and `nameplateBossTargetMode.UpdateHighlight()`.

- **Nameplate remainder display: "Next boss" vs. "Final boss" as a 3-way selector (`ui/isiLive_mob_nameplate.lua`, `ui/isiLive_settings.lua`):**
  - The previous single "show remainder to next boss (+X%)" toggle is replaced by a **3-option selector**: **Off / Next boss / Final boss**. Exclusive (radio-style), exactly one active at all times. Default `"next"`.
  - **`"next"` mode** (as before): remainder to the next undefeated boss target from `data/isiLive_mplus_boss_targets.lua`. Example: Skyreach, progress 17%, boss 1 target 28.07 -> `+11%`.
  - **New `"end"` mode**: remainder to 100% forces (final-boss threshold, independent of boss count). Example: progress 17% -> `+83%`. Useful as an overall progress display.
  - DB key `mobNameplateBossTargetMode` in `{"off","next","end"}` replaces the earlier `mobNameplateShowBossTarget` boolean. Migration in [factory/isiLive_factory.lua](../factory/isiLive_factory.lua) (`ResolveMobNameplateBossTargetMode`): old `== false` -> `"off"`, otherwise -> `"next"`. The old boolean is still written in sync for SavedVariables backward compatibility with 0.9.182 installations that manually downgrade.
  - Module API `MobNameplate.SetFormat` now accepts `bossTargetMode = "off"|"next"|"end"` instead of `showBossTarget = bool`. New helper `ResolveBossRemainder(mode)` in the nameplate module: "end" needs only the Scenario API (no boss-target DB lookup), while "next" works as before. The settings preview simulates both modes (`+13%` vs. `+83%`).
  - 4 new locale keys in all 8 languages: `SETTINGS_NAMEPLATE_BOSS_TARGET_MODE` + `_MODE_OFF`/`_NEXT`/`_END`. Old key `SETTINGS_NAMEPLATE_SHOW_BOSS_TARGET` removed from all languages.
  - Tests: the `SetFormat(showBossTarget)` scenario was split into two scenarios - `bossTargetMode=next renders +X% remainder to next boss` + `bossTargetMode=end renders remainder to 100%`. `ui_settings` checkbox count 24->23 (one fewer toggle; selector counts as buttons, not as a checkbox). Total 1060->1061 scenarios.

## 2026-04-24 - Version 0.9.182 (minor)

- **New feature: Mythic+ enemy-forces overlay on nameplates (`ui/isiLive_mob_nameplate.lua`) — complements the existing mouseover-tooltip forces line with an always-on text over every hostile unit's nameplate during a key:**
  - Source of truth is Blizzard's native 12.0 API `C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)` which returns `rawCount, _, percentString`. No MDT runtime dependency — the addon remains self-contained; our build-time [tools/sync_mdt_forces.lua](../tools/sync_mdt_forces.lua) already supplies the per-NPC + per-dungeon totals in [data/isiLive_mplus_forces.lua](../data/isiLive_mplus_forces.lua) and is now also consulted for the optional `count/total` format option. This explicitly avoids the `MDT:GetEnemyForces(npcID)` runtime-dependency pattern that forces every user to install MDT alongside.
  - Activation gate (all four must hold): `C_ChallengeMode.IsChallengeModeActive()` true, user toggle set via settings, `UnitReaction(unit,"player") ≤ 4` (hostile/neutral only — friendly units skipped), and `UnitGUID` is a real non-empty string that is not a Secret Value. Events driving refresh: `NAME_PLATE_UNIT_ADDED/REMOVED`, `CHALLENGE_MODE_START`, `PLAYER_ENTERING_WORLD`, `SCENARIO_UPDATE`. Frames are pooled per unit token so `CreateFrame` is called at most once per concurrent nameplate slot, not per event. 12.0 Secret-Value hardening applies to every protected-context return (`GetActiveChallengeMapID`, `UnitGUID`, `UnitReaction`, and both `rawCount` + `percentString` from `GetUnitCriteriaProgressValues`) — each is pcall-wrapped and routed through a local `IsSecretValue(v)` helper backed by `rawget(_G, "issecretvalue")`.
  - Configurable via new SavedVar keys on `IsiLiveDB` (flat, matching existing conventions like `mplusForcesEstimate`): `mobNameplateEnabled` (default `false` — see Plater/Platynator note below), `mobNameplateShowPercent` (default `true`), `mobNameplateShowCount` / `mobNameplateShowTotal` (default `false`, count-only vs `count/total` format), `mobNameplateFontSize` (8-24, default 10), `mobNameplatePosition` (`LEFT`/`RIGHT`/`TOP`/`BOTTOM`, default `RIGHT`), plus `mobNameplateXOffset`/`mobNameplateYOffset`. Factory wires `SetFormat` + `SetAppearance` + `Register` + `SetEnabled` through a new `onMobNameplateChange` callback so every settings checkbox/slider refreshes the live state without a reload.
  - Settings UI gets a dedicated new "Nameplates" section (between Display and Behavior) with toggle + percent/count/total checkboxes + font-size slider + position option-selector. A Plater/Platynator soft-detect (checks both `C_AddOns.IsAddOnLoaded` and the legacy global `IsAddOnLoaded`) shows a subtle warning note at build time: "Plater/Platynator already shows M+ count? Leave this off." — no hard disable, no `hooksecurefunc` on their internals, user decides. Default-OFF is intentional: most Plater/M+ users already have a Wago script doing this (although many such scripts break in 12.0 because they chain `UnitGUID` → strsplit → `MDT:GetEnemyForces`, a path that Secret Values now taint — see the [gerritalex.de Midnight nameplate writeup](https://gerritalex.de/blog/nameplates-in-midnight)).
  - Full locale coverage across all 8 supported languages (enUS, deDE, frFR, esES, ptBR, itIT, ruRU, trTR) in [locale/isiLive_texts.lua](../locale/isiLive_texts.lua). 13 new keys: `SETTINGS_SECTION_NAMEPLATES`, `_HINT`, `NAMEPLATE_EXTERNAL_WARN`, `NAMEPLATE_FORCES`, `_SHOW_PERCENT`, `_SHOW_COUNT`, `_SHOW_TOTAL`, `_FONT_SIZE`, `_POSITION`, `_POS_LEFT/RIGHT/TOP/BOTTOM`. ASCII-only transliteration for ruRU and accent-stripped German/French/Italian/etc. kept consistent with the rest of the file.
  - 12 scenarios in [testmodul/isilive_test_scenarios_mob_nameplate.lua](../testmodul/isilive_test_scenarios_mob_nameplate.lua) cover: Register succeeds/fails for each missing API (`C_ScenarioInfo`, `C_NamePlate`), `SetEnabled(true)` registers exactly the 5 expected events on a dedicated frame and `SetEnabled(false)` unregisters them all, happy-path percent rendering for an eligible hostile unit, friendly units (`reaction > 4`) skipped, challenge-mode-inactive skipped, Secret-Valued GUID path, Secret-Valued `percentString` path, `SetFormat({showCount=true})` renders raw integer, `SetFormat({showCount=true,showTotal=true})` renders `count/total`, and frame-pool cleanup on disable. Tests are registered in [tools/usecase_scenarios.lua](../tools/usecase_scenarios.lua) and run as part of both local and CI usecase validation (total now 1060/1060 passing).
  - Existing regression test in [testmodul/isilive_test_scenarios_ui_settings.lua](../testmodul/isilive_test_scenarios_ui_settings.lua) that asserts the exact number of sliders and checkboxes in the settings panel was updated: 2→3 sliders (BG opacity, UI scale, nameplate font-size), 23→24 checkboxes (legacy `mplusForces`+`nameplateForces` toggles replaced by a 3-way display-mode selector; `showCount`+`showTotal` redundant toggles dropped — see next bullet for rationale; new `showBossTarget` toggle added). The position option-selector uses `Button` frames which are not counted.
  - No TOC `## Interface:` change — still `120005`. No new bundled libraries, no MDT runtime dependency added.

- **Nameplate overlay upgrade: section percentage (to next boss) instead of redundant count display (`ui/isiLive_mob_nameplate.lua`, `data/isiLive_mplus_boss_targets.lua`):**
  - Rationale: the previous sub-toggles `showCount` and `showTotal` showed exactly the same per-mob contribution information as `showPercent`, only in a different format (`5`, `5/431` vs. `1.16%`) - redundant and not useful for M+ players. The more interesting data point is "how much forces progress is still missing until the next boss target". Both old toggles were removed (DB keys `mobNameplateShowCount`/`mobNameplateShowTotal` are no longer read either, but remain silently as legacy fields in old SavedVariables without migration).
  - New toggle `showBossTarget` (default ON) + new DB key `mobNameplateShowBossTarget`. Output format is now e.g. `1.16% | +13%` - the first value is the per-mob contribution, the second means "13 percentage points left until the current boss-target threshold is reached".
  - New data file `data/isiLive_mplus_boss_targets.lua` with cumulative boss-target percentages per dungeon. Values are community convention, adapted from [community source](https://github.com/community-source/forces-data) (GPLv2, attribution in the file header) - KP has maintained this mapping for years, and the numbers originally come from speedrun community consensus. For the current 8 Midnight Season 1 dungeons: Skyreach {28.07, 52.2, 60.09, 100}, SotT {14.61, 56.87, 100, 100}, Algethar {21.52, 51.09, 77.17, 100}, PoS {58.63, 79.94, 100}, Windrunner {45.35, 57.36, 100, 100}, Magisters {27.81, 48.91, 78.06, 100}, NPX {29.36, 73.66, 100}, Maisara {48.6, 89.95, 100}. User override via `IsiLiveDB.bossTargetsOverride[mapID] = { ... }` is possible (no UI for it - manual Lua edit).
  - Scenario API integration in [ui/isiLive_mob_nameplate.lua](../ui/isiLive_mob_nameplate.lua): new helpers `ResolveBossTargets(mapID)` + `ResolveScenarioProgress()` + `ResolveBossRemainder()`. `ResolveScenarioProgress` iterates `C_ScenarioInfo.GetStepInfo().numCriteria` and then `GetCriteriaInfo(i)` for each criterion: criteria with `totalQuantity > 1` are enemy forces (current progress via `quantity / totalQuantity`), criteria with `totalQuantity == 1` are bosses (Blizzard orders them in bossOrder sequence, so the nth boss criterion index is also the nth boss target from our DB). First non-`completed` boss -> next target value -> remainder = max(0, target - currentProgress). All API returns are pcall-wrapped and `IsSecretValue`-checked (including `totalQuantity`/`quantity`, for 12.0 Midnight Secret Value hardening).
  - Settings section adjusted: the sub-toggle block in the Nameplates section now contains only `Show percentage` + `Show remainder to next boss (+X%)` instead of the previous three. The preview row simulates the target format with fixed sample values `1.16%` and `+13%` (instead of the earlier `1.16% | 5/431`).
  - Locale: `SETTINGS_NAMEPLATE_SHOW_COUNT` and `SETTINGS_NAMEPLATE_SHOW_TOTAL` removed from all 8 languages, `SETTINGS_NAMEPLATE_SHOW_BOSS_TARGET` added (enUS: "Show remainder to next boss (+X%)", deDE: "Rest bis naechstem Boss anzeigen (+X%)", etc.).
  - Tests: `MobNameplate SetFormat(showCount)` and `SetFormat(showCount+showTotal)` replaced by two new scenarios - `SetFormat(showBossTarget) renders +X% remainder` (arranges a Scenario criteria mock with 4 bosses + forces criteria, checks "+11%" at 17% current vs. 28.07% target) and `hides boss-target when no active challenge map matches` (mapID 99999 -> no DB entry -> BossTarget part drops out, `showPercent` still renders). `testmodul/isilive_test_ui_helpers.lua` was extended with a Scenario API mock (`GetStepInfo`/`GetCriteriaInfo` via `state.scenarioCriteria`).
  - No new external runtime dependency. KP is not loaded or queried - we only adopted their numeric values as data points, just as our forces DB adopts MDT mob counts.

## 2026-04-22 - Version 0.9.181 (patch)

- **WoW 12.0.5 client compatibility — `## Interface: 120005` in `isiLive.toc`:**
  - Bumped from `120001` so the AddOns screen stops flagging isiLive as out-of-date on 12.0.5 clients. Title and version strings in `isiLive.toc` aligned to `v0.9.181`.
  - No runtime code changes were required. The `wow-api-check` skill was run against the full 12.0+ addon-restriction rule set: no `COMBAT_LOG_EVENT_UNFILTERED` registration (the addon uses `UNIT_SPELLCAST_SUCCEEDED` for BR/Lust, see `game/isiLive_combat_events.lua`); every `RegisterEvent` call lives in a main chunk or a login/factory init callback, never re-entered from a protected dispatcher (`CHALLENGE_MODE_START`, `ENCOUNTER_START`, etc.); `C_MythicPlus.GetOwnedKeystoneLink` is defensively guarded with `type == "function"` and has the bag-scan fallback for item `180653` (`core/isiLive_context_helpers.lua`); both real `PlaySoundFile` call sites use the `"SFX"` channel; no `|cff[...]|r` color-bracket pattern is injected into `SendChatMessage` outside a real `|H...|h|h` hyperlink; the peer-tooltip wording in `ui/isiLive_roster_tooltip.lua` is `"Client version: %s"` without a `(pN)` protocol suffix and without the `protocolVersion` branch. All six rule families passed on the 0.9.180 codebase, so 0.9.181 ships the same binary surface with only the TOC flag bumped.
  - Baseline version fields synchronised across `isiLive.toc`, `CHANGELOG_RELEASE.md`, `README.md`, `docs/ARCHITECTURE.md`, and `docs/USECASES.md`.

## 2026-04-21 - Version 0.9.180 (patch)

- **M+ Forces DB lifetime gate (`tools/check_mplus_db_lifetime.lua`) — prevents shipping a stale `data/isiLive_mplus_forces.lua` that was generated against an outdated MDT clone:**
  - The forces DB carries `expiresAt = "YYYY-MM-DD"` (15 days after `generatedAt`, written by `tools/sync_mdt_forces.lua`). The new gate loads the file via `loadfile + chunk("isiLive", t)` (the same sandbox contract as the addon's TOC loader — no side-effects, no globals leak) and compares `expiresAt` against today's UTC date (`os.date("!%Y-%m-%d")`, overridable via `ISILIVE_TODAY_OVERRIDE` for deterministic tests). Exit codes: `0` = fresh or boundary (today ≤ expiresAt), `1` = stale (today > expiresAt), `2` = malformed / missing DB. Bypass for emergency releases: `ISILIVE_ALLOW_STALE_MPLUS_DB=1` (must be exactly `"1"`, not truthy — any other value still fails, so `=true` or `=yes` does not accidentally disable the gate).
  - Wired into both CI surfaces as a new step between Locale Drift and the usecase validator: `.github/workflows/lua-check.yml` step `M+ Forces DB Lifetime` and `tools/validate_ci_local.ps1` preflight call `Invoke-CheckedCommand "M+ Forces DB Lifetime" "lua tools/check_mplus_db_lifetime.lua"`. `testmodul/isilive_test_scenarios_architecture.lua` now asserts both files contain the lifetime step so the gate cannot be silently dropped from CI by a future refactor.
  - 10 scenarios in `testmodul/isilive_test_scenarios_mplus_db_lifetime.lua` cover: fresh DB, boundary (today == expiresAt), stale DB, `ALLOW_STALE=1` bypass, `ALLOW_STALE` with non-`"1"` value does **not** bypass, missing file, missing `MPlusForces` table, malformed date string, missing `expiresAt`, and the shipped production DB loading cleanly. The tests load the tool via `chunk("module")` so the CLI main-chunk `os.exit` path is skipped and the tool's exported functions become callable as a library.

- **Automated weekly M+ forces DB refresh (`.github/workflows/sync-mplus-forces.yml`) — zero-click end-to-end refresh timed against the MDT release window:**
  - Scheduled trigger `cron: "0 6 * * 4"` fires every Thursday 06:00 UTC (= 07:00 CET / 08:00 CEST), positioned after the US Tuesday patch day + EU Wednesday weekly reset when MDT releases typically cluster. `workflow_dispatch` is also wired for manual on-demand refresh. `concurrency: { group: sync-mplus-forces, cancel-in-progress: false }` guards against overlapping runs (scheduled + manual dispatch racing) — queues behind any in-flight run instead of cancelling it mid-push.
  - Pipeline: Checkout → Setup Lua 5.1 → `git clone --depth 1 https://github.com/Nnoggie/MythicDungeonTools tools/cache/mdt` → `lua tools/sync_mdt_forces.lua` → `rm -rf tools/cache` (strip MDT source before CI gates so only the committed DB is present) → `git diff --quiet -- data/isiLive_mplus_forces.lua` into `steps.diff.outputs.changed` → all subsequent steps are gated on `changed == 'true'`. No diff means zero-work days are silent (no commit, no LuaRocks install, no lint runs).
  - Pre-commit CI preflight mirrors `lua-check.yml` exactly: Setup LuaRocks → `luarocks install luacheck 1.2.0-1` + `luarocks install luafilesystem 1.8.0-1` → StyLua check → Luacheck → Lua Syntax Check → Lua Metrics Check → Locale Drift Check → **M+ Forces DB Lifetime Check** (validates that the freshly regenerated DB has a future `expiresAt`, which it always should — this catches generator regressions that produce a malformed date) → Deterministic Usecase + Rules Logic Validation. Only after all seven gates pass does the workflow commit.
  - Commit step: `github-actions[bot]` identity, `git add data/isiLive_mplus_forces.lua` (narrow staging — the cache was already cleaned in step 4), MDT version extracted from the regenerated file via a sandbox load (`local f=assert(loadfile(...)); local t={}; f("isiLive",t); io.write(t.MPlusForces.mdtVersion)`) rather than `dofile` so the `_, addonTable = ...` varargs contract is honoured. Commit message format: `data: refresh M+ forces DB from MDT <mdtVersion>`. `git push origin HEAD:main` pushes directly to `main` — no PR review gate, because the workflow is the review gate (seven CI checks run before the commit is even created).
  - Permissions: `contents: write` only. No external secrets, no branch creation, no PR API usage. Uses the default `GITHUB_TOKEN` — the manual "release to CurseForge" flow remains a separate, explicitly-authorised action.

- **Generator format fix (`tools/sync_mdt_forces.lua`) — blocks the auto-refresh from silent-no-op failing on every Thursday:**
  - `formatDbLua` was writing column-aligned keys (`season      = %q,`, `mdtVersion  = %q,`, `npcCount     = %d,`) to produce a visually tidy diff. StyLua's default ruleset normalises `=` padding to single-space, so any freshly regenerated DB failed `stylua --check .` on the next CI run. In the new auto-refresh workflow that would have meant: every Thursday the scheduled run would regenerate the DB, hit the StyLua gate, and bail before the commit step — producing no artefact and no visible error unless someone inspected Actions manually.
  - All six `add(string.format("<key><padding>= %q,", ...))` calls in `formatDbLua` switched to single-space `= ` format. The committed `data/isiLive_mplus_forces.lua` was regenerated from the local MDT clone and passes `stylua --check` cleanly; the on-disk layout now matches what the generator writes, so future refreshes are idempotent.

- **Mob tooltip forces line — taint hardening for 12.0 "secret" GUIDs (`ui/isiLive_mob_tooltip.lua`):**
  - In-game bug report: `57x isiLive/ui/isiLive_mob_tooltip.lua:53: attempt to compare field 'guid' (a secret string value tainted by 'isiLive')` originating from the `SetWorldCursor` → `TooltipDataHandler.ProcessInfo` → our `Enum.TooltipDataType.Unit` post-call path. The previous `ResolveGuid` implementation did `type(tooltipData.guid) == "string" and tooltipData.guid ~= ""`. In 12.0 the `tooltipData.guid` for protected world-cursor tooltips can be a *secret string* — `type()` still returns `"string"` (safe), but any comparison (`~= ""`) taints the call stack and raises the forbidden-function crash shown in the report. `NpcIdFromGuid`'s `guid == ""` check and the subsequent `guid:match(...)` would have tainted too once reached.
  - New `IsSecretValue(v)` helper (same pattern already used locally for `GetActiveChallengeMapID` and in `logic/isiLive_queue.lua` / `ui/isiLive_lfg_flags.lua`) reads `rawget(_G, "issecretvalue")` and returns `type(fn) == "function" and fn(v) == true`. `ResolveGuid` calls it on both potential inputs: `tooltipData.guid` (secret → fall through to the `UnitGUID("mouseover")` backup) and the `UnitGUID` return value (secret → return `nil`, the caller bails without appending a forces line). Reading the field and calling `type()` do not taint; only the comparison/pattern match do, so the helper gate sits exactly before those operations.
  - `testmodul/isilive_test_scenarios_mob_tooltip.lua` gained one scenario: `MobTooltip honors issecretvalue on tooltipData.guid and UnitGUID fallback`. Real-engine secret GUIDs still have `type == "string"`, so the test stubs `issecretvalue` to return `true` for specific string GUIDs, then drives the tooltip callback first with `{ guid = secretString }` (exercises the `tooltipData.guid` secret path) and then with `{ dataInstanceID = 42 }` (exercises the `UnitGUID("mouseover")` secret-fallback path). Both must yield `#tooltipLines == 0` without raising.

- **Group roster repopulates after /reload inside an active M+ key (`logic/isiLive_group.lua`):**
  - User report: "nach einem reload im dungeon sehe ich keine gruppenmitglieder mehr". Repro path: inside an active keystone run, the main frame is usually hidden during combat, which means the hidden-frame event gate in `core/isiLive_bootstrap.lua:166-175` (`shouldAllowWhenHidden`) suppresses `GROUP_ROSTER_UPDATE` (`if not inChallenge and isInPartyInstance()` → `false` for party non-challenge, and the trailing `return isInGroup() and not inChallenge` → `false` while the challenge is active). The existing backup in `logic/isiLive_event_handlers_runtime.lua:418-420` covers this by manually calling `ctx.handleGroupRosterUpdate()` from `PLAYER_ENTERING_WORLD` when `wasInPartyInstance == nil and ctx.isInGroup()` (i.e. on reload). But `HandleGroupRosterUpdate` in `logic/isiLive_group.lua:366-370` had an unconditional early return `if deps.getActiveChallengeMapID() then updateUI(); updateLeaderButtons(); return end` — the fallback called the function, the function bailed out before `AddPlayerToRoster` / `UpdatePartyMembersInRoster`, and the roster stayed empty. The "Active M+ key blocks roster rebuild" scenario (v0.9.36) explicitly asserted this behaviour without distinguishing the "ongoing update during key" case from the "post-reload cold-start during key" case.
  - Fix: the active-challenge branch now populates the roster when `joinedNow == true` (`inGroupNow and not wasInGroupBefore`). Inside an active keystone no one joins a group mid-dungeon, so `joinedNow` in the challenge branch is the clean signal for "fresh Lua state after /reload". The branch runs `AddPlayerToRoster` + `UpdatePartyMembersInRoster` and then falls through to the same `updateUI()` / `updateLeaderButtons()` it did before. Critically it does **not** fall through to the regular `if joinedNow then setRoster({}); setMainFrameVisible(true, {reason="queue"}); captureQueueJoinCandidate(); announceQueuedGroupJoin(); onGroupJoined(); ... end` block below — that would auto-open the frame the user had intentionally closed during the pull, capture a non-existent queue candidate and fire the group-join sound, all of which are wrong for a reload.
  - Test rewrite in `testmodul/isilive_test_scenarios_group.lua`: the existing `Active M+ key blocks roster rebuild` scenario, which passed the default `wasInGroup = false` (= `joinedNow = true` internally) and asserted `state.roster.player == nil`, was locking in the buggy reload behaviour. Renamed to `Active M+ key does not rebuild roster on ongoing updates`, flipped to `wasInGroup = true` so `joinedNow = false` and the skip-rebuild path is exercised for its real purpose (preserving per-member spec/ilvl/rio/keys across repeated `GROUP_ROSTER_UPDATE` bursts during a key). New scenario `Active M+ key rebuilds roster after /reload (joinedNow path)` explicitly drives `wasInGroup = false` + `getActiveChallengeMapID = 2649` and asserts `state.roster.player` and `state.roster.party1` / `party4` are populated while `state.queued == 0`, `state.announced == 0`, `state.groupJoinedCalls == 0` and `#state.mainFrameVisibleCalls == 0` — i.e. the roster is rebuilt without any of the join-side-effects firing.

- **Tests:**
  - `tools/usecase_scenarios.lua` registers `testmodul/isilive_test_scenarios_mplus_db_lifetime.lua` alongside the existing `_mob_tooltip` / `_killtrack` scenarios.
  - 760 / 760 use-case scenarios pass. Stylua, luacheck, syntax, metrics, locale drift, lifetime gate and the deterministic usecase/rules logic validator are all green on the full local preflight.

## 2026-04-20 - Version 0.9.179 (patch)

- **BR / Bloodlust group announce: switched from `SendChatMessage` to the isiLive addon-message channel to avoid the 12.0 `ADDON_ACTION_FORBIDDEN` regression:**
  - Since 12.0 (Midnight), `SendChatMessage` is a protected function when invoked from a tainted execution path. `HandleUnitSpellcastSucceeded` in `game/isiLive_combat_events.lua` fires inside an active M+ keystone / boss encounter, which is exactly the context the 12.0 "Secret Values" system marks as tainted. The v0.9.175 broadcast path (local `DefaultSendChat` → `SendChatMessage(msg, "INSTANCE_CHAT" | "RAID" | "PARTY")`) therefore raised `ADDON_ACTION_FORBIDDEN AddOn 'isiLive' tried to call the protected function 'UNKNOWN()'` on every BR / Lust cast in a live key (reported 3× in a single pull from BugGrabber; the underlying `pcall` silently ate the failure client-side but the protected-call popup still fired for the caster).
  - New transport: a dedicated `BRLUST:<KIND>:<caster>:<spellID>` addon-message payload routed through `Sync.SendCombatAnnounce` in `logic/isiLive_sync.lua`, which reuses the existing `DispatchAddonMessage` pipeline (ChatThrottleLib v24 with `"NORMAL"` priority, falling back to raw `C_ChatInfo.SendAddonMessage` if the lib is unavailable). Addon-message traffic is not gated by the 12.0 protected-chat taint because it never touches `SendChatMessage` — DBM / BigWigs / WeakAuras sync the same way mid-encounter without issue.
  - Receiver dispatch: `Sync.ProcessAddonMessage` now recognises `BRLUST:` as a new payload bucket and surfaces the parsed `{kind, caster, spellID}` in `result.combatAnnounce`. `HandleChatMsgAddonEvent` in `logic/isiLive_event_handlers_runtime.lua` invokes `ctx.showCombatAnnounce(syncResult.combatAnnounce)`, which renders the locale-resolved template (`COMBAT_CHAT_BR_USED` / `COMBAT_CHAT_LUST_STARTED`) via `ctx.Print` into `DEFAULT_CHAT_FRAME`. Unknown `BRLUST` kinds (anything other than `"BR"` / `"LUST"`) are silently dropped so older peers emitting a future variant cannot log-spam the receiver.
  - Self-cast visibility preserved: the sender also renders its own cast locally through the same `ctx.ShowCombatAnnounce` helper, so the Ego user still sees their own BR / Lust in chat even outside a group. The realm-stripping `FormatDisplayName` helper moved from `combat_events` into `factory/isiLive_factory_controllers.lua` so both the self-render path and the incoming-peer path share a single normalisation.
  - Non-isiLive players see nothing. This is intentional: the v0.9.175 iteration already hard-filtered on `unit == "player"` self-casts (to avoid the "table index is secret" spam from other players' `UNIT_SPELLCAST_SUCCEEDED` in protected zones), so the previous `SendChatMessage` broadcast was already the only way non-isiLive users could have seen the call. With `N` isiLive users in the group each caster is announced to the remaining `N-1` isiLive clients.
  - Architecture cleanup in `game/isiLive_combat_events.lua`: the `DefaultResolveChannel` / `DefaultSendChat` helpers and the `sendChat` / `getL` dependencies are deleted. `CombatEvents.CreateController` now takes a single new dependency `broadcastCombatAnnounce(kind, sourceName, spellID)` and the announce path no longer formats any chat strings — that responsibility lives entirely on the receiver side. Dedup (3 s window per `sourceName|spellID`) and the `chatAnnounceBR` / `chatAnnounceLust` sender toggles stay exactly as before; they now gate whether the addon-message goes out (and, symmetrically, whether the sender prints locally), not whether a chat-API call is attempted.

- **Tests:**
  - `testmodul/isilive_test_scenarios_combat_events.lua`: the `sendChat` mock (line-based capture) is replaced by a `broadcastCombatAnnounce` mock that captures `{kind, caster, spellID}` tuples. The BR / Lust / dedup / toggle / non-player-unit / `Reset` scenarios all re-assert on the new contract; the realm-strip assertion moved out because the sender now passes the raw unit name through and the receiver handles display formatting.
  - `testmodul/isilive_test_scenarios_sync.lua`: new assertions for `Sync.ProcessAddonMessage` on `BRLUST:BR:<caster>:<spellID>` and `BRLUST:LUST:<caster>:<spellID>` payloads, plus a negative test for `BRLUST:UNKNOWN:...` to confirm unknown kinds drop to `nil`.
  - `testmodul/isilive_test_fixtures.lua`: the `BuildEventHandlersBaseOptions` fixture gained a `showCombatAnnounce` no-op default so every existing event-handler scenario picks up the new required dependency via `Merge` without per-test wiring.
  - 723 / 723 use-case scenarios pass. Architecture-rules and locale-drift checks are clean.

## 2026-04-20 - Version 0.9.178 (patch)

- **Rename the "M2" main-horizontal layout to "M+" in all user-visible strings:**
  - The compact main-horizontal layout mode is the second "main" layout alongside the expanded M view. Historically the mode button in the title bar, the "default UI to open" dropdown in settings and the "fade out during combat" checkbox hint all labelled it as `M2`. That was an internal implementation term (the layout is the *second* Main-style layout) and not meaningful to users; the addon's whole purpose is Mythic+, so `M+` conveys its intent at a glance and stays consistent with existing references to `M+` queue / keystone / run across the rest of the UI.
  - `ui/isiLive_roster_layout.lua`: `LAYOUT_MODE_CONFIG[LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL].label` switched from `"M2"` to `"M+"`. This feeds `CreateModeButton(mainFrame, def.xOffset, def.label, target, ...)` in `ui/isiLive_roster_panel.lua` and is the primary title-bar button label.
  - `ui/isiLive_roster_panel.lua`: `modeButtonDefs[1].label` (the separate static definition used for the tooltip / descriptor row) switched from `"M2"` to `"M+"`; the inline comment now reads `[M+][H][V]` instead of `[M2][H][V]`.
  - `ui/isiLive_settings.lua`: the fallback string for the "Default UI" dropdown entry changed from `"M2"` to `"M+"` so that locales without a translation also render the new label.
  - `locale/isiLive_texts.lua`: 16 values updated across all eight locales. `SETTINGS_DEFAULT_OPEN_UI_M2 = "M2"` becomes `"M+"` (8× identical). `SETTINGS_COMBAT_FADE_MM` loses the embedded `M2` reference in each language (e.g. `"Fade out during combat (M2 layout only)"` → `"Fade out during combat (M+ layout only)"`, `"Im Kampf ausblenden (nur M2-Layout)"` → `"Im Kampf ausblenden (nur M+-Layout)"`, plus the French/Spanish/Portuguese/Italian/Russian/Turkish variants). Locale **keys** (`SETTINGS_DEFAULT_OPEN_UI_M2`, `SETTINGS_COMBAT_FADE_MM`, `MODE_LAYOUT_M2`) are preserved — renaming the keys would have been a pure cosmetic rewrite touching every translation table and every test fixture.
  - Deliberately **not** renamed: the layout mode string `compact_main_horizontal` (persisted in `IsiLiveDB.rosterDefaultLayoutMode`), its legacy alias `compact_horizontal_2`, the `M2_ROW_LEFT_MARGIN` / `M2_MANAGEMENT_ROW_Y` / `M2_TOOLBAR_BUTTON_WIDTH` / etc. layout constants, and the `MODE_LAYOUT_M2` tooltip description text body. Touching any of those would have forced a SavedVariables migration and a mechanical churn diff across roster_layout, tests, docs and `.pkgmeta` with zero user-visible benefit.

- **Tests:**
  - `testmodul/isilive_test_scenarios_tank_helper.lua` adjusted the `m2Button._collapseButtonLabel` assertion from `"M2"` to `"M+"` (the internal `m2Button` variable name kept for historical continuity).
  - 723 / 723 use-case scenarios pass.

## 2026-04-20 - Version 0.9.177 (patch)

- **Readycheck 20 s-hold rendering: removed the split render pipeline that could drop the coloured background before the hold window ended:**
  - Root cause of the symptom "green/red row background disappears before the 20 s hold is up": `RenderRosterImpl` in `ui/isiLive_roster_panel_render.lua` cleared `readyCheckBackground` on every row via `ClearMemberRow` and rebuilt the row body without reapplying the ready-check colour. Reapplying it was deferred to a second pass, `RefreshReadyCheckStateImpl`, gated by `if isReadyCheckActive or HasReadyCheckHoldInRoster(state, roster) then ... end`. Any render triggered during a narrow window where the per-unit `readyCheckReadyUntil` / `readyCheckDeclinedUntil` maps had not yet been populated (e.g. between `READY_CHECK_FINISHED` firing and `PromoteReadyCheckReadyUnitsToHold` / `PromoteDeclinedReadyCheckUnitsToHold` filling the maps), or where `HasReadyCheckHoldInRoster` iterated the ordered roster and returned `false` for any other reason, cleared the background and never reapplied it — even though `displayData.readyCheckBackgroundColor` already carried the correct colour.
  - `RenderRosterImpl`'s main loop now calls `ApplyRowReadyCheckDisplay(row, displayData)` directly after `ApplyRowNameDisplay`, so the background is set (or hidden) in the same single pass that writes spec, name, key, ilvl, rio, dps and kick cells. The conditional `if isReadyCheckActive or HasReadyCheckHoldInRoster(...) then RefreshReadyCheckStateImpl({...}) end` block (23 lines) and the eleven unused local captures that only fed the `RefreshReadyCheckStateImpl` passthrough object (`buildDisplayData`, `truncateName`, `getShortSpecLabel`, `getLanguageFlagMarkup`, `getRioDelta`, `syncMarker`, `syncBadge`, `getPlayerSyncSummary`, `getReadyCheckReadyUntil`, `getReadyCheckDeclinedUntil`, `getTime`) were removed from `RenderRosterImpl`.
  - `RefreshReadyCheckStateImpl` itself stays: it is the public API surface consumed externally via `controller.RefreshReadyCheckState(roster)` in `ui/isiLive_roster_panel.lua` and invoked from `factory/isiLive_factory_controllers.lua:763` and `:1414` for targeted re-applies that must not rebuild the whole roster. `HasReadyCheckHoldInRoster` is also preserved as an `RI.HasReadyCheckHoldInRoster` export. The underlying state layer — per-unit `readyCheckReadyUntil` / `readyCheckDeclinedUntil` maps, the global `ctx.readyCheckHoldUntil` anchor and the `C_Timer.After`-based `ScheduleReadyCheckHoldClear` sweeper in `logic/isiLive_event_handlers_challenge.lua` — is untouched; the sweeper still triggers `RefreshReadyCheckUI` when the hold window elapses.
  - Side effect beyond the bug fix: render cost drops during the hold window because `BuildRowDisplayData`, `ApplyRowSpecDisplay` and `ApplyRowNameDisplay` no longer run twice per row per render.

- **Tests:**
  - 723 / 723 use-case scenarios pass. No test changes — the existing roster-render scenarios already exercised the single-pass contract.

## 2026-04-20 - Version 0.9.176 (patch)

- **Addon-message sync routed through ChatThrottleLib v24 with per-message priority:**
  - Embedded Mikk's Public Domain `ChatThrottleLib` (v24, ~534 lines) as `libs/ChatThrottleLib/ChatThrottleLib.lua` and loaded it as the first file in `isiLive.toc` so every sync send benefits from shared burst budgeting, CPS throttling and WoW's own congestion backpressure. WoW's addon-message pipe is a shared per-client bandwidth resource — hitting it raw (`C_ChatInfo.SendAddonMessage`) drops silently under contention; ChatThrottleLib queues, prioritises and redrives without loss.
  - New helper `DispatchAddonMessage(prefix, payload, channel, priority)` in `logic/isiLive_sync.lua` calls `ChatThrottleLib:SendAddonMessage(priority, prefix, text, chattype)` when the lib is loaded and falls back to raw `C_ChatInfo.SendAddonMessage` otherwise, so the addon still runs standalone if the lib ever fails to load.
  - Priority per message type reflects "speed vs. correctness" weighting: `KICK` and `REQSYNC` use `ALERT` (near-real-time — a missed kick broadcast degrades coordination during pulls); `STATS`, `DPS`, `LOC` use `BULK` (metrics can yield under load without hurting gameplay); `HELLO`, `KEY`, `TARGET`, `SHAREKEYS` and the LibKeystone party/request envelopes use `NORMAL`. All 11 send sites across the sync module were converted — no raw `C_ChatInfo.SendAddonMessage` call remains in `isiLive_sync.lua`.
  - Every send now logs its dispatch result as `sent=true|false` in the SyncLog trace, including the two LibKeystone flows (`send_libkeystone_request`, `send_libkeystone_party`) which were previously silent on failure. Drops are now visible in the debug log without needing ingame inspection of the chat pipe.
  - `.luacheckrc` split the `libs/` exclude into separate `/` and `\\` patterns so luacheck's Lua pattern matcher correctly skips the vendored lib on both Windows and Linux CI runners (char-class `[/\\]` is invalid in Lua patterns and triggered the `"Invalid pattern '^[]"` crash on first commit). Added `ChatThrottleLib` as a `read_globals` entry. The vendored lib file carries a `---@diagnostic disable` header so Sumneko Lua-LS doesn't surface inject-field hints on Blizzard / WoW API references in VS Code.

- **Tests:**
  - Added `RegisterChatThrottleLibRoutingTests` in `testmodul/isilive_test_scenarios_sync.lua` with two scenarios: one stubs `ChatThrottleLib` with a capturing mock and asserts the priority routing for all eight synchronous sends (`KICK=ALERT`, `REQSYNC=ALERT`, `STATS=BULK`, `DPS=BULK`, `LOC=BULK`, `KEY=NORMAL`, `TARGET=NORMAL`, `HELLO=NORMAL`); the other omits `ChatThrottleLib` entirely and asserts the raw `C_ChatInfo.SendAddonMessage` fallback path still dispatches with the `KICK:` payload and `ISILIVE` prefix.
  - Existing `send_reqsync` trace-log scenario was updated to expect the new `sent=%s` suffix.
  - 723 / 723 use-case scenarios pass.

## 2026-04-19 - Version 0.9.175 (patch)

- **BR/Lust announce: self-cast only, broadcast to group chat (fixes 6102x "table index is secret" spam in M+):**
  - Root cause: WoW 12.0.0's Secret Values system masks the `spellID` parameter of `UNIT_SPELLCAST_SUCCEEDED` for *other players'* casts inside M+ / boss combat-restriction zones. `type(spellID) == "number"` still returns true (Secrets masquerade as numbers), but the table lookup `BR_SPELL_IDS[spellID]` throws `"table index is secret"`. In a single live key this fired thousands of times.
  - `game/isiLive_combat_events.lua` `HandleUnitSpellcastSucceeded` now hard-filters on `unit == "player"` *before* any spellID inspection. The caster's own spellID is not Secret in their own context, so the table lookup is safe. Each isiLive client detects exactly its own cast — N isiLive users in a group cover all N casters automatically, no peer-sync needed.
  - Switched the announcement output from local `print` to `SendChatMessage` so the whole group (including non-isiLive members) sees the line. New `DefaultSendChat` resolves the channel via `IsInGroup(LE_PARTY_CATEGORY_INSTANCE)` → `INSTANCE_CHAT`, else `IsInRaid()` → `RAID`, else `IsInGroup()` → `PARTY`. Solo = no-op. The send is wrapped in `pcall` so a failed broadcast never throws.
  - The `IsGroupUnit` helper was removed (party/raid units are now rejected by the simpler `unit == "player"` check).
  - `factory/isiLive_factory_controllers.lua` no longer passes `print = ctx.Print` to `CombatEvents.SetDependencies` — the module's internal `DefaultSendChat` handles broadcast directly.
  - Locale templates (`COMBAT_CHAT_BR_USED`, `COMBAT_CHAT_LUST_STARTED`) and dedup behavior (3 s window, `Reset()` on `CHALLENGE_MODE_START` / `CHALLENGE_MODE_COMPLETED`) are unchanged.

- **Tests:**
  - Rewrote `testmodul/isilive_test_scenarios_combat_events.lua` for the self-cast contract: all BR / Lust scenarios drive `HandleUnitSpellcastSucceeded("player", ...)`, the BuildController `print` field was renamed to `sendChat` and the `prints` capture array to `messages`. The former "non-group units" test was extended to also cover `party1` and `raid3` and re-purposed as "ignores casts from units other than the player", documenting the self-cast-only invariant.
  - 721 / 721 use-case scenarios pass.

## 2026-04-19 - Version 0.9.174 (patch)

- **Chat announcements for Battle Res and Bloodlust in Mythic+:**
  - New module `game/isiLive_combat_events.lua` listens on `COMBAT_LOG_EVENT_UNFILTERED` while `C_ChallengeMode.GetActiveChallengeMapID()` reports an active key. `SPELL_RESURRECT` entries whose `spellID` matches the four battle-res spells (`20484` Rebirth, `61999` Raise Ally, `391054` Intercession, `20707` Soulstone Resurrection) produce a single chat line via the addon's `Print` helper, formatted with the localized `COMBAT_CHAT_BR_USED` template (e.g. `"Alice hat BR auf Bob benutzt"`). `SPELL_CAST_SUCCESS` entries whose `spellID` matches the twelve Bloodlust/Heroism/Time Warp/Drum/Pet variants (`2825`, `32182`, `80353`, `264667`, `390386`, `381301`, `178207`, `230935`, `256740`, `292463`, `90355`, `160452`) produce a single chat line via the `COMBAT_CHAT_LUST_STARTED` template. A 3-second dedup window keyed by `sourceGUID|spellID` swallows double-fires from the combat log; `CHALLENGE_MODE_START` / `CHALLENGE_MODE_COMPLETED` reset it so back-to-back keys do not inherit stale state.
  - Both announcements default to enabled and are individually toggleable in the Blizzard settings panel. `ui/isiLive_settings.lua` grows a dedicated **Chat Announcements** section between Sounds and Debug with two checkboxes (`chatAnnounceBR`, `chatAnnounceLust`), using the default-true idiom `db.chatAnnounceBR ~= false` so fresh installs light up both lines without touching the saved variables.
  - Realm suffixes are stripped for the local-realm case so the chat line reads `"Alice used BR on Bob"` instead of `"Alice-Realm used BR on Bob-Realm"`. Cross-realm names keep the realm segment when the combat log provides one.
  - Factory wiring in `factory/isiLive_factory_controllers.lua` calls `CombatEvents.SetDependencies({ getL = ctx.GetL, getDB = function() return IsiLiveDB or {} end, print = ctx.Print })` right after the LFGDetect block so the module picks up the addon's chat-prefix/print and localized templates.
  - Locale: added `SETTINGS_SECTION_CHAT`, `SETTINGS_SECTION_CHAT_HINT`, `SETTINGS_CHAT_BR_ANNOUNCE`, `SETTINGS_CHAT_LUST_ANNOUNCE`, `COMBAT_CHAT_BR_USED` (format `%s ... %s`) and `COMBAT_CHAT_LUST_STARTED` (format `%s`) to all eight language tables in `locale/isiLive_texts.lua`.

- **Tests:**
  - Added `testmodul/isilive_test_scenarios_combat_events.lua` with ten scenarios covering auto-registration of the three combat events, BR announcement in key, BR suppression outside key, BR gated by `chatAnnounceBR`, BR dedup inside the 3 s window with post-window re-fire, non-BR resurrect spells ignored, Bloodlust announced in key, Sated/Exhaustion aura IDs ignored (not in the cast-ID set), Lust gated by `chatAnnounceLust`, and `Reset()` clearing the dedup map so the same cast fires again.
  - Updated the checkbox count in `testmodul/isilive_test_scenarios_ui_settings.lua` from 20 to 22 to account for the two new chat-announce toggles.

## 2026-04-19 - Version 0.9.173 (patch)

- **Disambiguate active-key owner via LFG leader hint:**
  - Previously `ResolveActiveKeyOwnerUnit` in `logic/isiLive_keysync.lua` fell back to `nil` whenever more than one roster member held a keystone for the same `mapID`. That blocked both the chat announcement (`"Ziel-Dungeon: <name> +<level>"`) and the red highlight on the key owner's row in the roster panel for an ambiguous group.
  - `game/isiLive_lfg_detect.lua` now captures `info.leaderName` from `C_LFGList.GetSearchResultInfo` when an invite is seen (stored in `pendingInvites[searchResultID]`) and promotes it to a new module-level `activeInviteLeader` state on `inviteaccepted`. A new public accessor `LFGDetect.GetActiveInviteLeader()` exposes the value. `ClearDetectedState`/`ClearAllStateImpl` drop it alongside the detected mapID.
  - `logic/isiLive_keysync.lua` gained two helpers: `SplitNameRealm` parses the Blizzard LFG name form (`"Name"` or `"Name-Realm"`) and `FindRosterUnitByHint` matches it against the roster (realm is optional — Blizzard omits it when it matches the local realm). `ResolveActiveKeyOwnerUnit` now takes an optional third `preferredOwnerName` parameter: when the hinted roster unit holds a key for `targetMapID`, that unit wins over the ambiguity guard. When the hinted unit is in the roster but does not expose a matching `keyMapID` (e.g. the leader has no isiLive / LibKeystone sync), the function fails closed and returns `nil` — it must not silently fall back to another member's key for the same dungeon. Only when the hint resolves to no roster entry at all (e.g. boost runs where the applicant is not the key owner) does the unique-owner fallback run.
  - `factory/isiLive_factory_controllers.lua` wires the hint through both call sites — `ctx.ResolveActiveKeyOwnerUnit` and the direct `ctx.keySyncController.ResolveActiveKeyOwnerUnit` call inside `SendOwnTargetSnapshot` now fetch `addonTable.LFGDetect.GetActiveInviteLeader()` and forward it to the controller.
  - Net effect: after accepting an LFG invite for an M+ key, the chat announcement carries the leader's keystone level and the roster row's key text renders red for the exact leader we joined — even if another group member happens to carry a key for the same dungeon.

- **Teleport active-target highlight is now a calm hatched border instead of a goldish blink:**
  - Removed the `Interface\\SpellActivationOverlay\\IconAlert` glow texture (`button.activeGlow`) and the bouncing 1.2× scale animation that pulsed the whole teleport button. The goldish blinking was visually loud and distracting.
  - Replaced the solid goldish action-button border (`UI-ActionButton-Border`, vertex color `1, 0.85, 0.1`) with a container frame that hosts short dashed segments along all four edges, rendered from `Interface\\Buttons\\WHITE8X8` in a cool blue-white (`0.55, 0.85, 1.0, 0.95`) with additive blending. Dash length, gap, and edge counts are recomputed from the button size on `OnSizeChanged`, so the hatch stays consistent across layout modes.
  - The active-target overlay tint changed from a strong orange (`1, 0.5, 0.0, 0.5`) to a subtle cool blue (`0.15, 0.35, 0.55, 0.25`) so the icon itself stays readable.
  - The animation group now targets the new hatched border (no scale, no glow) and runs a single slow alpha pulse (0.55 → 1.0, 1.2 s BOUNCE), so the border breathes gently instead of blinking. `button:SetScale(1)` resets around the former scale animation are gone since no scaling happens anymore.

- **Tests:**
  - Added five `ResolveActiveKeyOwnerUnit` scenarios in `testmodul/isilive_test_scenarios_keysync.lua` covering bare-name hint disambiguation, realm-qualified hint selection, fail-closed when the hinted leader holds a different mapID, fail-closed when the hinted leader has no synced key at all, and hint ignored when unknown so the unique-owner resolution still fires.
  - Added three `GetActiveInviteLeader` scenarios in `testmodul/isilive_test_scenarios_lfg_detect.lua`: leader captured on `inviteaccepted` with a Blizzard-style `Name-Realm`, no leader surfaced for own-queue `detectedMapID`, and `ClearAllState` drops the hint.

## 2026-04-19 - Version 0.9.172 (patch)

- **LFG chat noise reduced — only the key-level announcement remains:**
  - Removed the two redundant chat prints that fired on the LFG detection path: `"LFG-Einladung erkannt: <dungeon>"` (`OnInviteAccepted` and the delayed `GROUP_ROSTER_UPDATE` fallback) and `"LFG-Eintrag erkannt: <dungeon>"` (own/group listing via `CheckActiveGroup`) in `game/isiLive_lfg_detect.lua`.
  - Rationale: isiLive is a Mythic+ tool; the status-panel announcement `"Ziel-Dungeon: <dungeon> +<level>"` (from `MaybeAnnounceTargetDungeonChat` in `ui/isiLive_status.lua`) already covers the only scenario where a chat line carries new information — a key-tied group context. For non-M+ LFG (Heroic/Normal Dungeon Finder) no chat line is emitted anymore; highlight and status panel are unaffected.
  - Cleanup: removed the now-unused `localeGetter`/`SetLocaleGetter` plumbing in `game/isiLive_lfg_detect.lua`, the matching `SetLocaleGetter` wiring in `factory/isiLive_factory_controllers.lua`, the unused `Print`/`GetDungeonName` helpers, and the `LFG_DETECT_INVITE` / `LFG_DETECT_QUEUE` locale keys across all 8 language tables in `locale/isiLive_texts.lua`.

- **Tests:**
  - Removed the now-obsolete `"LFGDetect uses injected locale getter for chat message"` and `"LFGDetect own listing chat dedup prints once for same mapID"` scenarios from `testmodul/isilive_test_scenarios_lfg_detect.lua`; renamed the remaining test group function from `RegisterLFGDetectResetAndLocaleTests` to `RegisterLFGDetectResetTests`.
  - Dropped the `SetLocaleGetter = function() end` stubs from `isilive_test_scenarios_factory_highlight_priority.lua`, `isilive_test_scenarios_factory_primary_part1.lua`, and `isilive_test_scenarios_factory_primary_part2.lua`.
  - Updated rule `RULE-TARGET-DUNGEON-CHAT-DEDUP` in `docs/RULES_LOGIC.md` to drop the removed LFG-print test from the required-tests list; the status target-dungeon dedup test remains.

## 2026-04-19 - Version 0.9.171 (patch)

- **LFG invite highlight no longer drops before the roster settles:**
  - Root cause: after `LFG_LIST_APPLICATION_STATUS_UPDATED=inviteaccepted` the player's own LFG application briefly stays visible in `C_LFGList.GetActiveEntryInfo` (so `CheckActiveGroup` promotes the map to `lastQueueMapID`), and a second `LFG_LIST_ACTIVE_ENTRY_UPDATE` immediately drops it. `GROUP_ROSTER_UPDATE` arrives ~300ms later, so `IsInGroup()` was still returning `false` in that window and `ClearDetectedState` wiped `detectedMapID` before the roster could settle.
  - Fix: `CheckActiveGroup` skips `ClearDetectedState` while `pendingAcceptedInviteMapID ~= nil` so the invite-set highlight survives the own-listing drop until `GROUP_ROSTER_UPDATE` promotes the group and clears the guard flag.
  - Net effect: after accepting an LFG invite, the teleport button for the matching dungeon stays highlighted without a visible flicker-off.

- **deDE dungeon name:**
  - Corrected `Windlaeuferturm` to `Windläuferturm` for mapID 557 in `game/isiLive_season_data.lua` (and the matching baseline test in `testmodul/isilive_test_scenarios_teleport.lua`).

- **Tests:**
  - Added regression test `"Highlight invite-accepted state survives own-listing drop before GROUP_ROSTER_UPDATE settles"` in `testmodul/isilive_test_scenarios_lfg_detect.lua` that reproduces the race: it fires `invited` → `inviteaccepted` → `LFG_LIST_ACTIVE_ENTRY_UPDATE` (entry present) → `LFG_LIST_ACTIVE_ENTRY_UPDATE` (entry dropped, still not in group) → `GROUP_ROSTER_UPDATE` (in group) and asserts `detectedMapID` stays at 557 throughout.

## 2026-04-18 - Version 0.9.170 (patch)

- **Factory load-order guard:**
  - Added `isiLive_factory_kick_tracker.lua` and `isiLive_factory_minimap.lua` to `IMPLICIT_DEPENDENCIES["isiLive_factory.lua"]`, and `isiLive_factory_kick_tracker.lua` to `IMPLICIT_DEPENDENCIES["isiLive_factory_controllers.lua"]`, so tests that load either umbrella file automatically pull in the split submodules at runtime.
  - Reordered `isiLive.toc` so `factory_kick_tracker.lua` loads before `factory_controllers.lua`, matching the runtime call direction (controllers invokes `FI.InitializeFactorySecondaryKickTracker`).
  - Added three architecture tests (`RegisterArchitectureLoadOrderTests` in `testmodul/isilive_test_scenarios_architecture.lua`) that verify every `IMPLICIT_DEPENDENCIES` key/value is listed in `isiLive.toc`, that each dependency appears before its dependent in load order, and that both sides are registered in the harness `FILE_PATHS` — regression guard for future splits.

- **UI scenario split:**
  - `testmodul/isilive_test_scenarios_ui.lua` was sitting at 3139/3200 lines (61 below the hard file cap). Extracted the ~430 lines of WoW frame stub helpers (`CreateTextureStub`, `CreateFontStringStub`, `CreateAnimationGroupStub`, `ApplyFrameMethods`, `BuildCreateFrameStub`, `FindCombatRetryFrame`, `RequireValue`) into the new `testmodul/isilive_test_ui_helpers.lua` module, loaded via `loadfile` from any scenario that needs them.
  - Moved the five SettingsPanel test groups (`RegisterSettingsPanelResetActionTests`, `RegisterSettingsPanelTests`, `RegisterSettingsPanelBehaviorTests`, `RegisterSettingsPanelAdvancedTests`, `RegisterSettingsPanelSoundAndLegacyTests`) into the new sibling file `testmodul/isilive_test_scenarios_ui_settings.lua` and registered it in `tools/usecase_scenarios.lua`.
  - Both scenario files now sit under 1400 lines, leaving comfortable headroom for new tests, and the helpers are reusable if more UI scenario files are added in the future.

- **Roster-Panel refactor (Phase 1):**
  - Extracted CdTracker row creation/update (`CreateCdTrackerRow`, `UpdateCdTrackerRow`) into `ui/isiLive_roster_panel_cd_row.lua`.
  - Extracted KillTrack row creation/update (`CreateKillTrackRow`, `UpdateKillTrackRow`) into `ui/isiLive_roster_panel_kill_row.lua`.
  - Moved shared font helpers (`ApplyFontStringSize`, `FormatMplusTime`, `SetFontStringTextColorSafe`) into `ui/isiLive_roster_panel_helpers.lua`, exposed via the existing `_RosterInternal` namespace.
  - `ui/isiLive_roster_panel.lua` shrinks from 2661 to 2085 lines; load order, test harness `FILE_PATHS` / `IMPLICIT_DEPENDENCIES`, and the architecture tests are kept in sync with the new modules.
  - Net effect: row rendering is isolated from the main panel controller, the main file stays well under the file cap, and all 704 usecase tests continue to pass.

- **Roster-Panel refactor (Phase 2):**
  - Extracted panel chrome (`CreateFlatButton`, `CreatePanelHeaders`, `CreateM2ColumnGuides`, `AttachPanelButtonTooltip`, `AttachModeButtonTooltip`, `CreateTankHelperButtons`) and the shared column position/width constants into a new `ui/isiLive_roster_panel_chrome.lua`.
  - The column constants (`SPEC_COL_X`, `NAME_COL_X`, …, `KICK_COL_WIDTH`) are now published via `_RosterInternal`; `roster_panel.lua` imports them instead of keeping a parallel copy, so header layout and row rendering stay aligned by construction.
  - `CreateShareKeysButton` and `CreatePanelButtons` stay in `roster_panel.lua` because they are tightly coupled to the keystone announce helpers.
  - `ui/isiLive_roster_panel.lua` shrinks further from 2085 to 1698 lines; load order, test harness, and architecture tests updated accordingly. All 704 usecase tests still pass.

- **Roster-Panel refactor (Phase 3):**
  - Extracted the row builder (`CreateMemberRow`) and the entire roster render pipeline (`RenderRosterImpl`, `RefreshReadyCheckStateImpl`, `BuildRowDisplayData`, `IsEntryAtTargetDungeon`, `ApplyRowNameDisplay`, `ApplyRowSpecDisplay`, `ApplyRowReadyCheckDisplay`, `HasReadyCheckHoldInRoster`, `ResolveReadyCheckActive`, `SetKickCellText`) into the new `ui/isiLive_roster_panel_render.lua` and exposed them through `_RosterInternal`.
  - `RosterPanel.SetTraceLogger` now also publishes the trace logger via `_RosterInternal._rosterPanelLogger` so the split render module can emit `RosterPanel:`-prefixed traces without sharing an upvalue.
  - Removed the now-orphan tooltip / column-constant / layout-helper imports from `roster_panel.lua` to keep the file free of dead locals; the controller methods reach the render and kick-cell helpers through small `RI` shims.
  - `ui/isiLive_roster_panel.lua` shrinks further from 1698 to 1039 lines; the new render module sits at 715 lines (well below the 3200-line file cap, with `RenderRosterImpl` at ~299 lines below the 420-line function cap). The architecture kick-column test now reads the kick-ready marker from the render module.
  - All 704 usecase tests continue to pass.

- **CI hygiene:**
  - Collapsed accidental double blank lines introduced by the recent scenario/UI splits to satisfy `stylua --check`.
  - Imported `CD_TRACKER_ROW_HEIGHT` into the new kill-row module and removed the now-unused `CD_TRACKER_ROW_BOTTOM_OFFSET` upvalue from `ui/isiLive_roster_panel.lua` to clear `luacheck` warnings.
  - Added `---@diagnostic disable: undefined-global` to `isilive_test_scenarios_ui.lua`, `isilive_test_scenarios_ui_settings.lua` and `tools/check_locale_drift.lua` so the Lua language server stops flagging `loadfile` / `io` / `os` in files that run under the real Lua stdlib.

## 2026-04-18 - Version 0.9.169 (patch)

- **Share-keys chat announcement fixed end-to-end:**
  - Root cause 1: WoW silently drops addon-sent chat messages that wrap square brackets in `|cffXXXXXX...|r` color codes (server-side fake-item-link filter). The plain-text keystone fallback no longer emits a color code.
  - Root cause 2: `C_MythicPlus.GetOwnedKeystoneLink` was removed in current WoW retail. `BuildKeystoneChatLink` now falls back to a bag scan for item `180653` and uses `C_Container.GetContainerItemLink` to obtain a real, server-accepted keystone link.
  - Net effect: the "Keys teilen" button now posts a clickable keystone link to party chat that group members actually see.

- **German locale:**
  - Replaced `Schluessel` with `Key` / `Keys` across keystone-related UI strings (`COL_KEY`, `BTN_SHARE_KEYS`, `TOOLTIP_ANNOUNCE_KEYS`, `TOOLTIP_SYNC_DEBUG_KEY`, `ANNOUNCE_PREFIX`, `TESTALL_DUMMY_GROUP`). The Blizzard item name "Persönlicher Schlüssel zur Arkantine" stays unchanged.

- **Cleanup:**
  - Removed temporary share-keys diagnostic traces that were only needed to locate the chat-filter and API-removal root causes.

## 2026-04-17 - Version 0.9.168 (patch)

- **Runtime-log noise reduction:**
  - `[SYNC] send_key_blocked` (unchanged / cooldown) moved to Deep-level: redundant same-tick key-send guards no longer spam the normal log. New `Sync.SetDeepTraceLogger` wires `runtimeLogController.TraceDeep`.
  - `[SYNC] message_applied` now logs at Normal level only when at least one flag (`key/stats/dps/loc/target/kick/ack/reqsync`) is true; all-false applies (pure duplicate peer traffic) go to Deep.
  - `[TP] update_button_called` with `soundContext=nil` moved to Deep; explicit trigger contexts (`queue`, `invite`, …) remain on Normal.
  - `[STATE] check_entered_target_dungeon` now logs on Normal only when `match=true`; `match=false` polls go to Deep.
  - `[INSPECT] enqueue` stays on Normal only when `forceRefresh=true`; routine post-roster re-enqueues go to Deep. New inspect-controller option `logRuntimeTracefDeep`.
  - `[LFG] group_roster_update` deduped against its previous signature (inGroup/members/pendingAccept); identical repeats go to Deep. New `LFGDetect.SetDeepTraceLogger`.
  - `[LFG_GROUP5]` trace deduped against its previous signature (event/inGroup/members/detected_before/detected_after/pendingAccept/latestQueueMap/localTargetMapID/resolvedSpell); identical repeats go to Deep.
  - These changes shorten observed group-run logs by roughly half without removing any information — Deep level (`/isilive log level deep`) surfaces every suppressed entry again for debugging.

- **Documentation / release sync:**
  - Synced `isiLive.toc`, `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `CHANGELOG_RELEASE.md` to `0.9.168`.

## 2026-04-17 - Version 0.9.167 (patch)

- **Runtime log expansion:**
  - Added deterministic runtime-log trace coverage for ready-check events when logging is enabled.
  - Added deterministic factory coverage for LFG group-settle diagnostics written into the runtime log.
  - Split the oversized factory-primary and ready-check test blocks into smaller helpers so the new trace coverage stays within the metric limits.
  - Added lazy runtime-log formatting via `Logf`, lazy trace builders via `Trace`, and a ring-buffer-backed log store so disabled logging avoids expensive message construction and active logging avoids per-entry array shifting after the cap is reached.
  - Added stable runtime-log sequence numbers, precise `GetTime`-based timestamps, and normalized `[TAG] event=<action>` formatting for trace readability.
  - Added a runtime-log session header when logging is enabled, `/isilive log level normal|deep` controls, and Deep-only trace paths for high-volume UI/teleport diagnostics.
  - Wired Sync and LFG diagnostics through lazy trace builders so runtime-log formatting stays deferred until the enabled logger actually consumes the trace.
  - Added Deep trace coverage for roster render decisions, leader-button decisions, teleport UI visibility, teleport button decisions, and high-detail teleport resolution flow.
  - Extended the rule validator so split scenario files referenced via `dofile` and `require` are indexed from the scenario manifest.
  - Added deterministic 2,000-entry burst coverage for runtime-log, Sync, and Group/Roster trace paths to prove capped storage and stable tail order.

- **Documentation / release sync:**
  - Synced `isiLive.toc` and `CHANGELOG_RELEASE.md` to `0.9.167`.
  - Updated the documented validator baseline to `619` scenarios / `619` indexed tests over `45` modules.

## 2026-04-16 - Version 0.9.166 (fix)

- **ReadyCheck hold:** `CHALLENGE_MODE_START` no longer calls `ResetReadyCheckDeclinedTracking` — the 20-second ready/declined hold state now persists when the key starts immediately after a ready check instead of being wiped.
- **Share Keys:** Fixed `sendOwnKeystoneToChat` in `isiLive_controller_wiring.lua` using `ctx.GetRoster`, `ctx.GetOwnedKeystoneSnapshot`, and `ctx.GetL` (capital G) — these keys do not exist on the runtime-setup dict; corrected to `ctx.getRoster`, `ctx.getOwnedKeystoneSnapshot`, and `ctx.getL`. Remote clients now post their keystone to party chat when a SHAREKEYS request is received. This was a regression introduced in v0.9.119.
- **Dungeon name locale:** `GetDungeonName` in `isiLive_lfg_detect.lua` now passes the active locale tag (`IsiLiveDB.locale` or `GetLocale()` fallback) to `SeasonData.GetDungeonName`, fixing the English-only dungeon name in LFG detect chat output.
- **LFG highlight reliability:** `MapIDFromActivityID` now falls back to `C_LFGList.GetActivityInfoTable` (pcall-protected) when an activity ID is not in the static `ACTIVITY_TO_MAP` table. The resolved mapID is cached for subsequent calls, fixing unreliable dungeon detection for dungeons whose activity IDs differ from the static entries.

## 2026-04-15 - Version 0.9.165 (patch)

- **Hidden sync test coverage:**
  - Added deterministic coverage for hidden addon sync pre-rendering, hidden refresh replies, hidden LibKeystone replies, real sync parsing while hidden, and sparse hidden background snapshots.
  - The new scenarios cover `Event handlers pre-render UI for hidden addon sync updates`, `Event handlers answer refresh requests while frame is hidden`, `Event handlers answer LibKeystone requests while frame is hidden`, `Event handlers process LibKeystone requests through the real sync parser and refresh hidden state`, `Event handlers process KEY through the real sync parser and apply roster key data`, `Event handlers process TARGET through the real sync parser and refresh target UI`, `Event handlers process STATS through the real sync parser and backfill roster stats`, `Event handlers process DPS through the real sync parser and backfill roster DPS`, `Event handlers process LOC through the real sync parser and backfill roster location`, `Event handlers answer SHAREKEYS requests while frame is hidden`, `Event handlers skip SHAREKEYS cooldown when no own key chat share was posted`, `Event handlers process SHAREKEYS through the real sync parser and trigger cooldown`, `Event handlers process REQSYNC through the real sync parser and answer hidden refreshes`, `Event handlers process KICK through the real sync parser and refresh hidden state`, `Event handlers process HELLO through the real sync parser and answer hidden onboarding`, and `Event handlers process ACK through the real sync parser and cache hello info`.

- **Documentation / release sync:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `CHANGELOG_RELEASE.md`, and `isiLive.toc` to `0.9.165`.
  - Updated the documented validator baseline to `602` scenarios / tests over `45` modules.
  - No runtime behavior changed in this bump.

## 2026-04-14 - Version 0.9.164 (patch)

- **Highlight / LFG hardening:**
  - The queue highlight resolver now ignores `C_ChallengeMode.GetActiveChallengeMapID()` before actual dungeon entry and only suppresses against the live player map, so the portal highlight no longer clears too early while the player is still outside.
  - Added deterministic coverage for the pre-entry queue highlight path and the late-roster false-negative invite-confirmation path.

- **Documentation / release sync:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `CHANGELOG_RELEASE.md`, and `isiLive.toc` to `0.9.164`.
  - Updated the documented validator baseline to `581` scenarios / tests over `43` modules.

## 2026-04-14 - Version 0.9.163 (patch)

- **Documentation / release sync:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `CHANGELOG_RELEASE.md`, and `isiLive.toc` to `0.9.163`.
  - This was a pure version sync with no runtime or UI behavior change.
  - No new deterministic test scenarios were added in this bump.
  - Updated the documented validator baseline to `579` scenarios / tests over `43` modules.

## 2026-04-14 - Version 0.9.162 (patch)
- **Share Keys no-op cooldown fix:**
  - Fixed the Share Keys button so the 30-second local cooldown starts only after a real effect happened: either the local key was announced or a `SHAREKEYS` addon sync request was successfully published.
  - `Sync.SendShareKeysRequest()` now returns an explicit success state instead of failing silently, which lets the roster UI keep the button usable when no addon sync channel exists.
  - Added deterministic coverage for the live `SendChatMessage` path, the no-op click path without chat or sync success, and the explicit sync-request failure contract.

- **Documentation / release sync:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `CHANGELOG_RELEASE.md`, and `isiLive.toc` to `0.9.162`.
  - Updated the documented validator baseline to `577` scenarios / tests over `42` modules.

## 2026-04-14 - Version 0.9.161 (patch)

- **Kick tracker matrix and cooldown hardening:**
  - Added deterministic interrupt coverage for the full mapped spec matrix, including the exact no-kick specs, so every supported class/spec path is now exercised explicitly instead of relying on a handful of spot checks.
  - Fixed kick cooldown reduction scanning to walk all active talent trees instead of only the first tree, so reduced interrupt cooldowns are recognized and synced even when the reduction lives on another class/spec tree.
  - Added deterministic coverage for the multi-tree cooldown-reduction path to prevent future regressions in interrupt remain sync.

- **Documentation / release sync:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `CHANGELOG_RELEASE.md`, and `isiLive.toc` to `0.9.161`.
  - Updated the documented validator baseline to `574` scenarios / tests over `42` modules.

## 2026-04-14 - Version 0.9.160 (patch)

- **Sync version fallback fix:**
  - `ACK` sync messages now persist the peer addon version as hello metadata, so the roster hover can still show the client version even when no full `HELLO` was observed beforehand.
  - Hidden clients now keep sending their `HELLO` inside group sync, so version visibility no longer depends on whether the peer had the UI frame visible.
  - Deterministic coverage now locks in the `ACK` parsing path, the hidden `HELLO` path, and tooltip version rendering from `ACK`-only hello info.

- **Documentation / release sync:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `CHANGELOG_RELEASE.md`, and `isiLive.toc` to `0.9.160`.
  - Updated the documented validator baseline to `571` scenarios / tests over `42` modules.

## 2026-04-14 - Version 0.9.159 (patch)

- **Highlight priority hardening:**
  - LFG-detected mapID now outranks peer-synced highlight resolution, so an accepted invite or own listing keeps the portal target aligned with the concrete LFG context instead of a stale synced target.
  - Added deterministic coverage for the priority path in a dedicated factory highlight scenario module.

- **Documentation / release sync:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `CHANGELOG_RELEASE.md`, and `isiLive.toc` to `0.9.159`.
  - Updated the documented validator baseline to `568` scenarios / tests over `42` modules.

## 2026-04-13 - Version 0.9.158 (patch)

- **Version bump:**
  - The addon metadata, release stub, architecture baseline, and usecase baseline were aligned to `0.9.158`.

## 2026-04-13 - Version 0.9.157 (patch)

- **Arkantine shortcut localization fix:**
  - The ESC-menu Arkantine shortcut now uses the exact localized German item name again, so the secure `/use` macro resolves on deDE clients.
  - Added regression coverage for the Arkantine shortcut macro text to prevent transliteration regressions.

## 2026-04-13 - Version 0.9.156 (patch)

- **Shared teleport refresh wiring fix:**
  - Teleport column refreshes now route through the shared highlight updater instead of bypassing the LFG-aware path with a naked teleport-button refresh.
  - Added deterministic architecture coverage so the factory keeps the teleport refresh on the shared highlight path.

## 2026-04-13 - Version 0.9.155 (patch)

- **LFG highlight visibility fix:**
  - LFG-driven teleport updates now auto-open the main frame once when a concrete resolved teleport target exists, so invite/listing highlights remain visible instead of only updating a hidden UI.
  - The auto-open only applies to invite/queue highlight updates, preserves the existing sound suppression, and stays gated by the normal frame visibility / combat rules.
  - Added regression coverage for the hidden-frame invite highlight path.

## 2026-04-13 - Version 0.9.154 (patch)

- **Late-wire LFG highlight hardening:**
  - `LFGDetect.SetHighlightCallback()` now replays the current resolved highlight state once when the callback is wired after `detectedMapID` already exists, so the teleport UI cannot miss a valid invite/listing highlight because of callback ordering.
  - Added deterministic coverage for the late-wire replay path so the visible portal state stays in sync even when the callback registration happens after the LFG confirmation event.

- **Ready-check roster render fix:**
  - `isiLive_roster_panel.lua` now resolves ready-check activity safely when the runtime provides either a boolean or a function, instead of calling a boolean like a callback.
  - The roster panel controller preserves boolean ready-check state and the regression coverage now locks in the non-crashing boolean path.

## 2026-04-13 - Version 0.9.153 (patch)

- **No-guess LFG hardening:**
  - Removed dungeon-name and token-based fallback resolution from `isiLive_lfg_detect.lua` so invite and listing detection now stays unresolved unless exact activity data is available.
  - Moved invite state to a pending-confirmation flow and kept the portal highlight/sound dispatch deterministic on the exact confirmation path.
  - Updated the deterministic LFG coverage and rule-to-test mapping to enforce the fail-closed no-guess contract.

## 2026-04-13 - Version 0.9.152 (patch)

- **LFG invite highlight fix:**
  - Incoming LFG invites now stay pending until the exact activity data is confirmed; the matching portal icon highlights on `inviteaccepted` instead of guessing from dungeon names.
  - Portal sounds are suppressed for invite-driven and queue-driven target refreshes; the sound remains reserved for actual active-target changes.
  - Updated the deterministic LFG and TeleportUI coverage to lock in the invite-silent highlight path and the fail-closed no-guess flow.
  - Updated the validator baseline references to `559` scenarios / tests over `40` modules.

## 2026-04-13 - Version 0.9.151 (patch)

- **LFG detection hardening:**
  - Injected the highlight callback and locale getter into `isiLive_lfg_detect.lua` so the game-layer module no longer needs direct `_factoryCtx` access or hardcoded chat strings.
  - Normalized invite/listing status handling, preserved pending invites across the active-entry ticker race, and cleared the full LFG state on group leave or `CHALLENGE_MODE_START`.
  - Added deterministic `LFGDetect` scenario coverage and registered the new module in the usecase harness.

- **Documentation / release sync:**
  - Synced `README.md`, `ARCHITECTURE.md`, and `USECASES.md` to the current runtime state.
  - Updated the validator baseline references to `556` scenarios / tests over `40` modules.

- **Locale and UI text cleanup:**
  - Standardized the German UI copy for clearer terminology while keeping established add-on labels such as `M+`, `Lead`, `UI`, and `SavedVariables` intact.
  - Transliterated locale strings with in-game rendering issues to ASCII across `deDE`, `frFR`, `esES`, `ptBR`, `itIT`, `ruRU`, and `trTR`.
  - Kept the deterministic validation green after the text-only changes (`lua tools/validate_usecases.lua`: `557 passed, 0 failed`).

- **Workflow formatting fix:**
  - Normalized the touched Lua files to Unix line endings and re-ran the local CI preflight so the GitHub Actions `Lua Check` workflow no longer fails on `StyLua`.
  - Verified the full local gate again after the formatter pass (`tools/validate_ci_local.ps1` passed, along with `lua tools/validate_usecases.lua`).

## 2026-04-12 - Version 0.9.151 (patch)

- **Sound settings and settings refresh:**
  - Moved the built-in sound toggles into a dedicated `Sounds` section in Blizzard Settings and added the portal-ready toggle alongside lead transfer and group join.
  - Centralized the three built-in sounds through the shared sound registry so enable-state resolution stays deterministic and switchable from one source of truth.
  - Refreshed the Settings page with a short intro and per-section hint lines so the layout reads more clearly and is easier to scan.

- **Documentation / release sync:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `isiLive.toc` to version `0.9.151`.
  - Kept the validator baseline aligned with the current deterministic scenario count.

## 2026-04-12 - Version 0.9.150 (patch)

- **Main-frame lock and tooltip localization:**
  - Added a top-right lock toggle in the main UI to prevent accidental dragging, backed by the `Lock main frame position` Blizzard setting.
  - Added `/isilive lock` and `/isilive unlock` as direct slash-command controls for the same saved lock state.
  - Added `/isilive resetui` to recenter the main window and restore UI scale / background opacity defaults when it is dragged off-screen.
  - The Settings button for `/isilive resetui` now shows the default values as a separate hint line and asks for confirmation before applying the reset.
  - Added localized tooltips for the main close button and lock button, including the CTRL+F9 reopen hint on the close button.
- **Documentation / release sync:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `RELEASE.md` to the current UI and validator baseline state.
  - Updated the local validator baseline references to `536` scenarios / tests over `39` modules.

## 2026-04-11 - Version 0.9.149 (patch)

- **LFG dungeon detection fix (`isiLive_lfg_detect.lua`):**
  - `GROUP_ROSTER_UPDATE` handler rewritten after LFGTeleportButtonMidnight: when not in any group → clear state and return; when in group and `detectedMapID` is nil → apply pending invite or call `CheckActiveGroup()`. Fixes the race condition where the event fired while the LFG group was still assembling, causing a false `ClearDetectedState()` that wiped the highlight immediately after it was set.
  - `Norm()` now strips non-alphanumeric characters (except `'` and whitespace) before keyword matching, matching LFGTeleportButtonMidnight's approach and guarding against broken multibyte sequences from tainted/locale LFG API strings.
  - `IsInRaid()` added alongside `IsInGroup()` in the group-presence check, consistent with LFGTeleportButtonMidnight.

## 2026-04-11 - Version 0.9.148 (patch)

- **Readycheck render split:**
  - Normal roster refreshes now re-apply the ready-check background during the hold window instead of letting a full roster render clear it implicitly.
  - The ready-check dedicated refresh path remains the canonical place for row background, waiting marker, and hold-state reapplication.
  - Added deterministic coverage for the normal-render reapply path and the hold-expiry cleanup path.
  - The remaining verification step is now an in-game live trace for the exact event or timer that still neutralizes the background in the user's setup.

- **Documentation / release sync:**
  - Bumped `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `isiLive.toc` to `0.9.148`.
  - Updated the local validator baseline to `527` scenarios / tests.

## 2026-04-11 - Version 0.9.147 (feature)

- **LFG dungeon detection:**
  - New module `game/isiLive_lfg_detect.lua` detects which dungeon the player received an LFG group invite for, or which dungeon they queued for via their own active LFG listing.
  - Detection uses a static `activityID → mapID` map as the primary (fast) path, with API name lookup and locale-aware keyword matching as fallbacks.
  - Keyword matching supports both `enUS` and `deDE` dungeon names (including umlauts and typographic apostrophes); other locales fall through to the API name path.
  - Detected dungeon is announced in chat as `[isiLive] Invite erkannt: <name>` or `[isiLive] Queue erkannt: <name>`.
  - The corresponding portal icon in the Teleport Grid is highlighted (active border + glow animation) as long as the queue or accepted invite is active.
  - Highlight clears automatically when: the player cancels the queue, leaves the group before the key starts, the key starts (`CHALLENGE_MODE_START`), or the group dissolves (`GROUP_ROSTER_UPDATE` with `not IsInGroup()`).
  - A 5-second polling ticker (`C_Timer.NewTicker`) re-checks the active LFG listing in case events are missed.
  - Public accessor: `addonTable.LFGDetect.GetDetectedMapID()`.
  - `UpdateMPlusTeleportButton` falls back to `LFGDetect` when no active teleport spell is resolved.

- **Demo mode toggle (CTRL-ALT-F9) improved:**
  - `CTRL-ALT-F9` now toggles the demo mode on/off **without closing the visualisation** when deactivating.
  - Deactivating restores the real group state via a full roster update (`triggerGroupRosterUpdate`), including correct solo-player entry reconstruction.
  - Previously the hotkey called `ToggleStandardTestMode` which closed the frame on exit; it now calls the dedicated `ToggleDemoMode`.

- **Share Keys fallback hardened:**
  - The local Share Keys announcement keeps the keystone message clickable even when the owned-link API is unavailable.
  - The fallback still posts the dungeon short code and level, but now wraps it in a deterministic keystone hyperlink instead of plain text.

- **Leader notification suppressed on own group creation:**
  - When the local player creates a group and is immediately the leader, the "you are now leader" notification and sound no longer fire.
  - Fix: `wasGroupLeader` is pre-synced to `true` in `HandleGroupRosterUpdate` when `joinedNow == true` and `unitIsGroupLeader("player") == true`, so `PARTY_LEADER_CHANGED` sees no state change.

- **Title bar updated:**
  - `TITLE_HINT` text changed from locale-specific "Open/Close CTRL-F9" strings to the uniform label `BETA` across all 8 supported languages.
  - All three title elements (`isiLive`, version, badge) now share the same font size (14) and a common Y anchor for pixel-accurate horizontal alignment.
  - BETA badge colour: green (`0.45, 0.85, 0.45`).

- **LSP setup:**
  - `.vscode/settings.json` `Lua.workspace.library` path changed from `~\\.vscode\\…` to the fully expanded absolute path so lua-language-server resolves the `ketho.wow-api` annotations correctly on Windows.

## 2026-04-11 - Version 0.9.146 (patch)

- ESC-menu shortcut buttons: icons upgraded from static `Interface\\Icons\\*` textures to MicroMenu atlas entries (`UI-HUD-MicroMenu-*-Up`) for Professions, Talents, Achievements, Quests, Dungeons, Journal, Collections, Guild, and Housing. The Spellbook, ReloadUI, Hearthstone, and Arkantine buttons retain their existing icon paths (no matching MicroMenu atlas).
- Fixed label overlap with icon on buttons that use an atlas icon: `textOffsetX` now accounts for `iconAtlas` in addition to `iconPath`.
- `CreatePanelUIButton` accepts an `iconAtlas` parameter; when set, `SetAtlas` is used instead of `SetTexture`/`SetTexCoord`.

## 2026-04-11 - Version 0.9.145 (patch)

- Documentation sync:
  - Bumped `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, and `isiLive.toc` to `0.9.145`.
  - Updated the local validator baseline to `525` scenarios / tests.

## 2026-04-10 - Version 0.9.144 (patch)

- Roster layout rollback:
  - Reverted the temporary RIO-width experiment and restored the compact roster column budget.
  - Restored the M2 frame width and the associated layout/test expectations to the previous stable state.
- Docs / release baseline:
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `isiLive.toc` to `0.9.144`.

## 2026-04-10 - Version 0.9.143 (patch)

- Kick event routing fix:
  - The kick tracker no longer registers a separate kick frame during addon initialization.
  - `UNIT_SPELLCAST_SUCCEEDED`, `UNIT_PET`, `SPELLS_CHANGED`, and `COMBAT_LOG_EVENT_UNFILTERED` now flow through the main event dispatcher, which avoids the protected `Frame:RegisterEvent()` call that could fire in tainted init contexts.
  - Updated the affected deterministic factory and architecture regressions to match the main-dispatcher wiring.
- Docs / release baseline:
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RULES_LOGIC.md`, and `isiLive.toc` to `0.9.143`.

## 2026-04-10 - Version 0.9.142 (feature)

- Kick column icon display:
  - Kick status is now shown as a coloured icon (green = ready, red = on cooldown, grey = unknown/no kick) instead of text.
  - When on cooldown, the icon darkens and a countdown number overlays it (no "s" suffix, font size 8).
  - Icons anchor right-aligned under the Kick header. Multi-slot ready for future dual-kick specs.
- Counterspell base cooldown corrected from 25s to 20s in `SPEC_DATA`.
- Title bar: removed "Öffnen/Schliessen STRG-F9" hint text.
- Test mode auto-exit: closing the UI via X-button or CTRL-F9 now automatically exits test mode if active.
- Settings persistence: background opacity and UI scale are now written to `IsiLiveDB` on first load with their defaults; subsequent sessions preserve user-changed values instead of always resetting.

## 2026-04-10 - Version 0.9.141 (patch)

- Rule 41 / UnitExists guard fixes:
  - Added explicit `UnitExists("player")` guards before runtime `GetBestMapForUnit("player")` lookups in highlight, hidden sync, tracked M0 runtime handling, factory target-dungeon checks, and frame-bridge player-map helpers.
  - Reworked the factory kick-sync path to reuse the last verified local player identity so stale local kick cache entries are still cleared fail-closed during transient `UnitExists` races.
  - Added deterministic call-site coverage for the guarded player-map lookup paths and cached kick-identity cleanup.
- Kick tracker combat-log failure diagnostics:
  - `KickTracker` now records deterministic failed-kick signals from matching combat-log miss events for the currently tracked interrupt without changing the live cooldown contract.
  - The factory kick tracker forwards `COMBAT_LOG_EVENT_UNFILTERED` into the kick tracker so the local failure signal can be observed deterministically in tests.
  - Added deterministic regressions for the local failed-kick signal and the factory combat-log forwarding path.
- Slot-based kick display:
  - The kick tracker now exposes slot lists for resolved interrupts, the sync layer transports the slot data alongside the legacy kick fields, and the roster Kick column renders green/red point markers instead of the previous `ready` text fallback.
  - Added deterministic regressions for slot transport, slot application, and the roster point rendering path.
- Docs / release baseline:
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RULES_LOGIC.md`, `WARTUNG.md`, `RELEASE.md`, and `isiLive.toc` to `0.9.141`.

## 2026-04-10 - Version 0.9.140 (feature)

- M+ Killtracker row added to M2 layout:
  - New bottom row in M2 shows Enemy Forces percentage as a progress bar with colour coding: green (<80%), yellow (<95%), red (≥95%).
  - Displays `--,--` when no key is active; switches to `00,00%` immediately on key start and resets to `--,--` on key end or reset.
  - Pull prediction: during active combat the row shows the forces delta gained in the current pull as `+X,XX%` text and as a second light-blue bar segment appended to the right of the main fill bar.
  - Pull prediction uses a scenario-quantity delta approach (combat-start snapshot vs. current quantity) — the only method that works in Midnight M+ where all NPC identification APIs return secret values inside the instance.
  - Demo mode shows `47,34%` with `+3,21%` pull preview.
  - Row label: `M+Killtracker` (grey, left-anchored).
  - Data source: `game/isiLive_killtrack.lua` — reads `C_ScenarioInfo.GetScenarioStepInfo()` weighted-progress criterion; reacts to `CHALLENGE_MODE_START/COMPLETED/RESET`, `SCENARIO_CRITERIA_UPDATE`, `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_DISABLED/ENABLED`.
  - M2 frame height extended by 28px to accommodate the new row; management, teleport and CD-tracker rows each shifted up by 28px.
- Docs / release baseline:
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `isiLive.toc` to `0.9.140`.

## 2026-04-10 - Version 0.9.139 (patch)

- Title bar UI polish:
  - Added `BETA` label in M2 title bar (after version string, hover tooltip shows beta notice + GitHub issues URL).
  - `BETA` label is only visible in M2 layout; hidden in H and V.
  - Settings panel: added Beta section at the top (above language selector) with notice text and copyable GitHub issues URL.
  - Removed decorative grip lines from the drag handle in the title bar.
  - Adjusted title bar font sizes: version string 12px, BETA label 12px, open/close hint 10px.
  - Fixed anchor chain so version, BETA, and open/close hint are all vertically aligned.
- Docs / release baseline:
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `isiLive.toc` to `0.9.139`.

## 2026-04-09 - Version 0.9.138 (patch)

- LibKeystone compatibility:
  - `isiLive` now registers and handles the `LibKS` addon-message prefix in party groups.
  - Manual `Re-Sync` now also sends one `LibKS` party request so compatible non-`isiLive` addons can answer with `level,mapID,rio`.
  - Incoming `LibKS` payloads now backfill party-member `Key` and `RIO`, while preserving richer `isiLive` `Spec`/`iLvl` data when it already exists.
  - Hidden clients now answer incoming `LibKS` requests with one party payload containing the local key and rating.
  - Added deterministic coverage for `LibKS` request/reply handling, hidden-party replies, request throttling, and KeySync delegation.
- Docs / release baseline:
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `isiLive.toc` to `0.9.138`.
  - Validator baseline is now documented as 522 scenarios across 38 modules, with 522 deterministic tests indexed by the rule validators.

## 2026-04-09 - Version 0.9.137 (patch)

- KICK / No-Guess hardening:
  - `Sync.SendKick()` and `Sync.SetPlayerKickInfo()` now reject malformed or incomplete KICK inputs instead of inventing a kick state.
  - `ProcessAddonMessage()` now discards malformed `KICK` payloads fail-closed, so no guess is written into the roster cache from broken peer data.
  - `ProcessAddonMessage()` now also treats changing remaining kick cooldown as a visible sync update, so the roster countdown keeps moving when the sender refreshes the payload.
  - Added deterministic regressions for malformed outbound `SendKick` inputs, malformed inbound `KICK` payloads, and remaining-cooldown updates; the kick test suite now covers the explicit no-guess contract and the countdown refresh path.
- Docs / release baseline:
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RULES.md`, `WARTUNG.md`, `RELEASE.md`, and `isiLive.toc` to `0.9.137`.
  - Validator baseline is now documented as 516 scenarios across 38 modules, with 516 deterministic tests indexed by the rule validators.

## 2026-04-09 - Version 0.9.134 (patch)

- Hidden / raid runtime hardening:
  - The dedicated kick tracker now does nothing in raid, including its separate cast frame and ticker paths, and resumes cleanly only after raid exit.
  - Explicit `HELLO`/`REQSYNC` kick replies now use the same guarded recovery path, and post-raid kick recovery may resume only from exact state: observed kick casts, exact Blizzard cooldown data, or an exact `no kick` resolution, never from guesses.
  - If post-raid kick recovery still cannot verify an exact available-kick state, the kick column stays unresolved and no kick sync packet is sent until exact cooldown data or a new observed kick cast becomes available; unrelated casts do not lift suppression.
  - Kick availability is now modeled with an explicit split between `unresolved` and exact `no kick`; `spellID == nil` alone no longer collapses those states.
  - Unreadable or protected Blizzard cooldown payloads no longer clear an already observed local kick cooldown; exact recovery fails closed instead of guessing `ready`.
  - Successful post-raid kick recovery now emits exactly one recovered kick sync packet and one visible kick-column refresh, even when the cooldown refresh path reports a state change during recovery.
  - `Sync.ClearKnownUsers()` now also resets the `KICK` dedup/rate-limit state so the next identical local kick payload is not suppressed by stale sender state.
  - Deferred post-run refresh state now lives in `RuntimeState` instead of ad-hoc handler context fields, and runtime resume on `GROUP_ROSTER_UPDATE` reads that state through the shared RuntimeState API.
  - Hidden mode no longer keeps the utility/CD polling ticker alive; explicit event-driven tracker refresh still runs, and reopening the UI marks the utility tracker dirty so the first visible roster render performs exactly one fresh utility rescan.
  - Delayed post-run refresh no longer leaks through raid hard-off; if the callback becomes due in raid, it is deferred and resumes on the next roster update after raid exit.
- Docs / release baseline:
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RULES.md`, `WARTUNG.md`, `RELEASE.md`, and `isiLive.toc` to `0.9.134`.
  - Validator baseline is now documented as 510 scenarios across 37 modules, with 510 deterministic tests indexed by the rule validators.

## 2026-04-08 - Version 0.9.133 (fix)

- Fix client version tooltip not showing for peers on older addon versions:
  - `sendIsiLiveHello` was missing from `BuildEventHandlersBaseConfig` — addon crashed on startup.
  - `sendIsiLiveHello` also missing from `BuildEventHandlersDepsFromContext` (secondary path).
  - Both HELLO and REQSYNC response paths now send a forced HELLO before the full state snapshot, so peers on older versions reliably receive and store the version info.
- Fix post-challenge full sync (key, stats, DPS, loc):
  - `NotifyPostChallengeSync()` flag consumed in `HandleOwnedKeyRefresh` — fires forced snapshot when `BAG_UPDATE_DELAYED`/`CHALLENGE_MODE_MAPS_UPDATE` arrives after key end.
  - When key level changed: forced snapshot instead of background snapshot.
  - When key unchanged but post-challenge flag set: forced snapshot.

## 2026-04-08 - Version 0.9.132 (fix)

- Key sync after Mythic+ run:
  - Full force-sync (key, stats, DPS, location) to all peers after a run ends, not just key.
  - `NotifyPostChallengeSync()` flag set on `CHALLENGE_MODE_COMPLETED`; consumed in `HandleOwnedKeyRefresh` when `BAG_UPDATE_DELAYED` / `CHALLENGE_MODE_MAPS_UPDATE` fires and WoW has updated the key.
  - Previously force-sync fired on `CHALLENGE_MODE_COMPLETED` before the API had the new key level; now always fires at the correct time regardless of key level change.

## 2026-04-08 - Version 0.9.131 (patch)

- Restructure: all Lua source files moved into subdirectories (`core/`, `ui/`, `logic/`, `locale/`, `factory/`, `game/`); doc files moved to `docs/`.
- UI: Center notice text vertically centered in frame (`TOPLEFT`→`BOTTOMRIGHT` anchor so `JustifyV MIDDLE` is effective).
- `sync_release_baseline.ps1` updated to new doc and locale paths.

## 2026-04-08 - Version 0.9.130 (patch)

- Minimap button:
  - Always created hidden at file-load time; shown/hidden on `PLAYER_LOGIN` once `IsiLiveDB` is available (mimics LibDBIcon pattern).
  - Right-click opens the Blizzard settings panel for isiLive directly.
- Roster panel: title bar now reads version from `C_AddOns.GetAddOnMetadata` at runtime instead of a hardcoded string.

## 2026-04-08 - Version 0.9.129 (feature)

- Multilanguage support:
  - Added French (`frFR`), Spanish (`esES`), and Portuguese (`ptBR`) UI languages.
  - Introduced `isiLive_languages.lua` as single source of truth for all supported languages (`Languages.SUPPORTED`, `Languages.ResolveTag`, `Languages.IsSupported`).
  - Language selector in Settings now built dynamically from `Languages.SUPPORTED` — no hardcoded button list.
  - `ResolveLocaleTag` in `isiLive_locale.lua` and `NormalizeLocaleTag` in `isiLive_season_data.lua` delegate to `Languages.ResolveTag`.
  - Button text clamping added to `SetFlatButtonText` and language selector buttons to prevent overflow on 120×24px action buttons.
  - All BTN_* keys for new languages kept ≤14 characters.
- Docs:
  - Added "Adding a new UI language" and "Button text length" sections to `CLAUDE.md`.
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `isiLive.toc` to `0.9.129`.

## 2026-04-02 - Version 0.9.128 (patch)

- Docs / release baseline:
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `isiLive.toc` to `0.9.128`.
  - Updated the runtime-visible addon title string to `v0.9.128`.

## 2026-04-02 - Version 0.9.127 (patch)

- Keystone chat output:
  - Share-Keys now builds a deterministic keystone hyperlink from the owned map ID and level instead of forwarding a foreign item hyperlink.
  - Tooltip helper fallbacks now accept varargs so the roster panel stays diagnostics-clean while still tolerating missing internal helpers.
- Docs / release baseline:
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `isiLive.toc` to `0.9.127`.

## 2026-04-02 - Tooling: local CI wrappers

- Added `tools/check.ps1`, `tools/check.cmd`, and `tools/run_local_ci.ps1` as short local entrypoints for the full CI preflight.
- Added a repo-local `tools/luacheck.cmd` shim so Windows uses `lua` to launch the LuaRocks `luacheck` script and no longer opens the "choose an app" dialog.
- Updated the local CI documentation to point at the wrapper chain instead of the bare LuaRocks script.

## 2026-04-02 - Version 0.9.126 (patch)

- Release packaging:
  - Excluded the `.claude/` helper directory from the CurseForge package.

## 2026-04-02 - Version 0.9.125 (patch)

- Release packaging:
  - Replaced the packaged changelog with a tiny release-note stub that links back to the repository changelog.
  - Excluded the full `CHANGELOG.md` from the CurseForge package to save zip size.

## 2026-04-02 - Version 0.9.124 (patch)

- Docs / release baseline:
  - Reduced the normal `/isilive` help output to `testall`, `log`, `start`, and `stop`.
  - Raised README, architecture, use-case, and TOC baselines to `0.9.124`.
  - Updated the UI title string to `v0.9.124` through the release baseline sync.

## 2026-04-01 - Version 0.9.122 (patch)

- Docs / release baseline:
  - Raised README, architecture, use-case, and TOC baselines to `0.9.122`.
  - Documented the raid hard-off behavior: raid-size groups now hide the UI and suppress background processing instead of forcing H mode.

## 2026-03-31 - Version 0.9.120 (patch)

- Slash command: `/isk` renamed to `/il` (shorter alias for `/isilive`).
- New command `/il reset` (also `/isilive reset`): wipes `IsiLiveDB` and triggers `ReloadUI()` to restore all settings to their defaults.
- Settings panel: new "Reset All Settings" button at the bottom of the settings page, equivalent to `/il reset`.

## 2026-03-30 - Version 0.9.119 (patch)

- Keys teilen: fix clients not posting their keystone to party chat — `ctx.getRoster` was nil (typo: should be `ctx.GetRoster`), causing `sendOwnKeystoneToChat` to silently return early on all remote clients.

## 2026-03-30 - Version 0.9.118 (patch)

- Kick-state sync: add 15s heartbeat broadcast so peers that reload or join late always see up-to-date interrupt ready/cooldown state instead of a stale dash.
- Settings: option-selector labels for "Default Layout on Open" and "Raid Transition Behavior" now render above the buttons to prevent overlap with long label text.
- Combat fade (M/M2): fix ticker conflict — existing fade animation is now cancelled before starting a new one; extract shared `ApplyCombatFade` helper; use RI layout constants instead of magic strings.
- Kick tracker: cache `ScanOwnTalents` result via `talentScanDirty` flag; invalidated on spec/talent change — avoids full talent-tree traversal on every cast.
- UI close button: `frame:Hide()` is now called directly (combat-safe) so the frame closes immediately even during combat.
- Sound: all sounds now routed through `SoundUtils` module on the SFX channel with 1s spam protection.
- Group join sound: new `onMemberJoinedGroup` callback detects when other players join the group (not just the local player).
- Column guides: wired `showRosterColumnGuides` into `CreateRosterPanelController`.

## 2026-03-30 - Version 0.9.117 (patch)

- `canRespondToRefreshRequest` gate simplified: the active-M+ (`GetActiveChallengeMapID`) block has been removed, so hidden clients now answer incoming `REQSYNC` refresh requests even during an active Mythic+ run; only stopped and paused states still suppress replies.
- Share-Keys remote cooldown propagation:
  - When a client receives an incoming `SHAREKEYS` sync message it now calls `TriggerRemoteCooldown` on the local `Share Keys` button, locking the button for 30 s on all peer clients as well as on the initiating client (guarded: an already-running local cooldown is not reset).
  - `TriggerShareKeysCooldown` accessor plumbed from `RosterPanel` controller through `isiLive_factory_controllers.lua` and `isiLive_controller_wiring.lua` into the runtime event handler.
  - `sendOwnKickState` is now called alongside `sendOwnTargetSnapshot` when answering a refresh request, so responding clients include up-to-date kick state in their reply.
- Kick-tracker no-interrupt state transport:
  - `SendKick` encodes a no-interrupt state as `onCooldown = -1` in the `KICK:` payload when `hasKick` is `false`, letting peers distinguish "no interrupt available for this spec" from "kick is on cooldown".
  - `ProcessAddonMessage` parses the `-1` sentinel and stores `hasKick = false` via `SetPlayerKickInfo`.
  - `ApplyKnownKeyToRosterEntry` in `isiLive_keysync.lua` propagates `syncHasKick` to roster entries; `SetKickCellText` in the roster panel renders `-` when `syncHasKick == false`.
- Kick-tracker pet-interrupt support:
  - Warlock Affliction and Destruction now track the Felguard/Felhunter `Spell Lock` (ID 19647, 24 s) via pet-cast unit tracking.
  - Warlock Demonology prefers `Axe Toss` (ID 89766, 30 s) when available; falls back to `Spell Lock`; shows `-` in the `Kick` column when neither pet interrupt is castable (`requireAvailability`).
  - Demon Hunter Devourer spec (ID 1480) added to the interrupt table (Disrupt, 15 s).
  - `UNIT_SPELLCAST_SUCCEEDED` now monitors the `pet` unit in addition to `player`; `UNIT_PET` triggers a spec-recheck when the active pet changes.
  - `SyncOwnKickState` extracted to a shared helper, unifying cooldown-change callbacks, spec-change broadcasts, and ticker-driven state updates.
- Background sync improvements:
  - `DPS` is now always included in background snapshots regardless of frame visibility, so peers always receive the latest run stats even while the main window is hidden.
  - `TARGET` snapshots now auto-set `allowHidden = true` whenever the local frame is not visible, ensuring hidden-client target data reaches peers on refresh.
- RULES_LOGIC.md: rule 28 updated (active-M+ block removed, all sync buckets listed explicitly), rule 53 added (Share-Keys spam guard propagation).
- Tests: validator baseline raised from 460 to 470 scenarios; new coverage added for pet-interrupt specs, no-interrupt state transport, Share-Keys remote lockdown, and SHAREKEYS hidden-client handling.
- Fix: luacheck unused-parameter warning in `onCooldownChanged` callback (`cooldownRemain` → `_cooldownRemain`) after kick-state sync was moved into `SyncOwnKickState`.

## 2026-03-29 - Version 0.9.116 (patch)

- Kick sync reliability overhaul:
  - Ticker interval reduced from 1.0 s to 0.5 s for more responsive cooldown updates.
  - Receive timestamp stored alongside `cooldownRemain` so the roster `Kick` column counts down smoothly between sync packets via linear interpolation.
  - After a cooldown expires the ticker continues broadcasting the ready state for 3 extra seconds to guarantee delivery to all peers.
  - `KICK:0:0` payload is now sent as `math.ceil` to prevent a premature ready frame at sub-second remain.
  - Rate limit tightened to 1 s minimum between identical payloads.
  - Roster `Kick` column shows `-` instead of `0s` while the final packet is still in-flight, eliminating false red flicker.
- Hello / full-state sync on peer discovery:
  - When a new peer sends a HELLO the addon now immediately replies with the complete local state: key, stats, DPS, location, and kick (ready/cooldown), so the first roster render for that peer is already complete.
- Kick tracker correctness:
  - Changing specialization to a class with a different interrupt spell now immediately clears the old cooldown rather than leaving a stale timer running.
  - `ClearKnownUsers` now also clears the kick-info cache (`kickInfoByPlayerKey`), preventing ghost kick data after group resets.
- Docs / release baseline:
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `CHANGELOG.md`, `isiLive_texts.lua`, and `isiLive.toc` to `0.9.116`.
  - Validator baseline remains `460` scenarios across `34` modules and `460` rule-indexed deterministic tests.
- Release metadata:
  - Bumped TOC/version strings to `0.9.116`.

## 2026-03-29 - Version 0.9.115 (patch)

- Distributed `Share Keys` flow:
  - `Share Keys` now posts the local player's own keystone to party chat immediately and then broadcasts a lightweight `SHAREKEYS` addon message so other `isiLive` users can post their own key line as well.
  - The `Share Keys` button now shows a visible `30s` cooldown in its label while blocked, matching the chat anti-spam guard.
  - Owned-keystone fallback links now include the dungeon name instead of a bare `[Keystone]` placeholder when the native Blizzard link is unavailable or incomplete.
- Sync / roster data polish:
  - Sync now clears stale kick-cache data on full known-user resets and stores receive timestamps so remote interrupt cooldowns in the roster `Kick` column can count down smoothly between sync updates.
  - Sync tooltips now show `Client version: x.y.z` / `Client-Version: x.y.z` without the protocol suffix.
- Combat utility / runtime fixes:
  - The Mythic+ timer now reads the correct elapsed-time return value from `GetWorldElapsedTime`, so the live `+3/+2/+1` cutoffs advance correctly during active keys.
  - Interrupt tracking now clears the old watched cooldown immediately when the player changes specialization to a different interrupt spell.
  - Kept ready-check finish behavior aligned with the active ready-check rule contract: the live ready-check state still ends immediately on finish, while explicit declines continue to linger for 20 seconds.
- Tests / docs / release baseline:
  - Added deterministic coverage for `SHAREKEYS` sync handling, hidden-mode key-share replies, the updated share-keys button wiring, and the simplified client-version tooltip text.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.115`.
  - Validator baseline is now `460` scenarios across `34` modules and `460` rule-indexed deterministic tests.
- Release metadata:
  - Bumped TOC/version strings to `0.9.115`.

## 2026-03-29 - Version 0.9.114 (patch)

- Audio settings and group lifecycle:
  - Added localized Blizzard Settings toggles for `Sound: Lead Transfer` and `Sound: Group Join`.
  - Leader-transfer promotions still show the visible notice, but the sound can now be disabled explicitly; the new group-join sound hook stays off by default until the user enables it.
- Kick tracker refresh path:
  - Kick cooldown updates now refresh only the dedicated roster `Kick` column instead of forcing a full UI rerender.
  - Kick spell resolution now also refreshes on `PLAYER_SPECIALIZATION_CHANGED`, so spec swaps update the tracked interrupt immediately.
- Tests / docs / release baseline:
  - Added deterministic coverage for the new sound toggles, the optional first-group-join callback, the disabled leader-sound path, and the lightweight kick-refresh wiring.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.114`.
  - Validator baseline is now `457` scenarios across `34` modules and `457` rule-indexed deterministic tests.
- Release metadata:
  - Bumped TOC/version strings to `0.9.114`.

## 2026-03-29 - Version 0.9.113 (patch)

- Combat utility refresh:
  - The one-second utility ticker now triggers a full UI rerender while an active Mythic+ timer is running, so the `+3/+2/+1` cutoff row keeps counting down live during a key.
- Metrics / release gate alignment:
  - Synced the Lua metrics hard limits to `3200` file lines and `420` function lines across `tools/lua_metrics_check.lua`, `.github/workflows/lua-check.yml`, and `tools/validate_ci_local.ps1` so local preflight and GitHub Actions enforce the same baseline.
  - Updated release and maintenance docs to use the current metrics baseline and local preflight expectations.
- Docs / release baseline:
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `WARTUNG.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.113`.
  - Validator baseline is now `452` scenarios across `34` modules and `452` rule-indexed deterministic tests.
- Release metadata:
  - Bumped TOC/version strings to `0.9.113`.

## 2026-03-29 - Version 0.9.112 (patch)

- Re-Sync flow:
  - Renamed the user-facing `Refresh` button to `Re-Sync` in both locales.
  - Increased the manual re-sync guard to `10` seconds and show the remaining cooldown directly on the button label while the action is blocked.
  - Real first-group joins now delay the forced `REQSYNC` trigger by `0.5s` so group state has settled before addon sync messages are sent.
- Main window title bar:
  - Removed the extra separator dot between title and version/hotkey hint; the compact header now renders as one cleaner title block.
  - Updated the compact-layout test/layout wiring so the simplified title head stays hidden correctly in `H` mode.
- Docs / release baseline:
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.112`.
  - Validator baseline remains `451` scenarios across `34` modules and `451` rule-indexed deterministic tests.
- Release metadata:
  - Bumped TOC/version strings to `0.9.112`.

## 2026-03-29 - Version 0.9.111 (patch)

- Main window title bar:
  - Added a small localized hotkey hint next to the version label: `Open/Close CTRL-F9` / `Öffnen/Schliessen STRG-F9`.
  - Compact `H` and `V` layouts now hide the title/version block completely, including the drag-grip lines, while drag-to-move still stays available.
- Roster combat info:
  - Added the `Kick` roster column with synced interrupt cooldown state (`ready` / remaining seconds) for party members.
  - Expanded the bottom combat utility area to include Mythic+ timer cutoffs (`+3/+2/+1`) and death-penalty tracking alongside `BRes` and lust timers.
  - Added the new runtime modules `isiLive_kick_tracker.lua` and `isiLive_mplus_timer.lua` and wired them into controller/bootstrap flow.
- Tooltip / demo / sync polish:
  - Peer version tooltip formatting now stays stable with protocol suffixes (`pN`) across locale overrides.
  - Demo full-preview rebuild tests now resolve ghost rows from the generated dataset instead of depending on a stale hardcoded dummy identity.
- Docs / release baseline:
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.111`.
  - Updated the documented validator counts to `451` scenarios across `34` modules and `451` rule-indexed deterministic tests.
- Release metadata:
  - Bumped TOC/version strings to `0.9.111`.

## 2026-03-29 - Version 0.9.110 (patch)

- Active Midnight Season 1 dungeon labels:
  - Corrected the localized `deDE` dungeon names to `Windlaeuferturm`, `Terrasse der Magister`, `Nexuspunkt Xenas`, `Maisarakavernen`, `Akademie von Algeth'ar`, `Grube von Saron`, `Sitz des Triumvirats`, and `Die Himmelsnadel`.
  - Unified the active Midnight Season 1 short codes for both `enUS` and `deDE` to `WRS / MT / NPX / MC / AA / POS / SOT / SR`.
  - Added deterministic coverage for the active-season short code baseline and the corrected `deDE` full-name baseline.
- Docs / release baseline:
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.110`.
  - Updated the documented validator counts to `450` scenarios across `34` modules and `450` rule-indexed deterministic tests.
- Release metadata:
  - Bumped TOC version to `0.9.110`.

## 2026-03-28 - Version 0.9.109 (patch)

- Code cleanup / dead code removal:
  - `SendRefreshResponse` now delegates to `SendOwnStateSnapshot` instead of duplicating the send logic.
  - `READY_CHECK_CONFIRM` no longer triggers a UI refresh when the `unit` parameter is invalid.
  - Removed `Teleport.ResetActivityCaches()` (unused export).
  - Removed 9 Season 3 legacy wrapper functions from `isiLive_teleport.lua` and their associated tests.
  - Removed `SeasonData.IsSeasonReady()` (unused export, superseded by `GetSeasonReadiness`).
- Docs / release baseline:
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.109`.
- Release metadata:
  - Bumped TOC version to `0.9.109`.

## 2026-03-28 - Version 0.9.108 (patch)

- Roster ghost ordering:
  - Persisted ghost rows no longer consume visible roster slots ahead of active group members.
  - The visible 5-row roster budget now guarantees active entries render before ghosts, so stale leavers cannot hide a current party member.
  - Added deterministic panel coverage for the exact `4 active + 2 ghosts` clipping case.
- Docs / release baseline:
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.108`.
  - Documented the new active-before-ghost roster guarantee across user docs and architecture docs.
  - Updated the documented validator counts to `449` scenarios across `34` modules and `449` rule-indexed deterministic tests.
- Release metadata:
  - Bumped TOC version to `0.9.108`.

## 2026-03-27 - Version 0.9.107 (patch)

- Ready-check UX:
  - Explicit `notready` answers now stay red for 20 seconds after `READY_CHECK_FINISHED` instead of clearing immediately.
  - Added deterministic coverage for runtime-state declined-hold tracking, event-handler timer cleanup, roster rendering during the hold window, and the dedicated post-hold refresh path.
- Docs / release baseline:
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.107`.
  - Corrected ready-check documentation from text-color wording to row-background + waiting sandglass + 20-second declined hold behavior.
  - Removed stale `Deaths`/`Kicks` references from architecture docs and updated documented validator counts to `448` scenarios across `34` modules and `448` rule-indexed deterministic tests.
- Release metadata:
  - Bumped TOC version to `0.9.107`.

## 2026-03-27 - Version 0.9.106 (patch)

- Group join / sync refresh:
  - A real first group join now forces the local `HELLO` + `KEY`/`STATS`/`DPS`/`LOC` snapshot and broadcasts `REQSYNC`, so roster data refreshes immediately after an invite accept instead of waiting for a manual `Refresh` click.
  - Added deterministic coverage that the first join path bypasses normal sync cooldowns and still avoids recursive auto-open side effects.
- Run snapshot / roster sync cleanup:
  - Removed unreliable `Deaths` and `Kicks` collection, transport, roster fallback, and tooltip rendering; last-run sync is now explicitly `DPS`-only.
  - Updated rules, docs, and deterministic coverage to reflect the verified `DPS`-only contract.
- Center notice / dungeon detection:
  - Removed dungeon/activity detection context from the runtime center-notice path; the visible right-side teleport grid remains unchanged.
  - Hardened the rules validator so multiline `test(` declarations remain indexable after `stylua` formatting.
- Esc menu taint hardening:
  - Reworked the optional `Esc` tooling and travel strips so both panels are mounted directly as prebuilt `GameMenuFrame` children instead of relying on a deferred external host-frame show/hide path.
  - During combat lockdown, the strip layout path is now strictly read-only: no `Show`, `Hide`, `ClearAllPoints`, `SetPoint`, `SetSize`, `EnableMouse`, or `SetAlpha` mutations run on the mounted overlays, insecure shortcut clicks no-op in combat, and secure refreshes stay queued until `PLAYER_REGEN_ENABLED`.
  - Added deterministic regression coverage for first combat-open visibility, parent-mounted panel ownership, and the absence of deferred host callbacks.
- Docs / release baseline:
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.106`.
  - Updated the documented validator counts to `432` scenarios across `34` modules and `428` rule-indexed deterministic tests.
- Release metadata:
  - Bumped TOC version to `0.9.106`.

## 2026-03-26 - Version 0.9.105 (patch)

- Queue join / ready-check / taint hardening:
  - Restored the active queue-join runtime wiring through factory, runtime setup, and controller wiring, and added live-path deterministic coverage for challenge-ignore, pending capture/reset, and grouped announce behavior.
  - Ready-check lifecycle now uses a dedicated roster refresh path instead of the generic full rerender, resetting name/spec colors cleanly after the ready check and avoiding secure role-button rewrites.
  - Combat-safe roster layout updates now skip secure button `SetPoint`/`SetSize` mutations during combat, preventing protected-call taint from M2 rerenders.
- Roster and notice UI polish:
  - Added a real leader marker in the roster: real group leaders render a 16x16 crown, and synced leaders keep the blue heart before the crown.
  - Unified center-notice body typography with the portal navigator via a shared helper, so body font and default color now stay aligned on one implementation path.
- Docs / release baseline:
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.105`.
  - Updated the documented validator counts to `419` scenarios across `34` modules and `415` rule-indexed deterministic tests.
- Release metadata:
  - Bumped TOC version to `0.9.105`.

## 2026-03-26 - Version 0.9.104 (patch)

- Queue join and ready-check hardening:
  - Documented the active queue-join runtime path as the factory/runtime-wired implementation, with deterministic parity coverage against the legacy `QueueFlow` helper.
  - Documented the dedicated ready-check refresh path that updates roster colors without rerunning the generic full render or rewriting secure role-button attributes.
  - Added deterministic coverage that a ready-check rerender resets spec color correctly after the ready check ends.
- Docs / release baseline:
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.104`.
  - Updated the documented validator counts to `412` scenarios across `34` modules and `408` rule-indexed deterministic tests.
- Release metadata:
  - Bumped TOC version to `0.9.104`.

## 2026-03-26 - Version 0.9.103 (patch)

- Docs / validation alignment:
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, and `isiLive.toc` to `0.9.103`.
  - Updated the documented deterministic gate counts to `400` scenarios across `34` modules and `396` rule-indexed deterministic tests.
  - Documented the current queue/runtime wiring shape: `isiLive_config_builders.lua` no longer exposes a dedicated queue-flow builder, and queue-target traceability now points at `isiLive_queue.lua` plus `isiLive_event_handlers_queue.lua`.
- Release metadata:
  - Bumped TOC version to `0.9.103`.

## 2026-03-26 - Version 0.9.102 (patch)
- **Removed / Queue Dungeon Detection:**
  - Removed queue dungeon recognition and highlighting entirely. Blizzard no longer delivers usable data via `LFG_LIST_APPLICATION_STATUS_UPDATED` or `LFG_LIST_SEARCH_RESULT_UPDATED` at the time of invite/join, making reliable detection impossible without guessing.
  - Queue join chat output now shows group name only: "Aus Queue beigetreten: [Gruppenname]" — no dungeon name.
  - `ShowQueueJoinPreview`, `setQueueTargetState`, `UpdatePendingQueueJoin`, `BuildAnnouncementSignature` and the full pending-queue-join-info pipeline removed from `isiLive_queue_flow.lua`.
  - `showQueueJoinPreview` removed from test mode controller.
- **Fixed / Hearthstone Button:**
  - Fallback Hearthstone button (item ID 6948) now sets `"item:6948"` (string) instead of `6948` (number) as the secure attribute, fixing the `C_Item.IsEquippableItem` error from Blizzard's SecureTemplates.
- **Changed / Administrative Settings:**
  - Debug section renamed to "Administrativ" (DE) / "Administrative" (EN).
  - Queue Debug Log and Runtime Log are no longer persisted across sessions — they always start disabled on login/reload. Labels updated to indicate this.
  - Settings checkboxes for these options now reflect live controller state instead of SavedVariables.
- **Docs / Release Sync:**
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, and `isiLive.toc` to `0.9.102`.
- **Tests / Validation:**
  - `lua tools/validate_rules_logic.lua` validates `397` deterministic tests indexed.
  - `lua tools/validate_usecases.lua` validates `401` scenarios across `34` modules.

## 2026-03-25 - Version 0.9.101 (patch)
- **Behavior / Main UI Auto-Close Default:**
  - The main UI no longer closes automatically by default on `CHALLENGE_MODE_START` or on the transition from group to solo.
  - Closing stays manual via `X` or `CTRL+F9`.
  - Blizzard Settings now expose `Auto-Close on Key Start / Solo` so the previous automatic close behavior can be re-enabled explicitly.
- **Tests / Validation:**
  - Added Lua regression coverage for the new auto-close option in settings, challenge-start handling, and group-to-solo transition handling.
  - Updated roster-panel deterministic test fixtures to satisfy the new required `setMainFrameWidthSafe` dependency.
  - `lua tools/validate_usecases.lua` validates `402` deterministic tests indexed and `406` scenarios across `34` modules.
- **Docs / Release Baseline:**
  - Bumped TOC version to `0.9.101`.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, and `isiLive.toc` to `0.9.101`.

## 2026-03-25 - Version 0.9.100 (patch)
- **Bugfix / BRes Charges API Migration:**
  - `CdTracker` now unpacks `C_Spell.GetSpellCharges` struct-return (`currentCharges`, `maxCharges`, `cooldownStartTime`, `cooldownDuration`) instead of the removed multi-return signature, fixing the `attempt to compare table with nil` error.
- **Bugfix / Group Roster Reload Recovery:**
  - `PLAYER_ENTERING_WORLD` now triggers `handleGroupRosterUpdate()` when the player is already in a group after a UI reload, so the roster panel rebuilds immediately instead of staying blank. Previously the hidden-frame event gate blocked `GROUP_ROSTER_UPDATE` inside party instances, and the `PLAYER_ENTERING_WORLD` handler did not re-scan the group.

## 2026-03-24 - Version 0.9.99
- **Docs / Release Baseline:**
  - Bumped TOC version to `0.9.99`.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, and `isiLive.toc` to `0.9.99`.
  - `lua tools/validate_usecases.lua` now validates `391` deterministic tests indexed and `395` scenarios across `34` modules.
- **Maintenance / Test Gate Cleanup:**
  - Removed dead TeleportUI cosmetic test blocks, deleted empty scenario placeholder modules, and trimmed the scenario manifest to active modules only.
  - Consolidated slash-command coverage into `isilive_test_scenarios_commands.lua`; the separate extended commands scenario file was removed.
  - Removed leftover dead roster-panel tooltip/layout test wiring after the cosmetic test cut.
- **Docs / Behavior Sync:**
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, and `RELEASE.md` to the cleaned validator counts and active scenario manifest.
  - Clarified that hidden leader promotions still play the transfer sound while suppressing center notice and chat output.
  - Clarified queue-join docs: there is no separate `Dungeon erkannt` chat line, grouped queue chat is member-only, and hidden `LFG_LIST_*` suppression prevents retroactive queue chat after a missed hidden capture.
- **Code Cleanup:**
  - Removed the duplicate `DidRecordRunSucceed` helper from the challenge and non-challenge run-capture paths.
  - Removed the dead hidden `soundEnabled` setting scaffolding from runtime startup, Blizzard Settings wiring, locale texts, and legacy tests; the unused BL sound file remains in `sounds/` by choice.
- **Bugfix / Bloodlust Zone-Reload Onset Guard:**
  - `UNIT_AURA` now forwards WoW's `isFullUpdate` flag into `CdTracker`, so zone/reload aura restores hydrate the active lust state without replaying the onset callback.
  - `SuppressOnset` now acts as a short 2-second safety net for early ticker scans before the full aura restore arrives.
- **Tests / Validation:**
  - Added regression coverage for `UNIT_AURA.isFullUpdate` forwarding, late full-update aura restores after the suppress window, and reload recovery while lust is already active.

## 2026-03-23 - Version 0.9.98
- **Docs / Release Baseline:**
  - Bumped TOC version to `0.9.98`.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, and `isiLive.toc` to `0.9.98`.
  - `lua tools/validate_usecases.lua` validates `418` deterministic tests indexed and `425` scenarios across `37` modules.
- **Bugfix / Bloodlust Aura Scan Type Safety:**
  - `CdTracker` now accepts only real numeric aura `spellId` values for the harmful-aura lust lookup.
  - Protected, secret, string, or otherwise non-numeric `spellId` payloads are ignored safely instead of being coerced or used as table keys.
- **Tests:**
  - Added regression coverage so mixed invalid/non-numeric `spellId` payloads still allow a later valid lust aura to be detected.

## 2026-03-23 - Version 0.9.97
- **Docs / Release Baseline:**
  - Bumped TOC version to `0.9.97`.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, and `isiLive.toc` to `0.9.97`.
  - `lua tools/validate_usecases.lua` validates `417` deterministic tests indexed and `424` scenarios across `37` modules.
- **Bugfix / Bloodlust Aura Scan Normalization:**
  - `CdTracker` now normalizes the lust-debuff `spellId` via `tonumber(...)` before the harmful-aura table lookup, so protected or string-tainted WoW aura payloads no longer break or bypass lust detection.
  - If one aura entry exposes an unusable `spellId`, later valid Bloodlust/Heroism/Time Warp exhaustion auras in the same scan are still detected correctly.
- **Tests:**
  - Existing regression coverage confirms `CdTracker` skips invalid aura `spellId` keys and still finds a later valid lust aura.

## 2026-03-23 - Version 0.9.96
- **Docs / Release Baseline:**
  - Bumped TOC version to `0.9.96`.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, and `isiLive.toc` to `0.9.96`.
  - `lua tools/validate_usecases.lua` now validates `417` deterministic tests indexed and `424` scenarios across `37` modules.
- **Bugfix / Bloodlust Aura Scan Hardening:**
  - `CdTracker` now protects the lust-debuff `spellId` lookup with `pcall`, so WoW aura payloads with protected/invalid `spellId` values no longer abort the entire harmful-aura scan.
  - If one aura entry exposes an unusable `spellId`, later valid Bloodlust/Heroism/Time Warp exhaustion auras in the same scan still get detected correctly.
- **Tests:**
  - Added regression coverage for invalid/protected aura `spellId` keys so `CdTracker` stays stable and still finds a later valid lust aura.

## 2026-03-23 - Version 0.9.95
- **Docs / Release Baseline:**
  - Bumped TOC version to `0.9.95`.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, and `isiLive.toc` to `0.9.95`.
  - `lua tools/validate_usecases.lua` now validates `416` deterministic tests indexed and `423` scenarios across `37` modules.
- **Bugfix / Bloodlust Zone Transition:**
  - `CdTracker` now mirrors `BResLustTracker` more closely by scanning player `HARMFUL` auras via `C_UnitAuras.GetAuraDataByIndex(...)` for lust exhaustion debuffs instead of relying on `GetPlayerAuraBySpellID`.
  - `UNIT_SPELLCAST_SUCCEEDED` for the local player is now registered so real lust casts can trigger the onset path immediately without waiting for the next ticker/aura pass.
  - Zone/world transition suppression now treats matching post-transition lust auras as continuations instead of new onsets, preventing false-positive Bloodlust/Heroism/Time Warp sounds on zoning or reload transitions.
- **Bugfix / Leader Promotion Sound:**
  - Leader gain detection now reacts to the first observed local leader transition across both `GROUP_ROSTER_UPDATE` and `PARTY_LEADER_CHANGED`, preventing missed promotion sounds when roster updates arrive first.
- **Bugfix / Esc Menu Combat Safety:**
  - Deferred game-menu side-panel host-frame `Show()` calls now stay combat-safe and replay through the existing `PLAYER_REGEN_ENABLED` retry path instead of triggering protected `Frame:Show()` calls in combat.
- **Bugfix / Hearthstone Fallback:**
  - The `Esc` travel-strip `Hearthstone` button now falls back to the default Hearthstone item (`6948`) when the player owns no Hearthstone toy, instead of leaving the secure button without a usable action.
- **Tests:**
  - Added regression coverage for harmful-aura lust scanning, zone-transition lust continuation, local lust spellcast forwarding, leader-promotion event ordering, game-menu combat-safe deferred host-frame shows, and Hearthstone toy/item fallback behavior.

## 2026-03-23 - Version 0.9.94
- **M2 Travel Short Codes:**
  - `M2` portal icons now render large localized dungeon short codes directly on the icon while the teleport is ready, so the destination is recognizable without mouseover.
  - The `M2` short-code overlay is hidden whenever the teleport is on cooldown, leaving the cooldown timer unobstructed.
  - Updated active Midnight Season 1 short codes to favor clearer `M2` readability: `Windrunner Spire` now uses `WRS` (`enUS`/`deDE`) and `Maisara Caverns` now uses `MAI` (`enUS`/`deDE`).
  - Added deterministic `TeleportUI` coverage for visible `M2` short-code rendering and cooldown-time overlay suppression.
- **Forward Compat / Blizzard 12.0.1 Cooldown Hotfix:**
  - `SpellUtils.ApplyCooldownFrameSafe` now prefers `SetCooldownFromDurationObject` (the only setter Blizzard guarantees for secret values post-hotfix) over `CooldownFrame_Set` and `SetCooldown`. Feature-detected: works on both current live and post-hotfix clients.
- **Bugfix / Sync Cooldown Reset:**
  - `Sync.ClearKnownUsers()` now resets all send cooldown timestamps and dedup payloads so the next identical snapshot fires immediately after a group change instead of being silently suppressed.
- **Bugfix / Realm Normalization:**
  - `Stats.NormalizeName()` now strips spaces, dashes, dots, parentheses, and quotes from realm names, matching the `Sync.NormalizePlayerKey()` convention. Previously, realm names with special characters (e.g. `Der Rat von Dalaran`) could fail to match between damage-meter sources and roster entries.
- **Bugfix / Arkantine Locale:**
  - The `Esc` travel strip `Arkantine` button now resolves the item name by WoW client locale at button creation time (`deDE` → German, all others → English). Previously, the macro was hardcoded to the German item name and would fail on non-German clients.
- **Bugfix / Highlight Determinism:**
  - Activity ID selection from multi-activity LFG listings now sorts candidates and picks the smallest ID instead of relying on non-deterministic `pairs()` iteration order.
- **Code Hardening / rawget Pattern:**
  - All `IsiLiveDB` global reads now use `rawget(_G, "IsiLiveDB")` consistently across all modules (`stats`, `sync`, `log_buffer`, `queue_debug`, `runtime_log`, `ui`, `factory_controllers`, `event_handlers_challenge`) to avoid triggering `__index` metamethods on `_G`.
  - `GetRealmName` access in both `isiLive_stats.lua` and `isiLive_sync.lua` switched to `rawget(_G, "GetRealmName")` with type guard, matching the defensive pattern used for all other WoW API globals.
  - Added nil-guards for `rawget(_G, "IsiLiveDB").stats` access in `isiLive_stats.lua` to prevent nil-index crashes if the call chain is ever reordered.
- **Code Cleanup / KeySync:**
  - Extracted `ResolveAverageItemLevel()` as a standalone function in `isiLive_keysync.lua`, eliminating the inline duplication between `C_Item` and legacy `GetAverageItemLevel` fallback paths.
- **Season Data:**
  - Cleared the inactive portal message for Midnight Season 1 now that the season is live (`inactivePortalMessageByLocale` is empty).
- **Tests:**
  - Added regression test for `Stats.NormalizeName` realm special-character stripping with `Der Rat von Dalaran` (spaces, stripped-variant lookup).
  - Added regression test for `Sync.ClearKnownUsers` cooldown/dedup reset (identical payload must fire immediately after clear).
  - New `isilive_test_scenarios_keysync.lua`: 17 dedicated KeySync controller tests covering `MarkIsiLiveUser`, `UnitHasIsiLive`, `RegisterIsiLiveSyncPrefix`, `ResolveActiveKeyOwnerUnit`, `RefreshLocalPlayerKey`, `ForceRefreshSyncState`, `GetOwnedKeystoneSnapshot`, `SendRefreshRequest`, and `ApplyKnownKeyToRosterEntry`.
  - New `isilive_test_scenarios_commands_extended.lua`: 13 extended commands tests covering `testall` (stopped/paused/running), `tptest`, `tpdebug`, `lead` (yes/no), `bindcheck`, unknown/empty input help, pause/resume while stopped, and `lang enus/dede` aliases.
  - New `isilive_test_scenarios_config_builders.lua`: 8 config builder tests verifying all 6 `BuildXxxOpts()` functions pass through context fields correctly and do not leak extra fields.
  - `lua tools/validate_usecases.lua` now validates `404` deterministic tests indexed and `408` scenarios across `37` modules.
- **Code Modernization / Shared Utilities:**
  - New `isiLive_validation_helpers.lua`: centralized `RequireFunction`, `RequireTable`, and `IsExistingUnit` — eliminates identical 4–13 line helper copies across 11+ modules.
  - New `isiLive_string_utils.lua`: centralized `Trim`, `StripWhitespace`, and `NormalizeRealmName` — replaces duplicate inline `gsub` patterns across 6+ modules.
  - All 11 modules with local `RequireFunction`/`RequireTable` now delegate to `addonTable.Validators`.
  - `IsExistingUnit` consolidated from 4 identical copies (units, locale, inspect, roster) into one canonical implementation.
  - Realm normalization in `Sync.NormalizePlayerKey`, `Stats.NormalizeName`, and `Locale.NormalizeRealmLookupKey` now uses `StringUtils.NormalizeRealmName`.
  - Trim patterns in `Status`, `FactoryControllers`, and `Sync.NormalizeSyncSource` now use `StringUtils.Trim`.
  - Test harness (`isilive_test_harness.lua`) extended with universal dependency loading for shared utility modules.
- **Code Modernization / Factory Decomposition:**
  - Split `InitializeFactoryRuntimeHelpers` (288 lines) into 4 focused sub-functions: `InitializeGameAPIHelpers`, `InitializeRuntimeStateDelegates`, `InitializeRioHelpers`, `InitializeStatusAndOperationalHelpers`.
- **Code Modernization / Sync Documentation:**
  - Replaced brief German inline comment with detailed English architecture note explaining the singleton state rationale, reset contract, and relationship to `ClearKnownUsers()`.
- **Tests:**
  - New `isilive_test_scenarios_validation_helpers.lua` (8 tests): RequireFunction/RequireTable pass/fail/default, IsExistingUnit nil/missing-API/delegation/pcall-safety.
  - New `isilive_test_scenarios_string_utils.lua` (7 tests): Trim/StripWhitespace/NormalizeRealmName with edge cases and canonical pattern verification.

## 2026-03-23 - Version 0.9.93
- **Sound / Leader Promotion:**
  - Plays `sounds/CartoonVoiceBaritone.ogg` (Master channel) when the local player is promoted to group leader via `PARTY_LEADER_CHANGED`.
  - Sound fires even when the isiLive frame is hidden; uses `PlaySoundFile` directly instead of `SOUNDKIT` constants.
- **Sound / Bloodlust & Heroism:**
  - Plays `sounds/BoxingArenaSound.ogg` (Master channel) on Bloodlust / Heroism / Time Warp onset, detected via `CdTracker`.
  - `CdTracker` gains an `onLustStart` callback and a `SuppressOnset(seconds)` method to prevent false positives from auras briefly disappearing during zone transitions or reloads.
  - `baselineCdTracker` (calls `SuppressOnset(3)`) is now wired into both `PLAYER_ENTERING_WORLD` and all `ZONE_CHANGED*` / `UPDATE_INSTANCE_INFO` handlers, covering portal traversals that do not trigger a loading screen.
- **Assets / Git:**
  - `sounds/` directory added; all sound files ignored by default except the two actively used (`CartoonVoiceBaritone.ogg`, `BoxingArenaSound.ogg`).
- **UI / Portal Navigator:**
  - Dungeon name text color changed from plain white to warm cream-gold for better visual harmony with the title.
  - Background alpha increased from `0.5` to `0.72` for improved readability.
  - Added a subtle gold separator line below the title to give the overlay more visual structure.

## 2026-03-22 - Version 0.9.92
- **Docs / Release Baseline:**
  - Bumped TOC version to `0.9.92`.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, and `isiLive.toc` to `0.9.92`.
  - `lua tools/validate_usecases.lua` now validates `338` deterministic tests indexed and `341` scenarios across `32` modules.
- **UI / Stats / Utility Row:**
  - Roster run stats now include `Deaths` and `Kicks` alongside `DPS`, with matching tooltip lines for completed runs.
  - Added the live cooldown tracker row for `BRes` charges/cooldown and `Bloodlust`/`Heroism`/`Time Warp` countdowns.
  - The `Esc` menu now also exposes a second travel strip with `Arkantine`, `Hearthstone`, and `Housing`.

## 2026-03-22 - Version 0.9.91
- **Docs / Release Baseline:**
  - Bumped TOC version to `0.9.91`.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, and `isiLive.toc` to `0.9.91`.
  - `lua tools/validate_usecases.lua` now validates `324` deterministic tests indexed and `327` scenarios across `31` modules.

## 2026-03-22 - Version 0.9.90
- **UI / Sync UX:**
  - Sync payloads now carry freshness metadata (`capturedAt`, `source`) and HELLO also carries the sync protocol version.
  - The roster tooltip shows sync age, source, peer version, and a Shift-only debug block for per-field sync provenance.
  - The roster row shows a compact sync icon badge next to the existing addon-presence heart marker; the visible `fullsync` row marker was removed.
- **UI / Settings Defaults:**
  - `Default UI on Open` now defaults to `M2` when no explicit choice is stored, while `Last Used` stays available as the explicit fallback sentinel.
  - `Auto-Hide when Solo` now defaults to enabled until the user turns it off.
  - Blizzard Settings now also expose the optional `Column Guides` debug toggle for roster layout tuning.
- **UI / Layout Cleanup:**
  - The roster panel keeps the `M2` main-horizontal layout as the default open view, shows the status line only in `M`, and removes the combat-logging / DM-reset toggles from the main panel UI.
  - Column guides stay hidden by default and are only shown in `M` and `M2` when explicitly enabled for tuning.
  - Portal buttons keep deterministic season-slot placement, and active-target highlighting remains unchanged.
- **UI / Portal Navigator:**
  - New overlay: when the player enters the Timeways portal room, a full-screen `Portal Navigator` notice appears showing the four portal destinations (half-left, left, right, half-right) with their dungeon names; closes via right-click or the X button; respects `Show Timeways Navigator` setting (defaults enabled); retries zone detection for one second if zone text is not yet available.
  - Zone matching uses Map ID first, then falls back to normalized `GetZoneText` / `GetSubZoneText` / `GetRealZoneText` / `C_Map.GetMapInfo` name matching across all registered portal-room names.
  - Non-group-member tooltip language flag now resolves correctly when LibRealmInfo is absent: `tooltipData.unitToken` is used as the unit source even in `preferTooltipDataOnly` mode so the static realm-data fallback in `GetUnitServerLanguage` stays reachable.
- **UI / Flag Icons:**
  - Flag texture markup corrected from portrait `14:10` to landscape `12:16`, matching the native 16×12 px asset dimensions; flags no longer appear squished.
  - Flag column (`SERVER_COL`) widened from 14 to 18 px; `NAME_COL_X` shifted +4 to 93 and `NAME_COL_WIDTH` reduced by 4 to 122 to keep the overall layout width unchanged.
- **UI / Polish:**
  - Title font reduced from `GameFontHighlightHuge` (~18 px after manual correction) to `GameFontNormalLarge` (~14 px); the manual `GetFont`/`SetFont` correction block is removed.
  - H-mode button labels (`RC`, `CD`, `CD 0`) are now fully localized: locale keys `BTN_READYCHECK_SHORT`, `BTN_COUNTDOWN10_SHORT`, `BTN_COUNTDOWN_CANCEL_SHORT` added to both `enUS` and `deDE` tables; hardcoded English strings removed from button construction.
  - Typo fixed in both locale tables: `LEAD_OPTIONS` was `"M+Managment"` → `"M+Management"`.
- **Code Cleanup:**
  - Removed 12 dead `RI.H2_*` alias exports from `isiLive_roster_layout.lua` (leftover from the internal H2→M2 rename; no consumer existed).
  - Portal Navigator `FormatPortalNavigatorEntryText`: unused `direction` parameter removed; function simplified.
  - Portal Navigator `BuildPortalNavigatorConfig`: removed unused `isInCombat` and `getL` config fields (text is passed as a pre-built layout; no combat gate on the navigator); factory call cleaned up accordingly.
  - Portal Navigator state fields (`wasInPortalRoom`, `lastPortalNavigatorSignature`, `portalNavigatorRetryToken`, `portalNavigatorRetryScheduledToken`) now explicitly initialized in the state table, consistent with all other state fields.
  - `restoreRioBaseline` callback was wired into `BuildEventHandlersDepsFromContext` but never forwarded to the EventHandlers config in `ExtendEventHandlersConfig`; the missing assignment is now in place.
- **Docs + Release Baseline:**
  - Bumped TOC version to `0.9.90`.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `TODO.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.90`.
  - `lua tools/validate_usecases.lua` now validates `310` deterministic tests indexed and `312` scenarios across `30` modules.

## 2026-03-20 - Version 0.9.88
- **Runtime Bugfixes:**
  - Narrowed the `autoOpenOnQueue` gate so only queue-triggered frame opens are suppressed; dungeon-entry, key-end, and test-preview opens still show the main frame.
  - Kept pending force-refresh state row-local across group rebuilds, and blocked sync backfill from overwriting an in-flight local refresh until the inspect result arrives.
  - Reused the existing player row on leave/rebuild so pending refresh state, freshness flags, sync data, and live player data survive group churn instead of being dropped during a fresh table build.
  - The deferred `GameMenuFrame` close callback now ignores a stale reopen race so the host frame is not hidden if the menu was reopened before the timer fired.
  - Added `UnitExists`-guarded helpers around unit-token reads so missing or shifting group tokens no longer hit raw `UnitClass`, `UnitName`, `UnitLevel`, `UnitIsConnected`, `UnitGUID`, `UnitIsUnit`, `UnitIsVisible`, or `CanInspect` paths.
  - Added deterministic regression coverage for the queue gate, pending force-refresh rebuilds, the deferred game-menu close race, and the missing-unit race paths across group, inspect, locale, roster display/panel, test mode, sync, UI, and unit helpers.
- **Docs + Release Baseline:**
  - Bumped TOC version to `0.9.88`.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `TODO.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.88`.
  - `lua tools/validate_usecases.lua` now validates `293` deterministic tests indexed and `295` scenarios across `30` modules.
- **Metrics Policy:**
  - Raised the `lua tools/lua_metrics_check.lua` file hard limit to `2600` lines so the current `testmodul/isilive_test_scenarios_roster_panel.lua` size stays within the release gate.

## 2026-03-18 - Version 0.9.86
- **UI - Combat-Safe Esc Shortcut Secure Refresh:**
  - Fixed the `ADDON_ACTION_BLOCKED` path where the `Esc`-menu `ReloadUI` secure button tried to refresh click registration / secure macro attributes while the protected `GameMenuFrame` was being shown during combat.
  - Game-menu secure shortcut updates now defer blocked secure refreshes and replay them on `PLAYER_REGEN_ENABLED` instead of touching the protected button immediately.
  - Added deterministic UI regression coverage for the combat `GameMenuFrame:OnShow` path so secure click registration, secure attributes, layout refresh, and visibility refresh stay combat-safe.
- **Internal Modernization:**
  - Extracted `isiLive_factory_frame_bridge.lua` (context creation, module wiring, frame bridge) and `isiLive_factory_controllers.lua` (runtime helpers, primary/secondary controllers, minimap button) from `isiLive_factory.lua`.
  - `isiLive_factory.lua` reduced from ~1413 to ~310 lines; sub-modules export via `addonTable._FactoryInternal`.
  - Extracted `isiLive_roster_tooltip.lua` (simple tooltip API, hover tooltip, content builders) and `isiLive_roster_layout.lua` (layout modes, collapse state, system option toggles) from `isiLive_roster_panel.lua`.
  - `isiLive_roster_panel.lua` reduced from ~2259 to ~1383 lines; sub-modules export via `addonTable._RosterInternal`.
  - Added `UICommon.BACKDROP_PRESETS` and `UICommon.ApplyBackdrop(frame, presetName)` in `isiLive_ui_common.lua`, replacing ~111 redundant inline `SetBackdrop` calls across UI files.
  - Replaced 23 individual `RegisterEvent` calls in `isiLive_bootstrap.lua` with a declarative `EVENT_REGISTRY` table; gate tables for combat/hidden/test modes are now generated from the registry.
  - Added `IMPLICIT_DEPENDENCIES` for `isiLive_roster_panel.lua` and `isiLive_factory.lua` so sub-modules auto-load in tests.
  - Updated architecture source-boundary tests to reference the new split files.
- **Docs + Release Baseline:**
  - Bumped TOC version to `0.9.86`.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `TODO.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.86`.
  - `lua tools/validate_usecases.lua` now validates `287` deterministic tests indexed and `289` scenarios across `30` modules.

## 2026-03-16 - Version 0.9.85
- **Settings - Expanded Blizzard Settings + Hidden Legacy Defaults:**
  - Extended `Settings -> AddOns -> isiLive` with `UI Scale`, `Minimap Button`, `Addon Sync`, `Auto-Open on M+ Queue`, and `Auto-Hide when Solo`.
  - Temporarily hid `Name Length`, `Teleport Grid Columns`, `Show DPS Column`, `Markers: Leader Only`, and `Sound Notifications` from Blizzard Settings without removing their code paths.
  - While these controls stay hidden, runtime now keeps deterministic live defaults: fixed 12-char name truncation, legacy 2-column `Travel` grid, `DPS` column on, `Markers: Leader Only` off, and `Sound Notifications` off.
- **Runtime - Non-Challenge DPS Capture:**
  - Last-run DPS capture on instance exit now covers tracked normal and heroic party dungeons in addition to tracked non-challenge mythic exits and `M+` completions.
  - Non-challenge exit capture still uses the roster frozen on dungeon entry and retries briefly if the Blizzard damage-meter session is not finalized yet.
- **UI - Travel Grid Layout Restore:**
  - Restored the `Travel` grid to the legacy two-column layout and kept the button block aligned under the `Travel` header again.
- **Validation + Docs Sync:**
  - `lua tools/validate_usecases.lua` now validates `286` deterministic tests indexed and `288` scenarios across `30` modules.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `TODO.md`, `CHANGELOG.md`, and `isiLive.toc` to `0.9.85`.

## 2026-03-15 - Version 0.9.84
- **UI - Sync Heart Marker:**
  - Replaced the text-based `<3` addon-presence marker with a custom dark-blue 16x16 TGA heart icon (`media/heart_sync.tga`) rendered as inline texture behind synced member names.
- **UI - Background Opacity Slider:**
  - Added a `Background Opacity` slider to the Blizzard Settings canvas (`Settings -> AddOns -> isiLive`) with a configurable range from 30% to 100% (default 50%, step 5%).
  - Changing the slider live-updates the main frame, ESC panel, and settings canvas backdrop alpha; the value persists in `IsiLiveDB.bgAlpha`.
- **UI - Teleport Tooltip Dungeon Name:**
  - Center-notice teleport button tooltip now shows the dungeon name instead of the spell name, so users can identify which dungeon the teleport leads to.
- **UI - Flat Management Buttons:**
  - Replaced standard Blizzard `UIPanelButtonTemplate` management buttons (`Readycheck`, `Countdown10`, `Countdown 0`, `Share Keys`, `Refresh`) with flat dark `BackdropTemplate` buttons matching the ESC panel style, including blue hover accent borders.
- **UI - Compact Spec Labels:**
  - Tightened long spec shortcodes to a max visible width of 5 characters (for example `Resto`, `Retri`, `Boomy`, `Shado`, with hunter short labels kept as `MM`/`BM`) so the roster keeps its compact column fit.
- **UI - Combat-Safe Close Button:**
  - The main frame X (close) button now always hides the frame immediately, even during combat lockdown. Toggle via `CTRL+F9` remains combat-deferred for taint safety.
- **Sync - DPS and Location Sharing:**
  - Added `DPS:<value>` sync message: isiLive users now share their last-run DPS with group members. The DPS column falls back to synced DPS when local data is unavailable.
  - Added `LOC:<mapID>` sync message: isiLive users now share their current dungeon location. The roster portal icon uses synced location as fallback when local unit map info is unavailable.
  - Both messages are included in local snapshot sends, `REQSYNC` responses, zone/context refreshes, and self-update snapshot pushes.
  - Foreign DPS and LOC data is session-only and cleared on group leave.
- **Validation + Docs Sync:**
  - `lua tools/validate_usecases.lua` now validates `280` deterministic tests indexed and `282` scenarios across `29` modules.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `TODO.md`, and `CHANGELOG.md` to `0.9.84`.

## 2026-03-15 - Version 0.9.83
- **UI - Esc Menu + Settings Integration:**
  - Added a Blizzard `Settings -> AddOns -> isiLive` category with localized controls for language, `Advanced Combat Logging`, `DM Reset on Dungeon Entry`, `Show ESC Menu Shortcuts`, `Queue Debug Log`, and `Runtime Log`.
  - Wired the new settings canvas into the shared localization refresh path so locale changes immediately refresh both the Blizzard settings canvas and the optional `Esc`-menu shortcut strip.
  - The optional `Esc` shortcut strip now documents the actual 10 wired targets: `Professions`, `Talents`, `Spells`, `Achievements`, `Quests`, `Dungeons`, `Journal`, `Collections`, `Guild`, and a separated `ReloadUI` button.
  - The `ReloadUI` shortcut now runs through a secure macro (`/click GameMenuButtonContinue` + `/reload`) and mirrors `ActionButtonUseKeyDown` instead of dispatching an addon-side Lua reload call.
- **UI - Visual Refresh:**
  - Added a shared dark/gold/blue UI palette in `isiLive_ui_common.lua` and applied it across private tooltips, center notice, invite hint, roster hover treatment, and panel chrome.
  - Roster rows now use alternating background shading, split gradient header separators, and a softer blue hover highlight; the roster title also gets a stronger shadow treatment.
  - Center-notice teleport hover gains a subtle glow and the blinking text pulse was slowed down for readability.
- **Validation + Docs Sync:**
  - Added the new `isiLive_settings.lua` module to the `.toc` load order and bumped the addon/docs baseline to `0.9.83`.
  - `lua tools/validate_usecases.lua` now validates `275` deterministic tests indexed and `277` scenarios across `29` modules.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `TODO.md`, and `isiLive.toc` to `0.9.83`.

## 2026-03-14 - Version 0.9.82
- **UI - Combat Visibility Deferral:**
  - Main-frame show/hide requests are now deferred during combat lockdown and deterministically replayed on `PLAYER_REGEN_ENABLED`.
  - Runtime regen recovery now reapplies queued main-frame visibility before the pending post-combat height/layout refresh.
- **UI - Roster Panel Compacting:**
  - Tightened the expanded roster-panel width and shifted the right-side columns left to reduce wasted horizontal space.
  - Shortened the visible helper headers from `M+Marker` / `M+Travel` to `Marker` / `Travel`.
  - Unified member-row clearing so raid H-mode and normal rerenders use the same deterministic reset path.
- **Season Data - Midnight Season 1 Live Portal Pool:**
  - Replaced the placeholder `midnight_s1` dataset with concrete map IDs, spell IDs, display order, and localized short codes for all eight season dungeons.
  - Teleport-grid entries now keep their deterministic season slot positions even when shared spells collapse duplicate visible buttons.
- **Validation + Docs Sync:**
  - Updated combat-visibility deterministic tests and active rule mappings to the deferred regen-apply behavior.
  - Hardened `isiLive_event_handlers.lua` so the pending-visibility getter is wired as an explicit optional dependency and the regen visibility path is exercised by the deterministic handler tests.
  - Cleaned up `testmodul/isilive_test_scenarios_ui.lua` with explicit nil-guards / `rawget` access so LuaLS no longer reports false-positive `need-check-nil` / `undefined-field` diagnostics on the dynamic test fixtures.
  - Updated deterministic validator counters to `267` scenarios across `29` modules.
  - Synced `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RULES_LOGIC.md`, `TODO.md`, and `isiLive.toc` to `0.9.82`.

## 2026-03-13 - Version 0.9.81
- **Packaging - Exclude PNG Assets From Curse Release:**
  - CurseForge packaging now excludes the UI screenshot PNG files `isiLive_H_ui.png`, `isiLive_M_ui.png`, and `isiLive_V_ui.png` in addition to the already ignored logo/screenshot assets.
  - Release maintenance docs now explicitly state that PNG screenshots and logo assets stay out of packaged addon releases unless intentionally re-added.
- **Docs Sync:**
  - Synced `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `TODO.md`, and `isiLive.toc` to `0.9.81`.
  - Updated deterministic validator counters to `263` scenarios across `29` modules.

## 2026-03-13 - Version 0.9.80
- **Stats — Character-Scoped Local DPS Persistence:**
  - The persisted local last-run DPS snapshot is now stored per local character key instead of a single account-wide slot.
  - Relogging to another own character no longer shows the previous character's persisted DPS entry.
  - Foreign-player DPS remains session-only and is still never persisted.
- **UI — Hidden Roster Hover Gating:**
  - Roster row hover frames now disable mouse interaction while the roster table is hidden in compact layouts, so invisible rows no longer keep tooltip/right-click hit areas active behind the compact tool palette.
- **Stats — Safe Legacy Migration:**
  - The legacy multi-entry `playerLastRuns` store is still migrated only for the exact current local character key.
  - The old single-slot `playerLastRun` snapshot is now discarded during migration because it has no owner identity and would otherwise be guessed onto whichever character logs in first.
- **Tests:**
  - Added deterministic regression coverage for per-character local DPS persistence and for discarding ambiguous legacy single-slot DPS during migration.
- **Docs Sync:**
  - Synced `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `TODO.md`, and `isiLive.toc` to `0.9.80`.
  - Updated deterministic validator counters to `263` scenarios across `29` modules.

## 2026-03-13 - Version 0.9.79
- **UI — Static Layout Mode Buttons:**
  - Replaced the old mode-toggle behavior with three always-visible top-right mode buttons `H`, `V`, and `M`; the active layout is now indicated by a gold label while inactive modes stay grey.
- **UI — Horizontal Compact Mode Simplification:**
  - Removed the H-mode management carousel and its left/right cycle arrows.
  - Horizontal compact mode now shows all three leader actions side by side with short labels `RC`, `CD`, and `CD 0`.
  - `Share Keys` and `Refresh` remain available in expanded and vertical compact mode, but are intentionally hidden in H mode to keep the toolbar minimal.
- **UI — Raid Transition Behavior:**
  - Entering a raid-size group (`>5` members) no longer hides the addon window.
  - The roster panel now stays visible, automatically switches to H mode, keeps roster rows hidden, and prints a localized raid transition notice once per raid-size transition.
- **UI — Title Size:**
  - Reduced the addon title font size by an additional 2 pt (delta now `-4` instead of `-2`) for a cleaner compact look.
- **Bug Fix — Test Mode Cleanup:**
  - `roleButton` was re-shown for empty roster rows after `ExitTestMode()` because `UpdateCollapseState` unconditionally called `SetVisible(row.roleButton, show)`. Fixed to `SetVisible(row.roleButton, show and row.unit ~= nil)` so empty rows are never re-activated.
- **Runtime — Hidden Group Update Gate:**
  - Hidden `GROUP_ROSTER_UPDATE` processing no longer depends on small-group size and stays available for grouped non-challenge transitions, so pre-rendered roster state also remains current across raid-size transitions.
- **Refactor — Declarative Layout Visibility:**
  - Replaced the flat `SetVisible` list in `UpdateCollapseState` with a `UI_VISIBILITY_RULES` table that declares M/V/H visibility per element as explicit `true/false` columns. Adding or changing an element's per-mode visibility now requires touching only one row in that table.
  - Introduced `ui.columnButtons` as the canonical list of management-column buttons that stay outside H mode (`shareKeysButton`, `refreshButton`). `UpdateColumnPositions` now iterates `columnButtons` uniformly instead of using a separate special-case block.
- **Docs Sync:**
  - Synced `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `TODO.md`, `RULES_LOGIC.md`, and `isiLive.toc` to the current `0.9.79` runtime/UI behavior.

## 2026-03-13 - Version 0.9.78
- **Refresh Sync Request:**
  - `Refresh` sends a dedicated `REQSYNC` addon message so hidden `isiLive` peers can answer with one forced `KEY` + `STATS` snapshot even while their UI is hidden.
  - Hidden refresh replies remain locally gated on the responder: no answer while `stopped`, `paused`, or during an active Mythic+ run.
  - Added deterministic regression coverage for refresh-triggered hidden replies, blocked reply states, and hidden event-handler processing.
- **UI â€” Compact Toggle Polish:**
  - Replaced the top-right compact-mode arrow icons with direct text toggles: `V` for vertical compact, `H` for horizontal compact, and `M` in compact modes to return to the main roster view.
  - Positioned the two compact toggles directly next to each other and kept the active alternate mode accessible from each compact layout.
- **UI â€” Panel Height Adjustment:**
  - Increased the default roster-panel base height so the lower M+Marker marker buttons keep clean visual separation from the `Target Dungeon` status line.
- **Docs Sync:**
  - Synced `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `TODO.md`, and `isiLive.toc` to `0.9.78`.
  - Updated deterministic validator counters to `262` scenarios across `29` modules.

## 2026-03-13 - Version 0.9.77
- **Taint-Safe Hardening:**
  - Expanded deterministic `ADDON_ACTION_FORBIDDEN` regression coverage for deferred teleport spell attributes, insecure teleport-grid buttons, center-notice teleport handling, tank-helper secure macros, and collapse interaction while secure roster buttons already exist.
  - Added explicit combat-path regression tests so secure/insecure button boundaries are exercised before release instead of only being inferred from higher-level UI tests.
- **Code Review — Bug Fixes & Correctness:**
  - `isiLive_runtime_state.lua`: `GetSnapshot()` was returning a live reference to the internal roster table instead of a copy; callers holding a snapshot could observe subsequent group changes. Fixed by returning a shallow copy via `CopyTableShallow`.
  - `isiLive_units.lua`: Dead entry `["stärkung"]` in `SPEC_SHORT_LABELS` was never reachable because `NormalizeSpecKey` converts `ä→a` before the lookup; corrected key to `["starkung"]`. Also fixed the UTF-8 fallback path in `TruncateName` to roll back continuation bytes (`0x80–0xBF`) at the cut point so the returned string is always valid UTF-8.
  - `isiLive_controller_wiring.lua`: `timerAfter` callbacks were silently swallowing all runtime errors. Wrapped callbacks in `xpcall` with traceback and forwarded failures to WoW's global error handler (`geterrorhandler()`) so crashes surface as the standard red error frame.
  - `isiLive_highlight.lua`: `TryGet()` used `rawget(obj, key) or nil`, which coerces `false` to `nil`. An inactive LFG listing (`active = false`) was therefore indistinguishable from an absent field, causing `ResolveActiveListingTarget` to skip the inactive-listing guard. Fixed by using explicit `~= nil` checks so `false` propagates correctly.
  - `isiLive_stats.lua`: `localPlayerKey` was resolved and `MigrateAndPrunePersistentPlayerStats` was called at Lua file-execution time — before `ADDON_LOADED` fires, before SavedVariables are restored, and before `UnitExists("player")` is reliable. Both operations are now deferred via a lazy `EnsureInitialized()` called on the first `RecordRun` or `GetPlayerLastRunDps` invocation, which always happens after `ADDON_LOADED`.
  - `isiLive_event_handlers_queue.lua`: `ctx.setPendingQueueJoinInfo(nil)` appeared in both the `if` and `else` branches of `LFG_LIST_ACTIVE_ENTRY_UPDATE`. Deduplicated to a single unconditional call after the branch.
- **Code Review — Documentation & Dead-Path Annotation:**
  - `isiLive_group.lua`: Added inline comment to `PruneGhosts` explaining the intentional design: ghosts are only pruned when the group is at full capacity (5 active members), so a 4-member group still shows prior-member history.
  - `isiLive_sync.lua`: Added module-level comment documenting the deliberate Singleton pattern and explaining how `ClearKnownUsers()` scopes the session-global state.
  - `isiLive_locale.lua`: Added comment to `LocaleToLanguageTag` documenting that `KR`, `CN`, and `TW` tags are recognized but have no flag assets in `LANGUAGE_FLAG_TEXTURE_BY_TAG`.
- **Code Review — Round 2 Follow-Up:**
  - `isiLive_locale.lua`: `GetLanguageFlagMarkup` now shows the language tag as grey text (e.g. `KR`, `CN`, `TW`) instead of `??` when no flag texture exists, giving Korean/Chinese/Taiwanese players a recognizable label.
  - `isiLive_keysync.lua`: `ForceRefreshSyncState` was clearing the player roster entry's key fields in the loop and immediately overwriting them after the loop. The redundant loop-side clear is removed; the player's key is now set only once from the live keystone snapshot after the loop.
- **Code Review — Regression Tests:**
  - `isilive_test_scenarios_highlight.lua`: Added scenario verifying that a `C_LFGList.GetActiveEntryInfo` struct response with `active = false` correctly propagates through `GetNormalizedActiveEntryInfo` and causes `ResolveActiveListingTeleportSpellID` to return `nil`. Directly covers the `TryGet` false-propagation fix.
  - `isilive_test_scenarios_stats.lua`: Added scenario asserting that `CreateController` alone does not touch `IsiLiveDB` (migration is deferred). Updated the legacy-migration scenario: pruning assertions now run after the first `GetPlayerLastRunDps` call to match the lazy-init contract.
- **UI — M+Marker Column:**
  - Renamed "Tank Helper" to "M+Marker" in the roster panel header (`isiLive_texts.lua`, `isiLive_roster_panel.lua`).
  - Corrected the header label position: the `TOPRIGHT`-anchored `FontString` is now placed at `xPos + 18` so its visual centre aligns with the button column centre, matching the layout of all other column headers.
- **UI — World Marker Buttons Fix:**
  - Replaced the `/wm`/`/cwm` macro approach with the native `SecureActionButtonTemplate` attribute type `"worldmarker"`. Left-click uses `action1 = "set"`, right-click uses `action2 = "clear"` — no cursor-placement step required, marker is placed immediately.
  - Expanded the M+Marker palette from 5 to all 8 Blizzard world markers (`Square`, `Triangle`, `Diamond`, `Cross`, `Star`, `Circle`, `Moon`, `Skull`) and compacted the icon spacing so collapsed mode still fits cleanly.
  - Restored `RegisterForClicks("AnyUp", "AnyDown")` to match the required registration for the `worldmarker` attribute type.
- **UI - Second Compact Layout:**
  - Added a second collapse toggle next to the existing arrow. The original arrow still switches to the vertical compact palette; the new down-arrow switches to a slim horizontal compact layout.
  - Horizontal compact mode hides the roster/table area and `M+Travel`, keeps only `M+Managment` plus `M+Marker`, places all 8 marker icons next to each other in one row, and uses left/right cycle arrows so only one management action button is shown at a time.
  - Fixed the horizontal-layout restore bug: marker icons now return to their original vertical stack after switching back to the normal roster view.
  - Added deterministic layout and taint regressions for the new horizontal compact mode, including the combat-ignore path for the second collapse button, the management-action carousel, and the marker restore path.
- **UI - Compact Mode Polish:**
  - Vertical compact mode now also hides the title, header separator, and bottom version line, matching the stripped-down tool-palette intent.
  - Horizontal compact mode width was reduced to the minimum practical toolbar width, gained slightly larger carousel arrows and marker buttons, hides the header separator and bottom version line, and keeps a bit more air between the management carousel and the marker row.
- **Docs Sync:**
  - Synced `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `TODO.md`, and `isiLive.toc` to `0.9.77`.
  - Updated deterministic validator counters to `258` scenarios across `29` modules.

## 2026-03-11 - Version 0.9.75
- **Tank Helper:**
  - Added a vertical bar of 5 secure world marker buttons (Blue Square, Green Triangle, Purple Diamond, Red Cross, Yellow Star) to the right of the DPS column.
  - Left-Click places the world marker (`/wm X`), Right-Click clears it (`/cwm X`).
- **Mini Mode (Collapse):**
  - Added a collapse toggle button (`<` / `>`) next to the top-right close button.
  - Toggling "Mini Mode" hides the roster table (left side) and `M+Travel`, while keeping Tank Helper and M+ Management visible.
  - Collapse state is persisted in `IsiLiveDB.rosterCollapsed` and restored on reload.
  - When collapsed, the window will not auto-close on key start or raid join, serving as a persistent compact tool palette.
- **Docs Sync:**
  - Synced all documentation files to `0.9.75` and updated the UI ASCII sketch in `ARCHITECTURE.md`.

## 2026-03-11 - Version 0.9.74
- **Manual Role Markers:**
  - Replaced the restricted "Auto-Mark" feature with interactive secure role icons in the roster.
  - Clicking the Tank icon securely applies **Blue Square** ({rt6}).
  - Clicking the Healer icon securely applies **Green Triangle** ({rt4}).
  - Removed the "Auto-Mark T/H" toggle from system options; the icons are now always interactive when a role is assigned.
- **Taint-Safe Hardening:**
  - Added a new automated test suite (`isilive_test_scenarios_taint.lua`) to proactively prevent `ADDON_ACTION_FORBIDDEN` errors.
  - The new "Härtetest" simulates a tainted environment and ensures that critical code paths (Group, Roster, Teleport, Bindings) do not call protected WoW APIs from insecure contexts.
- **Docs Sync:**
  - Synced `CHANGELOG.md`, `README.md`, `RELEASE.md`, `ARCHITECTURE.md`, `TODO.md`, and `USECASES.md` to `0.9.74`.

## 2026-03-11 - Version 0.9.73
- **Roster UI:**
  - Offline group members are now rendered in grey in the roster, matching ghost-style visual de-emphasis.
  - Ready-check status colors no longer override the offline-grey state.
- **Tests + Validation:**
  - Added deterministic coverage for offline roster-member grey rendering in `isilive_test_scenarios_roster_panel.lua`.
  - `tools/validate_usecases.lua` now validates `246` deterministic scenarios across `26` modules.
- **Docs Sync:**
  - Synced `CHANGELOG.md`, `README.md`, `RELEASE.md`, `ARCHITECTURE.md`, and `USECASES.md` to `0.9.73`.

## 2026-03-11 - Version 0.9.72
- **Auto-Mark Hotfix:**
  - Removed the forbidden direct `SetRaidTarget()` runtime path that triggered `ADDON_ACTION_FORBIDDEN` in retail.
  - Added an explicit runtime capability gate so Auto-Mark only touches raid-marker APIs when that API path is deliberately allowed; the default retail runtime now skips all marker API calls instead of tainting.
  - Kept the anti-spam behavior intact for explicitly allowed marker runtimes by still skipping units that already have the correct marker.
- **Rules + Validation Sync:**
  - Updated `RULES_LOGIC.md` rule `39` to the machine-checkable contract: markers require both the user toggle and an explicitly allowed marker API runtime; without that allowance, no marker API calls may occur.
  - Added deterministic coverage for the protected-API guard in `isilive_test_scenarios_group.lua`.
  - `tools/validate_usecases.lua` now validates `245` deterministic scenarios across `26` modules.
- **Docs Sync:**
  - Synced `CHANGELOG.md`, `README.md`, `RELEASE.md`, `ARCHITECTURE.md`, and `USECASES.md` to `0.9.72`.

## 2026-03-11 - Version 0.9.71
- **Runtime Hardening:**
  - Rolled the finalized `0.9.70` fix set forward into the next stable release after the archived accidental `0.9.70` package/tag.
  - Applied `pcall` protection to critical WoW API interactions in `isiLive_queue.lua`, `isiLive_spell_utils.lua`, `isiLive_units.lua`, `isiLive_inspect.lua`, `isiLive_status.lua`, and `isiLive_controller_wiring.lua` to prevent Lua errors during transient API failures or race conditions.
  - Added explicit `UnitExists` guards before unit-token API calls in `isiLive_units.lua` to handle group-member transitions more safely.
  - Corrected the argument order for `C_DamageMeter.GetCombatSessionFromType` in `isiLive_stats.lua` and hardened `IsUnitInspectable` in the inspect loop against API faults.
- **Tests + Validation:**
  - Added deterministic test coverage in `isiLive_test_scenarios_roster_display.lua` for roster value formatting, truncation rules, and key display logic.
  - Added deterministic `UnitExists` guard coverage in `isiLive_test_scenarios_units.lua` and inspect robustness scenarios for API error handling.
  - Consolidated `Roster.BuildDisplayData` tests into the dedicated roster-display module to remove duplicate test names and keep validation ownership clear.
  - `tools/validate_usecases.lua` now validates `244` deterministic scenarios across `26` modules.
- **Release Hardening:**
  - Deleted the accidental stable tag `isiLive_release_0.9.70` from Git and archived the corresponding CurseForge `0.9.70` artifact.
  - Documented the mandatory order `push main -> wait for green Lua Check on the exact commit -> create release tag`.
  - Documented rollback handling for accidental release tags and clarified that deleting a Git tag does not remove an already-created CurseForge artifact.
- **Docs Sync:**
  - Synced `CHANGELOG.md`, `README.md`, `RELEASE.md`, `TODO.md`, `WARTUNG.md`, `ARCHITECTURE.md`, and `USECASES.md` to `0.9.71`.
  - Removed a leftover conflict marker from `ARCHITECTURE.md`.

## 2026-03-10 - Version 0.9.70
- **Code Review & Robustness:**
  - **Defensive API Calls:** Applied `pcall` protection to critical WoW API interactions in `isiLive_queue.lua`, `isiLive_spell_utils.lua`, `isiLive_units.lua`, `isiLive_inspect.lua`, `isiLive_status.lua`, and `isiLive_controller_wiring.lua` to prevent Lua errors during transient API failures or race conditions.
  - **Unit Safety:** Added explicit `UnitExists` checks in `isiLive_units.lua` loops to handle group member transitions more gracefully.
  - **Damage Meter API:** Corrected the argument order for `C_DamageMeter.GetCombatSessionFromType` in `isiLive_stats.lua` to ensure reliable session retrieval.
  - **Inspect Stability:** Hardened `IsUnitInspectable` in the inspect loop against potential API errors.
- **Test Coverage:**
  - Added a new deterministic test module `isiLive_test_scenarios_roster_display.lua` covering roster value formatting, truncation rules, and key display logic.
  - Added robustness scenarios for API error handling in the inspect controller.
  - Added a new deterministic test module `isilive_test_scenarios_units.lua` to validate `UnitExists` guards.
  - Consolidated all `Roster.BuildDisplayData` unit tests into `isilive_test_scenarios_roster_display.lua` to resolve duplicate test names.
  - Deterministic validator coverage is now `242` scenarios across `26` modules.
- **Validation + Docs Sync:**
  - Synced `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `RELEASE.md` to `0.9.70`.

## 2026-03-10 - Version 0.9.69
- **Raid Notice in Roster Panel:**
  - Integrated the raid notice directly into the Roster Panel UI. When the group size exceeds 5 members, the roster rows are hidden and a localized "Raid warning" is displayed in the center of the roster area.
  - Removed the temporary `Center Notice` fallback for raid groups, consolidating all raid feedback into the main Roster Panel.
- **Auto-Marker Feature:**
  - Finalized the Auto-Marker feature for parties: Tanks are marked with **Blue Square** ({rt6}) and Healers with **Green Triangle** ({rt4}).
  - Removed the group leader restriction: any party member (regardless of lead status) can now automatically apply markers to group members.
  - Added an anti-spam check: the addon now verifies existing raid target indices before calling `SetRaidTarget` to avoid redundant API traffic.
  - Auto-marking logic is strictly scoped to 5-man parties; raid groups remain ignored for marking.
- **Architecture & Refactoring:**
  - **Dependency Injection Framework:** Refactored the `isRaidGroup` status to be passed through the factory context and controller wiring, ensuring clean separation between group state logic and UI rendering.
  - **Code Cleanup:** Removed deprecated `showCenterNotice` wiring and logic from `isiLive_group.lua` and `isiLive_controller_wiring.lua` in favor of the new integrated UI label.
  - **Mocking Strategy:** Standardized UI element mocks in the test suite (adding `Hide`/`Show` to `CreateFontString` mocks) to better reflect actual WoW API behavior and improve test reliability.
- **Robustness & UI:**
  - Improved `mainFrame:GetWidth()` robustness in `isiLive_roster_panel.lua` to handle mocked frame environments in tests.
  - Fixed the factory/runtime wiring regression for Auto-Mark state: the shared runtime state now forwards `getAutoMarkEnabled` / `setAutoMarkEnabled` back into roster-panel and controller wiring, preventing the startup crash in `isiLive_controller_wiring.lua`.
  - Reworked the bottom-left system-toggle layout so `Combat Logging`, `Auto-Mark T/H`, and `DM Reset on Entry` keep a fixed visible gap and no longer run into each other.
- **Validation + Docs Sync:**
  - Deterministic validator coverage is now `234` scenarios across `24` modules.
  - Synced `CHANGELOG.md`, `README.md`, and `ARCHITECTURE.md` to the current runtime/UI state.


## 2026-03-09 - Version 0.9.68
- **Post-Run DPS Capture Reliability:**
  - `M+` completed-run DPS capture now retries briefly when the Blizzard `C_DamageMeter` session is not ready on the first completion/reset event.
  - Tracked `M0` exit snapshots now use the same short retry path, so delayed damage-meter availability no longer leaves the roster `DPS` column empty permanently for that run.
  - Run capture still stays deterministic: no guessed player mapping, no duplicate completed-run records, and no persistent foreign-player history.
- **Validation + Docs Sync:**
  - Deterministic validator coverage is now `228` scenarios across `24` modules.
  - Synced `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, and `TODO.md` to `0.9.68`.

## 2026-03-09 - Version 0.9.67
- **Demo/Test Mode:**
  - `CTRL+ALT+F9` / `/isilive test` now use the exact same full dummy preview path as `/isilive testall`.
  - Both demo entries show a visible ghost/leaver row in the dummy roster so leave-state UI can be previewed without a live group.
  - Dummy preview rosters are rebuilt from fresh copies, so repeated refreshes do not accumulate mutated demo data.
- **Group Leave UI:**
  - Leaving or getting kicked from a normal party no longer auto-closes the main UI.
  - The local player stays active in the roster while former party members remain as grey ghost rows.
- **Midnight S1 Preparation:**
  - Added skeleton structure in `isiLive_season_data.lua` for the 8 upcoming Midnight Season 1 dungeons (Algeth'ar Academy, Magisters' Terrace, Maisara Caverns, Nexus-Point Xenas, Pit of Saron, Seat of the Triumvirate, Skyreach, Windrunner Spire).
  - Drafted English and German short codes for the new dungeons. MapIDs and SpellIDs remain commented out placeholders until the expansion hits the PTR.
- **Cleanup:**
  - Completely removed `tww_s3` data from `isiLive_season_data.lua` and replaced all test and documentation references with the new season context.
- **Feature:** Roster members now remain as greyed-out "ghosts" in the UI when they leave or the group disbands. Ghost rows are pruned deterministically on rejoin, fresh group join, or full-group rebuild instead of disappearing immediately.
- **Fix:** Corrected Midnight Season 1 M+ launch date from June 25, 2026, to March 25, 2026.
- **Hotfix:** `isiLive_roster_panel.lua` – Fixed a nil-crash related to `displayData.readyCheckMarkup` by adding an `or ""` fallback. This field was removed from `BuildDisplayData` in this session, missing a nil-check on the caller's side.
- **Code Review Pass 1 – Core Architecture Fixes:**
  - Extracted a single `GetL` helper in `isiLive.lua` to replace 7 duplicated `getL = function() return L end` lambdas.
  - Added `GetWasGroupLeader` wrapper for consistency with the existing `SetWasGroupLeader` wrapper.
  - Fixed duplicate `isInCombat` lambda that was defined twice in the main file.
  - Removed unnecessary `local _ = ...` assignments from fallback closures in `isiLive_events.lua`.
  - Fixed asymmetric `onEvent` handling in `isiLive_bootstrap.lua` (`BindMainFrameScripts`).
  - Removed unnecessary lambda wrapper around `opts.getUnitServerLanguage` in `isiLive_context_helpers.lua`.
  - Removed dead `ctx.dispatch` fallback code in `isiLive_config_builders.lua`.
  - Fixed `pcall` return type lint warning in `isiLive_event_handlers_runtime.lua`.
  - Added clarifying comment for intentional multiple `applyHotkeyBindings` calls on startup.
  - Added `CreatePrivateTooltip`, `PreparePrivateTooltip`, `HidePrivateTooltip` to `REQUIRED_FUNCTIONS` guards.
  - Renamed `self` → `frame` in challenge handler functions for consistency with WoW naming conventions.
- **Code Review Pass 2 – Module-Level Fixes:**
  - `isiLive_inspect.lua`: Wrapped `C_PaperDollInfo.GetInspectItemLevel` in `pcall` to prevent crash if API is absent. Moved `sendOwnKeySnapshot` from a public controller field to a local closure; exposed it via `TriggerOwnKeySnapshot()` method.
  - `isiLive_status.lua`: Fixed `GetDungeonDifficultyLabel` (internally calls `GetInstanceInfo`) being called twice inside `ConfirmAndShowNotice`; now called once, all 6 return values unpacked together.
  - `isiLive_highlight.lua`: Fixed `TryGet` calling `rawget(obj, nil)` when passed `nil` keys — guarded each key before calling `rawget`.
  - `isiLive_roster.lua`: Removed dead `readyCheckMarkup` variable (always `""`, never populated). Fixed `RAID_CLASS_COLORS` lint warning via `rawget(_G, ...)`.
  - `isiLive_log_buffer.lua`: Fixed O(n²) overflow trimming loop — now O(n) via in-place shift instead of repeated `table.remove(logs, 1)`.
  - `isiLive_units.lua`: Added `["stärkung"] = "Aug"` (DE: Augmentation Evoker) to spec short-label table.
  - `isiLive_spell_utils.lua`: Added explanatory comment for `issecretvalue` WoW-internal bug workaround.
  - `isiLive_queue_flow.lua`: Added comment explaining `AnnounceQueuedGroupJoin` forward-declaration pattern.
  - `isiLive_sync.lua`: Added comment noting `NormalizePlayerKey` is stricter than `NormalizeName` in `stats.lua` (potential key divergence on special-character realms).
  - `isiLive_keysync.lua`: Added comment documenting that `SeasonData.NormalizeMapID` is applied here (on read) and again in `sync.lua NormalizeKeyPayload` (idempotent).
  - `isiLive_stats.lua`: Added comment flagging potential parameter order question for `C_DamageMeter.GetCombatSessionFromType`.
- The code review items above do not change runtime behavior; they are internal code quality improvements.

## 2026-03-08 - Version 0.9.66
- **Tooltip Isolation Hardening:**
  - Roster row hover, roster control buttons, teleport grid buttons, and center-notice teleport hover now all use isolated `isiLive` tooltip frames instead of the shared Blizzard `GameTooltip`.
  - This removes the remaining shared `GameTooltip` anchor/unit path from `isiLive` and reduces exposure to external tooltip taint and anchor-family conflicts.
- **Tooltip Runtime Fixes:**
  - Fixed the post-isolation load-order regression by loading `isiLive_ui_common.lua` before tooltip consumers in `isiLive.toc`.
  - Fixed private tooltip rendering so isolated tooltips show their text content again instead of appearing empty.
  - Tightened private tooltip layout: narrower width, left-aligned wrapped text, and height derived from real line height so long strings no longer bleed past the tooltip edge.
- **Validation + Docs Sync:**
  - `lua tools/validate_usecases.lua` remains green at `221` deterministic scenarios across `24` modules.
  - Synced `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, and `TODO.md` to `0.9.66`.

## 2026-03-07 - Version 0.9.65
- **Post-Run DPS Snapshot:**
  - The addon now reads the Blizzard `C_DamageMeter` session after a dungeon run and exposes the latest run DPS for the current roster without guessing.
  - Supported completion paths are now `Mythic Plus` via `CHALLENGE_MODE_COMPLETED/RESET` and `Mythic 0` via tracked mythic non-challenge dungeon exit.
  - Roster tooltips now show a localized `Last run DPS` line when a matching post-run damage-meter value exists.
  - The main roster now includes a dedicated `DPS` column that renders the same latest completed-run snapshot.
  - Foreign-player DPS snapshots are now session-only and are no longer persisted to SavedVariables; only the local player's own last-run DPS remains persistent.
- **Stats Storage Pruning:**
  - Removed persistent foreign-player history from `IsiLiveDB.stats` so the database cannot grow unbounded with old group members.
  - Deprecated `Runs together` tooltip history has been removed together with the foreign-player persistence it relied on.
  - Removed the unused persistent dungeon-counter path and dead stats count APIs so the stats layer only keeps the bounded last-run DPS snapshot.
- **Roster Tooltip Expansion:**
  - Roster tooltips now also show the player's `Level` and server-language abbreviation (`DE`, `EN`, `FR`) in addition to the synced addon stats.
- **Roster Column Compression:**
  - The server-language column now renders only the flag icon, and its header is intentionally blank so no `....` placeholder appears.
  - The `Spec` column is now anchored further left, player names are clamped to Blizzard's 12-character limit, and spec labels are clamped to 5 characters.
  - `Key`, `iLvl`, `RIO`, and `DPS` column widths are now constrained to their real display maxima to free as much space as possible for the DPS snapshot.
  - Visible key short codes now allow up to 4 letters.
  - Unknown or unresolved dungeons no longer fall back to numeric map IDs in the roster or key-share text; the addon only shows fact-based short codes from season data.
- **Demo/Test Mode Fixes:**
  - Pressing `Refresh` while demo/test mode is active now rebuilds the full dummy roster instead of falling back to the live refresh path and showing only the local player.
  - Demo roster data now uses the canonical hunter spec name `Marksmanship`, so short-label resolution stays stable in preview mode.
- **Planning Docs:**
  - The hardcut rename plan in `TODO_RENAME.md` was moved from `after v0.9.65` to `after v0.9.70`.
  - Added `WARTUNG.md` as a maintenance runbook for long breaks and excluded it from CurseForge packaging.
- **Validation + Docs Sync:**
  - Deterministic validator coverage increased to `221` scenarios across `24` modules.
  - Synced `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `TODO.md`, `TODO_RENAME.md`, and `WARTUNG.md` to the current runtime/release state.
- **Post-Review Fixes:**
  - `M0` snapshots no longer flush early on tracked mythic subzone/map changes; the frozen roster now stays bound to the original dungeon entry until real instance exit.
  - `M0` snapshots now hydrate from the first reliable post-entry group roster update when zoning finishes before the roster is fully available.
  - Unknown tooltip key short codes now stay unresolved as `?` instead of falling back to numeric `mapID` values.
  - Roster row hover now uses a private `isiLive` tooltip instead of the shared Blizzard `GameTooltip`, removing the risky `SetUnit`/global-hide path that could collide with external tooltip taint.
  - Roster control buttons, teleport buttons, and center-notice teleport hover now also use isolated `isiLive` tooltip frames instead of the shared Blizzard `GameTooltip`.
  - Fixed addon load order regression by moving `isiLive_ui_common.lua` ahead of tooltip consumers in `isiLive.toc`.
  - Internal teleport wiring now uses season-agnostic resolver names; legacy `Season3` exports remain only as compatibility wrappers.
  - Runtime event wiring now forwards `recordRun` correctly from the composition root, hidden addon-sync/group updates may pre-render event-driven UI state without polling, and dead queue/runtime wiring was removed.
  - Status-line `M+` text now safely handles missing Blizzard challenge APIs instead of calling `C_ChallengeMode` unguarded.
  - Hidden-gate policy for background sync is now owned centrally by `ConfigBuilders.BuildGateOpts(...)` instead of being patched later in `RuntimeSetup`.
  - The root now de-duplicates the shared `GROUP_ROSTER_UPDATE` trigger helper and trims unused `RuntimeSetup` return payloads.
  - `LeaderWatch` now keeps `wasGroupLeader` synchronized even while the main UI is hidden, without firing hidden notices or chat output.

## 2026-03-06 - Version 0.9.64
- **Midnight S1 Pre-Season Portal Messaging:**
  - Kept the active season dataset on `midnight_s1` pre-season mode.
  - `M+Travel` now shows a localized Midnight Season 1 start message instead of stale `tww_s3` portal icons when no active portal pool exists.
  - The status line keeps the matching pre-season placeholder so the empty portal area reads as intentional, not broken.
- **Roster Interaction Safety:**
  - Removed roster-row left-click targeting from the insecure row UI path.
  - Right-click whisper remains available.
  - Added deterministic regression coverage so protected `TargetUnit` calls do not reappear through the row interaction path.
- **Packaging + Planning Docs:**
  - Excluded `TODO_RENAME.md` from CurseForge packaging via `.pkgmeta`.
  - Added `TODO_RENAME.md` as the hardcut rename runbook for the planned rename migration after `v0.9.65`.
- **Validation + Docs Sync:**
  - Deterministic validator coverage increased to `188` scenarios across `24` modules.
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `RULES.md`, and `TODO.md` to the current runtime/release state.

## 2026-03-05 - Version 0.9.63
- **Roster Tooltip Positioning:**
  - Forced roster tooltips to anchor at the mouse cursor (`ANCHOR_CURSOR`) instead of using the default UI position.
  - This keeps the tooltip near the mouse pointer for better context visibility.
  - Updated control buttons (Refresh, Readycheck, Share Keys) to also use `ANCHOR_CURSOR` for consistency.
- **"Runs Together" Tracker:**
  - The addon now tracks how often you have completed a dungeon with specific players.
  - If you have played with a group member before, a line `Runs together: X` appears in their roster tooltip.
  - Data is stored locally in `IsiLiveDB` and updates automatically on dungeon completion.
- **Ghost Members (Roster Persistence):**
  - Players leaving the group now remain visible as "ghosts" (greyed out) until their slot is filled or the UI is reloaded.
  - This improves context when forming groups, preventing rows from jumping immediately upon a leave.
- **Ghost Member Stability:**
  - Fixed data loss when group members shift slots (e.g. `party2` becomes `party1`).
  - Fixed duplicate ghost entries appearing during slot shifts.
  - RIO, iLvl, and Key data now correctly persists when a player moves slots or rejoins the group.
  - Ghosts are now reliably pruned when the group becomes full (5 members).
- **Background Data Sync:**
  - Relaxed Rule 28 ("Sparflamme"): Data synchronization (Addon messages, Roster updates) now continues in the background while the main window is hidden.
  - UI rendering remains suspended to conserve performance.
  - This ensures data (Keys, RIO, iLvl) is immediately available upon opening the window, improving responsiveness.
- **Smart Self-Update:**
  - The addon now automatically broadcasts a data snapshot (Key/Stats) when the player's own iLvl, RIO, or Spec changes (detected via inspect loop).
  - Previously, updates were only sent on group join, key end, or manual refresh.
  - This ensures the group always sees your current gear/score without manual intervention.
- **Roster Interaction:**
  - **Right-Click** on a roster row now opens a whisper to the player.
  - This adds direct whisper access from the isiLive list.
- **Ready Check Indicators:**
  - The roster now colors player names to indicate status during a ready check.
  - Green for "Ready", Red for "Not Ready", and Yellow for "Waiting".
  - This replaces the previous dot indicator for a cleaner look.
- **"At Dungeon" Indicator:**
  - Players in the group who are already inside the target dungeon are now marked with a summon-portal icon next to their name.
  - This provides a quick visual cue for who is ready at the summoning stone.
- **Midnight S1 Pre-Season Mode:**
  - Switched the active season dataset to `midnight_s1` pre-season mode instead of continuing to expose stale `tww_s3` portals.
  - `M+Travel` now shows an empty active portal pool until Midnight Season 1 dungeon/teleport mappings are complete.
  - The status line now explains the empty pool via a pre-season target-dungeon placeholder instead of looking broken.
  - The portal area itself now shows a `Midnight S1` season-start message instead of rendering obsolete `tww_s3` portal icons.
- **Architecture Refactor:**
  - Introduced central runtime state in `isiLive_runtime_state.lua` for roster, queue target, runtime flags, ready-check state, and RIO baseline ownership.
  - Reduced `isiLive.lua` toward a composition root by moving mutable runtime concerns behind the runtime-state controller.
  - Split `isiLive_event_handlers.lua` into lifecycle-specific modules: `isiLive_event_handlers_runtime.lua`, `isiLive_event_handlers_queue.lua`, and `isiLive_event_handlers_challenge.lua`.
  - Simplified wiring by adding context-based controller factories in `isiLive_controller_wiring.lua` and consuming them from `isiLive_runtime_setup.lua`.
- **Architecture Rule Gate:**
  - Added `ARCHITECTURE_RULES.md` as a dedicated contract source for structural module boundaries.
  - Added `tools/validate_architecture_rules.lua` and deterministic architecture scenarios for composition-root ownership, lifecycle aggregation, context-based wiring, runtime-state ownership, and focused config builders.
  - `tools/validate_usecases.lua` now validates both runtime rules and architecture rules before executing the full deterministic gate.
- **Runtime Fixes:**
  - Ready-check state is now fully wired through bootstrap, gating, event handling, and roster rendering.
  - Ghost roster members are excluded from forced inspect refresh paths so their cached data is preserved.
  - Completed-run recording is deduplicated across `CHALLENGE_MODE_COMPLETED` and `CHALLENGE_MODE_RESET`.
  - Removed insecure roster-row left-click targeting because direct `TargetUnit` calls from the current row UI can taint into protected-action errors ingame.
- **Test Coverage:**
  - Added dedicated `RuntimeState` regression scenarios.
  - Added dedicated architecture rule scenarios and validator coverage.
  - Test harness now supports implicit addon-module dependencies for aggregated controller modules.
  - Deterministic validator coverage increased to `186` scenarios across `24` modules.
- **Documentation:**
  - Updated `RULES_LOGIC.md` with Rule 32 (Ghost Member), Rule 33 (At Dungeon), Rule 34 (Ready Check), and updated Rule 28 (matching exact test names).
  - Added `ARCHITECTURE_RULES.md` and aligned docs with the architecture gate.
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, and `TODO.md` to 0.9.63.
  - Validator count increased to `186` deterministic scenarios across `24` modules.

## 2026-03-05 - Version 0.9.62
- **Bug Fix: Rich Roster Tooltip Guard:**
  - `ShowRosterInfoTooltip` now only fires when actual addon-synced data is present (`class`, `spec`, `iLvl`, or `RIO`).
  - Previously, players with only name/key data (no addon sync yet) could trigger the isiLive tooltip instead of the Blizzard unit tooltip, and double-anchor `GameTooltip`.
- **CI Fix: `SLASH_ISILIVE2` in luacheck whitelist:**
  - `.luacheckrc` globals list was missing `SLASH_ISILIVE2`. Lua Check CI gate is now fully green.
- **Off-Season Mode Infrastructure:**
  - Added `SeasonData.HasActiveDungeons()` helper: returns `true` when the active season has at least one mapped dungeon.
  - `MaybeShowNonMythicDungeonEntryNotice` is now gated in `isiLive_controller_wiring.lua`: the warning is suppressed automatically when `HasActiveDungeons()` is `false`.
  - Teleport grid already handles empty season mapping gracefully (renders no buttons). No extra code needed.
  - To activate off-season mode: set `ACTIVE_SEASON_ID` to an empty season scaffold (e.g. `midnight_s1` before data is ready).
- **Test Coverage:**
  - New deterministic test: `ADDON_LOADED` restores Rio baseline from `IsiLiveDB` (total: `156` scenarios across `21` modules).
  - Nil-guard fix for `delayedCallback` in event handler test.
  - Replaced broad `need-check-nil` diagnostic suppression in commands test with targeted `executor` type guard.

## 2026-03-05 - Version 0.9.61
- **`/isk` Slash Alias:**
  - `/isk` is now a registered shorthand for `/isilive`. All sub-commands work identically.
- **Persistent Rio Baseline:**
  - The Rio baseline captured on `CHALLENGE_MODE_START` is now persisted in `IsiLiveDB.rioBaseline` and restored on `ADDON_LOADED`.
  - A UI reload mid-session no longer loses the baseline. Delta display still only activates after a key completes and the post-run refresh fires.
  - Clearing the baseline (group leave, new key start) also clears the saved value from `IsiLiveDB`.
- **Rich Roster Hover Tooltip:**
  - Hovering a roster row now shows an isiLive-data tooltip: name (class-colored), realm, spec, iLvl, Rio, and key (if any).
  - Falls back to the WoW unit tooltip then plain name if isiLive data is unavailable.
- **Internal Refactor: Debug Log Command Handlers:**
  - Extracted shared `HandleDebugLogCommand` in `isiLive_commands.lua` to eliminate duplication between `HandleLogCommand` and `HandleQDebugCommand` (~90 lines → ~55 lines).
  - Minor inconsistency in qdebug `"cleared"` message normalized to match shared label pattern.
  - No user-facing behaviour change.

## 2026-03-05 - Version 0.9.60
- **Dungeon Announce Spam Softening:**
  - Grouped queue announces are now deduplicated by signature without a time-window fallback, so identical dungeon announce blocks do not re-fire later from timing jitter.
  - Dedup state is reset when no group is active, so the same dungeon can be announced again on a real leave/rejoin cycle.
  - Added deterministic QueueFlow coverage for "same target beyond debounce window" and "re-announce after regroup".
- **Release Metadata + Docs Sync:**
  - TOC version bumped to `0.9.60`.
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, and `TODO.md` to `0.9.60`.
- **Validation:**
  - `lua tools/validate_usecases.lua` passes with `155` deterministic scenarios across `21` modules.

## 2026-03-02 - Version 0.9.59
- **CurseForge Review Softening:**
  - Removed the remaining automatic Blizzard-CVar enforcement from runtime startup and challenge-start flows.
  - Added passive main-UI checkboxes for `advancedCombatLogging` and `damageMeterResetOnNewInstance`; the UI mirrors live Blizzard settings and writes only on explicit user clicks.
  - Reduced review-risk sync chatter further: no extra `HELLO` burst on main-window open, no delayed second sync wave on `PLAYER_ENTERING_WORLD`, and no `KEY/STATS` re-publish on incoming `HELLO`.
- **UI / Runtime Cleanup:**
  - Removed the stale `sendIsiLiveHello` dependency from the event-handler wiring path.
  - Added a lightweight live refresh watcher so the new Blizzard-setting checkboxes re-read current CVar state while the window remains open.
- **Validation:**
  - Deterministic runtime coverage increased to `153` scenarios across `21` modules (all passing).
  - `luacheck .` is clean across the repository.
- **Documentation + Packaging Sync:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, and `TODO.md` to `0.9.59` and current runtime semantics.
- **TOC:**
  - TOC version bumped to `0.9.59`.

## 2026-03-01 - Version 0.9.58
- **Window Auto-Open Tightening:**
  - Hidden-window auto-open now only triggers on a real fresh small-group join, on key end, and on real dungeon entry (`outside -> party instance`).
  - Repeated `GROUP_ROSTER_UPDATE` events while already grouped no longer re-open a manually hidden main window.
  - Hidden `GROUP_ROSTER_UPDATE` updates inside non-key party instances remain blocked, so normal/heroic dungeon roster refreshes do not pop the UI back open.
- **Peer Sync Expansion (Visible Window Only):**
  - `isiLive` peers now exchange `STATS` snapshots in addition to `HELLO/ACK/KEY`, so `Spec`, `iLvl`, and `RIO` can backfill without inspect range when both players use `isiLive`.
  - Opening the main window now forces an immediate sync refresh (`HELLO` + `KEY/STATS`), even if the normal sync cooldown is still active.
  - Remote sync data only backfills `Spec/iLvl/RIO` until a fresh local inspect result exists; fresh local inspect data wins afterward.
- **Damage Meter Defaults:**
  - `damageMeterResetOnNewInstance` is now hard-enforced to `ON`, alongside `advancedCombatLogging`.
  - The existing manual Blizzard damage-meter reset on `CHALLENGE_MODE_START` remains active as an additional reset path when the API is available.
- **Validation:**
  - Added deterministic coverage for visible-window peer stats sync, local-inspect precedence, non-key dungeon hidden reopen guards, fresh-join-only auto-open, and outdoor-to-dungeon auto-open transitions.
  - `tools/validate_usecases.lua` now validates `152` deterministic scenarios across `21` modules (all passing).
- **Documentation + Packaging Sync:**
  - Synced `README.md` and `ARCHITECTURE.md` to `0.9.58` and current runtime semantics.
- **TOC:**
  - TOC version bumped to `0.9.58`.

## 2026-02-28 - Version 0.9.57
- **Center Notice Font Regression Fix:**
  - Fixed center-notice font scaling so repeated non-Mythic warning notices no longer grow larger after each re-show.
  - Center notice font scaling now always applies relative to the cached base font instead of the last already-scaled size.
- **Validation:**
  - Added deterministic regression coverage for repeated center-notice font scaling.
  - `tools/validate_usecases.lua` now validates `144` deterministic scenarios across `21` modules (all passing).
- **Documentation + Packaging Sync:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `RELEASE.md` to `0.9.57`.
- **TOC:**
  - TOC version bumped to `0.9.57`.

## 2026-02-27 - Version 0.9.56
- **Documentation + Packaging Sync:**
  - Synced version references in `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `RELEASE.md` to `0.9.56`.
  - Added the release-example tag references for `0.9.56`.
- **TOC:**
  - TOC version bumped to `0.9.56`.

## 2026-02-27 - Documentation Sync (Workspace)
- **Combat UI Taint Hardening (`ADDON_ACTION_BLOCKED`):**
  - Teleport grid buttons now use `InsecureActionButtonTemplate` so `isiLiveMainFrame:Show()` remains combat-toggleable (`CTRL+F9`) without protected-frame promotion.
  - Center notice teleport button now also uses `InsecureActionButtonTemplate` so notice show/hide stays combat-safe.
  - Existing combat defer/retry behavior for teleport spell-attribute updates remains unchanged.
- **Validation:**
  - Added deterministic UI coverage that simulates protected-frame show blocking in combat and verifies no secure child template is attached to the main frame in the teleport UI path.
  - `tools/validate_usecases.lua` validates `143` deterministic scenarios across `21` modules (all passing).
- **Documentation:**
  - Synced `README.md`, `ARCHITECTURE.md`, and `USECASES.md` to reflect the insecure-action teleport template behavior and combat-toggle guarantees.

## 2026-02-27 - Version 0.9.55
- **Inspect Taint Fix (`ADDON_ACTION_BLOCKED`):**
  - Removed protected `CheckInteractDistance()` usage from inspect retry processing in `isiLive_inspect.lua`.
  - Unified inspectability gating to `UnitIsVisible + CanInspect` for both initial dispatch and retry requeue paths.
- **Validation:**
  - Added deterministic inspect retry coverage in new scenario module `testmodul/isilive_test_scenarios_inspect.lua`.
  - `tools/validate_usecases.lua` now validates `143` deterministic scenarios across `21` modules (all passing).
- **TOC:**
  - TOC version bumped to `0.9.55`.

## 2026-02-26 - Version 0.9.54
- **Lua Diagnostics Hardening:**
  - Replaced direct `debug.traceback` global access in event-gate error handling with guarded `_G.debug` lookup.
  - Normalized `GameTooltip:SetText` calls to explicit color-argument signatures for LuaLS compatibility.
  - Added explicit nil/type guards in roster-panel deterministic test handlers before invoking captured callbacks.
- **Validation:**
  - `tools/validate_usecases.lua` remains at `142` deterministic scenarios across `20` modules (all passing).
- **Docs Sync:**
  - Updated `README.md` and `ARCHITECTURE.md` with explicit Lua diagnostics compatibility notes.
- **TOC:**
  - TOC version bumped to `0.9.54`.

## 2026-02-26 - Version 0.9.53
- **Roster Hover Tooltip UX:**
  - Added Blizzard-style roster row mouseover tooltip via unit binding (`GameTooltip:SetUnit(unit)`).
  - Hover rows now keep unit context from current roster render (`player`/`partyX`) for deterministic tooltip targeting.
  - Added safe fallback tooltip text (`Name-Realm`) when unit tokens are temporarily unavailable (for example fast roster transition timing).
- **Validation:**
  - `tools/validate_usecases.lua` now validates `142` deterministic scenarios across `20` modules (all passing).
- **Docs Sync:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `RELEASE.md` to `0.9.53` references and current validator counts.
- **TOC:**
  - TOC version bumped to `0.9.53`.

## 2026-02-25 - Version 0.9.52
- **Share Keys Chat Output Fix:**
  - Fixed `Share Keys` no-output regression caused by invalid manually built keystone chat links.
  - `Share Keys` now uses Blizzard owned-keystone link payload for the local player when available (`C_MythicPlus.GetOwnedKeystoneLink`).
  - Added safe fallback to plain text key output when no valid owned keystone link is available.
  - Share line format is now `isiLive PartyKeys: <Name> -> <KeyLinkOrText>`.
- **Validation:**
  - `tools/validate_usecases.lua` remains at `140` deterministic scenarios across `20` modules (all passing).
- **Docs Sync:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `RELEASE.md` to `0.9.52` references and updated Share Keys output wording.
- **TOC:**
  - TOC version bumped to `0.9.52`.

## 2026-02-25 - Version 0.9.51
- **Runtime Reliability + Error Logging:**
  - Event gate dispatch now supports a safe error callback path (`onDispatchError`) so handler failures are captured without hard-crashing the gate loop.
  - Runtime setup now routes dispatch failures through addon logging (`Print(...)`), so enabled runtime-log sessions persist these failures in `IsiLiveDB.runtimeLog`.
  - Event-handler wiring now consistently restores `runtimeLogEnabled` state from SavedVariables on `ADDON_LOADED`.
- **Spam Guard + Roster Row Stability:**
  - Added debounce guard for `Refresh` full-refresh execution (`isiLive_refresh.lua`).
  - Added debounce guard for `Share Keys` button spam (`isiLive_roster_panel.lua`).
  - Hardened roster member row rendering to enforce single-line text behavior (no wrap) across all row columns.
- **Log Code De-duplication:**
  - Added shared log helper module `isiLive_log_buffer.lua`.
  - `isiLive_queue_debug.lua` and `isiLive_runtime_log.lua` now use the shared helper for storage init, ASCII sanitizing, append trim, and tail extraction.
- **Tests + Validation Coverage:**
  - Added new deterministic scenario modules:
    - `testmodul/isilive_test_scenarios_runtime_log.lua`
    - `testmodul/isilive_test_scenarios_roster_panel.lua`
  - Added dispatch-error callback coverage in `testmodul/isilive_test_scenarios_event_utils.lua`.
  - Added runtime-log restore coverage in `testmodul/isilive_test_scenarios_event_handlers.lua`.
  - `tools/validate_usecases.lua` now validates `140` deterministic scenarios across `20` modules (all passing).
- **Rules + Docs Sync:**
  - Filled rule-to-test mappings for:
    - `RULE-BUTTON-SPAM-GUARD`
    - `RULE-ROSTER-ZEILENUMBRUCH-VERBOT`
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `RELEASE.md` to `0.9.51` references and current validator counts.
- **TOC:**
  - Updated addon list title to `isiLive`.
  - TOC version bumped to `0.9.51`.

## 2026-02-25 - Documentation Sync (Workspace)
- **Rules/Contract Coverage:**
  - Added rule-detail blocks for rule numbers `26-31` in `RULES_LOGIC.md` with deterministic test mappings.
  - Clarified portal-slot contract wording: once sorted, portal icon slot order stays fixed (no re-sorting/switching).
- **Runtime Behavior Docs Sync:**
  - Synced docs to current hidden-mode behavior: queue/sync processing is suspended while UI is hidden.
  - Confirmed auto-open transition behavior remains active for group join and key end (`CHALLENGE_MODE_COMPLETED`/`RESET`).
  - Added deterministic coverage note for key-end auto-show while grouped.
- **Validation:**
  - `tools/validate_usecases.lua` now validates `131` deterministic scenarios across 18 modules (all passing).
- **Documentation:**
  - Updated `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `RELEASE.md` to current validator count and hidden-mode semantics.

## 2026-02-25 - Version 0.9.50
- **Season Scope Policy:**
  - Removed the hard **Season-3-only lock** from project rules/docs.
  - Season scope is now open and controlled via `SeasonData.ACTIVE_SEASON_ID`.
  - Current active season remains `tww_s3`; next target season is `midnight_s1` (prepared/inactive until IDs are complete).
- **UI Visibility Behavior:**
  - `CTRL+F9` now allows opening and closing the main window in every state, including combat.
  - Center notice visibility no longer defers opening during combat; close and open both apply immediately.
  - Removed legacy `pendingCenterNoticeVisible` regen-apply path (`PLAYER_REGEN_ENABLED`) and related dead wiring.
  - Removed legacy main-frame pending-visibility regen path (`GetPendingVisible/getPendingMainFrameVisible`) and dead wiring.
  - Main window and center notice drag remain available in all states, including combat.
  - Center notice position is no longer persisted; each open resets to screen center.
  - Deduplicated red close-button creation/style via shared `UICommon.CreateRedCloseButton`.
  - `CHALLENGE_MODE_START` auto-hide behavior remains unchanged.
  - Hidden-mode processing behavior remains unchanged (non-essential processing still halted while UI is hidden).
  - Combat runtime gate now suppresses non-essential event processing while in combat and only keeps essential event paths active.
- **Documentation Sync:**
  - Updated `RULES.md`, `RELEASE.md`, `USECASES.md`, and `README.md` to reflect the season-open workflow.
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, and `TODO.md` to `0.9.50` references.
- **Validation:**
  - `tools/validate_usecases.lua` validates `126` deterministic scenarios across 18 modules (all passing).
  - Split oversized test registration blocks in queue/UI/teleport scenario modules so no function exceeds the `lua_metrics_check` hard limit (`320` lines).
  - Refactored remaining oversized runtime/test validator functions (`commands`, `queue`, `ui`, `test_mode`, rules validator, scenario suites) so `lua_metrics_check` now reports **no metric warnings**.
- TOC version bumped to `0.9.50`.

## 2026-02-24 - Version 0.9.49
- **Sync/Refresh Key Visibility Fix:**
  - Fixed refresh handshake race where remote member keys could disappear after one client used `Refresh`.
  - `HELLO` messages that require `ACK` now also trigger an immediate forced own-key snapshot send.
  - This repopulates peer key caches deterministically after refresh-driven sync resets and prevents one-sided key visibility flip-flops between clients.
- **Validation:**
  - Extended deterministic event-handler sync coverage to assert `HELLO -> ACK -> forced KEY snapshot` behavior.
  - `tools/validate_usecases.lua` remains at `117` deterministic scenarios across 18 modules (all passing).
- **Documentation:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, and `TODO.md` to `0.9.49` references.
- TOC version bumped to `0.9.49`.

## 2026-02-24 - Version 0.9.48
- **Queue Join Dedup Reliability:**
  - Switched grouped queue-announce deduplication to stable queue source IDs instead of display-text signatures.
  - Stable dedup IDs now prioritize `applicationID`, then `searchResultID`, then `listingID`.
  - Queue capture now forwards stable source metadata into `QueueFlow` pending state and grouped announce signature generation.
  - This suppresses duplicate grouped announce output when group/dungeon text changes but the underlying queue event is unchanged.
- **Validation:**
  - Added deterministic coverage for:
    - stable search-result dedup ID forwarding in queue capture
    - stable application dedup ID forwarding in application scans
    - grouped announce deduplication by stable queue event ID in QueueFlow
  - `tools/validate_usecases.lua` now runs `117` deterministic scenarios across 18 modules (all passing).
- **Documentation:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, and `TODO.md` to `0.9.48` references and validator count updates.
- TOC version bumped to `0.9.48`.

## 2026-02-23 - Version 0.9.47
- **Key Mapping Reliability (Season 3):**
  - Added explicit challenge-map alias mapping for Season 3 key IDs:
    - `378 -> 2287` (Halls of Atonement)
    - `391 -> 2441` (Tazavesh: Streets of Wonder)
    - `392 -> 2441` (Tazavesh: So'leah's Gambit)
    - `499 -> 2649` (Priory of the Sacred Flame)
    - `503 -> 2660` (Ara-Kara, City of Echoes)
    - `505 -> 2662` (The Dawnbreaker)
    - `525 -> 2773` (Operation: Floodgate)
    - `542 -> 2830` (Eco-Dome Al'dani)
  - Incoming addon sync payloads (`KEY:<mapID>:<level>`) are now normalized through the same alias mapping before roster storage/rendering.
  - Fixed roster key column fallback-to-number behavior for known aliased challenge-map IDs.
- **Roster/UI Fixes:**
  - Fixed solo/manual-open path to always keep the local player row (including own key snapshot) visible.
  - Increased minimum frame height and moved status line further down to avoid overlap with bottom controls.
  - Removed `[fullsync]` roster marker override; detected `isiLive` users now consistently render the blue `<3` marker only.
- **Share Keys Output:**
  - `Share Keys` now sends one chat line per member key instead of one aggregated line.
  - Share action now keeps existing visible key values stable and only backfills missing key data from sync cache.
- **Validation/Docs:**
  - Added deterministic teleport/sync coverage for challenge-map alias normalization.
  - `tools/validate_usecases.lua` now runs `114` deterministic scenarios across 18 modules (all passing).
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, and `RELEASE.md` to current runtime behavior and versioning.
- TOC version bumped to `0.9.47`.

## 2026-02-23 - Version 0.9.46
- **Queue Join UX:**
  - Removed queue-join center notice popup (`Joined from queue ...`) from grouped announce flow.
  - Queue-join feedback now uses chat summary + invite hint only.
- **Runtime Logging:**
  - Added runtime log persistence controller (`isiLive_runtime_log.lua`) storing entries in `IsiLiveDB.runtimeLog`.
  - Added slash command `/isilive log [on|off|start|stop|status|clear|tail [n]]` for runtime log control.
  - Added runtime-log command regression coverage to deterministic command scenarios.
- **Documentation:**
  - Synced `README.md`, `ARCHITECTURE.md`, and `RELEASE.md` with runtime log command support and validator coverage updates.
  - Updated deterministic usecase gate references from `111` to `113` scenarios.
- TOC version bumped to `0.9.46`.

## 2026-02-23 - Version 0.9.45
- **Runtime Reliability:**
  - Removed duplicate forced key-sync payload behavior on `PLAYER_ENTERING_WORLD` by keeping immediate send forced and delayed follow-up send non-forced.
  - Added deterministic regression coverage to ensure no duplicate forced key snapshot sends in the entering-world flow.
  - Extended bottom status line with target dungeon context (`Target Dungeon: <Name> [+Level]`) sourced from resolved queue/joined-key state.
  - Unified target-map resolution across status/enter-check/highlight flows to a strict resolver path (no hidden API bypass in highlight map resolving).
  - Removed negative activity resolver cache locking so late-arriving activity map payloads can recover to concrete map/spell targets.
- **Code Cleanup:**
  - Removed dead helper `Teleport.AddActivityToTeleportCache` from `isiLive_teleport.lua`.
  - Removed unused season alias `SeasonData.MAP_SHORT_CODES_DE` from `isiLive_season_data.lua`.
  - Removed redundant early `OnEvent` script binding in bootstrap/main setup; runtime gate remains the single `OnEvent` owner.
- **Validation:**
  - Added contract source file `RULES_LOGIC.md` for enforceable usecase/rule definitions with `active|draft|deprecated|disabled` status.
  - Added rules-logic validator (`tools/validate_rules_logic.lua`, `tools/rules_logic_validator.lua`) and integrated it into `tools/validate_usecases.lua`.
  - `tools/validate_usecases.lua` now runs 111 deterministic scenarios across 18 modules (all passing).
  - Local hook `.githooks/pre-commit` now includes deterministic usecase/rules validation.
  - CI workflow `Lua Check` now includes deterministic usecase/rules validation.
- **Documentation:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `RULES.md`, and `TODO.md` to `0.9.45` references and current runtime behavior.
  - Updated `RULES_LOGIC.md` to append-only rule maintenance (no forced sorting) and expanded draft usecase rule coverage; aligned `AGENTS.md` workflow accordingly.
- TOC version bumped to `0.9.45`.

## 2026-02-22 - Version 0.9.44
- **Season Data Maintainability:**
  - Refactored season configuration into centralized structured data in `isiLive_season_data.lua` with explicit `ACTIVE_SEASON_ID`.
  - Added season helper API (`GetSeasonConfig`, `GetMapToTeleport`, `GetShortCodes`, `GetDungeonShortCode`) so future season swaps only require one data-file update.
  - Updated teleport runtime to consume SeasonData helper API instead of hardwired map/shortcode tables.
- **Localized Dungeon Short Codes:**
  - Added locale-aware roster key short-code resolution by active addon locale.
  - `deDE` short-code overrides now render as:
    - `PSF -> PRI`
    - `EDA -> BIO`
    - `HOA -> HDS`
    - `OFG -> SCH`
    - `AK -> AK`
    - `DB -> MB`
    - `TAZ -> TAZ`
  - `enUS` short codes remain unchanged.
- **Validation:**
  - Added deterministic coverage for locale-specific short-code resolution and SeasonData central helper fallback behavior.
  - `tools/validate_usecases.lua` now runs 103 deterministic scenarios across 18 modules (all passing).
- **Documentation:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, and `TODO.md` to `0.9.44` references and current runtime behavior.
- TOC version bumped to `0.9.44`.

## 2026-02-22 - Version 0.9.43
- **Combat-Safe Secure UI:**
  - Fixed `ADDON_ACTION_BLOCKED` errors from center-notice teleport secure button updates in combat (`Hide`, `EnableMouse`, and anchor changes).
  - Center-notice teleport button visibility, mouse state, and anchor updates are now deferred while in combat and applied safely after combat ends.
- **Validation:**
  - `tools/validate_usecases.lua` remains at 102 deterministic scenarios across 18 modules (all passing).
- **Documentation:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `RULES.md`, and `TODO.md` to `0.9.43` references and current runtime behavior.
- TOC version bumped to `0.9.43`.

## 2026-02-22 - Version 0.9.42
- **Queue/Highlight Reliability:**
  - Added negative-status race protection so fresh pending queue invite context is not cleared too early by follow-up declined/canceled application events, preventing missing initial dungeon detection/highlight immediately after join.
- **RIO Delta Reliability:**
  - Hidden-state event gate now allows `CHALLENGE_MODE_COMPLETED`/`CHALLENGE_MODE_RESET`, so delayed post-run refresh and delta activation still run even when the main window is currently hidden.
- **Packaging:**
  - Excluded the logo asset from CurseForge packaging via `.pkgmeta` ignore list.
- **Validation:**
  - `tools/validate_usecases.lua` remains at 102 deterministic scenarios across 18 modules (all passing).
- **Documentation:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `RULES.md`, and `TODO.md` to `0.9.42` references and current runtime behavior.
- TOC version bumped to `0.9.42`.

## 2026-02-22 - Version 0.9.41
- **RIO Delta Reliability:**
  - Added two short post-run follow-up refresh passes after the first successful delayed refresh so late RIO backend updates no longer stay stuck at temporary `(+0)` until manual refresh.
- **Validation:**
  - Added deterministic regression coverage for successful delayed refresh follow-up scheduling.
  - `tools/validate_usecases.lua` now runs 102 deterministic scenarios across 18 modules.
- **Documentation:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `RULES.md`, and `TODO.md` to `0.9.41` references and current post-run refresh behavior.
- TOC version bumped to `0.9.41`.

## 2026-02-22 - Version 0.9.40
- **RIO Delta Fixes:**
  - Fixed runtime wiring regression where `enableRioDeltaDisplay` was not forwarded into event-handler setup, which could keep delta display permanently disabled.
  - Delta display activation now happens after the delayed post-run refresh path (`CHALLENGE_MODE_COMPLETED`/`RESET`) instead of immediately at event time.
  - Added retry logic for delayed post-run refresh attempts when refresh is still temporarily blocked by active challenge-state timing.
  - Roster delta callback now receives the current roster unit token, so live unit RIO can be used during delta rendering.
- **Validation:**
  - Added deterministic regression coverage for delayed delta activation, retry behavior, and unit-aware delta rendering.
  - `tools/validate_usecases.lua` now runs 101 deterministic scenarios across 18 modules.
- **Documentation:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `RULES.md`, and `TODO.md` to `0.9.40` references and current RIO-delta runtime behavior.
- TOC version bumped to `0.9.40`.

## 2026-02-21 - Version 0.9.39
- **Maintenance:**
  - Documentation/version sync only (no gameplay behavior changes).
  - Updated `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, and `TODO.md` version/tag references to `0.9.39`.
- TOC version bumped to `0.9.39`.

## 2026-02-21 - Version 0.9.38
- **RIO Delta Display:**
  - Added challenge-start RIO baseline capture and per-player roster delta rendering as prefix `(+X)RIO`.
  - Delta is now strictly non-negative (`+0` minimum; never minus).
  - Added deterministic test-mode preview for visible positive RIO deltas in `/isilive test` and `/isilive testall`.
- **UI & Labels:**
  - Increased RIO-column spacing and adjusted right-side header/button offsets to avoid overlap with the management panel.
  - Reduced language-column width to reclaim horizontal table space.
  - Updated right-side column labels to `M+Managment` and `M+Travel`.
- **Validation:**
  - Added deterministic roster and event-handler coverage for RIO baseline/delta rules.
  - `tools/validate_usecases.lua` now runs 98 deterministic scenarios across 18 modules.
- **Documentation:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md`, `RULES.md`, and `TODO.md` to current runtime/UI behavior.
- TOC version bumped to `0.9.38`.

## 2026-02-21 - Version 0.9.37
- **Deterministic Target Resolution:**
  - Switched queue/highlight/teleport resolution to strict `activityID -> mapID -> spellID` flow.
  - Removed dungeon-name/token fallback resolution and removed first-candidate guessing when no concrete activity map exists.
  - Added explicit queue target `mapID` runtime state (`latestQueueMapID`) and map-first target clear behavior.
  - Fixed late queue-capture race: if LFG target data arrives after `GROUP_ROSTER_UPDATE`, grouped members now still get queue chat/notice/teleport preview immediately.
  - Added grouped announce deduplication for identical queue targets to prevent repeated chat spam and center-notice timer resets.
- **UI & UX:**
  - Fixed teleport-grid button layering to inherit main-frame strata/level instead of forcing `HIGH` (issue #14).
  - Fixed non-Mythic warning flow to also trigger on in-instance difficulty switches (for example `Normal -> Heroic`) and recognize heroic fallback difficulty ID `174`.
  - Widened roster `Key` column and disabled key-text wrapping so `SHORT +LEVEL` values stay on one line.
  - Updated `CTRL+F9` behavior: frame can always be closed in combat, but opening via hotkey is blocked during combat.
- **Validation:**
  - Added regression coverage for strict no-guess queue activity selection, strict no-name teleport resolution, unresolved-map caching, TeleportUI strata sync, and non-Mythic status transitions.
  - `tools/validate_usecases.lua` now runs 94 deterministic scenarios.
- TOC version bumped to `0.9.37`.

## 2026-02-20 - Version 0.9.36
- **Code Quality:**
  - Simplified `EventUtils.IsNegativeApplicationStatusEvent` by removing redundant explicit checks for arg positions 2 and 3; unified into a single loop that checks all arguments uniformly (both strings and numbers at every position).
  - Normalized inline comments in `isiLive_teleport.lua` from German to English for codebase-wide language consistency.
  - Wrapped `Guards.Validate` in `pcall` with user-friendly red error message instead of crashing the entire addon on load failures.
- **Combat Safety:**
  - Fixed `OnDragStop` handlers on main frame and drag handle to always call `StopMovingOrSizing()` before the combat guard, preventing the frame from getting stuck in a moving state if combat starts mid-drag.
  - Removed inconsistent `RightButton` drag registration from main frame; drag is now `LeftButton`-only, matching the drag handle behavior.
- **UI & UX:**
  - Added localized chat notification when addon hides due to raid group (>5 members), so the user understands why the window disappeared.
  - Fixed `deDE` `LOADED_HINT` to be fully German instead of mixed English/German.
- **Test Coverage:**
  - Added 40 new offline test scenarios across 9 new modules (Group, EventUtils, Locale, Sync, Guards, TestMode, LeaderWatch, Refresh, Commands), bringing total from 42 to 82.
- TOC version bumped to `0.9.36`.

## 2026-02-20 - Version 0.9.35
- **Teleport/Queue Detection:**
  - Fixed localized queue target resolution for Eco-Dome Al'dani variants (for example `Biokuppel Al'dani`) when activity map data is missing or incomplete.
  - Added localized fallback token matching so queue join notices and active teleport highlight resolve correctly for Biokuppel listings.
- **Runtime Defaults:**
  - Re-enabled former `DM Reset` behavior as hardcoded default: on `CHALLENGE_MODE_START`, Blizzard damage meter sessions are reset when `C_DamageMeter` APIs are available.
  - Enforced `advancedCombatLogging` as hardcoded `ON` (`1`) across startup/challenge lifecycle events.
- **Validation:**
  - Added deterministic regression tests for localized Eco-Dome name fallback and activity-name fallback without `mapID`.
  - Added deterministic regression tests for hardcoded advanced-combat-log enforcement and challenge-start damage-meter reset.
  - `tools/validate_usecases.lua` now runs 42 scenarios.

## 2026-02-19 - Version 0.9.34
- **Highlight Stability:**
  - Fixed queue-target clear regression on negative `LFG_LIST_APPLICATION_STATUS_UPDATED` events while already grouped (for example when the 5th member joins and other applications get declined).
  - Active teleport highlight now remains stable across full-group transition follow-up events.
- **Validation:**
  - Added deterministic regression coverage in `testmodul/isilive_test_scenarios_event_handlers.lua`.
  - `tools/validate_usecases.lua` now runs 38 scenarios.

## 2026-02-19 - Version 0.9.33
- **UI & UX:**
  - Increased main frame minimum height from `200` to `212` so the `Share Keys` / `Keys teilen` button no longer sits on the bottom edge.
  - Renamed the right-side countdown stop action label from `Countdown Cancel` to `Countdown 0` (behavior remains `DoCountdown(0)`).
- **Combat Safety:**
  - Fixed protected-call drag taint (`ADDON_ACTION_BLOCKED: isiLiveMainFrame:StartMoving()`) by skipping frame drag start/stop while in combat lockdown.
- **Documentation:**
  - Synced `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RULES.md`, `RELEASE.md`, and `TODO.md` with current UI labels and combat-drag behavior.

## 2026-02-19 - Version 0.9.32
- **Architecture & Stability:**
  - Fixed global variable leaks in realm data; moved to `addonTable.RealmData`.
  - Added combat-queue for teleport buttons to ensure updates apply correctly after combat ends (`PLAYER_REGEN_ENABLED`).
  - Fixed roster panel overflow in raid groups by strictly limiting display to 5 rows.
  - Improved realm language detection for same-realm players.
  - Fixed center-notice teleport resolution to also work with `activityID` when dungeon name is missing.
  - Added deterministic shared-teleport map handling (e.g. both Tazavesh wings on one portcast).
  - Fixed active-listing highlight suppression for shared portcasts by prioritizing exact activity map matching before shared-spell suppression.
  - Harmonized active-listing detection in event handlers to avoid premature queue-target clears when API variants omit explicit `active` booleans.
  - Hardened queue activity-name lookups with protected `GetActivityInfoTable` access.
- **UI & UX:**
  - Share Keys button is now disabled/dimmed if no keys are available to share.
  - Fixed typos in German localization (`Managment` -> `Management`, `Groupenfuehrer` -> `Gruppenfuehrer`).
- **Code Quality:**
  - reduced oversized function blocks across controller/UI modules
  - `tools/lua_metrics_check.lua` reports no function-size warnings at default thresholds (`warn>120`, `hard>320`)
  - added deterministic runtime usecase validator `tools/validate_usecases.lua` for queue/highlight/cooldown edge-case gates
  - validator refactored to modular offline simulation suite (`testmodul/isilive_test_*.lua`) with 37 deterministic scenarios
  - expanded CurseForge packaging ignore list in `.pkgmeta` to exclude non-runtime docs/dev assets (`tools/`, `testmodul/`, architecture/usecase docs, repo metadata)
  - wired `README.md` + `RELEASE.md` quality gates to include `lua tools/validate_usecases.lua`
  - removed 7 unused localization keys from `isiLive_texts.lua`:
    - `INVITE_HINT_TITLE`
    - `LEAD_TRANSFERRED`
    - `TELEPORT_ERR_NO_TARGET`
    - `TELEPORT_ERR_COMBAT`
    - `TELEPORT_ERR_FAILED`
    - `TIMEOUT_INSPECT`
    - `TOOLTIP_TELEPORT_NO_TARGET`

## 2026-02-18 - Version 0.9.31
- Runtime stability fixes:
  - fixed combat taint/protected-call error (`ADDON_ACTION_BLOCKED: Button:SetScale()`) by skipping teleport-button scale resets during combat and applying the reset after `PLAYER_REGEN_ENABLED`
  - fixed invite dungeon detection ambiguity by preferring concrete teleport-mapped activity IDs over generic dungeon candidates in queue application parsing (fixes `Halls of Atonement` / `Hallen der Suehne` mis-detection after invite)
  - updated right control headers: former `M+ Management` renamed to `M+travel`, former `Lead Options` renamed to `M+ Managment`
  - replaced obsolete `DM Reset` toggle with a leader-only `Countdown Cancel` action (`DoCountdown(0)`) and moved `Refresh` to the bottom slot in the right control stack
  - replaced the tiny key-speaker icon with a full-size `Share Keys` button below `Refresh` in the right control stack
- Documentation sync:
  - added `ARCHITECTURE.md` (runtime architecture + ASCII UI sketch)
  - added `USECASES.md` (invite/highlight/cooldown use-case plan)
  - updated `README.md`, `RELEASE.md`, `RULES.md`, and `TODO.md` to `0.9.31` baseline/examples
- TOC version bumped to `0.9.31`.

## 2026-02-18 - Version 0.9.30
- **Key Announce:** Added a speaker button to the roster panel to post all known party keys to chat.
- **Season Data:** Extracted season data (dungeons, teleports) into `isiLive_season_data.lua` for easier updates.
- **Season Data:** Updated/locked dungeon list and teleports for **Season 3**.
- **UI Behavior:** The main window is now "frozen" instead of strictly hidden during M+ runs; it can be opened via hotkey (`CTRL+F9`) to view cached data.
- **Auto-Refresh:** Added automatic group data refresh (iLvl/RIO) 5 seconds after dungeon completion.
- **UI Layout:** Moved addon version label from bottom-right to top-right in the main window.
- **Teleport UI:** Active dungeon target now shows the yellow border even if the teleport spell is not yet learned (locked), improving clarity for alts.
- **Teleport:** Optimized caching for teleport spell lookups (Tazavesh tokens).
- **Teleport Mapping:** Added support for multiple mapped spell IDs per dungeon map (for variant/faction-safe resolution).
- **Teleport Highlight:** Fixed self-hosted key highlight resolution for localized listing names (e.g. `Morgenbringer`) and solo-host active listings.
- **Teleport Highlight:** Highlight now turns off once the player is already inside the matching target dungeon.
- **Sync:** Improved realm name normalization for stricter sync matching.
- **Fixes:**
  - **Combat Safety:** Added retry logic for teleport buttons loaded during combat to prevent broken states.
  - Fixed queue invite detection when `pendingStatus` is returned as `0`.
  - Fixed persistence of debug settings (`qdebug`) and global variable usage (`issecretvalue`).
- TOC version bumped to `0.9.30`.

## 2026-02-17 - Version 0.9.29
- Maintenance/CI release (no gameplay behavior changes):
  - fixed `main` quality-gate stability by aligning CI runtime dependencies for Lua metrics check
  - CI now installs `luafilesystem` and loads LuaRocks paths before running `tools/lua_metrics_check.lua`
  - CI metrics hard limit for function size adjusted to `360` to match current modularization baseline and avoid false release blocking
- Code quality cleanup:
  - applied formatting-only normalization in touched modules
  - removed one unused local (`groupController`) in `isiLive.lua`
- Documentation/release metadata sync:
  - updated `README.md` and `RELEASE.md` examples to `0.9.29`
- TOC version bumped to `0.9.29`.

## 2026-02-17 - Version 0.9.28
- Runtime stability fixes:
  - fixed `QueueFlow` initialization-order regression (`updateUI` is now assigned before controller wiring), resolving startup error `QueueFlow requires updateUI`
  - fixed combat taint/protected-call error (`ADDON_ACTION_BLOCKED: Button:Enable()`) by removing runtime `Enable()` calls from secure teleport button update path
- Tooling/editor diagnostics:
  - fixed LuaLS false-positive diagnostics in `tools/lua_metrics_check.lua` for CLI globals (`require`, `io`, `os`) in standalone metrics script
- Documentation/release metadata sync:
  - updated `README.md` and `RELEASE.md` examples to `0.9.28`
- TOC version bumped to `0.9.28`.

## 2026-02-17 - Version 0.9.27
- Big refactoring and modularization pass:
  - split large runtime responsibilities into dedicated modules (wiring/bootstrap, event handlers, group lifecycle, queue flow, bindings, helpers)
- Refactor stabilization after modularization:
  - fixed runtime event-gate wiring regression where `dispatch` could be `nil` during setup (`onEvent` is now accepted as dispatch fallback)
- Release safety hardening:
  - stable CurseForge trigger restricted to `isiLive_release_*`
  - manual release trigger now requires confirmation and validates that the provided tag exists
  - added isolated pre-release workflow for `isiLive_alpha_*` and `isiLive_beta_*`
- Documentation and release metadata sync:
  - updated README/RELEASE examples and tag samples to `0.9.27`
- TOC version bumped to `0.9.27`.

## 2026-02-16 - Version 0.9.26
- Pre-key key visibility rework:
  - removed bottom key header line and replaced it with a new roster column `Key`
  - key values now render as `DungeonShortcut +Level` (for example `DB +14`)
  - added Season 3 dungeon short codes for key display (`PSF`, `EDA`, `HOA`, `OFG`, `AK`, `TAZ`, `DB`)
- Group key sync (isiLive users only):
  - added addon sync payload `KEY:<mapID>:<level>` and per-player key cache
  - roster key values are populated from sync data when party members also run `isiLive`
  - key sync/send remains visibility-bound; no key sync processing in hidden/sleep mode
  - clears known-isiLive runtime markers when the group is fully left, so next group starts with clean detection state
- UI layout adjustments:
  - widened main frame to reduce table overlap with right-side controls
  - widened `Key` column and shifted `iLvl`/`RIO` positions to avoid line wrapping/collision
- Teleport highlight stability:
  - fixed edge-case where highlight could stop around full-group transition (for example when the 5th member joins)
  - active-listing resolver now falls back to known queue/join target when listing activity cannot be resolved transiently
- Spec column readability:
  - added short-label mapping for long localized spec names (for example `Wiederherstellung -> Resto`, `Vergeltung -> Retri`)
- Active key indicator in roster:
  - added red key text marker for the active joined key (invite/join flow)
  - strict ownership rule: marker is only shown when key owner can be identified unambiguously from synced group keys
  - hosting flow is excluded from automatic ownership assumptions (active listing no longer implies own key owner)
- Refresh behavior:
  - `Refresh` now performs a full forced refresh for group data (`Spec/iLvl/RIO` + `hasIsiLive` + key sync state)
  - refresh flow now forces fresh `HELLO` and `KEY` sync broadcasts and resets stale per-roster sync hints before rebuilding
- TOC version bumped to `0.9.26`.

## 2026-02-15 - Version 0.9.25
- CI/release follow-up:
  - fixed Lua quality-gate regressions on `main` (Luacheck + StyLua compliance)
  - no gameplay/feature behavior changes; release refresh for stable packaging
- TOC version bumped to `0.9.25`.

## 2026-02-15 - Version 0.9.24
- Teleport highlight behavior:
  - activation is now strict: highlight appears only after actual group join or while actively hosting your own listing
  - no pre-invite/pre-group highlight anymore
- Teleport reliability:
  - hardened cooldown handling against secret values from `C_Spell.GetSpellCooldown`
  - fixed queue secret-table errors in `isiLive_queue.lua`
  - improved Tazavesh resolution with normalized/localized name matching
- Queue/LFG flow:
  - block `LFG_LIST_*` processing during active Mythic+ key
  - prevent "Joined from queue" message when player is leader/host
  - allow dungeon-category queue capture even when no teleport spell is mapped
- Debug cleanup:
  - simplified `tpdebug` output to actionable fields only (removed raw dumps and debug-side cache mutation)
  - added `/isilive qdebug tail [n]` (default `20`, clamped `1..100`)
  - removed stale debug state (`latestQueueCapturedAt`) and dead debug branching
- TOC version bumped to `0.9.24`.

## 2026-02-15 - Version 0.9.23
- Bugfixes:
  - Fixed teleport highlight disappearing when the group becomes full (listing removal caused queue info to be overwritten with empty data).
  - Fixed Lua error `attempt to compare local 'enabled' (a secret boolean value)` in `GetTeleportCooldownRemaining` by sanitizing secret values from `C_Spell.GetSpellCooldown`.
  - Fixed multiple Lua errors `table expected, got secret` in `isiLive_queue.lua` (including `ExtractApplicationSnapshot`).
  - Debug cleanup: reduced `tpdebug` output to actionable fields only (removed raw table dumps and debug-side cache mutation).
  - Added `qdebug tail [n]` (clamped to 1..100, default 20) to inspect recent queue debug entries without log spam.
  - Optimization: Completely block LFG event processing (`LFG_LIST_*`) when a Mythic+ key is active to prevent unnecessary background work and potential taint/secret errors.
  - Added robust teleport resolution for Tazavesh (Streets/Gambit) via normalized name matching (handles split wings sharing one teleport, including localized map names).
  - Fixed "Joined from queue" message appearing when hosting your own key (added leader check).
  - Fixed missing notifications for dungeons without mapped teleport spells (e.g. leveling dungeons or unmapped IDs).
    - Queue capture now validates activities via WoW API category (Dungeon/M+) instead of relying solely on teleport spell existence.
- Teleport highlight:
  - made visual pulse stronger/faster and overlay more dominant (scale 1.2, faster loop, stronger color)
  - highlight activation is now strict to real context only: shown only after actual group join or while actively hosting your own listing
- TOC version bumped to `0.9.23`.

## 2026-02-15 - Version 0.9.22
- Test mode flow:
  - added dedicated `ExitTestMode()` handling to leave test mode with a consistent cleanup/reset path
- TOC version bumped to `0.9.22`.

## 2026-02-14 - Version 0.9.21
- Queue capture reliability:
  - added `LFG_LIST_SEARCH_RESULT_UPDATED` event handling to trigger `CaptureQueueJoinCandidate(...)`
  - registered `LFG_LIST_SEARCH_RESULT_UPDATED` on the main frame and test-mode event gate allowlist
- TOC version bumped to `0.9.21`.

## 2026-02-14 - Version 0.9.20
- Queue capture cleanup:
  - removed redundant single-table fallback parsing in `Queue.CaptureQueueJoinFromApplications`
  - queue application status/pending extraction now uses the direct values path only
- TOC version bumped to `0.9.20`.

## 2026-02-14 - Version 0.9.19
- UI/Mainframe refresh:
  - title now shows `isiLive` branding.
  - added native-style backdrop and subtle header separator
  - roster rows now support hover highlight
  - roster name column now includes role icons (tank/healer/damager)
- Teleport/queue behavior:
  - replaced per-frame `OnUpdate` pulse with `AnimationGroup`-based active target animation
  - active teleport fallback now checks current challenge map ID
  - improved reset behavior when leaving test mode and after challenge start
- Data/role handling:
  - added player-role fallback via specialization role when assigned group role is unavailable
  - test roster generation now adapts party composition to the local player role
- Event gating:
  - test mode now supports configurable allowed events (`allowInTestMode`) and keeps required events active
- Packaging/docs:
  - added `TODO.md` and excluded it from CurseForge package via `.pkgmeta`
  - README title updated with rename note
- TOC version bumped to `0.9.19`.

## 2026-02-13 - Version 0.9.18
- Teleport target/highlight:
  - updated all 8 M+ dungeon mapIDs for Season 3 in `SEASON3_MAP_TO_TELEPORT` table:
    * Priory of Sacred Flame: 2649
    * Eco-Dome Al'dani: 2830
    * Halls of Atonement: 2287
    * Operation: Floodgate: 2773
    * Ara-Kara, City of Echoes: 2660
    * Tazavesh: Streets of Wonder / So'leah's Gambit: 2441
    * The Dawnbreaker: 2662
  - removed redundant name-based fallback logic and kept strict mapID/activityID-based resolution
  - removed unused local variable in teleport activity resolver
- Queue/event processing cleanup:
  - removed duplicate application rescans in `LFG_LIST_APPLICATION_STATUS_UPDATED` and `LFG_LIST_ACTIVE_ENTRY_UPDATE`
  - queue apply scan now runs through the existing queue capture path only (single source of truth)
- UX/Warnings:
  - non-Mythic dungeon warning changed from persistent to 120-second timeout
  - non-Mythic warning now auto-hides immediately upon dungeon exit
- TOC version bumped to `0.9.18`.

## 2026-02-13 - Version 0.9.17
- Release update after post-release architecture and repo-hardening changes.
- Repo quality/tooling hardening:
  - added `.gitattributes` to enforce LF line endings for core file types
  - added optional `.githooks/pre-commit` checks (`stylua --check`, `luacheck`)
  - finalized strict lint/format setup (`StyLua`, `Luacheck`, CI quality gate)
- Documentation refresh:
  - updated README with modular file inventory (including TOC/ui/teleport/status/units/demo modules)
  - added developer setup, CI quality gate, and optional git hook usage notes
- Bumped TOC version to `0.9.17`.

## 2026-02-12 - Version 0.9.16
- Fixed LuaLS `redundant-parameter` diagnostics after modularization by aligning fallback callback signatures with real call sites in:
  - `isiLive.lua`
  - `isiLive_commands.lua`
  - `isiLive_demo.lua`
  - `isiLive_events.lua`
  - `isiLive_notice.lua`
  - `isiLive_status.lua`
- Corrected status-controller method calls to consistent dot-style invocation where functions are defined without implicit `self`.
- Bumped TOC version to `0.9.16`.

## 2026-02-12 - Version 0.9.15
- Continued modularization and moved additional logic out of `isiLive.lua` into:
  - `isiLive_units.lua`
  - `isiLive_demo.lua`
  - `isiLive_status.lua`
- Added repo-wide Lua quality tooling and config:
  - `.stylua.toml`
  - `.luacheckrc` (strict globals + WoW API allowlist)
  - `.editorconfig`
  - `.styluaignore`
  - `.vscode/tasks.json`
- Hardened CI quality gate:
  - pinned `StyLua` check in workflow
  - integrated `luacheck` and syntax checks
  - fixed `stylua-action` auth handling (`github.token`)
  - excluded `.luarocks` noise from CI lint/syntax scope
  - fixed `luacheck` CLI arg parsing (`--` separator)
- Standardized release/tag naming to `isiLive_*` and aligned workflow/docs.
- Added `RELEASE.md` runbook for the repeatable release flow.
- Bumped TOC version to `0.9.15`.

## 2026-02-12 - Version 0.9.14
- Modularized addon architecture into dedicated files:
  - `isiLive_locale.lua`
  - `isiLive_sync.lua`
  - `isiLive_queue.lua`
  - `isiLive_inspect.lua`
  - `isiLive_roster.lua`
  - `isiLive_events.lua`
  - `isiLive_commands.lua`
- Added addon-presence roster markers:
  - blue `<3` marker for detected `isiLive` users
  - green `[fullsync]` marker when all visible roster members are detected as `isiLive` users
- Updated test/dummy roster so the local player is always used as `player` entry in test modes.
- Added bottom-right version line in the main window (`V.x.y.z`) sourced from TOC metadata.
- Updated load chat message to: `isiLive: Loaded Version x.x.x.x Press STRG+F9 to open`.
- Kept hidden-window behavior strict with minimal transition path: no non-essential processing while hidden; hotkey/binding flow remains active; small-group `GROUP_ROSTER_UPDATE` still allows auto-open.
- Fixed Lua diagnostics `redundant-parameter` warnings in modular fallbacks by aligning fallback function signatures with call sites.

## 2026-02-12 - Version 0.9.13
- Release-only republish to force a unique CurseForge package artifact after `.11` and `.12` pointed to the same commit.
- No code changes compared to `0.9.12`.

## 2026-02-12 - Version 0.9.12
- Fixed main window drag reliability:
  - window now supports direct left/right mouse drag
  - top drag handle is forced above overlays to prevent mouse event blocking
- Fixed combat lockdown taint error (`ADDON_ACTION_BLOCKED`) by deferring protected `isiLiveMainFrame:SetHeight()` updates until `PLAYER_REGEN_ENABLED`.

## 2026-02-12 - Version 0.9.11
- Fixed queue-teleport highlight reliability so invite-detected dungeon targets are applied immediately and remain stable across follow-up LFG status events.
- Prioritized invite/queue dungeon target for M+ teleport highlighting regardless of current player location/instance.
- Added dedicated mapID-to-teleport helper flow and tightened activity selection to prefer teleport-mappable activities.
- Fixed local function declaration order regression (`ResolveSeason3TeleportSpellIDByMapID`) that could cause a nil-call error in teleport cache building.
- Removed dead code in `isiLive.lua` (`GetUnitID`, unused `mplusActiveSpellID`, inactive duplicate dungeon line updater).

## 2026-02-12 - Version 0.9.10
- Reduced Lua diagnostics noise in `isiLive.lua`:
  - removed deprecated spell-known fallbacks
  - added safer dynamic field/global access (`rawget`) for Blizzard runtime-provided fields/frames
  - improved analyzer-friendly typing around teleport icon handling and rating summary reads
- Restored Russian realm entries in `realm_language_data.lua` with proper UTF-8 names and normalized keys.
- Removed corrupted `????` placeholder keys that produced duplicate-index diagnostics.

## 2026-02-12 - Version 0.9.9
- Reworked right-side M+ teleport UI from single button to multi-button grid (one button per mapped dungeon teleport).
- Added active-target highlight for the currently resolved teleport (strong pulse/glow + tinted overlay).
- Improved active teleport target resolution with fallbacks:
  - queue-derived dungeon/activity
  - active challenge map
  - current instance map/name
- Fixed non-Mythic entry warning timing by adding delayed confirmation to avoid false positives during instance-load transitions.
- Updated roster language display to include `flag + 2-letter code` (for example `DE`, `FR`).

## 2026-02-12 - Version 0.9.8
- Added inspect-based specialization (`Spec`) detection for party members and integrated it into the group table.
- Added a new `Spec` column before `Name`, with class-color rendering and localization support.
- Updated roster table alignment and labels:
  - `Name` column is left-aligned
  - German header `Flagge` renamed to `Sprache`
- Added non-Mythic dungeon entry warning as a center-screen notice with 30-second duration.
- Improved center notice interaction:
  - left-click drag to move
  - right-click to dismiss immediately
  - persisted position restore across reload/login
- Updated dummy/test roster values and sample specs to match current test expectations.

## 2026-02-11 - Version 0.9.2
- Improved dungeon teleport secure-button compatibility by expanding secure spell attributes for reliable click-cast behavior.
- Fixed hidden-state queue handling so `LFG_LIST_APPLICATION_STATUS_UPDATED` is still captured and dungeon targets do not stick to test/default values.
- Added automated Lua quality checks via GitHub Actions (`.github/workflows/lua-check.yml`).
- Added README quality-check section with local `luacheck` command.
- Added explicit versioning rules (`MAJOR.MINOR.PATCH`) in `RULES.md`.

## 2026-02-11 - Version 0.9.1
- Added server-language detection based on Blizzard EU realm status data (`realm_language_data.lua`) with normalized realm-name fallback.
- Replaced server/language text in roster with country flag icons (`DE/EN/FR/ES/IT/PT/RU`).
- Added `/isilive tpdebug` to inspect current teleport target resolution, secure attributes, known/cooldown state, and button visibility.
- Added `/isilive tptest` to force a dummy teleport target (`The Dawnbreaker`) for isolated teleport-button testing.
- Reduced chat noise by suppressing inspect-timeout chat lines (`Timeout beim Inspizieren von ...`).
- Improved hidden-frame behavior:
  - fully stops scan/processing work while the main window is hidden
  - keeps required transition handling so auto-open on small-group join still works
  - keeps auto-hide behavior on Mythic+ key start

## 2026-02-11 - Version 0.9
- Upgraded the center queue teleport control from text button to spell icon button (secure cast button with spell texture).
- Center queue notice now lasts 20 seconds by default.
- Center queue notice frame is now movable and persists position via `IsiLiveDB.centerNoticePosition`.
- Improved test preview dungeon for teleport testing (`/isilive testall`) by switching dummy dungeon to `The Dawnbreaker`.
- Added a new right-side column `M+ Management`.
- Added a second dungeon teleport icon button under `M+ Management`, synchronized with the latest queued invite dungeon/activity.
- Expanded teleport state handling for both teleport buttons:
  - no target dungeon yet
  - locked teleport (not learned)
  - combat lockdown blocked setup
- Fixed teleport icon/button setup for WoW `12.0.1` secure-cast behavior, including reliable icon visibility and click-cast updates.
- Added teleport cooldown detection with live button state updates and remaining time display in `HH:MM`.
- Fixed `OnEvent` nil-call regression by routing manual event refreshes through the frame's registered event script.
- Fixed protected frame visibility calls during combat by deferring blocked show/hide updates until `PLAYER_REGEN_ENABLED`.
- Improved main window dragging behavior to avoid click conflicts with UI controls while keeping the frame movable.

## 2026-02-10 - Version 0.7
- Fixed queue dungeon resolution to avoid wrong dungeon names from mixed numeric event args.
- Dungeon lookup now prefers the actual `searchResult` activity mapping for invite/application updates.
- Prevented cross-application dungeon carry-over unless the group name matches.
- Improved hotkey robustness for `CTRL+F9` / `CTRL+ALT+F9`:
  - watchdog now re-applies bindings safely after combat if a rebind was blocked in combat lockdown
  - binding click buttons now listen on key down/up and execute on key down for more reliable triggering
- Improved queue join chat visibility by adding white separator lines before and after the message block.
- Added right-side dungeon difficulty indicator (`Normal`/`Heroic`/`Mythic`) with live updates on instance/difficulty changes and key-readiness color hint.
- Added a center notice teleport button for queued invites:
  - maps Season 3 dungeons to their teleport spell IDs (compiled from the WoW spell database)
  - enables direct click-cast when the dungeon teleport is known
  - shows locked state when teleport is not unlocked yet and handles combat lockdown safely

## 2026-02-09 - Version 0.7
- Set addon compatibility policy to WoW `12.0+` only.
- Improved hotkey handling and rebinding reliability for:
  - `CTRL+F9` (window toggle)
  - `CTRL+ALT+F9` (test mode toggle)
- Added full test preview mode (`/isilive testall`) and improved test visuals.
- Added right-side control area updates:
  - `Readycheck`
  - `Countdown10`
  - `Refresh` (force re-read of all iLvl/RIO values)
  - `DM Reset: ON/OFF` (auto-reset Blizzard Damage Meter on key start)
- Added persistent DM reset setting via `IsiLiveDB.autoDamageMeterReset`.
- Added and improved queue join detection:
  - chat output
  - 10-second center message
  - invite hint panel near invite UI (with fallback positioning)
- Improved roster behavior when reopening the window and refreshing while list is empty.
- Implemented stable role sorting (`Tank -> Healer -> Damager`) and reduced row jumping.
- Reworked table layout and alignment:
  - fixed columns (`Name`, `iLvl`, `RIO`)
  - name truncation to 10 characters
  - spacing and visual tuning around lead options/buttons
- Added lead transfer center notification and warning sound.
- Added status line with `Lead`, `M+`, and addon runtime state.
- Fixed multiple scope/order Lua errors (`UpdateUI`, `UpdateLeaderButtons`, `OnEvent`).
- Standardized visible addon strings to English output.
- Added runtime language switching via `/isilive lang [en|de]` with persisted setting in `IsiLiveDB.locale`.
