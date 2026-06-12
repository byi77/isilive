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
end
