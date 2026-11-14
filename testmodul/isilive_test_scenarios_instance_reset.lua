---@diagnostic disable: undefined-global, undefined-field

-- Instance reset button after a key (rule 235). Every flow boots the real
-- factory and pumps the client events through the real gated dispatcher
-- (testmodul/isilive_test_mplus_stress_helpers.lua). Only the WoW API surface
-- is stubbed: instance state, group leader, ResetInstances, the localized
-- INSTANCE_RESET_* globals and the chat send.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

-- King's Rest, a dungeon of the active season (data/isiLive_seasons.lua).
local SEASON_MAP_ID = 249
-- The stress fixture's own key map: not part of the active season.
local OFF_SEASON_MAP_ID = 2662
local DUNGEON_NAME = "King's Rest"
local SUCCESS_FORMAT = "%s has been reset."
local FAILED_FORMAT = "Cannot reset %s.  There are players still inside the instance."
local FAILED_OFFLINE_FORMAT = "Cannot reset %s.  There are players offline in your party."
local SECRET = setmetatable({}, {
  __tostring = function()
    return "<secret>"
  end,
})

-- Harness trade-off (as in isilive_test_scenarios_audit_r7_sync_factory.lua):
-- the stub font strings have no layout, so the leader-gain center notice gets
-- a fixed text size to size its frame.
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

local function PrepareWorld(opts)
  opts = opts or {}
  return function(globals, session)
    MeasurableFontStrings(globals)
    session.inInstance = true
    session.leader = opts.leader == nil and true or opts.leader
    session.keyMapID = opts.keyMapID or SEASON_MAP_ID
    session.resetCalls = 0
    session.chat = {}
    globals.issecretvalue = function(value)
      return value == SECRET
    end
    globals.IsInInstance = function()
      return session.inInstance, session.inInstance and "party" or "none"
    end
    globals.UnitIsGroupLeader = function(unit)
      if unit == "player" then
        return session.leader
      end
      return false
    end
    globals.ResetInstances = function()
      session.resetCalls = session.resetCalls + 1
    end
    globals.INSTANCE_RESET_SUCCESS = SUCCESS_FORMAT
    globals.INSTANCE_RESET_FAILED = FAILED_FORMAT
    globals.INSTANCE_RESET_FAILED_OFFLINE = FAILED_OFFLINE_FORMAT
    globals.SendChatMessage = function(message, channel)
      session.chat[#session.chat + 1] = { message = message, channel = channel }
    end
    globals.C_ChallengeMode.GetActiveChallengeMapID = function()
      return session.active and session.keyMapID or nil
    end
    local db = globals.IsiLiveDB
    db.instanceResetButtonEnabled = opts.buttonEnabled ~= false
    db.instanceResetAnnounce = opts.announce ~= false
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

local function RunKey(session, endEvent)
  session.inInstance = true
  session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
  session.active = true
  session.Dispatch("CHALLENGE_MODE_START")
  session.Advance(2)
  session.Dispatch(endEvent or "CHALLENGE_MODE_COMPLETED")
  session.Advance(1)
end

local function LeaveDungeon(session)
  session.active = false
  session.inInstance = false
  session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
  session.Advance(1)
end

local function CountChat(session, text)
  local count = 0
  for _, entry in ipairs(session.chat) do
    if entry.message == text then
      count = count + 1
    end
  end
  return count
end

local function LastAnchor(frame)
  local point = frame._points[#frame._points]
  return point and point[1], point and point[2], point and point[3]
end

-- The M+ toolbar row: every frame anchored at the toolbar row height. The stub
-- frames start hidden and the standard buttons are never shown explicitly
-- (they are shown by default in the client), so only the reset button is
-- filtered by its own visibility.
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

return function(test, ctx)
  local Assert = ctx.assert

  test(
    "Instance reset button shows for the leader outside after a season key and clears on the reset message",
    function()
      Stress.WithParty(ctx, Fixture, function(session)
        local button = Assert.NotNil(FindResetButton(session), "the main window must own a reset button")
        Assert.False(IsShown(button), "no key ended yet: the button stays hidden")

        RunKey(session)
        Assert.False(IsShown(button), "still inside the dungeon after the key: hidden")

        LeaveDungeon(session)
        Assert.True(IsShown(button), "outside after a season key as leader: the button shows")

        Click(button)
        Assert.Equal(session.resetCalls, 1, "the click must call ResetInstances once")
        Assert.True(IsShown(button), "the click alone proves nothing: the button waits for the confirmation")

        session.Dispatch("CHAT_MSG_SYSTEM", string.format(SUCCESS_FORMAT, DUNGEON_NAME))
        session.Advance(1)
        Assert.False(IsShown(button), "the confirmed reset clears the mark and hides the button")
        Assert.Equal(CountChat(session, DUNGEON_NAME .. " has been reset."), 1, "the own reset is announced once")
        Assert.Equal(session.chat[#session.chat].channel, "PARTY", "the announce goes to party chat")
        Assert.False(session.chat[#session.chat].message:find("|c", 1, true) ~= nil, "no color codes in the announce")

        Click(button)
        Assert.Equal(session.resetCalls, 1, "a stale click after the reset must not call ResetInstances again")
      end, PrepareWorld())
    end
  )

  test("Instance reset button counts an abandoned season key", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local button = FindResetButton(session)
      RunKey(session, "CHALLENGE_MODE_RESET")
      LeaveDungeon(session)
      Assert.True(IsShown(button), "an abandoned key arms the reset like a completed one")
    end, PrepareWorld())
  end)

  test("Instance reset button counts a key the group walked out of (no CHALLENGE_MODE_RESET)", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local button = FindResetButton(session)
      session.inInstance = true
      session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
      session.active = true
      session.Dispatch("CHALLENGE_MODE_START")
      session.Advance(2)
      -- Leaving: the client lifts the restriction, the player lands outside,
      -- and no CHALLENGE_MODE_RESET arrives (probe log 2026-11-13).
      session.Dispatch("ADDON_RESTRICTION_STATE_CHANGED", 2, 0)
      LeaveDungeon(session)
      Assert.True(IsShown(button), "a left season key arms the reset and shows the button outside")

      -- The reset the client fires right before the next key start must not
      -- re-arm or disturb anything.
      session.inInstance = true
      session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
      session.Dispatch("CHALLENGE_MODE_RESET")
      session.active = true
      session.Dispatch("CHALLENGE_MODE_START")
      session.Advance(1)
      Assert.False(IsShown(button), "inside the next key: hidden")
    end, PrepareWorld())
  end)

  test("Instance reset mark from walking out is dropped when the player re-enters the running key", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local button = FindResetButton(session)
      session.inInstance = true
      session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
      session.active = true
      session.Dispatch("CHALLENGE_MODE_START")
      session.Advance(2)
      LeaveDungeon(session)
      Assert.True(IsShown(button), "outside without a readable key: the button shows")
      session.inInstance = true
      session.active = true
      session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
      session.Advance(1)
      session.inInstance = false
      session.active = false
      session.Dispatch("ZONE_CHANGED_NEW_AREA")
      session.Advance(1)
      Assert.True(IsShown(button), "walking out again arms it again")
      session.inInstance = true
      session.active = true
      session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
      session.active = false
      session.Dispatch("CHALLENGE_MODE_COMPLETED")
      session.Advance(1)
      LeaveDungeon(session)
      Assert.True(IsShown(button), "the completed key still arms the reset")
    end, PrepareWorld())
  end)

  test("Instance reset button stays hidden for a non-leader and a secret leader value", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local button = FindResetButton(session)
      RunKey(session)
      LeaveDungeon(session)
      Assert.False(IsShown(button), "a non-leader never sees the button")

      session.leader = true
      session.Dispatch("PARTY_LEADER_CHANGED")
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.Advance(1)
      Assert.True(IsShown(button), "the lead handed over: the button shows")

      session.leader = SECRET
      session.Dispatch("PARTY_LEADER_CHANGED")
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.Advance(1)
      Assert.False(IsShown(button), "a secret leader value fails closed")
      Click(button)
      Assert.Equal(session.resetCalls, 0, "a click with a secret leader value never resets")
      for _, e in ipairs(session.errors) do
        io.stderr:write("DBG " .. tostring(e) .. "\n")
      end
    end, PrepareWorld({ leader = false }))
  end)

  test("Instance reset button stays hidden with the setting off and follows the toggle", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local button = FindResetButton(session)
      RunKey(session)
      LeaveDungeon(session)
      Assert.False(IsShown(button), "default-off setting: no button")

      session.globals.IsiLiveDB.instanceResetButtonEnabled = true
      session.addon.InstanceReset.ApplySettings()
      Assert.True(IsShown(button), "switching the setting on shows the pending reset at once")

      session.globals.IsiLiveDB.instanceResetButtonEnabled = false
      session.addon.InstanceReset.ApplySettings()
      Assert.False(IsShown(button), "switching it off hides the button at once")
    end, PrepareWorld({ buttonEnabled = false }))
  end)

  test("Instance reset pending mark expires after one hour", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local button = FindResetButton(session)
      RunKey(session)
      LeaveDungeon(session)
      Assert.True(IsShown(button), "fresh mark: the button shows")
      session.Advance(3590)
      Assert.True(IsShown(button), "just under one hour: still shown")
      session.Advance(20)
      Assert.False(IsShown(button), "after one hour the mark expires and the button hides on its own")
      Click(button)
      Assert.Equal(session.resetCalls, 0, "an expired mark never resets")
    end, PrepareWorld())
  end)

  test("Instance reset ignores keys outside the active season", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local button = FindResetButton(session)
      RunKey(session)
      LeaveDungeon(session)
      Assert.False(IsShown(button), "a key outside the season dungeon list arms nothing")
    end, PrepareWorld({ keyMapID = OFF_SEASON_MAP_ID }))
  end)

  test("Instance reset failure keeps the mark and a foreign reset is not announced", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local button = FindResetButton(session)
      RunKey(session)
      LeaveDungeon(session)
      Click(button)
      session.Dispatch("CHAT_MSG_SYSTEM", string.format(FAILED_FORMAT, DUNGEON_NAME))
      session.Dispatch("CHAT_MSG_SYSTEM", string.format(FAILED_OFFLINE_FORMAT, DUNGEON_NAME))
      session.Dispatch("CHAT_MSG_SYSTEM", SECRET)
      session.Advance(1)
      Assert.True(IsShown(button), "a failed reset keeps the mark for a retry")
      Assert.Equal(#session.chat, 0, "a failed reset announces nothing")

      -- Well past the own-click window: somebody else reset the instances.
      session.Advance(30)
      session.Dispatch("CHAT_MSG_SYSTEM", string.format(SUCCESS_FORMAT, DUNGEON_NAME))
      session.Advance(1)
      Assert.False(IsShown(button), "any confirmed reset clears the mark")
      Assert.Equal(#session.chat, 0, "a reset without an own click in the window is not announced")
    end, PrepareWorld())
  end)

  test("Instance reset announce stays silent with the announce setting off", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local button = FindResetButton(session)
      RunKey(session)
      LeaveDungeon(session)
      Click(button)
      session.Dispatch("CHAT_MSG_SYSTEM", string.format(SUCCESS_FORMAT, DUNGEON_NAME))
      session.Advance(1)
      Assert.False(IsShown(button), "the reset still clears the button")
      Assert.Equal(#session.chat, 0, "default-off announce: nothing in party chat")
    end, PrepareWorld({ announce = false }))
  end)

  test("Instance reset button hides again when the leader re-enters an instance", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local button = FindResetButton(session)
      RunKey(session)
      LeaveDungeon(session)
      Assert.True(IsShown(button), "outside: shown")
      session.inInstance = true
      session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
      session.Advance(1)
      Assert.False(IsShown(button), "inside an instance: hidden")
      session.inInstance = false
      session.Dispatch("ZONE_CHANGED_NEW_AREA")
      session.Advance(1)
      Assert.True(IsShown(button), "outside again within the hour: shown")
    end, PrepareWorld())
  end)

  test("Instance reset button splits the M+ toolbar row without overlap", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local button = FindResetButton(session)
      RunKey(session)
      LeaveDungeon(session)
      Assert.True(IsShown(button), "M+ layout: the button shows")

      local row = CollectToolbarRow(session, button)
      Assert.Equal(#row, 6, "the M+ toolbar row carries the five buttons plus the reset button")
      Assert.Equal(row[6].frame, button, "the reset button takes the last slot")
      Assert.Equal(row[1].x, 8, "the row keeps its left margin")
      Assert.Equal(row[6].x + row[6].width, 8 + 484, "the row keeps its 484 px width")
      for index = 2, #row do
        Assert.True(row[index].x >= row[index - 1].x + row[index - 1].width + 6, "toolbar buttons must not overlap")
      end

      session.Dispatch("CHAT_MSG_SYSTEM", string.format(SUCCESS_FORMAT, DUNGEON_NAME))
      session.Advance(1)
      local restored = CollectToolbarRow(session, button)
      Assert.Equal(#restored, 5, "after the reset the row is back to five buttons")
      Assert.Equal(restored[1].width, 92, "five buttons get their original 92 px width back")
      Assert.Equal(restored[5].x, 400, "the last of five buttons is back at its original slot")
    end, PrepareWorld())
  end)

  test("Instance reset button takes the next leader slot in the M layout", function()
    Stress.WithParty(ctx, Fixture, function(session)
      -- Rule 249 locks the window to M+; the kept M layout code is covered with
      -- the lock lifted.
      session.addon._RosterInternal.LAYOUT_LOCKED_TO_MPLUS = false
      session.runtime.rosterPanelController.SetLayoutMode("expanded")
      local button = FindResetButton(session)
      RunKey(session)
      LeaveDungeon(session)
      Assert.True(IsShown(button), "M layout: the button shows")
      local point, x, y = LastAnchor(button)
      Assert.Equal(point, "TOPRIGHT", "M anchors the leader column at the top right")
      Assert.Equal(x, -145, "the reset button shares the leader column")
      Assert.Equal(y, -210, "the reset button takes the slot below Mark-T/H")
      Assert.Equal(button._size[1], 120, "full-width leader button")
      Assert.Equal(button._size[2], 24, "full-height leader button")
      for _, frame in ipairs(session.frames) do
        local otherPoint, otherX, otherY = LastAnchor(frame)
        if frame ~= button and otherPoint == "TOPRIGHT" and otherX == -145 then
          Assert.True(otherY >= -180, "no other leader-column button reaches into the reset slot")
        end
      end
    end, PrepareWorld({ layout = "expanded" }))
  end)

  -- COMPONENT-ONLY: BuildSystemMessagePattern is a pure function with no event
  -- path; the flows above cover its use through CHAT_MSG_SYSTEM.
  test("Instance reset system message pattern escapes magic characters and positional placeholders", function()
    ctx.with_globals({}, function()
      local addon = ctx.load_modules({ "isiLive_instance_reset.lua" })
      local build = addon.InstanceReset.BuildSystemMessagePattern
      local pattern = build("%s has been reset.")
      Assert.Equal(("King's Rest has been reset."):match(pattern), "King's Rest", "plain placeholder captures")
      Assert.Nil(("King's Rest has been reset!"):match(pattern), "the dot matches literally")
      Assert.Nil(("King's Rest has been reset. Again"):match(pattern), "the pattern is anchored at the end")
      local positional = build("Instanz %1$s (100%) [ok]?")
      Assert.Equal(("Instanz Halle (100%) [ok]?"):match(positional), "Halle", "positional placeholder and magic chars")
      Assert.Nil(build(nil), "no pattern without a format string")
      Assert.Nil(build(""), "no pattern for an empty format string")
    end)
  end)
end
