---@diagnostic disable: undefined-global

-- Rule 242: the shared show/hide motion (UICommon.ShowAnimated /
-- HideAnimated in ui/isiLive_ui_motion.lua) and its use by the main window,
-- driven through the real modules on the simulated widget layer of
-- testmodul/isilive_test_ui_world.lua.

local UIWorld = dofile("testmodul/isilive_test_ui_world.lua")
local NewWorld = UIWorld.NewWorld
local Globals = UIWorld.Globals
local AlphaAnim = UIWorld.AlphaAnim

local function NoticeOpts()
  return {
    parent = UIParent,
    isInCombat = function()
      return InCombatLockdown()
    end,
  }
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function LoadCards()
    return LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua", "isiLive_loadout_check_card.lua" })
  end

  test("ShowAnimated and HideAnimated reverse from the current alpha without flicker", function()
    local world = NewWorld()
    WithGlobals(Globals(world), function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local UICommon = addon.UICommon
      local frame = world.CreateFrame("Frame", nil, world.UIParent)
      frame:EnableMouse(true)
      frame:Hide()
      local hides = 0
      frame:HookScript("OnHide", function()
        hides = hides + 1
      end)

      UICommon.ShowAnimated(frame, "card")
      local alpha, group = AlphaAnim(frame)
      Assert.Equal(frame:GetAlpha(), 0, "a card starts transparent")
      Assert.Equal(alpha._duration, UICommon.Motion.duration.normal, "cards fade in over `normal`")
      Assert.Equal(group:Find("Translation", 1)._offset[2], 7, "cards start 7 px above their anchor")
      Assert.Equal(group:Find("Translation", 2)._offset[2], -7, "and slide down onto it")

      world.Advance(0.1)
      UICommon.HideAnimated(frame, "card")
      Assert.True(math.abs(alpha._from - 0.5) < 1e-6, "the hide starts from the alpha reached so far")
      Assert.Equal(alpha._to, 0, "the hide heads for transparent")
      Assert.True(math.abs(alpha._duration - UICommon.Motion.duration.fast * 0.5) < 1e-6, "half the way, half the time")
      Assert.True(
        math.abs(group:Find("Translation", 1)._offset[2] - 3.5) < 1e-6,
        "the remaining slide continues from where it was"
      )
      Assert.False(frame:IsMouseEnabled(), "a hiding frame drops the mouse at once")

      world.Advance(0.03)
      UICommon.ShowAnimated(frame, "card")
      Assert.True(alpha._from > 0 and alpha._from < 0.5, "showing again reverses from the current alpha")
      Assert.True(frame:IsMouseEnabled(), "showing again restores the mouse")
      world.Advance(1)
      Assert.Equal(hides, 0, "a reversed hide never hid the frame")
      Assert.Equal(frame:GetAlpha(), 1, "the frame settles fully visible")

      UICommon.HideAnimated(frame, "card")
      UICommon.HideAnimated(frame, "card")
      world.Advance(1)
      Assert.Equal(hides, 1, "a repeated hide runs once")
      Assert.False(frame:IsShown(), "the real Hide() follows the fade")
      Assert.Equal(frame:GetAlpha(), 1, "a hidden frame keeps full alpha for a later plain Show")
      Assert.True(frame:IsMouseEnabled(), "a hidden frame gets its mouse back for a later plain Show")
    end)
  end)

  test("Windows fade in and out over fast without sliding", function()
    local world = NewWorld()
    WithGlobals(Globals(world), function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local UICommon = addon.UICommon
      local frame = world.CreateFrame("Frame", nil, world.UIParent)
      frame:Hide()
      UICommon.ShowAnimated(frame, "window")
      local alpha, group = AlphaAnim(frame)
      Assert.Equal(alpha._duration, UICommon.Motion.duration.fast, "windows fade in over `fast`")
      Assert.Equal(group:Find("Translation", 1)._offset[2], 0, "windows do not slide")
      world.Advance(1)
      UICommon.HideAnimated(frame, "window")
      Assert.Equal(alpha._duration, UICommon.Motion.duration.fast, "windows fade out over `fast`")
      world.Advance(1)
      Assert.False(frame:IsShown(), "the window hides after its fade")
    end)
  end)

  test("Reduced motion shows and hides cards and windows at once", function()
    local world = NewWorld()
    WithGlobals(Globals(world, { IsiLiveDB = { reduceMotion = true } }), function()
      local addon = LoadCards()
      local UICommon = addon.UICommon
      local notice = addon.Notice.CreateCenterNotice(NoticeOpts())
      notice.Show("Calm notice", 20)
      local container = addon.CardStack.GetContainer()
      Assert.True(container:IsShown(), "the stack appears at once")
      Assert.Equal(container:GetAlpha(), 1, "fully visible at once")
      Assert.Nil(container._groups, "reduced motion builds no animation group")
      notice.SetVisible(false)
      Assert.False(container:IsShown(), "the stack hides at once")
      Assert.False(notice.frame:IsShown(), "the card hides at once")

      local window = world.CreateFrame("Frame", nil, world.UIParent)
      window:Hide()
      UICommon.ShowAnimated(window, "window")
      Assert.Equal(window:GetAlpha(), 1, "a window opens fully visible")
      UICommon.HideAnimated(window, "window")
      Assert.False(window:IsShown(), "a window closes at once")
    end)

    -- Switching reduced motion on settles a running fade at its end.
    local world2 = NewWorld()
    WithGlobals(Globals(world2), function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local UICommon = addon.UICommon
      local frame = world2.CreateFrame("Frame", nil, world2.UIParent)
      UICommon.HideAnimated(frame, "window")
      Assert.True(frame:IsShown(), "the fade runs")
      UICommon.SetReducedMotionEnabled(true)
      Assert.False(frame:IsShown(), "reduced motion finishes the running hide at once")
    end)
  end)

  test("Protected frames only fade in combat and get their real hide after regen", function()
    local world = NewWorld()
    WithGlobals(Globals(world), function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      local UICommon = addon.UICommon
      local frame = world.CreateFrame("Frame", nil, world.UIParent)
      world.CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
      frame:EnableMouse(true)

      world.inCombat = true
      UICommon.HideAnimated(frame, "window")
      world.Advance(1)
      Assert.True(frame:IsShown(), "a protected frame is not hidden in combat")
      Assert.Equal(frame:GetAlpha(), 0, "it fades out to transparent instead")
      Assert.True(frame:IsMouseEnabled(), "its mouse is not touched in combat")
      Assert.Equal(#world.violations, 0, "no blocked call reached the client")
      local blocker = world.frames[#world.frames]
      Assert.True(blocker ~= frame and blocker:IsShown() and blocker:IsMouseEnabled(), "a blocker eats the clicks")

      world.inCombat = false
      UICommon.ApplyDeferredShowHide()
      Assert.False(frame:IsShown(), "the real Hide() follows after combat")
      Assert.Equal(frame:GetAlpha(), 1, "full alpha again for the next show")
      Assert.False(blocker:IsShown(), "the blocker goes away")

      world.inCombat = true
      UICommon.ShowAnimated(frame, "window")
      Assert.False(frame:IsShown(), "a hidden protected frame is not shown in combat")
      world.inCombat = false
      UICommon.ApplyDeferredShowHide()
      Assert.True(frame:IsShown(), "the deferred show runs after combat")
      Assert.Equal(#world.violations, 0, "no blocked call reached the client")
    end)
  end)

  test("UI main frame fades out on close and a hotkey close in combat only fades", function()
    local world = NewWorld()
    WithGlobals(Globals(world), function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UICommon = addon.UICommon
      local mainUI = addon.UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return world.inCombat
        end,
      })
      local frame = mainUI.frame
      frame:Hide()
      -- The window holds secure buttons (Mark-T/H), so the client protects it.
      frame._protected = true

      Assert.True(mainUI.SetVisible(true), "opening shows the window")
      local alpha = AlphaAnim(frame)
      Assert.Equal(alpha._duration, UICommon.Motion.duration.fast, "the window fades in over `fast`")
      world.Advance(1)

      mainUI.closeButton:GetScript("OnClick")(mainUI.closeButton, "LeftButton")
      Assert.True(frame:IsShown(), "closing fades the window out first")
      Assert.Equal(alpha._to, 0, "the fade heads for transparent")
      world.Advance(1)
      Assert.False(frame:IsShown(), "the window hides after the fade")

      mainUI.SetVisible(true)
      world.Advance(1)
      world.inCombat = true
      mainUI.ToggleVisibility(true)
      world.Advance(1)
      Assert.True(frame:IsShown(), "a hotkey close in combat does not call Hide()")
      Assert.Equal(frame:GetAlpha(), 0, "it fades the window out instead")
      Assert.Equal(mainUI.GetPendingVisible(), false, "the close waits for the end of combat")
      Assert.Equal(#world.violations, 0, "no blocked call reached the client")

      mainUI.ToggleVisibility(true)
      world.Advance(1)
      Assert.Equal(frame:GetAlpha(), 1, "a second hotkey press in combat brings the window back")
      Assert.Equal(mainUI.GetPendingVisible(), true, "the window stays open after combat")
      mainUI.ToggleVisibility(true)
      world.Advance(1)

      world.inCombat = false
      UICommon.ApplyDeferredShowHide()
      mainUI.SetVisible(mainUI.GetPendingVisible())
      Assert.False(frame:IsShown(), "after combat the window is hidden for real")
      Assert.Equal(frame:GetAlpha(), 1, "and keeps full alpha for the next open")
      Assert.Equal(#world.violations, 0, "no blocked call reached the client")
    end)
  end)

  test("Config window and simulation tablet fade in and out and count as closed while fading", function()
    local world = NewWorld()
    WithGlobals(Globals(world, { UISpecialFrames = {} }), function()
      local addon =
        LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua", "isiLive_simulation_tablet.lua" })
      local UICommon = addon.UICommon
      local window = addon.ConfigWindow.Create({
        getL = function()
          return {}
        end,
        getDB = function()
          return IsiLiveDB
        end,
      })
      local frame = window.frame or world.named.isiLiveConfigWindow
      Assert.True(window.Open(), "the config window opens")
      local alpha = AlphaAnim(frame)
      Assert.Equal(alpha._duration, UICommon.Motion.duration.fast, "the config window fades in over `fast`")
      world.Advance(1)
      Assert.True(window.Close(), "the config window closes")
      Assert.True(frame:IsShown(), "it fades out first")
      Assert.False(window.IsOpen(), "a fading config window counts as closed")
      Assert.True(window.Open(), "opening again reverses the fade")
      world.Advance(1)
      Assert.True(frame:IsShown() and frame:GetAlpha() == 1, "the reopened window is fully visible")
      window.Close()
      world.Advance(1)
      Assert.False(frame:IsShown(), "the window hides after its fade")

      local anchor = world.CreateFrame("Frame", nil, world.UIParent)
      local tablet = addon.SimulationTablet.CreateController({
        anchorFrame = anchor,
        getL = function()
          return {}
        end,
        getActions = function()
          return {}
        end,
      })
      tablet.Show()
      local tabletAlpha = AlphaAnim(tablet.frame)
      Assert.Equal(tabletAlpha._duration, UICommon.Motion.duration.fast, "the tablet fades in over `fast`")
      world.Advance(1)
      tablet.Toggle()
      Assert.True(tablet.frame:IsShown(), "the tablet fades out first")
      Assert.False(tablet.IsShown(), "a fading tablet counts as closed")
      tablet.Toggle()
      Assert.True(tablet.IsShown(), "toggling during the fade brings it back")
      world.Advance(1)
      tablet.Hide()
      world.Advance(1)
      Assert.False(tablet.frame:IsShown(), "the tablet hides after its fade")
    end)
  end)
end
