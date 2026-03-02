---@diagnostic disable: undefined-global

local function CreateTextureStub()
  local texture = {}
  texture.SetHeight = function(_self, _value) end
  texture.SetPoint = function(_self, _point, _relativeTo, _relativePoint, _x, _y) end
  texture.SetAllPoints = function(_self) end
  texture.SetColorTexture = function(_self, _r, _g, _b, _a) end
  texture.Hide = function(_self) end
  texture.Show = function(_self) end
  return texture
end

local function CreateFontStringStub()
  local fontSize = 14
  local stub = {
    _point = nil,
    _wordWrap = nil,
    _nonSpaceWrap = nil,
    _maxLines = nil,
  }

  stub.SetPoint = function(self, ...)
    self._point = { ... }
  end
  stub.SetJustifyH = function(_self, _value) end
  stub.SetJustifyV = function(_self, _value) end
  stub.SetText = function(_self, _value) end
  stub.SetTextColor = function(_self, _r, _g, _b, _a) end
  stub.SetShadowOffset = function(_self, _x, _y) end
  stub.SetWidth = function(_self, _value) end
  stub.SetWordWrap = function(self, value)
    self._wordWrap = value
  end
  stub.SetNonSpaceWrap = function(self, value)
    self._nonSpaceWrap = value
  end
  stub.SetMaxLines = function(self, value)
    self._maxLines = value
  end
  stub.GetFont = function(_self)
    return "Fonts\\FRIZQT__.TTF", fontSize, ""
  end
  stub.SetFont = function(_self, _path, size, _flags)
    fontSize = tonumber(size) or fontSize
  end

  return stub
end

local function CreateFrameStubFactory(createdFrames)
  return function(frameType, name, parent, template)
    local frame = {
      _frameType = frameType,
      _name = name,
      _parent = parent,
      _template = template,
      _scripts = {},
      _point = nil,
      _fontStrings = {},
      _textures = {},
    }

    frame.SetSize = function(_self, _w, _h) end
    frame.SetPoint = function(self, ...)
      self._point = { ... }
    end
    frame.SetHeight = function(self, h)
      self._height = h
    end
    frame.EnableMouse = function(self, enabled)
      self._mouseEnabled = enabled == true
    end
    frame.SetBackdrop = function(_self, _value) end
    frame.SetBackdropColor = function(_self, _r, _g, _b, _a) end
    frame.SetScript = function(self, scriptName, handler)
      self._scripts[scriptName] = handler
    end
    frame.CreateFontString = function(self)
      local font = CreateFontStringStub()
      self._fontStrings[#self._fontStrings + 1] = font
      if parent and parent._fontStrings then
        parent._fontStrings[#parent._fontStrings + 1] = font
      end
      return font
    end
    frame.CreateTexture = function(self)
      local texture = CreateTextureStub()
      self._textures[#self._textures + 1] = texture
      return texture
    end
    frame.SetText = function(_self, _text) end
    frame.SetEnabled = function(_self, _value) end
    frame.SetAlpha = function(_self, _value) end
    frame.SetChecked = function(self, value)
      self._checked = value == true
    end
    frame.GetChecked = function(self)
      return self._checked == true
    end
    frame.Hide = function(_self) end
    frame.Show = function(_self) end

    createdFrames[#createdFrames + 1] = frame
    return frame
  end
end

local function BuildMainFrameStub()
  local mainFrame = {
    _fontStrings = {},
  }
  mainFrame.SetBackdrop = function(_self, _value) end
  mainFrame.SetBackdropColor = function(_self, _r, _g, _b, _a) end
  mainFrame.CreateFontString = function(self)
    local font = CreateFontStringStub()
    self._fontStrings[#self._fontStrings + 1] = font
    return font
  end
  mainFrame.CreateTexture = function(_self)
    return CreateTextureStub()
  end
  return mainFrame
end

local function BuildRosterPanelController(addon, mainFrame, nowRef)
  local roster = {
    player = {
      name = "Alpha",
      keyMapID = 2660,
      keyLevel = 12,
    },
  }

  return addon.RosterPanel.CreateController({
    mainFrame = mainFrame,
    getL = function()
      return {
        TITLE = "isiKeyMPlus",
        COL_SPEC = "Spec",
        COL_NAME = "Name",
        COL_LANGUAGE = "Flag",
        COL_KEY = "Key",
        COL_ILVL = "iLvl",
        COL_RIO = "RIO",
        LEAD_OPTIONS = "Lead",
        MPLUS_MANAGEMENT = "M+",
        BTN_READYCHECK = "Readycheck",
        BTN_COUNTDOWN10 = "Countdown10",
        BTN_COUNTDOWN_CANCEL = "Countdown 0",
        BTN_REFRESH = "Refresh",
        BTN_SHARE_KEYS = "Share Keys",
        OPT_ADVANCED_COMBAT_LOGGING = "Combat Logging",
        OPT_DAMAGE_METER_RESET = "DM Reset on Entry",
        ANNOUNCE_PREFIX = "Party Keys:",
        TOOLTIP_READY = "ready",
        TOOLTIP_CD10 = "cd10",
        TOOLTIP_REFRESH = "refresh",
        TOOLTIP_CD_CANCEL = "cancel",
        TOOLTIP_ANNOUNCE_KEYS = "announce",
      }
    end,
    isPlayerLeader = function()
      return true
    end,
    getAddonVersionText = function()
      return "V.0"
    end,
    updateStatusLine = function() end,
    setMainFrameHeightSafe = function(_height) end,
    minFrameHeight = 212,
    buildOrderedRoster = function(sourceRoster, _rolePriority, _unitPriority)
      local info = sourceRoster.player
      return {
        {
          unit = "player",
          info = info,
        },
      }
    end,
    hasFullSync = function(_sourceRoster)
      return false
    end,
    buildDisplayData = function(info, _displayOpts)
      return {
        colorHex = "ffffffff",
        specText = "MM",
        roleIconMarkup = "",
        displayName = info.name or "Unknown",
        addonMarker = "",
        languageDisplay = "EN",
        keyText = "AK +12",
        ilvlText = "650",
        rioText = "3200",
      }
    end,
    truncateName = function(name)
      return name
    end,
    getShortSpecLabel = function(spec)
      return spec or ""
    end,
    getLanguageFlagMarkup = function(language)
      return tostring(language or "")
    end,
    getDungeonShortCode = function(_mapID)
      return "AK"
    end,
    getRioDelta = function(_info, _unit)
      return nil
    end,
    resolveActiveKeyOwnerUnit = function()
      return nil
    end,
    getRoster = function()
      return roster
    end,
    isInGroup = function()
      return true
    end,
    rolePriority = {
      TANK = 1,
      HEALER = 2,
      DAMAGER = 3,
      NONE = 4,
    },
    unitPriority = {
      player = 1,
    },
    syncMarker = "",
    fullSyncMarker = "",
    applyKnownKeyToRosterEntry = function(_info)
      return false
    end,
    getTime = function()
      return nowRef.now
    end,
    shareKeysDebounceSeconds = 1,
  })
end

local function FindShareKeysButton(createdFrames)
  for _, frame in ipairs(createdFrames) do
    if frame._template == "UIPanelButtonTemplate" and type(frame._point) == "table" then
      local point = frame._point
      if point[1] == "TOPRIGHT" and point[2] == -136 and point[3] == -180 then
        return frame
      end
    end
  end
  return nil
end

local function FindSystemOptionToggle(createdFrames, xOffset)
  for _, frame in ipairs(createdFrames) do
    if frame._frameType == "CheckButton" and type(frame._point) == "table" then
      local point = frame._point
      if point[1] == "BOTTOMLEFT" and point[2] == xOffset and point[3] == 24 then
        return frame
      end
    end
  end
  return nil
end

local function FindSystemOptionWatcher(createdFrames, mainFrame)
  for _, frame in ipairs(createdFrames) do
    local hasOnUpdate = frame._scripts and type(frame._scripts.OnUpdate) == "function"
    if frame._frameType == "Frame" and frame._parent == mainFrame and hasOnUpdate then
      return frame
    end
  end
  return nil
end

local function FilterRowFontStringsAtYOffset(fontStrings, yOffset)
  local out = {}
  for _, font in ipairs(fontStrings) do
    local point = font._point
    if type(point) == "table" then
      for _, value in ipairs(point) do
        if value == yOffset then
          out[#out + 1] = font
          break
        end
      end
    end
  end
  return out
end

local function FindFirstRowHoverFrame(createdFrames, mainFrame)
  for _, frame in ipairs(createdFrames) do
    if frame._parent == mainFrame and frame._height == 16 and frame._scripts and frame._scripts.OnEnter then
      return frame
    end
  end
  return nil
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Roster panel rows disable wrapping for all member text columns", function()
    local createdFrames = {}
    local nowRef = { now = 100 }
    local mainFrame = BuildMainFrameStub()

    WithGlobals({
      CreateFrame = CreateFrameStubFactory(createdFrames),
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildRosterPanelController(addon, mainFrame, nowRef)
      controller.RenderRoster({
        player = {
          name = "Alpha",
          keyMapID = 2660,
          keyLevel = 12,
        },
      })

      local rowFonts = FilterRowFontStringsAtYOffset(mainFrame._fontStrings, -52)
      Assert.Equal(#rowFonts, 6, "one roster row must create six non-wrapping text columns")

      for _, font in ipairs(rowFonts) do
        Assert.Equal(font._wordWrap, false, "row text must disable word wrap")
        Assert.Equal(font._nonSpaceWrap, false, "row text must disable non-space wrap")
        Assert.Equal(font._maxLines, 1, "row text must clamp to a single line")
      end
    end)
  end)

  test("Roster panel row hover shows and hides unit tooltip", function()
    local createdFrames = {}
    local nowRef = { now = 100 }
    local mainFrame = BuildMainFrameStub()
    local tooltipState = {
      defaultAnchorCalls = 0,
      setOwnerCalls = 0,
      setUnitCalls = 0,
      showCalls = 0,
      hideCalls = 0,
      lastUnit = nil,
    }
    local tooltipStub = {}

    tooltipStub.SetOwner = function(_self, _owner, _anchor)
      tooltipState.setOwnerCalls = tooltipState.setOwnerCalls + 1
    end
    tooltipStub.SetUnit = function(_self, unit)
      tooltipState.setUnitCalls = tooltipState.setUnitCalls + 1
      tooltipState.lastUnit = unit
    end
    tooltipStub.Show = function(_self)
      tooltipState.showCalls = tooltipState.showCalls + 1
    end
    tooltipStub.Hide = function(_self)
      tooltipState.hideCalls = tooltipState.hideCalls + 1
    end

    WithGlobals({
      CreateFrame = CreateFrameStubFactory(createdFrames),
      GameTooltip = tooltipStub,
      GameTooltip_SetDefaultAnchor = function(_tooltip, _owner)
        tooltipState.defaultAnchorCalls = tooltipState.defaultAnchorCalls + 1
      end,
      UnitExists = function(unit)
        return unit == "player"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildRosterPanelController(addon, mainFrame, nowRef)
      controller.RenderRoster({
        player = {
          name = "Alpha",
          keyMapID = 2660,
          keyLevel = 12,
        },
      })

      local hoverFrame = FindFirstRowHoverFrame(createdFrames, mainFrame)
      Assert.NotNil(hoverFrame, "roster row hover frame must exist")
      if type(hoverFrame) ~= "table" then
        return
      end
      Assert.Equal(hoverFrame.unit, "player", "hover frame should keep rendered unit token")

      local onEnter = hoverFrame._scripts and hoverFrame._scripts.OnEnter or nil
      local onLeave = hoverFrame._scripts and hoverFrame._scripts.OnLeave or nil
      Assert.True(type(onEnter) == "function", "hover frame must define OnEnter handler")
      Assert.True(type(onLeave) == "function", "hover frame must define OnLeave handler")
      if type(onEnter) ~= "function" or type(onLeave) ~= "function" then
        return
      end

      onEnter(hoverFrame)
      Assert.Equal(tooltipState.setUnitCalls, 1, "row hover should set tooltip unit exactly once")
      Assert.Equal(tooltipState.lastUnit, "player", "row hover should use row unit for tooltip")
      Assert.Equal(tooltipState.defaultAnchorCalls, 1, "row hover should use default tooltip anchoring when available")
      Assert.Equal(tooltipState.setOwnerCalls, 0, "default anchoring should avoid explicit SetOwner fallback")
      Assert.Equal(tooltipState.showCalls, 1, "row hover should explicitly show tooltip")

      onLeave(hoverFrame)
      Assert.Equal(tooltipState.hideCalls, 1, "row leave should hide tooltip")
    end)
  end)

  test("Roster panel row hover falls back to name tooltip when unit token is missing", function()
    local createdFrames = {}
    local nowRef = { now = 100 }
    local mainFrame = BuildMainFrameStub()
    local tooltipState = {
      defaultAnchorCalls = 0,
      setOwnerCalls = 0,
      setUnitCalls = 0,
      setTextCalls = 0,
      showCalls = 0,
      hideCalls = 0,
      lastText = nil,
    }
    local tooltipStub = {}

    tooltipStub.SetOwner = function(_self, _owner, _anchor)
      tooltipState.setOwnerCalls = tooltipState.setOwnerCalls + 1
    end
    tooltipStub.SetUnit = function(_self, _unit)
      tooltipState.setUnitCalls = tooltipState.setUnitCalls + 1
    end
    tooltipStub.SetText = function(_self, text)
      tooltipState.setTextCalls = tooltipState.setTextCalls + 1
      tooltipState.lastText = text
    end
    tooltipStub.Show = function(_self)
      tooltipState.showCalls = tooltipState.showCalls + 1
    end
    tooltipStub.Hide = function(_self)
      tooltipState.hideCalls = tooltipState.hideCalls + 1
    end

    WithGlobals({
      CreateFrame = CreateFrameStubFactory(createdFrames),
      GameTooltip = tooltipStub,
      GameTooltip_SetDefaultAnchor = function(_tooltip, _owner)
        tooltipState.defaultAnchorCalls = tooltipState.defaultAnchorCalls + 1
      end,
      UnitExists = function(_unit)
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildRosterPanelController(addon, mainFrame, nowRef)
      controller.RenderRoster({
        player = {
          name = "Alpha",
          realm = "Blackmoore",
          keyMapID = 2660,
          keyLevel = 12,
        },
      })

      local hoverFrame = FindFirstRowHoverFrame(createdFrames, mainFrame)
      Assert.NotNil(hoverFrame, "roster row hover frame must exist")
      if type(hoverFrame) ~= "table" then
        return
      end
      Assert.Equal(hoverFrame.unit, "player", "hover frame should keep rendered unit token")

      local onEnter = hoverFrame._scripts and hoverFrame._scripts.OnEnter or nil
      local onLeave = hoverFrame._scripts and hoverFrame._scripts.OnLeave or nil
      Assert.True(type(onEnter) == "function", "hover frame must define OnEnter handler")
      Assert.True(type(onLeave) == "function", "hover frame must define OnLeave handler")
      if type(onEnter) ~= "function" or type(onLeave) ~= "function" then
        return
      end

      onEnter(hoverFrame)
      Assert.Equal(tooltipState.setUnitCalls, 0, "fallback path must skip SetUnit when unit token is missing")
      Assert.Equal(tooltipState.setTextCalls, 1, "fallback path should set tooltip text exactly once")
      Assert.Equal(tooltipState.lastText, "Alpha-Blackmoore", "fallback tooltip should use name-realm text")
      Assert.Equal(tooltipState.defaultAnchorCalls, 1, "fallback tooltip should still use default anchoring")
      Assert.Equal(tooltipState.setOwnerCalls, 0, "default anchoring should avoid explicit SetOwner fallback")
      Assert.Equal(tooltipState.showCalls, 1, "fallback tooltip should be shown")

      onLeave(hoverFrame)
      Assert.Equal(tooltipState.hideCalls, 1, "row leave should hide fallback tooltip")
    end)
  end)

  test("Roster panel share keys button debounces rapid clicks", function()
    local createdFrames = {}
    local chatMessages = {}
    local nowRef = { now = 10 }
    local mainFrame = BuildMainFrameStub()

    WithGlobals({
      CreateFrame = CreateFrameStubFactory(createdFrames),
      C_ChatInfo = {
        SendChatMessage = function(message, _channel)
          chatMessages[#chatMessages + 1] = message
        end,
      },
      C_MythicPlus = {
        GetOwnedKeystoneLink = function()
          return "|cffa335ee|Hkeystone:180653:503:12:10:9:147:0:17|h[Keystone: Ara-Kara, City of Echoes (12)]|h|r"
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildRosterPanelController(addon, mainFrame, nowRef)
      local shareButton = FindShareKeysButton(createdFrames)
      Assert.NotNil(shareButton, "share keys button must exist")
      if type(shareButton) ~= "table" then
        return
      end

      local onClick = shareButton._scripts and shareButton._scripts.OnClick or nil
      Assert.True(type(onClick) == "function", "share keys button must define click handler")
      if type(onClick) ~= "function" then
        return
      end

      controller.RenderRoster({
        player = {
          name = "Alpha",
          keyMapID = 2660,
          keyLevel = 12,
        },
      })

      onClick(shareButton, "LeftButton")
      onClick(shareButton, "LeftButton")
      nowRef.now = 11.5
      onClick(shareButton, "LeftButton")

      Assert.Equal(#chatMessages, 2, "rapid second click must be blocked by debounce")
      Assert.True(
        type(chatMessages[1]) == "string" and chatMessages[1]:find("isiKeyMPlus PartyKeys: Alpha -> ", 1, true) ~= nil,
        "share output must include addon prefix and player name"
      )
      Assert.True(
        type(chatMessages[1]) == "string"
          and chatMessages[1]:find(
              "|Hkeystone:180653:503:12:10:9:147:0:17|h[Keystone: Ara-Kara, City of Echoes (12)]|h|r",
              1,
              true
            )
            ~= nil,
        "share output must use owned keystone hyperlink payload when available"
      )
      Assert.Equal(
        chatMessages[2],
        chatMessages[1],
        "debounced follow-up share should keep deterministic message format"
      )
    end)
  end)

  test("Roster panel system option toggles mirror live cvar state and write once on click", function()
    local createdFrames = {}
    local nowRef = { now = 100 }
    local mainFrame = BuildMainFrameStub()
    local cvarValues = {
      advancedCombatLogging = "1",
      damageMeterResetOnNewInstance = "0",
    }
    local setCalls = {}

    WithGlobals({
      CreateFrame = CreateFrameStubFactory(createdFrames),
      C_CVar = {
        GetCVar = function(name)
          return cvarValues[name]
        end,
        SetCVar = function(name, value)
          cvarValues[name] = tostring(value)
          setCalls[#setCalls + 1] = {
            name = name,
            value = tostring(value),
          }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildRosterPanelController(addon, mainFrame, nowRef)
      controller.ApplyLocalization()

      local combatLoggingToggle = FindSystemOptionToggle(createdFrames, 10)
      local damageMeterToggle = FindSystemOptionToggle(createdFrames, 220)
      Assert.NotNil(combatLoggingToggle, "combat logging toggle must exist")
      Assert.NotNil(damageMeterToggle, "damage meter reset toggle must exist")
      if type(combatLoggingToggle) ~= "table" or type(damageMeterToggle) ~= "table" then
        return
      end

      Assert.True(combatLoggingToggle:GetChecked(), "combat logging toggle should mirror enabled live cvar")
      Assert.False(damageMeterToggle:GetChecked(), "damage meter reset toggle should mirror disabled live cvar")

      local watcher = FindSystemOptionWatcher(createdFrames, mainFrame)
      Assert.NotNil(watcher, "system option watcher must exist")
      if type(watcher) ~= "table" then
        return
      end

      cvarValues.advancedCombatLogging = "0"
      local onUpdate = watcher._scripts and watcher._scripts.OnUpdate or nil
      Assert.True(type(onUpdate) == "function", "system option watcher must define OnUpdate handler")
      if type(onUpdate) ~= "function" then
        return
      end

      onUpdate(watcher, 5)
      Assert.False(
        combatLoggingToggle:GetChecked(),
        "watcher should re-read live cvar state from Blizzard settings while the window stays open"
      )

      damageMeterToggle:SetChecked(true)
      local onClick = damageMeterToggle._scripts and damageMeterToggle._scripts.OnClick or nil
      Assert.True(type(onClick) == "function", "damage meter toggle must define click handler")
      if type(onClick) ~= "function" then
        return
      end

      onClick(damageMeterToggle, "LeftButton")

      Assert.Equal(#setCalls, 1, "clicking toggle should write current state exactly once")
      Assert.Equal(setCalls[1].name, "damageMeterResetOnNewInstance", "toggle should write the matching cvar")
      Assert.Equal(setCalls[1].value, "1", "checked toggle should write enabled cvar value")
      Assert.True(damageMeterToggle:GetChecked(), "toggle should re-read and keep the new live cvar state")
    end)
  end)
end
