---@diagnostic disable: undefined-global
-- Rule 248: run focus. Every scenario boots the real factory (main frame,
-- roster panel, run focus install) and pumps the client events through the
-- frames that registered them (testmodul/isilive_test_mplus_stress_helpers.lua).
-- The mock client has no frame loop, so PumpFrames plays the OnUpdate scripts
-- of the created frames, which drives the real animation.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local COMPACT_HEIGHT = 72

local function PumpFrames(session, seconds)
  local step = 0.05
  local elapsed = 0
  while elapsed < seconds do
    for index = 1, #session.frames do
      local frame = session.frames[index]
      local onUpdate = frame:GetScript("OnUpdate")
      if onUpdate and frame._isiLiveRunFocusPumped ~= false then
        onUpdate(frame, step)
      end
    end
    session.Advance(step)
    elapsed = elapsed + step
  end
end

local function Prepare(enabled)
  return function(globals, session)
    globals.IsiLiveDB.runFocusEnabled = enabled
    globals.C_ChallengeMode.IsChallengeModeActive = function()
      return session.active == true
    end
  end
end

local function Parts(session)
  local runtime = session.runtime
  local mainFrame = runtime.mainFrame
  local panel = runtime.rosterPanelController
  return mainFrame, panel, runtime.runFocusController
end

-- M+ layout after a full roster render: the height every later render asks for.
local function EnterRunLayout(session)
  local mainFrame, panel = Parts(session)
  panel.SetLayoutMode("compact_main_horizontal")
  panel.RenderRoster(session.runtime.GetRoster())
  return mainFrame:GetHeight()
end

-- Key start as the client delivers it: CHALLENGE_MODE_START, then the 10 s
-- key countdown (START_TIMER type 1); the M+ timer starts at its end.
local function BeginKey(session, countdown)
  session.active = true
  session.DispatchToFrames("CHALLENGE_MODE_START")
  if countdown ~= false then
    session.DispatchToFrames("START_TIMER", 1, 10, 10)
  end
end

local function StartKey(session)
  BeginKey(session)
  PumpFrames(session, 6)
end

local function ExpectCollapsed(Assert, session, label)
  local mainFrame, panel, runFocus = Parts(session)
  Assert.Equal(runFocus.GetPhase(), "collapsed", label .. ": run focus is collapsed")
  Assert.Equal(mainFrame:GetHeight(), COMPACT_HEIGHT, label .. ": the window shrinks to the run zone")
  Assert.False(panel.GetRefreshButton():IsShown(), label .. ": title-bar re-sync is hidden")
  Assert.False(panel.GetStatusLine():IsShown(), label .. ": the status line is hidden")
end

local function ExpectExpanded(Assert, session, label, fullHeight)
  local mainFrame, panel, runFocus = Parts(session)
  Assert.Equal(runFocus.GetPhase(), "idle", label .. ": run focus is idle")
  Assert.Equal(mainFrame:GetHeight(), fullHeight, label .. ": the window has its full height again")
  Assert.True(panel.GetRefreshButton():IsShown(), label .. ": title-bar re-sync is back")
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Run focus collapses the M+ window to the run zone at countdown 5 and keeps the run rows", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local mainFrame, panel, runFocus = Parts(session)
      Assert.NotNil(runFocus, "the factory installs the run focus")
      local fullHeight = EnterRunLayout(session)
      Assert.True(fullHeight > COMPACT_HEIGHT, "the M+ layout starts taller than the run zone")
      BeginKey(session)
      PumpFrames(session, 4.9)
      Assert.Equal(runFocus.GetPhase(), "idle", "the key start and countdown 6 only arm the run focus")
      PumpFrames(session, 0.1)
      Assert.Equal(runFocus.GetPhase(), "collapsing", "countdown 5 animates the collapse")
      Assert.Equal(mainFrame:GetHeight(), fullHeight, "the rest fades out before the window folds")
      PumpFrames(session, 0.2)
      local midHeight = mainFrame:GetHeight()
      Assert.True(midHeight < fullHeight and midHeight > COMPACT_HEIGHT, "the height moves between both")
      PumpFrames(session, 1)
      ExpectCollapsed(Assert, session, "key running")
      local point = mainFrame._points[#mainFrame._points]
      Assert.Equal(point and point[1], "BOTTOMLEFT", "the window is pinned at its bottom edge")
      panel.RenderRoster(session.runtime.GetRoster())
      ExpectCollapsed(Assert, session, "after a roster render")
    end, Prepare(true))
  end)

  test("Run focus stays off without the setting and ignores the setting in test mode", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local mainFrame, panel, runFocus = Parts(session)
      local fullHeight = EnterRunLayout(session)
      StartKey(session)
      Assert.Equal(runFocus.GetPhase(), "idle", "runFocusEnabled is Pattern B: off by default")
      Assert.Equal(mainFrame:GetHeight(), fullHeight, "the window keeps its height")
      Assert.True(session.addon.RunFocus.SetTestMode(true), "the test switch turns on")
      PumpFrames(session, 1)
      ExpectCollapsed(Assert, session, "test mode")
      Assert.False(session.addon.RunFocus.SetTestMode(false), "the test switch turns off")
      PumpFrames(session, 1)
      ExpectExpanded(Assert, session, "test mode off", fullHeight)
      session.addon._RosterInternal.LAYOUT_LOCKED_TO_MPLUS = false -- rule 249 lifted for the V check
      panel.SetLayoutMode("compact_vertical")
      session.addon.RunFocus.SetTestMode(true)
      PumpFrames(session, 1)
      Assert.Equal(runFocus.GetPhase(), "idle", "only the M+ layout has a run zone")
    end, Prepare(nil))
  end)

  test("Run focus waits for combat to end before the window shrinks or expands", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local mainFrame, panel, runFocus = Parts(session)
      local fullHeight = EnterRunLayout(session)
      session.combat = true
      StartKey(session)
      Assert.Equal(runFocus.GetPhase(), "collapsed", "content hides at once in combat")
      Assert.False(panel.GetRefreshButton():IsShown(), "the title bar is hidden in combat")
      Assert.Equal(mainFrame:GetHeight(), fullHeight, "the protected main frame keeps its size in combat")
      session.combat = false
      session.DispatchToFrames("PLAYER_REGEN_ENABLED")
      PumpFrames(session, 1)
      ExpectCollapsed(Assert, session, "after combat")
      session.combat = true
      session.active = false
      session.DispatchToFrames("CHALLENGE_MODE_RESET")
      PumpFrames(session, 1)
      Assert.Equal(runFocus.GetPhase(), "collapsed", "an expand waits for the end of combat")
      session.combat = false
      session.DispatchToFrames("PLAYER_REGEN_ENABLED")
      PumpFrames(session, 1)
      ExpectExpanded(Assert, session, "after combat", fullHeight)
    end, Prepare(true))
  end)

  test("Run focus expands 4 seconds after a completed key and at once after a reset", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local _, _, runFocus = Parts(session)
      local fullHeight = EnterRunLayout(session)
      StartKey(session)
      session.active = false
      session.DispatchToFrames("CHALLENGE_MODE_COMPLETED")
      PumpFrames(session, 3)
      Assert.Equal(runFocus.GetPhase(), "collapsed", "the run zone stays for the end of the key")
      PumpFrames(session, 2)
      ExpectExpanded(Assert, session, "completed key", fullHeight)
      StartKey(session)
      session.active = false
      session.DispatchToFrames("CHALLENGE_MODE_RESET")
      PumpFrames(session, 1)
      ExpectExpanded(Assert, session, "reset key", fullHeight)
      session.active = true
      session.DispatchToFrames("PLAYER_ENTERING_WORLD", false, true)
      ExpectCollapsed(Assert, session, "reload inside a key")
      session.active = false
      session.DispatchToFrames("ZONE_CHANGED_NEW_AREA")
      ExpectExpanded(Assert, session, "left the instance", fullHeight)
    end, Prepare(true))
  end)

  test("Run focus ignores a pull timer, falls back to the timer start and cancels on a reset", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local _, _, runFocus = Parts(session)
      local fullHeight = EnterRunLayout(session)
      BeginKey(session, false)
      session.DispatchToFrames("START_TIMER", 2, 10, 10)
      PumpFrames(session, 10)
      Assert.Equal(runFocus.GetPhase(), "idle", "a pull timer (PlayerCountdown) never collapses")
      session.DispatchToFrames("WORLD_STATE_TIMER_START", 1)
      PumpFrames(session, 1)
      ExpectCollapsed(Assert, session, "timer start fallback")
      session.active = false
      session.DispatchToFrames("CHALLENGE_MODE_RESET")
      PumpFrames(session, 1)
      ExpectExpanded(Assert, session, "reset key", fullHeight)
      BeginKey(session)
      PumpFrames(session, 2)
      session.active = false
      session.DispatchToFrames("CHALLENGE_MODE_RESET")
      PumpFrames(session, 10)
      ExpectExpanded(Assert, session, "reset during the countdown", fullHeight)
      session.DispatchToFrames("WORLD_STATE_TIMER_START", 1)
      ExpectExpanded(Assert, session, "timer start after a reset", fullHeight)
      BeginKey(session)
      PumpFrames(session, 2)
      session.globals.IsiLiveDB.runFocusEnabled = false
      session.addon.RunFocus.Refresh()
      session.globals.IsiLiveDB.runFocusEnabled = true
      PumpFrames(session, 5)
      Assert.Equal(runFocus.GetPhase(), "idle", "turning the setting off cancels the pending collapse")
    end, Prepare(true))
  end)

  test("Run focus pins the chosen edge and re-applies an anchor change while collapsed", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local mainFrame, _, runFocus = Parts(session)
      local db = session.globals.IsiLiveDB
      local function Anchor()
        local point = mainFrame._points[#mainFrame._points]
        return point and point[1]
      end
      local fullHeight = EnterRunLayout(session)
      db.runFocusAnchor = "top"
      StartKey(session)
      ExpectCollapsed(Assert, session, "top anchor")
      Assert.Equal(Anchor(), "TOPLEFT", "the top anchor pins the top edge")
      db.runFocusAnchor = "bottom"
      session.addon.RunFocus.Refresh()
      ExpectCollapsed(Assert, session, "switched to bottom")
      Assert.Equal(Anchor(), "BOTTOMLEFT", "an anchor change while collapsed re-pins at once")
      session.combat = true
      db.runFocusAnchor = "top"
      session.addon.RunFocus.Refresh()
      Assert.Equal(Anchor(), "BOTTOMLEFT", "in combat the anchor change waits")
      session.combat = false
      session.DispatchToFrames("PLAYER_REGEN_ENABLED")
      ExpectCollapsed(Assert, session, "after combat")
      Assert.Equal(Anchor(), "TOPLEFT", "the anchor change applies when combat ends")
      db.runFocusAnchor = "sideways"
      session.addon.RunFocus.Refresh()
      Assert.Equal(Anchor(), "BOTTOMLEFT", "an invalid anchor fails closed to bottom")
      Assert.Equal(runFocus.GetPhase(), "collapsed", "the run zone stays collapsed throughout")
      session.active = false
      session.DispatchToFrames("CHALLENGE_MODE_RESET")
      PumpFrames(session, 1)
      ExpectExpanded(Assert, session, "after the reset", fullHeight)
    end, Prepare(true))
  end)

  test("Run focus opens out of combat after a debounce and folds at once on the next pull", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local _, _, runFocus = Parts(session)
      local db = session.globals.IsiLiveDB
      local fullHeight = EnterRunLayout(session)
      StartKey(session)
      local function Pull(seconds)
        session.DispatchToFrames("PLAYER_REGEN_DISABLED")
        session.combat = true
        PumpFrames(session, seconds)
        session.combat = false
        session.DispatchToFrames("PLAYER_REGEN_ENABLED")
      end
      Pull(2)
      PumpFrames(session, 3)
      ExpectCollapsed(Assert, session, "option off")
      db.runFocusExpandOutOfCombat = true
      Pull(2)
      PumpFrames(session, 1)
      ExpectCollapsed(Assert, session, "inside the debounce")
      PumpFrames(session, 1.5)
      ExpectExpanded(Assert, session, "after the debounce", fullHeight)
      session.DispatchToFrames("PLAYER_REGEN_DISABLED")
      ExpectCollapsed(Assert, session, "folded in PLAYER_REGEN_DISABLED before the lockdown")
      session.combat = true
      PumpFrames(session, 1)
      session.combat = false
      session.DispatchToFrames("PLAYER_REGEN_ENABLED")
      PumpFrames(session, 1)
      Pull(2)
      PumpFrames(session, 1)
      ExpectCollapsed(Assert, session, "a chain pull restarts the debounce")
      PumpFrames(session, 1.5)
      ExpectExpanded(Assert, session, "after the chain pull", fullHeight)
      session.active = false
      session.DispatchToFrames("CHALLENGE_MODE_COMPLETED")
      PumpFrames(session, 6)
      ExpectExpanded(Assert, session, "after the key", fullHeight)
      Assert.Equal(runFocus.GetPhase(), "idle", "a completed key ends the open-out-of-combat state")
    end, Prepare(true))
  end)

  test("Run focus title switch toggles the setting and sits next to Re-Sync in M+ only", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local _, panel, runFocus = Parts(session)
      local db = session.globals.IsiLiveDB
      local fullHeight = EnterRunLayout(session)
      local button = runFocus.titleButton
      Assert.NotNil(button, "the run focus installs a title-bar switch")
      Assert.True(button:IsShown(), "the switch shows in the M+ layout")
      local point = button._points[#button._points]
      Assert.Equal(point[4], -96, "the switch takes the slot left of Re-Sync")
      button:GetScript("OnClick")(button, "LeftButton", false)
      Assert.True(db.runFocusEnabled == false, "a click switches run focus off")
      button:GetScript("OnClick")(button, "LeftButton", false)
      Assert.True(db.runFocusEnabled == true, "a second click switches it on")
      StartKey(session)
      ExpectCollapsed(Assert, session, "key with the switch on")
      Assert.False(button:IsShown(), "the switch hides with the title bar")
      button:GetScript("OnClick")(button, "LeftButton", false)
      PumpFrames(session, 1)
      ExpectExpanded(Assert, session, "switched off while collapsed", fullHeight)
      button:GetScript("OnClick")(button, "LeftButton", false)
      PumpFrames(session, 1)
      ExpectCollapsed(Assert, session, "switched on in a running key")
      session.active = false
      session.DispatchToFrames("CHALLENGE_MODE_RESET")
      PumpFrames(session, 1)
      session.addon._RosterInternal.LAYOUT_LOCKED_TO_MPLUS = false -- rule 249 lifted for the V check
      panel.SetLayoutMode("compact_vertical")
      Assert.False(button:IsShown(), "the switch is gone outside the M+ layout")
    end, Prepare(true))
  end)

  test("Layout lock keeps the main window in M+ and hides the mode buttons", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local _, panel, runFocus = Parts(session)
      local RI = session.addon._RosterInternal
      Assert.True(RI.IsLayoutLocked(), "the layout is locked to M+ by default")
      Assert.Equal(panel.GetLayoutMode(), "compact_main_horizontal", "a saved V layout opens as M+")
      Assert.Equal(session.globals.IsiLiveDB.rosterLayoutMode, "compact_vertical", "the saved value is not wiped")
      for _, mode in ipairs({ "compact_vertical", "compact_horizontal", "expanded" }) do
        panel.SetLayoutMode(mode)
        Assert.Equal(panel.GetLayoutMode(), "compact_main_horizontal", mode .. " resolves to M+")
      end
      local hiddenModeButtons = 0
      for _, frame in ipairs(session.frames) do
        if frame._modeTarget ~= nil then
          Assert.False(frame:IsShown(), "mode button " .. tostring(frame._modeLabel) .. " is hidden")
          hiddenModeButtons = hiddenModeButtons + 1
        end
      end
      Assert.Equal(hiddenModeButtons, 3, "all three mode buttons stay hidden")
      local point = runFocus.titleButton._points[#runFocus.titleButton._points]
      Assert.Equal(point[4], -96, "the run focus switch sits left of Re-Sync")
      session.raid = true
      session.DispatchToFrames("GROUP_ROSTER_UPDATE")
      session.Advance(2)
      Assert.Equal(panel.GetLayoutMode(), "compact_main_horizontal", "a raid does not fight the lock")
      session.raid = false
      session.DispatchToFrames("GROUP_ROSTER_UPDATE")
      session.Advance(2)
      Assert.Equal(panel.GetLayoutMode(), "compact_main_horizontal", "leaving the raid keeps M+")
      RI.LAYOUT_LOCKED_TO_MPLUS = false
      panel.SetLayoutMode("compact_vertical")
      Assert.Equal(panel.GetLayoutMode(), "compact_vertical", "lifting the flag brings layout switching back")
    end, function(globals)
      globals.IsiLiveDB.rosterLayoutMode = "compact_vertical"
      globals.IsiLiveDB.rosterDefaultLayoutMode = "last_used"
    end)
  end)
end
