---@diagnostic disable: undefined-global, undefined-field, unused-local

-- Deterministic scenarios for the tank / healer death alert:
-- game/isiLive_death_watch.lua (edge-triggered UNIT_HEALTH death detection),
-- ui/isiLive_death_alert.lua (frameless red on-screen warning) and
-- factory/isiLive_factory_death_alert.lua (alert + TTS sound wiring).

local function BuildWatchEnv(opts)
  opts = opts or {}
  local env = {
    inKey = opts.inKey ~= false,
    db = opts.db or {},
    alerts = {},
    deadUnits = opts.deadUnits or {},
    connectedUnits = opts.connectedUnits or {},
    guids = opts.guids or {
      player = "Player-1",
      party1 = "Player-2",
      party2 = "Player-3",
      party3 = "Player-4",
      party4 = "Player-5",
    },
    roles = opts.roles or {
      player = "DAMAGER",
      party1 = "TANK",
      party2 = "HEALER",
      party3 = "DAMAGER",
      party4 = "DAMAGER",
    },
  }

  env.deps = {
    isInKey = function()
      return env.inKey == true
    end,
    getDB = function()
      return env.db
    end,
    unitExists = function(unit)
      return env.guids[unit] ~= nil
    end,
    unitIsConnected = function(unit)
      return env.connectedUnits[unit] ~= false
    end,
    unitIsDeadOrGhost = function(unit)
      return env.deadUnits[unit] == true
    end,
    unitGUID = function(unit)
      return env.guids[unit]
    end,
    getUnitRole = function(unit)
      return env.roles[unit] or "NONE"
    end,
    onRoleDeath = function(role, unit)
      table.insert(env.alerts, { role = role, unit = unit })
    end,
  }

  return env
end

local function RegisterDeathWatchTests(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function LoadDeathWatch()
    local addon
    WithGlobals({}, function()
      addon = LoadAddonModules({ "isiLive_death_watch.lua" })
    end)
    return addon
  end

  test("DeathWatch fires tank death alert once per active-key death", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    local controller = addon.DeathWatch.CreateController(env.deps)

    controller.HandleUnitHealth("party1")
    Assert.Equal(#env.alerts, 0, "alive tank must not alert")

    env.deadUnits.party1 = true
    controller.HandleUnitHealth("party1")
    Assert.Equal(#env.alerts, 1, "tank death must alert exactly once")
    Assert.Equal(env.alerts[1].role, "TANK", "alert must carry TANK role")

    controller.HandleUnitHealth("party1")
    controller.HandleUnitHealth("party1")
    Assert.Equal(#env.alerts, 1, "repeated UNIT_HEALTH while dead must stay silent")
  end)

  test("DeathWatch fires healer death alert with role resolved at death time", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party2 = true
    controller.HandleUnitHealth("party2")
    Assert.Equal(#env.alerts, 1, "healer death must alert")
    Assert.Equal(env.alerts[1].role, "HEALER", "alert must carry HEALER role")
    Assert.Equal(env.alerts[1].unit, "party2", "alert must carry the dying unit token")
  end)

  test("DeathWatch stays silent outside an active M+ key", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv({ inKey = false })
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party1 = true
    controller.HandleUnitHealth("party1")
    Assert.Equal(#env.alerts, 0, "death outside a key must not alert")
  end)

  test("DeathWatch stays silent when the death alert setting is disabled", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv({ db = { deathAlertEnabled = false } })
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party1 = true
    controller.HandleUnitHealth("party1")
    Assert.Equal(#env.alerts, 0, "disabled setting must suppress the alert")
  end)

  test("DeathWatch fires again after revive and renewed death", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party1 = true
    controller.HandleUnitHealth("party1")
    env.deadUnits.party1 = false
    controller.HandleUnitHealth("party1")
    env.deadUnits.party1 = true
    controller.HandleUnitHealth("party1")
    Assert.Equal(#env.alerts, 2, "revive must re-arm the death edge")
  end)

  test("DeathWatch ignores DPS deaths and disconnected units", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party3 = true
    controller.HandleUnitHealth("party3")
    Assert.Equal(#env.alerts, 0, "DPS death must not alert")

    env.deadUnits.party1 = true
    env.connectedUnits.party1 = false
    controller.HandleUnitHealth("party1")
    Assert.Equal(#env.alerts, 0, "disconnected tank must not be treated as dead")
  end)

  test("DeathWatch alerts for the local player's own death", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    env.roles.player = "HEALER"
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.player = true
    controller.HandleUnitHealth("player")
    Assert.Equal(#env.alerts, 1, "own death must alert as well")
    Assert.Equal(env.alerts[1].role, "HEALER", "own role must be resolved like any other unit")
  end)

  test("DeathWatch resets dead flags on challenge lifecycle events", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    addon.DeathWatch.SetDependencies(env.deps)

    env.deadUnits.party1 = true
    addon.DeathWatch.HandleEvent("UNIT_HEALTH", "party1")
    Assert.Equal(#env.alerts, 1, "first death must alert")

    addon.DeathWatch.HandleEvent("CHALLENGE_MODE_RESET")
    addon.DeathWatch.HandleEvent("UNIT_HEALTH", "party1")
    Assert.Equal(#env.alerts, 2, "challenge reset must clear the dead flag and re-arm the edge")
  end)

  test("DeathWatch roster update drops dead flags of departed players", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party1 = true
    controller.HandleUnitHealth("party1")
    Assert.Equal(#env.alerts, 1, "first occupant's death must alert")

    -- The dead player leaves; a new player takes the party1 token and dies.
    env.guids.party1 = "Player-9"
    controller.HandleGroupRosterUpdate()
    controller.HandleUnitHealth("party1")
    Assert.Equal(#env.alerts, 2, "new slot occupant must get a fresh edge state")
  end)
end

local function BuildFrameStub(track)
  local function NewRegion()
    local region = {}
    region.SetPoint = function() end
    region.SetSize = function() end
    region.SetFont = function(_, path, size, flags)
      track.font = { path = path, size = size, flags = flags }
    end
    region.SetTextColor = function(_, r, g, b)
      track.color = { r = r, g = g, b = b }
    end
    region.SetText = function(_, text)
      track.text = text
    end
    return region
  end

  local function NewAnimation()
    local anim = {}
    local names = {
      "SetScaleFrom",
      "SetScaleTo",
      "SetDuration",
      "SetSmoothing",
      "SetOrder",
      "SetFromAlpha",
      "SetToAlpha",
      "SetStartDelay",
    }
    for _, name in ipairs(names) do
      anim[name] = function() end
    end
    return anim
  end

  local frame = NewRegion()
  frame.shown = false
  frame.Show = function()
    frame.shown = true
  end
  frame.Hide = function()
    frame.shown = false
  end
  frame.SetFrameStrata = function() end
  frame.CreateFontString = function()
    return NewRegion()
  end
  frame.CreateAnimationGroup = function()
    local group = {}
    group.CreateAnimation = function()
      return NewAnimation()
    end
    group.SetScript = function() end
    group.Play = function()
      track.plays = (track.plays or 0) + 1
    end
    group.Stop = function()
      track.stops = (track.stops or 0) + 1
    end
    return group
  end
  return frame
end

local function RegisterDeathAlertUiTests(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("DeathAlert renders big red death text and restarts animation on repeated show", function()
    local addon
    WithGlobals({}, function()
      addon = LoadAddonModules({ "isiLive_death_alert.lua" })
    end)

    local track = {}
    local controller = addon.DeathAlert.CreateController({
      createFrame = function()
        return BuildFrameStub(track)
      end,
      getL = function()
        return { DEATH_ALERT_TANK = "Tank died", DEATH_ALERT_HEALER = "Healer died" }
      end,
    })

    Assert.Equal(controller.ShowRoleDeath("DAMAGER"), false, "non tank/healer roles must not render")

    Assert.Equal(controller.ShowRoleDeath("TANK"), true, "tank alert must render")
    Assert.Equal(track.text, "Tank died", "tank alert must show the configured text")
    Assert.Equal(track.color.r, 1, "alert text must be red")
    Assert.True(track.color.g < 0.3 and track.color.b < 0.3, "alert text must be red, not white")
    Assert.Equal(track.plays, 1, "animation must play on show")

    Assert.Equal(controller.ShowRoleDeath("HEALER"), true, "healer alert must render")
    Assert.Equal(track.text, "Healer died", "healer alert must show the configured text")
    Assert.Equal(track.stops, 2, "animation must stop before every (re)play")
    Assert.Equal(track.plays, 2, "animation must restart for the second death")
    Assert.True(controller._Test_GetFrame().shown == true, "alert frame must be visible after show")
  end)
end

local function RegisterFactoryWiringTests(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Factory death alert wiring routes role deaths to alert and TTS sound", function()
    local shown = {}
    local sounds = {}
    local capturedDeps = nil

    local seed = {
      DeathAlert = {
        SetDependencies = function() end,
        ShowRoleDeath = function(role)
          table.insert(shown, role)
        end,
      },
      DeathWatch = {
        SetDependencies = function(deps)
          capturedDeps = deps
        end,
      },
      SoundUtils = {
        PlayTankDied = function()
          table.insert(sounds, "tank_died")
        end,
        PlayHealerDied = function()
          table.insert(sounds, "healer_died")
        end,
      },
      MplusTimer = {
        GetTimerData = function()
          return { running = true }
        end,
      },
    }

    local addon
    WithGlobals({}, function()
      addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, seed)
    end)

    local ctxStub = {
      GetL = function()
        return {}
      end,
      GetActiveChallengeMapID = function()
        return nil
      end,
      getUnitRole = function()
        return "NONE"
      end,
    }
    addon._FactoryInternal.InitializeFactoryDeathAlertControllers(ctxStub)

    Assert.Equal(type(capturedDeps), "table", "DeathWatch must receive its dependencies")
    Assert.Equal(capturedDeps.isInKey(), true, "running M+ timer must count as in-key")

    capturedDeps.onRoleDeath("TANK", "party1")
    capturedDeps.onRoleDeath("HEALER", "party2")
    Assert.Equal(shown[1], "TANK", "tank death must show the on-screen alert")
    Assert.Equal(shown[2], "HEALER", "healer death must show the on-screen alert")
    Assert.Equal(sounds[1], "tank_died", "tank death must play the tank TTS file")
    Assert.Equal(sounds[2], "healer_died", "healer death must play the healer TTS file")
  end)

  test("SoundUtils registry gates both death TTS files behind the single death alert setting", function()
    local addon
    WithGlobals({}, function()
      addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
    end)

    local registry = addon.SoundUtils.Registry
    Assert.Equal(registry.tank_died.settingKey, "deathAlertEnabled", "tank sound must use the feature toggle")
    Assert.Equal(registry.healer_died.settingKey, "deathAlertEnabled", "healer sound must use the feature toggle")
    Assert.True(registry.tank_died.file:find("TankDied.wav", 1, true) ~= nil, "tank entry must map the tank wav")
    Assert.True(
      registry.healer_died.file:find("HealerDied.wav", 1, true) ~= nil,
      "healer entry must map the healer wav"
    )

    local inOrder = false
    for _, key in ipairs(addon.SoundUtils.SettingsOrder) do
      if key == "tank_died" then
        inOrder = true
      end
      Assert.True(key ~= "healer_died", "healer entry must not render a second settings checkbox")
    end
    Assert.True(inOrder, "death alert toggle must appear in the sound settings order")
  end)
end

return function(test, ctx)
  RegisterDeathWatchTests(test, ctx)
  RegisterDeathAlertUiTests(test, ctx)
  RegisterFactoryWiringTests(test, ctx)
end
