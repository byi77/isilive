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
    local tooltipText = nil
    local tooltipHidden = false

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function(_, text)
          tooltipText = text
        end,
        Show = function() end,
        Hide = function()
          tooltipHidden = true
        end,
      },
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
            SETTINGS_SOUND_PREVIEW = "Preview",
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
      Assert.Equal(readyCheckPreview.label:GetText(), "\226\150\182", "preview button should render a play glyph")
      readyCheckPreview._scripts.OnEnter(readyCheckPreview)
      Assert.Equal(tooltipText, "Preview", "preview button hover should explain the action")
      readyCheckPreview._scripts.OnLeave(readyCheckPreview)
      Assert.True(tooltipHidden, "preview button leave should hide its tooltip")
    end)
  end)

  test("Settings panel keeps removed spoken TTS controls out of the sound UI", function()
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
      local nameCheck = nil
      local classCheck = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_TTS_ENABLED" then
          ttsCheck = frame
        elseif frame._ttsPreview == true then
          ttsPreview = frame
        elseif frame._settingKey == "SETTINGS_TTS_ANNOUNCE_NAME" then
          nameCheck = frame
        elseif frame._settingKey == "SETTINGS_TTS_ANNOUNCE_CLASS" then
          classCheck = frame
        end
      end

      Assert.Nil(ttsCheck, "removed TTS toggle checkbox must not exist")
      Assert.Nil(ttsPreview, "removed TTS preview button must not exist")
      Assert.Nil(nameCheck, "removed TTS name checkbox must not exist")
      Assert.Nil(classCheck, "removed TTS class checkbox must not exist")
      Assert.Nil(db.ttsAnnouncementsEnabled, "opening settings must not persist the TTS default")
      Assert.Nil(db.ttsAnnounceName, "opening settings must not persist the removed name setting")
      Assert.Nil(db.ttsAnnounceClass, "opening settings must not persist the removed class setting")
    end)
  end)

  test("Settings panel exposes separate tank and healer death sound toggles", function()
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

      local tankCheck = nil
      local healerCheck = nil
      local tankPreview = nil
      local healerPreview = nil
      for _, frame in ipairs(createdFrames) do
        if frame._soundKey == "tank_died" then
          tankCheck = frame
        elseif frame._soundKey == "healer_died" then
          healerCheck = frame
        elseif frame._soundPreviewKey == "tank_died" then
          tankPreview = frame
        elseif frame._soundPreviewKey == "healer_died" then
          healerPreview = frame
        end
      end

      tankCheck = Assert.NotNil(tankCheck, "tank death sound checkbox should exist")
      healerCheck = Assert.NotNil(healerCheck, "healer death sound checkbox should exist")
      Assert.NotNil(tankPreview, "tank death sound preview button should exist")
      Assert.NotNil(healerPreview, "healer death sound preview button should exist")
      Assert.True(tankCheck:GetChecked(), "tank death sound should default to enabled")
      Assert.True(healerCheck:GetChecked(), "healer death sound should default to enabled")
      Assert.Nil(db.soundTankDiedEnabled, "opening settings must not persist the tank death sound default")
      Assert.Nil(db.soundHealerDiedEnabled, "opening settings must not persist the healer death sound default")

      local tankOnClick = Assert.NotNil(tankCheck._scripts.OnClick, "tank death checkbox needs OnClick")
      local healerOnClick = Assert.NotNil(healerCheck._scripts.OnClick, "healer death checkbox needs OnClick")
      tankCheck:SetChecked(false)
      tankOnClick(tankCheck)
      healerCheck:SetChecked(false)
      healerOnClick(healerCheck)
      Assert.False(db.soundTankDiedEnabled, "disabling tank death sound should persist only the tank field")
      Assert.False(db.soundHealerDiedEnabled, "disabling healer death sound should persist only the healer field")
      Assert.Nil(db.deathAlertEnabled, "sound toggles must not persist the death-alert master gate")
    end)
  end)
end
