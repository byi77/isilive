local function CreateTextureStub()
  return {
    hidden = false,
    SetAllPoints = function() end,
    SetHeight = function() end,
    SetWidth = function() end,
    SetSize = function() end,
    SetPoint = function() end,
    SetColorTexture = function() end,
    SetTexture = function() end,
    SetTexCoord = function() end,
    SetBlendMode = function() end,
    SetVertexColor = function() end,
    Hide = function(self)
      self.hidden = true
    end,
    Show = function(self)
      self.hidden = false
    end,
  }
end

local function CreateFontStringStub(fontObject)
  local fontSize = 14
  return {
    _fontObject = fontObject,
    SetPoint = function(self, point, relativeTo, relativePoint, x, y)
      self._point = { point, relativeTo, relativePoint, x or 0, y or 0 }
    end,
    GetPoint = function(self)
      local p = self._point
      if not p then
        return nil
      end
      return p[1], p[2], p[3], p[4], p[5]
    end,
    SetJustifyH = function() end,
    SetJustifyV = function() end,
    SetWordWrap = function() end,
    SetNonSpaceWrap = function() end,
    SetTextColor = function(self, r, g, b, a)
      self._textColor = { r, g, b, a }
    end,
    GetTextColor = function(self)
      local color = self._textColor or { 1, 1, 1, 1 }
      return color[1], color[2], color[3], color[4]
    end,
    SetText = function(self, value)
      self._text = tostring(value or "")
    end,
    GetText = function(self)
      return self._text
    end,
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

---@generic T
---@param value T?
---@param message string
---@return T
local function RequireValue(value, message)
  if value == nil then
    error(message, 2)
  end
  return value
end

local function ApplyFrameMethods(frame)
  frame.SetSize = function(self, width, height)
    if self._simulateProtectedFrames and self._isProtected and self._isInCombat() then
      error("ADDON_ACTION_BLOCKED: protected frame size update blocked in combat")
    end
    self._width = tonumber(width) or self._width
    self._height = tonumber(height) or self._height
  end
  frame.SetHeight = function(self, height)
    self._height = tonumber(height) or self._height
  end
  frame.GetWidth = function(self)
    return self._width
  end
  frame.GetHeight = function(self)
    return self._height
  end
  frame.SetPoint = function(self, point, relativeTo, relativePoint, x, y)
    if self._simulateProtectedFrames and self._isProtected and self._isInCombat() then
      error("ADDON_ACTION_BLOCKED: protected frame point update blocked in combat")
    end
    self._point = { point, relativeTo, relativePoint, x or 0, y or 0 }
  end
  frame.GetPoint = function(self)
    local p = self._point
    return p[1], p[2], p[3], p[4], p[5]
  end
  frame.ClearAllPoints = function(self)
    if self._simulateProtectedFrames and self._isProtected and self._isInCombat() then
      error("ADDON_ACTION_BLOCKED: protected frame point clear blocked in combat")
    end
    self._point = nil
  end
  frame.SetMovable = function() end
  frame.EnableMouse = function(self, enabled)
    if self._simulateProtectedFrames and self._isProtected and self._isInCombat() then
      error("ADDON_ACTION_BLOCKED: protected frame mouse enable blocked in combat")
    end
    self._mouseEnabled = enabled == true
  end
  frame.RegisterForDrag = function() end
  frame.SetScript = function(self, name, handler)
    self._scripts[name] = handler
  end
  frame.RegisterEvent = function(self, event)
    self._events = self._events or {}
    self._events[event] = true
  end
  frame.UnregisterEvent = function(self, event)
    self._events = self._events or {}
    self._events[event] = nil
  end
  frame.IsEventRegistered = function(self, event)
    return self._events and self._events[event] == true or false
  end
  frame.FireEvent = function(self, event, ...)
    local handler = self._scripts and self._scripts.OnEvent or nil
    if type(handler) == "function" then
      handler(self, event, ...)
    end
  end
  frame.HookScript = function(self, name, handler)
    local previous = self._scripts[name]
    if type(previous) == "function" then
      self._scripts[name] = function(...)
        previous(...)
        handler(...)
      end
      return
    end
    self._scripts[name] = handler
  end
  frame.SetText = function(self, value)
    self._text = tostring(value or "")
  end
  frame.GetText = function(self)
    return self._text
  end
  frame.SetChecked = function(self, value)
    self._checked = value == true
  end
  frame.GetChecked = function(self)
    return self._checked == true
  end
  frame.Show = function(self)
    if self._simulateProtectedFrames and self._isProtected and self._isInCombat() then
      error("ADDON_ACTION_BLOCKED: protected frame show blocked in combat")
    end
    self._shown = true
  end
  frame.Hide = function(self)
    if self._simulateProtectedFrames and self._isProtected and self._isInCombat() then
      error("ADDON_ACTION_BLOCKED: protected frame hide blocked in combat")
    end
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
  frame.SetAlpha = function(self, value)
    if self._simulateProtectedFrames and self._isProtected and self._isInCombat() then
      error("ADDON_ACTION_BLOCKED: protected frame alpha update blocked in combat")
    end
    self._alpha = tonumber(value) or self._alpha
  end
  frame.GetAlpha = function(self)
    return self._alpha
  end
  frame.CreateTexture = function()
    return CreateTextureStub()
  end
  frame.CreateFontString = function(_self, _name, _layer, fontObject)
    return CreateFontStringStub(fontObject)
  end
  frame.RegisterForClicks = function(self, ...)
    self._registeredClicks = { ... }
  end
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
  frame.SetBackdrop = function(self, backdrop)
    self._backdrop = backdrop
  end
  frame.SetBackdropColor = function(self, r, g, b, a)
    self._backdropColor = { r, g, b, a }
  end
  frame.GetBackdropColor = function(self)
    if not self._backdropColor then
      return nil
    end
    return self._backdropColor[1], self._backdropColor[2], self._backdropColor[3], self._backdropColor[4]
  end
  frame.SetBackdropBorderColor = function(self, r, g, b, a)
    self._backdropBorderColor = { r, g, b, a }
  end
  frame.SetScrollChild = function(self, child)
    self._scrollChild = child
  end
  frame.GetScrollChild = function(self)
    return self._scrollChild
  end
  frame.SetVerticalScroll = function(self, value)
    self._verticalScroll = tonumber(value) or 0
  end
  frame.GetVerticalScroll = function(self)
    return self._verticalScroll or 0
  end
  frame.GetVerticalScrollRange = function(self)
    local child = self._scrollChild
    local childHeight = 0
    if child and type(child.GetHeight) == "function" then
      childHeight = tonumber(child:GetHeight()) or 0
    end
    local height = tonumber(self:GetHeight()) or 0
    local range = childHeight - height
    if range < 0 then
      range = 0
    end
    return range
  end
  frame.EnableMouseWheel = function(self, enabled)
    self._mouseWheelEnabled = enabled == true
  end
  frame.SetHorizontalScroll = function(self, value)
    self._horizontalScroll = tonumber(value) or 0
  end
  frame.GetHorizontalScroll = function(self)
    return self._horizontalScroll or 0
  end
  frame.SetOrientation = function(self, value)
    self._orientation = value
  end
  frame.SetMinMaxValues = function(self, minValue, maxValue)
    self._minValue = minValue
    self._maxValue = maxValue
  end
  frame.SetValueStep = function(self, value)
    self._valueStep = value
  end
  frame.SetObeyStepOnDrag = function(self, value)
    self._obeyStepOnDrag = value == true
  end
  frame.SetThumbTexture = function(self, value)
    self._thumbTexture = value
  end
  frame.SetValue = function(self, value)
    self._value = value
    local handler = self._scripts and self._scripts.OnValueChanged or nil
    if type(handler) == "function" then
      handler(self, value)
    end
  end
  frame.GetValue = function(self)
    return self._value
  end
  frame.CreateAnimationGroup = function(_self)
    return CreateAnimationGroupStub()
  end
  frame.SetAutoFocus = function(self, value)
    self._autoFocus = value == true
  end
  frame.SetCursorPosition = function() end
  frame.HighlightText = function() end
  frame.ClearFocus = function() end
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
      _alpha = 1,
      _attrs = {},
      _startMovingCalls = 0,
      _stopMovingCalls = 0,
      _parent = parent,
      _template = template,
      _simulateProtectedFrames = simulateProtectedFrames,
      _isInCombat = isInCombat,
      _isProtected = false,
    }

    if simulateProtectedFrames and type(parent) == "table" and parent._isProtected == true then
      frame._isProtected = true
    end

    if
      simulateProtectedFrames
      and type(template) == "string"
      and template:find("SecureActionButtonTemplate", 1, true) ~= nil
    then
      frame._isProtected = true
      MarkParentChainProtected(parent)
    end

    ApplyFrameMethods(frame)
    table.insert(createdFrames, frame)
    return frame
  end

  return CreateFrameStub, createdFrames
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
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local centerNotice = Notice.CreateCenterNotice({
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
      ---@diagnostic disable: need-check-nil
      onClick(centerNotice.closeButton, "LeftButton")
      ---@diagnostic enable: need-check-nil

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
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local centerNotice = Notice.CreateCenterNotice({
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
      ---@diagnostic disable: need-check-nil
      onClick(centerNotice.closeButton, "LeftButton")
      ---@diagnostic enable: need-check-nil

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
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local centerNotice = Notice.CreateCenterNotice({
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
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local centerNotice = Notice.CreateCenterNotice({
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

      Assert.Equal(baseSize, 24, "center notice should use the portal-navigator typography baseline")
      Assert.Equal(firstScaledSize, 32, "first scaled notice should apply configured font scale once")
      Assert.Equal(secondScaledSize, 32, "repeated scaled notice must not compound font size")
      Assert.Equal(resetSize, 24, "default notice should reset font size back to the portal baseline")
    end)
  end)

  test("Center notice uses portal navigator typography defaults", function()
    local now = 0

    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
      GetTime = function()
        return now
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local centerNotice = Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
      })

      centerNotice.Show("Typography test", 20, nil, nil, {})

      local _, fontSize = centerNotice.text:GetFont()
      Assert.Equal(
        centerNotice.text._fontObject,
        "GameFontNormal",
        "center notice body text must use the same font object as portal navigator entries"
      )
      Assert.Equal(fontSize, 24, "center notice body text should match the portal navigator font size")
      local r, g, b = centerNotice.text:GetTextColor()
      Assert.Equal(r, 1, "center notice should keep the portal navigator red channel")
      Assert.Equal(g, 0.92, "center notice should keep the portal navigator green channel")
      Assert.Equal(b, 0.7, "center notice should keep the portal navigator blue channel")
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
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local centerNotice = Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
        resolveTeleportSpellID = function()
          return 12345
        end,
        resolveMapIDBySpellID = function(spellID)
          if spellID == 12345 then
            return 558
          end
          return nil
        end,
        resolveMapIDByActivityID = function(activityID)
          if activityID == 999 then
            return 558
          end
          return nil
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
        getDungeonName = function(mapID, localeTag)
          if mapID == 558 and localeTag == "enUS" then
            return "Magisters' Terrace"
          end
          if mapID == 558 then
            return "Terrasse der Magister"
          end
          return nil
        end,
        getL = function()
          return {
            TOOLTIP_TELEPORT_CAST = "Cast",
            TOOLTIP_TELEPORT_READY = "Ready",
          }
        end,
      })

      centerNotice.ConfigureTeleportButton("Terrasse der Magister", 999)
      local onEnter = centerNotice.teleportButton._scripts and centerNotice.teleportButton._scripts.OnEnter or nil
      Assert.NotNil(onEnter, "center notice teleport button should define tooltip OnEnter")
      ---@diagnostic disable: need-check-nil
      onEnter(centerNotice.teleportButton)
      ---@diagnostic enable: need-check-nil

      local privateTooltip = nil
      for _, frame in ipairs(createdFrames) do
        if frame._isIsiLiveTooltip == true then
          privateTooltip = frame
          break
        end
      end

      Assert.NotNil(privateTooltip, "center notice should allocate a private tooltip frame")
      local privateTooltipFrame = RequireValue(privateTooltip, "center notice should allocate a private tooltip frame")
      Assert.Equal(
        rawget(privateTooltipFrame, "_isiLiveTooltipAnchor"),
        "ANCHOR_TOP",
        "center notice tooltip must stay top-anchored"
      )
      local lines = rawget(privateTooltipFrame, "_isiLiveTooltipLines") or {}
      Assert.Equal(
        lines[1] and lines[1]._text or nil,
        "Terrasse der Magister",
        "center notice tooltip title should stay localized"
      )
      Assert.Equal(
        lines[2] and lines[2]._text or nil,
        "Magisters' Terrace",
        "center notice tooltip should add the English name below the title"
      )
      Assert.Equal(sharedTooltipCalls, 0, "center notice tooltip should not use the shared Blizzard GameTooltip")
    end)
  end)

  test("Center notice tooltip prefers exact activity map over shared spell fallback", function()
    local now = 0
    local createFrameStub, createdFrames = BuildCreateFrameStub()

    WithGlobals({
      UIParent = {},
      CreateFrame = createFrameStub,
      GetTime = function()
        return now
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local centerNotice = Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
        resolveTeleportSpellID = function()
          return 367416
        end,
        resolveMapIDBySpellID = function(spellID)
          if spellID == 367416 then
            return 2441
          end
          return nil
        end,
        resolveMapIDByActivityID = function(activityID)
          if activityID == 999 then
            return 2442
          end
          return nil
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
        getDungeonName = function(mapID, localeTag)
          if mapID == 2442 and localeTag == "enUS" then
            return "Tazavesh: Streets of Wonder"
          end
          if mapID == 2442 then
            return "Tazavesh: Straßen der Wunder"
          end
          if mapID == 2441 and localeTag == "enUS" then
            return "Tazavesh: So'leah's Gambit"
          end
          if mapID == 2441 then
            return "Tazavesh: So'leahs Schachzug"
          end
          return nil
        end,
        getL = function()
          return {
            TOOLTIP_TELEPORT_CAST = "Cast",
            TOOLTIP_TELEPORT_READY = "Ready",
          }
        end,
      })

      centerNotice.ConfigureTeleportButton("Tazavesh: Straßen der Wunder", 999)
      local onEnter = centerNotice.teleportButton._scripts and centerNotice.teleportButton._scripts.OnEnter or nil
      Assert.NotNil(onEnter, "center notice teleport button should define tooltip OnEnter")
      ---@diagnostic disable: need-check-nil
      onEnter(centerNotice.teleportButton)
      ---@diagnostic enable: need-check-nil

      local privateTooltip = nil
      for _, frame in ipairs(createdFrames) do
        if frame._isIsiLiveTooltip == true then
          privateTooltip = frame
          break
        end
      end

      Assert.NotNil(privateTooltip, "center notice should allocate a private tooltip frame")
      local privateTooltipFrame = RequireValue(privateTooltip, "center notice should allocate a private tooltip frame")
      local lines = rawget(privateTooltipFrame, "_isiLiveTooltipLines") or {}
      Assert.Equal(
        lines[1] and lines[1]._text or nil,
        "Tazavesh: Straßen der Wunder",
        "center notice tooltip title should keep the concrete localized activity dungeon"
      )
      Assert.Equal(
        lines[2] and lines[2]._text or nil,
        "Tazavesh: Streets of Wonder",
        "center notice tooltip subtitle must use the exact activity map instead of the shared spell fallback"
      )
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
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local centerNotice = Notice.CreateCenterNotice({
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
      ---@diagnostic disable: need-check-nil
      onDragStart(centerNotice.frame)
      onDragStop(centerNotice.frame)
      ---@diagnostic enable: need-check-nil

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

  test("Portal navigator notice lays out the four portal labels around the frame", function()
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local portalNotice = Notice.CreatePortalNavigatorNotice({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
      })

      local framePoint, frameRelativeTo, frameRelativePoint, frameX, frameY = portalNotice.frame:GetPoint()
      Assert.Equal(framePoint, "CENTER", "portal navigator frame should stay centered on the horizontal axis")
      Assert.Equal(frameRelativeTo, UIParent, "portal navigator frame should anchor to UIParent")
      Assert.Equal(frameRelativePoint, "CENTER", "portal navigator frame should keep center relative point")
      Assert.Equal(frameX, 0, "portal navigator frame should not drift horizontally")
      Assert.Equal(frameY, 240, "portal navigator frame should move up by one frame height")
      Assert.Equal(portalNotice.frame:GetAlpha(), 1, "portal navigator text should stay fully opaque")
      local bgR, bgG, bgB, bgA = portalNotice.frame:GetBackdropColor()
      Assert.Equal(bgR, 0.05, "portal navigator background should keep the configured red channel")
      Assert.Equal(bgG, 0.05, "portal navigator background should keep the configured green channel")
      Assert.Equal(bgB, 0.08, "portal navigator background should keep the configured blue channel")
      Assert.Equal(bgA, 0.72, "portal navigator background should render at the configured alpha")

      portalNotice.SetVisible(false)
      Assert.True(not portalNotice.frame:IsShown(), "portal navigator should hide cleanly")

      portalNotice.SetVisible(true)
      local reopenedFramePoint, reopenedFrameRelativeTo, reopenedFrameRelativePoint, reopenedFrameX, reopenedFrameY =
        portalNotice.frame:GetPoint()
      Assert.Equal(reopenedFramePoint, "CENTER", "portal navigator should reopen on the horizontal center")
      Assert.Equal(reopenedFrameRelativeTo, UIParent, "portal navigator should still anchor to UIParent when reopened")
      Assert.Equal(reopenedFrameRelativePoint, "CENTER", "portal navigator should reopen with center relative point")
      Assert.Equal(reopenedFrameX, 0, "portal navigator should not drift horizontally when reopened")
      Assert.Equal(reopenedFrameY, 240, "portal navigator should reopen at the configured top offset")

      local shown = portalNotice.Show({
        title = "Portal Navigator",
        entries = {
          { slot = "half_left", direction = "Half left", destination = "Grube von Saron" },
          { slot = "left", direction = "Left", destination = "Himmelsnadel" },
          { slot = "right", direction = "Right", destination = "Sitz des Triumvirats" },
          { slot = "half_right", direction = "Half right", destination = "Akademie von Algeth'ar" },
        },
      })

      Assert.True(shown, "portal navigator show should accept structured layout")
      Assert.True(portalNotice.frame:IsShown(), "portal navigator should be visible after show")

      local _, titleFontSize = portalNotice.titleText:GetFont()
      Assert.Equal(titleFontSize, 24, "portal navigator title should be 10 points larger than the stub baseline")

      for _, slot in ipairs({ "half_left", "left", "right", "half_right" }) do
        local _, entryFontSize = portalNotice.entries[slot]:GetFont()
        Assert.Equal(entryFontSize, 24, "portal navigator entries should be 10 points larger than the stub baseline")
        Assert.Equal(
          portalNotice.entries[slot]._fontObject,
          "GameFontNormal",
          "portal navigator entry text should use GameFontNormal"
        )
      end

      local titlePoint, titleRelativeTo, titleRelativePoint, titleX, titleY = portalNotice.titleText:GetPoint()
      Assert.Equal(titlePoint, "TOP", "portal navigator title should anchor at the top center")
      Assert.Equal(titleRelativeTo, portalNotice.frame, "portal navigator title should anchor to the frame")
      Assert.Equal(titleRelativePoint, "TOP", "portal navigator title should keep the top relative point")
      Assert.Equal(titleX, 0, "portal navigator title should stay centered")
      Assert.Equal(titleY, -12, "portal navigator title should keep the configured top offset")

      local halfLeftPoint, halfLeftRelativeTo, halfLeftRelativePoint, halfLeftX, halfLeftY =
        portalNotice.entries.half_left:GetPoint()
      Assert.Equal(halfLeftPoint, "TOPLEFT", "half-left portal should anchor in the upper left quadrant")
      Assert.Equal(halfLeftRelativeTo, portalNotice.frame, "half-left portal should anchor to the frame")
      Assert.Equal(halfLeftRelativePoint, "TOPLEFT", "half-left portal should keep the top-left relative point")
      Assert.Equal(halfLeftX, 60, "half-left portal should use the configured x offset")
      Assert.Equal(halfLeftY, -78, "half-left portal should use the configured y offset")

      local leftPoint, leftRelativeTo, leftRelativePoint, leftX, leftY = portalNotice.entries.left:GetPoint()
      Assert.Equal(leftPoint, "LEFT", "left portal should anchor on the left edge")
      Assert.Equal(leftRelativeTo, portalNotice.frame, "left portal should anchor to the frame")
      Assert.Equal(leftRelativePoint, "LEFT", "left portal should keep the left relative point")
      Assert.Equal(leftX, 60, "left portal should use the configured x offset")
      Assert.Equal(leftY, -24, "left portal should sit lower to separate it from the upper entry")

      local rightPoint, rightRelativeTo, rightRelativePoint, rightX, rightY = portalNotice.entries.right:GetPoint()
      Assert.Equal(rightPoint, "RIGHT", "right portal should anchor on the right edge")
      Assert.Equal(rightRelativeTo, portalNotice.frame, "right portal should anchor to the frame")
      Assert.Equal(rightRelativePoint, "RIGHT", "right portal should keep the right relative point")
      Assert.Equal(rightX, -60, "right portal should use the configured x offset")
      Assert.Equal(rightY, -24, "right portal should sit lower to separate it from the upper entry")

      local halfRightPoint, halfRightRelativeTo, halfRightRelativePoint, halfRightX, halfRightY =
        portalNotice.entries.half_right:GetPoint()
      Assert.Equal(halfRightPoint, "TOPRIGHT", "half-right portal should anchor in the upper right quadrant")
      Assert.Equal(halfRightRelativeTo, portalNotice.frame, "half-right portal should anchor to the frame")
      Assert.Equal(halfRightRelativePoint, "TOPRIGHT", "half-right portal should keep the top-right relative point")
      Assert.Equal(halfRightX, -60, "half-right portal should use the configured x offset")
      Assert.Equal(halfRightY, -78, "half-right portal should use the configured y offset")

      Assert.Equal(
        portalNotice.entries.half_left:GetText(),
        "Grube von Saron",
        "upper-left portal should show the destination name"
      )
      Assert.Equal(
        portalNotice.entries.left:GetText(),
        "Himmelsnadel",
        "lower-left portal should show the destination name"
      )
      Assert.Equal(
        portalNotice.entries.right:GetText(),
        "Sitz des Triumvirats",
        "lower-right portal should show the destination name"
      )
      Assert.Equal(
        portalNotice.entries.half_right:GetText(),
        "Akademie von Algeth'ar",
        "upper-right portal should show the destination name"
      )
    end)
  end)
end

return function(test, ctx)
  local Assert = RequireValue(ctx.assert, "UI center notice scenario ctx.assert should exist")
  local WithGlobals = RequireValue(ctx.with_globals, "UI center notice scenario ctx.with_globals should exist")
  local LoadAddonModules = RequireValue(ctx.load_modules, "UI center notice scenario ctx.load_modules should exist")

  RegisterCenterNoticeVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCenterNoticeDragResetTest(test, Assert, WithGlobals, LoadAddonModules)
end
