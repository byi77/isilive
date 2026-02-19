# isiLive Architecture

Version baseline: `0.9.32`
Last updated: `2026-02-19`

## Purpose

`isiLive` is a WoW Mythic+ group helper addon.
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
| Shared helpers and data | Locale, units, season map/spell data, config builders | `isiLive_locale.lua`, `isiLive_units.lua`, `isiLive_season_data.lua`, `isiLive_teleport.lua`, `isiLive_config_builders.lua` |

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
| Hidden | Window hidden and non-essential work halted |
| Test/TestAll | Controlled preview mode for UI/testing |

## Deterministic Rule Set

1. Prefer concrete activity/map/spell data over fuzzy name matching.
2. Avoid fallback-of-fallback chains when a primary source is available.
3. Keep leader-only actions explicit and disabled when unauthorized.
4. Keep combat-safe UI updates deferred when protected operations are blocked.
5. For shared-portcast spells, prioritize exact activity map matching over spell-only suppression.
6. Do not clear highlight state from ambiguous shared spell mappings when exact map context is unknown.

## Deterministic Validation Gates

Local release-grade validation is intentionally split into static and runtime gates:

1. Static checks:
   - `stylua --check .`
   - `luacheck --exclude-files ".luarocks/**" -- .`
   - Lua syntax parse (`luac -p` for all `.lua` files)
   - `lua tools/lua_metrics_check.lua`
2. Runtime logic checks:
   - `lua tools/validate_usecases.lua`
3. `tools/validate_usecases.lua` covers critical queue/highlight/cooldown scenarios and shared-portcast edge behavior.

## UI Structure (ASCII Sketch)

```text
+--------------------------------------------------------------------------------------------------+
| isiLive (will be renamed to isiKeyMPlus soon)                                      V.0.9.32     |
|--------------------------------------------------------------------------------------------------|
| Spec         Name              Flag        Key         iLvl      RIO      M+ Management M+travel |
|--------------------------------------------------------------------------------------------------|
| [Tank]       PlayerOne         DE          DB +14      633       3521                           |
| [Healer]     PlayerTwo         EN          HOA +12     629       3410                           |
| [DPS]        PlayerThree       FR          -           631       3377      [Readycheck]         |
| [DPS]        PlayerFour        ES          AK +10      626       3290      [Countdown10]        |
| [DPS]        PlayerFive        DE          OFG +11     628       3333      [Countdown Cancel]   |
|                                                                       [Refresh]                  |
|                                                                       [Share Keys]               |
|                                                                 [Teleport Grid Buttons...]       |
|--------------------------------------------------------------------------------------------------|
| Lead: Yes   M+: Active   State: Running   Dungeon: Mythic                                       |
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
