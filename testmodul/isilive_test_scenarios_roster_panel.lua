local function RegisterRosterDisplayTests(test, Assert, WithGlobals, LoadAddonModules)
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
end

local function RegisterRosterPanelInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
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

local function RegisterRosterPanelTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterDisplayTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
end

return function(test, ctx)
  RegisterRosterPanelTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
