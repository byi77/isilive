# isiLive

`isiLive` is a WoW group helper addon for Mythic+ pug/party flow, focused on pre-key group overview.

Compatibility target: WoW `12.0+` only.
Current addon version: `0.9.16`.

## Features

- Group roster table with columns: `Spec`, `Name`, `Sprache/Flag`, `iLvl`, `RIO`
- Stable role sorting: `Tank -> Healer -> Damager`
- Right-side controls: `Readycheck`, `Countdown10`, `Refresh`, `DM Reset: ON/OFF`
- `M+ Management` teleport grid with all Season dungeon teleports
- Active invite/queue dungeon teleport is highlighted (pulse/glow), independent of your current location
- Queue join detection with chat message, center notice, and invite hint
- Dungeon teleport controls in center notice + right-side grid
- Teleport cooldown shown as `HH:MM`
- Addon-presence marker per roster name (`<3`) and full-group easter-egg marker (`[fullsync]`)
- Center notices: left-click drag, right-click dismiss, persistent position
- Non-Mythic dungeon entry warning (30s center notice with delayed confirmation)
- Bottom-right version label in main window (`V.x.y.z`)

## Behavior

- Auto-open on small-group join
- Auto-hide on M+ key start (`CHALLENGE_MODE_START`)
- Hidden window mode hard-stops non-essential scan/processing work, while hotkey/binding remains active and minimal small-group join transition is still allowed for auto-open
- Main window is movable via left/right drag; top drag handle stays above overlays for reliable dragging
- Main frame height updates are deferred during combat and applied on `PLAYER_REGEN_ENABLED`
- `Readycheck` and `Countdown10` are leader-only
- Server language is shown as `Flag + 2-letter code` (e.g. `DE`, `FR`)
- On addon load, chat shows current version and open hint (`Press CTRL+F9 to open`)

## Hotkeys

- `CTRL+F9`: toggle isiLive window
- `CTRL+ALT+F9`: toggle test mode

## Slash Commands

- `/isilive test`
- `/isilive testall`
- `/isilive tptest`
- `/isilive tpdebug`
- `/isilive lead`
- `/isilive lang [en|de]`
- `/isilive pause`
- `/isilive resume`
- `/isilive stop`
- `/isilive start`
- `/isilive bindcheck`

## Files

- `isiLive.toc`: addon metadata and load order
- `isiLive.lua`: main addon logic
- `isiLive_locale.lua`: locale/language/flag mapping helpers
- `isiLive_teleport.lua`: dungeon teleport mapping and secure teleport button helpers
- `isiLive_notice.lua`: center notice/invite hint UI components
- `isiLive_status.lua`: status line and dungeon-difficulty helpers
- `isiLive_units.lua`: unit/spec/name/RIO helper functions
- `isiLive_demo.lua`: dummy/test roster generation
- `isiLive_sync.lua`: addon sync (`HELLO`/`ACK`) and user detection
- `isiLive_queue.lua`: LFG/queue invite capture and parsing
- `isiLive_inspect.lua`: inspect queue/retry/cache controller
- `isiLive_roster.lua`: roster ordering + display-data builders
- `isiLive_events.lua`: event gate wrapper for stop/pause/test/hidden states
- `isiLive_commands.lua`: slash command registration/dispatch
- `isiLive_ui.lua`: main frame/UI construction and widget wiring
- `realm_language_data.lua`: Blizzard EU realm locale mapping (including UTF-8 Russian realm names)
- `CHANGELOG.md`: release notes
- `RELEASE.md`: release runbook
- `RULES.md`: project/versioning rules
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

- GitHub Action (on push/PR to `main`): `stylua --check .`, `luacheck --exclude-files ".luarocks/**" -- .`, and Lua syntax check.
- Local checks:
  - `stylua --check .`
  - `luacheck --exclude-files ".luarocks/**" -- .`

## Developer Setup

Prerequisites:
- VS Code
- VS Code extensions:
  - `JohnnyMorganz.stylua`
  - `sumneko.lua` (LuaLS)

Local checks:
- `stylua .` (format)
- `stylua --check .` (CI check)
- `luacheck .` (lint)

Notes:
- The addon is namespace-based (`local addonName, addonTable = ...`).
- Do not introduce new globals. `IsiLiveDB` (SavedVariables) is intentionally allowed.
- `realm_language_data.lua` is intentionally excluded from format/lint (data-only file).

## CI Quality Gate

The CI workflow runs three checks on `push`/`pull_request` to `main`:
- `stylua --check .`
- `luacheck --exclude-files ".luarocks/**" -- .`
- Lua syntax check (`loadfile` validation for all `.lua` files except `.luarocks`)

## Git Hooks (Optional)

Enable the repository hook path:
- `git config core.hooksPath .githooks`

Then `pre-commit` will run:
- `stylua --check .`
- `luacheck --exclude-files ".luarocks/**" -- .`

## CurseForge Auto Publish

`release.yml` triggers CurseForge's official auto-packager when you push a tag like `v0.9.3`.

Required GitHub settings (repo `Settings -> Secrets and variables -> Actions`):

1. `Secret`: `CF_API_KEY` (your CurseForge API token)
2. `Variable`: `CURSE_PROJECT_ID` (numeric CurseForge project ID)

Release flow:

1. Bump version in `isiLive.toc` and update `CHANGELOG.md`
2. Commit + push to `main`
3. Create and push tag (recommended filename style): `git tag isiLive_0.9.14 && git push origin isiLive_0.9.14`

Note: this avoids the legacy `wow.curseforge.com/api/game/versions` lookup used by older packaging flows.
