# isiLive Use Cases

Version baseline: `0.9.133`
Last updated: `2026-04-08`

## Actors

1. Player (group leader or member).
2. isiLive addon runtime (internal namespace: `isiLive_*`).
3. WoW APIs and events.

## Preconditions

1. Addon is loaded and not in `stopped` state.
2. Season dataset is selected by `ACTIVE_SEASON_ID` (currently `midnight_s1` with the live 8-dungeon Midnight Season 1 portal pool).
3. Relevant UI is visible for queue scanning and rendering; while hidden, addon-message sync and roster updates may still run in the background, UI can be auto-opened by fresh group join, key-end, real dungeon-entry transition logic, or UI reload while already grouped, and explicit refresh requests may still trigger one gated hidden sync reply (including during an active Mythic+ run — only stopped or paused state suppresses the reply).
4. Raid-size groups are a separate hard-off state: UI is off and background processing is disabled.
5. The optional `Esc` tooling and travel strips are enabled unless the user explicitly disables them in addon settings.

## Use Case Matrix

| ID | Title | Primary result |
|---|---|---|
| UC-01 | Invite detection and target resolution | Correct dungeon target is resolved deterministically |
| UC-02 | Chat hint and teleport highlight | User gets chat/info hint and sees correct portal highlight |
| UC-03 | Enter exact target dungeon | Highlight turns off immediately on exact target entry |
| UC-04 | Use portal cast | All portal casts receive 8h cooldown behavior |
| UC-05 | Cooldown lifecycle | Cooldown expires naturally or resets after dungeon finish |
| UC-06 | Share keys action | Group keys are announced in party chat via button |
| UC-07 | RIO delta visibility | Per-run RIO delta is shown as non-negative `(+X)` prefix |
| UC-08 | Post-run stats snapshot | Latest dungeon DPS per player is read from Blizzard damage meter and shown in roster + tooltip |
| UC-09 | Manual Role Marker Buttons | Tank/Healer role icons are secure buttons to set raid markers |
| UC-10 | Raid zero-process transition | Raid-size groups hide the addon UI and suppress background processing |
| UC-11 | M+Marker World Markers | Vertical bar of 8 secure world-marker buttons for immediate place/clear |
| UC-12 | Roster Panel Mini Mode | Collapse toggle hides roster list and `Travel`, while keeping compact Marker and management tools visible |
| UC-13 | Esc shortcuts and addon settings | Player gets dual Blizzard-UI entry surfaces plus localized config toggles and sound preferences |
| UC-14 | Combat utility tracker | Live BRes, lust, Mythic+ timer, and synced interrupt state stay visible in the roster panel |

## UC-01 Invite Detection Without Target Guessing

Goal: detect queue invite/join context without guessing a dungeon target.

1. Trigger: LFG list and queue events arrive while main UI is visible.
2. Inputs: pending status plus any visible group metadata from the queue payload.
3. Processing: queue handling stores grouped-join context only; dungeon/teleport resolution from queue payload is disabled.
4. Output: pending grouped-join context contains at most the captured group name.
5. Success criteria: grouped queue chat can use captured group context, and no dungeon target is guessed from queue events.

## UC-02 Grouped Queue Chat Summary

Goal: inform the player about a grouped queue join without inventing portal or dungeon context.

1. Trigger: group join is confirmed, grouped queue context exists, and player is not the local group leader.
2. Processing: addon posts one grouped queue/join summary block in chat only; no invite hint, no queue center notice, and no queue-based teleport highlight are produced.
3. Processing: queue joins do not update dungeon target state.
4. User action: player can click the portal button or move manually to dungeon.
5. Rule: follow-up negative application status updates must not fabricate or restore queue-based dungeon target context.
6. Rule: there is no separate generic `Dungeon erkannt` chat line; persistent target context is carried by `Target Dungeon` when available from non-queue sources.
7. Success criteria: grouped queue chat fires only for valid member joins, stays leader-suppressed, and never creates a guessed dungeon target.

## UC-03 Enter Exact Target Dungeon

Goal: remove highlight as soon as the player is in the exact dungeon target.

1. Trigger: zone/instance change events indicate current dungeon map.
2. Processing: current map is matched against active target map.
3. Rule: if exact target map is known and current map equals that map, highlight is turned off immediately.
4. Rule: for shared portcasts (for example Tazavesh streets/gambit), spell-only suppression must not clear ambiguously when multiple maps are mapped.
5. Rule: spell-only suppression is allowed only when mapping resolves to exactly one target map.
6. Success criteria: no active highlight while already inside the exact targeted dungeon, and no premature clear on sibling shared-portcast maps.

## UC-04 Use Portal Cast

Goal: apply portal cooldown behavior only when the portal cast is actually used.

1. Trigger: player clicks portal button and cast succeeds.
2. Processing: portal action buttons use `InsecureActionButtonTemplate` so parent frame show/hide remains combat-toggleable.
3. Processing: cooldown state is read from WoW spell cooldown APIs.
4. Rule: all dungeon portal casts share the same 8h cooldown window after use.
5. Rule: visible portal slots stay in deterministic season display order even when multiple dungeons share one teleport spell.
6. Output: teleport grid shows cooldown time and lock state consistently; in `M2`, ready buttons also show the locale-aware dungeon short code directly on the icon.
7. Rule: while a teleport is on cooldown, the `M2` short-code overlay is hidden so the cooldown timer remains readable.
8. Success criteria: every portal button reflects the shared cooldown without slot drift and `M2` keeps destination recognition without requiring mouseover.

## UC-05 Cooldown Lifecycle

Goal: support both normal cooldown expiry and dungeon-finish reset.

1. Trigger A: cooldown timer naturally reaches zero.
2. Result A: portal casts return to ready state.
3. Trigger B: dungeon completion/reset flow emits completion signals.
4. Result B: cooldown can be reset according to completion logic.
5. Success criteria: cooldown state converges to ready in both supported paths.

## UC-06 Share Keys Action

Goal: allow user to post current party keys quickly.

1. Trigger: user clicks `Share Keys` button in right control stack.
2. Processing: addon posts the local player's own key line immediately, preferring the Blizzard owned-keystone hyperlink and falling back to a localized dungeon short code plus level.
3. Processing: addon then broadcasts `SHAREKEYS` over the addon sync channel so other `isiLive` peers can post their own local key line without requiring a full `Re-Sync`.
4. Output: one local-player key line is sent to `PARTY` immediately, with local print fallback on send failure; additional peer lines may follow from responding group members.
5. Rule: `Share Keys` button clicks are debounced to suppress rapid duplicate chat output and show a visible `30s` cooldown in the button label while blocked.
5a. Rule: when a client receives an incoming `SHAREKEYS` sync message, the local `Share Keys` button is also locked for `30s` via `TriggerRemoteCooldown`; an already-running local cooldown is not reset by the remote signal.
6. Related action: the adjacent `Re-Sync` button forces the hidden-peer sync handshake and then stays on a visible `10s` cooldown.
7. Success criteria: the initiating user always gets the local owned keystone line first, and peer responses remain distributed per sender instead of being rebuilt from cached remote roster data.

## UC-07 RIO Delta Visibility

Goal: show pre/post-run rating change per player in roster without negative display noise.

1. Trigger: `CHALLENGE_MODE_START` fires while roster is available.
2. Processing: addon captures baseline RIO per normalized player identity.
3. Trigger: `CHALLENGE_MODE_COMPLETED`/`CHALLENGE_MODE_RESET` schedules delayed post-run refresh.
4. Processing: delta display is enabled only after the delayed refresh path succeeds (retry if still blocked by transient challenge-state timing), including when the completion/reset event was received while main window is hidden.
5. Trigger: roster is rendered after rating updates.
6. Output: RIO column shows `(+X)RIO` when baseline+current values exist.
7. Rule: delta is clamped to non-negative values (`+0` minimum); no minus rendering.
8. Rule: test modes (`/isilive test`, `/isilive testall`) use the same full dummy preview path, including visible positive dummy delta preview and a ghost/leaver row.
9. Success criteria: display is stable per player across unit-slot changes and never shows negative delta.

## UC-08 Post-Run Stats Snapshot

Goal: expose the latest completed dungeon DPS per player from Blizzard damage meter without guessing or layout churn, while keeping persistent storage bounded.

1. Trigger: `CHALLENGE_MODE_COMPLETED` / `CHALLENGE_MODE_RESET` records a completed `M+` run, and leaving a tracked non-challenge party dungeon (`Normal`/`Heroic`/`Mythic`) records a non-key run snapshot.
2. Processing: addon reads the Blizzard `C_DamageMeter` overall run session when `combatSources` are available.
3. Processing: if the first post-run read is still empty because Blizzard has not finalized the session yet, addon retries briefly on a short deterministic timer instead of permanently accepting an empty snapshot.
4. Processing: non-challenge matching uses the roster snapshot frozen on dungeon entry so later group leavers still remain matchable at dungeon exit.
5. Processing: addon matches damage-meter source names deterministically against the current roster or frozen roster snapshot and keeps only exact player matches.
6. Storage: foreign-player stats snapshots stay runtime-only for the current session; persistent storage keeps only the matching local character's own last-run snapshot fields.
7. Output: the roster shows a dedicated `DPS` column and hovering a roster row shows a localized `Last run DPS` line for players with currently available stored values.
8. Output: the tooltip also shows `Level` and `Lang` without re-expanding the roster layout.
9. UI rule: roster/button/teleport hover uses isolated `isiLive` tooltip frames with wrapped compact text layout instead of the shared Blizzard `GameTooltip`.
10. Rule: if the Blizzard damage meter API/session is unavailable or a player has no exact source match, no stats lines are shown.
11. Success criteria: roster and tooltip show the latest dungeon stats for matching roster players in-session, keep only the local player's own snapshot persistently, and stay empty for unresolved players instead of guessing.

## UC-13 Esc Shortcuts And Addon Settings

Goal: expose fast Blizzard-panel shortcuts and localized addon toggles without desynchronizing live CVars or SavedVariables.

1. Trigger A: player opens the WoW `Esc` game menu while `IsiLiveDB.showEscPanel ~= false`.
2. Result A: addon shows a localized tooling strip left of `GameMenuFrame` with buttons for `Professions`, `Talents`, `Spells`, `Achievements`, `Quests`, `Dungeons`, `Journal`, `Collections`, `Guild`, and a separated `ReloadUI` button, plus a second travel strip farther left with `Arkantine`, `Hearthstone`, and `Housing`.
3. Action: clicking a tooling-strip shortcut closes the game menu first and then opens the targeted Blizzard panel through the dedicated microbutton/direct opener path; the `ReloadUI` entry instead uses a secure macro path that clicks Blizzard `Continue` and then runs `/reload`.
4. Combat safety: if combat lockdown blocks secure `ReloadUI` button refreshes (for example click registration or macro attribute updates), addon defers that update and retries it on `PLAYER_REGEN_ENABLED`; the mounted `Esc` strips themselves stay read-only in combat, remain visible through `GameMenuFrame`, and insecure shortcut clicks become no-ops instead of mutating overlay layout.
5. Rule: the spellbook shortcut must use spellbook-specific openers and must not route through the talents panel.
6. Trigger B: player opens `Settings -> AddOns -> isiLive`.
7. Result B: Blizzard settings expose language, `Advanced Combat Logging`, `DM Reset on Dungeon Entry`, `Show ESC Menu Shortcuts`, `Background Opacity`, `UI Scale`, `Default UI on Open`, `Minimap Button`, `Addon Sync`, `Auto-Open on M+ Queue`, `Auto-Close on Key Start / Solo`, `Column Guides`, `Sound: Lead Transfer`, `Sound: Group Join`, `Queue Debug Log (resets on reload)`, and `Runtime Log (resets on reload)`.
8. Rule: settings controls mirror live Blizzard CVars / SavedVariables and apply changes immediately without requiring the main addon window to be visible; changing `Background Opacity` live-updates the main frame, the optional `Esc` tooling and travel strips, and the settings canvas itself. Hidden legacy controls (`Name Length`, `Teleport Grid Columns`, `Show DPS Column`, `Markers: Leader Only`) stay out of the settings UI and currently use fixed runtime defaults: `DPS` on, markers visible for all, fixed name truncation, and legacy 2-column `Travel` layout.
9. Success criteria: both entry surfaces stay localized, deterministic, and reflect the current config/runtime state.

## UC-14 Combat Utility Tracker

Goal: show live BRes, Bloodlust/Heroism/Time Warp, active Mythic+ timer cutoffs, and synced interrupt cooldown state in the roster panel without guessing.

1. Trigger: the roster panel is visible and the one-second utility ticker fires, or a manual refresh / local lust spellcast / player `UNIT_AURA` update requests a tracker refresh.
2. Processing: addon scans `C_Spell.GetSpellCharges` (struct-return: `currentCharges`, `maxCharges`, `cooldownStartTime`, `cooldownDuration`) for Battle Resurrection and iterates player `HARMFUL` auras via `C_UnitAuras.GetAuraDataByIndex("player", index, "HARMFUL")` for Bloodlust/Heroism/Time Warp exhaustion variants.
3. Rule: only numeric aura `spellId` values may participate in the lust lookup; protected, secret, string, or otherwise non-numeric values must be ignored safely without aborting the full lust scan.
4. Rule: `UNIT_AURA` updates with `isFullUpdate=true` after zone/world transitions or UI reloads must hydrate the active lust state without firing a new onset callback.
5. Rule: `PLAYER_ENTERING_WORLD` may keep only a short 2-second suppress window as a safety net until the full aura-restore event arrives.
6. Processing: while an active Mythic+ timer is running, the same one-second utility ticker must also trigger a full panel rerender so the visible `+3/+2/+1` cutoffs count down live.
7. Output: the tracker row shows BRes charges/cooldown, the current lust icon and remaining time, plus active `+3/+2/+1` timer cutoffs and death-penalty loss, or `--` when data is unavailable.
8. Output: roster rows additionally show synced interrupt status in the `Kick` column: `ready` (green) when available, remaining cooldown seconds (red) while on cooldown, or `-` (grey) when the spec has no interrupt or the pet interrupt is currently unavailable (e.g. Demonology Warlock without a summoned pet).
9. Processing: interrupt state is tracked locally via `KickTracker`; pet-based interrupts (Warlock Affliction/Destruction `Spell Lock`, Demonology `Axe Toss`/`Spell Lock`) track the pet cast unit separately so the cooldown starts only when the pet actually casts, not the player.
10. Rule: synced `hasKick = false` (no-interrupt spec) must render as `-` in the `Kick` column, not as `0s` or `ready`, and must be transmitted as `KICK:-1:0` so peers can distinguish it from a ready interrupt.
11. Success criteria: the row and `Kick` column update deterministically, stay non-negative, and remain stable when the relevant APIs are missing, mixed-validity aura payloads are encountered, or zone/reload aura restores arrive late.

## Non-Functional Rules

1. No speculative behavior: unresolved/ambiguous map context must stay unresolved (no name/token fallback guessing).
2. Combat-protected UI operations must be deferred safely while window dragging stays available, and teleport action buttons must not promote parent frames to protected status.
3. Leader-only actions must stay disabled for non-leaders.
4. Hidden mode should halt non-essential processing, suspend queue scanning and permanent polling, keep background roster/addon-message sync active, allow event-driven pre-rendered UI state updates, and only keep required auto-open transitions active; hidden leader promotions still play the transfer sound but suppress center notice/chat output, and hidden `LFG_LIST_*` suppression means missed queue capture is not replayed later as chat on group join.
5. Blizzard CVar state remains authoritative: `isiLive` only mirrors `advancedCombatLogging` / `damageMeterResetOnNewInstance` in the Blizzard settings canvas and writes them on explicit user clicks; challenge-start Blizzard damage-meter reset still runs when API support exists.
6. RIO delta display must be deterministic and non-negative (`(+X)` only).
7. UI visibility toggle (`CTRL+F9`) must stay requestable in combat; if combat lockdown blocks `Show` or `Hide`, the requested state is replayed on `PLAYER_REGEN_ENABLED`. `CHALLENGE_MODE_START` auto-hides the main window only when the `Auto-Close on Key Start / Solo` option is enabled.
8. During combat, non-essential event processing is suspended by runtime gate; essential events continue.
9. Re-Sync and key-share UI actions must enforce click-spam guards (debounce/rate-limit behavior).
10. Event-gate dispatch failures must be reported through error callbacks for diagnostics without terminating the gate loop.
11. Persistent stats storage must stay bounded: no persistent foreign-player run history and no persistent `Runs together` cache.
12. Leaving or being removed from a normal party must keep the current frame visibility state and retain former members as ghost rows until a deterministic prune path occurs; active members must still remain visible ahead of persisted ghosts.
13. Manual marking (Tank=Blue, Healer=Green) is available via secure role-icon buttons for all group members without leader restriction in 5-man parties.
14. Raid-group detection (> 5 members) hides the addon UI, suppresses background processing, prints no raid transition notice, and blocks switching back to M/V until party size returns.
15. The optional `Esc` tooling and travel strips stay localized, close the game menu before opening their targets, and keep `ReloadUI` on a secure macro path (`/click GameMenuButtonContinue` + `/reload`) that mirrors `ActionButtonUseKeyDown`; blocked secure refreshes for that button replay on `PLAYER_REGEN_ENABLED`, while both strips remain pre-mounted `GameMenuFrame` children and therefore run no deferred host-frame re-show path in combat.
16. Hidden legacy settings controls remain absent from Blizzard Settings and currently use fixed runtime defaults: `DPS` column on, markers visible for all, fixed name truncation, and legacy 2-column `Travel` layout.
17. Ready-check lifecycle updates must use the dedicated ready-check refresh path so row-background state, waiting sandglass markers, and the 20-second declined hold reset deterministically without rewriting secure role-button attributes.
18. Roster leader markers must mirror the true `UnitIsGroupLeader` state only; leader rows render a 16x16 crown, and if the same row also has the blue `isiLive` heart marker, the order must stay `heart -> crown`.

Runtime behavior in this document is validated by `tools/validate_usecases.lua`.
Active rule contracts in `RULES_LOGIC.md` are validated by `tools/validate_rules_logic.lua` and also enforced during `tools/validate_usecases.lua`.
Current validator baseline: `483` scenarios across `36` modules.

1. UC-01/UC-02: strict queue target resolution and queue highlight behavior without speculative fallback.
2. UC-03: exact-map suppression and shared-portcast ambiguity handling.
3. UC-04/UC-05: cooldown recognition/format behavior and state handling.
4. Event consistency: target clear behavior under API shape variants, grouped negative-application follow-up events, and protected API errors.
5. UC-07: challenge-start baseline capture and roster `(+X)RIO` rendering rules (including non-negative clamp).
6. UC-08: post-run stats snapshot capture for `M+` and tracked non-challenge party exits, bounded persistence, and tooltip/roster rendering.
7. UC-09: Manual Role Marker secure button configuration.
8. UC-10: raid-size zero-process behavior, hidden UI suppression, and no raid-notice output.
9. UC-11/UC-12: Secure world-marker button configuration for M+Marker and compact-layout visibility logic for M/V/H mode switching.
10. Taint hardening: deferred secure attribute writes, deferred `Esc` shortcut secure-button refreshes, insecure teleport-grid actions, and combat-safe collapse handling.
11. UC-13/UC-14: game-menu tooling/travel strips, localization, close-then-open behavior, deferred secure reload-button refresh, direct opener fallback selection, settings-canvas state mirroring/background-opacity behavior, live BRes/Bloodlust/M+ timer rendering, and synced interrupt cooldown display.

## Traceability To Source Files

| Concern | Files |
|---|---|
| Queue detection and target capture | `isiLive_queue.lua`, `isiLive_event_handlers_queue.lua` |
| Highlight resolution and inside-dungeon suppression | `isiLive_highlight.lua` |
| Teleport spell mapping and cooldown behavior | `isiLive_teleport.lua`, `isiLive_spell_utils.lua`, `isiLive_teleport_ui.lua` |
| Group lifecycle, leader-state mirroring, and roster rebuild | `isiLive_group.lua`, `isiLive_roster.lua` |
| RIO baseline capture and delta preview | `isiLive_event_handlers_challenge.lua`, `isiLive_roster.lua`, `isiLive_test_mode.lua`, `isiLive_runtime_state.lua` |
| Last-run DPS capture and bounded stats persistence | `isiLive_stats.lua`, `isiLive_event_handlers_challenge.lua`, `isiLive_event_handlers_runtime.lua`, `isiLive_roster_panel.lua`, `isiLive_roster_tooltip.lua` |
| Combat utility tracker row and kick state | `isiLive_cd_tracker.lua`, `isiLive_mplus_timer.lua`, `isiLive_kick_tracker.lua`, `isiLive_sync.lua`, `isiLive_keysync.lua`, `isiLive_factory_controllers.lua`, `isiLive_roster_panel.lua`, `isiLive_roster_tooltip.lua`, `isiLive_texts.lua` |
| Leader transfer detection and feedback | `isiLive_leader_watch.lua` |
| UI actions, role buttons, key sharing button | `isiLive_roster_panel.lua` |
| Esc tooling/travel strips and Blizzard settings canvas | `isiLive_ui.lua`, `isiLive_settings.lua`, `isiLive_factory.lua`, `isiLive_texts.lua`, `isiLive_ui_common.lua` |
| Auto-Marker logic (removed/replaced) | `isiLive_group.lua` (cleaned up) |
| Raid-size H-mode UI | `isiLive_roster_panel.lua`, `isiLive_group.lua` |
| Event routing and gating | `isiLive_events.lua`, `isiLive_event_handlers.lua`, `isiLive_event_handlers_runtime.lua`, `isiLive_event_handlers_queue.lua`, `isiLive_event_handlers_challenge.lua` |
