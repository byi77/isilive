---@diagnostic disable: undefined-global, undefined-field, unused-local

-- Builds the minimal WoW global stubs needed to load isiLive_combat_events.lua.
-- Returns the captured onEvent handler so tests can inject events directly,
-- plus the accumulated print buffer.
local function BuildCombatEventsEnv(overrides)
  overrides = overrides or {}

  local onEvent = nil
  local prints = {}
  local registered = {}

  local globals = {
    CreateFrame = function()
      return {
        RegisterEvent = function(_, event)
          registered[event] = true
        end,
        UnregisterEvent = function(_, event)
          registered[event] = nil
        end,
        SetScript = function(_, scriptType, fn)
          if scriptType == "OnEvent" then
            onEvent = fn
          end
        end,
      }
    end,
    DEFAULT_CHAT_FRAME = {
      AddMessage = function(_, msg)
        table.insert(prints, tostring(msg))
      end,
    },
    GetTime = overrides.GetTime or function()
      return 0
    end,
    C_ChallengeMode = overrides.C_ChallengeMode or {
      GetActiveChallengeMapID = function()
        return 0
      end,
    },
  }

  if overrides.globals then
    for k, v in pairs(overrides.globals) do
      globals[k] = v
    end
  end

  return globals,
    function(event, ...)
      local addon = rawget(_G, "__isilive_last_loaded_addon")
      if addon and addon.CombatEvents and type(addon.CombatEvents.HandleEvent) == "function" then
        addon.CombatEvents.HandleEvent(event, ...)
      elseif onEvent then
        onEvent(nil, event, ...)
      end
    end,
    prints,
    registered
end

local function RegisterCombatEventsAutoRegistrationTests(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("CombatEvents exposes central event handler and creates no direct event frame on load", function()
    local globals, _, _, registered = BuildCombatEventsEnv()
    local addon
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    -- COMBAT_LOG_EVENT_UNFILTERED was removed from the addon API in 12.0.0
    -- and raises ADDON_ACTION_FORBIDDEN on registration. We listen to
    -- UNIT_SPELLCAST_SUCCEEDED (not taint-sensitive) instead.
    Assert.Equal(type(addon.CombatEvents.HandleEvent), "function", "must expose HandleEvent for central dispatch")
    Assert.Nil(
      registered["UNIT_SPELLCAST_SUCCEEDED"],
      "module load must not directly register UNIT_SPELLCAST_SUCCEEDED"
    )
    Assert.Nil(registered["CHALLENGE_MODE_START"], "module load must not directly register CHALLENGE_MODE_START")
    Assert.Nil(
      registered["CHALLENGE_MODE_COMPLETED"],
      "module load must not directly register CHALLENGE_MODE_COMPLETED"
    )
    Assert.Nil(registered["COMBAT_LOG_EVENT_UNFILTERED"], "must NOT register CLEU (forbidden in 12.0.0)")
  end)
end

local function BuildController(opts)
  opts = opts or {}
  local broadcasts = opts.broadcasts or {}
  local nowRef = opts.nowRef or { value = 0 }
  local inKeyRef = opts.inKeyRef or { value = true }
  local dbRef = opts.dbRef or { value = {} }
  local nameMap = opts.nameMap or {
    player = "Alice-Realm",
  }

  local addon = opts.addon
  return addon.CombatEvents.CreateController({
    getTime = function()
      return nowRef.value
    end,
    isInKey = function()
      return inKeyRef.value == true
    end,
    getUnitName = function(unit)
      return nameMap[unit] or unit
    end,
    broadcastCombatAnnounce = function(kind, sourceName, spellID)
      table.insert(broadcasts, { kind = kind, caster = sourceName, spellID = spellID })
    end,
    getDB = function()
      return dbRef.value
    end,
  })
end

local function RegisterCombatEventsBRTests(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("CombatEvents broadcasts own BR when in key", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller = BuildController({ addon = addon, broadcasts = broadcasts })
    controller.HandleUnitSpellcastSucceeded("player", "cast-1", 20484)
    Assert.Equal(#broadcasts, 1, "must broadcast exactly one BR call")
    Assert.Equal(broadcasts[1].kind, "BR", "broadcast kind must be BR")
    Assert.Equal(
      broadcasts[1].caster,
      "Alice-Realm",
      "broadcast must pass raw unit name (realm strip happens in receiver)"
    )
    Assert.Equal(broadcasts[1].spellID, 20484, "broadcast must include spellID")
  end)

  test("CombatEvents suppresses BR when not in key", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller = BuildController({
      addon = addon,
      broadcasts = broadcasts,
      inKeyRef = { value = false },
    })
    controller.HandleUnitSpellcastSucceeded("player", "cast-1", 20484)
    Assert.Equal(#broadcasts, 0, "no BR broadcast outside M+")
  end)

  test("CombatEvents respects chatAnnounceBR=false toggle", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller = BuildController({
      addon = addon,
      broadcasts = broadcasts,
      dbRef = { value = { chatAnnounceBR = false } },
    })
    controller.HandleUnitSpellcastSucceeded("player", "cast-1", 20484)
    Assert.Equal(#broadcasts, 0, "BR broadcast must be gated by chatAnnounceBR")
  end)

  test("CombatEvents dedups identical BR events within 3s", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local nowRef = { value = 100 }
    local controller = BuildController({ addon = addon, broadcasts = broadcasts, nowRef = nowRef })
    controller.HandleUnitSpellcastSucceeded("player", "cast-1", 20484)
    nowRef.value = 102
    controller.HandleUnitSpellcastSucceeded("player", "cast-2", 20484)
    Assert.Equal(#broadcasts, 1, "second BR within dedup window must be dropped")
    nowRef.value = 104
    controller.HandleUnitSpellcastSucceeded("player", "cast-3", 20484)
    Assert.Equal(#broadcasts, 2, "BR after dedup window elapses must fire again")
  end)

  -- Regression for the in-line expiry sweep introduced in 0.9.234. Without
  -- the sweep, each distinct `sourceName|spellID` pair stayed in `recent`
  -- forever (or until CHALLENGE_MODE_* Reset), so a long session that
  -- hopped raids without entering a key could grow the map unboundedly.
  test("CombatEvents.ShouldDedup sweeps entries that fell out of the 3s window", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local nowRef = { value = 100 }
    local nameMap = {}
    for i = 1, 5 do
      nameMap["player" .. i] = "Caster" .. i .. "-Realm"
    end
    local controller = BuildController({
      addon = addon,
      broadcasts = broadcasts,
      nowRef = nowRef,
      nameMap = nameMap,
    })
    -- HandleUnitSpellcastSucceeded only fires on the literal "player" unit
    -- (Secret-Value safety), so we cannot just iterate party1..party5 to
    -- generate five distinct caster|spell dedup entries. Instead we rebind
    -- nameMap.player to a different "CasterN-Realm" name before each call —
    -- the controller's getUnitName resolves the current binding and ShouldDedup
    -- keys by name, so each call lands as a different caster from the dedup
    -- map's perspective. Helper makes the rebind contract explicit.
    local function fireCastFromCaster(casterIdx, castLabel, atTime)
      nameMap.player = nameMap["player" .. casterIdx]
      nowRef.value = atTime
      controller.HandleUnitSpellcastSucceeded("player", castLabel, 20484)
    end

    fireCastFromCaster(1, "cast-1", 100)
    fireCastFromCaster(2, "cast-2", 100.5)
    fireCastFromCaster(3, "cast-3", 101)
    fireCastFromCaster(4, "cast-4", 101.5)
    fireCastFromCaster(5, "cast-5", 102)
    Assert.Equal(controller._Test_GetRecentSize(), 5, "five distinct caster|spell entries are tracked")

    -- Jump well past the 3s dedup window. The next cast triggers the
    -- in-line sweep before writing its own timestamp, so the four prior
    -- entries from t=100..101.5 must be reaped. The 102/fresh entries
    -- remain — t=102 is still within 3s of t=104.5.
    fireCastFromCaster(1, "cast-6", 104.5)
    Assert.True(
      controller._Test_GetRecentSize() <= 2,
      "expired entries must be reaped on the next ShouldDedup miss; map size = "
        .. tostring(controller._Test_GetRecentSize())
    )

    -- Long-term unbounded check: many more casts spread across an even
    -- bigger time gap shrink the map back to a single fresh entry.
    fireCastFromCaster(2, "cast-7", 200)
    Assert.Equal(
      controller._Test_GetRecentSize(),
      1,
      "after a 3s+ gap with one fresh cast, only the new entry survives the sweep"
    )
  end)

  test("CombatEvents ignores casts from units other than the player", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller = BuildController({ addon = addon, broadcasts = broadcasts })
    -- Only the caster announces their own cast; other non-owned units are
    -- ignored to avoid "table index is secret" from the 12.0.0 Secret Values
    -- system. The owned pet Bloodlust path is covered separately.
    controller.HandleUnitSpellcastSucceeded("party1", "cast-1", 20484)
    controller.HandleUnitSpellcastSucceeded("raid3", "cast-2", 20484)
    controller.HandleUnitSpellcastSucceeded("target", "cast-3", 20484)
    controller.HandleUnitSpellcastSucceeded("boss1", "cast-4", 20484)
    controller.HandleUnitSpellcastSucceeded("focus", "cast-5", 20484)
    Assert.Equal(#broadcasts, 0, "BR from non-player units must be ignored (self-casts only)")
  end)

  test("CombatEvents ignores BR spell IDs reported on pet unit", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller = BuildController({ addon = addon, broadcasts = broadcasts })
    controller.HandleUnitSpellcastSucceeded("pet", "cast-1", 20484)
    Assert.Equal(#broadcasts, 0, "pet-unit BR spell IDs must not announce as a local battle res")
  end)
end

local function RegisterCombatEventsLustTests(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("CombatEvents broadcasts own Bloodlust cast when in key", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller = BuildController({ addon = addon, broadcasts = broadcasts })
    controller.HandleUnitSpellcastSucceeded("player", "cast-1", 2825)
    Assert.Equal(#broadcasts, 1, "must broadcast the Bloodlust cast")
    Assert.Equal(broadcasts[1].kind, "LUST", "broadcast kind must be LUST")
    Assert.Equal(broadcasts[1].spellID, 2825, "broadcast must carry the Bloodlust spellID")
  end)

  test("CombatEvents broadcasts Marksmanship Hunter Harrier's Cry as Bloodlust when in key", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller = BuildController({
      addon = addon,
      broadcasts = broadcasts,
      nameMap = {
        player = "Hunter-Realm",
      },
    })
    controller.HandleUnitSpellcastSucceeded("player", "cast-1", 466904)
    Assert.Equal(#broadcasts, 1, "Harrier's Cry must broadcast as a Bloodlust cast")
    Assert.Equal(broadcasts[1].kind, "LUST", "Harrier's Cry broadcast kind must be LUST")
    Assert.Equal(broadcasts[1].caster, "Hunter-Realm", "Harrier's Cry must display the casting hunter")
    Assert.Equal(broadcasts[1].spellID, 466904, "Harrier's Cry broadcast must keep its triggering spellID")
  end)

  test("CombatEvents broadcasts owned pet Bloodlust as the local player", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller = BuildController({
      addon = addon,
      broadcasts = broadcasts,
      nameMap = {
        player = "Hunter-Realm",
        pet = "PetName",
      },
    })
    controller.HandleUnitSpellcastSucceeded("pet", "cast-1", 264667)
    Assert.Equal(#broadcasts, 1, "owned pet Bloodlust must broadcast once")
    Assert.Equal(broadcasts[1].kind, "LUST", "pet Bloodlust must announce as Lust")
    Assert.Equal(broadcasts[1].caster, "Hunter-Realm", "pet Bloodlust must display the owning player")
    Assert.Equal(broadcasts[1].spellID, 264667, "pet Bloodlust must keep its triggering spellID")
  end)

  test("CombatEvents ignores unrelated spell IDs", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller = BuildController({ addon = addon, broadcasts = broadcasts })
    -- 1459 = Arcane Intellect: a cast but neither BR nor Lust.
    controller.HandleUnitSpellcastSucceeded("player", "cast-1", 1459)
    Assert.Equal(#broadcasts, 0, "unrelated cast IDs must not broadcast anything")
  end)

  test("CombatEvents respects chatAnnounceLust=false toggle", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller = BuildController({
      addon = addon,
      broadcasts = broadcasts,
      dbRef = { value = { chatAnnounceLust = false } },
    })
    controller.HandleUnitSpellcastSucceeded("player", "cast-1", 2825)
    Assert.Equal(#broadcasts, 0, "Lust broadcast must be gated by chatAnnounceLust")
  end)

  test("CombatEvents Reset clears dedup so same cast fires again", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local nowRef = { value = 50 }
    local controller = BuildController({ addon = addon, broadcasts = broadcasts, nowRef = nowRef })
    controller.HandleUnitSpellcastSucceeded("player", "cast-1", 2825)
    controller.HandleUnitSpellcastSucceeded("player", "cast-2", 2825)
    Assert.Equal(#broadcasts, 1, "dedup must suppress repeat before Reset")
    controller.Reset()
    controller.HandleUnitSpellcastSucceeded("player", "cast-3", 2825)
    Assert.Equal(#broadcasts, 2, "Reset must clear dedup state")
  end)
end

local function RegisterCombatEventsDefaultTests(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("CombatEvents CreateController uses default getTime when opts.getTime missing", function()
    local globals = BuildCombatEventsEnv()
    globals.GetTime = function()
      return 1234
    end
    local addon = nil
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)

    local broadcasts = {}
    local controller
    WithGlobals({
      GetTime = function()
        return 1234
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return 42
        end,
      },
      GetUnitName = function(unit, _)
        return unit == "player" and "Alice-Realm" or unit
      end,
    }, function()
      controller = addon.CombatEvents.CreateController({
        broadcastCombatAnnounce = function(kind, src, sid)
          table.insert(broadcasts, { kind = kind, src = src, sid = sid })
        end,
      })
      controller.HandleUnitSpellcastSucceeded("player", "cast-1", 20484)
    end)
    Assert.Equal(#broadcasts, 1, "default getTime + isInKey + getUnitName must still broadcast")
    Assert.Equal(broadcasts[1].src, "Alice-Realm", "default getUnitName must use GetUnitName(unit, true)")
  end)

  test("CombatEvents default isInKey returns false when C_ChallengeMode is missing", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller
    WithGlobals({
      GetTime = function()
        return 1
      end,
      C_ChallengeMode = false,
      GetUnitName = function(unit)
        return unit
      end,
    }, function()
      controller = addon.CombatEvents.CreateController({
        broadcastCombatAnnounce = function(kind)
          table.insert(broadcasts, kind)
        end,
      })
      controller.HandleUnitSpellcastSucceeded("player", "cast-1", 20484)
    end)
    Assert.Equal(#broadcasts, 0, "default isInKey must gate to false when C_ChallengeMode is absent")
  end)

  test("CombatEvents default isInKey returns false when C_ChallengeMode.GetActiveChallengeMapID raises", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller
    WithGlobals({
      GetTime = function()
        return 1
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          error("boom", 0)
        end,
      },
      GetUnitName = function(unit)
        return unit
      end,
    }, function()
      controller = addon.CombatEvents.CreateController({
        broadcastCombatAnnounce = function(kind)
          table.insert(broadcasts, kind)
        end,
      })
      controller.HandleUnitSpellcastSucceeded("player", "cast-1", 20484)
    end)
    Assert.Equal(#broadcasts, 0, "pcall failure must degrade isInKey to false")
  end)

  test("CombatEvents default getUnitName falls back to UnitName when GetUnitName fails", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller
    WithGlobals({
      GetTime = function()
        return 1
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return 9
        end,
      },
      GetUnitName = function()
        error("no name", 0)
      end,
      UnitName = function(unit)
        return unit == "player" and "Bob" or unit
      end,
    }, function()
      controller = addon.CombatEvents.CreateController({
        broadcastCombatAnnounce = function(kind, src)
          table.insert(broadcasts, src)
        end,
      })
      controller.HandleUnitSpellcastSucceeded("player", "cast-1", 20484)
    end)
    Assert.Equal(broadcasts[1], "Bob", "fallback must use UnitName result")
  end)

  test("CombatEvents default getUnitName returns unit token when all name APIs fail", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller
    WithGlobals({
      GetTime = function()
        return 1
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return 9
        end,
      },
      GetUnitName = function()
        return nil
      end,
      UnitName = function()
        return ""
      end,
    }, function()
      controller = addon.CombatEvents.CreateController({
        broadcastCombatAnnounce = function(_, src)
          table.insert(broadcasts, src)
        end,
      })
      controller.HandleUnitSpellcastSucceeded("player", "cast-1", 20484)
    end)
    Assert.Equal(broadcasts[1], "player", "last-resort fallback must be the unit token itself")
  end)

  test("CombatEvents HandleUnitSpellcastSucceeded ignores non-numeric spellID", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller = BuildController({ addon = addon, broadcasts = broadcasts })
    controller.HandleUnitSpellcastSucceeded("player", "cast-1", "not-a-number")
    controller.HandleUnitSpellcastSucceeded("player", "cast-2", nil)
    Assert.Equal(#broadcasts, 0)
  end)
end

local function RegisterCombatEventsDependencyInjectionTests(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("CombatEvents.SetDependencies ignores non-table input", function()
    local addon = nil
    local globals, dispatch = BuildCombatEventsEnv()
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    -- Must not raise; controllerInstance stays nil.
    addon.CombatEvents.SetDependencies(nil)
    addon.CombatEvents.SetDependencies("string")
    addon.CombatEvents.SetDependencies(42)
    -- OnEvent with no controller set must also be a no-op (early return).
    dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 20484)
    dispatch("CHALLENGE_MODE_START")
  end)

  test("CombatEvents eventFrame OnEvent routes UNIT_SPELLCAST_SUCCEEDED to the controller", function()
    local addon = nil
    local globals, dispatch = BuildCombatEventsEnv()
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    addon.CombatEvents.SetDependencies({
      getTime = function()
        return 0
      end,
      isInKey = function()
        return true
      end,
      getUnitName = function(unit)
        return unit == "player" and "Alice" or unit
      end,
      broadcastCombatAnnounce = function(kind, src, sid)
        table.insert(broadcasts, { kind = kind, src = src, sid = sid })
      end,
      getDB = function()
        return {}
      end,
    })
    dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 20484)
    Assert.Equal(#broadcasts, 1, "UNIT_SPELLCAST_SUCCEEDED must flow through to HandleUnitSpellcastSucceeded")
    Assert.Equal(broadcasts[1].kind, "BR")
  end)

  test("CombatEvents eventFrame OnEvent CHALLENGE_MODE_START resets dedup state", function()
    local addon = nil
    local globals, dispatch = BuildCombatEventsEnv()
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local nowRef = { value = 100 }
    addon.CombatEvents.SetDependencies({
      getTime = function()
        return nowRef.value
      end,
      isInKey = function()
        return true
      end,
      getUnitName = function(unit)
        return unit == "player" and "Alice" or unit
      end,
      broadcastCombatAnnounce = function(kind, src, sid)
        table.insert(broadcasts, { kind = kind, src = src, sid = sid })
      end,
      getDB = function()
        return {}
      end,
    })
    dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 20484)
    dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 20484)
    Assert.Equal(#broadcasts, 1, "dedup must suppress repeat cast before reset")
    dispatch("CHALLENGE_MODE_START")
    dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-3", 20484)
    Assert.Equal(#broadcasts, 2, "CHALLENGE_MODE_START must Reset() dedup")
    dispatch("CHALLENGE_MODE_COMPLETED")
    dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-4", 20484)
    Assert.Equal(#broadcasts, 3, "CHALLENGE_MODE_COMPLETED must also Reset() dedup")
  end)

  test("CombatEvents eventFrame OnEvent ignores unrelated events", function()
    local addon = nil
    local globals, dispatch = BuildCombatEventsEnv()
    WithGlobals(globals, function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    addon.CombatEvents.SetDependencies({
      getTime = function()
        return 0
      end,
      isInKey = function()
        return true
      end,
      getUnitName = function(unit)
        return unit
      end,
      broadcastCombatAnnounce = function(_, _, _)
        table.insert(broadcasts, true)
      end,
      getDB = function()
        return {}
      end,
    })
    dispatch("PLAYER_LOGIN")
    dispatch("GROUP_ROSTER_UPDATE")
    Assert.Equal(#broadcasts, 0, "events outside the known set must not trigger anything")
  end)

  test("CombatEvents CreateController default getDB returns empty table (BR + Lust enabled)", function()
    local addon = nil
    WithGlobals(BuildCombatEventsEnv(), function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local broadcasts = {}
    local controller = addon.CombatEvents.CreateController({
      getTime = function()
        return 0
      end,
      isInKey = function()
        return true
      end,
      getUnitName = function(unit)
        return unit
      end,
      broadcastCombatAnnounce = function(kind)
        table.insert(broadcasts, kind)
      end,
      -- getDB omitted on purpose -> defaults to function returning {}.
    })
    controller.HandleUnitSpellcastSucceeded("player", "cast-1", 20484)
    Assert.Equal(broadcasts[1], "BR", "default getDB {} must leave BR enabled")
  end)
end

return function(test, ctx)
  RegisterCombatEventsAutoRegistrationTests(test, ctx)
  RegisterCombatEventsBRTests(test, ctx)
  RegisterCombatEventsLustTests(test, ctx)
  RegisterCombatEventsDefaultTests(test, ctx)
  RegisterCombatEventsDependencyInjectionTests(test, ctx)
end
