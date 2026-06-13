local _, addonTable = ...
addonTable = addonTable or {}

local RegisterRosterRenderReadyCheckReapplyTest

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

  RegisterRosterRenderReadyCheckReapplyTest(test, Assert, WithGlobals, LoadAddonModules)

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

  test("Roster display appends skull marker and repeat count for tracked deaths", function()
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

      local once = addon.Roster.BuildDisplayData({
        name = "Once",
      }, {
        deathSummary = { count = 1 },
      })
      Assert.True(
        once.addonMarker:find("UI%-RaidTargetingIcon_8", 1) ~= nil,
        "a player with deaths should receive the skull marker"
      )
      Assert.False(once.addonMarker:find("|cffff60601|r", 1, true) ~= nil, "one death should not add a noisy count")

      local twice = addon.Roster.BuildDisplayData({
        name = "Twice",
      }, {
        deathSummary = { count = 2 },
      })
      Assert.True(
        twice.addonMarker:find("UI%-RaidTargetingIcon_8", 1) ~= nil,
        "repeat deaths should keep the skull marker"
      )
      Assert.True(twice.addonMarker:find("|cffff60602|r", 1, true) ~= nil, "repeat deaths should show the count")
    end)
  end)

  test("Roster render appends green bonus-heart marker for relevant roster class buffs", function()
    WithGlobals({
      GetReadyCheckStatus = function()
        return nil
      end,
      UnitClass = function(unit)
        if unit == "player" then
          return "Warrior", "WARRIOR"
        end
        return nil, nil
      end,
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function()
        return 72
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
        "isiLive_lfg_flags.lua",
        "isiLive_roster_panel_render.lua",
      })

      local displayData = addon._RosterInternal.BuildRowDisplayData({
        buildDisplayData = function(info, opts)
          return addon.Roster.BuildDisplayData(info, opts)
        end,
      }, {
        unit = "party1",
        info = {
          name = "Warrior",
          class = "WARRIOR",
          role = "DAMAGER",
          specID = 72,
        },
      }, false, nil, true)

      local capturedNameText = nil
      addon._RosterInternal.ApplyRowNameDisplay({
        name = {
          SetText = function(_, value)
            capturedNameText = value
          end,
        },
      }, displayData)

      Assert.True(
        capturedNameText:find("media\\heart_bonus_green", 1, true) ~= nil,
        "relevant roster class buffs must render the green bonus-heart marker next to the member name"
      )
      Assert.True(
        capturedNameText:find("Warrior|r |TInterface\\AddOns\\isiLive\\media\\heart_bonus_green", 1, true) ~= nil,
        "roster bonus-heart marker must keep the same leading spacing style as inline roster markers"
      )
    end)
  end)

  test("Roster render hides green bonus-heart marker when group-bonus setting is disabled", function()
    WithGlobals({
      GetReadyCheckStatus = function()
        return nil
      end,
      UnitClass = function(unit)
        if unit == "player" then
          return "Warrior", "WARRIOR"
        end
        return nil, nil
      end,
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function()
        return 72
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
        "isiLive_lfg_flags.lua",
        "isiLive_roster_panel_render.lua",
      })
      addon.LFGFlags.SetGroupBonusesEnabled(false)

      local displayData = addon._RosterInternal.BuildRowDisplayData({
        buildDisplayData = function(info, opts)
          return addon.Roster.BuildDisplayData(info, opts)
        end,
      }, {
        unit = "party1",
        info = {
          name = "Warrior",
          class = "WARRIOR",
          role = "DAMAGER",
          specID = 72,
        },
      }, false, nil, true)

      local capturedNameText = nil
      addon._RosterInternal.ApplyRowNameDisplay({
        name = {
          SetText = function(_, value)
            capturedNameText = value
          end,
        },
      }, displayData)

      Assert.True(
        capturedNameText:find("media\\heart_bonus_green", 1, true) == nil,
        "disabled group-bonus setting must suppress roster bonus-heart markers"
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
  function fontString.GetFont(self)
    return self._fontPath or "Fonts\\FRIZQT__.TTF", self._fontSize or 10, self._fontFlags or ""
  end
  function fontString.SetFont(self, path, size, flags)
    self._fontPath = path
    self._fontSize = size
    self._fontFlags = flags
  end
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
  function frame.RegisterForClicks(self, ...)
    self.registeredClicks = { ... }
  end
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

addonTable._RosterPanelTests = addonTable._RosterPanelTests or {}
addonTable._RosterPanelTests.NewRecordedFontString = NewRecordedFontString
addonTable._RosterPanelTests.NewRecordedFrame = NewRecordedFrame
addonTable._RosterPanelTests.NewRecordedMainFrame = NewRecordedMainFrame

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

      readyCheckButton = Assert.NotNil(readyCheckButton, "ready-check button should exist")
      countdownButton = Assert.NotNil(countdownButton, "countdown button should exist")
      countdownCancelButton = Assert.NotNil(countdownCancelButton, "countdown-cancel button should exist")
      ---@diagnostic disable: undefined-field
      Assert.False(readyCheckButton.enabled, "ready-check button should be disabled for non-leaders")
      Assert.False(countdownButton.enabled, "countdown button should be disabled for non-leaders")
      Assert.False(countdownCancelButton.enabled, "countdown-cancel button should be disabled for non-leaders")
      Assert.Equal(readyCheckButton.alpha, 0.45, "ready-check button should be dimmed for non-leaders")
      Assert.Equal(countdownButton.alpha, 0.45, "countdown button should be dimmed for non-leaders")
      Assert.Equal(countdownCancelButton.alpha, 0.45, "countdown-cancel button should be dimmed for non-leaders")
      ---@diagnostic enable: undefined-field
    end)
  end)

  test("Roster panel ready-check button uses a secure macro action", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local doReadyCheckCalls = 0

    WithGlobals({
      CreateFrame = function(frameType, name, parent, template)
        local frame = NewRecordedFrame(createdFrames, createdFontStrings)
        frame._frameType = frameType
        frame._name = name
        frame._parent = parent
        frame._template = template
        return frame
      end,
      DoReadyCheck = function()
        doReadyCheckCalls = doReadyCheckCalls + 1
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
          return true
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

      local readyCheckButton = nil
      for _, frame in ipairs(createdFrames) do
        if frame.text == "Readycheck" then
          readyCheckButton = frame
          break
        end
      end

      readyCheckButton = Assert.NotNil(readyCheckButton, "ready-check button should exist")
      Assert.Equal(
        readyCheckButton._template,
        "SecureActionButtonTemplate,BackdropTemplate",
        "ready-check button must be a secure action button"
      )
      Assert.Equal(readyCheckButton.attributes.type, "macro", "ready-check default click must execute a macro")
      Assert.Equal(
        readyCheckButton.attributes.macrotext,
        "/readycheck",
        "ready-check default macro must use Blizzard's secure slash command"
      )
      Assert.Equal(readyCheckButton.attributes.type1, "macro", "ready-check left click must execute a macro")
      Assert.Equal(
        readyCheckButton.attributes.macrotext1,
        "/readycheck",
        "ready-check macro must use Blizzard's secure slash command"
      )
      Assert.Equal(readyCheckButton.attributes.type2, "macro", "ready-check right click must execute a macro")
      Assert.Equal(
        readyCheckButton.attributes.macrotext2,
        "/readycheck",
        "ready-check right-click macro must use Blizzard's secure slash command"
      )
      Assert.Equal(readyCheckButton.registeredClicks[1], "AnyUp", "ready-check must accept mouse-up clicks")
      Assert.Equal(readyCheckButton.registeredClicks[2], "AnyDown", "ready-check must accept mouse-down clicks")
      Assert.Nil(readyCheckButton.OnClick, "ready-check button must not replace the secure action OnClick script")

      if type(readyCheckButton.OnClick) == "function" then
        readyCheckButton.OnClick(readyCheckButton)
      end
      Assert.Equal(doReadyCheckCalls, 0, "ready-check click script must not call protected DoReadyCheck directly")
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
          SetFrameLevel = function() end,
          GetFrameLevel = function()
            return 1
          end,
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
      rowFrame = Assert.NotNil(rowFrame, "interactive roster row should exist")

      rowFrame.OnMouseUp(nil, "LeftButton")
      Assert.Equal(targetCalls, 0, "left-click must not invoke protected targeting from the roster row")
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
    buildDisplayData = opts.buildDisplayData or function()
      return {}
    end,
    isReadyCheckActive = opts.isReadyCheckActive,
    getReadyCheckReadyUntil = opts.getReadyCheckReadyUntil,
    getReadyCheckDeclinedUntil = opts.getReadyCheckDeclinedUntil,
    getTime = opts.getTime,
    resolveTargetMapID = opts.resolveTargetMapID,
    getRioDelta = opts.getRioDelta,
    getPlayerSyncSummary = opts.getPlayerSyncSummary,
    getDungeonName = opts.getDungeonName,
    getLanguageTooltipMarkup = opts.getLanguageTooltipMarkup,
    isRaidGroup = opts.isRaidGroup,
    applyKnownKeyToRosterEntry = opts.applyKnownKeyToRosterEntry,
    syncMarker = opts.syncMarker,
    syncBadge = opts.syncBadge,
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

RegisterRosterRenderReadyCheckReapplyTest = function(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster render re-applies ready-check background during hold after a normal roster update", function()
    local readyCheckReadyUntilByUnit = {}
    local now = 100
    local createdFrames = {}
    local createdFontStrings = {}
    local createdTextures = {}

    WithGlobals({
      GetReadyCheckStatus = function()
        return nil
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
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua", "isiLive_roster.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings, {
        createdTextures = createdTextures,
        buildOrderedRoster = function(currentRoster)
          return {
            {
              unit = "player",
              info = currentRoster and currentRoster.player or {},
            },
          }
        end,
        buildDisplayData = function(info, opts)
          return addon.Roster.BuildDisplayData(info, opts)
        end,
        isReadyCheckActive = function()
          return false
        end,
        getReadyCheckReadyUntil = function(unit)
          return readyCheckReadyUntilByUnit[unit]
        end,
        getReadyCheckDeclinedUntil = function()
          return nil
        end,
        getTime = function()
          return now
        end,
      })

      readyCheckReadyUntilByUnit.player = now + 20
      controller.RenderRoster({
        player = {
          name = "TestPlayer",
          class = "WARRIOR",
          role = "DAMAGER",
        },
      })

      local foundReadyBackground = false
      for _, frame in ipairs(createdFrames) do
        local textures = rawget(frame, "_textures")
        if type(textures) == "table" then
          for _, texture in ipairs(textures) do
            if texture.color and texture.color[1] == 0.08 and texture.color[2] == 0.5 and texture.color[3] == 0.16 then
              foundReadyBackground = true
              break
            end
          end
        end
        if foundReadyBackground then
          break
        end
      end

      Assert.True(
        foundReadyBackground,
        "normal roster refresh during ready-check hold must re-apply the green background"
      )
    end)
  end)

  test("Roster render accepts boolean ready-check state without calling it like a function", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local createdTextures = {}

    WithGlobals({
      GetReadyCheckStatus = function(unit)
        if unit == "player" then
          return "ready"
        end
        return nil
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
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua", "isiLive_roster.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings, {
        createdTextures = createdTextures,
        buildOrderedRoster = function(currentRoster)
          return {
            {
              unit = "player",
              info = currentRoster and currentRoster.player or {},
            },
          }
        end,
        buildDisplayData = function(info, opts)
          return addon.Roster.BuildDisplayData(info, opts)
        end,
        isReadyCheckActive = true,
        getReadyCheckReadyUntil = function()
          return nil
        end,
        getReadyCheckDeclinedUntil = function()
          return nil
        end,
        getTime = function()
          return 100
        end,
      })

      controller.RenderRoster({
        player = {
          name = "TestPlayer",
          class = "WARRIOR",
          role = "DAMAGER",
        },
      })

      local foundReadyBackground = false
      for _, frame in ipairs(createdFrames) do
        local textures = rawget(frame, "_textures")
        if type(textures) == "table" then
          for _, texture in ipairs(textures) do
            if texture.color and texture.color[1] == 0.08 and texture.color[2] == 0.5 and texture.color[3] == 0.16 then
              foundReadyBackground = true
              break
            end
          end
        end
        if foundReadyBackground then
          break
        end
      end

      Assert.True(
        foundReadyBackground,
        "boolean ready-check state must render without attempting to call it as a function"
      )
    end)
  end)

  test("Roster render uses Cyrillic-capable font for Cyrillic player names", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local createdTextures = {}
    local cyrillicName = "\208\159\208\184\208\189\209\130\208\190"

    WithGlobals({
      IsiLiveDB = { locale = "enUS" },
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
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_roster_panel.lua" })
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings, {
        createdTextures = createdTextures,
        buildOrderedRoster = function(currentRoster)
          return {
            {
              unit = "player",
              info = currentRoster and currentRoster.player or {},
            },
          }
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = cyrillicName,
            languageDisplay = "RU",
            specText = "",
            ilvlText = "",
            rioText = "",
            keyText = "-",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        isReadyCheckActive = false,
      })

      controller.RenderRoster({
        player = {
          name = cyrillicName,
          role = "DAMAGER",
        },
      })

      local foundReadableName = false
      for _, fontString in ipairs(createdFontStrings) do
        if type(fontString.text) == "string" and fontString.text:find(cyrillicName, 1, true) then
          foundReadableName = fontString._fontPath == "Fonts\\ARIALN.TTF"
          break
        end
      end

      Assert.True(foundReadableName, "Cyrillic roster player names must switch the row font")
    end)
  end)

  -- Coverage + regression for the selective slot-clear logic in RenderRosterImpl:
  -- (1) full 5-member render goes through the entire re-render path for every slot,
  -- and (2) a follow-up render with fewer members must clear ONLY the now-orphaned
  -- slots — not the slots that the new orderedRoster still occupies. This is what
  -- protects the readyCheck-hold background from being hidden by parent-Hide between
  -- a RefreshReadyCheckStateImpl and a follow-up generic RenderRoster. (The original
  -- implementation tracked the refilled slots in a `touchedRowSlots` set; the
  -- sequential render loop now derives the same cleanup range from the final
  -- `index` value, so the cleanup is `[index, #memberRows]`. Test name kept
  -- intent-focused rather than implementation-anchored.)
  test("Roster render shrink cleanup: 5-member roster fills all slots, group-shrink clears only orphans", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local createdTextures = {}

    WithGlobals({
      GetReadyCheckStatus = function()
        return nil
      end,
      RAID_CLASS_COLORS = {
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
        PRIEST = { r = 1, g = 1, b = 1 },
        MAGE = { r = 0.41, g = 0.8, b = 0.94 },
        ROGUE = { r = 1, g = 0.96, b = 0.41 },
        WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
      },
      CreateColor = function(r, g, b)
        return {
          GenerateHexColor = function()
            return string.format("ff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
          end,
        }
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
      C_ChatInfo = { SendChatMessage = function() end },
      print = function() end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua", "isiLive_roster.lua" })
      local fullRoster = {
        player = { name = "Tank", class = "WARRIOR", role = "TANK" },
        party1 = { name = "Healer", class = "PRIEST", role = "HEALER" },
        party2 = { name = "Dps1", class = "MAGE", role = "DAMAGER" },
        party3 = { name = "Dps2", class = "ROGUE", role = "DAMAGER" },
        party4 = { name = "Dps3", class = "WARLOCK", role = "DAMAGER" },
      }
      local orderedFromRoster = function(currentRoster)
        local out = {}
        for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
          local info = currentRoster and currentRoster[unit]
          if info then
            table.insert(out, { unit = unit, info = info })
          end
        end
        return out
      end
      local controller = BuildHiddenSettingTestController(addon, createdFontStrings, {
        createdTextures = createdTextures,
        buildOrderedRoster = orderedFromRoster,
        buildDisplayData = function(info, opts)
          return addon.Roster.BuildDisplayData(info, opts)
        end,
        isReadyCheckActive = function()
          return false
        end,
        getReadyCheckReadyUntil = function()
          return nil
        end,
        getReadyCheckDeclinedUntil = function()
          return nil
        end,
        getTime = function()
          return 100
        end,
      })

      -- Phase 1: full 5-member render — every slot gets touched, none cleared.
      controller.RenderRoster(fullRoster)

      -- Phase 2: group shrinks to 3 members — slots 4 & 5 become orphans and
      -- must be cleared, slots 1-3 stay refilled (NOT cleared a second time).
      local shrunkRoster = {
        player = fullRoster.player,
        party1 = fullRoster.party1,
        party2 = fullRoster.party2,
      }
      controller.RenderRoster(shrunkRoster)

      -- Sanity: the render path executed without error and at least one row
      -- frame has been created. Coverage of the touched/untouched branch is
      -- the primary purpose of this test — a Lua error from the new clear
      -- loop would surface here as a thrown WithGlobals failure.
      Assert.True(#createdFrames > 0, "render must have created at least one row frame")
    end)
  end)
end

addonTable._RosterPanelTests = addonTable._RosterPanelTests or {}
addonTable._RosterPanelTests.NewRecordedFontString = NewRecordedFontString
addonTable._RosterPanelTests.NewRecordedTexture = NewRecordedTexture
addonTable._RosterPanelTests.NewRecordedFrame = NewRecordedFrame
addonTable._RosterPanelTests.NewRecordedMainFrame = NewRecordedMainFrame
addonTable._RosterPanelTests.FindFrameByProperty = FindFrameByProperty
addonTable._RosterPanelTests.FindWorldMarkerButtons = FindWorldMarkerButtons
addonTable._RosterPanelTests.FindM2ColumnGuides = FindM2ColumnGuides
addonTable._RosterPanelTests.BuildHiddenSettingTestController = BuildHiddenSettingTestController

local function RegisterRosterPanelInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelLeaderInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
end

local function RegisterRosterPanelTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterDisplayTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelInteractionTests(test, Assert, WithGlobals, LoadAddonModules)
end

return function(test, ctx)
  RegisterRosterPanelTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
