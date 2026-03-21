---@diagnostic disable: undefined-global

local function BuildGroupState(overrides)
  overrides = overrides or {}
  return {
    wasInGroup = overrides.wasInGroup or false,
    wasRaidGroup = overrides.wasRaidGroup or false,
    roster = {},
    mainFrameVisible = overrides.mainFrameVisible or false,
    raidModeSwitches = 0,
    prints = {},
    queued = 0,
    announced = 0,
    knownUsersCleared = 0,
    inspectResets = 0,
    uiUpdates = 0,
    teleportUpdates = overrides.teleportUpdates or 0,
  }
end

local function BuildGroupControllerOptions(state, overrides)
  overrides = overrides or {}
  return {
    printFn = function(msg)
      table.insert(state.prints, tostring(msg))
    end,
    getL = overrides.getL or function()
      return { RAID_GROUP_HIDDEN = "Raid group detected (>5 members). Addon paused." }
    end,
    isInGroup = overrides.isInGroup or function()
      return true
    end,
    getNumGroupMembers = overrides.getNumGroupMembers or function()
      return 5
    end,
    getActiveChallengeMapID = overrides.getActiveChallengeMapID or function()
      return nil
    end,
    getWasInGroup = function()
      return state.wasInGroup
    end,
    setWasInGroup = function(value)
      state.wasInGroup = value
    end,
    getWasRaidGroup = function()
      return state.wasRaidGroup
    end,
    setWasRaidGroup = function(value)
      state.wasRaidGroup = value
    end,
    setWasGroupLeader = function(_value) end,
    getRoster = function()
      return state.roster
    end,
    setRoster = function(value)
      state.roster = value
    end,
    captureQueueJoinCandidate = function()
      state.queued = state.queued + 1
    end,
    announceQueuedGroupJoin = function()
      state.announced = state.announced + 1
    end,
    setMainFrameVisible = function(visible)
      state.mainFrameVisible = visible
    end,
    switchToRaidMode = function()
      state.raidModeSwitches = state.raidModeSwitches + 1
    end,
    updateLeaderButtons = function() end,
    clearLatestQueueTarget = function() end,
    clearKnownUsers = function()
      state.knownUsersCleared = state.knownUsersCleared + 1
    end,
    resetInspectAll = function()
      state.inspectResets = state.inspectResets + 1
    end,
    resetInspectQueues = function() end,
    updateUI = function()
      state.uiUpdates = state.uiUpdates + 1
    end,
    updateMPlusTeleportButton = function()
      state.teleportUpdates = state.teleportUpdates + 1
    end,
    getUnitNameAndRealm = overrides.getUnitNameAndRealm or function(unit)
      if unit == "player" then
        return "TestPlayer", "TestRealm"
      end
      local idx = tonumber(unit:match("party(%d+)"))
      if idx then
        return "Party" .. idx, "Realm" .. idx
      end
      return nil, nil
    end,
    getUnitClass = overrides.getUnitClass or function(unit)
      if unit == "player" then
        return "Warrior", "WARRIOR"
      end
      return "Mage", "MAGE"
    end,
    getUnitServerLanguage = function(_unit, _realm)
      return "DE"
    end,
    getOwnedKeystoneSnapshot = function()
      return 2649, 15
    end,
    markIsiLiveUser = function() end,
    setPlayerKeyInfo = function() end,
    getUnitRole = overrides.getUnitRole or function(_unit)
      return "DAMAGER"
    end,
    getPlayerSpecName = function()
      return "Arms"
    end,
    getUnitRio = function(_unit)
      return 3500
    end,
    unitHasIsiLive = function(_unit)
      return false
    end,
    applyKnownKeyToRosterEntry = function(_info)
      return false
    end,
    sendOwnKeySnapshot = function(_force) end,
    sendIsiLiveHello = function(_force) end,
  }
end

local function BuildGroupController(loadAddonModules, overrides)
  local state = BuildGroupState(overrides)
  local addon = loadAddonModules({ "isiLive_group.lua" })
  local controller = addon.Group.CreateController(BuildGroupControllerOptions(state, overrides))
  return controller, state
end

local function RegisterGroupLifecycleTests(test, Assert, LoadAddonModules, WithGlobals)
  test("Group join builds roster with player and 4 party members", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return 5
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.NotNil(state.roster.player, "player entry must exist in roster")
    Assert.Equal(state.roster.player.name, "TestPlayer", "player name must be set")
    Assert.Equal(state.roster.player.class, "WARRIOR", "player class must be set")
    Assert.Equal(state.roster.player.hasIsiLive, true, "player must be marked as isiLive user")
    Assert.NotNil(state.roster.party1, "party1 must exist")
    Assert.NotNil(state.roster.party4, "party4 must exist")
    Assert.True(state.mainFrameVisible, "main frame must be visible after group join")

    WithGlobals({
      IsiLiveDB = {
        autoOpenOnQueue = false,
      },
      UIParent = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_frame_bridge.lua" })
      local frameBridgeCalls = {}

      local ctx = {
        modules = {
          contextHelpers = {
            CreateRealmInfoGetter = function()
              return function()
                return nil
              end
            end,
            GetAddonVersionRaw = function()
              return "1.0.0"
            end,
            GetUnitServerLanguage = function(_locale, _realmInfoLib, _unit, _realm)
              return "DE"
            end,
            BuildDummyRoster = function(_opts)
              return {
                player = {
                  name = "TestPlayer",
                  realm = "TestRealm",
                  class = "WARRIOR",
                },
              }
            end,
          },
          frameBridge = {
            CreateContext = function(_opts)
              return {
                centerNotice = {},
                centerNoticeFrame = {},
                centerNoticeTeleportButton = {},
                inviteHint = {},
                mainUI = {},
                mainFrame = {
                  GetScript = function()
                    return nil
                  end,
                  IsShown = function()
                    return false
                  end,
                },
                SetCenterNoticeVisible = function() end,
                UpdateCenterTeleportButtonVisual = function() end,
                ShowCenterNotice = function() end,
                ShowInviteHint = function() end,
                SetMainFrameVisible = function(visible)
                  table.insert(frameBridgeCalls, visible)
                end,
                SetMainFrameHeightSafe = function() end,
                ToggleMainFrameVisibility = function() end,
              }
            end,
          },
          locale = {},
          notice = {
            CreateCenterNotice = function()
              return {}
            end,
            CreateInviteHint = function()
              return {}
            end,
          },
          ui = {
            CreateMainFrame = function()
              return {}
            end,
          },
          teleport = {
            ResolveTeleportSpellIDByActivityID = function() end,
            ResolveMapIDByActivityID = function() end,
            ResolveTeleportSpellID = function() end,
            ApplySecureSpellToButton = function() end,
          },
          units = {
            GetUnitRole = function()
              return "DAMAGER"
            end,
            GetUnitClass = function()
              return "Warrior", "WARRIOR"
            end,
            TruncateName = function(value)
              return value
            end,
            GetUnitNameAndRealm = function()
              return "TestPlayer", "TestRealm"
            end,
            GetPlayerSpecName = function()
              return nil
            end,
            GetInspectSpecName = function()
              return nil
            end,
            GetShortSpecLabel = function(value)
              return value
            end,
            GetUnitRio = function()
              return nil
            end,
          },
          demo = {
            BuildDummyRoster = function()
              return {}
            end,
          },
        },
        runtimeState = {
          IsTestAllMode = function()
            return false
          end,
          SetRoster = function() end,
        },
        GetUnitNameAndRealm = function()
          return "TestPlayer", "TestRealm"
        end,
        GetUnitClass = function()
          return "Warrior", "WARRIOR"
        end,
        GetUnitRole = function()
          return "DAMAGER"
        end,
        GetPlayerSpecName = function()
          return nil
        end,
        GetUnitRio = function()
          return nil
        end,
        GetOwnedKeystoneSnapshot = function()
          return nil, nil
        end,
        UpdateUI = function() end,
        UpdateLeaderButtons = function() end,
        IsSpellKnownSafe = function()
          return true
        end,
        GetTeleportCooldownRemaining = function()
          return nil
        end,
        FormatCooldownSeconds = function(value)
          return tostring(value or "")
        end,
        GetL = function()
          return {}
        end,
        IsInCombat = function()
          return false
        end,
        GetRealmInfoLib = function()
          return nil
        end,
      }

      addon._FactoryInternal.InitializeFactoryFrameBridge(ctx)
      ctx.SetMainFrameVisible(true, "queue")
      Assert.Equal(#frameBridgeCalls, 0, "queue auto-open must stay disabled when the setting is off")
      ctx.SetMainFrameVisible(true)
      Assert.Equal(#frameBridgeCalls, 1, "non-queue show requests must still work when queue auto-open is off")
      Assert.True(frameBridgeCalls[1], "non-queue show request must remain visible")
    end)
  end)

  test("Factory frame bridge restores the layout state when the main frame opens", function()
    local frameBridgeCalls = {}
    local restoreCalls = 0

    WithGlobals({
      IsiLiveDB = {
        autoOpenOnQueue = true,
      },
      UIParent = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_frame_bridge.lua" })

      local ctx = {
        modules = {
          contextHelpers = {
            CreateRealmInfoGetter = function()
              return function()
                return nil
              end
            end,
            GetAddonVersionRaw = function()
              return "1.0.0"
            end,
            GetUnitServerLanguage = function(_locale, _realmInfoLib, _unit, _realm)
              return "DE"
            end,
            BuildDummyRoster = function(_opts)
              return {}
            end,
          },
          frameBridge = {
            CreateContext = function(opts)
              return {
                centerNotice = {},
                centerNoticeFrame = {},
                centerNoticeTeleportButton = {},
                inviteHint = {},
                mainUI = {},
                mainFrame = {
                  GetScript = function()
                    return nil
                  end,
                  IsShown = function()
                    return false
                  end,
                },
                SetCenterNoticeVisible = function() end,
                UpdateCenterTeleportButtonVisual = function() end,
                ShowCenterNotice = function() end,
                ShowInviteHint = function() end,
                SetMainFrameVisible = function(visible)
                  table.insert(frameBridgeCalls, visible)
                  if visible and type(opts.onShownInGroup) == "function" then
                    opts.onShownInGroup()
                  end
                  return visible and true or false
                end,
                SetMainFrameHeightSafe = function() end,
                ToggleMainFrameVisibility = function() end,
              }
            end,
          },
          locale = {},
          notice = {
            CreateCenterNotice = function()
              return {}
            end,
            CreateInviteHint = function()
              return {}
            end,
          },
          ui = {
            CreateMainFrame = function()
              return {}
            end,
          },
          teleport = {
            ResolveTeleportSpellIDByActivityID = function() end,
            ResolveMapIDByActivityID = function() end,
            ResolveTeleportSpellID = function() end,
            ApplySecureSpellToButton = function() end,
          },
          units = {
            GetUnitRole = function()
              return "DAMAGER"
            end,
            GetUnitClass = function()
              return "Warrior", "WARRIOR"
            end,
            TruncateName = function(value)
              return value
            end,
            GetUnitNameAndRealm = function()
              return "TestPlayer", "TestRealm"
            end,
            GetPlayerSpecName = function()
              return nil
            end,
            GetInspectSpecName = function()
              return nil
            end,
            GetShortSpecLabel = function(value)
              return value
            end,
            GetUnitRio = function()
              return nil
            end,
          },
          demo = {
            BuildDummyRoster = function()
              return {}
            end,
          },
        },
        runtimeState = {
          IsTestAllMode = function()
            return false
          end,
          SetRoster = function() end,
        },
        RestoreLayoutState = function()
          restoreCalls = restoreCalls + 1
        end,
        GetUnitNameAndRealm = function()
          return "TestPlayer", "TestRealm"
        end,
        GetUnitClass = function()
          return "Warrior", "WARRIOR"
        end,
        GetUnitRole = function()
          return "DAMAGER"
        end,
        GetPlayerSpecName = function()
          return nil
        end,
        GetUnitRio = function()
          return nil
        end,
        GetOwnedKeystoneSnapshot = function()
          return nil, nil
        end,
        UpdateUI = function() end,
        UpdateLeaderButtons = function() end,
        IsSpellKnownSafe = function()
          return true
        end,
        GetTeleportCooldownRemaining = function()
          return nil
        end,
        FormatCooldownSeconds = function(value)
          return tostring(value or "")
        end,
        GetL = function()
          return {}
        end,
        IsInCombat = function()
          return false
        end,
        GetRealmInfoLib = function()
          return nil
        end,
      }

      addon._FactoryInternal.InitializeFactoryFrameBridge(ctx)
      ctx.SetMainFrameVisible(true)

      Assert.Equal(#frameBridgeCalls, 1, "main frame should be shown once")
      Assert.Equal(restoreCalls, 1, "main frame show should restore the configured layout state")
    end)
  end)

  test("Factory auto-hide when solo defaults to enabled unless explicitly disabled", function()
    local addon = LoadAddonModules({ "isiLive_factory.lua" }, {
      _FactoryInternal = {},
    })

    local resolveAutoHideSoloEnabled = addon._FactoryInternal and addon._FactoryInternal.ResolveAutoHideSoloEnabled
      or nil

    Assert.NotNil(resolveAutoHideSoloEnabled, "factory should export the auto-hide default resolver")
    Assert.True(resolveAutoHideSoloEnabled(nil), "missing saved data should default auto-hide to enabled")
    Assert.True(resolveAutoHideSoloEnabled({}), "missing saved value should default auto-hide to enabled")
    Assert.True(resolveAutoHideSoloEnabled({ autoHideSolo = true }), "explicit true should keep auto-hide enabled")
    Assert.False(resolveAutoHideSoloEnabled({ autoHideSolo = false }), "explicit false should disable auto-hide")
  end)

  test("Group leave keeps frame state and ghosts former party members", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      isInGroup = function()
        return false
      end,
      wasInGroup = true,
      mainFrameVisible = true,
      getUnitNameAndRealm = function(unit)
        if unit == "player" then
          return "Hero", "Realm"
        end
        return nil, nil
      end,
    })

    state.roster.player = {
      name = "Hero",
      realm = "Realm",
      language = "DE",
      class = "WARRIOR",
      role = "DAMAGER",
      spec = "Arms",
      ilvl = 610,
      rio = 3210,
      hasIsiLive = true,
      keyMapID = 2649,
      keyLevel = 15,
      isGhost = false,
      syncDps = 420000,
      syncLocMapID = 2649,
      _refreshQueued = true,
      _localSpecFresh = true,
      _localIlvlFresh = true,
      _localRioFresh = true,
      _localDpsFresh = true,
    }
    local playerEntry = state.roster.player
    state.roster.party1 = { name = "Buddy", realm = "Realm" }

    controller.HandleGroupRosterUpdate()

    Assert.NotNil(state.roster.player, "player row must remain visible after leave")
    Assert.True(state.roster.player == playerEntry, "player row must be updated in place on leave")
    Assert.Equal(state.roster.player.name, "Hero", "player row should keep the local player visible")
    Assert.Equal(state.roster.player.spec, "Arms", "player row should keep the fresh local spec on leave")
    Assert.Equal(state.roster.player.ilvl, 610, "player row should keep the fresh local ilvl on leave")
    Assert.Equal(state.roster.player.rio, 3210, "player row should keep the fresh local rio on leave")
    Assert.Equal(state.roster.player.syncDps, 420000, "player row should keep the sync DPS on leave")
    Assert.Equal(state.roster.player.syncLocMapID, 2649, "player row should keep the sync map on leave")
    Assert.True(state.roster.player._refreshQueued, "player row should keep the pending forced refresh on leave")
    Assert.True(state.roster.player._localSpecFresh, "player row should keep the local spec freshness on leave")
    Assert.True(state.roster.player._localIlvlFresh, "player row should keep the local ilvl freshness on leave")
    Assert.True(state.roster.player._localRioFresh, "player row should keep the local rio freshness on leave")
    Assert.True(state.roster.player._localDpsFresh, "player row should keep the local dps freshness on leave")
    Assert.False(state.roster.player.isGhost, "player row must stay active after leave")
    Assert.Nil(state.roster.party1, "active party1 slot must be cleared after leave")
    Assert.NotNil(state.roster["ghost:Buddy-Realm"], "party1 must become a ghost")
    Assert.True(state.roster["ghost:Buddy-Realm"].isGhost, "party1 ghost flag must be set")
    Assert.Nil(state.roster["ghost:Hero-Realm"], "local player must not become a ghost on leave")
    Assert.True(state.mainFrameVisible, "main frame must stay open after leave when it was visible")
    Assert.Equal(state.inspectResets, 1, "inspect queues must be reset on leave")
    Assert.Equal(state.knownUsersCleared, 1, "known users must be cleared on leave")
  end)

  test("Old ghosts are cleared when joining a new group", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      isInGroup = function()
        return true
      end,
      wasInGroup = false,
      getNumGroupMembers = function()
        return 2
      end,
    })

    state.roster["ghost:OldGuy-Realm"] = { name = "OldGuy", realm = "Realm", isGhost = true }

    controller.HandleGroupRosterUpdate()

    Assert.Nil(state.roster["ghost:OldGuy-Realm"], "old ghosts should be wiped out on new group join")
    Assert.NotNil(state.roster.player, "player should be in roster")
    Assert.NotNil(state.roster.party1, "party1 should be in roster")
  end)

  test("Raid group switches to H mode, keeps frame visible and prints notification", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return 6
      end,
    })

    controller.HandleGroupRosterUpdate()
    controller.HandleGroupRosterUpdate()

    Assert.True(state.mainFrameVisible, "frame must stay visible for raid group (H mode)")
    Assert.Equal(state.raidModeSwitches, 1, "switchToRaidMode must be called exactly once on first raid transition")
    Assert.Equal(#state.prints, 1, "exactly one notification must be printed")
    Assert.True(state.prints[1]:find("Raid") ~= nil, "notification must contain raid message")
  end)

  test("Raid notification prints again after leaving raid-size group", function()
    local members = 6
    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return members
      end,
    })

    controller.HandleGroupRosterUpdate()
    members = 5
    controller.HandleGroupRosterUpdate()
    members = 6
    controller.HandleGroupRosterUpdate()

    Assert.Equal(#state.prints, 2, "raid notification should print again on fresh transition to raid size")
  end)

  test("First group join fires queue capture and announce", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      wasInGroup = false,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Equal(state.queued, 1, "queue capture must fire on first join")
    Assert.Equal(state.announced, 1, "queue announce must fire on first join")
  end)
end

local function RegisterGroupRosterCoreTests(test, Assert, LoadAddonModules)
  test("Active M+ key blocks roster rebuild", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      mainFrameVisible = true,
      getActiveChallengeMapID = function()
        return 2649
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Nil(state.roster.player, "roster must not rebuild during active M+")
    Assert.Equal(state.uiUpdates, 1, "UI should still update during active M+")
  end)

  test("Hidden grouped roster updates keep pre-rendered UI fresh", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      wasInGroup = true,
      mainFrameVisible = false,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Equal(state.uiUpdates, 1, "hidden grouped roster updates should still pre-render UI state")
    Assert.False(state.mainFrameVisible, "hidden grouped roster updates must keep the frame hidden")
  end)

  test("Re-join after leave resets wasInGroup correctly", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      wasInGroup = false,
    })

    controller.HandleGroupRosterUpdate()
    Assert.True(state.wasInGroup, "wasInGroup must be true after join")
    Assert.Equal(state.queued, 1, "first join must capture queue")

    controller.HandleGroupRosterUpdate()
    Assert.Equal(state.queued, 1, "subsequent updates must not re-capture queue")
  end)

  test("Existing grouped roster updates do not re-open a manually hidden frame", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      wasInGroup = true,
      getPlayerSpecName = function()
        return "Fury"
      end,
      getUnitRio = function()
        return 9999
      end,
    })

    state.roster.player = {
      name = "TestPlayer",
      realm = "TestRealm",
      language = "DE",
      class = "WARRIOR",
      role = "DAMAGER",
      spec = "Arms",
      ilvl = 622,
      rio = 3300,
      hasIsiLive = true,
      keyMapID = 2649,
      keyLevel = 15,
      isGhost = false,
      syncDps = 480000,
      syncLocMapID = 2649,
      _refreshQueued = true,
      _localSpecFresh = true,
      _localIlvlFresh = true,
      _localRioFresh = true,
      _localDpsFresh = true,
    }
    local playerEntry = state.roster.player

    controller.HandleGroupRosterUpdate()

    Assert.False(state.mainFrameVisible, "non-join roster updates must keep hidden frame hidden")
    Assert.Equal(state.queued, 0, "non-join roster updates must not re-capture queue")
    Assert.True(state.roster.player == playerEntry, "player row must be updated in place during grouped rebuild")
    Assert.Equal(state.roster.player.spec, "Arms", "pending player spec must not be overwritten during grouped rebuild")
    Assert.Equal(state.roster.player.ilvl, 622, "pending player ilvl must not be overwritten during grouped rebuild")
    Assert.Equal(state.roster.player.rio, 3300, "pending player rio must not be overwritten during grouped rebuild")
    Assert.Equal(state.roster.player.syncDps, 480000, "pending player sync dps must stay intact during grouped rebuild")
    Assert.Equal(
      state.roster.player.syncLocMapID,
      2649,
      "pending player sync map must stay intact during grouped rebuild"
    )
    Assert.True(state.roster.player._refreshQueued, "pending forced refresh must survive grouped rebuild")
    Assert.True(state.roster.player._localSpecFresh, "local spec freshness must survive grouped rebuild")
    Assert.True(state.roster.player._localIlvlFresh, "local ilvl freshness must survive grouped rebuild")
    Assert.True(state.roster.player._localRioFresh, "local rio freshness must survive grouped rebuild")
    Assert.True(state.roster.player._localDpsFresh, "local dps freshness must survive grouped rebuild")
  end)

  test("Party members get correct roles and classes", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return 3
      end,
      getUnitClass = function(unit)
        if unit == "player" then
          return "Paladin", "PALADIN"
        end
        if unit == "party1" then
          return "Priest", "PRIEST"
        end
        if unit == "party2" then
          return "Rogue", "ROGUE"
        end
        return "Warrior", "WARRIOR"
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Equal(state.roster.player.class, "PALADIN", "player class must match")
    Assert.Equal(state.roster.party1.class, "PRIEST", "party1 class must match")
    Assert.Equal(state.roster.party2.class, "ROGUE", "party2 class must match")
  end)

  test("Group leave clears known isiLive users", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      isInGroup = function()
        return false
      end,
      wasInGroup = true,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Equal(state.knownUsersCleared, 1, "known users cache must be cleared on group leave")
  end)
end

local function RegisterGroupGhostShiftTests(test, Assert, LoadAddonModules)
  test("Group member leaving becomes ghost", function()
    local members = 2
    local unitState = "present"
    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return members
      end,
      getUnitNameAndRealm = function(unit)
        if unit == "player" then
          return "Player", "Realm"
        end
        if unit == "party1" and unitState == "present" then
          return "Member", "Realm"
        end
        return nil
      end,
    })

    -- Initial join
    controller.HandleGroupRosterUpdate()
    Assert.NotNil(state.roster.party1, "party1 should exist")

    -- Transient UnitExists failure: keep the current slot alive until it can be read again.
    unitState = "missing"
    controller.HandleGroupRosterUpdate()

    Assert.NotNil(state.roster.party1, "party1 should survive a transient missing-unit race")
    Assert.False(state.roster.party1.isGhost, "transient missing-unit race must not ghost the slot")
    Assert.Nil(state.roster["ghost:Member-Realm"], "transient missing-unit race must not create a ghost")

    -- Member leaves
    members = 1
    controller.HandleGroupRosterUpdate()

    Assert.Nil(state.roster.party1, "party1 slot should be cleared")
    Assert.NotNil(state.roster["ghost:Member-Realm"], "ghost entry should be created")
    Assert.True(state.roster["ghost:Member-Realm"].isGhost, "ghost flag should be set")

    -- Member rejoins (or slot filled)
    members = 2
    unitState = "present"
    controller.HandleGroupRosterUpdate()

    -- Note: In a real scenario, if the SAME player rejoins,
    -- the ghost key logic might vary depending on implementation details,
    -- but if the slot is filled, the ghost should eventually be pruned if the group is full or logic dictates.
    -- Current implementation prunes ghosts only when activeCount >= 5.
    -- Let's verify the ghost persists if group is not full.
    Assert.Nil(state.roster["ghost:Member-Realm"], "ghost should be removed if player rejoins")
    Assert.NotNil(state.roster.party1, "party1 should be back")
  end)

  test("Ghost created correctly when party1 leaves and party2 shifts to party1", function()
    local members = 3 -- Player + 2 party members
    local unitMapping = {
      player = "Player",
      party1 = "MemberA",
      party2 = "MemberB",
    }

    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return members
      end,
      getUnitNameAndRealm = function(unit)
        local name = unitMapping[unit]
        if name then
          return name, "Realm"
        end
        return nil
      end,
    })

    -- Initial state
    controller.HandleGroupRosterUpdate()
    Assert.Equal(state.roster.party1.name, "MemberA", "party1 should be MemberA")
    Assert.Equal(state.roster.party2.name, "MemberB", "party2 should be MemberB")

    -- Shift: MemberA leaves, MemberB becomes party1
    members = 2
    unitMapping = {
      player = "Player",
      party1 = "MemberB",
    }

    controller.HandleGroupRosterUpdate()

    -- Verify MemberA is ghost
    local ghostKey = "ghost:MemberA-Realm"
    Assert.NotNil(state.roster[ghostKey], "MemberA should be a ghost")
    Assert.True(state.roster[ghostKey].isGhost, "MemberA ghost flag should be true")

    -- Verify MemberB is party1
    Assert.Equal(state.roster.party1.name, "MemberB", "party1 should now be MemberB")

    -- Verify party2 is gone (stale slot cleared)
    Assert.Nil(state.roster.party2, "party2 slot should be empty after shrink")
  end)

  test("RIO data persists when member shifts from party2 to party1", function()
    local members = 3
    local unitMapping = {
      player = "Player",
      party1 = "MemberA",
      party2 = "MemberB",
    }

    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return members
      end,
      getUnitNameAndRealm = function(unit)
        local name = unitMapping[unit]
        if name then
          return name, "Realm"
        end
        return nil
      end,
    })

    -- Initial state
    controller.HandleGroupRosterUpdate()

    -- Inject data into MemberB (party2)
    state.roster.party2.rio = 2500
    state.roster.party2.keyLevel = 15

    -- Shift: MemberA leaves, MemberB becomes party1
    members = 2
    unitMapping = {
      player = "Player",
      party1 = "MemberB",
    }

    controller.HandleGroupRosterUpdate()

    -- Verify MemberB (now party1) kept data
    Assert.Equal(state.roster.party1.name, "MemberB", "party1 should be MemberB")
    Assert.Equal(state.roster.party1.rio, 2500, "RIO should persist across slot shift")
    Assert.Equal(state.roster.party1.keyLevel, 15, "Key level should persist across slot shift")
  end)
end

local function RegisterGroupGhostLifecycleTests(test, Assert, LoadAddonModules)
  test("Ghost is removed and data restored when player rejoins", function()
    local members = 2 -- Player + 1 party member
    local unitMapping = {
      player = "Player",
      party1 = "Rejoiner",
    }

    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return members
      end,
      getUnitNameAndRealm = function(unit)
        local name = unitMapping[unit]
        if name then
          return name, "Realm"
        end
        return nil
      end,
    })

    -- Initial state
    controller.HandleGroupRosterUpdate()
    state.roster.party1.rio = 2000 -- Inject data
    Assert.Equal(state.roster.party1.name, "Rejoiner", "party1 should be Rejoiner")

    -- Leave
    members = 1
    unitMapping = { player = "Player" }
    controller.HandleGroupRosterUpdate()

    -- Verify ghost
    local ghostKey = "ghost:Rejoiner-Realm"
    Assert.NotNil(state.roster[ghostKey], "Rejoiner should be a ghost")
    Assert.True(state.roster[ghostKey].isGhost, "ghost flag should be set")
    Assert.Equal(state.roster[ghostKey].rio, 2000, "ghost should retain data")

    -- Rejoin
    members = 2
    unitMapping = {
      player = "Player",
      party1 = "Rejoiner",
    }
    controller.HandleGroupRosterUpdate()

    -- Verify ghost gone
    Assert.Nil(state.roster[ghostKey], "ghost entry should be removed on rejoin")

    -- Verify party1 back with data
    Assert.NotNil(state.roster.party1, "party1 should be present")
    Assert.Equal(state.roster.party1.name, "Rejoiner", "party1 should be Rejoiner")
    Assert.Equal(state.roster.party1.rio, 2000, "data should be restored from ghost")
    Assert.False(state.roster.party1.isGhost, "isGhost should be false for active member")
  end)

  test("Ghosts are pruned when group becomes full (5 members)", function()
    local members = 5 -- Full group (Player + 4)
    local unitMapping = {
      player = "Player",
      party1 = "Member1",
      party2 = "Member2",
      party3 = "Member3",
      party4 = "Member4",
    }

    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return members
      end,
      getUnitNameAndRealm = function(unit)
        local name = unitMapping[unit]
        if name then
          return name, "Realm"
        end
        return nil
      end,
    })

    -- Inject a ghost
    state.roster["ghost:Leaver-Realm"] = {
      name = "Leaver",
      realm = "Realm",
      isGhost = true,
    }

    -- Update with full group
    controller.HandleGroupRosterUpdate()

    -- Verify full group
    Assert.NotNil(state.roster.party1, "party1 should be present")
    Assert.NotNil(state.roster.party4, "party4 should be present")

    -- Verify ghost is pruned
    Assert.Nil(state.roster["ghost:Leaver-Realm"], "ghost should be pruned when group is full")
  end)

  test("Ghosts persist when group is not full (4 members)", function()
    local members = 4 -- Player + 3 party members
    local unitMapping = {
      player = "Player",
      party1 = "Member1",
      party2 = "Member2",
      party3 = "Member3",
    }

    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return members
      end,
      getUnitNameAndRealm = function(unit)
        local name = unitMapping[unit]
        if name then
          return name, "Realm"
        end
        return nil
      end,
      wasInGroup = true,
      isInGroup = function()
        return true
      end,
    })

    -- Inject a ghost
    state.roster["ghost:Leaver-Realm"] = {
      name = "Leaver",
      realm = "Realm",
      isGhost = true,
    }

    -- Update with 4 members
    controller.HandleGroupRosterUpdate()

    -- Verify active members
    Assert.NotNil(state.roster.party1, "party1 should be present")
    Assert.NotNil(state.roster.party3, "party3 should be present")
    Assert.Nil(state.roster.party4, "party4 should not be present")

    -- Verify ghost persists
    Assert.NotNil(state.roster["ghost:Leaver-Realm"], "ghost should persist when group is not full")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  RegisterGroupLifecycleTests(test, Assert, LoadAddonModules, WithGlobals)
  RegisterGroupRosterCoreTests(test, Assert, LoadAddonModules)
  RegisterGroupGhostShiftTests(test, Assert, LoadAddonModules)
  RegisterGroupGhostLifecycleTests(test, Assert, LoadAddonModules)
end
