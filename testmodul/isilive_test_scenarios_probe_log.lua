---@diagnostic disable: undefined-global, undefined-field

-- Probe mode (rule 239). Every flow boots the real factory and pumps client
-- events through the real gated dispatcher (stress helpers); the probe lines
-- land in the real runtime log ring through the real ProbeLog sink. Only the
-- WoW API surface is stubbed: the damage meter, threat, chat lockdown,
-- nameplate units, IsInInstance and the restriction enums.
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

local COUNTERSPELL = 2139
local FIREBALL = 133
local SESSION_OVERALL, SESSION_CURRENT = 0, 1
local METER_DAMAGE, METER_INTERRUPTS = 0, 5

local function ReadableMeter(_sessionType, meterType)
  if meterType == METER_INTERRUPTS then
    return { combatSources = { { name = "Tester", totalAmount = 12 }, { name = "Peer1", totalAmount = 3 } } }
  end
  return {
    combatSources = {
      { name = "Tester", totalAmount = 822220920 },
      { name = "Peer1", totalAmount = 578022840 },
    },
  }
end

-- opts: { probe = true|false, alert, meter = function, noMeterApi }
local function Prepare(opts)
  opts = opts or {}
  return function(globals, session)
    local db = globals.IsiLiveDB
    db.probeLogEnabled = opts.probe ~= false
    db.missedKickAlertEnabled = opts.alert == true
    session.calls = { lockdown = 0, threat = 0, meter = 0 }
    session.lockdown = false
    session.inInstance = true
    session.meter = opts.meter or ReadableMeter
    session.plates = {}
    session.printed = {}
    local basePrint = globals.print
    globals.print = function(message)
      session.printed[#session.printed + 1] = tostring(message)
      basePrint(message)
    end
    globals.Enum = globals.Enum or {}
    globals.Enum.AddOnRestrictionType =
      { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 }
    globals.Enum.AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 }
    globals.Enum.DamageMeterSessionType = { Overall = SESSION_OVERALL, Current = SESSION_CURRENT }
    globals.Enum.DamageMeterType = { DamageDone = METER_DAMAGE, Interrupts = METER_INTERRUPTS }
    if opts.noMeterApi then
      globals.C_DamageMeter = nil
    else
      globals.C_DamageMeter = {
        IsDamageMeterAvailable = function()
          return true
        end,
        ResetAllCombatSessions = function() end,
        GetCombatSessionFromType = function(sessionType, meterType)
          session.calls.meter = session.calls.meter + 1
          return session.meter(sessionType, meterType)
        end,
      }
    end
    globals.C_ChatInfo.InChatMessagingLockdown = function()
      session.calls.lockdown = session.calls.lockdown + 1
      return session.lockdown
    end
    globals.IsInInstance = function()
      return session.inInstance, session.inInstance and "party" or "none"
    end
    local unitExists = globals.UnitExists
    globals.UnitExists = function(unit)
      if type(unit) == "string" and unit:find("^nameplate") then
        return session.plates[unit] ~= nil
      end
      return unitExists(unit)
    end
    globals.UnitCanAttack = function(_, unit)
      local plate = session.plates[unit]
      if plate then
        return plate.hostile
      end
      return not (unit == "player" or unit:find("^party%d") ~= nil)
    end
    globals.UnitThreatSituation = function(_, unit)
      session.calls.threat = session.calls.threat + 1
      if unit == nil then
        return session.selfThreat
      end
      local plate = session.plates[unit]
      return plate and plate.threat or nil
    end
    -- Own buffs and weapon enchants for the ready-check probe (K4).
    session.auras = {}
    session.weapon = { false, nil, 0, nil, false, nil, 0, nil }
    globals.C_UnitAuras = globals.C_UnitAuras or {}
    globals.C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
      session.calls.auras = (session.calls.auras or 0) + 1
      if unit ~= "player" or filter ~= "HELPFUL" then
        return nil
      end
      return session.auras[index]
    end
    globals.C_UnitAuras.GetPlayerAuraBySpellID = function(spellId)
      for _, aura in ipairs(session.auras) do
        if type(aura) == "table" and aura.spellId == spellId then
          return aura
        end
      end
      return nil
    end
    globals.GetWeaponEnchantInfo = function()
      session.calls.weapon = (session.calls.weapon or 0) + 1
      return unpack(session.weapon, 1, 8)
    end
    globals.InCombatLockdown = function()
      return session.combat == true
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

local function Deliver(session, event, ...)
  return session.DispatchToFrames(event, ...)
end

local function Kick(session, spellID, castGUID)
  Deliver(session, "UNIT_SPELLCAST_SUCCEEDED", "player", castGUID or "kick-cast", spellID or COUNTERSPELL)
end

local function HostileInterrupt(session)
  Deliver(session, "UNIT_SPELLCAST_INTERRUPTED", "nameplate3", "hostile-cast", 12345, nil, 1)
end

local function Pull(session)
  session.combat = true
  session.Dispatch("PLAYER_REGEN_DISABLED")
end

local function EndPull(session)
  session.combat = false
  session.Dispatch("PLAYER_REGEN_ENABLED")
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Probe mode off writes no probe lines and reads no probe API", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      session.runtime.runtimeLogController.SetEnabled(true)
      session.plates.nameplate1 = { hostile = true, threat = 3 }
      Pull(session)
      Kick(session)
      HostileInterrupt(session)
      session.Advance(3)
      EndPull(session)
      session.Dispatch("ADDON_RESTRICTION_STATE_CHANGED", 2, 2)
      session.Dispatch("READY_CHECK", "Tester")
      session.active = false
      session.Dispatch("CHALLENGE_MODE_COMPLETED")
      session.Advance(10)
      local _, total = ProbeLines(session)
      Assert.Equal(total, 0, "probe mode off writes no [PROBE] line")
      Assert.Equal(session.calls.threat, 0, "probe mode off never reads threat")
      Assert.Equal(session.calls.auras or 0, 0, "probe mode off never reads own auras")
      Assert.Equal(session.calls.weapon or 0, 0, "probe mode off never reads weapon enchants")
      Assert.False(session.globals.IsiLiveDB.probeLogEnabled, "the switch stays off (Pattern B)")
    end, Prepare({ probe = false }))
  end)

  test("Probe mode logs readable damage meter sessions between pulls and at the key end", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      Pull(session)
      session.Advance(3)
      EndPull(session)
      local lines = ProbeLines(session, "event=meter")
      Assert.Equal(#lines, 4, "one snapshot has Overall/Current x DamageDone/Interrupts")
      Assert.NotNil(
        FindLine(
          lines,
          "phase=between_pulls session=Overall(0) meter=Interrupts(5) present=yes sources=2 secretEntries=0 "
            .. "secretNames=0 secretAmounts=0 values=Tester:12,Peer1:3"
        ),
        "readable interrupt sources are logged as name:value"
      )
      Assert.NotNil(
        FindLine(lines, "session=Current(1) meter=DamageDone(0) present=yes sources=2"),
        "the Current session is read as well"
      )

      session.Advance(11)
      session.active = false
      session.Dispatch("CHALLENGE_MODE_COMPLETED")
      Assert.NotNil(FindLine(ProbeLines(session), "event=key_end trigger=CHALLENGE_MODE_COMPLETED"), "key end line")
      Assert.NotNil(
        FindLine(ProbeLines(session, "event=meter"), "phase=key_completed session=Overall(0)"),
        "the meter is read at the key end"
      )
      session.Advance(6)
      Assert.NotNil(
        FindLine(ProbeLines(session, "event=meter"), "phase=key_completed+5s session=Overall(0)"),
        "and once more five seconds later"
      )
    end, Prepare())
  end)

  test("Probe mode logs masked damage meter sessions as secret without converting them", function()
    local secret, secretGlobals = ctx.fixtures.MakeStrictSecret("string")
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      Pull(session)
      EndPull(session)
      local lines = ProbeLines(session, "event=meter")
      Assert.NotNil(
        FindLine(
          lines,
          "session=Overall(0) meter=Interrupts(5) present=yes sources=3 secretEntries=1 secretNames=2 "
            .. "secretAmounts=2 values=none"
        ),
        "masked names and amounts are counted, never converted"
      )
      Assert.NotNil(
        FindLine(lines, "session=Current(1) meter=Interrupts(5) present=yes sources=secret"),
        "a masked combatSources list is reported as secret"
      )
      Assert.NotNil(
        FindLine(lines, "session=Current(1) meter=DamageDone(0) present=secret"),
        "a masked session is reported as secret"
      )
      for _, line in ipairs(lines) do
        Assert.Nil(tostring(line):find("table:", 1, true), "no secret is ever stringified: " .. tostring(line))
      end
    end, function(globals, session)
      Prepare({
        meter = function(sessionType, meterType)
          if sessionType == SESSION_CURRENT and meterType == METER_DAMAGE then
            return secret
          end
          if sessionType == SESSION_CURRENT then
            return { combatSources = secret }
          end
          return {
            combatSources = {
              { name = secret, totalAmount = secret },
              { name = secret, totalAmount = secret },
              secret,
            },
          }
        end,
      })(globals, session)
      for key, value in pairs(secretGlobals) do
        globals[key] = value
      end
    end)
  end)

  test("Probe mode logs a missing damage meter API", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      Pull(session)
      EndPull(session)
      Assert.NotNil(
        FindLine(ProbeLines(session), "event=meter phase=between_pulls api=missing"),
        "a client without C_DamageMeter gets one api=missing line"
      )
    end, Prepare({ noMeterApi = true }))
  end)

  test("Probe mode samples nameplate threat two seconds into a key pull", function()
    local secret, secretGlobals = ctx.fixtures.MakeStrictSecret("number")
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      session.plates.nameplate1 = { hostile = true, threat = 3 }
      session.plates.nameplate2 = { hostile = true, threat = 0 }
      session.plates.nameplate3 = { hostile = secret, threat = secret }
      session.plates.nameplate4 = { hostile = false, threat = 1 }
      session.selfThreat = 2
      Pull(session)
      session.Advance(1)
      Assert.Equal(select(2, ProbeLines(session, "event=threat")), 0, "the sample waits two seconds")
      session.Advance(1.5)
      local line = FindLine(ProbeLines(session, "event=threat"), "event=threat")
      Assert.NotNil(line, "one threat line per pull")
      Assert.NotNil(
        tostring(line):find(
          "inKey=yes self=2 plates=4 hostile=2 hostileSecret=1 threat0=1 threat1=0 threat2=0 threat3=1 "
            .. "threatNil=0 threatSecret=1 threatOther=0",
          1,
          true
        ),
        "hostile plates and secret answers are counted: " .. tostring(line)
      )
    end, function(globals, session)
      Prepare()(globals, session)
      for key, value in pairs(secretGlobals) do
        globals[key] = value
      end
    end)
  end)

  test("Probe mode logs the one-argument own threat as secret without converting it", function()
    local secret, secretGlobals = ctx.fixtures.MakeStrictSecret("number")
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      session.selfThreat = secret
      Pull(session)
      session.Advance(2.5)
      local line = FindLine(ProbeLines(session, "event=threat"), "event=threat")
      Assert.NotNil(line, "one threat line per pull")
      Assert.NotNil(tostring(line):find("self=secret plates=0", 1, true), "a masked own threat: " .. tostring(line))
    end, function(globals, session)
      Prepare()(globals, session)
      for key, value in pairs(secretGlobals) do
        globals[key] = value
      end
    end)
  end)

  test("Probe mode logs own buff and weapon enchant readability on a ready check", function()
    local secret, secretGlobals = ctx.fixtures.MakeStrictSecret("number")
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      session.auras = {
        { spellId = 1234, expirationTime = 100 },
        { spellId = secret, expirationTime = secret },
        secret,
      }
      session.weapon = { true, 3600000, 0, 7495, false, nil, 0, nil }
      session.Dispatch("READY_CHECK", "Tester")
      local line = FindLine(ProbeLines(session, "event=ready_check"), "event=ready_check")
      Assert.NotNil(line, "one line per ready check")
      Assert.NotNil(
        tostring(line):find(
          "inKey=yes inInstance=true inCombat=no auras=3 auraSecret=1 spellIdSecret=1 expirationSecret=1 "
            .. "auraErrors=0 bySpellID=readable mh=yes mhMin=60 mhEnchant=7495 oh=no ohMin=nil ohEnchant=nil",
          1,
          true
        ),
        "buffs, masked fields and weapon slots are described: " .. tostring(line)
      )
      Assert.NotNil(
        tostring(line):find("spellIDs=1234", 1, true),
        "the readable own buff IDs are listed for the consumable season data: " .. tostring(line)
      )

      session.auras = {}
      session.weapon = { secret, secret, 0, secret, false, nil, 0, nil }
      session.Dispatch("READY_CHECK", "Tester")
      local lines = ProbeLines(session, "event=ready_check")
      local last = tostring(lines[#lines])
      Assert.NotNil(
        last:find(
          "auras=0 auraSecret=0 spellIdSecret=0 expirationSecret=0 auraErrors=0 bySpellID=no_candidate",
          1,
          true
        ),
        "no buffs leave nothing to look up: " .. last
      )
      Assert.NotNil(
        last:find("mh=secret mhMin=secret mhEnchant=secret", 1, true),
        "a masked weapon slot is written as secret: " .. last
      )
    end, function(globals, session)
      Prepare()(globals, session)
      for key, value in pairs(secretGlobals) do
        globals[key] = value
      end
    end)
  end)

  test("Probe mode logs own cast readability once per spell and run", function()
    local secret, secretGlobals = ctx.fixtures.MakeStrictSecret("number")
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      Pull(session)
      Kick(session)
      session.Advance(30)
      Kick(session)
      Deliver(session, "UNIT_SPELLCAST_SUCCEEDED", "player", secret, FIREBALL)
      Deliver(session, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", secret)
      Deliver(session, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", secret)
      local lines, total = ProbeLines(session, "event=own_cast")
      Assert.Equal(total, 3, "one line per spell and run")
      Assert.NotNil(
        FindLine(lines, "unit=player spellID=2139 spellIDSecret=no castGUID=readable kick=yes inKey=yes"),
        "a readable own kick"
      )
      Assert.NotNil(
        FindLine(lines, "spellID=133 spellIDSecret=no castGUID=secret kick=no"),
        "a secret castGUID is named, not converted"
      )
      Assert.NotNil(FindLine(lines, "spellID=secret spellIDSecret=yes"), "a secret spell ID is named, not converted")
    end, function(globals, session)
      Prepare()(globals, session)
      for key, value in pairs(secretGlobals) do
        globals[key] = value
      end
    end)
  end)

  test("Probe mode logs kick calibration timings with the missed-kick alert off", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      Pull(session)
      Kick(session)
      session.Advance(0.1)
      HostileInterrupt(session)
      session.Advance(1)
      local landed = FindLine(ProbeLines(session, "event=kick "), "event=kick")
      Assert.NotNil(landed, "a kick line after the one second lookahead")
      Assert.NotNil(
        tostring(landed):find(
          "spellID=2139 inKey=yes inCombat=yes alert=off window_ms=250 verdict=landed "
            .. "firstInterruptAfterMs=100 firstEvent=UNIT_SPELLCAST_INTERRUPTED interruptBeforeCastMs=none",
          1,
          true
        ),
        "delta from cast to the first hostile interrupt: " .. tostring(landed)
      )

      session.Advance(30)
      Kick(session)
      session.Advance(1.1)
      Assert.NotNil(
        FindLine(ProbeLines(session, "event=kick "), "verdict=missed firstInterruptAfterMs=none firstEvent=none"),
        "no interrupt within one second"
      )

      session.Advance(30)
      HostileInterrupt(session)
      session.Advance(0.03)
      Kick(session)
      session.Advance(0.4)
      HostileInterrupt(session)
      session.Advance(1)
      Assert.NotNil(
        FindLine(ProbeLines(session, "event=kick "), "verdict=missed firstInterruptAfterMs=400"),
        "an interrupt after the window does not land the kick"
      )
      Assert.NotNil(
        FindLine(ProbeLines(session, "event=kick "), "interruptBeforeCastMs=30"),
        "the teammate interrupt before the cast is timed"
      )
      Assert.Equal(select(2, ProbeLines(session, "event=kick ")), 3, "one line per own kick")
    end, Prepare())
  end)

  test("Probe mode logs chat lockdown transitions and restriction changes with enum names", function()
    local secret, secretGlobals = ctx.fixtures.MakeStrictSecret("number")
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      local lines = ProbeLines(session, "event=chat_lockdown")
      Assert.NotNil(FindLine(lines, "at=key_start inKey=yes value=no prev=unknown"), "first reading at the key start")
      session.lockdown = true
      Pull(session)
      session.lockdown = false
      EndPull(session)
      lines = ProbeLines(session, "event=chat_lockdown")
      Assert.NotNil(FindLine(lines, "at=combat_start inKey=yes value=yes prev=no"), "lockdown on at the pull")
      Assert.NotNil(FindLine(lines, "at=combat_end inKey=yes value=no prev=yes"), "lockdown off after the pull")
      local before = select(2, ProbeLines(session, "event=chat_lockdown"))
      Pull(session)
      Assert.Equal(select(2, ProbeLines(session, "event=chat_lockdown")), before, "only transitions are logged")

      session.Dispatch("ADDON_RESTRICTION_STATE_CHANGED", 2, 2)
      session.Dispatch("ADDON_RESTRICTION_STATE_CHANGED", secret, secret)
      session.Dispatch("ADDON_RESTRICTION_STATE_CHANGED", 9, 0)
      lines = ProbeLines(session, "event=restriction")
      Assert.NotNil(FindLine(lines, "type=ChallengeMode(2) state=Active(2) inKey=yes"), "enum names resolved")
      Assert.NotNil(FindLine(lines, "type=secret state=secret"), "secret payload is named, not converted")
      Assert.NotNil(FindLine(lines, "type=unnamed(9) state=Inactive(0)"), "unknown enum values stay numeric")
    end, function(globals, session)
      Prepare()(globals, session)
      for key, value in pairs(secretGlobals) do
        globals[key] = value
      end
    end)
  end)

  test("Probe mode reads the damage meter after a key outside the instance and on a lifted restriction", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      session.active = false
      session.Dispatch("CHALLENGE_MODE_COMPLETED")
      session.Advance(20)
      session.Dispatch("ADDON_RESTRICTION_STATE_CHANGED", 2, 0)
      Assert.NotNil(
        FindLine(ProbeLines(session, "event=meter"), "phase=post_key_restriction_lifted session=Overall(0)"),
        "a lifted restriction after the key reads the meter"
      )
      session.Dispatch("ZONE_CHANGED_NEW_AREA")
      Assert.Nil(
        FindLine(ProbeLines(session, "event=meter"), "phase=post_key_outside_instance"),
        "still inside the instance: no outside snapshot"
      )
      session.inInstance = false
      session.Dispatch("ZONE_CHANGED_NEW_AREA")
      Assert.NotNil(
        FindLine(ProbeLines(session, "event=meter"), "phase=post_key_outside_instance session=Overall(0)"),
        "a readable outside-the-instance reads the meter"
      )
    end, Prepare())
  end)

  test("Probe mode throttles meter snapshots and caps every probe per run", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      session.plates.nameplate1 = { hostile = true, threat = 3 }
      Pull(session)
      EndPull(session)
      Pull(session)
      session.Advance(1)
      EndPull(session)
      Assert.Equal(select(2, ProbeLines(session, "event=meter")), 4, "one snapshot per 10 s and phase")

      for _ = 1, 100 do
        session.Advance(11)
        Pull(session)
        session.Advance(2.5)
        EndPull(session)
      end
      local limits = session.addon.ProbeLog.LIMITS
      Assert.Equal(
        select(2, ProbeLines(session, "event=meter")),
        limits.meterSnapshotsPerRun * 4,
        "meter snapshots are capped per run"
      )
      Assert.Equal(
        select(2, ProbeLines(session, "event=threat")),
        limits.threatPullsPerRun,
        "threat samples are capped per run"
      )
      Assert.Equal(select(2, ProbeLines(session, "event=cap_reached probe=meter")), 1, "one cap line per probe")
      Assert.Equal(select(2, ProbeLines(session, "event=cap_reached probe=threat")), 1, "one cap line per probe")

      session.Dispatch("CHALLENGE_MODE_START")
      Pull(session)
      session.Advance(2.5)
      Assert.NotNil(FindLine(ProbeLines(session), "event=key_start"), "a new key starts a new budget")
      Assert.Equal(
        select(2, ProbeLines(session, "event=threat")),
        limits.threatPullsPerRun + 1,
        "the next key samples again"
      )
    end, Prepare())
  end)

  test("Probe slash command toggles persists and reports status", function()
    Stress.WithParty(ctx, FixtureWithSchema, function(session)
      local db = session.globals.IsiLiveDB
      local slash = session.globals.SlashCmdList.ISILIVE
      slash("probe")
      Assert.True(db.probeLogEnabled, "no argument toggles probe mode on")
      Assert.NotNil(FindLine(session.printed, "Probe mode ON"), "localized confirmation")
      Assert.Nil(FindLine(session.printed, "The runtime log is off"), "no hint: probe mode switched the runtime log on")
      Assert.NotNil(FindLine(ProbeLines(session), "event=probe_enabled"), "enabling writes a probe line")
      Assert.NotNil(FindLine(ProbeLines(session), "event=probe_session"), "with a session header")
      Assert.True(db.runtimeLogEnabled, "probe mode switches the runtime log on for the context lines")

      session.printed = {}
      slash("probe status")
      Assert.NotNil(
        FindLine(session.printed, "Probe mode: ON | runtime log: ON | probe lines this session: 2"),
        "status"
      )

      slash("probe")
      Assert.False(db.probeLogEnabled, "no argument toggles probe mode off again")
      Assert.NotNil(FindLine(ProbeLines(session), "event=probe_disabled"), "disabling writes a last probe line")
      slash("probe on")
      Assert.True(db.probeLogEnabled, "on")
      slash("probe off")
      Assert.False(db.probeLogEnabled, "off persists as false")
      Assert.Equal(type(db.probeLogEnabled), "boolean", "the saved value is a plain boolean")
    end, Prepare({ probe = false }))
  end)

  -- Probe report (rule 239): every flow below writes its lines through the
  -- real ProbeLog hooks (real dispatcher, real kick tracker, real runtime log
  -- ring) and reads the verdicts back through the real slash command.
  local function Report(session)
    session.printed = {}
    session.globals.SlashCmdList.ISILIVE("probe report")
    return session.printed
  end

  local function AssertReportLine(printed, expected, label)
    Assert.NotNil(FindLine(printed, expected), label .. ": " .. table.concat(printed, " || "))
  end

  local function AssertNoStringifiedSecret(printed)
    for _, line in ipairs(printed) do
      Assert.Nil(tostring(line):find("table:", 1, true), "no secret is ever stringified: " .. tostring(line))
    end
  end

  test("Probe report gives yes verdicts from readable probe lines", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      session.plates.nameplate1 = { hostile = true, threat = 3 }
      session.selfThreat = 2
      session.lockdown = true
      Pull(session)
      Kick(session)
      session.Advance(0.1)
      HostileInterrupt(session)
      session.Advance(2.5)
      session.lockdown = false
      EndPull(session)
      session.auras = { { spellId = 1234, expirationTime = 100 } }
      session.weapon = { true, 3600000, 0, 7495, false, nil, 0, nil }
      session.Dispatch("READY_CHECK", "Tester")
      session.Dispatch("ADDON_RESTRICTION_STATE_CHANGED", 2, 2)
      session.Advance(11)
      session.active = false
      session.Dispatch("CHALLENGE_MODE_COMPLETED")
      session.Advance(20)
      session.inInstance = false
      session.Dispatch("ZONE_CHANGED_NEW_AREA")

      local printed = Report(session)
      AssertReportLine(printed, "key starts in the runtime log):", "header")
      AssertReportLine(printed, "1 key starts", "one key start in the ring")
      AssertReportLine(
        printed,
        "K9 damage meter between pulls readable: yes (1 snapshots, 0 secret)",
        "readable meter between pulls"
      )
      AssertReportLine(
        printed,
        "K11 damage meter after the key: at the key end yes (2 snapshots, 0 secret), later yes (1 snapshots, 0 secret)",
        "key end, +5 s and the outside snapshot"
      )
      AssertReportLine(
        printed,
        "K6 threat in the key: per nameplate yes (1 readable, 0 secret), own threat yes (1 readable, 0 secret), "
          .. "UnitCanAttack secret: 0",
        "readable threat"
      )
      AssertReportLine(
        printed,
        "K4 ready check: own buffs yes (1 readable, 0 secret), weapon enchant yes (1 readable, 0 secret)",
        "readable ready check"
      )
      AssertReportLine(
        printed,
        "Own interrupt spell IDs readable: yes (1 kick spells readable, 0 own casts with a secret spell ID)",
        "readable kick spell ID"
      )
      AssertReportLine(
        printed,
        "Chat lockdown seen in the key: yes (3 readings in the key, 0 secret)",
        "key start no, pull yes, pull end no"
      )
      AssertReportLine(
        printed,
        "K3 kick timing: 1 kicks, 1 landed, 0 missed, 0 excluded; ms to the first hostile interrupt "
          .. "min/median/max 100/100/100 (1 timed)",
        "landed kick timing"
      )
      AssertReportLine(
        printed,
        "Restriction changes seen: yes (1 changes, 0 secret; types: ChallengeMode)",
        "restriction change"
      )
      Assert.Nil(FindLine(printed, "Probe budgets reached"), "no budget was reached")
      Assert.Equal(
        select(2, ProbeLines(session, "Probe report")),
        0,
        "the report is printed without being written into the ring it reads"
      )
    end, Prepare())
  end)

  test("Probe report gives no verdicts from masked probe lines", function()
    local secret, secretGlobals = ctx.fixtures.MakeStrictSecret("number")
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      session.plates.nameplate1 = { hostile = secret, threat = secret }
      session.selfThreat = secret
      Pull(session)
      Deliver(session, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", secret)
      session.Advance(2.5)
      EndPull(session)
      session.auras = { secret }
      session.weapon = { secret, secret, 0, secret, false, nil, 0, nil }
      session.Dispatch("READY_CHECK", "Tester")
      session.Dispatch("ADDON_RESTRICTION_STATE_CHANGED", secret, secret)
      session.Advance(11)
      session.active = false
      session.Dispatch("CHALLENGE_MODE_COMPLETED")
      session.Advance(20)
      session.inInstance = false
      session.Dispatch("ZONE_CHANGED_NEW_AREA")

      local printed = Report(session)
      AssertReportLine(
        printed,
        "K9 damage meter between pulls readable: no (1 snapshots, 1 secret)",
        "masked meter between pulls"
      )
      AssertReportLine(
        printed,
        "K11 damage meter after the key: at the key end no (2 snapshots, 2 secret), later no (1 snapshots, 1 secret)",
        "masked meter after the key"
      )
      AssertReportLine(
        printed,
        "K6 threat in the key: per nameplate no (0 readable, 1 secret), own threat no (0 readable, 1 secret), "
          .. "UnitCanAttack secret: 1",
        "masked threat"
      )
      AssertReportLine(
        printed,
        "K4 ready check: own buffs no (0 readable, 1 secret), weapon enchant no (0 readable, 1 secret)",
        "masked ready check"
      )
      AssertReportLine(
        printed,
        "Own interrupt spell IDs readable: no (0 kick spells readable, 1 own casts with a secret spell ID)",
        "every own cast masked"
      )
      AssertReportLine(
        printed,
        "Chat lockdown seen in the key: unknown (1 readings in the key, 1 secret)",
        "a masked lockdown answers nothing"
      )
      AssertReportLine(printed, "K3 kick timing: unknown (no kick lines)", "no kick")
      AssertReportLine(
        printed,
        "Restriction changes seen: yes (1 changes, 1 secret; types: -)",
        "a masked restriction change is seen but unnamed"
      )
      AssertNoStringifiedSecret(printed)
    end, function(globals, session)
      Prepare({
        meter = function()
          return secret
        end,
      })(globals, session)
      session.lockdown = secret
      for key, value in pairs(secretGlobals) do
        globals[key] = value
      end
    end)
  end)

  test("Probe report says unknown without probe data", function()
    Stress.WithParty(ctx, FixtureWithSchema, function(session)
      local printed = Report(session)
      Assert.Equal(#printed, 1, "one line without probe data")
      AssertReportLine(printed, "Probe report: no [PROBE] lines in the runtime log.", "empty ring")
      Assert.False(session.globals.IsiLiveDB.probeLogEnabled == true, "the report does not switch probe mode on")

      session.globals.SlashCmdList.ISILIVE("probe on")
      printed = Report(session)
      AssertReportLine(printed, "Probe report (2 probe lines, 0 key starts in the runtime log):", "header")
      AssertReportLine(printed, "between pulls readable: unknown (0 snapshots, 0 secret)", "no meter data")
      AssertReportLine(
        printed,
        "at the key end unknown (0 snapshots, 0 secret), later unknown (0 snapshots, 0 secret)",
        "no meter data after a key"
      )
      AssertReportLine(printed, "per nameplate unknown (0 readable, 0 secret), own threat unknown", "no threat")
      AssertReportLine(printed, "own buffs unknown (0 readable, 0 secret), weapon enchant unknown", "no ready check")
      AssertReportLine(printed, "Own interrupt spell IDs readable: unknown (0 kick spells", "no own cast")
      AssertReportLine(printed, "Chat lockdown seen in the key: unknown (0 readings", "no lockdown reading")
      AssertReportLine(printed, "K3 kick timing: unknown (no kick lines)", "no kick")
      AssertReportLine(printed, "Restriction changes seen: unknown (0 changes, 0 secret; types: -)", "no change")

      session.runtime.SetLanguage("deDE")
      printed = Report(session)
      AssertReportLine(printed, "Probe-Bericht (2 Probe-Zeilen, 0 Key-Starts im Laufzeit-Log):", "German header")
      AssertReportLine(
        printed,
        "K9 Schadensmesser zwischen Pulls lesbar: unbekannt (0 Schnappschüsse, 0 secret)",
        "German verdict"
      )
    end, Prepare({ probe = false }))
  end)

  test("Probe report mixes readable and masked answers and tolerates broken lines", function()
    local secret, secretGlobals = ctx.fixtures.MakeStrictSecret("number")
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      session.plates.nameplate1 = { hostile = true, threat = 3 }
      session.plates.nameplate2 = { hostile = secret, threat = secret }
      session.selfThreat = 1
      Pull(session)
      Kick(session)
      session.Advance(0.1)
      HostileInterrupt(session)
      session.Advance(2.5)
      EndPull(session)

      session.meterSecret = true
      session.selfThreat = secret
      session.Advance(30)
      Pull(session)
      Kick(session)
      session.Advance(2.5)
      EndPull(session)

      session.Advance(30)
      HostileInterrupt(session)
      session.Advance(0.03)
      Kick(session)
      session.Advance(0.4)
      HostileInterrupt(session)
      session.Advance(1)

      local limits = session.addon.ProbeLog.LIMITS
      for index = 1, limits.restrictionLinesPerRun + 1 do
        session.Dispatch("ADDON_RESTRICTION_STATE_CHANGED", index % 2 == 0 and 0 or 2, 2)
      end

      -- HAND-WRITTEN: the current writer cannot produce an older or a
      -- truncated line, so these four are appended as literals through the
      -- real ring: a threat line from before the `self=` field, a meter and a
      -- kick line without fields, and a probe tag without an event.
      local runtimeLog = session.runtime.runtimeLogController
      runtimeLog.AppendLog(
        "[PROBE] event=threat phase=pull_start+2s inKey=yes plates=1 hostile=1 hostileSecret=0 threat0=0 "
          .. "threat1=0 threat2=0 threat3=1 threatNil=0 threatSecret=0 threatOther=0"
      )
      runtimeLog.AppendLog("[PROBE] event=meter phase=between_pulls")
      runtimeLog.AppendLog("[PROBE] event=kick")
      runtimeLog.AppendLog("[PROBE] event= broken")

      local printed = Report(session)
      AssertReportLine(
        printed,
        "K9 damage meter between pulls readable: partly (3 snapshots, 1 secret)",
        "one readable, one masked and one empty snapshot"
      )
      AssertReportLine(
        printed,
        "K6 threat in the key: per nameplate partly (3 readable, 2 secret), own threat partly (1 readable, 1 secret), "
          .. "UnitCanAttack secret: 2",
        "two samples with a readable and a masked plate plus the old line without self="
      )
      AssertReportLine(
        printed,
        "Own interrupt spell IDs readable: yes (1 kick spells readable, 0 own casts with a secret spell ID)",
        "the kick spell is logged once per run"
      )
      AssertReportLine(
        printed,
        "K3 kick timing: 4 kicks, 1 landed, 2 missed, 0 excluded; ms to the first hostile interrupt "
          .. "min/median/max 100/100/400 (2 timed)",
        "lower median of the logged timings; the empty kick line counts without a verdict"
      )
      AssertReportLine(
        printed,
        "Restriction changes seen: yes (80 changes, 0 secret; types: ChallengeMode, Combat)",
        "restriction lines up to the budget"
      )
      AssertReportLine(printed, "Probe budgets reached: restriction x1", "the cap_reached line is reported")
      AssertNoStringifiedSecret(printed)
    end, function(globals, session)
      Prepare({
        meter = function(sessionType, meterType)
          if session.meterSecret then
            return secret
          end
          return ReadableMeter(sessionType, meterType)
        end,
      })(globals, session)
      for key, value in pairs(secretGlobals) do
        globals[key] = value
      end
    end)
  end)

  test("Probe mode widens the ring and is switched off again by every load", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      local db = session.globals.IsiLiveDB
      local probe = session.addon.ProbeLog
      Assert.Equal(probe.GetRingEntries(), probe.RING_ENTRIES_PROBE, "probe mode widens the ring")
      local controller = session.runtime.runtimeLogController
      for index = 1, probe.RING_ENTRIES_DEFAULT + 50 do
        controller.AppendLog("[TEST] filler " .. index)
      end
      Assert.Equal(
        select(2, controller.GetLogTailFiltered(1, "event=filler")),
        probe.RING_ENTRIES_DEFAULT + 50,
        "the wider ring keeps more than the default size"
      )
      session.Dispatch("ADDON_LOADED", "isiLive")
      Assert.False(db.probeLogEnabled, "admin tool: every load (reload, relog) switches probe mode off")
      Assert.False(db.runtimeLogEnabled, "and the runtime log with it")
      Assert.Equal(probe.GetRingEntries(), probe.RING_ENTRIES_DEFAULT, "probe off: default ring size")
      Assert.True(
        select(2, controller.GetLogTailFiltered(1, "event=filler")) <= probe.RING_ENTRIES_DEFAULT,
        "probe off trims the ring to the default size"
      )
    end, Prepare())
  end)

  test("Probe mode off leaves the runtime log off after a reload", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      session.Dispatch("ADDON_LOADED", "isiLive")
      Assert.False(session.globals.IsiLiveDB.runtimeLogEnabled, "the load reset stays in force")
    end, Prepare({ probe = false }))
  end)

  test("Switching probe mode on switches the runtime log on", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      local db = session.globals.IsiLiveDB
      Assert.False(db.runtimeLogEnabled == true, "precondition: runtime log off")
      session.addon.ProbeLog.SetEnabled(true)
      Assert.True(db.runtimeLogEnabled, "probe on brings the context lines along")
    end, Prepare({ probe = false }))
  end)

  test("Probe mode tells the reset before a key start apart from an abandoned key", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      session.active = false
      session.Dispatch("CHALLENGE_MODE_COMPLETED")
      Assert.NotNil(
        FindLine(ProbeLines(session), "event=key_end trigger=CHALLENGE_MODE_COMPLETED kind=completed"),
        "a completed key"
      )
      session.Advance(30)
      session.Dispatch("CHALLENGE_MODE_RESET")
      Assert.NotNil(
        FindLine(ProbeLines(session), "event=challenge_reset kind=no_running_key"),
        "the reset the client fires before a key start is no key end"
      )
      Assert.Equal(select(2, ProbeLines(session, "event=key_end")), 1, "still one key end")
      session.Advance(0.25)
      session.active = true
      session.Dispatch("CHALLENGE_MODE_START")
      Assert.NotNil(
        FindLine(ProbeLines(session), "event=key_start mapID=2662 resetBeforeStartMs=250"),
        "the key start names the gap to the reset before it"
      )
      session.Advance(60)
      session.Dispatch("CHALLENGE_MODE_RESET")
      Assert.NotNil(
        FindLine(ProbeLines(session), "event=key_end trigger=CHALLENGE_MODE_RESET kind=abandoned"),
        "a reset inside a running key is an abandoned key"
      )
    end, Prepare())
  end)

  test("Probe mode logs every hostile channel stop with the presence of interruptedBy", function()
    local secret, secretGlobals = ctx.fixtures.MakeStrictSecret("string")
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      Pull(session)
      Deliver(session, "UNIT_SPELLCAST_CHANNEL_STOP", "nameplate3", "chan-1", 4321, nil)
      Kick(session)
      Deliver(session, "UNIT_SPELLCAST_CHANNEL_STOP", "nameplate4", "chan-2", 4321, "Player-1-00000001")
      Deliver(session, "UNIT_SPELLCAST_CHANNEL_STOP", "nameplate5", "chan-3", 4321, secret)
      Deliver(session, "UNIT_SPELLCAST_CHANNEL_STOP", "party1", "chan-4", 4321, nil)
      local lines = ProbeLines(session, "event=channel_stop")
      Assert.Equal(#lines, 3, "hostile units only")
      Assert.NotNil(
        FindLine(lines, "unit=nameplate3 interruptedBy=nil ownKickPendingMs=none inKey=yes"),
        "a channel that simply ends"
      )
      Assert.NotNil(
        FindLine(lines, "unit=nameplate4 interruptedBy=readable ownKickPendingMs=0"),
        "a kicked channel right after the own kick"
      )
      Assert.NotNil(FindLine(lines, "unit=nameplate5 interruptedBy=secret"), "a masked interruptedBy is never read")
      session.Advance(2)
      Assert.NotNil(
        FindLine(ProbeLines(session, "event=kick spellID="), "firstEvent=UNIT_SPELLCAST_CHANNEL_STOP"),
        "the kicked channel still counts for the kick verdict"
      )
    end, function(globals, session)
      Prepare()(globals, session)
      for key, value in pairs(secretGlobals) do
        globals[key] = value
      end
    end)
  end)

  test("Probe mode logs blocked protected calls of isiLive only", function()
    Stress.WithKey(ctx, FixtureWithSchema, function(session)
      local probe = session.addon.ProbeLog
      local frame = probe._actionBlockedFrame
      Assert.NotNil(frame, "the event frame is created in the main chunk")
      local onEvent = frame:GetScript("OnEvent")
      session.combat = true
      onEvent(frame, "ADDON_ACTION_BLOCKED", "isiLive", "isiLiveResizeGrip:Hide()")
      onEvent(frame, "ADDON_ACTION_FORBIDDEN", "OtherAddon", "CastSpellByName()")
      onEvent(frame, "ADDON_ACTION_FORBIDDEN", "isiLive", "SetRaidTarget()")
      local lines = ProbeLines(session, "event=action_blocked")
      Assert.Equal(#lines, 2, "other addons are ignored")
      Assert.NotNil(
        FindLine(lines, "kind=blocked func=isiLiveResizeGrip:Hide() inCombat=yes inKey=yes"),
        "blocked call with its context"
      )
      Assert.NotNil(FindLine(lines, "kind=forbidden func=SetRaidTarget()"), "forbidden call")
      probe.SetEnabled(false)
      onEvent(frame, "ADDON_ACTION_BLOCKED", "isiLive", "Show()")
      Assert.Equal(select(2, ProbeLines(session, "event=action_blocked")), 2, "probe off: nothing logged")
    end, Prepare())
  end)

  test("DBSchema declares probeLogEnabled as a default-off boolean", function()
    ctx.with_globals({}, function()
      local addon = ctx.load_modules({ "isiLive_db_schema.lua" })
      Assert.True(addon.DBSchema.GetKnownFieldNames().probeLogEnabled == true, "known schema field")
      local fresh = {}
      addon.DBSchema.Sanitize(fresh)
      Assert.Equal(fresh.probeLogEnabled, false, "a fresh install starts with probe mode off")
      local broken = { probeLogEnabled = "yes" }
      addon.DBSchema.Sanitize(broken)
      Assert.Equal(broken.probeLogEnabled, false, "a non-boolean value is repaired to off")
      local kept = { probeLogEnabled = true }
      addon.DBSchema.Sanitize(kept)
      Assert.True(kept.probeLogEnabled, "an enabled probe mode survives the schema pass")
    end)
  end)
end
