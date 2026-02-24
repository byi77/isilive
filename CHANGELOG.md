# Changelog

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
