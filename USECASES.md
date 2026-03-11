# isiKeyMPlus Use Cases

Version baseline: `0.9.70`
Last updated: `2026-03-11`

## Actors

1. Player (group leader or member).
2. isiKeyMPlus addon runtime (internal namespace: `isiLive_*`).
3. WoW APIs and events.

## Preconditions

1. Addon is loaded and not in `stopped` state.
2. Season dataset is selected by `ACTIVE_SEASON_ID` (currently `midnight_s1` pre-season with empty active portal pool).
3. Relevant UI is visible for queue scanning and rendering; while hidden, addon-message sync and roster updates may still run in the background, and UI can be auto-opened by fresh group join, key-end, or real dungeon-entry transition logic.

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
| UC-08 | Post-run DPS snapshot | Latest dungeon DPS per player is read from Blizzard damage meter and shown in roster + tooltip |
| UC-09 | Auto-Marker Feature | Tank and Healer are automatically marked with icons in parties |
| UC-10 | Raid Notice integration | Persistent warning is shown in roster area when group > 5 members |

## UC-01 Invite Detection And Target Resolution

Goal: detect queue invite/join context and identify the correct dungeon target without guessing.

1. Trigger: LFG list and queue events arrive while main UI is visible.
2. Inputs: activity ID, pending status, group metadata, known season map/teleport mapping.
3. Processing: resolver uses strict `activityID -> mapID -> spellID` mapping only.
4. Output: `targetMapID`, `targetTeleportSpellID`, and display dungeon name are stored.
5. Success criteria: one deterministic target is selected, or target remains unset when concrete map context is missing.

## UC-02 Chat Hint And Teleport Highlight

Goal: inform the player and highlight the correct portal cast icon.

1. Trigger: group join is confirmed and target metadata exists.
2. Processing: addon posts queue/join hint and updates UI state (chat + invite hint, no queue center notice).
3. Processing: teleport button matching the resolved target spell is highlighted.
4. User action: player can click the portal button or move manually to dungeon.
5. Rule: follow-up negative application status updates must not clear queue target while player is already grouped.
6. Rule: repeated grouped queue announces are deduplicated by stable queue source IDs (`applicationID`/`searchResultID`/`listingID`) instead of display text.
7. Success criteria: highlight matches the same resolved dungeon as chat hint and remains stable when group fills to 5 members.

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
5. Output: teleport grid shows cooldown time and lock state consistently.
6. Success criteria: every portal button reflects the shared cooldown.

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
2. Processing: addon builds ordered roster key summary from known keys.
3. Sync relation: on refresh handshakes, HELLO recipients send ACK and a forced own KEY/STATS snapshot so peer key and peer stats caches are repopulated.
4. Output: one message per key owner is sent to `PARTY`, with local print fallback on send failure.
5. Rule: `Share Keys` button clicks are debounced to suppress rapid duplicate chat output.
6. Success criteria: each available member key appears as its own deterministic chat line (`isiKeyMPlus PartyKeys: Name -> Key`), with owned-keystone hyperlink payload for the local player when available.

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

## UC-08 Post-Run DPS Snapshot

Goal: expose the latest completed dungeon DPS per player from Blizzard damage meter without guessing or layout churn, while keeping persistent storage bounded.

1. Trigger: `CHALLENGE_MODE_COMPLETED` / `CHALLENGE_MODE_RESET` records a completed `M+` run, and leaving a tracked mythic non-challenge party dungeon records an `M0` run snapshot.
2. Processing: addon reads the Blizzard `C_DamageMeter` overall run session when `combatSources` are available.
3. Processing: if the first post-run read is still empty because Blizzard has not finalized the session yet, addon retries briefly on a short deterministic timer instead of permanently accepting an empty snapshot.
4. Processing: `M0` matching uses the roster snapshot frozen on dungeon entry so later group leavers still remain matchable at dungeon exit.
5. Processing: addon matches damage-meter source names deterministically against the current roster or frozen roster snapshot and keeps only exact player matches.
6. Storage: foreign-player DPS snapshots stay runtime-only for the current session; persistent storage keeps only the local player's own last-run DPS.
7. Output: the roster shows a dedicated `DPS` column and hovering a roster row shows a localized `Last run DPS: ...` tooltip line for players with a currently available stored value.
8. Output: the tooltip also shows `Level` and `Lang` without re-expanding the roster layout.
9. UI rule: roster/button/teleport/notice hover uses isolated `isiLive` tooltip frames with wrapped compact text layout instead of the shared Blizzard `GameTooltip`.
10. Rule: if the Blizzard damage meter API/session is unavailable or a player has no exact source match, no DPS line is shown.
11. Success criteria: roster and tooltip show the latest dungeon DPS for matching roster players in-session, keep only the local player's own snapshot persistently, and stay empty for unresolved players instead of guessing.

## Non-Functional Rules

1. No speculative behavior: unresolved/ambiguous map context must stay unresolved (no name/token fallback guessing).
2. Combat-protected UI operations must be deferred safely while window dragging stays available, and teleport action buttons must not promote parent frames to protected status.
3. Leader-only actions must stay disabled for non-leaders.
4. Hidden mode should halt non-essential processing, suspend queue scanning and permanent polling, keep background roster/addon-message sync active, allow event-driven pre-rendered UI state updates, and only keep required auto-open transitions active.
5. Blizzard CVar state remains authoritative: `isiLive` only mirrors `advancedCombatLogging` / `damageMeterResetOnNewInstance` in the UI and writes them on explicit user clicks; challenge-start Blizzard damage-meter reset still runs when API support exists.
6. RIO delta display must be deterministic and non-negative (`(+X)` only).
7. UI visibility toggle (`CTRL+F9`) must allow both open and close in combat; `CHALLENGE_MODE_START` still auto-hides the main window.
8. During combat, non-essential event processing is suspended by runtime gate; essential events continue.
9. Refresh and key-share UI actions must enforce click-spam guards (debounce/rate-limit behavior).
10. Event-gate dispatch failures must be reported through error callbacks for diagnostics without terminating the gate loop.
11. Persistent stats storage must stay bounded: no persistent foreign-player run history and no persistent `Runs together` cache.
12. Leaving or being removed from a normal party must keep the current frame visibility state and retain former members as ghost rows until a deterministic prune path occurs.
13. Auto-marking (Tank=Blue, Healer=Green) happens automatically for all group members without leader restriction in 5-man parties.
14. Raid-group detection (> 5 members) shows a persistent localized warning in the roster area and hides roster rows.

## Automated Validation Mapping

Runtime behavior in this document is validated by `tools/validate_usecases.lua`.
Active rule contracts in `RULES_LOGIC.md` are validated by `tools/validate_rules_logic.lua` and also enforced during `tools/validate_usecases.lua`.

1. UC-01/UC-02: strict queue target resolution and queue highlight behavior without speculative fallback.
2. UC-03: exact-map suppression and shared-portcast ambiguity handling.
3. UC-04/UC-05: cooldown recognition/format behavior and state handling.
4. Event consistency: target clear behavior under API shape variants, grouped negative-application follow-up events, and protected API errors.
5. UC-07: challenge-start baseline capture and roster `(+X)RIO` rendering rules (including non-negative clamp).
6. UC-08: post-run DPS snapshot capture for `M+` and `M0`, bounded persistence, and tooltip/roster rendering.
7. UC-09: Auto-Marker logic (Tank=Blue Square, Healer=Green Triangle) available for all party members.
8. UC-10: Raid notice integration within the Roster Panel.

## Traceability To Source Files

| Concern | Files |
|---|---|
| Queue detection and target capture | `isiLive_queue.lua`, `isiLive_queue_flow.lua` |
| Highlight resolution and inside-dungeon suppression | `isiLive_highlight.lua` |
| Teleport spell mapping and cooldown behavior | `isiLive_teleport.lua`, `isiLive_spell_utils.lua`, `isiLive_teleport_ui.lua` |
| Group lifecycle and roster rebuild | `isiLive_group.lua`, `isiLive_roster.lua` |
| RIO baseline capture and delta preview | `isiLive_event_handlers_challenge.lua`, `isiLive_roster.lua`, `isiLive_test_mode.lua`, `isiLive_runtime_state.lua` |
| Last-run DPS capture and bounded stats persistence | `isiLive_stats.lua`, `isiLive_event_handlers_challenge.lua`, `isiLive_event_handlers_runtime.lua`, `isiLive_roster_panel.lua` |
| UI actions and key sharing button | `isiLive_roster_panel.lua` |
| Auto-Marker logic | `isiLive_group.lua` |
| Raid notice UI | `isiLive_roster_panel.lua` |
| Event routing and gating | `isiLive_events.lua`, `isiLive_event_handlers.lua`, `isiLive_event_handlers_runtime.lua`, `isiLive_event_handlers_queue.lua`, `isiLive_event_handlers_challenge.lua` |
