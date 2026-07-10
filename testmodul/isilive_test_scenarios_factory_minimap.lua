---@diagnostic disable: undefined-global

-- Scenarios for factory/isiLive_factory_minimap.lua.
-- The module creates a draggable minimap button with a left-click toggle
-- and a right-click Blizzard-Settings opener. Tests exercise the public
-- entry point FI.CreateFactoryMinimapButton(ctx) under several stub
-- environments: Minimap missing, default angle resolution, drag-stop
-- angle recalc, click routing, tooltip lifecycle, and the
-- PLAYER_LOGIN-driven initial visibility.

local function NewTextureStub()
  local texture = {}
  function texture:SetSize(_w, _h) end
  function texture:SetTexture(_path) end
  function texture:SetPoint(_anchor, _rel, _x, _y) end
  return texture
end

local function NewButtonStub()
  local btn = {
    scripts = {},
    textures = {},
    points = {},
    shown = false,
    dragButtons = nil,
    clickButtons = nil,
  }
  function btn:SetSize(_w, _h) end
  function btn:SetFrameStrata(_s) end
  function btn:SetFrameLevel(_l) end
  function btn:SetPoint(anchor, rel, arg3, arg4, arg5)
    -- WoW SetPoint has two forms: (anchor, x, y) and (anchor, relFrame, relAnchor, x, y).
    -- The minimap button uses the five-arg form; capture both shapes.
    local x, y
    if arg5 ~= nil then
      x, y = arg4, arg5
    else
      x, y = arg3, arg4
    end
    self.points[#self.points + 1] = { anchor = anchor, rel = rel, x = x, y = y }
  end
  function btn:CreateTexture(_name, _layer)
    local t = NewTextureStub()
    self.textures[#self.textures + 1] = t
    return t
  end
  function btn:RegisterForDrag(buttons)
    self.dragButtons = buttons
  end
  function btn:RegisterForClicks(a, b)
    self.clickButtons = { a, b }
  end
  function btn:SetScript(name, fn)
    self.scripts[name] = fn
  end
  function btn:Show()
    self.shown = true
  end
  function btn:Hide()
    self.shown = false
  end
  return btn
end

local function NewEventFrameStub(state)
  local frame = {
    registered = {},
  }
  function frame:RegisterEvent(event)
    self.registered[event] = true
  end
  function frame:UnregisterEvent(event)
    self.registered[event] = nil
  end
  function frame:SetScript(name, fn)
    if name == "OnEvent" then
      state.loginHandler = fn
    end
    self[name] = fn
  end
  return frame
end

local function NewMinimapStub()
  return {
    isMinimap = true,
    GetCenter = function()
      return 500, 300
    end,
    GetEffectiveScale = function()
      return 1
    end,
  }
end

local function NewGameTooltipStub(state)
  return {
    SetOwner = function(self, _owner, _anchor)
      state.tooltipOwner = true
    end,
    AddLine = function(self, text, _r, _g, _b)
      state.tooltipLines = state.tooltipLines or {}
      state.tooltipLines[#state.tooltipLines + 1] = text
    end,
    Show = function()
      state.tooltipShown = true
    end,
    Hide = function()
      state.tooltipShown = false
    end,
  }
end

local function BuildMinimapEnv(overrides)
  overrides = overrides or {}
  local state = {
    createdButton = nil,
    createdEventFrames = {},
  }

  -- Lua 5.4 dropped math.atan2. WoW ships Lua 5.1 where it exists, but the
  -- local dev Lua may be 5.4. Ensure the code path can resolve the symbol
  -- regardless of host interpreter version. The Sumneko WoW-API annotation
  -- declares math.atan2 as a single-arg function (and math.atan as
  -- single-arg), so we install the polyfill via rawset to sidestep the
  -- duplicate-set-field diagnostic, and compute atan2 from atan(y/x) with
  -- explicit quadrant handling so the single-arg math.atan matches both
  -- Lua 5.1 (one arg) and the Sumneko annotation.
  if type(rawget(math, "atan2")) ~= "function" then
    rawset(math, "atan2", function(y, x)
      if x == 0 then
        if y > 0 then
          return math.pi / 2
        elseif y < 0 then
          return -math.pi / 2
        end
        return 0
      end
      local base = math.atan(y / x)
      if x < 0 then
        return y >= 0 and base + math.pi or base - math.pi
      end
      return base
    end)
  end

  -- `false` (not nil) is used to disable Minimap, because ctx.with_globals
  -- iterates stubs via pairs() which skips nil entries and therefore
  -- would not reset _G.Minimap between scenarios. A ternary via `a and b or c`
  -- cannot return false (false is falsy and the `or` branch wins), so
  -- resolve with an explicit branch.
  local minimapStub
  if overrides.Minimap == false then
    minimapStub = false
  else
    minimapStub = NewMinimapStub()
  end
  local globals = {
    Minimap = minimapStub,
    CreateFrame = function(kind, _name, _parent)
      if kind == "Button" then
        local btn = NewButtonStub()
        state.createdButton = btn
        return btn
      end
      local frame = NewEventFrameStub(state)
      state.createdEventFrames[#state.createdEventFrames + 1] = frame
      return frame
    end,
    IsiLiveDB = overrides.IsiLiveDB or { showMinimapButton = true },
    GetCursorPosition = overrides.GetCursorPosition or function()
      return 600, 400
    end,
    GameTooltip = NewGameTooltipStub(state),
    Settings = overrides.Settings or nil,
  }

  if overrides.globals then
    for k, v in pairs(overrides.globals) do
      globals[k] = v
    end
  end

  return globals, state
end

-- Creates the minimap button and optionally runs a callback still inside the
-- WithGlobals block. All button scripts (OnClick, OnEnter, OnDragStop, the
-- PLAYER_LOGIN handler) call WoW APIs (IsiLiveDB, GameTooltip, Settings) at
-- trigger time, so triggering them must happen while the stubs are live.
-- `trigger(btn, state)` runs after creation and within the stub scope.
local function LoadAndCreate(ctx, globals, ctxOverrides, trigger)
  local addonTable
  local btn
  ctx.with_globals(globals, function()
    addonTable = ctx.load_modules({ "isiLive_factory_minimap.lua" })
    local FI = addonTable._FactoryInternal
    local factoryCtx = {
      runtimeLogController = nil,
      settingsPanel = nil,
      ToggleMainFrameVisibility = function()
        ctxOverrides.toggled = (ctxOverrides.toggled or 0) + 1
      end,
    }
    if ctxOverrides.ctx then
      for k, v in pairs(ctxOverrides.ctx) do
        factoryCtx[k] = v
      end
    end
    btn = FI.CreateFactoryMinimapButton(factoryCtx)
    if trigger and btn ~= nil then
      trigger(btn, ctxOverrides.state)
    end
  end)
  return btn, addonTable
end

local function Register(test, ctx)
  local Assert = ctx.assert

  test("factory_minimap: returns nil when Minimap global is absent", function()
    local globals = BuildMinimapEnv({ Minimap = false })
    local btn, _ = LoadAndCreate(ctx, globals, {})
    Assert.Nil(btn, "must short-circuit when Minimap frame is unavailable")
  end)

  test("factory_minimap: creates button with drag + click registrations", function()
    local globals, state = BuildMinimapEnv()
    local btn = LoadAndCreate(ctx, globals, {})
    Assert.NotNil(btn, "button must be created when Minimap exists")
    Assert.Equal(btn.dragButtons, "LeftButton", "RegisterForDrag must be wired for LeftButton")
    Assert.NotNil(btn.clickButtons, "RegisterForClicks must be wired")
    Assert.Equal(btn.clickButtons[1], "LeftButtonUp", "click registration must include LeftButtonUp")
    Assert.Equal(btn.clickButtons[2], "RightButtonUp", "click registration must include RightButtonUp")
    Assert.NotNil(btn.scripts["OnDragStart"], "OnDragStart must be wired")
    Assert.NotNil(btn.scripts["OnDragStop"], "OnDragStop must be wired")
    Assert.Nil(btn.scripts["OnUpdate"], "idle minimap button must not retain an OnUpdate handler")
    Assert.NotNil(btn.scripts["OnClick"], "OnClick must be wired")
    Assert.NotNil(btn.scripts["OnEnter"], "OnEnter must be wired for tooltip")
    Assert.NotNil(btn.scripts["OnLeave"], "OnLeave must be wired for tooltip hide")
    Assert.True(#btn.textures >= 3, "button must create overlay + background + icon textures")
    Assert.NotNil(state.loginHandler, "a PLAYER_LOGIN handler must be registered")
  end)

  test("factory_minimap: uses IsiLiveDB.minimapAngle when available", function()
    local globals, state = BuildMinimapEnv({ IsiLiveDB = { minimapAngle = 90, showMinimapButton = true } })
    local btn = LoadAndCreate(ctx, globals, {})
    Assert.True(#btn.points >= 1, "SetPoint must have been called to place the button")
    local lastPoint = btn.points[#btn.points]
    Assert.Equal(lastPoint.anchor, "CENTER", "placement anchor must be CENTER")
    -- angle=90deg => cos=0, sin=1 => x≈0, y≈radius(80)
    Assert.True(math.abs(lastPoint.x) < 1, "x offset must be ~0 for 90deg angle")
    Assert.True(lastPoint.y > 75 and lastPoint.y < 85, "y offset must be ~80 for 90deg angle")
  end)

  test("factory_minimap: drag stop recomputes angle and persists to IsiLiveDB", function()
    local db = { minimapAngle = 0, showMinimapButton = true }
    local globals = BuildMinimapEnv({
      IsiLiveDB = db,
      GetCursorPosition = function()
        return 500, 400
      end,
    })
    LoadAndCreate(ctx, globals, {}, function(btn)
      btn.scripts["OnDragStart"](btn)
      btn.scripts["OnDragStop"](btn)
    end)
    Assert.True(
      math.abs(db.minimapAngle - 90) < 0.5,
      "cursor directly above minimap center must produce angle ~= 90deg"
    )
  end)

  test("factory_minimap: OnUpdate exists only during an active drag", function()
    local globals = BuildMinimapEnv()
    LoadAndCreate(ctx, globals, {}, function(btn)
      Assert.Nil(btn.scripts["OnUpdate"], "idle button must not poll")
      btn.scripts["OnDragStart"](btn)
      Assert.Equal(type(btn.scripts["OnUpdate"]), "function", "drag start must install live tracking")
      btn.scripts["OnUpdate"](btn, 0.016)
      btn.scripts["OnDragStop"](btn)
      Assert.Nil(btn.scripts["OnUpdate"], "drag stop must remove live tracking")
    end)
  end)

  test("factory_minimap: left-click toggles main frame visibility", function()
    local globals = BuildMinimapEnv()
    local captured = {}
    LoadAndCreate(ctx, globals, {
      ctx = {
        ToggleMainFrameVisibility = function()
          captured.toggled = (captured.toggled or 0) + 1
        end,
      },
    }, function(btn)
      btn.scripts["OnClick"](btn, "LeftButton")
    end)
    Assert.Equal(captured.toggled, 1, "left-click must trigger exactly one toggle")
  end)

  test("factory_minimap: right-click opens Blizzard Settings when category exists", function()
    local opens = {}
    local globals = BuildMinimapEnv({
      Settings = {
        OpenToCategory = function(id)
          opens[#opens + 1] = id
        end,
      },
    })
    LoadAndCreate(ctx, globals, {
      ctx = { settingsPanel = { category = { ID = "isiLive-category-id" } } },
    }, function(btn)
      btn.scripts["OnClick"](btn, "RightButton")
    end)
    Assert.Equal(#opens, 1, "right-click must open Settings exactly once")
    Assert.Equal(opens[1], "isiLive-category-id", "settings opener must receive isiLive category id")
  end)

  test("factory_minimap: right-click is a no-op when Settings global is missing", function()
    local globals = BuildMinimapEnv({ Settings = nil })
    -- Must not throw; no-op is the contract.
    LoadAndCreate(ctx, globals, {}, function(btn)
      btn.scripts["OnClick"](btn, "RightButton")
    end)
  end)

  test("factory_minimap: OnEnter populates tooltip and OnLeave hides it", function()
    local globals, state = BuildMinimapEnv()
    LoadAndCreate(ctx, globals, {
      ctx = {
        GetL = function()
          return {
            TOOLTIP_MINIMAP_TOGGLE_WINDOW = "Linksklick: Fenster ein- oder ausblenden.",
            TOOLTIP_MINIMAP_OPEN_SETTINGS = "Rechtsklick: Einstellungen oeffnen.",
          }
        end,
      },
    }, function(btn)
      btn.scripts["OnEnter"](btn)
    end)
    Assert.Equal(state.tooltipShown, true, "tooltip must be shown on enter")
    Assert.NotNil(state.tooltipLines, "tooltip lines must be populated")
    Assert.True(#state.tooltipLines >= 3, "tooltip must contain title + left-click + right-click hints")
    Assert.Equal(
      state.tooltipLines[2],
      "Linksklick: Fenster ein- oder ausblenden.",
      "tooltip must use the localized left-click hint"
    )
    Assert.Equal(
      state.tooltipLines[3],
      "Rechtsklick: Einstellungen oeffnen.",
      "tooltip must use the localized right-click settings hint"
    )

    local globals2, state2 = BuildMinimapEnv()
    LoadAndCreate(ctx, globals2, {}, function(btn)
      btn.scripts["OnEnter"](btn)
      btn.scripts["OnLeave"](btn)
    end)
    Assert.Equal(state2.tooltipShown, false, "tooltip must be hidden on leave")
  end)

  test("factory_minimap: click emits runtime log line when logf is wired", function()
    local globals = BuildMinimapEnv()
    local lines = {}
    LoadAndCreate(ctx, globals, {
      ctx = {
        runtimeLogController = {
          Logf = function(fmt, ...)
            lines[#lines + 1] = string.format(fmt, ...)
          end,
        },
      },
    }, function(btn)
      btn.scripts["OnClick"](btn, "LeftButton")
    end)
    Assert.Equal(#lines, 1, "one log line must be emitted on click")
    Assert.True(string.find(lines[1], "minimap", 1, true) ~= nil, "log line must mention the minimap button")
    Assert.True(string.find(lines[1], "LeftButton", 1, true) ~= nil, "log line must include the mouse button")
  end)

  test("factory_minimap: PLAYER_LOGIN handler shows button when showMinimapButton is true", function()
    local globals, state = BuildMinimapEnv({ IsiLiveDB = { showMinimapButton = true } })
    local buttonShown
    LoadAndCreate(ctx, globals, {}, function(btn)
      state.loginHandler(state.createdEventFrames[1])
      buttonShown = btn.shown
    end)
    Assert.Equal(buttonShown, true, "button must be shown when SavedVariable flag is set")
  end)

  test("factory_minimap: PLAYER_LOGIN handler hides button when showMinimapButton is false", function()
    local globals, state = BuildMinimapEnv({ IsiLiveDB = { showMinimapButton = false } })
    local buttonShown
    LoadAndCreate(ctx, globals, {}, function(btn)
      state.loginHandler(state.createdEventFrames[1])
      buttonShown = btn.shown
    end)
    Assert.Equal(buttonShown, false, "button must be hidden when SavedVariable flag is false")
  end)
end

return Register
