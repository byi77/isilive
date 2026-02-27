# isiKeyMPlus

`isiKeyMPlus` is a WoW group helper addon for Mythic+ pug/party flow, focused on pre-key group overview.
Internal Lua file/module namespace remains `isiLive_*` for compatibility.

Compatibility target: WoW `12.0+` only.
Current addon version: `0.9.55`.

## Features

- Group roster table with columns: `Spec`, `Name`, `Sprache/Flag`, `Key`, `iLvl`, `RIO`
- Stable role sorting: `Tank -> Healer -> Damager`
- Right-side controls: `Readycheck`, `Countdown10`, `Countdown 0`, `Refresh`, `Share Keys`
- Right-side headers: `M+Managment` and `M+Travel`
- `M+Travel` teleport grid with all Season dungeon teleports
- Active dungeon teleport is highlighted (pulse/glow) only when you joined a group from queue or are actively hosting your own group
- Group key visibility via addon sync: members with `isiLive` share key as `Shortcut +Level` (for example `DB +14` / `MB +14` depending on locale)
- Key mapping normalizes active-season challenge-map IDs to canonical season map IDs before short-code rendering
- Season scope is open via `ACTIVE_SEASON_ID`; current active season is `tww_s3`, and `midnight_s1` exists as prepared inactive scaffold
- `Key` column keeps `Shortcut +Level` on one line (no row-wrap bleed into next member line)
- `RIO` column can show per-run delta as `(+X)RIO` (non-negative only; never minus)
- Queue join detection with chat message and invite hint
- Grouped queue-join announce deduplication is driven by stable queue source IDs (`applicationID`/`searchResultID`/`listingID`), not volatile display text
- Dungeon teleport controls in center notice + right-side grid
- Teleport cooldown shown as `HH:MM`
- Addon-presence marker per roster name (`<3`)
- `Share Keys` posts one party-chat line per available member key (`isiKeyMPlus PartyKeys: Name -> Key`), using Blizzard owned-keystone link payload for the local player when available
- Spec column supports short labels for long localized names (for example `Wiederherstellung -> Resto`, `Vergeltung -> Retri`)
- Center notices: left-click drag, right-click dismiss, top-right close button; position resets to center on each open
- Optional runtime log persisted in `IsiLiveDB.runtimeLog` (enable/disable via slash command; flushed on `/reload`/logout)
- Non-Mythic dungeon entry warning with delayed confirmation (larger/blinking persistent notice; right-click dismiss, left-click drag)
- Top-right version label in main window (`V.x.y.z`)

## Behavior

- Auto-open on small-group join
- Auto-hide on M+ key start (`CHALLENGE_MODE_START`); can be manually opened (`CTRL+F9`) in "frozen" read-only state.
- Auto-open on key end (`CHALLENGE_MODE_COMPLETED`/`CHALLENGE_MODE_RESET`) while grouped.
- `CTRL+F9`: opening and closing are always allowed (including combat).
- Hidden window mode hard-stops non-essential scan/processing work; queue/sync event processing is suspended while hidden.
- Combat runtime gate now suppresses non-essential event processing while in combat; essential events (for example `PLAYER_REGEN_ENABLED` and `CHALLENGE_MODE_*`) still run.
- Key sync runs only while the main window is visible (hidden mode stays in sleep behavior)
- Main window is movable via left drag in every mode; top drag handle stays above overlays for reliable dragging
- Roster member row hover shows the Blizzard player tooltip when unit context exists, with `Name-Realm` fallback text when unit tokens are temporarily unavailable
- Teleport grid buttons inherit main-frame strata/level to avoid overlay conflicts with external UI panels
- Combat-safe frame updates: pending frame-height changes are applied on `PLAYER_REGEN_ENABLED`
- Advanced combat logging (`advancedCombatLogging`) is hard-enforced to `ON`.
- Blizzard damage meter reset is hard-enforced on `CHALLENGE_MODE_START` when `C_DamageMeter` API support is available.
- `CHALLENGE_MODE_START` captures a per-player RIO baseline.
- `CHALLENGE_MODE_COMPLETED`/`CHALLENGE_MODE_RESET` schedules delayed post-run refresh and enables clamped delta display `(+X)RIO` after refresh succeeds (with short retry if still blocked), including when the window is currently hidden.
- Test mode (`/isilive test`, `/isilive testall`) includes visible positive dummy RIO delta preview.
- `Readycheck`, `Countdown10`, and `Countdown 0` are leader-only
- Server language is shown as `Flag + 2-letter code` (e.g. `DE`, `FR`)
- On addon load, chat shows current version and open hint (`Press CTRL+F9 to open`)
- Bottom status line includes current target dungeon context as `Target Dungeon: <Name> [+Level]` (or `Target Dungeon: -` when unresolved)
- Runtime log entries are persisted through SavedVariables when logging is enabled.
- Sync handshake behavior: `HELLO` recipients send `ACK` and also force-send their own `KEY` snapshot to restore peer key visibility after refresh.

## Use Case / Logic Baseline (v0.9.55)

Documented on `2026-02-27` as runtime behavior baseline for validation checks.

1. Queue invite -> grouped flow
   - Queue/LFG events capture candidate group + dungeon (`LFG_LIST_*`) while main UI is visible.
   - On confirmed small-group join (`GROUP_ROSTER_UPDATE`), addon announces joined group, shows invite hint, resolves target dungeon teleport, and highlights the active teleport.
2. Group roster build and ordering
   - On group update, roster is rebuilt as `player + party1..party4`.
   - Display ordering is stable by role (`TANK -> HEALER -> DAMAGER -> NONE`) and unit priority.
   - Per row data includes `Spec`, `Name`, `Language/Flag`, `Key`, `iLvl`, `RIO` and optional run-delta prefix `(+X)`.
3. Key sync and key column
   - Addon sync channel exchanges `HELLO/ACK/KEY` between `isiLive` users.
   - `KEY:<mapID>:<level>` snapshots populate roster key text as `Shortcut +Level` (for example `DB +14` / `MB +14` depending on locale).
   - Active joined key owner is highlighted only when ownership is unambiguous.
4. Teleport targeting and highlight logic
    - Active target resolves in strict order: active listing `activityID -> mapID -> spellID`, then latest queue target `mapID -> spellID`.
    - If concrete `mapID` context is missing, target stays unresolved (no name/token guessing).
    - Highlight is group-bound (no solo highlight), and updates on queue/listing/challenge transitions.
    - Exact target map has priority: if activity map is known, highlight clears only on that exact map.
    - Shared-portcast dungeons (for example both Tazavesh wings) are handled as multi-map targets and remain unresolved if map context is ambiguous.
    - Negative queue application follow-up events do not clear queue-derived target while already grouped (prevents highlight drop when group fills to 5 members).
5. Refresh and inspect pipeline
   - `Refresh` triggers forced sync reset (`HELLO/KEY`) and inspect cache invalidation/requeue.
   - Inspect controller updates `Spec/iLvl/RIO` asynchronously via queue/retry flow and `INSPECT_READY`.
   - After challenge completion/reset, a delayed post-run refresh is attempted; RIO delta display is enabled only after this refresh path succeeds (with retry fallback).
6. Runtime gating and hidden/sleep behavior
   - Event gate blocks non-required processing in `stopped`, `paused`, and hidden states.
   - Hidden mode keeps only transition events active (auto-open on group join/key end); queue/sync events are suppressed while hidden.
   - `CHALLENGE_MODE_START` hides UI; completion/reset rehydrates group view and refresh flow.
   - Combat-safe UI behavior: secure teleport-button updates are still deferred during combat lockdown and restored on `PLAYER_REGEN_ENABLED`.

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
- `isiLive.lua`: main addon logic
- `isiLive_locale.lua`: locale/language/flag mapping helpers
- `isiLive_season_data.lua`: active season dataset (`ACTIVE_SEASON_ID`, map->teleport mappings, locale short-code overrides)
- `isiLive_teleport.lua`: dungeon teleport mapping and secure teleport button helpers
- `isiLive_teleport_ui.lua`: teleport grid button creation/update helpers
- `isiLive_teleport_debug.lua`: teleport debug/test command controller (`tpdebug`, `tptest`)
- `isiLive_notice.lua`: center notice/invite hint UI components
- `isiLive_status.lua`: status line and dungeon-difficulty helpers
- `isiLive_units.lua`: unit/spec/name/RIO helper functions
- `isiLive_demo.lua`: dummy/test roster generation
- `isiLive_sync.lua`: addon sync (`HELLO`/`ACK`/`KEY`) and user detection
- `isiLive_keysync.lua`: key-sync controller (`HELLO/KEY` sends, key cache apply, active key owner resolver)
- `isiLive_refresh.lua`: refresh controller (forced full refresh flow incl. `HELLO/KEY` + inspect requeue)
- `isiLive_highlight.lua`: active-target resolver and highlight-state decision helpers
- `isiLive_group.lua`: group lifecycle controller (`GROUP_ROSTER_UPDATE`, roster rebuild, leave cleanup)
- `isiLive_queue.lua`: LFG/queue invite capture and parsing
- `isiLive_queue_debug.lua`: queue debug storage + command helpers (`qdebug`)
- `isiLive_runtime_log.lua`: runtime log storage + command helpers (`log`)
- `isiLive_log_buffer.lua`: shared saved-log buffer utilities (`queueDebugLog` + `runtimeLog`)
- `isiLive_inspect.lua`: inspect queue/retry/cache controller
- `isiLive_roster.lua`: roster ordering + display-data builders
- `isiLive_events.lua`: event gate wrapper for stop/pause/test/hidden states
- `isiLive_event_handlers.lua`: runtime event handler controller (`OnEvent` routing targets)
- `isiLive_commands.lua`: slash command registration/dispatch
- `isiLive_ui.lua`: main frame/UI construction and widget wiring
- `RULES_LOGIC.md`: enforceable usecase/rule contract source (`RULE-ID` blocks with status + required tests)
- `tools/validate_rules_logic.lua`: rules-logic validator entrypoint
- `tools/validate_usecases.lua`: deterministic usecase validator entrypoint
- `testmodul/isilive_test_*.lua`: modular offline simulation scenarios + harness for queue/highlight/event/cooldown/teleport/group/sync/locale/commands/guards logic (dev-only, not packaged)
- `realm_language_data.lua`: Blizzard EU realm locale mapping (including UTF-8 Russian realm names)
- `CHANGELOG.md`: release notes
- `RELEASE.md`: release runbook
- `RULES.md`: project/versioning rules
- `RULES_LOGIC.md`: runtime usecase/rule contracts
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
  - `lua tools/validate_usecases.lua`
  - Metrics defaults: file `warn>1200` / `hard>2400`, function `warn>120` / `hard>320` (override via `ISILIVE_WARN_FILE_LINES`, `ISILIVE_MAX_FILE_LINES`, `ISILIVE_WARN_FUNCTION_LINES`, `ISILIVE_MAX_FUNCTION_LINES`)
  - Windows note: if metrics cannot find LuaRocks modules (`lfs`/`luacheck.*`), set `LUA_PATH` + `LUA_CPATH` to your LuaRocks `share/lua/5.4` and `lib/lua/5.4` paths before running.

## Deterministic Usecase Gate

`tools/validate_rules_logic.lua` validates active rule contracts from `RULES_LOGIC.md` against deterministic test names.
`tools/validate_usecases.lua` runs the same rules-logic validation first and then executes a modular deterministic runtime-logic gate (`testmodul/isilive_test_*.lua`) with 143 scenarios across 21 modules (queue/highlight/event-handlers/queue-flow/spell-utils/teleport/group/event-utils/locale/sync/guards/inspect/test-mode/leader-watch/refresh/commands/runtime-log/roster/roster-panel/status/ui), including:
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
- hidden-mode gate behavior (queue/sync suppression while hidden, auto-open transition triggers only)
- non-Mythic status detection (normal/heroic transitions and heroic fallback difficulty IDs)
- combat hotkey visibility rules (`CTRL+F9`: open and close allowed during combat)
- RIO baseline/delta rendering rules (`(+X)RIO`, no negative deltas) and challenge-start baseline capture
- EventUtils negative/positive status detection and edge cases
- locale key completeness (enUS ↔ deDE symmetry, format placeholders)
- sync NormalizePlayerKey, MarkUser/IsUserKnown, key dedup, HELLO/KEY messages
- Guards full module+function validation, missing module/function detection
- TestMode toggle/stop/pause guards, full dummy preview
- LeaderWatch gain/loss/initial-state transitions
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
- `release.yml` triggers CurseForge's official auto-packager only for tags like `isiLive_release_0.9.55`.

Pre-release:
- `pre-release.yml` triggers CurseForge packaging for tags like `isiLive_alpha_0.9.55` or `isiLive_beta_0.9.55`.
- Stable workflow is isolated and will not trigger on alpha/beta tags.

Required GitHub settings (repo `Settings -> Secrets and variables -> Actions`):

1. `Secret`: `CF_API_KEY` (your CurseForge API token)
2. `Variable`: `CURSE_PROJECT_ID` (numeric CurseForge project ID)

Release flow:

1. Bump version in `isiLive.toc` and update `CHANGELOG.md`
2. Commit + push to `main`
3. Create and push stable tag: `git tag isiLive_release_0.9.55 && git push origin isiLive_release_0.9.55`
4. Optional pre-release tags:
   - alpha: `git tag isiLive_alpha_0.9.55 && git push origin isiLive_alpha_0.9.55`
   - beta: `git tag isiLive_beta_0.9.55 && git push origin isiLive_beta_0.9.55`

Note: this avoids the legacy `wow.curseforge.com/api/game/versions` lookup used by older packaging flows.
