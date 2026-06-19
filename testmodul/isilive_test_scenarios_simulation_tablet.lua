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

local function MakeFrameStub()
  local frame = { _shown = false, _scripts = {}, _children = {}, _clampCalls = 0 }
  function frame:SetSize(w, h)
    self._size = { w, h }
  end
  function frame:SetPoint(...)
    self._point = { ... }
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
  function frame:SetScript(script, fn)
    self._scripts[script] = fn
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
    Assert.Equal(controller.buttons[1].label:GetText(), "A0", "first button must render its code")
    Assert.Equal(controller.buttons[2].label:GetText(), "A1", "second button must render its code")
    Assert.True(controller.buttons[1].statusDot._color[1] > 0.9, "red status dot must use red channel")
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
    Assert.Equal(controller.buttons[50].label:GetText(), "A50", "last large-grid action must still render")
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
end
