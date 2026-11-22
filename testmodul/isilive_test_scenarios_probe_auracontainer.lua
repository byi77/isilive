---@diagnostic disable: undefined-global, undefined-field

-- Probe mode aura container probes (rule 239, P1..P5). Every flow boots the
-- real factory and pumps client events through the real gated dispatcher
-- (stress helpers): the slash command, GROUP_ROSTER_UPDATE, UNIT_AURA and the
-- combat edges reach logic/isiLive_probe_auracontainer.lua through the real
-- ProbeLog hooks, and the lines land in the real runtime log ring. Only the
-- WoW API surface is stubbed: the AuraContainer widget (Blizzard's secure
-- filtering and layout cannot run outside the client, so the stub answers
-- IsMouseOver/GetWidth from session.auraUp or a strict secret), StatusBar,
-- C_CurveUtil, AuraUtil, C_XMLUtil, C_Secrets and GetCursorPosition.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local FixtureWithSchema = {
  buildGlobals = Fixture.buildGlobals,
  moduleFiles = function()
    local files = Fixture.moduleFiles()
    table.insert(files, 1, "isiLive_simulation_tablet.lua")
    table.insert(files, 1, "isiLive_db_schema.lua")
    table.insert(files, 1, "isiLive_sound_registry.lua")
    return files
  end,
}

local TEMPLATE = "CustomAuraContainerTemplate"
local FILTER_EXTERNAL = "HELPFUL|EXTERNAL_DEFENSIVE"
local FILTER_BIG = "HELPFUL|BIG_DEFENSIVE"
-- Test values for Enum.SecrecyLevel; the probe resolves names at run time.
local SECRECY = { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 }
local FORBEARANCE = 25771

-- opts: { probe = true|false, secret = <strict secret> }
local function PrepareSensors(opts)
  opts = opts or {}
  return function(globals, session)
    globals.IsiLiveDB.probeLogEnabled = opts.probe == true
    session.printed = {}
    local basePrint = globals.print
    globals.print = function(message)
      session.printed[#session.printed + 1] = tostring(message)
      basePrint(message)
    end
    session.containers = {}
    session.bars = {}
    session.auraUp = {}
    session.mouseOverCalls = 0
    session.cursor = { 300, 200 }
    session.invalidFilters = {}
    session.groupErrors = {}
    session.secret = opts.secret
    globals.UIParent:SetSize(1920, 1080)
    local createFrame = globals.CreateFrame
    globals.CreateFrame = function(frameType, name, parent, template, ...)
      local frame = createFrame(frameType, name, parent, template, ...)
      if frameType == "AuraContainer" then
        frame._template = template
        frame._groups = {}
        frame._combatCalls = {}
        local function NoteCombatCall(label)
          if session.combat then
            frame._combatCalls[#frame._combatCalls + 1] = label
            local blocked = session.blockInCombat and session.blockInCombat[label]
            if blocked then
              -- The client fires ADDON_ACTION_BLOCKED for the protected call.
              session.Blocked(label)
            end
          end
        end
        function frame:AddAuraGroup(key, filter, options)
          assert(type(key) == "string" and key ~= "", "group key")
          if session.groupErrors[filter] then
            error("test: group refused")
          end
          self._groups[#self._groups + 1] = { key = key, filter = filter, options = options }
          if type(options) == "table" and type(options.initializeFrame) == "function" then
            options.initializeFrame(createFrame("Button", nil, self))
          end
        end
        function frame:SetUnit(unit)
          NoteCombatCall("SetUnit")
          self._unit = unit
        end
        function frame:SetEnabled(enabled)
          NoteCombatCall("SetEnabled")
          if session.combat and session.failInCombat and session.failInCombat.SetEnabled then
            error("test: SetEnabled refused in combat")
          end
          self._enabled = enabled
        end
        local baseHide, baseShow = frame.Hide, frame.Show
        function frame:Hide()
          NoteCombatCall("Hide")
          return baseHide(self)
        end
        function frame:Show()
          NoteCombatCall("Show")
          return baseShow(self)
        end
        function frame:IsMouseOver(top, bottom, left, right)
          session.mouseOverCalls = session.mouseOverCalls + 1
          self._overArgs = { top, bottom, left, right }
          if session.secret and session.secretSensor then
            return session.secret
          end
          if session.toggleSensor then
            self._flip = not self._flip
            return self._flip
          end
          return session.auraUp[self._unit] == true
        end
        function frame:GetWidth()
          if session.secret and session.secretSensor then
            return session.secret
          end
          return session.auraUp[self._unit] == true and 60000 or 0
        end
        session.containers[#session.containers + 1] = frame
      elseif frameType == "StatusBar" then
        frame._values = {}
        function frame:SetValue(value)
          self._values[#self._values + 1] = value
        end
        session.bars[#session.bars + 1] = frame
      end
      return frame
    end
    globals.C_CurveUtil = globals.C_CurveUtil or {}
    globals.C_CurveUtil.EvaluateColorValueFromBoolean = function(value, ifTrue, ifFalse)
      if session.secret and rawequal(value, session.secret) then
        return session.secret
      end
      return value == true and ifTrue or ifFalse
    end
    globals.AuraUtil = {
      IsValidFilterString = function(filter)
        return not session.invalidFilters[filter]
      end,
    }
    globals.C_XMLUtil = {
      GetTemplateInfo = function(templateName)
        return templateName == TEMPLATE and { type = "AuraContainer" } or nil
      end,
    }
    globals.GetCursorPosition = function()
      return session.cursor[1], session.cursor[2]
    end
    globals.Enum = globals.Enum or {}
    globals.Enum.SecrecyLevel = SECRECY
    globals.C_Secrets = {
      ShouldAurasBeSecret = function()
        return session.active == true
      end,
      ShouldCooldownsBeSecret = function()
        return session.active == true
      end,
      HasSecretRestrictions = function()
        return true
      end,
      GetSpellAuraSecrecy = function(spellID)
        return spellID == FORBEARANCE and SECRECY.NeverSecret or SECRECY.ContextuallySecret
      end,
      GetSpellCooldownSecrecy = function()
        return SECRECY.ContextuallySecret
      end,
      ShouldSpellCooldownBeSecret = function()
        return session.active == true
      end,
    }
  end
end

local function WithSecret(ctx, opts)
  local secret, secretGlobals = ctx.fixtures.MakeStrictSecret("boolean")
  opts = opts or {}
  opts.secret = secret
  local prepare = PrepareSensors(opts)
  return secret,
    function(globals, session)
      prepare(globals, session)
      for key, value in pairs(secretGlobals) do
        globals[key] = value
      end
    end
end

local function ProbeLines(session, filter)
  local lines, total = session.runtime.runtimeLogController.GetLogTailFiltered(100, filter or "[PROBE]")
  return lines, total or #lines
end

local function FindLine(lines, needle)
  for _, line in ipairs(lines) do
    if tostring(line):find(needle, 1, true) then
      return line
    end
  end
  return nil
end

local function CountLines(session, needle)
  return select(2, ProbeLines(session, needle))
end

local function PartyAura(session, unit)
  return session.DispatchToFrames("UNIT_AURA", unit, { isFullUpdate = true })
end

local function Pull(session)
  session.combat = true
  session.Dispatch("PLAYER_REGEN_DISABLED")
end

local function EndPull(session)
  session.combat = false
  session.Dispatch("PLAYER_REGEN_ENABLED")
end

local function Report(session)
  session.printed = {}
  session.globals.SlashCmdList.ISILIVE("probe report")
  return session.printed
end

-- Sum of one field over the ac_tally lines that match `needle`.
local function SumTally(session, needle, field)
  local sum = 0
  for _, line in ipairs((ProbeLines(session, "event=ac_tally"))) do
    local text = tostring(line)
    if text:find(needle, 1, true) then
      sum = sum + (tonumber(text:match(" " .. field .. "=(%d+)")) or 0)
    end
  end
  return sum
end

local function ContainersBy(session, predicate)
  local out = {}
  for _, container in ipairs(session.containers) do
    local group = container._groups[1]
    if group and predicate(container, group) then
      out[#out + 1] = container
    end
  end
  return out
end

local function IsSensor(session)
  return function(container, group)
    return group.options.layout.elementWidth == session.addon.ProbeAuraContainer.GEOMETRY.sensorStride
      and container:GetParent() == session.globals.UIParent
  end
end

return function(test, ctx)
  local Assert = ctx.assert

  local function AssertReportLine(printed, expected, label)
    Assert.NotNil(FindLine(printed, expected), label .. ": " .. table.concat(printed, " || "))
  end

  local function AssertNoTableText(lines)
    for _, line in ipairs(lines) do
      Assert.Nil(tostring(line):find("table:", 1, true), "no secret is ever stringified: " .. tostring(line))
    end
  end

  test("Probe aura containers are not built without probe mode", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      Pull(session)
      PartyAura(session, "party1")
      session.Advance(3)
      EndPull(session)
      PartyAura(session, "party2")
      session.Advance(3)
      session.Dispatch("GROUP_ROSTER_UPDATE")
      Assert.Equal(#session.containers, 0, "probe mode off creates no AuraContainer")
      Assert.Equal(#session.bars, 0, "and no sensor bar")
      Assert.Equal(session.mouseOverCalls, 0, "and reads no sensor")
      Assert.Nil(session.addon.ProbeAuraContainer._GetFrames(), "no probe frame")
      Assert.Equal(CountLines(session, "event=ac_"), 0, "no aura container line")
    end, PrepareSensors({ probe = false }))
  end)

  test("Probe aura containers build out of combat with the configured filters and log the setup", function()
    Stress.WithParty(ctx, FixtureWithSchema, function(session)
      local manifest = session.addon.DefensiveManifest
      session.globals.SlashCmdList.ISILIVE("probe on")
      Assert.Equal(#session.containers, 17, "3 visible columns and 1 sensor per party unit, plus the test container")
      for _, container in ipairs(session.containers) do
        Assert.Equal(container._template, TEMPLATE, "every container uses the Blizzard template")
        Assert.True(container._enabled, "every container is enabled")
      end

      local sensors = ContainersBy(session, IsSensor(session))
      Assert.Equal(#sensors, 4, "one sensor per party unit")
      local geometry = session.addon.ProbeAuraContainer.GEOMETRY
      for index, sensor in ipairs(sensors) do
        local group = sensor._groups[1]
        Assert.Equal(sensor._unit, "party" .. index, "sensor unit")
        Assert.Equal(sensor:GetAlpha(), 0, "the sensor is invisible")
        Assert.Equal(group.filter, "HELPFUL", "sensor filter")
        Assert.Equal(group.options.maxFrameCount, 1, "one aura frame is enough")
        Assert.True(group.options.candidateFilters.includeSpellIDs[33206], "Pain Suppression is on the list")
        Assert.True(group.options.candidateFilters.includeSpellIDs[145629], "the Anti-Magic Zone aura is on it")
        Assert.Nil(group.options.candidateFilters.includeSpellIDs[51052], "the cast ID is not an aura ID")
        Assert.Equal(sensor._points[1][4], geometry.sensorOffsetX, "the sensor starts left of the screen")
      end
      local ext = ContainersBy(session, function(_, group)
        return group.filter == FILTER_EXTERNAL
      end)
      local big = ContainersBy(session, function(_, group)
        return group.filter == FILTER_BIG
      end)
      Assert.Equal(#ext, 4, "one EXTERNAL_DEFENSIVE column per row")
      Assert.Equal(#big, 4, "one BIG_DEFENSIVE column per row")
      Assert.Nil(ext[1]._groups[1].options.candidateFilters, "the Blizzard filters need no ID list")

      local frames = session.addon.ProbeAuraContainer._GetFrames()
      Assert.True(frames.root:IsShown(), "the probe frame is visible")
      Assert.True(frames.root:IsMovable(), "and movable")
      Assert.Equal(frames.rows[2].name:GetText(), "party2 Peer2", "rows carry the party names")

      local idCount = 0
      for _, record in ipairs(manifest.list) do
        if record.probe == true then
          idCount = idCount + 1
        end
      end
      Assert.NotNil(
        FindLine(
          ProbeLines(session, "event=ac_config"),
          string.format(
            "inKey=no template=yes auraIDs=%d extFilter=valid bigFilter=valid stride=%d offsetX=%d reach=%d",
            idCount,
            geometry.sensorStride,
            geometry.sensorOffsetX,
            geometry.mouseOverReach
          )
        ),
        "the own configuration is logged"
      )
      Assert.NotNil(
        FindLine(ProbeLines(session, "event=ac_setup"), "unit=party1 ids=ok ext=ok big=ok sensor=ok bar=ok error=none"),
        "setup per row"
      )
      Assert.NotNil(FindLine(ProbeLines(session, "event=ac_setup"), "unit=ops status=ok error=none"), "test container")
      Assert.NotNil(
        FindLine(
          ProbeLines(session, "event=ac_secrets"),
          "inKey=no inCombat=no aurasSecret=no cooldownsSecret=no hasRestrictions=yes"
        ),
        "C_Secrets outside a key"
      )
      local auraParts = math.ceil((idCount + 1) / 10)
      Assert.NotNil(
        FindLine(
          ProbeLines(session, "event=ac_secrecy kind=aura"),
          string.format("part=%d/%d values=", auraParts, auraParts)
        ),
        "aura secrecy in chunks"
      )
      Assert.NotNil(
        FindLine(ProbeLines(session, "event=ac_secrecy kind=aura"), "25771:NeverSecret"),
        "Forbearance is checked as well"
      )
      Assert.NotNil(
        FindLine(ProbeLines(session, "event=ac_secrecy kind=cooldown"), "values=33206:ContextuallySecret/no,"),
        "cooldown secrecy with the contextual answer"
      )
      Assert.NotNil(
        FindLine(ProbeLines(session, "event=ac_secrecy kind=cooldown"), "51052:ContextuallySecret/no"),
        "cooldowns use the cast ID"
      )

      local printed = Report(session)
      AssertReportLine(printed, "P1 visible aura containers set up: yes (17 ok, 0 failed)", "P1")
      AssertReportLine(
        printed,
        "P2 sensor chain in the key: unknown (reads=0, secret=0, errors=0); outside the key readable: unknown",
        "P2 without reads"
      )
      AssertReportLine(printed, "P3 container calls in combat without errors: unknown (0 tests", "P3 without pull")
      AssertReportLine(
        printed,
        string.format(
          "P4 C_Secrets: auras secret outside no, in the key -; aura secrecy ContextuallySecret:%d,NeverSecret:1; "
            .. "cooldown secrecy ContextuallySecret:%d, cooldowns secret in the key 0/0",
          idCount,
          idCount
        ),
        "P4"
      )
      AssertReportLine(printed, "P5 cursor readable at the sensor reads: unknown (in the window 0", "P5 without reads")
    end, PrepareSensors({ probe = false }))
  end)

  test("Probe aura sensors read readable answers outside a key on UNIT_AURA and drive the bar", function()
    Stress.WithParty(ctx, FixtureWithSchema, function(session)
      session.globals.SlashCmdList.ISILIVE("probe on")
      local frames = session.addon.ProbeAuraContainer._GetFrames()
      session.auraUp.party2 = true
      PartyAura(session, "party2")
      PartyAura(session, "party2")
      PartyAura(session, "party2")
      Assert.Equal(session.mouseOverCalls, 0, "the read waits for the container layout")
      session.Advance(0.2)
      Assert.Equal(session.mouseOverCalls, 1, "UNIT_AURA bursts collapse into one read per unit")
      local sensor = ContainersBy(session, IsSensor(session))[2]
      local reach = session.addon.ProbeAuraContainer.GEOMETRY.mouseOverReach
      Assert.Equal(table.concat(sensor._overArgs, ","), string.format("%d,%d,0,0", reach, -reach), "hit box")
      Assert.NotNil(
        FindLine(
          ProbeLines(session, "event=ac_sensor"),
          "unit=party2 trigger=unit_aura phase=outside inKey=no inCombat=no over=true curve=ok curveSecret=no "
            .. "bar=ok width=60000 cursor=in change=no"
        ),
        "a readable active sensor"
      )
      local bar = frames.rows[2].bar
      Assert.Equal(bar._values[#bar._values], 1, "the curve maps active to 1 on the bar")

      session.auraUp.party2 = false
      session.cursor = { -40, 200 }
      PartyAura(session, "party2")
      session.Advance(0.2)
      Assert.NotNil(
        FindLine(
          ProbeLines(session, "event=ac_sensor"),
          "unit=party2 trigger=unit_aura phase=outside inKey=no "
            .. "inCombat=no over=false curve=ok curveSecret=no bar=ok width=0 cursor=out change=yes"
        ),
        "a readable change gets its own line"
      )
      Assert.Equal(bar._values[#bar._values], 0, "inactive maps to 0")
      PartyAura(session, "player")
      PartyAura(session, "party9")
      session.Advance(0.2)
      Assert.Equal(session.mouseOverCalls, 2, "only party1..4 trigger a read")

      local printed = Report(session)
      AssertReportLine(
        printed,
        "outside the key readable: yes (reads=2, active=1, secret=0, errors=0)",
        "P2 outside the key"
      )
      AssertReportLine(
        printed,
        "P5 cursor readable at the sensor reads: yes (in the window 1, outside 1, unreadable 0)",
        "P5"
      )
    end, PrepareSensors({ probe = false }))
  end)

  test("Probe aura sensors tick in a key pull and pass secret answers through the curve into the bar", function()
    local secret, prepare = WithSecret(ctx, { probe = true })
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      local probe = session.addon.ProbeAuraContainer
      local frames = probe._GetFrames()
      Assert.NotNil(frames, "probe mode on from the load: built at the first roster update, out of combat")
      session.secretSensor = true
      Pull(session)
      session.Advance(2.1)
      Assert.Equal(session.mouseOverCalls, 16, "four ticks of four sensors in two seconds")
      local lines = ProbeLines(session, "event=ac_sensor")
      Assert.Equal(#lines, 4, "one line per unit and segment while the answer stays secret")
      Assert.NotNil(
        FindLine(
          lines,
          "unit=party3 trigger=tick phase=pull inKey=yes inCombat=yes over=secret curve=ok curveSecret=yes "
            .. "bar=ok width=secret cursor=in change=no"
        ),
        "the secret answer is passed on, never compared"
      )
      local bar = frames.rows[3].bar
      Assert.True(rawequal(bar._values[#bar._values], secret), "the bar receives the secret curve value")

      Assert.NotNil(
        FindLine(ProbeLines(session, "event=ac_combat_ops"), "stage=begin inKey=yes inCombat=yes"),
        "combat test start"
      )
      Assert.NotNil(
        FindLine(
          ProbeLines(session, "event=ac_combat_ops"),
          "stage=end setUnit=ok setEnabledOff=ok setEnabledOn=ok hide=ok show=ok shownAfter=yes error=none"
        ),
        "the container calls in combat"
      )
      local ops = frames.ops
      Assert.Equal(table.concat(ops._combatCalls, ","), "SetUnit,SetEnabled,SetEnabled,Hide,Show", "call order")
      Assert.NotNil(
        FindLine(ProbeLines(session, "event=ac_secrets"), "at=combat_start inKey=yes inCombat=yes aurasSecret=yes"),
        "C_Secrets in the key"
      )

      EndPull(session)
      Assert.NotNil(
        FindLine(
          ProbeLines(session, "event=ac_tally"),
          "at=combat_end phase=pull inKey=yes reads=16 overTrue=0 overFalse=0 overSecret=16 overError=0 overOther=0 "
            .. "curveOk=16 curveSecret=16 curveError=0 barOk=16 barError=0 cursorIn=16"
        ),
        "every read is tallied"
      )
      session.Advance(5)
      Assert.Equal(session.mouseOverCalls, 16, "the ticker stops at the combat end")
      Pull(session)
      session.Advance(2.1)
      Assert.Equal(CountLines(session, "stage=begin"), 1, "the combat test runs once per run")
      EndPull(session)

      local printed = Report(session)
      AssertReportLine(printed, "P2 sensor chain in the key: yes (reads=32, secret=32, errors=0)", "P2 in the key")
      AssertReportLine(
        printed,
        "P3 container calls in combat without errors: yes (1 tests, 0 failed calls, 0 blocked)",
        "P3"
      )
      AssertReportLine(printed, "auras secret outside -, in the key yes;", "P4 in the key")
      AssertReportLine(printed, "cooldowns secret in the key 37/37", "P4 contextual cooldowns")
      AssertNoTableText(ProbeLines(session))
      AssertNoTableText(printed)
    end, prepare)
  end)

  test("Probe aura containers log a refused aura group and skip a filter the client rejects", function()
    Stress.WithParty(ctx, FixtureWithSchema, function(session)
      session.invalidFilters[FILTER_BIG] = true
      session.groupErrors[FILTER_EXTERNAL] = true
      session.globals.SlashCmdList.ISILIVE("probe on")
      Assert.NotNil(FindLine(ProbeLines(session, "event=ac_config"), "extFilter=valid bigFilter=invalid"), "filters")
      local line = FindLine(
        ProbeLines(session, "event=ac_setup"),
        "unit=party4 ids=ok ext=group_error big=skipped_filter_invalid sensor=ok bar=ok error="
      )
      Assert.NotNil(line, "a refused group and a skipped column")
      Assert.NotNil(tostring(line):find("group_refused", 1, true), "the error text is logged without spaces")
      Assert.Equal(#ContainersBy(session, function(_, group)
        return group.filter == FILTER_BIG
      end), 0, "no container for a rejected filter")
      local printed = Report(session)
      AssertReportLine(printed, "P1 visible aura containers set up: partly (9 ok, 4 failed)", "P1 partly")
    end, PrepareSensors({ probe = false }))
  end)

  test("Probe aura containers wait for the combat end, stay off in a raid and hide with probe mode off", function()
    Stress.WithParty(ctx, FixtureWithSchema, function(session)
      session.combat = true
      session.globals.SlashCmdList.ISILIVE("probe on")
      Assert.Equal(#session.containers, 0, "no frame is created in combat")
      Assert.NotNil(FindLine(ProbeLines(session, "event=ac_setup"), "status=deferred_in_combat"), "deferred")
      EndPull(session)
      Assert.Equal(#session.containers, 17, "built right after the combat end")
      local frames = session.addon.ProbeAuraContainer._GetFrames()

      session.raid = true
      session.Dispatch("GROUP_ROSTER_UPDATE")
      Assert.NotNil(FindLine(ProbeLines(session, "event=ac_suspended"), "reason=raid"), "raid suspends")
      Assert.False(frames.root:IsShown(), "the probe frame is hidden in a raid")
      for _, container in ipairs(session.containers) do
        Assert.False(container._enabled, "every container is disabled in a raid")
      end
      local reads = session.mouseOverCalls
      PartyAura(session, "party1")
      Pull(session)
      session.Advance(3)
      EndPull(session)
      Assert.Equal(session.mouseOverCalls, reads, "no sensor read in a raid")

      session.raid = false
      session.Dispatch("GROUP_ROSTER_UPDATE")
      Assert.NotNil(FindLine(ProbeLines(session, "event=ac_resumed"), "at=roster"), "the way back resumes")
      Assert.True(frames.root:IsShown(), "visible again")
      Assert.True(session.containers[1]._enabled, "enabled again")
      Assert.Equal(#session.containers, 17, "the containers are reused, never rebuilt")

      session.globals.SlashCmdList.ISILIVE("probe off")
      Assert.NotNil(FindLine(ProbeLines(session, "event=ac_suspended"), "reason=probe_off"), "probe off suspends")
      Assert.False(frames.root:IsShown(), "hidden with probe mode off")
      reads = session.mouseOverCalls
      session.auraUp.party1 = true
      PartyAura(session, "party1")
      Pull(session)
      session.Advance(3)
      EndPull(session)
      Assert.Equal(session.mouseOverCalls, reads, "probe mode off reads no sensor")
    end, PrepareSensors({ probe = false }))
  end)

  test("Probe aura sensors cap lines per segment and phase and still tally every read", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      local limits = session.addon.ProbeAuraContainer.LIMITS
      session.toggleSensor = true
      Pull(session)
      session.Advance(5)
      EndPull(session)
      Assert.Equal(
        CountLines(session, "event=ac_sensor"),
        limits.sensorLinesPerSegment,
        "changing answers write at most sensorLinesPerSegment lines per segment"
      )
      local pulls = limits.sensorLinesPerPhase / limits.sensorLinesPerSegment + 2
      for _ = 2, pulls do
        Pull(session)
        session.Advance(5)
        EndPull(session)
      end
      Assert.Equal(CountLines(session, "event=ac_sensor"), limits.sensorLinesPerPhase, "the pull phase is capped")
      Assert.Equal(CountLines(session, "event=cap_reached probe=ac_sensor_pull"), 1, "one cap line")
      Assert.Equal(SumTally(session, "phase=pull", "reads"), pulls * 40, "the tally counts every read")
    end, PrepareSensors({ probe = true }))
  end)

  test("Probe aura container combat test counts failed and blocked calls", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      local probeLog = session.addon.ProbeLog
      local frame = probeLog._actionBlockedFrame
      function session.Blocked(label)
        frame:GetScript("OnEvent")(frame, "ADDON_ACTION_BLOCKED", "isiLive", label .. "()")
      end
      session.blockInCombat = { Hide = true }
      session.failInCombat = { SetEnabled = true }
      Pull(session)
      session.Advance(1.2)
      Assert.NotNil(
        FindLine(
          ProbeLines(session, "event=ac_combat_ops"),
          "stage=end setUnit=ok setEnabledOff=error setEnabledOn=error hide=ok show=ok"
        ),
        "a throwing call is logged as error, never raised"
      )
      Assert.NotNil(FindLine(ProbeLines(session, "event=action_blocked"), "func=Hide() inCombat=yes"), "blocked")
      EndPull(session)
      local printed = Report(session)
      AssertReportLine(
        printed,
        "P3 container calls in combat without errors: no (1 tests, 2 failed calls, 1 blocked)",
        "P3 failed"
      )
    end, PrepareSensors({ probe = true }))
  end)
end
