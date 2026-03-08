local function CreateTextureStub()
  return {
    SetAllPoints = function() end,
    SetColorTexture = function() end,
    SetTexture = function() end,
    SetTexCoord = function() end,
    SetBlendMode = function() end,
    SetVertexColor = function() end,
    Hide = function() end,
    Show = function() end,
  }
end

local function CreateFontStringStub()
  local fontSize = 14
  return {
    SetPoint = function() end,
    SetJustifyH = function() end,
    SetJustifyV = function() end,
    SetWordWrap = function() end,
    SetNonSpaceWrap = function() end,
    SetTextColor = function() end,
    SetText = function() end,
    SetWidth = function() end,
    GetStringHeight = function()
      return 20
    end,
    GetFont = function()
      return "Fonts\\FRIZQT__.TTF", fontSize, ""
    end,
    SetFont = function(_self, _path, size, _flags)
      fontSize = tonumber(size) or fontSize
    end,
    Hide = function() end,
    Show = function() end,
  }
end

local function CreateAnimationGroupStub()
  local group = {
    _playing = false,
  }
  group.SetLooping = function(_self, _mode) end
  group.CreateAnimation = function(_self, _kind)
    return {
      SetScale = function(_anim, _x, _y) end,
      SetDuration = function(_anim, _duration) end,
      SetSmoothing = function(_anim, _value) end,
      SetOrder = function(_anim, _value) end,
      SetFromAlpha = function(_anim, _value) end,
      SetToAlpha = function(_anim, _value) end,
      SetTarget = function(_anim, _target) end,
    }
  end
  group.IsPlaying = function(self)
    return self._playing == true
  end
  group.Play = function(self)
    self._playing = true
  end
  group.Stop = function(self)
    self._playing = false
  end
  return group
end

local function ApplyFrameMethods(frame)
  frame.SetSize = function(self, width, height)
    self._width = tonumber(width) or self._width
    self._height = tonumber(height) or self._height
  end
  frame.SetHeight = function(self, height)
    self._height = tonumber(height) or self._height
  end
  frame.GetWidth = function(self)
    return self._width
  end
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
    if self._simulateProtectedFrames and self._isProtected and self._isInCombat() then
      error("ADDON_ACTION_BLOCKED: protected frame show blocked in combat")
    end
    self._shown = true
  end
  frame.Hide = function(self)
    self._shown = false
  end
  frame.IsShown = function(self)
    return self._shown == true
  end
  frame.StartMoving = function(self)
    self._startMovingCalls = (self._startMovingCalls or 0) + 1
  end
  frame.StopMovingOrSizing = function(self)
    self._stopMovingCalls = (self._stopMovingCalls or 0) + 1
  end
  frame.SetAlpha = function() end
  frame.CreateTexture = function()
    return CreateTextureStub()
  end
  frame.CreateFontString = function()
    return CreateFontStringStub()
  end
  frame.RegisterForClicks = function() end
  frame.SetAttribute = function(self, key, value)
    self._attrs[key] = value
  end
  frame.GetAttribute = function(self, key)
    return self._attrs[key]
  end
  frame.Enable = function() end
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
  frame.SetAllPoints = function(_self) end
  frame.SetDrawEdge = function(_self, _value) end
  frame.SetScale = function(self, value)
    self._scale = value
  end
  frame.CreateAnimationGroup = function(_self)
    return CreateAnimationGroupStub()
  end
end

local function BuildCreateFrameStub(opts)
  opts = opts or {}
  local createdFrames = {}
  local simulateProtectedFrames = opts.simulateProtectedFrames == true
  local isInCombat = opts.isInCombat or function()
    return false
  end

  local function MarkParentChainProtected(parent)
    local current = parent
    while current do
      current._isProtected = true
      current = current._parent
    end
  end

  local function CreateFrameStub(frameType, _name, parent, template)
    local frame = {
      _frameType = frameType,
      _scripts = {},
      _shown = true,
      _point = { "CENTER", nil, "CENTER", 0, 0 },
      _frameStrata = "MEDIUM",
      _frameLevel = 1,
      _width = 680,
      _height = 212,
      _attrs = {},
      _startMovingCalls = 0,
      _stopMovingCalls = 0,
      _parent = parent,
      _template = template,
      _simulateProtectedFrames = simulateProtectedFrames,
      _isInCombat = isInCombat,
      _isProtected = false,
    }

    if simulateProtectedFrames and template == "SecureActionButtonTemplate" then
      frame._isProtected = true
      MarkParentChainProtected(parent)
    end

    ApplyFrameMethods(frame)
    table.insert(createdFrames, frame)
    return frame
  end

  return CreateFrameStub, createdFrames
end

local function RegisterMainFrameVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UI toggle allows closing frame during combat", function()
    local inCombat = false
    local shownInGroupCalls = 0

    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
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
      Assert.Equal(shownInGroupCalls, 0, "close path must not trigger show callbacks")
    end)
  end)

  test("UI toggle opens frame during combat without pending delay", function()
    local inCombat = true
    local shownInGroupCalls = 0
    local shownNoGroupCalls = 0
    local createFrameStub, createdFrames = BuildCreateFrameStub({
      simulateProtectedFrames = true,
      isInCombat = function()
        return inCombat
      end,
    })

    WithGlobals({
      UIParent = {},
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua", "isiLive_teleport_ui.lua" })
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
      local teleportController = addon.TeleportUI.CreateController({
        mainFrame = mainUI.frame,
        applySecureSpellToButton = function(_button, _spellID)
          return true
        end,
        getEntries = function()
          return {
            { spellID = 445414, mapID = 2662, mapName = "The Dawnbreaker" },
          }
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function(_spellID)
          return true
        end,
        getTeleportCooldownRemaining = function(_spellID)
          return 0
        end,
        formatCooldownSeconds = function(sec)
          return tostring(sec or 0)
        end,
        getSpellCooldownSafe = function(_spellID)
          return 0, 0, true
        end,
        applyCooldownFrameSafe = function(_frame, _start, _duration, _enabled) end,
        getSpellTexture = function(_spellID)
          return nil
        end,
        isInCombat = function()
          return inCombat
        end,
      })
      teleportController.BuildButtons()

      local hasSecureChildOnMainFrame = false
      for _, frame in ipairs(createdFrames) do
        if frame._parent == mainUI.frame and frame._template == "SecureActionButtonTemplate" then
          hasSecureChildOnMainFrame = true
          break
        end
      end
      Assert.False(
        hasSecureChildOnMainFrame,
        "combat-toggleable main frame must not receive secure-action child buttons"
      )

      Assert.False(mainUI.frame:IsShown(), "frame should start hidden")
      mainUI.ToggleVisibility(true)

      Assert.True(mainUI.frame:IsShown(), "combat toggle must open hidden frame immediately")
      Assert.Equal(shownInGroupCalls, 1, "combat hotkey-open should trigger in-group callback")
      Assert.Equal(shownNoGroupCalls, 0, "in-group combat open must not trigger no-group callback")
    end)
  end)

  test("UI direct SetVisible(true) in combat opens immediately without pending delay", function()
    local inCombat = true

    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local mainUI = addon.UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
      })

      mainUI.SetVisible(true)

      Assert.True(mainUI.frame:IsShown(), "direct SetVisible should open during combat")
    end)
  end)
end

local function RegisterMainFrameInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UI drag start/stop remains available during combat", function()
    local inCombat = true

    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
      IsiLiveDB = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local mainUI = addon.UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
      })

      local onDragStart = mainUI.frame._scripts and mainUI.frame._scripts.OnDragStart or nil
      local onDragStop = mainUI.frame._scripts and mainUI.frame._scripts.OnDragStop or nil
      Assert.NotNil(onDragStart, "main frame should define OnDragStart handler")
      Assert.NotNil(onDragStop, "main frame should define OnDragStop handler")

      onDragStart(mainUI.frame)
      onDragStop(mainUI.frame)

      Assert.Equal(mainUI.frame._startMovingCalls, 1, "combat drag start should still call StartMoving")
      Assert.Equal(mainUI.frame._stopMovingCalls, 1, "combat drag stop should still call StopMovingOrSizing")
      Assert.NotNil(IsiLiveDB.position, "drag stop should persist main-frame position")
    end)
  end)

  test("UI close button hides frame directly", function()
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local mainUI = addon.UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
      })

      mainUI.SetVisible(true)
      Assert.True(mainUI.frame:IsShown(), "frame should be visible before close button click")
      Assert.NotNil(mainUI.closeButton, "main UI should expose close button")

      local onClick = mainUI.closeButton._scripts and mainUI.closeButton._scripts.OnClick or nil
      Assert.NotNil(onClick, "close button should define OnClick handler")
      onClick(mainUI.closeButton, "LeftButton")

      Assert.False(mainUI.frame:IsShown(), "close button should hide frame")
    end)
  end)
end

local function RegisterCenterNoticeVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Center notice close button hides center notice directly", function()
    local now = 0

    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
      GetTime = function()
        return now
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local centerNotice = addon.Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
      })

      centerNotice.Show("Test notice", 20, nil, nil, {})
      Assert.True(centerNotice.frame:IsShown(), "center notice should be visible before close button click")
      Assert.NotNil(centerNotice.closeButton, "center notice should expose close button")

      local onClick = centerNotice.closeButton._scripts and centerNotice.closeButton._scripts.OnClick or nil
      Assert.NotNil(onClick, "center notice close button should define OnClick handler")
      onClick(centerNotice.closeButton, "LeftButton")

      Assert.False(centerNotice.frame:IsShown(), "center notice close button should hide notice frame")
    end)
  end)

  test("Center notice close button also closes during combat", function()
    local now = 0
    local inCombat = false

    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
      GetTime = function()
        return now
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local centerNotice = addon.Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
      })

      centerNotice.Show("Combat close test", 20, nil, nil, {})
      Assert.True(centerNotice.frame:IsShown(), "center notice should be visible before combat close test")

      inCombat = true
      local onClick = centerNotice.closeButton._scripts and centerNotice.closeButton._scripts.OnClick or nil
      Assert.NotNil(onClick, "center notice close button should define OnClick handler")
      onClick(centerNotice.closeButton, "LeftButton")

      Assert.False(centerNotice.frame:IsShown(), "center notice close in combat should hide notice frame immediately")
    end)
  end)

  test("Center notice can open during combat without pending delay", function()
    local now = 0
    local inCombat = true
    local createFrameStub = BuildCreateFrameStub({
      simulateProtectedFrames = true,
      isInCombat = function()
        return inCombat
      end,
    })

    WithGlobals({
      UIParent = {},
      CreateFrame = createFrameStub,
      GetTime = function()
        return now
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local centerNotice = addon.Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
      })

      centerNotice.Show("Combat open test", 20, nil, nil, {})

      Assert.True(centerNotice.frame:IsShown(), "center notice should open during combat")
    end)
  end)

  test("Center notice font scale does not grow across repeated notices", function()
    local now = 0

    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
      GetTime = function()
        return now
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local centerNotice = addon.Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
      })

      local _, baseSize = centerNotice.text:GetFont()
      centerNotice.Show("Scaled notice 1", 20, nil, nil, { fontScale = 1.35 })
      local _, firstScaledSize = centerNotice.text:GetFont()
      centerNotice.Show("Scaled notice 2", 20, nil, nil, { fontScale = 1.35 })
      local _, secondScaledSize = centerNotice.text:GetFont()
      centerNotice.Show("Default notice", 20, nil, nil, {})
      local _, resetSize = centerNotice.text:GetFont()

      Assert.Equal(baseSize, 14, "font stub baseline should remain stable for regression test")
      Assert.Equal(firstScaledSize, 18, "first scaled notice should apply configured font scale once")
      Assert.Equal(secondScaledSize, 18, "repeated scaled notice must not compound font size")
      Assert.Equal(resetSize, 14, "default notice should reset font size back to baseline")
    end)
  end)

  test("Center notice teleport button uses isolated top-anchored tooltip", function()
    local now = 0
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local sharedTooltipCalls = 0

    WithGlobals({
      UIParent = {},
      CreateFrame = createFrameStub,
      GetTime = function()
        return now
      end,
      GameTooltip = {
        SetOwner = function()
          sharedTooltipCalls = sharedTooltipCalls + 1
        end,
        SetText = function()
          sharedTooltipCalls = sharedTooltipCalls + 1
        end,
        AddLine = function()
          sharedTooltipCalls = sharedTooltipCalls + 1
        end,
        SetSpellByID = function()
          sharedTooltipCalls = sharedTooltipCalls + 1
        end,
        Show = function()
          sharedTooltipCalls = sharedTooltipCalls + 1
        end,
        Hide = function()
          sharedTooltipCalls = sharedTooltipCalls + 1
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local centerNotice = addon.Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
        resolveTeleportSpellID = function()
          return 12345
        end,
        applySecureSpellToButton = function() end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getL = function()
          return {
            TOOLTIP_TELEPORT_CAST = "Cast",
          }
        end,
      })

      centerNotice.ConfigureTeleportButton("Test Dungeon", 999)
      local onEnter = centerNotice.teleportButton._scripts and centerNotice.teleportButton._scripts.OnEnter or nil
      Assert.NotNil(onEnter, "center notice teleport button should define tooltip OnEnter")
      onEnter(centerNotice.teleportButton)

      local privateTooltip = nil
      for _, frame in ipairs(createdFrames) do
        if frame._isIsiLiveTooltip == true then
          privateTooltip = frame
          break
        end
      end

      Assert.NotNil(privateTooltip, "center notice should allocate a private tooltip frame")
      Assert.Equal(privateTooltip._isiLiveTooltipAnchor, "ANCHOR_TOP", "center notice tooltip must stay top-anchored")
      Assert.Equal(sharedTooltipCalls, 0, "center notice tooltip should not use the shared Blizzard GameTooltip")
    end)
  end)
end

local function RegisterCenterNoticeDragResetTest(test, Assert, WithGlobals, LoadAddonModules)
  test("Center notice drag stays non-persistent and resets to center on next open", function()
    local now = 0

    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
      IsiLiveDB = {},
      GetTime = function()
        return now
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local centerNotice = addon.Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return true
        end,
      })

      local onDragStart = centerNotice.frame._scripts and centerNotice.frame._scripts.OnDragStart or nil
      local onDragStop = centerNotice.frame._scripts and centerNotice.frame._scripts.OnDragStop or nil
      Assert.NotNil(onDragStart, "center notice should define an OnDragStart handler")
      Assert.NotNil(onDragStop, "center notice should define an OnDragStop handler")

      centerNotice.Show("Drag test", 20, nil, nil, {})
      centerNotice.frame:SetPoint("CENTER", UIParent, "CENTER", 12, -34)
      onDragStart(centerNotice.frame)
      onDragStop(centerNotice.frame)

      Assert.Equal(centerNotice.frame._startMovingCalls, 1, "center notice drag start should call StartMoving")
      Assert.Equal(centerNotice.frame._stopMovingCalls, 1, "center notice drag stop should call StopMovingOrSizing")
      Assert.Nil(IsiLiveDB.centerNoticePosition, "center notice drag must not persist position in DB")

      centerNotice.SetVisible(false)
      centerNotice.Show("Reopen test", 20, nil, nil, {})

      local point, _, relativePoint, x, y = centerNotice.frame:GetPoint()
      Assert.Equal(point, "CENTER", "reopened center notice should use CENTER point")
      Assert.Equal(relativePoint, "CENTER", "reopened center notice should use CENTER relativePoint")
      Assert.Equal(x, 0, "reopened center notice should reset x offset")
      Assert.Equal(y, 0, "reopened center notice should reset y offset")
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterMainFrameVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterMainFrameInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCenterNoticeVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCenterNoticeDragResetTest(test, Assert, WithGlobals, LoadAddonModules)
end
