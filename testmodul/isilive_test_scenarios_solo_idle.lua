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

  local function ResolveDropdownEnv(env)
    local frames, pending = env.frames, env.pending
    for index, frame in ipairs(frames) do
      if frame._settingKey == "SETTINGS_HEARTHSTONE_SELECT" then
        env.button, env.menu, env.catcher = frame, frames[index + 1], frames[index + 2]
      end
    end
    Assert.NotNil(env.button, "the production hearthstone dropdown must exist")
    Assert.Equal(env.menu._frameStrata, "DIALOG", "the menu frame follows the dropdown button")
    Assert.Equal(env.catcher._frameStrata, "BACKGROUND", "the click catcher follows the menu frame")
    env.FireItemEvent = function()
      for _, frame in ipairs(frames) do
        if frame:IsEventRegistered("GET_ITEM_INFO_RECEIVED") then
          frame:FireEvent("GET_ITEM_INFO_RECEIVED", 6948, true)
        end
      end
      while #pending > 0 do
        table.remove(pending, 1)()
      end
    end
  end

  -- Builds the real settings panel and returns the hearthstone dropdown with
  -- its UIParent-anchored menu frame and click catcher (created right after it).
  local function WithHearthstoneDropdown(toyIds, body)
    local createFrameStub, frames = BuildCreateFrameStub()
    local pending = {}
    local env = { frames = frames, pending = pending }
    WithGlobals({
      UIParent = {},
      IsiLiveDB = {},
      CreateFrame = createFrameStub,
      GetLocale = function()
        return "enUS"
      end,
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
        return toyIds
      end
      addon.UI.GetHearthstoneToyEnglishName = function(toyId)
        return "Toy " .. tostring(toyId)
      end
      env.panel = addon.SettingsPanel.Create({
        getL = function()
          return {}
        end,
        getDB = function()
          return IsiLiveDB
        end,
        setLanguage = function() end,
      })
      env.panel.canvas:Show()
      env.panel.canvas._scripts.OnShow(env.panel.canvas)
      ResolveDropdownEnv(env)
      body(env)
    end)
  end

  test("Settings dropdown pools option rows and keeps an open menu across unchanged refreshes", function()
    local toyIds = {}
    WithHearthstoneDropdown(toyIds, function(env)
      env.button._scripts.OnClick(env.button)
      Assert.True(env.menu:IsShown(), "clicking the dropdown opens the menu")
      local framesAfterFirstOpen = #env.frames

      env.FireItemEvent()
      Assert.True(env.menu:IsShown(), "an unchanged option list must keep the open menu open")
      Assert.True(env.catcher:IsShown(), "an unchanged option list must keep the click catcher up")

      for _ = 1, 5 do
        env.button._scripts.OnClick(env.button)
        env.FireItemEvent()
        env.button._scripts.OnClick(env.button)
      end
      Assert.True(env.menu:IsShown(), "the menu reopens after the refresh cycles")
      Assert.Equal(#env.frames, framesAfterFirstOpen, "refreshes and reopening must not create new frames")

      toyIds[1] = 54452
      env.FireItemEvent()
      Assert.False(env.menu:IsShown(), "a changed option list closes the open menu")
      env.button._scripts.OnClick(env.button)
      Assert.Equal(#env.frames, framesAfterFirstOpen + 1, "one new option creates exactly one pooled row")
      toyIds[1] = nil
      env.FireItemEvent()
      env.button._scripts.OnClick(env.button)
      Assert.Equal(#env.frames, framesAfterFirstOpen + 1, "a shrunken list reuses the pool")
      Assert.False(env.frames[#env.frames]:IsShown(), "the surplus pooled row stays hidden")
    end)
  end)

  test("Settings dropdown menu and click catcher close when the dropdown is hidden", function()
    WithHearthstoneDropdown({}, function(env)
      env.button._scripts.OnClick(env.button)
      Assert.True(env.menu:IsShown(), "clicking the dropdown opens the menu")
      Assert.True(env.catcher:IsShown(), "the open menu raises the full-screen click catcher")

      env.panel.canvas:Hide()
      -- The client fires OnHide on every shown child when an ancestor hides
      -- (warcraft.wiki.gg UIHANDLER_OnHide); the frame stub does not propagate.
      local onHide = env.button._scripts.OnHide
      Assert.NotNil(onHide, "the dropdown button must react to being hidden")
      onHide(env.button)
      Assert.False(env.menu:IsShown(), "closing settings must close the dropdown menu")
      Assert.False(env.catcher:IsShown(), "closing settings must drop the click catcher")
    end)
  end)
end
