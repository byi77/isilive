-- Headless WoW widget engine for the wowsim simulator.
--
-- Implements enough of the WoW widget API (Frame, Button, Texture, FontString,
-- StatusBar, Cooldown, EditBox, ScrollFrame, Slider, GameTooltip, animation
-- groups, font objects) for isiLive to build its real UI, and records every
-- property that matters for rendering: anchors, size, scale, strata/level,
-- backdrop, texture, text, colors and visibility. Snapshot() resolves the
-- anchor graph to absolute screen rectangles so tools/wowsim/viewer_template
-- can draw the UI without the game client.
--
-- One engine instance exists per simulated client (see wowsim.lua): each
-- client owns its own UIParent, frame registry and event registrations.

local Widgets = {}

local Compat = require("compat")
local unpack = Compat.unpack

local STRATA_ORDER = {
  BACKGROUND = 1,
  LOW = 2,
  MEDIUM = 3,
  HIGH = 4,
  DIALOG = 5,
  FULLSCREEN = 6,
  FULLSCREEN_DIALOG = 7,
  TOOLTIP = 8,
}

local POINT_FACTORS = {
  TOPLEFT = { 0, 1 },
  TOP = { 0.5, 1 },
  TOPRIGHT = { 1, 1 },
  LEFT = { 0, 0.5 },
  CENTER = { 0.5, 0.5 },
  RIGHT = { 1, 0.5 },
  BOTTOMLEFT = { 0, 0 },
  BOTTOM = { 0.5, 0 },
  BOTTOMRIGHT = { 1, 0 },
}

local FONT_DEFAULT_PATH = "Fonts\\FRIZQT__.TTF"

-- Strips WoW escape sequences so string-width estimates count visible glyphs.
local function StripEscapes(text)
  local s = tostring(text or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
  s = s:gsub("|r", "")
  s = s:gsub("|T.-|t", "WW")
  s = s:gsub("|A.-|a", "WW")
  s = s:gsub("|H.-|h(.-)|h", "%1")
  s = s:gsub("||", "|")
  return s
end

local function Utf8Len(s)
  local _, count = s:gsub("[^\128-\191]", "")
  return count
end

-- Approximates the rendered width of a text in pixels. Friz Quadrata averages
-- about 0.55 em per glyph for mixed-case text; good enough for layout checks.
local function EstimateTextWidth(text, size)
  local longest = 0
  for line in (StripEscapes(text) .. "\n"):gmatch("(.-)\n") do
    local w = Utf8Len(line) * (size or 12) * 0.55
    if w > longest then
      longest = w
    end
  end
  return longest
end

local function CountLines(text)
  local s = tostring(text or ""):gsub("|n", "\n")
  local _, n = s:gsub("\n", "")
  return n + 1
end

local function CopyColor(r, g, b, a)
  if type(r) == "table" then
    return { r.r or r[1] or 1, r.g or r[2] or 1, r.b or r[3] or 1, r.a or r[4] or 1 }
  end
  return { tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1 }
end

local function DefineRegion(engine, M)
  local env = M.env
  ---------------------------------------------------------------------------
  -- ScriptObject / Region shared methods
  ---------------------------------------------------------------------------
  local Region = {}

  function Region:GetObjectType()
    return self._type
  end
  function Region:IsObjectType(t)
    return self._type == t
      or (t == "Frame" and self._isFrame)
      or (t == "Region" and true)
      or (t == "Button" and (self._type == "CheckButton"))
  end
  function Region:GetName()
    return self._name
  end
  function Region:GetDebugName()
    return self._name or ("<" .. self._type .. "#" .. self._id .. ">")
  end
  function Region:GetParent()
    return self._parent
  end
  function Region:IsForbidden()
    return false
  end
  function Region:IsProtected()
    return false, false
  end
  function Region:SetPoint(point, a, b, c, d)
    point = string.upper(tostring(point or "CENTER"))
    local relTo, relPoint, x, y
    if type(a) == "number" or a == nil and type(b) == "number" then
      -- SetPoint(point, x, y)
      relTo, relPoint, x, y = nil, point, a, b
    elseif a == nil then
      relTo, relPoint, x, y = nil, b or point, c, d
    else
      relTo = a
      if type(b) == "number" then
        -- SetPoint(point, relativeTo, x, y)
        relPoint, x, y = point, b, c
      else
        relPoint, x, y = b or point, c, d
      end
    end
    if type(relTo) == "string" then
      relTo = engine.byName[relTo] or (env and rawget(env, relTo))
    end
    self._points = self._points or {}
    self._points[point] = {
      point = point,
      relTo = relTo,
      relPoint = string.upper(tostring(relPoint or point)),
      x = tonumber(x) or 0,
      y = tonumber(y) or 0,
    }
  end
  function Region:ClearAllPoints()
    self._points = {}
  end
  function Region:ClearPoint(point)
    if self._points then
      self._points[string.upper(point)] = nil
    end
  end
  function Region:SetAllPoints(relTo)
    relTo = relTo or self._parent
    if relTo == true then
      relTo = self._parent
    end
    self._points = {}
    Region.SetPoint(self, "TOPLEFT", relTo, "TOPLEFT", 0, 0)
    Region.SetPoint(self, "BOTTOMRIGHT", relTo, "BOTTOMRIGHT", 0, 0)
  end
  function Region:GetNumPoints()
    local n = 0
    for _ in pairs(self._points or {}) do
      n = n + 1
    end
    return n
  end
  function Region:GetPoint(index)
    local list = {}
    for _, p in pairs(self._points or {}) do
      list[#list + 1] = p
    end
    table.sort(list, function(l, r)
      return l.point < r.point
    end)
    local p = list[index or 1]
    if not p then
      return nil
    end
    return p.point, p.relTo or self._parent, p.relPoint, p.x, p.y
  end
  function Region:GetPointByName(name)
    local p = self._points and self._points[name]
    if not p then
      return nil
    end
    return p.point, p.relTo or self._parent, p.relPoint, p.x, p.y
  end
  function Region:SetSize(w, h)
    self._w = tonumber(w)
    self._h = tonumber(h or w)
  end
  function Region:SetWidth(w)
    self._w = tonumber(w)
  end
  function Region:SetHeight(h)
    self._h = tonumber(h)
  end
  function Region:GetWidth()
    local rect = engine.ResolveRect(self)
    if rect then
      return rect.w / engine.EffectiveScale(self)
    end
    return self._w or 0
  end
  function Region:GetHeight()
    local rect = engine.ResolveRect(self)
    if rect then
      return rect.h / engine.EffectiveScale(self)
    end
    return self._h or 0
  end
  function Region:GetSize()
    return Region.GetWidth(self), Region.GetHeight(self)
  end
  function Region:GetRect()
    local rect = engine.ResolveRect(self)
    if not rect then
      return nil
    end
    local s = engine.EffectiveScale(self)
    return rect.left / s, rect.bottom / s, rect.w / s, rect.h / s
  end
  function Region:GetScaledRect()
    local rect = engine.ResolveRect(self)
    if not rect then
      return nil
    end
    return rect.left, rect.bottom, rect.w, rect.h
  end
  function Region:GetLeft()
    local rect = engine.ResolveRect(self)
    return rect and rect.left / engine.EffectiveScale(self) or nil
  end
  function Region:GetRight()
    local rect = engine.ResolveRect(self)
    return rect and (rect.left + rect.w) / engine.EffectiveScale(self) or nil
  end
  function Region:GetTop()
    local rect = engine.ResolveRect(self)
    return rect and (rect.bottom + rect.h) / engine.EffectiveScale(self) or nil
  end
  function Region:GetBottom()
    local rect = engine.ResolveRect(self)
    return rect and rect.bottom / engine.EffectiveScale(self) or nil
  end
  function Region:GetCenter()
    local rect = engine.ResolveRect(self)
    if not rect then
      return nil
    end
    local s = engine.EffectiveScale(self)
    return (rect.left + rect.w / 2) / s, (rect.bottom + rect.h / 2) / s
  end
  function Region:IsRectValid()
    return engine.ResolveRect(self) ~= nil
  end
  function Region:IsAnchoringRestricted()
    return false
  end
  function Region:SetAlpha(a)
    self._alpha = tonumber(a) or 1
  end
  function Region:GetAlpha()
    return self._alpha or 1
  end
  function Region:GetEffectiveAlpha()
    local a = self._alpha or 1
    local p = self._parent
    while p do
      a = a * (p._alpha or 1)
      p = p._parent
    end
    return a
  end
  function Region:SetScale(s)
    self._scale = tonumber(s) or 1
  end
  function Region:GetScale()
    return self._scale or 1
  end
  function Region:GetEffectiveScale()
    return engine.EffectiveScale(self)
  end
  function Region:SetIgnoreParentScale(v)
    self._ignoreParentScale = v and true or false
  end
  function Region:SetIgnoreParentAlpha(v)
    self._ignoreParentAlpha = v and true or false
  end
  function Region:IsShown()
    return self._shown ~= false
  end
  function Region:IsVisible()
    if self._shown == false then
      return false
    end
    if self._parent then
      return self._parent:IsVisible()
    end
    return true
  end
  function Region:Show()
    if self._shown == false then
      self._shown = true
      engine.PropagateVisibility(self)
    end
  end
  function Region:Hide()
    if self._shown ~= false then
      self._shown = false
      engine.PropagateVisibility(self)
    end
  end
  function Region:SetShown(v)
    if v then
      self:Show()
    else
      self:Hide()
    end
  end
  function Region:SetParent(parent)
    if type(parent) == "string" then
      parent = engine.byName[parent]
    end
    local old = self._parent
    if old == parent then
      return
    end
    if old and old._children then
      for i, child in ipairs(old._children) do
        if child == self then
          table.remove(old._children, i)
          break
        end
      end
    end
    self._parent = parent
    if parent then
      parent._children = parent._children or {}
      parent._children[#parent._children + 1] = self
    end
    engine.PropagateVisibility(self)
  end
  function Region:SetDrawLayer(layer, sublevel)
    self._layer = layer
    self._sublevel = tonumber(sublevel) or 0
  end
  function Region:GetDrawLayer()
    return self._layer or "ARTWORK", self._sublevel or 0
  end
  function Region:SetVertexColor(r, g, b, a)
    self._vertex = CopyColor(r, g, b, a)
  end
  function Region:GetVertexColor()
    local c = self._vertex or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4]
  end
  function Region:CreateAnimationGroup(name)
    return engine.CreateAnimationGroup(self, name)
  end
  function Region:GetAnimationGroups() end
  function Region:StopAnimating()
    for _, group in ipairs(self._animGroups or {}) do
      group:Stop()
    end
  end
  function Region:IsMouseOver()
    return false
  end
  function Region:IsDragging()
    return false
  end
  M.Region = Region
end

local function DefineTexture(engine, M)
  local Region = M.Region
  ---------------------------------------------------------------------------
  -- Texture
  ---------------------------------------------------------------------------
  local Texture = setmetatable({}, { __index = Region })
  function Texture:SetTexture(path, ...)
    self._tex = path
    self._texColor = nil
    self._atlas = nil
    return true
  end
  function Texture:GetTexture()
    return self._tex
  end
  function Texture:GetTextureFilePath()
    return self._tex
  end
  function Texture:GetTextureFileID()
    return type(self._tex) == "number" and self._tex or nil
  end
  function Texture:SetColorTexture(r, g, b, a)
    self._texColor = CopyColor(r, g, b, a)
    self._tex = nil
    self._atlas = nil
  end
  function Texture:SetAtlas(atlas, useAtlasSize)
    self._atlas = atlas
    self._tex = nil
    self._texColor = nil
    if useAtlasSize and not self._w then
      self._w, self._h = 16, 16
    end
    return true
  end
  function Texture:GetAtlas()
    return self._atlas
  end
  function Texture:SetTexCoord(...)
    local n = select("#", ...)
    if n == 4 then
      self._coords = { ... }
    elseif n == 8 then
      local ulx, uly, _, _, _, _, lrx, lry = ...
      self._coords = { ulx, lrx, uly, lry }
    end
  end
  function Texture:GetTexCoord()
    local c = self._coords or { 0, 1, 0, 1 }
    return c[1], c[3], c[1], c[4], c[2], c[3], c[2], c[4]
  end
  function Texture:SetDesaturated(v)
    self._desaturated = v and true or false
  end
  function Texture:IsDesaturated()
    return self._desaturated == true
  end
  function Texture:SetDesaturation(v)
    self._desaturated = (tonumber(v) or 0) > 0
  end
  function Texture:SetGradient(_orientation, minColor, maxColor)
    self._gradient = { minColor, maxColor }
  end
  function Texture:SetBlendMode(mode)
    self._blend = mode
  end
  function Texture:SetRotation(r)
    self._rotation = r
  end
  function Texture:GetRotation()
    return self._rotation or 0
  end
  function Texture:AddMaskTexture() end
  function Texture:RemoveMaskTexture() end
  function Texture:SetMask() end
  function Texture:SetHorizTile() end
  function Texture:SetVertTile() end
  function Texture:SetSnapToPixelGrid() end
  function Texture:SetTexelSnappingBias() end
  function Texture:SetStartPoint(...)
    self._lineStart = { ... }
  end
  function Texture:SetEndPoint(...)
    self._lineEnd = { ... }
  end
  function Texture:SetThickness(t)
    self._thickness = t
  end
  M.Texture = Texture
end

local function DefineFonts(engine, M)
  local env = M.env
  local MakeObject = M.MakeObject
  local Region = M.Region
  ---------------------------------------------------------------------------
  -- Fonts: FontString and font objects
  ---------------------------------------------------------------------------
  local FontInstance = {}
  function FontInstance:SetFont(path, size, flags)
    self._font = { path = path or FONT_DEFAULT_PATH, size = tonumber(size) or 12, flags = flags or "" }
    return true
  end
  function FontInstance:GetFont()
    local f = self._font
    if not f and self._fontObject then
      return self._fontObject:GetFont()
    end
    f = f or { path = FONT_DEFAULT_PATH, size = 12, flags = "" }
    return f.path, f.size, f.flags
  end
  function FontInstance:SetFontObject(obj)
    if type(obj) == "string" then
      obj = engine.fontObjects[obj] or (env and rawget(env, obj))
    end
    self._fontObject = obj
    if type(obj) == "table" and obj._font then
      self._font = { path = obj._font.path, size = obj._font.size, flags = obj._font.flags }
      if obj._textColor and not self._textColorExplicit then
        self._textColor = { unpack(obj._textColor) }
      end
    end
  end
  function FontInstance:GetFontObject()
    return self._fontObject
  end
  function FontInstance:SetTextColor(r, g, b, a)
    self._textColor = CopyColor(r, g, b, a)
    self._textColorExplicit = true
  end
  function FontInstance:GetTextColor()
    local c = self._textColor or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4]
  end
  function FontInstance:SetJustifyH(j)
    self._justifyH = j
  end
  function FontInstance:GetJustifyH()
    return self._justifyH or "CENTER"
  end
  function FontInstance:SetJustifyV(j)
    self._justifyV = j
  end
  function FontInstance:GetJustifyV()
    return self._justifyV or "MIDDLE"
  end
  function FontInstance:SetShadowColor(...)
    self._shadowColor = CopyColor(...)
  end
  function FontInstance:GetShadowColor()
    local c = self._shadowColor or { 0, 0, 0, 0 }
    return c[1], c[2], c[3], c[4]
  end
  function FontInstance:SetShadowOffset(x, y)
    self._shadowOffset = { x, y }
  end
  function FontInstance:GetShadowOffset()
    local o = self._shadowOffset or { 0, 0 }
    return o[1], o[2]
  end
  function FontInstance:SetSpacing(s)
    self._spacing = s
  end
  function FontInstance:GetSpacing()
    return self._spacing or 0
  end
  function FontInstance:CopyFontObject(src)
    if type(src) == "string" then
      src = engine.fontObjects[src] or (env and rawget(env, src))
    end
    if type(src) == "table" and src._font then
      self._font = { path = src._font.path, size = src._font.size, flags = src._font.flags }
      if src._textColor then
        self._textColor = { unpack(src._textColor) }
      end
    end
  end

  local FontString = setmetatable({}, { __index = Region })
  for k, v in pairs(FontInstance) do
    FontString[k] = v
  end
  function FontString:SetText(text)
    if text == nil then
      self._text = nil
    else
      self._text = tostring(text)
    end
  end
  function FontString:SetFormattedText(fmt, ...)
    self._text = string.format(fmt, ...)
  end
  function FontString:GetText()
    return self._text
  end
  function FontString:GetStringWidth()
    local _, size = self:GetFont()
    return EstimateTextWidth(self._text, size)
  end
  function FontString:GetUnboundedStringWidth()
    return self:GetStringWidth()
  end
  function FontString:GetStringHeight()
    local _, size = self:GetFont()
    return CountLines(self._text) * (size or 12) * 1.15
  end
  function FontString:GetLineHeight()
    local _, size = self:GetFont()
    return size or 12
  end
  function FontString:GetNumLines()
    return CountLines(self._text)
  end
  function FontString:IsTruncated()
    local w = self._w
    return w ~= nil and w > 0 and self:GetStringWidth() > w
  end
  function FontString:SetWordWrap(v)
    self._wrap = v and true or false
  end
  function FontString:GetWordWrap()
    return self._wrap ~= false
  end
  function FontString:SetNonSpaceWrap(v)
    self._nonSpaceWrap = v
  end
  function FontString:SetMaxLines(n)
    self._maxLines = n
  end
  function FontString:GetMaxLines()
    return self._maxLines or 0
  end
  function FontString:SetIndentedWordWrap() end
  function FontString:SetTextScale(s)
    self._textScale = s
  end
  function FontString:GetTextScale()
    return self._textScale or 1
  end
  function FontString:SetTextHeight(h)
    local path, _, flags = self:GetFont()
    self._font = { path = path, size = h, flags = flags }
  end
  function FontString:CanWordWrap()
    return true
  end
  function FontString:CanNonSpaceWrap()
    return true
  end

  local FontObject = {}
  for k, v in pairs(FontInstance) do
    FontObject[k] = v
  end
  function FontObject:GetName()
    return self._name
  end
  function FontObject:GetObjectType()
    return "Font"
  end
  function FontObject:IsObjectType(t)
    return t == "Font"
  end

  function engine.CreateFont(name, path, size, flags, color)
    local obj = MakeObject("Font", FontObject)
    obj._name = name
    obj._font = { path = path or FONT_DEFAULT_PATH, size = size or 12, flags = flags or "" }
    obj._textColor = color and { unpack(color) } or { 1, 1, 1, 1 }
    if name then
      engine.fontObjects[name] = obj
    end
    return obj
  end
  M.FontInstance = FontInstance
  M.FontString = FontString
  M.FontObject = FontObject
end

local function DefineFrame(engine, M)
  local SafeCall = M.SafeCall
  local Region = M.Region
  ---------------------------------------------------------------------------
  -- Frame
  ---------------------------------------------------------------------------
  local Frame = setmetatable({}, { __index = Region })

  function Frame:SetScript(name, fn)
    self._scripts = self._scripts or {}
    self._scripts[name] = fn
    if name == "OnUpdate" then
      engine.onUpdateDirty = true
    end
  end
  function Frame:GetScript(name)
    return self._scripts and self._scripts[name]
  end
  function Frame:HasScript(name)
    return true
  end
  function Frame:HookScript(name, fn)
    local existing = self:GetScript(name)
    if existing then
      self:SetScript(name, function(...)
        existing(...)
        fn(...)
      end)
    else
      self:SetScript(name, fn)
    end
  end
  function Frame:RegisterEvent(event)
    self._events = self._events or {}
    self._events[event] = true
    engine.eventFrames[self] = true
    return true
  end
  function Frame:RegisterUnitEvent(event, ...)
    self._events = self._events or {}
    local units = {}
    for i = 1, select("#", ...) do
      local u = select(i, ...)
      if u then
        units[u] = true
      end
    end
    self._events[event] = next(units) and units or true
    engine.eventFrames[self] = true
    return true
  end
  function Frame:UnregisterEvent(event)
    if self._events then
      self._events[event] = nil
    end
  end
  function Frame:UnregisterAllEvents()
    self._events = {}
  end
  function Frame:IsEventRegistered(event)
    local reg = self._events and self._events[event]
    if reg == nil then
      return false
    end
    return true
  end
  function Frame:CreateTexture(name, layer, template, sublevel)
    return engine.CreateRegion("Texture", self, name, layer, sublevel)
  end
  function Frame:CreateMaskTexture(name, layer)
    local t = engine.CreateRegion("MaskTexture", self, name, layer)
    t._isMask = true
    return t
  end
  function Frame:CreateLine(name, layer)
    local t = engine.CreateRegion("Line", self, name, layer)
    t._isLine = true
    return t
  end
  function Frame:CreateFontString(name, layer, template)
    local fs = engine.CreateRegion("FontString", self, name, layer)
    if template then
      fs:SetFontObject(template)
    end
    return fs
  end
  function Frame:GetChildren()
    local frames = {}
    for _, child in ipairs(self._children or {}) do
      if child._isFrame then
        frames[#frames + 1] = child
      end
    end
    return unpack(frames)
  end
  function Frame:GetNumChildren()
    return select("#", self:GetChildren())
  end
  function Frame:GetRegions()
    local regions = {}
    for _, child in ipairs(self._children or {}) do
      if not child._isFrame then
        regions[#regions + 1] = child
      end
    end
    return unpack(regions)
  end
  function Frame:GetNumRegions()
    return select("#", self:GetRegions())
  end
  function Frame:SetFrameStrata(s)
    self._strata = s
  end
  function Frame:GetFrameStrata()
    local f = self
    while f do
      if f._strata then
        return f._strata
      end
      f = f._parent
    end
    return "MEDIUM"
  end
  function Frame:SetFrameLevel(l)
    self._level = tonumber(l) or 0
  end
  function Frame:GetFrameLevel()
    if self._level then
      return self._level
    end
    local p = self._parent
    return p and p.GetFrameLevel and (p:GetFrameLevel() + 1) or 0
  end
  function Frame:Raise() end
  function Frame:Lower() end
  function Frame:SetToplevel(v)
    self._toplevel = v
  end
  function Frame:SetBackdrop(backdrop)
    self._backdrop = backdrop
    if not backdrop then
      self._bg, self._border = nil, nil
    end
  end
  function Frame:GetBackdrop()
    return self._backdrop
  end
  function Frame:SetBackdropColor(r, g, b, a)
    self._bg = CopyColor(r, g, b, a)
  end
  function Frame:GetBackdropColor()
    local c = self._bg or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4]
  end
  function Frame:SetBackdropBorderColor(r, g, b, a)
    self._border = CopyColor(r, g, b, a)
  end
  function Frame:GetBackdropBorderColor()
    local c = self._border or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4]
  end
  function Frame:ApplyBackdrop() end
  function Frame:OnBackdropLoaded() end
  function Frame:OnBackdropSizeChanged() end
  function Frame:SetAttribute(k, v)
    self._attributes = self._attributes or {}
    self._attributes[k] = v
    local cb = self:GetScript("OnAttributeChanged")
    if cb then
      SafeCall(cb, self, k, v)
    end
  end
  function Frame:SetAttributeNoHandler(k, v)
    self._attributes = self._attributes or {}
    self._attributes[k] = v
  end
  function Frame:GetAttribute(k)
    return self._attributes and self._attributes[k]
  end
  function Frame:EnableMouse(v)
    self._mouse = v and true or false
  end
  function Frame:IsMouseEnabled()
    return self._mouse == true
  end
  function Frame:EnableMouseWheel(v)
    self._wheel = v
  end
  function Frame:IsMouseWheelEnabled()
    return self._wheel == true
  end
  function Frame:EnableKeyboard(v)
    self._keyboard = v
  end
  function Frame:SetMouseClickEnabled(v)
    self._mouseClick = v
  end
  function Frame:SetMouseMotionEnabled(v)
    self._mouseMotion = v
  end
  function Frame:SetPropagateKeyboardInput() end
  function Frame:RegisterForDrag() end
  function Frame:SetMovable(v)
    self._movable = v
  end
  function Frame:IsMovable()
    return self._movable == true
  end
  function Frame:SetResizable(v)
    self._resizable = v
  end
  function Frame:IsResizable()
    return self._resizable == true
  end
  function Frame:SetResizeBounds() end
  function Frame:SetClampedToScreen(v)
    self._clamped = v
  end
  function Frame:IsClampedToScreen()
    return self._clamped == true
  end
  function Frame:SetClampRectInsets() end
  function Frame:SetHitRectInsets() end
  function Frame:SetClipsChildren(v)
    self._clips = v and true or false
  end
  function Frame:DoesClipChildren()
    return self._clips == true
  end
  function Frame:SetUserPlaced() end
  function Frame:IsUserPlaced()
    return false
  end
  function Frame:SetDontSavePosition() end
  function Frame:StartMoving() end
  function Frame:StartSizing() end
  function Frame:StopMovingOrSizing() end
  function Frame:SetFixedFrameStrata() end
  function Frame:SetFixedFrameLevel() end
  function Frame:SetFlattensRenderLayers() end
  function Frame:SetIsFrameBuffer() end
  function Frame:SetID(id)
    self._idValue = id
  end
  function Frame:GetID()
    return self._idValue or 0
  end
  function Frame:EnableGamePadButton() end
  function Frame:SetHyperlinksEnabled(v)
    self._hyperlinks = v
  end
  function Frame:SetHyperlinkPropagateToParent() end
  M.Frame = Frame
end

local function DefineButtons(engine, M)
  local SafeCall = M.SafeCall
  local Frame = M.Frame
  ---------------------------------------------------------------------------
  -- Button / CheckButton
  ---------------------------------------------------------------------------
  local Button = setmetatable({}, { __index = Frame })
  -- Like the client, a plain Button only renders SetText output once it has a
  -- font (SetNormalFontObject, a template, or SetFontString); otherwise the
  -- text is stored but invisible.
  local function EnsureButtonText(self, forceVisible)
    if not self._fontString and not forceVisible and not self._hasButtonFont then
      self._fontString = engine.CreateRegion("FontString", self, nil, "OVERLAY")
      self._fontString:SetPoint("CENTER", self, "CENTER", 0, 0)
      self._fontString._invisibleButtonText = true
      self._fontString._shown = false
      return self._fontString
    end
    if self._fontString and self._fontString._invisibleButtonText and (forceVisible or self._hasButtonFont) then
      self._fontString._invisibleButtonText = nil
      self._fontString._shown = true
      self._fontString._font = { path = FONT_DEFAULT_PATH, size = 12, flags = "" }
      self._fontString._textColor = { 1, 0.82, 0, 1 }
    end
    if not self._fontString then
      local fs = engine.CreateRegion("FontString", self, nil, "OVERLAY")
      fs:SetPoint("CENTER", self, "CENTER", 0, 0)
      fs._font = { path = FONT_DEFAULT_PATH, size = 12, flags = "" }
      fs._textColor = { 1, 0.82, 0, 1 }
      self._fontString = fs
    end
    return self._fontString
  end
  function Button:SetText(text)
    EnsureButtonText(self):SetText(text)
  end
  function Button:SetFormattedText(fmt, ...)
    EnsureButtonText(self):SetText(string.format(fmt, ...))
  end
  function Button:GetText()
    return self._fontString and self._fontString:GetText()
  end
  function Button:GetFontString()
    return self._fontString
  end
  function Button:SetFontString(fs)
    self._hasButtonFont = true
    self._fontString = fs
  end
  function Button:GetTextWidth()
    return self._fontString and self._fontString:GetStringWidth() or 0
  end
  function Button:GetTextHeight()
    return self._fontString and self._fontString:GetStringHeight() or 0
  end
  function Button:SetNormalFontObject(obj)
    self._hasButtonFont = true
    EnsureButtonText(self, true):SetFontObject(obj)
  end
  function Button:SetHighlightFontObject() end
  function Button:SetDisabledFontObject() end
  function Button:GetNormalFontObject()
    return self._fontString and self._fontString._fontObject
  end
  local function SetStateTexture(self, slot, value, layer, hidden)
    local tex = self[slot]
    if type(value) == "table" then
      tex = value
      tex:SetParent(self)
    else
      if not tex then
        tex = engine.CreateRegion("Texture", self, nil, layer)
        tex:SetAllPoints(self)
      end
      tex:SetTexture(value)
    end
    tex._stateHidden = hidden
    self[slot] = tex
    return tex
  end
  function Button:SetNormalTexture(v)
    SetStateTexture(self, "_normalTex", v, "ARTWORK", false)
  end
  function Button:SetPushedTexture(v)
    SetStateTexture(self, "_pushedTex", v, "ARTWORK", true)
  end
  function Button:SetHighlightTexture(v)
    SetStateTexture(self, "_highlightTex", v, "HIGHLIGHT", true)
  end
  function Button:SetDisabledTexture(v)
    SetStateTexture(self, "_disabledTex", v, "ARTWORK", true)
  end
  function Button:SetNormalAtlas(a)
    SetStateTexture(self, "_normalTex", nil, "ARTWORK", false):SetAtlas(a)
  end
  function Button:SetPushedAtlas(a)
    SetStateTexture(self, "_pushedTex", nil, "ARTWORK", true):SetAtlas(a)
  end
  function Button:SetHighlightAtlas(a)
    SetStateTexture(self, "_highlightTex", nil, "HIGHLIGHT", true):SetAtlas(a)
  end
  function Button:SetDisabledAtlas(a)
    SetStateTexture(self, "_disabledTex", nil, "ARTWORK", true):SetAtlas(a)
  end
  function Button:GetNormalTexture()
    return self._normalTex or SetStateTexture(self, "_normalTex", nil, "ARTWORK", false)
  end
  function Button:GetPushedTexture()
    return self._pushedTex or SetStateTexture(self, "_pushedTex", nil, "ARTWORK", true)
  end
  function Button:GetHighlightTexture()
    return self._highlightTex or SetStateTexture(self, "_highlightTex", nil, "HIGHLIGHT", true)
  end
  function Button:GetDisabledTexture()
    return self._disabledTex or SetStateTexture(self, "_disabledTex", nil, "ARTWORK", true)
  end
  function Button:RegisterForClicks() end
  function Button:RegisterForMouse() end
  function Button:Enable()
    self._disabled = false
  end
  function Button:Disable()
    self._disabled = true
  end
  function Button:SetEnabled(v)
    self._disabled = not v
  end
  function Button:IsEnabled()
    return self._disabled ~= true
  end
  function Button:SetButtonState(state)
    self._buttonState = state
  end
  function Button:GetButtonState()
    return self._buttonState or "NORMAL"
  end
  function Button:LockHighlight() end
  function Button:UnlockHighlight() end
  function Button:SetMotionScriptsWhileDisabled() end
  function Button:Click(button)
    local fn = self:GetScript("OnClick")
    if fn and self._disabled ~= true then
      SafeCall(fn, self, button or "LeftButton", false)
    end
  end

  local CheckButton = setmetatable({}, { __index = Button })
  function CheckButton:SetChecked(v)
    self._checked = v and true or false
  end
  function CheckButton:GetChecked()
    return self._checked == true
  end
  function CheckButton:SetCheckedTexture(v)
    SetStateTexture(self, "_checkedTex", v, "OVERLAY", false)
  end
  function CheckButton:GetCheckedTexture()
    return self._checkedTex or SetStateTexture(self, "_checkedTex", nil, "OVERLAY", false)
  end
  function CheckButton:SetDisabledCheckedTexture() end
  M.Button = Button
  M.EnsureButtonText = EnsureButtonText
  M.SetStateTexture = SetStateTexture
  M.CheckButton = CheckButton
end

local function DefineWidgetTypes(engine, M)
  local clock = M.clock
  local SafeCall = M.SafeCall
  local methodsByType = M.methodsByType
  local Texture = M.Texture
  local FontInstance = M.FontInstance
  local FontString = M.FontString
  local Frame = M.Frame
  local Button = M.Button
  local SetStateTexture = M.SetStateTexture
  local CheckButton = M.CheckButton
  ---------------------------------------------------------------------------
  -- StatusBar / Slider / Cooldown / EditBox / ScrollFrame / tooltips
  ---------------------------------------------------------------------------
  local StatusBar = setmetatable({}, { __index = Frame })
  function StatusBar:SetMinMaxValues(min, max)
    self._min, self._max = tonumber(min) or 0, tonumber(max) or 1
  end
  function StatusBar:GetMinMaxValues()
    return self._min or 0, self._max or 1
  end
  function StatusBar:SetValue(v)
    self._value = tonumber(v) or 0
    local cb = self:GetScript("OnValueChanged")
    if cb then
      SafeCall(cb, self, self._value, false)
    end
  end
  function StatusBar:GetValue()
    return self._value or 0
  end
  function StatusBar:SetStatusBarTexture(v)
    if type(v) == "table" then
      self._barTex = v
    else
      self._barTex = self._barTex or engine.CreateRegion("Texture", self, nil, "ARTWORK")
      self._barTex:SetTexture(v)
    end
  end
  function StatusBar:GetStatusBarTexture()
    if not self._barTex then
      self:SetStatusBarTexture(nil)
    end
    return self._barTex
  end
  function StatusBar:SetStatusBarColor(r, g, b, a)
    self._barColor = CopyColor(r, g, b, a)
  end
  function StatusBar:GetStatusBarColor()
    local c = self._barColor or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4]
  end
  function StatusBar:SetOrientation(o)
    self._orientation = o
  end
  function StatusBar:SetReverseFill(v)
    self._reverse = v
  end
  function StatusBar:SetFillStyle() end
  function StatusBar:SetRotatesTexture() end
  function StatusBar:SetTimerDuration() end
  function StatusBar:SetToTargetValue() end

  local Slider = setmetatable({}, { __index = StatusBar })
  function Slider:SetValueStep(s)
    self._step = s
  end
  function Slider:GetValueStep()
    return self._step or 1
  end
  function Slider:SetObeyStepOnDrag() end
  function Slider:SetThumbTexture(v)
    SetStateTexture(self, "_thumbTex", v, "OVERLAY", false)
  end
  function Slider:GetThumbTexture()
    return self._thumbTex or SetStateTexture(self, "_thumbTex", nil, "OVERLAY", false)
  end
  function Slider:SetStepsPerPage() end
  function Slider:Enable()
    self._disabled = false
  end
  function Slider:Disable()
    self._disabled = true
  end
  function Slider:SetEnabled(v)
    self._disabled = not v
  end
  function Slider:IsEnabled()
    return self._disabled ~= true
  end

  local Cooldown = setmetatable({}, { __index = Frame })
  function Cooldown:SetCooldown(start, duration)
    self._cdStart, self._cdDuration = tonumber(start) or 0, tonumber(duration) or 0
  end
  function Cooldown:SetCooldownDuration(duration)
    self._cdStart, self._cdDuration = clock.now(), tonumber(duration) or 0
  end
  function Cooldown:SetCooldownFromDurationObject(obj)
    self._cdDurationObject = obj
  end
  function Cooldown:GetCooldownTimes()
    return (self._cdStart or 0) * 1000, (self._cdDuration or 0) * 1000
  end
  function Cooldown:GetCooldownDuration()
    return (self._cdDuration or 0) * 1000
  end
  function Cooldown:Clear()
    self._cdStart, self._cdDuration = 0, 0
  end
  function Cooldown:SetDrawBling() end
  function Cooldown:SetDrawEdge() end
  function Cooldown:SetDrawSwipe() end
  function Cooldown:SetSwipeColor() end
  function Cooldown:SetSwipeTexture() end
  function Cooldown:SetReverse() end
  function Cooldown:SetHideCountdownNumbers() end
  function Cooldown:SetCountdownFont() end
  function Cooldown:SetUseCircularEdge() end
  function Cooldown:Pause() end
  function Cooldown:Resume() end

  local EditBox = setmetatable({}, { __index = Frame })
  for k, v in pairs(FontInstance) do
    EditBox[k] = v
  end
  function EditBox:SetText(t)
    self._text = tostring(t or "")
    local cb = self:GetScript("OnTextChanged")
    if cb then
      SafeCall(cb, self, false)
    end
  end
  function EditBox:GetText()
    return self._text or ""
  end
  function EditBox:Insert(t)
    self:SetText((self._text or "") .. tostring(t or ""))
  end
  function EditBox:GetNumber()
    return tonumber(self._text) or 0
  end
  function EditBox:SetNumber(n)
    self:SetText(tostring(n))
  end
  function EditBox:SetAutoFocus() end
  function EditBox:SetFocus()
    self._focus = true
  end
  function EditBox:ClearFocus()
    self._focus = false
  end
  function EditBox:HasFocus()
    return self._focus == true
  end
  function EditBox:HighlightText() end
  function EditBox:SetMaxLetters() end
  function EditBox:SetMaxBytes() end
  function EditBox:SetMultiLine(v)
    self._multiLine = v
  end
  function EditBox:IsMultiLine()
    return self._multiLine == true
  end
  function EditBox:SetNumeric() end
  function EditBox:SetTextInsets() end
  function EditBox:SetCursorPosition() end
  function EditBox:GetCursorPosition()
    return 0
  end
  function EditBox:Enable()
    self._disabled = false
  end
  function EditBox:Disable()
    self._disabled = true
  end
  function EditBox:SetEnabled(v)
    self._disabled = not v
  end
  function EditBox:IsEnabled()
    return self._disabled ~= true
  end
  function EditBox:AddHistoryLine() end
  function EditBox:SetCountInvisibleLetters() end

  local ScrollFrame = setmetatable({}, { __index = Frame })
  function ScrollFrame:SetScrollChild(child)
    self._scrollChild = child
    if child then
      child:SetParent(self)
      if not next(child._points or {}) then
        child:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
      end
    end
  end
  function ScrollFrame:GetScrollChild()
    return self._scrollChild
  end
  function ScrollFrame:SetVerticalScroll(v)
    self._vscroll = v
  end
  function ScrollFrame:GetVerticalScroll()
    return self._vscroll or 0
  end
  function ScrollFrame:SetHorizontalScroll(v)
    self._hscroll = v
  end
  function ScrollFrame:GetHorizontalScroll()
    return self._hscroll or 0
  end
  function ScrollFrame:GetVerticalScrollRange()
    return 0
  end
  function ScrollFrame:GetHorizontalScrollRange()
    return 0
  end
  function ScrollFrame:UpdateScrollChildRect() end

  local GameTooltip = setmetatable({}, { __index = Frame })
  function GameTooltip:SetOwner(owner, anchor, x, y)
    self._owner = owner
    self._lines = {}
    self:ClearAllPoints()
    if owner then
      self:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", x or 0, y or 0)
    end
  end
  function GameTooltip:GetOwner()
    return self._owner
  end
  function GameTooltip:IsOwned(owner)
    return self._owner == owner
  end
  local function TooltipLine(self, left, right, r, g, b)
    self._lines = self._lines or {}
    local index = #self._lines + 1
    local fs = engine.CreateRegion("FontString", self, nil, "ARTWORK")
    fs._font = { path = FONT_DEFAULT_PATH, size = index == 1 and 14 or 12, flags = "" }
    fs:SetText(left)
    fs:SetTextColor(r or 1, g or 1, b or 1, 1)
    fs:SetJustifyH("LEFT")
    self._lines[index] = { left = fs, right = right }
    local y = -10
    for i = 1, index - 1 do
      y = y - (i == 1 and 18 or 15)
    end
    fs:SetPoint("TOPLEFT", self, "TOPLEFT", 10, y)
    local width = 20
    for _, line in ipairs(self._lines) do
      width = math.max(width, line.left:GetStringWidth() + 20 + (line.right and 60 or 0))
    end
    self:SetSize(width, -y + 22)
  end
  function GameTooltip:SetText(text, r, g, b)
    for _, line in ipairs(self._lines or {}) do
      line.left:Hide()
    end
    self._lines = {}
    TooltipLine(self, text, nil, r, g, b)
  end
  function GameTooltip:AddLine(text, r, g, b)
    TooltipLine(self, text, nil, r, g, b)
  end
  function GameTooltip:AddDoubleLine(left, right, r, g, b)
    TooltipLine(self, tostring(left or "") .. "    " .. tostring(right or ""), right, r, g, b)
  end
  function GameTooltip:ClearLines()
    for _, line in ipairs(self._lines or {}) do
      line.left:Hide()
    end
    self._lines = {}
  end
  function GameTooltip:NumLines()
    return #(self._lines or {})
  end
  function GameTooltip:SetMinimumWidth() end
  function GameTooltip:SetPadding() end
  function GameTooltip:AddTexture() end
  function GameTooltip:SetUnit() end
  function GameTooltip:SetSpellByID() end
  function GameTooltip:SetItemByID() end
  function GameTooltip:SetHyperlink() end
  function GameTooltip:FadeOut()
    self:Hide()
  end

  local MessageFrame = setmetatable({}, { __index = Frame })
  for k, v in pairs(FontInstance) do
    MessageFrame[k] = v
  end
  function MessageFrame:AddMessage(text)
    self._messages = self._messages or {}
    self._messages[#self._messages + 1] = tostring(text)
    if engine.onChatFrameMessage then
      engine.onChatFrameMessage(self, text)
    end
  end
  function MessageFrame:Clear()
    self._messages = {}
  end
  function MessageFrame:GetNumMessages()
    return #(self._messages or {})
  end
  function MessageFrame:SetMaxLines() end
  function MessageFrame:SetFading() end
  function MessageFrame:SetTimeVisible() end
  function MessageFrame:SetFadeDuration() end
  function MessageFrame:SetInsertMode() end
  function MessageFrame:ScrollToBottom() end
  function MessageFrame:SetIndentedWordWrap() end

  methodsByType.Texture = Texture
  methodsByType.MaskTexture = Texture
  methodsByType.Line = Texture
  methodsByType.FontString = FontString
  methodsByType.Frame = Frame
  methodsByType.Button = Button
  methodsByType.CheckButton = CheckButton
  methodsByType.StatusBar = StatusBar
  methodsByType.Slider = Slider
  methodsByType.Cooldown = Cooldown
  methodsByType.EditBox = EditBox
  methodsByType.ScrollFrame = ScrollFrame
  methodsByType.GameTooltip = GameTooltip
  methodsByType.MessageFrame = MessageFrame
  methodsByType.ScrollingMessageFrame = MessageFrame
  methodsByType.SimpleHTML = MessageFrame
  methodsByType.ColorSelect = Frame
  methodsByType.Model = Frame
  methodsByType.PlayerModel = Frame
  methodsByType.ModelScene = Frame
  methodsByType.DropdownButton = Button
  methodsByType.ItemButton = Button
  engine.methodsByType = methodsByType
  engine.FontInstance = FontInstance
  M.StatusBar = StatusBar
  M.Slider = Slider
  M.Cooldown = Cooldown
  M.EditBox = EditBox
  M.ScrollFrame = ScrollFrame
  M.GameTooltip = GameTooltip
  M.TooltipLine = TooltipLine
  M.MessageFrame = MessageFrame
end

local function DefineCreation(engine, M)
  local env = M.env
  local onUnknownMethod = M.onUnknownMethod
  local methodsByType = M.methodsByType
  local MakeObject = M.MakeObject
  local Texture = M.Texture
  local Frame = M.Frame
  ---------------------------------------------------------------------------
  -- Creation
  ---------------------------------------------------------------------------
  local function Publish(obj, name, parent)
    if type(name) ~= "string" or name == "" then
      return
    end
    if name:find("$parent", 1, true) then
      local parentName = parent and parent._name or ""
      name = name:gsub("%$parent", parentName)
    end
    obj._name = name
    engine.byName[name] = obj
    if env then
      rawset(env, name, obj)
    end
  end

  function engine.CreateRegion(regionType, parent, name, layer, sublevel)
    local methods = methodsByType[regionType] or Texture
    local region = MakeObject(regionType, methods)
    region._layer = layer or "ARTWORK"
    region._sublevel = tonumber(sublevel) or 0
    region._isRegion = true
    if regionType == "FontString" then
      region._textColor = { 1, 0.82, 0, 1 }
    end
    engine.all[#engine.all + 1] = region
    Publish(region, name, parent)
    if parent then
      region:SetParent(parent)
    end
    return region
  end

  local templateHandlers = {}
  function engine.RegisterTemplate(name, fn)
    templateHandlers[name] = fn
  end

  function engine.CreateFrame(frameType, name, parent, template, id)
    frameType = frameType or "Frame"
    local methods = methodsByType[frameType]
    if not methods then
      onUnknownMethod("CreateFrame", frameType)
      methods = Frame
    end
    if type(parent) == "string" then
      parent = engine.byName[parent]
    end
    local frame = MakeObject(frameType, methods)
    frame._isFrame = true
    frame._children = {}
    engine.all[#engine.all + 1] = frame
    Publish(frame, name, parent)
    if parent then
      frame:SetParent(parent)
    end
    if id then
      frame._idValue = id
    end
    if type(template) == "string" then
      for tpl in template:gmatch("[^,%s]+") do
        local handler = templateHandlers[tpl]
        if handler then
          handler(frame)
        end
      end
    end
    return frame
  end
  M.Publish = Publish
  M.templateHandlers = templateHandlers
end

local function DefineAnimations(engine, M)
  local clock = M.clock
  local SafeCall = M.SafeCall
  local MakeObject = M.MakeObject
  ---------------------------------------------------------------------------
  -- Animations (time-based on the simulated clock)
  ---------------------------------------------------------------------------
  local AnimationGroup = {}
  local Animation = {}

  function AnimationGroup:CreateAnimation(animType, name)
    local anim = MakeObject("Animation", Animation)
    anim._animType = animType or "Animation"
    anim._group = self
    anim._duration = 0
    anim._delay = 0
    anim._order = 1
    self._anims[#self._anims + 1] = anim
    return anim
  end
  function AnimationGroup:GetAnimations()
    return unpack(self._anims)
  end
  function AnimationGroup:SetScript(name, fn)
    self._scripts[name] = fn
  end
  function AnimationGroup:GetScript(name)
    return self._scripts[name]
  end
  function AnimationGroup:HookScript(name, fn)
    local existing = self._scripts[name]
    self._scripts[name] = existing and function(...)
      existing(...)
      fn(...)
    end or fn
  end
  function AnimationGroup:SetLooping(mode)
    self._looping = mode
  end
  function AnimationGroup:GetLooping()
    return self._looping or "NONE"
  end
  function AnimationGroup:SetToFinalAlpha(v)
    self._toFinalAlpha = v
  end
  function AnimationGroup:GetDuration()
    local total = 0
    for _, a in ipairs(self._anims) do
      total = math.max(total, (a._delay or 0) + (a._duration or 0) + (a._endDelay or 0))
    end
    return total
  end
  function AnimationGroup:Play()
    self._playing = true
    self._startedAt = clock.now()
    self._token = (self._token or 0) + 1
    local token = self._token
    local onPlay = self._scripts.OnPlay
    if onPlay then
      SafeCall(onPlay, self)
    end
    if self._looping and self._looping ~= "NONE" then
      return
    end
    clock.after(self:GetDuration(), function()
      if self._token ~= token or not self._playing then
        return
      end
      self._playing = false
      if self._toFinalAlpha then
        for _, a in ipairs(self._anims) do
          if a._animType == "Alpha" and a._toAlpha and self._owner then
            local target = a._target or self._owner
            target:SetAlpha(a._toAlpha)
          end
        end
      end
      local onFinished = self._scripts.OnFinished
      if onFinished then
        SafeCall(onFinished, self, false)
      end
    end)
  end
  function AnimationGroup:Stop()
    if self._playing then
      self._playing = false
      self._token = (self._token or 0) + 1
      local onStop = self._scripts.OnStop
      if onStop then
        SafeCall(onStop, self)
      end
    end
  end
  function AnimationGroup:Finish()
    self:Stop()
  end
  function AnimationGroup:Pause()
    self._playing = false
  end
  function AnimationGroup:Restart()
    self:Stop()
    self:Play()
  end
  function AnimationGroup:IsPlaying()
    return self._playing == true
  end
  function AnimationGroup:IsPaused()
    return false
  end
  function AnimationGroup:IsDone()
    return not self._playing
  end
  function AnimationGroup:GetProgress()
    if not self._playing then
      return 0
    end
    local d = self:GetDuration()
    return d > 0 and math.min(1, (clock.now() - self._startedAt) / d) or 1
  end
  function AnimationGroup:GetParent()
    return self._owner
  end
  function AnimationGroup:GetElapsed()
    return self._playing and (clock.now() - self._startedAt) or 0
  end

  function Animation:SetDuration(d)
    self._duration = tonumber(d) or 0
  end
  function Animation:GetDuration()
    return self._duration
  end
  function Animation:SetStartDelay(d)
    self._delay = tonumber(d) or 0
  end
  function Animation:GetStartDelay()
    return self._delay
  end
  function Animation:SetEndDelay(d)
    self._endDelay = tonumber(d) or 0
  end
  function Animation:SetOrder(o)
    self._order = o
  end
  function Animation:SetFromAlpha(a)
    self._fromAlpha = a
  end
  function Animation:SetToAlpha(a)
    self._toAlpha = a
  end
  function Animation:SetTarget(t)
    self._target = t
  end
  function Animation:SetChildKey() end
  function Animation:SetTargetKey() end
  function Animation:SetSmoothing() end
  function Animation:SetOffset() end
  function Animation:SetScale() end
  function Animation:SetScaleFrom() end
  function Animation:SetScaleTo() end
  function Animation:SetOrigin() end
  function Animation:SetDegrees() end
  function Animation:SetScript(name, fn)
    self._scripts = self._scripts or {}
    self._scripts[name] = fn
  end
  function Animation:GetScript(name)
    return self._scripts and self._scripts[name]
  end
  function Animation:GetParent()
    return self._group
  end
  function Animation:GetRegionParent()
    return self._group._owner
  end
  function Animation:Play()
    self._group:Play()
  end
  function Animation:Stop()
    self._group:Stop()
  end
  function Animation:IsPlaying()
    return self._group:IsPlaying()
  end
  function Animation:GetProgress()
    return self._group:GetProgress()
  end
  function Animation:GetSmoothProgress()
    return self._group:GetProgress()
  end

  function engine.CreateAnimationGroup(owner, name)
    local group = MakeObject("AnimationGroup", AnimationGroup)
    group._owner = owner
    group._anims = {}
    group._scripts = {}
    owner._animGroups = owner._animGroups or {}
    owner._animGroups[#owner._animGroups + 1] = group
    return group
  end
  M.AnimationGroup = AnimationGroup
  M.Animation = Animation
end

local function DefineVisibility(engine, M)
  local SafeCall = M.SafeCall
  ---------------------------------------------------------------------------
  -- Visibility propagation (OnShow / OnHide)
  ---------------------------------------------------------------------------
  function engine.PropagateVisibility(root)
    local function Walk(obj)
      local visible = obj:IsVisible()
      if obj._isFrame and visible ~= (obj._wasVisible == true) then
        obj._wasVisible = visible
        local cb = obj._scripts and obj._scripts[visible and "OnShow" or "OnHide"]
        if cb then
          SafeCall(cb, obj)
        end
      elseif not obj._isFrame then
        obj._wasVisible = visible
      end
      for _, child in ipairs(obj._children or {}) do
        Walk(child)
      end
    end
    Walk(root)
  end
end

local function DefineLayoutAndSnapshot(engine, M)
  local screenW = M.screenW
  local screenH = M.screenH
  local SafeCall = M.SafeCall
  ---------------------------------------------------------------------------
  -- Layout: anchor resolution to absolute screen rectangles
  ---------------------------------------------------------------------------
  function engine.EffectiveScale(obj)
    local s = 1
    local f = obj
    while f do
      if f._isFrame or f == obj then
        s = s * (f._scale or 1)
      end
      if f._ignoreParentScale then
        break
      end
      f = f._parent
    end
    return s
  end

  local resolveCache = nil
  local resolving = {}

  local function IntrinsicSize(obj)
    local w, h = obj._w, obj._h
    if obj._type == "FontString" then
      local _, size = obj:GetFont()
      if not w or w == 0 then
        w = EstimateTextWidth(obj._text, size)
      end
      if not h or h == 0 then
        h = CountLines(obj._text) * (size or 12) * 1.15
      end
    end
    return w, h
  end

  -- Returns { left, bottom, w, h } in screen pixels (WoW origin bottom-left)
  -- or nil when the anchors do not define a valid rectangle.
  function engine.ResolveRect(obj)
    if obj == engine.UIParent or obj == engine.WorldFrame then
      return { left = 0, bottom = 0, w = screenW, h = screenH }
    end
    if resolveCache and resolveCache[obj] ~= nil then
      return resolveCache[obj] or nil
    end
    if resolving[obj] then
      return nil -- anchor cycle
    end
    local points = obj._points
    if not points or next(points) == nil then
      if resolveCache then
        resolveCache[obj] = false
      end
      return nil
    end
    resolving[obj] = true
    local scale = engine.EffectiveScale(obj)
    local xs, ys = {}, {}
    for _, p in pairs(points) do
      local rel = p.relTo or obj._parent or engine.UIParent
      local relRect = engine.ResolveRect(rel)
      if relRect then
        local rf = POINT_FACTORS[p.relPoint] or POINT_FACTORS.CENTER
        local pf = POINT_FACTORS[p.point] or POINT_FACTORS.CENTER
        local ax = relRect.left + relRect.w * rf[1] + p.x * scale
        local ay = relRect.bottom + relRect.h * rf[2] + p.y * scale
        xs[#xs + 1] = { f = pf[1], v = ax }
        ys[#ys + 1] = { f = pf[2], v = ay }
      end
    end
    resolving[obj] = nil
    local iw, ih = IntrinsicSize(obj)
    local function Axis(list, intrinsic)
      if #list == 0 then
        return nil
      end
      local minF, maxF = list[1], list[1]
      for _, e in ipairs(list) do
        if e.f < minF.f then
          minF = e
        end
        if e.f > maxF.f then
          maxF = e
        end
      end
      if maxF.f > minF.f then
        local size = (maxF.v - minF.v) / (maxF.f - minF.f)
        return minF.v - size * minF.f, size
      end
      local size = (intrinsic or 0) * scale
      return minF.v - size * minF.f, size
    end
    local left, w = Axis(xs, iw)
    local bottom, h = Axis(ys, ih)
    local rect = nil
    if left and bottom then
      rect = { left = left, bottom = bottom, w = w, h = h }
    end
    if resolveCache then
      resolveCache[obj] = rect or false
    end
    return rect
  end

  ---------------------------------------------------------------------------
  -- Ticking and events
  ---------------------------------------------------------------------------
  function engine.RunOnUpdate(elapsed)
    for _, obj in ipairs(engine.all) do
      local fn = obj._isFrame and obj._scripts and obj._scripts.OnUpdate
      if fn and obj:IsVisible() then
        SafeCall(fn, obj, elapsed)
      end
    end
  end

  local function UnitMatches(reg, ...)
    if reg == true then
      return true
    end
    local unit = ...
    return type(unit) == "string" and reg[unit] == true
  end

  function engine.FireEvent(event, ...)
    local targets = {}
    for _, obj in ipairs(engine.all) do
      if obj._events then
        local reg = obj._events[event]
        if reg and UnitMatches(reg, ...) then
          targets[#targets + 1] = obj
        end
      end
    end
    for _, obj in ipairs(targets) do
      local fn = obj._scripts and obj._scripts.OnEvent
      if fn then
        SafeCall(fn, obj, event, ...)
      end
    end
    return #targets
  end

  ---------------------------------------------------------------------------
  -- Snapshot
  ---------------------------------------------------------------------------
  local function OwnerFrame(obj)
    local f = obj
    while f and not f._isFrame do
      f = f._parent
    end
    return f
  end

  -- Intersection of the rects of all clipping ancestors (ScrollFrames always
  -- clip their scroll child; other frames clip with SetClipsChildren(true)).
  -- Returns nil when nothing clips, false when the clip area is empty.
  local function ClipRect(obj)
    local clip = nil
    local f = obj._parent
    while f do
      if f._type == "ScrollFrame" or f._clips then
        local r = engine.ResolveRect(f)
        if r then
          if not clip then
            clip = { left = r.left, bottom = r.bottom, right = r.left + r.w, top = r.bottom + r.h }
          else
            clip.left = math.max(clip.left, r.left)
            clip.bottom = math.max(clip.bottom, r.bottom)
            clip.right = math.min(clip.right, r.left + r.w)
            clip.top = math.min(clip.top, r.bottom + r.h)
          end
        end
      end
      f = f._parent
    end
    if clip and (clip.right <= clip.left or clip.top <= clip.bottom) then
      return false
    end
    return clip
  end

  local function Round1(v)
    return math.floor(v * 10 + 0.5) / 10
  end

  function engine.Snapshot()
    resolveCache = {}
    local out = {}
    for _, obj in ipairs(engine.all) do
      if obj ~= engine.UIParent and obj._type ~= "AnimationGroup" and not obj._isMask then
        local hiddenState = obj._stateHidden == true
        if
          not hiddenState and obj:IsVisible() and obj._type ~= "GameTooltip"
          or (obj._type == "GameTooltip" and obj:IsVisible() and obj._owner)
        then
          local rect = engine.ResolveRect(obj)
          local alpha = obj:GetEffectiveAlpha()
          local clip = rect and ClipRect(obj)
          if clip then
            local outside = rect.left >= clip.right
              or rect.left + rect.w <= clip.left
              or rect.bottom >= clip.top
              or rect.bottom + rect.h <= clip.bottom
            if outside then
              clip = false
            end
          end
          if rect and rect.w > 0 and rect.h > 0 and alpha > 0.001 and clip ~= false then
            local owner = OwnerFrame(obj)
            local entry = {
              id = obj._id,
              parent = obj._parent and obj._parent ~= engine.UIParent and obj._parent._id or nil,
              name = obj._name,
              type = obj._type,
              x = math.floor(rect.left * 10 + 0.5) / 10,
              y = math.floor((screenH - rect.bottom - rect.h) * 10 + 0.5) / 10,
              w = math.floor(rect.w * 10 + 0.5) / 10,
              h = math.floor(rect.h * 10 + 0.5) / 10,
              strata = owner and owner:GetFrameStrata() or "MEDIUM",
              level = owner and owner:GetFrameLevel() or 0,
              alpha = math.floor(alpha * 1000 + 0.5) / 1000,
            }
            if clip then
              entry.clip = {
                Round1(clip.left),
                Round1(screenH - clip.top),
                Round1(clip.right - clip.left),
                Round1(clip.top - clip.bottom),
              }
            end
            if not obj._isFrame then
              entry.layer = obj._layer or "ARTWORK"
              entry.sublevel = obj._sublevel or 0
            end
            if obj._isFrame and obj._backdrop then
              entry.bg = obj._backdrop.bgFile and (obj._bg or { 1, 1, 1, 1 }) or nil
              entry.border = obj._backdrop.edgeFile and (obj._border or { 1, 1, 1, 1 }) or nil
              entry.edge = obj._backdrop.edgeSize
            end
            if obj._type == "Texture" or obj._type == "Line" then
              if obj._tex == nil and obj._texColor == nil and obj._atlas == nil then
                entry = nil -- empty texture renders nothing
              else
                entry.tex = {
                  path = obj._tex,
                  color = obj._texColor,
                  vertex = obj._vertex,
                  coords = obj._coords,
                  atlas = obj._atlas,
                  desaturated = obj._desaturated or nil,
                }
              end
            elseif obj._type == "FontString" then
              if obj._text == nil or obj._text == "" then
                entry = nil
              else
                local path, size, flags = obj:GetFont()
                entry.text = {
                  s = obj._text,
                  size = size,
                  color = obj._textColor,
                  h = obj._justifyH or "CENTER",
                  v = obj._justifyV or "MIDDLE",
                  flags = flags,
                  font = path,
                  wrap = obj._wrap ~= false,
                }
              end
            elseif obj._type == "StatusBar" then
              entry.bar = {
                min = obj._min or 0,
                max = obj._max or 1,
                value = obj._value or 0,
                color = obj._barColor or (obj._barTex and obj._barTex._vertex) or { 1, 1, 1, 1 },
              }
            elseif obj._type == "EditBox" and obj._text and obj._text ~= "" then
              local path, size, flags = obj:GetFont()
              entry.text = {
                s = obj._text,
                size = size,
                color = obj._textColor,
                h = "LEFT",
                v = "MIDDLE",
                flags = flags,
                font = path,
              }
            end
            if entry then
              out[#out + 1] = entry
            end
          end
        end
      end
    end
    resolveCache = nil
    return out
  end
  M.resolveCache = resolveCache
  M.resolving = resolving
  M.IntrinsicSize = IntrinsicSize
  M.UnitMatches = UnitMatches
  M.OwnerFrame = OwnerFrame
  M.ClipRect = ClipRect
  M.Round1 = Round1
end

function Widgets.New(opts)
  opts = opts or {}
  local clock = assert(opts.clock, "widgets: clock required")
  local onUnknownMethod = opts.onUnknownMethod or function(...) end
  local onScriptError = opts.onScriptError or function(...) end
  local screenW = opts.screenW or 1920
  local screenH = opts.screenH or 1080

  local engine = {
    all = {}, -- every widget ever created, in creation order
    byName = {}, -- global names
    eventFrames = {}, -- frame -> true for frames with registered events
    nextId = 1,
    fontObjects = {},
  }

  local env = opts.env -- client global table; named frames are published there

  local function SafeCall(fn, ...)
    local ok, err = Compat.XCall(fn, ...)
    if not ok then
      onScriptError(err)
    end
    return ok
  end

  ---------------------------------------------------------------------------
  -- Base object with the method catch-all
  ---------------------------------------------------------------------------
  local methodsByType = {}

  local function MakeObject(objectType, methods)
    local obj = { _type = objectType, _id = engine.nextId }
    engine.nextId = engine.nextId + 1
    setmetatable(obj, {
      __index = function(t, key)
        local m = methods[key]
        if m ~= nil then
          return m
        end
        -- Unknown PascalCase widget method: record it and hand back a no-op
        -- returning nil, so a missing API surfaces in the report instead of
        -- crashing the composition. Fields (lowercase / _prefixed) stay nil.
        if type(key) == "string" and key:match("^[A-Z]") then
          onUnknownMethod(objectType, key)
          local fn = function() end
          rawset(t, key, fn)
          return fn
        end
        return nil
      end,
    })
    return obj
  end

  local M = {
    clock = clock,
    env = env,
    onUnknownMethod = onUnknownMethod,
    onScriptError = onScriptError,
    screenW = screenW,
    screenH = screenH,
    SafeCall = SafeCall,
    methodsByType = methodsByType,
    MakeObject = MakeObject,
  }
  DefineRegion(engine, M)
  DefineTexture(engine, M)
  DefineFonts(engine, M)
  DefineFrame(engine, M)
  DefineButtons(engine, M)
  DefineWidgetTypes(engine, M)
  DefineCreation(engine, M)
  DefineAnimations(engine, M)
  DefineVisibility(engine, M)
  DefineLayoutAndSnapshot(engine, M)

  -- Root frames
  local uiParent = engine.CreateFrame("Frame", "UIParent", nil)
  uiParent._strata = "MEDIUM"
  engine.UIParent = uiParent
  local worldFrame = engine.CreateFrame("Frame", "WorldFrame", nil)
  engine.WorldFrame = worldFrame
  engine.screenW, engine.screenH = screenW, screenH
  engine.StripEscapes = StripEscapes
  engine.STRATA_ORDER = STRATA_ORDER

  return engine
end

return Widgets
