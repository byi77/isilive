---@diagnostic disable: undefined-global
local helpersChunk, helpersErr = loadfile("testmodul/isilive_test_ui_helpers.lua")
if not helpersChunk then
  error("cannot load UI helpers: " .. tostring(helpersErr))
end
local helpers = helpersChunk()
local BuildCreateFrameStub = helpers.BuildCreateFrameStub
local RequireValue = helpers.RequireValue

local function RegisterSettingsPanelOrderTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Settings panel orders controls by thematic sections", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}

    local function FindFirstIndexBySettingKey(settingKey)
      for index, frame in ipairs(createdFrames) do
        if frame._settingKey == settingKey then
          return index
        end
      end
      return nil
    end

    local function AssertBefore(leftKey, rightKey)
      local leftIndex = Assert.NotNil(FindFirstIndexBySettingKey(leftKey), leftKey .. " should exist")
      local rightIndex = Assert.NotNil(FindFirstIndexBySettingKey(rightKey), rightKey .. " should exist")
      Assert.True(leftIndex < rightIndex, leftKey .. " should be built before " .. rightKey)
    end

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      GetCVar = function()
        return "0"
      end,
      SetCVar = function() end,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_HEARTHSTONE_SELECT = "Hearthstone",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SHOW_TIMEWAYS_NAVIGATOR = "Show Timeways Navigator",
            SETTINGS_LFG_FLAGS = "Group Finder: Language Flags",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_NAMEPLATE_FONT_SIZE = "Nameplate font size",
            SETTINGS_SOUND_LEAD_ENABLED = "Leadership sound",
            SETTINGS_VIP_ASTRAL_AUROCHS_SOUND = "Astral Aurochs sound",
            SETTINGS_CHAT_BR_ANNOUNCE = "Chat BR",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RESET_UI_POSITION = "Reset UI position",
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

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")

      AssertBefore("SETTINGS_ESC_PANEL", "SETTINGS_HEARTHSTONE_SELECT")
      AssertBefore("SETTINGS_HEARTHSTONE_SELECT", "SETTINGS_UI_SCALE")
      AssertBefore("SETTINGS_BG_ALPHA", "SETTINGS_STATS_BOX_ENABLED")
      AssertBefore("SETTINGS_STATS_BOX_SHOW_AVOIDANCE", "SETTINGS_MINIMAP_BUTTON")
      AssertBefore("SETTINGS_MINIMAP_BUTTON", "SETTINGS_SHOW_TIMEWAYS_NAVIGATOR")
      AssertBefore("SETTINGS_SHOW_TIMEWAYS_NAVIGATOR", "SETTINGS_LFG_FLAGS")
      AssertBefore("SETTINGS_LFG_FLAGS", "SETTINGS_SYNC_ENABLED")
      AssertBefore("SETTINGS_SYNC_ENABLED", "SETTINGS_NAMEPLATE_FONT_SIZE")
      AssertBefore("SETTINGS_NAMEPLATE_FONT_SIZE", "SETTINGS_SOUND_LEAD_ENABLED")
      AssertBefore("SETTINGS_SOUND_LEAD_ENABLED", "SETTINGS_CHAT_BR_ANNOUNCE")
      AssertBefore("SETTINGS_CHAT_BR_ANNOUNCE", "SETTINGS_COMBAT_LOGGING")
      AssertBefore("SETTINGS_COMBAT_LOGGING", "SETTINGS_QUEUE_DEBUG")
      AssertBefore("SETTINGS_QUEUE_DEBUG", "SETTINGS_RESET_UI_POSITION")
      AssertBefore("SETTINGS_RESET_UI_POSITION", "SETTINGS_VIP_ASTRAL_AUROCHS_SOUND")
    end)
  end)

  test("Settings language selector hides Spanish Portuguese and Italian buttons", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_languages.lua", "isiLive_settings.lua" })
      addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_LANGUAGE_DESC = "Changes the isiLive addon language.",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
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

      local rendered = {}
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "Button" and frame._languageTag then
          rendered[frame._languageTag] = true
        end
      end

      Assert.True(rendered.enUS == true, "English must remain selectable in settings")
      Assert.True(rendered.deDE == true, "German must remain selectable in settings")
      Assert.True(rendered.frFR == true, "French must remain selectable in settings")
      Assert.True(rendered.ruRU == true, "Russian must remain selectable in settings")
      Assert.True(rendered.trTR == true, "Turkish must remain selectable in settings")
      Assert.Nil(rendered.esES, "Spanish must no longer be selectable in settings")
      Assert.Nil(rendered.ptBR, "Portuguese must no longer be selectable in settings")
      Assert.Nil(rendered.itIT, "Italian must no longer be selectable in settings")
    end)
  end)
end

return function(test, ctx)
  local Assert = RequireValue(ctx.assert, "UI settings order scenario ctx.assert should exist")
  local WithGlobals = RequireValue(ctx.with_globals, "UI settings order scenario ctx.with_globals should exist")
  local LoadAddonModules = RequireValue(ctx.load_modules, "UI settings order scenario ctx.load_modules should exist")

  RegisterSettingsPanelOrderTests(test, Assert, WithGlobals, LoadAddonModules)
end
