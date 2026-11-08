---@diagnostic disable: undefined-global
local helpers = dofile("testmodul/isilive_test_ui_helpers.lua")
local BuildCreateFrameStub = helpers.BuildCreateFrameStub

-- The lazy build runs on the first Open() of isiLive's own config window
-- (rule 237); the tests drive the real SettingsPanel.Create and Open.
return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function WithDeferredPanel(callback)
    local createFrameStub, frames = BuildCreateFrameStub()
    local labelReads = 0
    WithGlobals({
      UIParent = {},
      IsiLiveDB = {},
      CreateFrame = createFrameStub,
      C_Timer = {
        After = function() end,
      },
      Settings = {
        RegisterVerticalLayoutCategory = function(name)
          local layout = { initializers = {} }
          function layout.AddInitializer(self, initializer)
            table.insert(self.initializers, initializer)
          end
          return { ID = 7, name = name, layout = layout }, layout
        end,
        RegisterAddOnCategory = function() end,
      },
      CreateSettingsButtonInitializer = function(name, buttonText, buttonClick)
        return { data = { name = name, buttonText = buttonText, buttonClick = buttonClick } }
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        deferBuild = true,
        getL = function()
          labelReads = labelReads + 1
          return {}
        end,
        getDB = function()
          return IsiLiveDB
        end,
        setLanguage = function() end,
      })
      callback(panel, frames, function()
        return labelReads
      end)
    end)
  end

  local function DisplayCanvas(panel)
    panel.Open()
  end

  test("SettingsPanel deferBuild registers the category but builds no section before the first display", function()
    WithDeferredPanel(function(panel, frames, getLabelReads)
      Assert.NotNil(panel.category, "the Blizzard stub category must be registered at load")
      Assert.False(panel.IsBuilt(), "no section may be built before the config window opens")
      Assert.False(panel.IsOpen(), "the config window starts closed")
      Assert.Nil(panel.navigation, "the section navigation does not exist yet")
      Assert.True(getLabelReads() <= 4, "only the window title and the stub texts are read at load")
      local framesBefore = #frames
      local readsBefore = getLabelReads()

      panel.Refresh()
      Assert.False(panel.IsBuilt(), "Refresh on a closed window must not build the sections")
      Assert.Equal(#frames, framesBefore, "nothing may be created while the window stays closed")
      Assert.True(
        getLabelReads() - readsBefore <= 4,
        "a refresh before the first open only relabels the window title and the stub"
      )
    end)
  end)

  test("SettingsPanel deferBuild builds every section once on the first display", function()
    WithDeferredPanel(function(panel, frames)
      local framesBefore = #frames
      DisplayCanvas(panel)
      Assert.True(panel.IsBuilt(), "the first display must build the sections")
      Assert.NotNil(panel.navigation, "the section navigation must exist after the first display")
      local framesAfterBuild = #frames
      Assert.True(framesAfterBuild > framesBefore, "the first display must create the section widgets")

      panel.Close()
      DisplayCanvas(panel)
      Assert.Equal(#frames, framesAfterBuild, "a second display must not build the sections again")
      Assert.False(panel.EnsureBuilt(), "EnsureBuilt after the build is a no-op")
    end)
  end)
end
