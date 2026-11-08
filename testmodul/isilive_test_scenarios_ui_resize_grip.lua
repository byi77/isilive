---@diagnostic disable: undefined-global

-- Resize grip in the bottom-right corner of the main window
-- (ui/isiLive_ui_main_frame.lua, CreateResizeGrip).
--
-- Every test drives the real UI.CreateMainFrame and the grip's own scripts
-- (OnMouseDown / OnUpdate / OnMouseUp / OnDoubleClick) with a mocked
-- GetCursorPosition. The combat tests additionally route
-- PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED through the real
-- ControllerWiring.CreateEventHandlersController config into the real
-- EventHandlers dispatcher, so the wiring of EndResizeForCombat and the
-- post-combat ApplyPendingGeometry drain is covered end to end.
--
-- The frame stub models real anchor geometry (GetLeft / GetTop follow the
-- anchor, its offsets and SetScale), because "the top-left corner stays put"
-- is only observable through that math. UIParent runs at effective scale
-- 0.75, so the cursor pixels must be converted into UIParent units.

local UIPARENT_WIDTH = 1920
local UIPARENT_HEIGHT = 1080
local UIPARENT_EFFECTIVE_SCALE = 0.75
local MAIN_FRAME_WIDTH = 755
local EPSILON = 0.001

local function Noop() end

local function AnchorFractions(point)
  point = point or "CENTER"
  local fx = 0.5
  local fy = 0.5
  if point:find("LEFT", 1, true) then
    fx = 0
  elseif point:find("RIGHT", 1, true) then
    fx = 1
  end
  if point:find("TOP", 1, true) then
    fy = 1
  elseif point:find("BOTTOM", 1, true) then
    fy = 0
  end
  return fx, fy
end

local function CreateTextureStub()
  return setmetatable({}, {
    __index = function()
      return Noop
    end,
  })
end

local CreateFrameStub

-- Explicit geometry and state methods; every other widget call (backdrop,
-- fonts, cosmetic textures) falls through to a no-op.
local function BuildFrameMethods()
  local methods = {}

  function methods:SetSize(w, h)
    self._width = w
    self._height = h
  end
  function methods:SetWidth(w)
    self._width = w
  end
  function methods:SetHeight(h)
    self._height = h
  end
  function methods:GetWidth()
    return self._width
  end
  function methods:GetHeight()
    return self._height
  end
  function methods:SetScale(scale)
    self._setScaleCalls = self._setScaleCalls + 1
    if self._protectedInCombat and self._isInCombat and self._isInCombat() then
      self._blockedCalls = self._blockedCalls + 1
      return
    end
    self._scale = scale
  end
  function methods:GetScale()
    return self._scale
  end
  function methods:GetEffectiveScale()
    local parentScale = self._parent and self._parent:GetEffectiveScale() or 1
    return parentScale * self._scale
  end
  function methods:SetPoint(point, relativeTo, relativePoint, x, y)
    if type(relativeTo) ~= "table" then
      -- SetPoint("CENTER") / SetPoint("CENTER", x, y) shorthand.
      x, y = relativeTo, relativePoint
      relativeTo, relativePoint = self._parent, point
    end
    self._point = { point, relativeTo, relativePoint or point, tonumber(x) or 0, tonumber(y) or 0 }
  end
  function methods:GetPoint()
    if not self._point then
      return nil
    end
    return self._point[1], self._point[2], self._point[3], self._point[4], self._point[5]
  end
  function methods:ClearAllPoints()
    self._point = nil
  end
  -- Edges in the frame's own (scaled) units, like the client.
  local function Edges(self)
    if self._isRoot then
      return 0, 0, self._width, self._height
    end
    local anchor = self._point
    local parent = self._parent
    if not anchor or not parent then
      return nil
    end
    local pLeft, pBottom, pWidth, pHeight = Edges(parent)
    if not pLeft then
      return nil
    end
    local rfx, rfy = AnchorFractions(anchor[3])
    local fx, fy = AnchorFractions(anchor[1])
    local s = self._scale
    local px = (pLeft + rfx * pWidth) / s + anchor[4]
    local py = (pBottom + rfy * pHeight) / s + anchor[5]
    local left = px - fx * self._width
    local bottom = py - fy * self._height
    return left, bottom, self._width, self._height
  end
  function methods:GetLeft()
    local left = Edges(self)
    return left
  end
  function methods:GetTop()
    local _, bottom, _, height = Edges(self)
    if not bottom then
      return nil
    end
    return bottom + height
  end
  function methods:SetFrameStrata(strata)
    self._frameStrata = strata
  end
  function methods:GetFrameStrata()
    return self._frameStrata
  end
  function methods:SetFrameLevel(level)
    self._frameLevel = level
  end
  function methods:GetFrameLevel()
    return self._frameLevel
  end
  function methods:SetMovable(flag)
    self._movable = flag == true
  end
  function methods:EnableMouse(flag)
    self._mouseEnabled = flag == true
  end
  function methods:Show()
    self._shown = true
  end
  function methods:Hide()
    local wasShown = self._shown
    self._shown = false
    local onHide = self._scripts.OnHide
    if wasShown and onHide then
      onHide(self)
    end
  end
  function methods:IsShown()
    return self._shown == true
  end
  function methods:SetAlpha(alpha)
    self._alpha = alpha
  end
  function methods:GetAlpha()
    return self._alpha
  end
  function methods:SetScript(name, fn)
    self._scripts[name] = fn
  end
  function methods:GetScript(name)
    return self._scripts[name]
  end
  function methods:HookScript(name, fn)
    self._scripts[name] = fn
  end
  function methods:SetNormalTexture(path)
    self._normalTexturePath = path
  end
  function methods:GetNormalTexture()
    self._normalTexture = self._normalTexture or CreateTextureStub()
    return self._normalTexture
  end
  function methods:CreateTexture()
    return CreateTextureStub()
  end
  function methods:CreateFontString()
    return CreateTextureStub()
  end
  return methods
end

local FRAME_METHODS = BuildFrameMethods()

CreateFrameStub = function(_frameType, _name, parent)
  local frame = {
    _scripts = {},
    _shown = false,
    _parent = parent,
    _width = 100,
    _height = 100,
    _scale = 1,
    _alpha = 1,
    _frameStrata = "MEDIUM",
    _frameLevel = 1,
    _setScaleCalls = 0,
    _blockedCalls = 0,
  }
  return setmetatable(frame, {
    __index = function(_, key)
      local method = FRAME_METHODS[key]
      if method then
        return method
      end
      if type(key) == "string" and key:sub(1, 1) ~= "_" then
        return Noop
      end
      return nil
    end,
  })
end

local function BuildUIParent()
  local uiParent = CreateFrameStub("Frame", "UIParent", nil)
  uiParent._isRoot = true
  uiParent._shown = true
  uiParent:SetSize(UIPARENT_WIDTH, UIPARENT_HEIGHT)
  function uiParent:GetEffectiveScale()
    return UIPARENT_EFFECTIVE_SCALE
  end
  return uiParent
end

-- One isolated world per test: real main frame, mocked cursor, own DB.
local function BuildWorld(opts)
  opts = opts or {}
  local world = {
    inCombat = false,
    locked = opts.locked == true,
    cursorX = 1000,
    cursorY = 500,
    committed = {},
    db = { uiScale = 1.0 },
  }
  world.uiParent = BuildUIParent()
  world.globals = {
    UIParent = world.uiParent,
    CreateFrame = CreateFrameStub,
    IsiLiveDB = world.db,
    InCombatLockdown = function()
      return world.inCombat
    end,
    GetCursorPosition = function()
      return world.cursorX, world.cursorY
    end,
    GameTooltip = {
      SetOwner = Noop,
      AddLine = Noop,
      Show = Noop,
      Hide = Noop,
    },
  }
  return world
end

local function CreateMainUI(addon, world)
  local mainUI = addon.UI.CreateMainFrame({
    parent = world.uiParent,
    minHeight = 236,
    isInCombat = function()
      return world.inCombat
    end,
    isDragLocked = function()
      return world.locked
    end,
    onScaleCommitted = function(scale)
      world.committed[#world.committed + 1] = scale
    end,
  })
  local frame = mainUI.frame
  -- The main frame parents secure buttons in production: SetScale during
  -- lockdown is blocked and counted instead of applied.
  frame._protectedInCombat = true
  frame._isInCombat = function()
    return world.inCombat
  end
  frame:SetSize(MAIN_FRAME_WIDTH, 236)
  mainUI.ApplyStoredPosition({ point = "CENTER", relativePoint = "CENTER", x = 120, y = -40 })
  frame:Show()
  return mainUI
end

-- Top-left corner in UIParent units.
local function TopLeft(frame)
  local scale = frame:GetScale()
  return frame:GetLeft() * scale, frame:GetTop() * scale
end

-- Pixel travel that makes the drag formula land on `targetScale`.
local function PixelsForScale(startScale, targetScale)
  local startWidth = MAIN_FRAME_WIDTH * startScale
  local travel = startWidth * (targetScale / startScale - 1)
  return travel * UIPARENT_EFFECTIVE_SCALE
end

local function Press(grip)
  grip:GetScript("OnMouseDown")(grip, "LeftButton")
end

local function Move(world, grip, pixels)
  world.cursorX = world.cursorX + pixels
  local onUpdate = grip:GetScript("OnUpdate")
  if onUpdate then
    onUpdate(grip, 0.016)
  end
end

local function Release(grip)
  grip:GetScript("OnMouseUp")(grip, "LeftButton")
end

local function AssertNear(actual, expected, message)
  if type(actual) ~= "number" or math.abs(actual - expected) > EPSILON then
    error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
  end
end

local function BuildWiringDeps(mainUI, world)
  return {
    addonName = "isiLive",
    isRosterCollapsed = Noop,
    showCombatAnnounce = Noop,
    defaultLocale = "enUS",
    locales = { enUS = {} },
    resolveLocaleTag = Noop,
    setLocaleTable = Noop,
    isInGroup = Noop,
    isInChallengeMode = Noop,
    isNegativeApplicationStatusEvent = Noop,
    getNormalizedActiveEntryInfo = Noop,
    sendIsiLiveHello = Noop,
    sendOwnKeySnapshot = Noop,
    sendOwnBackgroundSnapshot = Noop,
    sendRefreshResponse = Noop,
    ensureQueueDebugStorage = Noop,
    setQueueDebugEnabled = Noop,
    registerIsiLiveSyncPrefix = Noop,
    applyHotkeyBindings = Noop,
    startBindingWatchdog = Noop,
    getUnitNameAndRealm = Noop,
    markIsiLiveUser = Noop,
    applyKnownKeyToRosterEntry = Noop,
    runFullRefresh = Noop,
    isInCombat = function()
      return world.inCombat
    end,
    state = {
      isTestMode = Noop,
      isTestAllMode = Noop,
      setPendingQueueJoinInfo = Noop,
      setPendingPostChallengeRefresh = Noop,
      getActiveJoinedKeyMapID = Noop,
      setActiveJoinedKeyMapID = Noop,
      getPendingBindingApply = Noop,
      getRoster = function()
        return {}
      end,
    },
    refs = {
      mainFrame = mainUI.frame,
      mainUI = mainUI,
      applySecureSpellToButton = Noop,
    },
    controllers = {
      group = { HandleGroupRosterUpdate = Noop },
    },
    callbacks = {
      exitTestMode = Noop,
      clearLatestQueueTarget = Noop,
      updateMPlusTeleportButton = Noop,
      captureQueueJoinCandidate = Noop,
      updateUI = Noop,
      refreshReadyCheckUI = Noop,
      setMainFrameVisible = Noop,
      updateLeaderButtons = Noop,
      updateStatusLine = Noop,
      applyLocalizationToUI = Noop,
      restoreLayoutState = Noop,
      updateCountdownCancelButton = Noop,
      checkIfEnteredTargetDungeon = Noop,
      setMainFrameHeightSafe = mainUI.SetHeightSafe,
      setMainFrameWidthSafe = mainUI.SetWidthSafe,
    },
    modules = {
      sync = {
        ProcessAddonMessage = Noop,
        GetPrefix = function()
          return "ISILIVE"
        end,
        IsUserKnown = function()
          return false
        end,
      },
    },
  }
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function LoadMainFrameAddon()
    return LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
  end

  test("Resize grip sits in the bottom-right corner above the content", function()
    local world = BuildWorld()
    WithGlobals(world.globals, function()
      local mainUI = CreateMainUI(LoadMainFrameAddon(), world)
      local grip = mainUI.resizeGrip
      Assert.NotNil(grip, "main UI must expose the resize grip")
      local point, relativeTo, relativePoint = grip:GetPoint()
      Assert.Equal(point, "BOTTOMRIGHT", "grip anchors with its bottom-right corner")
      Assert.True(relativeTo == mainUI.frame, "grip anchors to the main frame")
      Assert.Equal(relativePoint, "BOTTOMRIGHT", "grip sits in the frame's bottom-right corner")
      Assert.True(grip:GetFrameLevel() > mainUI.frame:GetFrameLevel(), "grip is raised above the frame content")
      Assert.True(grip:IsShown(), "unlocked frame shows the grip")
      Assert.True(
        tostring(grip._normalTexturePath):find("UI%-ChatIM%-SizeGrabber%-Up") ~= nil,
        "grip uses the Blizzard size-grabber texture"
      )
    end)
  end)

  test("Resize grip drag right scales live, rounds on release and keeps the top-left corner", function()
    local world = BuildWorld()
    WithGlobals(world.globals, function()
      local mainUI = CreateMainUI(LoadMainFrameAddon(), world)
      local frame = mainUI.frame
      local grip = mainUI.resizeGrip
      local left0, top0 = TopLeft(frame)

      Press(grip)
      Assert.True(mainUI.IsResizing(), "mouse down on the grip starts a resize")
      Move(world, grip, PixelsForScale(1.0, 1.23))
      AssertNear(frame:GetScale(), 1.23, "the window follows the mouse live")
      local liveLeft, liveTop = TopLeft(frame)
      AssertNear(liveLeft, left0, "top-left x stays put while dragging")
      AssertNear(liveTop, top0, "top-left y stays put while dragging")
      Assert.Equal(world.db.uiScale, 1.0, "no SavedVariables write on a mouse move")
      Assert.Nil(world.db.position, "no position write on a mouse move")
      Assert.Equal(#world.committed, 0, "settings are not refreshed on a mouse move")

      Release(grip)
      Assert.False(mainUI.IsResizing(), "mouse up ends the resize")
      AssertNear(frame:GetScale(), 1.25, "release rounds to the 0.05 slider step")
      Assert.Equal(world.db.uiScale, 1.25, "release persists the rounded scale")
      local left1, top1 = TopLeft(frame)
      AssertNear(left1, left0, "top-left x unchanged after release")
      AssertNear(top1, top0, "top-left y unchanged after release")
      Assert.NotNil(world.db.position, "release saves the position")
      Assert.Equal(world.db.position.point, "TOPLEFT", "the saved anchor is the fixed top-left corner")
      Assert.Equal(#world.committed, 1, "the settings panel is refreshed once")
      Assert.Equal(world.committed[1], 1.25, "the committed value reaches the settings refresh")
    end)
  end)

  test("Resize grip drag left shrinks and clamps to the 50 % minimum", function()
    local world = BuildWorld()
    WithGlobals(world.globals, function()
      local mainUI = CreateMainUI(LoadMainFrameAddon(), world)
      local frame = mainUI.frame
      local grip = mainUI.resizeGrip
      local left0, top0 = TopLeft(frame)

      Press(grip)
      Move(world, grip, PixelsForScale(1.0, 0.82))
      AssertNear(frame:GetScale(), 0.82, "dragging left shrinks the window live")
      Release(grip)
      Assert.Equal(world.db.uiScale, 0.8, "0.82 rounds to 0.80")

      Press(grip)
      Move(world, grip, -5000)
      AssertNear(frame:GetScale(), 0.5, "a far drag left clamps to 0.5")
      Release(grip)
      Assert.Equal(world.db.uiScale, 0.5, "the clamped minimum is persisted")
      local left1, top1 = TopLeft(frame)
      AssertNear(left1, left0, "top-left x unchanged after shrinking")
      AssertNear(top1, top0, "top-left y unchanged after shrinking")
    end)
  end)

  test("Resize grip drag right clamps to the 200 % maximum", function()
    local world = BuildWorld()
    WithGlobals(world.globals, function()
      local mainUI = CreateMainUI(LoadMainFrameAddon(), world)
      local grip = mainUI.resizeGrip
      Press(grip)
      Move(world, grip, 5000)
      AssertNear(mainUI.frame:GetScale(), 2.0, "a far drag right clamps to 2.0")
      Release(grip)
      Assert.Equal(world.db.uiScale, 2.0, "the clamped maximum is persisted")
    end)
  end)

  test("Resize grip click without mouse travel writes nothing and keeps the anchor", function()
    local world = BuildWorld()
    WithGlobals(world.globals, function()
      local mainUI = CreateMainUI(LoadMainFrameAddon(), world)
      local grip = mainUI.resizeGrip
      Press(grip)
      Move(world, grip, 0)
      Release(grip)
      Assert.Nil(world.db.position, "a plain click saves no position")
      Assert.Equal(#world.committed, 0, "a plain click commits nothing")
      Assert.Equal((mainUI.frame:GetPoint()), "CENTER", "a plain click keeps the CENTER anchor")
    end)
  end)

  test("Resize grip double-click resets to 100 % and keeps the top-left corner", function()
    local world = BuildWorld()
    WithGlobals(world.globals, function()
      local mainUI = CreateMainUI(LoadMainFrameAddon(), world)
      local frame = mainUI.frame
      local grip = mainUI.resizeGrip
      Press(grip)
      Move(world, grip, PixelsForScale(1.0, 1.6))
      Release(grip)
      Assert.Equal(world.db.uiScale, 1.6, "setup: dragged to 160 %")
      local left0, top0 = TopLeft(frame)

      -- Client order of a double-click: down, up, down, up, OnDoubleClick.
      Press(grip)
      Release(grip)
      Press(grip)
      Release(grip)
      grip:GetScript("OnDoubleClick")(grip, "LeftButton")
      AssertNear(frame:GetScale(), 1.0, "double-click returns to scale 1.0")
      Assert.Equal(world.db.uiScale, 1.0, "double-click persists 1.0")
      local left1, top1 = TopLeft(frame)
      AssertNear(left1, left0, "top-left x unchanged after the reset")
      AssertNear(top1, top0, "top-left y unchanged after the reset")
      Assert.Equal(world.committed[#world.committed], 1.0, "the reset refreshes the settings slider")
    end)
  end)

  test("Resize grip is hidden while the window position is locked", function()
    local world = BuildWorld({ locked = true })
    WithGlobals(world.globals, function()
      local mainUI = CreateMainUI(LoadMainFrameAddon(), world)
      local grip = mainUI.resizeGrip
      Assert.False(grip:IsShown(), "locked frame hides the grip")
      Press(grip)
      Assert.False(mainUI.IsResizing(), "a locked grip does not start a resize")
      grip:GetScript("OnDoubleClick")(grip, "LeftButton")
      Assert.Equal(#world.committed, 0, "a locked grip ignores double-click")

      mainUI.SetDragLocked(false)
      Assert.True(grip:IsShown(), "unlocking shows the grip")
      Press(grip)
      Move(world, grip, PixelsForScale(1.0, 1.4))
      mainUI.SetDragLocked(true)
      Assert.False(grip:IsShown(), "locking hides the grip again")
      Assert.False(mainUI.IsResizing(), "locking ends a running resize")
      Assert.Equal(world.db.uiScale, 1.4, "the interrupted resize still commits its value")
    end)
  end)

  test("Resize grip does not start a drag during combat lockdown", function()
    local world = BuildWorld()
    WithGlobals(world.globals, function()
      local mainUI = CreateMainUI(LoadMainFrameAddon(), world)
      local frame = mainUI.frame
      local grip = mainUI.resizeGrip
      world.inCombat = true
      local setScaleCalls = frame._setScaleCalls
      Press(grip)
      Assert.False(mainUI.IsResizing(), "no resize starts in combat")
      Move(world, grip, PixelsForScale(1.0, 1.5))
      Release(grip)
      grip:GetScript("OnDoubleClick")(grip, "LeftButton")
      Assert.Equal(frame._setScaleCalls, setScaleCalls, "no SetScale call on the protected frame in combat")
      Assert.Equal(world.db.uiScale, 1.0, "the scale stays unchanged in combat")
    end)
  end)

  test("Resize grip drag running into combat ends on PLAYER_REGEN_DISABLED and applies after combat", function()
    local world = BuildWorld()
    WithGlobals(world.globals, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_ui.lua",
        "isiLive_controller_wiring.lua",
        "isiLive_event_handlers.lua",
      })
      local mainUI = CreateMainUI(addon, world)
      local frame = mainUI.frame
      local grip = mainUI.resizeGrip
      local controller =
        addon.ControllerWiring.CreateEventHandlersController(addon.EventHandlers, BuildWiringDeps(mainUI, world))
      local left0, top0 = TopLeft(frame)

      Press(grip)
      Move(world, grip, PixelsForScale(1.0, 1.32))
      AssertNear(frame:GetScale(), 1.32, "setup: live scale before combat")

      -- Lockdown already holds when the event reaches isiLive: the final
      -- value has to wait for the post-combat drain.
      world.inCombat = true
      controller:Dispatch("PLAYER_REGEN_DISABLED")
      Assert.False(mainUI.IsResizing(), "combat start ends the resize")
      Assert.Equal(world.db.uiScale, 1.3, "the rounded value is persisted at combat start")
      Assert.Equal(frame._blockedCalls, 0, "no protected SetScale call during lockdown")
      AssertNear(frame:GetScale(), 1.32, "the live scale stays until combat ends")

      Move(world, grip, PixelsForScale(1.0, 1.8))
      Assert.Equal(frame._blockedCalls, 0, "mouse moves after combat start do not touch the frame")

      world.inCombat = false
      controller:Dispatch("PLAYER_REGEN_ENABLED")
      AssertNear(frame:GetScale(), 1.3, "the queued scale is applied after combat")
      local left1, top1 = TopLeft(frame)
      AssertNear(left1, left0, "top-left x unchanged after the deferred apply")
      AssertNear(top1, top0, "top-left y unchanged after the deferred apply")
      Assert.Equal(world.db.position.point, "TOPLEFT", "the deferred apply keeps the top-left anchor")
    end)
  end)

  test("Resize grip drag still runs at PLAYER_REGEN_DISABLED before lockdown applies at once", function()
    local world = BuildWorld()
    WithGlobals(world.globals, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_ui.lua",
        "isiLive_controller_wiring.lua",
        "isiLive_event_handlers.lua",
      })
      local mainUI = CreateMainUI(addon, world)
      local frame = mainUI.frame
      local grip = mainUI.resizeGrip
      local controller =
        addon.ControllerWiring.CreateEventHandlersController(addon.EventHandlers, BuildWiringDeps(mainUI, world))

      Press(grip)
      Move(world, grip, PixelsForScale(1.0, 0.71))
      -- PLAYER_REGEN_DISABLED fires just before lockdown: the frame is still
      -- writable, so the final value lands right away.
      controller:Dispatch("PLAYER_REGEN_DISABLED")
      Assert.False(mainUI.IsResizing(), "combat start ends the resize")
      AssertNear(frame:GetScale(), 0.7, "the rounded scale applies before lockdown")
      Assert.Equal(world.db.uiScale, 0.7, "the rounded scale is persisted")
    end)
  end)

  test("UI.RoundUiScale rounds to the slider step and clamps", function()
    local world = BuildWorld()
    WithGlobals(world.globals, function()
      local addon = LoadMainFrameAddon()
      local round = addon.UI.RoundUiScale
      Assert.Equal(round(1.024), 1.0, "1.024 rounds down")
      Assert.Equal(round(1.026), 1.05, "1.026 rounds up")
      Assert.Equal(round(1.15), 1.15, "step values stay exact")
      Assert.Equal(round(0.1), 0.5, "below the minimum clamps to 0.5")
      Assert.Equal(round(3), 2.0, "above the maximum clamps to 2.0")
    end)
  end)
end
