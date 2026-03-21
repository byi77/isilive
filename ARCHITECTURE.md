# isiLive Architecture

Version baseline: `0.9.90`
Last updated: `2026-03-21`

## Purpose

`isiLive` is a WoW Mythic+ group helper addon.
Internal runtime namespace and module filenames remain `isiLive_*`.
The architecture is event-driven and split into clear runtime layers:

1. WoW event input and gating.
2. Domain processing for queue/group/sync/highlight/inspect.
3. UI rendering and user actions.

## Layer Overview

| Layer | Responsibility | Primary files |
|---|---|---|
| Entry and orchestration | Composition root, runtime state, wiring, controller lifecycle | `isiLive.lua`, `isiLive_runtime_state.lua`, `isiLive_bootstrap.lua`, `isiLive_runtime_setup.lua`, `isiLive_controller_wiring.lua`, `isiLive_factory.lua`, `isiLive_factory_frame_bridge.lua`, `isiLive_factory_controllers.lua` |
| Event gate and dispatch | Enforce stop/pause/hidden/test behavior and route lifecycle handlers | `isiLive_events.lua`, `isiLive_event_handlers.lua`, `isiLive_event_handlers_runtime.lua`, `isiLive_event_handlers_queue.lua`, `isiLive_event_handlers_challenge.lua`, `isiLive_event_utils.lua` |
| Domain logic | Queue parsing, group model, highlight resolution, key sync, refresh, inspect, bounded run stats | `isiLive_queue.lua`, `isiLive_queue_flow.lua`, `isiLive_group.lua`, `isiLive_highlight.lua`, `isiLive_keysync.lua`, `isiLive_refresh.lua`, `isiLive_inspect.lua`, `isiLive_sync.lua`, `isiLive_stats.lua` |
| UI composition | Main frame, roster panel, optional game-menu side panel, Blizzard settings canvas, teleport grid, notices, status line | `isiLive_ui.lua`, `isiLive_settings.lua`, `isiLive_roster_panel.lua`, `isiLive_roster_tooltip.lua`, `isiLive_roster_layout.lua`, `isiLive_teleport_ui.lua`, `isiLive_notice.lua`, `isiLive_status.lua` |
| Shared helpers and data | Locale, localized texts, units, season map/spell data, runtime logging, focused config builders, private tooltip/shared UI helpers, centralized backdrop presets | `isiLive_locale.lua`, `isiLive_texts.lua`, `isiLive_units.lua`, `isiLive_season_data.lua`, `isiLive_teleport.lua`, `isiLive_ui_common.lua`, `isiLive_runtime_log.lua`, `isiLive_log_buffer.lua`, `isiLive_config_builders.lua` |

## Runtime Flow

```text
WoW Event
  -> Event Gate (stopped/paused/hidden/test checks)
  -> Event Handler Aggregator
  -> Lifecycle Handler (runtime/queue/challenge)
  -> Domain Controllers (queue/group/highlight/sync/inspect/refresh/stats)
  -> Runtime State Update
  -> UI Controllers Render
```

## Main Runtime States

| State | Behavior |
|---|---|
| Running | Full processing active |
| Paused | Processing blocked except required transitions |
| Stopped | Addon processing disabled except minimal control paths |
| Hidden | Window hidden, queue scanning suspended; background addon sync and roster updates continue and may event-drive pre-rendered UI state without polling |
| Test/TestAll | Unified full dummy preview mode for UI/testing, including positive RIO delta preview and ghost/leaver row |

## Deterministic Rule Set

1. Resolve dungeon targets only through concrete `activityID -> mapID -> spellID` data.
2. If `mapID` context is missing or ambiguous, keep target unresolved (no name/token guessing).
3. Keep leader-only actions explicit and disabled when unauthorized.
4. Keep combat-safe UI updates deferred when protected operations are blocked; teleport action buttons must not promote parent frames to protected status, and blocked main-frame visibility/height changes plus blocked `Esc` shortcut secure-button refreshes must replay on `PLAYER_REGEN_ENABLED`.
5. Keep teleport-grid button strata/level synchronized with main-frame strata/level.
6. For shared-portcast spells, prioritize exact activity map matching over spell-only suppression.
7. Do not clear highlight state from ambiguous shared spell mappings when exact map context is unknown.
8. Do not clear queue-derived target on negative application follow-up events while already grouped.
9. Mirror Blizzard CVar state for `advancedCombatLogging` and `damageMeterResetOnNewInstance` in the Blizzard settings canvas, write only on explicit user toggle clicks, and still trigger Blizzard damage-meter reset on challenge start when API support exists.
10. Capture per-player RIO baseline on challenge start and enable delta rendering only after delayed post-run refresh; delta is always shown as non-negative `(+X)` prefix.
11. Completed-run DPS capture must tolerate delayed Blizzard damage-meter availability through short deterministic retries for both `M+` and tracked non-challenge party exits (`Normal`/`Heroic`/`Mythic`).
12. Keep post-run refresh/delta pipeline active when challenge completion/reset events fire while the main window is hidden.
13. Keep sync handshake resilient: HELLO recipients acknowledge with `ACK`, explicit local refresh force-sends the local `HELLO/KEY/STATS/DPS/LOC` snapshot, and manual `REQSYNC` refresh requests may trigger one hidden `KEY/STATS/DPS/LOC` reply when locally allowed.
14. In hidden mode, suspend queue scanning and permanent polling; keep background roster/addon-message sync plus required auto-open transitions active, allow event-driven pre-render updates, and permit one forced refresh reply without un-hiding the frame.
15. Keep UI action spam guards active for `Refresh` and `Share Keys` (debounce/rate-limit behavior).
16. Keep event-gate dispatch resilient: runtime handler errors must be reported and must not break the gate loop.
17. Keep LuaLS compatibility in shared helpers: guard `_G.debug` access and use explicit color signatures where Blizzard tooltip APIs are still referenced.
18. Shared `isiLive` tooltip frames own their own text layout and must not route UI hover rendering back through the shared Blizzard `GameTooltip`.
19. Raid-size groups force the visible roster panel into H mode, hide roster rows, and suppress duplicate raid-transition notifications until the group leaves raid size again.
20. The optional game-menu shortcut strip closes the menu before opening its target panel; `ReloadUI` is owned by a secure macro button (`/click GameMenuButtonContinue` + `/reload`) that mirrors `ActionButtonUseKeyDown`, defers blocked secure refreshes to `PLAYER_REGEN_ENABLED`, while the other entries keep direct opener paths for `Professions`, `Talents`, `Spells`, `Achievements`, `Quests`, `Dungeons`, `Journal`, `Collections`, and `Guild`.
21. Temporarily hidden legacy settings controls stay absent from Blizzard Settings while runtime enforces their fixed defaults (`DPS` on, markers leader-only off, sound off, fixed name truncation, legacy 2-column `Travel` grid) until the controls are re-enabled.

## Architecture Contract Set

`ARCHITECTURE_RULES.md` defines the structural contracts for the current module split.
These rules are not style rules like `pep8`; they describe allowed ownership and dependency boundaries and are enforced through deterministic source/module tests.

Current active architecture contracts cover:
- `isiLive.lua` as composition root
- `isiLive_event_handlers.lua` as lifecycle aggregator
- `isiLive_runtime_setup.lua` using context-based controller factories
- `isiLive_runtime_state.lua` as shared mutable runtime-state API
- `isiLive_controller_wiring.lua` exporting context factories
- `isiLive_config_builders.lua` staying focused without legacy event/group dependency builders

## Deterministic Validation Gates

Local release-grade validation is intentionally split into static and runtime gates:

1. Static checks:
   - `stylua --check .`
   - `luacheck --exclude-files ".luarocks/**" -- .`
   - Lua syntax parse (`luac -p` for all `.lua` files)
   - `lua tools/lua_metrics_check.lua`
2. Runtime logic checks:
   - `lua tools/validate_rules_logic.lua`
   - `lua tools/validate_architecture_rules.lua`
   - `lua tools/validate_usecases.lua`
3. `tools/validate_rules_logic.lua` validates active contracts from `RULES_LOGIC.md` against deterministic test names.
4. `tools/validate_architecture_rules.lua` validates active architecture contracts from `ARCHITECTURE_RULES.md` against deterministic test names.
5. `tools/validate_usecases.lua` runs both validators first and then covers 308 deterministic tests indexed and 310 scenarios across 30 modules: architecture/queue/highlight/event-handlers/event-handler lifecycles/queue-flow/spell-utils/teleport/group/event-utils/locale/sync/guards/inspect/test-mode/leader-watch/refresh/commands/runtime-log/runtime-state/roster/roster-panel/roster-panel-layout/status/stats/units/ui/roster-display/taint/tank-helper logic.

## UI Structure (ASCII Sketch)

```text
| isiLive                                                                          V.0.9.90 [H][V][M][X]|
|---------------------------------------------------------------------------------------------------|
| Spec   Name         Flag Key     iLvl RIO        DPS    M+Managment  Marker    Travel              |
|---------------------------------------------------------------------------------------------------|
| [Tank] PlayerOne    [ ]  DB +14  633  (+12)3521 321.1K  [Blue]              [Readycheck]          |
| [Heal] PlayerTwo    [ ]  DAWN+12 629  (+0)3410  287.4K  [Grn]               [Countdown10]         |
| [DPS]  PlayerThree  [ ]  -       631  3377      -       [Purp]              [Countdown 0]         |
| [DPS]  PlayerFour   [ ]  AK +10  626  3290      301.8K  [Red]               [Share Keys]          |
| [DPS]  PlayerFive   [ ]  OFG+11  628  3333      298.2K  [Yel]               [Refresh]             |
|                                               ... [Circle] [Moon] [Skull] ...                     |
|                                                                             [Teleport Grid...]    |
|---------------------------------------------------------------------------------------------------|
| Lead: Yes   M+: Active   State: Running   Dungeon: Mythic   Target Dungeon: Ara-Kara +14          |
+---------------------------------------------------------------------------------------------------+

Collapsed / Vertical Mini Mode:

|                                          [H][V][M][X]|
|----------------------------------------------------------------|
| M+Managment                 Marker                              |
| [Readycheck]                [Blue]                              |
| [Countdown10]               [Green]                             |
| [Countdown 0]               [Purple]                            |
| [Share Keys]                [Red]                               |
| [Refresh]                   [Yellow]                            |
| [... Circle / Moon / Skull stay stacked below in mini mode ...] |
+----------------------------------------------------------------+

Horizontal Mini Mode:

|                                      [H][V][M][X]|
|---------------------------------------------------|
| [CD 0] [CD] [RC]                                  |
| [Blue][Green][Purple][Red][Yel][Cir][Moo][Sku]    |
+-------------------------------------+
```

In addition to the main roster frame, `isiLive_ui.lua` can attach an optional shortcut panel left of `GameMenuFrame`, and `isiLive_settings.lua` registers the Blizzard Settings canvas for localized config/state mirrors.

## Current Controller Boundaries

| Controller | Input | Output |
|---|---|---|
| RuntimeState | Root orchestration and controller callbacks | Central mutable runtime snapshot (`roster`, queue target, flags, rio baseline, ready-check state, layout/collapse state) |
| QueueFlow | LFG events and queue snapshots | Joined target metadata |
| Group | Group roster events | Rebuilt roster model, ghost retention/pruning, and lifecycle transitions |
| Highlight | Active listing and queue target | Active teleport spell and highlight state |
| KeySync | Sync messages and owned snapshot data | Roster key/stats/dps/location backfill, key ownership, and sync markers |
| Refresh | User refresh action | Forced local snapshot, groupwide sync request, and inspect refresh pipeline |
| EventHandlersRuntime | Addon/world/combat/inspect/sync events | Startup, hidden-mode sync, regen recovery for pending visibility/height, inspect dispatch |
| EventHandlersQueue | LFG queue/listing events | Queue capture, target preservation, joined-key tracking |
| EventHandlersChallenge | Challenge and ready-check events | Run lifecycle, delayed refresh, rio delta enable, ready-check state |
| Stats | Challenge/non-challenge party run completion signals plus Blizzard damage-meter session | Bounded last-run DPS snapshots with short delayed-session retry (persistent only for the matching local character, foreign players session-only) |
| RosterPanel | Roster model and localization | Main table rendering and action button callbacks |
| SettingsPanel | Locale/CVar/SavedVariable getters plus toggle callbacks | Blizzard Settings canvas, language selector, visible display/behavior/debug toggles, UI/background sliders, default-open layout selector, optional roster column-guide toggle, and temporary legacy-setting suppression |
| TeleportUI | Season teleport entries and state | Insecure-action teleport button states, deterministic season-slot placement, legacy 2-column travel layout, and cooldown labels |

## Extension Points

1. New season support should be added in `isiLive_season_data.lua` and consumed through `isiLive_teleport.lua`.
2. New UI actions and config surfaces should be added through `isiLive_roster_panel.lua`, `isiLive_ui.lua`, or `isiLive_settings.lua`, then wired through `isiLive_controller_wiring.lua` / `isiLive_factory.lua`. Roster tooltip and layout helpers belong in `isiLive_roster_tooltip.lua` and `isiLive_roster_layout.lua` respectively; factory context/controller helpers belong in `isiLive_factory_frame_bridge.lua` and `isiLive_factory_controllers.lua`.
3. New event behavior should pass through gate logic first and then land in the appropriate lifecycle handler to keep runtime state consistent.
