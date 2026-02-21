return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function BuildCreateFrameStub()
    local function CreateFrameStub(_frameType, _name, _parent, _template)
      local frame = {
        _scripts = {},
        _shown = true,
        _point = { "CENTER", nil, "CENTER", 0, 0 },
        _frameStrata = "MEDIUM",
        _frameLevel = 1,
      }

      frame.SetSize = function() end
      frame.SetHeight = function() end
      frame.SetPoint = function(self, point, relativeTo, relativePoint, x, y)
        self._point = { point, relativeTo, relativePoint, x or 0, y or 0 }
      end
      frame.GetPoint = function(self)
        local p = self._point
        return p[1], p[2], p[3], p[4], p[5]
      end
      frame.ClearAllPoints = function(self)
        self._point = nil
      end
      frame.SetMovable = function() end
      frame.EnableMouse = function() end
      frame.RegisterForDrag = function() end
      frame.SetScript = function(self, name, handler)
        self._scripts[name] = handler
      end
      frame.Show = function(self)
        self._shown = true
      end
      frame.Hide = function(self)
        self._shown = false
      end
      frame.IsShown = function(self)
        return self._shown == true
      end
      frame.StartMoving = function() end
      frame.StopMovingOrSizing = function() end
      frame.SetAlpha = function() end
      frame.SetFrameStrata = function(self, value)
        self._frameStrata = value
      end
      frame.GetFrameStrata = function(self)
        return self._frameStrata
      end
      frame.SetFrameLevel = function(self, value)
        self._frameLevel = value
      end
      frame.GetFrameLevel = function(self)
        return self._frameLevel
      end

      return frame
    end

    return CreateFrameStub
  end

  test("UI toggle allows closing frame during combat", function()
    local inCombat = false
    local shownInGroupCalls = 0

    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui.lua" })
      local mainUI = addon.UI.CreateMainFrame({
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

      Assert.False(mainUI.frame:IsShown(), "combat toggle must be able to close an open frame")
      Assert.Nil(mainUI.GetPendingVisible(), "combat close must not leave pending visibility state")
      Assert.Equal(shownInGroupCalls, 0, "close path must not trigger show callbacks")
    end)
  end)

  test("UI toggle blocks opening frame during combat and does not queue delayed open", function()
    local inCombat = true
    local shownInGroupCalls = 0
    local shownNoGroupCalls = 0

    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui.lua" })
      local mainUI = addon.UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
        onShownInGroup = function()
          shownInGroupCalls = shownInGroupCalls + 1
        end,
        onShownNoGroup = function()
          shownNoGroupCalls = shownNoGroupCalls + 1
        end,
      })

      Assert.False(mainUI.frame:IsShown(), "frame should start hidden")
      mainUI.ToggleVisibility(true)

      Assert.False(mainUI.frame:IsShown(), "combat toggle must not open hidden frame")
      Assert.Nil(mainUI.GetPendingVisible(), "combat hotkey-open must not queue delayed open")
      Assert.Equal(shownInGroupCalls, 0, "blocked combat open must not trigger in-group callback")
      Assert.Equal(shownNoGroupCalls, 0, "blocked combat open must not trigger no-group callback")
    end)
  end)

  test("UI direct SetVisible(true) in combat still queues pending open for non-hotkey flows", function()
    local inCombat = true

    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui.lua" })
      local mainUI = addon.UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
      })

      mainUI.SetVisible(true)

      Assert.False(mainUI.frame:IsShown(), "direct SetVisible should not open during combat")
      Assert.Equal(mainUI.GetPendingVisible(), true, "direct SetVisible should preserve pending open semantics")
    end)
  end)
end
