---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  local function noop() end

  local function makeMinimalDeps()
    return {
      printFn = noop,
      getL = noop,
      isInGroup = noop,
      getNumGroupMembers = noop,
      getActiveChallengeMapID = noop,
      getUnitNameAndRealm = noop,
      getUnitClass = noop,
      getUnitServerLanguage = noop,
      getOwnedKeystoneSnapshot = noop,
      markIsiLiveUser = noop,
      getUnitRole = noop,
      getPlayerSpecName = noop,
      getUnitRio = noop,
      unitIsGroupLeader = noop,
      unitHasIsiLive = noop,
      applyKnownKeyToRosterEntry = noop,
      enqueueInspect = noop,
      sendOwnKeySnapshot = noop,
      sendIsiLiveHello = noop,
      sendRefreshRequest = noop,
      state = {
        getWasInGroup = noop,
        setWasInGroup = noop,
        getWasRaidGroup = noop,
        setWasRaidGroup = noop,
        setWasGroupLeader = noop,
        getRoster = noop,
        setRoster = noop,
      },
      callbacks = {
        captureQueueJoinCandidate = noop,
        announceQueuedGroupJoin = noop,
        setMainFrameVisible = noop,
        updateLeaderButtons = noop,
        clearLatestQueueTarget = noop,
        resetInspectAll = noop,
        resetInspectQueues = noop,
        updateUI = noop,
        updateMPlusTeleportButton = noop,
      },
      modules = {
        sync = {
          ClearKnownUsers = noop,
          SetPlayerKeyInfo = noop,
        },
      },
    }
  end

  local function captureGroupModuleOpts()
    local captured = nil
    local groupModule = {
      CreateController = function(opts)
        captured = opts
        return {}
      end,
    }
    return groupModule, function()
      return captured
    end
  end

  test("ControllerWiring CreateGroupController succeeds with all required deps provided", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local groupModule, getOpts = captureGroupModuleOpts()
    local ctrl = addon.ControllerWiring.CreateGroupController(groupModule, makeMinimalDeps())
    Assert.NotNil(ctrl, "controller must be returned when all deps are provided")
    Assert.NotNil(getOpts(), "groupModule.CreateController must be called")
  end)

  test("ControllerWiring CreateGroupController throws when groupModule is nil", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local ok, err = pcall(function()
      addon.ControllerWiring.CreateGroupController(nil, makeMinimalDeps())
    end)
    Assert.False(ok, "nil groupModule must throw")
    Assert.True(type(err) == "string" and err:find("groupModule") ~= nil, "error must mention groupModule")
  end)

  test("ControllerWiring CreateGroupController throws when printFn is missing", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local groupModule = captureGroupModuleOpts()
    local deps = makeMinimalDeps()
    deps.printFn = nil
    local ok, err = pcall(function()
      addon.ControllerWiring.CreateGroupController(groupModule, deps)
    end)
    Assert.False(ok, "missing printFn must throw")
    Assert.True(type(err) == "string" and err:find("printFn") ~= nil, "error must mention printFn")
  end)

  test("ControllerWiring CreateGroupController throws when required state table is missing", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local groupModule = captureGroupModuleOpts()
    local deps = makeMinimalDeps()
    deps.state = nil
    local ok, err = pcall(function()
      addon.ControllerWiring.CreateGroupController(groupModule, deps)
    end)
    Assert.False(ok, "missing state table must throw")
    Assert.True(type(err) == "string" and err:find("state") ~= nil, "error must mention state")
  end)

  test("ControllerWiring CreateGroupController throws when required callbacks table is missing", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local groupModule = captureGroupModuleOpts()
    local deps = makeMinimalDeps()
    deps.callbacks = nil
    local ok, err = pcall(function()
      addon.ControllerWiring.CreateGroupController(groupModule, deps)
    end)
    Assert.False(ok, "missing callbacks table must throw")
    Assert.True(type(err) == "string" and err:find("callbacks") ~= nil, "error must mention callbacks")
  end)

  test("ControllerWiring clearKnownUsers closure delegates to modules.sync.ClearKnownUsers", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local clearCalled = false
    local deps = makeMinimalDeps()
    deps.modules.sync.ClearKnownUsers = function()
      clearCalled = true
    end
    local groupModule, getOpts = captureGroupModuleOpts()
    addon.ControllerWiring.CreateGroupController(groupModule, deps)

    getOpts().clearKnownUsers()

    Assert.True(clearCalled, "clearKnownUsers must delegate to modules.sync.ClearKnownUsers")
  end)

  test("ControllerWiring clearKnownUsers is a no-op when sync lacks ClearKnownUsers", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local deps = makeMinimalDeps()
    deps.modules.sync = {}
    local groupModule, getOpts = captureGroupModuleOpts()
    addon.ControllerWiring.CreateGroupController(groupModule, deps)

    local ok = pcall(function()
      getOpts().clearKnownUsers()
    end)
    Assert.True(ok, "clearKnownUsers must not throw when sync has no ClearKnownUsers")
  end)

  test("ControllerWiring setPlayerKeyInfo closure delegates to modules.sync.SetPlayerKeyInfo", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    ---@type {name:string, realm:string, mapID:number, level:number}?
    local capturedArgs = nil
    local deps = makeMinimalDeps()
    deps.modules.sync.SetPlayerKeyInfo = function(name, realm, mapID, level)
      capturedArgs = { name = name, realm = realm, mapID = mapID, level = level }
    end
    local groupModule, getOpts = captureGroupModuleOpts()
    addon.ControllerWiring.CreateGroupController(groupModule, deps)

    getOpts().setPlayerKeyInfo("TestPlayer", "TestRealm", 2649, 15)

    Assert.NotNil(capturedArgs, "setPlayerKeyInfo must invoke modules.sync.SetPlayerKeyInfo")
    ---@cast capturedArgs -nil
    Assert.Equal(capturedArgs.name, "TestPlayer")
    Assert.Equal(capturedArgs.realm, "TestRealm")
    Assert.Equal(capturedArgs.mapID, 2649)
    Assert.Equal(capturedArgs.level, 15)
  end)

  test("ControllerWiring forwards full-group sound callback into the group controller", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local callbackCalls = 0
    local deps = makeMinimalDeps()
    deps.callbacks.onMemberJoinedGroup = function()
      callbackCalls = callbackCalls + 1
    end
    local groupModule, getOpts = captureGroupModuleOpts()
    addon.ControllerWiring.CreateGroupController(groupModule, deps)

    getOpts().onMemberJoinedGroup()

    Assert.Equal(callbackCalls, 1, "onMemberJoinedGroup must be forwarded to Group.CreateController")
  end)

  test("ControllerWiring forwards group-joined callback into the group controller", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local callbackCalls = 0
    local deps = makeMinimalDeps()
    deps.callbacks.onGroupJoined = function()
      callbackCalls = callbackCalls + 1
    end
    local groupModule, getOpts = captureGroupModuleOpts()
    addon.ControllerWiring.CreateGroupController(groupModule, deps)

    getOpts().onGroupJoined()

    Assert.Equal(callbackCalls, 1, "onGroupJoined must be forwarded to Group.CreateController")
  end)

  test("ControllerWiring optional clearRioBaselineSnapshot uses no-op default when absent", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local deps = makeMinimalDeps()
    deps.callbacks.clearRioBaselineSnapshot = nil
    local groupModule, getOpts = captureGroupModuleOpts()
    addon.ControllerWiring.CreateGroupController(groupModule, deps)

    local ok = pcall(function()
      getOpts().clearRioBaselineSnapshot()
    end)
    Assert.True(ok, "absent clearRioBaselineSnapshot must produce a callable no-op")
  end)

  test("ControllerWiring optional clearPendingQueueJoinInfo uses no-op default when absent", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local deps = makeMinimalDeps()
    deps.callbacks.clearPendingQueueJoinInfo = nil
    local groupModule, getOpts = captureGroupModuleOpts()
    addon.ControllerWiring.CreateGroupController(groupModule, deps)

    local ok = pcall(function()
      getOpts().clearPendingQueueJoinInfo()
    end)
    Assert.True(ok, "absent clearPendingQueueJoinInfo must produce a callable no-op")
  end)

  test("ControllerWiring CreateGroupControllerFromContext maps sync into modules.sync", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local clearCalled = false
    local syncStub = {
      ClearKnownUsers = function()
        clearCalled = true
      end,
      SetPlayerKeyInfo = noop,
    }

    local wireCtx = {
      sync = syncStub,
      printFn = noop,
      getL = noop,
      isInGroup = noop,
      getNumGroupMembers = noop,
      getActiveChallengeMapID = noop,
      getUnitNameAndRealm = noop,
      getUnitClass = noop,
      getUnitServerLanguage = noop,
      getOwnedKeystoneSnapshot = noop,
      markIsiLiveUser = noop,
      getUnitRole = noop,
      getPlayerSpecName = noop,
      getUnitRio = noop,
      unitIsGroupLeader = noop,
      unitHasIsiLive = noop,
      applyKnownKeyToRosterEntry = noop,
      enqueueInspect = noop,
      sendOwnKeySnapshot = noop,
      sendIsiLiveHello = noop,
      sendRefreshRequest = noop,
      getWasInGroup = noop,
      setWasInGroup = noop,
      getWasRaidGroup = noop,
      setWasRaidGroup = noop,
      setWasGroupLeader = noop,
      getRoster = noop,
      setRoster = noop,
      captureQueueJoinCandidate = noop,
      announceQueuedGroupJoin = noop,
      setMainFrameVisible = noop,
      updateLeaderButtons = noop,
      clearLatestQueueTarget = noop,
      resetInspectAll = noop,
      resetInspectQueues = noop,
      updateUI = noop,
      updateMPlusTeleportButton = noop,
    }

    local groupModule, getOpts = captureGroupModuleOpts()
    addon.ControllerWiring.CreateGroupControllerFromContext(groupModule, wireCtx)

    getOpts().clearKnownUsers()
    Assert.True(clearCalled, "CreateGroupControllerFromContext must wire sync.ClearKnownUsers through clearKnownUsers")
  end)

  test("ControllerWiring CreateGroupControllerFromContext forwards group-joined callback", function()
    local addon = LoadAddonModules({ "isiLive_controller_wiring.lua" })
    local callbackCalls = 0
    local syncStub = {
      ClearKnownUsers = noop,
      SetPlayerKeyInfo = noop,
    }

    local wireCtx = {
      sync = syncStub,
      printFn = noop,
      getL = noop,
      isInGroup = noop,
      getNumGroupMembers = noop,
      getActiveChallengeMapID = noop,
      getUnitNameAndRealm = noop,
      getUnitClass = noop,
      getUnitServerLanguage = noop,
      getOwnedKeystoneSnapshot = noop,
      markIsiLiveUser = noop,
      getUnitRole = noop,
      getPlayerSpecName = noop,
      getUnitRio = noop,
      unitIsGroupLeader = noop,
      unitHasIsiLive = noop,
      applyKnownKeyToRosterEntry = noop,
      enqueueInspect = noop,
      sendOwnKeySnapshot = noop,
      sendIsiLiveHello = noop,
      sendRefreshRequest = noop,
      getWasInGroup = noop,
      setWasInGroup = noop,
      getWasRaidGroup = noop,
      setWasRaidGroup = noop,
      setWasGroupLeader = noop,
      getRoster = noop,
      setRoster = noop,
      captureQueueJoinCandidate = noop,
      announceQueuedGroupJoin = noop,
      onGroupJoined = function()
        callbackCalls = callbackCalls + 1
      end,
      setMainFrameVisible = noop,
      updateLeaderButtons = noop,
      clearLatestQueueTarget = noop,
      resetInspectAll = noop,
      resetInspectQueues = noop,
      updateUI = noop,
      updateMPlusTeleportButton = noop,
    }

    local groupModule, getOpts = captureGroupModuleOpts()
    addon.ControllerWiring.CreateGroupControllerFromContext(groupModule, wireCtx)

    getOpts().onGroupJoined()
    Assert.Equal(callbackCalls, 1, "context group-join callback must survive ControllerWiring")
  end)
end
