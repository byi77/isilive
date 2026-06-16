---@diagnostic disable: undefined-global, undefined-field, unused-local

-- Deterministic scenarios for the tank / healer death alert:
-- game/isiLive_death_watch.lua (edge-triggered UNIT_HEALTH death detection),
-- ui/isiLive_death_alert.lua (frameless red on-screen warning) and
-- factory/isiLive_factory_death_alert.lua (alert + static death sound wiring).

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

  test("DeathWatch fires for damage-dealer deaths so they can be tracked", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party3 = true -- party3 is a DAMAGER
    controller.HandleUnitHealth("party3")
    Assert.Equal(#env.alerts, 1, "a damage-dealer death must fire so death tracking can observe it")
    Assert.Equal(env.alerts[1].role, "DAMAGER", "the resolved role must be DAMAGER")
  end)

  test("DeathWatch suppresses damage-dealer death-audio event after tank and healer are dead", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party1 = true -- tank
    controller.HandleUnitHealth("party1")
    env.deadUnits.party2 = true -- healer
    controller.HandleUnitHealth("party2")
    env.deadUnits.party3 = true -- damage dealer
    controller.HandleUnitHealth("party3")

    Assert.Equal(#env.alerts, 2, "DPS deaths after tank and healer are dead must not produce an audio event")
    Assert.Equal(env.alerts[1].role, "TANK", "the tank death still alerts")
    Assert.Equal(env.alerts[2].role, "HEALER", "the healer death still alerts")
  end)

  test("DeathWatch marks death-audio pause for 30 seconds after two consecutive player deaths", function()
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
    Assert.False(env.alerts[1].opts.suppressAudio == true, "first death must still allow death audio")

    env.now = 101
    env.deadUnits.party2 = true
    controller.HandleUnitHealth("party2")
    Assert.True(env.alerts[2].opts.suppressAudio == true, "second different player death must start the audio pause")

    env.now = 120
    env.deadUnits.party3 = true
    controller.HandleUnitHealth("party3")
    Assert.True(env.alerts[3].opts.suppressAudio == true, "death audio must stay paused inside the 30-second window")

    env.now = 132
    env.deadUnits.party4 = true
    controller.HandleUnitHealth("party4")
    Assert.False(env.alerts[4].opts.suppressAudio == true, "death audio must resume after the 30-second pause expires")
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

  test("DeathWatch keeps counting damage-dealer deaths even when audio is suppressed", function()
    local addon = LoadDeathWatch()
    local env = BuildWatchEnv()
    local controller = addon.DeathWatch.CreateController(env.deps)

    env.deadUnits.party1 = true -- tank
    controller.HandleUnitHealth("party1")
    env.deadUnits.party2 = true -- healer
    controller.HandleUnitHealth("party2")
    env.deadUnits.party3 = true -- damage dealer
    controller.HandleUnitHealth("party3")

    Assert.Equal(#env.alerts, 2, "the late DPS death still must not emit an audio event")
    local summary = controller.GetDeathSummaryForPlayer("Magey", "Realm")
    Assert.Equal(summary.count, 1, "the suppressed DPS death must still increment death tracking")
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

  test("Factory death alert wiring routes role deaths to alert and static WAV sound", function()
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
    Assert.Equal(sounds[1], "tank_died", "tank death must play the tank WAV file")
    Assert.Equal(sounds[2], "healer_died", "healer death must play the healer WAV file")
  end)

  test("SoundUtils registry gates tank and healer death WAV files behind separate settings", function()
    local addon
    WithGlobals({}, function()
      addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
    end)

    local registry = addon.SoundUtils.Registry
    Assert.Equal(registry.tank_died.settingKey, "soundTankDiedEnabled", "tank sound must use its own feature toggle")
    Assert.Equal(
      registry.healer_died.settingKey,
      "soundHealerDiedEnabled",
      "healer sound must use its own feature toggle"
    )
    Assert.True(registry.tank_died.file:find("TankDied.wav", 1, true) ~= nil, "tank entry must map the tank wav")
    Assert.True(
      registry.healer_died.file:find("HealerDied.wav", 1, true) ~= nil,
      "healer entry must map the healer wav"
    )

    local tankInOrder = false
    local healerInOrder = false
    for _, key in ipairs(addon.SoundUtils.SettingsOrder) do
      if key == "tank_died" then
        tankInOrder = true
      elseif key == "healer_died" then
        healerInOrder = true
      end
    end
    Assert.True(tankInOrder, "tank death sound toggle must appear in the sound settings order")
    Assert.True(healerInOrder, "healer death sound toggle must appear in the sound settings order")
  end)

  test("SoundUtils tank and healer death settings disable only their own WAV playback", function()
    local playCalls = {}
    WithGlobals({
      IsiLiveDB = {
        soundTankDiedEnabled = false,
        soundHealerDiedEnabled = true,
      },
      GetTime = function()
        return 100
      end,
      PlaySoundFile = function(path)
        playCalls[#playCalls + 1] = path
        return true
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.False(addon.SoundUtils.PlayTankDied(), "disabled tank death setting must suppress tank WAV")
      Assert.True(addon.SoundUtils.PlayHealerDied(), "enabled healer death setting must still play healer WAV")
    end)
    Assert.Equal(#playCalls, 1, "only the healer WAV must play")
    Assert.True(playCalls[1]:find("HealerDied.wav", 1, true) ~= nil, "the played file must be the healer WAV")
  end)

  test("SoundUtils death WAV failure records path channel and reason", function()
    WithGlobals({
      IsiLiveDB = {
        soundTankDiedEnabled = true,
      },
      GetTime = function()
        return 100
      end,
      PlaySoundFile = function()
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.False(addon.SoundUtils.PlayTankDied(), "rejected tank death WAV playback must fail")
      local result = addon.SoundUtils.GetLastPlayResult()
      Assert.Equal(result.reason, "play_rejected", "rejected PlaySoundFile must record the rejection reason")
      Assert.Equal(result.channel, "Master", "death WAV failure must record the resolved channel")
      Assert.True(result.path:find("TankDied.wav", 1, true) ~= nil, "death WAV failure must record the asset path")
    end)
  end)
end

local function RegisterStaticDeathWavTests(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function ReadLe16(bytes, offset)
    local b1, b2 = bytes:byte(offset, offset + 1)
    return (b1 or 0) + ((b2 or 0) * 256)
  end

  local function ReadLe32(bytes, offset)
    local b1, b2, b3, b4 = bytes:byte(offset, offset + 3)
    return (b1 or 0) + ((b2 or 0) * 256) + ((b3 or 0) * 65536) + ((b4 or 0) * 16777216)
  end

  local function ReadWavInfo(path)
    local file = assert(io.open(path, "rb"))
    local bytes = file:read("*a")
    file:close()
    Assert.Equal(bytes:sub(1, 4), "RIFF", path .. " must be a RIFF file")
    Assert.Equal(bytes:sub(9, 12), "WAVE", path .. " must be a WAVE file")

    local audioFormat = nil
    local channels = nil
    local sampleRate = nil
    local blockAlign = nil
    local bitsPerSample = nil
    local dataBytes = nil
    local dataOffset = nil
    local fmtChunkSize = nil
    local offset = 13
    while offset + 7 <= #bytes do
      local chunkId = bytes:sub(offset, offset + 3)
      local chunkSize = ReadLe32(bytes, offset + 4)
      local payloadOffset = offset + 8
      if chunkId == "fmt " then
        fmtChunkSize = chunkSize
        audioFormat = ReadLe16(bytes, payloadOffset)
        channels = ReadLe16(bytes, payloadOffset + 2)
        sampleRate = ReadLe32(bytes, payloadOffset + 4)
        blockAlign = ReadLe16(bytes, payloadOffset + 12)
        bitsPerSample = ReadLe16(bytes, payloadOffset + 14)
      elseif chunkId == "data" then
        dataBytes = chunkSize
        dataOffset = payloadOffset
        break
      end
      offset = payloadOffset + chunkSize
      if chunkSize % 2 == 1 then
        offset = offset + 1
      end
    end

    Assert.True(type(sampleRate) == "number" and sampleRate > 0, path .. " must declare a sample rate")
    Assert.True(type(blockAlign) == "number" and blockAlign > 0, path .. " must declare block align")
    Assert.True(type(dataBytes) == "number" and dataBytes > 0, path .. " must contain PCM data")

    local maxAbs = 0
    if bitsPerSample == 16 and type(dataOffset) == "number" then
      local dataEnd = math.min(#bytes, dataOffset + dataBytes - 1)
      local i = dataOffset
      while i + 1 <= dataEnd do
        local sample = ReadLe16(bytes, i)
        if sample >= 32768 then
          sample = sample - 65536
        end
        local absValue = math.abs(sample)
        if absValue > maxAbs then
          maxAbs = absValue
        end
        i = i + 2
      end
    end

    return {
      audioFormat = audioFormat,
      channels = channels,
      sampleRate = sampleRate,
      blockAlign = blockAlign,
      bitsPerSample = bitsPerSample,
      fmtChunkSize = fmtChunkSize,
      durationSeconds = dataBytes / (sampleRate * blockAlign),
      peakRatio = maxAbs / 32768,
    }
  end

  test("SoundUtils keeps native SpeakText TTS disabled", function()
    local speakCalls = 0
    WithGlobals({
      IsiLiveDB = { ttsAnnouncementsEnabled = true },
      C_VoiceChat = {
        GetTtsVoices = function()
          return { { voiceID = 7 } }
        end,
        SpeakText = function()
          speakCalls = speakCalls + 1
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.Nil(addon.SoundUtils.SpeakTts, "native SpeakText wrapper must not be exposed")
      Assert.Nil(addon.SoundUtils.IsTtsEnabled, "removed TTS setting helper must not be exposed")
      Assert.Nil(addon.SoundUtils.ShouldAnnounceName, "removed name-announcement helper must not be exposed")
      Assert.Nil(addon.SoundUtils.ShouldAnnounceClass, "removed class-announcement helper must not be exposed")
    end)
    Assert.Equal(speakCalls, 0, "loading sound utils must not call C_VoiceChat.SpeakText")
  end)

  test("SoundUtils death WAV assets stay single-announcement length", function()
    local tankInfo = ReadWavInfo("sounds/TankDied.wav")
    local healerInfo = ReadWavInfo("sounds/HealerDied.wav")
    for label, info in pairs({ TankDied = tankInfo, HealerDied = healerInfo }) do
      Assert.Equal(info.audioFormat, 1, label .. ".wav must use PCM format")
      Assert.Equal(info.fmtChunkSize, 16, label .. ".wav must use the canonical PCM fmt chunk")
      Assert.Equal(info.channels, 1, label .. ".wav must be mono")
      Assert.Equal(info.sampleRate, 44100, label .. ".wav must use the addon sound sample rate")
      Assert.Equal(info.bitsPerSample, 16, label .. ".wav must be 16-bit PCM")
      Assert.True(info.durationSeconds <= 1.2, label .. ".wav must contain only one short spoken announcement")
      Assert.True(info.peakRatio >= 0.85, label .. ".wav must be normalized loudly enough for in-game playback")
    end
  end)

  local function BuildFactoryStaticWavEnv()
    local env = { wavs = {}, deps = nil, shown = {}, spoke = 0 }
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
        SpeakTts = function()
          env.spoke = env.spoke + 1
          return true
        end,
        PlayTankDied = function()
          env.wavs[#env.wavs + 1] = "tank"
        end,
        PlayHealerDied = function()
          env.wavs[#env.wavs + 1] = "healer"
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
        return {
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

  test("Factory death alert uses only bundled tank and healer death WAVs", function()
    local env = BuildFactoryStaticWavEnv()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, env.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(env.ctxStub)
      env.deps.onRoleDeath("TANK", "party1")
      env.deps.onRoleDeath("HEALER", "party2")
      env.deps.onRoleDeath("DAMAGER", "party3")
    end)
    Assert.Equal(env.wavs[1], "tank", "tank death must play the tank WAV")
    Assert.Equal(env.wavs[2], "healer", "healer death must play the healer WAV")
    Assert.Equal(#env.wavs, 2, "damage-dealer deaths have no bundled WAV")
    Assert.Equal(env.spoke, 0, "factory must not call SpeakTts even when a stale stub exists")
  end)

  test("Factory death alert reports failed static WAV playback without TTS fallback", function()
    local printed = {}
    local env = BuildFactoryStaticWavEnv()
    env.seed.SoundUtils.PlayTankDied = function()
      return false
    end
    env.seed.SoundUtils.GetLastPlayResult = function()
      return {
        reason = "play_rejected",
        channel = "Master",
        path = "Interface\\AddOns\\isiLive\\sounds\\TankDied.wav",
      }
    end

    WithGlobals({
      print = function(message)
        printed[#printed + 1] = message
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, env.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(env.ctxStub)
      env.deps.onRoleDeath("TANK", "party1")
    end)

    Assert.Equal(env.wavs[1], nil, "failed tank death sound helper must not be counted as played")
    Assert.Equal(env.spoke, 0, "failed static WAV playback must not fall back to stale SpeakTts")
    Assert.Equal(#printed, 1, "failed death WAV playback must print one diagnostic line")
    Assert.True(printed[1]:find("role=TANK", 1, true) ~= nil, "diagnostic must include the role")
    Assert.True(printed[1]:find("reason=play_rejected", 1, true) ~= nil, "diagnostic must include the failure reason")
    Assert.True(printed[1]:find("TankDied.wav", 1, true) ~= nil, "diagnostic must include the asset path")
  end)

  test("Factory death alert keeps the on-screen warning to tank and healer", function()
    local env = BuildFactoryStaticWavEnv()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, env.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(env.ctxStub)
      env.deps.onRoleDeath("TANK", "party1")
      env.deps.onRoleDeath("DAMAGER", "party3")
    end)
    Assert.Equal(#env.shown, 1, "only the tank death renders the on-screen warning")
    Assert.Equal(env.shown[1], "TANK", "the rendered on-screen role must be the tank")
  end)

  test("Factory death alert drops immediate duplicate tank and healer role announcements", function()
    local now = 100
    local env = BuildFactoryStaticWavEnv()
    WithGlobals({
      GetTime = function()
        return now
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, env.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(env.ctxStub)
      env.deps.onRoleDeath("TANK", "party1")
      env.deps.onRoleDeath("TANK", "party1")
      env.deps.onRoleDeath("HEALER", "party2")
      env.deps.onRoleDeath("HEALER", "party2")
      now = 102
      env.deps.onRoleDeath("TANK", "party1")
    end)
    Assert.Equal(#env.shown, 3, "only immediate duplicate tank and healer warnings must be dropped")
    Assert.Equal(env.shown[1], "TANK", "the first tank warning must render")
    Assert.Equal(env.shown[2], "HEALER", "the first healer warning must render")
    Assert.Equal(env.shown[3], "TANK", "a later tank warning must be allowed")
    Assert.Equal(#env.wavs, 3, "only immediate duplicate tank and healer WAV files must be dropped")
    Assert.Equal(env.wavs[1], "tank", "the first tank WAV must play")
    Assert.Equal(env.wavs[2], "healer", "the first healer WAV must play")
    Assert.Equal(env.wavs[3], "tank", "a later tank WAV must play")
  end)

  test("Factory death alert suppresses paused death WAV without hiding tank or healer warnings", function()
    local env = BuildFactoryStaticWavEnv()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_factory_death_alert.lua" }, env.seed)
      addon._FactoryInternal.InitializeFactoryDeathAlertControllers(env.ctxStub)
      env.deps.onRoleDeath("TANK", "party1", { suppressAudio = true })
      env.deps.onRoleDeath("HEALER", "party2", { suppressAudio = true })
    end)
    Assert.Equal(#env.shown, 2, "suppressed death audio must not hide tank or healer warnings")
    Assert.Equal(env.shown[1], "TANK", "the tank warning must still render")
    Assert.Equal(env.shown[2], "HEALER", "the healer warning must still render")
    Assert.Equal(#env.wavs, 0, "suppressed death audio must not play tank or healer WAV files")
  end)
end

return function(test, ctx)
  RegisterDeathWatchTests(test, ctx)
  RegisterDeathAlertUiTests(test, ctx)
  RegisterFactoryWiringTests(test, ctx)
  RegisterStaticDeathWavTests(test, ctx)
end
