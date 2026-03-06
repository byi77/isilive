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
end

local function NewRecordedFontString(createdFontStrings)
  local fontString = {
    wordWrap = nil,
    nonSpaceWrap = nil,
    maxLines = nil,
  }

  function fontString.SetPoint() end
  function fontString.SetWidth() end
  function fontString.SetJustifyH() end
  function fontString.GetFont()
    return "font", 10, ""
  end
  function fontString.SetFont() end
  function fontString.SetTextColor() end
  function fontString.SetShadowOffset() end
  function fontString.SetText() end
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

      Assert.False(createdFrames[1].enabled, "ready-check button should be disabled for non-leaders")
      Assert.False(createdFrames[2].enabled, "countdown button should be disabled for non-leaders")
      Assert.False(createdFrames[5].enabled, "countdown-cancel button should be disabled for non-leaders")
      Assert.Equal(createdFrames[1].alpha, 0.45, "ready-check button should be dimmed for non-leaders")
      Assert.Equal(createdFrames[2].alpha, 0.45, "countdown button should be dimmed for non-leaders")
      Assert.Equal(createdFrames[5].alpha, 0.45, "countdown-cancel button should be dimmed for non-leaders")
    end)
  end)
end

local function RegisterRosterPanelTooltipInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  test("RosterPanel control buttons use ANCHOR_CURSOR for tooltips", function()
    local tooltipAnchor = nil
    local createFrameStub = function(_type, _name, _parent)
      return {
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
          }
        end,
      }
    end

    WithGlobals({
      CreateFrame = createFrameStub,
      GameTooltip = {
        SetOwner = function(_self, _owner, anchor)
          tooltipAnchor = anchor
        end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
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
      Assert.Equal(tooltipAnchor, "ANCHOR_CURSOR", "Refresh button tooltip must use ANCHOR_CURSOR")
    end)
  end)
end

local function RegisterRosterPanelRowTooltipTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster row tooltip shows 'Runs together' when count > 0", function()
    local tooltipLines = {}
    local createdFrames = {}
    local createFrameStub = function()
      local f = {
        SetPoint = function() end,
        SetSize = function() end,
        SetHeight = function() end,
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
          }
        end,
        Hide = function() end,
        Show = function() end,
      }
      table.insert(createdFrames, f)
      return f
    end

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
        getPlayerRunCount = function(name)
          if name == "Buddy" then
            return 5
          end
          return 0
        end,
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
      Assert.True(foundRuns, "Tooltip should contain 'Runs together: 5'")
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

local function RegisterRosterPanelWrappingTests(test, Assert, WithGlobals, LoadAddonModules)
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

      Assert.Equal(#rowFontStrings, 6, "one rendered row should create six member text columns")
      for _, fontString in ipairs(rowFontStrings) do
        Assert.False(fontString.wordWrap, "member text columns must disable word wrap")
        Assert.False(fontString.nonSpaceWrap, "member text columns must disable non-space wrap")
      end
    end)
  end)
end

local function RegisterRosterPanelInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelLeaderInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelTooltipInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelShareKeysTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelWrappingTests(test, Assert, WithGlobals, LoadAddonModules)
end

local function RegisterRosterPanelTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterDisplayTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
end

return function(test, ctx)
  RegisterRosterPanelTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
