# isiLive Architecture

Version baseline: `0.9.132`
Last updated: `2026-04-08`

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
| Entry and orchestration | Composition root, runtime state, wiring, controller lifecycle, keybindings, module presence guards | `isiLive.lua`, `isiLive_runtime_state.lua`, `isiLive_bootstrap.lua`, `isiLive_runtime_setup.lua`, `isiLive_controller_wiring.lua`, `isiLive_controller_init.lua`, `isiLive_factory.lua`, `isiLive_factory_frame_bridge.lua`, `isiLive_factory_controllers.lua`, `isiLive_frame_bridge.lua`, `isiLive_context_helpers.lua`, `isiLive_guards.lua`, `isiLive_bindings.lua` |
| Event gate and dispatch | Enforce stop/pause/hidden/test behavior, route lifecycle handlers, slash command routing | `isiLive_events.lua`, `isiLive_event_handlers.lua`, `isiLive_event_handlers_runtime.lua`, `isiLive_event_handlers_queue.lua`, `isiLive_event_handlers_challenge.lua`, `isiLive_event_utils.lua`, `isiLive_commands.lua` |
| Domain logic | Queue parsing and join-flow, group model, highlight resolution, key sync, refresh, inspect, leader transitions, bounded run stats, cooldown/interrupt tracking, per-spec kick data, Mythic+ timer state | `isiLive_queue.lua`, `isiLive_queue_flow.lua`, `isiLive_group.lua`, `isiLive_highlight.lua`, `isiLive_keysync.lua`, `isiLive_refresh.lua`, `isiLive_inspect.lua`, `isiLive_sync.lua`, `isiLive_stats.lua`, `isiLive_cd_tracker.lua`, `isiLive_kick_tracker.lua`, `isiLive_mplus_timer.lua`, `isiLive_leader_watch.lua` |
| UI composition | Main frame, roster row markup, roster panel, optional game-menu tooling/travel side panels, Blizzard settings canvas, combat utility row, teleport grid and debug navigator, notices, status line | `isiLive_ui.lua`, `isiLive_settings.lua`, `isiLive_roster.lua`, `isiLive_roster_panel.lua`, `isiLive_roster_tooltip.lua`, `isiLive_roster_layout.lua`, `isiLive_teleport_ui.lua`, `isiLive_teleport_debug.lua`, `isiLive_notice.lua`, `isiLive_status.lua` |
| Shared helpers and data | Locale, localized texts, units, realm language data, season map/spell data, safe spell-cooldown wrappers, runtime logging, focused config builders, private tooltip/shared UI helpers, centralized backdrop presets, shared validation/string utilities, debug utilities, demo/test helpers | `isiLive_validation_helpers.lua`, `isiLive_string_utils.lua`, `isiLive_spell_utils.lua`, `isiLive_locale.lua`, `isiLive_texts.lua`, `realm_language_data.lua`, `isiLive_units.lua`, `isiLive_season_data.lua`, `isiLive_teleport.lua`, `isiLive_ui_common.lua`, `isiLive_runtime_log.lua`, `isiLive_log_buffer.lua`, `isiLive_config_builders.lua`, `isiLive_queue_debug.lua`, `isiLive_demo.lua`, `isiLive_test_mode.lua` |

## Runtime Flow

```text
WoW Event
  -> Event Gate (stopped/paused/hidden/test checks)
  -> Event Handler Aggregator
  -> Lifecycle Handler (runtime/queue/challenge)
  -> Domain Controllers (queue/group/highlight/sync/inspect/refresh/stats/cd-tracker/kick-tracker)
  -> Runtime State Update
  -> UI Controllers Render
```

## Main Runtime States

| State | Behavior |
|---|---|
| Running | Full processing active |
| Paused | Processing blocked except required transitions |
| Stopped | Addon processing disabled except minimal control paths |
| Hidden | Window hidden, queue scanning suspended; background addon sync and roster updates continue and may event-drive pre-rendered UI state without polling, but hidden `LFG_LIST_*` gaps do not get replayed later as queue chat. Raid-size groups are a separate hard-off state that hide the UI and suspend background sync instead of following hidden-mode keep-alive behavior. |
| Test/TestAll | Unified full dummy preview mode for UI/testing, including positive RIO delta preview and ghost/leaver row |

## Deterministic Rule Set

1. Resolve dungeon targets only through concrete `activityID -> mapID -> spellID` data.
2. If `mapID` context is missing or ambiguous, keep target unresolved (no name/token guessing).
3. Keep leader-only actions explicit and disabled when unauthorized.
4. Keep combat-safe UI updates deferred when protected operations are blocked; teleport action buttons must not promote parent frames to protected status, blocked main-frame visibility/height changes plus blocked `Esc` shortcut secure-button refreshes must replay on `PLAYER_REGEN_ENABLED`, and the mounted `Esc` strips must stay read-only during combat instead of scheduling host-frame re-shows.
5. Keep teleport-grid button strata/level synchronized with main-frame strata/level.
6. For shared-portcast spells, prioritize exact activity map matching over spell-only suppression.
7. Do not clear highlight state from ambiguous shared spell mappings when exact map context is unknown.
8. Do not clear queue-derived target on negative application follow-up events while already grouped.
9. Mirror Blizzard CVar state for `advancedCombatLogging` and `damageMeterResetOnNewInstance` in the Blizzard settings canvas, write only on explicit user toggle clicks, and still trigger Blizzard damage-meter reset on challenge start when API support exists.
10. Capture per-player RIO baseline on challenge start and enable delta rendering only after delayed post-run refresh; delta is always shown as non-negative `(+X)` prefix.
11. Completed-run stat capture must tolerate delayed Blizzard damage-meter availability through short deterministic retries for both `M+` and tracked non-challenge party exits (`Normal`/`Heroic`/`Mythic`), feeding the `DPS` roster column only.
12. Keep post-run refresh/delta pipeline active when challenge completion/reset events fire while the main window is hidden.
13. Keep sync handshake resilient: HELLO recipients acknowledge with `ACK`, immediately answer with the full local `KEY/STATS/DPS/LOC` snapshot plus current kick state, explicit local refresh force-sends the full local snapshot, and manual `REQSYNC` refresh requests trigger one hidden reply (all buckets: `KEY`, `STATS`, `DPS`, `LOC`, `TARGET`, `KICK`) unless the client is stopped or paused — active Mythic+ runs no longer suppress the reply. `DPS` is always included in background snapshots regardless of frame visibility so peers receive current run stats even while the main window is hidden.
14. In hidden mode, suspend queue scanning and permanent polling; keep background roster/addon-message sync plus required auto-open transitions active, allow event-driven pre-render updates, and permit one forced refresh reply without un-hiding the frame. Fresh grouped joins may still auto-open, but without prior visible queue capture they must not backfill a grouped queue chat summary. After a UI reload while already grouped, `PLAYER_ENTERING_WORLD` must trigger a full group-roster rebuild so the roster panel re-appears immediately, even inside party instances where the hidden-frame event gate would otherwise block `GROUP_ROSTER_UPDATE`.
15. Keep UI action spam guards active for `Re-Sync` and `Share Keys` (debounce/rate-limit behavior); the manual re-sync button currently uses a visible 10-second cooldown state, and `Share Keys` uses a visible 30-second cooldown state while blocked. When any isiLive peer's `SHAREKEYS` message is received, the local `Share Keys` button is locked for 30 s via `TriggerRemoteCooldown` on all receiving clients; an already-running local cooldown is never reset by the remote signal.
16. Keep event-gate dispatch resilient: runtime handler errors must be reported and must not break the gate loop.
17. Keep LuaLS compatibility in shared helpers: guard `_G.debug` access and use explicit color signatures where Blizzard tooltip APIs are still referenced.
18. Shared `isiLive` tooltip frames own their own text layout and must not route UI hover rendering back through the shared Blizzard `GameTooltip`.
19. Raid-size groups hide the visible roster panel, suspend background sync, and suppress duplicate raid-transition notifications by keeping the addon in a hard-off state until the group leaves raid size again.
20. The optional game-menu tooling strip closes the menu before opening its target panel; `ReloadUI` is owned by a secure macro button (`/click GameMenuButtonContinue` + `/reload`) that mirrors `ActionButtonUseKeyDown` and defers blocked secure refreshes to `PLAYER_REGEN_ENABLED`, while the other entries keep direct opener paths for `Professions`, `Talents`, `Spells`, `Achievements`, `Quests`, `Dungeons`, `Journal`, `Collections`, and `Guild`. Both game-menu strips are mounted directly as `GameMenuFrame` children, so combat-open paths do not run overlay `Show`/`Hide` or layout mutations; the secondary travel strip stays further left and exposes `Arkantine`, `Hearthstone`, and `Housing`.
21. Temporarily hidden legacy settings controls stay absent from Blizzard Settings while runtime enforces their fixed defaults (`DPS` on, markers leader-only off, fixed name truncation, legacy 2-column `Travel` grid) until the controls are re-enabled.
22. CdTracker lust onset detection must combine player harmful-aura scanning with direct local lust spellcast signals, accept only numeric aura `spellId` values for lookup, ignore protected or otherwise non-numeric values safely, treat `UNIT_AURA(..., { isFullUpdate = true })` restores as non-onset hydration after zone/reload transitions, and use only a short 2-second `PLAYER_ENTERING_WORLD` suppress window as a safety net before the full restore arrives.
23. Leader promotion/loss detection must compare current local leader state against cached state on both `GROUP_ROSTER_UPDATE` and `PARTY_LEADER_CHANGED`; hidden promotions suppress center notice/chat output but still play the transfer sound.
24. Ready-check lifecycle events must go through a dedicated roster refresh path that reapplies ready-check-dependent row background state, waiting sandglass markers, and the 20-second declined hold without rerunning the generic roster full render or touching secure role-button attributes.
25. Roster leader markers must be derived only from mirrored `UnitIsGroupLeader` state; the roster display renders a 16x16 crown for those rows, and synced leaders keep the blue heart before the crown.
26. Persisted ghost rows may remain in non-full groups, but roster ordering must keep all active members ahead of ghosts so visible 5-row clipping never hides a current group member behind stale leavers.

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
   - `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1`
   - `cmd /c tools\check.cmd`
   - Lua syntax parse (`luac -p` for all `.lua` files)
   - `ISILIVE_MAX_FILE_LINES=3200 ISILIVE_MAX_FUNCTION_LINES=420 lua tools/lua_metrics_check.lua`
2. Runtime logic checks:
   - `lua tools/validate_rules_logic.lua`
   - `lua tools/validate_architecture_rules.lua`
   - `lua tools/validate_usecases.lua`
3. `tools/validate_rules_logic.lua` validates active contracts from `RULES_LOGIC.md` against deterministic test names.
4. `tools/validate_architecture_rules.lua` validates active architecture contracts from `ARCHITECTURE_RULES.md` against deterministic test names.
5. `tools/validate_usecases.lua` runs both validators first and then covers 483 scenarios across 36 modules, while the rule validators currently index 483 deterministic tests.

The local `tools/check.ps1` / `tools/check.cmd` wrappers are the preferred entrypoint for the static gate because they route `luacheck` through the repo-local Windows shim instead of invoking the LuaRocks script directly.

## UI Structure (ASCII Sketch)

```text
| isiLive                                                 v0.9.132 Open/Close CTRL-F9 [H][V][M][M2][X]|
|---------------------------------------------------------------------------------------------------|
| Spec   Name         Flag Key     iLvl RIO        DPS                M+Managment  Marker    Travel  |
|---------------------------------------------------------------------------------------------------|
| [Tank] PlayerOne    [ ]  DB +14  633  (+12)3521 321.1K  [Blue]              [Readycheck]          |
| [Heal] PlayerTwo    [ ]  DAWN+12 629  (+0)3410  287.4K  [Grn]               [Countdown10]         |
| [DPS]  PlayerThree  [ ]  -       631  3377      -       [Purp]              [Countdown 0]         |
| [DPS]  PlayerFour   [ ]  AK +10  626  3290      301.8K  [Red]               [Share Keys]          |
| [DPS]  PlayerFive   [ ]  OFG+11  628  3333      298.2K  [Yel]               [Re-Sync]             |
|                                               ... [Circle] [Moon] [Skull] ...                     |
|                                                                             [Teleport Grid...]    |
| BR: 2/3 06:20  BL: 05:00                                                                        |
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
| [Re-Sync]                   [Yellow]                            |
| [... Circle / Moon / Skull stay stacked below in mini mode ...] |
+----------------------------------------------------------------+

Horizontal Mini Mode:

|                                      [H][V][M][X]|
|---------------------------------------------------|
| [CD 0] [CD] [RC]                                  |
| [Blue][Green][Purple][Red][Yel][Cir][Moo][Sku]    |
+-------------------------------------+
```

In addition to the main roster frame, `isiLive_ui.lua` can attach optional tooling and travel panels left of `GameMenuFrame`, and `isiLive_settings.lua` registers the Blizzard Settings canvas for localized config/state mirrors.

## Current Controller Boundaries

| Controller | Input | Output |
|---|---|---|
| RuntimeState | Root orchestration and controller callbacks | Central mutable runtime snapshot (`roster`, queue target, flags, rio baseline, ready-check state, layout/collapse state) |
| Group | Group roster events | Rebuilt roster model, mirrored local leader state per roster entry, ghost retention/pruning, and lifecycle transitions |
| Highlight | Active listing and queue target | Active teleport spell and highlight state |
| KeySync | Sync messages and owned snapshot data | Roster key/stats/dps/location backfill, key ownership, and sync markers |
| Re-Sync | User refresh action | Forced local snapshot, groupwide sync request, inspect refresh pipeline, and a visible 10s cooldown |
| Share Keys | User chat/share action | Immediate own-key party post, groupwide `SHAREKEYS` request to peers, a visible 30s local cooldown, and remote-triggered 30s cooldown lock on all peer clients that receive the `SHAREKEYS` message (guarded: does not reset an already-running local cooldown) |
| EventHandlersRuntime | Addon/world/combat/inspect/sync events | Startup, hidden-mode sync, immediate full-state reply on new peer `HELLO`, `UNIT_AURA` full-update forwarding for cd tracking, regen recovery for pending visibility/height, inspect dispatch |
| EventHandlersQueue | LFG queue/listing events | Visible-mode queue capture, pending-join preservation on negative follow-ups, and joined-key tracking |
| EventHandlersChallenge | Challenge and ready-check events | Run lifecycle, delayed refresh, rio delta enable, ready-check state, declined-hold tracking, and dedicated ready-check UI refresh routing |
| Stats | Challenge/non-challenge party run completion signals plus Blizzard damage-meter session | Bounded last-run DPS snapshots with short delayed-session retry (persistent only for the matching local character, foreign players session-only) |
| CdTracker | Battle-res charges via `C_Spell.GetSpellCharges` struct-return, numeric-only harmful lust-aura scans, direct lust spellcasts, and `isFullUpdate` aura-restore hydration | Live BRes charges/cooldown and Lust countdown row state with zone-transition-safe onset suppression |
| KickTracker | Spec ID lookup, spec change notifications, and own kick state sync; pet-interrupt support for Warlock (`Spell Lock` 24s / `Axe Toss` 30s) and Demon Hunter Devourer | Per-spec interrupt spell ID and cooldown; stale cooldown cleared immediately on spec change; kick state forwarded to sync for roster kick-column rendering |
| LeaderWatch | `GROUP_ROSTER_UPDATE` / `PARTY_LEADER_CHANGED` plus cached leader state | Leader-only button refresh, visible center notice on promotion, and transfer sound feedback even for hidden promotions unless the user disables it |
| RosterPanel | Roster model and localization | Main table rendering, active-before-ghost row ordering under the 5-row budget, 16x16 leader crown plus synced-heart marker ordering, dedicated ready-check row-background refresh with waiting sandglass and declined hold, DPS column, dedicated kick-column refresh path, CD tracker row, and action button callbacks |
| SettingsPanel | Locale/CVar/SavedVariable getters plus toggle callbacks | Blizzard Settings canvas, language selector, visible display/behavior/debug toggles, UI/background sliders, default-open layout selector, optional roster column-guide toggle, sound toggles for leader-transfer/group-join feedback, and temporary legacy-setting suppression |
| TeleportUI | Season teleport entries and state | Insecure-action teleport button states, deterministic season-slot placement, locale-aware `M2` short-code overlays while ready, and cooldown labels that take precedence while on cooldown |

## Extension Points

1. New season support should be added in `isiLive_season_data.lua` and consumed through `isiLive_teleport.lua`.
2. New UI actions and config surfaces should be added through `isiLive_roster_panel.lua`, `isiLive_ui.lua`, or `isiLive_settings.lua`, then wired through `isiLive_controller_wiring.lua` / `isiLive_factory.lua`. Roster tooltip and layout helpers belong in `isiLive_roster_tooltip.lua` and `isiLive_roster_layout.lua` respectively; factory context/controller helpers belong in `isiLive_factory_frame_bridge.lua` and `isiLive_factory_controllers.lua`.
3. New event behavior should pass through gate logic first and then land in the appropriate lifecycle handler to keep runtime state consistent.
