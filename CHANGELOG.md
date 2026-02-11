# Changelog

## 2026-02-11 - Version 0.91
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
