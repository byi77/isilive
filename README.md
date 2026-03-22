# isiLive

`isiLive` is a WoW group helper addon for Mythic+ pug/party flow, focused on pre-key group overview.
Internal Lua file/module namespace remains `isiLive_*` for compatibility.

Compatibility target: WoW `12.0+` only.
Current documented baseline: `0.9.92`.

## Features

- Group roster table with columns: `Spec`, `Name`, `Flag`, `Key`, `iLvl`, `RIO`, `DPS`, `Deaths`, `Kicks`
- Raid-size groups (`>5` members) automatically switch the visible addon window into H mode, keep roster rows hidden, and print a localized transition notice
- Interactive Role Icons: Click the role icon in the roster to securely mark Tank (**Blue Square**) or Healer (**Green Triangle**).
- **M+Marker:** Expanded view uses a vertical bar of 8 world marker buttons (`Square`, `Triangle`, `Diamond`, `Cross`, `Star`, `Circle`, `Moon`, `Skull`) with native secure world-marker actions; the horizontal mini layout arranges the same icons in one slim row and restores the vertical stack correctly when expanded again.
- **Mini Mode:** Three static mode buttons are available next to the close button: `H` switches to the slim horizontal tool layout, `V` switches to the compact vertical palette, and `M` switches back to the main roster view. The active mode is highlighted in gold.
- **Horizontal Mini Mode:** Shows the compact leader actions `RC`, `CD`, and `CD 0` side by side while M+Marker stays visible as one horizontal marker row. `Share Keys` and `Refresh` stay available only in M/V layouts.
- **Esc Menu Tooling:** The WoW `Esc` game menu can show a tooling strip left of the default menu, with direct buttons for `Professions`, `Talents`, `Spells`, `Achievements`, `Quests`, `Dungeons`, `Journal`, `Collections`, `Guild`, and a separated `ReloadUI` button. The `ReloadUI` entry is wired as a secure macro (`/click GameMenuButtonContinue` + `/reload`), mirrors `ActionButtonUseKeyDown`, and defers blocked secure refreshes until `PLAYER_REGEN_ENABLED`.
- **Esc Travel Strip:** A second strip farther left adds `Ark. Key`, `Hearthstone`, and `Housing` buttons.
- **Blizzard Settings Category:** `Settings -> AddOns -> isiLive` exposes localized controls for language, `Advanced Combat Logging`, `DM Reset on Dungeon Entry`, `Show ESC Menu Shortcuts` (tooling + travel strips), `Background Opacity`, `UI Scale`, `Default UI on Open`, `Minimap Button`, `Addon Sync`, `Auto-Open on M+ Queue`, `Auto-Hide when Solo`, `Column Guides`, `Queue Debug Log`, and `Runtime Log`.
- **Default Open Layout:** `Default UI on Open` now opens the addon in `M2` by default until the user picks another layout; `Last Used` remains an explicit option.
- **Roster Column Guides:** Optional debug column guides can be enabled for `M` and `M2` layout tuning and stay off by default.
- **Hidden Legacy Settings Defaults:** `Name Length`, `Teleport Grid Columns`, `Show DPS Column`, `Markers: Leader Only`, and `Sound Notifications` are temporarily hidden from Blizzard Settings; runtime keeps fixed live defaults instead (`DPS`, `Deaths`, and `Kicks` on, markers visible for all, sound off, fixed name truncation, legacy 2-column `Travel` grid).
- **UI Polish Refresh:** The roster panel, private tooltips, invite hint, and center notice now share the same dark framed palette with softer blue hover accents, alternating row shading, and cleaner separators.
- **Combat Utility Row:** A bottom tracker row shows live `BRes` charges/cooldown plus `Bloodlust`/`Heroism`/`Time Warp` remaining time with spell icons.
- **Minimap Button:** Optional draggable Minimap button toggles the main window and persists its angle around the minimap.
- Blizzard Settings only: `Combat Logging` and `DM Reset on Entry` live in `Settings -> AddOns -> isiLive`; the main roster panel no longer shows those toggles.
- Stable role sorting: `Tank -> Healer -> Damager`
- Right-side controls: `Readycheck`, `Countdown10`, `Countdown 0`, `Share Keys`, `Refresh`
- Right-side headers: `M+Management`, `Marker`, and `Travel`
- `Travel` teleport grid uses the active-season portal pool in deterministic Midnight Season 1 order, keeps duplicate shared-spell collapse without losing slot order, and currently stays on the legacy 2-column layout
- Active dungeon teleport is highlighted (pulse/glow) only when you joined a group from queue or are actively hosting your own group
- Teleport action buttons use `InsecureActionButtonTemplate` so main/notice visibility requests stay combat-safe without protected-frame promotion
- Players inside the target dungeon are marked with a portal icon in the roster
- Group key visibility via addon sync: members with `isiLive` share key as `Shortcut +Level` (for example `DB +14` / `MB +14` depending on locale)
- Visible-window peer sync between `isiLive` users can also backfill remote `Spec`, `iLvl`, `RIO`, `DPS`, and dungeon location without inspect range; fresh local inspect data keeps priority once available
- Manual `Refresh` force-sends the local `HELLO` + `KEY`/`STATS`/`DPS`/`LOC` snapshot and also broadcasts `REQSYNC`, so hidden `isiLive` peers can answer once with a forced `KEY`/`STATS`/`DPS`/`LOC` reply when they are not stopped, paused, or inside an active Mythic+ run
- Key mapping normalizes active-season challenge-map IDs to canonical season map IDs before short-code rendering
- Season scope is open via `ACTIVE_SEASON_ID`; current active season is `midnight_s1` with all 8 Midnight Season 1 portals mapped live
- `Key` column keeps `Shortcut +Level` on one line (no row-wrap bleed into next member line)
- `RIO` column can show per-run delta as `(+X)RIO` (non-negative only; never minus)
- Run snapshot columns show the latest completed-run Blizzard damage-meter snapshot for the current roster as `DPS`, `Deaths`, and `Kicks` when an exact player match exists
- Roster tooltip adds `Level`, `Lang`, localized `Last run DPS`/`Last run deaths`/`Last run kicks`, sync age/source/version, and a Shift-only provenance debug block
- Private `isiLive` tooltips now use their own wrapped compact layout so longer lines stay inside the tooltip frame
- Persistent stats stay bounded: only the matching local character's own last-run DPS/Deaths/Kicks are kept in SavedVariables; foreign-player snapshots are session-only
- CurseForge release packaging excludes PNG screenshot/logo assets via `.pkgmeta`, so repository preview images do not ship inside the addon zip
- Queue join detection with chat message and invite hint
- Grouped queue-join announce deduplication is driven by stable queue source IDs (`applicationID`/`searchResultID`/`listingID`), not volatile display text
- Dungeon teleport controls in center notice + right-side grid
- Teleport cooldown shown as `HH:MM`
- Addon-presence marker per roster name (custom blue heart icon plus a compact sync refresh badge when metadata is available)
- `Share Keys` posts one party-chat line per available member key (`isiLive PartyKeys: Name -> Key`), using Blizzard owned-keystone link payload for the local player when available
- Spec column uses max-5-char short labels for long localized names (for example `Wiederherstellung -> Resto`, `Vergeltung -> Retri`, `Treffsicherheit -> MM`, `Tierherrschaft -> BM`)
- Center notices: left-click drag, right-click dismiss, top-right close button; position resets to center on each open
- Optional runtime log persisted in `IsiLiveDB.runtimeLog` (enable/disable via slash command; flushed on `/reload`/logout)
- Roster rows support **Right-Click** (Whisper)
- **Portal Navigator:** When the player enters the Timeways portal room, a full-screen overlay appears showing the four portal destinations (half-left, left, right, half-right) with their dungeon names; closes via right-click or the X button; toggleable via `Show Timeways Navigator` in Blizzard Settings (defaults enabled).
- Non-Mythic dungeon entry warning with delayed confirmation (larger/blinking persistent notice; right-click dismiss, left-click drag)
- Top-right version label in main window (`V.x.y.z`)

## Behavior

- Auto-open on real fresh small-group join
- `Default UI on Open` defaults to `M2` until the user changes it in settings.
- `Auto-Hide when Solo` defaults to enabled until the user turns it off.
- Auto-hide on M+ key start (`CHALLENGE_MODE_START`); can be manually opened (`CTRL+F9`) in "frozen" read-only state.
- Auto-open on key end (`CHALLENGE_MODE_COMPLETED`/`CHALLENGE_MODE_RESET`) while grouped.
- Auto-open on real dungeon entry (`outside -> party instance`) while not in an active key.
- `CTRL+F9`: visibility changes can always be requested; if combat lockdown blocks `Show`/`Hide`, the pending open/close is applied on `PLAYER_REGEN_ENABLED`. The close button (X) always hides the frame immediately, even during combat.
- Hidden window mode still blocks queue scanning, but background data sync (`CHAT_MSG_ADDON`, `GROUP_ROSTER_UPDATE`) may event-drive pre-rendered roster state so reopen stays immediate without adding polling load.
- Combat runtime gate suppresses non-essential event processing while in combat; essential events (for example `PLAYER_REGEN_ENABLED` and `CHALLENGE_MODE_*`) still run.
- Own outbound sync snapshots (`HELLO`/`KEY`/`STATS`/`DPS`/`LOC`) remain visibility-bound, while hidden mode still processes incoming addon sync messages, whisper `ACK`s, and one gated hidden `REQSYNC` reply path so cached roster data and pre-rendered UI state stay current without polling.
- A manual `Refresh` force-sends the local `HELLO` + `KEY`/`STATS`/`DPS`/`LOC` snapshot and additionally sends `REQSYNC`; hidden peers may answer with one forced `KEY`/`STATS`/`DPS`/`LOC` reply while staying hidden, but they suppress that reply when locally stopped, paused, or inside an active key.
- Main window is movable via left drag in every mode; top drag handle stays above overlays for reliable dragging
- Roster member row hover uses an isolated `isiLive` tooltip instead of the shared Blizzard `GameTooltip`, with `Name-Realm` fallback when no synced details are available
- Roster control buttons, teleport grid buttons, and center-notice teleport hover also use isolated `isiLive` tooltip frames instead of the shared Blizzard `GameTooltip`
- When the roster table is hidden in compact layouts, the hidden row hover/click hitboxes are also disabled so invisible rows do not keep catching tooltip or whisper interactions.
- Teleport grid buttons inherit main-frame strata/level to avoid overlay conflicts with external UI panels
- Ghost members: players leaving the group remain visible (greyed out) across slot shifts and even after party leave/disband; ghost rows are pruned deterministically on rejoin, fresh group join, full-group rebuild, or reload.
- `CTRL+ALT+F9`, `/isilive test`, and `/isilive testall` now enter the same full dummy preview path, including a visible ghost/leaver row and positive dummy RIO delta preview; preview refresh rebuilds fresh dummy copies each time.
- Smart self-update: automatically broadcasts a full sync snapshot (`KEY`/`STATS`/`DPS`/`LOC`) when the player's own iLvl, RIO, or Spec changes.
- Teleport action buttons are intentionally `InsecureActionButtonTemplate` so main-frame and notice visibility do not promote their parents to protected frames
- Combat-safe frame updates: pending main-frame visibility, frame-height changes, and blocked `Esc` shortcut secure-button refreshes are applied on `PLAYER_REGEN_ENABLED`
- `Advanced Combat Logging` and `DM Reset on Dungeon Entry` live in Blizzard Settings only.
- They mirror the live Blizzard CVar state and write only on explicit user clicks.
- Blizzard `Settings -> AddOns -> isiLive` mirrors locale, those same CVar-backed toggles, `Show ESC Menu Shortcuts`, `Background Opacity`, `UI Scale`, `Default UI on Open`, `Minimap Button`, `Addon Sync`, `Auto-Open on M+ Queue`, `Auto-Hide when Solo`, `Column Guides`, `Queue Debug Log`, and `Runtime Log` without forcing the main addon window open.
- Hidden legacy Settings controls stay absent from Blizzard Settings for now and use fixed runtime defaults (`DPS`, `Deaths`, and `Kicks` on, markers visible for all, sound off, fixed name truncation, legacy 2-column `Travel` grid).
- Disabling `Show ESC Menu Shortcuts` hides the optional `Esc` tooling and travel strips immediately; localization refresh updates both strips and the Blizzard settings canvas.
- The toggle row keeps a fixed gap between adjacent labels.
- Blizzard damage meter is also manually reset on `CHALLENGE_MODE_START` when `C_DamageMeter` API support is available.
- In **Mini Mode** (collapsed), the window acts as a compact tool palette with M+Marker and Management controls only. `H`, `V`, and `M` are always visible as direct mode selectors; H mode compresses the leader tools to localized short labels (`RC` / `CD` / `CD 0`), while `Share Keys` and `Refresh` remain limited to M/V. Both compact modes stay open during key start, and raid-size groups now force the visible window into H mode instead of hiding it.
- While a raid-size group is active, H mode is enforced: `V` and `M` clicks are ignored until the group returns to party size.
- `CHALLENGE_MODE_START` captures a per-player RIO baseline.
- `CHALLENGE_MODE_COMPLETED`/`CHALLENGE_MODE_RESET` schedules delayed post-run refresh and enables clamped delta display `(+X)RIO` after refresh succeeds (with short retry if still blocked), including when the window is currently hidden.
- Latest run DPS/Deaths/Kicks is captured after `CHALLENGE_MODE_COMPLETED`/`CHALLENGE_MODE_RESET` for `M+`, and after leaving tracked non-challenge party dungeons (`Normal`/`Heroic`/`Mythic`); both paths retry briefly if the Blizzard damage-meter session is not ready yet, and non-challenge matching uses the roster snapshot frozen on dungeon entry.
- Test mode (`/isilive test`, `/isilive testall`) includes visible positive dummy RIO delta preview.
- `Readycheck`, `Countdown10`, and `Countdown 0` are leader-only
- Roster language column shows the flag icon (16×12 px, 4:3 landscape) when a texture exists; for tags without a flag asset (for example `KR`, `CN`, `TW`) it shows a grey text tag instead. The tooltip still shows the 2-letter server language code.
- On addon load, chat shows current version and open hint (`Press CTRL+F9 to open`)
- Bottom status line includes current target dungeon context as `Target Dungeon: <Name> [+Level]` (or `Target Dungeon: -` when unresolved)
- Runtime log entries are persisted through SavedVariables when logging is enabled.
- Sync handshake behavior: `HELLO` recipients send `ACK`; explicit local refresh force-sends the local `HELLO` + `KEY`/`STATS`/`DPS`/`LOC` snapshot and broadcasts `REQSYNC`; visibility-bound snapshots keep cached `KEY`/`STATS`/`DPS`/`LOC` data current.

## Use Case / Logic Baseline (v0.9.92)

Documented on `2026-03-22` as runtime behavior baseline (`0.9.92`) for validation checks.


1. Queue invite -> grouped flow
   - Queue/LFG events capture candidate group + dungeon (`LFG_LIST_*`) while main UI is visible.
   - On confirmed small-group join (`GROUP_ROSTER_UPDATE`), addon announces joined group, shows invite hint, resolves target dungeon teleport, and highlights the active teleport.
2. Group roster build and ordering
   - On group update, roster is rebuilt as `player + party1..party4`.
   - Display ordering is stable by role (`TANK -> HEALER -> DAMAGER -> NONE`) and unit priority.
   - Per row data includes `Spec`, `Name`, `Flag`, `Key`, `iLvl`, `RIO`, `DPS`, `Deaths`, `Kicks` and optional run-delta prefix `(+X)`.
3. Key sync and key column
   - Own outbound sync snapshots remain visibility-bound, while incoming addon sync messages can still refresh cached roster data during hidden mode.
   - Manual `Refresh` force-sends the local `HELLO` + `KEY/STATS/DPS/LOC` snapshot and also sends `REQSYNC`; hidden peers may answer with one forced `KEY/STATS/DPS/LOC` reply without opening their UI, but only when they are not stopped, paused, or inside an active key.
   - `KEY:<mapID>:<level>` snapshots populate roster key text as `Shortcut +Level` (for example `DB +14` / `MB +14` depending on locale).
   - `STATS` snapshots can backfill remote `Spec/iLvl/RIO` without inspect range; once fresh local inspect data exists for a field, that local value keeps priority over later sync backfill.
   - `DPS` snapshots share the local player's last-run DPS; the roster DPS column falls back to synced DPS when local damage-meter data is unavailable.
   - `LOC` snapshots share the player's current dungeon map ID; the roster portal icon uses synced location as fallback when local unit map info is unavailable.
   - Active joined key owner is highlighted only when ownership is unambiguous.
4. Teleport targeting and highlight logic
    - Active target resolves in strict order: active listing `activityID -> mapID -> spellID`, then latest queue target `mapID -> spellID`.
    - If concrete `mapID` context is missing, target stays unresolved (no name/token guessing).
    - Highlight is group-bound (no solo highlight), and updates on queue/listing/challenge transitions.
    - Exact target map has priority: if activity map is known, highlight clears only on that exact map.
    - Shared-portcast dungeons (for example both Tazavesh wings) are handled as multi-map targets and remain unresolved if map context is ambiguous.
    - Negative queue application follow-up events do not clear queue-derived target while already grouped (prevents highlight drop when group fills to 5 members).
5. Refresh and inspect pipeline
   - `Refresh` triggers a forced local sync wave (`HELLO/KEY/STATS/DPS/LOC`), a groupwide `REQSYNC` hidden-peer reply request, and inspect cache invalidation/requeue.
   - Inspect controller updates `Spec/iLvl/RIO` asynchronously via queue/retry flow and `INSPECT_READY`.
   - After challenge completion/reset, a delayed post-run refresh is attempted; RIO delta display is enabled only after this refresh path succeeds (with retry fallback).
6. Runtime gating and hidden/sleep behavior
   - Event gate blocks non-required processing in `stopped`, `paused`, and hidden states.
   - Hidden mode keeps transition events active (auto-open) and allows background data sync (`CHAT_MSG_ADDON`, `GROUP_ROSTER_UPDATE`) plus event-driven pre-rendered UI state; grouped non-challenge roster updates stay active even across raid-size transitions, while queue scanning and permanent polling remain suppressed.
   - `CHALLENGE_MODE_START` hides UI; completion/reset rehydrates group view and refresh flow.
   - Combat-safe UI behavior: teleport action buttons use `InsecureActionButtonTemplate` (to avoid protected-parent show/hide taint), while spell-attribute updates, `Esc` shortcut secure-button refreshes, main-frame visibility, and blocked frame-height changes are restored on `PLAYER_REGEN_ENABLED`.
   - Hidden leader changes are synchronized silently so leader-only button state stays correct on the next visible transition without firing hidden notices/chat output.
   - Leaving or getting removed from a normal party keeps the current frame visibility state and converts former party members into ghost rows instead of clearing the roster immediately.
7. Post-run stats snapshot behavior
   - `M+` run-end events (`CHALLENGE_MODE_COMPLETED`/`CHALLENGE_MODE_RESET`) record the latest Blizzard damage-meter overall session for exact roster matches and retry briefly if the session is still empty on the first event.
   - Non-challenge snapshots are recorded when leaving tracked `Normal`/`Heroic`/`Mythic` party dungeons, use the roster frozen on dungeon entry so late leavers still match, and also retry briefly if the damage-meter session is not ready yet.
   - Only the matching local character's own last-run DPS/Deaths/Kicks persists across sessions; relogging to another own character does not inherit the previous character's persisted snapshot, and foreign-player snapshots stay runtime-only.
8. External UI entry points and settings
   - Opening the WoW `Esc` menu can show localized tooling and travel strips for `Professions`, `Talents`, `Spells`, `Achievements`, `Quests`, `Dungeons`, `Journal`, `Collections`, `Guild`, `ReloadUI`, `Ark. Key`, `Hearthstone`, and `Housing`.
   - The `ReloadUI` shortcut uses a secure macro path instead of an addon-side Lua reload call, first dismissing the menu via Blizzard's own `Continue` button and then dispatching `/reload`.
   - Successful shortcut clicks close the game menu first and then open the targeted Blizzard panel through the dedicated opener path; the spellbook path does not route through talents.
   - Blizzard `Settings -> AddOns -> isiLive` mirrors locale, CVar-backed toggles, `Show ESC Menu Shortcuts` (tooling + travel strips), `Background Opacity`, `UI Scale`, `Default UI on Open`, `Minimap Button`, `Addon Sync`, `Auto-Open on M+ Queue`, `Auto-Hide when Solo`, `Column Guides`, `Queue Debug Log`, and `Runtime Log`.
   - Hidden legacy settings (`Name Length`, `Teleport Grid Columns`, `Show DPS Column`, `Markers: Leader Only`, `Sound Notifications`) stay absent from Blizzard Settings and currently use fixed runtime defaults: `DPS`, `Deaths`, and `Kicks` on, markers visible for all, sound off, fixed name truncation, and legacy 2-column `Travel` layout.

## Hotkeys

- `CTRL+F9`: toggle main window
- `CTRL+ALT+F9`: toggle test mode

## Slash Commands

- `/isilive test`
- `/isilive testall`
- `/isilive tptest`
- `/isilive tpdebug`
- `/isilive log [on|off|start|stop|status|clear|tail [n]]`
- `/isilive lead`
- `/isilive lang [en|de]`
- `/isilive pause`
- `/isilive resume`
- `/isilive stop`
- `/isilive start`
- `/isilive bindcheck`

Developer debug (hidden command, not listed in in-game help):
- `/isilive qdebug [on|off|status|clear|tail [n]]`

## Files

- `isiLive.toc`: addon metadata and load order
- `isiLive.lua`: composition root and top-level addon orchestration
- `isiLive_runtime_state.lua`: central runtime-state controller for roster, queue target, flags, ready check, and RIO baseline
- `isiLive_locale.lua`: locale/language/flag mapping helpers
- `isiLive_texts.lua`: localized UI text table for roster labels, game-menu shortcuts, and settings labels
- `isiLive_season_data.lua`: active season dataset (`ACTIVE_SEASON_ID`, map->teleport mappings, locale short-code overrides)
- `isiLive_ui_common.lua`: shared UI colors, close-button helpers, isolated private tooltip frames, and configurable background opacity
- `media/heart_sync.tga`: custom 16x16 dark-blue heart icon for addon-presence sync marker
- `isiLive_teleport.lua`: dungeon teleport mapping and secure teleport button helpers
- `isiLive_teleport_ui.lua`: teleport grid button creation/update helpers
- `isiLive_teleport_debug.lua`: teleport debug/test command controller (`tpdebug`, `tptest`)
- `isiLive_notice.lua`: center notice/invite hint UI components
- `isiLive_status.lua`: status line and dungeon-difficulty helpers
- `isiLive_units.lua`: unit/spec/name/RIO helper functions
- `isiLive_demo.lua`: dummy/test roster generation, including unified full-preview ghost rows for test mode
- `isiLive_sync.lua`: addon sync (`HELLO`/`ACK`/`KEY`/`STATS`/`DPS`/`LOC`) and user detection
- `isiLive_stats.lua`: bounded last-run DPS/Deaths/Kicks snapshot storage (persistent only for the matching local character; foreign players session-only)
- `isiLive_cd_tracker.lua`: live `BRes`/`Bloodlust` countdown controller for the roster utility row
- `isiLive_leader_watch.lua`: leader-transfer detection and leader-only button state sync
- `isiLive_keysync.lua`: key-sync controller (sync snapshot sends, cache apply, active key owner resolver)
- `isiLive_refresh.lua`: refresh controller (forced full refresh flow incl. `HELLO/KEY/STATS/DPS/LOC` + inspect requeue)
- `isiLive_highlight.lua`: active-target resolver and highlight-state decision helpers
- `isiLive_group.lua`: group lifecycle controller (`GROUP_ROSTER_UPDATE`, roster rebuild, leave cleanup)
- `isiLive_queue.lua`: LFG/queue invite capture and parsing
- `isiLive_queue_debug.lua`: queue debug storage + command helpers (`qdebug`)
- `isiLive_runtime_log.lua`: runtime log storage + command helpers (`log`)
- `isiLive_log_buffer.lua`: shared saved-log buffer utilities (`queueDebugLog` + `runtimeLog`)
- `isiLive_inspect.lua`: inspect queue/retry/cache controller
- `isiLive_roster.lua`: roster ordering + display-data builders
- `isiLive_roster_tooltip.lua`: isolated roster tooltip rendering for sync and last-run stats
- `isiLive_roster_panel.lua`: main roster table, action buttons, run-stat columns, and CD tracker row
- `isiLive_events.lua`: event gate wrapper for stop/pause/test/hidden states
- `isiLive_event_handlers.lua`: runtime event-handler aggregator (`OnEvent` routing targets)
- `isiLive_event_handlers_runtime.lua`: addon/world/combat/inspect/sync lifecycle handlers
- `isiLive_event_handlers_queue.lua`: LFG queue/listing lifecycle handlers
- `isiLive_event_handlers_challenge.lua`: challenge/ready-check lifecycle handlers
- `isiLive_controller_wiring.lua`: controller dependency wiring and context-to-controller adapters
- `isiLive_runtime_setup.lua`: runtime bootstrap assembly for group/event/gate controllers
- `isiLive_config_builders.lua`: focused builders for refresh, queue-flow, slash commands, gate, and leader watch
- `isiLive_commands.lua`: slash command registration/dispatch
- `isiLive_ui.lua`: main frame/UI construction, optional `Esc`-menu tooling/travel strips, and widget wiring
- `isiLive_settings.lua`: Blizzard Settings canvas for locale/system/debug toggles
- `isiLive_factory.lua`: secondary-controller assembly, localization fan-out, and settings/panel initialization
- `RULES_LOGIC.md`: enforceable usecase/rule contract source (`RULE-ID` blocks with status + required tests)
- `ARCHITECTURE_RULES.md`: enforceable architecture contract source (`RULE-ID` blocks with status + required tests)
- `tools/validate_rules_logic.lua`: rules-logic validator entrypoint
- `tools/validate_architecture_rules.lua`: architecture-rules validator entrypoint
- `tools/validate_usecases.lua`: deterministic usecase validator entrypoint
- `testmodul/isilive_test_*.lua`: modular offline simulation scenarios + harness for queue/highlight/event/cooldown/cd-tracker/teleport/group/sync/locale/commands/guards logic (dev-only, not packaged)
- `realm_language_data.lua`: Blizzard EU realm locale mapping (including UTF-8 Russian realm names)
- `CHANGELOG.md`: release notes
- `RELEASE.md`: release runbook
- `RULES.md`: project/versioning rules
- `WARTUNG.md`: long-break maintenance runbook (dev-only, not packaged)
- `LICENSE`: license file

## Local Install

1. Place this folder as `Interface/AddOns/isiLive`.
2. Ensure `isiLive.toc` is present.
3. Reload UI or restart game.

## GitHub Publish (First Time)

1. `git init`
2. `git add .`
3. `git commit -m "Initial release v0.9.1"`
4. Create an empty GitHub repo (e.g. `isiLive`)
5. `git branch -M main`
6. `git remote add origin https://github.com/<user>/isiLive.git`
7. `git push -u origin main`

## Quality Check

- GitHub Action (on push/PR to `main`): `stylua --check .`, `luacheck --exclude-files ".luarocks/**" -- .`, Lua syntax check, Lua metrics check (`lua tools/lua_metrics_check.lua`), and deterministic usecase/rules gate (`lua tools/validate_usecases.lua`).
- Local release-grade checks:
  - `stylua --check .`
  - `luacheck --exclude-files ".luarocks/**" -- .`
  - `lua tools/lua_metrics_check.lua`
  - `lua tools/validate_rules_logic.lua`
  - `lua tools/validate_architecture_rules.lua`
  - `lua tools/validate_usecases.lua`
  - Windows preflight mirroring the GitHub workflow as closely as possible: `powershell -ExecutionPolicy Bypass -File tools/validate_ci_local.ps1`
  - Metrics defaults: file `warn>1200` / `hard>2600`, function `warn>120` / `hard>320` (override via `ISILIVE_WARN_FILE_LINES`, `ISILIVE_MAX_FILE_LINES`, `ISILIVE_WARN_FUNCTION_LINES`, `ISILIVE_MAX_FUNCTION_LINES`)
  - Windows note: if metrics cannot find LuaRocks modules (`lfs`/`luacheck.*`), set `LUA_PATH` + `LUA_CPATH` to your LuaRocks `share/lua/5.4` and `lib/lua/5.4` paths before running.

## Deterministic Usecase Gate

`tools/validate_rules_logic.lua` validates active runtime rule contracts from `RULES_LOGIC.md` against deterministic test names.
`tools/validate_architecture_rules.lua` validates active architecture contracts from `ARCHITECTURE_RULES.md` against deterministic test names.
5. `tools/validate_usecases.lua` runs both validators first and then executes a modular deterministic runtime/structure gate (`testmodul/isilive_test_*.lua`) with 338 deterministic tests indexed and 341 scenarios across 32 modules (architecture/queue/highlight/event-handlers/event-handler lifecycles/queue-flow/spell-utils/teleport/group/event-utils/locale/sync/guards/inspect/test-mode/leader-watch/refresh/commands/runtime-log/runtime-state/roster/roster-panel/status/stats/cd-tracker/units/ui/roster-display/taint/tank-helper), including:
- architecture guardrails for composition-root ownership, lifecycle aggregation, runtime-state centralization, context-based controller wiring, and focused config builders
- queue candidate resolution priority (concrete teleport mapping over generic candidates)
- shared-portcast highlight behavior (queue + active listing exact-map suppression)
- ambiguous shared-spell map handling (no guessing)
- event-handler target-clear behavior under API shape variants
- grouped negative-application follow-up stability (no target clear on full-group transition)
- strict no-guess behavior when activity map context is missing in queue/teleport resolution
- hardcoded advanced-combat-log enforcement and challenge-start damage-meter reset behavior
- protected API fallback robustness in queue flow
- cooldown recognition/format behavior for teleport spells
- group lifecycle (join/leave/raid detection/queue capture/roster build)
- hidden-mode gate behavior (queue scanning and permanent polling suspended while hidden, background sync + event-driven pre-render allowed, auto-open only on fresh join, dungeon entry, and key-end transitions)
- hidden-mode background sync behavior (`CHAT_MSG_ADDON` and `GROUP_ROSTER_UPDATE` stay active while cached/pre-rendered UI state is refreshed without polling)
- visible-window peer sync for remote `Spec/iLvl/RIO` backfill plus local-inspect precedence over later sync payloads
- non-Mythic status detection (normal/heroic transitions and heroic fallback difficulty IDs)
- combat hotkey visibility rules (`CTRL+F9`: blocked show/hide requests are replayed on `PLAYER_REGEN_ENABLED`)
- center-notice font-scale stability across repeated warning re-shows (no cumulative growth)
- expanded taint-hardening regressions for deferred secure spell apply, insecure notice/teleport buttons, tank-helper macros, and collapse behavior around secure child buttons
- RIO baseline/delta rendering rules (`(+X)RIO`, no negative deltas) and challenge-start baseline capture
- runtime-state patching/queue-target clearing/RIO-baseline reset invariants
- EventUtils negative/positive status detection and edge cases
- locale key completeness (enUS ↔ deDE symmetry, format placeholders)
- sync NormalizePlayerKey, MarkUser/IsUserKnown, key dedup, HELLO/KEY messages
- Guards full module+function validation, missing module/function detection
- TestMode toggle/stop/pause guards, full dummy preview
- LeaderWatch gain/loss/initial-state transitions plus hidden-state silent synchronization
- Refresh guards (stopped, active M+), full refresh pipeline
- Commands slash routing (test, stop/start, pause/resume, lang switch, runtime log start/stop)
- Event gate dispatch-error callback handling (`onDispatchError`) without crash propagation
- Runtime-log controller behavior (enable gating, ring-buffer trim, ASCII sanitizing, tail clamping)
- Button-spam guards (`Refresh` + `Share Keys` debounce) and roster-row no-wrap guarantees

## Developer Setup

Prerequisites:
- VS Code
- VS Code extensions:
  - `JohnnyMorganz.stylua`
  - `sumneko.lua` (LuaLS)

Local checks:
- `stylua .` (format)
- `stylua --check .` (CI check)
- `luacheck --exclude-files ".luarocks/**" -- .` (lint)
- `lua tools/lua_metrics_check.lua` (file/function size metrics)
- `lua tools/validate_rules_logic.lua` (active rule/test mapping gate)
- `lua tools/validate_architecture_rules.lua` (active architecture-rule/test mapping gate)
- `lua tools/validate_usecases.lua` (deterministic usecase gates)

Notes:
- The addon is namespace-based (`local addonName, addonTable = ...`).
- Do not introduce new globals. `IsiLiveDB` (SavedVariables) is intentionally allowed.
- LuaLS compatibility baseline: use guarded `rawget(_G, "debug")` access for traceback paths and pass explicit RGB args to `GameTooltip:SetText`.
- `realm_language_data.lua` is intentionally excluded from format/lint (data-only file).

## CI Quality Gate

The CI workflow runs five checks on `push`/`pull_request` to `main`:
- `stylua --check .`
- `luacheck --exclude-files ".luarocks/**" -- .`
- Lua syntax check (`loadfile` validation for all `.lua` files except `.luarocks`)
- Lua metrics check (`lua tools/lua_metrics_check.lua`)
- deterministic usecase and rules gate (`lua tools/validate_usecases.lua`)
  - includes runtime rules from `RULES_LOGIC.md` and architecture rules from `ARCHITECTURE_RULES.md`

Release gating additionally runs local deterministic usecase/rules validation:
- `lua tools/validate_usecases.lua`

## Git Hooks (Optional)

Enable the repository hook path:
- `git config core.hooksPath .githooks`

Then `pre-commit` will run:
- `stylua --check .`
- `luacheck --exclude-files ".luarocks/**" -- .`
- `lua tools/lua_metrics_check.lua`
- `lua tools/validate_usecases.lua`

## CurseForge Auto Publish

Stable release:
- `release.yml` triggers CurseForge's official auto-packager only for tags like `isiLive_release_X.Y.Z`.

Pre-release:
- `pre-release.yml` triggers CurseForge packaging for tags like `isiLive_alpha_X.Y.Z` or `isiLive_beta_X.Y.Z`.
- Stable workflow is isolated and will not trigger on alpha/beta tags.

Required GitHub settings (repo `Settings -> Secrets and variables -> Actions`):

1. `Secret`: `CF_API_KEY` (your CurseForge API token)
2. `Variable`: `CURSE_PROJECT_ID` (numeric CurseForge project ID)

Release flow:

1. Bump version in `isiLive.toc` and update `CHANGELOG.md`
2. Commit + push to `main`
3. Wait until the `Lua Check` workflow is green for that exact `main` commit
4. Create and push stable tag: `git tag isiLive_release_X.Y.Z && git push origin isiLive_release_X.Y.Z`
5. Optional pre-release tags:
   - alpha: `git tag isiLive_alpha_X.Y.Z && git push origin isiLive_alpha_X.Y.Z`
   - beta: `git tag isiLive_beta_X.Y.Z && git push origin isiLive_beta_X.Y.Z`

Notes:
- Deleting a release tag does not delete an already-created CurseForge file; archive/remove that artifact separately on CurseForge if a release fired accidentally.
- The mistaken `isiLive_release_0.9.70` package had to be archived manually after tag cleanup; keep Git cleanup and CurseForge cleanup as two separate steps.
- This avoids the legacy `wow.curseforge.com/api/game/versions` lookup used by older packaging flows.
