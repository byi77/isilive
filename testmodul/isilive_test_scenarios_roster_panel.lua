local function RegisterRosterDisplayTests(test, Assert, WithGlobals, LoadAddonModules)
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
        syncMarker = " |cff33aaff<3|r",
      })

      Assert.True(
        displayData.addonMarker:find("<3", 1, true) ~= nil,
        "synced users should receive the blue-heart marker"
      )
    end)
  end)

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

  test("Roster display truncates spec labels to six characters", function()
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

      Assert.Equal(capturedMaxChars, 6, "spec display should use the six-character limit")
      Assert.Equal(displayData.specText, "Shadow", "six-character spec labels should remain intact")
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

local function NewRecordedFontString(createdFontStrings)
  local fontString = {
    wordWrap = nil,
    nonSpaceWrap = nil,
    maxLines = nil,
    width = nil,
  }

  function fontString.SetPoint() end
  function fontString.Hide() end
  function fontString.Show() end
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

local function NewRecordedFrame(createdFrames, createdFontStrings)
  local frame = {
    enabled = nil,
    alpha = nil,
    pointY = nil,
    checked = false,
  }

  function frame.SetSize() end
  function frame.SetHeight() end
  function frame.SetWidth() end
  function frame.SetPoint(self, ...)
    local argCount = select("#", ...)
    for index = argCount, 1, -1 do
      local value = select(index, ...)
      if type(value) == "number" then
        self.pointY = value
        return
      end
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
  function frame.EnableMouse() end
  function frame.Hide() end
  function frame.Show() end
  function frame.IsShown()
    return true
  end
  function frame.CreateTexture()
    return {
      SetAllPoints = function() end,
      SetColorTexture = function() end,
      Hide = function() end,
      Show = function() end,
      SetHeight = function() end,
      SetPoint = function() end,
    }
  end
  function frame.CreateFontString()
    return NewRecordedFontString(createdFontStrings)
  end

  table.insert(createdFrames, frame)
  return frame
end

local function NewRecordedMainFrame(createdFontStrings)
  local mainFrame = {}

  function mainFrame.SetBackdrop() end
  function mainFrame.SetBackdropColor() end
  function mainFrame.IsShown()
    return true
  end
  function mainFrame.CreateFontString()
    return NewRecordedFontString(createdFontStrings)
  end
  function mainFrame.CreateTexture()
    return {
      SetHeight = function() end,
      SetPoint = function() end,
      SetColorTexture = function() end,
    }
  end

  return mainFrame
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
          return {}
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

      controller.UpdateLeaderButtons()

      local readyCheckButton = nil
      local countdownButton = nil
      local countdownCancelButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.pointY == -60 then
          readyCheckButton = frame
        elseif frame.pointY == -90 then
          countdownButton = frame
        elseif frame.pointY == -120 then
          countdownCancelButton = frame
        end
      end

      Assert.NotNil(readyCheckButton, "ready-check button should exist")
      Assert.NotNil(countdownButton, "countdown button should exist")
      Assert.NotNil(countdownCancelButton, "countdown-cancel button should exist")
      Assert.False(readyCheckButton.enabled, "ready-check button should be disabled for non-leaders")
      Assert.False(countdownButton.enabled, "countdown button should be disabled for non-leaders")
      Assert.False(countdownCancelButton.enabled, "countdown-cancel button should be disabled for non-leaders")
      Assert.Equal(readyCheckButton.alpha, 0.45, "ready-check button should be dimmed for non-leaders")
      Assert.Equal(countdownButton.alpha, 0.45, "countdown button should be dimmed for non-leaders")
      Assert.Equal(countdownCancelButton.alpha, 0.45, "countdown-cancel button should be dimmed for non-leaders")
    end)
  end)
end

local function RegisterRosterPanelTooltipInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  test("RosterPanel control buttons use isolated cursor-anchored tooltips", function()
    local createdFrames = {}
    local sharedTooltipCalls = 0
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
            SetText = function() end,
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
            return { SetHeight = function() end, SetPoint = function() end, SetColorTexture = function() end }
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
        if frame._isIsiLiveTooltip == true then
          privateTooltip = frame
          break
        end
      end

      Assert.NotNil(privateTooltip, "RosterPanel should allocate a private tooltip frame")
      Assert.Equal(
        privateTooltip._isiLiveTooltipAnchor,
        "ANCHOR_CURSOR",
        "Refresh button tooltip must use cursor anchor"
      )
      Assert.Equal(sharedTooltipCalls, 0, "RosterPanel control tooltips should not use the shared Blizzard GameTooltip")
    end)
  end)
end

local function NewRowTooltipCreateFrameStub(createdFrames, tooltipLines, tooltipOps)
  return function(frameType)
    local f = {
      frameType = frameType,
    }

    f.SetPoint = function() end
    f.SetSize = function() end
    f.SetHeight = function() end
    f.SetWidth = function() end
    f.SetEnabled = function() end
    f.SetAlpha = function() end
    f.EnableMouse = function() end
    f.SetScript = function(self, script, handler)
      self[script] = handler
    end
    f.CreateTexture = function()
      return {
        SetAllPoints = function() end,
        SetColorTexture = function() end,
        Hide = function() end,
        Show = function() end,
      }
    end
    f.CreateFontString = function()
      return {
        SetPoint = function() end,
        SetJustifyH = function() end,
        SetWidth = function() end,
        SetText = function(_, text)
          if f._isIsiLiveTooltip == true then
            table.insert(tooltipLines, tostring(text or ""))
          end
        end,
        SetWordWrap = function() end,
        SetNonSpaceWrap = function() end,
        SetMaxLines = function() end,
        Hide = function() end,
        Show = function() end,
      }
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

local function RegisterRosterPanelRowTooltipHistoryAndDpsTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster row tooltip no longer shows deprecated runs-together history", function()
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
            return { SetHeight = function() end, SetPoint = function() end, SetColorTexture = function() end }
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

      -- The first created frame in RenderRoster loop (after headers/buttons) should be the row hover frame
      -- But CreatePanelButtons creates frames first.
      -- Let's find the frame with OnEnter that triggers the tooltip logic
      local rowFrame = nil
      for _, f in ipairs(createdFrames) do
        if f.OnEnter and f.unit == "party1" then
          -- Trigger it to see if it calls GetPlayerRunCount
          f.OnEnter()
          if #tooltipLines > 0 then
            rowFrame = f
            break
          end
        end
      end

      Assert.NotNil(rowFrame, "Should find a row frame with OnEnter")
      local foundRuns = false
      for _, line in ipairs(tooltipLines) do
        if line:find("Runs together: 5") then
          foundRuns = true
        end
      end
      Assert.False(foundRuns, "Tooltip should not contain deprecated runs-together history")
    end)
  end)

  test("Roster row tooltip shows last run DPS when available", function()
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
      AbbreviateNumbers = function(value)
        if value == 321123 then
          return "321.1K"
        end
        return tostring(value)
      end,
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
            return { SetHeight = function() end, SetPoint = function() end, SetColorTexture = function() end }
          end,
        },
        getL = function()
          return {
            TOOLTIP_LAST_RUN_DPS = "Last run DPS: %s",
          }
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
        getPlayerLastRunDps = function(name, realm)
          if name == "Buddy" and realm == "Realm" then
            return 321123
          end
          return nil
        end,
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
      local foundDps = false
      for _, line in ipairs(tooltipLines) do
        if line:find("Last run DPS: 321.1K", 1, true) then
          foundDps = true
        end
      end
      Assert.True(foundDps, "Tooltip should contain abbreviated last-run DPS")
    end)
  end)
end

local function RegisterRosterPanelRowTooltipMetadataTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster row tooltip shows level and language abbreviation", function()
    local tooltipLines = {}
    local createdFrames = {}
    local createFrameStub = NewRowTooltipCreateFrameStub(createdFrames, tooltipLines)

    WithGlobals({
      CreateFrame = createFrameStub,
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
            return { SetHeight = function() end, SetPoint = function() end, SetColorTexture = function() end }
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
      for _, line in ipairs(tooltipLines) do
        if line == "Level: 80" then
          foundLevel = true
        end
        if line == "Lang: DE" then
          foundLanguage = true
        end
      end
      Assert.True(foundLevel, "Tooltip should contain the player level")
      Assert.True(foundLanguage, "Tooltip should contain the language abbreviation")
    end)
  end)

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
            return { SetHeight = function() end, SetPoint = function() end, SetColorTexture = function() end }
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
            return { SetHeight = function() end, SetPoint = function() end, SetColorTexture = function() end }
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
    Assert.Equal(
      privateTooltip._isiLiveTooltipAnchor,
      "ANCHOR_CURSOR",
      "private roster tooltip should keep cursor anchoring"
    )
    Assert.True(privateTooltip._isiLiveTooltipOwner ~= nil, "private roster tooltip should keep its hover owner")
  end)
end

local function RegisterRosterPanelRowTooltipTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipHistoryAndDpsTests(test, Assert, WithGlobals, LoadAddonModules)
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

local function RegisterRosterPanelRowInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster row left-click does not call protected targeting from insecure row UI", function()
    local createdFrames = {}
    local targetCalls = 0

    WithGlobals({
      CreateFrame = function()
        local frame = {
          SetPoint = function() end,
          SetSize = function() end,
          SetHeight = function() end,
          SetWidth = function() end,
          SetEnabled = function() end,
          SetAlpha = function() end,
          EnableMouse = function() end,
          SetScript = function(self, script, handler)
            self[script] = handler
          end,
          CreateTexture = function()
            return {
              SetAllPoints = function() end,
              SetColorTexture = function() end,
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
        if frame.pointY == -180 then
          shareKeysButton = frame
          break
        end
      end

      Assert.NotNil(shareKeysButton, "share-keys button should exist")
      shareKeysButton.OnClick()
      shareKeysButton.OnClick()
      Assert.Equal(#sentMessages, 1, "rapid repeated share-keys clicks should be debounced")
      Assert.Equal(sentMessages[1].channel, "PARTY", "share-keys should announce to party chat")

      currentTime = 101.5
      shareKeysButton.OnClick()
      Assert.Equal(#sentMessages, 2, "share-keys click should fire again after debounce window")
    end)
  end)
end

local function RegisterRosterPanelSystemOptionLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster panel system option toggles keep spacing between adjacent labels", function()
    local createdFrames = {}
    local createdFontStrings = {}

    local function NewPointRecordedFontString()
      local fontString = {}

      function fontString.SetPoint(self, point, relativeTo, relativePoint, x, y)
        self.point = point
        self.relativeTo = relativeTo
        self.relativePoint = relativePoint
        self.pointX = x
        self.pointY = y
      end
      function fontString.SetWidth() end
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
      function fontString.SetWordWrap() end
      function fontString.SetNonSpaceWrap() end
      function fontString.SetMaxLines() end
      function fontString.Hide() end
      function fontString.Show() end

      table.insert(createdFontStrings, fontString)
      return fontString
    end

    local function NewPointRecordedFrame()
      local frame = {
        checked = false,
      }

      function frame.SetSize() end
      function frame.SetHeight() end
      function frame.SetWidth() end
      function frame.ClearAllPoints(self)
        self.point = nil
        self.relativeTo = nil
        self.relativePoint = nil
        self.pointX = nil
        self.pointY = nil
      end
      function frame.SetPoint(self, point, relativeTo, relativePoint, x, y)
        self.point = point
        self.relativeTo = relativeTo
        self.relativePoint = relativePoint
        self.pointX = x
        self.pointY = y
      end
      function frame.SetScript(self, script, handler)
        self[script] = handler
      end
      function frame.SetText(self, value)
        self.text = value
      end
      function frame.SetEnabled() end
      function frame.SetAlpha() end
      function frame.SetChecked(self, value)
        self.checked = value and true or false
      end
      function frame.GetChecked(self)
        return self.checked
      end
      function frame.EnableMouse() end
      function frame.Hide() end
      function frame.Show() end
      function frame.IsShown()
        return true
      end
      function frame.CreateTexture()
        return {
          SetAllPoints = function() end,
          SetColorTexture = function() end,
          Hide = function() end,
          Show = function() end,
          SetHeight = function() end,
          SetPoint = function() end,
        }
      end
      function frame.CreateFontString()
        return NewPointRecordedFontString()
      end

      table.insert(createdFrames, frame)
      return frame
    end

    local mainFrame = {
      SetBackdrop = function() end,
      SetBackdropColor = function() end,
      IsShown = function()
        return true
      end,
      CreateFontString = function()
        return NewPointRecordedFontString()
      end,
      CreateTexture = function()
        return {
          SetHeight = function() end,
          SetPoint = function() end,
          SetColorTexture = function() end,
        }
      end,
    }

    WithGlobals({
      CreateFrame = function()
        return NewPointRecordedFrame()
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
        mainFrame = mainFrame,
        getL = function()
          return {
            OPT_ADVANCED_COMBAT_LOGGING = "Combat Logging",
            OPT_AUTO_MARK = "Auto-Mark T/H",
            OPT_DAMAGE_METER_RESET = "DM Reset on Entry",
          }
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
        getAutoMarkEnabled = function()
          return true
        end,
        setAutoMarkEnabled = function() end,
      })

      controller.ApplyLocalization()

      local combatLabel = nil
      local autoMarkLabel = nil
      for _, fontString in ipairs(createdFontStrings) do
        if fontString.text == "Combat Logging" then
          combatLabel = fontString
        elseif fontString.text == "Auto-Mark T/H" then
          autoMarkLabel = fontString
        end
      end

      Assert.NotNil(combatLabel, "combat logging label should exist")
      Assert.NotNil(autoMarkLabel, "auto-mark label should exist")

      local autoMarkToggle = nil
      local damageMeterResetToggle = nil
      for _, frame in ipairs(createdFrames) do
        if frame.relativeTo == combatLabel then
          autoMarkToggle = frame
        elseif frame.relativeTo == autoMarkLabel then
          damageMeterResetToggle = frame
        end
      end

      Assert.NotNil(autoMarkToggle, "auto-mark toggle should anchor after combat logging label")
      Assert.Equal(autoMarkToggle.point, "LEFT", "auto-mark toggle should align horizontally")
      Assert.Equal(autoMarkToggle.relativePoint, "RIGHT", "auto-mark toggle should attach to the combat label edge")
      Assert.Equal(autoMarkToggle.pointX, 18, "auto-mark toggle should keep a visible gap after combat logging")
      Assert.Equal(autoMarkToggle.pointY, 0, "auto-mark toggle should stay on the same baseline")

      Assert.NotNil(
        damageMeterResetToggle,
        "damage meter reset toggle should anchor after the auto-mark label"
      )
      Assert.Equal(damageMeterResetToggle.pointX, 18, "damage meter reset toggle should keep the same visible gap")
    end)
  end)
end

local function RegisterRosterPanelWrappingLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster panel rows disable wrapping for all member text columns", function()
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
              info = {
                name = "Member",
                role = "DAMAGER",
              },
            },
          }
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Member",
            languageDisplay = "EN",
            specText = "DPS",
            ilvlText = "650",
            rioText = "3000",
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
          return {}
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          party1 = 1,
        },
      })

      local fontStringsBeforeRender = #createdFontStrings
      controller.RenderRoster({})

      local rowFontStrings = {}
      for index = fontStringsBeforeRender + 1, #createdFontStrings do
        table.insert(rowFontStrings, createdFontStrings[index])
      end

      Assert.Equal(#rowFontStrings, 7, "one rendered row should create seven member text columns")
      for _, fontString in ipairs(rowFontStrings) do
        Assert.False(fontString.wordWrap, "member text columns must disable word wrap")
        Assert.False(fontString.nonSpaceWrap, "member text columns must disable non-space wrap")
      end
    end)
  end)

  test("Roster panel uses compact width budget for primary data columns", function()
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
            COL_DPS = "DPS",
          }
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
              info = {
                name = "Member",
                realm = "Realm",
                role = "DAMAGER",
              },
            },
          }
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Member",
            languageDisplay = "|Tflag-de:0|t",
            specText = "Shadow",
            ilvlText = "650",
            rioText = "(+15)3000",
            keyText = "DAWN +14",
            dpsText = "321.1K",
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
          return "DAWN"
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
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          party1 = 1,
        },
      })

      local fontStringsBeforeRender = #createdFontStrings
      controller.RenderRoster({})

      local rowFontStrings = {}
      for index = fontStringsBeforeRender + 1, #createdFontStrings do
        table.insert(rowFontStrings, createdFontStrings[index])
      end

      Assert.Equal(#rowFontStrings, 7, "one rendered row should create seven member text columns")
      Assert.Equal(rowFontStrings[1].width, 52, "spec column should keep compact width budget")
      Assert.Equal(rowFontStrings[2].width, 134, "name column should keep compact width budget")
      Assert.Equal(rowFontStrings[3].width, 24, "ilvl column should keep three-digit width budget")
      Assert.Equal(rowFontStrings[4].width, 56, "key column should keep four-letter short-code width budget")
      Assert.Equal(rowFontStrings[5].width, 70, "rio column should keep compact width budget")
      Assert.Equal(rowFontStrings[6].width, 58, "dps column should keep compact width budget")
      Assert.Equal(rowFontStrings[7].width, 14, "flag column should keep flag-only width budget")
    end)
  end)
end

local function RegisterRosterPanelWrappingDpsTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster panel renders DPS column from latest run snapshot", function()
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
      AbbreviateNumbers = function(value)
        if value == 321123 then
          return "321.1K"
        end
        return tostring(value)
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {
            COL_DPS = "DPS",
          }
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
              info = {
                name = "Member",
                realm = "Realm",
                role = "DAMAGER",
              },
            },
          }
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Member",
            languageDisplay = "EN",
            specText = "DPS",
            ilvlText = "650",
            rioText = "3000",
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
          return {}
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          party1 = 1,
        },
        getPlayerLastRunDps = function(name, realm)
          if name == "Member" and realm == "Realm" then
            return 321123
          end
          return nil
        end,
      })

      local fontStringsBeforeRender = #createdFontStrings
      controller.RenderRoster({})

      local rowFontStrings = {}
      for index = fontStringsBeforeRender + 1, #createdFontStrings do
        table.insert(rowFontStrings, createdFontStrings[index])
      end

      local foundDpsText = false
      for _, fontString in ipairs(rowFontStrings) do
        if fontString.text == "321.1K" then
          foundDpsText = true
          break
        end
      end
      Assert.True(foundDpsText, "rendered row should include abbreviated DPS text")
    end)
  end)
end

local function RegisterRosterPanelWrappingTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelWrappingLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelWrappingDpsTests(test, Assert, WithGlobals, LoadAddonModules)
end

local function RegisterRosterPanelInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelLeaderInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelTooltipInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelShareKeysTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelSystemOptionLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelWrappingTests(test, Assert, WithGlobals, LoadAddonModules)
end

local function RegisterRosterPanelTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterDisplayTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
end

return function(test, ctx)
  RegisterRosterPanelTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
