local function RegisterRosterDisplayColorTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster ready check uses row backgrounds and waiting icon without recoloring text", function()
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
      Assert.Equal(readyData.colorHex, "ffc69b6d", "Ready status must keep class-colored text")
      Assert.Equal(readyData.readyCheckStatus, "ready", "Ready status should be exposed for background rendering")
      Assert.Equal(readyData.readyCheckBackgroundColor[1], 0.08, "Ready status should tint row background green")
      Assert.Equal(readyData.readyCheckBackgroundColor[2], 0.5, "Ready status should tint row background green")
      Assert.Equal(readyData.readyCheckBackgroundColor[3], 0.16, "Ready status should tint row background green")
      Assert.Equal(readyData.readyCheckBackgroundColor[4], 0.42, "Ready status should tint row background green")
      Assert.Equal(readyData.readyCheckMarkup, "", "Ready status should not prepend waiting markup")

      readyCheckStatusByUnit.player = "notready"
      local notReadyData = addon.Roster.BuildDisplayData(info, {
        unit = "player",
        isReadyCheckActive = true,
      })
      Assert.Equal(notReadyData.colorHex, "ffc69b6d", "Not-ready status must keep class-colored text")
      Assert.Equal(
        notReadyData.readyCheckStatus,
        "notready",
        "Not-ready status should be exposed for background rendering"
      )
      Assert.Equal(notReadyData.readyCheckBackgroundColor[1], 0.48, "Not-ready status should tint row background red")
      Assert.Equal(notReadyData.readyCheckBackgroundColor[2], 0.12, "Not-ready status should tint row background red")
      Assert.Equal(notReadyData.readyCheckBackgroundColor[3], 0.12, "Not-ready status should tint row background red")
      Assert.Equal(notReadyData.readyCheckBackgroundColor[4], 0.34, "Not-ready status should tint row background red")
      Assert.Equal(notReadyData.readyCheckMarkup, "", "Not-ready status should not prepend waiting markup")

      readyCheckStatusByUnit.player = "waiting"
      local waitingData = addon.Roster.BuildDisplayData(info, {
        unit = "player",
        isReadyCheckActive = true,
      })
      Assert.Equal(waitingData.colorHex, "ffc69b6d", "Waiting status must keep class-colored text")
      Assert.Equal(waitingData.readyCheckStatus, "waiting", "Waiting status should be exposed for background rendering")
      Assert.Equal(waitingData.readyCheckBackgroundColor[1], 0.55, "Waiting status should tint row background yellow")
      Assert.Equal(waitingData.readyCheckBackgroundColor[2], 0.4, "Waiting status should tint row background yellow")
      Assert.Equal(waitingData.readyCheckBackgroundColor[3], 0.08, "Waiting status should tint row background yellow")
      Assert.Equal(waitingData.readyCheckBackgroundColor[4], 0.32, "Waiting status should tint row background yellow")
      Assert.True(
        waitingData.readyCheckMarkup:find("ReadyCheck%-Waiting:16:16", 1) ~= nil,
        "Waiting status should prepend the waiting icon markup"
      )
    end)
  end)

  test("Roster declined ready check stays red for 20 seconds after finish", function()
    local readyCheckStatusByUnit = {}
    local readyCheckDeclinedUntilByUnit = {}
    local now = 100
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
        getReadyCheckDeclinedUntil = function(unit)
          return readyCheckDeclinedUntilByUnit[unit]
        end,
        getTime = function()
          return now
        end,
      })
      Assert.Equal(displayDataInitial.colorHex, "ffc69b6d", "Initial color should be warrior class color")
      Assert.Nil(displayDataInitial.readyCheckBackgroundColor, "Initial state should not tint the row background")
      Assert.Equal(displayDataInitial.readyCheckMarkup, "", "Initial state should not prepend waiting markup")

      -- 2. Ready check active, status 'ready': background tint only
      readyCheckStatusByUnit.player = "ready"
      local displayDataReady = addon.Roster.BuildDisplayData(roster.player, {
        unit = "player",
        isReadyCheckActive = true,
        getReadyCheckDeclinedUntil = function(unit)
          return readyCheckDeclinedUntilByUnit[unit]
        end,
        getTime = function()
          return now
        end,
      })
      Assert.Equal(displayDataReady.colorHex, "ffc69b6d", "Ready state should keep class-colored text")
      Assert.NotNil(displayDataReady.readyCheckBackgroundColor, "Ready state should tint the row background")

      -- 3. After an explicit decline, the finished row stays red for 20 seconds
      readyCheckStatusByUnit.player = nil
      readyCheckDeclinedUntilByUnit.player = now + 20
      local displayDataHeld = addon.Roster.BuildDisplayData(roster.player, {
        unit = "player",
        isReadyCheckActive = false,
        getReadyCheckDeclinedUntil = function(unit)
          return readyCheckDeclinedUntilByUnit[unit]
        end,
        getTime = function()
          return now
        end,
      })
      Assert.Equal(displayDataHeld.colorHex, "ffc69b6d", "Declined hold should keep class-colored text")
      Assert.NotNil(displayDataHeld.readyCheckBackgroundColor, "Declined hold should keep the row background active")
      Assert.Equal(displayDataHeld.readyCheckStatus, "notready", "Declined hold should keep the not-ready row state")
      Assert.Equal(displayDataHeld.readyCheckMarkup, "", "Declined hold should not prepend the waiting icon")

      -- 4. Once the hold expires, the row returns to normal
      now = now + 21
      local displayDataExpired = addon.Roster.BuildDisplayData(roster.player, {
        unit = "player",
        isReadyCheckActive = false,
        getReadyCheckDeclinedUntil = function(unit)
          return readyCheckDeclinedUntilByUnit[unit]
        end,
        getTime = function()
          return now
        end,
      })
      Assert.Equal(displayDataExpired.colorHex, "ffc69b6d", "Expired declined hold should keep class-colored text")
      Assert.Nil(displayDataExpired.readyCheckBackgroundColor, "Expired declined hold should clear the row background")
      Assert.Equal(displayDataExpired.readyCheckMarkup, "", "Expired declined hold should not show waiting markup")
    end)
  end)

  test("Roster ready check stays green for 20 seconds after finish", function()
    local readyCheckStatusByUnit = {}
    local readyCheckReadyUntilByUnit = {}
    local now = 100
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

      local displayDataInitial = addon.Roster.BuildDisplayData(roster.player, {
        unit = "player",
        isReadyCheckActive = false,
        getReadyCheckReadyUntil = function(unit)
          return readyCheckReadyUntilByUnit[unit]
        end,
        getTime = function()
          return now
        end,
      })
      Assert.Equal(displayDataInitial.colorHex, "ffc69b6d", "Initial color should be warrior class color")
      Assert.Nil(displayDataInitial.readyCheckBackgroundColor, "Initial state should not tint the row background")
      Assert.Equal(displayDataInitial.readyCheckMarkup, "", "Initial state should not prepend waiting markup")

      readyCheckStatusByUnit.player = "ready"
      local displayDataActive = addon.Roster.BuildDisplayData(roster.player, {
        unit = "player",
        isReadyCheckActive = true,
        getReadyCheckReadyUntil = function(unit)
          return readyCheckReadyUntilByUnit[unit]
        end,
        getTime = function()
          return now
        end,
      })
      Assert.Equal(displayDataActive.colorHex, "ffc69b6d", "Active ready state should keep class-colored text")
      Assert.NotNil(displayDataActive.readyCheckBackgroundColor, "Active ready state should tint the row background")
      Assert.Equal(displayDataActive.readyCheckStatus, "ready", "Active ready state should report ready status")

      readyCheckStatusByUnit.player = nil
      readyCheckReadyUntilByUnit.player = now + 20
      local displayDataHeld = addon.Roster.BuildDisplayData(roster.player, {
        unit = "player",
        isReadyCheckActive = false,
        getReadyCheckReadyUntil = function(unit)
          return readyCheckReadyUntilByUnit[unit]
        end,
        getTime = function()
          return now
        end,
      })
      Assert.Equal(displayDataHeld.colorHex, "ffc69b6d", "Ready hold should keep class-colored text")
      Assert.NotNil(displayDataHeld.readyCheckBackgroundColor, "Ready hold should keep the row background active")
      Assert.Equal(displayDataHeld.readyCheckStatus, "ready", "Ready hold should keep the ready row state")
      Assert.Equal(displayDataHeld.readyCheckMarkup, "", "Ready hold should not prepend waiting markup")

      now = now + 21
      local displayDataExpired = addon.Roster.BuildDisplayData(roster.player, {
        unit = "player",
        isReadyCheckActive = false,
        getReadyCheckReadyUntil = function(unit)
          return readyCheckReadyUntilByUnit[unit]
        end,
        getTime = function()
          return now
        end,
      })
      Assert.Equal(displayDataExpired.colorHex, "ffc69b6d", "Expired ready hold should keep class-colored text")
      Assert.Nil(displayDataExpired.readyCheckBackgroundColor, "Expired ready hold should clear the row background")
      Assert.Equal(displayDataExpired.readyCheckMarkup, "", "Expired ready hold should not show waiting markup")
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

  test("Roster display appends crown marker for group leader", function()
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
        name = "LeaderPlayer",
        isLeader = true,
      }, {})

      Assert.True(
        displayData.addonMarker:find("UI%-Group%-LeaderIcon", 1) ~= nil,
        "group leader should receive the crown marker"
      )
      Assert.True(
        displayData.addonMarker:find("UI%-Group%-LeaderIcon:16:16", 1) ~= nil,
        "group leader crown marker should render at 16x16"
      )
    end)
  end)

  test("Roster display renders blue-heart marker before crown marker for synced leader", function()
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
        name = "LeaderPlayer",
        isLeader = true,
        hasIsiLive = true,
      }, {
        syncMarker = " |TInterface\\AddOns\\isiLive\\media\\heart_sync:12:12|t",
      })

      Assert.True(
        displayData.addonMarker:find("UI%-Group%-LeaderIcon", 1) ~= nil,
        "leader marker must remain visible for synced leaders"
      )
      Assert.True(
        displayData.addonMarker:find("heart_sync", 1, true) ~= nil,
        "blue-heart marker must remain visible for synced leaders"
      )
      local heartPosition = displayData.addonMarker:find("heart_sync", 1, true)
      local crownPosition = displayData.addonMarker:find("UI%-Group%-LeaderIcon", 1)

      Assert.True(heartPosition ~= nil, "blue-heart marker position must be detectable")
      Assert.True(crownPosition ~= nil, "crown marker position must be detectable")
      Assert.True(
        heartPosition < crownPosition,
        "blue-heart marker must render before the crown marker for synced leaders"
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
  function fontString.SetAllPoints() end
  function fontString.ClearAllPoints() end
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

local function NewRecordedMainFrame(createdFontStrings, createdTextures, opts)
  opts = opts or {}
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
    local shownState = opts.mainFrameShownState
    if type(shownState) == "table" then
      return shownState.value == true
    end
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
        setMainFrameWidthSafe = function() end,
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
        setMainFrameWidthSafe = function() end,
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

local function RegisterRosterPanelShareKeysLinkTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster panel share keys button builds a deterministic keystone link", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local sentMessages = {}
    local shareKeyRequests = 0
    local currentTime = 300

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      C_ChallengeMode = {
        GetMapUIInfo = function(mapID)
          if mapID == 2662 then
            return "Mists of Tirna Scithe"
          end
          return nil
        end,
      },
      C_MythicPlus = {
        GetOwnedKeystoneLink = function()
          return "|Hitem:19019|h[Thunderfury, Blessed Blade of the Windseeker]|h"
        end,
      },
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
        setMainFrameWidthSafe = function() end,
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
              keyMapID = 2662,
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
        sendShareKeysRequest = function()
          shareKeyRequests = shareKeyRequests + 1
        end,
      })

      controller.RenderRoster({
        player = {
          name = "Self",
          role = "DAMAGER",
          keyMapID = 2662,
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
      ---@diagnostic enable: need-check-nil, undefined-field

      Assert.Equal(#sentMessages, 1, "share-keys should emit one chat message")
      Assert.Equal(sentMessages[1].channel, "PARTY", "share-keys should still announce to party chat")
      Assert.True(
        sentMessages[1].text:find("|Hkeystone:180653:2662:10:0:0:0:0|h", 1, true) ~= nil,
        "share-keys must build a full keystone hyperlink from the owned map ID and level"
      )
      Assert.True(
        sentMessages[1].text:find("|Hitem:", 1, true) == nil,
        "share-keys must not forward a foreign item hyperlink"
      )
      Assert.Equal(shareKeyRequests, 1, "share-keys should still broadcast the sync request")
    end)
  end)
end

local function RegisterRosterPanelShareKeysTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster panel share keys button debounces rapid clicks", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local sentMessages = {}
    local shareKeyRequests = 0
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
        setMainFrameWidthSafe = function() end,
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
        sendShareKeysRequest = function()
          shareKeyRequests = shareKeyRequests + 1
        end,
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
      Assert.Equal(shareKeyRequests, 1, "share-keys should send one sync request on the first click")

      currentTime = 101.5
      shareKeysButton.OnClick()
      ---@diagnostic enable: need-check-nil, undefined-field
      Assert.Equal(#sentMessages, 2, "share-keys click should fire again after debounce window")
      Assert.Equal(shareKeyRequests, 2, "share-keys should send another sync request after the debounce window")
    end)
  end)

  test("Roster panel share keys button locks on remote SHAREKEYS signal", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local shareKeyRequests = 0
    local currentTime = 200

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
      C_ChatInfo = { SendChatMessage = function() end },
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
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function(roster)
          return { { unit = "player", info = roster.player } }
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
          return { player = { name = "Self", role = "DAMAGER", keyMapID = 2441, keyLevel = 10 } }
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = { DAMAGER = 1, NONE = 2 },
        unitPriority = { player = 1 },
        getTime = function()
          return currentTime
        end,
        shareKeysDebounceSeconds = 30,
        sendShareKeysRequest = function()
          shareKeyRequests = shareKeyRequests + 1
        end,
      })

      controller.RenderRoster({
        player = { name = "Self", role = "DAMAGER", keyMapID = 2441, keyLevel = 10 },
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

      -- Simulate remote SHAREKEYS received: lock the button on this client too
      controller.TriggerShareKeysCooldown()

      -- Local click within debounce window must now be blocked
      shareKeysButton.OnClick()
      Assert.Equal(shareKeyRequests, 0, "local click must be blocked after remote SHAREKEYS locks the button")

      -- After debounce window, button is usable again
      currentTime = 231
      shareKeysButton.OnClick()
      ---@diagnostic enable: need-check-nil, undefined-field
      Assert.Equal(shareKeyRequests, 1, "local click must succeed once debounce window has passed")
    end)
  end)
end

local function BuildHiddenSettingTestController(addon, createdFontStrings, opts)
  opts = opts or {}
  return addon.RosterPanel.CreateController({
    mainFrame = NewRecordedMainFrame(createdFontStrings, opts.createdTextures, {
      mainFrameShownState = opts.mainFrameShownState,
    }),
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
    setMainFrameWidthSafe = function() end,
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

local function RegisterRosterPanelHiddenDisplayDefaultTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster panel keeps active members visible ahead of persisted ghosts", function()
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
      local addon = LoadAddonModules({
        "isiLive_roster.lua",
        "isiLive_roster_panel.lua",
      })

      local roster = {
        player = { name = "Player", role = "DAMAGER" },
        party1 = { name = "Bircan", role = "DAMAGER" },
        party2 = { name = "Zidane", role = "DAMAGER" },
        party3 = { name = "Kurshad", role = "DAMAGER" },
        ["ghost:OldTank-Realm"] = { name = "OldTank", role = "TANK", isGhost = true },
        ["ghost:OldHeal-Realm"] = { name = "OldHeal", role = "HEALER", isGhost = true },
      }

      local controller = BuildHiddenSettingTestController(addon, createdFontStrings, {
        buildOrderedRoster = function(currentRoster, rolePriority, unitPriority)
          return addon.Roster.BuildOrderedRoster(currentRoster, rolePriority, unitPriority)
        end,
        buildDisplayData = function(info)
          return {
            colorHex = info.isGhost and "ff808080" or "ffffffff",
            displayName = info.name,
            languageDisplay = "",
            specText = "-",
            ilvlText = "-",
            rioText = "-",
            keyText = "-",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        rolePriority = {
          TANK = 1,
          HEALER = 2,
          DAMAGER = 3,
          NONE = 4,
        },
        unitPriority = {
          player = 1,
          party1 = 2,
          party2 = 3,
          party3 = 4,
          party4 = 5,
        },
      })

      controller.RenderRoster(roster)

      local visibleRowNames = {}
      for _, fontString in ipairs(createdFontStrings) do
        if
          fontString.pointX == 93
          and fontString.pointY ~= -34
          and type(fontString.text) == "string"
          and fontString.text ~= ""
        then
          table.insert(visibleRowNames, fontString.text)
        end
      end

      Assert.Equal(#visibleRowNames, 5, "roster should still render only five visible rows")
      Assert.True(visibleRowNames[1]:find("Player", 1, true) ~= nil, "player should stay visible before ghosts")
      Assert.True(visibleRowNames[2]:find("Bircan", 1, true) ~= nil, "first active party member should stay visible")
      Assert.True(visibleRowNames[3]:find("Zidane", 1, true) ~= nil, "second active party member should stay visible")
      Assert.True(visibleRowNames[4]:find("Kurshad", 1, true) ~= nil, "active members must not be pushed out by ghosts")
      Assert.True(
        visibleRowNames[5]:find("OldTank", 1, true) ~= nil,
        "a persisted ghost may consume only leftover row budget"
      )
      for _, rowText in ipairs(visibleRowNames) do
        Assert.False(
          rowText:find("OldHeal", 1, true) ~= nil,
          "extra ghosts must stay behind all active members when the row budget is exhausted"
        )
      end
    end)
  end)

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
        if fontString.pointX == 390 and fontString.pointY == -34 then
          dpsHeader = fontString
        elseif fontString.pointX == 390 and fontString.pointY ~= -34 then
          rowDps = fontString
        end
      end

      Assert.NotNil(dpsHeader, "DPS header should exist")
      ---@diagnostic disable-next-line: need-check-nil, undefined-field
      Assert.True(dpsHeader:IsShown(), "hidden settings must keep the DPS header visible")
      Assert.NotNil(rowDps, "row DPS cell should exist")
      ---@diagnostic disable-next-line: need-check-nil, undefined-field
      Assert.True(rowDps:IsShown(), "hidden settings must keep row DPS values visible")
      ---@diagnostic disable-next-line: need-check-nil, undefined-field
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

  test("Roster panel first visible render rescans cd tracker after hidden mode", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local mainFrameShownState = { value = false }
    local cdScans = 0

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
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings, {
        mainFrameShownState = mainFrameShownState,
      })

      controller.SetCdController({
        Scan = function()
          cdScans = cdScans + 1
        end,
        GetBResInfo = function()
          return nil
        end,
        GetLustInfo = function()
          return nil
        end,
      })

      controller.RenderRoster({})
      Assert.Equal(cdScans, 0, "hidden pre-render must not rescan the local CD tracker")

      mainFrameShownState.value = true
      controller.MarkCdTrackerDirty()
      controller.RenderRoster({})
      controller.RenderRoster({})
    end)

    Assert.Equal(cdScans, 1, "first visible render after hidden mode must rescan the CD tracker exactly once")
  end)

  test("Roster panel visible render does not rescan cd tracker after an explicit cd refresh", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local cdScans = 0

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
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings)

      controller.SetCdController({
        Scan = function()
          cdScans = cdScans + 1
        end,
        GetBResInfo = function()
          return nil
        end,
        GetLustInfo = function()
          return nil
        end,
      })

      controller.RefreshCdTracker()
      controller.RenderRoster({})
    end)

    Assert.Equal(
      cdScans,
      0,
      "visible render must not rescan immediately after an explicit CD refresh already updated the row"
    )
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
        key = 278,
        ilvl = 314,
        rio = 388,
        dps = 430,
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
    end)
  end)
end

local function RegisterRosterPanelMainLayoutVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
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
      ---@diagnostic disable-next-line: need-check-nil, undefined-field
      Assert.False(combatLoggingToggle:IsShown(), "combat logging toggle should stay hidden in the main panel")
      ---@diagnostic disable-next-line: need-check-nil, undefined-field
      Assert.False(damageMeterResetToggle:IsShown(), "DM reset toggle should stay hidden in the main panel")
    end)
  end)
end

local function RegisterRosterPanelRestoreDefaultLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
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

local function RegisterRosterPanelHiddenSettingDefaultTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelHiddenDisplayDefaultTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelMainLayoutVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRestoreDefaultLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
end

local function RegisterRosterPanelInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelLeaderInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelShareKeysLinkTests(test, Assert, WithGlobals, LoadAddonModules)
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
