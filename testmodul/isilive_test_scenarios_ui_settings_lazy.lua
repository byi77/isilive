---@diagnostic disable: undefined-global
local helpers = dofile("testmodul/isilive_test_ui_helpers.lua")
local BuildCreateFrameStub = helpers.BuildCreateFrameStub

-- COMPONENT-ONLY: the trigger for the lazy build is Blizzard's
-- SettingsPanelMixin:DisplayLayout (frame:Show(), then OnRefresh), which has no
-- addon-side event path. The tests drive SettingsPanel.Create through that
-- same sequence: Show + the hooked OnShow script, and canvas:OnRefresh().
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
        RegisterCanvasLayoutCategory = function(canvas)
          return { canvas = canvas, ID = 7 }
        end,
        RegisterAddOnCategory = function() end,
      },
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
    panel.canvas:Show()
    panel.canvas._scripts.OnShow(panel.canvas)
    panel.canvas:OnRefresh()
  end

  test("SettingsPanel deferBuild registers the category but builds no section before the first display", function()
    WithDeferredPanel(function(panel, frames, getLabelReads)
      Assert.NotNil(panel.category, "the category must be registered at load so it can be opened")
      Assert.False(panel.IsBuilt(), "no section may be built before the canvas is displayed")
      Assert.False(panel.canvas:IsShown(), "the canvas starts hidden like an unopened category")
      Assert.Nil(panel.navigation, "the section navigation does not exist yet")
      Assert.Equal(getLabelReads(), 0, "no locale lookup happens before the first display")
      local framesBefore = #frames

      panel.Refresh()
      panel.canvas:OnRefresh()
      Assert.False(panel.IsBuilt(), "Refresh and OnRefresh on a hidden canvas must not build it")
      Assert.Equal(#frames, framesBefore, "nothing may be created while the canvas stays hidden")
      Assert.Equal(getLabelReads(), 0, "a refresh before the first display repaints nothing")
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

      panel.canvas:Hide()
      DisplayCanvas(panel)
      Assert.Equal(#frames, framesAfterBuild, "a second display must not build the sections again")
      Assert.False(panel.EnsureBuilt(), "EnsureBuilt after the build is a no-op")
    end)
  end)
end
