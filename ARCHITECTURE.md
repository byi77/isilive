# isiKeyMPlus Architecture

Version baseline: `0.9.51`
Last updated: `2026-02-25`

## Purpose

`isiKeyMPlus` is a WoW Mythic+ group helper addon.
Internal runtime namespace and module filenames remain `isiLive_*`.
The architecture is event-driven and split into clear runtime layers:

1. WoW event input and gating.
2. Domain processing for queue/group/sync/highlight/inspect.
3. UI rendering and user actions.

## Layer Overview

| Layer | Responsibility | Primary files |
|---|---|---|
| Entry and orchestration | Runtime state, wiring, controller lifecycle | `isiLive.lua`, `isiLive_bootstrap.lua`, `isiLive_runtime_setup.lua` |
| Event gate and dispatch | Enforce stop/pause/hidden/test behavior and route events | `isiLive_events.lua`, `isiLive_event_handlers.lua`, `isiLive_event_utils.lua` |
| Domain logic | Queue parsing, group model, highlight resolution, key sync, refresh, inspect | `isiLive_queue.lua`, `isiLive_queue_flow.lua`, `isiLive_group.lua`, `isiLive_highlight.lua`, `isiLive_keysync.lua`, `isiLive_refresh.lua`, `isiLive_inspect.lua`, `isiLive_sync.lua` |
| UI composition | Main frame, roster panel, teleport grid, notices, status line | `isiLive_ui.lua`, `isiLive_roster_panel.lua`, `isiLive_teleport_ui.lua`, `isiLive_notice.lua`, `isiLive_status.lua` |
| Shared helpers and data | Locale, units, season map/spell data, runtime logging, config builders | `isiLive_locale.lua`, `isiLive_units.lua`, `isiLive_season_data.lua`, `isiLive_teleport.lua`, `isiLive_runtime_log.lua`, `isiLive_log_buffer.lua`, `isiLive_config_builders.lua` |

## Runtime Flow

```text
WoW Event
  -> Event Gate (stopped/paused/hidden/test checks)
  -> Event Handler Controller
  -> Domain Controllers (queue/group/highlight/sync/inspect/refresh)
  -> Runtime State Update
  -> UI Controllers Render
```

## Main Runtime States

| State | Behavior |
|---|---|
| Running | Full processing active |
| Paused | Processing blocked except required transitions |
| Stopped | Addon processing disabled except minimal control paths |
| Hidden | Window hidden, queue/sync events suppressed, only transition events kept |
| Test/TestAll | Controlled preview mode for UI/testing |

## Deterministic Rule Set

1. Resolve dungeon targets only through concrete `activityID -> mapID -> spellID` data.
2. If `mapID` context is missing or ambiguous, keep target unresolved (no name/token guessing).
3. Keep leader-only actions explicit and disabled when unauthorized.
4. Keep combat-safe UI updates deferred when protected operations are blocked; frame dragging remains available.
5. Keep teleport-grid button strata/level synchronized with main-frame strata/level.
6. For shared-portcast spells, prioritize exact activity map matching over spell-only suppression.
7. Do not clear highlight state from ambiguous shared spell mappings when exact map context is unknown.
8. Do not clear queue-derived target on negative application follow-up events while already grouped.
9. Keep `advancedCombatLogging` hard-enabled and trigger Blizzard damage-meter reset on challenge start when API support exists.
10. Capture per-player RIO baseline on challenge start and enable delta rendering only after delayed post-run refresh; delta is always shown as non-negative `(+X)` prefix.
11. Keep post-run refresh/delta pipeline active when challenge completion/reset events fire while the main window is hidden.
12. Keep sync handshake resilient: HELLO recipients acknowledge and force-send own KEY snapshot so refresh-driven cache clears repopulate deterministically.
13. In hidden mode, suppress queue/sync event processing; keep only required auto-open transitions (`GROUP_ROSTER_UPDATE`, key-end events).
14. Keep UI action spam guards active for `Refresh` and `Share Keys` (debounce/rate-limit behavior).
15. Keep event-gate dispatch resilient: runtime handler errors must be reported and must not break the gate loop.

## Deterministic Validation Gates

Local release-grade validation is intentionally split into static and runtime gates:

1. Static checks:
   - `stylua --check .`
   - `luacheck --exclude-files ".luarocks/**" -- .`
   - Lua syntax parse (`luac -p` for all `.lua` files)
   - `lua tools/lua_metrics_check.lua`
2. Runtime logic checks:
   - `lua tools/validate_rules_logic.lua`
   - `lua tools/validate_usecases.lua`
3. `tools/validate_rules_logic.lua` validates active contracts from `RULES_LOGIC.md` against deterministic test names.
4. `tools/validate_usecases.lua` runs the rules validator first and then covers 140 scenarios across 20 modules: queue/highlight/cooldown/teleport/group/sync/locale/commands/guards/test-mode/leader-watch/refresh/status/ui/roster/runtime-log/roster-panel logic.

## UI Structure (ASCII Sketch)

```text
+--------------------------------------------------------------------------------------------------+
| isiKeyMPlus                                                                        V.0.9.51     |
|--------------------------------------------------------------------------------------------------|
| Spec         Name              Flag        Key         iLvl      RIO      M+Managment  M+Travel   |
|--------------------------------------------------------------------------------------------------|
| [Tank]       PlayerOne         DE          DB +14      633       (+12)3521                      |
| [Healer]     PlayerTwo         EN          HOA +12     629       (+0)3410                       |
| [DPS]        PlayerThree       FR          -           631       3377         [Readycheck]      |
| [DPS]        PlayerFour        ES          AK +10      626       3290         [Countdown10]     |
| [DPS]        PlayerFive        DE          OFG +11     628       3333         [Countdown 0]     |
|                                                                       [Refresh]                  |
|                                                                       [Share Keys]               |
|                                                                 [Teleport Grid Buttons...]       |
|--------------------------------------------------------------------------------------------------|
| Lead: Yes   M+: Active   State: Running   Dungeon: Mythic   Target Dungeon: Ara-Kara +14       |
+--------------------------------------------------------------------------------------------------+
```

## Current Controller Boundaries

| Controller | Input | Output |
|---|---|---|
| QueueFlow | LFG events and queue snapshots | Joined target metadata |
| Group | Group roster events | Rebuilt roster model and lifecycle transitions |
| Highlight | Active listing and queue target | Active teleport spell and highlight state |
| KeySync | Sync messages and owned key snapshot | Roster key map ownership and sync markers |
| Refresh | User refresh action | Forced key/sync/inspect refresh pipeline |
| RosterPanel | Roster model and localization | Main table rendering and action button callbacks |
| TeleportUI | Season teleport entries and state | Secure teleport button states and cooldown labels |

## Extension Points

1. New season support should be added in `isiLive_season_data.lua` and consumed through `isiLive_teleport.lua`.
2. New UI actions should be added through controller interfaces in `isiLive_roster_panel.lua` plus wiring in `isiLive_controller_init.lua`.
3. New event behavior should pass through gate logic first to keep runtime state consistent.
