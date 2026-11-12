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
      Assert.NotNil(FindLine(session.printed, "The runtime log is off"), "hint while the runtime log is off")
      Assert.NotNil(FindLine(ProbeLines(session), "event=probe_enabled"), "enabling writes a probe line")
      Assert.NotNil(FindLine(ProbeLines(session), "event=probe_session"), "with a session header")
      Assert.False(db.runtimeLogEnabled == true, "the runtime log switch is left untouched")

      session.printed = {}
      slash("probe status")
      Assert.NotNil(
        FindLine(session.printed, "Probe mode: ON | runtime log: OFF | probe lines this session: 2"),
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
