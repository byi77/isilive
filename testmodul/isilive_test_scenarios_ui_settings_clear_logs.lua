---@diagnostic disable: undefined-global
local helpersChunk, helpersErr = loadfile("testmodul/isilive_test_ui_helpers.lua")
if not helpersChunk then
  error("cannot load UI helpers: " .. tostring(helpersErr))
end
local helpers = helpersChunk()
local BuildCreateFrameStub = helpers.BuildCreateFrameStub
local RequireValue = helpers.RequireValue

local function RegisterSettingsPanelClearLogTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Settings panel Clear Queue Debug Log button OnClick invokes the wired callback", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local clearCalls = 0

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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_QUEUE_DEBUG_CLEAR = "Clear Queue Debug Log",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
            SETTINGS_RUNTIME_LOG_CLEAR = "Clear Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onClearQueueDebugLog = function()
          clearCalls = clearCalls + 1
        end,
      })
      Assert.NotNil(panel, "settings panel should be created")

      local btn = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_QUEUE_DEBUG_CLEAR" then
          btn = frame
          break
        end
      end
      btn = Assert.NotNil(btn, "Clear Queue Debug Log action button should be created")

      local onClick = btn._scripts and btn._scripts.OnClick
      onClick = Assert.NotNil(onClick, "Clear Queue Debug Log button should bind an OnClick handler")
      onClick(btn, "LeftButton")

      Assert.Equal(clearCalls, 1, "OnClick must invoke config.onClearQueueDebugLog exactly once")
    end)
  end)

  test("Settings panel Clear Runtime Log button OnClick invokes the wired callback", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local clearCalls = 0

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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_QUEUE_DEBUG_CLEAR = "Clear Queue Debug Log",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
            SETTINGS_RUNTIME_LOG_CLEAR = "Clear Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onClearRuntimeLog = function()
          clearCalls = clearCalls + 1
        end,
      })
      Assert.NotNil(panel, "settings panel should be created")

      local btn = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_RUNTIME_LOG_CLEAR" then
          btn = frame
          break
        end
      end
      btn = Assert.NotNil(btn, "Clear Runtime Log action button should be created")

      local onClick = btn._scripts and btn._scripts.OnClick
      onClick = Assert.NotNil(onClick, "Clear Runtime Log button should bind an OnClick handler")
      onClick(btn, "LeftButton")

      Assert.Equal(clearCalls, 1, "OnClick must invoke config.onClearRuntimeLog exactly once")
    end)
  end)
end

return function(test, ctx)
  local Assert = RequireValue(ctx.assert, "UI settings clear-log scenario ctx.assert should exist")
  local WithGlobals = RequireValue(ctx.with_globals, "UI settings clear-log scenario ctx.with_globals should exist")
  local LoadAddonModules =
    RequireValue(ctx.load_modules, "UI settings clear-log scenario ctx.load_modules should exist")

  RegisterSettingsPanelClearLogTests(test, Assert, WithGlobals, LoadAddonModules)
end
