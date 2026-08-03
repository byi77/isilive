local ioLib = rawget(_G, "io")

-- Lua module paths come from the shared test harness (single source of truth).
-- Architecture tests extend this with docs / non-Lua assets they need to read.
---@diagnostic disable-next-line: undefined-global
local harnessChunk, harnessErr = loadfile("testmodul/isilive_test_harness.lua")
if not harnessChunk then
  error(string.format("cannot load test harness for architecture tests: %s", tostring(harnessErr)))
end
local Harness = harnessChunk()
if type(Harness) ~= "table" or type(Harness.FILE_PATHS) ~= "table" then
  error("test harness must expose FILE_PATHS table for architecture tests")
end

local FILE_PATHS = {}
for key, value in pairs(Harness.FILE_PATHS) do
  FILE_PATHS[key] = value
end
FILE_PATHS["ARCHITECTURE.md"] = "docs/ARCHITECTURE.md"
FILE_PATHS["ARCHITECTURE_RULES.md"] = "docs/ARCHITECTURE_RULES.md"
FILE_PATHS["CHANGELOG.md"] = "docs/CHANGELOG.md"
FILE_PATHS["CHANGELOG_RELEASE.md"] = "CHANGELOG_RELEASE.md"
FILE_PATHS["RELEASE.md"] = "docs/RELEASE.md"
FILE_PATHS["RULES.md"] = "docs/RULES.md"
FILE_PATHS["RULES_LOGIC.md"] = "docs/RULES_LOGIC.md"
FILE_PATHS["SEASON_INTAKE.md"] = "docs/SEASON_INTAKE.md"
FILE_PATHS["USECASES.md"] = "docs/USECASES.md"
FILE_PATHS["WARTUNG.md"] = "docs/WARTUNG.md"
FILE_PATHS["simulate_multi_invite_target_chain.lua"] = "tools/simulate_multi_invite_target_chain.lua"

local function ReadFile(path)
  if type(ioLib) ~= "table" or type(ioLib.open) ~= "function" then
    error("io library unavailable for architecture source checks")
  end

  local resolved = FILE_PATHS[path] or path
  local file, openErr = ioLib.open(resolved, "rb")
  if not file then
    error(string.format("cannot read %s: %s", tostring(resolved), tostring(openErr)))
  end

  local content = file:read("*a")
  file:close()
  return content or ""
end

local function AssertContains(Assert, haystack, needle, message)
  Assert.True(haystack:find(needle, 1, true) ~= nil, message)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Architecture group-join sound hook stays local to controller wiring", function()
    local wiringContent = ReadFile("isiLive_controller_wiring.lua")
    local groupContent = ReadFile("isiLive_group.lua")
    local leaderWatchContent = ReadFile("isiLive_leader_watch.lua")

    AssertContains(
      Assert,
      groupContent,
      "onGroupJoined = opts.onGroupJoined or function() end,",
      "Group controller must accept the optional group-join callback"
    )
    AssertContains(
      Assert,
      groupContent,
      "deps.onGroupJoined()",
      "Group controller must invoke the group-join callback on the first real join"
    )
    AssertContains(
      Assert,
      leaderWatchContent,
      'PlayKey("leader_transfer")',
      "LeaderWatch must route leader transfer audio through the registry key"
    )
    AssertContains(
      Assert,
      wiringContent,
      "onGroupJoined = ctx.onGroupJoined,",
      "ControllerWiring must pass the group-joined callback through"
    )
    AssertContains(
      Assert,
      wiringContent,
      "PlayGroupJoin()",
      "ControllerWiring member-join sound hook must use the dedicated SynthChord helper"
    )

    local playCalls = 0
    local playedPath = nil
    local playedChannel = nil
    local playedSoundKit = nil
    local stoppedHandles = {}
    local now = 0
    local db = {}
    WithGlobals({
      IsiLiveDB = db,
      GetTime = function()
        return now
      end,
      PlaySoundFile = function(path, channel)
        playCalls = playCalls + 1
        playedPath = path
        playedChannel = channel
        return true, "file:" .. tostring(playCalls)
      end,
      PlaySound = function(id, channel)
        playCalls = playCalls + 1
        playedSoundKit = id
        playedChannel = channel
        return true, "kit:" .. tostring(playCalls)
      end,
      StopSound = function(handle)
        stoppedHandles[#stoppedHandles + 1] = handle
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.NotNil(addon.SoundUtils, "sound utils module should load")
      Assert.NotNil(addon.SoundUtils.Registry, "sound utils should expose a sound registry")
      Assert.NotNil(addon.SoundUtils.SettingsOrder, "sound utils should expose a stable settings order")
      Assert.NotNil(addon.SoundUtils.GetEntry, "sound utils should expose a registry lookup helper")
      Assert.NotNil(addon.SoundUtils.HasKey, "sound utils should expose a registry presence helper")
      Assert.NotNil(addon.SoundUtils.IsEnabled, "sound utils should expose an enabled-state helper")
      Assert.NotNil(addon.SoundUtils.PlayKey, "sound utils should expose a key-based play helper")
      Assert.True(addon.SoundUtils.HasKey("leader_transfer"), "sound registry should include the leader-transfer key")
      Assert.True(addon.SoundUtils.HasKey("group_join"), "sound registry should include the group-join key")
      Assert.True(
        addon.SoundUtils.HasKey("ready_check_complete"),
        "sound registry should include the ready-check-complete key"
      )
      Assert.True(addon.SoundUtils.HasKey("portal_available"), "sound registry should include the portal key")
      Assert.True(addon.SoundUtils.HasKey("battle_res"), "sound registry should include the battle-res key")
      Assert.True(addon.SoundUtils.HasKey("battle_res_ready"), "sound registry should include the battle-res-ready key")
      Assert.True(addon.SoundUtils.HasKey("bloodlust"), "sound registry should include the bloodlust key")
      Assert.True(addon.SoundUtils.HasKey("bloodlust_ready"), "sound registry should include the bloodlust-ready key")
      local leaderEntry = addon.SoundUtils.GetEntry("leader_transfer")
      Assert.NotNil(leaderEntry, "leader-transfer entry should exist")
      Assert.Equal(
        leaderEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\CartoonVoiceBaritone.ogg",
        "leader-transfer entry should point at the transfer asset"
      )
      Assert.True(leaderEntry.defaultEnabled, "leader-transfer sound should default to enabled")
      Assert.Equal(
        leaderEntry.settingKey,
        "soundLeadEnabled",
        "leader-transfer sound should map to the lead-enabled setting key"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("leader_transfer"),
        "leader-transfer sound should be enabled by default when no DB override exists"
      )
      local groupEntry = addon.SoundUtils.GetEntry("group_join")
      Assert.NotNil(groupEntry, "group-join entry should exist")
      Assert.Equal(
        groupEntry.settingKey,
        "soundGroupJoinEnabled",
        "group-join sound should map to the group-join setting key"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("group_join"),
        "group-join sound should be enabled by default when no DB override exists"
      )
      local readyCheckCompleteEntry = addon.SoundUtils.GetEntry("ready_check_complete")
      Assert.NotNil(readyCheckCompleteEntry, "ready-check-complete sound entry should exist")
      Assert.Equal(
        readyCheckCompleteEntry.settingKey,
        "soundReadyCheckCompleteEnabled",
        "ready-check-complete sound should map to the ready-check-complete setting key"
      )
      Assert.Equal(
        readyCheckCompleteEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\BttF_Tinkle.wav",
        "ready-check-complete sound should use the bundled BttF tinkle asset"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("ready_check_complete"),
        "ready-check-complete sound should default to enabled when no DB override exists"
      )
      local portalEntry = addon.SoundUtils.GetEntry("portal_available")
      Assert.NotNil(portalEntry, "portal sound entry should exist")
      Assert.Equal(
        portalEntry.settingKey,
        "soundPortalAvailableEnabled",
        "portal sound should map to the portal-enabled setting key"
      )
      Assert.Equal(
        portalEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\Portal.ogg",
        "portal sound should use the bundled incoming-summon asset"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("portal_available"),
        "portal sound should default to enabled when no DB override exists"
      )
      local battleResEntry = addon.SoundUtils.GetEntry("battle_res")
      Assert.NotNil(battleResEntry, "battle-res sound entry should exist")
      Assert.Equal(
        battleResEntry.settingKey,
        "soundBattleResEnabled",
        "battle-res sound should map to the battle-res setting key"
      )
      Assert.Equal(
        battleResEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\ChickenAlarm.ogg",
        "battle-res entry should point at the chicken-alarm asset"
      )
      Assert.Equal(
        battleResEntry.fallbackFile,
        "Interface\\AddOns\\isiLive\\sounds\\RoosterChickenCalls.ogg",
        "battle-res entry should fall back to a non-ready BR asset if the primary file is rejected"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("battle_res"),
        "battle-res sound should default to enabled when no DB override exists"
      )
      local battleResReadyEntry = addon.SoundUtils.GetEntry("battle_res_ready")
      Assert.NotNil(battleResReadyEntry, "battle-res-ready sound entry should exist")
      Assert.Equal(
        battleResReadyEntry.settingKey,
        "soundBattleResReadyEnabled",
        "battle-res-ready sound should map to the battle-res-ready setting key"
      )
      Assert.Equal(
        battleResReadyEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\BattleRezReady.wav",
        "battle-res-ready entry should point at the bundled WAV asset"
      )
      Assert.False(
        battleResEntry.fallbackFile == battleResReadyEntry.file,
        "combat battle-res fallback must not reuse the battle-res-ready WAV asset"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("battle_res_ready"),
        "battle-res-ready sound should default to enabled when no DB override exists"
      )
      local bloodlustEntry = addon.SoundUtils.GetEntry("bloodlust")
      Assert.NotNil(bloodlustEntry, "bloodlust sound entry should exist")
      Assert.Equal(
        bloodlustEntry.settingKey,
        "soundBloodlustEnabled",
        "bloodlust sound should map to the bloodlust setting key"
      )
      Assert.Equal(
        bloodlustEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\BoxingArenaSound.ogg",
        "bloodlust entry should point at the boxing-arena asset"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("bloodlust"),
        "bloodlust sound should default to enabled when no DB override exists"
      )
      local bloodlustReadyEntry = addon.SoundUtils.GetEntry("bloodlust_ready")
      Assert.NotNil(bloodlustReadyEntry, "bloodlust-ready sound entry should exist")
      Assert.Equal(
        bloodlustReadyEntry.settingKey,
        "soundBloodlustReadyEnabled",
        "bloodlust-ready sound should map to the bloodlust-ready setting key"
      )
      Assert.Equal(
        bloodlustReadyEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\BloodlustReady.wav",
        "bloodlust-ready entry should point at the bundled WAV asset"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("bloodlust_ready"),
        "bloodlust-ready sound should default to enabled when no DB override exists"
      )
      local piReceivedEntry = addon.SoundUtils.GetEntry("power_infusion_received")
      Assert.NotNil(piReceivedEntry, "PI-received sound entry should exist")
      Assert.Equal(
        piReceivedEntry.settingKey,
        "soundPowerInfusionReceivedEnabled",
        "PI-received sound should map to the PI-received setting key"
      )
      Assert.Equal(
        piReceivedEntry.file,
        "Interface\\AddOns\\isiLive\\sounds\\PowerInfusionReceived.wav",
        "PI-received entry should point at the bundled WAV asset"
      )
      Assert.True(
        addon.SoundUtils.IsEnabled("power_infusion_received"),
        "PI-received sound should default to enabled when no DB override exists"
      )
      Assert.NotNil(addon.SoundUtils.PlayGroupJoin, "sound utils should expose a dedicated group-join sound helper")
      Assert.NotNil(addon.SoundUtils.StopAllActiveSounds, "sound utils should expose a stop-all helper")
      Assert.NotNil(
        addon.SoundUtils.PlayReadyCheckComplete,
        "sound utils should expose a dedicated ready-check-complete sound helper"
      )
      Assert.NotNil(addon.SoundUtils.PlayPortalAvailable, "sound utils should expose a dedicated portal sound helper")
      Assert.NotNil(addon.SoundUtils.PlayIncomingSummon, "sound utils should expose a dedicated summon sound helper")
      Assert.NotNil(addon.SoundUtils.PlayBattleRes, "sound utils should expose a dedicated battle-res sound helper")
      Assert.NotNil(
        addon.SoundUtils.PlayBattleResReady,
        "sound utils should expose a dedicated battle-res-ready sound helper"
      )
      Assert.NotNil(addon.SoundUtils.PlayBloodlust, "sound utils should expose a dedicated bloodlust sound helper")
      Assert.NotNil(
        addon.SoundUtils.PlayBloodlustReady,
        "sound utils should expose a dedicated bloodlust-ready sound helper"
      )
      Assert.NotNil(
        addon.SoundUtils.PlayPowerInfusionReceived,
        "sound utils should expose a dedicated PI-received sound helper"
      )
      addon.SoundUtils.PlayKey("leader_transfer")
      Assert.Equal(playCalls, 1, "leader-transfer sound helper should play exactly once")
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\CartoonVoiceBaritone.ogg",
        "leader-transfer sound helper should use the transfer asset"
      )
      Assert.Equal(playedChannel, "Master", "leader-transfer sound helper should use the Master channel")
      db.soundGroupJoinEnabled = true
      addon.SoundUtils.PlayGroupJoin()
      Assert.Equal(playCalls, 2, "group-join sound helper should play exactly once after the leader sound")
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\SynthChord.ogg",
        "group-join sound helper should use the SynthChord asset"
      )
      Assert.Equal(playedChannel, "Master", "group-join sound helper should use the Master channel")
      addon.SoundUtils.PlayReadyCheckComplete()
      Assert.Equal(playCalls, 3, "ready-check-complete sound helper should play exactly once after the group sound")
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\BttF_Tinkle.wav",
        "ready-check-complete sound helper should use the bundled BttF tinkle asset"
      )
      Assert.Equal(playedChannel, "Master", "ready-check-complete sound helper should use the Master channel")
      addon.SoundUtils.PlayPortalAvailable()
      Assert.Equal(playCalls, 4, "portal sound helper should play exactly once after the ready-check sound")
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\Portal.ogg",
        "portal sound helper should use the bundled portal asset"
      )
      Assert.Equal(playedChannel, "Master", "portal sound helper should use the Master channel")
      addon.SoundUtils.PlayBattleRes()
      addon.SoundUtils.PlayBattleResReady()
      addon.SoundUtils.PlayBloodlust()
      addon.SoundUtils.PlayBloodlustReady()
      addon.SoundUtils.PlayPowerInfusionReceived()
      Assert.Equal(
        playCalls,
        9,
        "battle-res, battle-res-ready, bloodlust, bloodlust-ready, and PI-received play their configured assets"
      )
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\PowerInfusionReceived.wav",
        "PI-received helper should use the bundled WAV asset"
      )
      addon.SoundUtils.StopAllActiveSounds()
      Assert.Equal(#stoppedHandles, 9, "stop-all helper must stop every active sound handle")
      local stoppedByHandle = {}
      for _, handle in ipairs(stoppedHandles) do
        stoppedByHandle[handle] = true
      end
      Assert.True(stoppedByHandle["file:1"] == true, "stop-all helper must pass file playback handles to StopSound")

      db.soundLeadEnabled = false
      db.soundGroupJoinEnabled = true
      db.soundReadyCheckCompleteEnabled = false
      db.soundPortalAvailableEnabled = false
      db.soundBattleResEnabled = true
      db.soundBattleResReadyEnabled = true
      db.soundBloodlustEnabled = true
      db.soundBloodlustReadyEnabled = true
      db.soundPowerInfusionReceivedEnabled = true
      now = 2.9
      playCalls = 0
      addon.SoundUtils.PlayGroupJoin()
      Assert.Equal(playCalls, 1, "same sound key replay should play after the one-second spam window")

      now = 4
      addon.SoundUtils.PlayKey("leader_transfer")
      addon.SoundUtils.PlayGroupJoin()
      addon.SoundUtils.PlayReadyCheckComplete()
      addon.SoundUtils.PlayPortalAvailable()
      addon.SoundUtils.PlayBattleRes()
      addon.SoundUtils.PlayBattleResReady()
      addon.SoundUtils.PlayBloodlust()
      addon.SoundUtils.PlayBloodlustReady()
      addon.SoundUtils.PlayPowerInfusionReceived()
      Assert.Equal(
        playCalls,
        7,
        "enabled group-join, battle-res, battle-res-ready, bloodlust, bloodlust-ready, and PI-received should play; "
          .. "disabled lead, ready-check, and portal stay silent"
      )
      Assert.Equal(
        playedPath,
        "Interface\\AddOns\\isiLive\\sounds\\PowerInfusionReceived.wav",
        "PI-received asset should be the last played sound"
      )

      playCalls = 0
      playedSoundKit = nil
      _G.SOUNDKIT = {
        UI_TEST_SOUND = 4242,
      }
      now = 10
      addon.SoundUtils.PlaySoundKit(nil)
      addon.SoundUtils.PlaySoundKit("UNKNOWN_SOUND")
      Assert.Equal(playCalls, 0, "missing SoundKit values must fail closed without playback")
      addon.SoundUtils.PlaySoundKit("UI_TEST_SOUND", "Dialog")
      Assert.Equal(playCalls, 1, "named SoundKit values must resolve through SOUNDKIT")
      Assert.Equal(playedSoundKit, 4242, "named SoundKit playback must pass the resolved numeric id")
      Assert.Equal(playedChannel, "Dialog", "explicit SoundKit channel should be preserved")
      addon.SoundUtils.PlaySoundKit("UI_TEST_SOUND", "Dialog")
      Assert.Equal(playCalls, 1, "SoundKit duplicate playback should be suppressed inside the spam window")
      now = 12.9
      addon.SoundUtils.PlaySoundKit("UI_TEST_SOUND", "Dialog")
      Assert.Equal(playCalls, 2, "SoundKit playback should resume after the spam window")
      now = 13
      addon.SoundUtils.PlaySoundKit("UI_TEST_SOUND", "Dialog")
      Assert.Equal(playCalls, 2, "SoundKit playback should be suppressed again inside the new window")
      now = 16
      addon.SoundUtils.PlaySoundKit(7777)
      Assert.Equal(playCalls, 3, "numeric SoundKit ids must play directly")
      Assert.Equal(playedSoundKit, 7777, "numeric SoundKit playback must pass the given id")
      Assert.Equal(playedChannel, "Master", "SoundKit playback defaults to the Master channel")

      local aurochsIDs = addon.SoundUtils.GetAstralAurochsSoundFileIDs()
      Assert.NotNil(aurochsIDs, "astral aurochs sound mute list must be exposed for tests")
      Assert.True(#aurochsIDs >= 88, "astral aurochs mute list should include summon, special, flight, and loop files")
      local hasWingFlap = false
      local hasLoop = false
      for _, id in ipairs(aurochsIDs) do
        if id == 4906115 then
          hasWingFlap = true
        elseif id == 6788040 then
          hasLoop = true
        end
      end
      Assert.True(hasWingFlap, "astral aurochs mute list must include the model wing-flap flight sound")
      Assert.True(hasLoop, "astral aurochs mute list must include the model loop flight sound")
      local yakIDs = addon.SoundUtils.GetGrandExpeditionYakSoundFileIDs()
      local brutosaurIDs = addon.SoundUtils.GetGildedBrutosaurSoundFileIDs()
      local dkHorseIDs = addon.SoundUtils.GetDkApocalypseHorseSoundFileIDs()
      Assert.True(#yakIDs >= 300, "grand expedition yak mute list must include verified model and footstep files")
      Assert.True(#brutosaurIDs >= 100, "gilded brutosaur mute list must include verified model and special files")
      Assert.Equal(#dkHorseIDs, 3, "DK apocalypse horse mute list must include the three known summon files")
      Assert.Equal(yakIDs[1], 613111, "grand expedition yak mute list must start with the verified base yak file")
      Assert.Equal(
        brutosaurIDs[1],
        1824124,
        "gilded brutosaur mute list must start with the verified base brutosaur file"
      )
      local hasYakFootstep = false
      local hasYakMountFoley = false
      local hasYakFalsePositive = false
      for _, id in ipairs(yakIDs) do
        if id == 1023697 then
          hasYakFootstep = true
        elseif id == 633579 then
          hasYakMountFoley = true
        elseif id == 3528725 then
          hasYakFalsePositive = true
        end
      end
      Assert.True(hasYakFootstep, "grand expedition yak mute list must include verified footstep files")
      Assert.True(hasYakMountFoley, "grand expedition yak mute list must include verified yak mount foley files")
      Assert.False(
        hasYakFalsePositive,
        "grand expedition yak mute list must not include the MountID 1460 false-positive row"
      )
      local hasBrutosaurFootstep = false
      local hasBrutosaurMoving = false
      local hasBrutosaurLateFidget = false
      for _, id in ipairs(brutosaurIDs) do
        if id == 801310 then
          hasBrutosaurFootstep = true
        elseif id == 6211355 then
          hasBrutosaurMoving = true
        elseif id == 6211670 then
          hasBrutosaurLateFidget = true
        end
      end
      Assert.True(hasBrutosaurFootstep, "gilded brutosaur mute list must include verified footstep files")
      Assert.True(hasBrutosaurMoving, "gilded brutosaur mute list must include verified mount-special moving files")
      Assert.True(hasBrutosaurLateFidget, "gilded brutosaur mute list must include verified late fidget files")
      Assert.Equal(dkHorseIDs[1], 987917, "DK apocalypse horse mute list must start with the first known summon file")
      Assert.Equal(dkHorseIDs[3], 987921, "DK apocalypse horse mute list must include the final known summon file")
    end)

    local fallbackCalls = {}
    WithGlobals({
      IsiLiveDB = {
        soundBattleResEnabled = true,
        soundBloodlustEnabled = true,
      },
      GetTime = function()
        return 100
      end,
      PlaySoundFile = function(path, channel)
        fallbackCalls[#fallbackCalls + 1] = { path = path, channel = channel }
        if path == "Interface\\AddOns\\isiLive\\sounds\\ChickenAlarm.ogg" then
          return false
        end
        return true
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.True(addon.SoundUtils.PlayBattleRes(), "battle-res should fall back when the primary file is rejected")
      Assert.Equal(
        fallbackCalls[1].path,
        "Interface\\AddOns\\isiLive\\sounds\\ChickenAlarm.ogg",
        "BR must try the primary configured asset first"
      )
      Assert.Equal(fallbackCalls[1].channel, "Master", "BR primary attempt must keep the configured channel")
      Assert.Equal(
        fallbackCalls[2].path,
        "Interface\\AddOns\\isiLive\\sounds\\RoosterChickenCalls.ogg",
        "BR must try the fallback asset when the primary asset is rejected"
      )
      Assert.Equal(fallbackCalls[2].channel, "Master", "BR fallback must keep the configured channel")
      Assert.Equal(#fallbackCalls, 2, "BR fallback must add exactly one secondary playback attempt")
    end)

    local bloodlustCalls = {}
    WithGlobals({
      IsiLiveDB = {
        soundBloodlustEnabled = true,
      },
      GetTime = function()
        return 200
      end,
      PlaySoundFile = function(path, channel)
        bloodlustCalls[#bloodlustCalls + 1] = { path = path, channel = channel }
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.False(addon.SoundUtils.PlayBloodlust(), "bloodlust should report rejected playback without a fallback")
      Assert.Equal(#bloodlustCalls, 1, "bloodlust must not inherit the battle-res fallback")
      Assert.Equal(
        bloodlustCalls[1].path,
        "Interface\\AddOns\\isiLive\\sounds\\BoxingArenaSound.ogg",
        "bloodlust must keep the BoxingArenaSound asset"
      )
    end)

    local muted = {}
    local unmuted = {}

    WithGlobals({
      C_Sound = {
        MuteSoundFile = function(id)
          muted[#muted + 1] = id
        end,
        UnmuteSoundFile = function(id)
          unmuted[#unmuted + 1] = id
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.True(addon.SoundUtils.ApplyAstralAurochsSoundSetting(true), "C_Sound mute API should be accepted")
      Assert.Equal(muted[1], 7340960, "C_Sound mute API should receive astral aurochs file IDs")
      Assert.True(addon.SoundUtils.ApplyAstralAurochsSoundSetting(false), "C_Sound unmute API should be accepted")
      Assert.Equal(unmuted[1], 7340960, "C_Sound unmute API should receive astral aurochs file IDs")
      muted = {}
      unmuted = {}
      Assert.True(
        addon.SoundUtils.ApplyDkApocalypseHorseSoundSetting(true),
        "C_Sound DK horse mute API should be accepted"
      )
      Assert.Equal(muted[1], 987917, "C_Sound DK horse mute API should receive the first horse file ID")
      Assert.True(
        addon.SoundUtils.ApplyDkApocalypseHorseSoundSetting(false),
        "C_Sound DK horse unmute API should be accepted"
      )
      Assert.Equal(unmuted[3], 987921, "C_Sound DK horse unmute API should receive the final horse file ID")
    end)
  end)

  test("SoundUtils suppresses identical sound keys for one second", function()
    local now = 10
    local fileCalls = 0
    local kitCalls = 0
    WithGlobals({
      IsiLiveDB = {},
      GetTime = function()
        return now
      end,
      PlaySoundFile = function()
        fileCalls = fileCalls + 1
        return true, "file:" .. tostring(fileCalls)
      end,
      PlaySound = function()
        kitCalls = kitCalls + 1
        return true, "kit:" .. tostring(kitCalls)
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      local file = "Interface\\AddOns\\isiLive\\sounds\\SynthChord.ogg"

      Assert.True(addon.SoundUtils.Play(file, "Master", "group"), "first scoped file playback should succeed")
      now = 10.999
      Assert.False(
        addon.SoundUtils.Play(file, "Master", "group"),
        "identical scoped file playback must be suppressed before one second"
      )
      Assert.Equal(fileCalls, 1, "suppressed scoped file playback must not reach PlaySoundFile")
      Assert.Equal(
        addon.SoundUtils.GetLastPlayResult().reason,
        "spam_window",
        "suppressed scoped file playback must expose the spam-window reason"
      )
      Assert.True(
        addon.SoundUtils.Play(file, "Master", "other"),
        "a different explicit spam scope should remain independent"
      )
      now = 11
      Assert.True(
        addon.SoundUtils.Play(file, "Master", "group"),
        "identical scoped file playback should resume at exactly one second"
      )

      Assert.True(addon.SoundUtils.PlaySoundKit(4242, "Master"), "first SoundKit playback should succeed")
      Assert.False(
        addon.SoundUtils.PlaySoundKit(4242, "Master"),
        "identical SoundKit playback must be suppressed before one second"
      )
      Assert.Equal(kitCalls, 1, "suppressed SoundKit playback must not reach PlaySound")
      now = 12
      Assert.True(
        addon.SoundUtils.PlaySoundKit(4242, "Master"),
        "identical SoundKit playback should resume after one second"
      )
    end)
  end)

  test("SoundUtils uses Master by default and SFX when configured", function()
    local now = 1
    local playedChannel = nil
    local playedByPath = {}
    local db = {}

    WithGlobals({
      IsiLiveDB = db,
      GetTime = function()
        return now
      end,
      PlaySoundFile = function(path, channel)
        playedChannel = channel
        playedByPath[path] = channel
        return true
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.Equal(
        addon.SoundUtils.GetConfiguredOutputChannel(),
        "Master",
        "sound output channel should default to Master"
      )

      addon.SoundUtils.PlayGroupJoin()
      Assert.Equal(playedChannel, "Master", "built-in sound playback should use Master by default")

      db.soundOutputChannel = "SFX"
      now = 4
      addon.SoundUtils.PlayGroupJoin()
      Assert.Equal(playedChannel, "SFX", "built-in sound playback should use configured SFX output")

      for _, key in ipairs(addon.SoundUtils.SettingsOrder) do
        now = now + 1
        local entry = addon.SoundUtils.GetEntry(key)
        playedChannel = nil
        Assert.True(addon.SoundUtils.PlayKey(key), "registered sound key should play: " .. tostring(key))
        Assert.Equal(playedChannel, "SFX", "runtime sound key must use configured SFX output: " .. tostring(key))

        now = now + 1
        playedChannel = nil
        Assert.True(addon.SoundUtils.PlayPreviewKey(key), "preview sound key should play: " .. tostring(key))
        Assert.Equal(playedChannel, "SFX", "preview sound key must use configured SFX output: " .. tostring(key))
        Assert.Equal(
          playedByPath[entry.file],
          "SFX",
          "registry asset must be bound to configured SFX output: " .. tostring(entry.file)
        )
      end

      db.soundOutputChannel = "Dialog"
      now = 7
      addon.SoundUtils.PlayGroupJoin()
      Assert.Equal(playedChannel, "Master", "invalid sound output channel should fail closed to Master")
    end)
  end)

  test("SoundUtils resolves German spoken WAV assets only for deDE", function()
    local calls = {}
    local locale = "deDE"
    local now = 0

    WithGlobals({
      IsiLiveDB = {},
      GetLocale = function()
        return locale
      end,
      GetTime = function()
        now = now + 1
        return now
      end,
      PlaySoundFile = function(path, channel)
        calls[#calls + 1] = { path = path, channel = channel }
        return true
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      local localizedKeys = {
        battle_res_ready = "BattleRezReady_deDE.wav",
        bloodlust_ready = "BloodlustReady_deDE.wav",
        power_infusion_received = "PowerInfusionReceived_deDE.wav",
        portal_available = "Portal_deDE.wav",
        tank_died = "TankDied_deDE.wav",
        healer_died = "HealerDied_deDE.wav",
      }

      for key, expectedFile in pairs(localizedKeys) do
        local entry = addon.SoundUtils.GetEntry(key)
        Assert.NotNil(entry.localizedFiles, key .. " must declare localized static WAV files")
        Assert.Equal(
          addon.SoundUtils.ResolveSoundFile(entry),
          "Interface\\AddOns\\isiLive\\sounds\\" .. expectedFile,
          key .. " must resolve to the German WAV on deDE clients"
        )
        Assert.True(addon.SoundUtils.PlayKey(key), key .. " must play the German WAV")
        Assert.True(
          calls[#calls].path:find(expectedFile, 1, true) ~= nil,
          key .. " playback must use the German WAV on deDE clients"
        )
      end

      locale = "frFR"
      calls = {}
      addon.SoundUtils.PlayBattleResReady()
      addon.SoundUtils.PlayBloodlustReady()
      addon.SoundUtils.PlayPowerInfusionReceived()
      addon.SoundUtils.PlayPortalAvailable()
      addon.SoundUtils.PlayTankDied()
      addon.SoundUtils.PlayHealerDied()
      Assert.True(calls[1].path:find("BattleRezReady.wav", 1, true) ~= nil, "frFR must use English BR-ready")
      Assert.True(calls[2].path:find("BloodlustReady.wav", 1, true) ~= nil, "frFR must use English BL-ready")
      Assert.True(calls[3].path:find("PowerInfusionReceived.wav", 1, true) ~= nil, "frFR must use English PI")
      Assert.True(calls[4].path:find("Portal.ogg", 1, true) ~= nil, "frFR must use default incoming summon")
      Assert.True(calls[5].path:find("TankDied.wav", 1, true) ~= nil, "frFR must use English tank death")
      Assert.True(calls[6].path:find("HealerDied.wav", 1, true) ~= nil, "frFR must use English healer death")
    end)
  end)

  test("SoundUtils Bloodlust-ready setting disables WAV playback", function()
    local playCalls = 0
    local db = {
      soundBloodlustReadyEnabled = false,
    }
    WithGlobals({
      IsiLiveDB = db,
      GetTime = function()
        return 30
      end,
      PlaySoundFile = function()
        playCalls = playCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.False(
        addon.SoundUtils.IsEnabled("bloodlust_ready"),
        "bloodlust-ready setting should disable the WAV sound"
      )
      addon.SoundUtils.PlayBloodlustReady()
      Assert.Equal(playCalls, 0, "disabled bloodlust-ready setting must suppress WAV playback")

      db.soundBloodlustReadyEnabled = true
      addon.SoundUtils.PlayBloodlustReady()
      Assert.Equal(playCalls, 1, "enabled bloodlust-ready setting should allow one WAV playback")
    end)
  end)

  test("SoundUtils Battle Res-ready setting disables WAV playback", function()
    local playCalls = 0
    local db = {
      soundBattleResReadyEnabled = false,
    }
    WithGlobals({
      IsiLiveDB = db,
      GetTime = function()
        return 40
      end,
      PlaySoundFile = function()
        playCalls = playCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.False(
        addon.SoundUtils.IsEnabled("battle_res_ready"),
        "battle-res-ready setting should disable the WAV sound"
      )
      addon.SoundUtils.PlayBattleResReady()
      Assert.Equal(playCalls, 0, "disabled battle-res-ready setting must suppress WAV playback")

      db.soundBattleResReadyEnabled = true
      addon.SoundUtils.PlayBattleResReady()
      Assert.Equal(playCalls, 1, "enabled battle-res-ready setting should allow one WAV playback")
    end)
  end)

  test("SoundUtils Power Infusion received setting disables WAV playback", function()
    local playCalls = 0
    local db = {
      soundPowerInfusionReceivedEnabled = false,
    }
    WithGlobals({
      IsiLiveDB = db,
      GetTime = function()
        return 50
      end,
      PlaySoundFile = function()
        playCalls = playCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.False(
        addon.SoundUtils.IsEnabled("power_infusion_received"),
        "PI-received setting should disable the WAV sound"
      )
      addon.SoundUtils.PlayPowerInfusionReceived()
      Assert.Equal(playCalls, 0, "disabled PI-received setting must suppress WAV playback")

      db.soundPowerInfusionReceivedEnabled = true
      addon.SoundUtils.PlayPowerInfusionReceived()
      Assert.Equal(playCalls, 1, "enabled PI-received setting should allow one WAV playback")
    end)
  end)

  test("SoundUtils ready-check-complete setting disables BttF playback", function()
    local playCalls = 0
    local db = {
      soundReadyCheckCompleteEnabled = false,
    }
    WithGlobals({
      IsiLiveDB = db,
      GetTime = function()
        return 50
      end,
      PlaySoundFile = function()
        playCalls = playCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
      Assert.False(
        addon.SoundUtils.IsEnabled("ready_check_complete"),
        "ready-check-complete setting should disable the BttF sound"
      )
      addon.SoundUtils.PlayReadyCheckComplete()
      Assert.Equal(playCalls, 0, "disabled ready-check-complete setting must suppress BttF playback")

      db.soundReadyCheckCompleteEnabled = true
      addon.SoundUtils.PlayReadyCheckComplete()
      Assert.Equal(playCalls, 1, "enabled ready-check-complete setting should allow one BttF playback")
    end)
  end)

  test("Architecture kick tracker uses lightweight kick-column refresh hooks", function()
    local helpersContent = ReadFile("isiLive_factory_kick_tracker.lua")
    local secondaryFactoryContent = ReadFile("isiLive_factory_secondary.lua")
    local rosterPanelContent = ReadFile("isiLive_roster_panel.lua")

    AssertContains(
      Assert,
      helpersContent,
      "ctx.HandleKickTrackerEvent = function(event, unit, _, spellID)",
      "factory kick tracking must expose a central-gate kick event handler"
    )
    AssertContains(
      Assert,
      helpersContent,
      'event == "UNIT_SPELLCAST_SUCCEEDED"',
      "factory kick tracking must handle player/pet interrupt casts through the central event path"
    )
    AssertContains(
      Assert,
      helpersContent,
      'event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UNIT_PET"',
      "factory kick tracking must refresh interrupt availability through central events"
    )
    AssertContains(
      Assert,
      helpersContent,
      "ctx.rosterPanelController.RefreshKickColumn()",
      "factory kick tracking must use the dedicated roster kick refresh path"
    )
    AssertContains(
      Assert,
      helpersContent,
      'if type(IsGroupSyncActive) ~= "function" then\n      return false',
      "factory kick tracking must fail closed when the group-sync gate dependency is missing"
    )
    AssertContains(
      Assert,
      helpersContent,
      "if not IsKickSyncContextActive() then",
      "factory kick ticker must route polling through the group-sync gate"
    )
    AssertContains(
      Assert,
      secondaryFactoryContent,
      "ctx.isInInstanceGroup() == true",
      "factory kick group-sync gate must include verified automatic instance groups"
    )
    AssertContains(
      Assert,
      rosterPanelContent,
      "function controller.RefreshKickColumn()",
      "RosterPanel must expose a dedicated kick-column refresh helper"
    )
    AssertContains(
      Assert,
      rosterPanelContent,
      "SetKickCellText(row.kick, info, getL)",
      "RosterPanel dedicated kick-column refresh must use the same compact ready marker as full roster renders"
    )
    local rosterPanelRenderContent = ReadFile("isiLive_roster_panel_render.lua")
    AssertContains(
      Assert,
      rosterPanelRenderContent,
      'SetReadableText(cell, "|cff44ff44" .. readyText .. "|r")',
      "RosterPanel render module must render the compact kick-ready state in green"
    )
  end)
end
