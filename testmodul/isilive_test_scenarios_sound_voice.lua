---@diagnostic disable: undefined-global
-- Rule 266: "Voice instead of effect" per alert. Every test drives the real
-- sound registry and SoundUtils; leader transfer and group full run through
-- the real event dispatcher of the factory composition root.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local SOUND_DIR = "Interface\\AddOns\\isiLive\\sounds\\"

-- Expected files per alert, written out on purpose instead of read from the
-- registry, so a registry drift fails here.
local VOICE_CASES = {
  {
    key = "leader_transfer",
    voice = "LeaderTransfer",
    effectFile = "CartoonVoiceBaritone.ogg",
    voiceSetting = "soundLeadVoiceEnabled",
  },
  {
    key = "group_join",
    voice = "GroupFull",
    effectFile = "SynthChord.ogg",
    voiceSetting = "soundGroupJoinVoiceEnabled",
  },
  {
    key = "ready_check_complete",
    voice = "ReadyCheckComplete",
    effectFile = "BttF_Tinkle.ogg",
    voiceSetting = "soundReadyCheckCompleteVoiceEnabled",
  },
  {
    key = "battle_res",
    voice = "BattleResUsed",
    effectFile = "ChickenAlarm.ogg",
    voiceSetting = "soundBattleResVoiceEnabled",
  },
  {
    key = "bloodlust",
    voice = "BloodlustUsed",
    effectFile = "BoxingArenaSound.ogg",
    voiceSetting = "soundBloodlustVoiceEnabled",
  },
  {
    key = "aggro",
    voice = "Aggro",
    effectKit = "ALARM_CLOCK_WARNING_3",
    voiceSetting = "aggroAlertVoiceEnabled",
    soundSetting = "aggroAlertSound",
  },
  {
    key = "missed_kick",
    voice = "MissedKick",
    effectKit = "RAID_WARNING",
    voiceSetting = "missedKickVoiceEnabled",
    soundSetting = "missedKickSound",
  },
}

-- deDE takes the German line; every other addon language the English one.
local LOCALE_SUFFIX = { deDE = "_deDE", enUS = "", frFR = "", ruRU = "", trTR = "" }

local function BuildSoundGlobals(db, calls, clock, rejectPath)
  return {
    IsiLiveDB = db,
    GetTime = function()
      return clock.now
    end,
    SOUNDKIT = { ALARM_CLOCK_WARNING_3 = 12867, RAID_WARNING = 8959 },
    PlaySoundFile = function(path, channel)
      calls[#calls + 1] = { path = path, channel = channel }
      if rejectPath and path == rejectPath then
        return false
      end
      return true, #calls
    end,
    PlaySound = function(kit, channel)
      calls[#calls + 1] = { kit = kit, channel = channel }
      return true, #calls
    end,
    GetLocale = function()
      return "enUS"
    end,
  }
end

return function(test, ctx)
  local Assert = ctx.assert

  test(
    "SoundUtils voice option plays the localized voice line, the effect when off and the voice by default",
    function()
      local SOUNDKIT_IDS = { ALARM_CLOCK_WARNING_3 = 12867, RAID_WARNING = 8959 }
      for _, case in ipairs(VOICE_CASES) do
        for locale, suffix in pairs(LOCALE_SUFFIX) do
          for _, voiceValue in ipairs({ "nil", "true", "false" }) do
            ---@type table<string, any>
            local db = { locale = locale }
            if case.soundSetting then
              -- Aggro and missed kick stay opt-in (Pattern B); the voice is the
              -- default only once the sound itself is on.
              db[case.soundSetting] = true
            end
            if voiceValue ~= "nil" then
              db[case.voiceSetting] = voiceValue == "true"
            end
            local calls = {}
            local clock = { now = 10 }
            ctx.with_globals(BuildSoundGlobals(db, calls, clock), function()
              local addon = ctx.load_modules({ "isiLive_sound_registry.lua", "isiLive_sound_utils.lua" })
              local label = case.key .. " " .. locale .. " voice=" .. voiceValue
              Assert.True(addon.SoundUtils.PlayKey(case.key), label .. ": alert must play")
              Assert.Equal(#calls, 1, label .. ": exactly one playback")
              Assert.Equal(calls[1].channel, "Master", label .. ": Master channel")
              if voiceValue == "false" then
                if case.effectKit then
                  Assert.Equal(calls[1].kit, SOUNDKIT_IDS[case.effectKit], label .. ": SoundKit effect")
                else
                  Assert.Equal(calls[1].path, SOUND_DIR .. case.effectFile, label .. ": effect file")
                end
              else
                Assert.Equal(calls[1].path, SOUND_DIR .. case.voice .. suffix .. ".ogg", label .. ": voice line")
              end
              -- The preview follows the same choice.
              clock.now = 20
              Assert.True(addon.SoundUtils.PlayPreviewKey(case.key), label .. ": preview must play")
              Assert.Equal(calls[2].path, calls[1].path, label .. ": preview plays what the alert plays")
              Assert.Equal(calls[2].kit, calls[1].kit, label .. ": preview kit matches the alert")
            end)
          end
        end
      end
    end
  )

  test("SoundUtils voice option keeps the main sound switch and the opt-in alerts off", function()
    local calls = {}
    local clock = { now = 10 }
    local db = { locale = "deDE", soundLeadEnabled = false }
    ctx.with_globals(BuildSoundGlobals(db, calls, clock), function()
      local addon = ctx.load_modules({ "isiLive_sound_registry.lua", "isiLive_sound_utils.lua" })
      Assert.False(addon.SoundUtils.PlayKey("leader_transfer"), "a disabled sound stays silent despite its voice")
      Assert.False(addon.SoundUtils.PlayKey("aggro"), "aggro sound stays opt-in")
      Assert.False(addon.SoundUtils.PlayKey("missed_kick"), "missed-kick sound stays opt-in")
      Assert.Equal(#calls, 0, "no playback at all")
      Assert.True(addon.SoundUtils.IsVoiceEnabled("aggro"), "voice option itself defaults to on")
      Assert.False(addon.SoundUtils.IsVoiceEnabled("tank_died"), "alerts without a voice part report no voice")
    end)
  end)

  test("SoundUtils falls back to the effect when the client rejects the voice line", function()
    local calls = {}
    local clock = { now = 10 }
    local db = { locale = "enUS" }
    ctx.with_globals(BuildSoundGlobals(db, calls, clock, SOUND_DIR .. "BloodlustUsed.ogg"), function()
      local addon = ctx.load_modules({ "isiLive_sound_registry.lua", "isiLive_sound_utils.lua" })
      Assert.True(addon.SoundUtils.PlayBloodlust(), "the alert still plays")
      Assert.Equal(#calls, 2, "voice attempt, then the effect")
      Assert.Equal(calls[1].path, SOUND_DIR .. "BloodlustUsed.ogg", "voice line first")
      Assert.Equal(calls[2].path, SOUND_DIR .. "BoxingArenaSound.ogg", "effect after the rejected voice line")
      clock.now = 10.5
      Assert.False(addon.SoundUtils.PlayBloodlust(), "inside the spam window nothing plays")
      Assert.Equal(#calls, 2, "the spam window holds back voice and effect alike")
    end)
  end)

  local function CapturePlayback(globals, session)
    session.played = {}
    globals.PlaySoundFile = function(path, channel)
      session.played[#session.played + 1] = { path = path, channel = channel }
      return true, #session.played
    end
  end

  local function Count(session, path)
    local count = 0
    for _, call in ipairs(session.played) do
      if call.path == path then
        count = count + 1
      end
    end
    return count
  end

  test("Group-full voice line follows locale and option through the real roster dispatch", function()
    for _, variant in ipairs({
      { locale = "deDE", voice = nil, expected = "GroupFull_deDE.ogg" },
      { locale = "enUS", voice = true, expected = "GroupFull.ogg" },
      { locale = "frFR", voice = nil, expected = "GroupFull.ogg" },
      { locale = "deDE", voice = false, expected = "SynthChord.ogg" },
    }) do
      local label = variant.locale .. " voice=" .. tostring(variant.voice)
      Stress.WithParty(ctx, Fixture, function(session)
        session.globals.IsiLiveDB.locale = variant.locale
        session.globals.IsiLiveDB.soundGroupJoinVoiceEnabled = variant.voice
        session.Dispatch("GROUP_ROSTER_UPDATE")
        session.Advance(1)
        session.members = 5
        session.Dispatch("GROUP_ROSTER_UPDATE")
        session.Advance(1)
        Assert.Equal(Count(session, SOUND_DIR .. variant.expected), 1, label .. ": fifth join plays once")
        for _, other in ipairs({ "GroupFull.ogg", "GroupFull_deDE.ogg", "SynthChord.ogg" }) do
          if other ~= variant.expected then
            Assert.Equal(Count(session, SOUND_DIR .. other), 0, label .. ": no " .. other)
          end
        end
      end, function(globals, session)
        session.members = 4
        session.grouped = true
        CapturePlayback(globals, session)
        local unitName = globals.UnitName
        globals.UnitName = function(unit)
          if unit == "party4" and (session.members or 5) < 5 then
            return nil
          end
          return unitName(unit)
        end
        globals.UnitFullName = globals.UnitName
        local unitExists = globals.UnitExists
        globals.UnitExists = function(unit)
          if unit == "party4" and (session.members or 5) < 5 then
            return false
          end
          return unitExists(unit)
        end
      end)
    end
  end)

  test("Leader-transfer voice line follows locale and option through the real leader dispatch", function()
    for _, variant in ipairs({
      { locale = "deDE", voice = nil, expected = "LeaderTransfer_deDE.ogg" },
      { locale = "enUS", voice = nil, expected = "LeaderTransfer.ogg" },
      { locale = "ruRU", voice = true, expected = "LeaderTransfer.ogg" },
      { locale = "enUS", voice = false, expected = "CartoonVoiceBaritone.ogg" },
    }) do
      local label = variant.locale .. " voice=" .. tostring(variant.voice)
      Stress.WithParty(ctx, Fixture, function(session)
        session.globals.IsiLiveDB.locale = variant.locale
        session.globals.IsiLiveDB.soundLeadVoiceEnabled = variant.voice
        -- The login roster update of the full party played the group-full alert.
        session.played = {}
        session.Dispatch("PARTY_LEADER_CHANGED")
        Assert.Equal(#session.played, 0, label .. ": no sound without a leader change")
        session.leader = true
        session.Advance(2)
        session.Dispatch("PARTY_LEADER_CHANGED")
        Assert.Equal(#session.played, 1, label .. ": promotion plays once")
        Assert.Equal(session.played[1].path, SOUND_DIR .. variant.expected, label .. ": expected file")
        Assert.Equal(session.played[1].channel, "Master", label .. ": Master channel")
      end, function(globals, session)
        session.grouped = true
        session.leader = false
        CapturePlayback(globals, session)
        globals.UnitIsGroupLeader = function(unit)
          return unit == "player" and session.leader == true
        end
      end)
    end
  end)

  test("Settings panel shows an indented voice option under each voice alert, default on", function()
    local helpers = dofile("testmodul/isilive_test_ui_helpers.lua")
    local createFrameStub, createdFrames = helpers.BuildCreateFrameStub()
    local db = {}
    ctx.with_globals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      GetTime = function()
        return 100
      end,
      PlaySoundFile = function() end,
      Settings = {
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = ctx.load_modules({ "isiLive_ui_common.lua", "isiLive_sound_utils.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return { SETTINGS_SECTION_SOUNDS = "Sounds", SETTINGS_SOUND_VOICE_INSTEAD = "Voice X" }
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
      local previous = {}
      local lastCheck = nil
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "CheckButton" then
          local soundKey = type(frame._soundKey) == "string" and frame._soundKey:match("^(.+)_voice$") or nil
          if soundKey then
            checks[soundKey] = frame
            previous[soundKey] = lastCheck
          end
          lastCheck = frame
        end
      end
      for _, case in ipairs(VOICE_CASES) do
        local check = Assert.NotNil(checks[case.key], case.key .. ": voice option exists")
        Assert.Equal(check.label:GetText(), "Voice X", case.key .. ": localized label")
        Assert.True(check:GetChecked(), case.key .. ": voice option defaults to on")
        Assert.Nil(db[case.voiceSetting], case.key .. ": opening settings persists nothing")
        Assert.Equal(check._point[4], 32, case.key .. ": voice option is indented as a child option")
        local parentCheck = previous[case.key]
        if case.soundSetting then
          Assert.Equal(
            parentCheck._settingKey,
            "SETTINGS_" .. case.key:upper() .. "_SOUND",
            case.key .. ": below the sound"
          )
        else
          Assert.Equal(parentCheck._soundKey, case.key, case.key .. ": directly below its sound toggle")
        end
        check:SetChecked(false)
        check._scripts.OnClick(check)
        Assert.Equal(db[case.voiceSetting], false, case.key .. ": unchecking persists false")
        check:SetChecked(true)
        check._scripts.OnClick(check)
        Assert.Equal(db[case.voiceSetting], true, case.key .. ": checking persists true")
      end
      db.aggroAlertVoiceEnabled = false
      panel.Refresh()
      Assert.False(checks.aggro:GetChecked(), "refresh repaints the stored voice option")
      local keys = {}
      for _, entry in ipairs(panel.GetSearchEntries()) do
        keys[entry.key] = true
      end
      Assert.True(keys["soundVoiceChecks.missed_kick"] == true, "voice options take part in the settings search")
    end)
  end)

  test("Aggro and missed-kick alerts play the voice line once their sound is on", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local db = session.globals.IsiLiveDB
      db.locale = "deDE"
      -- The login roster update of the full party played the group-full alert.
      session.played = {}
      local runtime = session.runtime
      runtime.ShowAggroAlert()
      runtime.ShowMissedKickAlert()
      Assert.Equal(#session.played, 0, "sound settings off: no playback")
      db.aggroAlertSound = true
      db.missedKickSound = true
      runtime.ShowAggroAlert()
      runtime.ShowMissedKickAlert()
      Assert.Equal(Count(session, SOUND_DIR .. "Aggro_deDE.ogg"), 1, "aggro voice line by default")
      Assert.Equal(Count(session, SOUND_DIR .. "MissedKick_deDE.ogg"), 1, "missed-kick voice line by default")
      db.aggroAlertVoiceEnabled = false
      db.missedKickVoiceEnabled = false
      session.Advance(2)
      local before = #session.played
      runtime.ShowAggroAlert()
      runtime.ShowMissedKickAlert()
      Assert.Equal(#session.played, before, "voice off: SoundKit instead of a file")
      Assert.Equal(#session.kits, 2, "voice off: both SoundKits play")
    end, function(globals, session)
      CapturePlayback(globals, session)
      session.kits = {}
      globals.SOUNDKIT = { ALARM_CLOCK_WARNING_3 = 12867, RAID_WARNING = 8959 }
      globals.PlaySound = function(kit, channel)
        session.kits[#session.kits + 1] = { kit = kit, channel = channel }
        return true
      end
    end)
  end)
end
