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

      Assert.Equal(#sentMessages, 2, "key snapshot should publish both KEY and STATS payloads")
      Assert.Equal(sentMessages[1].message, "KEY:2649:15", "first payload must be KEY snapshot")
      Assert.Equal(sentMessages[2].message, "STATS:72:615:3210", "second payload must be STATS snapshot")

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
  test("Sync ProcessAddonMessage handles HELLO and KEY payloads", function()
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

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterNormalizeKeyTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterKnownUserAndKeyTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterStatsSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterKeySyncStatsTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterProcessMessageTests(test, Assert, WithGlobals, LoadAddonModules)
end
