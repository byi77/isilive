# wowsim — headless isiLive simulator

Runs the real addon (every file of `isiLive.toc`, in TOC order) outside the
game client, drives it through a scripted scenario on a simulated clock and
renders what the player would have seen into an HTML timeline viewer.

```sh
lua tools/wowsim/wowsim.lua --list                    # available scenarios
lua tools/wowsim/wowsim.lua mplus_run                 # run one, writes tools/wowsim/out/mplus_run.{json,html}
lua tools/wowsim/wowsim.lua mplus_run --locale enUS   # other client locale
lua tools/wowsim/wowsim.lua login --savedvars auto    # start from your real IsiLiveDB
tools/wowsim/screenshot.sh tools/wowsim/out/mplus_run.html 11 shot.png   # step 11 as PNG (Edge/Chrome)
```

Open `tools/wowsim/out/<scenario>.html` in a browser. Timeline at the bottom
(arrow keys step), log per step on the right (events, addon messages, chat,
sounds, prints, errors), hover/click a widget for its details. Deep links:
`<file>.html#step=11&zoom=1.6&frame=isiLiveMainFrame`.

Exit code is 1 when a scenario expectation failed or the addon raised a Lua
error, so scenarios double as regression tests.

## What is simulated

| Part | File | Notes |
|---|---|---|
| Widgets | `widgets.lua` | Frame, Button, Texture, FontString, StatusBar, Cooldown, EditBox, ScrollFrame, Slider, GameTooltip, animation groups, font objects; anchor resolution to absolute rects, OnShow/OnHide/OnUpdate/OnEvent, ScrollFrame clipping |
| World | `world.lua` | Clock + timer queue, party model, addon-message network (party/instance/whisper routing, sender echo) |
| WoW API | `api.lua` | Units, specs, group, challenge mode, scenario criteria (enemy forces), keystone in bag, inspect, chat, sounds, C_Timer, CVars, Settings panel, ... read from the world model per client |
| Runner | `wowsim.lua` | Clients, TOC loading, scenario API, JSON + viewer output |
| Viewer | `viewer_template.html`, `build_viewer.lua` | Self-contained HTML; local `.tga`/`.png` media are embedded |
| Lua 5.1 bridges | `compat.lua` | Runs on the CI's Lua 5.1 and on local Lua 5.4; on 5.4 `tostring` / `string.format("%d")` inside the addon follow 5.1 |

Every party member with `simulate = true` runs **its own copy of isiLive** in
a private global environment, so sync, BR/Lust announces and key sharing
travel as the real addon-message bytes. `addon = "libks"` members answer as
LibKeystone peers (RaiderIO and friends); `addon = "none"` members send
nothing.

## Writing a scenario

A scenario is `tools/wowsim/scenarios/<name>.lua` returning
`{ name, description, setup = { locale, party = {...} }, run = function(sim) ... end }`.
The first party entry is the player (the client whose UI is recorded).

| Call | Effect |
|---|---|
| `sim.Login()` | load the addon on every simulated client, fire the login events |
| `sim.Step(label)` | record a UI snapshot + the log since the previous step |
| `sim.Wait(seconds[, tick])` | advance the clock (OnUpdate every `tick`, default 0.1 s) |
| `sim.JoinGroup(...)`, `sim.LeaveGroup(name)`, `sim.SetLeader(name)` | group changes |
| `sim.ReadyCheck(initiator, {name = true})`, `sim.FinishReadyCheck()` | ready check |
| `sim.EnterDungeon(mapID)`, `sim.StartKey{mapID, level, bosses}`, `sim.CompleteKey()`, `sim.ResetKey()` | M+ lifecycle (new keystone for the keyholder after completion) |
| `sim.Combat(on)`, `sim.KillForces(n)`, `sim.KillBoss(i)` | combat and progress |
| `sim.Death(name)`, `sim.Resurrect(name)`, `sim.SetHealth(name, f)` | health |
| `sim.Cast(name, spellID)` | `UNIT_SPELLCAST_SUCCEEDED` on the caster's own client |
| `sim.Slash("/il sim")`, `sim.Click(textPattern)` | user input |
| `sim.Fire(event, ...)`, `sim.Env(name)`, `sim.Client(name)` | escape hatches |
| `sim.Expect(cond, msg)`, `sim.ExpectText(pattern)`, `sim.ExpectLog(kind, pattern, client)` | assertions |

## Limits

- Game textures and icons are not available; they render as labelled
  placeholders. Only isiLive's own `media/` files are drawn.
- Text width is estimated (0.55 em per glyph), so truncation is approximate.
- Combat itself (damage, auras, nameplates, the damage meter) is not
  simulated; secret values are never produced.
- On Lua 5.4, concatenating a float (`"x" .. 10 / 2`) still yields `5.0`.
- The run reports globals and widget methods the addon touched that the
  simulator does not provide; extend `api.lua` / `widgets.lua` when a feature
  depends on one.
