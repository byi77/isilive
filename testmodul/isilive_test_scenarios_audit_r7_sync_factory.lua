---@diagnostic disable: undefined-global
-- Audit round 7, sync + factory findings: LibKeystone self-echo, priest
-- self-PI broadcast, simulation tablet leaks, minimap angle restore, resetui
-- opacity path, the deferred demo cooldown write and the language tooltip
-- locale. Every test boots the real factory and pumps events through the real
-- gated dispatcher or the client-style frame delivery
-- (testmodul/isilive_test_mplus_stress_helpers.lua).
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

-- The shared fixture list leaves out the schema and the tablet module; both
-- are loaded here so the real ADDON_LOADED sanitize pass and the real tablet
-- controller run.
local FixtureWithTablet = {
  buildGlobals = Fixture.buildGlobals,
  moduleFiles = function()
    local files = Fixture.moduleFiles()
    table.insert(files, 1, "isiLive_simulation_tablet.lua")
    table.insert(files, 1, "isiLive_db_schema.lua")
    return files
  end,
}

-- Harness trade-off: the stub font strings have no layout, so the demo center
-- notices get a fixed text height to size their frame.
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

-- WoW runs Lua 5.1, which has math.atan2; the 5.3+ test interpreter folded it
-- into math.atan.
local function WithAtan2(fn)
  local previous = rawget(math, "atan2")
  rawset(math, "atan2", previous or function(y, x)
    -- Only reached on Lua 5.3+, where math.atan takes (y, x).
    ---@diagnostic disable-next-line: redundant-parameter
    -- rawget: LuaLS checks against the 5.1 signature, where atan takes one argument.
    return rawget(math, "atan")(y, x)
  end)
  local ok, err = pcall(fn)
  rawset(math, "atan2", previous)
  if not ok then
    error(err, 0)
  end
end

local SYNC_PREFIX = "ISILIVE"
local LIBKS_PREFIX = "LibKS"
local OWN_KEY_MAP_ID = 2662
local OWN_KEY_LEVEL = 12

-- Boots the real factory the way the client does: SavedVariables are nil
-- while the addon files run and are restored before ADDON_LOADED.
local function BootFromSavedVariables(ctx, prepare, callback)
  local globals, session = Stress.BuildGlobals(FixtureWithTablet.buildGlobals)
  local savedDB = globals.IsiLiveDB
  if type(prepare) == "function" then
    prepare(globals, session, savedDB)
  end
  ctx.with_globals(globals, function()
    _G.IsiLiveDB = nil
    local addon = ctx.load_modules(FixtureWithTablet.moduleFiles())
    local runtime = addon.Factory.InitializeAddon("isiLive", addon, { returnContext = true })
    session.addon, session.runtime, session.globals = addon, runtime, globals
    local gated = runtime.eventFrame:GetScript("OnEvent")
    function session.Dispatch(event, ...)
      gated(runtime.eventFrame, event, ...)
    end
    _G.IsiLiveDB = savedDB
    session.Dispatch("ADDON_LOADED", "isiLive")
    -- The minimap button listens for PLAYER_LOGIN on its own frame, so the
    -- login goes to every registered frame like the client delivers it.
    session.DispatchToFrames("PLAYER_LOGIN")
    session.Dispatch("GROUP_ROSTER_UPDATE")
    session.Advance(5)
    callback(session, savedDB)
    ctx.assert.Equal(#session.errors, 0, "protected dispatch must report zero errors throughout the workload")
  end)
end

local function FindMinimapButton(session)
  for _, frame in ipairs(session.frames) do
    if frame:GetParent() == session.globals.Minimap and frame._size[1] == 28 and frame._size[2] == 28 then
      return frame
    end
  end
  return nil
end

-- Last CENTER anchor offset of the minimap button, converted back to degrees.
local function ButtonAngle(button)
  local point = button._points[#button._points]
  local x, y = point[4], point[5]
  -- Lua 5.1 (CI, game client) ignores a second argument to math.atan.
  local atan2 = rawget(math, "atan2") or math.atan
  return math.deg(atan2(y, x)) % 360, x, y
end

local function SelfRow(session)
  return session.runtime.GetRoster().player
end

local function CountPayloads(session, pattern, fromIndex)
  local count = 0
  for index = fromIndex or 1, #session.messages do
    local message = session.messages[index]
    if message.prefix == SYNC_PREFIX and tostring(message.payload):find(pattern) then
      count = count + 1
    end
  end
  return count
end

local function TabletActions(session)
  local actions = session.runtime._simulationTabletActions
  local byId = {}
  for _, action in ipairs(type(actions) == "table" and actions or {}) do
    byId[action.id] = action
  end
  return byId
end

local function OwnKeystone(globals)
  globals.C_MythicPlus.GetOwnedKeystoneChallengeMapID = function()
    return OWN_KEY_MAP_ID
  end
  globals.C_MythicPlus.GetOwnedKeystoneLevel = function()
    return OWN_KEY_LEVEL
  end
end

return function(test, ctx)
  local Assert = ctx.assert

  test("R7 L-6 a LibKeystone answer from the own client cannot wipe the own key row", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      local row = Assert.NotNil(SelfRow(session), "the real roster must carry the player row")
      Assert.Equal(row.keyMapID, OWN_KEY_MAP_ID, "the local key scan must own the player's key")
      Assert.Equal(row.keyLevel, OWN_KEY_LEVEL, "the local key scan must own the player's key level")
      -- Another addon embedding LibKeystone in this client answers for the
      -- player with no key; the server echoes it back with the own name.
      -- No roster update follows: the next one would re-scan the own key and
      -- hide the wipe until then.
      session.Dispatch("CHAT_MSG_ADDON", LIBKS_PREFIX, "0,0,2500", "PARTY", "Tester-Realm")
      session.Advance(5)
      row = Assert.NotNil(SelfRow(session), "the player row must survive the echo")
      Assert.Equal(row.keyMapID, OWN_KEY_MAP_ID, "the own LibKeystone echo must not clear the key map")
      Assert.Equal(row.keyLevel, OWN_KEY_LEVEL, "the own LibKeystone echo must not clear the key level")
      local cached = session.addon.Sync.GetPlayerKeyInfo("Tester", "Realm")
      Assert.Equal(
        cached and cached.mapID,
        OWN_KEY_MAP_ID,
        "the own LibKeystone echo must not clear the local key in the shared cache"
      )

      -- A peer's LibKeystone payload still lands.
      session.Dispatch("CHAT_MSG_ADDON", LIBKS_PREFIX, "15,2662,3100", "PARTY", "Peer1-Realm")
      local peerKey = Assert.NotNil(session.addon.Sync.GetPlayerKeyInfo("Peer1", "Realm"), "peer key must sync")
      Assert.Equal(peerKey.level, 15, "the peer LibKeystone key must be stored")
    end, OwnKeystone)
  end)

  test("R7 G-2 a priest's self Power Infusion is broadcast to the party", function()
    local spellID
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      spellID = session.addon.SpellManifest.powerInfusion
      local first = #session.messages + 1
      session.piActive = true
      session.Dispatch("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 77 } })
      session.Advance(1)
      Assert.Equal(#session.errors, 0, "the self PI scan must not crash the dispatcher")
      Assert.Equal(CountPayloads(session, "^PI:", first), 1, "a self-cast PI must go out to the party once")
      session.Dispatch("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 77 } })
      session.Advance(1)
      Assert.Equal(CountPayloads(session, "^PI:", first), 1, "the same buff must not be broadcast twice")
    end, function(globals, session)
      globals.UnitClass = function(unit)
        if unit == "player" then
          return "Priest", "PRIEST", 5
        end
        return "Mage", "MAGE", 8
      end
      globals.C_UnitAuras.GetPlayerAuraBySpellID = function(id)
        if session.piActive and id == spellID then
          return { spellId = id, sourceUnit = "player", auraInstanceID = 77 }
        end
        return nil
      end
    end)
  end)

  test("R7 F-1 closing the simulation tablet outside test mode restores the live state", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      local db = session.globals.IsiLiveDB
      db.statsBoxEnabled = false
      db.mobNameplateEnabled = false
      local runtimeState = session.runtime.runtimeState
      runtimeState.SetLatestQueueState("Real Dungeon", 1234, 5678, 9999)
      local timer, nameplate = session.addon.MplusTimer, session.addon.MobNameplate

      session.globals.SlashCmdList.ISILIVE("sim")
      local tablet = Assert.NotNil(session.runtime.simulationTabletController, "/isilive sim must open the tablet")
      Assert.True(tablet.IsShown(), "the tablet must be visible")
      local actions = TabletActions(session)
      actions.C1.run()
      actions.C4.run()
      actions.B1.run()
      session.Advance(1)
      Assert.True(timer.IsRunning(), "C1 must show the demo timer")
      Assert.True(nameplate.IsTestMode(), "C4 must switch the nameplates into test mode")
      Assert.True(db.statsBoxEnabled, "B1 must preview the stats box")
      Assert.True(session.runtime.cdTrackerController.HasDemoData(), "C1 must show demo cooldowns")
      local _, _, _, demoMapID = runtimeState.GetLatestQueueState()
      Assert.True(demoMapID ~= 9999, "C1 points the queue target at the demo dungeon")

      session.globals.SlashCmdList.ISILIVE("sim")
      Assert.False(tablet.IsShown(), "the second /isilive sim must close the tablet")
      session.Advance(1)
      Assert.False(timer.IsRunning(), "closing the tablet must drop the demo timer")
      Assert.False(nameplate.IsTestMode(), "closing the tablet must end the nameplate test mode")
      Assert.False(session.runtime.cdTrackerController.HasDemoData(), "closing the tablet must drop demo cooldowns")
      Assert.Equal(db.statsBoxEnabled, false, "closing the tablet must restore the B1 settings")
      Assert.Equal(db.mobNameplateEnabled, false, "closing the tablet must restore the nameplate setting")
      Assert.Nil(db.demoFeatureSnapshot, "the persisted demo snapshot must be gone")
      local name, activityID, teleportSpellID, mapID = runtimeState.GetLatestQueueState()
      Assert.Equal(name, "Real Dungeon", "the real queue target name must come back")
      Assert.Equal(activityID, 1234, "the real queue activity must come back")
      Assert.Equal(teleportSpellID, 5678, "the real queue teleport must come back")
      Assert.Equal(mapID, 9999, "the real queue map must come back")

      -- An untouched tablet leaves live state alone when it closes.
      runtimeState.SetLatestQueueState("Next Dungeon", 4321, nil, 8888)
      session.globals.SlashCmdList.ISILIVE("sim")
      session.globals.SlashCmdList.ISILIVE("sim")
      local _, _, _, untouchedMapID = runtimeState.GetLatestQueueState()
      Assert.Equal(untouchedMapID, 8888, "opening and closing an unused tablet keeps the queue target")
    end, MeasurableFontStrings)
  end)

  test("R7 F-1 the tablet reset clears every tablet action and keeps the tablet open", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      local runtimeState = session.runtime.runtimeState
      runtimeState.ClearLatestQueueTarget({ keepActiveJoinedKey = true })
      session.globals.SlashCmdList.ISILIVE("sim")
      local tablet = session.runtime.simulationTabletController
      local actions = TabletActions(session)
      actions.C5.run()
      actions.C1.run()
      actions.C4.run()
      session.Advance(1)
      Assert.True(session.addon.MobNameplate.IsTestMode(), "C4 must switch the nameplates into test mode")
      actions.F3.run()
      session.Advance(1)
      Assert.True(tablet.IsShown(), "F3 keeps the tablet open")
      Assert.False(session.addon.MplusTimer.IsRunning(), "F3 must drop the demo timer")
      Assert.False(session.addon.MobNameplate.IsTestMode(), "F3 must end the nameplate test mode")
      Assert.False(session.runtime.cdTrackerController.HasDemoData(), "F3 must drop demo cooldowns")
      local name, _, _, mapID = runtimeState.GetLatestQueueState()
      Assert.Nil(name, "F3 must drop the demo queue target name")
      Assert.Nil(mapID, "F3 must drop the demo queue target map")
    end)
  end)

  test("R7 F-1 a real key start is not masked by a tablet's demo timer", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      session.globals.SlashCmdList.ISILIVE("sim")
      TabletActions(session).C1.run()
      Assert.Equal(session.addon.MplusTimer.GetTimerData().timer, 780, "C1 shows the simulated run")
      session.active = true
      session.DispatchToFrames("CHALLENGE_MODE_START")
      session.Advance(5)
      local data = session.addon.MplusTimer.GetTimerData()
      Assert.True(data.running, "the real key must run")
      Assert.True(data.timer ~= 780, "the real key timer must replace the simulated run")
      Assert.Equal(data.deaths, 0, "the real key must not carry the demo deaths")
    end)
  end)

  test("R7 F-4 ending the demo timer before the deferred demo cooldowns land leaves none behind", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      session.globals.SlashCmdList.ISILIVE("sim")
      local actions = TabletActions(session)
      actions.C1.run()
      -- F3 runs before the 0.2 s cooldown-tracker write of C1 is due.
      actions.F3.run()
      session.Advance(1)
      Assert.False(
        session.runtime.cdTrackerController.HasDemoData(),
        "the deferred cooldown write must not outlive the demo timer"
      )
      actions.C1.run()
      session.Advance(1)
      Assert.True(session.runtime.cdTrackerController.HasDemoData(), "a demo timer that stays shows demo cooldowns")
    end)
  end)

  test("R7 F-2 the minimap button returns to the saved angle after a reload", function()
    BootFromSavedVariables(ctx, function(_, _, savedDB)
      savedDB.showMinimapButton = true
      savedDB.minimapAngle = 90
    end, function(session)
      local button = Assert.NotNil(FindMinimapButton(session), "the minimap button must exist")
      local angle = ButtonAngle(button)
      Assert.True(math.abs(angle - 90) < 0.01, "the button must sit at the saved angle, got " .. tostring(angle))
    end)
  end)

  test("R7 F-2 an angle below the minimap axis survives the save and the next load", function()
    BootFromSavedVariables(ctx, function(_, _, savedDB)
      savedDB.showMinimapButton = true
      -- Saved by an older build straight from atan2.
      savedDB.minimapAngle = -90
    end, function(session, savedDB)
      Assert.Equal(savedDB.minimapAngle, 270, "the schema must fold a negative angle instead of clamping it to 0")
      local button = Assert.NotNil(FindMinimapButton(session), "the minimap button must exist")
      local angle = ButtonAngle(button)
      Assert.True(math.abs(angle - 270) < 0.01, "the button must sit below the minimap, got " .. tostring(angle))

      -- Dragging below the horizontal axis stores the angle in [0, 360).
      session.globals.GetCursorPosition = function()
        return 0, -50
      end
      WithAtan2(function()
        button:GetScript("OnDragStart")(button)
        button:GetScript("OnDragStop")(button)
      end)
      Assert.True(
        savedDB.minimapAngle >= 0 and savedDB.minimapAngle < 360,
        "the dragged angle must be stored in [0, 360), got " .. tostring(savedDB.minimapAngle)
      )
      Assert.True(math.abs(savedDB.minimapAngle - 270) < 0.01, "straight below the minimap is 270 degrees")
    end)
  end)

  test("R7 F-3 /isilive resetui goes through the shared opacity path", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      local uiCommon = session.addon.UICommon
      local mainFrame = session.runtime.mainFrame
      Assert.True(mainFrame._isiLiveRoundedFill == true, "Modern draws the main frame's rounded fill")
      session.globals.IsiLiveDB.bgAlpha = 0.9
      mainFrame:SetBackdropColor(0, 0, 0, 0)
      local painted = {}
      local surface = {
        SetColorTexture = function(_, r, g, b, a)
          painted[#painted + 1] = { r, g, b, a }
        end,
      }
      Assert.True(
        uiCommon.RegisterBackgroundAlphaSurface(surface, "SetColorTexture", { 0.1, 0.2, 0.3 }, 0.5),
        "the probe surface must register"
      )
      session.globals.SlashCmdList.ISILIVE("resetui")
      local last = Assert.NotNil(painted[#painted], "resetui must repaint the registered surfaces")
      Assert.Equal(last[4], uiCommon.DEFAULT_BG_ALPHA * 0.5, "the surface must get the default opacity")
      Assert.Equal(mainFrame._backdropColor[4], 0, "the rounded fill's backdrop must stay transparent")
      Assert.Equal(uiCommon.Colors.BG_PRIMARY[4], uiCommon.DEFAULT_BG_ALPHA, "the palette takes the default")
    end)
  end)

  test("R7 F-6 language tooltip names follow the isiLive language, not the client", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      local Locale = session.addon.Locale
      session.globals.IsiLiveDB.locale = "deDE"
      local markup = session.runtime.GetLanguageTooltipMarkup("FR")
      Assert.Equal(markup, Locale.GetLanguageTooltipMarkup("FR", "deDE"), "the German UI names the language in German")
      Assert.True(
        markup ~= Locale.GetLanguageTooltipMarkup("FR", "enUS"),
        "the English client language must not decide the name"
      )
      session.globals.IsiLiveDB.locale = "enUS"
      Assert.Equal(
        session.runtime.GetLanguageTooltipMarkup("FR"),
        Locale.GetLanguageTooltipMarkup("FR", "enUS"),
        "switching the UI language switches the cached name"
      )
    end)
  end)
end
