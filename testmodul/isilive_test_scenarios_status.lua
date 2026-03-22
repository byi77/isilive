local function BuildLocale()
  return {
    DUNGEON_DIFF_OUTSIDE = "Outside",
    DUNGEON_DIFF_UNKNOWN = "Unknown",
    DUNGEON_DIFF_NORMAL = "Normal",
    DUNGEON_DIFF_HEROIC = "Heroic",
    DUNGEON_DIFF_MYTHIC = "Mythic",
    NON_MYTHIC_ENTERED = "Warning: Entered non-Mythic dungeon (%s).",
    PORTAL_NAVIGATOR_TITLE = "Portal Navigator",
    PORTAL_NAVIGATOR_HALF_LEFT = "Half left",
    PORTAL_NAVIGATOR_LEFT = "Left",
    PORTAL_NAVIGATOR_RIGHT = "Right",
    PORTAL_NAVIGATOR_HALF_RIGHT = "Half right",
    PORTAL_NAVIGATOR_SKYREACH = "Skyreach",
    PORTAL_NAVIGATOR_TRIUMVIRATE = "Seat of the Triumvirate",
    PORTAL_NAVIGATOR_PIT_OF_SARON = "Pit of Saron",
    PORTAL_NAVIGATOR_ALGETHAR = "Algeth'ar Academy",
    PORTAL_NAVIGATOR_TEXT = "Portal Navigator\nLeft: Skyreach\nRight: Seat of the Triumvirate\nHalf left: Pit of Saron\nHalf right: Algeth'ar Academy",
    STATUS_LEAD_YES = "Lead: Yes",
    STATUS_LEAD_NO = "Lead: No",
    STATUS_MPLUS_YES = "M+: Active",
    STATUS_MPLUS_NO = "M+: Inactive",
    STATUS_TARGET_DUNGEON_TEXT = "Target Dungeon: %s",
    STATUS_TARGET_DUNGEON_NONE = "Target Dungeon: -",
    STATUS_TARGET_DUNGEON_PRESEASON = "Target Dungeon: Pre-Season (%s)",
    STATUS_STATE_RUNNING = "State: Running",
    STATUS_STATE_PAUSED = "State: Paused",
    STATUS_STATE_STOPPED = "State: Stopped",
    STATUS_STATE_TEST = "State: Test",
    DUNGEON_DIFF_TEXT = "Dungeon: %s",
  }
end

local function RegisterDungeonDifficultyTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Status maps heroic fallback difficulty IDs as non-mythic heroic", function()
    local current = {
      instanceName = "Priory of the Sacred Flame",
      instanceType = "party",
      difficultyID = 174,
    }

    WithGlobals({
      GetInstanceInfo = function()
        return current.instanceName, current.instanceType, current.difficultyID, "Heroic"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
      })

      local label, isMythic, inDungeon = controller.GetDungeonDifficultyLabel()
      Assert.Equal(label, "Heroic", "difficulty 174 should resolve as heroic")
      Assert.False(isMythic, "heroic fallback difficulty must not be mythic")
      Assert.True(inDungeon, "heroic fallback difficulty must be treated as dungeon context")
    end)
  end)

  test("Status warns when switching from normal to heroic without leaving dungeon context", function()
    local notices = {}
    local current = {
      instanceName = "Priory of the Sacred Flame",
      instanceType = "none",
      difficultyID = 0,
    }

    WithGlobals({
      GetInstanceInfo = function()
        return current.instanceName, current.instanceType, current.difficultyID, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
      C_Timer = {
        After = function(_delay, fn)
          fn()
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showCenterNotice = function(message, duration, _dungeonName, _activityID, _showOptions)
          table.insert(notices, { message = message, duration = duration })
        end,
        hideCenterNotice = function() end,
      })

      controller.MaybeShowNonMythicDungeonEntryNotice()

      current.instanceType = "party"
      current.difficultyID = 1
      controller.MaybeShowNonMythicDungeonEntryNotice()
      Assert.Equal(#notices, 1, "normal dungeon entry should show non-mythic notice")
      Assert.True(
        string.find(notices[1].message, "Normal", 1, true) ~= nil,
        "normal notice should include normal difficulty label"
      )

      current.difficultyID = 2
      controller.MaybeShowNonMythicDungeonEntryNotice()
      Assert.Equal(#notices, 2, "normal -> heroic switch should show another non-mythic notice")
      Assert.True(
        string.find(notices[2].message, "Heroic", 1, true) ~= nil,
        "heroic notice should include heroic difficulty label"
      )

      controller.MaybeShowNonMythicDungeonEntryNotice()
      Assert.Equal(#notices, 2, "repeated heroic refresh should not re-show same notice")
    end)
  end)
end

local function RegisterPortalNavigatorTests(test, Assert, WithGlobals, LoadAddonModules)
  local function AssertPortalNavigatorLayout(layout)
    Assert.Equal(type(layout), "table", "portal navigator should pass a structured layout table")
    Assert.Equal(layout.title, BuildLocale().PORTAL_NAVIGATOR_TITLE, "portal navigator should expose the title")
    Assert.Equal(type(layout.entries), "table", "portal navigator should expose entry widgets")
    Assert.Equal(#layout.entries, 4, "portal navigator should expose four directional entries")

    Assert.Equal(layout.entries[1].slot, "half_left", "first portal entry should be half left")
    Assert.Equal(
      layout.entries[1].direction,
      BuildLocale().PORTAL_NAVIGATOR_HALF_LEFT,
      "half left entry should use the localized direction label"
    )
    Assert.Equal(
      layout.entries[1].destination,
      BuildLocale().PORTAL_NAVIGATOR_PIT_OF_SARON,
      "half left entry should point to Pit of Saron"
    )

    Assert.Equal(layout.entries[2].slot, "left", "second portal entry should be left")
    Assert.Equal(layout.entries[2].direction, BuildLocale().PORTAL_NAVIGATOR_LEFT, "left entry should use left label")
    Assert.Equal(
      layout.entries[2].destination,
      BuildLocale().PORTAL_NAVIGATOR_SKYREACH,
      "left entry should point to Skyreach"
    )

    Assert.Equal(layout.entries[3].slot, "right", "third portal entry should be right")
    Assert.Equal(layout.entries[3].direction, BuildLocale().PORTAL_NAVIGATOR_RIGHT, "right entry should use right label")
    Assert.Equal(
      layout.entries[3].destination,
      BuildLocale().PORTAL_NAVIGATOR_TRIUMVIRATE,
      "right entry should point to Seat of the Triumvirate"
    )

    Assert.Equal(layout.entries[4].slot, "half_right", "fourth portal entry should be half right")
    Assert.Equal(
      layout.entries[4].direction,
      BuildLocale().PORTAL_NAVIGATOR_HALF_RIGHT,
      "half right entry should use the localized direction label"
    )
    Assert.Equal(
      layout.entries[4].destination,
      BuildLocale().PORTAL_NAVIGATOR_ALGETHAR,
      "half right entry should point to Algeth'ar Academy"
    )
  end

  test("Portal navigator shows the four portal directions only in the Timeways room", function()
    local current = {
      zoneText = nil,
      subZoneText = nil,
      playerMapID = 100,
      mapNames = {
        [100] = "Valdrakken",
        [2266] = "Jahrhunderschwelle",
      },
    }
    local notices = {}
    local hides = 0

    WithGlobals({
      GetZoneText = function()
        return current.zoneText
      end,
      GetSubZoneText = function()
        return current.subZoneText
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.playerMapID
          end
          return nil
        end,
        GetMapInfo = function(mapID)
          local name = current.mapNames[mapID]
          if type(name) ~= "string" then
            return nil
          end
          return { name = name }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showPortalNavigatorNotice = function(layout)
          table.insert(notices, layout)
        end,
        hidePortalNavigatorNotice = function()
          hides = hides + 1
        end,
      })

      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(#notices, 0, "outdoor zone must not show the portal navigator")
      Assert.Equal(hides, 0, "outdoor zone must not hide the portal navigator before it was shown")

      current.zoneText = "Jahrhunderschwelle"
      current.playerMapID = 2266
      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(#notices, 1, "portal room should show the navigator exactly once")
      AssertPortalNavigatorLayout(notices[1])

      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(#notices, 1, "same portal room should not re-show the navigator")

      current.zoneText = nil
      current.subZoneText = nil
      current.playerMapID = 100
      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(hides, 1, "leaving the portal room should hide the portal navigator")
    end)
  end)

  test("Portal navigator also detects the room from subzone text", function()
    local current = {
      subZoneText = nil,
      playerMapID = nil,
      mapNames = {},
    }
    local notices = {}

    WithGlobals({
      GetSubZoneText = function()
        return current.subZoneText
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.playerMapID
          end
          return nil
        end,
        GetMapInfo = function(mapID)
          local name = current.mapNames[mapID]
          if type(name) ~= "string" then
            return nil
          end
          return { name = name }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showPortalNavigatorNotice = function(layout)
          table.insert(notices, layout)
        end,
      })

      current.subZoneText = "Timeways"
      controller.MaybeShowPortalNavigatorNotice()

      Assert.Equal(#notices, 1, "subzone text should also trigger the portal navigator")
      AssertPortalNavigatorLayout(notices[1])
    end)
  end)

  test("Portal navigator also detects the room from zone text", function()
    local current = {
      zoneText = nil,
      subZoneText = nil,
      playerMapID = nil,
      mapNames = {},
    }
    local notices = {}

    WithGlobals({
      GetZoneText = function()
        return current.zoneText
      end,
      GetSubZoneText = function()
        return current.subZoneText
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.playerMapID
          end
          return nil
        end,
        GetMapInfo = function(mapID)
          local name = current.mapNames[mapID]
          if type(name) ~= "string" then
            return nil
          end
          return { name = name }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showPortalNavigatorNotice = function(layout)
          table.insert(notices, layout)
        end,
      })

      current.zoneText = "Jahrhunderschwelle"
      controller.MaybeShowPortalNavigatorNotice()

      Assert.Equal(#notices, 1, "zone text should also trigger the portal navigator")
      AssertPortalNavigatorLayout(notices[1])
    end)
  end)

  test("Portal navigator retries when the portal map resolves one tick later", function()
    local current = {
      subZoneText = nil,
      playerMapID = nil,
    }
    local notices = {}
    local scheduled = {}

    WithGlobals({
      GetSubZoneText = function()
        return current.subZoneText
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.playerMapID
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showPortalNavigatorNotice = function(layout)
          table.insert(notices, layout)
        end,
        timerAfter = function(seconds, callback)
          table.insert(scheduled, { seconds = seconds, callback = callback })
        end,
      })

      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(#notices, 0, "missing zone data should not show the navigator immediately")
      Assert.Equal(#scheduled, 1, "missing zone data should schedule one retry")

      current.playerMapID = 2266
      scheduled[1].callback()

      Assert.Equal(#notices, 1, "retry should show the navigator once the portal map resolves")
      AssertPortalNavigatorLayout(notices[1])
    end)
  end)

  test("Portal navigator respects the settings toggle", function()
    local current = {
      zoneText = "Jahrhunderschwelle",
      playerMapID = 2266,
      enabled = false,
      mapNames = {
        [2266] = "Jahrhunderschwelle",
      },
    }
    local notices = {}
    local hides = 0

    WithGlobals({
      GetZoneText = function()
        return current.zoneText
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return current.playerMapID
          end
          return nil
        end,
        GetMapInfo = function(mapID)
          local name = current.mapNames[mapID]
          if type(name) ~= "string" then
            return nil
          end
          return { name = name }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        isPortalNavigatorEnabled = function()
          return current.enabled
        end,
        showPortalNavigatorNotice = function(layout)
          table.insert(notices, layout)
        end,
        hidePortalNavigatorNotice = function()
          hides = hides + 1
        end,
      })

      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(#notices, 0, "disabled portal navigator should stay hidden")
      Assert.Equal(hides, 0, "disabled portal navigator should not emit a hide event before showing")

      current.enabled = true
      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(#notices, 1, "enabled portal navigator should show in the portal room")
      AssertPortalNavigatorLayout(notices[1])

      current.enabled = false
      controller.MaybeShowPortalNavigatorNotice()
      Assert.Equal(hides, 1, "disabling the portal navigator should hide the visible notice")
    end)
  end)
end

local function RegisterStatusLineTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Status line includes target dungeon and key level when available", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        getTargetDungeonInfo = function()
          return {
            name = "Ara-Kara",
            level = 14,
          }
        end,
      })

      local text = controller.BuildStatusLineText({})
      Assert.True(
        string.find(text, "\nTarget Dungeon: Ara-Kara +14", 1, true) ~= nil,
        "status line should include resolved target dungeon with key level on the second line"
      )
    end)
  end)

  test("Status line places target dungeon at the end", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        getTargetDungeonInfo = function()
          return {
            name = "Ara-Kara",
            level = 14,
          }
        end,
      })

      local text = controller.BuildStatusLineText({})
      Assert.Equal(
        text,
        "Lead: No | M+: Inactive | State: Running | Dungeon: Outside\nTarget Dungeon: Ara-Kara +14",
        "target dungeon should be rendered on a second line below the lead/status summary"
      )
    end)
  end)

  test("Status line keeps target placeholder when no target is available", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
      })

      local text = controller.BuildStatusLineText({})
      Assert.True(
        string.find(text, "\nTarget Dungeon: -", 1, true) ~= nil,
        "status line should show target placeholder on the second line when no target is known"
      )
    end)
  end)

  test("Status line keeps M+ inactive when challenge API is unavailable", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = nil,
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
      })

      local text = controller.BuildStatusLineText({})
      Assert.True(
        string.find(text, "M+: Inactive", 1, true) ~= nil,
        "status line should keep M+ inactive when the Blizzard challenge API is missing"
      )
    end)
  end)

  test("Status line shows pre-season placeholder when active portal pool is empty", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        hasActiveDungeons = function()
          return false
        end,
        getActiveSeasonLabel = function()
          return "Midnight Season 1 (prepared, inactive)"
        end,
      })

      local text = controller.BuildStatusLineText({})
      Assert.True(
        string.find(text, "\nTarget Dungeon: Pre-Season (Midnight Season 1 (prepared, inactive))", 1, true) ~= nil,
        "status line should explain the empty pre-season portal pool on the second line"
      )
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterDungeonDifficultyTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterPortalNavigatorTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterStatusLineTests(test, Assert, WithGlobals, LoadAddonModules)
end
