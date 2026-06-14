---@diagnostic disable: undefined-global
local helpersChunk, helpersErr = loadfile("testmodul/isilive_test_ui_helpers.lua")
if not helpersChunk then
  error("cannot load UI helpers: " .. tostring(helpersErr))
end
local helpers = helpersChunk()
local BuildCreateFrameStub = helpers.BuildCreateFrameStub

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Settings panel exposes ready-check-complete sound toggle and preview", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local previewCalls = {}

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      GetTime = function()
        return 100
      end,
      PlaySoundFile = function(path, channel)
        previewCalls[#previewCalls + 1] = { path = path, channel = channel }
      end,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_sound_utils.lua", "isiLive_settings.lua" })
      addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_SOUNDS = "Sounds",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      local readyCheckSoundCheck = nil
      local readyCheckPreview = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_SOUND_READY_CHECK_COMPLETE" then
          readyCheckSoundCheck = frame
        elseif frame._soundPreviewKey == "ready_check_complete" then
          readyCheckPreview = frame
        end
      end

      readyCheckSoundCheck = Assert.NotNil(readyCheckSoundCheck, "ready-check sound checkbox should exist")
      readyCheckPreview = Assert.NotNil(readyCheckPreview, "ready-check sound preview button should exist")
      Assert.Nil(db.soundReadyCheckCompleteEnabled, "opening settings must not persist the ready-check default")
      Assert.True(readyCheckSoundCheck:GetChecked(), "ready-check sound should default to enabled")

      local onClick = Assert.NotNil(readyCheckSoundCheck._scripts.OnClick, "ready-check sound checkbox needs OnClick")
      readyCheckSoundCheck:SetChecked(false)
      onClick(readyCheckSoundCheck)
      Assert.False(db.soundReadyCheckCompleteEnabled, "disabling ready-check sound should persist false")

      local onPreview = Assert.NotNil(readyCheckPreview._scripts.OnClick, "ready-check preview button needs OnClick")
      onPreview(readyCheckPreview, "LeftButton")
      Assert.Equal(#previewCalls, 1, "ready-check preview should play once")
      Assert.Equal(previewCalls[1].path, "Interface\\AddOns\\isiLive\\sounds\\BttF_Tinkle.wav", "preview asset")
      Assert.Equal(previewCalls[1].channel, "Master", "ready-check preview should use the default Master channel")
    end)
  end)

  test("Settings panel exposes the spoken-alert toggle and TTS preview", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local spokenPreviews = {}

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      GetTime = function()
        return 100
      end,
      PlaySoundFile = function() end,
      C_VoiceChat = {
        GetTtsVoices = function()
          return { { voiceID = 1, name = "Voice" } }
        end,
        SpeakText = function(_voiceID, text)
          spokenPreviews[#spokenPreviews + 1] = text
          return true
        end,
      },
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_sound_utils.lua", "isiLive_settings.lua" })
      addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_SOUNDS = "Sounds",
            SETTINGS_TTS_ENABLED = "Spoken alerts",
            TTS_PREVIEW_TEXT = "isiLive text to speech is active.",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      local ttsCheck = nil
      local ttsPreview = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_TTS_ENABLED" then
          ttsCheck = frame
        elseif frame._ttsPreview == true then
          ttsPreview = frame
        end
      end

      ttsCheck = Assert.NotNil(ttsCheck, "TTS toggle checkbox should exist")
      ttsPreview = Assert.NotNil(ttsPreview, "TTS preview button should exist")
      Assert.Nil(db.ttsAnnouncementsEnabled, "opening settings must not persist the TTS default")
      Assert.False(ttsCheck:GetChecked(), "TTS announcements must default to off")

      local onClick = Assert.NotNil(ttsCheck._scripts.OnClick, "TTS toggle needs OnClick")
      ttsCheck:SetChecked(true)
      onClick(ttsCheck)
      Assert.True(db.ttsAnnouncementsEnabled, "enabling the TTS toggle must persist true")

      local onPreview = Assert.NotNil(ttsPreview._scripts.OnClick, "TTS preview button needs OnClick")
      onPreview(ttsPreview, "LeftButton")
      Assert.Equal(#spokenPreviews, 1, "TTS preview should speak once")
      Assert.Equal(spokenPreviews[1], "isiLive text to speech is active.", "preview must speak the localized line")
    end)
  end)

  test("Settings panel exposes the TTS name and class toggles", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      GetTime = function()
        return 100
      end,
      PlaySoundFile = function() end,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_sound_utils.lua", "isiLive_settings.lua" })
      addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_SOUNDS = "Sounds",
            SETTINGS_TTS_ANNOUNCE_NAME = "Say the player name",
            SETTINGS_TTS_ANNOUNCE_CLASS = "Say the class",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      local nameCheck, classCheck = nil, nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_TTS_ANNOUNCE_NAME" then
          nameCheck = frame
        elseif frame._settingKey == "SETTINGS_TTS_ANNOUNCE_CLASS" then
          classCheck = frame
        end
      end

      nameCheck = Assert.NotNil(nameCheck, "TTS name toggle should exist")
      classCheck = Assert.NotNil(classCheck, "TTS class toggle should exist")
      Assert.False(nameCheck:GetChecked(), "name announcement must default off")
      Assert.False(classCheck:GetChecked(), "class announcement must default off")

      local onNameClick = Assert.NotNil(nameCheck._scripts.OnClick, "name toggle needs OnClick")
      nameCheck:SetChecked(true)
      onNameClick(nameCheck)
      Assert.True(db.ttsAnnounceName, "enabling the name toggle must persist true")
      Assert.False(db.ttsAnnounceClass, "enabling name must keep class disabled")

      local onClassClick = Assert.NotNil(classCheck._scripts.OnClick, "class toggle needs OnClick")
      classCheck:SetChecked(true)
      onClassClick(classCheck)
      Assert.True(db.ttsAnnounceClass, "enabling the class toggle must persist true")
      Assert.False(db.ttsAnnounceName, "enabling class must disable name")
      Assert.False(nameCheck:GetChecked(), "enabling class must visually uncheck name")

      nameCheck:SetChecked(true)
      onNameClick(nameCheck)
      Assert.True(db.ttsAnnounceName, "re-enabling name must persist true")
      Assert.False(db.ttsAnnounceClass, "re-enabling name must disable class")
      Assert.False(classCheck:GetChecked(), "re-enabling name must visually uncheck class")
    end)
  end)
end
