# Changelog

## 2026-03-11 - Release Follow-up / Docs Sync
- **Release Cleanup:**
  - Deleted the accidental stable tag `isiLive_release_0.9.70` from Git after it had triggered the release workflow too early.
  - Archived the corresponding CurseForge `0.9.70` package so the mistaken artifact no longer remains part of the active stable line.
- **Release Runbook Hardening:**
  - Documented the mandatory order `push main -> wait for green Lua Check on the exact commit -> create release tag`.
  - Documented rollback handling for accidental release tags and clarified that deleting a Git tag does not remove an already-created CurseForge artifact.
- **Docs Consistency:**
  - Synced `CHANGELOG.md`, `README.md`, `RELEASE.md`, `TODO.md`, `WARTUNG.md`, `ARCHITECTURE.md`, and `USECASES.md` after the archived `0.9.70` release incident.
  - Updated deterministic validation references to `244` scenarios across `26` modules and removed a leftover conflict marker from `ARCHITECTURE.md`.

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
  - The `Spec` column is now anchored further left, player names are clamped to Blizzard's 12-character limit, and spec labels are clamped to 6 characters.
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
  - Added `TODO_RENAME.md` as the hardcut rename runbook for the planned `isiLive -> isiKeyMPlus` migration after `v0.9.65`.
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
  - Share line format is now `isiKeyMPlus PartyKeys: <Name> -> <KeyLinkOrText>`.
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
  - Updated addon list title to `isiKeyMPlus`.
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
  - Removed the hard **TWW S3-only lock** from project rules/docs.
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
- **Key Mapping Reliability (TWW S3):**
  - Added explicit challenge-map alias mapping for TWW S3 key IDs:
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
  - Excluded `isiKeyMplus_logo.png` from CurseForge packaging via `.pkgmeta` ignore list.
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
- **Season Data:** Updated/locked dungeon list and teleports for **The War Within Season 3 (TWW S3)**.
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
  - title now shows rename note: `isiLive (will be renamed to isiKeyMPlus soon)`
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
  - updated all 8 M+ dungeon mapIDs for TWW Season 3 in `TWW_SEASON3_MAP_TO_TELEPORT` table:
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
  - maps TWW Season 3 dungeons to their teleport spell IDs (based on TeleportMenu data)
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
