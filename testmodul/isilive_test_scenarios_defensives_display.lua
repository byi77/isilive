---@diagnostic disable: undefined-global, undefined-field
-- Defensives stage 2 (rules 268, 269): the estimate sensors, the roster cell
-- and the tooltip block. Every flow boots the real factory through the stress
-- fixture and runs the production tickers; the cells are read from the real
-- main frame (children with slots), the tooltip from the real row hover
-- frame. Only the client surface is stubbed: Blizzard's AuraContainer
-- (secure filtering and layout cannot run outside the client, so the stub
-- answers IsMouseOver from session.auraUp or a strict secret), StatusBar
-- value recording, C_CurveUtil.EvaluateColorValueFromBoolean, C_XMLUtil,
-- the cursor, inspect specs, spell names / textures and the chat lockdown.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local TEMPLATE = "CustomAuraContainerTemplate"
local PAIN_SUPPRESSION = 33206
local RALLYING_CRY_AURA = 97463
local SHIELD_WALL = 871
local ICE_BLOCK = 45438
local IRONBARK = 102342
local BLESSING_OF_SACRIFICE = 6940

-- party1 Prot Warrior, party2 Paladin (spec not inspected), party3 Mage,
-- party4 Resto Druid; the player is a Disc Priest.
local CLASSES = {
  player = { "Priest", "PRIEST", 5 },
  party1 = { "Warrior", "WARRIOR", 1 },
  party2 = { "Paladin", "PALADIN", 2 },
  party3 = { "Mage", "MAGE", 8 },
  party4 = { "Druid", "DRUID", 11 },
}
local SPECS = { party1 = 73, party3 = 64, party4 = 105 }

local function IsSecret(session, value)
  return session.secret ~= nil and rawequal(value, session.secret)
end

-- opts: { tracker, sync, estimate, design, combat, template = false, secret }
local function Prepare(opts)
  opts = opts or {}
  return function(globals, session)
    local db = globals.IsiLiveDB
    db.defensiveTrackerEnabled = opts.tracker ~= false
    db.defensiveSyncEnabled = opts.sync == true
    db.defensiveEstimateEnabled = opts.estimate == true
    db.uiDesign = opts.design
    session.combat = opts.combat == true
    session.lockdown = false
    session.secret = opts.secret
    session.auraUp = {}
    session.cooldowns = {}
    session.containers = {}
    session.bars = {}
    session.createdInCombat = 0
    session.refilteredInCombat = 0
    session.cursor = { 300, 200 }
    globals.UIParent:SetSize(1920, 1080)
    globals.UIParent:SetScale(1)
    globals.UnitClass = function(unit)
      local class = CLASSES[unit]
      if class then
        return class[1], class[2], class[3]
      end
    end
    globals.GetInspectSpecialization = function(unit)
      return SPECS[unit] or 0
    end
    globals.C_SpellBook = {
      IsSpellKnown = function(spellID)
        return spellID == PAIN_SUPPRESSION
      end,
    }
    globals.C_Secrets = {
      ShouldSpellCooldownBeSecret = function()
        return false
      end,
    }
    globals.C_ChatInfo.InChatMessagingLockdown = function()
      return session.lockdown
    end
    local baseCooldown = globals.C_Spell.GetSpellCooldown
    globals.C_Spell.GetSpellCooldown = function(spellID)
      local cooldown = session.cooldowns[spellID]
      if cooldown then
        return { startTime = cooldown.start, duration = cooldown.duration, isEnabled = true, modRate = 1 }
      end
      return baseCooldown(spellID)
    end
    globals.C_Spell.GetSpellCharges = function()
      return nil
    end
    globals.C_Spell.GetSpellName = function(spellID)
      return "Spell" .. tostring(spellID)
    end
    globals.C_Spell.GetSpellTexture = function(spellID)
      return 100000 + spellID
    end
    globals.C_UnitAuras.GetPlayerAuraBySpellID = function()
      return nil
    end
    globals.GetCursorPosition = function()
      return session.cursor[1], session.cursor[2]
    end
    globals.C_XMLUtil = {
      GetTemplateInfo = function(name)
        if opts.template == false then
          return nil
        end
        return name == TEMPLATE and { type = "AuraContainer" } or nil
      end,
    }
    globals.C_CurveUtil = globals.C_CurveUtil or {}
    globals.C_CurveUtil.EvaluateColorValueFromBoolean = function(condition, ifTrue, ifFalse)
      if IsSecret(session, condition) or IsSecret(session, ifTrue) or IsSecret(session, ifFalse) then
        return session.secret
      end
      if condition == true then
        return ifTrue
      end
      return ifFalse
    end
    local createFrame = globals.CreateFrame
    globals.CreateFrame = function(frameType, name, parent, template, ...)
      local frame = createFrame(frameType, name, parent, template, ...)
      if frameType == "AuraContainer" then
        assert(template == TEMPLATE, "containers use Blizzard's template")
        if session.combat then
          session.createdInCombat = session.createdInCombat + 1
        end
        frame._groups = {}
        function frame:AddAuraGroup(key, filter, options)
          if opts.refuseGroups then
            error("test: aura group refused")
          end
          if session.combat then
            session.createdInCombat = session.createdInCombat + 1
          end
          self._groups[key] = { filter = filter, options = options }
          self._aura = next(options.candidateFilters.includeSpellIDs)
          if type(options.initializeFrame) == "function" then
            self._button = createFrame("Button", nil, self)
            options.initializeFrame(self._button)
          end
        end
        function frame:SetAuraGroupCandidateFilters(key, filters)
          assert(self._groups[key], "known group")
          if session.combat then
            session.refilteredInCombat = session.refilteredInCombat + 1
          end
          self._aura = next(filters.includeSpellIDs)
        end
        function frame:SetUnit(unit)
          self._unit = unit
        end
        function frame:SetEnabled(enabled)
          self._enabled = enabled
        end
        function frame:IsMouseOver(top, bottom)
          assert(top > 1000 and bottom < -1000, "the sensor reads with a huge vertical reach")
          if session.secret ~= nil then
            return session.secret
          end
          return session.auraUp[tostring(self._unit) .. ":" .. tostring(self._aura)] == true
        end
        session.containers[#session.containers + 1] = frame
      elseif frameType == "StatusBar" then
        function frame:SetMinMaxValues(minValue, maxValue)
          self._min, self._max = minValue, maxValue
        end
        function frame:SetValue(value)
          self._value = value
        end
        session.bars[#session.bars + 1] = frame
      end
      return frame
    end
    if type(opts.extra) == "function" then
      opts.extra(globals, session)
    end
  end
end

-- The mock client has no frame loop: play the OnUpdate scripts of the
-- created frames (drives the real run focus animation).
local function PumpFrames(session, seconds)
  local step = 0.05
  local elapsed = 0
  while elapsed < seconds do
    for index = 1, #session.frames do
      local frame = session.frames[index]
      local onUpdate = frame:GetScript("OnUpdate")
      if onUpdate then
        onUpdate(frame, step)
      end
    end
    session.Advance(step)
    elapsed = elapsed + step
  end
end

-- Every defensives cell of the real main frame (children carrying slots).
local function Cells(session)
  local out = {}
  for _, child in ipairs(session.runtime.mainFrame._children or {}) do
    if type(child.slots) == "table" then
      out[#out + 1] = child
    end
  end
  return out
end

local function VisibleCells(session)
  local out = {}
  for _, cell in ipairs(Cells(session)) do
    if cell._shown then
      out[#out + 1] = cell
    end
  end
  return out
end

local function FindSlot(session, spellID)
  for _, cell in ipairs(VisibleCells(session)) do
    for _, slot in ipairs(cell.slots) do
      if slot._shown and slot.spellID == spellID then
        return slot, cell
      end
    end
  end
  return nil
end

local function HeaderTexts(session)
  local texts = {}
  for _, fontString in ipairs(session.runtime.mainFrame._fontStrings or {}) do
    texts[fontString._text or ""] = (texts[fontString._text or ""] or 0) + 1
  end
  return texts
end

-- Font strings of the main frame with the given width (RIO header and rows).
local function CountWidth(session, width)
  local count = 0
  for _, fontString in ipairs(session.runtime.mainFrame._fontStrings or {}) do
    if fontString._size and fontString._size[1] == width then
      count = count + 1
    end
  end
  return count
end

local function Render(session)
  session.runtime.UpdateUI()
end

-- Lines of the shown roster tooltip (the real isiLive tooltip frame).
local function RosterTooltipLines(session)
  for _, child in ipairs(session.globals.UIParent._children or {}) do
    if child._isIsiLiveTooltip == true and child._isiLiveTooltipShown == true then
      local lines = {}
      for index = 1, child._isiLiveTooltipLineCount or 0 do
        local line = child._isiLiveTooltipLines[index]
        lines[#lines + 1] = line and line.GetText and line:GetText() or ""
      end
      return lines
    end
  end
  return {}
end

local function Receive(session, payload, sender)
  session.Dispatch("CHAT_MSG_ADDON", "ISILIVE", payload, "PARTY", sender)
end

local function SensorContainers(session)
  local out = {}
  for _, container in ipairs(session.containers) do
    if container._groups.isiLiveDefSensor then
      out[#out + 1] = container
    end
  end
  return out
end

local function EnabledSensors(session)
  local out = {}
  for _, container in ipairs(SensorContainers(session)) do
    if container._enabled == true then
      out[#out + 1] = container
    end
  end
  return out
end

local function SensorFor(session, unit, auraID)
  for _, container in ipairs(EnabledSensors(session)) do
    if container._unit == unit and container._aura == auraID then
      return container
    end
  end
  return nil
end

-- Remaining share the client would draw: (value - min) / (max - min), clamped.
local function FillShare(bar)
  local span = bar._max - bar._min
  local share = (bar._value - bar._min) / span
  return math.max(0, math.min(1, share))
end

local function RegisterCellTests(test, ctx)
  local Assert = ctx.assert

  local function RunCellPhase(design)
    Stress.WithKey(ctx, Fixture, function(session)
      session.Advance(2)
      Render(session)
      local headers = HeaderTexts(session)
      Assert.True((headers.Def or 0) >= 1, "the DPS header reads Def in the key")
      Assert.Nil(headers.DPS, "no DPS header in the key")
      local slot = FindSlot(session, PAIN_SUPPRESSION)
      Assert.NotNil(slot, "the own external fills a slot of the own row")
      Assert.Equal(slot.text._text, "", "ready: no text")
      Assert.True(CountWidth(session, 54) >= 2, "RIO header and rows shrink to 54 px in the key")
      Assert.Equal(CountWidth(session, 84), 0, "no 84 px RIO cell in the key")
      -- COMPONENT-ONLY: the "(+N)" strip is a pure text step of the render.
      local cell = session.addon.RosterDefensiveCell
      Assert.Equal(cell.ApplyRio({ rio = { SetWidth = function() end } }, "(+12)3120", true), "3120", "no delta")
      Assert.Equal(cell.ApplyRio({ rio = { SetWidth = function() end } }, "(+12)3120", false), "(+12)3120", "kept")

      -- Run focus (rule 248) hides the cell with the rest of the roster.
      session.runtime.rosterPanelController.SetLayoutMode("compact_main_horizontal")
      session.addon.RunFocus.SetTestMode(true)
      PumpFrames(session, 1)
      Assert.Equal(session.runtime.runFocusController.GetPhase(), "collapsed", "run focus collapsed")
      Render(session)
      Assert.Equal(#VisibleCells(session), 0, "the run focus hides the defensives cell")
      session.addon.RunFocus.SetTestMode(false)
      PumpFrames(session, 1)
      Assert.True(#VisibleCells(session) > 0, "and gives it back when it expands")

      session.active = false
      session.Dispatch("CHALLENGE_MODE_COMPLETED")
      session.Advance(2)
      Render(session)
      headers = HeaderTexts(session)
      Assert.True((headers.DPS or 0) >= 1, "after the key the DPS header is back")
      Assert.Equal(#VisibleCells(session), 0, "no defensives cell outside the key")
      Assert.Equal(CountWidth(session, 54), 0, "RIO is back to its full width")
    end, Prepare({ design = design }))
  end

  test("Defensives cell replaces the DPS column only in a running key (Modern)", function()
    RunCellPhase("modern")
  end)

  test("Defensives cell replaces the DPS column only in a running key (Classic)", function()
    RunCellPhase("classic")
  end)

  test("Defensives cell stays away with the tracker off", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.Advance(2)
      Render(session)
      Assert.Equal(#VisibleCells(session), 0, "no cell with the switch off")
      Assert.True((HeaderTexts(session).DPS or 0) >= 1, "the DPS column stays")
    end, Prepare({ tracker = false }))
  end)

  test("Defensives cell shows own, sync and frozen sync states with the clock glyph", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.cooldowns[PAIN_SUPPRESSION] = { start = session.now, duration = 180 }
      session.DispatchToFrames("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", PAIN_SUPPRESSION)
      session.Advance(1)
      Render(session)
      local own = FindSlot(session, PAIN_SUPPRESSION)
      Assert.Equal(own.text._text, "3m", "own cooldown from 100 s on in minutes")
      Assert.Equal(own.state, "cd", "own cooldown state")

      Receive(session, "DEF:102342,0,40", "Peer4-Realm")
      session.Advance(1)
      local peer = FindSlot(session, IRONBARK)
      Assert.NotNil(peer, "the synced external of party4 fills a slot")
      Assert.Equal(peer.text._text, "39", "exact seconds, counted down locally")
      Assert.False(peer.clock._shown == true, "no clock while the sync is live")

      session.lockdown = true
      session.Advance(2)
      peer = FindSlot(session, IRONBARK)
      Assert.Equal(peer.state, "frozen", "the own chat lockdown freezes the sync state")
      Assert.True(peer.clock._shown == true, "frozen: clock glyph instead of seconds")
      Assert.Equal(peer.text._text, "", "frozen: no seconds")
      Assert.Equal(FindSlot(session, PAIN_SUPPRESSION).state, "cd", "the own state keeps counting")
    end, Prepare({ sync = true }))
  end)

  test("Defensives tooltip lists every defensive with kind, state and the source age", function()
    Stress.WithKey(ctx, Fixture, function(session)
      Receive(session, "DEF:22812,1,0;102342,0,40", "Peer4-Realm")
      session.Advance(5)
      Render(session)
      local _, cell = FindSlot(session, IRONBARK)
      Assert.NotNil(cell, "the synced player has a cell")
      local hover
      for _, child in ipairs(session.runtime.mainFrame._children) do
        if child.unit == "party4" and child._scripts and child._scripts.OnEnter then
          hover = child
        end
      end
      hover = Assert.NotNil(hover, "the row hover frame of party4")
      hover._scripts.OnEnter(hover)
      local joined = table.concat(RosterTooltipLines(session), "\n")
      Assert.True(joined:find("Defensives / externals", 1, true) ~= nil, "block header")
      Assert.True(joined:find("Spell102342 |cff8a96a8(external)|r: cooldown 0:35", 1, true) ~= nil, "external")
      Assert.True(joined:find("Spell22812 |cff8a96a8(personal)|r: ready", 1, true) ~= nil, "personal, ready")
      Assert.True(joined:find("Source: isiLive sync, 0:05 ago", 1, true) ~= nil, "source with its age")
      Assert.True(
        joined:find("Defensives / externals", 1, true) < joined:find("Spell102342", 1, true),
        "the header comes first"
      )
    end, Prepare({ sync = true }))
  end)
end

local function RegisterSensorTests(test, ctx)
  local Assert = ctx.assert

  test("Defensive estimate builds sensors only out of combat, within the budget and not for isiLive users", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.Advance(3)
      Assert.Equal(#session.containers, 0, "no container is built in combat")
      session.combat = false
      session.Dispatch("PLAYER_REGEN_ENABLED")
      session.Advance(2)
      Render(session)
      Assert.Equal(session.createdInCombat, 0, "nothing was built in combat")
      -- party1 Prot: Rallying Cry + Shield Wall; party2 Paladin (no spec):
      -- Sacrifice + Protection; party3 Mage: Ice Block; party4 Resto: Ironbark
      -- + Barkskin.
      Assert.Equal(#EnabledSensors(session), 7, "two sensors per member at most, by class and spec")
      Assert.NotNil(SensorFor(session, "party1", RALLYING_CRY_AURA), "group cooldown first for the warrior")
      Assert.NotNil(SensorFor(session, "party1", SHIELD_WALL), "then the Prot-only Shield Wall")
      Assert.Nil(SensorFor(session, "party1", 118038), "no Arms-only spell for a Prot warrior")
      Assert.NotNil(SensorFor(session, "party2", BLESSING_OF_SACRIFICE), "class-wide spells without a spec")
      Assert.Nil(SensorFor(session, "party2", 31821), "no spec-bound spell without an inspected spec")
      local sensors = session.addon.DefensiveSensors
      Assert.True(sensors.GetContainerCount() <= sensors.LIMITS.maxContainers, "budget")
      Assert.True(sensors.GetContainerCount() < 60, "below the V1 frame budget")
      Assert.Equal(#VisibleCells(session), 5, "every row has a cell: own, four estimated")
      local slot = FindSlot(session, ICE_BLOCK)
      Assert.Equal(slot.text._text, "~", "estimated slots carry the ~ mark")
      Assert.Equal(slot.state, "estimate", "estimate state")
      local paladinHover
      for _, child in ipairs(session.runtime.mainFrame._children) do
        if child.unit == "party2" and child._scripts and child._scripts.OnEnter then
          paladinHover = child
        end
      end
      paladinHover._scripts.OnEnter(paladinHover)
      local joined = table.concat(RosterTooltipLines(session), "\n")
      Assert.True(joined:find("Spell6940 |cff8a96a8(external)|r: ~ estimated, see the icon", 1, true) ~= nil, "est.")
      Assert.True(joined:find("Spell642 |cff8a96a8(personal)|r: likely ready (not seen)", 1, true) ~= nil, "unseen")
      Assert.True(joined:find("Source: estimated (~)", 1, true) ~= nil, "estimated source")
      Assert.Nil(joined:find("Spell31821", 1, true), "no spec-bound spell without a spec")

      -- party4 turns out to run isiLive: its sensors go, the sync takes over.
      Receive(session, "DEF:102342,1,0", "Peer4-Realm")
      session.Advance(2)
      Assert.Nil(SensorFor(session, "party4", IRONBARK), "no sensor for an isiLive user")
      Assert.Equal(#sensors.GetEstimate(session.addon.Sync.NormalizePlayerKey("Peer4", "Realm")), 0, "no estimate")
      Assert.Equal(FindSlot(session, IRONBARK).text._text, "", "the synced slot shows the exact ready state")

      -- A spec change in combat only switches off, never re-filters.
      session.combat = true
      SPECS.party1 = 71
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.Advance(2)
      SPECS.party1 = 73
      Assert.Equal(session.createdInCombat, 0, "no container created in combat")
      Assert.Equal(session.refilteredInCombat, 0, "no container re-filtered in combat")
    end, Prepare({ estimate = true, sync = true, combat = true }))
  end)

  test("Defensive estimate stays off by default, without the client template and in a raid", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.Advance(3)
      Assert.Equal(#session.containers, 0, "default off: no sensor")
    end, Prepare({}))
    Stress.WithKey(ctx, Fixture, function(session)
      session.Advance(3)
      Assert.Equal(#session.containers, 0, "no template: no sensor (fail-closed)")
      Assert.False(session.addon.DefensiveSensors.IsSupported(), "unsupported client")
      local rows = session.addon.ApiHealth.Run()
      local found = false
      for _, row in ipairs(rows) do
        if row.name == "C_XMLUtil.GetTemplateInfo" and row.status == "error" then
          found = true
        end
      end
      Assert.True(found, "the selftest names the missing template")
    end, Prepare({ estimate = true, template = false }))
    Stress.WithKey(ctx, Fixture, function(session)
      session.Advance(3)
      Assert.True(#EnabledSensors(session) > 0, "sensors run in the party")
      session.raid = true
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.Advance(2)
      Assert.Equal(#EnabledSensors(session), 0, "every sensor off in a raid (rule 11)")
    end, Prepare({ estimate = true }))
  end)

  test("Defensive estimate switches off and reports a refused container setup in the selftest", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.Advance(3)
      local sensors = session.addon.DefensiveSensors
      Assert.False(sensors.IsSupported(), "a refused setup switches the estimate off")
      Assert.Equal(#sensors.GetEstimate(session.addon.Sync.NormalizePlayerKey("Peer3", "Realm")), 0, "no estimate")
      local found = nil
      for _, row in ipairs(session.addon.ApiHealth.Run()) do
        if row.name == "AuraContainer setup" then
          found = row
        end
      end
      found = Assert.NotNil(found, "the selftest lists the refused setup")
      Assert.Equal(found.status, "error", "as an error row")
      Assert.True(tostring(found.detail):find("group", 1, true) ~= nil, "naming the refused step")
    end, Prepare({ estimate = true, refuseGroups = true }))
  end)

  test("Defensive estimate passes secret sensor answers through the curve into the bar", function()
    local secret, secretGlobals = ctx.fixtures.MakeStrictSecret("boolean")
    Stress.WithKey(
      ctx,
      Fixture,
      function(session)
        session.Advance(3)
        Render(session)
        local sensors = session.addon.DefensiveSensors
        local reads = sensors.GetReadCount()
        Assert.True(reads > 0, "the sensors were read")
        -- Several ticks with secret answers: any comparison, arithmetic or
        -- truth test on them would raise inside the production ticker.
        session.Advance(10)
        Assert.True(sensors.GetReadCount() > reads, "the secret answers keep flowing")
        local slot = FindSlot(session, ICE_BLOCK)
        local bar = slot.estimateBar
        Assert.True(rawequal(bar._min, secret), "the bar minimum is the secret latch")
        Assert.True(rawequal(bar._max, secret), "the bar maximum is the secret latch")
        Assert.Equal(type(bar._value), "number", "the bar value is the plain clock")
      end,
      Prepare({
        estimate = true,
        secret = secret,
        extra = function(globals)
          for key, value in pairs(secretGlobals) do
            globals[key] = value
          end
        end,
      })
    )
  end)

  test("Defensive estimate counts the manifest cooldown down from the detected buff start", function()
    Stress.WithKey(ctx, Fixture, function(session)
      session.Advance(3)
      Render(session)
      local bar = FindSlot(session, ICE_BLOCK).estimateBar
      Assert.Equal(FillShare(bar), 0, "never seen: no remaining cooldown drawn")

      session.auraUp["party3:" .. ICE_BLOCK] = true
      local start = session.now
      session.Advance(1)
      session.auraUp["party3:" .. ICE_BLOCK] = nil
      session.Advance(59)
      local share = FillShare(bar)
      local expected = (240 - (session.now - start)) / 240
      Assert.True(math.abs(share - expected) <= 1 / 240, "remaining share from the buff start: " .. share)

      -- Cursor outside the screen: the tick is skipped, nothing is forced.
      local reads = session.addon.DefensiveSensors.GetReadCount()
      session.cursor = { -50, -50 }
      session.auraUp["party3:" .. ICE_BLOCK] = true
      session.Advance(5)
      Assert.Equal(session.addon.DefensiveSensors.GetReadCount(), reads, "no read with the cursor off screen")
      session.auraUp["party3:" .. ICE_BLOCK] = nil
      session.cursor = { 300, 200 }

      session.Advance(200)
      Assert.Equal(FillShare(bar), 0, "the cooldown ran out: ready")
    end, Prepare({ estimate = true }))
  end)
end

local function RegisterSettingsTests(test, ctx)
  local Assert = ctx.assert

  test("Defensives settings default off (Pattern B) and re-apply the runtime on every switch", function()
    local addon = ctx.load_modules({ "isiLive_db_schema.lua" })
    local db = {}
    addon.DBSchema.Sanitize(db)
    Assert.Equal(db.defensiveEstimateEnabled, false, "schema default of the estimate")
    Assert.Equal(db.defensiveTrackerEnabled, false, "schema default of the feature")
    Assert.Equal(db.defensiveSyncEnabled, false, "schema default of the sync")

    Stress.WithKey(ctx, Fixture, function(session)
      session.Advance(2)
      Assert.Equal(#VisibleCells(session), 0, "off")
      local options = session.addon.SettingsDefensives.OPTIONS
      Assert.Equal(options[1].field, "defensiveTrackerEnabled", "the feature switch first")
      session.globals.IsiLiveDB.defensiveTrackerEnabled = true
      session.addon.SettingsDefensives.ApplyRuntime()
      Assert.True(#VisibleCells(session) > 0, "switching on shows the cell at once")
      session.globals.IsiLiveDB.defensiveTrackerEnabled = false
      session.addon.SettingsDefensives.ApplyRuntime()
      Assert.Equal(#VisibleCells(session), 0, "switching off removes it at once")
    end, Prepare({ tracker = false }))
  end)

  test("Settings panel shows the three defensives switches, Pattern B, and applies the runtime", function()
    local helpers = dofile("testmodul/isilive_test_ui_helpers.lua")
    local createFrameStub, createdFrames = helpers.BuildCreateFrameStub()
    local db = {}
    ctx.with_globals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = { RegisterAddOnCategory = function() end },
    }, function()
      local addon = ctx.load_modules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local applied = 0
      addon.DefensiveRuntime = {
        ApplySettings = function()
          applied = applied + 1
        end,
      }
      addon.SettingsPanel.Create({
        getL = function()
          return {}
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })
      local checks = {}
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "CheckButton" and type(frame._settingKey) == "string" then
          checks[frame._settingKey] = frame
        end
      end
      for index, entry in ipairs({
        { "SETTINGS_DEFENSIVE_TRACKER", "defensiveTrackerEnabled" },
        { "SETTINGS_DEFENSIVE_SYNC", "defensiveSyncEnabled" },
        { "SETTINGS_DEFENSIVE_ESTIMATE", "defensiveEstimateEnabled" },
      }) do
        local check = Assert.NotNil(checks[entry[1]], entry[1] .. " checkbox")
        Assert.False(check:GetChecked(), entry[2] .. " reads unchecked when unset (Pattern B)")
        check:SetChecked(true)
        check._scripts.OnClick(check)
        Assert.True(db[entry[2]] == true, entry[2] .. " persists true")
        Assert.Equal(applied, index, "every switch re-applies the runtime once")
      end
    end)
  end)

  test("Defensives texts exist in all five languages", function()
    local addon = ctx.load_modules({ "isiLive_texts.lua" })
    local tables = addon.Texts.GetLocaleTables()
    for _, tag in ipairs({ "enUS", "deDE", "frFR", "ruRU", "trTR" }) do
      for _, key in ipairs({
        "COL_DEF",
        "DEF_TOOLTIP_HEADER",
        "DEF_STATE_ESTIMATED",
        "DEF_STATE_NOT_SEEN",
        "DEF_SOURCE_SYNC",
        "SETTINGS_DEFENSIVE_TRACKER",
        "SETTINGS_DEFENSIVE_SYNC",
        "SETTINGS_DEFENSIVE_ESTIMATE",
      }) do
        Assert.True(type(tables[tag][key]) == "string" and tables[tag][key] ~= "", tag .. " " .. key)
      end
    end
  end)
end

return function(test, ctx)
  RegisterCellTests(test, ctx)
  RegisterSensorTests(test, ctx)
  RegisterSettingsTests(test, ctx)
end
