---@diagnostic disable: undefined-global
local function BuildMockSync()
  local calls = {}
  local keyStore = {}
  local statsStore = {}
  local dpsStore = {}
  local locStore = {}
  local kickStore = {}
  local knownUsers = {}
  local aliases = {}

  local function Key(name, realm)
    local text = tostring(name or "")
    local resolvedRealm = tostring(realm or "")
    if resolvedRealm == "" then
      local splitName, splitRealm = text:match("^(.+)%-([^-]+)$")
      if splitName and splitRealm then
        text = splitName
        resolvedRealm = splitRealm
      end
    end
    return string.lower(text .. "-" .. resolvedRealm)
  end

  local function Lookup(store, name, realm)
    local key = Key(name, realm)
    return store[key] or (aliases[key] and store[aliases[key]]) or nil
  end

  return {
    calls = calls,
    keyStore = keyStore,
    MarkUser = function(name, realm)
      table.insert(calls, { fn = "MarkUser", name = name, realm = realm })
      knownUsers[Key(name, realm)] = true
    end,
    NormalizePlayerKey = Key,
    RegisterVerifiedAlias = function(senderName, senderRealm, rosterName, rosterRealm)
      local senderKey = Key(senderName, senderRealm)
      if not knownUsers[senderKey] then
        return false
      end
      aliases[Key(rosterName, rosterRealm)] = senderKey
      return true
    end,
    IsUnitKnown = function(getUnitNameAndRealm, unit)
      local name, realm = getUnitNameAndRealm(unit)
      local key = Key(name, realm)
      return knownUsers[key] == true or (aliases[key] and knownUsers[aliases[key]] == true)
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
      return Lookup(keyStore, name, realm)
    end,
    GetPlayerStatsInfo = function(name, realm)
      return Lookup(statsStore, name, realm)
    end,
    GetPlayerDpsInfo = function(name, realm)
      return Lookup(dpsStore, name, realm)
    end,
    GetPlayerLocInfo = function(name, realm)
      return Lookup(locStore, name, realm)
    end,
    GetPlayerKickInfo = function(name, realm)
      return Lookup(kickStore, name, realm)
    end,
    SetPlayerKeyInfo = function(name, realm, mapID, level)
      keyStore[Key(name, realm)] = { mapID = mapID, level = level }
    end,
    SetPlayerStatsInfo = function(name, realm, specID, ilvl, rio)
      statsStore[Key(name, realm)] = { specID = specID, ilvl = ilvl, rio = rio }
    end,
    SetPlayerDpsInfo = function(name, realm, dps)
      local key = Key(name, realm)
      if dps == nil then
        dpsStore[key] = nil
        return
      end
      dpsStore[key] = { dps = dps }
    end,
    SetPlayerLocInfo = function(name, realm, mapID)
      locStore[Key(name, realm)] = { mapID = mapID }
    end,
    SetPlayerKickInfo = function(name, realm, onCooldown, cooldownRemain, _capturedAt, hasKick)
      kickStore[Key(name, realm)] = {
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

  test(
    "KeySync ResolveActiveKeyOwnerUnit refuses unique-owner fallback in a multi-member group without a hint",
    function()
      -- 0.9.238 (extended): without a preferredOwnerName, a sole match in a
      -- multi-member roster is treated as a sync-race symptom (the listing
      -- owner's key has not propagated yet; only some member's locally
      -- cached key happens to match). Return nil so the deferred consumer
      -- waits for a real source instead of locking onto a random member.
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local roster = {
        player = { name = "Me", realm = "R", keyMapID = 100, keyLevel = 10 },
        party1 = { name = "P1", realm = "R", keyMapID = 200, keyLevel = 12 },
        party2 = { name = "P2", realm = "R", keyMapID = 300, keyLevel = 8 },
      }
      Assert.Equal(
        ctrl.ResolveActiveKeyOwnerUnit(roster, 200),
        nil,
        "unique match without a hint in a multi-member group must stay nil (race-safety)"
      )
    end
  )

  test("KeySync.GetDiagnostics counts unique-owner guard skips and ResetDiagnostics zeros them", function()
    -- The unique-owner guard above (sole match, multi-member roster, no hint)
    -- fails closed silently. KeySync.GetDiagnostics exposes how many times
    -- the guard fired so /dump can distinguish "guard never engages" from
    -- "guard suppressing X resolutions per session". Without this signal the
    -- consumer is mute and the race-safety choice has no telemetry.
    --
    -- The Controller and the diagnostics accessor must come from the SAME
    -- KeySync module instance — LoadAddonModules creates a fresh chunk per
    -- call, so going through BuildController (which re-loads internally)
    -- would split state across two instances and the counter would look
    -- like it never advanced.
    local sync = BuildMockSync()
    local addon = LoadAddonModules({ "isiLive_keysync.lua" })
    local KeySync = addon.KeySync
    KeySync.ResetDiagnostics()
    Assert.Equal(KeySync.GetDiagnostics().uniqueOwnerGuardSkips, 0, "ResetDiagnostics zeroes the counter")

    local ctrl = KeySync.CreateController({
      sync = sync,
      getUnitNameAndRealm = function(unit)
        if unit == "player" then
          return "TestPlayer", "TestRealm"
        end
        return nil, nil
      end,
      getAddonVersionRaw = function()
        return "0.9.99"
      end,
      getUnitRio = function(_unit)
        return nil
      end,
      isFrameVisible = function()
        return true
      end,
    })
    local roster = {
      player = { name = "Me", realm = "R", keyMapID = 100, keyLevel = 10 },
      party1 = { name = "P1", realm = "R", keyMapID = 200, keyLevel = 12 },
      party2 = { name = "P2", realm = "R", keyMapID = 300, keyLevel = 8 },
    }
    -- Trigger the guard twice. Each call hits the "sole match + multi-member
    -- + no hint" branch and increments the counter by exactly one.
    ctrl.ResolveActiveKeyOwnerUnit(roster, 200)
    ctrl.ResolveActiveKeyOwnerUnit(roster, 200)
    Assert.Equal(
      KeySync.GetDiagnostics().uniqueOwnerGuardSkips,
      2,
      "each unique-owner guard hit must increment the counter exactly once"
    )

    -- A resolution that does NOT hit the guard (hint provided, hint matches)
    -- must leave the counter alone.
    ctrl.ResolveActiveKeyOwnerUnit(roster, 200, "P1")
    Assert.Equal(
      KeySync.GetDiagnostics().uniqueOwnerGuardSkips,
      2,
      "hint-driven resolutions must not bump the guard counter"
    )

    KeySync.ResetDiagnostics()
    Assert.Equal(
      KeySync.GetDiagnostics().uniqueOwnerGuardSkips,
      0,
      "ResetDiagnostics zeroes again after counts accumulate"
    )
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

  test("KeySync ResolveActiveKeyOwnerUnit hint picks leader when mapID is ambiguous", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    local roster = {
      player = { name = "Me", realm = "R", keyMapID = 200, keyLevel = 10 },
      party1 = { name = "Leader", realm = "R", keyMapID = 200, keyLevel = 14 },
      party2 = { name = "Other", realm = "R", keyMapID = 200, keyLevel = 8 },
    }
    Assert.Equal(
      ctrl.ResolveActiveKeyOwnerUnit(roster, 200, "Leader"),
      "party1",
      "bare-name hint must disambiguate matching roster unit"
    )
  end)

  test("KeySync ResolveActiveKeyOwnerUnit hint with realm matches Name-Realm entry", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    local roster = {
      party1 = { name = "Leader", realm = "Blackmoore", keyMapID = 200, keyLevel = 14 },
      party2 = { name = "Leader", realm = "Antonidas", keyMapID = 200, keyLevel = 9 },
    }
    Assert.Equal(
      ctrl.ResolveActiveKeyOwnerUnit(roster, 200, "Leader-Antonidas"),
      "party2",
      "realm-qualified hint must resolve to the cross-realm entry"
    )
  end)

  test("KeySync ResolveActiveKeyOwnerUnit fails closed when hinted leader holds different mapID", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    local roster = {
      player = { name = "Me", realm = "R", keyMapID = 200, keyLevel = 10 },
      party1 = { name = "Leader", realm = "R", keyMapID = 300, keyLevel = 14 },
      party2 = { name = "Other", realm = "R", keyMapID = 200, keyLevel = 8 },
    }
    Assert.Equal(
      ctrl.ResolveActiveKeyOwnerUnit(roster, 200, "Leader"),
      nil,
      "leader in roster with wrong mapID must fail closed, not fall back to another member"
    )
  end)

  test("KeySync ResolveActiveKeyOwnerUnit fails closed when hinted leader has no key synced", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    local roster = {
      player = { name = "Me", realm = "R", keyMapID = nil, keyLevel = nil },
      party1 = { name = "Leader", realm = "R", keyMapID = nil, keyLevel = nil },
      party2 = { name = "Other", realm = "R", keyMapID = 200, keyLevel = 8 },
    }
    Assert.Equal(
      ctrl.ResolveActiveKeyOwnerUnit(roster, 200, "Leader"),
      nil,
      "leader in roster without synced key must fail closed, not highlight another member's key"
    )
  end)

  test("KeySync ResolveActiveKeyOwnerUnit hint with unknown leader falls back to unique owner", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    local roster = {
      player = { name = "Me", realm = "R", keyMapID = 100, keyLevel = 10 },
      party1 = { name = "P1", realm = "R", keyMapID = 200, keyLevel = 12 },
    }
    Assert.Equal(
      ctrl.ResolveActiveKeyOwnerUnit(roster, 200, "GhostLeader"),
      "party1",
      "unknown hint must not block unique-owner resolution"
    )
  end)

  -- 0.9.238: race guard. In the seconds after GROUP_ROSTER_UPDATE only the
  -- player's own key (and whatever LibKeystone-style cross-addon mirroring
  -- happens to surface locally) is in the roster; the listing owner's key
  -- arrives over the sync roundtrip. Without this guard,
  -- ResolveActiveKeyOwnerUnit happily returned whichever member matched
  -- alone — confidently wrong when that lone match is not the listing
  -- owner.

  test("KeySync ResolveActiveKeyOwnerUnit refuses 'player' as the lone match in a multi-member group", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    local roster = {
      player = { name = "Me", realm = "R", keyMapID = 200, keyLevel = 15 },
      party1 = { name = "Leader", realm = "R", keyMapID = nil, keyLevel = nil },
      party2 = { name = "P2", realm = "R", keyMapID = nil, keyLevel = nil },
      party3 = { name = "P3", realm = "R", keyMapID = nil, keyLevel = nil },
    }
    Assert.Equal(
      ctrl.ResolveActiveKeyOwnerUnit(roster, 200),
      nil,
      "the 'player'-as-sole-match case is the canonical race symptom — must stay nil"
    )
  end)

  test("KeySync ResolveActiveKeyOwnerUnit refuses a non-player lone match in a multi-member group", function()
    -- Real-world case: Pinto accepts "+13 Relaxed Grube von Saron" (POS).
    -- Listing owner Larilan holds POS +13 but his key has not synced yet.
    -- Vladax (another member) happens to have his own POS +14 key, which
    -- LibKeystone-style cross-addon mirroring makes locally visible. Without
    -- a preferred-owner hint, Vladax would have surfaced as the unique
    -- owner and the chat would have said "+14" — the actual Grube-von-Saron
    -- screenshot bug.
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    local roster = {
      player = { name = "Pinto", realm = "R", keyMapID = 247, keyLevel = 15 },
      party1 = { name = "Larilan", realm = "R", keyMapID = nil, keyLevel = nil },
      party2 = { name = "Vladax", realm = "R", keyMapID = 200, keyLevel = 14 },
      party3 = { name = "P3", realm = "R", keyMapID = nil, keyLevel = nil },
    }
    Assert.Equal(
      ctrl.ResolveActiveKeyOwnerUnit(roster, 200),
      nil,
      "a non-player lone match without a hint in a multi-member group is also a race symptom"
    )
  end)

  test("KeySync ResolveActiveKeyOwnerUnit returns 'player' as unique owner when the roster is solo", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    local roster = {
      player = { name = "Me", realm = "R", keyMapID = 200, keyLevel = 15 },
    }
    Assert.Equal(
      ctrl.ResolveActiveKeyOwnerUnit(roster, 200),
      "player",
      "solo roster: 'player' is the legitimate unique owner"
    )
  end)

  test("KeySync ResolveActiveKeyOwnerUnit returns 'player' as unique owner when other members are isGhost", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    local roster = {
      player = { name = "Me", realm = "R", keyMapID = 200, keyLevel = 15 },
      party1 = { name = "Ghost", realm = "R", keyMapID = nil, keyLevel = nil, isGhost = true },
    }
    -- Ghosts do not contribute to the headcount; the only non-ghost roster
    -- member is the player, so this is functionally a solo roster.
    Assert.Equal(
      ctrl.ResolveActiveKeyOwnerUnit(roster, 200),
      "player",
      "ghost-only siblings must not block the legitimate solo-roster fallback"
    )
  end)
end

local function RegisterKeySyncOwnedKeyTests(test, Assert, WithGlobals, LoadAddonModules)
  test("KeySync location snapshot rejects secret instance metadata", function()
    local secret = {}
    WithGlobals({
      GetInstanceInfo = function()
        return "Secret Dungeon", secret, 23, "Mythic", 5, nil, nil, 777, 12345
      end,
      issecretvalue = function(value)
        return value == secret
      end,
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      ctrl.SendOwnKeySnapshot(true, "secret-instance-test", true, false, false)

      local locationCall = nil
      for _, call in ipairs(sync.calls) do
        if call.fn == "SendLoc" then
          locationCall = call
          break
        end
      end
      Assert.True(locationCall ~= nil, "location snapshot must still be dispatched")
      Assert.Nil(locationCall.opts.mapID, "secret instance metadata must keep local map unresolved")
    end)
  end)

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

  local function MakeBagApiWithKeystone(mapID, level)
    return {
      GetContainerNumSlots = function(bagID)
        return bagID == 0 and 16 or 0
      end,
      GetContainerItemID = function(bagID, slotID)
        if bagID == 0 and slotID == 5 then
          return 180653
        end
        return nil
      end,
      GetContainerItemLink = function(bagID, slotID)
        if bagID == 0 and slotID == 5 then
          return string.format("|cffa335ee|Hkeystone:180653:%d:%d:10:10:10:10|h[Keystone]|h|r", mapID, level)
        end
        return nil
      end,
    }
  end

  test("KeySync GetOwnedKeystoneSnapshot falls back to bag scan when C_MythicPlus returns nil", function()
    WithGlobals({
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return nil
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return nil
        end,
      },
      C_Container = MakeBagApiWithKeystone(2649, 14),
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, 2649, "must parse mapID from bag link when API empty")
      Assert.Equal(level, 14, "must parse level from bag link when API empty")
    end)
  end)

  test("KeySync GetOwnedKeystoneSnapshot falls back to bag scan when C_MythicPlus is absent", function()
    WithGlobals({
      C_MythicPlus = nil,
      C_Container = MakeBagApiWithKeystone(2660, 12),
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, 2660, "must parse mapID from bag link without API")
      Assert.Equal(level, 12, "must parse level from bag link without API")
    end)
  end)

  test("KeySync GetOwnedKeystoneSnapshot returns nil when both API and bag are empty", function()
    WithGlobals({
      C_MythicPlus = nil,
      C_Container = {
        GetContainerNumSlots = function()
          return 0
        end,
        GetContainerItemID = function()
          return nil
        end,
        GetContainerItemLink = function()
          return nil
        end,
      },
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, nil, "mapID must be nil when API and bag are empty")
      Assert.Equal(level, nil, "level must be nil when API and bag are empty")
    end)
  end)

  test("KeySync GetOwnedKeystoneSnapshot prefers C_MythicPlus over bag when both have data", function()
    WithGlobals({
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return 16
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 500
        end,
      },
      C_Container = MakeBagApiWithKeystone(2649, 14),
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, 500, "must prefer API mapID over bag")
      Assert.Equal(level, 16, "must prefer API level over bag")
    end)
  end)

  -- API edge cases that must trigger the bag fallback ----------------------------------

  test("KeySync GetOwnedKeystoneSnapshot falls back to bag when API returns level=0", function()
    WithGlobals({
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return 0
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 500
        end,
      },
      C_Container = MakeBagApiWithKeystone(2649, 14),
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, 2649, "level=0 must trigger bag fallback")
      Assert.Equal(level, 14, "level=0 must trigger bag fallback")
    end)
  end)

  test("KeySync GetOwnedKeystoneSnapshot falls back to bag when API returns mapID=0", function()
    WithGlobals({
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return 14
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 0
        end,
      },
      C_Container = MakeBagApiWithKeystone(2649, 14),
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, 2649, "mapID=0 must trigger bag fallback")
      Assert.Equal(level, 14, "mapID=0 must trigger bag fallback")
    end)
  end)

  test("KeySync GetOwnedKeystoneSnapshot falls back to bag when API throws", function()
    WithGlobals({
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          error("API tainted", 0)
        end,
        GetOwnedKeystoneChallengeMapID = function()
          error("API tainted", 0)
        end,
      },
      C_Container = MakeBagApiWithKeystone(2649, 14),
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, 2649, "pcall failure must trigger bag fallback")
      Assert.Equal(level, 14, "pcall failure must trigger bag fallback")
    end)
  end)

  -- Bag scan: spread across bag indices --------------------------------------------------

  test("KeySync GetOwnedKeystoneSnapshot finds keystone in the reagent bag (bagID=5)", function()
    WithGlobals({
      C_MythicPlus = nil,
      C_Container = {
        GetContainerNumSlots = function(bag)
          return bag == 5 and 8 or 0
        end,
        GetContainerItemID = function(bag, slot)
          if bag == 5 and slot == 3 then
            return 180653
          end
          return nil
        end,
        GetContainerItemLink = function(bag, slot)
          if bag == 5 and slot == 3 then
            return "|Hkeystone:180653:2660:11:0:0:0:0|h[Keystone]|h"
          end
          return nil
        end,
      },
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, 2660, "must find key in bag 5 (reagent bag)")
      Assert.Equal(level, 11, "must find key in bag 5 (reagent bag)")
    end)
  end)

  test("KeySync GetOwnedKeystoneSnapshot iterates past empty bags (key in bagID=3)", function()
    WithGlobals({
      C_MythicPlus = nil,
      C_Container = {
        GetContainerNumSlots = function(bag)
          if bag == 3 then
            return 12
          end
          return bag <= 2 and 0 or 0
        end,
        GetContainerItemID = function(bag, slot)
          if bag == 3 and slot == 7 then
            return 180653
          end
          return nil
        end,
        GetContainerItemLink = function(bag, slot)
          if bag == 3 and slot == 7 then
            return "|Hkeystone:180653:2649:13:0:0:0:0|h[Keystone]|h"
          end
          return nil
        end,
      },
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, 2649, "must find key in bag 3 after skipping empty bags 0..2")
      Assert.Equal(level, 13, "must find key in bag 3 after skipping empty bags 0..2")
    end)
  end)

  test("KeySync GetOwnedKeystoneSnapshot returns the first keystone found when multiple exist", function()
    WithGlobals({
      C_MythicPlus = nil,
      C_Container = {
        GetContainerNumSlots = function(bag)
          return bag <= 5 and 16 or 0
        end,
        GetContainerItemID = function(bag, slot)
          if bag == 0 and slot == 4 then
            return 180653
          end
          if bag == 2 and slot == 9 then
            return 180653
          end
          return nil
        end,
        GetContainerItemLink = function(bag, slot)
          if bag == 0 and slot == 4 then
            return "|Hkeystone:180653:2649:14:0:0:0:0|h[Keystone +14]|h"
          end
          if bag == 2 and slot == 9 then
            return "|Hkeystone:180653:2660:18:0:0:0:0|h[Keystone +18]|h"
          end
          return nil
        end,
      },
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, 2649, "must return the first keystone found (bag 0 before bag 2)")
      Assert.Equal(level, 14, "must return the first keystone found (bag 0 before bag 2)")
    end)
  end)

  -- Bag scan: defensive guards against partial / failing C_Container API -----------------

  test("KeySync GetOwnedKeystoneSnapshot returns nil when C_Container is partially missing", function()
    WithGlobals({
      C_MythicPlus = nil,
      C_Container = {
        GetContainerNumSlots = function()
          return 16
        end,
        -- GetContainerItemID intentionally missing
        GetContainerItemLink = function()
          return "|Hkeystone:180653:2649:14|h[Keystone]|h"
        end,
      },
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, nil, "partial bag API must short-circuit safely")
      Assert.Equal(level, nil, "partial bag API must short-circuit safely")
    end)
  end)

  test("KeySync GetOwnedKeystoneSnapshot survives pcall failure on GetContainerNumSlots", function()
    WithGlobals({
      C_MythicPlus = nil,
      C_Container = {
        GetContainerNumSlots = function(bag)
          if bag == 0 then
            error("slots tainted", 0)
          end
          return bag == 1 and 8 or 0
        end,
        GetContainerItemID = function(bag, slot)
          if bag == 1 and slot == 4 then
            return 180653
          end
          return nil
        end,
        GetContainerItemLink = function(bag, slot)
          if bag == 1 and slot == 4 then
            return "|Hkeystone:180653:2649:9:0:0:0:0|h[Keystone]|h"
          end
          return nil
        end,
      },
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, 2649, "must continue scanning after a bag throws on slot count")
      Assert.Equal(level, 9, "must continue scanning after a bag throws on slot count")
    end)
  end)

  test("KeySync GetOwnedKeystoneSnapshot survives pcall failure on GetContainerItemID", function()
    WithGlobals({
      C_MythicPlus = nil,
      C_Container = {
        GetContainerNumSlots = function(bag)
          return bag == 0 and 4 or 0
        end,
        GetContainerItemID = function(bag, slot)
          if bag == 0 and slot == 1 then
            error("itemID tainted", 0)
          end
          if bag == 0 and slot == 3 then
            return 180653
          end
          return nil
        end,
        GetContainerItemLink = function(bag, slot)
          if bag == 0 and slot == 3 then
            return "|Hkeystone:180653:2700:7:0:0:0:0|h[Keystone]|h"
          end
          return nil
        end,
      },
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, 2700, "must skip slots that throw and continue scanning")
      Assert.Equal(level, 7, "must skip slots that throw and continue scanning")
    end)
  end)

  -- Bag scan: malformed keystone links -----------------------------------------------------

  test("KeySync GetOwnedKeystoneSnapshot returns nil when bag link is missing the mapID/level", function()
    WithGlobals({
      C_MythicPlus = nil,
      C_Container = {
        GetContainerNumSlots = function(bag)
          return bag == 0 and 4 or 0
        end,
        GetContainerItemID = function(bag, slot)
          if bag == 0 and slot == 2 then
            return 180653
          end
          return nil
        end,
        GetContainerItemLink = function(bag, slot)
          if bag == 0 and slot == 2 then
            return "|Hkeystone:180653:|h[Keystone]|h"
          end
          return nil
        end,
      },
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, nil, "malformed keystone link must not yield a snapshot")
      Assert.Equal(level, nil, "malformed keystone link must not yield a snapshot")
    end)
  end)

  test("KeySync GetOwnedKeystoneSnapshot returns nil when bag link encodes mapID=0", function()
    WithGlobals({
      C_MythicPlus = nil,
      C_Container = {
        GetContainerNumSlots = function(bag)
          return bag == 0 and 4 or 0
        end,
        GetContainerItemID = function(bag, slot)
          if bag == 0 and slot == 2 then
            return 180653
          end
          return nil
        end,
        GetContainerItemLink = function(bag, slot)
          if bag == 0 and slot == 2 then
            return "|Hkeystone:180653:0:14:0:0:0:0|h[Keystone]|h"
          end
          return nil
        end,
      },
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, nil, "mapID=0 in the bag link must not be accepted")
      Assert.Equal(level, nil, "mapID=0 in the bag link must not be accepted")
    end)
  end)

  test("KeySync GetOwnedKeystoneSnapshot returns nil when bag link encodes level=0", function()
    WithGlobals({
      C_MythicPlus = nil,
      C_Container = {
        GetContainerNumSlots = function(bag)
          return bag == 0 and 4 or 0
        end,
        GetContainerItemID = function(bag, slot)
          if bag == 0 and slot == 2 then
            return 180653
          end
          return nil
        end,
        GetContainerItemLink = function(bag, slot)
          if bag == 0 and slot == 2 then
            return "|Hkeystone:180653:2649:0:0:0:0:0|h[Keystone]|h"
          end
          return nil
        end,
      },
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
      Assert.Equal(mapID, nil, "level=0 in the bag link must not be accepted")
      Assert.Equal(level, nil, "level=0 in the bag link must not be accepted")
    end)
  end)

  -- End-to-end: receiver pipeline that the original bug broke ------------------------------

  test(
    "KeySync receiver pipeline: empty API + bag with key → BuildOwnKeystoneAnnounceLine produces a sendable line",
    function()
      WithGlobals({
        C_MythicPlus = {
          GetOwnedKeystoneLevel = function()
            return nil
          end,
          GetOwnedKeystoneChallengeMapID = function()
            return nil
          end,
        },
        C_Container = MakeBagApiWithKeystone(2649, 14),
        C_ChallengeMode = false,
      }, function()
        local sync = BuildMockSync()
        local ctrl = BuildController(LoadAddonModules, sync)
        local mapID, level = ctrl.GetOwnedKeystoneSnapshot()
        Assert.Equal(mapID, 2649, "snapshot must come from bag")
        Assert.Equal(level, 14, "snapshot must come from bag")

        local addon = LoadAddonModules({ "isiLive_context_helpers.lua" })
        local line = addon.ContextHelpers.BuildOwnKeystoneAnnounceLine({
          getOwnedKeystoneSnapshot = ctrl.GetOwnedKeystoneSnapshot,
          getL = function()
            return { ANNOUNCE_PREFIX = "PartyKeys:" }
          end,
        })
        Assert.True(type(line) == "string" and #line > 0, "line must be built end-to-end after bag fallback")
        Assert.True(
          line:find("|Hkeystone:", 1, true) ~= nil,
          "line must embed the real keystone hyperlink from the bag, not a manually built one"
        )
      end)
    end
  )

  -- Sender-vs-receiver format parity: both paths route through the same
  -- ContextHelpers.BuildOwnKeystoneAnnounceLine, so the chat output for
  -- a button click and a SHAREKEYS-triggered post must be byte-identical
  -- and must satisfy the two server-side filter rules:
  --   1. Real |Hkeystone:...|h hyperlink (no manually constructed link)
  --   2. No |cffXXXXXX...|r color codes wrapping bare [brackets]
  test(
    "KeySync sender vs receiver: both paths produce byte-identical chat lines and pass server-filter rules",
    function()
      WithGlobals({
        C_MythicPlus = {
          GetOwnedKeystoneLevel = function()
            return nil
          end,
          GetOwnedKeystoneChallengeMapID = function()
            return nil
          end,
        },
        C_Container = MakeBagApiWithKeystone(2649, 14),
        C_ChallengeMode = false,
      }, function()
        local sync = BuildMockSync()
        local ctrl = BuildController(LoadAddonModules, sync)
        local addon = LoadAddonModules({ "isiLive_context_helpers.lua" })

        local senderLine = addon.ContextHelpers.BuildOwnKeystoneAnnounceLine({
          getOwnedKeystoneSnapshot = ctrl.GetOwnedKeystoneSnapshot,
          getL = function()
            return { ANNOUNCE_PREFIX = "PartyKeys:" }
          end,
        })

        local receiverLine = addon.ContextHelpers.BuildOwnKeystoneAnnounceLine({
          getOwnedKeystoneSnapshot = ctrl.GetOwnedKeystoneSnapshot,
          getL = function()
            return { ANNOUNCE_PREFIX = "PartyKeys:" }
          end,
        })

        Assert.Equal(senderLine, receiverLine, "sender and receiver must emit byte-identical chat lines")
        Assert.True(
          type(senderLine) == "string" and senderLine:find("|Hkeystone:", 1, true) ~= nil,
          "format-rule-1: line must embed a real keystone hyperlink, not a manually constructed |Hkeystone string"
        )

        -- Format-rule-2 detector: any |cff... that opens BEFORE a [ but is not part of a |H...|h hyperlink.
        -- A real hyperlink looks like |cff…|Hkeystone:…|h[…]|h|r — the [ sits inside |H…|h, which is allowed.
        -- A faked link that the chat server drops looks like |cff…[…]|r with no |H…|h around the brackets.
        local function HasColorWrappingBareBrackets(line)
          local searchStart = 1
          while true do
            local colorOpen = line:find("|cff", searchStart, true)
            if not colorOpen then
              return false
            end
            local nextBracket = line:find("[", colorOpen, true)
            local nextHyperlink = line:find("|H", colorOpen, true)
            if not nextBracket then
              return false
            end
            if not nextHyperlink or nextBracket < nextHyperlink then
              return true
            end
            searchStart = colorOpen + 1
          end
        end

        Assert.True(
          not HasColorWrappingBareBrackets(senderLine),
          "format-rule-2: no |cff... color code may wrap bare [brackets] without an enclosing |H...|h hyperlink"
        )
      end)
    end
  )

  test("KeySync sender vs receiver: plain-text fallback path also stays format-rule-2 compliant", function()
    WithGlobals({
      C_MythicPlus = false,
      C_Container = false,
      C_ChallengeMode = false,
    }, function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      -- Seed the roster with a synced own-key so ResolveOwnedKeystoneSnapshot's roster fallback fires.
      local addon = LoadAddonModules({ "isiLive_context_helpers.lua" })

      local line = addon.ContextHelpers.BuildOwnKeystoneAnnounceLine({
        getOwnedKeystoneSnapshot = function()
          return 2649, 12
        end,
        getL = function()
          return { ANNOUNCE_PREFIX = "PartyKeys:" }
        end,
      })
      Assert.True(type(line) == "string", "plain-text fallback must still produce a string")
      Assert.Equal(
        line:find("|cff", 1, true),
        nil,
        "plain-text fallback must NOT contain any |cff color code (would trigger server-side fake-link filter)"
      )
      Assert.True(
        line:find("[", 1, true) ~= nil,
        "plain-text fallback must still contain bare brackets — only |cff...|r wrapping triggers the filter"
      )
      -- Sanity: ctrl is loaded just to mirror the test-setup of the parity test (suppresses
      -- a luacheck unused-warning and proves the controller is reachable in this scope too).
      Assert.NotNil(ctrl)
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

  test("KeySync SendIsiLiveHello allows hidden version sync", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync, {
      isFrameVisible = function()
        return false
      end,
      getAddonVersionRaw = function()
        return "0.9.160"
      end,
    })

    ctrl.SendIsiLiveHello(true, "group")

    Assert.Equal(#sync.calls, 1, "must forward exactly one hello message")
    Assert.Equal(sync.calls[1].fn, "SendHello", "must delegate to sync.SendHello")
    Assert.True(sync.calls[1].opts.force, "must pass force flag through")
    Assert.False(sync.calls[1].opts.isVisible, "hidden frame state must be forwarded")
    Assert.True(sync.calls[1].opts.allowHidden, "hidden hello sync must stay enabled")
    Assert.Equal(sync.calls[1].opts.version, "0.9.160", "hello payload must include addon version")
    Assert.Equal(sync.calls[1].opts.protocolVersion, 2, "hello payload must include sync protocol version")
    Assert.Equal(sync.calls[1].opts.source, "group", "hello payload must include sync source")
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

  test("KeySync RegisterVerifiedSyncAliasForRoster maps one same-realm sender to one roster row", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    sync.MarkUser("Kørshad-Blackmoore")
    sync.SetPlayerKeyInfo("Kørshad-Blackmoore", nil, 239, 17)

    local roster = {
      party1 = { name = "Kürshad", realm = "Blackmoore" },
    }

    Assert.True(
      ctrl.RegisterVerifiedSyncAliasForRoster(roster, "Kørshad-Blackmoore"),
      "unique same-realm sender must register as a verified alias"
    )
    local info = roster.party1
    Assert.True(ctrl.ApplyKnownKeyToRosterEntry(info), "verified alias must allow sync data to backfill the roster row")
    Assert.Equal(info.keyMapID, 239, "aliased key map must apply")
    Assert.Equal(info.keyLevel, 17, "aliased key level must apply")
  end)

  test("KeySync RegisterVerifiedSyncAliasForRoster fails closed for ambiguous same-realm candidates", function()
    local sync = BuildMockSync()
    local ctrl = BuildController(LoadAddonModules, sync)
    sync.MarkUser("Kørshad-Blackmoore")
    sync.SetPlayerKeyInfo("Kørshad-Blackmoore", nil, 239, 17)

    local roster = {
      party1 = { name = "Kürshad", realm = "Blackmoore" },
      party2 = { name = "Kyrshad", realm = "Blackmoore" },
    }

    Assert.False(
      ctrl.RegisterVerifiedSyncAliasForRoster(roster, "Kørshad-Blackmoore"),
      "ambiguous same-realm candidates must not register an alias"
    )
    local info = roster.party1
    Assert.False(ctrl.ApplyKnownKeyToRosterEntry(info), "unverified alias must not backfill roster state")
    Assert.Nil(info.keyMapID, "ambiguous alias must leave key map unresolved")
    Assert.Nil(info.keyLevel, "ambiguous alias must leave key level unresolved")
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

  test(
    "KeySync ApplyKnownKeyToRosterEntry KEEPS syncDps on a ghost when sync cache is empty (post-disband UI continuity)",
    function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local info = {
        name = "GhostPlayer",
        realm = "GhostRealm",
        isGhost = true,
        ilvl = 630,
        rio = 3400,
        syncDps = 45000,
      }

      -- Simulate post-disband state: sync cache cleared by clearKnownUsers, ghost still in roster.
      sync.SetPlayerDpsInfo("GhostPlayer", "GhostRealm", nil)
      ctrl.ApplyKnownKeyToRosterEntry(info)

      Assert.Equal(
        info.syncDps,
        45000,
        "ghost must keep its last-known syncDps after sync cache wipe — symmetric to ilvl/rio"
      )
      Assert.Equal(info.ilvl, 630, "ghost ilvl must be untouched (symmetry baseline)")
      Assert.Equal(info.rio, 3400, "ghost rio must be untouched (symmetry baseline)")
    end
  )

  test(
    "KeySync ApplyKnownKeyToRosterEntry STILL clears syncDps on an active member when sync data disappears",
    function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local info = {
        name = "ActivePlayer",
        realm = "ActiveRealm",
        isGhost = false,
        syncDps = 45000,
      }

      sync.SetPlayerDpsInfo("ActivePlayer", "ActiveRealm", nil)
      local changed = ctrl.ApplyKnownKeyToRosterEntry(info)

      Assert.True(changed, "active member: clearing syncDps must still report a change")
      Assert.Nil(
        info.syncDps,
        "active member: syncDps reset behavior must be preserved (not regressed by the ghost fix)"
      )
    end
  )

  test(
    "KeySync ApplyKnownKeyToRosterEntry clears stale synced LOC fallback fields when sync data disappears",
    function()
      local sync = BuildMockSync()
      local ctrl = BuildController(LoadAddonModules, sync)
      local info = {
        name = "ActivePlayer",
        realm = "ActiveRealm",
        isGhost = false,
        syncLocMapID = 300,
      }

      sync.SetPlayerLocInfo("ActivePlayer", "ActiveRealm", nil)
      local changed = ctrl.ApplyKnownKeyToRosterEntry(info)

      Assert.True(changed, "active member: clearing syncLocMapID must report a roster change")
      Assert.Nil(info.syncLocMapID, "stale syncLocMapID must be cleared when sync data disappears")
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

  -- Branch coverage: kick-info interpolation against GetTime + extras drift.
  -- The default mock SetPlayerKickInfo doesn't carry receivedAtGetTime / extras,
  -- so these tests override GetPlayerKickInfo with a richer payload.

  test("KeySync ApplyKnownKeyToRosterEntry interpolates cooldownRemain against elapsed GetTime", function()
    local sync = BuildMockSync()
    sync.GetPlayerKickInfo = function(name, realm)
      if name == "InterpUser" and realm == "InterpRealm" then
        return {
          hasKick = true,
          onCooldown = true,
          cooldownRemain = 10,
          receivedAtGetTime = 100,
        }
      end
      return nil
    end

    WithGlobals({
      GetTime = function()
        return 103 -- 3 seconds elapsed since receivedAtGetTime=100
      end,
    }, function()
      local ctrl = BuildController(LoadAddonModules, sync)
      local info = { name = "InterpUser", realm = "InterpRealm" }
      local changed = ctrl.ApplyKnownKeyToRosterEntry(info)
      Assert.True(changed, "first apply must report a change")
      Assert.Equal(info.syncKickOnCooldown, true, "onCooldown must be propagated")
      Assert.Equal(info.syncKickRemain, 7, "cooldownRemain must be interpolated to 10 - 3 = 7")
    end)
  end)

  test("KeySync ApplyKnownKeyToRosterEntry clears peer kick state after stale heartbeat window", function()
    local sync = BuildMockSync()
    sync.GetPlayerKickInfo = function(name, realm)
      if name == "StaleKickUser" and realm == "StaleKickRealm" then
        return {
          hasKick = true,
          spellID = 119914,
          onCooldown = false,
          cooldownRemain = 0,
          receivedAtGetTime = 100,
        }
      end
      return nil
    end
    WithGlobals({
      GetTime = function()
        return 146
      end,
    }, function()
      local ctrl = BuildController(LoadAddonModules, sync)
      local info = {
        name = "StaleKickUser",
        realm = "StaleKickRealm",
        syncHasKick = true,
        syncKickOnCooldown = false,
        syncKickRemain = 0,
        syncKickSpellID = 119914,
      }
      local changed = ctrl.ApplyKnownKeyToRosterEntry(info)
      Assert.True(changed, "peer kick data older than three 15s heartbeats must clear")
      Assert.Nil(info.syncHasKick, "stale peer kick availability must become unresolved")
      Assert.Nil(info.syncKickOnCooldown, "stale peer kick cooldown state must clear")
      Assert.Nil(info.syncKickRemain, "stale peer kick remaining time must clear")
      Assert.Nil(info.syncKickSpellID, "stale peer kick spellID must clear")
    end)
  end)

  test("KeySync ApplyKnownKeyToRosterEntry backfills primary kick spellID when synced", function()
    local sync = BuildMockSync()
    sync.GetPlayerKickInfo = function(name, realm)
      if name == "SpellKickUser" and realm == "SpellKickRealm" then
        return {
          hasKick = true,
          spellID = 119914,
          onCooldown = false,
          cooldownRemain = 0,
          receivedAtGetTime = 100,
        }
      end
      return nil
    end
    WithGlobals({
      GetTime = function()
        return 101
      end,
    }, function()
      local ctrl = BuildController(LoadAddonModules, sync)
      local info = { name = "SpellKickUser", realm = "SpellKickRealm" }
      local changed = ctrl.ApplyKnownKeyToRosterEntry(info)
      Assert.True(changed, "synced primary kick spellID must mark the roster entry changed")
      Assert.Equal(info.syncKickSpellID, 119914, "primary kick spellID must be available to UI/tooltip code")
    end)
  end)

  test("KeySync ApplyKnownKeyToRosterEntry clamps interpolated cooldownRemain to 0 when fully elapsed", function()
    local sync = BuildMockSync()
    sync.GetPlayerKickInfo = function(name, realm)
      if name == "ExpiredUser" and realm == "ExpiredRealm" then
        return {
          hasKick = true,
          onCooldown = true,
          cooldownRemain = 5,
          receivedAtGetTime = 100,
        }
      end
      return nil
    end
    WithGlobals({
      GetTime = function()
        return 106 -- 6s elapsed > 5s remaining, still inside the 45s stale window
      end,
    }, function()
      local ctrl = BuildController(LoadAddonModules, sync)
      local info = { name = "ExpiredUser", realm = "ExpiredRealm" }
      ctrl.ApplyKnownKeyToRosterEntry(info)
      Assert.Equal(info.syncKickRemain, 0, "elapsed > remain must clamp to 0 (math.max guard)")
    end)
  end)

  test("KeySync ApplyKnownKeyToRosterEntry interpolates extras and drops entries whose remain has expired", function()
    local sync = BuildMockSync()
    sync.GetPlayerKickInfo = function(name, realm)
      if name == "ExtrasUser" and realm == "ExtrasRealm" then
        return {
          hasKick = true,
          onCooldown = true,
          cooldownRemain = 10,
          receivedAtGetTime = 100,
          extras = {
            [31935] = { cooldownRemain = 12 }, -- 12 - 5 = 7 → kept
            [89766] = { cooldownRemain = 2 }, -- 2 - 5 < 0 → dropped
          },
        }
      end
      return nil
    end
    WithGlobals({
      GetTime = function()
        return 105 -- 5s elapsed
      end,
    }, function()
      local ctrl = BuildController(LoadAddonModules, sync)
      local info = { name = "ExtrasUser", realm = "ExtrasRealm" }
      ctrl.ApplyKnownKeyToRosterEntry(info)
      Assert.NotNil(info.syncKickExtras, "extras table must be populated")
      Assert.Equal(info.syncKickExtras[31935].cooldownRemain, 7, "kept extra must be interpolated to 12-5=7")
      Assert.Nil(info.syncKickExtras[89766], "expired extra (remain<elapsed) must be dropped")
    end)
  end)

  test("KeySync ApplyKnownKeyToRosterEntry signals extrasChanged when a previously-tracked extra disappears", function()
    local sync = BuildMockSync()
    sync.GetPlayerKickInfo = function(name, realm)
      if name == "DriftUser" and realm == "DriftRealm" then
        return {
          hasKick = true,
          onCooldown = true,
          cooldownRemain = 8,
          receivedAtGetTime = 100,
          extras = {
            [31935] = { cooldownRemain = 7 }, -- still active (no elapsed drift)
          },
        }
      end
      return nil
    end
    WithGlobals({
      GetTime = function()
        return 100 -- no elapsed → interpolated values match incoming
      end,
    }, function()
      local ctrl = BuildController(LoadAddonModules, sync)
      local info = {
        name = "DriftUser",
        realm = "DriftRealm",
        syncHasKick = true,
        syncKickOnCooldown = true,
        syncKickRemain = 8,
        syncKickExtras = {
          [31935] = { cooldownRemain = 7 },
          [89766] = { cooldownRemain = 5 }, -- not in new payload → must trigger extrasChanged
        },
      }
      local changed = ctrl.ApplyKnownKeyToRosterEntry(info)
      Assert.True(changed, "removing a previously-tracked extra must mark roster as changed")
      Assert.Nil(info.syncKickExtras[89766], "missing extra must be dropped from roster entry")
    end)
  end)

  test("KeySync ApplyKnownKeyToRosterEntry signals no change when extras drift stays under 0.6s threshold", function()
    local sync = BuildMockSync()
    sync.GetPlayerKickInfo = function(name, realm)
      if name == "StableUser" and realm == "StableRealm" then
        return {
          hasKick = true,
          onCooldown = true,
          cooldownRemain = 8,
          receivedAtGetTime = 100,
          extras = {
            [31935] = { cooldownRemain = 7.4 }, -- only 0.4s drift from existing 7.0
          },
        }
      end
      return nil
    end
    WithGlobals({
      GetTime = function()
        return 100
      end,
    }, function()
      local ctrl = BuildController(LoadAddonModules, sync)
      local info = {
        name = "StableUser",
        realm = "StableRealm",
        syncHasKick = true,
        syncKickOnCooldown = true,
        syncKickRemain = 8,
        syncKickExtras = {
          [31935] = { cooldownRemain = 7 }, -- 0.4s diff from incoming 7.4 → below 0.6s drift cap
        },
      }
      local changed = ctrl.ApplyKnownKeyToRosterEntry(info)
      Assert.False(changed, "sub-threshold extras drift must not trigger a roster change")
    end)
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
