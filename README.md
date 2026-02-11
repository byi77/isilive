# isiLive

`isiLive` is a WoW group helper addon for Mythic+ pug/party flow.

Compatibility target: WoW `12.0+` only.

## Features

- Group roster table with columns: `Name`, `Flag`, `iLvl`, `RIO`
- Stable role sorting: `Tank -> Healer -> Damager`
- Right-side controls: `Readycheck`, `Countdown10`, `Refresh`, `DM Reset: ON/OFF`
- `M+ Management` teleport icon button
- Queue join detection with chat message, center notice, and invite hint
- Dungeon teleport icon buttons (center + right side)
- Teleport cooldown shown as `HH:MM`

## Behavior

- Auto-open on small-group join
- Auto-hide on M+ key start (`CHALLENGE_MODE_START`)
- Hidden window mode hard-stops non-essential scan/processing work
- `Readycheck` and `Countdown10` are leader-only

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

- `isiLive.lua`: main addon logic
- `realm_language_data.lua`: Blizzard EU realm locale mapping
- `CHANGELOG.md`: release notes

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

- GitHub Action: automatic Lua syntax check on each push/PR to `main`.
- Local (optional): `lua -e "assert(loadfile('isiLive.lua')); assert(loadfile('realm_language_data.lua'))"`

## CurseForge Auto Publish

`release.yml` publishes automatically when you push a tag like `v0.9.3`.

Required GitHub settings (repo `Settings -> Secrets and variables -> Actions`):

1. `Secret`: `CF_API_KEY` (your CurseForge API token)
2. `Variable`: `CURSE_PROJECT_ID` (numeric CurseForge project ID)

Release flow:

1. Bump version in `isiLive.toc` and update `CHANGELOG.md`
2. Commit + push to `main`
3. Create and push tag: `git tag v0.9.3 && git push origin v0.9.3`
