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
    names = opts.names or {
      player = { "Self", "Realm" },
      party1 = { "Tankadin", "Realm" },
      party2 = { "Priestess", "Realm" },
      party3 = { "Magey", "Realm" },
      party4 = { "Hunterx", "Realm" },
    },
    now = opts.now or 100,
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
    getUnitNameAndRealm = function(unit)
      local nameRealm = env.names[unit]
      if type(nameRealm) == "table" then
        return nameRealm[1], nameRealm[2]
      end
      return nil, nil
    end,
    getTime = function()
      return env.now
    end,
    onRoleDeath = function(role, unit, optsTable)
      table.insert(env.alerts, { role = role, unit = unit, opts = optsTable })
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

  test("DeathWatch fires for damage-dealer deaths so they can be announced", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party3 = true -- party3 is a DAMAGER
    controller.HandleUnitHealth("party3")
    Assert.Equal(#env.alerts, 1, "a damage-dealer death must fire so the spoken alert can announce it")
    Assert.Equal(env.alerts[1].role, "DAMAGER", "the resolved role must be DAMAGER")
  end)

  test("DeathWatch suppresses damage-dealer TTS event after tank and healer are dead", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party1 = true -- tank
    controller.HandleUnitHealth("party1")
    env.deadUnits.party2 = true -- healer
    controller.HandleUnitHealth("party2")
    env.deadUnits.party3 = true -- damage dealer
    controller.HandleUnitHealth("party3")

    Assert.Equal(#env.alerts, 2, "DPS deaths after tank and healer are dead must not produce a TTS event")
    Assert.Equal(env.alerts[1].role, "TANK", "the tank death still alerts")
    Assert.Equal(env.alerts[2].role, "HEALER", "the healer death still alerts")
  end)

  test("DeathWatch pauses death TTS for 30 seconds after two consecutive player deaths", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv({
      roles = {
        player = "DAMAGER",
        party1 = "TANK",
        party2 = "DAMAGER",
        party3 = "DAMAGER",
        party4 = "DAMAGER",
      },
    })
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party1 = true
    controller.HandleUnitHealth("party1")
    Assert.False(env.alerts[1].opts.suppressTts == true, "first death must still allow TTS")

    env.now = 101
    env.deadUnits.party2 = true
    controller.HandleUnitHealth("party2")
    Assert.True(env.alerts[2].opts.suppressTts == true, "second different player death must start the TTS pause")

    env.now = 120
    env.deadUnits.party3 = true
    controller.HandleUnitHealth("party3")
    Assert.True(env.alerts[3].opts.suppressTts == true, "death TTS must stay paused inside the 30-second window")

    env.now = 132
    env.deadUnits.party4 = true
    controller.HandleUnitHealth("party4")
    Assert.False(env.alerts[4].opts.suppressTts == true, "death TTS must resume after the 30-second pause expires")
  end)

  test("DeathWatch ignores disconnected units", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party1 = true
    env.connectedUnits.party1 = false
    controller.HandleUnitHealth("party1")
    Assert.Equal(#env.alerts, 0, "a disconnected unit must not be treated as dead")
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

  test("DeathWatch tracks per-player death counts until a new challenge starts", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party1 = true
    controller.HandleUnitHealth("party1")
    env.deadUnits.party1 = false
    controller.HandleUnitHealth("party1")
    env.deadUnits.party1 = true
    controller.HandleUnitHealth("party1")

    local summary = controller.GetDeathSummaryForPlayer("Tankadin", "Realm")
    Assert.Equal(summary.count, 2, "two separate tank deaths must be counted for the player")
    Assert.Equal(summary.role, "TANK", "summary should keep the resolved role")

    controller.ResetEdges()
    summary = controller.GetDeathSummaryForPlayer("Tankadin", "Realm")
    Assert.Equal(summary.count, 2, "key end/reset edge clearing must not wipe the visible death count")

    controller.Reset()
    Assert.Nil(controller.GetDeathSummaryForPlayer("Tankadin", "Realm"), "new key reset must clear death counts")
  end)

  test("DeathWatch keeps counting damage-dealer deaths even when TTS is suppressed", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party1 = true -- tank
    controller.HandleUnitHealth("party1")
    env.deadUnits.party2 = true -- healer
    controller.HandleUnitHealth("party2")
    env.deadUnits.party3 = true -- damage dealer
    controller.HandleUnitHealth("party3")

    Assert.Equal(#env.alerts, 2, "the late DPS death still must not emit a TTS event")
    local summary = controller.GetDeathSummaryForPlayer("Magey", "Realm")
    Assert.Equal(summary.count, 1, "the suppressed DPS TTS event must still increment death tracking")
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

  test("DeathWatch default dependencies fail closed and dispatch safely", function()
    local alerts = {}
    local addon
    WithGlobals({
      IsiLiveDB = {},
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return 2662
        end,
      },
      UnitExists = function(unit)
        return unit == "party1"
      end,
      UnitIsConnected = function()
        return true
      end,
      UnitGUID = function(unit)
        return "GUID-" .. tostring(unit)
      end,
      UnitIsDeadOrGhost = function()
        return true
      end,
    }, function()
      addon = LoadAddonModules({ "isiLive_death_watch.lua" }, {
        Units = {
          GetUnitRole = function()
            return "TANK"
          end,
        },
      })
      addon.DeathWatch.SetDependencies("invalid")
      addon.DeathWatch.HandleEvent("UNIT_HEALTH", "party1")
      addon.DeathWatch.SetDependencies({
        onRoleDeath = function(role, unit)
          table.insert(alerts, { role = role, unit = unit })
        end,
      })
      addon.DeathWatch.HandleEvent("UNIT_HEALTH", "party1")
      addon.DeathWatch.HandleEvent("GROUP_ROSTER_UPDATE")
      addon.DeathWatch.HandleEvent("CHALLENGE_MODE_START")
      addon.DeathWatch.HandleEvent("UNIT_HEALTH", "party1")
      addon.DeathWatch.HandleEvent("UNKNOWN_EVENT")
    end)

    Assert.Equal(#alerts, 2, "default dependency dispatch should alert, reset, and alert again")
    Assert.Equal(alerts[1].role, "TANK", "default role resolver should use addon Units")
  end)

  test("DeathWatch default API readers fail closed on missing or protected values", function()
    local alerts = {}
    WithGlobals({
      IsiLiveDB = {},
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          error("protected map")
        end,
      },
      UnitExists = function()
        error("protected exists")
      end,
      UnitIsConnected = function()
        error("protected connected")
      end,
      UnitGUID = function()
        error("protected guid")
      end,
      UnitIsDeadOrGhost = function()
        error("protected dead")
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_death_watch.lua" })
      addon.DeathWatch.SetDependencies({
        onRoleDeath = function(role, unit)
          table.insert(alerts, { role = role, unit = unit })
        end,
      })
      addon.DeathWatch.HandleEvent("UNIT_HEALTH", "party1")
    end)

    Assert.Equal(#alerts, 0, "protected default API reads must fail closed without alerts")
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

local function RegisterTtsTests(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("SoundUtils SpeakTts fails closed without the voice-chat API", function()
    WithGlobals({
      IsiLiveDB = { ttsAnnouncementsEnabled = true },
      GetTime = function()
        return 100
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.False(addon.SoundUtils.SpeakTts("tank down"), "missing C_VoiceChat must fail closed")
    end)
  end)

  test("SoundUtils SpeakTts fails closed when no system voice is available", function()
    local spoke = 0
    WithGlobals({
      IsiLiveDB = { ttsAnnouncementsEnabled = true },
      GetTime = function()
        return 100
      end,
      C_VoiceChat = {
        GetTtsVoices = function()
          return {}
        end,
        SpeakText = function()
          spoke = spoke + 1
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.False(addon.SoundUtils.SpeakTts("tank down"), "empty voice list must fail closed")
    end)
    Assert.Equal(spoke, 0, "no SpeakText call without a voice")
  end)

  test("SoundUtils SpeakTts speaks with the 12.0 argument order and honours the spam window", function()
    local calls = {}
    local now = 100
    WithGlobals({
      IsiLiveDB = { ttsAnnouncementsEnabled = true, ttsVolume = 100 },
      GetTime = function()
        return now
      end,
      C_VoiceChat = {
        GetTtsVoices = function()
          return { { voiceID = 7, name = "Voice" } }
        end,
        SpeakText = function(voiceID, text, rate, volume, overlap)
          calls[#calls + 1] = { voiceID = voiceID, text = text, rate = rate, volume = volume, overlap = overlap }
          return true
        end,
      },
      C_TTSSettings = {
        GetSpeechRate = function()
          return 2
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.True(addon.SoundUtils.SpeakTts("tank down", { spamScope = "death:TANK" }), "first call must speak")
      Assert.Equal(#calls, 1, "exactly one SpeakText call")
      Assert.Equal(calls[1].voiceID, 7, "voiceID must be the first argument (no destination arg in 12.0)")
      Assert.Equal(calls[1].text, "tank down", "text must be the second argument")
      Assert.Equal(calls[1].rate, 2, "rate must come from C_TTSSettings.GetSpeechRate")
      Assert.Equal(calls[1].volume, 100, "volume must be the fourth argument")
      Assert.Equal(calls[1].overlap, false, "overlap must be the fifth argument and default false")
      Assert.False(
        addon.SoundUtils.SpeakTts("tank down", { spamScope = "death:TANK" }),
        "a repeat within the spam window must be suppressed"
      )
      Assert.Equal(#calls, 1, "no second SpeakText within the spam window")
      now = 102
      Assert.True(
        addon.SoundUtils.SpeakTts("tank down", { spamScope = "death:TANK" }),
        "after the spam window the same text speaks again"
      )
      Assert.Equal(#calls, 2, "second SpeakText fires once the window passed")
    end)
  end)

  test("SoundUtils SpeakTts prefers the configured voice id and clamps the volume", function()
    local calls = {}
    WithGlobals({
      IsiLiveDB = { ttsAnnouncementsEnabled = true, ttsVoiceID = 9, ttsVolume = 250 },
      GetTime = function()
        return 100
      end,
      C_VoiceChat = {
        GetTtsVoices = function()
          return { { voiceID = 7 }, { voiceID = 9 } }
        end,
        SpeakText = function(voiceID, _text, _rate, volume)
          calls[#calls + 1] = { voiceID = voiceID, volume = volume }
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.True(addon.SoundUtils.SpeakTts("healer down"), "call with a valid configured voice must speak")
      Assert.Equal(calls[1].voiceID, 9, "the configured ttsVoiceID must win when present in the live list")
      Assert.Equal(calls[1].volume, 100, "an out-of-range volume must clamp to 100")
    end)
  end)

  test("SoundUtils IsTtsEnabled defaults to off and follows the setting", function()
    local addon
    WithGlobals({}, function()
      addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
    end)
    WithGlobals({}, function()
      Assert.False(addon.SoundUtils.IsTtsEnabled(), "missing DB must default off")
    end)
    WithGlobals({ IsiLiveDB = {} }, function()
      Assert.False(addon.SoundUtils.IsTtsEnabled(), "unset setting must default off")
    end)
    WithGlobals({ IsiLiveDB = { ttsAnnouncementsEnabled = true } }, function()
      Assert.True(addon.SoundUtils.IsTtsEnabled(), "explicit true must enable")
    end)
    WithGlobals({ IsiLiveDB = { ttsAnnouncementsEnabled = false } }, function()
      Assert.False(addon.SoundUtils.IsTtsEnabled(), "explicit false must disable")
    end)
  end)

  -- Factory death-alert TTS path: dynamic player name, nameless fallback, WAV
  -- fallback. The SoundUtils seed stubs the primitives so these tests pin the
  -- factory's branching, not the SpeakTts internals (covered above).
  local function BuildFactoryTtsEnv(opts)
    opts = opts or {}
    local env = { spoke = nil, wav = nil, deps = nil, shown = {} }
    env.seed = {
      DeathAlert = {
        SetDependencies = function() end,
        ShowRoleDeath = function(role)
          table.insert(env.shown, role)
        end,
      },
      DeathWatch = {
        SetDependencies = function(deps)
          env.deps = deps
        end,
      },
      SoundUtils = {
        IsTtsEnabled = function()
          return opts.ttsEnabled == true
        end,
        ShouldAnnounceName = function()
          return opts.announceName ~= false
        end,
        ShouldAnnounceClass = function()
          return opts.announceClass == true
        end,
        SpeakTts = function(text, spakOpts)
          env.spoke = { text = text, opts = spakOpts }
          return opts.speakResult ~= false
        end,
        PlayTankDied = function()
          env.wav = "tank"
        end,
        PlayHealerDied = function()
          env.wav = "healer"
        end,
      },
      MplusTimer = {
        GetTimerData = function()
          return { running = true }
        end,
      },
    }
    env.ctxStub = {
      GetL = function()
        return opts.locale
          or {
            TTS_NAMED_DIED_FMT = "%s, %s, died.",
            TTS_DIED_FMT = "%s died.",
            TTS_ROLE_TANK = "Tank",
            TTS_ROLE_HEALER = "Healer",
            TTS_ROLE_DAMAGER = "Damage dealer",
            DEATH_ALERT_TANK = "Tank died",
            DEATH_ALERT_HEALER = "Healer died",
          }
      end,
      GetActiveChallengeMapID = function()
        return nil
      end,
      getUnitRole = function()
        return "NONE"
      end,
    }
    return env
  end

  test("Factory death alert speaks the player name when TTS is enabled", function()
    local env = BuildFactoryTtsEnv({ ttsEnabled = true })
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitName = function(unit)
        return unit == "party1" and "Tankadin" or nil
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, env.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(env.ctxStub)
      env.deps.onRoleDeath("TANK", "party1")
    end)
    Assert.Equal(env.spoke.text, "Tankadin, Tank, died.", "TTS must speak name plus role descriptor by default")
    Assert.Equal(env.spoke.opts.spamScope, "death:TANK", "the spoken alert must carry a per-role spam scope")
    Assert.Nil(env.wav, "no recorded WAV must play when TTS spoke")
  end)

  test("Factory death alert announces the role word when names are off", function()
    local env = BuildFactoryTtsEnv({ ttsEnabled = true, announceName = false })
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitName = function()
        return "Tankadin"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, env.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(env.ctxStub)
      env.deps.onRoleDeath("TANK", "party1")
    end)
    Assert.Equal(env.spoke.text, "Tank died.", "names off must speak the role word only")
  end)

  test("Factory death alert announces the class when class mode is on", function()
    local env = BuildFactoryTtsEnv({ ttsEnabled = true, announceName = false, announceClass = true })
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitName = function()
        return "Bob"
      end,
      UnitClass = function()
        return "Hunter", "HUNTER"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, env.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(env.ctxStub)
      env.deps.onRoleDeath("DAMAGER", "party3")
    end)
    Assert.Equal(env.spoke.text, "Hunter died.", "class mode must speak the class name")
  end)

  test("Factory death alert announces a damage-dealer death via class TTS only", function()
    local env = BuildFactoryTtsEnv({ ttsEnabled = true, announceName = false })
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitName = function()
        return "Bob"
      end,
      UnitClass = function()
        return "Hunter", "HUNTER"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, env.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(env.ctxStub)
      env.deps.onRoleDeath("DAMAGER", "party3")
    end)
    Assert.Equal(env.spoke.text, "Hunter died.", "a DPS death speaks the resolved class by default")
    Assert.Equal(#env.shown, 0, "a DPS death must not render the on-screen warning")
    Assert.Nil(env.wav, "a DPS death has no recorded WAV")
  end)

  test("Factory death alert suppresses TTS for the local player's own death", function()
    local env = BuildFactoryTtsEnv({ ttsEnabled = true, announceName = false })
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitName = function()
        return "Self"
      end,
      UnitClass = function()
        return "Hunter", "HUNTER"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, env.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(env.ctxStub)
      env.deps.onRoleDeath("DAMAGER", "player")
    end)
    Assert.Nil(env.spoke, "own death must not produce a spoken TTS alert")
    Assert.Nil(env.wav, "DPS own death has no recorded WAV fallback")
  end)

  test("Factory death alert suppresses paused death TTS without hiding tank or healer warnings", function()
    local env = BuildFactoryTtsEnv({ ttsEnabled = true, announceName = false })
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitName = function()
        return "Tankadin"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, env.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(env.ctxStub)
      env.deps.onRoleDeath("TANK", "party1", { suppressTts = true })
    end)
    Assert.Nil(env.spoke, "paused death TTS must not call SpeakTts")
    Assert.Nil(env.wav, "paused enabled TTS must not fall back to the recorded WAV")
    Assert.Equal(env.shown[1], "TANK", "the on-screen warning must still render for tank deaths")
  end)

  test("Factory death alert keeps recorded wav fallback when TTS is disabled during a burst pause", function()
    local env = BuildFactoryTtsEnv({ ttsEnabled = false })
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitName = function()
        return "Tankadin"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, env.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(env.ctxStub)
      env.deps.onRoleDeath("TANK", "party1", { suppressTts = true })
    end)
    Assert.Nil(env.spoke, "disabled TTS must not speak")
    Assert.Equal(env.wav, "tank", "recorded fallback remains unchanged when TTS is disabled")
  end)

  test("Factory death alert keeps the on-screen warning to tank and healer", function()
    local env = BuildFactoryTtsEnv({ ttsEnabled = false })
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitName = function()
        return "Bob"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, env.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(env.ctxStub)
      env.deps.onRoleDeath("TANK", "party1")
      env.deps.onRoleDeath("DAMAGER", "party3")
    end)
    Assert.Equal(#env.shown, 1, "only the tank death renders the on-screen warning")
    Assert.Equal(env.shown[1], "TANK", "the rendered on-screen role must be the tank")
  end)

  test("Factory death alert falls back to a nameless announcement for a secret or missing name", function()
    local env = BuildFactoryTtsEnv({ ttsEnabled = true })
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitName = function()
        return "Hidden"
      end,
      issecretvalue = function()
        return true
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, env.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(env.ctxStub)
      env.deps.onRoleDeath("HEALER", "party2")
    end)
    Assert.Equal(env.spoke.text, "Healer died.", "a secret name must fall back to the role-word announcement")
    Assert.Nil(env.wav, "the nameless TTS still counts as spoken, so no WAV plays")
  end)

  test("Factory death alert falls back to the recorded wav when TTS is disabled or unavailable", function()
    local disabledEnv = BuildFactoryTtsEnv({ ttsEnabled = false })
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitName = function()
        return "Tankadin"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, disabledEnv.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(disabledEnv.ctxStub)
      disabledEnv.deps.onRoleDeath("TANK", "party1")
    end)
    Assert.Nil(disabledEnv.spoke, "TTS must not speak while disabled")
    Assert.Equal(disabledEnv.wav, "tank", "the recorded WAV plays when TTS is disabled")

    local failingEnv = BuildFactoryTtsEnv({ ttsEnabled = true, speakResult = false })
    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitName = function()
        return "Tankadin"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, failingEnv.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(failingEnv.ctxStub)
      failingEnv.deps.onRoleDeath("HEALER", "party2")
    end)
    Assert.Equal(failingEnv.wav, "healer", "a failed SpeakTts must fall back to the recorded WAV")
  end)

  test("SoundUtils ShouldAnnounceName defaults off and class mode wins stale conflicts", function()
    local addon
    WithGlobals({}, function()
      addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
    end)
    WithGlobals({ IsiLiveDB = {} }, function()
      Assert.False(addon.SoundUtils.ShouldAnnounceName(), "name announcement defaults off")
    end)
    WithGlobals({ IsiLiveDB = { ttsAnnounceName = true } }, function()
      Assert.True(addon.SoundUtils.ShouldAnnounceName(), "explicit true enables the name")
    end)
    WithGlobals({ IsiLiveDB = { ttsAnnounceName = true, ttsAnnounceClass = true } }, function()
      Assert.False(addon.SoundUtils.ShouldAnnounceName(), "class mode must win stale both-true saved data")
    end)
  end)

  test("SoundUtils ShouldAnnounceClass defaults off and follows the setting", function()
    local addon
    WithGlobals({}, function()
      addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
    end)
    WithGlobals({ IsiLiveDB = {} }, function()
      Assert.False(addon.SoundUtils.ShouldAnnounceClass(), "class announcement defaults off")
    end)
    WithGlobals({ IsiLiveDB = { ttsAnnounceClass = true } }, function()
      Assert.True(addon.SoundUtils.ShouldAnnounceClass(), "explicit true enables the class")
    end)
  end)
end

return function(test, ctx)
  RegisterDeathWatchTests(test, ctx)
  RegisterDeathAlertUiTests(test, ctx)
  RegisterFactoryWiringTests(test, ctx)
  RegisterTtsTests(test, ctx)
end
