---@diagnostic disable: undefined-global
local helpers = dofile("testmodul/isilive_test_ui_helpers.lua")
local BuildCreateFrameStub = helpers.BuildCreateFrameStub

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Settings item event bursts skip hidden panels and coalesce visible toy updates", function()
    local createFrameStub, frames = BuildCreateFrameStub()
    local pending, toyScans, labelReads = {}, 0, 0
    WithGlobals({
      UIParent = {},
      IsiLiveDB = {},
      CreateFrame = createFrameStub,
      C_Timer = {
        After = function(_, callback)
          pending[#pending + 1] = callback
        end,
      },
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas)
          return { canvas = canvas }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      addon.UI = addon.UI or {}
      addon.UI.CollectOwnedHearthstoneToys = function()
        toyScans = toyScans + 1
        return {}
      end
      local panel = addon.SettingsPanel.Create({
        getL = function()
          labelReads = labelReads + 1
          return {}
        end,
        getDB = function()
          return IsiLiveDB
        end,
        setLanguage = function() end,
      })
      local eventFrame
      for _, frame in ipairs(frames) do
        if frame:IsEventRegistered("GET_ITEM_INFO_RECEIVED") then
          eventFrame = frame
        end
      end
      Assert.NotNil(eventFrame, "the production item-event frame must exist")
      panel.canvas:Hide()
      local beforeScans, beforeLabels = toyScans, labelReads
      for id = 1, 10000 do
        eventFrame:FireEvent("GET_ITEM_INFO_RECEIVED", id, true)
      end
      eventFrame:FireEvent("TOYS_UPDATED")
      Assert.Equal(toyScans, beforeScans, "closed settings must perform zero toy scans during an event storm")
      Assert.Equal(labelReads, beforeLabels, "closed settings must perform zero control refreshes")
      Assert.Equal(#pending, 0, "closed settings must schedule zero callbacks")
      panel.canvas:Show()
      panel.canvas._scripts.OnShow(panel.canvas)
      beforeScans, beforeLabels = toyScans, labelReads
      for id = 1, 10000 do
        eventFrame:FireEvent("GET_ITEM_INFO_RECEIVED", id, true)
      end
      Assert.Equal(#pending, 1, "an entire visible burst must schedule just one callback")
      Assert.Equal(toyScans, beforeScans, "the burst must not scan synchronously")
      pending[1]()
      Assert.Equal(toyScans, beforeScans + 1, "the deferred callback must rebuild just the toy options once")
      Assert.Equal(labelReads, beforeLabels + 2, "item events must not refresh every settings section or preview")
      eventFrame:FireEvent("TOYS_UPDATED")
      panel.canvas:Hide()
      pending[2]()
      Assert.Equal(toyScans, beforeScans + 1, "closing before the callback must discard the visible refresh")
      panel.canvas:Show()
      panel.canvas._scripts.OnShow(panel.canvas)
      Assert.Equal(toyScans, beforeScans + 2, "opening settings must hydrate changes skipped while hidden")
    end)
  end)
end
