local function RegisterRosterDisplayColorTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster name color follows ready check status colors", function()
    local readyCheckStatusByUnit = {}

    WithGlobals({
      GetReadyCheckStatus = function(unit)
        return readyCheckStatusByUnit[unit]
      end,
      RAID_CLASS_COLORS = {
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
      },
      CreateColor = function(r, g, b)
        return {
          GenerateHexColor = function()
            return string.format("ff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
          end,
        }
      end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_roster.lua",
      })

      local info = {
        name = "TestPlayer",
        class = "WARRIOR",
        role = "DAMAGER",
      }

      readyCheckStatusByUnit.player = "ready"
      local readyData = addon.Roster.BuildDisplayData(info, {
        unit = "player",
        isReadyCheckActive = true,
      })
      Assert.Equal(readyData.colorHex, "ff00ff00", "Ready status should color name green")

      readyCheckStatusByUnit.player = "notready"
      local notReadyData = addon.Roster.BuildDisplayData(info, {
        unit = "player",
        isReadyCheckActive = true,
      })
      Assert.Equal(notReadyData.colorHex, "ffff0000", "Not-ready status should color name red")

      readyCheckStatusByUnit.player = "waiting"
      local waitingData = addon.Roster.BuildDisplayData(info, {
        unit = "player",
        isReadyCheckActive = true,
      })
      Assert.Equal(waitingData.colorHex, "ffffff00", "Waiting status should color name yellow")
    end)
  end)

  test("Roster name color resets to class color after ready check", function()
    local readyCheckStatusByUnit = {}
    local roster = {
      player = {
        name = "TestPlayer",
        class = "WARRIOR",
        role = "DAMAGER",
      },
    }

    WithGlobals({
      GetReadyCheckStatus = function(unit)
        return readyCheckStatusByUnit[unit]
      end,
      RAID_CLASS_COLORS = {
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
      },
      CreateColor = function(r, g, b)
        return {
          GenerateHexColor = function()
            return string.format("ff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
          end,
        }
      end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_roster.lua",
      })

      -- 1. Initial state: class color
      local displayDataInitial = addon.Roster.BuildDisplayData(roster.player, {
        unit = "player",
        isReadyCheckActive = false,
      })
      Assert.Equal(displayDataInitial.colorHex, "ffc69b6d", "Initial color should be warrior class color")

      -- 2. Ready check active, status 'ready': green
      readyCheckStatusByUnit.player = "ready"
      local displayDataReady = addon.Roster.BuildDisplayData(roster.player, {
        unit = "player",
        isReadyCheckActive = true,
      })
      Assert.Equal(displayDataReady.colorHex, "ff00ff00", "Ready status should color name green")

      -- 3. Ready check finished: back to class color
      local displayDataFinished = addon.Roster.BuildDisplayData(roster.player, {
        unit = "player",
        isReadyCheckActive = false,
      })
      Assert.Equal(displayDataFinished.colorHex, "ffc69b6d", "After ready check, color should reset to class color")
    end)
  end)

  test("Roster shows at-dungeon marker when unit map matches target", function()
    local roster = { party1 = { name = "Member" } }

    WithGlobals({
      GetReadyCheckStatus = function()
        return nil
      end,
      RAID_CLASS_COLORS = {},
      CreateColor = function()
        return {
          GenerateHexColor = function()
            return "ffffffff"
          end,
        }
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "party1" then
            return 1234
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster.lua" })

      local displayData = addon.Roster.BuildDisplayData(roster.party1, {
        unit = "party1",
        isAtDungeon = true, -- Logic is computed in RosterPanel, passed as flag to Roster
      })

      Assert.True(displayData.atDungeonMarker:find("Minimap_Summon_Icon") ~= nil, "should contain summon icon texture")
    end)
  end)

  test("Roster renders ghost member name in grey", function()
    local roster = {
      ["ghost:Player-Realm"] = {
        name = "GhostPlayer",
        class = "WARRIOR",
        role = "DAMAGER",
        isGhost = true,
      },
    }

    WithGlobals({
      GetReadyCheckStatus = function(_unit)
        return nil
      end,
      RAID_CLASS_COLORS = {},
      CreateColor = function()
        return {}
      end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_roster.lua",
      })

      local displayData = addon.Roster.BuildDisplayData(roster["ghost:Player-Realm"], {
        unit = "ghost:Player-Realm",
      })

      Assert.Equal(displayData.colorHex, "ff808080", "Ghost member should be rendered in grey")
    end)
  end)

  test("Roster renders offline member name in grey", function()
    local roster = {
      party1 = {
        name = "OfflinePlayer",
        class = "WARRIOR",
        role = "DAMAGER",
      },
    }

    WithGlobals({
      GetReadyCheckStatus = function(_unit)
        return "ready"
      end,
      UnitExists = function(unit)
        return unit == "party1"
      end,
      UnitIsConnected = function(unit)
        return unit ~= "party1"
      end,
      RAID_CLASS_COLORS = {
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
      },
      CreateColor = function(r, g, b)
        return {
          GenerateHexColor = function()
            return string.format("ff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
          end,
        }
      end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_roster.lua",
      })

      local displayData = addon.Roster.BuildDisplayData(roster.party1, {
        unit = "party1",
        isReadyCheckActive = true,
      })

      Assert.Equal(displayData.colorHex, "ff808080", "Offline member should be rendered in grey")
    end)
  end)
end

local function RegisterRosterDisplayMarkerTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster display appends blue-heart marker for synced users", function()
    WithGlobals({
      GetReadyCheckStatus = function()
        return nil
      end,
      RAID_CLASS_COLORS = {},
      CreateColor = function()
        return {
          GenerateHexColor = function()
            return "ffffffff"
          end,
        }
      end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_roster.lua",
      })

      local displayData = addon.Roster.BuildDisplayData({
        name = "SyncedPlayer",
        hasIsiLive = true,
      }, {
        syncMarker = " |TInterface\\AddOns\\isiLive\\media\\heart_sync:12:12|t",
      })

      Assert.True(
        displayData.addonMarker:find("heart_sync", 1, true) ~= nil,
        "synced users should receive the heart icon marker"
      )
    end)
  end)

  test("Roster display adds a sync badge when sync metadata exists", function()
    WithGlobals({
      GetReadyCheckStatus = function()
        return nil
      end,
      RAID_CLASS_COLORS = {},
      CreateColor = function()
        return {
          GenerateHexColor = function()
            return "ffffffff"
          end,
        }
      end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_roster.lua",
      })

      local displayData = addon.Roster.BuildDisplayData({
        name = "SyncedPlayer",
        hasIsiLive = true,
      }, {
        syncMarker = " |TInterface\\AddOns\\isiLive\\media\\heart_sync:12:12|t",
        syncBadge = " |TInterface\\Buttons\\UI-RefreshButton:12:12|t",
        syncSummary = {
          source = "refresh",
          capturedAt = 100,
          receivedAt = 100,
        },
      })

      Assert.True(
        displayData.addonMarker:find("UI%-RefreshButton", 1) ~= nil,
        "synced users with metadata should receive the refresh icon badge"
      )
    end)
  end)
end

local function RegisterRosterDisplayTruncationTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster display truncates names to Blizzard 12-character limit", function()
    WithGlobals({
      GetReadyCheckStatus = function()
        return nil
      end,
      RAID_CLASS_COLORS = {},
      CreateColor = function()
        return {
          GenerateHexColor = function()
            return "ffffffff"
          end,
        }
      end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_roster.lua",
      })

      local capturedMaxChars = nil
      local displayData = addon.Roster.BuildDisplayData({
        name = "VeryLongCharacterName",
      }, {
        truncateName = function(text, maxChars)
          capturedMaxChars = maxChars
          return string.sub(text, 1, maxChars)
        end,
      })

      Assert.Equal(capturedMaxChars, 12, "name display should use Blizzard's 12-character player-name limit")
      Assert.Equal(displayData.displayName, "VeryLongChar", "display name should be truncated to 12 characters")
    end)
  end)

  test("Roster display truncates spec labels to five characters", function()
    WithGlobals({
      GetReadyCheckStatus = function()
        return nil
      end,
      RAID_CLASS_COLORS = {},
      CreateColor = function()
        return {
          GenerateHexColor = function()
            return "ffffffff"
          end,
        }
      end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_roster.lua",
      })

      local capturedMaxChars = nil
      local displayData = addon.Roster.BuildDisplayData({
        name = "SpecPlayer",
        spec = "Shadow",
      }, {
        getShortSpecLabel = function(text)
          return text
        end,
        truncateName = function(text, maxChars)
          if text == "Shadow" then
            capturedMaxChars = maxChars
          end
          return string.sub(text, 1, maxChars)
        end,
      })

      Assert.Equal(capturedMaxChars, 5, "spec display should use the five-character limit")
      Assert.Equal(displayData.specText, "Shado", "five-character spec labels should remain intact")
    end)
  end)

  test("Roster display shows flag only without language letters", function()
    WithGlobals({
      GetReadyCheckStatus = function()
        return nil
      end,
      RAID_CLASS_COLORS = {},
      CreateColor = function()
        return {
          GenerateHexColor = function()
            return "ffffffff"
          end,
        }
      end,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_roster.lua",
      })

      local displayData = addon.Roster.BuildDisplayData({
        name = "FlagPlayer",
        language = "DE",
      }, {
        getLanguageFlagMarkup = function(tag)
          Assert.Equal(tag, "DE", "flag resolver should still receive the 2-letter language tag")
          return "|Tflag-de:0|t"
        end,
      })

      Assert.Equal(displayData.languageDisplay, "|Tflag-de:0|t", "language column should render only the flag markup")
    end)
  end)
end

local function RegisterRosterDisplayTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterDisplayColorTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterDisplayMarkerTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterDisplayTruncationTests(test, Assert, WithGlobals, LoadAddonModules)
end

local function NewRecordedFontString(createdFontStrings)
  local fontString = {
    wordWrap = nil,
    nonSpaceWrap = nil,
    maxLines = nil,
    width = nil,
    pointX = nil,
    pointY = nil,
    _shown = true,
  }

  function fontString.SetPoint(self, ...)
    local numericArgs = {}
    for index = 1, select("#", ...) do
      local value = select(index, ...)
      if type(value) == "number" then
        table.insert(numericArgs, value)
      end
    end
    if #numericArgs >= 2 then
      self.pointX = numericArgs[#numericArgs - 1]
      self.pointY = numericArgs[#numericArgs]
    elseif #numericArgs == 1 then
      self.pointX = 0
      self.pointY = numericArgs[1]
    end
  end
  function fontString.Hide(self)
    self._shown = false
  end
  function fontString.Show(self)
    self._shown = true
  end
  function fontString.IsShown(self)
    return self._shown
  end
  function fontString.SetWidth(self, value)
    self.width = value
  end
  function fontString.SetJustifyH() end
  function fontString.GetFont()
    return "font", 10, ""
  end
  function fontString.SetFont() end
  function fontString.SetTextColor() end
  function fontString.SetShadowOffset() end
  function fontString.SetText(self, value)
    self.text = value
  end
  function fontString.SetWordWrap(self, value)
    self.wordWrap = value
  end
  function fontString.SetNonSpaceWrap(self, value)
    self.nonSpaceWrap = value
  end
  function fontString.SetMaxLines(self, value)
    self.maxLines = value
  end

  table.insert(createdFontStrings, fontString)
  return fontString
end

local function NewRecordedTexture(createdTextures)
  local texture = {
    _shown = true,
    pointX = nil,
    pointY = nil,
    width = nil,
    height = nil,
  }

  function texture.SetPoint(self, ...)
    local numericArgs = {}
    for index = 1, select("#", ...) do
      local value = select(index, ...)
      if type(value) == "number" then
        table.insert(numericArgs, value)
      end
    end
    if #numericArgs >= 2 then
      self.pointX = numericArgs[#numericArgs - 1]
      self.pointY = numericArgs[#numericArgs]
    elseif #numericArgs == 1 then
      self.pointX = 0
      self.pointY = numericArgs[1]
    end
  end
  function texture.SetWidth(self, value)
    self.width = value
  end
  function texture.SetHeight(self, value)
    self.height = value
  end
  function texture.SetAllPoints(self)
    self.allPoints = true
  end
  function texture.SetColorTexture(self, r, g, b, a)
    self.color = { r, g, b, a }
  end
  function texture.SetTexture(self, value)
    self.texture = value
  end
  function texture.SetTexCoord(self, ...)
    self.texCoord = { ... }
  end
  function texture.Hide(self)
    self._shown = false
  end
  function texture.Show(self)
    self._shown = true
  end
  function texture.IsShown(self)
    return self._shown
  end

  table.insert(createdTextures, texture)
  return texture
end

local function NewRecordedFrame(createdFrames, createdFontStrings)
  local frame = {
    enabled = nil,
    alpha = nil,
    pointX = nil,
    pointY = nil,
    checked = false,
    attributes = {},
    _shown = true,
    _frameStrata = "MEDIUM",
    _frameLevel = 1,
  }

  function frame.SetSize() end
  function frame.SetHeight() end
  function frame.SetWidth() end
  function frame.SetPoint(self, ...)
    local numericArgs = {}
    for index = 1, select("#", ...) do
      local value = select(index, ...)
      if type(value) == "number" then
        table.insert(numericArgs, value)
      end
    end
    if #numericArgs >= 2 then
      self.pointX = numericArgs[#numericArgs - 1]
      self.pointY = numericArgs[#numericArgs]
    elseif #numericArgs == 1 then
      self.pointX = 0
      self.pointY = numericArgs[1]
    end
  end
  function frame.SetScript(self, script, handler)
    self[script] = handler
  end
  function frame.SetText(self, text)
    self.text = text
  end
  function frame.SetEnabled(self, value)
    self.enabled = value and true or false
  end
  function frame.SetAlpha(self, value)
    self.alpha = value
  end
  function frame.SetChecked(self, value)
    self.checked = value and true or false
  end
  function frame.GetChecked(self)
    return self.checked
  end
  function frame.SetAttribute(self, key, value)
    self.attributes[key] = value
  end
  function frame.GetAttribute(self, key)
    return self.attributes[key]
  end
  function frame.EnableMouse() end
  function frame.RegisterForClicks() end
  function frame.Hide(self)
    self._shown = false
  end
  function frame.Show(self)
    self._shown = true
  end
  function frame.SetShown(self, value)
    self._shown = value and true or false
  end
  function frame.IsShown(self)
    return self._shown
  end
  function frame.SetNormalTexture(self, value)
    self.normalTexture = value
  end
  function frame.SetPushedTexture(self, value)
    self.pushedTexture = value
  end
  function frame.SetHighlightTexture(self, value)
    self.highlightTexture = value
  end
  function frame.SetFrameStrata(self, value)
    self._frameStrata = value
  end
  function frame.GetFrameStrata(self)
    return self._frameStrata
  end
  function frame.SetFrameLevel(self, value)
    self._frameLevel = value
  end
  function frame.GetFrameLevel(self)
    return self._frameLevel
  end
  function frame.CreateTexture()
    local textures = rawget(frame, "_textures")
    if type(textures) ~= "table" then
      textures = {}
      frame._textures = textures
    end
    return NewRecordedTexture(textures)
  end
  function frame.CreateFontString()
    return NewRecordedFontString(createdFontStrings)
  end

  table.insert(createdFrames, frame)
  return frame
end

local function NewRecordedMainFrame(createdFontStrings, createdTextures)
  createdTextures = createdTextures or {}
  local mainFrame = {
    width = 0,
    _frameStrata = "MEDIUM",
    _frameLevel = 1,
    _textures = createdTextures,
  }

  function mainFrame.SetBackdrop() end
  function mainFrame.SetBackdropColor() end
  function mainFrame.SetWidth(self, value)
    self.width = value
  end
  function mainFrame.GetFrameStrata(self)
    return self._frameStrata
  end
  function mainFrame.GetFrameLevel(self)
    return self._frameLevel
  end
  function mainFrame.IsShown()
    return true
  end
  function mainFrame.CreateFontString()
    return NewRecordedFontString(createdFontStrings)
  end
  function mainFrame.CreateTexture()
    return NewRecordedTexture(createdTextures)
  end

  return mainFrame
end

local function FindFrameByProperty(createdFrames, key, value)
  for _, frame in ipairs(createdFrames) do
    if frame[key] == value then
      return frame
    end
  end

  return nil
end

local function GetTooltipLineTexts(tooltip)
  local texts = {}
  local lineCount = tonumber(tooltip and tooltip._isiLiveTooltipLineCount) or 0
  local lines = tooltip and tooltip._isiLiveTooltipLines or {}
  for index = 1, lineCount do
    local line = lines[index]
    if type(line) == "table" then
      table.insert(texts, tostring(line.text or ""))
    end
  end

  return texts
end

local function RegisterRosterPanelLeaderInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster panel leader-only buttons disable when player is not leader", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {
            BTN_READYCHECK = "Readycheck",
            BTN_COUNTDOWN10 = "Countdown10",
            BTN_COUNTDOWN_CANCEL = "Countdown 0",
          }
        end,
        isPlayerLeader = function()
          return false
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        buildOrderedRoster = function()
          return {}
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {}
        end,
        truncateName = function() end,
        getShortSpecLabel = function() end,
        getLanguageFlagMarkup = function() end,
        getDungeonShortCode = function() end,
        resolveActiveKeyOwnerUnit = function() end,
        getRoster = function()
          return {}
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {},
        unitPriority = {},
      })

      controller.ApplyLocalization()
      controller.UpdateLeaderButtons()

      local readyCheckButton = nil
      local countdownButton = nil
      local countdownCancelButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.text == "Readycheck" then
          readyCheckButton = frame
        elseif frame.text == "Countdown10" then
          countdownButton = frame
        elseif frame.text == "Countdown 0" then
          countdownCancelButton = frame
        end
      end

      Assert.NotNil(readyCheckButton, "ready-check button should exist")
      Assert.NotNil(countdownButton, "countdown button should exist")
      Assert.NotNil(countdownCancelButton, "countdown-cancel button should exist")
      ---@diagnostic disable: need-check-nil, undefined-field
      Assert.False(readyCheckButton.enabled, "ready-check button should be disabled for non-leaders")
      Assert.False(countdownButton.enabled, "countdown button should be disabled for non-leaders")
      Assert.False(countdownCancelButton.enabled, "countdown-cancel button should be disabled for non-leaders")
      Assert.Equal(readyCheckButton.alpha, 0.45, "ready-check button should be dimmed for non-leaders")
      Assert.Equal(countdownButton.alpha, 0.45, "countdown button should be dimmed for non-leaders")
      Assert.Equal(countdownCancelButton.alpha, 0.45, "countdown-cancel button should be dimmed for non-leaders")
      ---@diagnostic enable: need-check-nil, undefined-field
    end)
  end)
end

local function RegisterRosterPanelTooltipInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  test("RosterPanel control buttons use isolated cursor-anchored tooltips", function()
    local createdFrames = {}
    local sharedTooltipCalls = 0
    local deLocale = {
      BTN_READYCHECK = "Bereitcheck",
      BTN_COUNTDOWN10 = "Countdown10",
      BTN_COUNTDOWN_CANCEL = "Countdown 0",
      BTN_REFRESH = "Aktualisieren",
      BTN_SHARE_KEYS = "Keys teilen",
      OPT_ADVANCED_COMBAT_LOGGING = "Combat-Logging",
      OPT_DAMAGE_METER_RESET = "DM-Reset beim Betreten",
      TOOLTIP_REFRESH = "Alle iLvl/RIO-Werte aktualisieren.",
      TOOLTIP_LAYOUT_SWITCH = "Zum Wechseln klicken.",
      MODE_LAYOUT_M = "Erweitertes Haupt-Layout.",
      MODE_LAYOUT_V = "Kompaktes vertikales Layout.",
      MODE_LAYOUT_H = "Kompaktes horizontales Layout.",
      MODE_LAYOUT_M2 = "Horizontales Haupt-Layout.",
      COL_SPEC = "Spec",
      COL_NAME = "Name",
      COL_LANGUAGE = "",
      COL_KEY = "Key",
      COL_ILVL = "iLvl",
      COL_RIO = "RIO",
      COL_DPS = "DPS",
      PANEL_HEADER_SHORTCUTS = "Shortcuts",
      LEAD_OPTIONS = "M+Managment",
      MPLUS_MANAGEMENT = "Travel",
      TANK_HELPER_HEADER = "Marker",
    }
    local enLocale = {
      BTN_READYCHECK = "Readycheck",
      BTN_COUNTDOWN10 = "Countdown10",
      BTN_COUNTDOWN_CANCEL = "Countdown 0",
      BTN_REFRESH = "Refresh",
      BTN_SHARE_KEYS = "Share Keys",
      OPT_ADVANCED_COMBAT_LOGGING = "Combat Logging",
      OPT_DAMAGE_METER_RESET = "DM Reset on Entry",
      TOOLTIP_REFRESH = "Force refresh all iLvl/RIO values.",
      TOOLTIP_LAYOUT_SWITCH = "Click to switch layout.",
      MODE_LAYOUT_M = "Expanded main layout.",
      MODE_LAYOUT_V = "Compact vertical layout.",
      MODE_LAYOUT_H = "Compact horizontal layout.",
      MODE_LAYOUT_M2 = "Main horizontal layout.",
      COL_SPEC = "Spec",
      COL_NAME = "Name",
      COL_LANGUAGE = "",
      COL_KEY = "Key",
      COL_ILVL = "iLvl",
      COL_RIO = "RIO",
      COL_DPS = "DPS",
      PANEL_HEADER_SHORTCUTS = "Shortcuts",
      LEAD_OPTIONS = "M+Management",
      MPLUS_MANAGEMENT = "Travel",
      TANK_HELPER_HEADER = "Marker",
    }
    local currentLocale = deLocale
    local createFrameStub = function(frameType, _name, _parent)
      local frame = {
        _frameType = frameType,
        SetSize = function() end,
        SetPoint = function() end,
        SetScript = function(self, script, handler)
          self[script] = handler
        end,
        SetText = function() end,
        SetEnabled = function() end,
        SetAlpha = function() end,
        CreateFontString = function()
          return {
            SetPoint = function() end,
            SetWidth = function() end,
            SetJustifyH = function() end,
            GetFont = function()
              return "font", 10, ""
            end,
            SetFont = function() end,
            SetTextColor = function() end,
            SetShadowOffset = function() end,
            SetText = function(self, text)
              self.text = tostring(text or "")
            end,
            GetStringWidth = function(self)
              return #tostring(self.text or "") * 6
            end,
            SetWordWrap = function() end,
            SetNonSpaceWrap = function() end,
            SetMaxLines = function() end,
            Hide = function() end,
            Show = function() end,
          }
        end,
        Show = function(self)
          self._shown = true
        end,
        Hide = function(self)
          self._shown = false
        end,
        SetFrameStrata = function() end,
        SetClampedToScreen = function() end,
      }
      table.insert(createdFrames, frame)
      return frame
    end

    WithGlobals({
      CreateFrame = createFrameStub,
      GetTime = function()
        return 100
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
        Show = function()
          sharedTooltipCalls = sharedTooltipCalls + 1
        end,
        Hide = function()
          sharedTooltipCalls = sharedTooltipCalls + 1
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua", "isiLive_roster_panel.lua" })
      addon.Sync.SetPlayerHelloInfo("Buddy", "Realm", "0.9.36", 2, 90, "inspect")
      local controller = addon.RosterPanel.CreateController({
        mainFrame = {
          SetBackdrop = function() end,
          SetBackdropColor = function() end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              GetFont = function()
                return "font", 10, ""
              end,
              SetFont = function() end,
              SetTextColor = function() end,
              SetShadowOffset = function() end,
              SetText = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetMaxLines = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
          CreateTexture = function()
            return {
              SetHeight = function() end,
              SetPoint = function() end,
              SetColorTexture = function() end,
              SetTexture = function() end,
              SetTexCoord = function() end,
            }
          end,
        },
        getL = function()
          return currentLocale
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        buildOrderedRoster = function()
          return {}
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {}
        end,
        truncateName = function() end,
        getShortSpecLabel = function() end,
        getLanguageFlagMarkup = function() end,
        getDungeonShortCode = function() end,
        resolveActiveKeyOwnerUnit = function() end,
        getRoster = function()
          return {}
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {},
        unitPriority = {},
      })

      local refreshBtn = controller.GetRefreshButton()
      refreshBtn.OnEnter(refreshBtn)

      local privateTooltip = nil
      for _, frame in ipairs(createdFrames) do
        if frame._isIsiLiveTooltip == true and frame._isiLiveTooltipOwner ~= nil then
          privateTooltip = frame
          break
        end
      end

      Assert.NotNil(privateTooltip, "RosterPanel should allocate a private tooltip frame")
      ---@diagnostic disable: need-check-nil, undefined-field
      Assert.Equal(
        privateTooltip._isiLiveTooltipAnchor,
        "ANCHOR_CURSOR",
        "Refresh button tooltip must use cursor anchor"
      )
      ---@diagnostic enable: need-check-nil, undefined-field
      Assert.Equal(sharedTooltipCalls, 0, "RosterPanel control tooltips should not use the shared Blizzard GameTooltip")

      local expectedModeButtons = {
        { mode = "compact_main_horizontal", label = "M2", description = "MODE_LAYOUT_M2" },
        { mode = "compact_horizontal", label = "H", description = "MODE_LAYOUT_H" },
        { mode = "compact_vertical", label = "V", description = "MODE_LAYOUT_V" },
        { mode = "expanded", label = "M", description = "MODE_LAYOUT_M" },
      }

      for _, expected in ipairs(expectedModeButtons) do
        local modeButton = FindFrameByProperty(createdFrames, "_collapseLayoutMode", expected.mode)
        Assert.NotNil(modeButton, "Mode button " .. expected.label .. " should exist")
        ---@diagnostic disable: need-check-nil, undefined-field
        Assert.Equal(modeButton._modeLabel, expected.label, "Mode button should keep its label")
        Assert.True(
          type(modeButton.OnEnter) == "function",
          "Mode button " .. expected.label .. " should have a tooltip handler"
        )
        modeButton:OnEnter()
        Assert.Equal(
          privateTooltip._isiLiveTooltipOwner,
          modeButton,
          "Mode button " .. expected.label .. " tooltip should anchor to the hovered button"
        )
        Assert.Equal(
          privateTooltip._isiLiveTooltipAnchor,
          "ANCHOR_CURSOR",
          "Mode button " .. expected.label .. " tooltip must use cursor anchor"
        )
        local tooltipTexts = GetTooltipLineTexts(privateTooltip)
        Assert.Equal(tooltipTexts[1], expected.label, "Mode button tooltip should keep its short label")
        Assert.Equal(
          tooltipTexts[2],
          currentLocale[expected.description],
          "Mode button tooltip should use the active locale description"
        )
        Assert.Equal(
          tooltipTexts[3],
          currentLocale.TOOLTIP_LAYOUT_SWITCH,
          "Mode button tooltip should use the active locale click hint"
        )
        ---@diagnostic enable: need-check-nil, undefined-field
      end

      currentLocale = enLocale
      local m2Button = FindFrameByProperty(createdFrames, "_collapseLayoutMode", "compact_main_horizontal")
      Assert.NotNil(m2Button, "M2 button should still exist after locale switch")
      ---@diagnostic disable: need-check-nil, undefined-field
      m2Button:OnEnter()
      local englishTooltipTexts = GetTooltipLineTexts(privateTooltip)
      Assert.Equal(
        englishTooltipTexts[2],
        enLocale.MODE_LAYOUT_M2,
        "Mode button tooltip should refresh to English after locale switch"
      )
      Assert.Equal(
        englishTooltipTexts[3],
        enLocale.TOOLTIP_LAYOUT_SWITCH,
        "Mode button tooltip click hint should refresh to English after locale switch"
      )
      ---@diagnostic enable: need-check-nil, undefined-field
    end)
  end)
end

local function NewRowTooltipCreateFrameStub(createdFrames, tooltipLines, tooltipOps)
  return function(frameType)
    local f = {
      frameType = frameType,
    }

    f.SetPoint = function() end
    f.SetSize = function(_self, width, height)
      f.width = width
      f.height = height
    end
    f.SetHeight = function(_self, height)
      f.height = height
    end
    f.SetWidth = function(_self, width)
      f.width = width
    end
    f.SetEnabled = function() end
    f.SetAlpha = function() end
    f.EnableMouse = function() end
    f.RegisterForClicks = function() end
    f.SetScript = function(self, script, handler)
      self[script] = handler
    end
    f.CreateTexture = function()
      return {
        SetAllPoints = function() end,
        SetColorTexture = function() end,
        SetTexture = function() end,
        SetTexCoord = function() end,
        Hide = function() end,
        Show = function() end,
      }
    end
    f.CreateFontString = function()
      local fontString = {
        text = "",
        SetPoint = function() end,
        SetJustifyH = function() end,
        SetWidth = function() end,
        SetText = function(self, text)
          self.text = tostring(text or "")
          if f._isIsiLiveTooltip == true then
            table.insert(tooltipLines, self.text)
          end
        end,
        GetStringWidth = function(self)
          return #tostring(self.text or "") * 6
        end,
        SetWordWrap = function() end,
        SetNonSpaceWrap = function() end,
        SetMaxLines = function() end,
        Hide = function() end,
        Show = function() end,
      }
      return fontString
    end
    f.Hide = function()
      if tooltipOps and f._isIsiLiveTooltip == true then
        tooltipOps.hideCalls = (tooltipOps.hideCalls or 0) + 1
      end
    end
    f.Show = function()
      if tooltipOps and f._isIsiLiveTooltip == true then
        tooltipOps.showCalls = (tooltipOps.showCalls or 0) + 1
      end
    end

    if tooltipOps then
      f.ClearAllPoints = function() end
      f.SetOwner = function(_self, _anchorFrame, anchor)
        if f._isIsiLiveTooltip == true then
          tooltipOps.setOwnerCalls = (tooltipOps.setOwnerCalls or 0) + 1
          tooltipOps.lastAnchor = anchor
        end
      end
    end

    table.insert(createdFrames, f)
    return f
  end
end

local function RegisterRosterPanelRowTooltipLocalizedClassTest(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster row tooltip shows localized class instead of specialization", function()
    local tooltipLines = {}
    local createdFrames = {}
    local createFrameStub = NewRowTooltipCreateFrameStub(createdFrames, tooltipLines)

    WithGlobals({
      CreateFrame = createFrameStub,
      LOCALIZED_CLASS_NAMES_MALE = {
        MONK = "Monk",
      },
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function(_self, text)
          table.insert(tooltipLines, text)
        end,
        Show = function() end,
        Hide = function() end,
      },
      RAID_CLASS_COLORS = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = {
          SetBackdrop = function() end,
          SetBackdropColor = function() end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              GetFont = function()
                return "font", 10, ""
              end,
              SetFont = function() end,
              SetTextColor = function() end,
              SetShadowOffset = function() end,
              SetText = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetMaxLines = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
          CreateTexture = function()
            return {
              SetHeight = function() end,
              SetPoint = function() end,
              SetColorTexture = function() end,
              SetTexture = function() end,
              SetTexCoord = function() end,
            }
          end,
        },
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        buildOrderedRoster = function()
          return {
            {
              unit = "party1",
              info = { name = "Buddy", realm = "Realm", class = "MONK", spec = "Brewmaster", language = "DE" },
            },
          }
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Buddy",
            languageDisplay = "|Tflag-de:0|t",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(n)
          return n
        end,
        getShortSpecLabel = function(s)
          return s
        end,
        getLanguageFlagMarkup = function()
          return "|Tflag-de:0|t"
        end,
        getLanguageTooltipMarkup = function(tag)
          Assert.Equal(tag, "DE", "Tooltip helper should receive the 2-letter language tag")
          return "|Tflag-de:0|t Deutsch"
        end,
        getDungeonShortCode = function()
          return ""
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {}
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {},
        unitPriority = {},
      })

      controller.RenderRoster({})

      for _, f in ipairs(createdFrames) do
        if f.OnEnter and f.unit == "party1" then
          f.OnEnter()
          break
        end
      end

      local foundClass = false
      local foundSpec = false
      for _, line in ipairs(tooltipLines) do
        if line == "Class: Monk" then
          foundClass = true
        end
        if line == "Brewmaster" then
          foundSpec = true
        end
      end

      local privateTooltip = nil
      for _, frame in ipairs(createdFrames) do
        if frame._isIsiLiveTooltip == true then
          privateTooltip = frame
          break
        end
      end

      Assert.True(foundClass, "Tooltip should show the localized class name")
      Assert.False(foundSpec, "Tooltip should no longer show the specialization line when class info exists")
      Assert.NotNil(privateTooltip, "private tooltip should exist")
    end)
  end)
end

local function RegisterRosterPanelRowTooltipLevelAndLanguageTest(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster row tooltip shows level and language name", function()
    local tooltipLines = {}
    local createdFrames = {}
    local createFrameStub = NewRowTooltipCreateFrameStub(createdFrames, tooltipLines)

    WithGlobals({
      CreateFrame = createFrameStub,
      UnitExists = function(unit)
        return unit == "party1"
      end,
      UnitLevel = function(unit)
        if unit == "party1" then
          return 80
        end
        return nil
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function(_self, text)
          table.insert(tooltipLines, text)
        end,
        Show = function() end,
        Hide = function() end,
      },
      RAID_CLASS_COLORS = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = {
          SetBackdrop = function() end,
          SetBackdropColor = function() end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              GetFont = function()
                return "font", 10, ""
              end,
              SetFont = function() end,
              SetTextColor = function() end,
              SetShadowOffset = function() end,
              SetText = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetMaxLines = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
          CreateTexture = function()
            return {
              SetHeight = function() end,
              SetPoint = function() end,
              SetColorTexture = function() end,
              SetTexture = function() end,
              SetTexCoord = function() end,
            }
          end,
        },
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        buildOrderedRoster = function()
          return { { unit = "party1", info = { name = "Buddy", realm = "Realm", class = "WARRIOR", language = "DE" } } }
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Buddy",
            languageDisplay = "|Tflag-de:0|t",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(n)
          return n
        end,
        getShortSpecLabel = function(s)
          return s
        end,
        getLanguageFlagMarkup = function()
          return "|Tflag-de:0|t"
        end,
        getLanguageTooltipMarkup = function(tag)
          Assert.Equal(tag, "DE", "Tooltip helper should receive the 2-letter language tag")
          return "|Tflag-de:0|t Deutsch"
        end,
        getDungeonShortCode = function()
          return ""
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {}
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {},
        unitPriority = {},
      })

      controller.RenderRoster({})

      local rowFrame = nil
      for _, f in ipairs(createdFrames) do
        if f.OnEnter and f.unit == "party1" then
          f.OnEnter()
          if #tooltipLines > 0 then
            rowFrame = f
            break
          end
        end
      end

      Assert.NotNil(rowFrame, "Should find a row frame with OnEnter")
      local foundLevel = false
      local foundLanguage = false
      local foundLanguageText = false
      for _, line in ipairs(tooltipLines) do
        if line == "Level: 80" then
          foundLevel = true
        end
        if line == "|Tflag-de:0|t Deutsch" then
          foundLanguage = true
        end
        if line:find("Lang:", 1, true) then
          foundLanguageText = true
        end
      end
      Assert.True(foundLevel, "Tooltip should contain the player level")
      Assert.True(foundLanguage, "Tooltip should contain the server language name")
      Assert.False(foundLanguageText, "Tooltip should not show language letters anymore")
    end)
  end)

  test("Roster row tooltip skips UnitLevel for missing units", function()
    local tooltipLines = {}
    local createdFrames = {}
    local createFrameStub = NewRowTooltipCreateFrameStub(createdFrames, tooltipLines)

    WithGlobals({
      CreateFrame = createFrameStub,
      UnitExists = function(unit)
        return unit == "player"
      end,
      UnitLevel = function(_unit)
        error("UnitLevel must not be called for missing units")
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function(_self, text)
          table.insert(tooltipLines, text)
        end,
        Show = function() end,
        Hide = function() end,
      },
      RAID_CLASS_COLORS = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = {
          SetBackdrop = function() end,
          SetBackdropColor = function() end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              GetFont = function()
                return "font", 10, ""
              end,
              SetFont = function() end,
              SetTextColor = function() end,
              SetShadowOffset = function() end,
              SetText = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetMaxLines = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
          CreateTexture = function()
            return {
              SetHeight = function() end,
              SetPoint = function() end,
              SetColorTexture = function() end,
              SetTexture = function() end,
              SetTexCoord = function() end,
            }
          end,
        },
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        buildOrderedRoster = function()
          return {
            {
              unit = "party1",
              info = { name = "Buddy", realm = "Realm", class = "WARRIOR", language = "DE" },
            },
          }
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Buddy",
            languageDisplay = "|Tflag-de:0|t",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(n)
          return n
        end,
        getShortSpecLabel = function(s)
          return s
        end,
        getLanguageFlagMarkup = function()
          return "|Tflag-de:0|t"
        end,
        getLanguageTooltipMarkup = function(tag)
          Assert.Equal(tag, "DE", "Tooltip helper should receive the 2-letter language tag")
          return "|Tflag-de:0|t Deutsch"
        end,
        getDungeonShortCode = function()
          return ""
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {}
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {},
        unitPriority = {},
      })

      controller.RenderRoster({})

      local rowFrame = nil
      for _, f in ipairs(createdFrames) do
        if f.OnEnter and f.unit == "party1" then
          f.OnEnter()
          if #tooltipLines > 0 then
            rowFrame = f
            break
          end
        end
      end

      Assert.NotNil(rowFrame, "Should find a row frame with OnEnter")
      local foundLevel = false
      local foundLanguage = false
      local foundLanguageText = false
      for _, line in ipairs(tooltipLines) do
        if line:find("Level:", 1, true) then
          foundLevel = true
        end
        if line == "|Tflag-de:0|t Deutsch" then
          foundLanguage = true
        end
        if line:find("Lang:", 1, true) then
          foundLanguageText = true
        end
      end
      Assert.False(foundLevel, "Tooltip must not query level for missing units")
      Assert.True(foundLanguage, "Tooltip should still show the server language name")
      Assert.False(foundLanguageText, "Tooltip should not show language letters anymore")
    end)
  end)
end

local function RegisterRosterPanelRowTooltipUnknownKeyTest(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster row tooltip keeps unknown key short code unresolved instead of showing numeric map ids", function()
    local tooltipLines = {}
    local createdFrames = {}
    local createFrameStub = NewRowTooltipCreateFrameStub(createdFrames, tooltipLines)

    WithGlobals({
      CreateFrame = createFrameStub,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function(_self, text)
          table.insert(tooltipLines, text)
        end,
        Show = function() end,
        Hide = function() end,
      },
      RAID_CLASS_COLORS = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = {
          SetBackdrop = function() end,
          SetBackdropColor = function() end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              GetFont = function()
                return "font", 10, ""
              end,
              SetFont = function() end,
              SetTextColor = function() end,
              SetShadowOffset = function() end,
              SetText = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetMaxLines = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
          CreateTexture = function()
            return {
              SetHeight = function() end,
              SetPoint = function() end,
              SetColorTexture = function() end,
              SetTexture = function() end,
              SetTexCoord = function() end,
            }
          end,
        },
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        buildOrderedRoster = function()
          return {
            {
              unit = "party1",
              info = { name = "Buddy", realm = "Realm", class = "WARRIOR", keyMapID = 2287, keyLevel = 14 },
            },
          }
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Buddy",
            languageDisplay = "",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(n)
          return n
        end,
        getShortSpecLabel = function(s)
          return s
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return nil
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {}
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {},
        unitPriority = {},
      })

      controller.RenderRoster({})

      for _, f in ipairs(createdFrames) do
        if f.OnEnter and f.unit == "party1" then
          f.OnEnter()
          break
        end
      end
    end)

    local foundUnknownKey = false
    local foundNumericKey = false
    for _, line in ipairs(tooltipLines) do
      if line == "Key: ? +14" then
        foundUnknownKey = true
      end
      if line:find("2287", 1, true) then
        foundNumericKey = true
      end
    end
    Assert.True(foundUnknownKey, "Tooltip should keep unresolved keys as '?' instead of exposing numeric map ids")
    Assert.False(foundNumericKey, "Tooltip must not show numeric map ids for unresolved key short codes")
  end)
end

local function RegisterRosterPanelRowTooltipMetadataTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipLocalizedClassTest(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipLevelAndLanguageTest(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipUnknownKeyTest(test, Assert, WithGlobals, LoadAddonModules)
end

local function RegisterRosterPanelRowTooltipIsolationTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster row tooltip stays off the shared Blizzard GameTooltip path", function()
    local tooltipLines = {}
    local createdFrames = {}
    local privateTooltipOps = {}
    local sharedTooltipCalls = {
      setOwner = 0,
      setText = 0,
      addLine = 0,
      show = 0,
      hide = 0,
      setUnit = 0,
    }

    WithGlobals({
      CreateFrame = NewRowTooltipCreateFrameStub(createdFrames, tooltipLines, privateTooltipOps),
      GameTooltip = {
        SetOwner = function()
          sharedTooltipCalls.setOwner = sharedTooltipCalls.setOwner + 1
        end,
        SetText = function()
          sharedTooltipCalls.setText = sharedTooltipCalls.setText + 1
        end,
        AddLine = function()
          sharedTooltipCalls.addLine = sharedTooltipCalls.addLine + 1
        end,
        Show = function()
          sharedTooltipCalls.show = sharedTooltipCalls.show + 1
        end,
        Hide = function()
          sharedTooltipCalls.hide = sharedTooltipCalls.hide + 1
        end,
        SetUnit = function()
          sharedTooltipCalls.setUnit = sharedTooltipCalls.setUnit + 1
        end,
      },
      RAID_CLASS_COLORS = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = {
          SetBackdrop = function() end,
          SetBackdropColor = function() end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              GetFont = function()
                return "font", 10, ""
              end,
              SetFont = function() end,
              SetTextColor = function() end,
              SetShadowOffset = function() end,
              SetText = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetMaxLines = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
          CreateTexture = function()
            return {
              SetHeight = function() end,
              SetPoint = function() end,
              SetColorTexture = function() end,
              SetTexture = function() end,
              SetTexCoord = function() end,
            }
          end,
        },
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        buildOrderedRoster = function()
          return { { unit = "party1", info = { name = "Buddy", realm = "Realm", class = "WARRIOR" } } }
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Buddy",
            languageDisplay = "",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(n)
          return n
        end,
        getShortSpecLabel = function(s)
          return s
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return ""
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {}
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {},
        unitPriority = {},
      })

      controller.RenderRoster({})

      for _, f in ipairs(createdFrames) do
        if f.OnEnter and f.unit == "party1" then
          f.OnEnter()
          f.OnLeave()
          break
        end
      end
    end)

    Assert.True(#tooltipLines > 0, "private roster tooltip should still render content")
    Assert.Equal(sharedTooltipCalls.setOwner, 0, "row hover must not re-anchor the shared Blizzard GameTooltip")
    Assert.Equal(sharedTooltipCalls.setText, 0, "row hover must not write to the shared Blizzard GameTooltip")
    Assert.Equal(sharedTooltipCalls.addLine, 0, "row hover must not add lines to the shared Blizzard GameTooltip")
    Assert.Equal(sharedTooltipCalls.show, 0, "row hover must not show the shared Blizzard GameTooltip")
    Assert.Equal(sharedTooltipCalls.hide, 0, "row hover must not hide the shared Blizzard GameTooltip")
    Assert.Equal(sharedTooltipCalls.setUnit, 0, "row hover must not call SetUnit on the shared Blizzard GameTooltip")
    local privateTooltip = nil
    for _, frame in ipairs(createdFrames) do
      if frame._isIsiLiveTooltip == true and frame._isiLiveTooltipOwner ~= nil then
        privateTooltip = frame
        break
      end
    end

    Assert.NotNil(privateTooltip, "private roster tooltip frame should exist")
    ---@diagnostic disable: need-check-nil, undefined-field
    Assert.Equal(
      privateTooltip._isiLiveTooltipAnchor,
      "ANCHOR_CURSOR",
      "private roster tooltip should keep cursor anchoring"
    )
    Assert.True(privateTooltip._isiLiveTooltipOwner ~= nil, "private roster tooltip should keep its hover owner")
    ---@diagnostic enable: need-check-nil, undefined-field
  end)
end

local function RegisterRosterPanelRowTooltipTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipMetadataTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipIsolationTests(test, Assert, WithGlobals, LoadAddonModules)
end

local function FindInteractiveRosterRow(createdFrames)
  for _, frame in ipairs(createdFrames) do
    if frame.unit == "party1" and type(frame.OnMouseUp) == "function" then
      return frame
    end
  end

  return nil
end

local function FindWorldMarkerButtons(createdFrames)
  local buttons = {}
  for _, frame in ipairs(createdFrames) do
    if frame.attributes and frame.attributes.type1 == "worldmarker" and frame.attributes.type2 == "worldmarker" then
      table.insert(buttons, frame)
    end
  end

  return buttons
end

local function FindM2ColumnGuides(createdTextures)
  local guides = {}
  for _, texture in ipairs(createdTextures or {}) do
    if texture._m2ColumnGuide then
      guides[texture._guideKey] = texture
    end
  end

  return guides
end

local function RegisterRosterPanelRowInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster row left-click does not call protected targeting from insecure row UI", function()
    local createdFrames = {}
    local targetCalls = 0

    WithGlobals({
      CreateFrame = function()
        local frame = {
          attributes = {},
          SetPoint = function() end,
          SetSize = function() end,
          SetHeight = function() end,
          SetWidth = function() end,
          SetEnabled = function() end,
          SetAlpha = function() end,
          EnableMouse = function() end,
          RegisterForClicks = function() end,
          SetScript = function(self, script, handler)
            self[script] = handler
          end,
          SetAttribute = function(self, key, value)
            self.attributes[key] = value
          end,
          GetAttribute = function(self, key)
            return self.attributes[key]
          end,
          CreateTexture = function()
            return {
              SetAllPoints = function() end,
              SetColorTexture = function() end,
              SetTexture = function() end,
              SetTexCoord = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetJustifyH = function() end,
              SetWidth = function() end,
              SetText = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetMaxLines = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
          Hide = function() end,
          Show = function() end,
        }
        table.insert(createdFrames, frame)
        return frame
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      TargetUnit = function()
        targetCalls = targetCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame({}),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        buildOrderedRoster = function()
          return { { unit = "party1", info = { name = "Buddy", role = "DAMAGER" } } }
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Buddy",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return ""
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {}
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {},
        unitPriority = {},
      })

      controller.RenderRoster({})

      local rowFrame = FindInteractiveRosterRow(createdFrames)
      Assert.NotNil(rowFrame, "interactive roster row should exist")

      ---@diagnostic disable-next-line: need-check-nil
      rowFrame.OnMouseUp(nil, "LeftButton")
      Assert.Equal(targetCalls, 0, "left-click must not invoke protected targeting from the roster row")
    end)
  end)
end

local function RegisterRosterPanelShareKeysTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster panel share keys button debounces rapid clicks", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local sentMessages = {}
    local currentTime = 100

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      C_ChatInfo = {
        SendChatMessage = function(text, channel)
          table.insert(sentMessages, {
            text = text,
            channel = channel,
          })
        end,
      },
      print = function() end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        buildOrderedRoster = function(roster)
          return {
            { unit = "player", info = roster.player },
          }
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Self",
            languageDisplay = "EN",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {
            player = {
              name = "Self",
              role = "DAMAGER",
              keyMapID = 2441,
              keyLevel = 10,
            },
          }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          player = 1,
        },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 1,
      })

      controller.RenderRoster({
        player = {
          name = "Self",
          role = "DAMAGER",
          keyMapID = 2441,
          keyLevel = 10,
        },
      })

      local shareKeysButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -150 then
          shareKeysButton = frame
          break
        end
      end

      Assert.NotNil(shareKeysButton, "share-keys button should exist")
      ---@diagnostic disable: need-check-nil, undefined-field
      shareKeysButton.OnClick()
      shareKeysButton.OnClick()
      Assert.Equal(#sentMessages, 1, "rapid repeated share-keys clicks should be debounced")
      Assert.Equal(sentMessages[1].channel, "PARTY", "share-keys should announce to party chat")

      currentTime = 101.5
      shareKeysButton.OnClick()
      ---@diagnostic enable: need-check-nil, undefined-field
      Assert.Equal(#sentMessages, 2, "share-keys click should fire again after debounce window")
    end)
  end)
end

local function RegisterRosterPanelHiddenSettingDefaultTests(test, Assert, WithGlobals, LoadAddonModules)
  local function BuildHiddenSettingTestController(addon, createdFontStrings, opts)
    opts = opts or {}
    return addon.RosterPanel.CreateController({
      mainFrame = NewRecordedMainFrame(createdFontStrings, opts.createdTextures),
      getL = function()
        return {
          TITLE = "isiLive",
          COL_SPEC = "Spec",
          COL_NAME = "Name",
          COL_LANGUAGE = "Lang",
          COL_KEY = "Key",
          COL_ILVL = "iLvl",
          COL_RIO = "RIO",
          COL_DPS = "DPS",
          LEAD_OPTIONS = "Lead",
          MPLUS_MANAGEMENT = "M+",
          BTN_READYCHECK = "Readycheck",
          BTN_COUNTDOWN10 = "Countdown10",
          BTN_COUNTDOWN_CANCEL = "Countdown 0",
          BTN_REFRESH = "Refresh",
          BTN_SHARE_KEYS = "Share",
          OPT_ADVANCED_COMBAT_LOGGING = "ACL",
          OPT_DAMAGE_METER_RESET = "DMR",
          TANK_HELPER_HEADER = "Tank Helper",
        }
      end,
      isPlayerLeader = opts.isPlayerLeader or function()
        return true
      end,
      getAddonVersionText = function()
        return ""
      end,
      updateStatusLine = function() end,
      setMainFrameHeightSafe = function() end,
      buildOrderedRoster = opts.buildOrderedRoster or function()
        return {}
      end,
      hasFullSync = function()
        return false
      end,
      buildDisplayData = opts.buildDisplayData or function()
        return {}
      end,
      truncateName = function(text)
        return text
      end,
      getShortSpecLabel = function(text)
        return text
      end,
      getLanguageFlagMarkup = function()
        return ""
      end,
      getDungeonShortCode = function()
        return ""
      end,
      resolveActiveKeyOwnerUnit = function()
        return nil
      end,
      getRoster = function()
        return {}
      end,
      isInGroup = function()
        return true
      end,
      showRosterColumnGuides = opts.showRosterColumnGuides or function()
        local db = rawget(_G, "IsiLiveDB")
        return type(db) == "table" and db.showRosterColumnGuides == true
      end,
      rolePriority = opts.rolePriority or {},
      unitPriority = opts.unitPriority or {},
    })
  end

  test("Roster panel keeps hidden DPS setting hard-enabled even when DB disables it", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      IsiLiveDB = {
        showDpsColumn = false,
      },
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings, {
        buildOrderedRoster = function()
          return {
            {
              unit = "party1",
              info = {
                name = "Buddy",
                role = "DAMAGER",
              },
            },
          }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Buddy",
            languageDisplay = "EN",
            specText = "Fury",
            ilvlText = "650",
            rioText = "3000",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        rolePriority = {
          DAMAGER = 1,
        },
        unitPriority = {
          party1 = 1,
        },
      })

      controller.RenderRoster({})

      local dpsHeader = nil
      local rowDps = nil
      for _, fontString in ipairs(createdFontStrings) do
        if fontString.pointX == 380 and fontString.pointY == -34 then
          dpsHeader = fontString
        elseif fontString.pointX == 380 and fontString.pointY ~= -34 then
          rowDps = fontString
        end
      end

      Assert.NotNil(dpsHeader, "DPS header should exist")
      Assert.True(dpsHeader:IsShown(), "hidden settings must keep the DPS header visible")
      Assert.NotNil(rowDps, "row DPS cell should exist")
      Assert.True(rowDps:IsShown(), "hidden settings must keep row DPS values visible")
      Assert.Equal(rowDps.text, "-", "row DPS cell should still render the placeholder value")
    end)
  end)

  test("Roster panel keeps hidden marker setting visible for non-leaders even when DB enables leader-only", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      IsiLiveDB = {
        markersLeaderOnly = true,
      },
      InCombatLockdown = function()
        return false
      end,
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings, {
        isPlayerLeader = function()
          return false
        end,
      })

      controller.RenderRoster({})

      local tankButtons = FindWorldMarkerButtons(createdFrames)
      Assert.Equal(#tankButtons, 8, "marker helper should still create all eight world-marker buttons")
      for _, button in ipairs(tankButtons) do
        Assert.True(button:IsShown(), "hidden settings must keep world-marker buttons visible for non-leaders")
      end
    end)
  end)

  test("Roster panel keeps column guides disabled until the setting is enabled", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local createdTextures = {}

    WithGlobals({
      IsiLiveDB = {
        rosterDefaultLayoutMode = "compact_main_horizontal",
      },
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings, {
        createdTextures = createdTextures,
      })

      local guides = FindM2ColumnGuides(createdTextures)
      local expectedGuideX = {
        spec = 56,
        server = 93,
        name = 215,
        key = 268,
        ilvl = 304,
        rio = 378,
        dps = 420,
      }

      for guideKey, expectedX in pairs(expectedGuideX) do
        local guide = guides[guideKey]
        Assert.NotNil(guide, "M2 guide " .. guideKey .. " should exist")
        Assert.Equal(guide.pointX, expectedX, "M2 guide " .. guideKey .. " should sit at the expected boundary")
        Assert.False(guide:IsShown(), "column guides should start hidden while the setting is off")
      end

      IsiLiveDB.showRosterColumnGuides = true
      controller.RefreshLayoutState()

      for guideKey, _ in pairs(expectedGuideX) do
        Assert.True(guides[guideKey]:IsShown(), "column guides should be visible in the main layout when enabled")
      end

      controller.RestoreSavedState()

      for guideKey, _ in pairs(expectedGuideX) do
        Assert.True(guides[guideKey]:IsShown(), "column guides should stay visible in M2 when enabled")
      end

      controller.SwitchToRaidMode()

      for guideKey, _ in pairs(expectedGuideX) do
        Assert.False(guides[guideKey]:IsShown(), "column guides should hide again when leaving the main layout family")
      end
    end)
  end)

  test("Roster panel keeps the status line only in the main M layout", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      IsiLiveDB = {},
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings)

      local statusLine = controller.GetStatusLine()
      Assert.NotNil(statusLine, "status line should exist")
      Assert.True(statusLine:IsShown(), "status line should be visible in the main M layout")

      controller.RestoreSavedState()

      Assert.False(statusLine:IsShown(), "status line should hide in M2")
    end)
  end)

  test("Roster panel hides the main-panel combat logging and DM reset toggles", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      IsiLiveDB = {},
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      BuildHiddenSettingTestController(addon, createdFontStrings)

      local combatLoggingToggle = FindFrameByProperty(createdFrames, "_cvarName", "advancedCombatLogging")
      local damageMeterResetToggle = FindFrameByProperty(createdFrames, "_cvarName", "damageMeterResetOnNewInstance")

      Assert.NotNil(combatLoggingToggle, "combat logging toggle should exist in the main panel")
      Assert.NotNil(damageMeterResetToggle, "damage-meter reset toggle should exist in the main panel")
      Assert.False(combatLoggingToggle:IsShown(), "combat logging toggle should stay hidden in the main panel")
      Assert.False(damageMeterResetToggle:IsShown(), "DM reset toggle should stay hidden in the main panel")
    end)
  end)

  test("Roster panel restore prefers the configured default layout when opening", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      IsiLiveDB = {
        rosterLayoutMode = "compact_vertical",
        rosterDefaultLayoutMode = "compact_main_horizontal",
      },
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings)

      controller.RestoreSavedState()

      Assert.Equal(
        controller.GetLayoutMode(),
        "compact_main_horizontal",
        "configured default layout should override the saved layout mode when opening"
      )
      Assert.False(controller.IsCollapsed(), "configured default M2 layout should stay in the main horizontal mode")
    end)
  end)

  test("Roster panel defaults to M2 when no default is configured", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      IsiLiveDB = {},
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings)

      controller.RestoreSavedState()

      Assert.Equal(
        controller.GetLayoutMode(),
        "compact_main_horizontal",
        "without a configured default, the roster should open in M2"
      )
      Assert.False(controller.IsCollapsed(), "M2 should keep the roster visible")
    end)
  end)

  test("Roster panel restore honors explicit last-used default layout when configured", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      IsiLiveDB = {
        rosterLayoutMode = "compact_horizontal",
        rosterDefaultLayoutMode = "last_used",
      },
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings)

      controller.RestoreSavedState()

      Assert.Equal(
        controller.GetLayoutMode(),
        "compact_horizontal",
        "explicit last-used default should restore the saved compact layout"
      )
      Assert.True(controller.IsCollapsed(), "explicit last-used default should keep compact horizontal collapsed")
    end)
  end)
end

local function RegisterRosterPanelInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelLeaderInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelTooltipInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelShareKeysTests(test, Assert, WithGlobals, LoadAddonModules)
end

local function RegisterRosterPanelTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterDisplayTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelHiddenSettingDefaultTests(test, Assert, WithGlobals, LoadAddonModules)
end

return function(test, ctx)
  RegisterRosterPanelTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
