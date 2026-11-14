-- Run focus (rule 248): while a key runs, the M+ layout keeps only the run
-- zone (CD row with battle res, Bloodlust, M+ timer; killtracker row) and
-- slides the rest away. The bottom edge of the window stays put.
--
-- Covers: setting off -> nothing happens; key start only arms, the key
-- countdown collapses at 5 (not at 6); reset during the countdown cancels;
-- a pull timer never collapses, the M+ timer start does (fallback);
-- renders during the key stay collapsed; /reload mid-key starts collapsed;
-- completed key -> expand after 4 s; key start in combat -> content hidden at
-- once, shrink after combat; reset key -> immediate expand; the test switch
-- (slash command and demo action C13) works with the setting off.
local KR = 249 -- King's Rest
local COMPACT_HEIGHT = 72

local function MainFrame(sim)
  return sim.Env().isiLiveMainFrame
end

local function Height(sim)
  return MainFrame(sim):GetHeight()
end

local function Bottom(sim)
  return MainFrame(sim):GetBottom()
end

local function Top(sim)
  return MainFrame(sim):GetTop()
end

local function Near(a, b)
  return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.5
end

-- Visible text inside the main window only (demo cards overlap it).
local function HasText(frame, pattern)
  for _, child in ipairs(frame._children or {}) do
    if child:IsVisible() then
      if child._isFrame then
        if HasText(child, pattern) then
          return true
        end
      elseif type(child.GetText) == "function" then
        local text = child:GetText()
        if type(text) == "string" and text:find(pattern) then
          return true
        end
      end
    end
  end
  return false
end

local function Visible(sim, pattern)
  return HasText(MainFrame(sim), pattern)
end

-- sim.Click reads button text only; the tablet buttons carry theirs in a label.
local function ClickTabletButton(sim, text)
  local tablet = sim.Env().isiLiveSimulationTablet
  for _, child in ipairs(tablet and tablet._children or {}) do
    if child._isFrame and child:IsVisible() and child:GetScript("OnClick") then
      for _, region in ipairs(child._children or {}) do
        if not region._isFrame and type(region.GetText) == "function" and region:GetText() == text then
          child:GetScript("OnClick")(child, "LeftButton", false)
          return
        end
      end
    end
  end
  sim.Expect(false, "no tablet button: " .. text)
end

local function TitleToggle(sim)
  return sim.Client().addonTable.RunFocus.GetActiveController().titleButton
end

local function ClickTitleToggle(sim)
  local button = TitleToggle(sim)
  button:GetScript("OnClick")(button, "LeftButton", false)
end

-- [RUNFOCUS] lines in the runtime log ring (IsiLiveDB.runtimeLog).
local function HasRunFocusLine(sim, pattern)
  local ring = sim.Env().IsiLiveDB.runtimeLog
  for _, line in pairs(type(ring) == "table" and ring or {}) do
    if type(line) == "string" and line:find(pattern) then
      return true
    end
  end
  return false
end

local function ExpectCollapsed(sim, label)
  sim.Expect(Near(Height(sim), COMPACT_HEIGHT), label .. ": window height is the run zone (" .. Height(sim) .. ")")
  sim.Expect(not Visible(sim, "^Readycheck$"), label .. ": ready check button hidden")
  sim.Expect(not Visible(sim, "^Share Keys$"), label .. ": share keys button hidden")
  sim.Expect(not Visible(sim, "Stormbreaker"), label .. ": roster hidden")
  sim.Expect(not Visible(sim, "^isiLive$"), label .. ": title hidden")
  sim.Expect(Visible(sim, "^M%+Tracker$"), label .. ": killtracker visible")
  -- Live: "BR: --"; the demo shows charges as "0/1  1:52".
  sim.Expect(Visible(sim, "^BR:") or Visible(sim, "^%d+/%d+"), label .. ": battle res visible")
end

local function ExpectExpanded(sim, label, fullHeight)
  sim.Expect(Height(sim) > 150, label .. ": full window height (" .. Height(sim) .. ")")
  if fullHeight then
    sim.Expect(Near(Height(sim), fullHeight), label .. ": same height as before the key")
  end
  sim.Expect(Visible(sim, "^Readycheck$"), label .. ": ready check button back")
  sim.Expect(Visible(sim, "Stormbreaker"), label .. ": roster back")
  sim.Expect(Visible(sim, "^M%+Tracker$"), label .. ": killtracker still visible")
end

return {
  name = "run_focus",
  description = "Run focus (rule 248): M+ window collapses to the run zone in a key, keeps its bottom edge",
  timeLimits = { [KR] = 33 * 60 },
  setup = {
    locale = "enUS",
    party = {
      {
        name = "Isiplayer",
        class = "MAGE",
        specID = 63,
        role = "DAMAGER",
        ilvl = 712,
        rating = 3120,
        key = { mapID = KR, level = 14 },
      },
      {
        name = "Stormbreaker",
        class = "WARRIOR",
        specID = 73,
        role = "TANK",
        ilvl = 715,
        rating = 3188,
        key = { mapID = 250, level = 15 },
        addon = "libks",
      },
      {
        name = "Velindra",
        class = "DRUID",
        specID = 105,
        role = "HEALER",
        ilvl = 709,
        rating = 2990,
        simulate = true,
      },
    },
  },
  run = function(sim)
    sim.Login()
    sim.JoinGroup("Stormbreaker", "Velindra")
    sim.Wait(8)
    sim.Step("Group, M+ layout")
    local fullHeight = Height(sim)
    local bottom = Bottom(sim)
    ExpectExpanded(sim, "before the key")

    -- Setting off (default): a key start changes nothing.
    sim.EnterDungeon(KR)
    sim.StartKey({ mapID = KR, level = 14 })
    sim.Wait(1)
    sim.Step("Key start, setting off")
    ExpectExpanded(sim, "setting off", fullHeight)
    sim.ResetKey()
    sim.Wait(1)

    -- Setting on: the key start only arms; the countdown (START_TIMER 1,
    -- 10 s) starts the collapse when it shows 5.
    sim.Env().IsiLiveDB.runFocusEnabled = true
    sim.Env().IsiLiveDB.runtimeLogEnabled = true
    -- Client order: StartKey fires START_TIMER(1, 10, 10) 2.5 s before
    -- CHALLENGE_MODE_START and returns at the key start (countdown 7.5).
    sim.StartKey({ mapID = KR, level = 14 })
    sim.Wait(0.1, 0.05)
    sim.Step("Key start: armed, countdown 7.4")
    ExpectExpanded(sim, "right after the key start", fullHeight)
    sim.Wait(1.3, 0.05)
    sim.Step("Countdown 6: still full")
    ExpectExpanded(sim, "countdown at 6", fullHeight)
    sim.Wait(1.35, 0.05)
    sim.Step("Countdown 5: collapsing")
    sim.Expect(Height(sim) < fullHeight, "countdown at 5 starts the collapse animation")
    sim.Wait(1)
    sim.Step("Key running: run zone only")
    ExpectCollapsed(sim, "key running")
    sim.Expect(
      HasRunFocusLine(sim, "%[RUNFOCUS%] event=start_timer type=1 remaining=10 total=10 armed=no"),
      "trace: the countdown before the key start is recorded"
    )
    sim.Expect(
      HasRunFocusLine(sim, "%[RUNFOCUS%] event=armed pendingCountdown=yes remainingNow=7%.5"),
      "trace: the key start finds the running countdown"
    )
    sim.Expect(
      HasRunFocusLine(sim, "%[RUNFOCUS%] event=collapse trigger=countdown anchor=bottom inCombat=no"),
      "trace: collapse at countdown 5"
    )
    sim.Expect(Near(Bottom(sim), bottom), "bottom edge unchanged after collapse")

    sim.Wait(5)
    sim.KillForces(40)
    sim.Wait(6)
    sim.Step("Renders during the key")
    ExpectCollapsed(sim, "after renders")

    -- /reload inside the key starts collapsed, without an animation.
    sim.Reload()
    sim.Wait(1)
    sim.Step("/reload mid-key")
    sim.Env().IsiLiveDB.runtimeLogEnabled = true -- admin logs are off after every load
    ExpectCollapsed(sim, "after reload")
    local reloadBottom = Bottom(sim)

    -- Completed key: the run zone stays 4 s, then the window expands.
    sim.CompleteKey()
    sim.Wait(2)
    sim.Step("Completed: still collapsed")
    ExpectCollapsed(sim, "2 s after completion")
    sim.Wait(3)
    sim.Step("Completed + 5 s: expanded")
    ExpectExpanded(sim, "after completion")
    sim.Expect(Near(Bottom(sim), reloadBottom), "bottom edge unchanged after expand")
    local expandedBottom = Bottom(sim)
    local expandedHeight = Height(sim)

    -- A reset during the countdown cancels the pending collapse.
    sim.StartKey({ mapID = KR, level = 15, countdownOrder = "after_start", timerStartDelay = 10 })
    sim.Wait(2)
    sim.ResetKey()
    sim.Wait(10)
    sim.Step("Reset during the countdown")
    ExpectExpanded(sim, "reset during the countdown", expandedHeight)

    -- Without a key countdown: a pull timer (PlayerCountdown, type 2) never
    -- collapses; the M+ timer start does (fallback).
    sim.StartKey({ mapID = KR, level = 15, startTimer = false, timerStartDelay = 10 })
    sim.Fire("START_TIMER", 2, 10, 10)
    sim.Wait(9)
    sim.Step("Pull timer only: still full")
    ExpectExpanded(sim, "pull timer", expandedHeight)
    sim.Wait(2)
    sim.Step("M+ timer start: collapsed (fallback)")
    ExpectCollapsed(sim, "timer start fallback")
    sim.Expect(
      HasRunFocusLine(sim, "%[RUNFOCUS%] event=start_timer type=2 remaining=10 total=10 armed=yes"),
      "trace: the pull timer is seen"
    )
    sim.Expect(HasRunFocusLine(sim, "%[RUNFOCUS%] event=collapse trigger=fallback"), "trace: fallback collapse")
    sim.ResetKey()
    sim.Wait(1)

    -- Key start in combat: content hides at countdown 5, the shrink waits.
    sim.Combat(true)
    sim.StartKey({ mapID = KR, level = 15, countdownOrder = "after_start", timerStartDelay = 10 })
    sim.Wait(6)
    sim.Step("Countdown 5 in combat")
    sim.Expect(not Visible(sim, "^Readycheck$"), "combat: buttons hidden at once")
    sim.Expect(not Visible(sim, "Stormbreaker"), "combat: roster hidden at once")
    sim.Expect(Height(sim) > 150, "combat: frame keeps its height until combat ends")
    sim.Combat(false)
    sim.Wait(1)
    sim.Step("Combat over: shrunk")
    ExpectCollapsed(sim, "after combat")
    sim.Expect(
      HasRunFocusLine(sim, "%[RUNFOCUS%] event=deferred reason=combat action=collapse_geometry"),
      "trace: the combat collapse defers its geometry"
    )
    sim.Expect(Near(Bottom(sim), expandedBottom), "bottom edge unchanged after combat shrink")

    -- Reset (abandoned) key: expands at once.
    sim.ResetKey()
    sim.Wait(1)
    sim.Step("Key reset: expanded")
    ExpectExpanded(sim, "after reset")
    sim.Expect(HasRunFocusLine(sim, "%[RUNFOCUS%] event=expand trigger=reset"), "trace: reset expand")

    -- Anchor "top": the top edge stays, the run zone moves up with the
    -- bottom edge while the rest fades.
    local env = sim.Env()
    env.IsiLiveDB.runFocusAnchor = "top"
    local fullTop, fullBottom = Top(sim), Bottom(sim)
    sim.StartKey({ mapID = KR, level = 16, countdownOrder = "after_start", timerStartDelay = 10 })
    sim.Wait(5.25, 0.05)
    sim.Step("Top anchor: collapsing")
    sim.Expect(Height(sim) < 150, "top anchor: countdown 5 starts the collapse")
    sim.Expect(Near(Top(sim), fullTop), "top anchor: the top edge stays during the animation")
    sim.Wait(1)
    sim.Step("Top anchor: run zone at the top")
    ExpectCollapsed(sim, "top anchor")
    sim.Expect(Near(Top(sim), fullTop), "top anchor: top edge unchanged after collapse")

    -- Switching the anchor while collapsed re-applies at once.
    env.IsiLiveDB.runFocusAnchor = "bottom"
    sim.Client().addonTable.RunFocus.Refresh()
    sim.Wait(0.5)
    sim.Step("Anchor switched to bottom while collapsed")
    ExpectCollapsed(sim, "anchor switch to bottom")
    sim.Expect(Near(Bottom(sim), fullBottom), "anchor switch: bottom edge back where the full window ended")
    env.IsiLiveDB.runFocusAnchor = "top"
    sim.Client().addonTable.RunFocus.Refresh()
    sim.Wait(0.5)
    ExpectCollapsed(sim, "anchor switch to top")
    sim.Expect(Near(Top(sim), fullTop), "anchor switch: top edge back where the full window started")

    sim.CompleteKey()
    sim.Wait(5)
    sim.Step("Top anchor: expanded")
    ExpectExpanded(sim, "top anchor after completion")
    sim.Expect(Near(Top(sim), fullTop), "top anchor: top edge unchanged after expand")
    sim.Expect(Near(Bottom(sim), fullBottom), "top anchor: bottom edge back after expand")
    env.IsiLiveDB.runFocusAnchor = nil

    -- Option off (default): leaving combat inside the key keeps the run zone.
    sim.StartKey({ mapID = KR, level = 16, countdownOrder = "after_start", timerStartDelay = 10 })
    sim.Wait(6.5)
    ExpectCollapsed(sim, "key for the combat cycle")
    sim.Combat(true)
    sim.Wait(2)
    sim.Combat(false)
    sim.Wait(3)
    sim.Step("Out of combat, option off: stays collapsed")
    ExpectCollapsed(sim, "option off after combat")

    -- Option on: 1.5 s out of combat opens the window, the next fight folds
    -- it back at once; a chain pull inside the 1.5 s keeps it closed.
    env.IsiLiveDB.runFocusExpandOutOfCombat = true
    sim.Combat(true)
    sim.Wait(2)
    sim.Combat(false)
    sim.Wait(1)
    ExpectCollapsed(sim, "1 s out of combat (debounce)")
    sim.Wait(1.5)
    sim.Step("Out of combat, option on: opened")
    ExpectExpanded(sim, "1.5 s out of combat")
    sim.Expect(Near(Bottom(sim), fullBottom), "opened window keeps the bottom edge")
    sim.Combat(true)
    sim.Step("Combat start: folded at once")
    ExpectCollapsed(sim, "combat start in the opened window")
    sim.Expect(Near(Bottom(sim), fullBottom), "combat fold keeps the bottom edge")
    sim.Combat(false)
    sim.Wait(1)
    sim.Combat(true)
    sim.Wait(3)
    sim.Combat(false)
    sim.Wait(1)
    ExpectCollapsed(sim, "chain pull inside the debounce")
    sim.Wait(1.5)
    ExpectExpanded(sim, "after the chain pull")
    env.IsiLiveDB.runFocusAnchor = "top"
    sim.Combat(true)
    sim.Step("Combat start with top anchor")
    ExpectCollapsed(sim, "combat fold with top anchor")
    sim.Expect(Near(Top(sim), fullTop), "combat fold with top anchor keeps the top edge")
    sim.Combat(false)
    sim.Wait(3)
    ExpectExpanded(sim, "opened again with top anchor")
    env.IsiLiveDB.runFocusAnchor = nil

    -- Title-bar switch: off expands nothing more (already open) and keeps the
    -- next fight from folding; on folds the running key again.
    sim.Expect(TitleToggle(sim):IsVisible(), "title switch visible in the open M+ window")
    ClickTitleToggle(sim)
    sim.Expect(env.IsiLiveDB.runFocusEnabled == false, "title switch turns run focus off")
    sim.Step("Title switch off")
    sim.Combat(true)
    sim.Wait(0.5)
    ExpectExpanded(sim, "combat with run focus off")
    sim.Combat(false)
    sim.Wait(0.5)
    ClickTitleToggle(sim)
    sim.Expect(env.IsiLiveDB.runFocusEnabled == true, "title switch turns run focus on")
    sim.Wait(1)
    sim.Step("Title switch on: folded")
    ExpectCollapsed(sim, "title switch on in a running key")
    sim.Expect(not TitleToggle(sim):IsVisible(), "the switch hides with the title bar while collapsed")
    env.IsiLiveDB.runFocusExpandOutOfCombat = false
    sim.Client().addonTable.RunFocus.Refresh()

    -- In combat: switching on hides the content at once, the frame shrinks
    -- after combat; switching off expands after combat.
    ClickTitleToggle(sim) -- the button is hidden; its script still works for the test
    sim.Wait(1)
    ExpectExpanded(sim, "switched off out of combat")
    sim.Combat(true)
    ClickTitleToggle(sim)
    sim.Wait(1)
    sim.Expect(not Visible(sim, "^Readycheck$"), "switch on in combat hides the content at once")
    sim.Expect(Height(sim) > 150, "switch on in combat keeps the frame size")
    sim.Combat(false)
    sim.Wait(1)
    ExpectCollapsed(sim, "switch on in combat, after combat")
    sim.Combat(true)
    sim
      .Client().addonTable.RunFocus
      .GetActiveController().titleButton
      :GetScript("OnClick")(TitleToggle(sim), "LeftButton", false)
    sim.Wait(1)
    ExpectCollapsed(sim, "switch off in combat waits")
    sim.Combat(false)
    sim.Wait(1)
    ExpectExpanded(sim, "switch off in combat, after combat")
    env.IsiLiveDB.runFocusEnabled = true
    sim.CompleteKey()
    sim.Wait(5)

    -- Test switch with the setting off: slash command and demo action.
    sim.Env().IsiLiveDB.runFocusEnabled = false
    sim.Slash("/il runfocus")
    sim.Wait(1)
    sim.Step("/il runfocus: test on")
    ExpectCollapsed(sim, "slash test on")
    sim.Slash("/il runfocus")
    sim.Wait(1)
    ExpectExpanded(sim, "slash test off")

    -- Demo mode: the M+ tab of the demo tablet has the run focus switch (C13).
    sim.Slash("/il testall")
    sim.Wait(1)
    ClickTabletButton(sim, "M+")
    sim.Wait(0.5)
    ClickTabletButton(sim, "Run focus")
    sim.Wait(1)
    sim.Step("Demo action C13: run focus on")
    ExpectCollapsed(sim, "demo on")
    ClickTabletButton(sim, "Run focus")
    sim.Wait(1)
    sim.Step("Demo action C13: run focus off")
    ExpectExpanded(sim, "demo off")
    ClickTabletButton(sim, "Run focus")
    sim.Wait(1)
    ExpectCollapsed(sim, "demo on again")
    -- PLAYER_REGEN_DISABLED ends the demo just before the lockdown.
    sim.Fire("PLAYER_REGEN_DISABLED")
    sim.Fire("PLAYER_REGEN_ENABLED")
    sim.Wait(1)
    sim.Step("Demo ended: run focus off")
    sim.Expect(Height(sim) > 150, "leaving the demo ends the run focus preview")
    sim.Expect(Visible(sim, "^Readycheck$"), "leaving the demo brings the buttons back")
  end,
}
