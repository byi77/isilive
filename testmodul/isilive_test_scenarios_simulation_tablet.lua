---@diagnostic disable: undefined-global

local function MakeFontStringStub()
  local fs = { _text = "" }
  function fs:SetText(text)
    self._text = tostring(text or "")
  end
  function fs:GetText()
    return self._text
  end
  function fs:SetPoint() end
  function fs:SetJustifyH() end
  function fs:SetWidth() end
  function fs:SetTextColor() end
  function fs:Show() end
  function fs:Hide() end
  return fs
end

local function MakeTextureStub()
  local texture = {}
  function texture:SetSize(w, h)
    self._size = { w, h }
  end
  function texture:SetPoint(...)
    self._point = { ... }
  end
  function texture:SetColorTexture(r, g, b, a)
    self._color = { r, g, b, a }
  end
  function texture:Show() end
  function texture:Hide() end
  return texture
end

local function MakeFrameStub(bounds)
  local frame = { _shown = false, _scripts = {}, _hooks = {}, _children = {}, _clampCalls = 0, _bounds = bounds }
  function frame:SetSize(w, h)
    self._size = { w, h }
  end
  function frame:GetWidth()
    return self._size and self._size[1] or (self._bounds and (self._bounds.right - self._bounds.left))
  end
  function frame:GetHeight()
    return self._size and self._size[2] or (self._bounds and (self._bounds.top - self._bounds.bottom))
  end
  function frame:GetLeft()
    return self._bounds and self._bounds.left
  end
  function frame:GetRight()
    return self._bounds and self._bounds.right
  end
  function frame:GetTop()
    return self._bounds and self._bounds.top
  end
  function frame:GetBottom()
    return self._bounds and self._bounds.bottom
  end
  function frame:GetEffectiveScale()
    return (self._bounds and self._bounds.scale) or 1
  end
  function frame:SetPoint(...)
    self._point = { ... }
  end
  function frame:ClearAllPoints()
    self._point = nil
  end
  function frame:SetFrameStrata(strata)
    self._strata = strata
  end
  function frame:SetFrameLevel(level)
    self._level = level
  end
  function frame:SetMovable(movable)
    self._movable = movable
  end
  function frame:EnableMouse(enabled)
    self._mouse = enabled
  end
  function frame:RegisterForDrag(button)
    self._dragButton = button
  end
  function frame:SetClampedToScreen(clamped)
    self._clamped = clamped
    self._clampCalls = self._clampCalls + 1
  end
  function frame:SetClampRectInsets() end
  function frame:SetBackdrop(backdrop)
    self._backdrop = backdrop
  end
  function frame:SetBackdropColor(r, g, b, a)
    self._backdropColor = { r, g, b, a }
  end
  function frame:SetAlpha(alpha)
    self._alpha = alpha
  end
  function frame:Enable()
    self._enabled = true
  end
  function frame:Disable()
    self._enabled = false
  end
  function frame:SetScript(script, fn)
    self._scripts[script] = fn
  end
  function frame:HookScript(script, fn)
    self._hooks[script] = fn
  end
  function frame:CreateFontString()
    local fs = MakeFontStringStub()
    table.insert(self._children, fs)
    return fs
  end
  function frame:CreateTexture()
    local texture = MakeTextureStub()
    table.insert(self._children, texture)
    return texture
  end
  function frame:Show()
    self._shown = true
  end
  function frame:Hide()
    self._shown = false
  end
  function frame:IsShown()
    return self._shown == true
  end
  function frame:StartMoving()
    self._moving = true
  end
  function frame:StopMovingOrSizing()
    self._moving = false
  end
  return frame
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Simulation tablet renders actions and runs only executable buttons", function()
    local createdFrames = {}
    local actionRuns = 0
    local controller = nil

    WithGlobals({
      UIParent = MakeFrameStub(),
      CreateFrame = function(_frameType, _name, _parent, _template)
        local frame = MakeFrameStub()
        table.insert(createdFrames, frame)
        return frame
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_simulation_tablet.lua" }, {
        UICommon = {
          ApplyBackdrop = function(frame)
            frame._backdropApplied = true
            return true
          end,
          CreateRedCloseButton = function(parent, _opts)
            local button = MakeFrameStub()
            button._parent = parent
            return button
          end,
        },
      })
      controller = addon.SimulationTablet.CreateController({
        getL = function()
          return {
            SIM_TABLET_TITLE = "Demo simulator",
            SIM_TABLET_READY = "Ready",
            SIM_ACTION_BLOCKED = "Blocked",
          }
        end,
      })
      controller.SetActions({
        { id = "A0", status = "red", title = "Blocked", description = "No-op" },
        {
          id = "A1",
          status = "green",
          title = "Run",
          description = "Runs",
          run = function()
            actionRuns = actionRuns + 1
            return "done"
          end,
        },
      })
    end)

    Assert.True(controller ~= nil, "controller must be created")
    Assert.True(controller.frame._shown == false, "tablet must start hidden")
    Assert.True(controller.frame._clamped == true, "tablet frame must be clamped to screen")
    controller.Show()
    Assert.True(controller.frame._shown == true, "show must reveal tablet")
    Assert.Equal(controller.buttons[1].codeLabel:GetText(), "A0", "first button must retain its compact code")
    Assert.Equal(controller.buttons[1].label:GetText(), "Blocked", "first button must render its readable title")
    Assert.Equal(controller.buttons[2].codeLabel:GetText(), "A1", "second button must retain its compact code")
    Assert.Equal(controller.buttons[2].label:GetText(), "Run", "second button must render its readable title")
    Assert.True(controller.buttons[1].statusBar._color[1] > 0.9, "red status bar must use red channel")
    Assert.Equal(controller.buttons[1].statusLabel:GetText(), "BLOCKED", "blocked state must also be textual")
    controller.buttons[1]._scripts.OnClick(controller.buttons[1])
    Assert.Equal(actionRuns, 0, "blocked button must not run an action")
    controller.buttons[2]._scripts.OnClick(controller.buttons[2])
    Assert.Equal(actionRuns, 1, "executable button must run its action")
    Assert.True(#createdFrames >= 3, "tablet and buttons must be created")
  end)

  test("Simulation tablet toggles, hides stale buttons, and handles tooltip paths", function()
    local tooltipLines = {}
    local controller = nil

    WithGlobals({
      UIParent = MakeFrameStub(),
      GameTooltip = {
        SetOwner = function() end,
        AddLine = function(_, text)
          table.insert(tooltipLines, text)
        end,
        Show = function() end,
        Hide = function() end,
      },
      CreateFrame = function()
        return MakeFrameStub()
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_simulation_tablet.lua" }, {
        UICommon = {
          ApplyBackdrop = function()
            return true
          end,
        },
      })
      controller = addon.SimulationTablet.CreateController({
        getL = function()
          return {
            SIM_TABLET_TITLE = "Demo simulator",
            SIM_TABLET_READY = "Ready",
            SIM_STATUS_GREEN = "Green",
            SIM_ACTION_BLOCKED = "Blocked",
            SIM_ACTION_FAILED = "Failed",
          }
        end,
      })
      controller.SetActions({
        { id = "A1", status = "green", title = "Tooltip title", description = "Tooltip body" },
        { id = "A2", status = "yellow", title = "Second", description = "Second body" },
      })
      controller.SetActions({ { id = "B1", status = "green", title = "Reduced", description = "Reduced body" } })
    end)

    Assert.True(controller ~= nil, "controller must be created without UICommon close button")
    Assert.True(controller.buttons[2]._shown == false, "stale buttons must be hidden after action shrink")
    controller.Toggle()
    Assert.True(controller.IsShown(), "toggle must show a hidden tablet")
    local previousTooltip = rawget(_G, "GameTooltip")
    _G.GameTooltip = {
      SetOwner = function() end,
      AddLine = function(_, text)
        table.insert(tooltipLines, text)
      end,
      Show = function() end,
      Hide = function() end,
    }
    controller.buttons[1]._scripts.OnEnter(controller.buttons[1])
    _G.GameTooltip = previousTooltip
    Assert.Equal(tooltipLines[1], "Reduced", "tooltip must render action title")
    controller.buttons[1]._scripts.OnLeave(controller.buttons[1])
    controller.Toggle()
    Assert.False(controller.IsShown(), "toggle must hide a visible tablet")
    controller.SetActions(nil)
    Assert.Equal(#controller.actions, 0, "invalid action table must clear actions")
  end)

  test("Simulation tablet hover uses private tooltip without mutating buttons", function()
    local controller = nil
    local preparedTooltip = nil
    local hiddenTooltip = nil
    local tooltipLines = {}

    WithGlobals({
      UIParent = MakeFrameStub(),
      CreateFrame = function()
        return MakeFrameStub()
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_simulation_tablet.lua" }, {
        UICommon = {
          ApplyBackdrop = function()
            return true
          end,
          CreatePrivateTooltip = function(parent)
            local tooltip = MakeFrameStub()
            tooltip._parent = parent
            function tooltip:SetOwner(owner, anchor)
              self._owner = owner
              self._anchor = anchor
            end
            function tooltip:ClearLines()
              tooltipLines = {}
            end
            function tooltip:AddLine(text)
              table.insert(tooltipLines, text)
            end
            return tooltip
          end,
          PreparePrivateTooltip = function(tooltip, owner, anchor)
            preparedTooltip = tooltip
            tooltip:SetOwner(owner, anchor)
            return tooltip
          end,
          HidePrivateTooltip = function(tooltip)
            hiddenTooltip = tooltip
            tooltip:Hide()
          end,
        },
      })
      controller = addon.SimulationTablet.CreateController({
        getL = function()
          return {
            SIM_TABLET_TITLE = "Demo simulator",
            SIM_TABLET_READY = "Ready",
            SIM_STATUS_GREEN = "Green",
          }
        end,
      })
      controller.SetActions({ { id = "A1", status = "green", title = "Hover", description = "Body" } })
    end)

    local button = controller.buttons[1]
    local originalSize = button._size
    button._scripts.OnEnter(button)
    Assert.True(preparedTooltip == controller.tooltipFrame, "hover must prepare the dedicated tablet tooltip")
    Assert.True(button._isiLiveTooltipReady ~= true, "hover must not turn the button into a tooltip")
    Assert.Equal(button._size[1], originalSize[1], "hover must not resize the button width")
    Assert.Equal(button._size[2], originalSize[2], "hover must not resize the button height")
    Assert.Equal(tooltipLines[1], "Hover", "private tooltip must receive the action title")
    button._scripts.OnLeave(button)
    Assert.True(hiddenTooltip == controller.tooltipFrame, "leave must hide the dedicated tablet tooltip")
  end)

  test("Simulation tablet expands frame height for larger action grids", function()
    local controller = nil

    WithGlobals({
      UIParent = MakeFrameStub(),
      CreateFrame = function()
        return MakeFrameStub()
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_simulation_tablet.lua" }, {
        UICommon = {
          ApplyBackdrop = function()
            return true
          end,
        },
      })
      controller = addon.SimulationTablet.CreateController({
        getL = function()
          return {
            SIM_TABLET_TITLE = "Demo simulator",
            SIM_TABLET_READY = "Ready",
          }
        end,
      })
      local actions = {}
      for index = 1, 50 do
        actions[index] = { id = "A" .. tostring(index), status = "green", title = "Action", description = "Preview" }
      end
      controller.SetActions(actions)
    end)

    Assert.True(controller.frame._size[2] > 360, "tablet height must grow when the action grid exceeds baseline")
    Assert.Equal(controller.buttons[50].codeLabel:GetText(), "A50", "last large-grid action must retain its code")
    Assert.Equal(controller.buttons[50].label:GetText(), "Action", "last large-grid action must render its title")
  end)

  test("Simulation tablet reapplies screen clamp after dynamic height changes", function()
    local controller = nil

    WithGlobals({
      UIParent = MakeFrameStub(),
      CreateFrame = function()
        return MakeFrameStub()
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_simulation_tablet.lua" }, {
        UICommon = {
          ApplyBackdrop = function()
            return true
          end,
        },
      })
      controller = addon.SimulationTablet.CreateController({
        getL = function()
          return {
            SIM_TABLET_TITLE = "Demo simulator",
            SIM_TABLET_READY = "Ready",
          }
        end,
      })
      local initialClampCalls = controller.frame._clampCalls
      local actions = {}
      for index = 1, 50 do
        actions[index] = { id = "A" .. tostring(index), status = "green", title = "Action", description = "Preview" }
      end
      controller.SetActions(actions)

      Assert.True(
        controller.frame._clampCalls > initialClampCalls,
        "tablet must reapply screen clamping after the dynamic height update"
      )
      Assert.True(controller.frame._clamped == true, "tablet must remain clamped after resizing")
    end)
  end)

  test("Simulation tablet docks beside the live main frame with resolution-aware fallbacks", function()
    local screen = MakeFrameStub({ left = 0, right = 1920, top = 1080, bottom = 0, scale = 1 })
    local centeredMain = MakeFrameStub({ left = 420, right = 920, top = 850, bottom = 560, scale = 1 })
    local rightEdgeMain = MakeFrameStub({ left = 1320, right = 1820, top = 850, bottom = 560, scale = 1 })
    local lowMain = MakeFrameStub({ left = 420, right = 920, top = 200, bottom = 20, scale = 1 })
    local middleMain = MakeFrameStub({ left = 290, right = 710, top = 800, bottom = 450, scale = 1 })
    local upperMain = MakeFrameStub({ left = 290, right = 710, top = 450, bottom = 100, scale = 1 })
    local rightController = nil
    local leftController = nil
    local lowController = nil
    local belowController = nil
    local aboveController = nil
    local scaledController = nil

    WithGlobals({
      UIParent = screen,
      CreateFrame = function()
        return MakeFrameStub()
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_simulation_tablet.lua" }, {
        UICommon = {
          ApplyBackdrop = function()
            return true
          end,
        },
      })
      rightController = addon.SimulationTablet.CreateController({ anchorFrame = centeredMain })
      leftController = addon.SimulationTablet.CreateController({ anchorFrame = rightEdgeMain })
      lowController = addon.SimulationTablet.CreateController({ anchorFrame = lowMain })
      belowController = addon.SimulationTablet.CreateController({
        anchorFrame = middleMain,
        parent = MakeFrameStub({ left = 0, right = 1000, top = 1000, bottom = 0, scale = 1 }),
      })
      aboveController = addon.SimulationTablet.CreateController({
        anchorFrame = upperMain,
        parent = MakeFrameStub({ left = 0, right = 1000, top = 1000, bottom = 0, scale = 1 }),
      })
    end)

    WithGlobals({
      UIParent = MakeFrameStub({ left = 0, right = 1920, top = 1080, bottom = 0, scale = 0.75 }),
      CreateFrame = function(_frameType, name)
        if name == "isiLiveSimulationTablet" then
          return MakeFrameStub({ scale = 0.75 })
        end
        return MakeFrameStub()
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_simulation_tablet.lua" }, {
        UICommon = {
          ApplyBackdrop = function()
            return true
          end,
        },
      })
      scaledController = addon.SimulationTablet.CreateController({
        anchorFrame = MakeFrameStub({ left = 500, right = 900, top = 650, bottom = 450, scale = 1.5 }),
      })
    end)

    Assert.Equal(rightController.dockSide, "right", "tablet must prefer the visible right side")
    Assert.Equal(rightController.frame._point[1], "TOPLEFT", "right dock must use tablet top-left")
    Assert.True(rightController.frame._point[2] == centeredMain, "right dock must stay anchored to the live main frame")
    Assert.Equal(rightController.frame._point[3], "TOPRIGHT", "right dock must follow the main-frame right edge")
    Assert.Equal(rightController.frame._point[4], 12, "right dock must keep the explicit gap")
    Assert.Equal(leftController.dockSide, "left", "tablet must use the left side when right space is insufficient")
    Assert.Equal(leftController.frame._point[1], "TOPRIGHT", "left fallback must use tablet top-right")
    Assert.True(
      leftController.frame._point[2] == rightEdgeMain,
      "left fallback must stay anchored to the live main frame"
    )
    Assert.Equal(leftController.frame._point[3], "TOPLEFT", "left fallback must follow the main-frame left edge")
    Assert.Equal(lowController.dockSide, "right", "vertical fitting must preserve a valid right-side dock")
    Assert.Equal(lowController.frame._point[5], 126, "low main-frame docks must shift up to keep the tablet visible")
    Assert.Equal(belowController.dockSide, "below", "tablet must use the lower side after both horizontal sides fail")
    Assert.Equal(belowController.frame._point[1], "TOPLEFT", "lower fallback must use tablet top-left")
    Assert.Equal(belowController.frame._point[3], "BOTTOMLEFT", "lower fallback must follow the main-frame bottom")
    Assert.Equal(aboveController.dockSide, "above", "tablet must use the upper side when every earlier side fails")
    Assert.Equal(aboveController.frame._point[1], "BOTTOMLEFT", "upper fallback must use tablet bottom-left")
    Assert.Equal(aboveController.frame._point[3], "TOPLEFT", "upper fallback must follow the main-frame top")
    Assert.Equal(
      scaledController.dockSide,
      "left",
      "dock side selection must compare effective physical bounds across different UI scales"
    )
  end)

  test("Simulation tablet category tabs keep the control surface compact", function()
    local controller = nil

    WithGlobals({
      UIParent = MakeFrameStub(),
      CreateFrame = function()
        return MakeFrameStub()
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_simulation_tablet.lua" }, {
        UICommon = {
          ApplyBackdrop = function()
            return true
          end,
        },
      })
      controller = addon.SimulationTablet.CreateController({
        getL = function()
          return {
            SIM_CATEGORY_GROUP = "Group",
            SIM_CATEGORY_MPLUS = "M+",
          }
        end,
      })
      controller.SetActions({
        { id = "A1", category = "group", status = "green", title = "Invite" },
        { id = "C1", category = "mplus", status = "green", title = "Timer" },
      })
    end)

    Assert.Equal(controller.activeCategory, "mplus", "M+ must be the initial category when available")
    Assert.Equal(controller.buttons[1].label:GetText(), "Timer", "initial category must render only M+ actions")
    controller.tabButtons[1]._scripts.OnClick(controller.tabButtons[1])
    Assert.Equal(controller.activeCategory, "group", "group tab must switch the visible category")
    Assert.Equal(controller.buttons[1].label:GetText(), "Invite", "group tab must render group actions")
  end)

  test("Simulation tablet drag detaches and Dock restores the responsive anchor", function()
    local screen = MakeFrameStub({ left = 0, right = 1920, top = 1080, bottom = 0, scale = 1 })
    local mainFrame = MakeFrameStub({ left = 420, right = 920, top = 850, bottom = 560, scale = 1 })
    local controller = nil

    WithGlobals({
      UIParent = screen,
      CreateFrame = function()
        return MakeFrameStub()
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_simulation_tablet.lua" }, {
        UICommon = {
          ApplyBackdrop = function()
            return true
          end,
        },
      })
      controller = addon.SimulationTablet.CreateController({ anchorFrame = mainFrame })
    end)

    controller.frame._scripts.OnDragStart(controller.frame)
    Assert.False(controller.isDocked, "manual drag must detach the simulator")
    controller.frame._scripts.OnDragStop(controller.frame)
    Assert.False(controller.frame._moving, "drag stop must stop frame movement")
    Assert.Equal(controller.Dock(), "right", "Dock must restore the responsive right-side anchor")
    Assert.True(controller.isDocked, "Dock must mark the simulator as docked")
  end)

  test("Simulation tablet reflows dock after anchor and viewport changes", function()
    local screen = MakeFrameStub({ left = 0, right = 1920, top = 1080, bottom = 0, scale = 1 })
    local mainFrame = MakeFrameStub({ left = 420, right = 920, top = 850, bottom = 560, scale = 1 })
    local controller = nil

    WithGlobals({
      UIParent = screen,
      CreateFrame = function()
        return MakeFrameStub()
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_simulation_tablet.lua" }, {
        UICommon = {
          ApplyBackdrop = function()
            return true
          end,
        },
      })
      controller = addon.SimulationTablet.CreateController({ anchorFrame = mainFrame })
    end)

    controller.Show()
    Assert.Equal(controller.dockSide, "right", "visible tablet must begin on the available right side")

    mainFrame._bounds = { left = 1320, right = 1820, top = 850, bottom = 560, scale = 1 }
    mainFrame._hooks.OnSizeChanged(mainFrame)
    Assert.Equal(controller.dockSide, "left", "anchor size changes must recalculate the available dock side")

    mainFrame._bounds = { left = 300, right = 800, top = 800, bottom = 500, scale = 1 }
    screen._bounds = { left = 0, right = 1100, top = 1080, bottom = 0, scale = 1 }
    screen._hooks.OnSizeChanged(screen)
    Assert.Equal(controller.dockSide, "below", "viewport changes must recalculate the dock fallback")

    controller.frame._scripts.OnDragStart(controller.frame)
    mainFrame._bounds = { left = 100, right = 600, top = 850, bottom = 560, scale = 1 }
    mainFrame._hooks.OnDragStop(mainFrame)
    Assert.Equal(controller.dockSide, "below", "detached tablets must ignore later anchor movement")
  end)
end
