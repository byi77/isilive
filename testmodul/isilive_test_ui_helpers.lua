local function CreateTextureStub()
  return {
    hidden = false,
    SetAllPoints = function() end,
    SetHeight = function() end,
    SetWidth = function() end,
    SetSize = function() end,
    SetPoint = function() end,
    SetColorTexture = function() end,
    SetTexture = function(self, texture)
      self._texture = texture
    end,
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
  local fontFlags = ""
  return {
    _fontObject = fontObject,
    _shown = true,
    SetPoint = function(self, point, relativeTo, relativePoint, x, y)
      self._point = { point, relativeTo, relativePoint, x or 0, y or 0 }
    end,
    ClearAllPoints = function(self)
      self._point = nil
    end,
    GetPoint = function(self)
      local p = self._point
      if not p then
        return nil
      end
      return p[1], p[2], p[3], p[4], p[5]
    end,
    SetJustifyH = function(self, value)
      self._justifyH = value
    end,
    SetJustifyV = function() end,
    SetWordWrap = function(self, value)
      self._wordWrap = value == true
    end,
    SetNonSpaceWrap = function(self, value)
      self._nonSpaceWrap = value == true
    end,
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
    SetWidth = function(self, width)
      self._width = tonumber(width) or self._width
    end,
    GetStringHeight = function(self)
      local text = tostring(self._text or "")
      if text == "" then
        return 20
      end
      if self._wordWrap ~= true then
        return 20
      end

      local width = tonumber(self._width) or 0
      if width <= 0 then
        return 20
      end

      local estimatedCharsPerLine = math.max(12, math.floor(width / 7))
      local lineCount = math.max(1, math.ceil(#text / estimatedCharsPerLine))
      return lineCount * 16
    end,
    GetStringWidth = function(self)
      local text = tostring(self._text or "")
      local size = tonumber(fontSize) or 14
      return #text * math.max(5, math.floor(size * 0.5))
    end,
    GetFont = function()
      return "Fonts\\FRIZQT__.TTF", fontSize, fontFlags
    end,
    SetFont = function(_self, _path, size, flags)
      fontSize = tonumber(size) or fontSize
      fontFlags = flags
    end,
    SetShadowColor = function(self, r, g, b, a)
      self._shadowColor = { r, g, b, a }
    end,
    SetShadowOffset = function(self, x, y)
      self._shadowOffset = { x, y }
    end,
    Hide = function(self)
      self.hidden = true
      self._shown = false
    end,
    Show = function(self)
      self.hidden = false
      self._shown = true
    end,
    IsShown = function(self)
      return self._shown == true
    end,
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

local function RequireValue(value, message)
  if value == nil then
    error(message, 2)
  end
  return value
end

local function FindCombatRetryFrame(createdFrames)
  for _, frame in ipairs(createdFrames or {}) do
    if frame.IsEventRegistered and frame:IsEventRegistered("PLAYER_REGEN_ENABLED") then
      return frame
    end
  end
  return nil
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
  frame.SetMovable = function(self, enabled)
    self._movable = enabled == true
  end
  frame.SetClampedToScreen = function(self, enabled)
    self._clampedToScreen = enabled == true
  end
  frame.SetClampRectInsets = function(self, left, right, top, bottom)
    self._clampRectInsets = { left, right, top, bottom }
  end
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
  frame.CreateFontString = function(self, _name, _layer, fontObject)
    local fontString = CreateFontStringStub(fontObject)
    if type(self) == "table" then
      self._fontStrings = self._fontStrings or {}
      table.insert(self._fontStrings, fontString)
    end
    return fontString
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

return {
  CreateTextureStub = CreateTextureStub,
  CreateFontStringStub = CreateFontStringStub,
  CreateAnimationGroupStub = CreateAnimationGroupStub,
  RequireValue = RequireValue,
  FindCombatRetryFrame = FindCombatRetryFrame,
  BuildCreateFrameStub = BuildCreateFrameStub,
}
