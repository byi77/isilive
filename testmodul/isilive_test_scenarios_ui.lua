local function CreateTextureStub()
  return {
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
  frame.EnableMouse = function(self, enabled)
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
  frame.SetBackdropBorderColor = function(self, r, g, b, a)
    self._backdropBorderColor = { r, g, b, a }
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

local function RegisterMainFrameVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UI toggle defers closing frame during combat and applies after regen", function()
    local inCombat = false
    local shownInGroupCalls = 0

    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
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

      Assert.True(mainUI.frame:IsShown(), "combat toggle must not close frame immediately (taint protection)")
      Assert.Equal(mainUI.GetPendingVisible(), false, "combat toggle should store pending hide")
      Assert.Equal(shownInGroupCalls, 0, "close path must not trigger show callbacks")

      inCombat = false
      mainUI.SetVisible(mainUI.GetPendingVisible())
      Assert.False(mainUI.frame:IsShown(), "frame should close after combat ends and pending is applied")
    end)
  end)

  test("UI toggle defers opening frame during combat and applies after regen", function()
    local inCombat = false
    local shownInGroupCalls = 0

    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
        onShownInGroup = function()
          shownInGroupCalls = shownInGroupCalls + 1
        end,
      })

      Assert.False(mainUI.frame:IsShown(), "frame should start hidden")

      inCombat = true
      mainUI.ToggleVisibility(true)

      Assert.False(mainUI.frame:IsShown(), "combat toggle must not open frame immediately (taint protection)")
      Assert.Equal(mainUI.GetPendingVisible(), true, "combat toggle should store pending show")
      Assert.Equal(shownInGroupCalls, 0, "combat show must not trigger callbacks yet")

      inCombat = false
      mainUI.SetVisible(mainUI.GetPendingVisible())
      Assert.True(mainUI.frame:IsShown(), "frame should open after combat ends and pending is applied")
    end)
  end)

  test("UI direct SetVisible defers during combat and applies after regen", function()
    local inCombat = true

    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
      })

      mainUI.SetVisible(true)

      Assert.False(mainUI.frame:IsShown(), "direct SetVisible must not open during combat (taint protection)")
      Assert.Equal(mainUI.GetPendingVisible(), true, "combat SetVisible should store pending show")

      inCombat = false
      mainUI.SetVisible(mainUI.GetPendingVisible())
      Assert.True(mainUI.frame:IsShown(), "frame should open after combat ends and pending is applied")
    end)
  end)

  test("Frame bridge direct SetMainFrameVisible triggers show callbacks on successful open", function()
    local visible = false
    local inGroup = true
    local groupShownCalls = 0
    local soloShownCalls = 0

    WithGlobals({
      UIParent = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_frame_bridge.lua" })
      local FrameBridge = RequireValue(addon.FrameBridge, "FrameBridge module should load")

      local context = FrameBridge.CreateContext({
        createCenterNotice = function()
          return {
            frame = {},
            teleportButton = {},
            SetVisible = function() end,
            UpdateTeleportButtonVisual = function() end,
            Show = function() end,
          }
        end,
        createInviteHint = function()
          return {
            Show = function() end,
          }
        end,
        createMainFrame = function(_opts)
          return {
            frame = {
              IsShown = function()
                return visible
              end,
            },
            SetVisible = function(wantVisible)
              if wantVisible then
                if visible then
                  return false
                end
                visible = true
                return true
              end
              if not visible then
                return false
              end
              visible = false
              return true
            end,
            SetHeightSafe = function() end,
            ToggleVisibility = function() end,
          }
        end,
        isInGroup = function()
          return inGroup
        end,
        onShownInGroup = function()
          groupShownCalls = groupShownCalls + 1
        end,
        onShownNoGroup = function()
          soloShownCalls = soloShownCalls + 1
        end,
        isInCombat = function()
          return false
        end,
        resolveTeleportSpellID = function()
          return nil
        end,
        applySecureSpellToButton = function() end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return nil
        end,
        formatCooldownSeconds = function(value)
          return tostring(value or "")
        end,
        getL = function()
          return {}
        end,
      })

      local didShow = context.SetMainFrameVisible(true)
      Assert.True(didShow, "direct show should report a successful visibility change")
      Assert.Equal(groupShownCalls, 1, "group show callback should run after a successful direct open")
      Assert.Equal(soloShownCalls, 0, "solo callback should stay untouched while in a group")

      local didHide = context.SetMainFrameVisible(false)
      Assert.True(didHide, "direct hide should also report a successful visibility change")

      inGroup = false
      local didSoloShow = context.SetMainFrameVisible(true)
      Assert.True(didSoloShow, "direct solo show should report a successful visibility change")
      Assert.Equal(groupShownCalls, 1, "group callback should not run again for solo open")
      Assert.Equal(soloShownCalls, 1, "solo show callback should run when not in a group")
    end)
  end)

  test("UI SetVisible outside combat has no pending state", function()
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
      })

      mainUI.SetVisible(true)
      Assert.True(mainUI.frame:IsShown(), "SetVisible(true) outside combat should open immediately")
      Assert.Nil(mainUI.GetPendingVisible(), "no pending state outside combat")

      mainUI.SetVisible(false)
      Assert.False(mainUI.frame:IsShown(), "SetVisible(false) outside combat should close immediately")
      Assert.Nil(mainUI.GetPendingVisible(), "no pending state outside combat after close")
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
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
      })

      local onDragStart = mainUI.frame._scripts and mainUI.frame._scripts.OnDragStart or nil
      local onDragStop = mainUI.frame._scripts and mainUI.frame._scripts.OnDragStop or nil
      Assert.NotNil(onDragStart, "main frame should define OnDragStart handler")
      Assert.NotNil(onDragStop, "main frame should define OnDragStop handler")

      ---@diagnostic disable: need-check-nil
      onDragStart(mainUI.frame)
      onDragStop(mainUI.frame)
      ---@diagnostic enable: need-check-nil

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
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
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
      ---@diagnostic disable: need-check-nil
      onClick(mainUI.closeButton, "LeftButton")
      ---@diagnostic enable: need-check-nil

      Assert.False(mainUI.frame:IsShown(), "close button should hide frame")
    end)
  end)

  test("UI close button hides frame even during combat", function()
    local inCombat = true
    WithGlobals({
      UIParent = {},
      CreateFrame = BuildCreateFrameStub(),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local mainUI = UI.CreateMainFrame({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
      })

      -- Show frame before combat starts (SetVisible respects combat guard)
      inCombat = false
      mainUI.SetVisible(true)
      inCombat = true
      Assert.True(mainUI.frame:IsShown(), "frame should be visible before combat close test")

      local onClick = mainUI.closeButton._scripts and mainUI.closeButton._scripts.OnClick or nil
      Assert.NotNil(onClick, "close button should define OnClick handler")
      ---@diagnostic disable: need-check-nil
      onClick(mainUI.closeButton, "LeftButton")
      ---@diagnostic enable: need-check-nil

      Assert.False(mainUI.frame:IsShown(), "close button must hide frame immediately even during combat")
    end)
  end)
end

local function RegisterGameMenuMicroButtonLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UI attaches game-menu micromenu buttons left of the close button in vertical order", function()
    local createFrameStub = BuildCreateFrameStub()
    local uiParent = {}
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    local gameMenuButtonContinue =
      createFrameStub("Button", "GameMenuButtonContinue", gameMenuFrame, "GameMenuButtonTemplate")
    gameMenuFrame.CloseButton = closeButton
    gameMenuFrame:SetSize(286, 372)
    gameMenuButtonContinue:SetSize(124, 32)

    WithGlobals({
      UIParent = uiParent,
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      GameMenuButtonContinue = gameMenuButtonContinue,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
        getL = function()
          return {
            BTN_GAMEMENU_PROFESSIONS = "Berufe",
            BTN_GAMEMENU_TALENTS = "Talente",
            BTN_GAMEMENU_SPELLBOOK = "Zauber",
            BTN_GAMEMENU_ACHIEVEMENTS = "Erfolge",
            BTN_GAMEMENU_QUESTS = "Quests",
            BTN_GAMEMENU_DUNGEONS = "Dungeons",
            BTN_GAMEMENU_JOURNAL = "Journal",
            BTN_GAMEMENU_COLLECTIONS = "Sammlung",
            BTN_GAMEMENU_GUILD = "Gilde",
            BTN_GAMEMENU_RELOADUI = "ReloadUI",
          }
        end,
        panelActions = {},
      })

      Assert.NotNil(strip, "game menu micromenu strip should be created")
      Assert.Equal(#strip.buttons, 10, "all requested micromenu buttons should be created")
      Assert.Equal(strip.buttons[1]._actionId, "professions", "first button should open professions")
      Assert.Equal(strip.buttons[2]._actionId, "talents", "second button should open talents")
      Assert.Equal(strip.buttons[3]._actionId, "spellbook", "third button should open the spellbook")
      Assert.Equal(strip.buttons[9]._actionId, "guild", "ninth button should still open the guild UI")
      Assert.Equal(strip.buttons[10]._actionId, "reloadui", "last button should trigger ReloadUI")
      Assert.Equal(strip.buttons[1]:GetText(), "Berufe", "button text should use localized label")
      Assert.Equal(strip.buttons[2]:GetText(), "Talente", "second button text should use localized label")
      Assert.Equal(strip.buttons[3]:GetText(), "Zauber", "third button text should use localized label")
      Assert.Equal(strip.buttons[10]:GetText(), "ReloadUI", "reload button should use its localized label")
      Assert.Equal(
        strip.buttons[10]._template,
        "SecureActionButtonTemplate,BackdropTemplate",
        "reload button should use a secure macro button template"
      )
      Assert.Equal(
        strip.buttons[10]._parent,
        gameMenuFrame,
        "reload button should avoid the external host-frame parent chain"
      )
      Assert.Equal(strip.buttons[10]:GetAttribute("type1"), "macro", "reload button should be wired as a macro action")
      Assert.Equal(
        strip.buttons[10]:GetAttribute("macrotext1"),
        "/click GameMenuButtonContinue\n/reload",
        "reload button should first close the game menu and then reload"
      )
      Assert.Equal(strip.anchor, closeButton, "close-button detection should still resolve the Blizzard anchor")
      Assert.Equal(strip.hostFrame._parent, uiParent, "micromenu strip should live on an external host frame")
      Assert.True(strip.hostFrame._mouseEnabled, "micromenu host frame should allow mouse input")
      Assert.NotNil(strip.panelFrame, "micromenu strip should create a framed Blizzard-style container")
      Assert.Equal(strip.panelFrame._parent, strip.hostFrame, "panel frame should live inside the external host frame")
      Assert.Equal(strip.panelFrame:GetWidth(), 144, "panel frame should wrap the shortcut strip content tightly")
      Assert.Equal(
        strip.panelFrame._backdrop and strip.panelFrame._backdrop.bgFile or nil,
        "Interface\\Buttons\\WHITE8X8",
        "panel frame should use the modern flat background"
      )
      Assert.Equal(
        strip.panelFrame._backdrop and strip.panelFrame._backdrop.edgeFile or nil,
        "Interface\\Tooltips\\UI-Tooltip-Border",
        "panel frame should use the modern tooltip border art"
      )
      Assert.Equal(strip.buttons[1]:GetWidth(), 124, "micromenu buttons should mirror Blizzard game-menu button width")
      Assert.Equal(strip.buttons[1]:GetHeight(), 32, "micromenu buttons should mirror Blizzard game-menu button height")

      local hostPoint = strip.hostFrame._point
      local panelPoint = strip.panelFrame._point
      local firstPoint = strip.buttons[1]._point
      local secondPoint = strip.buttons[2]._point
      local reloadPoint = strip.buttons[10]._point
      Assert.NotNil(hostPoint, "micromenu host frame should be positioned")
      Assert.NotNil(panelPoint, "micromenu panel frame should be positioned")
      Assert.NotNil(firstPoint, "first micromenu button should be positioned")
      Assert.NotNil(secondPoint, "second micromenu button should be positioned")
      Assert.NotNil(reloadPoint, "reload micromenu button should be positioned")
      Assert.Equal(hostPoint[1], "TOPRIGHT", "host frame should align from the top-right")
      Assert.Equal(hostPoint[2], gameMenuFrame, "host frame should anchor from the game-menu frame")
      Assert.Equal(hostPoint[3], "TOPLEFT", "host frame should sit left outside the game menu")
      Assert.Equal(hostPoint[4], -60, "host frame should sit clearly left of the game menu")
      Assert.Equal(hostPoint[5], 0, "host frame should align flush with the game menu top")
      Assert.Equal(panelPoint[1], "TOPLEFT", "panel frame should anchor from the top-left")
      Assert.Equal(panelPoint[2], strip.hostFrame, "panel frame should anchor inside the host frame")
      Assert.Equal(panelPoint[3], "TOPLEFT", "panel frame should fill the host frame from its top-left edge")
      Assert.Equal(firstPoint[1], "TOP", "first micromenu button should align from the top")
      Assert.Equal(firstPoint[2], strip.panelFrame, "first micromenu button should anchor from the framed panel")
      Assert.Equal(firstPoint[3], "TOP", "first micromenu button should sit inside the framed panel")
      Assert.Equal(firstPoint[4], 0, "first micromenu button should stay horizontally centered in the frame")
      Assert.Equal(
        firstPoint[5],
        -29,
        "first micromenu button should sit below the section header inside the framed panel"
      )
      Assert.True(strip.buttons[1]._mouseEnabled, "micromenu buttons should explicitly allow mouse clicks")
      Assert.NotNil(strip.buttons[1]._registeredClicks, "micromenu buttons should register click events explicitly")
      Assert.Equal(
        strip.buttons[1]._registeredClicks[1],
        "LeftButtonUp",
        "micromenu buttons should react on left button up"
      )
      Assert.Equal(secondPoint[2], strip.buttons[1], "second micromenu button should stack below the first button")
      Assert.Equal(secondPoint[3], "BOTTOM", "second micromenu button should anchor to the previous button")
      Assert.Equal(secondPoint[5], -1, "micromenu buttons should keep the configured vertical gap")
      Assert.Equal(reloadPoint[2], strip.buttons[9], "reload button should stack below the guild button")
      Assert.Equal(reloadPoint[3], "BOTTOM", "reload button should anchor to the previous button")
      Assert.Equal(reloadPoint[5], -10, "reload button should keep a visible section gap before it")
    end)
  end)

  test("UI game-menu micromenu buttons run configured opener callbacks and close the menu", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local calls = {
      professions = 0,
      spellbook = 0,
    }
    local hideCalls = 0

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      HideUIPanel = function(frame)
        if frame == gameMenuFrame then
          hideCalls = hideCalls + 1
          frame:Hide()
        end
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
        panelActions = {
          professions = function()
            calls.professions = calls.professions + 1
            return true
          end,
          spellbook = function()
            calls.spellbook = calls.spellbook + 1
            return true
          end,
        },
      })

      local onClickProfessions = strip.buttonsById.professions._scripts
          and strip.buttonsById.professions._scripts.OnClick
        or nil
      local onClickSpellbook = strip.buttonsById.spellbook._scripts and strip.buttonsById.spellbook._scripts.OnClick
        or nil
      Assert.NotNil(onClickProfessions, "professions micromenu button should define OnClick")
      Assert.NotNil(onClickSpellbook, "spellbook micromenu button should define OnClick")

      ---@diagnostic disable: need-check-nil
      gameMenuFrame:Show()
      onClickProfessions(strip.buttonsById.professions, "LeftButton")
      gameMenuFrame:Show()
      onClickSpellbook(strip.buttonsById.spellbook, "LeftButton")
      ---@diagnostic enable: need-check-nil

      Assert.Equal(calls.professions, 1, "professions button should run the configured opener once")
      Assert.Equal(calls.spellbook, 1, "spellbook button should run the configured opener once")
      Assert.Nil(
        strip.buttonsById.reloadui._scripts and strip.buttonsById.reloadui._scripts.OnClick or nil,
        "reload button should not use an insecure OnClick callback"
      )
      Assert.Equal(hideCalls, 2, "successful micromenu clicks should close the game menu")
      Assert.False(gameMenuFrame:IsShown(), "game menu should be hidden after a successful micromenu click")
    end)
  end)
end

local function RegisterGameMenuReloadButtonTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UI game-menu reload button uses secure macro attributes instead of insecure callbacks", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })

      Assert.Equal(
        strip.buttonsById.reloadui._template,
        "SecureActionButtonTemplate,BackdropTemplate",
        "reload button should be created as a secure action button"
      )
      Assert.Equal(
        strip.buttonsById.reloadui._parent,
        gameMenuFrame,
        "reload button should be parented to the Blizzard game menu instead of the external host frame"
      )
      Assert.Nil(
        strip.buttonsById.reloadui._scripts and strip.buttonsById.reloadui._scripts.OnClick or nil,
        "reload button should not define an insecure OnClick handler"
      )
      Assert.Equal(
        strip.buttonsById.reloadui._registeredClicks[1],
        "LeftButtonUp",
        "reload button should default to key-up activation when no action-button cvar is available"
      )
      Assert.Equal(
        strip.buttonsById.reloadui:GetAttribute("type"),
        "macro",
        "reload button should use macro action type"
      )
      Assert.Equal(
        strip.buttonsById.reloadui:GetAttribute("type1"),
        "macro",
        "reload button should use left-click macro action type"
      )
      Assert.Equal(
        strip.buttonsById.reloadui:GetAttribute("useOnKeyDown"),
        false,
        "reload button should default to key-up mode when no action-button cvar is available"
      )
      Assert.Equal(
        strip.buttonsById.reloadui:GetAttribute("macrotext1"),
        "/click GameMenuButtonContinue\n/reload",
        "reload button macro should close the menu and then reload"
      )
    end)
  end)

  test("UI game-menu reload button follows ActionButtonUseKeyDown cvar for secure clicks", function()
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      GetCVarBool = function(name)
        if name == "ActionButtonUseKeyDown" then
          return true
        end
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })

      Assert.Equal(
        strip.buttonsById.reloadui._registeredClicks[1],
        "LeftButtonDown",
        "reload button should switch to key-down activation when the cvar requests it"
      )
      Assert.Equal(
        strip.buttonsById.reloadui:GetAttribute("useOnKeyDown"),
        true,
        "reload button should mirror the action-button key-down cvar into its secure attributes"
      )
    end)
  end)

  test("UI game-menu secure button updates are deferred during combat and applied after regen", function()
    local inCombat = false
    local useKeyDown = false
    local createFrameStub, createdFrames = BuildCreateFrameStub({
      simulateProtectedFrames = true,
      isInCombat = function()
        return inCombat
      end,
    })
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      UIParent = {},
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      GetCVarBool = function(name)
        if name == "ActionButtonUseKeyDown" then
          return useKeyDown
        end
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
        isInCombat = function()
          return inCombat
        end,
      })

      local reloadButton = RequireValue(strip.buttonsById.reloadui, "reload button should exist")
      local originalRegisterForClicks = reloadButton.RegisterForClicks
      reloadButton.RegisterForClicks = function(self, ...)
        if inCombat then
          error("secure click registration blocked in combat")
        end
        return originalRegisterForClicks(self, ...)
      end

      local originalSetAttribute = reloadButton.SetAttribute
      reloadButton.SetAttribute = function(self, key, value)
        if inCombat then
          error("secure attribute write blocked in combat: " .. tostring(key))
        end
        return originalSetAttribute(self, key, value)
      end

      local originalSetSize = reloadButton.SetSize
      reloadButton.SetSize = function(self, ...)
        if inCombat then
          error("secure size update blocked in combat")
        end
        return originalSetSize(self, ...)
      end

      local originalClearAllPoints = reloadButton.ClearAllPoints
      reloadButton.ClearAllPoints = function(self)
        if inCombat then
          error("secure point clear blocked in combat")
        end
        return originalClearAllPoints(self)
      end

      local originalSetPoint = reloadButton.SetPoint
      reloadButton.SetPoint = function(self, ...)
        if inCombat then
          error("secure point update blocked in combat")
        end
        return originalSetPoint(self, ...)
      end

      local originalShow = reloadButton.Show
      reloadButton.Show = function(self)
        if inCombat then
          error("secure show blocked in combat")
        end
        return originalShow(self)
      end

      local originalHide = reloadButton.Hide
      reloadButton.Hide = function(self)
        if inCombat then
          error("secure hide blocked in combat")
        end
        return originalHide(self)
      end

      useKeyDown = true
      inCombat = true

      local onShow = gameMenuFrame._scripts and gameMenuFrame._scripts.OnShow or nil
      Assert.NotNil(onShow, "game menu should register an OnShow hook")

      local ok, err = pcall(function()
        ---@diagnostic disable-next-line: need-check-nil
        onShow(gameMenuFrame)
      end)

      Assert.True(ok, "combat OnShow must defer secure button updates instead of tainting: " .. tostring(err))
      Assert.Equal(
        reloadButton._registeredClicks[1],
        "LeftButtonUp",
        "combat OnShow should keep the previous secure click binding until regen"
      )
      Assert.Equal(
        reloadButton:GetAttribute("useOnKeyDown"),
        false,
        "combat OnShow should keep the previous secure attribute until regen"
      )

      local retryFrame = FindCombatRetryFrame(createdFrames)
      Assert.NotNil(retryFrame, "combat secure update should register a regen retry frame")
      retryFrame = RequireValue(retryFrame, "combat secure update should register a regen retry frame")

      inCombat = false
      retryFrame:FireEvent("PLAYER_REGEN_ENABLED")

      Assert.Equal(
        reloadButton._registeredClicks[1],
        "LeftButtonDown",
        "deferred secure update should apply the key-down click binding after regen"
      )
      Assert.Equal(
        reloadButton:GetAttribute("useOnKeyDown"),
        true,
        "deferred secure update should refresh secure attributes after regen"
      )
      Assert.False(
        retryFrame:IsEventRegistered("PLAYER_REGEN_ENABLED"),
        "regen retry frame should unregister after applying pending secure updates"
      )
    end)
  end)

  test("UI game-menu reload button keeps host frame insecure under protected-frame simulation", function()
    local inCombat = false
    local createFrameStub = BuildCreateFrameStub({
      simulateProtectedFrames = true,
      isInCombat = function()
        return inCombat
      end,
    })
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      UIParent = {},
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
        isInCombat = function()
          return inCombat
        end,
      })

      Assert.False(strip.hostFrame._isProtected, "external host frame should stay insecure")
      Assert.False(strip.panelFrame._isProtected, "external panel frame should stay insecure")
      Assert.True(strip.buttonsById.reloadui._isProtected, "reload button itself should remain secure")
    end)
  end)

  test("UI game-menu hides the host frame after close via deferred callback", function()
    local createFrameStub = BuildCreateFrameStub()
    local uiParent = {}
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local scheduledCallback = nil
    local hideCalls = 0

    WithGlobals({
      UIParent = uiParent,
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      C_Timer = {
        After = function(_delay, callback)
          scheduledCallback = callback
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })

      strip.hostFrame.Hide = function()
        hideCalls = hideCalls + 1
      end

      local onHide = gameMenuFrame._scripts and gameMenuFrame._scripts.OnHide or nil
      Assert.NotNil(onHide, "game menu should register an OnHide hook")

      ---@diagnostic disable: need-check-nil
      gameMenuFrame:Show()
      onHide(gameMenuFrame)
      ---@diagnostic enable: need-check-nil

      Assert.Equal(hideCalls, 0, "host frame should not hide synchronously inside the GameMenuFrame OnHide hook")
      Assert.NotNil(scheduledCallback, "host frame hide should be deferred after game menu close")

      ---@diagnostic disable: need-check-nil
      gameMenuFrame:Show()
      scheduledCallback()
      ---@diagnostic enable: need-check-nil

      Assert.Equal(hideCalls, 0, "reopened game menu should not hide the host frame when a stale close callback fires")

      scheduledCallback = nil
      gameMenuFrame:Hide()
      ---@diagnostic disable: need-check-nil
      onHide(gameMenuFrame)
      ---@diagnostic enable: need-check-nil

      Assert.NotNil(scheduledCallback, "host frame hide should be scheduled when the game menu actually closes")

      ---@diagnostic disable: need-check-nil
      scheduledCallback()
      ---@diagnostic enable: need-check-nil

      Assert.Equal(hideCalls, 1, "host frame should hide once the deferred game menu close callback runs")
    end)
  end)

  test("UI game-menu reload button refreshes secure click mode when panel UI is reused", function()
    local useKeyDown = false
    local createFrameStub = BuildCreateFrameStub()
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton

    WithGlobals({
      UIParent = {},
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      GetCVarBool = function(name)
        if name == "ActionButtonUseKeyDown" then
          return useKeyDown
        end
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })

      Assert.Equal(
        strip.buttonsById.reloadui._registeredClicks[1],
        "LeftButtonUp",
        "initial binding should use key-up mode"
      )
      Assert.Equal(
        strip.buttonsById.reloadui:GetAttribute("useOnKeyDown"),
        false,
        "initial attribute should match key-up mode"
      )

      useKeyDown = true
      local reusedStrip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })

      Assert.Equal(reusedStrip, strip, "panel UI should be reused for the same GameMenuFrame")
      Assert.Equal(
        reusedStrip.buttonsById.reloadui._registeredClicks[1],
        "LeftButtonDown",
        "reused panel should refresh to key-down mode"
      )
      Assert.Equal(
        reusedStrip.buttonsById.reloadui:GetAttribute("useOnKeyDown"),
        true,
        "reused panel should refresh secure click attributes"
      )
    end)
  end)
end

local function RegisterGameMenuDefaultOpenerTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UI game-menu default profession and spellbook buttons prefer native Blizzard openers", function()
    local createFrameStub = BuildCreateFrameStub()
    local uiParent = {}
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local professionsFrame = createFrameStub("Frame", "ProfessionsFrame", uiParent, "BackdropTemplate")
    professionsFrame:Hide()
    local professionClicks = 0
    local playerSpellsClicks = 0
    local spellbookMicroClicks = 0
    local spellbookDirectCalls = 0
    local fallbackCalls = 0

    WithGlobals({
      UIParent = uiParent,
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      ProfessionMicroButton = {
        Click = function()
          professionClicks = professionClicks + 1
          professionsFrame:Show()
        end,
      },
      PlayerSpellsMicroButton = {
        Click = function()
          playerSpellsClicks = playerSpellsClicks + 1
        end,
      },
      SpellbookMicroButton = {
        Click = function()
          spellbookMicroClicks = spellbookMicroClicks + 1
        end,
      },
      ProfessionsFrame = professionsFrame,
      PlayerSpellsUtil = {
        ToggleSpellBookFrame = function()
          spellbookDirectCalls = spellbookDirectCalls + 1
        end,
      },
      ToggleProfessionsBook = function()
        fallbackCalls = fallbackCalls + 1
      end,
      TogglePlayerSpellsFrame = function()
        fallbackCalls = fallbackCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })

      local onClickProfessions = strip.buttonsById.professions._scripts
          and strip.buttonsById.professions._scripts.OnClick
        or nil
      local onClickSpellbook = strip.buttonsById.spellbook._scripts and strip.buttonsById.spellbook._scripts.OnClick
        or nil
      Assert.NotNil(onClickProfessions, "professions micromenu button should define OnClick")
      Assert.NotNil(onClickSpellbook, "spellbook micromenu button should define OnClick")

      ---@diagnostic disable: need-check-nil
      onClickProfessions(strip.buttonsById.professions, "LeftButton")
      onClickSpellbook(strip.buttonsById.spellbook, "LeftButton")
      ---@diagnostic enable: need-check-nil

      Assert.Equal(professionClicks, 1, "profession button should trigger ProfessionMicroButton first")
      Assert.Equal(spellbookDirectCalls, 1, "spellbook button should prefer the explicit spellbook opener")
      Assert.Equal(playerSpellsClicks, 0, "spellbook button should not route through PlayerSpellsMicroButton")
      Assert.Equal(
        spellbookMicroClicks,
        0,
        "spellbook button should avoid the spellbook microbutton when the direct API exists"
      )
      Assert.Equal(fallbackCalls, 0, "native opener path should avoid the fallback toggle functions")
    end)
  end)

  test("UI game-menu falls back to direct open without routing spellbook through talents", function()
    local createFrameStub = BuildCreateFrameStub()
    local uiParent = {}
    local gameMenuFrame = createFrameStub("Frame", "GameMenuFrame", nil, "BackdropTemplate")
    local closeButton = createFrameStub("Button", nil, gameMenuFrame, "UIPanelCloseButton")
    gameMenuFrame.CloseButton = closeButton
    local professionsFrame = createFrameStub("Frame", "ProfessionsFrame", uiParent, "BackdropTemplate")
    local playerSpellsFrame = createFrameStub("Frame", "PlayerSpellsFrame", uiParent, "BackdropTemplate")
    professionsFrame:Hide()
    playerSpellsFrame:Hide()
    local professionClicks = 0
    local playerSpellsClicks = 0
    local spellbookMicroClicks = 0
    local professionFallbackCalls = 0
    local spellbookFallbackCalls = 0

    WithGlobals({
      UIParent = uiParent,
      CreateFrame = createFrameStub,
      GameMenuFrame = gameMenuFrame,
      ProfessionMicroButton = {
        Click = function()
          professionClicks = professionClicks + 1
        end,
      },
      PlayerSpellsMicroButton = {
        Click = function()
          playerSpellsClicks = playerSpellsClicks + 1
        end,
      },
      SpellbookMicroButton = {
        Click = function()
          spellbookMicroClicks = spellbookMicroClicks + 1
        end,
      },
      ProfessionsFrame = professionsFrame,
      PlayerSpellsFrame = playerSpellsFrame,
      ToggleProfessionsBook = function()
        professionFallbackCalls = professionFallbackCalls + 1
        professionsFrame:Show()
      end,
      PlayerSpellsUtil = {
        FrameTabs = {
          SpellBook = "SpellBook",
        },
      },
      TogglePlayerSpellsFrame = function(tab)
        if tab == "SpellBook" then
          spellbookFallbackCalls = spellbookFallbackCalls + 1
          playerSpellsFrame:Show()
        end
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui.lua" })
      local UI = RequireValue(addon.UI, "UI module should load")
      local strip = UI.EnsurePanelUI({
        gameMenuFrame = gameMenuFrame,
      })

      local onClickProfessions = strip.buttonsById.professions._scripts
          and strip.buttonsById.professions._scripts.OnClick
        or nil
      local onClickSpellbook = strip.buttonsById.spellbook._scripts and strip.buttonsById.spellbook._scripts.OnClick
        or nil
      Assert.NotNil(onClickProfessions, "professions micromenu button should define OnClick")
      Assert.NotNil(onClickSpellbook, "spellbook micromenu button should define OnClick")

      ---@diagnostic disable: need-check-nil
      onClickProfessions(strip.buttonsById.professions, "LeftButton")
      onClickSpellbook(strip.buttonsById.spellbook, "LeftButton")
      ---@diagnostic enable: need-check-nil

      Assert.Equal(professionClicks, 1, "profession button should still try the native micro button first")
      Assert.Equal(
        professionFallbackCalls,
        1,
        "profession button should fall back to ToggleProfessionsBook on no-op click"
      )
      Assert.Equal(
        spellbookFallbackCalls,
        1,
        "spellbook button should fall back to the explicit SpellBook tab when the direct API is unavailable"
      )
      Assert.Equal(playerSpellsClicks, 0, "spellbook button should not click the talents microbutton")
      Assert.Equal(
        spellbookMicroClicks,
        0,
        "spellbook button should not need the spellbook microbutton when the tab API exists"
      )
      Assert.True(professionsFrame:IsShown(), "profession fallback should open the professions frame")
      Assert.True(playerSpellsFrame:IsShown(), "spellbook fallback should open the player spells frame")
    end)
  end)
end

local function RegisterGameMenuMicroButtonTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterGameMenuMicroButtonLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterGameMenuReloadButtonTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterGameMenuDefaultOpenerTests(test, Assert, WithGlobals, LoadAddonModules)
end

local function RegisterSettingsPanelTests(test, Assert, WithGlobals, LoadAddonModules)
  test("UICommon background alpha defaults to 50 percent and honors saved override", function()
    WithGlobals({
      IsiLiveDB = nil,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      Assert.Equal(addon.UICommon.GetBackgroundAlpha(), 0.50, "default background alpha should be 50 percent")
    end)

    WithGlobals({
      IsiLiveDB = { bgAlpha = 0.65 },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua" })
      Assert.Equal(addon.UICommon.GetBackgroundAlpha(), 0.65, "saved background alpha should override the default")
    end)
  end)

  test("Settings panel background opacity keeps 50 percent default until user changes it", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local bgAlphaChanges = 0
    local lastBgAlpha = nil

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onBgAlphaChange = function(val)
          bgAlphaChanges = bgAlphaChanges + 1
          lastBgAlpha = val
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.bgAlpha, "default background alpha should not be written just by opening settings")

      local slider = nil
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "Slider" then
          slider = frame
          break
        end
      end

      Assert.NotNil(slider, "settings panel should create a background alpha slider")
      ---@diagnostic disable: need-check-nil, undefined-field
      Assert.Equal(slider:GetValue(), 0.50, "slider should initialize with a 50 percent default")

      panel.Refresh()

      Assert.Nil(db.bgAlpha, "refresh should not persist the default background alpha")
      Assert.Equal(bgAlphaChanges, 0, "refresh should not fire background alpha change callbacks")

      local onValueChanged = slider._scripts and slider._scripts.OnValueChanged or nil
      Assert.NotNil(onValueChanged, "slider should define OnValueChanged")
      onValueChanged(slider, 0.70)
      ---@diagnostic enable: need-check-nil, undefined-field

      Assert.Equal(db.bgAlpha, 0.70, "user changes should be persisted")
      Assert.Equal(lastBgAlpha, 0.70, "user changes should call the background alpha callback")
      Assert.Equal(bgAlphaChanges, 1, "user changes should fire exactly one callback")
    end)
  end)

  test("Settings panel lets the user choose the default layout on open", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local defaultLayoutChanges = {}

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_SHOW_DPS_COLUMN = "Show DPS Column",
            SETTINGS_NAME_MAX_CHARS = "Name Length",
            SETTINGS_TELEPORT_COLUMNS = "Teleport Grid Columns",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_HIDE_SOLO = "Auto Hide Solo",
            SETTINGS_DEFAULT_OPEN_UI = "Default UI on Open",
            SETTINGS_DEFAULT_OPEN_UI_LAST = "Last Used",
            SETTINGS_DEFAULT_OPEN_UI_M = "M",
            SETTINGS_DEFAULT_OPEN_UI_V = "V",
            SETTINGS_DEFAULT_OPEN_UI_H = "H",
            SETTINGS_DEFAULT_OPEN_UI_M2 = "M2",
            SETTINGS_MARKERS_LEADER_ONLY = "Markers Leader Only",
            SETTINGS_SOUND_ENABLED = "Sound Enabled",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onDefaultLayoutModeChange = function(mode)
          defaultLayoutChanges[#defaultLayoutChanges + 1] = mode or false
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.rosterDefaultLayoutMode, "default layout should stay unset until the user chooses one")

      local m2Button = nil
      local lastUsedButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame._optionValue == "compact_main_horizontal" then
          m2Button = frame
        elseif frame._optionValue == "last_used" and frame._optionLabelKey == "SETTINGS_DEFAULT_OPEN_UI_LAST" then
          lastUsedButton = frame
        end
      end

      Assert.NotNil(m2Button, "settings panel should create an M2 default-layout button")
      Assert.NotNil(lastUsedButton, "settings panel should create a last-used default-layout button")
      ---@diagnostic disable: need-check-nil, undefined-field
      Assert.Equal(
        m2Button._backdropColor[4],
        0.25,
        "M2 should be highlighted by default when no saved default layout exists"
      )
      Assert.Equal(
        lastUsedButton._backdropColor[4],
        0.7,
        "Last Used should stay unselected by default when no saved default layout exists"
      )
      ---@diagnostic enable: need-check-nil, undefined-field

      local onClickM2 = m2Button._scripts and m2Button._scripts.OnClick or nil
      local onClickLast = lastUsedButton._scripts and lastUsedButton._scripts.OnClick or nil
      Assert.NotNil(onClickM2, "M2 button should define OnClick")
      Assert.NotNil(onClickLast, "Last Used button should define OnClick")

      ---@diagnostic disable: need-check-nil
      onClickM2(m2Button, "LeftButton")
      onClickLast(lastUsedButton, "LeftButton")
      ---@diagnostic enable: need-check-nil

      Assert.Equal(
        db.rosterDefaultLayoutMode,
        "last_used",
        "choosing Last Used should store the explicit last-used sentinel"
      )
      Assert.Equal(
        defaultLayoutChanges[1],
        "compact_main_horizontal",
        "clicking M2 should persist the normalized layout mode and notify the callback"
      )
      Assert.Equal(
        defaultLayoutChanges[2],
        false,
        "clicking Last Used should notify the callback with a nil layout mode"
      )
    end)
  end)

  test("Settings panel defaults Auto-Hide when Solo to enabled until the user turns it off", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_HIDE_SOLO = "Auto Hide Solo",
            SETTINGS_DEFAULT_OPEN_UI = "Default UI on Open",
            SETTINGS_DEFAULT_OPEN_UI_LAST = "Last Used",
            SETTINGS_DEFAULT_OPEN_UI_M = "M",
            SETTINGS_DEFAULT_OPEN_UI_V = "V",
            SETTINGS_DEFAULT_OPEN_UI_H = "H",
            SETTINGS_DEFAULT_OPEN_UI_M2 = "M2",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.autoHideSolo, "opening settings should not persist the default auto-hide value")

      local autoHideCheck = nil
      local checkButtonIndex = 0
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "CheckButton" then
          checkButtonIndex = checkButtonIndex + 1
          if checkButtonIndex == 7 then
            autoHideCheck = frame
            break
          end
        end
      end

      Assert.NotNil(autoHideCheck, "settings panel should create an auto-hide checkbox")
      Assert.True(autoHideCheck:GetChecked(), "auto-hide should default to enabled when no saved value exists")

      db.autoHideSolo = false
      panel.Refresh()

      Assert.False(autoHideCheck:GetChecked(), "refresh should honor an explicit false override")
    end)
  end)

  test("Settings panel keeps column guides disabled by default and lets the user enable them", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local callbackStates = {}

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_HIDE_SOLO = "Auto Hide Solo",
            SETTINGS_DEFAULT_OPEN_UI = "Default UI on Open",
            SETTINGS_DEFAULT_OPEN_UI_LAST = "Last Used",
            SETTINGS_DEFAULT_OPEN_UI_M = "M",
            SETTINGS_DEFAULT_OPEN_UI_V = "V",
            SETTINGS_DEFAULT_OPEN_UI_H = "H",
            SETTINGS_DEFAULT_OPEN_UI_M2 = "M2",
            SETTINGS_ROSTER_COLUMN_GUIDES = "Column Guides",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
        onRosterColumnGuidesToggle = function(enabled)
          callbackStates[#callbackStates + 1] = enabled and true or false
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.showRosterColumnGuides, "column guides should stay unset until the user chooses them")

      local guideCheck = nil
      for _, frame in ipairs(createdFrames) do
        if frame._settingKey == "SETTINGS_ROSTER_COLUMN_GUIDES" then
          guideCheck = frame
          break
        end
      end

      Assert.NotNil(guideCheck, "settings panel should create a column-guides checkbox")
      Assert.False(guideCheck:GetChecked(), "column guides should default to disabled")

      local onClick = guideCheck._scripts and guideCheck._scripts.OnClick or nil
      Assert.NotNil(onClick, "column guides checkbox should define OnClick")

      guideCheck:SetChecked(true)
      onClick(guideCheck)
      Assert.True(db.showRosterColumnGuides, "enabling the checkbox should persist the enabled setting")
      Assert.Equal(callbackStates[1], true, "enabling the checkbox should notify the callback")

      panel.Refresh()
      Assert.True(guideCheck:GetChecked(), "refresh should keep the enabled checkbox state")

      guideCheck:SetChecked(false)
      onClick(guideCheck)
      Assert.False(db.showRosterColumnGuides, "disabling the checkbox should persist the disabled setting")
      Assert.Equal(callbackStates[2], false, "disabling the checkbox should notify the callback")
    end)
  end)

  test("Settings panel hides disabled legacy display and behavior controls", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {
      showDpsColumn = true,
      nameMaxChars = 18,
      markersLeaderOnly = true,
      soundEnabled = true,
      teleportColumns = 2,
    }

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_GENERAL = "General",
            SETTINGS_SECTION_DISPLAY = "Display",
            SETTINGS_SECTION_BEHAVIOR = "Behavior",
            SETTINGS_SECTION_DEBUG = "Debug",
            SETTINGS_LANGUAGE = "Language",
            SETTINGS_COMBAT_LOGGING = "Combat Logging",
            SETTINGS_DM_RESET = "DM Reset",
            SETTINGS_ESC_PANEL = "ESC Panel",
            SETTINGS_BG_ALPHA = "Background Opacity",
            SETTINGS_UI_SCALE = "UI Scale",
            SETTINGS_SHOW_DPS_COLUMN = "Show DPS Column",
            SETTINGS_NAME_MAX_CHARS = "Name Length",
            SETTINGS_TELEPORT_COLUMNS = "Teleport Grid Columns",
            SETTINGS_MINIMAP_BUTTON = "Minimap Button",
            SETTINGS_SYNC_ENABLED = "Addon Sync",
            SETTINGS_AUTO_OPEN_QUEUE = "Auto Open Queue",
            SETTINGS_AUTO_HIDE_SOLO = "Auto Hide Solo",
            SETTINGS_MARKERS_LEADER_ONLY = "Markers Leader Only",
            SETTINGS_SOUND_ENABLED = "Sound Enabled",
            SETTINGS_QUEUE_DEBUG = "Queue Debug",
            SETTINGS_RUNTIME_LOG = "Runtime Log",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      Assert.NotNil(panel, "settings panel should still be created")

      local sliderCount = 0
      local checkboxCount = 0
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "Slider" then
          sliderCount = sliderCount + 1
        elseif frame._frameType == "CheckButton" then
          checkboxCount = checkboxCount + 1
        end
      end

      Assert.Equal(sliderCount, 2, "settings should only expose the background opacity and UI scale sliders")
      Assert.Equal(
        checkboxCount,
        10,
        "settings should hide the legacy DPS, markers, sound, name-length,"
          .. " and teleport-column controls while keeping column guides visible"
      )

      panel.Refresh()
      Assert.Equal(sliderCount, 2, "refresh should keep the legacy sliders hidden")
      Assert.Equal(
        checkboxCount,
        10,
        "refresh should keep the hidden legacy checkboxes out of the settings UI while preserving column guides"
      )
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
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local centerNotice = Notice.CreateCenterNotice({
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
end

return function(test, ctx)
  local Assert = RequireValue(ctx.assert, "UI scenario ctx.assert should exist")
  local WithGlobals = RequireValue(ctx.with_globals, "UI scenario ctx.with_globals should exist")
  local LoadAddonModules = RequireValue(ctx.load_modules, "UI scenario ctx.load_modules should exist")

  RegisterMainFrameVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterMainFrameInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterGameMenuMicroButtonTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterSettingsPanelTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCenterNoticeVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCenterNoticeDragResetTest(test, Assert, WithGlobals, LoadAddonModules)
end
