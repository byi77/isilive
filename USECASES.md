# isiLive Use Cases

Version baseline: `0.9.33`
Last updated: `2026-02-19`

## Actors

1. Player (group leader or member).
2. isiLive addon runtime.
3. WoW APIs and events.

## Preconditions

1. Addon is loaded and not in `stopped` state.
2. Season dataset is TWW S3.
3. Relevant UI is visible or can be auto-opened by group transition logic.

## Use Case Matrix

| ID | Title | Primary result |
|---|---|---|
| UC-01 | Invite detection and target resolution | Correct dungeon target is resolved deterministically |
| UC-02 | Chat hint and teleport highlight | User gets chat/info hint and sees correct portal highlight |
| UC-03 | Enter exact target dungeon | Highlight turns off immediately on exact target entry |
| UC-04 | Use portal cast | All portal casts receive 8h cooldown behavior |
| UC-05 | Cooldown lifecycle | Cooldown expires naturally or resets after dungeon finish |
| UC-06 | Share keys action | Group keys are announced in party chat via button |

## UC-01 Invite Detection And Target Resolution

Goal: detect queue invite/join context and identify the correct dungeon target without guessing.

1. Trigger: LFG list and queue events arrive.
2. Inputs: activity ID, pending status, group metadata, known season mapping.
3. Processing: resolver prioritizes concrete teleport-mapped activity IDs over generic dungeon candidates.
4. Output: `targetMapID`, `targetTeleportSpellID`, and display dungeon name are stored.
5. Success criteria: one deterministic target is selected or no target is set.

## UC-02 Chat Hint And Teleport Highlight

Goal: inform the player and highlight the correct portal cast icon.

1. Trigger: group join is confirmed and target metadata exists.
2. Processing: addon posts queue/join hint and updates notice/UI state.
3. Processing: teleport button matching the resolved target spell is highlighted.
4. User action: player can click the portal button or move manually to dungeon.
5. Success criteria: highlight matches the same resolved dungeon as chat hint.

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
2. Processing: cooldown state is read from WoW spell cooldown APIs.
3. Rule: all dungeon portal casts share the same 8h cooldown window after use.
4. Output: teleport grid shows cooldown time and lock state consistently.
5. Success criteria: every portal button reflects the shared cooldown.

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
3. Output: message is sent to `PARTY`, with local print fallback on send failure.
4. Success criteria: chat line contains party key list in deterministic format.

## Non-Functional Rules

1. No speculative behavior when concrete API data exists.
2. Combat-protected UI operations must be deferred safely; main-frame drag start/stop must no-op during combat lockdown.
3. Leader-only actions must stay disabled for non-leaders.
4. Hidden mode should halt non-essential processing.

## Automated Validation Mapping

Runtime behavior in this document is validated by `tools/validate_usecases.lua`.

1. UC-01/UC-02: queue target resolution priority and queue highlight behavior.
2. UC-03: exact-map suppression and shared-portcast ambiguity handling.
3. UC-04/UC-05: cooldown recognition/format behavior and state handling.
4. Event consistency: target clear behavior under API shape variants and protected API errors.

## Traceability To Source Files

| Concern | Files |
|---|---|
| Queue detection and target capture | `isiLive_queue.lua`, `isiLive_queue_flow.lua` |
| Highlight resolution and inside-dungeon suppression | `isiLive_highlight.lua` |
| Teleport spell mapping and cooldown behavior | `isiLive_teleport.lua`, `isiLive_spell_utils.lua`, `isiLive_teleport_ui.lua` |
| Group lifecycle and roster rebuild | `isiLive_group.lua`, `isiLive_roster.lua` |
| UI actions and key sharing button | `isiLive_roster_panel.lua` |
| Event routing and gating | `isiLive_events.lua`, `isiLive_event_handlers.lua` |
