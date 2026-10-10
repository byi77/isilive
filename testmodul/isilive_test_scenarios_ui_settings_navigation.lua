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

  test("Settings section navigation keeps a fixed-width tab per section and jumps within the scroll frame", function()
    local baseCreateFrame = BuildCreateFrameStub()
    local templateScrollCalls = 0
    local function createFrameStub(frameType, name, parent, template)
      local frame = baseCreateFrame(frameType, name, parent, template)
      if template == "UIPanelScrollFrameTemplate" then
        frame:SetScript("OnVerticalScroll", function(self, offset)
          templateScrollCalls = templateScrollCalls + 1
          self._scrollbarValue = offset
        end)
        local setScroll = frame.SetVerticalScroll
        frame.SetVerticalScroll = function(self, offset)
          setScroll(self, offset)
          self._scripts.OnVerticalScroll(self, offset)
        end
      end
      return frame
    end
    local labels = { SETTINGS_NAV_GENERAL = "General", SETTINGS_NAV_VIP = "VIP" }
    WithGlobals({
      UIParent = {},
      IsiLiveDB = {},
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
          return labels
        end,
        getDB = function()
          return IsiLiveDB
        end,
      })
      local nav = Assert.NotNil(panel.navigation, "settings navigation must exist")
      local count = 0
      for _, button in pairs(nav.buttons) do
        count = count + 1
        Assert.Equal(button:GetWidth(), 126, "navigation tabs must keep their width budget")
        Assert.Equal(button._parent, panel.canvas, "navigation must stay outside the scroll child")
      end
      Assert.Equal(count, 11, "all settings sections need a navigation tab")
      Assert.True(nav.offsets.vip > nav.offsets.general, "section offsets must follow content order")
      Assert.True(nav.offsets.raid > nav.offsets.sounds, "the raid section must follow the sounds section")
      Assert.True(nav.offsets.chat > nav.offsets.raid, "the raid section must come before chat")

      local display = nav.buttons.display
      display._scripts.OnClick(display)
      Assert.Equal(panel.scrollFrame:GetVerticalScroll(), nav.offsets.display, "tab click must jump to its section")
      Assert.Equal(nav.activeKey, "display", "clicked section must be marked active")
      Assert.Equal(panel.scrollFrame._scrollbarValue, nav.offsets.display, "tab jumps must synchronize the scrollbar")
      local beforeWheel = templateScrollCalls
      panel.scrollFrame._scripts.OnMouseWheel(panel.scrollFrame, -1)
      Assert.Equal(templateScrollCalls, beforeWheel + 1, "mouse wheel must preserve the template scroll handler")
      Assert.Equal(
        panel.scrollFrame._scrollbarValue,
        panel.scrollFrame:GetVerticalScroll(),
        "wheel must move the scrollbar"
      )

      labels.SETTINGS_NAV_DISPLAY = "Anzeige"
      panel.Refresh()
      Assert.Equal(display._flatLabel:GetText(), "Anzeige", "navigation must refresh after a language change")
      Assert.False(display._flatLabel._wordWrap, "navigation labels must stay within one line")

      panel.scrollFrame:SetVerticalScroll(nav.offsets.behavior)
      panel.scrollFrame._scripts.OnVerticalScroll(panel.scrollFrame, nav.offsets.behavior)
      Assert.Equal(nav.activeKey, "behavior", "manual scrolling must update the active section")
    end)
  end)
end
