---@diagnostic disable: undefined-global
local function BuildMockSync()
  local calls = {}
  local keyStore = {}
  local statsStore = {}
  local dpsStore = {}
  local locStore = {}
  local kickStore = {}
  local knownUsers = {}

  return {
    calls = calls,
    keyStore = keyStore,
    MarkUser = function(name, realm)
      table.insert(calls, { fn = "MarkUser", name = name, realm = realm })
      knownUsers[tostring(name) .. "-" .. tostring(realm)] = true
    end,
    IsUnitKnown = function(getUnitNameAndRealm, unit)
      local name, realm = getUnitNameAndRealm(unit)
      return knownUsers[tostring(name) .. "-" .. tostring(realm)] == true
    end,
    RegisterPrefix = function()
      table.insert(calls, { fn = "RegisterPrefix" })
    end,
    SendHello = function(opts)
      table.insert(calls, { fn = "SendHello", opts = opts })
    end,
    SendKey = function(opts)
      table.insert(calls, { fn = "SendKey", opts = opts })
    end,
    SendStats = function(opts)
      table.insert(calls, { fn = "SendStats", opts = opts })
    end,
    SendDps = function(opts)
      table.insert(calls, { fn = "SendDps", opts = opts })
    end,
    SendLoc = function(opts)
      table.insert(calls, { fn = "SendLoc", opts = opts })
    end,
    SendRefreshRequest = function(opts)
      table.insert(calls, { fn = "SendRefreshRequest", opts = opts })
    end,
    SendLibKeystoneRequest = function(opts)
      table.insert(calls, { fn = "SendLibKeystoneRequest", opts = opts })
    end,
    SendLibKeystonePartyData = function(opts)
      table.insert(calls, { fn = "SendLibKeystonePartyData", opts = opts })
      return true
    end,
    GetPlayerKeyInfo = function(name, realm)
      return keyStore[tostring(name) .. "-" .. tostring(realm)]
    end,
    GetPlayerStatsInfo = function(name, realm)
      return statsStore[tostring(name) .. "-" .. tostring(realm)]
    end,
    GetPlayerDpsInfo = function(name, realm)
      return dpsStore[tostring(name) .. "-" .. tostring(realm)]
    end,
    GetPlayerLocInfo = function(name, realm)
      return locStore[tostring(name) .. "-" .. tostring(realm)]
    end,
    GetPlayerKickInfo = function(name, realm)
      return kickStore[tostring(name) .. "-" .. tostring(realm)]
    end,
    SetPlayerKeyInfo = function(name, realm, mapID, level)
      keyStore[tostring(name) .. "-" .. tostring(realm)] = { mapID = mapID, level = level }
    end,
    SetPlayerStatsInfo = function(name, realm, specID, ilvl, rio)
      statsStore[tostring(name) .. "-" .. tostring(realm)] = { specID = specID, ilvl = ilvl, rio = rio }
    end,
    SetPlayerDpsInfo = function(name, realm, dps)
      local key = tostring(name) .. "-" .. tostring(realm)
      if dps == nil then
        dpsStore[key] = nil
        return
      end
      dpsStore[key] = { dps = dps }
    end,
    SetPlayerLocInfo = function(name, realm, mapID)
      locStore[tostring(name) .. "-" .. tostring(realm)] = { mapID = mapID }
    end,
    SetPlayerKickInfo = function(name, realm, onCooldown, cooldownRemain, _capturedAt, hasKick)
      kickStore[tostring(name) .. "-" .. tostring(realm)] = {
        hasKick = hasKick ~= false,
        onCooldown = onCooldown == true,
        cooldownRemain = tonumber(cooldownRemain) or 0,
      }
    end,
    ClearKnownUsers = function()
      table.insert(calls, { fn = "ClearKnownUsers" })
      for k in pairs(knownUsers) do
        knownUsers[k] = nil
      end
      for k in pairs(keyStore) do
        keyStore[k] = nil
      end
      for k in pairs(statsStore) do
        statsStore[k] = nil
      end
      for k in pairs(dpsStore) do
        dpsStore[k] = nil
      end
      for k in pairs(locStore) do
        locStore[k] = nil
      end
      for k in pairs(kickStore) do
        kickStore[k] = nil
      end
    end,
    GetProtocolVersion = function()
      return 2
    end,
  }
end

local function BuildController(loadAddonModules, sync, overrides)
  overrides = overrides or {}
  local addon = loadAddonModules({ "isiLive_keysync.lua" })
  return addon.KeySync.CreateController({
    sync = sync,
    getUnitNameAndRealm = overrides.getUnitNameAndRealm or function(unit)
      if unit == "player" then
        return "TestPlayer", "TestRealm"
      end
      return nil, nil
    end,
    getAddonVersionRaw = overrides.getAddonVersionRaw or function()
      return "0.9.99"
    end,
    getUnitRio = overrides.getUnitRio or function(_unit)
      return nil
    end,
    isFrameVisible = overrides.isFrameVisible or function()
      return true
    end,
    canRespondToRefreshRequest = overrides.canRespondToRefreshRequest or function()
      return true
    end,
    getPlayerLastRunDps = overrides.getPlayerLastRunDps or nil,
  })
end

local function RegisterKeySyncPresenceTests(test, Assert, LoadAddonModules)
  test("KeySync MarkIsiLiveUser delegates to sync.MarkUser", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    ctrl.MarkIsiLiveUser("PlayerA", "RealmA")
    Assert.Equal(#sync.calls, 1, "must call sync exactly once")
    Assert.Equal(sync.calls[1].fn, "MarkUser", "must call MarkUser")
    Assert.Equal(sync.calls[1].name, "PlayerA", "must pass name")
    Assert.Equal(sync.calls[1].realm, "RealmA", "must pass realm")
  end)

  test("KeySync UnitHasIsiLive returns true for marked units", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync, {
      getUnitNameAndRealm = function(unit)
        if unit == "player" then
          return "Me", "MyRealm"
        end
        if unit == "party1" then
          return "Friend", "FriendRealm"
        end
        return nil, nil
      end,
    })
    ctrl.MarkIsiLiveUser("Friend", "FriendRealm")
    Assert.True(ctrl.UnitHasIsiLive("party1"), "marked unit must be recognized")
    Assert.True(not ctrl.UnitHasIsiLive("party2"), "unknown unit must not be recognized")
  end)

  test("KeySync RegisterIsiLiveSyncPrefix delegates to sync.RegisterPrefix", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    ctrl.RegisterIsiLiveSyncPrefix()
    local found = false
    for _, c in ipairs(sync.calls) do
      if c.fn == "RegisterPrefix" then
        found = true
      end
    end
    Assert.True(found, "must call RegisterPrefix")
  end)

  test("KeySync ResolveActiveKeyOwnerUnit returns unique key owner", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    local roster = {
      player = { name = "Me", realm = "R", keyMapID = 100, keyLevel = 10 },
      party1 = { name = "P1", realm = "R", keyMapID = 200, keyLevel = 12 },
      party2 = { name = "P2", realm = "R", keyMapID = 300, keyLevel = 8 },
    }
    Assert.Equal(ctrl.ResolveActiveKeyOwnerUnit(roster, 200), "party1", "must return unique owner unit")
  end)

  test("KeySync ResolveActiveKeyOwnerUnit returns nil for duplicate mapID", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    local roster = {
      player = { name = "Me", realm = "R", keyMapID = 200, keyLevel = 10 },
      party1 = { name = "P1", realm = "R", keyMapID = 200, keyLevel = 12 },
    }
    Assert.Equal(ctrl.ResolveActiveKeyOwnerUnit(roster, 200), nil, "must return nil when multiple matches")
  end)

  test("KeySync ResolveActiveKeyOwnerUnit returns nil for unknown mapID", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    local roster = {
      player = { name = "Me", realm = "R", keyMapID = 100, keyLevel = 10 },
    }
    Assert.Equal(ctrl.ResolveActiveKeyOwnerUnit(roster, 999), nil, "must return nil for unmatched mapID")
  end)

  test("KeySync ResolveActiveKeyOwnerUnit returns nil for nil activeJoinedKeyMapID", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    Assert.Equal(ctrl.ResolveActiveKeyOwnerUnit({}, nil), nil, "nil mapID must return nil")
  end)
end

local function RegisterKeySyncOwnedKeyTests(test, Assert, WithGlobals, LoadAddonModules)
  test("KeySync RefreshLocalPlayerKey updates player key from C_MythicPlus", function()
    WithGlobals({
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return 14
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 250
        end,
      },
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local roster = {
        player = { name = "TestPlayer", realm = "TestRealm", keyMapID = nil, keyLevel = nil },
      }
      local changed = ctrl.RefreshLocalPlayerKey(roster)
      Assert.True(changed, "must return true when key changed")
      Assert.Equal(roster.player.keyMapID, 250, "roster must have updated mapID")
      Assert.Equal(roster.player.keyLevel, 14, "roster must have updated level")
    end)
  end)

  test("KeySync RefreshLocalPlayerKey returns false when key unchanged", function()
    WithGlobals({
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return 14
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 250
        end,
      },
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local roster = {
        player = { name = "TestPlayer", realm = "TestRealm", keyMapID = 250, keyLevel = 14 },
      }
      local changed = ctrl.RefreshLocalPlayerKey(roster)
      Assert.True(not changed, "must return false when key is same")
    end)
  end)

  test("KeySync ForceRefreshSyncState clears non-player data and restores own key", function()
    WithGlobals({
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return 10
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 400
        end,
      },
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local roster = {
        player = { name = "TestPlayer", realm = "TestRealm", keyMapID = 100, keyLevel = 5, hasIsiLive = true },
        party1 = {
          name = "Other",
          realm = "OtherRealm",
          keyMapID = 200,
          keyLevel = 8,
          hasIsiLive = true,
          syncDps = 50000,
          syncLocMapID = 300,
        },
      }
      ctrl.ForceRefreshSyncState(roster)
      Assert.True(roster.player.hasIsiLive, "player must keep hasIsiLive")
      Assert.Equal(roster.player.keyMapID, 400, "player key must be refreshed")
      Assert.Equal(roster.player.keyLevel, 10, "player level must be refreshed")
      Assert.True(not roster.party1.hasIsiLive, "party member must lose hasIsiLive")
      Assert.Equal(roster.party1.keyMapID, nil, "party member key must be cleared")
      Assert.Equal(roster.party1.syncDps, nil, "party member syncDps must be cleared")
      Assert.Equal(roster.party1.syncLocMapID, nil, "party member syncLocMapID must be cleared")
    end)
  end)

  test("KeySync GetOwnedKeystoneSnapshot returns nil when C_MythicPlus is absent", function()
    WithGlobals({
      C_MythicPlus = nil,
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, nil, "mapID must be nil without API")
      Assert.Equal(level, nil, "level must be nil without API")
    end)
  end)

  test("KeySync GetOwnedKeystoneSnapshot returns values from C_MythicPlus", function()
    WithGlobals({
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return 15
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 375
        end,
      },
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, 375, "must return mapID from API")
      Assert.Equal(level, 15, "must return level from API")
    end)
  end)

  test("KeySync SendRefreshRequest delegates to sync and LibKeystone request", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    ctrl.SendRefreshRequest(true)
    local refreshFound = false
    local libKeystoneFound = false
    for _, c in ipairs(sync.calls) do
      if c.fn == "SendRefreshRequest" then
        refreshFound = true
        Assert.True(c.opts.force, "must pass force flag")
      elseif c.fn == "SendLibKeystoneRequest" then
        libKeystoneFound = true
        Assert.True(c.opts.force, "LibKeystone request must receive the same force flag")
      end
    end
    Assert.True(refreshFound, "must call SendRefreshRequest")
    Assert.True(libKeystoneFound, "must also request LibKeystone party data")
  end)

  test("KeySync SendLibKeystonePartyData delegates current key and rio to sync", function()
    local sync = BuildMockSync()
    WithGlobals({
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return 17
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 505
        end,
      },
    }, function()
      local ctrl = BuildController(LoadAddonModules, sync, {
        getUnitRio = function(unit)
          if unit == "player" then
            return 3333
          end
          return nil
        end,
      })

      local sent = ctrl.SendLibKeystonePartyData(true)

      Assert.True(sent, "LibKeystone party send should report success from sync")
      local found = false
      for _, c in ipairs(sync.calls) do
        if c.fn == "SendLibKeystonePartyData" then
          found = true
          Assert.True(c.opts.force, "LibKeystone party data must pass through the force flag")
          Assert.Equal(c.opts.mapID, 505, "LibKeystone party data must use the current key map")
          Assert.Equal(c.opts.level, 17, "LibKeystone party data must use the current key level")
          Assert.Equal(c.opts.rio, 3333, "LibKeystone party data must include the current rio")
        end
      end
      Assert.True(found, "must call SendLibKeystonePartyData")
    end)
  end)
end

local function RegisterKeySyncApplyKnownKeyTests(test, Assert, WithGlobals, LoadAddonModules)
  test("KeySync ApplyKnownKeyToRosterEntry applies key and stats from sync", function()
    local sync = BuildMockSync()
    WithGlobals({
      GetSpecializationInfoByID = function(specID)
        if specID == 265 then
          return 265, "Affliction"
        end
        return nil, nil
      end,
    }, function()
      local ctrl = BuildController(LoadAddonModules, sync)
      sync.SetPlayerKeyInfo("PlayerX", "RealmX", 300, 12)
      sync.SetPlayerStatsInfo("PlayerX", "RealmX", 265, 630, 3400)
      sync.SetPlayerDpsInfo("PlayerX", "RealmX", 45000)
      sync.SetPlayerLocInfo("PlayerX", "RealmX", 300)
      sync.SetPlayerKickInfo("PlayerX", "RealmX", true, 9, nil, true)

      local info = { name = "PlayerX", realm = "RealmX" }
      local changed = ctrl.ApplyKnownKeyToRosterEntry(info)
      Assert.True(changed, "must return true when data changed")
      Assert.Equal(info.keyMapID, 300, "keyMapID must be applied")
      Assert.Equal(info.keyLevel, 12, "keyLevel must be applied")
      Assert.Equal(info.spec, "Affliction", "spec must be resolved from specID")
      Assert.Equal(info.ilvl, 630, "ilvl must be applied")
      Assert.Equal(info.rio, 3400, "rio must be applied")
      Assert.Equal(info.syncDps, 45000, "syncDps must be applied")
      Assert.Equal(info.syncLocMapID, 300, "syncLocMapID must be applied")
      Assert.True(info.syncHasKick, "sync kick availability must be applied")
      Assert.True(info.syncKickOnCooldown, "sync kick cooldown state must be applied")
      Assert.Equal(info.syncKickRemain, 9, "sync kick remaining cooldown must be applied")
    end)
  end)

  test("KeySync ApplyKnownKeyToRosterEntry skips when _localSpecFresh is set", function()
    local sync = BuildMockSync()
    WithGlobals({
      GetSpecializationInfoByID = function()
        return nil, "ShouldNotBeUsed"
      end,
    }, function()
      local ctrl = BuildController(LoadAddonModules, sync)
      sync.SetPlayerStatsInfo("P", "R", 265, 640, 3500)
      local info = { name = "P", realm = "R", spec = "Original", ilvl = 620, rio = 3000, _localSpecFresh = true }
      ctrl.ApplyKnownKeyToRosterEntry(info)
      Assert.Equal(info.spec, "Original", "spec must not be overwritten when _localSpecFresh")
      Assert.Equal(info.ilvl, 640, "ilvl should still update (not _localIlvlFresh)")
    end)
  end)

  test("KeySync ApplyKnownKeyToRosterEntry returns false for nil info", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    Assert.Equal(ctrl.ApplyKnownKeyToRosterEntry(nil), false, "nil info must return false")
  end)

  test(
    "KeySync ApplyKnownKeyToRosterEntry clears stale synced DPS fallback fields when sync data disappears",
    function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local info = {
        name = "PlayerX",
        realm = "RealmX",
        syncDps = 45000,
      }

      sync.SetPlayerDpsInfo("PlayerX", "RealmX", 45000)
      ctrl.ApplyKnownKeyToRosterEntry(info)

      sync.SetPlayerDpsInfo("PlayerX", "RealmX", nil)
      local changed = ctrl.ApplyKnownKeyToRosterEntry(info)

      Assert.True(changed, "clearing synced DPS data must report a roster change")
      Assert.Nil(info.syncDps, "stale syncDps must be cleared when sync data disappears")
    end
  )

  test("KeySync ApplyKnownKeyToRosterEntry preserves synced no-interrupt state", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    local info = {
      name = "PlayerX",
      realm = "RealmX",
      syncHasKick = true,
      syncKickOnCooldown = true,
      syncKickRemain = 4,
    }

    sync.SetPlayerKickInfo("PlayerX", "RealmX", false, 0, nil, false)
    local changed = ctrl.ApplyKnownKeyToRosterEntry(info)

    Assert.True(changed, "switching to no-interrupt sync state must report a roster change")
    Assert.False(info.syncHasKick, "no-interrupt sync state must be preserved on the roster entry")
    Assert.Nil(info.syncKickOnCooldown, "no-interrupt sync state must clear cooldown marker")
    Assert.Nil(info.syncKickRemain, "no-interrupt sync state must clear cooldown remaining seconds")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterKeySyncPresenceTests(test, Assert, LoadAddonModules)
  RegisterKeySyncOwnedKeyTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterKeySyncApplyKnownKeyTests(test, Assert, WithGlobals, LoadAddonModules)
end
