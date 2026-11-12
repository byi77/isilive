---@diagnostic disable: undefined-global

-- Simulated widget layer for the show/hide motion and card stack scenarios
-- (rule 242): frames keep parent, anchors, alpha and mouse state; animation
-- groups run on a simulated clock (world.Advance) and fire OnFinished like
-- the client; a protected frame raises on every call the client blocks in
-- combat and records it in world.violations.

local Unpack = rawget(_G, "unpack") or rawget(table, "unpack")

local function NewWorld()
  local world = { now = 0, inCombat = false, groups = {}, violations = {}, frames = {} }

  local function Blocked(frame, method)
    if world.inCombat and frame._protected then
      world.violations[#world.violations + 1] = method
      error("ADDON_ACTION_BLOCKED: " .. method .. " on a protected frame in combat")
    end
  end

  local function OrderedDuration(anims)
    local byOrder = {}
    for _, anim in ipairs(anims) do
      local order = anim._order or 1
      byOrder[order] = math.max(byOrder[order] or 0, anim._duration or 0)
    end
    local total, starts = 0, {}
    local orders = {}
    for order in pairs(byOrder) do
      orders[#orders + 1] = order
    end
    table.sort(orders)
    for _, order in ipairs(orders) do
      starts[order] = total
      total = total + byOrder[order]
    end
    return total, starts
  end

  local function NewAnimationGroup(owner)
    local group = { _anims = {}, _scripts = {}, _playing = false, _owner = owner, plays = 0 }
    function group:CreateAnimation(kind)
      local anim = { _kind = kind, _group = self, _order = 1, _duration = 0 }
      function anim:SetOrder(order)
        self._order = order
      end
      function anim:SetDuration(duration)
        self._duration = duration
      end
      function anim:SetFromAlpha(value)
        self._from = value
      end
      function anim:SetToAlpha(value)
        self._to = value
      end
      function anim:SetOffset(x, y)
        self._offset = { x, y }
      end
      function anim:SetSmoothing(value)
        self._smoothing = value
      end
      function anim:GetSmoothProgress()
        local g = self._group
        if not g._playing then
          return 0
        end
        local _, starts = OrderedDuration(g._anims)
        local elapsed = world.now - g._startedAt - (starts[self._order] or 0)
        if (self._duration or 0) <= 0 then
          return elapsed >= 0 and 1 or 0
        end
        return math.max(0, math.min(1, elapsed / self._duration))
      end
      self._anims[#self._anims + 1] = anim
      return anim
    end
    function group:SetScript(name, fn)
      self._scripts[name] = fn
    end
    function group:SetToFinalAlpha() end
    function group:Play()
      self._playing = true
      self._startedAt = world.now
      self.plays = self.plays + 1
    end
    function group:Stop()
      self._playing = false
    end
    function group:IsPlaying()
      return self._playing
    end
    function group:Find(kind, order)
      for _, anim in ipairs(self._anims) do
        if anim._kind == kind and (order == nil or anim._order == order) then
          return anim
        end
      end
      return nil
    end
    world.groups[#world.groups + 1] = group
    return group
  end

  -- Simulated time: every group whose duration has passed finishes.
  function world.Advance(seconds)
    world.now = world.now + seconds
    for _ = 1, 20 do
      local finished = false
      for _, group in ipairs(world.groups) do
        if group._playing then
          local total = OrderedDuration(group._anims)
          if world.now - group._startedAt >= total - 1e-9 then
            group._playing = false
            finished = true
            if group._owner and group:Find("Alpha") and group:Find("Alpha")._to then
              group._owner._alpha = group:Find("Alpha")._to
            end
            local onFinished = group._scripts.OnFinished
            if onFinished then
              onFinished(group)
            end
          end
        end
      end
      if not finished then
        return
      end
    end
  end

  local Region = {}
  local function NewRegion(kind, parent)
    local region = {
      _kind = kind,
      _parent = parent,
      _shown = true,
      _alpha = 1,
      _points = {},
      _scripts = {},
      _width = 0,
      _height = 0,
    }
    return setmetatable(region, {
      __index = function(_, key)
        local method = Region[key]
        if method then
          return method
        end
        -- Every other widget method is a harmless no-op.
        if type(key) == "string" and key:match("^%u") then
          return function() end
        end
        return nil
      end,
    })
  end

  function Region:SetPoint(point, relativeTo, relativePoint, x, y)
    Blocked(self, "SetPoint")
    self._points[#self._points + 1] = { point, relativeTo, relativePoint, x or 0, y or 0 }
  end
  function Region:ClearAllPoints()
    Blocked(self, "ClearAllPoints")
    self._points = {}
  end
  function Region:GetPoint(index)
    local p = self._points[index or 1]
    if not p then
      return nil
    end
    return p[1], p[2], p[3], p[4], p[5]
  end
  function Region:Show()
    Blocked(self, "Show")
    self._shown = true
    local onShow = self._scripts.OnShow
    if onShow then
      onShow(self)
    end
  end
  function Region:Hide()
    Blocked(self, "Hide")
    local wasShown = self._shown
    self._shown = false
    local onHide = self._scripts.OnHide
    if wasShown and onHide then
      onHide(self)
    end
  end
  function Region:IsShown()
    return self._shown == true
  end
  function Region:SetAlpha(alpha)
    self._alpha = alpha
  end
  function Region:GetAlpha()
    return self._alpha
  end
  function Region:SetSize(width, height)
    self._width, self._height = width, height
  end
  function Region:SetWidth(width)
    self._width = width
  end
  function Region:SetHeight(height)
    self._height = height
  end
  function Region:GetWidth()
    return self._width
  end
  function Region:GetHeight()
    return self._height
  end
  function Region:EnableMouse(enabled)
    Blocked(self, "EnableMouse")
    self._mouse = enabled == true
  end
  function Region:IsMouseEnabled()
    return self._mouse == true
  end
  function Region:IsProtected()
    return self._protected == true, self._protected == true
  end
  function Region:SetScript(name, fn)
    self._scripts[name] = fn
  end
  function Region:GetScript(name)
    return self._scripts[name]
  end
  function Region:HookScript(name, fn)
    local previous = self._scripts[name]
    self._scripts[name] = previous and function(...)
      previous(...)
      fn(...)
    end or fn
  end
  function Region:SetParent(parent)
    Blocked(self, "SetParent")
    local old = self._parent
    if old and old._children then
      for index, child in ipairs(old._children) do
        if child == self then
          table.remove(old._children, index)
          break
        end
      end
    end
    self._parent = parent
    if parent then
      parent._children = parent._children or {}
      parent._children[#parent._children + 1] = self
    end
  end
  function Region:GetParent()
    return self._parent
  end
  function Region:GetChildren()
    return Unpack(self._children or {})
  end
  function Region:SetFrameStrata(strata)
    self._strata = strata
  end
  function Region:GetFrameStrata()
    return self._strata or "MEDIUM"
  end
  function Region:SetFrameLevel(level)
    self._level = level
  end
  function Region:GetFrameLevel()
    return self._level or 1
  end
  function Region:StartMoving()
    self._moving = (self._moving or 0) + 1
  end
  function Region:CreateAnimationGroup()
    local group = NewAnimationGroup(self)
    self._groups = self._groups or {}
    self._groups[#self._groups + 1] = group
    return group
  end
  function Region:CreateTexture()
    return NewRegion("Texture", self)
  end
  function Region:CreateFontString()
    local fs = NewRegion("FontString", self)
    fs._size = 14
    function fs.SetText(target, text)
      target._text = text
    end
    function fs.GetText(target)
      return target._text
    end
    function fs.GetFont(target)
      return "Fonts\\FRIZQT__.TTF", target._size, ""
    end
    function fs.SetFont(target, _path, size)
      target._size = size
    end
    function fs.GetStringHeight()
      return 14
    end
    function fs.GetStringWidth()
      return 60
    end
    function fs.SetTextColor(target, r, g, b, a)
      target._color = { r, g, b, a }
    end
    function fs.GetTextColor(target)
      local c = target._color or { 1, 1, 1, 1 }
      return c[1], c[2], c[3], c[4]
    end
    return fs
  end
  function Region:SetBackdrop(backdrop)
    self._backdrop = backdrop
  end
  function Region:SetBackdropColor(r, g, b, a)
    self._backdropColor = { r, g, b, a }
  end

  function world.CreateFrame(kind, name, parent, template)
    local frame = NewRegion(kind or "Frame", nil)
    frame._name = name
    frame._template = template
    frame._shown = true
    if parent then
      frame:SetParent(parent)
    end
    if type(template) == "string" and template:find("SecureActionButtonTemplate", 1, true) then
      -- A secure child makes the whole parent chain protected.
      local current = frame
      while current do
        current._protected = true
        current = current._parent
      end
    end
    world.frames[#world.frames + 1] = frame
    if name then
      world.named = world.named or {}
      world.named[name] = frame
    end
    return frame
  end

  world.UIParent = NewRegion("Frame", nil)
  world.UIParent._width, world.UIParent._height = 1920, 1080
  return world
end

local function Globals(world, extra)
  local globals = {
    UIParent = world.UIParent,
    CreateFrame = world.CreateFrame,
    GetTime = function()
      return world.now
    end,
    InCombatLockdown = function()
      return world.inCombat
    end,
    IsiLiveDB = {},
  }
  for key, value in pairs(extra or {}) do
    globals[key] = value
  end
  return globals
end

local function AlphaAnim(frame)
  local group = frame._groups and frame._groups[1]
  return group and group:Find("Alpha") or nil, group
end

return {
  NewWorld = NewWorld,
  Globals = Globals,
  AlphaAnim = AlphaAnim,
}
