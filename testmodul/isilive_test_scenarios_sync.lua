---@diagnostic disable: undefined-global

local function RegisterNormalizeKeyTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Sync NormalizePlayerKey extracts name and realm correctly", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local parts = {}
        local pattern = "([^" .. sep .. "]*)"
        local count = 0
        for part in str:gmatch(pattern) do
          count = count + 1
          table.insert(parts, part)
          if max and count >= max then
            break
          end
        end
        return unpack(parts)
      end,
      GetRealmName = function()
        return "FallbackRealm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      local key = addon.Sync.NormalizePlayerKey("TestPlayer", "TestRealm")

      Assert.NotNil(key, "key must not be nil")
      Assert.True(key:find("testplayer") ~= nil, "key must contain normalized player name")
      Assert.True(key:find("testrealm") ~= nil, "key must contain normalized realm name")
    end)
  end)

  test("Sync NormalizePlayerKey handles multi-dash realm names", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str:sub(1, pos - 1)
      end,
      GetRealmName = function()
        return "FallbackRealm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      local key = addon.Sync.NormalizePlayerKey("Player-Der-Rat-von-Dalaran", "")

      Assert.NotNil(key, "key must not be nil for multi-dash realm")
      Assert.True(key:find("player") ~= nil, "key must contain player name")
      Assert.True(key:find("derratvondalaran") ~= nil, "key must normalize multi-dash realm")
    end)
  end)

  test("Sync NormalizePlayerKey handles empty realm with fallback", function()
    WithGlobals({
      strsplit = function(_sep, str, _max)
        return str
      end,
      GetRealmName = function()
        return "MyRealm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      local key = addon.Sync.NormalizePlayerKey("Solo", "")

      Assert.NotNil(key, "key must not be nil for empty realm")
      Assert.True(key:find("solo") ~= nil, "key must contain player name")
      Assert.True(key:find("myrealm") ~= nil, "key must use GetRealmName fallback")
    end)
  end)
end

local function RegisterKnownUserAndKeyTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Sync MarkUser and IsUserKnown track players", function()
    WithGlobals({
      strsplit = function(_sep, str, _max)
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      Assert.False(addon.Sync.IsUserKnown("Alpha", "Realm"), "user must not be known before mark")

      addon.Sync.MarkUser("Alpha", "Realm")
      Assert.True(addon.Sync.IsUserKnown("Alpha", "Realm"), "user must be known after mark")

      addon.Sync.ClearKnownUsers()
      Assert.False(addon.Sync.IsUserKnown("Alpha", "Realm"), "user must not be known after clear")
    end)
  end)

  test("Sync SetPlayerKeyInfo deduplicates identical key updates", function()
    WithGlobals({
      strsplit = function(_sep, str, _max)
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local firstChanged = addon.Sync.SetPlayerKeyInfo("Player", "Realm", 2649, 15)
      Assert.True(firstChanged, "first key set must report change")

      local secondChanged = addon.Sync.SetPlayerKeyInfo("Player", "Realm", 2649, 15)
      Assert.False(secondChanged, "identical key set must not report change")

      local thirdChanged = addon.Sync.SetPlayerKeyInfo("Player", "Realm", 2649, 16)
      Assert.True(thirdChanged, "different level must report change")

      local info = addon.Sync.GetPlayerKeyInfo("Player", "Realm")
      Assert.NotNil(info, "key info must exist after set")
      Assert.Equal(info.mapID, 2649, "stored mapID must match")
      Assert.Equal(info.level, 16, "stored level must match latest update")
    end)
  end)
end

local function RegisterStatsSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Sync ProcessAddonMessage stores STATS payload and exposes synced stats", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str:sub(1, pos - 1)
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local firstResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "STATS:72:615:3210", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")
      Assert.NotNil(firstResult, "STATS must return result")
      Assert.True(firstResult.statsUpdated, "first STATS must report update")

      local secondResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "STATS:72:615:3210", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")
      Assert.NotNil(secondResult, "duplicate STATS must still return result")
      Assert.False(secondResult.statsUpdated, "identical STATS must be deduplicated")

      local statsInfo = addon.Sync.GetPlayerStatsInfo("OtherPlayer", "OtherRealm")
      Assert.NotNil(statsInfo, "synced stats info must be stored")
      Assert.Equal(statsInfo.specID, 72, "stored specID must match payload")
      Assert.Equal(statsInfo.ilvl, 615, "stored ilvl must match payload")
      Assert.Equal(statsInfo.rio, 3210, "stored rio must match payload")
    end)
  end)

  test("Sync SendStats respects visibility and deduplicates payloads", function()
    local sentMessages = {}
    local now = 100

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendStats({
        isVisible = false,
        specID = 72,
        ilvl = 615,
        rio = 3210,
      })
      Assert.Equal(#sentMessages, 0, "hidden stats send must be suppressed")

      addon.Sync.SendStats({
        isVisible = true,
        specID = 72,
        ilvl = 615,
        rio = 3210,
      })
      Assert.Equal(#sentMessages, 1, "visible stats send must publish one payload")
      Assert.Equal(sentMessages[1].prefix, "ISILIVE", "stats payload must use isiLive prefix")
      Assert.Equal(
        sentMessages[1].message,
        "STATS:72:615:3210:100:local",
        "stats payload must encode spec/ilvl/rio and metadata"
      )
      Assert.Equal(sentMessages[1].channel, "PARTY", "stats payload must use party channel while grouped")

      now = 101
      addon.Sync.SendStats({
        isVisible = true,
        specID = 72,
        ilvl = 615,
        rio = 3210,
      })
      Assert.Equal(#sentMessages, 1, "duplicate stats payload within cooldown must be suppressed")

      now = 106
      addon.Sync.SendStats({
        isVisible = true,
        specID = 72,
        ilvl = 615,
        rio = 3210,
      })
      Assert.Equal(#sentMessages, 2, "same stats payload must resend after cooldown expires")
      Assert.Equal(sentMessages[2].message, "STATS:72:615:3210:106:local", "resend must refresh metadata timestamp")

      now = 107
      addon.Sync.SendStats({
        force = true,
        isVisible = false,
        allowHidden = true,
        specID = 72,
        ilvl = 615,
        rio = 3210,
      })
      Assert.Equal(#sentMessages, 3, "forced hidden refresh replies must bypass visibility suppression")
      Assert.Equal(sentMessages[3].message, "STATS:72:615:3210:107:local", "forced resend must include latest metadata")
    end)
  end)
end

local function RegisterSendOwnKeySnapshotTests(test, Assert, WithGlobals, LoadAddonModules)
  test("KeySync SendOwnKeySnapshot publishes key and stats when frame is visible", function()
    local sentMessages = {}

    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitExists = function(unit)
        return unit == "player"
      end,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return 15
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 2649
        end,
      },
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 72, "Fury"
        end
        return nil
      end,
      GetSpecializationInfoByID = function(specID)
        if specID == 72 then
          return 72, "Fury"
        end
        return nil, nil
      end,
      C_Item = {
        GetAverageItemLevel = function()
          return 611.4, 615.2
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua", "isiLive_keysync.lua" })
      local controller = addon.KeySync.CreateController({
        sync = addon.Sync,
        getUnitNameAndRealm = function(_unit)
          return "Me", "Realm"
        end,
        getAddonVersionRaw = function()
          return "1.0"
        end,
        getUnitRio = function(_unit)
          return 3210
        end,
        isFrameVisible = function()
          return true
        end,
      })

      controller.SendOwnKeySnapshot(true)

      Assert.Equal(#sentMessages, 4, "key snapshot should publish KEY, STATS, DPS, and LOC payloads")
      Assert.Equal(sentMessages[1].message, "KEY:2649:15:100:local", "first payload must be KEY snapshot")
      Assert.Equal(sentMessages[2].message, "STATS:72:615:3210:100:local", "second payload must be STATS snapshot")
      Assert.Equal(sentMessages[3].message, "DPS:0:100:local", "third payload must be DPS snapshot")
      Assert.Equal(sentMessages[4].message, "LOC:0:100:local", "fourth payload must be LOC snapshot")

      addon.Sync.SetPlayerKeyInfo("Peer", "Realm", 2649, 15)
      addon.Sync.SetPlayerStatsInfo("Peer", "Realm", 72, 615, 3210)

      local info = {
        name = "Peer",
        realm = "Realm",
        keyMapID = nil,
        keyLevel = nil,
        spec = nil,
        ilvl = nil,
        rio = nil,
      }

      local changed = controller.ApplyKnownKeyToRosterEntry(info)

      Assert.True(changed, "synced key+stats should update roster entry")
      Assert.Equal(info.keyMapID, 2649, "synced key mapID must backfill roster entry")
      Assert.Equal(info.keyLevel, 15, "synced key level must backfill roster entry")
      Assert.Equal(info.spec, "Fury", "synced specID must resolve to localized spec name")
      Assert.Equal(info.ilvl, 615, "synced ilvl must backfill roster entry")
      Assert.Equal(info.rio, 3210, "synced rio must backfill roster entry")
    end)
  end)

  test("KeySync SendOwnBackgroundSnapshot publishes sparse hidden changes without DPS spam", function()
    local sentMessages = {}
    local keyLevel = 15
    local keyMapID = 2649

    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitExists = function(unit)
        return unit == "player"
      end,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return keyLevel
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return keyMapID
        end,
      },
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 72, "Fury"
        end
        return nil
      end,
      C_Item = {
        GetAverageItemLevel = function()
          return 611.4, 615.2
        end,
      },
      GetInstanceInfo = function()
        return "Dungeon", "party"
      end,
      C_Map = {
        GetBestMapForUnit = function(unit)
          if unit == "player" then
            return 503
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua", "isiLive_keysync.lua" })
      local controller = addon.KeySync.CreateController({
        sync = addon.Sync,
        getUnitNameAndRealm = function(_unit)
          return "Me", "Realm"
        end,
        getAddonVersionRaw = function()
          return "1.0"
        end,
        getUnitRio = function(_unit)
          return 3210
        end,
        getPlayerLastRunDps = function(_name, _realm)
          return 777
        end,
        isFrameVisible = function()
          return false
        end,
      })

      controller.SendOwnBackgroundSnapshot("zone")
      controller.SendOwnBackgroundSnapshot("zone")
      keyLevel = 16
      controller.SendOwnBackgroundSnapshot("zone")

      Assert.Equal(#sentMessages, 5, "hidden sparse background sync must send all changed sync buckets once")
      Assert.Equal(sentMessages[1].message, "KEY:2649:15:100:zone", "first hidden background payload must send KEY")
      Assert.Equal(
        sentMessages[2].message,
        "STATS:72:615:3210:100:zone",
        "second hidden background payload must send STATS"
      )
      Assert.Equal(sentMessages[3].message, "DPS:777:100:zone", "third hidden background payload must send DPS")
      Assert.Equal(sentMessages[4].message, "LOC:503:100:zone", "fourth hidden background payload must send LOC")
      Assert.Equal(sentMessages[5].message, "KEY:2649:16:100:zone", "changed key state must resend only KEY")
    end)
  end)

  test("KeySync owned location lookup skips player map lookup when player unit is missing", function()
    local sentMessages = {}
    local mapCalls = 0

    WithGlobals({
      GetTime = function()
        return 100
      end,
      UnitExists = function(_unit)
        return false
      end,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return 15
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 2649
        end,
      },
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 72, "Fury"
        end
        return nil
      end,
      C_Item = {
        GetAverageItemLevel = function()
          return 611.4, 615.2
        end,
      },
      GetInstanceInfo = function()
        return "Dungeon", "party"
      end,
      C_Map = {
        GetBestMapForUnit = function(_unit)
          mapCalls = mapCalls + 1
          error("GetBestMapForUnit must not run when player unit is missing")
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua", "isiLive_keysync.lua" })
      local controller = addon.KeySync.CreateController({
        sync = addon.Sync,
        getUnitNameAndRealm = function(_unit)
          return "Me", "Realm"
        end,
        getAddonVersionRaw = function()
          return "1.0"
        end,
        getUnitRio = function(_unit)
          return 3210
        end,
        getPlayerLastRunDps = function(_name, _realm)
          return 777
        end,
        isFrameVisible = function()
          return false
        end,
      })

      controller.SendOwnBackgroundSnapshot("zone")
    end)

    Assert.Equal(mapCalls, 0, "hidden background sync must skip player map lookup when UnitExists is false")
    Assert.Equal(sentMessages[4].message, "LOC:0:100:zone", "missing player unit must keep LOC unresolved")
  end)
end

local function RegisterHiddenRefreshResponseTests(test, Assert, WithGlobals, LoadAddonModules)
  test("KeySync SendRefreshResponse can answer hidden refresh requests", function()
    local sentMessages = {}

    WithGlobals({
      GetTime = function()
        return 100
      end,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
      C_MythicPlus = {
        GetOwnedKeystoneLevel = function()
          return 15
        end,
        GetOwnedKeystoneChallengeMapID = function()
          return 2649
        end,
      },
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 72, "Fury"
        end
        return nil
      end,
      C_Item = {
        GetAverageItemLevel = function()
          return 611.4, 615.2
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua", "isiLive_keysync.lua" })
      local controller = addon.KeySync.CreateController({
        sync = addon.Sync,
        getUnitNameAndRealm = function(_unit)
          return "Me", "Realm"
        end,
        getAddonVersionRaw = function()
          return "1.0"
        end,
        getUnitRio = function(_unit)
          return 3210
        end,
        isFrameVisible = function()
          return false
        end,
        canRespondToRefreshRequest = function()
          return true
        end,
      })

      local sent = controller.SendRefreshResponse()

      Assert.True(sent, "hidden refresh response should be allowed outside blocked runtime states")
      Assert.Equal(#sentMessages, 4, "refresh response should publish KEY, STATS, DPS, and LOC")
      Assert.Equal(
        sentMessages[1].message,
        "KEY:2649:15:100:reqsync",
        "refresh response must publish current key payload first"
      )
      Assert.Equal(
        sentMessages[2].message,
        "STATS:72:615:3210:100:reqsync",
        "refresh response must publish current stats payload"
      )
      Assert.Equal(sentMessages[3].message, "DPS:0:100:reqsync", "refresh response must publish DPS payload")
      Assert.Equal(sentMessages[4].message, "LOC:0:100:reqsync", "refresh response must publish LOC payload")
    end)
  end)

  test("KeySync SendRefreshResponse skips while paused or stopped", function()
    local sentMessages = {}

    WithGlobals({
      GetTime = function()
        return 100
      end,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua", "isiLive_keysync.lua" })
      local controller = addon.KeySync.CreateController({
        sync = addon.Sync,
        getUnitNameAndRealm = function(_unit)
          return "Me", "Realm"
        end,
        getAddonVersionRaw = function()
          return "1.0"
        end,
        getUnitRio = function(_unit)
          return nil
        end,
        isFrameVisible = function()
          return false
        end,
        canRespondToRefreshRequest = function()
          return false
        end,
      })

      local sent = controller.SendRefreshResponse()

      Assert.False(sent, "blocked runtime states must suppress hidden refresh responses")
      Assert.Equal(#sentMessages, 0, "blocked refresh responses must not publish sync payloads")
    end)
  end)
end

local function RegisterInspectFreshnessSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  test("KeySync keeps fresh local inspect stats over synced peer stats", function()
    WithGlobals({
      GetSpecializationInfoByID = function(specID)
        if specID == 72 then
          return 72, "Fury"
        end
        return nil, nil
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua", "isiLive_keysync.lua" })
      local controller = addon.KeySync.CreateController({
        sync = addon.Sync,
        getUnitNameAndRealm = function(_unit)
          return "Me", "Realm"
        end,
        getAddonVersionRaw = function()
          return "1.0"
        end,
        getUnitRio = function(_unit)
          return nil
        end,
        isFrameVisible = function()
          return true
        end,
      })

      addon.Sync.SetPlayerKeyInfo("Peer", "Realm", 2649, 15)
      addon.Sync.SetPlayerStatsInfo("Peer", "Realm", 72, 615, 3210)

      local info = {
        name = "Peer",
        realm = "Realm",
        keyMapID = nil,
        keyLevel = nil,
        spec = "Arms",
        ilvl = 622,
        rio = 3300,
        _localSpecFresh = true,
        _localIlvlFresh = true,
        _localRioFresh = true,
      }

      local changed = controller.ApplyKnownKeyToRosterEntry(info)

      Assert.True(changed, "key sync should still backfill key while local inspect stats stay authoritative")
      Assert.Equal(info.keyMapID, 2649, "key mapID must still be applied from sync")
      Assert.Equal(info.keyLevel, 15, "key level must still be applied from sync")
      Assert.Equal(info.spec, "Arms", "fresh local spec must not be overwritten by sync")
      Assert.Equal(info.ilvl, 622, "fresh local ilvl must not be overwritten by sync")
      Assert.Equal(info.rio, 3300, "fresh local rio must not be overwritten by sync")

      local pendingInfo = {
        name = "Peer",
        realm = "Realm",
        keyMapID = nil,
        keyLevel = nil,
        spec = "Arms",
        ilvl = 622,
        rio = 3300,
        _refreshQueued = true,
      }

      local pendingChanged = controller.ApplyKnownKeyToRosterEntry(pendingInfo)
      Assert.True(pendingChanged, "pending forced refresh should still backfill key data")
      Assert.Equal(pendingInfo.keyMapID, 2649, "pending forced refresh must still backfill key mapID")
      Assert.Equal(pendingInfo.keyLevel, 15, "pending forced refresh must still backfill key level")
      Assert.Equal(pendingInfo.spec, "Arms", "pending forced refresh must not be overwritten by sync")
      Assert.Equal(pendingInfo.ilvl, 622, "pending forced refresh must not be overwritten by sync")
      Assert.Equal(pendingInfo.rio, 3300, "pending forced refresh must not be overwritten by sync")
    end)
  end)
end

local function RegisterPendingFallbackSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  test("KeySync pending forced refresh backfills missing sync fallback fields while inspect is pending", function()
    WithGlobals({
      GetSpecializationInfoByID = function(specID)
        if specID == 72 then
          return 72, "Fury"
        end
        return nil, nil
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua", "isiLive_keysync.lua" })
      local controller = addon.KeySync.CreateController({
        sync = addon.Sync,
        getUnitNameAndRealm = function(_unit)
          return "Me", "Realm"
        end,
        getAddonVersionRaw = function()
          return "1.0"
        end,
        getUnitRio = function(_unit)
          return nil
        end,
        isFrameVisible = function()
          return true
        end,
      })

      addon.Sync.SetPlayerKeyInfo("Peer", "Realm", 2649, 15)
      addon.Sync.SetPlayerStatsInfo("Peer", "Realm", 72, 615, 3210)
      addon.Sync.SetPlayerDpsInfo("Peer", "Realm", 250000)
      addon.Sync.SetPlayerLocInfo("Peer", "Realm", 2649)

      local pendingFallbackInfo = {
        name = "Peer",
        realm = "Realm",
        keyMapID = nil,
        keyLevel = nil,
        spec = nil,
        ilvl = nil,
        rio = nil,
        syncDps = nil,
        syncLocMapID = nil,
        _refreshQueued = true,
      }

      local pendingFallbackChanged = controller.ApplyKnownKeyToRosterEntry(pendingFallbackInfo)
      Assert.True(
        pendingFallbackChanged,
        "pending forced refresh should still fill missing sync fallback fields while inspect is pending"
      )
      Assert.Equal(pendingFallbackInfo.keyMapID, 2649, "pending sync fallback must still keep key mapID current")
      Assert.Equal(pendingFallbackInfo.keyLevel, 15, "pending sync fallback must still keep key level current")
      Assert.Equal(pendingFallbackInfo.spec, "Fury", "pending sync fallback must fill missing spec from sync")
      Assert.Equal(pendingFallbackInfo.ilvl, 615, "pending sync fallback must fill missing ilvl from sync")
      Assert.Equal(pendingFallbackInfo.rio, 3210, "pending sync fallback must fill missing rio from sync")
      Assert.Equal(pendingFallbackInfo.syncDps, 250000, "pending sync fallback must fill missing syncDps")
      Assert.Equal(pendingFallbackInfo.syncLocMapID, 2649, "pending sync fallback must fill missing syncLocMapID")
    end)
  end)
end

local function RegisterKeySyncStatsTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterSendOwnKeySnapshotTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterHiddenRefreshResponseTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterInspectFreshnessSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterPendingFallbackSyncTests(test, Assert, WithGlobals, LoadAddonModules)
end

local function RegisterProcessMessageTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Sync ProcessAddonMessage handles HELLO, REQSYNC, and KEY payloads", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str:sub(1, pos - 1)
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local helloResult = addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "HELLO:0.9.36:2:123:refresh",
        "OtherPlayer-OtherRealm",
        "MyPlayer",
        "Realm"
      )
      Assert.NotNil(helloResult, "HELLO must return result")
      Assert.True(helloResult.shouldAck, "HELLO from different player must require ack")
      Assert.Equal(helloResult.peerProtocolVersion, 2, "HELLO must expose protocol version")
      Assert.Equal(helloResult.peerCapturedAt, 123, "HELLO must expose capturedAt metadata")
      Assert.Equal(helloResult.peerSource, "refresh", "HELLO must expose source metadata")

      local legacyHelloResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "HELLO:0.9.36", "LegacyPlayer-OtherRealm", "MyPlayer", "Realm")
      Assert.NotNil(legacyHelloResult, "legacy HELLO must still return result")
      Assert.True(legacyHelloResult.shouldAck, "legacy HELLO must still require ack")

      local selfResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "HELLO:0.9.36:2:123:refresh", "MyPlayer-Realm", "MyPlayer", "Realm")
      Assert.NotNil(selfResult, "self HELLO must return result")
      Assert.False(selfResult.shouldAck, "HELLO from self must not require ack")

      local requestResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "REQSYNC", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")
      Assert.NotNil(requestResult, "REQSYNC must return result")
      Assert.True(requestResult.shouldRequestRefresh, "REQSYNC from different player must request a refresh response")

      local keyResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "KEY:2649:15", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")
      Assert.NotNil(keyResult, "KEY must return result")
      Assert.True(keyResult.keyUpdated, "first KEY must report update")

      local wrongPrefix =
        addon.Sync.ProcessAddonMessage("WRONGPREFIX", "HELLO:1.0", "Someone-Realm", "MyPlayer", "Realm")
      Assert.Nil(wrongPrefix, "wrong prefix must return nil")
    end)
  end)

  test("Sync ProcessAddonMessage handles SHAREKEYS payloads", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str:sub(1, pos - 1)
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local shareKeysResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "SHAREKEYS", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")

      Assert.NotNil(shareKeysResult, "SHAREKEYS must return result")
      Assert.True(
        shareKeysResult.shouldShareKeys,
        "SHAREKEYS from different player must request a key-share announcement"
      )
      Assert.False(shareKeysResult.shouldRequestRefresh, "SHAREKEYS must not request a refresh response")
    end)
  end)

  test("Sync ProcessAddonMessage handles LibKeystone requests and payloads", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str:sub(1, pos - 1)
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local requestResult =
        addon.Sync.ProcessAddonMessage("LibKS", "R", "OtherPlayer-OtherRealm", "MyPlayer", "Realm", "PARTY")
      Assert.NotNil(requestResult, "LibKeystone request must return result")
      Assert.True(
        requestResult.shouldReplyLibKeystone,
        "LibKeystone request from a different player must request one party-key reply"
      )

      local selfRequestResult =
        addon.Sync.ProcessAddonMessage("LibKS", "R", "MyPlayer-Realm", "MyPlayer", "Realm", "PARTY")
      Assert.NotNil(selfRequestResult, "self LibKeystone request must still return a result")
      Assert.False(selfRequestResult.shouldReplyLibKeystone, "self LibKeystone request must not trigger a reply")

      local payloadResult =
        addon.Sync.ProcessAddonMessage("LibKS", "15,2649,3210", "OtherPlayer-OtherRealm", "MyPlayer", "Realm", "PARTY")
      Assert.NotNil(payloadResult, "LibKeystone payload must return result")
      Assert.True(payloadResult.keyUpdated, "first LibKeystone key payload must report update")
      Assert.True(payloadResult.statsUpdated, "first LibKeystone rating payload must report update")

      local keyInfo = addon.Sync.GetPlayerKeyInfo("OtherPlayer", "OtherRealm")
      Assert.NotNil(keyInfo, "LibKeystone key payload must be stored in the shared key cache")
      Assert.Equal(keyInfo.mapID, 2649, "LibKeystone payload must store the synced key map")
      Assert.Equal(keyInfo.level, 15, "LibKeystone payload must store the synced key level")
      Assert.Equal(keyInfo.source, "libks", "LibKeystone payload must tag the shared source")

      local statsInfo = addon.Sync.GetPlayerStatsInfo("OtherPlayer", "OtherRealm")
      Assert.NotNil(statsInfo, "LibKeystone rating payload must be stored in the shared stats cache")
      Assert.Equal(statsInfo.rio, 3210, "LibKeystone payload must store the synced rio")
      Assert.Equal(statsInfo.source, "libks", "LibKeystone stats must tag the shared source")

      local duplicateResult =
        addon.Sync.ProcessAddonMessage("LibKS", "15,2649,3210", "OtherPlayer-OtherRealm", "MyPlayer", "Realm", "PARTY")
      Assert.False(duplicateResult.keyUpdated, "duplicate LibKeystone key payload must be deduplicated")
      Assert.False(duplicateResult.statsUpdated, "duplicate LibKeystone stats payload must be deduplicated")

      local guildResult =
        addon.Sync.ProcessAddonMessage("LibKS", "15,2649,3210", "Guildie-OtherRealm", "MyPlayer", "Realm", "GUILD")
      Assert.Nil(guildResult, "guild LibKeystone payloads must stay ignored for party roster sync")
    end)
  end)

  test("Sync ProcessAddonMessage keeps richer isiLive stats when LibKeystone only refreshes rio", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str:sub(1, pos - 1)
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SetPlayerStatsInfo("OtherPlayer", "OtherRealm", 72, 615, 3000, nil, "isilive")
      local result =
        addon.Sync.ProcessAddonMessage("LibKS", "15,2649,3210", "OtherPlayer-OtherRealm", "MyPlayer", "Realm", "PARTY")

      Assert.NotNil(result, "LibKeystone payload must still return a result")
      Assert.True(result.statsUpdated, "changed rio from LibKeystone must still report a stats update")

      local statsInfo = addon.Sync.GetPlayerStatsInfo("OtherPlayer", "OtherRealm")
      Assert.NotNil(statsInfo, "merged stats must remain stored")
      Assert.Equal(statsInfo.specID, 72, "LibKeystone payload must preserve richer synced spec data")
      Assert.Equal(statsInfo.ilvl, 615, "LibKeystone payload must preserve richer synced ilvl data")
      Assert.Equal(statsInfo.rio, 3210, "LibKeystone payload must refresh the rio field")
    end)
  end)

  test("Sync GetPlayerSyncSummary exposes the latest observed sync interval", function()
    local addon = LoadAddonModules({ "isiLive_sync.lua" })

    addon.Sync.SetPlayerHelloInfo("Peer", "Realm", "0.9.36", 2, 80, "zone")
    addon.Sync.SetPlayerHelloInfo("Peer", "Realm", "0.9.36", 2, 95, "zone")

    local summary = addon.Sync.GetPlayerSyncSummary("Peer", "Realm")
    Assert.NotNil(summary, "sync summary must exist after HELLO packets")
    Assert.Equal(summary.kind, "hello", "latest summary kind must match the updated HELLO bucket")
    Assert.Equal(summary.intervalSeconds, 15, "summary must expose the previous-to-current sync interval")
  end)

  test("Sync SendShareKeysRequest publishes SHAREKEYS to the addon sync channel", function()
    local sentMessages = {}

    WithGlobals({
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendShareKeysRequest()

      Assert.Equal(#sentMessages, 1, "share-keys request should publish one addon message")
      Assert.Equal(sentMessages[1].message, "SHAREKEYS", "share-keys request must use SHAREKEYS payload")
    end)
  end)

  test("Sync SendLibKeystoneRequest publishes one party request", function()
    local sentMessages = {}
    local now = 100

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local firstSent = addon.Sync.SendLibKeystoneRequest()
      Assert.True(firstSent, "LibKeystone request should send while grouped")
      Assert.Equal(#sentMessages, 1, "LibKeystone request should publish exactly one addon message")
      Assert.Equal(sentMessages[1].prefix, "LibKS", "LibKeystone request must use the LibKS prefix")
      Assert.Equal(sentMessages[1].message, "R", "LibKeystone request must use the request payload")
      Assert.Equal(sentMessages[1].channel, "PARTY", "LibKeystone request must use the party channel")

      now = 101
      local secondSent = addon.Sync.SendLibKeystoneRequest()
      Assert.False(secondSent, "LibKeystone request should respect the throttle window")
      Assert.Equal(#sentMessages, 1, "throttled LibKeystone request must not send again")

      now = 104
      local forcedSent = addon.Sync.SendLibKeystoneRequest({ force = true })
      Assert.True(forcedSent, "forced LibKeystone request should bypass the throttle window")
      Assert.Equal(#sentMessages, 2, "forced LibKeystone request must send again")
    end)
  end)

  test("Sync SendLibKeystonePartyData publishes current key and rio to party", function()
    local sentMessages = {}

    WithGlobals({
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local sent = addon.Sync.SendLibKeystonePartyData({
        mapID = 505,
        level = 17,
        rio = 3333,
      })
      Assert.True(sent, "LibKeystone party data should send while grouped")
      Assert.Equal(#sentMessages, 1, "LibKeystone party data should publish exactly one addon message")
      Assert.Equal(sentMessages[1].prefix, "LibKS", "LibKeystone party data must use the LibKS prefix")
      Assert.Equal(sentMessages[1].message, "17,505,3333", "LibKeystone party data must encode level, map, and rio")
      Assert.Equal(sentMessages[1].channel, "PARTY", "LibKeystone party data must use the party channel")
    end)
  end)
end

local function RegisterDpsLocSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Sync ProcessAddonMessage parses DPS payload and stores it", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result = addon.Sync.ProcessAddonMessage("ISILIVE", "DPS:321100", "Peer-Realm", "Me", "Realm")
      Assert.NotNil(result, "DPS message must return result")
      Assert.True(result.dpsUpdated, "first DPS must report update")

      local dpsInfo = addon.Sync.GetPlayerDpsInfo("Peer", "Realm")
      Assert.NotNil(dpsInfo, "DPS info must be stored")
      Assert.Equal(dpsInfo.dps, 321100, "stored DPS must match payload")

      local dupResult = addon.Sync.ProcessAddonMessage("ISILIVE", "DPS:321100", "Peer-Realm", "Me", "Realm")
      Assert.False(dupResult.dpsUpdated, "duplicate DPS must not report update")
    end)
  end)

  test("Sync ProcessAddonMessage parses LOC payload and stores it", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result = addon.Sync.ProcessAddonMessage("ISILIVE", "LOC:2649", "Peer-Realm", "Me", "Realm")
      Assert.NotNil(result, "LOC message must return result")
      Assert.True(result.locUpdated, "first LOC must report update")

      local locInfo = addon.Sync.GetPlayerLocInfo("Peer", "Realm")
      Assert.NotNil(locInfo, "LOC info must be stored")
      Assert.Equal(locInfo.mapID, 2649, "stored mapID must match payload")

      local dupResult = addon.Sync.ProcessAddonMessage("ISILIVE", "LOC:2649", "Peer-Realm", "Me", "Realm")
      Assert.False(dupResult.locUpdated, "duplicate LOC must not report update")
    end)
  end)

  test("Sync SendTarget respects visibility and deduplicates payloads", function()
    local sentMessages = {}
    local now = 100

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendTarget({
        isVisible = false,
        mapID = 2441,
        level = 14,
      })
      Assert.Equal(#sentMessages, 0, "hidden target send must be suppressed")

      addon.Sync.SendTarget({
        isVisible = false,
        allowHidden = true,
        mapID = 2441,
        level = 14,
      })
      Assert.Equal(#sentMessages, 1, "hidden target send must publish when full hidden sync explicitly allows it")
      Assert.Equal(
        sentMessages[1].message,
        "TARGET:2441:14:100:local",
        "hidden full-sync target payload must still encode exact target map, level, and metadata"
      )

      addon.Sync.SendTarget({
        isVisible = true,
        mapID = 2441,
        level = 14,
      })
      Assert.Equal(
        #sentMessages,
        1,
        "duplicate visible target payload must stay deduplicated after hidden full-sync send"
      )
      Assert.Equal(sentMessages[1].prefix, "ISILIVE", "target payload must use isiLive prefix")
      Assert.Equal(
        sentMessages[1].message,
        "TARGET:2441:14:100:local",
        "target payload must encode exact target map, level, and metadata"
      )
      Assert.Equal(sentMessages[1].channel, "PARTY", "target payload must use party channel while grouped")

      now = 101
      addon.Sync.SendTarget({
        isVisible = true,
        mapID = 2441,
        level = 14,
      })
      Assert.Equal(#sentMessages, 1, "duplicate target payload within cooldown must be suppressed")

      now = 106
      addon.Sync.SendTarget({
        isVisible = true,
        mapID = 2441,
        level = nil,
      })
      Assert.Equal(#sentMessages, 2, "changed target payload should publish again after cooldown window")
      Assert.Equal(
        sentMessages[2].message,
        "TARGET:2441:0:106:local",
        "missing level must serialize as exact map without guess"
      )
    end)
  end)
end

local function RegisterKickSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Sync SendKick encodes no-interrupt state and deduplicates payloads", function()
    local sentMessages = {}
    local now = 100

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendKick({
        hasKick = false,
        onCooldown = false,
        cooldownRemain = 0,
      })
      Assert.Equal(#sentMessages, 1, "no-interrupt kick state must publish once")
      Assert.Equal(sentMessages[1].message, "KICK:-1:0:0", "no-interrupt state must serialize distinctly from ready")

      now = 100.5
      addon.Sync.SendKick({
        hasKick = false,
        onCooldown = false,
        cooldownRemain = 0,
      })
      Assert.Equal(#sentMessages, 1, "duplicate no-interrupt kick payload within cooldown must be suppressed")

      now = 101.5
      addon.Sync.SendKick({
        hasKick = true,
        onCooldown = true,
        cooldownRemain = 2.1,
      })
      Assert.Equal(#sentMessages, 2, "changed kick state after cooldown window must publish again")
      Assert.Equal(
        sentMessages[2].message,
        "KICK:1:3:1:1:3",
        "cooldown kick state must ceil remaining seconds and carry one slot"
      )
      Assert.Equal(sentMessages[2].prefix, "ISILIVE", "kick payload must use isiLive prefix")
      Assert.Equal(sentMessages[2].channel, "PARTY", "kick payload must use grouped sync channel")

      now = 102.5
      addon.Sync.SendKick({
        onCooldown = false,
        cooldownRemain = 0,
      })
      Assert.Equal(#sentMessages, 2, "kick send without explicit hasKick must be rejected")
    end)
  end)

  test("Sync SendKick encodes kick slot lists when multiple slots are provided", function()
    local sentMessages = {}
    local now = 300

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendKick({
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
        kickSlots = {
          { onCooldown = false, cooldownRemain = 0 },
          { onCooldown = true, cooldownRemain = 4.2 },
        },
      })

      Assert.Equal(#sentMessages, 1, "kick slot payload must publish once")
      Assert.Equal(sentMessages[1].message, "KICK:0:0:2:0:0:1:5", "kick slot payload must include both slot states")
    end)
  end)

  test("Sync SendKick rejects malformed kick payload inputs without guessing", function()
    local sentMessages = {}
    local now = 200

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendKick({
        hasKick = true,
        onCooldown = true,
      })
      Assert.Equal(#sentMessages, 0, "kick send without explicit remain must be rejected")

      addon.Sync.SendKick({
        hasKick = true,
        cooldownRemain = 5,
      })
      Assert.Equal(#sentMessages, 0, "kick send without explicit cooldown state must be rejected")
    end)
  end)

  test("Sync ProcessAddonMessage parses TARGET payload and stores it", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result = addon.Sync.ProcessAddonMessage("ISILIVE", "TARGET:2441:14", "Peer-Realm", "Me", "Realm")
      Assert.NotNil(result, "TARGET message must return result")
      Assert.True(result.targetUpdated, "first TARGET must report update")

      local targetInfo = addon.Sync.GetPlayerTargetInfo("Peer", "Realm")
      Assert.NotNil(targetInfo, "TARGET info must be stored")
      Assert.Equal(targetInfo.mapID, 2441, "stored target mapID must match payload")
      Assert.Equal(targetInfo.level, 14, "stored target level must match payload")

      local dupResult = addon.Sync.ProcessAddonMessage("ISILIVE", "TARGET:2441:14", "Peer-Realm", "Me", "Realm")
      Assert.False(dupResult.targetUpdated, "duplicate TARGET must not report update")
    end)
  end)

  test("Sync ProcessAddonMessage parses KICK payloads with slot lists", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local unavailableResult = addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:-1:0:0", "Peer-Realm", "Me", "Realm")
      Assert.NotNil(unavailableResult, "KICK message must return result")
      Assert.True(unavailableResult.kickUpdated, "first KICK no-interrupt payload must report update")

      local kickInfo = addon.Sync.GetPlayerKickInfo("Peer", "Realm")
      Assert.NotNil(kickInfo, "KICK info must be stored")
      Assert.False(kickInfo.hasKick, "no-interrupt payload must preserve hasKick=false")
      Assert.False(kickInfo.onCooldown, "no-interrupt payload must not mark the spell on cooldown")
      Assert.Equal(kickInfo.cooldownRemain, 0, "no-interrupt payload must store zero remaining cooldown")
      Assert.NotNil(kickInfo.kickSlots, "no-interrupt payload must preserve an empty slot list")
      Assert.Equal(#kickInfo.kickSlots, 0, "no-interrupt payload must keep zero kick slots")

      local slotListResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:0:0:2:0:0:1:4", "Peer-Realm", "Me", "Realm")
      Assert.True(slotListResult.kickUpdated, "slot-list KICK payload must report update")

      local slotListInfo = addon.Sync.GetPlayerKickInfo("Peer", "Realm")
      Assert.NotNil(slotListInfo.kickSlots, "slot-list payload must preserve the kick slots")
      Assert.Equal(#slotListInfo.kickSlots, 2, "slot-list payload must keep multiple kick slots")
      Assert.False(slotListInfo.kickSlots[1].onCooldown, "first slot-list kick slot must stay ready")
      Assert.True(slotListInfo.kickSlots[2].onCooldown, "second slot-list kick slot must stay on cooldown")

      local duplicateResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:0:0:2:0:0:1:4", "Peer-Realm", "Me", "Realm")
      Assert.False(duplicateResult.kickUpdated, "duplicate slot-list KICK must not report update")
    end)
  end)

  test("Sync ProcessAddonMessage reports kick updates when remaining cooldown changes", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local firstResult = addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:1:8:2:1:8:0:0", "Peer-Realm", "Me", "Realm")
      Assert.True(firstResult.kickUpdated, "first active KICK payload must report update")

      local secondResult = addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:1:7:2:1:7:0:0", "Peer-Realm", "Me", "Realm")
      Assert.True(secondResult.kickUpdated, "changed remaining cooldown must report update")

      local kickInfo = addon.Sync.GetPlayerKickInfo("Peer", "Realm")
      Assert.NotNil(kickInfo, "active KICK info must be stored")
      Assert.True(kickInfo.hasKick, "active KICK payload must preserve hasKick=true")
      Assert.True(kickInfo.onCooldown, "active KICK payload must preserve cooldown state")
      Assert.Equal(kickInfo.cooldownRemain, 7, "updated remaining cooldown must be stored")
      Assert.NotNil(kickInfo.kickSlots, "active KICK payload must preserve kick slots")
      Assert.Equal(#kickInfo.kickSlots, 2, "active KICK payload must preserve multiple slots")
      Assert.True(kickInfo.kickSlots[1].onCooldown, "first active KICK slot must stay on cooldown")
      Assert.False(kickInfo.kickSlots[2].onCooldown, "second active KICK slot must stay ready")
    end)
  end)

  test("Sync ProcessAddonMessage rejects malformed KICK payloads without inventing a state", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local invalidStateResult = addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:bogus:0", "Peer-Realm", "Me", "Realm")
      Assert.False(invalidStateResult.kickUpdated, "invalid KICK state must be rejected without inventing a payload")
      Assert.Nil(addon.Sync.GetPlayerKickInfo("Peer", "Realm"), "invalid KICK state must not store any kick info")

      local invalidRemainResult = addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:1:bogus", "Peer-Realm", "Me", "Realm")
      Assert.False(invalidRemainResult.kickUpdated, "invalid KICK remain must be rejected without inventing a payload")
      Assert.Nil(addon.Sync.GetPlayerKickInfo("Peer", "Realm"), "invalid KICK remain must not store any kick info")

      local malformedSlotResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "KICK:1:5:2:0:0:1", "Peer-Realm", "Me", "Realm")
      Assert.False(
        malformedSlotResult.kickUpdated,
        "malformed multi-slot KICK payload must be rejected without inventing a payload"
      )
      Assert.Nil(
        addon.Sync.GetPlayerKickInfo("Peer", "Realm"),
        "malformed multi-slot KICK payload must not store any kick info"
      )
    end)
  end)

  test("KeySync ApplyKnownKeyToRosterEntry backfills syncDps and syncLocMapID", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua", "isiLive_keysync.lua" })
      local controller = addon.KeySync.CreateController({
        sync = addon.Sync,
        getUnitNameAndRealm = function(_unit)
          return "Me", "Realm"
        end,
        getAddonVersionRaw = function()
          return "1.0"
        end,
        isFrameVisible = function()
          return true
        end,
      })

      addon.Sync.SetPlayerDpsInfo("Peer", "Realm", 250000)
      addon.Sync.SetPlayerLocInfo("Peer", "Realm", 2649)

      local info = {
        name = "Peer",
        realm = "Realm",
      }

      local changed = controller.ApplyKnownKeyToRosterEntry(info)
      Assert.True(changed, "DPS/LOC backfill should mark entry as changed")
      Assert.Equal(info.syncDps, 250000, "syncDps should be backfilled from sync data")
      Assert.Equal(info.syncLocMapID, 2649, "syncLocMapID should be backfilled from sync data")

      local pendingInfo = {
        name = "Peer",
        realm = "Realm",
        _refreshQueued = true,
      }

      local pendingChanged = controller.ApplyKnownKeyToRosterEntry(pendingInfo)
      Assert.True(pendingChanged, "pending forced refresh should still backfill missing DPS and LOC fallback data")
      Assert.Equal(pendingInfo.syncDps, 250000, "pending forced refresh must backfill missing syncDps")
      Assert.Equal(pendingInfo.syncLocMapID, 2649, "pending forced refresh should still backfill syncLocMapID")

      local unchanged = controller.ApplyKnownKeyToRosterEntry(info)
      Assert.False(unchanged, "repeat apply with same data should not mark as changed")
    end)
  end)

  test("Sync ClearKnownUsers also clears DPS, LOC, and TARGET caches", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then
          return str
        end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SetPlayerDpsInfo("Peer", "Realm", 100000)
      addon.Sync.SetPlayerLocInfo("Peer", "Realm", 2649)
      addon.Sync.SetPlayerTargetInfo("Peer", "Realm", 2441, 14)
      Assert.NotNil(addon.Sync.GetPlayerDpsInfo("Peer", "Realm"), "DPS info should exist before clear")
      Assert.NotNil(addon.Sync.GetPlayerLocInfo("Peer", "Realm"), "LOC info should exist before clear")
      Assert.NotNil(addon.Sync.GetPlayerTargetInfo("Peer", "Realm"), "TARGET info should exist before clear")

      addon.Sync.ClearKnownUsers()
      Assert.Nil(addon.Sync.GetPlayerDpsInfo("Peer", "Realm"), "DPS info should be cleared")
      Assert.Nil(addon.Sync.GetPlayerLocInfo("Peer", "Realm"), "LOC info should be cleared")
      Assert.Nil(addon.Sync.GetPlayerTargetInfo("Peer", "Realm"), "TARGET info should be cleared")
    end)
  end)
end

local function RegisterSyncResetTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Sync ClearKnownUsers resets send cooldowns so next identical payload fires immediately", function()
    local sentMessages = {}
    local now = 100

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, { prefix = prefix, message = message, channel = channel })
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendStats({ isVisible = true, specID = 72, ilvl = 615, rio = 3210 })
      Assert.Equal(#sentMessages, 1, "first send must go through")

      now = 102
      addon.Sync.SendStats({ isVisible = true, specID = 72, ilvl = 615, rio = 3210 })
      Assert.Equal(#sentMessages, 1, "identical send within cooldown must be suppressed")

      addon.Sync.ClearKnownUsers()
      addon.Sync.SendStats({ isVisible = true, specID = 72, ilvl = 615, rio = 3210 })
      Assert.Equal(#sentMessages, 2, "send after ClearKnownUsers must bypass cooldown and dedup")
    end)
  end)

  test("Sync ClearKnownUsers resets kick send cooldowns so next identical payload fires immediately", function()
    local sentMessages = {}
    local now = 100

    WithGlobals({
      GetTime = function()
        return now
      end,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, { prefix = prefix, message = message, channel = channel })
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendKick({ hasKick = true, onCooldown = false, cooldownRemain = 0 })
      Assert.Equal(#sentMessages, 1, "first kick send must go through")

      now = 100.5
      addon.Sync.SendKick({ hasKick = true, onCooldown = false, cooldownRemain = 0 })
      Assert.Equal(#sentMessages, 1, "identical kick send within cooldown must be suppressed")

      addon.Sync.ClearKnownUsers()
      addon.Sync.SendKick({ hasKick = true, onCooldown = false, cooldownRemain = 0 })
      Assert.Equal(#sentMessages, 2, "kick send after ClearKnownUsers must bypass cooldown and dedup")
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterNormalizeKeyTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterKnownUserAndKeyTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterStatsSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterKeySyncStatsTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterProcessMessageTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterDpsLocSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterKickSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterSyncResetTests(test, Assert, WithGlobals, LoadAddonModules)
end
