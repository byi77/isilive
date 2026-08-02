local function BuildTeleportUICreateFrameStub()
  local createdFrames = {}

  local function CreateTextureStub()
    local texture = {}
    texture.SetAllPoints = function(_self) end
    texture.SetPoint = function(_self, _point, _relativeTo, _relativePoint, _x, _y) end
    texture.SetTexCoord = function(_self, _x1, _x2, _y1, _y2) end
    texture.SetTexture = function(_self, _value) end
    texture.SetColorTexture = function(_self, _r, _g, _b, _a) end
    texture.SetBlendMode = function(_self, _mode) end
    texture.SetVertexColor = function(_self, _r, _g, _b, _a) end
    texture.Hide = function(_self) end
    texture.Show = function(_self) end
    return texture
  end

  local function CreateFontStringStub()
    local fontString = {
      _text = nil,
      _shown = false,
    }
    fontString.SetPoint = function(_self, _point, _relativeTo, _relativePoint, _x, _y) end
    fontString.SetText = function(self, value)
      self._text = value
    end
    fontString.Hide = function(self)
      self._shown = false
    end
    fontString.Show = function(self)
      self._shown = true
    end
    fontString.SetWidth = function(_self, _width) end
    fontString.SetJustifyH = function(_self, _value) end
    fontString.SetJustifyV = function(_self, _value) end
    fontString.SetWordWrap = function(_self, _value) end
    fontString.SetNonSpaceWrap = function(_self, _value) end
    fontString.SetMaxLines = function(_self, _value) end
    fontString.SetTextColor = function(_self, _r, _g, _b, _a) end
    fontString.SetShadowColor = function(_self, _r, _g, _b, _a) end
    fontString.SetShadowOffset = function(_self, _x, _y) end
    fontString.GetStringHeight = function()
      return 16
    end
    return fontString
  end

  local function CreateAnimationGroupStub()
    local group = { playing = false }
    group.SetLooping = function(_self, _mode) end
    group.CreateAnimation = function(_group, _kind)
      local anim = {}
      anim.SetScale = function(_self, _x, _y) end
      anim.SetDuration = function(_self, _duration) end
      anim.SetSmoothing = function(_self, _value) end
      anim.SetOrder = function(_self, _value) end
      anim.SetFromAlpha = function(_self, _value) end
      anim.SetToAlpha = function(_self, _value) end
      anim.SetTarget = function(_self, _target) end
      return anim
    end
    function group:IsPlaying()
      return self.playing
    end
    function group:Play()
      self.playing = true
    end
    function group:Stop()
      self.playing = false
    end
    return group
  end

  local function CreateFrameStub(frameType, _name, _parent, _template)
    local frame = {
      _frameType = frameType,
      _events = {},
      _scripts = {},
      _attrs = {},
      _frameStrata = "MEDIUM",
      _frameLevel = 1,
    }

    function frame:SetScript(name, handler)
      self._scripts[name] = handler
    end

    function frame:RegisterEvent(event)
      self._events[event] = true
    end

    function frame:UnregisterEvent(event)
      self._events[event] = nil
    end

    function frame:IsEventRegistered(event)
      return self._events[event] == true
    end

    function frame:FireEvent(event)
      local handler = self._scripts.OnEvent
      if handler then
        handler(self, event)
      end
    end

    frame.SetSize = function(self, w, h)
      self.width = w
      self.height = h
    end
    frame.SetPoint = function(self, point, ...)
      local args = { ... }
      self._point = {
        point = point,
        relativeTo = #args >= 4 and args[1] or nil,
        relativePoint = #args >= 4 and args[2] or nil,
        x = #args >= 4 and args[3] or args[1] or 0,
        y = #args >= 4 and args[4] or args[2] or 0,
      }
    end
    frame.ClearAllPoints = function(self)
      self._point = nil
    end
    frame.EnableMouse = function(_self, _enabled) end
    frame.RegisterForClicks = function(_self, _down, _up) end
    function frame:SetFrameStrata(value)
      self._frameStrata = value
    end
    function frame:GetFrameStrata()
      return self._frameStrata
    end
    function frame:SetFrameLevel(value)
      self._frameLevel = value
    end
    function frame:GetFrameLevel()
      return self._frameLevel
    end
    frame.CreateTexture = function(_self, _texName, _layer)
      return CreateTextureStub()
    end
    frame.CreateAnimationGroup = function(_self)
      return CreateAnimationGroupStub()
    end
    function frame:SetAttribute(key, value)
      self._attrs[key] = value
    end
    function frame:GetAttribute(key)
      return self._attrs[key]
    end
    frame.SetScale = function(_self, _scale) end
    frame.SetAllPoints = function(_self) end
    frame.SetDrawEdge = function(_self, _enabled) end
    frame.SetClampedToScreen = function(_self, _enabled) end
    frame.Show = function(self)
      self._shown = true
    end
    frame.Hide = function(self)
      self._shown = false
    end
    frame.CreateFontString = function()
      return CreateFontStringStub()
    end

    table.insert(createdFrames, frame)
    return frame
  end

  return CreateFrameStub, createdFrames
end

local function RegisterTeleportUIEmptyStateTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TeleportUI shows pre-season message when active portal pool is empty", function()
    local createFrameStub = BuildTeleportUICreateFrameStub()
    local emptyState = {
      text = nil,
      shown = false,
      SetPoint = function() end,
      SetWidth = function() end,
      SetJustifyH = function() end,
      SetTextColor = function() end,
      SetWordWrap = function() end,
      SetNonSpaceWrap = function() end,
      SetText = function(self, value)
        self.text = value
      end,
      Show = function(self)
        self.shown = true
      end,
      Hide = function(self)
        self.shown = false
      end,
    }

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
          CreateFontString = function()
            return emptyState
          end,
        },
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return {}
        end,
        getEmptyStateText = function()
          return "Midnight S1 launches March 18, 2026\nM+ available March 25, 2026"
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function()
          return false
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getSpellCooldownSafe = function()
          return 0, 0, true
        end,
        applyCooldownFrameSafe = function() end,
        getSpellTexture = function()
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()

      Assert.Equal(#controller.GetButtons(), 0, "pre-season empty state should not create teleport buttons")
      Assert.True(emptyState.shown, "pre-season empty state message should be visible")
      Assert.Equal(
        emptyState.text,
        "Midnight S1 launches March 18, 2026\nM+ available March 25, 2026",
        "empty state should show season message"
      )
    end)
  end)

  test("TeleportUI SetVisible hides travel buttons and empty state", function()
    local createFrameStub = BuildTeleportUICreateFrameStub()
    local emptyState = {
      text = nil,
      shown = false,
      SetPoint = function() end,
      SetWidth = function() end,
      SetJustifyH = function() end,
      SetTextColor = function() end,
      SetWordWrap = function() end,
      SetNonSpaceWrap = function() end,
      SetText = function(self, value)
        self.text = value
      end,
      Show = function(self)
        self.shown = true
      end,
      Hide = function(self)
        self.shown = false
      end,
    }

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
          CreateFontString = function()
            return emptyState
          end,
        },
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return {}
        end,
        getEmptyStateText = function()
          return "No teleports"
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function()
          return false
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getSpellCooldownSafe = function()
          return 0, 0, true
        end,
        applyCooldownFrameSafe = function() end,
        getSpellTexture = function()
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()
      Assert.True(emptyState.shown, "empty state should be visible before collapse hiding")

      controller.SetVisible(false)

      Assert.False(emptyState.shown, "empty state should hide when travel area is collapsed")
      Assert.Equal(#controller.GetButtons(), 0, "empty-state setup should still keep button list empty")
    end)
  end)

  test("TeleportUI keeps the legacy two-column travel grid", function()
    local createFrameStub = BuildTeleportUICreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
      IsiLiveDB = {
        teleportColumns = 4,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              SetTextColor = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetText = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
        },
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return {
            { spellID = 1, mapID = 1001, slotIndex = 1 },
            { spellID = 2, mapID = 1002, slotIndex = 2 },
            { spellID = 3, mapID = 1003, slotIndex = 3 },
            { spellID = 4, mapID = 1004, slotIndex = 4 },
          }
        end,
        getEmptyStateText = function()
          return nil
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getSpellCooldownSafe = function()
          return 0, 0, true
        end,
        applyCooldownFrameSafe = function() end,
        getSpellTexture = function()
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()
      local buttons = controller.GetButtons()

      Assert.Equal(#buttons, 4, "travel grid should build one button per entry")
      Assert.Equal(
        buttons[1]._point and buttons[1]._point.x or nil,
        -60,
        "first column should keep the original left slot anchor"
      )
      Assert.Equal(
        buttons[2]._point and buttons[2]._point.x or nil,
        -28,
        "second column should keep the original right slot anchor"
      )
      Assert.Equal(
        buttons[3]._point and buttons[3]._point.x or nil,
        -60,
        "third button should wrap back to the left column on the second row"
      )
      Assert.Equal(
        buttons[4]._point and buttons[4]._point.x or nil,
        -28,
        "fourth button should stay in the right column on the second row"
      )
      Assert.Equal(
        buttons[1]._point and buttons[1]._point.y or nil,
        -60,
        "first travel row should stay under the header baseline"
      )
      Assert.Equal(buttons[2]._point and buttons[2]._point.y or nil, -60, "second button should stay on the first row")
      Assert.Equal(
        buttons[3]._point and buttons[3]._point.y or nil,
        -92,
        "third button should start the second row one slot below"
      )
      Assert.Equal(buttons[4]._point and buttons[4]._point.y or nil, -92, "fourth button should stay on the second row")
    end)
  end)
end

local function RegisterTeleportUIVisualTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TeleportUI tooltip shows English dungeon name below the localized title", function()
    local createFrameStub, createdFrames = BuildTeleportUICreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
      UIParent = {},
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              SetTextColor = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetText = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
        },
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return {
            { spellID = 1, mapID = 558, mapName = "Terrasse der Magister", slotIndex = 1 },
          }
        end,
        getEmptyStateText = function()
          return nil
        end,
        getL = function()
          return {
            TOOLTIP_TELEPORT_READY = "Ready",
          }
        end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getSpellCooldownSafe = function()
          return 0, 0, true
        end,
        applyCooldownFrameSafe = function() end,
        getSpellTexture = function()
          return nil
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
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()
      local button = controller.GetButtons()[1]
      Assert.NotNil(button, "TeleportUI should build one teleport button")
      Assert.Equal(button._isiLiveSurfaceRole, "run", "portal button should use the shared M+ run surface")
      Assert.NotNil(button.runTile, "portal button should render a stable run-zone tile behind its icon")
      local onEnter = button._scripts and button._scripts.OnEnter or nil
      Assert.NotNil(onEnter, "Teleport button should define an OnEnter handler")
      if onEnter then
        onEnter(button)
      end

      local privateTooltip = nil
      for _, frame in ipairs(createdFrames) do
        if frame._isIsiLiveTooltip == true then
          privateTooltip = frame
        end
      end

      Assert.NotNil(privateTooltip, "TeleportUI should allocate a private tooltip frame")
      local lines = privateTooltip and privateTooltip._isiLiveTooltipLines or {}
      Assert.Equal(lines[1] and lines[1]._text or nil, "Terrasse der Magister", "Tooltip title should stay localized")
      Assert.Equal(
        lines[2] and lines[2]._text or nil,
        "Magisters' Terrace",
        "Tooltip should add the English name on the next line"
      )
    end)
  end)

  test("TeleportUI distinguishes account-wide portal unlocks from new-dungeon level gates", function()
    local createFrameStub, createdFrames = BuildTeleportUICreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
      UIParent = {},
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              SetTextColor = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetText = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
        },
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return {
            { spellID = 1254572, mapID = 558, mapName = "Magisters' Terrace", minimumPlayerLevel = 90 },
            { spellID = 1254555, mapID = 556, mapName = "Pit of Saron" },
            { spellID = 1254551, mapID = 239, mapName = "Seat of the Triumvirate" },
          }
        end,
        getEmptyStateText = function()
          return nil
        end,
        getL = function()
          return {
            TOOLTIP_TELEPORT_LOCKED = "Account-wide +10 unlock",
            TOOLTIP_TELEPORT_LEVEL_REQUIRED = "Requires level %d; +10 is account-wide",
            TOOLTIP_TELEPORT_READY = "Ready",
          }
        end,
        getPlayerLevel = function()
          return 80
        end,
        isSpellKnown = function(spellID)
          return spellID ~= 1254551
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getSpellCooldownSafe = function()
          return 0, 0, true
        end,
        applyCooldownFrameSafe = function() end,
        getSpellTexture = function()
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()
      local buttons = controller.GetButtons()
      buttons[1]._scripts.OnEnter(buttons[1])

      local privateTooltip
      for _, frame in ipairs(createdFrames) do
        if frame._isIsiLiveTooltip == true then
          privateTooltip = frame
        end
      end
      local lines = privateTooltip and privateTooltip._isiLiveTooltipLines or {}
      Assert.Equal(
        lines[2] and lines[2]._text or nil,
        "Requires level 90; +10 is account-wide",
        "a new dungeon on a level-80 character must show only the level-90 gate plus account-wide unlock scope"
      )

      buttons[2]._scripts.OnEnter(buttons[2])
      lines = privateTooltip and privateTooltip._isiLiveTooltipLines or {}
      Assert.Equal(
        lines[2] and lines[2]._text or nil,
        "Ready",
        "an account-wide unlocked old-dungeon portal must be ready below level 90"
      )

      buttons[3]._scripts.OnEnter(buttons[3])
      lines = privateTooltip and privateTooltip._isiLiveTooltipLines or {}
      Assert.Equal(
        lines[2] and lines[2]._text or nil,
        "Account-wide +10 unlock",
        "a missing old-dungeon portal must explain the account-wide +10 unlock without a level-90 gate"
      )
    end)
  end)

  test("TeleportUI keeps M2 short-code overlay visible during global cooldown", function()
    local createFrameStub = BuildTeleportUICreateFrameStub()
    local appliedCooldowns = {}

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              SetTextColor = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetText = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
        },
        layoutMode = "compact_main_horizontal",
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return {
            { spellID = 12345, mapID = 558, slotIndex = 1 },
          }
        end,
        getEmptyStateText = function()
          return nil
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getSpellCooldownSafe = function()
          return 100, 1.5, true
        end,
        applyCooldownFrameSafe = function(_frame, start, duration, enabled)
          table.insert(appliedCooldowns, {
            start = start,
            duration = duration,
            enabled = enabled,
          })
        end,
        getSpellTexture = function()
          return nil
        end,
        getDungeonShortCode = function(mapID)
          if mapID == 558 then
            return "MT"
          end
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()
      controller.UpdateButtons(nil)
      controller.UpdateButtons(1)

      local button = controller.GetButtons()[1]
      Assert.NotNil(button, "TeleportUI should build one M2 button")
      Assert.NotNil(button.shortCodeText, "M2 button should create a short-code font string")
      Assert.True(button.shortCodeText._shown, "short-code overlay must stay visible during pure GCD")
      Assert.Equal(button.shortCodeText._text, "MT", "short-code overlay should keep the dungeon code")
      Assert.Equal(#appliedCooldowns, 2, "button update should refresh the cooldown frame for both state transitions")
      Assert.Equal(appliedCooldowns[1].start, 0, "pure GCD should clear the visible cooldown swipe")
      Assert.Equal(appliedCooldowns[1].duration, 0, "pure GCD should clear the visible cooldown swipe duration")
      Assert.False(appliedCooldowns[1].enabled, "pure GCD should disable the cooldown frame for portal buttons")
    end)
  end)

  test("TeleportUI applies visible cooldown frame from normalized remaining time", function()
    local createFrameStub = BuildTeleportUICreateFrameStub()
    local appliedCooldowns = {}

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              SetTextColor = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetText = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
        },
        layoutMode = "compact_main_horizontal",
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return {
            { spellID = 12345, mapID = 558, slotIndex = 1 },
          }
        end,
        getEmptyStateText = function()
          return nil
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 10920
        end,
        formatCooldownSeconds = function()
          return "03:02"
        end,
        getSpellCooldownSafe = function()
          return 4402120, 28800, true
        end,
        getCooldownFrameStartForRemaining = function(remaining)
          return 100000, remaining
        end,
        applyCooldownFrameSafe = function(_frame, start, duration, enabled)
          table.insert(appliedCooldowns, {
            start = start,
            duration = duration,
            enabled = enabled,
          })
        end,
        getSpellTexture = function()
          return nil
        end,
        getDungeonShortCode = function(mapID)
          if mapID == 558 then
            return "MT"
          end
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()
      controller.UpdateButtons(nil)

      Assert.Equal(#appliedCooldowns, 1, "button update should apply one visible cooldown frame")
      Assert.Equal(appliedCooldowns[1].start, 100000, "cooldown frame must anchor at current session time")
      Assert.Equal(appliedCooldowns[1].duration, 10920, "cooldown frame must use normalized remaining seconds")
      Assert.True(appliedCooldowns[1].enabled, "normalized active cooldown must keep the frame enabled")
    end)
  end)

  test("TeleportUI keeps active-target refreshes silent because summon sound owns Portal.ogg", function()
    local createFrameStub = BuildTeleportUICreateFrameStub()
    local soundCalls = 0

    WithGlobals({
      CreateFrame = createFrameStub,
      PlaySoundFile = function()
        soundCalls = soundCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              SetJustifyV = function() end,
              SetTextColor = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetText = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
        },
        layoutMode = "compact_main_horizontal",
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return {
            { spellID = 12345, mapID = 558, slotIndex = 1 },
          }
        end,
        getEmptyStateText = function()
          return nil
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getSpellCooldownSafe = function()
          return 100, 1.5, true
        end,
        applyCooldownFrameSafe = function() end,
        getSpellTexture = function()
          return nil
        end,
        getDungeonShortCode = function(mapID)
          if mapID == 558 then
            return "MT"
          end
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()
      controller.UpdateButtons(nil)
      controller.UpdateButtons(12345)

      Assert.Equal(soundCalls, 0, "active-target refreshes must not play the incoming-summon sound")
    end)
  end)
end

local function RegisterTeleportUIAudioAndDebugTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TeleportUI suppresses portal sound for queue-driven active target refreshes", function()
    local createFrameStub = BuildTeleportUICreateFrameStub()
    local soundCalls = 0

    WithGlobals({
      CreateFrame = createFrameStub,
      PlaySoundFile = function()
        soundCalls = soundCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              SetJustifyV = function() end,
              SetTextColor = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetText = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
        },
        layoutMode = "compact_main_horizontal",
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return {
            { spellID = 12345, mapID = 558, slotIndex = 1 },
          }
        end,
        getEmptyStateText = function()
          return nil
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getSpellCooldownSafe = function()
          return 0, 0, false
        end,
        applyCooldownFrameSafe = function() end,
        getSpellTexture = function()
          return nil
        end,
        getDungeonShortCode = function(mapID)
          if mapID == 558 then
            return "MT"
          end
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()
      controller.UpdateButtons(nil, "queue")
      controller.UpdateButtons(12345, "queue")

      Assert.Equal(soundCalls, 0, "queue-driven target refreshes must not play the portal sound")
    end)
  end)

  test("TeleportUI suppresses portal sound for invite-driven active target refreshes", function()
    local createFrameStub = BuildTeleportUICreateFrameStub()
    local soundCalls = 0

    WithGlobals({
      CreateFrame = createFrameStub,
      PlaySoundFile = function()
        soundCalls = soundCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              SetJustifyV = function() end,
              SetTextColor = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetText = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
        },
        layoutMode = "compact_main_horizontal",
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return {
            { spellID = 12345, mapID = 558, slotIndex = 1 },
          }
        end,
        getEmptyStateText = function()
          return nil
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getSpellCooldownSafe = function()
          return 0, 0, false
        end,
        applyCooldownFrameSafe = function() end,
        getSpellTexture = function()
          return nil
        end,
        getDungeonShortCode = function(mapID)
          if mapID == 558 then
            return "MT"
          end
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()
      controller.UpdateButtons(nil, "invite")
      controller.UpdateButtons(12345, "invite")

      Assert.Equal(soundCalls, 0, "invite-driven target refreshes must not play the portal sound")
    end)
  end)

  test("Teleport debug output labels short cooldowns as GCD", function()
    local prints = {}

    WithGlobals({
      InCombatLockdown = function()
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_teleport_debug.lua" })
      local controller = addon.TeleportDebug.CreateController({
        printFn = function(msg)
          prints[#prints + 1] = tostring(msg)
        end,
        getL = function()
          return {}
        end,
        updateMPlusTeleportButton = function() end,
        resolveActiveTeleportSpellID = function()
          return 12345
        end,
        isSpellKnownSafe = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        getSpellCooldownSafe = function()
          return 100, 1.5, true
        end,
        formatCooldownSeconds = function(value)
          return tostring(value or 0)
        end,
        getLatestQueueState = function()
          return "Dungeon", 999, 12345, 558
        end,
        resolveMapIDByActivityID = function(activityID)
          if activityID == 999 then
            return 558
          end
          return nil
        end,
        resolveTeleportSpellIDByActivityID = function()
          return 12345
        end,
        resolveTeleportSpellIDByMapID = function(mapID)
          if mapID == 558 then
            return 12345
          end
          return nil
        end,
        getNormalizedActiveEntryInfo = function()
          return { active = true, activityID = 999, mapID = 558 }
        end,
        getCenterNoticeTeleportButton = function()
          return {
            IsShown = function()
              return true
            end,
            GetAttribute = function(_self, key)
              if key == "type" then
                return "spell"
              end
              if key == "spell" then
                return 12345
              end
              return nil
            end,
            spellID = 12345,
            mapName = "Terrasse der Magister",
            isActiveTarget = true,
          }
        end,
        getMplusTeleportButtons = function()
          return {}
        end,
        showCenterNotice = function() end,
        setLatestQueueState = function() end,
      })

      controller.PrintTeleportDebug()

      local foundGcd = false
      local foundRaw = false
      for _, line in ipairs(prints) do
        if line:find("cdType=gcd", 1, true) then
          foundGcd = true
        end
        if line:find("rawDuration=1.5", 1, true) then
          foundRaw = true
        end
      end

      Assert.True(foundGcd, "debug output must label short cooldowns as GCD")
      Assert.True(foundRaw, "debug output must expose the raw short cooldown duration")
    end)
  end)
end

-- Branch-coverage tests for the remaining TeleportDebug paths: missing center
-- button, long-cooldown ("teleport") branch, ready-state ("ready") branch via
-- enabled=false, grid loop with multiple buttons, ResolveHostedSpell scan via
-- activityIDs, and ForceTeleportTestTarget end-to-end.
local function RegisterTeleportDebugBranchTests(test, Assert, WithGlobals, LoadAddonModules)
  -- Build a dummy spell-attribute button stub. cooldown describes the button's
  -- own spellID cooldown via getSpellCooldownSafe.
  local function MakeSpellButton(opts)
    opts = opts or {}
    return {
      IsShown = function()
        return opts.shown ~= false
      end,
      GetAttribute = function(_self, key)
        if key == "type" then
          return "spell"
        end
        if key == "spell" then
          return opts.spellID
        end
        return nil
      end,
      spellID = opts.spellID,
      mapName = opts.mapName,
      isActiveTarget = opts.isActiveTarget == true,
    }
  end

  local function BuildController(opts)
    local addon = LoadAddonModules({ "isiLive_teleport_debug.lua" })
    return addon.TeleportDebug.CreateController(opts)
  end

  test("Teleport debug labels long cooldowns as 'teleport' on the resolved spell", function()
    local prints = {}
    WithGlobals({
      InCombatLockdown = function()
        return false
      end,
    }, function()
      local controller = BuildController({
        printFn = function(msg)
          prints[#prints + 1] = tostring(msg)
        end,
        getL = function()
          return {}
        end,
        updateMPlusTeleportButton = function() end,
        resolveActiveTeleportSpellID = function()
          return 12345
        end,
        isSpellKnownSafe = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 540
        end,
        getSpellCooldownSafe = function()
          return 1000, 600, true
        end,
        formatCooldownSeconds = function(value)
          return tostring(value or 0)
        end,
        getLatestQueueState = function()
          return "Dungeon", 999, 12345, 558
        end,
        resolveMapIDByActivityID = function()
          return 558
        end,
        resolveTeleportSpellIDByActivityID = function()
          return 12345
        end,
        resolveTeleportSpellIDByMapID = function()
          return 12345
        end,
        getNormalizedActiveEntryInfo = function()
          return { active = true, activityID = 999 }
        end,
        getCenterNoticeTeleportButton = function()
          return MakeSpellButton({ spellID = 12345, mapName = "Test", isActiveTarget = true })
        end,
        getMplusTeleportButtons = function()
          return {}
        end,
        showCenterNotice = function() end,
        setLatestQueueState = function() end,
      })
      controller.PrintTeleportDebug()

      local foundTeleport = false
      for _, line in ipairs(prints) do
        if line:find("cdType=teleport", 1, true) then
          foundTeleport = true
          break
        end
      end
      Assert.True(foundTeleport, "long cooldown must be labelled cdType=teleport")
    end)
  end)

  test("Teleport debug treats enabled=false as 'ready' on the resolved spell", function()
    local prints = {}
    WithGlobals({
      InCombatLockdown = function()
        return false
      end,
    }, function()
      local controller = BuildController({
        printFn = function(msg)
          prints[#prints + 1] = tostring(msg)
        end,
        getL = function()
          return {}
        end,
        updateMPlusTeleportButton = function() end,
        resolveActiveTeleportSpellID = function()
          return 12345
        end,
        isSpellKnownSafe = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        getSpellCooldownSafe = function()
          -- enabled=false must collapse to "ready" regardless of duration
          return 1000, 600, false
        end,
        formatCooldownSeconds = function(value)
          return tostring(value or 0)
        end,
        getLatestQueueState = function()
          return "Dungeon", 999, 12345, 558
        end,
        resolveMapIDByActivityID = function()
          return 558
        end,
        resolveTeleportSpellIDByActivityID = function()
          return 12345
        end,
        resolveTeleportSpellIDByMapID = function()
          return 12345
        end,
        getNormalizedActiveEntryInfo = function()
          return nil
        end,
        getCenterNoticeTeleportButton = function()
          return MakeSpellButton({ spellID = 12345 })
        end,
        getMplusTeleportButtons = function()
          return {}
        end,
        showCenterNotice = function() end,
        setLatestQueueState = function() end,
      })
      controller.PrintTeleportDebug()

      local foundReady = false
      for _, line in ipairs(prints) do
        if line:find("cdType=ready", 1, true) then
          foundReady = true
          break
        end
      end
      Assert.True(foundReady, "enabled=false must collapse to cdType=ready")
    end)
  end)

  test("Teleport debug emits <missing> for the center button when nil and iterates the grid loop", function()
    local prints = {}
    WithGlobals({
      InCombatLockdown = function()
        return false
      end,
    }, function()
      local controller = BuildController({
        printFn = function(msg)
          prints[#prints + 1] = tostring(msg)
        end,
        getL = function()
          return {}
        end,
        updateMPlusTeleportButton = function() end,
        resolveActiveTeleportSpellID = function()
          return nil
        end,
        isSpellKnownSafe = function()
          return false
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        getSpellCooldownSafe = function()
          return 0, 0, true
        end,
        formatCooldownSeconds = function(value)
          return tostring(value or 0)
        end,
        getLatestQueueState = function()
          return nil, nil, nil, nil
        end,
        resolveMapIDByActivityID = function()
          return nil
        end,
        resolveTeleportSpellIDByActivityID = function()
          return nil
        end,
        resolveTeleportSpellIDByMapID = function()
          return nil
        end,
        getNormalizedActiveEntryInfo = function()
          return nil
        end,
        getCenterNoticeTeleportButton = function()
          return nil
        end,
        getMplusTeleportButtons = function()
          return {
            MakeSpellButton({ spellID = 11111 }),
            MakeSpellButton({ spellID = 22222 }),
          }
        end,
        showCenterNotice = function() end,
        setLatestQueueState = function() end,
      })
      controller.PrintTeleportDebug()

      local foundMissing, foundGrid1, foundGrid2 = false, false, false
      for _, line in ipairs(prints) do
        if line:find("TP center: <missing>", 1, true) then
          foundMissing = true
        end
        if line:find("TP grid[1]", 1, true) then
          foundGrid1 = true
        end
        if line:find("TP grid[2]", 1, true) then
          foundGrid2 = true
        end
      end
      Assert.True(foundMissing, "missing center button must produce <missing> output")
      Assert.True(foundGrid1, "grid loop must dump button index 1")
      Assert.True(foundGrid2, "grid loop must dump button index 2")
    end)
  end)

  test("Teleport debug ResolveHostedSpell scans entryInfo.activityIDs when the primary activityID misses", function()
    local prints = {}
    WithGlobals({
      InCombatLockdown = function()
        return false
      end,
    }, function()
      local controller = BuildController({
        printFn = function(msg)
          prints[#prints + 1] = tostring(msg)
        end,
        getL = function()
          return {}
        end,
        updateMPlusTeleportButton = function() end,
        resolveActiveTeleportSpellID = function()
          return nil
        end,
        isSpellKnownSafe = function()
          return false
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        getSpellCooldownSafe = function()
          return 0, 0, true
        end,
        formatCooldownSeconds = function(value)
          return tostring(value or 0)
        end,
        getLatestQueueState = function()
          return nil, nil, nil, nil
        end,
        -- activityID 1 → no map; activityID 7 → map 558 → spell 12345
        resolveMapIDByActivityID = function(activityID)
          if activityID == 7 then
            return 558
          end
          return nil
        end,
        resolveTeleportSpellIDByActivityID = function()
          return nil
        end,
        resolveTeleportSpellIDByMapID = function(mapID)
          if mapID == 558 then
            return 12345
          end
          return nil
        end,
        getNormalizedActiveEntryInfo = function()
          return { active = true, activityID = 1, activityIDs = { 3, 7, 9 } }
        end,
        getCenterNoticeTeleportButton = function()
          return nil
        end,
        getMplusTeleportButtons = function()
          return {}
        end,
        showCenterNotice = function() end,
        setLatestQueueState = function() end,
      })
      controller.PrintTeleportDebug()

      local found = false
      for _, line in ipairs(prints) do
        if
          line:find("TP host detail", 1, true)
          and line:find("activityID=7", 1, true)
          and line:find("spell=12345", 1, true)
        then
          found = true
          break
        end
      end
      Assert.True(found, "activityIDs scan must surface the matching activity in TP host detail line")
    end)
  end)

  test("Teleport debug ForceTeleportTestTarget seeds queue state, refreshes button, shows notice", function()
    local prints = {}
    local seededState
    local centerNotice
    local refreshed = 0
    local controller = BuildController({
      printFn = function(msg)
        prints[#prints + 1] = tostring(msg)
      end,
      getL = function()
        return {
          TESTALL_DUMMY_DUNGEON = "Dawnbreaker",
          TESTALL_DUMMY_GROUP = "Test Group",
          UNKNOWN_GROUP = "?",
          JOINED_FROM_QUEUE_DUNGEON = "%s joined %s",
        }
      end,
      updateMPlusTeleportButton = function()
        refreshed = refreshed + 1
      end,
      resolveActiveTeleportSpellID = function() end,
      isSpellKnownSafe = function() end,
      getTeleportCooldownRemaining = function() end,
      getSpellCooldownSafe = function() end,
      formatCooldownSeconds = function() end,
      getLatestQueueState = function() end,
      resolveMapIDByActivityID = function() end,
      resolveTeleportSpellIDByActivityID = function() end,
      resolveTeleportSpellIDByMapID = function(mapID)
        if mapID == 2662 then
          return 99999
        end
        return nil
      end,
      getNormalizedActiveEntryInfo = function() end,
      getCenterNoticeTeleportButton = function() end,
      getMplusTeleportButtons = function() end,
      showCenterNotice = function(msg, _duration, dungeon)
        centerNotice = { msg = msg, dungeon = dungeon }
      end,
      setLatestQueueState = function(dungeon, activityID, spellID, mapID)
        seededState = { dungeon = dungeon, activityID = activityID, spellID = spellID, mapID = mapID }
      end,
    })

    controller.ForceTeleportTestTarget()

    Assert.NotNil(seededState, "setLatestQueueState must be called")
    Assert.Equal(seededState.dungeon, "Dawnbreaker", "dungeon must come from L.TESTALL_DUMMY_DUNGEON")
    Assert.Equal(seededState.mapID, 2662, "target mapID must be hard-coded 2662")
    Assert.Equal(seededState.spellID, 99999, "spellID must be resolved via mapID")
    Assert.Equal(refreshed, 1, "updateMPlusTeleportButton must be called exactly once")
    Assert.NotNil(centerNotice, "center notice must be shown")
    Assert.Equal(centerNotice.dungeon, "Dawnbreaker", "center notice must carry the dungeon name")
    local found = false
    for _, line in ipairs(prints) do
      if line:find("Teleport test target set: Dawnbreaker", 1, true) then
        found = true
        break
      end
    end
    Assert.True(found, "confirmation message must be printed")
  end)
end

-- WoW frames cannot be destroyed. BuildButtons used to allocate a fresh button
-- per entry every time, so each rebuild stranded the previous generation on
-- mainFrame -- 4 frames plus roughly 44 textures per dungeon.
local function RegisterTeleportUIPoolingTests(test, Assert, WithGlobals, LoadAddonModules)
  local function BuildPoolingController(addon, createFrameStub, getEntriesRef)
    return addon.TeleportUI.CreateController({
      mainFrame = {
        GetFrameLevel = function()
          return 10
        end,
        GetFrameStrata = function()
          return "MEDIUM"
        end,
        CreateFontString = function()
          return {
            SetPoint = function() end,
            SetWidth = function() end,
            SetJustifyH = function() end,
            SetTextColor = function() end,
            SetWordWrap = function() end,
            SetNonSpaceWrap = function() end,
            SetText = function() end,
            Show = function() end,
            Hide = function() end,
          }
        end,
      },
      applySecureSpellToButton = function()
        return true
      end,
      getEntries = function()
        return getEntriesRef()
      end,
      getL = function()
        return {}
      end,
      isSpellKnown = function()
        return true
      end,
      getTeleportCooldownRemaining = function()
        return 0
      end,
      formatCooldownSeconds = function()
        return ""
      end,
      createFrame = createFrameStub,
    })
  end

  test("TeleportUI reuses teleport buttons across rebuilds instead of leaking frames", function()
    local createFrameStub, createdFrames = BuildTeleportUICreateFrameStub()
    local entries = {
      { spellID = 1, mapID = 101, mapName = "A" },
      { spellID = 2, mapID = 102, mapName = "B" },
    }

    WithGlobals({ CreateFrame = createFrameStub }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_teleport_ui.lua" })
      local controller = BuildPoolingController(addon, createFrameStub, function()
        return entries
      end)

      controller.BuildButtons()
      local framesAfterFirst = #createdFrames
      local firstButtons = { controller.GetButtons()[1], controller.GetButtons()[2] }
      Assert.Equal(#controller.GetButtons(), 2, "first build must produce one button per entry")

      controller.BuildButtons()
      Assert.Equal(#createdFrames, framesAfterFirst, "a rebuild must not allocate additional frames")
      Assert.Equal(controller.GetButtons()[1], firstButtons[1], "slot 1 must reuse the same button object")
      Assert.Equal(controller.GetButtons()[2], firstButtons[2], "slot 2 must reuse the same button object")
    end)
  end)

  test("TeleportUI rebinds pooled buttons to the new entry list", function()
    local createFrameStub, createdFrames = BuildTeleportUICreateFrameStub()
    local entries = {
      { spellID = 1, mapID = 101, mapName = "A" },
      { spellID = 2, mapID = 102, mapName = "B" },
      { spellID = 3, mapID = 103, mapName = "C" },
    }

    WithGlobals({ CreateFrame = createFrameStub }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_teleport_ui.lua" })
      local controller = BuildPoolingController(addon, createFrameStub, function()
        return entries
      end)

      controller.BuildButtons()
      local framesAfterFirst = #createdFrames
      local pooledThird = controller.GetButtons()[3]

      -- Season change to a shorter list: surplus buttons stay pooled, not stranded.
      entries = { { spellID = 9, mapID = 909, mapName = "Z" } }
      controller.BuildButtons()
      Assert.Equal(#controller.GetButtons(), 1, "the active button list must follow the new entry count")
      Assert.Equal(controller.GetButtons()[1].spellID, 9, "the reused button must carry the new entry's spell")
      Assert.Equal(controller.GetButtons()[1].mapID, 909, "the reused button must carry the new entry's map")

      -- Growing again must pick the pooled button back up, not allocate.
      entries = {
        { spellID = 4, mapID = 104, mapName = "D" },
        { spellID = 5, mapID = 105, mapName = "E" },
        { spellID = 6, mapID = 106, mapName = "F" },
      }
      controller.BuildButtons()
      Assert.Equal(#createdFrames, framesAfterFirst, "growing back must reuse pooled buttons")
      Assert.Equal(controller.GetButtons()[3], pooledThird, "slot 3 must come back from the pool")
      Assert.Equal(controller.GetButtons()[3].spellID, 6, "the pooled button must be rebound to the new entry")
    end)
  end)
end

local function RegisterTeleportUITests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportUIPoolingTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportUIEmptyStateTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportUIVisualTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportUIAudioAndDebugTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportDebugBranchTests(test, Assert, WithGlobals, LoadAddonModules)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterTeleportUITests(test, Assert, WithGlobals, LoadAddonModules)
end
