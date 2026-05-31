---@diagnostic disable: undefined-global

local function BuildGroupState(overrides)
  overrides = overrides or {}
  return {
    wasInGroup = overrides.wasInGroup or false,
    wasRaidGroup = overrides.wasRaidGroup or false,
    roster = {},
    mainFrameVisible = overrides.mainFrameVisible or false,
    prints = {},
    queued = 0,
    announced = 0,
    snapshotCalls = 0,
    snapshotArgs = {},
    helloCalls = 0,
    helloArgs = {},
    refreshRequests = 0,
    refreshRequestArgs = {},
    groupJoinedCalls = 0,
    memberJoinedCalls = 0,
    knownUsersCleared = 0,
    inspectResets = 0,
    uiUpdates = 0,
    teleportUpdates = overrides.teleportUpdates or 0,
    autoCloseCalls = 0,
    mainFrameVisibleCalls = {},
    reloadRosterMirror = overrides.reloadRosterMirror,
    reloadMirrorWrites = 0,
    reloadMirrorClears = 0,
    reloadRosterTargetSnapshot = overrides.reloadRosterTargetSnapshot,
    restoredReloadRosterTargetSnapshot = nil,
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
    setMainFrameVisible = overrides.setMainFrameVisible or function(visible, reasonOrOpts)
      state.mainFrameVisible = visible
      table.insert(state.mainFrameVisibleCalls, {
        visible = visible,
        reasonOrOpts = reasonOrOpts,
      })
    end,
    updateLeaderButtons = function() end,
    clearLatestQueueTarget = function() end,
    clearPendingQueueJoinInfo = function() end,
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
    getOwnAverageItemLevel = overrides.getOwnAverageItemLevel or function()
      return nil
    end,
    unitIsGroupLeader = overrides.unitIsGroupLeader or function(_unit)
      return false
    end,
    unitHasIsiLive = overrides.unitHasIsiLive or function(_unit)
      return false
    end,
    applyKnownKeyToRosterEntry = overrides.applyKnownKeyToRosterEntry or function(_info)
      return false
    end,
    sendOwnKeySnapshot = overrides.sendOwnKeySnapshot or function(force, source)
      state.snapshotCalls = state.snapshotCalls + 1
      table.insert(state.snapshotArgs, {
        force = force == true,
        source = source,
      })
    end,
    sendIsiLiveHello = overrides.sendIsiLiveHello or function(force, source)
      state.helloCalls = state.helloCalls + 1
      table.insert(state.helloArgs, {
        force = force == true,
        source = source,
      })
    end,
    sendRefreshRequest = overrides.sendRefreshRequest or function(force)
      state.refreshRequests = state.refreshRequests + 1
      table.insert(state.refreshRequestArgs, {
        force = force == true,
      })
    end,
    getReloadRosterMirror = overrides.getReloadRosterMirror or function()
      return state.reloadRosterMirror
    end,
    setReloadRosterMirror = overrides.setReloadRosterMirror or function(snapshot)
      state.reloadRosterMirror = snapshot
      state.reloadMirrorWrites = state.reloadMirrorWrites + 1
    end,
    clearReloadRosterMirror = overrides.clearReloadRosterMirror or function()
      state.reloadRosterMirror = {}
      state.reloadMirrorClears = state.reloadMirrorClears + 1
    end,
    getReloadRosterTargetSnapshot = overrides.getReloadRosterTargetSnapshot or function()
      return state.reloadRosterTargetSnapshot
    end,
    restoreReloadRosterTargetSnapshot = overrides.restoreReloadRosterTargetSnapshot or function(snapshot)
      state.restoredReloadRosterTargetSnapshot = snapshot
    end,
    onGroupJoined = overrides.onGroupJoined or function()
      state.groupJoinedCalls = state.groupJoinedCalls + 1
    end,
    onMemberJoinedGroup = overrides.onMemberJoinedGroup or function()
      state.memberJoinedCalls = state.memberJoinedCalls + 1
    end,
    shouldAutoCloseOnSoloChange = overrides.shouldAutoCloseOnSoloChange or function()
      return false
    end,
    getRaidTransitionBehavior = overrides.getRaidTransitionBehavior or function()
      return "hide"
    end,
    autoCloseMainFrame = overrides.autoCloseMainFrame or function()
      state.autoCloseCalls = state.autoCloseCalls + 1
      state.mainFrameVisible = false
    end,
    logRuntimeTrace = overrides.logRuntimeTrace,
    logRuntimeTracef = overrides.logRuntimeTracef,
  }
end

local function BuildGroupController(loadAddonModules, overrides)
  local state = BuildGroupState(overrides)
  local addon = loadAddonModules({ "isiLive_group.lua" })
  local controller = addon.Group.CreateController(BuildGroupControllerOptions(state, overrides))
  return controller, state
end

local function CountRosterEntries(roster)
  local count = 0
  for _ in pairs(roster or {}) do
    count = count + 1
  end
  return count
end

local function RegisterGroupJoinLifecycleTests(test, Assert, LoadAddonModules, WithGlobals)
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
            CreatePortalNavigatorNotice = function()
              return {
                frame = {},
                SetVisible = function() end,
                Show = function() end,
              }
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

  test("Player ilvl is populated directly from getOwnAverageItemLevel without inspect", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return 5
      end,
      getOwnAverageItemLevel = function()
        return 632
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Equal(state.roster.player.ilvl, 632, "player ilvl must be filled from getOwnAverageItemLevel")
    Assert.True(
      state.roster.player._localIlvlFresh,
      "direct player ilvl must mark _localIlvlFresh so sync cannot overwrite it"
    )
  end)

  test("Player ilvl falls back to nil when getOwnAverageItemLevel returns nil and no fresh value exists", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return 5
      end,
      getOwnAverageItemLevel = function()
        return nil
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Nil(state.roster.player.ilvl, "player ilvl stays nil when local API returns nil")
    Assert.True(
      state.roster.player._localIlvlFresh ~= true,
      "_localIlvlFresh must not be set when getOwnAverageItemLevel returned nil"
    )
  end)

  test("Player ilvl is populated even while _refreshQueued is true (post force-refresh)", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return 5
      end,
      getOwnAverageItemLevel = function()
        return 641
      end,
    })

    -- Simulate the QueueForceRefreshData side-effect on the player row that
    -- happens during a /reload, refresh, or post-challenge sync: row exists,
    -- _refreshQueued is true, ilvl/_localIlvlFresh wiped.
    state.roster.player = {
      name = "TestPlayer",
      realm = "TestRealm",
      hasIsiLive = true,
      _refreshQueued = true,
    }

    controller.HandleGroupRosterUpdate()

    Assert.Equal(
      state.roster.player.ilvl,
      641,
      "player ilvl must be populated by getOwnAverageItemLevel even while _refreshQueued is true"
    )
    Assert.True(state.roster.player._localIlvlFresh, "_localIlvlFresh must be set when local ilvl was applied")
  end)

  test("Group roster updates re-apply the teleport highlight while grouped", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return 5
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Equal(state.uiUpdates, 1, "group roster update should still refresh the roster UI once")
    Assert.Equal(state.teleportUpdates, 1, "group roster update should also re-apply the teleport highlight")
  end)

  test("Group roster stores current group leader flag for player and party units", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return 4
      end,
      unitIsGroupLeader = function(unit)
        return unit == "party2"
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.False(state.roster.player.isLeader == true, "player must not be marked as leader when API reports false")
    Assert.False(state.roster.party1.isLeader == true, "non-leader party member must not be marked as leader")
    Assert.True(state.roster.party2.isLeader == true, "party leader must be marked on the roster entry")
    Assert.False(state.roster.party3.isLeader == true, "other party members must remain non-leaders")
  end)

  test("Group roster runtime logger stays capped across 2000 roster burst", function()
    WithGlobals({
      IsiLiveDB = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_log_buffer.lua", "isiLive_runtime_log.lua", "isiLive_group.lua" })
      local runtimeLog = addon.RuntimeLog.CreateController({
        getTimestamp = function()
          return "1000.000"
        end,
        maxEntries = 100,
      })
      runtimeLog.SetEnabled(true)

      local state = BuildGroupState({
        wasInGroup = false,
      })
      local controller = addon.Group.CreateController(BuildGroupControllerOptions(state, {
        getNumGroupMembers = function()
          return 5
        end,
        logRuntimeTracef = runtimeLog.Logf,
      }))

      for _ = 1, 2000 do
        controller.HandleGroupRosterUpdate()
      end

      local tail = runtimeLog.GetLogTail(100)
      Assert.Equal(runtimeLog.GetLogCount(), 100, "roster burst trace must stay capped")
      Assert.Equal(#tail, 100, "roster burst tail must stay capped")
      Assert.Equal(CountRosterEntries(state.roster), 5, "roster burst must keep only player plus party entries")
      Assert.Equal(state.snapshotCalls, 2000, "roster burst must complete all snapshot sends")
      Assert.True(
        tail[#tail]:find("%[GROUP%] event=roster_update wasInGroup=true inGroupNow=true joinedNow=false") ~= nil,
        "roster burst tail must include normalized group trace"
      )
    end)
  end)
end

local function RegisterFactoryFrameBridgeRestoreTests(test, Assert, LoadAddonModules, WithGlobals)
  test("Factory frame bridge restores the layout state when the main frame opens", function()
    local frameBridgeCalls = {}
    local markCdTrackerDirtyCalls = 0
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
            CreatePortalNavigatorNotice = function()
              return {
                frame = {},
                SetVisible = function() end,
                Show = function() end,
              }
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
        rosterPanelController = {
          MarkCdTrackerDirty = function()
            markCdTrackerDirtyCalls = markCdTrackerDirtyCalls + 1
          end,
        },
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
      Assert.Equal(
        markCdTrackerDirtyCalls,
        1,
        "main frame show should mark the utility tracker dirty for one fresh visible rescan"
      )
      Assert.Equal(restoreCalls, 1, "main frame show should restore the configured layout state")
    end)
  end)

  test("Factory frame bridge wires GetDungeonName into center notice context", function()
    local capturedFrameBridgeOpts = nil

    WithGlobals({
      UIParent = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_factory_frame_bridge.lua" })

      local ctx = {
        locale = "deDE",
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
            GetUnitServerLanguage = function()
              return "DE"
            end,
            BuildDummyRoster = function()
              return {}
            end,
          },
          frameBridge = {
            CreateContext = function(opts)
              capturedFrameBridgeOpts = opts
              return {
                centerNotice = {},
                centerNoticeFrame = {},
                centerNoticeTeleportButton = {},
                inviteHint = {},
                mainUI = {},
                mainFrame = {},
                SetCenterNoticeVisible = function() end,
                UpdateCenterTeleportButtonVisual = function() end,
                ShowCenterNotice = function() end,
                ShowInviteHint = function() end,
                SetMainFrameVisible = function()
                  return false
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
            CreatePortalNavigatorNotice = function()
              return {
                frame = {},
                SetVisible = function() end,
                Show = function() end,
              }
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
            ResolveMapIDBySpellID = function() end,
            ResolveTeleportSpellID = function() end,
            GetDungeonName = function(mapID, localeTag)
              if mapID == 558 and localeTag == "enUS" then
                return "Magisters' Terrace"
              end
              if mapID == 558 and localeTag == "deDE" then
                return "Terrasse der Magister"
              end
              return nil
            end,
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
        RestoreLayoutState = function() end,
        EnsureSoloPlayerRoster = function() end,
        UpdateUI = function() end,
        UpdateLeaderButtons = function() end,
        IsSpellKnownSafe = function()
          return true
        end,
        GetTeleportCooldownRemaining = function()
          return 0
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

      Assert.NotNil(capturedFrameBridgeOpts, "frame bridge context must be created")
      local getDungeonName = capturedFrameBridgeOpts and capturedFrameBridgeOpts.getDungeonName or nil
      if getDungeonName == nil then
        error("factory frame bridge must wire GetDungeonName into the center notice context")
      end
      Assert.Equal(
        getDungeonName(558, "enUS"),
        "Magisters' Terrace",
        "factory frame bridge must wire GetDungeonName into the center notice context"
      )
    end)
  end)
end

local function RegisterGroupLifecycleTests(test, Assert, LoadAddonModules, WithGlobals)
  RegisterGroupJoinLifecycleTests(test, Assert, LoadAddonModules, WithGlobals)
  RegisterFactoryFrameBridgeRestoreTests(test, Assert, LoadAddonModules, WithGlobals)
end

local function RegisterGroupLifecycleFollowupTests(test, Assert, LoadAddonModules)
  test("Factory key-start and solo-change auto-close resolvers default to disabled", function()
    local addon = LoadAddonModules({ "isiLive_factory.lua" }, {
      _FactoryInternal = {},
    })

    local resolveKeyStart = addon._FactoryInternal and addon._FactoryInternal.ResolveAutoCloseOnKeyStartEnabled or nil
    local resolveSolo = addon._FactoryInternal and addon._FactoryInternal.ResolveAutoCloseOnSoloChangeEnabled or nil

    Assert.NotNil(resolveKeyStart, "factory should export the key-start auto-close resolver")
    Assert.NotNil(resolveSolo, "factory should export the solo-change auto-close resolver")
    if resolveKeyStart == nil or resolveSolo == nil then
      error("factory should export both auto-close resolvers")
    end
    Assert.False(resolveKeyStart(nil), "missing saved data should default key-start auto-close to disabled")
    Assert.False(resolveKeyStart({}), "missing saved value should default key-start auto-close to disabled")
    Assert.True(resolveKeyStart({ autoCloseOnKeyStart = true }), "explicit true enables key-start auto-close")
    Assert.False(resolveKeyStart({ autoCloseOnKeyStart = false }), "explicit false keeps key-start auto-close disabled")
    Assert.True(resolveSolo({ autoCloseOnSoloChange = true }), "explicit true enables solo-change auto-close")
    Assert.False(resolveSolo({ autoCloseOnSoloChange = false }), "explicit false keeps solo-change auto-close off")
  end)

  test("Factory startup and key-end auto-open resolvers default to enabled", function()
    local addon = LoadAddonModules({ "isiLive_factory.lua" }, {
      _FactoryInternal = {},
    })

    local internal = addon._FactoryInternal or {}
    local resolveStartup = internal.ResolveAutoShowMainFrameOnStartupEnabled
    local resolveKeyEnd = internal.ResolveAutoOpenMainFrameOnKeyEndEnabled

    Assert.NotNil(resolveStartup, "factory should export the startup auto-show resolver")
    Assert.NotNil(resolveKeyEnd, "factory should export the key-end auto-open resolver")
    Assert.True(resolveStartup(nil), "missing startup setting should default to enabled")
    Assert.True(resolveKeyEnd(nil), "missing key-end setting should default to enabled")
    Assert.False(
      resolveStartup({ autoShowMainFrameOnStartup = false }),
      "explicit false should disable startup auto-show"
    )
    Assert.False(
      resolveKeyEnd({ autoOpenMainFrameOnKeyEnd = false }),
      "explicit false should disable key-end auto-open"
    )
  end)

  test("Factory raid behavior resolver defaults to raid off and normalizes legacy values", function()
    local addon = LoadAddonModules({ "isiLive_factory.lua" }, {
      _FactoryInternal = {},
    })

    local resolveRaidBehavior = addon._FactoryInternal and addon._FactoryInternal.ResolveRaidTransitionBehavior or nil

    Assert.NotNil(resolveRaidBehavior, "factory should export the raid behavior resolver")
    local resolveRaid = resolveRaidBehavior
    if resolveRaid == nil then
      error("factory should export the raid behavior resolver")
    end
    Assert.Equal(resolveRaid(nil), "hide", "missing raid behavior should default to raid off")
    Assert.Equal(resolveRaid({}), "hide", "missing raid behavior field should default to raid off")
    Assert.Equal(
      resolveRaid({ raidTransitionBehavior = "show_h" }),
      "hide",
      "legacy raid behavior must normalize to raid off"
    )
    Assert.Equal(
      resolveRaid({ raidTransitionBehavior = "show_keep" }),
      "hide",
      "legacy raid behavior must normalize to raid off"
    )
    Assert.Equal(
      resolveRaid({ raidTransitionBehavior = "preserve" }),
      "hide",
      "legacy raid behavior must normalize to raid off"
    )
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
    state.roster.party1 = { name = "Buddy", realm = "Realm", isLeader = true }

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
    Assert.False(state.roster["ghost:Buddy-Realm"].isLeader == true, "party1 ghost must not keep leader crown state")
    Assert.Nil(state.roster["ghost:Hero-Realm"], "local player must not become a ghost on leave")
    Assert.True(state.mainFrameVisible, "main frame must stay open after leave when it was visible")
    Assert.Equal(state.inspectResets, 1, "inspect queues must be reset on leave")
    Assert.Equal(state.knownUsersCleared, 1, "known users must be cleared on leave")
  end)

  test("Group leave auto-close hides frame when option is enabled", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      isInGroup = function()
        return false
      end,
      wasInGroup = true,
      mainFrameVisible = true,
      shouldAutoCloseOnSoloChange = function()
        return true
      end,
    })

    state.roster.player = {
      name = "Hero",
      realm = "Realm",
      hasIsiLive = true,
      isGhost = false,
    }
    state.roster.party1 = { name = "Buddy", realm = "Realm" }

    controller.HandleGroupRosterUpdate()

    Assert.False(state.mainFrameVisible, "enabled auto-close must hide the frame on solo transition")
    Assert.Equal(state.autoCloseCalls, 1, "solo transition must trigger exactly one auto-close callback")
    Assert.NotNil(state.roster["ghost:Buddy-Realm"], "auto-close must not skip ghost preservation")
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

  test("Raid group hides the UI and suppresses background processing", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      getNumGroupMembers = function()
        return 6
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.False(state.mainFrameVisible, "raid transition must hide the main frame")
    Assert.Equal(#state.mainFrameVisibleCalls, 1, "raid transition should issue one hide request")
    Assert.False(state.mainFrameVisibleCalls[1].visible, "raid transition should hide instead of opening")
    Assert.Equal(state.uiUpdates, 0, "raid transition must not rerender the roster")
    Assert.Equal(#state.prints, 0, "raid transition must not print a raid notice")
  end)

  test("First group join fires queue capture and announce", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      wasInGroup = false,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Equal(state.queued, 1, "queue capture must fire on first join")
    Assert.Equal(state.announced, 1, "queue announce must fire on first join")
    Assert.Equal(state.memberJoinedCalls, 1, "first join should notify once when the group is full")
  end)

  test("Group join sound waits until the group is full", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      wasInGroup = false,
      getNumGroupMembers = function()
        return 4
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Equal(state.memberJoinedCalls, 0, "partial groups must not play the group-full sound")
  end)

  test("First group join fires the optional join callback exactly once", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      wasInGroup = false,
    })

    controller.HandleGroupRosterUpdate()
    controller.HandleGroupRosterUpdate()

    Assert.Equal(state.groupJoinedCalls, 1, "first join callback must fire once and not repeat on later roster updates")
  end)

  test("First group join auto-open suppresses recursive join side effects", function()
    local controller, state
    local controllerRef = nil
    controller, state = BuildGroupController(LoadAddonModules, {
      wasInGroup = false,
      setMainFrameVisible = function(visible, reasonOrOpts)
        state.mainFrameVisible = visible
        table.insert(state.mainFrameVisibleCalls, {
          visible = visible,
          reasonOrOpts = reasonOrOpts,
        })
        local opts = type(reasonOrOpts) == "table" and reasonOrOpts or {}
        if visible and opts.skipShowCallbacks ~= true and controllerRef then
          controllerRef.HandleGroupRosterUpdate()
        end
      end,
    })
    controllerRef = controller

    controller.HandleGroupRosterUpdate()

    local firstCall = state.mainFrameVisibleCalls[1]
    Assert.NotNil(firstCall, "first join should still issue a frame show request")
    Assert.True(
      type(firstCall.reasonOrOpts) == "table" and firstCall.reasonOrOpts.skipShowCallbacks == true,
      "first join auto-open must suppress follow-up show callbacks"
    )
    Assert.Equal(
      type(firstCall.reasonOrOpts) == "table" and firstCall.reasonOrOpts.reason or nil,
      "queue",
      "first join auto-open must preserve queue reason metadata"
    )
    Assert.Equal(state.queued, 1, "first join queue capture must still run exactly once")
    Assert.Equal(state.announced, 1, "first join queue announce must still run exactly once")
    Assert.Equal(state.snapshotCalls, 1, "first join key snapshot must still send exactly once")
    Assert.Equal(state.helloCalls, 1, "first join hello must still send exactly once")
    Assert.Equal(state.refreshRequests, 1, "first join must request one forced peer sync refresh")
    Assert.True(
      state.snapshotArgs[1] and state.snapshotArgs[1].force == true,
      "first join key snapshot must bypass sync cooldowns"
    )
    Assert.True(state.helloArgs[1] and state.helloArgs[1].force == true, "first join hello must bypass sync cooldowns")
    Assert.True(
      state.refreshRequestArgs[1] and state.refreshRequestArgs[1].force == true,
      "first join peer sync request must bypass request cooldowns"
    )
  end)
end

local function RegisterGroupRosterCoreTests(test, Assert, LoadAddonModules)
  test("Active M+ key does not rebuild roster on ongoing updates", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      mainFrameVisible = true,
      wasInGroup = true,
      getActiveChallengeMapID = function()
        return 2649
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Nil(state.roster.player, "ongoing roster updates must not rebuild during active M+")
    Assert.Equal(state.uiUpdates, 1, "UI should still update during active M+")
  end)

  test("Active M+ key rebuilds roster after /reload (joinedNow path)", function()
    -- On /reload inside an active key, the Lua state is fresh: wasInGroup=false and
    -- inGroupNow=true, so joinedNow=true. PLAYER_ENTERING_WORLD manually triggers
    -- handleGroupRosterUpdate() as a fallback (GROUP_ROSTER_UPDATE is gated hidden in key).
    -- The roster must be populated so UI shows group members again.
    local controller, state = BuildGroupController(LoadAddonModules, {
      mainFrameVisible = true,
      wasInGroup = false,
      getActiveChallengeMapID = function()
        return 2649
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.NotNil(state.roster.player, "post-reload rebuild must populate the player entry")
    Assert.Equal(state.roster.player.name, "TestPlayer", "player name must be set after reload")
    Assert.NotNil(state.roster.party1, "post-reload rebuild must populate party1")
    Assert.NotNil(state.roster.party4, "post-reload rebuild must populate party4")
    Assert.Equal(state.queued, 0, "reload-in-key must not trigger queue-join side effects (no queue capture)")
    Assert.Equal(state.announced, 0, "reload-in-key must not announce a queued group join")
    Assert.Equal(state.groupJoinedCalls, 0, "reload-in-key must not fire onGroupJoined")
    Assert.Equal(#state.mainFrameVisibleCalls, 0, "reload-in-key must not auto-show or auto-hide the main frame")
  end)

  test("Reload roster mirror suppresses group-join side effects outside active key", function()
    local mirror = {
      signature = "Party1-Realm1|Party2-Realm2|Party3-Realm3|Party4-Realm4|TestPlayer-TestRealm",
      members = {
        ["TestPlayer-TestRealm"] = {
          name = "TestPlayer",
          realm = "TestRealm",
          class = "WARRIOR",
          spec = "Arms",
          ilvl = 631,
          rio = 3500,
        },
        ["Party1-Realm1"] = { name = "Party1", realm = "Realm1", class = "MAGE" },
        ["Party2-Realm2"] = { name = "Party2", realm = "Realm2", class = "MAGE" },
        ["Party3-Realm3"] = { name = "Party3", realm = "Realm3", class = "MAGE" },
        ["Party4-Realm4"] = { name = "Party4", realm = "Realm4", class = "MAGE" },
      },
      targetKey = {
        mapID = 2449,
        name = "Sitz des Triumvirats",
      },
    }
    local controller, state = BuildGroupController(LoadAddonModules, {
      wasInGroup = false,
      reloadRosterMirror = mirror,
    })

    controller.HandleGroupRosterUpdate()

    Assert.NotNil(state.roster.player, "reload mirror must still restore the player entry")
    Assert.Equal(state.queued, 0, "reload with matching mirror must not capture a fresh queue join")
    Assert.Equal(state.announced, 0, "reload with matching mirror must not announce a queued group join")
    Assert.Equal(state.groupJoinedCalls, 0, "reload with matching mirror must not fire group-join notice callbacks")
    Assert.Equal(#state.mainFrameVisibleCalls, 0, "reload with matching mirror must not auto-open as a queue join")
    Assert.Equal(state.snapshotCalls, 1, "reload with matching mirror still sends the normal group snapshot")
    Assert.False(state.snapshotArgs[1].force, "reload group snapshot must not be marked as a fresh forced join")
    Assert.Equal(state.helloCalls, 1, "reload with matching mirror still sends the normal group hello")
    Assert.False(state.helloArgs[1].force, "reload group hello must not be marked as a fresh forced join")
    Assert.Equal(state.refreshRequests, 1, "reload with matching mirror must still request live peer refresh")
    Assert.True(state.refreshRequestArgs[1].force, "reload mirror refresh should bypass request cooldowns")
    Assert.NotNil(state.restoredReloadRosterTargetSnapshot, "reload mirror must restore the verified target snapshot")
  end)

  test("Reload roster mirror restores verified data when group signature matches", function()
    local mirror = {
      signature = "Member-Realm|TestPlayer-TestRealm",
      members = {
        ["TestPlayer-TestRealm"] = {
          name = "TestPlayer",
          realm = "TestRealm",
          class = "WARRIOR",
          spec = "Arms",
          ilvl = 631,
          rio = 3500,
          hasIsiLive = true,
          keyMapID = 2649,
          keyLevel = 15,
          syncHasKick = true,
        },
        ["Member-Realm"] = {
          name = "Member",
          realm = "Realm",
          class = "MAGE",
          spec = "Frost",
          ilvl = 629,
          rio = 3210,
          hasIsiLive = true,
          keyMapID = 2650,
          keyLevel = 16,
          syncDps = 450000,
          syncLocMapID = 2650,
          syncHasKick = false,
        },
      },
    }
    local controller, state = BuildGroupController(LoadAddonModules, {
      wasInGroup = false,
      reloadRosterMirror = mirror,
      getNumGroupMembers = function()
        return 2
      end,
      getUnitNameAndRealm = function(unit)
        if unit == "player" then
          return "TestPlayer", "TestRealm"
        end
        if unit == "party1" then
          return "Member", "Realm"
        end
        return nil, nil
      end,
      unitHasIsiLive = function()
        return false
      end,
      applyKnownKeyToRosterEntry = function(info)
        info.keyMapID = nil
        info.keyLevel = nil
        return true
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Equal(state.roster.party1.spec, "Frost", "matching mirror must restore peer spec")
    Assert.Equal(state.roster.party1.ilvl, 629, "matching mirror must restore peer ilvl")
    Assert.Equal(state.roster.party1.rio, 3210, "matching mirror must restore peer RIO")
    Assert.Equal(state.roster.party1.keyMapID, 2650, "matching mirror must preserve peer key before live sync")
    Assert.Equal(state.roster.party1.keyLevel, 16, "matching mirror must preserve peer key level before live sync")
    Assert.Equal(state.roster.party1.syncDps, 450000, "matching mirror must restore peer DPS fallback")
    Assert.Equal(state.roster.party1.hasIsiLive, true, "matching mirror must restore known isiLive marker")
    Assert.Nil(state.roster.party1.syncHasKick, "kick state must not be restored from the reload mirror")
    Assert.Equal(state.refreshRequests, 1, "restore path must still request live peer refresh on join")
    Assert.True(state.reloadMirrorWrites > 0, "restored roster must be mirrored again after the update")
  end)

  test("Reload roster mirror restores verified target key when group signature matches", function()
    local mirror = {
      signature = "Member-Realm|TestPlayer-TestRealm",
      targetKey = {
        mapID = 2441,
        name = "Tazavesh",
        level = 12,
        levelText = "+12",
      },
      members = {
        ["TestPlayer-TestRealm"] = {
          name = "TestPlayer",
          realm = "TestRealm",
          class = "WARRIOR",
        },
        ["Member-Realm"] = {
          name = "Member",
          realm = "Realm",
          class = "MAGE",
        },
      },
    }
    local controller, state = BuildGroupController(LoadAddonModules, {
      wasInGroup = false,
      reloadRosterMirror = mirror,
      getNumGroupMembers = function()
        return 2
      end,
      getUnitNameAndRealm = function(unit)
        if unit == "player" then
          return "TestPlayer", "TestRealm"
        end
        if unit == "party1" then
          return "Member", "Realm"
        end
        return nil, nil
      end,
      getReloadRosterTargetSnapshot = function()
        return {
          mapID = 2441,
          name = "Tazavesh",
          level = 12,
          levelText = "+12",
        }
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.NotNil(state.restoredReloadRosterTargetSnapshot, "matching mirror must restore target key snapshot")
    Assert.Equal(state.restoredReloadRosterTargetSnapshot.mapID, 2441, "restored target mapID must match")
    Assert.Equal(state.restoredReloadRosterTargetSnapshot.name, "Tazavesh", "restored target name must match")
    Assert.Equal(state.restoredReloadRosterTargetSnapshot.level, 12, "restored target level must match")
    Assert.Equal(state.restoredReloadRosterTargetSnapshot.levelText, "+12", "restored target level text must match")
    Assert.NotNil(state.reloadRosterMirror.targetKey, "post-restore mirror write must keep target key snapshot")
    Assert.Equal(state.reloadRosterMirror.targetKey.mapID, 2441, "saved target mapID must match")
    Assert.Equal(state.reloadRosterMirror.targetKey.level, 12, "saved target level must match")
  end)

  test("Reload roster mirror is discarded when group signature differs", function()
    local controller, state = BuildGroupController(LoadAddonModules, {
      wasInGroup = false,
      reloadRosterMirror = {
        signature = "Other-Realm|TestPlayer-TestRealm",
        targetKey = {
          mapID = 2441,
          name = "Tazavesh",
          level = 12,
        },
        members = {
          ["TestPlayer-TestRealm"] = {
            name = "TestPlayer",
            realm = "TestRealm",
          },
          ["Other-Realm"] = {
            name = "Other",
            realm = "Realm",
            spec = "Frost",
            ilvl = 629,
          },
        },
      },
      getNumGroupMembers = function()
        return 2
      end,
      getUnitNameAndRealm = function(unit)
        if unit == "player" then
          return "TestPlayer", "TestRealm"
        end
        if unit == "party1" then
          return "Member", "Realm"
        end
        return nil, nil
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Nil(state.roster.party1.spec, "mismatched mirror must not restore peer spec")
    Assert.Nil(state.roster.party1.ilvl, "mismatched mirror must not restore peer ilvl")
    Assert.Nil(state.restoredReloadRosterTargetSnapshot, "mismatched mirror must not restore target key")
    Assert.True(state.reloadMirrorClears > 0, "mismatched mirror must be cleared")
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

  test("Raid exit clears known isiLive users before resync", function()
    local sentSnapshots = 0
    local snapshotArgs = {}
    local controller, state = BuildGroupController(LoadAddonModules, {
      wasInGroup = true,
      wasRaidGroup = true,
      getNumGroupMembers = function()
        return 5
      end,
      sendOwnKeySnapshot = function(force, source)
        sentSnapshots = sentSnapshots + 1
        table.insert(snapshotArgs, {
          force = force == true,
          source = source,
        })
      end,
    })

    controller.HandleGroupRosterUpdate()

    Assert.Equal(state.knownUsersCleared, 1, "known users cache must be cleared when leaving raid")
    Assert.Equal(sentSnapshots, 1, "raid exit must still resync once after cache reset")
    Assert.True(
      snapshotArgs[1] and snapshotArgs[1].force == false,
      "raid exit resync should use the normal non-forced snapshot path"
    )
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
    Assert.False(state.roster["ghost:Member-Realm"].isLeader == true, "ghost entry must not retain leader state")

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
  RegisterGroupLifecycleFollowupTests(test, Assert, LoadAddonModules)
  RegisterGroupRosterCoreTests(test, Assert, LoadAddonModules)
  RegisterGroupGhostShiftTests(test, Assert, LoadAddonModules)
  RegisterGroupGhostLifecycleTests(test, Assert, LoadAddonModules)
end
