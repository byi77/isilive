---@diagnostic disable: undefined-global, undefined-field

-- Demo preview of the defensives column (rule 270, tablet action C14). Every
-- flow boots the real factory, opens the tablet through the real slash
-- commands and clicks the real tablet button; the cells are read from the
-- real main frame, the tooltip from the real row hover frame. Only the client
-- surface is stubbed: class, spec and role, spell names and textures, and the
-- StatusBar values the client would draw.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

-- The simulation tablet and the DB schema are not part of the default fixture.
local FixtureWithTablet = {
  buildGlobals = Fixture.buildGlobals,
  moduleFiles = function()
    local files = Fixture.moduleFiles()
    table.insert(files, 1, "isiLive_simulation_tablet.lua")
    table.insert(files, 1, "isiLive_db_schema.lua")
    return files
  end,
}

local DEFENSIVE_SETTINGS = { "defensiveTrackerEnabled" }
local TEXTURE_BASE = 100000

local function DeepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for key, entry in pairs(value) do
    out[key] = DeepCopy(entry)
  end
  return out
end

-- Path of the first difference between two tables, or nil when they match.
local function FirstDifference(a, b, path)
  if type(a) ~= "table" or type(b) ~= "table" then
    if a == b then
      return nil
    end
    return path or "value"
  end
  for key, value in pairs(a) do
    local found = FirstDifference(value, b[key], (path or "db") .. "." .. tostring(key))
    if found then
      return found
    end
  end
  for key in pairs(b) do
    if a[key] == nil then
      return (path or "db") .. "." .. tostring(key)
    end
  end
  return nil
end

-- opts: { grouped = true, settings = true (all three switches on) }.
-- The player is a Holy Paladin in the open world (session.inDungeon moves it
-- into a dungeon); addon code reaches every stub through the closures.
local function Prepare(opts)
  opts = opts or {}
  return function(globals, session)
    session.grouped = opts.grouped == true
    session.player = { class = "PALADIN", specID = 65, role = "HEALER" }
    local db = globals.IsiLiveDB
    for _, key in ipairs(DEFENSIVE_SETTINGS) do
      db[key] = opts.settings == true
    end
    session.chat = 0
    -- the login card (rule 256) would write its seen ID during the demo
    db.whatsNewSeen = "voice_announcements"
    globals.SendChatMessage = function()
      session.chat = session.chat + 1
    end
    local instanceInfo = globals.GetInstanceInfo
    globals.GetInstanceInfo = function()
      if session.inDungeon or session.active then
        return instanceInfo()
      end
      return "Open world", "none", 0, "", 0, false, false, 1
    end
    local unitClass = globals.UnitClass
    globals.UnitClass = function(unit)
      if unit == "player" then
        return session.player.class, session.player.class, 2
      end
      return unitClass(unit)
    end
    globals.UnitIsUnit = function(a, b)
      return a == b
    end
    globals.GetSpecialization = function()
      return 1
    end
    globals.GetSpecializationInfo = function()
      return session.player.specID, "Spec", "desc", 0, session.player.role
    end
    globals.GetSpecializationRole = function()
      return session.player.role
    end
    globals.C_Spell.GetSpellName = function(spellID)
      return "Spell" .. tostring(spellID)
    end
    globals.C_Spell.GetSpellTexture = function(spellID)
      return TEXTURE_BASE + spellID
    end
    local createFrame = globals.CreateFrame
    globals.CreateFrame = function(...)
      local frame = createFrame(...)
      if (...) == "StatusBar" then
        function frame:SetMinMaxValues(minValue, maxValue)
          self._min, self._max = minValue, maxValue
        end
        function frame:SetValue(value)
          self._value = value
        end
      end
      -- Harness trade-off (as in isilive_test_scenarios_demo_reset_grip.lua):
      -- the stub font strings have no layout, the demo notices need a size.
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
end

local function Slash(session, command)
  session.globals.SlashCmdList.ISILIVE(command)
  session.Advance(1)
end

-- Clicks a tablet action through its tab and its real button.
local function ClickAction(session, id)
  local tablet = assert(session.runtime.simulationTabletController, "the tablet is open")
  local category
  for _, action in ipairs(tablet.actions) do
    if action.id == id then
      category = action.category or action.kind
    end
  end
  assert(category, "the tablet offers " .. id)
  local button
  if category == "reset" then
    button = tablet.resetButton
  else
    for _, tab in ipairs(tablet.tabButtons) do
      if tab._isiLiveCategory == category then
        tab:GetScript("OnClick")(tab)
      end
    end
    for _, candidate in ipairs(tablet.buttons) do
      if candidate._isiLiveAction and candidate._isiLiveAction.id == id then
        button = candidate
      end
    end
  end
  assert(button, "the tablet shows a button for " .. id)
  button:GetScript("OnClick")(button)
end

local function VisibleCells(session)
  local out = {}
  for _, child in ipairs(session.runtime.mainFrame._children or {}) do
    if type(child.slots) == "table" and child._shown then
      out[#out + 1] = child
    end
  end
  return out
end

-- The visible slots by what the player sees.
local function ReadSlots(session)
  local seen = { slots = {} }
  for _, cell in ipairs(VisibleCells(session)) do
    for _, slot in ipairs(cell.slots) do
      if slot._shown then
        seen.slots[#seen.slots + 1] = slot
        local kind = slot.state
        if kind == "cd" then
          kind = (slot.text._text or ""):find("m$") and "minutes" or "seconds"
        end
        seen[kind] = seen[kind] or slot
      end
    end
  end
  return seen
end

local function HasHeader(session, text)
  for _, fontString in ipairs(session.runtime.mainFrame._fontStrings or {}) do
    if fontString._text == text then
      return true
    end
  end
  return false
end

local function CountWidth(session, width)
  local count = 0
  for _, fontString in ipairs(session.runtime.mainFrame._fontStrings or {}) do
    if fontString._size and fontString._size[1] == width then
      count = count + 1
    end
  end
  return count
end

local function TooltipFor(session, unit)
  for _, child in ipairs(session.runtime.mainFrame._children) do
    if child.unit == unit and child._scripts and child._scripts.OnEnter then
      child._scripts.OnEnter(child)
    end
  end
  for _, child in ipairs(session.globals.UIParent._children or {}) do
    if child._isIsiLiveTooltip == true and child._isiLiveTooltipShown == true then
      local lines = {}
      for index = 1, child._isiLiveTooltipLineCount or 0 do
        local line = child._isiLiveTooltipLines[index]
        lines[#lines + 1] = line and line.GetText and line:GetText() or ""
      end
      return table.concat(lines, "\n")
    end
  end
  return ""
end

local function IsDemo(session)
  return session.runtime.testModeController ~= nil
    and session.addon._FactoryInternal.FactoryDemo.IsPreviewModeActive(session.runtime)
end

local function StartDefensivesDemo(session)
  Slash(session, "testall")
  ClickAction(session, "C14")
end

local function RegisterDisplayTests(test, ctx)
  local Assert = ctx.assert

  test("Simulation tablet C14 shows every defensives state of a running key without a key or group", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      Slash(session, "testall")
      Assert.Equal(#VisibleCells(session), 0, "the demo alone keeps the DPS column")
      Assert.True(HasHeader(session, "DPS"), "DPS header before C14")

      ClickAction(session, "C14")
      Assert.True(HasHeader(session, "Def"), "the DPS header reads Def")
      Assert.False(HasHeader(session, "DPS"), "no DPS header")
      Assert.True(CountWidth(session, 54) >= 2, "RIO shrinks to 54 px like in a key")
      Assert.False(session.addon.RuntimeMode.IsActiveChallenge(), "no key state is faked")

      local seen = ReadSlots(session)
      local ready = Assert.NotNil(seen.ready, "ready slot")
      Assert.Equal(ready.text._text, "", "ready: no text")
      Assert.Equal(Assert.NotNil(seen.seconds, "exact cooldown slot").text._text, "45", "cooldown in seconds")
      Assert.Equal(Assert.NotNil(seen.minutes, "minute cooldown slot").text._text, "3m", "from 100 s on in minutes")
      local active = Assert.NotNil(seen.active, "active slot")
      Assert.Equal(active.text._text, "12", "active: remaining buff seconds")
      Assert.True(active.border._shown == true, "active: blue border")
      local frozen = Assert.NotNil(seen.frozen, "frozen slot")
      Assert.True(frozen.clock._shown == true, "frozen: clock glyph")
      Assert.Equal(frozen.text._text, "", "frozen: no seconds")
      local estimate = Assert.NotNil(seen.estimate, "estimated slot")
      Assert.Equal(estimate.text._text, "~", "estimate: ~ mark")
      Assert.True(estimate.estimateBar._shown == true, "estimate: fill bar")

      for _, slot in ipairs(seen.slots) do
        Assert.NotNil(session.addon.DefensiveManifest.spells[slot.spellID], "demo spells come from the manifest")
      end
    end, Prepare())
  end)

  test("Defensives demo counts down and fills the estimate with plain values", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      -- The sensors must not take part in the demo.
      local sensors = session.addon.DefensiveSensors
      local sensorCalls = 0
      local getEstimate, attachActive = sensors.GetEstimate, sensors.AttachActive
      sensors.GetEstimate = function(...)
        sensorCalls = sensorCalls + 1
        return getEstimate(...)
      end
      sensors.AttachActive = function(...)
        sensorCalls = sensorCalls + 1
        return attachActive(...)
      end

      StartDefensivesDemo(session)
      local seen = ReadSlots(session)
      local bar = seen.estimate.estimateBar
      Assert.Equal(bar._min, 0, "plain minimum")
      Assert.Equal(bar._max, 1, "plain maximum")
      local share = bar._value
      local seconds, active, minutes = seen.seconds, seen.active, seen.minutes
      session.Advance(5)
      Assert.Equal(seconds.text._text, "40", "the cooldown counts down on the demo's own ticker")
      Assert.Equal(active.text._text, "7", "the buff counts down")
      Assert.True(bar._value < share, "the estimated fill shrinks")
      session.Advance(50)
      Assert.True(minutes.text._text:find("m$") ~= nil, "the minute cooldown stays in minutes")
      Assert.Equal(sensorCalls, 0, "no sensor is read or attached")
    end, Prepare({ settings = true }))
  end)

  test("Defensives demo tooltip names own, sync age, frozen and estimated sources", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      -- Damage dealer: tank (sync), healer without isiLive (estimate), mage (frozen).
      session.player = { class = "ROGUE", specID = 259, role = "DAMAGER" }
      StartDefensivesDemo(session)
      session.Advance(4)
      local own = TooltipFor(session, "player")
      Assert.True(own:find("Defensives / externals", 1, true) ~= nil, "own row: block header")
      Assert.True(own:find("Source: own client", 1, true) ~= nil, "own row: source")
      local sync = TooltipFor(session, "party1")
      Assert.True(sync:find("Source: isiLive sync, 0:04 ago", 1, true) ~= nil, "sync row: source with age")
      Assert.True(sync:find("active, 0:08 left", 1, true) ~= nil, "sync row: running buff")
      local estimate = TooltipFor(session, "party2")
      Assert.True(estimate:find("~ estimated, see the icon", 1, true) ~= nil, "estimated row: entries")
      Assert.True(estimate:find("Source: estimated (~)", 1, true) ~= nil, "estimated row: source")
      local frozen = TooltipFor(session, "party3")
      Assert.True(frozen:find("0:24 ago (locked during the key)", 1, true) ~= nil, "frozen row: age and note")
    end, Prepare())
  end)

  test("Defensives demo shows all states for every class and spec of the player", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      local roles = {
        [66] = "TANK",
        [73] = "TANK",
        [104] = "TANK",
        [250] = "TANK",
        [268] = "TANK",
        [581] = "TANK",
        [65] = "HEALER",
        [105] = "HEALER",
        [256] = "HEALER",
        [257] = "HEALER",
        [264] = "HEALER",
        [270] = "HEALER",
        [1468] = "HEALER",
      }
      local checked = 0
      for specID, spec in pairs(session.addon.SpecManifest.specs) do
        session.player = { class = spec.class, specID = specID, role = roles[specID] or "DAMAGER" }
        StartDefensivesDemo(session)
        local shown = {}
        -- A one-defensive class alternates between its cooldown and ready.
        for _ = 1, 15 do
          for kind in pairs(ReadSlots(session)) do
            shown[kind] = true
          end
          session.Advance(1)
        end
        for _, kind in ipairs({ "ready", "seconds", "minutes", "active", "frozen", "estimate" }) do
          Assert.True(shown[kind] == true, string.format("%s %d shows the %s state", spec.class, specID, kind))
        end
        session.runtime.ExitTestMode()
        session.Advance(1)
        checked = checked + 1
      end
      Assert.True(checked >= 39, "every spec was checked")
    end, Prepare())
  end)
end

local function RegisterIsolationTests(test, ctx)
  local Assert = ctx.assert

  test("Defensives demo writes no setting and sends nothing, whatever the three switches say", function()
    for _, settings in ipairs({ false, true }) do
      for _, grouped in ipairs({ false, true }) do
        Stress.WithParty(ctx, FixtureWithTablet, function(session)
          local db = session.globals.IsiLiveDB
          Slash(session, "testall")
          local before = DeepCopy(db)
          local messages = #session.messages
          local chat = session.chat
          ClickAction(session, "C14")
          Assert.True(#VisibleCells(session) >= 4, "shown independent of the switches")
          Assert.Nil(FirstDifference(before, db), "C14 writes no setting")
          session.Advance(10)
          for index = messages + 1, #session.messages do
            Assert.Nil(session.messages[index].payload:find("^DEF:"), "no demo state goes out")
          end
          Assert.Equal(session.chat, chat, "the defensives demo never chats")
          ClickAction(session, "C14")
          Assert.Nil(FirstDifference(before, db), "switching off writes no setting")
          for _, key in ipairs(DEFENSIVE_SETTINGS) do
            Assert.Equal(db[key], settings, key .. " stays as the user set it")
          end
        end, Prepare({ settings = settings, grouped = grouped }))
      end
    end
  end)

  test("Defensives demo click sends no addon message", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      Slash(session, "testall")
      local messages = #session.messages
      ClickAction(session, "C14")
      Assert.Equal(#session.messages, messages, "switching on sends nothing")
      ClickAction(session, "C14")
      Assert.Equal(#session.messages, messages, "switching off sends nothing")
    end, Prepare({ settings = true, grouped = true }))
  end)

  test("Defensives demo leaves the real store and sync state untouched", function()
    Stress.WithKey(ctx, FixtureWithTablet, function(session)
      session.Dispatch("CHAT_MSG_ADDON", "ISILIVE", "DEF:102342,0,90", "PARTY", "Peer4-Realm")
      local key = session.addon.Sync.NormalizePlayerKey("Peer4", "Realm")
      local store = session.addon.DefensiveStore
      Assert.Equal(store.GetForPlayer(key, session.now).source, "sync", "setup: real sync state")
      StartDefensivesDemo(session)
      for _, slot in ipairs(ReadSlots(session).slots) do
        Assert.True(slot.spellID ~= 102342, "the demo rows show demo data only")
      end
      local view = store.GetForPlayer(key, session.now)
      Assert.Equal(view.source, "sync", "the real record survives the demo")
      Assert.Equal(view.entries[1].spellID, 102342, "the real record is unchanged")
      Assert.Equal(#view.entries, 1, "nothing was added to the record")
      ClickAction(session, "C14")
      Assert.False(session.addon.RosterDefensiveCell.IsDemoActive(), "switching off drops the demo source")
      Assert.Equal(store.GetForPlayer(key, session.now).entries[1].spellID, 102342, "still the real record")
    end, Prepare({ settings = true, grouped = true }))
  end)
end

local function RegisterLifecycleTests(test, ctx)
  local Assert = ctx.assert

  local function ExpectCleared(session, how)
    Assert.False(session.addon.RosterDefensiveCell.IsDemoActive(), how .. ": demo source dropped")
    Assert.Nil(session.runtime._demoDefensivesTicker, how .. ": ticker stopped")
    Assert.Equal(#VisibleCells(session), 0, how .. ": no defensives cell")
    Assert.True(HasHeader(session, "DPS"), how .. ": DPS column back")
    Assert.Equal(CountWidth(session, 54), 0, how .. ": RIO back to full width")
  end

  local endings = {
    {
      "C14 again",
      function(session)
        ClickAction(session, "C14")
      end,
    },
    {
      "C5 before key start",
      function(session)
        ClickAction(session, "C5")
      end,
    },
    {
      "F3 reset",
      function(session)
        ClickAction(session, "F3")
      end,
    },
    {
      "demo toggle",
      function(session)
        session.runtime.ToggleDemoMode()
      end,
    },
    {
      "demo exit",
      function(session)
        session.runtime.ExitTestMode()
      end,
    },
    {
      "combat start",
      function(session)
        session.Dispatch("PLAYER_REGEN_DISABLED")
      end,
    },
    {
      "five idle minutes",
      function(session)
        for _ = 1, 320 do
          session.Advance(1)
        end
      end,
    },
    {
      "dungeon entry",
      function(session)
        session.inDungeon = true
        session.DispatchToFrames("PLAYER_ENTERING_WORLD", false, false)
      end,
    },
    {
      "real key start",
      function(session)
        session.DispatchToFrames("CHALLENGE_MODE_START")
      end,
    },
  }

  test("Defensives demo ends with every demo end and gives the DPS column back", function()
    for _, ending in ipairs(endings) do
      Stress.WithParty(ctx, FixtureWithTablet, function(session)
        StartDefensivesDemo(session)
        Assert.True(#VisibleCells(session) >= 4, ending[1] .. ": setup")
        ending[2](session)
        session.Advance(1)
        ExpectCleared(session, ending[1])
      end, Prepare())
    end
  end)

  test("Simulation tablet C14 starts the demo itself and respects its gates", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      Slash(session, "sim")
      Assert.False(IsDemo(session), "the tablet alone starts no demo")
      ClickAction(session, "C14")
      Assert.True(IsDemo(session), "C14 starts the demo")
      Assert.True(#VisibleCells(session) >= 4, "and shows the cells")
      session.runtime.ExitTestMode()
      session.Advance(1)
      ExpectCleared(session, "demo exit")
    end, Prepare())

    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      Slash(session, "sim")
      session.combat = true
      ClickAction(session, "C14")
      Assert.False(IsDemo(session), "no demo in combat")
      Assert.False(session.addon.RosterDefensiveCell.IsDemoActive(), "no defensives demo in combat")
    end, Prepare())
  end)

  test("Defensives demo works from a hidden main window, solo and in a group", function()
    for _, grouped in ipairs({ false, true }) do
      for _, viaTablet in ipairs({ false, true }) do
        Stress.WithParty(ctx, FixtureWithTablet, function(session)
          session.runtime.SetMainFrameVisible(false)
          session.Advance(1)
          Assert.False(session.runtime.mainFrame:IsShown(), "setup: hidden main window")
          Slash(session, viaTablet and "sim" or "testall")
          ClickAction(session, "C14")
          session.Advance(2)
          Assert.True(IsDemo(session), "the demo keeps running")
          Assert.Equal(session.runtime.GetRoster().party1.isDemoEntry, true, "the dummy roster is not replaced")
          Assert.True(ReadSlots(session).minutes ~= nil, "the dummy members carry their defensives")
        end, Prepare({ grouped = grouped }))
      end
    end
  end)

  test("Demo ends on a dungeon entry through the real world-entry event", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      Slash(session, "testall")
      session.DispatchToFrames("PLAYER_ENTERING_WORLD", false, false)
      Assert.True(IsDemo(session), "a loading screen in the open world keeps the demo")
      session.inDungeon = true
      session.DispatchToFrames("PLAYER_ENTERING_WORLD", false, false)
      Assert.False(IsDemo(session), "the dungeon entry ends the demo")
      Assert.True(session.runtime.mainFrame:IsShown(), "the main window stays open")
    end, Prepare())
  end)

  test("Dungeon entry from the demo runs the whole world-entry handler", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
      Slash(session, "testall")
      Assert.True(IsDemo(session), "setup: demo in the open world")
      session.Advance(2)
      session.inDungeon = true
      local sentBefore = #session.messages
      session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
      Assert.False(IsDemo(session), "the gated dispatcher ends the demo")
      local kickStates = 0
      for index = sentBefore + 1, #session.messages do
        if tostring(session.messages[index].payload):find("^KICK:") then
          kickStates = kickStates + 1
        end
      end
      Assert.True(kickStates >= 1, "the entry sends the own kick state")

      -- Only a recorded entry keeps the next world entry in the same dungeon
      -- from counting as a new one, which would open the window again.
      session.runtime.SetMainFrameVisible(false)
      session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
      Assert.False(session.runtime.mainFrame:IsShown(), "the entry from the demo was recorded")
    end, Prepare({ grouped = true }))
  end)

  test("Demo lets no world entry through in the open world or in combat", function()
    for _, case in ipairs({ { name = "open world" }, { name = "combat", dungeon = true, combat = true } }) do
      Stress.WithParty(ctx, FixtureWithTablet, function(session)
        Slash(session, "testall")
        session.Advance(2)
        session.inDungeon = case.dungeon
        session.combat = case.combat
        local roster = session.runtime.GetRoster()
        local sentBefore = #session.messages
        session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
        Assert.True(IsDemo(session), case.name .. ": the demo stays")
        Assert.Equal(session.runtime.GetRoster(), roster, case.name .. ": the dummy roster stays")
        Assert.Equal(#session.messages, sentBefore, case.name .. ": the handler does not run on demo data")
      end, Prepare({ grouped = true }))
    end
  end)

  test("Leaving a dungeon ends the demo and the next entry counts as new", function()
    Stress.WithParty(ctx, FixtureWithTablet, function(session)
      session.inDungeon = true
      session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
      Slash(session, "testall")
      Assert.True(IsDemo(session), "setup: demo inside the dungeon")
      session.inDungeon = false
      session.combat = true
      session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
      Assert.True(IsDemo(session), "an exit in combat stays held back")
      session.combat = false
      session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
      Assert.False(IsDemo(session), "leaving the dungeon ends the demo")
      Assert.True(session.runtime.mainFrame:IsShown(), "the main window stays open")

      Slash(session, "testall")
      session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
      Assert.True(IsDemo(session), "the recorded exit leaves a later demo in the open world running")
      session.runtime.ExitTestMode()

      session.runtime.SetMainFrameVisible(false)
      session.inDungeon = true
      session.Dispatch("PLAYER_ENTERING_WORLD", false, false)
      Assert.True(session.runtime.mainFrame:IsShown(), "the next entry opens the window again")
    end, Prepare({ grouped = true }))
  end)

  -- Boots like the client: SavedVariables are nil while the files run and
  -- come back before ADDON_LOADED.
  local function BootFromSavedVariables(saved, callback)
    local globals, session = Stress.BuildGlobals(FixtureWithTablet.buildGlobals)
    Prepare({ settings = saved.defensiveTrackerEnabled })(globals, session)
    for key, value in pairs(saved) do
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
      Assert.Equal(#session.errors, 0, "protected dispatch must report zero errors")
    end)
  end

  test("Defensives demo leaves nothing behind after a reload", function()
    local saved
    BootFromSavedVariables({ defensiveTrackerEnabled = true }, function(session, db)
      StartDefensivesDemo(session)
      Assert.True(#VisibleCells(session) >= 4, "setup: the demo runs")
      saved = DeepCopy(db)
    end)
    BootFromSavedVariables(saved, function(session, db)
      Assert.False(session.addon.RosterDefensiveCell.IsDemoActive(), "no demo source after the reload")
      Assert.Equal(#VisibleCells(session), 0, "no cell outside a key after the reload")
      Assert.Nil(session.runtime._demoDefensivesTicker, "no demo ticker after the reload")
      Assert.Nil(db.demoFeatureSnapshot, "the demo snapshot is consumed")
      for _, key in ipairs(DEFENSIVE_SETTINGS) do
        Assert.True(db[key] == true, key .. " keeps the user's value")
      end
    end)
  end)

  test("Defensives demo tablet texts exist in all five languages", function()
    local addon = ctx.load_modules({ "isiLive_texts.lua" })
    local tables = addon.Texts.GetLocaleTables()
    for _, tag in ipairs({ "enUS", "deDE", "frFR", "ruRU", "trTR" }) do
      for _, key in ipairs({ "SIM_ACTION_C14_TITLE", "SIM_ACTION_C14_DESC" }) do
        Assert.True(type(tables[tag][key]) == "string" and tables[tag][key] ~= "", tag .. " " .. key)
      end
    end
  end)
end

return function(test, ctx)
  RegisterDisplayTests(test, ctx)
  RegisterIsolationTests(test, ctx)
  RegisterLifecycleTests(test, ctx)
end
