---@diagnostic disable: undefined-global
local helpersChunk, helpersErr = loadfile("testmodul/isilive_test_ui_helpers.lua")
if not helpersChunk then
  error("cannot load UI helpers: " .. tostring(helpersErr))
end
local helpers = helpersChunk()
local RequireValue = helpers.RequireValue
local FindCombatRetryFrame = helpers.FindCombatRetryFrame
local BuildCreateFrameStub = helpers.BuildCreateFrameStub
local function RegisterMainFrameCombatVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UI toggle defers closing frame during combat and applies after regen", function()
    local inCombat = false
    local shownInGroupCalls = 0
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
        onShownInGroup = function()
          shownInGroupCalls = shownInGroupCalls + 1
        end,
      })
      mainUI.SetVisible(true)
      Assert.True(mainUI.frame:IsShown(), "frame should be visible before combat close test")
      inCombat = true
      mainUI.ToggleVisibility(true)
      Assert.True(mainUI.frame:IsShown(), "combat toggle must not close frame immediately (taint protection)")
      Assert.Equal(mainUI.GetPendingVisible(), false, "combat toggle should store pending hide")
      Assert.Equal(shownInGroupCalls, 0, "close path must not trigger show callbacks")
      inCombat = false
      mainUI.SetVisible(mainUI.GetPendingVisible())
      Assert.False(mainUI.frame:IsShown(), "frame should close after combat ends and pending is applied")
    end)
  end)
  test("UI toggle defers opening frame during combat and applies after regen", function()
    local inCombat = false
    local shownInGroupCalls = 0
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
        onShownInGroup = function()
          shownInGroupCalls = shownInGroupCalls + 1
        end,
      })
      Assert.False(mainUI.frame:IsShown(), "frame should start hidden")
      inCombat = true
      mainUI.ToggleVisibility(true)
      Assert.False(mainUI.frame:IsShown(), "combat toggle must not open frame immediately (taint protection)")
      Assert.Equal(mainUI.GetPendingVisible(), true, "combat toggle should store pending show")
      Assert.Equal(shownInGroupCalls, 0, "combat show must not trigger callbacks yet")
      inCombat = false
      mainUI.SetVisible(mainUI.GetPendingVisible())
      Assert.True(mainUI.frame:IsShown(), "frame should open after combat ends and pending is applied")
    end)
  end)
  test("UI direct SetVisible defers during combat and applies after regen", function()
    local inCombat = true
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
      })
      mainUI.SetVisible(true)
      Assert.False(mainUI.frame:IsShown(), "direct SetVisible must not open during combat (taint protection)")
      Assert.Equal(mainUI.GetPendingVisible(), true, "combat SetVisible should store pending show")
      inCombat = false
      mainUI.SetVisible(mainUI.GetPendingVisible())
      Assert.True(mainUI.frame:IsShown(), "frame should open after combat ends and pending is applied")
    end)
  end)
end
local function RegisterFrameBridgeVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Frame bridge direct SetMainFrameVisible triggers show callbacks on successful open", function()
    local visible = false
    local inGroup = true
    local groupShownCalls = 0
    local soloShownCalls = 0
    WithGlobals({
      UIParent = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_frame_bridge.lua" })
      local FrameBridge = RequireValue(addon.FrameBridge, "FrameBridge module should load")
      local context = FrameBridge.CreateContext({
        createCenterNotice = function()
          return {
            frame = {},
            teleportButton = {},
            SetVisible = function() end,
            UpdateTeleportButtonVisual = function() end,
            Show = function() end,
          }
        end,
        createInviteHint = function()
          return {
            Show = function() end,
          }
        end,
        createMainFrame = function(_opts)
          return {
            frame = {
              IsShown = function()
                return visible
              end,
            },
            SetVisible = function(wantVisible)
              if wantVisible then
                if visible then
                  return false
                end
                visible = true
                return true
              end
              if not visible then
                return false
              end
              visible = false
              return true
            end,
            SetHeightSafe = function() end,
            ToggleVisibility = function() end,
          }
        end,
        isInGroup = function()
          return inGroup
        end,
        onShownInGroup = function()
          groupShownCalls = groupShownCalls + 1
        end,
        onShownNoGroup = function()
          soloShownCalls = soloShownCalls + 1
        end,
        isInCombat = function()
          return false
        end,
        resolveTeleportSpellID = function()
          return nil
        end,
        applySecureSpellToButton = function() end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return nil
        end,
        formatCooldownSeconds = function(value)
          return tostring(value or "")
        end,
        getL = function()
          return {}
        end,
      })
      local didShow = context.SetMainFrameVisible(true)
      Assert.True(didShow, "direct show should report a successful visibility change")
      Assert.Equal(groupShownCalls, 1, "group show callback should run after a successful direct open")
      Assert.Equal(soloShownCalls, 0, "solo callback should stay untouched while in a group")
      local didHide = context.SetMainFrameVisible(false)
      Assert.True(didHide, "direct hide should also report a successful visibility change")
      inGroup = false
      local didSoloShow = context.SetMainFrameVisible(true)
      Assert.True(didSoloShow, "direct solo show should report a successful visibility change")
      Assert.Equal(groupShownCalls, 1, "group callback should not run again for solo open")
      Assert.Equal(soloShownCalls, 1, "solo show callback should run when not in a group")
    end)
  end)
  test("Frame bridge can open without running show callbacks when layout restore must be skipped", function()
    local visible = false
    local groupShownCalls = 0
    WithGlobals({
      UIParent = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_frame_bridge.lua" })
      local FrameBridge = RequireValue(addon.FrameBridge, "FrameBridge module should load")
      local context = FrameBridge.CreateContext({
        createCenterNotice = function()
          return {
            frame = {},
            teleportButton = {},
            SetVisible = function() end,
            UpdateTeleportButtonVisual = function() end,
            Show = function() end,
          }
        end,
        createInviteHint = function()
          return {
            Show = function() end,
          }
        end,
        createMainFrame = function(_opts)
          return {
            frame = {
              IsShown = function()
                return visible
              end,
            },
            SetVisible = function(wantVisible)
              if wantVisible then
                if visible then
                  return false
                end
                visible = true
                return true
              end
              visible = false
              return true
            end,
            SetHeightSafe = function() end,
            ToggleVisibility = function() end,
            GetPendingVisible = function()
              return nil
            end,
          }
        end,
        isInGroup = function()
          return true
        end,
        onShownInGroup = function()
          groupShownCalls = groupShownCalls + 1
        end,
        onShownNoGroup = function() end,
        isInCombat = function()
          return false
        end,
        resolveTeleportSpellID = function()
          return nil
        end,
        applySecureSpellToButton = function() end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return nil
        end,
        formatCooldownSeconds = function(value)
          return tostring(value or "")
        end,
        getL = function()
          return {}
        end,
      })
      local didShow = context.SetMainFrameVisible(true, {
        skipShowCallbacks = true,
      })
      Assert.True(didShow, "show should still open the frame")
      Assert.Equal(groupShownCalls, 0, "skipShowCallbacks must suppress restore/show callbacks")
    end)
  end)
  test("UI SetVisible outside combat has no pending state", function()
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
      })
      mainUI.SetVisible(true)
      Assert.True(mainUI.frame:IsShown(), "SetVisible(true) outside combat should open immediately")
      Assert.Nil(mainUI.GetPendingVisible(), "no pending state outside combat")
      mainUI.SetVisible(false)
      Assert.False(mainUI.frame:IsShown(), "SetVisible(false) outside combat should close immediately")
      Assert.Nil(mainUI.GetPendingVisible(), "no pending state outside combat after close")
    end)
  end)
  test("Frame bridge forwards settings opener to the main frame", function()
    local forwardedOpenSettings = nil
    local openSettingsCalls = 0
    WithGlobals({
      UIParent = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_frame_bridge.lua" })
      local FrameBridge = RequireValue(addon.FrameBridge, "FrameBridge module should load")
      FrameBridge.CreateContext({
        createCenterNotice = function()
          return {
            frame = {},
            teleportButton = {},
            SetVisible = function() end,
            UpdateTeleportButtonVisual = function() end,
            Show = function() end,
          }
        end,
        createInviteHint = function()
          return {
            Show = function() end,
          }
        end,
        createMainFrame = function(opts)
          forwardedOpenSettings = opts.onOpenSettings
          return {
            frame = {
              IsShown = function()
                return false
              end,
            },
            SetVisible = function()
              return false
            end,
            SetHeightSafe = function() end,
            ToggleVisibility = function() end,
            GetPendingVisible = function()
              return nil
            end,
          }
        end,
        isInGroup = function()
          return false
        end,
        onShownInGroup = function() end,
        onShownNoGroup = function() end,
        isInCombat = function()
          return false
        end,
        onOpenSettings = function()
          openSettingsCalls = openSettingsCalls + 1
        end,
        resolveTeleportSpellID = function()
          return nil
        end,
        applySecureSpellToButton = function() end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return nil
        end,
        formatCooldownSeconds = function(value)
          return tostring(value or "")
        end,
        getL = function()
          return {}
        end,
      })
      forwardedOpenSettings = Assert.NotNil(forwardedOpenSettings, "main frame should receive the settings opener")
      forwardedOpenSettings()
      Assert.Equal(openSettingsCalls, 1, "forwarded settings opener should call the bridge callback")
    end)
  end)
end
local function RegisterMainFrameInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UI main frame is clamped to the WoW screen while movable", function()
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
      IsiLiveDB = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
        isDragLocked = function()
          return false
        end,
      })
      Assert.True(mainUI.frame._clampedToScreen, "main frame must be clamped to the WoW screen")
      Assert.Equal(mainUI.frame._clampRectInsets[1], 0, "main frame left clamp inset must stay at the edge")
      Assert.Equal(mainUI.frame._clampRectInsets[2], 0, "main frame right clamp inset must stay at the edge")
      Assert.Equal(mainUI.frame._clampRectInsets[3], 0, "main frame top clamp inset must stay at the edge")
      Assert.Equal(mainUI.frame._clampRectInsets[4], 0, "main frame bottom clamp inset must stay at the edge")
    end)
  end)
  test("UI drag start/stop remains available during combat", function()
    local inCombat = true
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
      IsiLiveDB = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
        isDragLocked = function()
          return false
        end,
      })
      local onDragStart = mainUI.frame._scripts and mainUI.frame._scripts.OnDragStart or nil
      local onDragStop = mainUI.frame._scripts and mainUI.frame._scripts.OnDragStop or nil
      onDragStart = Assert.NotNil(onDragStart, "main frame should define OnDragStart handler")
      onDragStop = Assert.NotNil(onDragStop, "main frame should define OnDragStop handler")
      onDragStart(mainUI.frame)
      onDragStop(mainUI.frame)
      Assert.Equal(mainUI.frame._startMovingCalls, 1, "combat drag start should still call StartMoving")
      Assert.Equal(mainUI.frame._stopMovingCalls, 1, "combat drag stop should still call StopMovingOrSizing")
      Assert.NotNil(IsiLiveDB.position, "drag stop should persist main-frame position")
    end)
  end)
  test("UI drag grip lines can be hidden without disabling the drag handle", function()
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
        isDragLocked = function()
          return false
        end,
      })
      Assert.NotNil(mainUI.dragHandle, "main UI should expose the drag handle")
      Assert.Equal(#(mainUI.dragHandle._grips or {}), 0, "drag handle should have no decorative grip lines")
      mainUI.SetDragGripVisible(false)
      Assert.False(mainUI.dragHandle._gripVisible, "drag grip should be flagged hidden")
      for _, grip in ipairs(mainUI.dragHandle._grips or {}) do
        Assert.True(grip.hidden == true, "all drag grip lines should hide together")
      end
      local onDragStart = mainUI.dragHandle._scripts and mainUI.dragHandle._scripts.OnDragStart or nil
      local onDragStop = mainUI.dragHandle._scripts and mainUI.dragHandle._scripts.OnDragStop or nil
      onDragStart = Assert.NotNil(onDragStart, "drag handle should still define OnDragStart")
      onDragStop = Assert.NotNil(onDragStop, "drag handle should still define OnDragStop")
      onDragStart(mainUI.dragHandle)
      onDragStop(mainUI.dragHandle)
      Assert.Equal(mainUI.frame._startMovingCalls, 1, "hidden grip lines must not disable dragging")
      Assert.Equal(mainUI.frame._stopMovingCalls, 1, "hidden grip lines must not disable drag stop")
    end)
  end)
  test("UI close button hides frame directly", function()
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
      })
      mainUI.SetVisible(true)
      Assert.True(mainUI.frame:IsShown(), "frame should be visible before close button click")
      Assert.NotNil(mainUI.closeButton, "main UI should expose close button")
      local onClick = mainUI.closeButton._scripts and mainUI.closeButton._scripts.OnClick or nil
      onClick = Assert.NotNil(onClick, "close button should define OnClick handler")
      onClick(mainUI.closeButton, "LeftButton")
      Assert.False(mainUI.frame:IsShown(), "close button should hide frame")
    end)
  end)
  test("UI title bar settings button opens settings beside the lock button", function()
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local settingsOpenCalls = 0
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
        onOpenSettings = function()
          settingsOpenCalls = settingsOpenCalls + 1
        end,
      })
      Assert.NotNil(mainUI.lockButton, "main UI should expose the lock button")
      Assert.NotNil(mainUI.settingsButton, "main UI should expose the settings button")
      Assert.NotNil(mainUI.settingsButton.icon, "settings button should render a gear icon")
      local _, _, _, lockX = mainUI.lockButton:GetPoint()
      local _, _, _, settingsX = mainUI.settingsButton:GetPoint()
      Assert.Equal(settingsX, -46, "settings button should sit directly left of the lock button")
      Assert.Equal(lockX, -24, "lock button should stay directly left of the close button")
      local onClick = mainUI.settingsButton._scripts and mainUI.settingsButton._scripts.OnClick or nil
      onClick = Assert.NotNil(onClick, "settings button should define OnClick")
      onClick(mainUI.settingsButton, "LeftButton")
      Assert.Equal(settingsOpenCalls, 1, "settings button should call the settings opener")
    end)
  end)
  test("UI close button hides frame even during combat", function()
    local inCombat = true
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
      })
      -- Show frame before combat starts (SetVisible respects combat guard)
      inCombat = false
      mainUI.SetVisible(true)
      inCombat = true
      Assert.True(mainUI.frame:IsShown(), "frame should be visible before combat close test")
      local onClick = mainUI.closeButton._scripts and mainUI.closeButton._scripts.OnClick or nil
      onClick = Assert.NotNil(onClick, "close button should define OnClick handler")
      onClick(mainUI.closeButton, "LeftButton")
      Assert.False(mainUI.frame:IsShown(), "close button must hide frame immediately even during combat")
    end)
  end)
end
local function RegisterGameMenuReloadButtonTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UI game-menu reload button uses secure macro attributes instead of insecure callbacks", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })
      Assert.Equal(
        strip.buttonsById.reloadui._template,
        "SecureActionButtonTemplate,BackdropTemplate",
        "reload button should be created as a secure action button"
      )
      Assert.Equal(
        strip.buttonsById.reloadui._parent,
        gameMenuFrame,
        "reload button should be parented to the Blizzard game menu instead of the external host frame"
      )
      Assert.Nil(
        strip.buttonsById.reloadui._scripts and strip.buttonsById.reloadui._scripts.OnClick or nil,
        "reload button should not define an insecure OnClick handler"
      )
      Assert.Equal(
        strip.buttonsById.reloadui._registeredClicks[1],
        "LeftButtonUp",
        "reload button should default to key-up activation when no action-button cvar is available"
      )
      Assert.Equal(
        strip.buttonsById.reloadui:GetAttribute("type"),
        "macro",
        "reload button should use macro action type"
      )
      Assert.Equal(
        strip.buttonsById.reloadui:GetAttribute("type1"),
        "macro",
        "reload button should use left-click macro action type"
      )
      Assert.Equal(
        strip.buttonsById.reloadui:GetAttribute("useOnKeyDown"),
        false,
        "reload button should default to key-up mode when no action-button cvar is available"
      )
      Assert.Equal(
        strip.buttonsById.reloadui:GetAttribute("macrotext1"),
        "/click GameMenuButtonContinue\n/reload",
        "reload button macro should close the menu and then reload"
      )
    end)
  end)
  test("UI game-menu reload button follows ActionButtonUseKeyDown cvar for secure clicks", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      GetCVarBool = function(name)
        if name == "ActionButtonUseKeyDown" then
          return true
        end
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })
      Assert.Equal(
        strip.buttonsById.reloadui._registeredClicks[1],
        "LeftButtonDown",
        "reload button should switch to key-down activation when the cvar requests it"
      )
      Assert.Equal(
        strip.buttonsById.reloadui:GetAttribute("useOnKeyDown"),
        true,
        "reload button should mirror the action-button key-down cvar into its secure attributes"
      )
    end)
  end)
  test("UI game-menu secure button updates are deferred during combat and applied after regen", function()
    local inCombat = false
    local useKeyDown = false
    local createFrameStub, createdFrames = BuildCreateFrameStub({
      simulateProtectedFrames = true,
      isInCombat = function()
        return inCombat
      end,
    })
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    WithGlobals({
      UIParent = {},
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      GetCVarBool = function(name)
        if name == "ActionButtonUseKeyDown" then
          return useKeyDown
        end
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
        isInCombat = function()
          return inCombat
        end,
      })
      local reloadButton = RequireValue(strip.buttonsById.reloadui, "reload button should exist")
      local originalRegisterForClicks = reloadButton.RegisterForClicks
      reloadButton.RegisterForClicks = function(self, ...)
        if inCombat then
          error("secure click registration blocked in combat")
        end
        return originalRegisterForClicks(self, ...)
      end
      local originalSetAttribute = reloadButton.SetAttribute
      reloadButton.SetAttribute = function(self, key, value)
        if inCombat then
          error("secure attribute write blocked in combat: " .. tostring(key))
        end
        return originalSetAttribute(self, key, value)
      end
      local originalSetSize = reloadButton.SetSize
      reloadButton.SetSize = function(self, ...)
        if inCombat then
          error("secure size update blocked in combat")
        end
        return originalSetSize(self, ...)
      end
      local originalClearAllPoints = reloadButton.ClearAllPoints
      reloadButton.ClearAllPoints = function(self)
        if inCombat then
          error("secure point clear blocked in combat")
        end
        return originalClearAllPoints(self)
      end
      local originalSetPoint = reloadButton.SetPoint
      reloadButton.SetPoint = function(self, ...)
        if inCombat then
          error("secure point update blocked in combat")
        end
        return originalSetPoint(self, ...)
      end
      local originalShow = reloadButton.Show
      reloadButton.Show = function(self)
        if inCombat then
          error("secure show blocked in combat")
        end
        return originalShow(self)
      end
      local originalHide = reloadButton.Hide
      reloadButton.Hide = function(self)
        if inCombat then
          error("secure hide blocked in combat")
        end
        return originalHide(self)
      end
      useKeyDown = true
      inCombat = true
      local onShow = gameMenuFrame._scripts and gameMenuFrame._scripts.OnShow or nil
      onShow = Assert.NotNil(onShow, "game menu should register an OnShow hook")
      local ok, err = pcall(function()
        onShow(gameMenuFrame)
      end)
      Assert.True(ok, "combat OnShow must defer secure button updates instead of tainting: " .. tostring(err))
      Assert.Equal(
        reloadButton._registeredClicks[1],
        "LeftButtonUp",
        "combat OnShow should keep the previous secure click binding until regen"
      )
      Assert.Equal(
        reloadButton:GetAttribute("useOnKeyDown"),
        false,
        "combat OnShow should keep the previous secure attribute until regen"
      )
      local retryFrame = FindCombatRetryFrame(createdFrames)
      Assert.NotNil(retryFrame, "combat secure update should register a regen retry frame")
      retryFrame = RequireValue(retryFrame, "combat secure update should register a regen retry frame")
      inCombat = false
      retryFrame:FireEvent("PLAYER_REGEN_ENABLED")
      Assert.Equal(
        reloadButton._registeredClicks[1],
        "LeftButtonDown",
        "deferred secure update should apply the key-down click binding after regen"
      )
      Assert.Equal(
        reloadButton:GetAttribute("useOnKeyDown"),
        true,
        "deferred secure update should refresh secure attributes after regen"
      )
      -- PLAYER_REGEN_ENABLED stays registered after drain: the frame is statically
      -- registered at module load to avoid dynamic RegisterEvent from protected
      -- dispatch (ADDON_ACTION_FORBIDDEN in 12.0+). OnEvent early-returns when the
      -- pending queue is empty.
      Assert.True(
        retryFrame:IsEventRegistered("PLAYER_REGEN_ENABLED"),
        "regen retry frame keeps PLAYER_REGEN_ENABLED registered (static registration)"
      )
    end)
  end)
  test("UI game-menu panel stays mounted as GameMenuFrame child while reload button remains secure", function()
    local inCombat = false
    local createFrameStub = BuildCreateFrameStub({
      simulateProtectedFrames = true,
      isInCombat = function()
        return inCombat
      end,
    })
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    gameMenuFrame._isProtected = true
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    WithGlobals({
      UIParent = {},
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
        isInCombat = function()
          return inCombat
        end,
      })
      Assert.True(
        strip.panelFrame._parent == gameMenuFrame,
        "panel frame should be mounted directly under GameMenuFrame"
      )
      Assert.True(strip.hostFrame == strip.panelFrame, "host frame alias should point to the mounted panel frame")
      Assert.True(strip.panelFrame._isProtected, "panel frame should inherit protected GameMenuFrame parentage")
      Assert.True(strip.buttonsById.reloadui._isProtected, "reload button itself should remain secure")
    end)
  end)
end
local function RegisterGameMenuSecondPanelBehaviorTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UI second game-menu hearthstone button picks an owned toy and re-rolls on PreClick", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    -- Player owns three of the listed hearthstone toys; the addon should pick
    -- one initially and re-pick a different one on every PreClick fire. The
    -- production code's anti-repeat guard (`repeat … until pick ~= current`)
    -- guarantees `post ~= pre` regardless of math.random's actual sequence,
    -- so the test can rely on the live RNG without patching it.
    local ownedToys = { [54452] = true, [64488] = true, [93672] = true }

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      PlayerHasToy = function(itemID)
        return ownedToys[itemID] == true
      end,
      InCombatLockdown = function()
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = strip,
        getL = function()
          return {
            BTN_SECOND_HEARTHSTONE = "Hearthstone",
            BTN_SECOND_HOUSING = "Housing",
            PANEL_HEADER_TRAVEL = "Travel",
          }
        end,
      })

      local hearthstoneButton =
        RequireValue(travelStrip.buttonsById.hearthstone, "hearthstone button should exist when toys are owned")
      Assert.Equal(
        hearthstoneButton:GetAttribute("type"),
        "toy",
        "secure type must be 'toy' when at least one hearthstone toy is owned"
      )
      local initialToy = hearthstoneButton:GetAttribute("toy")
      Assert.True(
        ownedToys[initialToy] == true,
        "initial bound toy must be one of the owned ids (got " .. tostring(initialToy) .. ")"
      )

      local preClick = hearthstoneButton._scripts and hearthstoneButton._scripts.PreClick or nil
      preClick = Assert.NotNil(preClick, "PreClick handler must be installed for re-rolling")

      local pre = hearthstoneButton:GetAttribute("toy")
      preClick(hearthstoneButton)
      local post = hearthstoneButton:GetAttribute("toy")
      Assert.True(ownedToys[post] == true, "re-rolled toy must still come from the owned pool")
      Assert.True(post ~= pre, "re-roll must produce a toy different from the previous one")

      local pre2 = post
      preClick(hearthstoneButton)
      local post2 = hearthstoneButton:GetAttribute("toy")
      Assert.True(ownedToys[post2] == true, "second re-roll must stay within the owned pool")
      Assert.True(post2 ~= pre2, "second re-roll must produce a toy different from the previous one")
    end)
  end)

  test("UI second game-menu hearthstone button skips re-roll while in combat", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    local ownedToys = { [54452] = true, [64488] = true }
    local inCombat = false

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      PlayerHasToy = function(itemID)
        return ownedToys[itemID] == true
      end,
      InCombatLockdown = function()
        return inCombat
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = strip,
        getL = function()
          return {
            BTN_SECOND_HEARTHSTONE = "Hearthstone",
            BTN_SECOND_HOUSING = "Housing",
            PANEL_HEADER_TRAVEL = "Travel",
          }
        end,
      })

      local hearthstoneButton = RequireValue(travelStrip.buttonsById.hearthstone, "hearthstone button must exist")
      local initialToy = hearthstoneButton:GetAttribute("toy")

      inCombat = true
      local preClick = hearthstoneButton._scripts and hearthstoneButton._scripts.PreClick or nil
      preClick = Assert.NotNil(preClick, "PreClick handler must be installed")
      preClick(hearthstoneButton)

      Assert.Equal(
        hearthstoneButton:GetAttribute("toy"),
        initialToy,
        "in-combat re-roll must be a no-op so secure attributes are not rewritten"
      )
    end)
  end)

  test("UI second game-menu hearthstone button falls back to item:6948 when no toys are owned", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      PlayerHasToy = function(_itemID)
        return false
      end,
      InCombatLockdown = function()
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = strip,
        getL = function()
          return {
            BTN_SECOND_HEARTHSTONE = "Hearthstone",
            BTN_SECOND_HOUSING = "Housing",
            PANEL_HEADER_TRAVEL = "Travel",
          }
        end,
      })

      local hearthstoneButton = RequireValue(travelStrip.buttonsById.hearthstone, "hearthstone button must exist")
      Assert.Equal(hearthstoneButton:GetAttribute("type"), "item", "no owned toy must fall back to a plain item action")
      Assert.Equal(
        hearthstoneButton:GetAttribute("item"),
        "item:6948",
        "fallback must bind the classic Hearthstone item id"
      )
      -- PreClick is always installed so the button can self-heal once the
      -- account-wide toy cache warms up (typical after a character switch:
      -- the panel is built from ADDON_LOADED before TOYS_UPDATED fires).
      local preClick = hearthstoneButton._scripts and hearthstoneButton._scripts.PreClick or nil
      preClick = Assert.NotNil(preClick, "PreClick handler must be installed even without owned toys")

      -- Calling PreClick while still no toys are owned must be a no-op so the
      -- secure attributes stay on the item-fallback for this click.
      preClick(hearthstoneButton)
      Assert.Equal(
        hearthstoneButton:GetAttribute("type"),
        "item",
        "PreClick must not rewrite type when no toys are owned"
      )
      Assert.Equal(
        hearthstoneButton:GetAttribute("item"),
        "item:6948",
        "PreClick must keep the fallback item binding when no toys are owned"
      )
    end)
  end)

  test("UI second game-menu hearthstone button respects explicit toy choice", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      PlayerHasToy = function(itemID)
        return itemID == 64488
      end,
      InCombatLockdown = function()
        return false
      end,
      IsiLiveDB = { hearthstoneChoice = "toy:64488" },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = strip,
        getL = function()
          return {
            BTN_SECOND_HEARTHSTONE = "Hearthstone",
            BTN_SECOND_HOUSING = "Housing",
            PANEL_HEADER_TRAVEL = "Travel",
          }
        end,
      })

      local hearthstoneButton = RequireValue(travelStrip.buttonsById.hearthstone, "hearthstone button must exist")
      Assert.Equal(
        hearthstoneButton:GetAttribute("type"),
        "toy",
        "explicit toy choice must bind the button as a toy action"
      )
      Assert.Equal(hearthstoneButton:GetAttribute("toy"), 64488, "explicit toy choice must bind the selected toy id")
      local preClick = hearthstoneButton._scripts and hearthstoneButton._scripts.PreClick or nil
      preClick = Assert.NotNil(preClick, "PreClick handler must be installed")
      preClick(hearthstoneButton)
      Assert.Equal(hearthstoneButton:GetAttribute("toy"), 64488, "explicit toy choice must not be changed by PreClick")
    end)
  end)

  test("UI second game-menu hearthstone button rejects explicit toy choice when not owned", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      PlayerHasToy = function(itemID)
        return itemID == 93672
      end,
      InCombatLockdown = function()
        return false
      end,
      IsiLiveDB = { hearthstoneChoice = "toy:64488" },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = strip,
        getL = function()
          return {
            BTN_SECOND_HEARTHSTONE = "Hearthstone",
            BTN_SECOND_HOUSING = "Housing",
            PANEL_HEADER_TRAVEL = "Travel",
          }
        end,
      })

      local hearthstoneButton = RequireValue(travelStrip.buttonsById.hearthstone, "hearthstone button must exist")
      Assert.Equal(
        hearthstoneButton:GetAttribute("type"),
        "toy",
        "invalid explicit toy must fall back to a verified owned toy when one exists"
      )
      Assert.Equal(
        hearthstoneButton:GetAttribute("toy"),
        93672,
        "unowned explicit toy id must never be bound to the secure action"
      )
    end)
  end)

  test("UI second game-menu hearthstone settings change defers secure attributes during combat", function()
    local inCombat = false
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local db = { hearthstoneChoice = "random" }
    local ownedToys = { [54452] = true, [93672] = true }

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      IsiLiveDB = db,
      PlayerHasToy = function(itemID)
        return ownedToys[itemID] == true
      end,
      InCombatLockdown = function()
        return inCombat
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
        isInCombat = function()
          return inCombat
        end,
      })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = strip,
        isInCombat = function()
          return inCombat
        end,
        getL = function()
          return {
            BTN_SECOND_HEARTHSTONE = "Hearthstone",
            BTN_SECOND_HOUSING = "Housing",
            PANEL_HEADER_TRAVEL = "Travel",
          }
        end,
      })

      local hearthstoneButton = RequireValue(travelStrip.buttonsById.hearthstone, "hearthstone button must exist")
      local originalToy = hearthstoneButton:GetAttribute("toy")
      local originalSetAttribute = hearthstoneButton.SetAttribute
      hearthstoneButton.SetAttribute = function(self, key, value)
        if inCombat then
          error("secure hearthstone attribute write blocked in combat: " .. tostring(key))
        end
        return originalSetAttribute(self, key, value)
      end

      db.hearthstoneChoice = "toy:93672"
      inCombat = true
      local ok, err = pcall(function()
        travelStrip.SyncVisibility()
      end)
      Assert.True(ok, "combat settings refresh must defer secure hearthstone attributes: " .. tostring(err))
      Assert.Equal(
        hearthstoneButton:GetAttribute("toy"),
        originalToy,
        "combat settings refresh must keep existing secure toy binding until regen"
      )

      local retryFrame =
        Assert.NotNil(createdFrames and FindCombatRetryFrame(createdFrames), "combat refresh must queue regen")
      inCombat = false
      retryFrame:FireEvent("PLAYER_REGEN_ENABLED")

      Assert.Equal(hearthstoneButton:GetAttribute("type"), "toy", "regen must apply the selected hearthstone action")
      Assert.Equal(
        hearthstoneButton:GetAttribute("toy"),
        93672,
        "regen must apply the verified selected hearthstone toy"
      )
    end)
  end)

  test("UI game-menu hearthstone settings change defers secure attributes during active challenge key", function()
    local activeChallengeKey = false
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local db = { hearthstoneChoice = "random" }
    local ownedToys = { [54452] = true, [93672] = true }

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      IsiLiveDB = db,
      PlayerHasToy = function(itemID)
        return ownedToys[itemID] == true
      end,
      InCombatLockdown = function()
        return activeChallengeKey
      end,
      C_ChallengeMode = {
        IsChallengeModeActive = function()
          return activeChallengeKey
        end,
        GetActiveChallengeMapID = function()
          return activeChallengeKey and 503 or nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
        isInCombat = function()
          return activeChallengeKey
        end,
      })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = strip,
        isInCombat = function()
          return activeChallengeKey
        end,
        getL = function()
          return {
            BTN_SECOND_HEARTHSTONE = "Hearthstone",
            BTN_SECOND_HOUSING = "Housing",
            PANEL_HEADER_TRAVEL = "Travel",
          }
        end,
      })

      local hearthstoneButton = RequireValue(travelStrip.buttonsById.hearthstone, "hearthstone button must exist")
      local originalToy = hearthstoneButton:GetAttribute("toy")
      local originalSetAttribute = hearthstoneButton.SetAttribute
      hearthstoneButton.SetAttribute = function(self, key, value)
        if activeChallengeKey then
          error("secure hearthstone attribute write blocked during active challenge key: " .. tostring(key))
        end
        return originalSetAttribute(self, key, value)
      end

      db.hearthstoneChoice = "toy:93672"
      activeChallengeKey = true
      local ok, err = pcall(function()
        travelStrip.SyncVisibility()
      end)
      Assert.True(ok, "active-key settings refresh must defer secure hearthstone attributes: " .. tostring(err))
      Assert.Equal(
        hearthstoneButton:GetAttribute("toy"),
        originalToy,
        "active-key settings refresh must keep existing secure toy binding until protected state ends"
      )

      local retryFrame =
        Assert.NotNil(createdFrames and FindCombatRetryFrame(createdFrames), "active-key refresh must queue regen")
      activeChallengeKey = false
      retryFrame:FireEvent("PLAYER_REGEN_ENABLED")

      Assert.Equal(hearthstoneButton:GetAttribute("type"), "toy", "post-key regen must apply the selected action")
      Assert.Equal(hearthstoneButton:GetAttribute("toy"), 93672, "post-key regen must apply the verified selected toy")
    end)
  end)

  test("UI hearthstone collector only includes gated toys when their live requirement is verified", function()
    local createFrameStub = BuildCreateFrameStub()
    local playerHasToyByID = {
      [180290] = true,
      [210455] = true,
      [64488] = true,
    }
    local activeCovenantID = 0
    local raceID = 1

    WithGlobals({
      CreateFrame = createFrameStub,
      UnitExists = function()
        return true
      end,
      PlayerHasToy = function(itemID)
        return playerHasToyByID[itemID] == true
      end,
      GetAchievementCriteriaInfo = function(_achievementID, criteriaIndex)
        return nil, nil, false
      end,
      C_Covenants = {
        GetActiveCovenantID = function()
          return activeCovenantID
        end,
      },
      UnitRace = function()
        return nil, nil, raceID
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local collect = Assert.NotNil(addon.UI.CollectOwnedHearthstoneToys, "collector must be exported")
      local englishName =
        Assert.NotNil(addon.UI.GetHearthstoneToyEnglishName, "English hearthstone name resolver must be exported")
      Assert.Equal(
        englishName(180290),
        "Night Fae Hearthstone",
        "English hearthstone name resolver must return the verified static name"
      )

      local cold = collect()
      local coldSet = {}
      for _, id in ipairs(cold) do
        coldSet[id] = true
      end
      Assert.True(coldSet[64488] == true, "plain owned hearthstone toy must be available")
      Assert.Nil(coldSet[180290], "covenant-gated hearthstone must stay hidden without verified access")
      Assert.Nil(coldSet[210455], "race-gated hearthstone must stay hidden without verified race")

      activeCovenantID = 3
      raceID = 11
      local warm = collect()
      local warmSet = {}
      for _, id in ipairs(warm) do
        warmSet[id] = true
      end
      Assert.True(warmSet[180290] == true, "covenant-gated hearthstone must appear after verified access")
      Assert.True(warmSet[210455] == true, "race-gated hearthstone must appear after verified race")
    end)
  end)

  test("UI second game-menu hearthstone button self-heals on PreClick once the toy cache warms up", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    -- Reproduces the character-switch bug: at panel-build time the
    -- account-wide toy cache is cold and PlayerHasToy reports false for
    -- everything, so the button falls back to item:6948. Once the cache
    -- warms up (PlayerHasToy now reports true), the PreClick hook must
    -- rebuild the pool and rebind the button to a real toy.
    local cacheWarm = false
    local ownedToys = { [54452] = true, [64488] = true, [93672] = true }

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      PlayerHasToy = function(itemID)
        if not cacheWarm then
          return false
        end
        return ownedToys[itemID] == true
      end,
      InCombatLockdown = function()
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
      local travelStrip = UI.EnsureSecondPanelUI({
        gameMenuFrame = gameMenuFrame,
        firstPanelState = strip,
        getL = function()
          return {
            BTN_SECOND_HEARTHSTONE = "Hearthstone",
            BTN_SECOND_HOUSING = "Housing",
            PANEL_HEADER_TRAVEL = "Travel",
          }
        end,
      })

      local hearthstoneButton =
        RequireValue(travelStrip.buttonsById.hearthstone, "hearthstone button must exist on cold cache")
      Assert.Equal(hearthstoneButton:GetAttribute("type"), "item", "cold-cache build must fall back to the item action")

      cacheWarm = true
      local preClick = hearthstoneButton._scripts and hearthstoneButton._scripts.PreClick or nil
      preClick = Assert.NotNil(preClick, "PreClick handler must be installed for self-heal")
      preClick(hearthstoneButton)

      Assert.Equal(
        hearthstoneButton:GetAttribute("type"),
        "toy",
        "PreClick must upgrade the button to a toy action once the cache warms up"
      )
      local pickedToy = hearthstoneButton:GetAttribute("toy")
      Assert.True(
        ownedToys[pickedToy] == true,
        "self-healed toy must be one of the owned ids (got " .. tostring(pickedToy) .. ")"
      )
    end)
  end)

  -- ----------------------------------------------------------------------
  -- Housing-plot teleport button
  -- ----------------------------------------------------------------------

  local function FindFrameWithEvent(createdFrames, eventName)
    for _, frame in ipairs(createdFrames or {}) do
      if frame.IsEventRegistered and frame:IsEventRegistered(eventName) then
        return frame
      end
    end
    return nil
  end

  local function FireEventOnRegisteredFrames(createdFrames, eventName, ...)
    for _, frame in ipairs(createdFrames or {}) do
      if frame.IsEventRegistered and frame:IsEventRegistered(eventName) and frame.FireEvent then
        frame:FireEvent(eventName, ...)
      end
    end
  end

  local function BuildHousingScenario()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    return createFrameStub, createdFrames, gameMenuFrame
  end

  local function BuildHousingGlobals(createFrameStub, gameMenuFrame, isInCombatRef)
    return {
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      PlayerHasToy = function(_itemID)
        return false
      end,
      InCombatLockdown = function()
        return isInCombatRef.value == true
      end,
      C_Housing = {
        GetPlayerOwnedHouses = function() end,
      },
    }
  end

  local function BuildHousingPanels(addon, gameMenuFrame)
    local UI = RequireValue(addon.UI, "UI module should load")
    local strip = UI.EnsurePanelUI({ gameMenuFrame = gameMenuFrame })
    local travelStrip = UI.EnsureSecondPanelUI({
      gameMenuFrame = gameMenuFrame,
      firstPanelState = strip,
      getL = function()
        return {
          BTN_SECOND_HEARTHSTONE = "Hearthstone",
          BTN_SECOND_DALARAN = "Dalaran",
          BTN_SECOND_HOUSING = "Housing",
          PANEL_HEADER_TRAVEL = "Travel",
        }
      end,
    })
    return travelStrip
  end

  test("UI second game-menu Dalaran button binds toy only when owned", function()
    local createFrameStub, createdFrames, gameMenuFrame = BuildHousingScenario()
    local isInCombat = { value = false }

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      PlayerHasToy = function(itemID)
        return itemID == 140192
      end,
      InCombatLockdown = function()
        return isInCombat.value == true
      end,
      C_Housing = {
        GetPlayerOwnedHouses = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local travelStrip = BuildHousingPanels(addon, gameMenuFrame)

      local dalaranButton = RequireValue(travelStrip.buttonsById.dalaran_hearthstone, "Dalaran button must exist")
      Assert.True(dalaranButton:IsShown(), "owned Dalaran Hearthstone button must be visible")
      Assert.Equal(dalaranButton:GetAttribute("type"), "toy", "Dalaran button must bind a toy action")
      Assert.Equal(dalaranButton:GetAttribute("toy"), 140192, "Dalaran button must bind the Dalaran Hearthstone toy")

      local housingButton = RequireValue(travelStrip.buttonsById.housing_plot, "housing button must still exist")
      Assert.Equal(housingButton:GetAttribute("type"), nil, "unrelated housing button must keep its own conditions")
      Assert.NotNil(FindFrameWithEvent(createdFrames, "TOYS_UPDATED"), "Dalaran toy refresh frame must be registered")
    end)
  end)

  test("UI second game-menu Dalaran button appears after TOYS_UPDATED warms the toy cache", function()
    local createFrameStub, createdFrames, gameMenuFrame = BuildHousingScenario()
    local hasDalaranToy = false

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      PlayerHasToy = function(itemID)
        return itemID == 140192 and hasDalaranToy == true
      end,
      InCombatLockdown = function()
        return false
      end,
      C_Housing = {
        GetPlayerOwnedHouses = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local travelStrip = BuildHousingPanels(addon, gameMenuFrame)

      local dalaranButton =
        RequireValue(travelStrip.buttonsById.dalaran_hearthstone, "Dalaran button must exist while hidden")
      Assert.False(dalaranButton:IsShown(), "cold or missing Dalaran toy cache must keep the button hidden")
      Assert.Equal(dalaranButton:GetAttribute("type"), nil, "hidden Dalaran button must not guess a fallback action")

      hasDalaranToy = true
      FireEventOnRegisteredFrames(createdFrames, "TOYS_UPDATED")

      Assert.True(dalaranButton:IsShown(), "Dalaran button must appear after verified TOYS_UPDATED ownership")
      Assert.Equal(dalaranButton:GetAttribute("type"), "toy", "warmed Dalaran button must bind a toy action")
      Assert.Equal(dalaranButton:GetAttribute("toy"), 140192, "warmed Dalaran button must bind the verified toy")
    end)
  end)

  test("UI housing-plot button binds teleporthome attributes on PLAYER_HOUSE_LIST_UPDATED", function()
    local createFrameStub, createdFrames, gameMenuFrame = BuildHousingScenario()
    local isInCombat = { value = false }

    WithGlobals(BuildHousingGlobals(createFrameStub, gameMenuFrame, isInCombat), function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local travelStrip = BuildHousingPanels(addon, gameMenuFrame)

      local housingButton = RequireValue(travelStrip.buttonsById.housing_plot, "housing button must exist")
      Assert.Equal(
        housingButton:GetAttribute("type"),
        nil,
        "no attributes are bound before the housing payload arrives"
      )

      local housingEventFrame = FindFrameWithEvent(createdFrames, "PLAYER_HOUSE_LIST_UPDATED")
      housingEventFrame = Assert.NotNil(housingEventFrame, "housing data event frame must be created")
      if housingEventFrame == nil then
        return
      end
      housingEventFrame:FireEvent("PLAYER_HOUSE_LIST_UPDATED", {
        {
          neighborhoodGUID = "ngh-1",
          houseGUID = "house-1",
          plotID = 42,
        },
      })

      Assert.Equal(housingButton:GetAttribute("type"), "teleporthome", "type must be teleporthome after payload")
      Assert.Equal(housingButton:GetAttribute("house-neighborhood-guid"), "ngh-1", "neighborhood guid must be bound")
      Assert.Equal(housingButton:GetAttribute("house-guid"), "house-1", "house guid must be bound")
      Assert.Equal(housingButton:GetAttribute("house-plot-id"), 42, "plot id must be bound")
    end)
  end)

  test("UI housing-plot button keeps listening when the first PLAYER_HOUSE_LIST_UPDATED has no houses", function()
    local createFrameStub, createdFrames, gameMenuFrame = BuildHousingScenario()
    local isInCombat = { value = false }

    WithGlobals(BuildHousingGlobals(createFrameStub, gameMenuFrame, isInCombat), function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local travelStrip = BuildHousingPanels(addon, gameMenuFrame)

      local housingButton = RequireValue(travelStrip.buttonsById.housing_plot, "housing button must exist")
      local housingEventFrame = FindFrameWithEvent(createdFrames, "PLAYER_HOUSE_LIST_UPDATED")
      housingEventFrame = Assert.NotNil(housingEventFrame, "housing data event frame must be created")
      if housingEventFrame == nil then
        return
      end

      -- First fire arrives with an empty houses list (player has no plot yet).
      housingEventFrame:FireEvent("PLAYER_HOUSE_LIST_UPDATED", {})
      Assert.Equal(
        housingButton:GetAttribute("type"),
        nil,
        "no attributes are bound when the payload has no first house"
      )
      Assert.True(
        housingEventFrame:IsEventRegistered("PLAYER_HOUSE_LIST_UPDATED"),
        "listener must stay registered so a later house assignment still configures the button"
      )

      -- Later, the player buys a house and the event re-fires with a real payload.
      housingEventFrame:FireEvent("PLAYER_HOUSE_LIST_UPDATED", {
        {
          neighborhoodGUID = "ngh-late",
          houseGUID = "house-late",
          plotID = 7,
        },
      })
      Assert.Equal(housingButton:GetAttribute("type"), "teleporthome", "late payload still wires the button")
      Assert.Equal(housingButton:GetAttribute("house-guid"), "house-late", "late house guid must be bound")
    end)
  end)

  test("UI housing-plot button defers SetAttribute during combat and applies on PLAYER_REGEN_ENABLED", function()
    local createFrameStub, createdFrames, gameMenuFrame = BuildHousingScenario()
    local isInCombat = { value = true }

    WithGlobals(BuildHousingGlobals(createFrameStub, gameMenuFrame, isInCombat), function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local travelStrip = BuildHousingPanels(addon, gameMenuFrame)

      local housingButton = RequireValue(travelStrip.buttonsById.housing_plot, "housing button must exist")
      local housingEventFrame = FindFrameWithEvent(createdFrames, "PLAYER_HOUSE_LIST_UPDATED")
      housingEventFrame = Assert.NotNil(housingEventFrame, "housing data event frame must be created")
      if housingEventFrame == nil then
        return
      end

      housingEventFrame:FireEvent("PLAYER_HOUSE_LIST_UPDATED", {
        {
          neighborhoodGUID = "ngh-combat",
          houseGUID = "house-combat",
          plotID = 99,
        },
      })

      Assert.Equal(
        housingButton:GetAttribute("type"),
        nil,
        "combat must block SetAttribute and keep the button unconfigured for now"
      )

      -- Locate the combat-retry frame (panelUISecureRetryFrame) and drain it.
      local retryFrame = FindCombatRetryFrame(createdFrames)
      retryFrame = Assert.NotNil(retryFrame, "combat retry frame must exist")
      if retryFrame == nil then
        return
      end

      isInCombat.value = false
      retryFrame:FireEvent("PLAYER_REGEN_ENABLED")

      Assert.Equal(
        housingButton:GetAttribute("type"),
        "teleporthome",
        "post-combat regen drain must apply the pending housing attributes"
      )
      Assert.Equal(housingButton:GetAttribute("house-guid"), "house-combat", "deferred house guid must be bound")
      Assert.Equal(housingButton:GetAttribute("house-plot-id"), 99, "deferred plot id must be bound")
    end)
  end)

  test("UI game-menu reload button refreshes secure click mode when panel UI is reused", function()
    local useKeyDown = false
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      UIParent = {},
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      GetCVarBool = function(name)
        if name == "ActionButtonUseKeyDown" then
          return useKeyDown
        end
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })

      Assert.Equal(
        strip.buttonsById.reloadui._registeredClicks[1],
        "LeftButtonUp",
        "initial binding should use key-up mode"
      )
      Assert.Equal(
        strip.buttonsById.reloadui:GetAttribute("useOnKeyDown"),
        false,
        "initial attribute should match key-up mode"
      )

      useKeyDown = true
      local reusedStrip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })

      Assert.Equal(reusedStrip, strip, "panel UI should be reused for the same GameMenuFrame")
      Assert.Equal(
        reusedStrip.buttonsById.reloadui._registeredClicks[1],
        "LeftButtonDown",
        "reused panel should refresh to key-down mode"
      )
      Assert.Equal(
        reusedStrip.buttonsById.reloadui:GetAttribute("useOnKeyDown"),
        true,
        "reused panel should refresh secure click attributes"
      )
    end)
  end)
end

local function RegisterGameMenuDefaultOpenerTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UI game-menu default profession and spellbook buttons prefer native Blizzard openers", function()
    local createFrameStub = BuildCreateFrameStub()
    local uiParent = {}
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local professionsFrame = createFrameStub("Frame", "ProfessionsFrame", uiParent, "BackdropTemplate")
    professionsFrame:Hide()
    local professionClicks = 0
    local playerSpellsClicks = 0
    local spellbookMicroClicks = 0
    local spellbookDirectCalls = 0
    local fallbackCalls = 0

    WithGlobals({
      UIParent = uiParent,
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      ProfessionMicroButton = {
        Click = function()
          professionClicks = professionClicks + 1
          professionsFrame:Show()
        end,
      },
      PlayerSpellsMicroButton = {
        Click = function()
          playerSpellsClicks = playerSpellsClicks + 1
        end,
      },
      SpellbookMicroButton = {
        Click = function()
          spellbookMicroClicks = spellbookMicroClicks + 1
        end,
      },
      ProfessionsFrame = professionsFrame,
      PlayerSpellsUtil = {
        ToggleSpellBookFrame = function()
          spellbookDirectCalls = spellbookDirectCalls + 1
        end,
      },
      ToggleProfessionsBook = function()
        fallbackCalls = fallbackCalls + 1
      end,
      TogglePlayerSpellsFrame = function()
        fallbackCalls = fallbackCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })

      local onClickProfessions = strip.buttonsById.professions._scripts
          and strip.buttonsById.professions._scripts.OnClick
        or nil
      local onClickSpellbook = strip.buttonsById.spellbook._scripts and strip.buttonsById.spellbook._scripts.OnClick
        or nil
      onClickProfessions = Assert.NotNil(onClickProfessions, "professions micromenu button should define OnClick")
      onClickSpellbook = Assert.NotNil(onClickSpellbook, "spellbook micromenu button should define OnClick")

      onClickProfessions(strip.buttonsById.professions, "LeftButton")
      onClickSpellbook(strip.buttonsById.spellbook, "LeftButton")

      Assert.Equal(professionClicks, 1, "profession button should trigger ProfessionMicroButton first")
      Assert.Equal(spellbookDirectCalls, 1, "spellbook button should prefer the explicit spellbook opener")
      Assert.Equal(playerSpellsClicks, 0, "spellbook button should not route through PlayerSpellsMicroButton")
      Assert.Equal(
        spellbookMicroClicks,
        0,
        "spellbook button should avoid the spellbook microbutton when the direct API exists"
      )
      Assert.Equal(fallbackCalls, 0, "native opener path should avoid the fallback toggle functions")
    end)
  end)

  test("UI game-menu falls back to direct open without routing spellbook through talents", function()
    local createFrameStub = BuildCreateFrameStub()
    local uiParent = {}
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local professionsFrame = createFrameStub("Frame", "ProfessionsFrame", uiParent, "BackdropTemplate")
    local playerSpellsFrame = createFrameStub("Frame", "PlayerSpellsFrame", uiParent, "BackdropTemplate")
    professionsFrame:Hide()
    playerSpellsFrame:Hide()
    local professionClicks = 0
    local playerSpellsClicks = 0
    local spellbookMicroClicks = 0
    local professionFallbackCalls = 0
    local spellbookFallbackCalls = 0

    WithGlobals({
      UIParent = uiParent,
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      ProfessionMicroButton = {
        Click = function()
          professionClicks = professionClicks + 1
        end,
      },
      PlayerSpellsMicroButton = {
        Click = function()
          playerSpellsClicks = playerSpellsClicks + 1
        end,
      },
      SpellbookMicroButton = {
        Click = function()
          spellbookMicroClicks = spellbookMicroClicks + 1
        end,
      },
      ProfessionsFrame = professionsFrame,
      PlayerSpellsFrame = playerSpellsFrame,
      ToggleProfessionsBook = function()
        professionFallbackCalls = professionFallbackCalls + 1
        professionsFrame:Show()
      end,
      PlayerSpellsUtil = {
        FrameTabs = {
          SpellBook = "SpellBook",
        },
      },
      TogglePlayerSpellsFrame = function(tab)
        if tab == "SpellBook" then
          spellbookFallbackCalls = spellbookFallbackCalls + 1
          playerSpellsFrame:Show()
        end
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })

      local onClickProfessions = strip.buttonsById.professions._scripts
          and strip.buttonsById.professions._scripts.OnClick
        or nil
      local onClickSpellbook = strip.buttonsById.spellbook._scripts and strip.buttonsById.spellbook._scripts.OnClick
        or nil
      onClickProfessions = Assert.NotNil(onClickProfessions, "professions micromenu button should define OnClick")
      onClickSpellbook = Assert.NotNil(onClickSpellbook, "spellbook micromenu button should define OnClick")

      onClickProfessions(strip.buttonsById.professions, "LeftButton")
      onClickSpellbook(strip.buttonsById.spellbook, "LeftButton")

      Assert.Equal(professionClicks, 1, "profession button should still try the native micro button first")
      Assert.Equal(
        professionFallbackCalls,
        1,
        "profession button should fall back to ToggleProfessionsBook on no-op click"
      )
      Assert.Equal(
        spellbookFallbackCalls,
        1,
        "spellbook button should fall back to the explicit SpellBook tab when the direct API is unavailable"
      )
      Assert.Equal(playerSpellsClicks, 0, "spellbook button should not click the talents microbutton")
      Assert.Equal(
        spellbookMicroClicks,
        0,
        "spellbook button should not need the spellbook microbutton when the tab API exists"
      )
      Assert.True(professionsFrame:IsShown(), "profession fallback should open the professions frame")
      Assert.True(playerSpellsFrame:IsShown(), "spellbook fallback should open the player spells frame")
    end)
  end)
end

local function RegisterGameMenuMicroButtonTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterGameMenuReloadButtonTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterGameMenuSecondPanelBehaviorTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterGameMenuDefaultOpenerTests(test, Assert, WithGlobals, LoadAddonModules)
end

local function RegisterMainFrameLockTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Settings panel defaults main frame position lock to enabled and persists unlocks", function()
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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LOCK_MAIN_FRAME_POSITION = "Lock main frame position",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_CLOSE_MAIN_FRAME = "Auto Close Main Frame",
            SETTINGS_AUTO_SHOW_MAIN_FRAME_ON_STARTUP = "Show on Login / Reload",
            SETTINGS_AUTO_OPEN_MAIN_FRAME_ON_KEY_END = "Auto Open on Key End",
            SETTINGS_DEFAULT_OPEN_UI = "Default UI on Open",
            SETTINGS_DEFAULT_OPEN_UI_LAST = "Last Used",
            SETTINGS_DEFAULT_OPEN_UI_V = "V",
            SETTINGS_DEFAULT_OPEN_UI_H = "H",
            SETTINGS_DEFAULT_OPEN_UI_M2 = "M2",
            SETTINGS_RAID_TRANSITION_BEHAVIOR = "Raid Behavior",
            SETTINGS_RAID_TRANSITION_BEHAVIOR_HIDE = "Raid Off",
            SETTINGS_ROSTER_COLUMN_GUIDES = "Column Guides",
            SETTINGS_SHOW_TIMEWAYS_NAVIGATOR = "Show Timeways Navigator",
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

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")

      local lockCheck = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_LOCK_MAIN_FRAME_POSITION" then
          lockCheck = frame
          break
        end
      end

      lockCheck = Assert.NotNil(lockCheck, "settings panel should create the drag-lock checkbox")
      ---@diagnostic disable: undefined-field
      Assert.True(lockCheck:GetChecked(), "main frame position lock should default to enabled")

      local onClick = lockCheck._scripts and lockCheck._scripts.OnClick or nil
      onClick = Assert.NotNil(onClick, "main frame position lock checkbox should define OnClick")
      lockCheck:SetChecked(false)
      onClick(lockCheck)
      Assert.False(db.lockMainFramePosition, "unlocking the checkbox should persist false")
      ---@diagnostic enable: undefined-field
    end)
  end)

  test("UI main frame drag lock blocks accidental movement until unlocked", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      UIParent = {},
      IsiLiveDB = {},
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
        isDragLocked = function()
          return true
        end,
      })

      Assert.True(mainUI.GetDragLocked(), "main UI should start locked")
      local onDragStart = mainUI.frame._scripts and mainUI.frame._scripts.OnDragStart or nil
      local onDragStop = mainUI.frame._scripts and mainUI.frame._scripts.OnDragStop or nil
      onDragStart = Assert.NotNil(onDragStart, "main UI should define an OnDragStart handler")
      onDragStop = Assert.NotNil(onDragStop, "main UI should define an OnDragStop handler")

      onDragStart(mainUI.frame)
      onDragStop(mainUI.frame)

      Assert.Equal(mainUI.frame._startMovingCalls, 0, "locked frame should ignore drag start")
      Assert.Equal(mainUI.frame._stopMovingCalls, 0, "locked frame should ignore drag stop")

      mainUI.SetDragLocked(false)
      onDragStart(mainUI.frame)
      onDragStop(mainUI.frame)

      Assert.Equal(mainUI.frame._startMovingCalls, 1, "unlocked frame should start moving")
      Assert.Equal(mainUI.frame._stopMovingCalls, 1, "unlocked frame should stop moving")
      Assert.NotNil(IsiLiveDB.position, "unlocked drag should persist the position")
    end)
  end)

  test("UI main frame lock button toggles the drag lock state", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      UIParent = {},
      IsiLiveDB = {},
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
        isDragLocked = function()
          return true
        end,
      })

      Assert.NotNil(mainUI.lockButton, "main UI should expose the lock button")
      Assert.True(mainUI.GetDragLocked(), "main UI should start locked")
      Assert.True(mainUI.lockButton._isLocked, "lock button should reflect the initial locked state")

      local onClick = mainUI.lockButton._scripts and mainUI.lockButton._scripts.OnClick or nil
      onClick = Assert.NotNil(onClick, "lock button should define OnClick")
      onClick(mainUI.lockButton, "LeftButton")

      Assert.False(mainUI.GetDragLocked(), "first click should unlock the frame")
      Assert.False(mainUI.lockButton._isLocked, "lock button should reflect the unlocked state")

      onClick(mainUI.lockButton, "LeftButton")
      Assert.True(mainUI.GetDragLocked(), "second click should lock the frame again")
      Assert.True(mainUI.lockButton._isLocked, "lock button should reflect the relocked state")
    end)
  end)

  test("UI main frame reset position recenters the frame", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      UIParent = {},
      IsiLiveDB = {},
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
        isDragLocked = function()
          return false
        end,
      })

      Assert.NotNil(mainUI.ResetPosition, "main UI should expose a reset-position helper")
      mainUI.frame:ClearAllPoints()
      mainUI.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -80)

      mainUI.ResetPosition()

      local pos = IsiLiveDB.position
      pos = Assert.NotNil(pos, "reset position should persist a saved position")
      Assert.Equal(pos.point, "CENTER", "reset position should center the frame")
      Assert.Equal(pos.relativePoint, "CENTER", "reset position should anchor to the center")
      Assert.Equal(pos.x, 0, "reset position should clear horizontal offset")
      Assert.Equal(pos.y, 0, "reset position should clear vertical offset")
    end)
  end)
end

return function(test, ctx)
  local Assert = RequireValue(ctx.assert, "UI scenario ctx.assert should exist")
  local WithGlobals = RequireValue(ctx.with_globals, "UI scenario ctx.with_globals should exist")
  local LoadAddonModules = RequireValue(ctx.load_modules, "UI scenario ctx.load_modules should exist")

  RegisterMainFrameCombatVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterFrameBridgeVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterMainFrameInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterGameMenuMicroButtonTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterMainFrameLockTests(test, Assert, WithGlobals, LoadAddonModules)
end
