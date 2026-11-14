---@diagnostic disable: undefined-global, undefined-field

-- Demo preview of the instance reset button (rule 235) and the resize grip
-- (rule 234). Every flow boots the real factory and enters the demo through
-- the real `/isilive testall` and `/isilive sim` slash commands; the buttons
-- are clicked through their real OnClick scripts. Only the WoW API surface is
-- stubbed: ResetInstances, SendChatMessage and print count their calls, so the
-- demo can be shown to never reach a real reset or a chat line.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

-- The simulation tablet and the DB schema are not part of the default
-- fixture; the tablet actions and the ADDON_LOADED sanitize pass need them.
local FixtureWithTablet = {
  buildGlobals = Fixture.buildGlobals,
  moduleFiles = function()
    local files = Fixture.moduleFiles()
    table.insert(files, 1, "isiLive_simulation_tablet.lua")
    table.insert(files, 1, "isiLive_db_schema.lua")
    return files
  end,
}

local DEMO_CLICK_NOTICE = "Demo: no instance was reset."

-- Harness trade-off (as in isilive_test_scenarios_audit_r7_sync_factory.lua):
-- the stub font strings have no layout, so the demo center notices get a
-- fixed text size to size their frame.
local function MeasurableFontStrings(globals)
  local createFrame = globals.CreateFrame
  globals.CreateFrame = function(...)
    local frame = createFrame(...)
    local createFontString = frame.CreateFontString
    function frame:CreateFontString(...)
      local fontString = createFontString(self, ...)
      function fontString:GetStringHeight()
        return 12
      end
      function fontString:GetStringWidth()
        return 80
      end
      return fontString
    end
    return frame
  end
end

-- No key, no lead and inside an instance: nothing in the live state would
-- show the reset button, so whatever shows it comes from the demo.
local function PrepareWorld(opts)
  opts = opts or {}
  return function(globals, session)
    MeasurableFontStrings(globals)
    session.resetCalls = 0
    session.chat = {}
    session.printed = {}
    globals.IsInInstance = function()
      return true, "party"
    end
    globals.UnitIsGroupLeader = function()
      return false
    end
    globals.ResetInstances = function()
      session.resetCalls = session.resetCalls + 1
    end
    globals.SendChatMessage = function(message, channel)
      session.chat[#session.chat + 1] = { message = message, channel = channel }
    end
    local basePrint = globals.print
    globals.print = function(message)
      session.printed[#session.printed + 1] = tostring(message)
      basePrint(message)
    end
    local db = globals.IsiLiveDB
    db.instanceResetButtonEnabled = opts.buttonEnabled
    db.instanceResetAnnounce = true
    db.lockMainFramePosition = opts.locked
    if opts.layout then
      db.rosterDefaultLayoutMode = opts.layout
    end
  end
end

local function FindResetButton(session)
  for _, frame in ipairs(session.frames) do
    if frame._verticalY == -210 and frame._m2ToolbarText ~= nil then
      return frame
    end
  end
  return nil
end

local function IsShown(frame)
  return frame ~= nil and frame:IsShown() == true
end

local function Click(frame)
  local onClick = frame:GetScript("OnClick")
  if onClick then
    onClick(frame, "LeftButton")
  end
end

local function LastAnchor(frame)
  local point = frame._points[#frame._points]
  return point and point[1], point and point[2], point and point[3]
end

local function CollectToolbarRow(session, resetButton)
  local row = {}
  for _, frame in ipairs(session.frames) do
    local point, x, y = LastAnchor(frame)
    if point == "BOTTOMLEFT" and y == 104 and (frame ~= resetButton or IsShown(frame)) then
      row[#row + 1] = { frame = frame, x = x, width = frame._size[1] }
    end
  end
  table.sort(row, function(a, b)
    return a.x < b.x
  end)
  return row
end

local function CountPrinted(session, text)
  local count = 0
  for _, line in ipairs(session.printed) do
    if line:find(text, 1, true) then
      count = count + 1
    end
  end
  return count
end

local function TabletActions(session)
  local byId = {}
  for _, action in ipairs(session.runtime._simulationTabletActions or {}) do
    byId[action.id] = action
  end
  return byId
end

local function Slash(session, command)
  session.globals.SlashCmdList.ISILIVE(command)
  session.Advance(1)
end

local function Grip(session)
  return session.runtime.mainUI.resizeGrip
end

-- Boots the real factory the way the client does: SavedVariables are nil
-- while the addon files run and are restored before ADDON_LOADED.
local function BootFromSavedVariables(ctx, savedDB, callback)
  local globals, session = Stress.BuildGlobals(FixtureWithTablet.buildGlobals)
  PrepareWorld({ buttonEnabled = savedDB.instanceResetButtonEnabled, locked = savedDB.lockMainFramePosition })(
    globals,
    session
  )
  for key, value in pairs(savedDB) do
    globals.IsiLiveDB[key] = value
  end
  local db = globals.IsiLiveDB
  ctx.with_globals(globals, function()
    _G.IsiLiveDB = nil
    local addon = ctx.load_modules(FixtureWithTablet.moduleFiles())
    local runtime = addon.Factory.InitializeAddon("isiLive", addon, { returnContext = true })
    session.addon, session.runtime, session.globals = addon, runtime, globals
    local gated = runtime.eventFrame:GetScript("OnEvent")
    function session.Dispatch(event, ...)
      gated(runtime.eventFrame, event, ...)
    end
    _G.IsiLiveDB = db
    session.Dispatch("ADDON_LOADED", "isiLive")
    session.DispatchToFrames("PLAYER_LOGIN")
    session.Dispatch("GROUP_ROSTER_UPDATE")
    session.Advance(5)
    callback(session, db)
    ctx.assert.Equal(#session.errors, 0, "protected dispatch must report zero errors throughout the workload")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Demo shows the instance reset button in the M+ layout and a demo click never resets", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      local db = session.globals.IsiLiveDB
      local button = Assert.NotNil(FindResetButton(session), "the main window must own a reset button")
      Assert.False(IsShown(button), "no key, no lead, inside an instance: hidden before the demo")

      Slash(session, "testall")
      Assert.True(IsShown(button), "the demo shows the reset button without any group or instance state")
      Assert.True(db.instanceResetButtonEnabled == true, "the demo enables the default-off setting")
      local row = CollectToolbarRow(session, button)
      Assert.Equal(#row, 6, "the demo button joins the M+ toolbar row as its sixth button")
      Assert.Equal(row[6].frame, button, "the reset button takes the last slot")
      for index = 2, #row do
        Assert.True(row[index].x >= row[index - 1].x + row[index - 1].width + 6, "toolbar buttons must not overlap")
      end

      Click(button)
      Assert.Equal(session.resetCalls, 0, "a demo click must never call ResetInstances")
      Assert.Equal(#session.chat, 0, "a demo click must never send a chat line")
      Assert.False(IsShown(button), "the demo click drops the demo mark like a confirmed reset")
      Assert.Equal(CountPrinted(session, DEMO_CLICK_NOTICE), 1, "the demo click prints one local notice")
      Assert.Equal(#CollectToolbarRow(session, button), 5, "the toolbar row is back to five buttons")

      Click(button)
      Assert.Equal(session.resetCalls, 0, "a stale click after the demo mark is gone never resets")
      Assert.Equal(CountPrinted(session, DEMO_CLICK_NOTICE), 1, "a stale click prints nothing")

      session.runtime.ExitTestMode()
      session.Advance(1)
      Assert.False(IsShown(button), "the demo end leaves the button hidden")
      Assert.Equal(db.instanceResetButtonEnabled, false, "the demo end restores the user's setting")
      Assert.Nil(db.demoFeatureSnapshot, "the persisted demo snapshot is gone")
      Assert.Equal(session.resetCalls, 0, "the whole demo never called ResetInstances")
      Assert.Equal(#session.chat, 0, "the whole demo never sent a chat line")
    end, PrepareWorld({ buttonEnabled = false }))
  end)

  test("Demo shows the instance reset button in the M layout and the demo end hides it", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      -- Rule 249 locks the window to M+; the kept M layout is covered unlocked.
      session.addon._RosterInternal.LAYOUT_LOCKED_TO_MPLUS = false
      session.runtime.rosterPanelController.SetLayoutMode("expanded")
      local db = session.globals.IsiLiveDB
      local button = FindResetButton(session)
      Slash(session, "testall")
      Assert.True(IsShown(button), "M layout: the demo shows the button")
      local point, x, y = LastAnchor(button)
      Assert.Equal(point, "TOPRIGHT", "M anchors the leader column at the top right")
      Assert.Equal(x, -145, "the demo button shares the leader column")
      Assert.Equal(y, -210, "the demo button takes the slot below Mark-T/H")
      Assert.Equal(button._size[1], 120, "full-width leader button")

      session.runtime.ExitTestMode()
      session.Advance(1)
      Assert.False(IsShown(button), "the demo end hides the button")
      Assert.Nil(db.instanceResetButtonEnabled, "an unset setting returns to unset")
      Assert.False(session.addon.InstanceReset.IsDemoActive(), "the demo end drops the demo mark")
      Assert.Equal(session.resetCalls, 0, "the demo never called ResetInstances")
    end, PrepareWorld({ layout = "expanded" }))
  end)

  test("Simulation tablet C12 toggles the demo reset button and F3 and closing remove it", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      local db = session.globals.IsiLiveDB
      local button = FindResetButton(session)
      Slash(session, "sim")
      local tablet = Assert.NotNil(session.runtime.simulationTabletController, "/isilive sim opens the tablet")
      local actions = TabletActions(session)
      local toggle = Assert.NotNil(actions.C12, "the tablet must offer C12")
      Assert.Equal(toggle.category, "mplus", "C12 sits on the M+ tab")

      toggle.run()
      Assert.True(IsShown(button), "C12 shows the demo reset button")
      Assert.True(db.instanceResetButtonEnabled == true, "C12 enables the default-off setting for the preview")
      toggle.run()
      Assert.False(IsShown(button), "a second C12 hides it again")
      toggle.run()
      Assert.True(IsShown(button), "a third C12 shows it again")

      actions.F3.run()
      session.Advance(1)
      Assert.True(tablet.IsShown(), "F3 keeps the tablet open")
      Assert.False(IsShown(button), "F3 removes the demo reset button")
      Assert.Equal(db.instanceResetButtonEnabled, false, "F3 restores the user's setting")
      Assert.Nil(db.demoFeatureSnapshot, "F3 drops the persisted snapshot")

      toggle.run()
      Assert.True(IsShown(button), "C12 works again after F3")
      Slash(session, "sim")
      Assert.False(tablet.IsShown(), "the second /isilive sim closes the tablet")
      Assert.False(IsShown(button), "closing the tablet removes the demo reset button")
      Assert.Equal(db.instanceResetButtonEnabled, false, "closing the tablet restores the user's setting")
      Assert.Equal(session.resetCalls, 0, "the tablet never called ResetInstances")
      Assert.Equal(#session.chat, 0, "the tablet never sent a chat line")
    end, PrepareWorld({ buttonEnabled = false }))
  end)

  test("Demo shows the resize grip while the window stays locked and hides it on demo end", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      local db = session.globals.IsiLiveDB
      local mainUI = session.runtime.mainUI
      local grip = Assert.NotNil(Grip(session), "the main window must own a resize grip")
      Assert.False(IsShown(grip), "the default lock hides the grip")

      Slash(session, "testall")
      Assert.True(IsShown(grip), "the demo shows the grip")
      Assert.True(mainUI.GetDragLocked(), "the window stays locked during the demo")
      Assert.Nil(db.lockMainFramePosition, "the demo never writes the lock setting")

      session.runtime.ExitTestMode()
      session.Advance(1)
      Assert.False(IsShown(grip), "the demo end hides the grip again")
      Assert.True(mainUI.GetDragLocked(), "the window is still locked after the demo")
      Assert.Nil(db.lockMainFramePosition, "the lock setting is untouched after the demo")

      Slash(session, "sim")
      local actions = TabletActions(session)
      local toggle = Assert.NotNil(actions.F4, "the tablet must offer F4")
      Assert.Equal(toggle.category, "extras", "F4 sits on the extras tab")
      toggle.run()
      Assert.True(IsShown(grip), "F4 shows the grip")
      toggle.run()
      Assert.False(IsShown(grip), "a second F4 hides it")
      toggle.run()
      Slash(session, "sim")
      Assert.False(IsShown(grip), "closing the tablet hides the grip")
      Assert.Nil(db.lockMainFramePosition, "the tablet never writes the lock setting")
    end, PrepareWorld())
  end)

  test("Demo grip on an unlocked window stays after the demo and a combat close waits for combat end", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      local db = session.globals.IsiLiveDB
      local grip = Grip(session)
      Assert.True(IsShown(grip), "an unlocked window shows the grip")
      Slash(session, "testall")
      session.runtime.ExitTestMode()
      session.Advance(1)
      Assert.True(IsShown(grip), "the demo end keeps the grip of an unlocked window")
      Assert.Equal(db.lockMainFramePosition, false, "the unlocked setting stays")

      session.runtime.mainUI.SetDragLocked(true)
      Assert.False(IsShown(grip), "setup: locked again, grip hidden")
      Slash(session, "sim")
      TabletActions(session).F4.run()
      Assert.True(IsShown(grip), "F4 shows the grip")
      session.combat = true
      Slash(session, "sim")
      Assert.True(IsShown(grip), "in combat the grip on the protected main frame is not hidden")
      session.combat = false
      session.Dispatch("PLAYER_REGEN_ENABLED")
      session.Advance(1)
      Assert.False(IsShown(grip), "the combat-end drain hides the grip")
    end, PrepareWorld({ locked = false }))
  end)

  test("Demo reload with a persisted snapshot restores the reset setting and keeps the window lock", function()
    local saved
    BootFromSavedVariables(
      ctx,
      { instanceResetButtonEnabled = false, lockMainFramePosition = true },
      function(session, db)
        Slash(session, "testall")
        Assert.True(IsShown(FindResetButton(session)), "setup: the demo shows the reset button")
        Assert.True(IsShown(Grip(session)), "setup: the demo shows the grip")
        local persisted = Assert.NotNil(db.demoFeatureSnapshot, "the running demo persists the user's values")
        Assert.Equal(persisted.values.instanceResetButtonEnabled, false, "the reset setting is persisted")
        Assert.Equal(db.lockMainFramePosition, true, "the demo keeps the saved lock")
        -- /reload while the demo runs: only the saved table survives.
        saved = {}
        for key, value in pairs(db) do
          saved[key] = value
        end
      end
    )

    BootFromSavedVariables(ctx, saved, function(session, db)
      Assert.Nil(db.demoFeatureSnapshot, "the load consumes the snapshot")
      Assert.Equal(db.instanceResetButtonEnabled, false, "the reload restores the reset setting")
      Assert.Equal(db.lockMainFramePosition, true, "the reload keeps the window lock")
      Assert.True(session.runtime.mainUI.GetDragLocked(), "the reloaded window is locked")
      Assert.False(IsShown(Grip(session)), "after the reload the grip is hidden again")
      Assert.False(IsShown(FindResetButton(session)), "after the reload the reset button is hidden")
      Assert.False(session.addon.InstanceReset.IsDemoActive(), "the demo mark does not survive a reload")
    end)
  end)
end
