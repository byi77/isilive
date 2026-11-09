-- Forward-declared: font-string stubs above its definition create groups too.
local CreateAnimationGroupStub
local Unpack = rawget(table, "unpack") or rawget(_G, "unpack")

local function RemoveChild(parent, child)
  local children = type(parent) == "table" and rawget(parent, "_children") or nil
  if type(children) ~= "table" then
    return
  end
  for index = #children, 1, -1 do
    if children[index] == child then
      table.remove(children, index)
    end
  end
end

local function AddChild(parent, child)
  if type(parent) ~= "table" then
    return
  end
  local children = rawget(parent, "_children")
  if type(children) ~= "table" then
    children = {}
    rawset(parent, "_children", children)
  end
  children[#children + 1] = child
end

local function CreateTextureStub()
  return {
    hidden = false,
    SetAllPoints = function() end,
    SetHeight = function(self, height)
      self._height = tonumber(height) or height
    end,
    SetWidth = function(self, width)
      self._width = tonumber(width) or width
    end,
    SetSize = function(self, width, height)
      self._width = tonumber(width) or width
      self._height = tonumber(height) or height
    end,
    SetPoint = function(self, ...)
      self._points = self._points or {}
      table.insert(self._points, { ... })
    end,
    SetColorTexture = function(self, ...)
      self._color = { ... }
    end,
    SetTexture = function(self, texture)
      self._texture = texture
    end,
    SetTexCoord = function() end,
    SetBlendMode = function() end,
    SetVertexColor = function(self, ...)
      self._vertexColor = { ... }
    end,
    SetDesaturated = function(self, desaturated)
      self._desaturated = desaturated
    end,
    SetAlpha = function(self, alpha)
      self._alpha = alpha
    end,
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
    GetFont = function(self)
      return self._fontPath or "Fonts\\FRIZQT__.TTF", fontSize, fontFlags
    end,
    SetFont = function(self, path, size, flags)
      self._fontPath = path
      fontSize = tonumber(size) or fontSize
      fontFlags = flags
    end,
    SetShadowColor = function(self, r, g, b, a)
      self._shadowColor = { r, g, b, a }
    end,
    CreateAnimationGroup = function(self)
      local group = CreateAnimationGroupStub()
      self._animGroups = self._animGroups or {}
      table.insert(self._animGroups, group)
      return group
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

CreateAnimationGroupStub = function()
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
    if type(p) ~= "table" then
      return nil
    end
    return p[1], p[2], p[3], p[4], p[5]
  end
  frame.SetParent = function(self, parent)
    RemoveChild(self._parent, self)
    self._parent = parent
    AddChild(parent, self)
  end
  -- Like the client: child frames in creation order, and the frame's own
  -- textures and font strings.
  frame.GetChildren = function(self)
    return Unpack(self._children or {})
  end
  frame.GetRegions = function(self)
    local regions = {}
    for _, texture in ipairs(self._textures or {}) do
      regions[#regions + 1] = texture
    end
    for _, fontString in ipairs(self._fontStrings or {}) do
      regions[#regions + 1] = fontString
    end
    return Unpack(regions)
  end
  frame.GetParent = function(self)
    return self._parent
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
  frame.CreateTexture = function(self)
    local texture = CreateTextureStub()
    if type(self) == "table" then
      self._textures = self._textures or {}
      table.insert(self._textures, texture)
      texture._parent = self
      texture.GetParent = function(region)
        return region._parent
      end
    end
    return texture
  end
  frame.CreateFontString = function(self, _name, _layer, fontObject)
    local fontString = CreateFontStringStub(fontObject)
    if type(self) == "table" then
      self._fontStrings = self._fontStrings or {}
      table.insert(self._fontStrings, fontString)
      fontString._parent = self
      fontString.GetParent = function(region)
        return region._parent
      end
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
  frame.Enable = function(self)
    self._disabled = false
  end
  frame.Disable = function(self)
    self._disabled = true
  end
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
  frame.GetScale = function(self)
    return self._scale or 1
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
  frame.CreateAnimationGroup = function(self)
    local group = CreateAnimationGroupStub()
    self._animGroups = self._animGroups or {}
    table.insert(self._animGroups, group)
    return group
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
    AddChild(parent, frame)
    table.insert(createdFrames, frame)
    return frame
  end

  return CreateFrameStub, createdFrames
end

-- COMPONENT-ONLY (Blizzard side): mirrors the 12.1.5 Settings API the config
-- window stub uses (Blizzard_Settings_Shared: RegisterVerticalLayoutCategory,
-- CreateSettingsButtonInitializer with AddSearchTags, the vertical-layout
-- search of SettingsPanelMixin:FindInitializersMatchingSearchText, and
-- HideUIPanel's refusal from addon code in combat). The client's Settings
-- frame has no addon-side event path. Returns globals plus a state table.
local function BuildBlizzardSettingsStub(opts)
  opts = opts or {}
  local state = { categories = {}, hideCalls = 0, blockedHides = 0, openCalls = 0 }
  local function CreateInitializer(template, data)
    local initializer = { template = template, data = data, searchTags = {} }
    function initializer.GetData(self)
      return self.data
    end
    function initializer.AddSearchTags(self, ...)
      for index = 1, select("#", ...) do
        local tag = select(index, ...)
        if type(tag) == "string" and tag ~= "" then
          table.insert(self.searchTags, tag:upper())
        end
      end
    end
    function initializer.MatchesSearchTags(self, words)
      for _, word in ipairs(words) do
        for _, tag in ipairs(self.searchTags) do
          local first, last = string.find(tag, word, nil, true)
          if first and last then
            return last - first
          end
        end
      end
      return nil
    end
    return initializer
  end
  local settingsPanel = {
    _shown = false,
    Show = function(self)
      self._shown = true
    end,
    Hide = function(self)
      self._shown = false
    end,
    IsShown = function(self)
      return self._shown == true
    end,
  }
  state.settingsPanel = settingsPanel
  local globals = {
    SettingsPanel = settingsPanel,
    HideUIPanel = function(frame)
      state.hideCalls = state.hideCalls + 1
      local inCombat = type(opts.isInCombat) == "function" and opts.isInCombat() == true
      if inCombat then
        -- CheckProtectedFunctionsAllowed: InCombatLockdown() and not issecure().
        state.blockedHides = state.blockedHides + 1
        return
      end
      frame:Hide()
    end,
    CreateSettingsButtonInitializer = function(name, buttonText, buttonClick, tooltip, addSearchTags)
      assert(addSearchTags ~= nil, "addSearchTags must not be nil")
      local initializer = CreateInitializer("SettingButtonControlTemplate", {
        name = name,
        buttonText = buttonText,
        buttonClick = buttonClick,
        tooltip = tooltip,
      })
      if addSearchTags then
        initializer:AddSearchTags(name)
        initializer:AddSearchTags(buttonText)
      end
      return initializer
    end,
    CreateSettingsListSectionHeaderInitializer = function(name, tooltip)
      return CreateInitializer("SettingsListSectionHeaderTemplate", { name = name, tooltip = tooltip })
    end,
    Settings = {
      RegisterVerticalLayoutCategory = function(name)
        local layout = { initializers = {} }
        function layout.AddInitializer(self, initializer)
          table.insert(self.initializers, initializer)
        end
        local category = { ID = "isiLive-stub-" .. tostring(#state.categories + 1), name = name, layout = layout }
        table.insert(state.categories, category)
        return category, layout
      end,
      RegisterCanvasLayoutCategory = function()
        error("isiLive must not register a canvas category any more (rule 237)")
      end,
      RegisterAddOnCategory = function(category)
        category.registered = true
      end,
      OpenToCategory = function(categoryID)
        state.openCalls = state.openCalls + 1
        state.openedCategory = categoryID
        settingsPanel:Show()
      end,
    },
  }
  function state.Search(text)
    local searchText = tostring(text or ""):upper()
    local words = { searchText }
    for word in string.gmatch(searchText, "([^, ]+)") do
      table.insert(words, word)
    end
    local matches = {}
    for _, category in ipairs(state.categories) do
      for _, initializer in ipairs(category.layout.initializers) do
        if initializer:MatchesSearchTags(words) then
          matches[#matches + 1] = { initializer = initializer, category = category }
        end
      end
    end
    return matches
  end
  function state.FindButton()
    for _, category in ipairs(state.categories) do
      for _, initializer in ipairs(category.layout.initializers) do
        if initializer.template == "SettingButtonControlTemplate" then
          return initializer
        end
      end
    end
    return nil
  end
  return globals, state
end

return {
  CreateTextureStub = CreateTextureStub,
  CreateFontStringStub = CreateFontStringStub,
  CreateAnimationGroupStub = CreateAnimationGroupStub,
  RequireValue = RequireValue,
  FindCombatRetryFrame = FindCombatRetryFrame,
  BuildCreateFrameStub = BuildCreateFrameStub,
  BuildBlizzardSettingsStub = BuildBlizzardSettingsStub,
}
