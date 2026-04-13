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
    PORTAL_NAVIGATOR_TEXT = "Portal Navigator\n"
      .. "Left: Skyreach\n"
      .. "Right: Seat of the Triumvirate\n"
      .. "Half left: Pit of Saron\n"
      .. "Half right: Algeth'ar Academy",
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
    STATUS_STATE_TEST = "State: Test Mode",
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
    Assert.Equal(
      layout.entries[3].direction,
      BuildLocale().PORTAL_NAVIGATOR_RIGHT,
      "right entry should use right label"
    )
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

  test("Status target dungeon chat announces grouped key once and resets after target clears", function()
    local current = {
      inGroup = false,
      targetInfo = {
        name = "Ara-Kara",
        level = 14,
      },
    }
    local prints = {}

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
        isInGroup = function()
          return current.inGroup
        end,
        getTargetDungeonInfo = function()
          return current.targetInfo
        end,
        printFn = function(message)
          table.insert(prints, tostring(message))
        end,
      })

      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 0, "solo target resolution must not write key chat lines")

      current.inGroup = true
      current.targetInfo = {
        name = "Ara-Kara",
      }
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 0, "missing key level must stay silent until sync resolves")

      current.targetInfo = {
        name = "Ara-Kara",
        level = 14,
      }
      controller.MaybeAnnounceTargetDungeonChat()
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 1, "identical grouped target must only print once")
      Assert.Equal(
        prints[1],
        "Target Dungeon: Ara-Kara +14",
        "grouped key chat should use the localized target dungeon text with key level"
      )

      current.targetInfo = nil
      controller.MaybeAnnounceTargetDungeonChat()

      current.targetInfo = {
        name = "Ara-Kara",
        level = 14,
      }
      controller.MaybeAnnounceTargetDungeonChat()
      Assert.Equal(#prints, 2, "clearing the target must allow a fresh grouped key announce later")
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

local function BuildFactoryRuntimeHelperContext(initial, LoadAddonModules)
  local addon = LoadAddonModules({ "isiLive_factory_controllers.lua" }, {
    _FactoryInternal = {},
  })

  local state = initial or {}
  local runtimeState = {
    GetRoster = function()
      return state.roster or {}
    end,
    GetPendingQueueJoinInfo = function()
      return state.pendingQueueJoinInfo
    end,
    SetPendingQueueJoinInfo = function(value)
      state.pendingQueueJoinInfo = value
    end,
    GetLatestQueueState = function()
      return state.latestQueueDungeonName, state.latestQueueActivityID, nil, state.latestQueueMapID
    end,
    GetActiveJoinedKeyMapID = function()
      return state.activeJoinedKeyMapID
    end,
  }

  local ctx = {
    modules = {
      sync = {
        NormalizePlayerKey = function(name, realm)
          return tostring(name or "") .. "-" .. tostring(realm or "")
        end,
        GetPlayerTargetInfo = function(name, realm)
          local targetInfoByPlayer = state.targetInfoByPlayer or {}
          return targetInfoByPlayer[tostring(name or "") .. "-" .. tostring(realm or "")]
        end,
        SendTarget = function(opts)
          state.sentTargetSnapshots = state.sentTargetSnapshots or {}
          table.insert(state.sentTargetSnapshots, opts)
        end,
      },
      teleport = {
        GetTeleportInfoByMapID = function(mapID)
          local infoByMapID = state.teleportInfoByMapID or {}
          return infoByMapID[mapID]
        end,
      },
      queue = {
        GetActivityName = function(activityID)
          local namesByActivityID = state.activityNamesByActivityID or {}
          return namesByActivityID[activityID]
        end,
      },
    },
    runtimeState = runtimeState,
    addonTable = {},
    GetL = function()
      return {
        UNKNOWN_GROUP = "Unknown",
        JOINED_FROM_QUEUE = "Joined from queue: %s",
        CHAT_QUEUE_PREFIX = "Queue Join",
      }
    end,
    Print = function(message)
      state.prints = state.prints or {}
      table.insert(state.prints, tostring(message))
    end,
    IsPlayerLeader = function()
      return state.isPlayerLeader == true
    end,
    keySyncController = {
      ResolveActiveKeyOwnerUnit = function(roster, targetMapID)
        if type(state.resolveActiveKeyOwnerUnit) == "function" then
          return state.resolveActiveKeyOwnerUnit(roster, targetMapID)
        end
        return nil
      end,
    },
    ResolveMapIDByActivityID = function(activityID)
      local mapIDsByActivityID = state.mapIDsByActivityID or {}
      return mapIDsByActivityID[activityID]
    end,
  }

  addon._FactoryInternal.InitializeFactoryRuntimeHelpers(ctx)
  return ctx, state
end

local function RegisterFactoryRuntimeQueueTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Factory runtime queue capture ignores queue events while challenge mode is active", function()
    WithGlobals({
      IsInGroup = function()
        return false
      end,
      GetTime = function()
        return 42
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return 507
        end,
      },
    }, function()
      local ctx, state = BuildFactoryRuntimeHelperContext({}, LoadAddonModules)

      ctx.CaptureQueueJoinCandidate({ groupName = "Queued Group" })

      Assert.Nil(state.pendingQueueJoinInfo, "challenge mode must not capture pending queue join info")
      Assert.Equal(#(state.prints or {}), 0, "challenge mode capture path must stay silent")
    end)
  end)

  test("Factory runtime queue capture stores pending info when not in group", function()
    WithGlobals({
      IsInGroup = function()
        return false
      end,
      GetTime = function()
        return 42
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local ctx, state = BuildFactoryRuntimeHelperContext({}, LoadAddonModules)

      ctx.CaptureQueueJoinCandidate({ groupName = "Queued Group" })

      Assert.NotNil(state.pendingQueueJoinInfo, "queue capture must store pending queue join info outside a group")
      Assert.Equal(
        state.pendingQueueJoinInfo.groupName,
        "Queued Group",
        "queue capture must keep the queued group name for the later announce"
      )
      Assert.Equal(state.pendingQueueJoinInfo.capturedAt, 42, "queue capture must stamp deterministic capture time")
    end)
  end)

  test("Factory runtime queue capture announces immediately when already grouped", function()
    WithGlobals({
      IsInGroup = function()
        return true
      end,
      GetTime = function()
        return 42
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local ctx, state = BuildFactoryRuntimeHelperContext({
        pendingQueueJoinInfo = {
          groupName = "Late Group",
          capturedAt = 1,
        },
      }, LoadAddonModules)

      ctx.CaptureQueueJoinCandidate()

      Assert.Nil(state.pendingQueueJoinInfo, "already-grouped capture must consume pending queue join info immediately")
      Assert.True(#(state.prints or {}) >= 3, "already-grouped capture must print the queue join summary")
    end)
  end)

  test("Factory runtime queue capture resets stale pending info when a new search starts outside a group", function()
    WithGlobals({
      IsInGroup = function()
        return false
      end,
      GetTime = function()
        return 42
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local ctx, state = BuildFactoryRuntimeHelperContext({
        pendingQueueJoinInfo = {
          groupName = "Old Group",
          capturedAt = 1,
        },
      }, LoadAddonModules)

      ctx.CaptureQueueJoinCandidate()

      Assert.Nil(
        state.pendingQueueJoinInfo,
        "capture outside a group must clear stale pending queue join info before a new search starts"
      )
      Assert.Equal(#(state.prints or {}), 0, "stale pending reset outside a group must stay silent")
    end)
  end)

  test("Factory runtime queue announce prints queue joined message for members and clears pending", function()
    local ctx, state = BuildFactoryRuntimeHelperContext({
      pendingQueueJoinInfo = {
        groupName = "Queued Group",
        capturedAt = 42,
      },
    }, LoadAddonModules)

    ctx.AnnounceQueuedGroupJoin()

    Assert.Nil(state.pendingQueueJoinInfo, "member announce path must clear pending queue join info")
    Assert.True(#(state.prints or {}) >= 3, "member announce path must print the queue join summary")
  end)

  test("Factory runtime queue announce clears pending for leaders without printing", function()
    local ctx, state = BuildFactoryRuntimeHelperContext({
      isPlayerLeader = true,
      pendingQueueJoinInfo = {
        groupName = "Queued Group",
        capturedAt = 42,
      },
    }, LoadAddonModules)

    ctx.AnnounceQueuedGroupJoin()

    Assert.Nil(state.pendingQueueJoinInfo, "leader announce path must clear pending queue join info")
    Assert.Equal(#(state.prints or {}), 0, "leader announce path must not print the queue join summary")
  end)

  test("Factory runtime queue helpers stay semantically aligned with legacy QueueFlow", function()
    local queueFlowAddon = LoadAddonModules({ "isiLive_queue_flow.lua" })

    local function BuildComparableResult(initialState, globals, action)
      local factoryResult
      local legacyState = {
        pendingQueueJoinInfo = initialState.pendingQueueJoinInfo,
        prints = {},
      }

      WithGlobals(globals, function()
        local factoryCtx, factoryState = BuildFactoryRuntimeHelperContext(initialState, LoadAddonModules)
        local queueFlowController = queueFlowAddon.QueueFlow.CreateController({
          getL = factoryCtx.GetL,
          getPendingQueueJoinInfo = function()
            return legacyState.pendingQueueJoinInfo
          end,
          setPendingQueueJoinInfo = function(value)
            legacyState.pendingQueueJoinInfo = value
          end,
          printFn = function(message)
            table.insert(legacyState.prints, tostring(message))
          end,
          isInChallengeMode = function()
            return factoryCtx.GetActiveChallengeMapID() ~= nil
          end,
          isInGroup = function()
            return IsInGroup()
          end,
          isPlayerLeader = function()
            return factoryState.isPlayerLeader == true
          end,
          getTimeFn = function()
            return GetTime()
          end,
        })

        factoryResult = {
          pendingQueueJoinInfo = factoryState.pendingQueueJoinInfo,
          prints = factoryState.prints or {},
        }

        action(factoryCtx, queueFlowController)

        factoryResult.pendingQueueJoinInfo = factoryState.pendingQueueJoinInfo
        factoryResult.prints = factoryState.prints or {}
      end)

      Assert.Equal(
        legacyState.pendingQueueJoinInfo and legacyState.pendingQueueJoinInfo.groupName or nil,
        factoryResult.pendingQueueJoinInfo and factoryResult.pendingQueueJoinInfo.groupName or nil,
        "legacy QueueFlow and factory helper must keep the same pending group name"
      )
      Assert.Equal(
        legacyState.pendingQueueJoinInfo and legacyState.pendingQueueJoinInfo.capturedAt or nil,
        factoryResult.pendingQueueJoinInfo and factoryResult.pendingQueueJoinInfo.capturedAt or nil,
        "legacy QueueFlow and factory helper must keep the same pending capture timestamp"
      )
      Assert.Equal(
        #legacyState.prints,
        #factoryResult.prints,
        "legacy QueueFlow and factory helper must emit the same number of queue announce lines"
      )
    end

    BuildComparableResult({}, {
      IsInGroup = function()
        return false
      end,
      GetTime = function()
        return 42
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function(factoryCtx, queueFlowController)
      factoryCtx.CaptureQueueJoinCandidate({ groupName = "Queued Group" })
      queueFlowController.CaptureQueueJoinCandidate({ groupName = "Queued Group" })
    end)

    BuildComparableResult({
      pendingQueueJoinInfo = {
        groupName = "Old Group",
        capturedAt = 1,
      },
    }, {
      IsInGroup = function()
        return false
      end,
      GetTime = function()
        return 42
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function(factoryCtx, queueFlowController)
      factoryCtx.CaptureQueueJoinCandidate()
      queueFlowController.CaptureQueueJoinCandidate()
    end)

    BuildComparableResult({
      pendingQueueJoinInfo = {
        groupName = "Queued Group",
        capturedAt = 42,
      },
    }, {
      IsInGroup = function()
        return true
      end,
      GetTime = function()
        return 42
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function(factoryCtx, queueFlowController)
      factoryCtx.AnnounceQueuedGroupJoin()
      queueFlowController.AnnounceQueuedGroupJoin()
    end)
  end)
end

local function RegisterFactoryTargetContextResolutionTests(test, Assert, LoadAddonModules)
  test("Factory target dungeon stays unresolved without queue or joined-key map context", function()
    local ctx = BuildFactoryRuntimeHelperContext({
      roster = {
        player = { name = "Me", realm = "Realm", keyMapID = 2441, keyLevel = 12 },
        party1 = { name = "Other", realm = "Realm", keyMapID = 2441, keyLevel = 14 },
      },
      teleportInfoByMapID = {
        [2441] = { mapName = "Ara-Kara" },
      },
    }, LoadAddonModules)

    Assert.Nil(ctx.ResolveStatusTargetMapID(), "target map must stay unresolved without queue or joined-key context")
    Assert.Nil(ctx.GetStatusTargetDungeonInfo(), "target dungeon text must stay unresolved without strict map context")
  end)

  test("Factory target dungeon omits key level without unique owner resolution", function()
    local ctx = BuildFactoryRuntimeHelperContext({
      latestQueueMapID = 2441,
      latestQueueDungeonName = "Ara-Kara",
      roster = {
        player = { name = "Me", realm = "Realm", keyMapID = 2441, keyLevel = 12 },
      },
      resolveActiveKeyOwnerUnit = function(_roster, _targetMapID)
        return nil
      end,
    }, LoadAddonModules)

    local info = ctx.GetStatusTargetDungeonInfo()
    Assert.NotNil(info, "queue-backed target dungeon should still resolve by name")
    Assert.Equal(info.name, "Ara-Kara", "queue-backed target dungeon should keep the known dungeon name")
    Assert.Nil(info.level, "target key level must stay unresolved without a uniquely resolved owner")
  end)

  test("Factory target dungeon resolves from synced exact target context", function()
    local ctx = BuildFactoryRuntimeHelperContext({
      roster = {
        party1 = { name = "Owner", realm = "Realm" },
      },
      targetInfoByPlayer = {
        ["Owner-Realm"] = { mapID = 2441, level = 14 },
      },
      teleportInfoByMapID = {
        [2441] = { mapName = "Ara-Kara" },
      },
    }, LoadAddonModules)

    Assert.Equal(
      ctx.ResolveStatusTargetMapID(),
      2441,
      "synced exact target map should resolve without local queue context"
    )

    local info = ctx.GetStatusTargetDungeonInfo()
    Assert.NotNil(info, "synced exact target should populate target dungeon info")
    Assert.Equal(info.name, "Ara-Kara", "synced exact target should resolve the map name")
    Assert.Equal(info.level, 14, "synced exact target should keep the explicit synced key level")
  end)

  test("Factory target dungeon stays unresolved on conflicting synced exact targets", function()
    local ctx = BuildFactoryRuntimeHelperContext({
      roster = {
        party1 = { name = "OwnerA", realm = "Realm" },
        party2 = { name = "OwnerB", realm = "Realm" },
      },
      targetInfoByPlayer = {
        ["OwnerA-Realm"] = { mapID = 2441, level = 14 },
        ["OwnerB-Realm"] = { mapID = 2662, level = 12 },
      },
    }, LoadAddonModules)

    Assert.Nil(ctx.ResolveStatusTargetMapID(), "conflicting synced exact targets must stay unresolved")
    Assert.Nil(ctx.GetStatusTargetDungeonInfo(), "conflicting synced exact targets must not guess a dungeon name")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterDungeonDifficultyTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterPortalNavigatorTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterStatusLineTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterFactoryRuntimeQueueTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterFactoryTargetContextResolutionTests(test, Assert, LoadAddonModules)
end
