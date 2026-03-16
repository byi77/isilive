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
      Assert.Equal(sentMessages[1].message, "STATS:72:615:3210", "stats payload must encode spec/ilvl/rio")
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
    end)
  end)
end

local function RegisterKeySyncStatsTests(test, Assert, WithGlobals, LoadAddonModules)
  test("KeySync SendOwnKeySnapshot publishes key and stats when frame is visible", function()
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
      Assert.Equal(sentMessages[1].message, "KEY:2649:15", "first payload must be KEY snapshot")
      Assert.Equal(sentMessages[2].message, "STATS:72:615:3210", "second payload must be STATS snapshot")
      Assert.Equal(sentMessages[3].message, "DPS:0", "third payload must be DPS snapshot")
      Assert.Equal(sentMessages[4].message, "LOC:0", "fourth payload must be LOC snapshot")

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

  test("KeySync SendRefreshResponse can answer hidden refresh requests outside active M+", function()
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
      Assert.Equal(sentMessages[1].message, "KEY:2649:15", "refresh response must publish current key payload first")
      Assert.Equal(sentMessages[2].message, "STATS:72:615:3210", "refresh response must publish current stats payload")
      Assert.Equal(sentMessages[3].message, "DPS:0", "refresh response must publish DPS payload")
      Assert.Equal(sentMessages[4].message, "LOC:0", "refresh response must publish LOC payload")
    end)
  end)

  test("KeySync SendRefreshResponse skips while paused, stopped, or active M+", function()
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
    end)
  end)
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

      local helloResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "HELLO:0.9.36", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")
      Assert.NotNil(helloResult, "HELLO must return result")
      Assert.True(helloResult.shouldAck, "HELLO from different player must require ack")

      local selfResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "HELLO:0.9.36", "MyPlayer-Realm", "MyPlayer", "Realm")
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

      local unchanged = controller.ApplyKnownKeyToRosterEntry(info)
      Assert.False(unchanged, "repeat apply with same data should not mark as changed")
    end)
  end)

  test("Sync ClearKnownUsers also clears DPS and LOC caches", function()
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
      Assert.NotNil(addon.Sync.GetPlayerDpsInfo("Peer", "Realm"), "DPS info should exist before clear")
      Assert.NotNil(addon.Sync.GetPlayerLocInfo("Peer", "Realm"), "LOC info should exist before clear")

      addon.Sync.ClearKnownUsers()
      Assert.Nil(addon.Sync.GetPlayerDpsInfo("Peer", "Realm"), "DPS info should be cleared")
      Assert.Nil(addon.Sync.GetPlayerLocInfo("Peer", "Realm"), "LOC info should be cleared")
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
end
