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

local function RegisterSyncRuntimeLogBurstTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Sync runtime logger keeps capped trace across 2000 message burst", function()
    WithGlobals({
      IsiLiveDB = {},
      GetTime = function()
        return 1000
      end,
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
      local addon = LoadAddonModules({ "isiLive_log_buffer.lua", "isiLive_runtime_log.lua", "isiLive_sync.lua" })
      local runtimeLog = addon.RuntimeLog.CreateController({
        getTimestamp = function()
          return "1000.000"
        end,
        maxEntries = 100,
      })
      runtimeLog.SetEnabled(true)
      addon.Sync.SetTraceLogger(runtimeLog.Trace)

      -- Index is a counter, not a key level: keep it under the sanity bound.
      local lastLevel
      for i = 1, 2000 do
        lastLevel = ((i - 1) % 500) + 1
        addon.Sync.ProcessAddonMessage("ISILIVE", "KEY:2649:" .. tostring(lastLevel), "Peer-Realm", "Me", "Realm")
      end

      local keyInfo = addon.Sync.GetPlayerKeyInfo("Peer", "Realm")
      local tail = runtimeLog.GetLogTail(100)
      Assert.Equal(runtimeLog.GetLogCount(), 100, "sync burst trace must stay capped")
      Assert.Equal(#tail, 100, "sync burst tail must stay capped")
      Assert.NotNil(keyInfo, "sync burst must keep applying latest key state")
      Assert.Equal(keyInfo.level, lastLevel, "sync burst must retain latest applied key level")
      Assert.True(
        tail[#tail]:find("%[SYNC%] event=message_applied sender=Peer%-Realm") ~= nil,
        "tail must include applied sync trace"
      )
    end)
  end)

  test("Sync runtime trace logger passes a lazy builder to runtime logging", function()
    WithGlobals({
      IsiLiveDB = {},
      GetTime = function()
        return 1000
      end,
      IsInGroup = function()
        return true
      end,
      IsInRaid = function()
        return false
      end,
      UnitExists = function(unit)
        return unit == "player"
      end,
      C_ChatInfo = {
        SendAddonMessage = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      local capturedBuilder = nil

      addon.Sync.SetTraceLogger(function(builder)
        capturedBuilder = builder
      end)
      addon.Sync.SendRefreshRequest({ force = true })

      Assert.Equal(type(capturedBuilder), "function", "sync trace logger must receive a lazy message builder")
      local formatted = capturedBuilder and capturedBuilder() or nil
      Assert.Equal(formatted, "[SYNC] send_reqsync channel=PARTY sent=true", "sync trace builder must format on demand")
    end)
  end)

  test("Sync ProcessAddonMessage deep trace exposes raw bucket payloads and sender bytes", function()
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
      local lines = {}
      addon.Sync.SetDeepTraceLogger(function(builder)
        table.insert(lines, builder())
      end)

      addon.Sync.ProcessAddonMessage("ISILIVE", "KEY:2649:17:123:hello", "Kürshad-Blackmoore", "Me", "Realm")

      local sawPayload = false
      local expectedPayload = "[SYNC] message_payload sender=Kürshad-Blackmoore"
        .. " senderBytes=4B-C3-BC-72-73-68-61-64-2D-42-6C-61-63-6B-6D-6F-6F-72-65"
        .. " bucket=KEY raw=KEY:2649:17:123:hello"
      for _, line in ipairs(lines) do
        if line == expectedPayload then
          sawPayload = true
        end
      end
      Assert.True(sawPayload, "deep trace must expose the raw incoming bucket payload")
    end)
  end)

  test("Sync RegisterVerifiedAlias exposes exact sender data through a verified roster name", function()
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

      addon.Sync.ProcessAddonMessage("ISILIVE", "KEY:239:17", "Kørshad-Blackmoore", "Me", "Realm")

      Assert.Nil(
        addon.Sync.GetPlayerKeyInfo("Kürshad", "Blackmoore"),
        "different unicode names must not match before a verified alias exists"
      )
      Assert.True(
        addon.Sync.RegisterVerifiedAlias("Kørshad-Blackmoore", nil, "Kürshad", "Blackmoore"),
        "verified same-realm alias must be accepted for a known sync sender"
      )

      local aliasedInfo = addon.Sync.GetPlayerKeyInfo("Kürshad", "Blackmoore")
      Assert.NotNil(aliasedInfo, "verified alias must expose sender key data through the roster key")
      Assert.Equal(aliasedInfo.mapID, 239, "aliased mapID must match sender payload")
      Assert.Equal(aliasedInfo.level, 17, "aliased level must match sender payload")
      Assert.True(addon.Sync.IsUserKnown("Kürshad", "Blackmoore"), "verified alias must mark roster name as known")
    end)
  end)

  test("Sync RegisterVerifiedAlias rejects cross-realm and unknown sender aliases", function()
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

      Assert.False(
        addon.Sync.RegisterVerifiedAlias("Kørshad-Blackmoore", nil, "Kürshad", "Blackmoore"),
        "alias must reject senders that have not been observed through sync"
      )
      addon.Sync.ProcessAddonMessage("ISILIVE", "KEY:239:17", "Kørshad-Blackmoore", "Me", "Realm")
      Assert.False(
        addon.Sync.RegisterVerifiedAlias("Kørshad-Blackmoore", nil, "Kürshad", "Malfurion"),
        "alias must reject cross-realm mappings"
      )
      Assert.Nil(
        addon.Sync.GetPlayerKeyInfo("Kürshad", "Malfurion"),
        "rejected cross-realm alias must not expose sender data"
      )
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
          return true
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
          return true
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
      UnitExists = function(unit)
        return unit == "player"
      end,
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
          return true
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
          return true
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
          return true
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

local function RegisterProcessMessageReceiveTests(test, Assert, WithGlobals, LoadAddonModules)
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

      local brResult = addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "BRLUST:BR:Caster-OtherRealm:20484",
        "Caster-OtherRealm",
        "MyPlayer",
        "Realm"
      )
      Assert.NotNil(brResult, "BRLUST must return result")
      Assert.NotNil(brResult.combatAnnounce, "BR payload must surface combatAnnounce on the result")
      Assert.Equal(brResult.combatAnnounce.kind, "BR", "combatAnnounce kind must be BR")
      Assert.Equal(brResult.combatAnnounce.caster, "Caster-OtherRealm", "combatAnnounce must carry the raw caster name")
      Assert.Equal(brResult.combatAnnounce.spellID, 20484, "combatAnnounce must include numeric spellID")

      local lustResult = addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "BRLUST:LUST:Shaman-OtherRealm:2825",
        "Shaman-OtherRealm",
        "MyPlayer",
        "Realm"
      )
      Assert.NotNil(lustResult.combatAnnounce, "LUST payload must surface combatAnnounce on the result")
      Assert.Equal(lustResult.combatAnnounce.kind, "LUST", "combatAnnounce kind must be LUST")

      local malformed =
        addon.Sync.ProcessAddonMessage("ISILIVE", "BRLUST:UNKNOWN:Foo:1", "Foo-OtherRealm", "MyPlayer", "Realm")
      Assert.Nil(malformed.combatAnnounce, "unknown BRLUST kind must not surface combatAnnounce")
    end)
  end)

  test("Sync ProcessAddonMessage handles Power Infusion payloads", function()
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
      local piResult = addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "PI:Priest-OtherRealm:MyPlayer-Realm:10060",
        "Priest-OtherRealm",
        "MyPlayer",
        "Realm"
      )
      Assert.NotNil(piResult.powerInfusionAnnounce, "PI payload must surface powerInfusionAnnounce on the result")
      Assert.Equal(piResult.powerInfusionAnnounce.caster, "Priest-OtherRealm", "PI payload must carry caster")
      Assert.Equal(piResult.powerInfusionAnnounce.recipient, "MyPlayer-Realm", "PI payload must carry recipient")
      Assert.True(piResult.powerInfusionAnnounce.isLocalRecipient, "PI payload must mark the local recipient")

      local piSelfEcho = addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "PI:MyPlayer-Realm:Target-OtherRealm:10060",
        "MyPlayer-Realm",
        "MyPlayer",
        "Realm"
      )
      Assert.Nil(piSelfEcho.powerInfusionAnnounce, "PI self echo must not surface an announce")

      local malformedPi = addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "PI:Priest-OtherRealm:Target-OtherRealm:123",
        "Priest-OtherRealm",
        "MyPlayer",
        "Realm"
      )
      Assert.Nil(malformedPi.powerInfusionAnnounce, "wrong PI spell id must not surface an announce")
    end)
  end)

  test("Sync ProcessAddonMessage does not ack hello-ack or reqsync-ack fan-out hellos", function()
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

      -- Loop breaker: without it two peers answer each other's ack fan-out
      -- hellos forever, flooding the send queue and reflecting SKCD locks.
      local helloAckResult = addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "HELLO:0.9.310:2:123:hello-ack",
        "OtherPlayer-OtherRealm",
        "MyPlayer",
        "Realm"
      )
      Assert.NotNil(helloAckResult, "hello-ack HELLO must return a result")
      Assert.False(helloAckResult.shouldAck, "a hello-ack fan-out reply must not be acked again")
      Assert.Equal(helloAckResult.peerSource, "hello-ack", "hello-ack source metadata must stay exposed")

      local reqsyncAckResult = addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "HELLO:0.9.310:2:124:reqsync-ack",
        "OtherPlayer-OtherRealm",
        "MyPlayer",
        "Realm"
      )
      Assert.NotNil(reqsyncAckResult, "reqsync-ack HELLO must return a result")
      Assert.False(reqsyncAckResult.shouldAck, "a reqsync-ack fan-out reply must not be acked again")

      local initialResult = addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "HELLO:0.9.310:2:125:group",
        "OtherPlayer-OtherRealm",
        "MyPlayer",
        "Realm"
      )
      Assert.NotNil(initialResult, "initial HELLO must return a result")
      Assert.True(initialResult.shouldAck, "an initial HELLO must still require an ack")
    end)
  end)

  test("Sync ProcessAddonMessage stores ACK version as hello info", function()
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

      local ackResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "ACK:0.9.41", "AckPlayer-OtherRealm", "MyPlayer", "Realm")

      Assert.NotNil(ackResult, "ACK must return result")
      Assert.False(ackResult.shouldAck, "ACK must not request another ack")
      Assert.Equal(ackResult.peerAddonVersion, "0.9.41", "ACK must expose the peer addon version")
      Assert.Equal(ackResult.peerProtocolVersion, nil, "ACK must keep unknown protocol unresolved")
      Assert.Equal(ackResult.peerCapturedAt, nil, "ACK must keep unknown capture timestamp unresolved")
      Assert.Equal(ackResult.peerSource, "ack", "ACK must expose its sync source")

      local helloInfo = addon.Sync.GetPlayerHelloInfo("AckPlayer", "OtherRealm")
      Assert.NotNil(helloInfo, "ACK must populate hello info for tooltip version rendering")
      Assert.Equal(helloInfo.addonVersion, "0.9.41", "stored hello info must keep ACK version")
      Assert.Equal(helloInfo.protocolVersion, nil, "stored ACK hello info must not guess a protocol version")
      Assert.Equal(helloInfo.capturedAt, nil, "stored ACK hello info must not guess a capture timestamp")
      Assert.Equal(helloInfo.source, "ack", "stored hello info must preserve ACK source")
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
      local logs = {}
      addon.Sync.SetLogger(function(message)
        logs[#logs + 1] = message
      end)

      local shareKeysResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "SHAREKEYS", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")

      Assert.NotNil(shareKeysResult, "SHAREKEYS must return result")
      Assert.True(
        shareKeysResult.shouldShareKeys,
        "SHAREKEYS from different player must request a key-share announcement"
      )
      Assert.False(shareKeysResult.shouldRequestRefresh, "SHAREKEYS must not request a refresh response")
      Assert.True(
        logs[#logs] and logs[#logs]:find("sharekeys=true", 1, true) ~= nil,
        "SHAREKEYS message_applied trace must expose sharekeys=true"
      )
      addon.Sync.SetLogger(nil)
    end)
  end)

  test("Sync ProcessAddonMessage handles SHAREKEYS from UTF-8 sender names", function()
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

      local umlautResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "SHAREKEYS", "Kürshad-Blackmoore", "Pinto", "Malfurion")
      local cyrillicResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "SHAREKEYS", "Кирилл-Гордунни", "Pinto", "Malfurion")

      Assert.NotNil(umlautResult, "UTF-8 umlaut SHAREKEYS sender must return a result")
      Assert.True(umlautResult.shouldShareKeys, "UTF-8 umlaut sender must trigger share-keys response")
      Assert.NotNil(cyrillicResult, "Cyrillic SHAREKEYS sender must return a result")
      Assert.True(cyrillicResult.shouldShareKeys, "Cyrillic sender must trigger share-keys response")
    end)
  end)

  test("Sync ProcessAddonMessage suppresses SHAREKEYS self-echo for UTF-8 names", function()
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

      local umlautResult =
        addon.Sync.ProcessAddonMessage("ISILIVE", "SHAREKEYS", "Kürshad-Blackmoore", "Kürshad", "Blackmoore")
      local cyrillicResult = addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "SHAREKEYS",
        "Кирилл-Гордунни",
        "Кирилл",
        "Гордунни"
      )

      Assert.NotNil(umlautResult, "UTF-8 umlaut self-echo must return a result")
      Assert.False(umlautResult.shouldShareKeys, "UTF-8 umlaut self-echo must not trigger a response")
      Assert.NotNil(cyrillicResult, "Cyrillic self-echo must return a result")
      Assert.False(cyrillicResult.shouldShareKeys, "Cyrillic self-echo must not trigger a response")
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

      -- Inside an instance (M+ key, dungeon, scenario) the WoW server delivers
      -- party addon messages on INSTANCE_CHAT rather than PARTY. Must accept.
      local instanceResult = addon.Sync.ProcessAddonMessage(
        "LibKS",
        "10,505,3050",
        "InstancePeer-OtherRealm",
        "MyPlayer",
        "Realm",
        "INSTANCE_CHAT"
      )
      Assert.NotNil(instanceResult, "INSTANCE_CHAT LibKeystone payloads must not be silently dropped")
      Assert.True(instanceResult.keyUpdated, "INSTANCE_CHAT key data must update sync state")
      local instanceKeyInfo = addon.Sync.GetPlayerKeyInfo("InstancePeer", "OtherRealm")
      Assert.NotNil(instanceKeyInfo, "INSTANCE_CHAT key info must be stored")
      Assert.Equal(instanceKeyInfo.level, 10, "INSTANCE_CHAT key level must be parsed")
      Assert.Equal(instanceKeyInfo.mapID, 505, "INSTANCE_CHAT key mapID must be parsed")
    end)
  end)

  test("Sync ProcessAddonMessage ignores LibKeystone payloads for kick state", function()
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

      local libKickResult = addon.Sync.ProcessAddonMessage(
        "LibKS",
        "KICK:0:0:S:119914",
        "OtherPlayer-OtherRealm",
        "MyPlayer",
        "Realm",
        "PARTY"
      )
      Assert.Nil(libKickResult, "LibKeystone payloads must not be interpreted as isiLive kick state")
      Assert.Nil(
        addon.Sync.GetPlayerKickInfo("OtherPlayer", "OtherRealm"),
        "LibKeystone interop must not create synthetic kick info for non-isiLive peers"
      )
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
end

local function RegisterProcessMessageSendTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Sync GetAddonSyncChannel returns nil in raid", function()
    WithGlobals({
      LE_PARTY_CATEGORY_INSTANCE = 1,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return true
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      Assert.Nil(addon.Sync.GetAddonSyncChannel(), "raid hard-off must suppress the addon sync channel")
    end)
  end)
  test("Sync GetAddonSyncChannel returns INSTANCE_CHAT for an instance group without home party", function()
    WithGlobals({
      LE_PARTY_CATEGORY_INSTANCE = 2,
      LE_PARTY_CATEGORY_HOME = 1,
      IsInGroup = function(category)
        return category == 2
      end,
      IsInRaid = function()
        return false
      end,
      UnitInParty = function()
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      Assert.Equal(addon.Sync.GetAddonSyncChannel(), "INSTANCE_CHAT", "instance group must use INSTANCE_CHAT")
    end)
  end)
  test("Sync GetAddonSyncChannel fails closed without verified party or instance group", function()
    WithGlobals({
      LE_PARTY_CATEGORY_INSTANCE = 2,
      LE_PARTY_CATEGORY_HOME = 1,
      IsInGroup = function(category)
        return category == nil
      end,
      IsInRaid = function()
        return false
      end,
      UnitInParty = function()
        return false
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      Assert.Nil(addon.Sync.GetAddonSyncChannel(), "unverified group must not synthesize PARTY")
    end)
  end)
  test("Sync SendHello respects cooldown and force bypass", function()
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
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendHello({
        isVisible = true,
        version = "1.0",
        protocolVersion = 2,
        source = "local",
      })
      Assert.Equal(#sentMessages, 1, "first hello must publish once")
      Assert.Equal(
        sentMessages[1].message,
        "HELLO:1.0:2:100:local",
        "hello payload must encode version, protocol, timestamp, and source"
      )

      now = 101
      addon.Sync.SendHello({
        isVisible = true,
        version = "1.0",
        protocolVersion = 2,
        source = "local",
      })
      Assert.Equal(#sentMessages, 1, "duplicate hello within cooldown must be suppressed")

      now = 109
      addon.Sync.SendHello({
        isVisible = true,
        version = "1.0",
        protocolVersion = 2,
        source = "local",
      })
      Assert.Equal(#sentMessages, 2, "hello must resend after cooldown expires")
      Assert.Equal(sentMessages[2].message, "HELLO:1.0:2:109:local", "resend must refresh hello timestamp")

      now = 110
      addon.Sync.SendHello({
        force = true,
        isVisible = true,
        version = "1.0",
        protocolVersion = 2,
        source = "local",
      })
      Assert.Equal(#sentMessages, 3, "forced hello must bypass the cooldown")
      Assert.Equal(sentMessages[3].message, "HELLO:1.0:2:110:local", "forced hello must still encode current metadata")
    end)
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
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result = addon.Sync.SendShareKeysRequest()

      Assert.True(result, "share-keys request should report success when the addon sync message is sent")
      Assert.Equal(#sentMessages, 1, "share-keys request should publish one addon message")
      Assert.Equal(sentMessages[1].message, "SHAREKEYS", "share-keys request must use SHAREKEYS payload")
    end)
  end)

  test("Sync SendShareKeysRequest returns false without an addon sync channel", function()
    local sentMessages = {}

    WithGlobals({
      IsInGroup = function(_category)
        return false
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

      local result = addon.Sync.SendShareKeysRequest()

      Assert.False(result, "share-keys request must report failure when no addon sync channel exists")
      Assert.Equal(#sentMessages, 0, "share-keys request must not publish without an addon sync channel")
    end)
  end)

  test("Sync SendShareKeysRequest does not publish in raid", function()
    local sentMessages = {}

    WithGlobals({
      LE_PARTY_CATEGORY_INSTANCE = 1,
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return true
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result = addon.Sync.SendShareKeysRequest()

      Assert.False(result, "share-keys request must report failure in raid")
      Assert.Equal(#sentMessages, 0, "share-keys request must not publish in raid")
    end)
  end)

  test("Sync SendShareKeysRequest returns false when addon message dispatch fails", function()
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
          return false
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result = addon.Sync.SendShareKeysRequest()

      Assert.False(result, "share-keys request must report failure when the addon message dispatch fails")
      Assert.Equal(#sentMessages, 1, "share-keys request should still attempt one addon message dispatch")
      Assert.Equal(sentMessages[1].message, "SHAREKEYS", "failed dispatch must still carry the SHAREKEYS payload")
    end)
  end)

  test("Sync SendPowerInfusionAnnounce sends verified PI payload", function()
    local sentMessages = {}

    WithGlobals({
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel, priority)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
            priority = priority,
          })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendPowerInfusionAnnounce({
        caster = "Priest-Realm",
        recipient = "Target-Realm",
        spellID = 10060,
      })
      addon.Sync.SendPowerInfusionAnnounce({
        caster = "Priest-Realm",
        recipient = "",
        spellID = 10060,
      })
      addon.Sync.SendPowerInfusionAnnounce({
        caster = "Priest-Realm",
        recipient = "Target-Realm",
        spellID = 123,
      })

      Assert.Equal(#sentMessages, 1, "only the verified PI payload should be sent")
      Assert.Equal(sentMessages[1].prefix, "ISILIVE", "PI announce must use the isiLive prefix")
      Assert.Equal(
        sentMessages[1].message,
        "PI:Priest-Realm:Target-Realm:10060",
        "PI announce must carry caster and recipient"
      )
      Assert.Equal(sentMessages[1].channel, "PARTY", "PI announce must use the addon sync channel")
    end)
  end)

  test("Sync SendShareKeysCooldown publishes SKCD with ceiled and clamped remain", function()
    local sentMessages = {}

    WithGlobals({
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      GetTime = function()
        return 100
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local result = addon.Sync.SendShareKeysCooldown({ remain = 12.4 })
      Assert.True(result, "share-keys cooldown send should report success")
      Assert.Equal(#sentMessages, 1, "share-keys cooldown should publish one addon message")
      Assert.Equal(sentMessages[1].prefix, "ISILIVE", "share-keys cooldown must use the ISILIVE prefix")
      Assert.Equal(sentMessages[1].message, "SKCD:13", "fractional remain must be ceiled to whole seconds")

      local blocked = addon.Sync.SendShareKeysCooldown({ remain = 20 })
      Assert.False(blocked, "second send within the 1s rate limit must be suppressed")
      Assert.Equal(#sentMessages, 1, "rate-limited send must not publish a second message")

      local clamped = addon.Sync.SendShareKeysCooldown({ remain = 999, force = true })
      Assert.True(clamped, "forced send must bypass the rate limit")
      Assert.Equal(sentMessages[2].message, "SKCD:30", "remain must be clamped to the 30s debounce window")
    end)
  end)

  test("Sync SendShareKeysCooldown returns false for invalid remain or missing channel", function()
    local sentMessages = {}

    WithGlobals({
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      GetTime = function()
        return 100
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, {
            prefix = prefix,
            message = message,
            channel = channel,
          })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      Assert.False(addon.Sync.SendShareKeysCooldown({ remain = 0 }), "remain=0 must not publish")
      Assert.False(addon.Sync.SendShareKeysCooldown({ remain = -5 }), "negative remain must not publish")
      Assert.False(addon.Sync.SendShareKeysCooldown({}), "missing remain must not publish")
      Assert.Equal(#sentMessages, 0, "invalid remain must never reach the wire")
    end)

    WithGlobals({
      IsInGroup = function(_category)
        return false
      end,
      IsInRaid = function()
        return false
      end,
      GetTime = function()
        return 100
      end,
      C_ChatInfo = {
        SendAddonMessage = function(_prefix, _message, _channel)
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      Assert.False(addon.Sync.SendShareKeysCooldown({ remain = 10 }), "no group channel must suppress the send")
    end)
  end)

  test("Sync ProcessAddonMessage mirrors SKCD payloads with clamping", function()
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

      local result = addon.Sync.ProcessAddonMessage("ISILIVE", "SKCD:25", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")
      Assert.NotNil(result, "SKCD must return a result")
      Assert.Equal(result.shareKeysCooldownRemain, 25, "SKCD remain must be mirrored verbatim")
      Assert.False(result.shouldShareKeys, "SKCD must not trigger a share-keys chat response")

      local clamped =
        addon.Sync.ProcessAddonMessage("ISILIVE", "SKCD:999", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")
      Assert.Equal(clamped.shareKeysCooldownRemain, 30, "oversized SKCD remain must be clamped to 30s")

      local zero = addon.Sync.ProcessAddonMessage("ISILIVE", "SKCD:0", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")
      Assert.Nil(zero.shareKeysCooldownRemain, "SKCD remain 0 must be ignored")

      local garbage =
        addon.Sync.ProcessAddonMessage("ISILIVE", "SKCD:abc", "OtherPlayer-OtherRealm", "MyPlayer", "Realm")
      Assert.Nil(garbage.shareKeysCooldownRemain, "non-numeric SKCD remain must be ignored")
    end)
  end)

  test("Sync ProcessAddonMessage suppresses SKCD self-echo", function()
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

      local result = addon.Sync.ProcessAddonMessage("ISILIVE", "SKCD:25", "MyPlayer-Realm", "MyPlayer", "Realm")
      Assert.NotNil(result, "SKCD self-echo must still return a result")
      Assert.Nil(result.shareKeysCooldownRemain, "SKCD self-echo must not mirror the own cooldown back")
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
          return true
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

  test("Sync SendLibKeystoneRequest reports rejected dispatch and does not start throttle", function()
    local sentMessages = {}
    local now = 100
    local allowSend = false

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
          if not allowSend then
            return false
          end
          table.insert(sentMessages, { prefix = prefix, message = message, channel = channel })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local rejected = addon.Sync.SendLibKeystoneRequest()
      Assert.False(rejected, "rejected LibKeystone request dispatch must report false")
      Assert.Equal(#sentMessages, 0, "rejected LibKeystone request must not publish")

      allowSend = true
      now = 100.1
      local retry = addon.Sync.SendLibKeystoneRequest()
      Assert.True(retry, "LibKeystone request must retry immediately after dispatch rejection")
      Assert.Equal(#sentMessages, 1, "retry after rejected LibKeystone request must publish once")
      Assert.Equal(sentMessages[1].message, "R", "LibKeystone retry must keep the request payload")
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
          return true
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

  test("Sync SendLibKeystonePartyData reports rejected dispatch", function()
    WithGlobals({
      IsInGroup = function(_category)
        return true
      end,
      IsInRaid = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(_prefix, _message, _channel)
          return false
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      local sent = addon.Sync.SendLibKeystonePartyData({
        mapID = 505,
        level = 17,
        rio = 3333,
      })

      Assert.False(sent, "rejected LibKeystone party data dispatch must report false")
    end)
  end)

  test("Sync SendLibKeystoneRequest routes to INSTANCE_CHAT inside an instance group", function()
    local sentMessages = {}

    WithGlobals({
      GetTime = function()
        return 200
      end,
      LE_PARTY_CATEGORY_INSTANCE = 2,
      LE_PARTY_CATEGORY_HOME = 1,
      IsInGroup = function(category)
        return category == 2
      end,
      IsInRaid = function()
        return false
      end,
      UnitInParty = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, { prefix = prefix, message = message, channel = channel })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      addon.Sync.SendLibKeystoneRequest({ force = true })
      Assert.Equal(#sentMessages, 1, "request must send")
      Assert.Equal(
        sentMessages[1].channel,
        "INSTANCE_CHAT",
        "LibKeystone request must use INSTANCE_CHAT inside an instance group"
      )
    end)
  end)

  test("Sync SendLibKeystonePartyData routes to INSTANCE_CHAT inside an instance group", function()
    local sentMessages = {}

    WithGlobals({
      LE_PARTY_CATEGORY_INSTANCE = 2,
      LE_PARTY_CATEGORY_HOME = 1,
      IsInGroup = function(category)
        return category == 2
      end,
      IsInRaid = function()
        return false
      end,
      UnitInParty = function()
        return false
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, { prefix = prefix, message = message, channel = channel })
          return true
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      addon.Sync.SendLibKeystonePartyData({ mapID = 505, level = 17, rio = 3333 })
      Assert.Equal(#sentMessages, 1, "party data must send")
      Assert.Equal(
        sentMessages[1].channel,
        "INSTANCE_CHAT",
        "LibKeystone party data must use INSTANCE_CHAT inside an instance group"
      )
    end)
  end)
end

local function RegisterProcessMessageTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterProcessMessageReceiveTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterProcessMessageSendTests(test, Assert, WithGlobals, LoadAddonModules)
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

      now = 112
      addon.Sync.SendTarget({
        isVisible = true,
        mapID = 2441,
        level = nil,
        levelText = "|Kk584|k",
      })
      Assert.Equal(#sentMessages, 3, "verified Blizzard level markup must publish as changed target detail")
      Assert.Equal(
        sentMessages[3].message,
        "TARGET:2441:0:112:local:LT:|Kk584|k",
        "levelText must serialize only as verified opaque Blizzard keystone markup"
      )

      now = 118
      addon.Sync.SendTarget({
        isVisible = true,
        mapID = 2441,
        level = nil,
        levelText = "+14 freeform",
      })
      Assert.Equal(#sentMessages, 4, "dropping invalid levelText must still publish the changed target detail")
      Assert.Equal(
        sentMessages[4].message,
        "TARGET:2441:0:118:local",
        "free-form levelText must not be serialized into TARGET sync"
      )
    end)
  end)
end

local function RegisterChatThrottleLibRoutingTests(test, Assert, WithGlobals, LoadAddonModules)
  local function SetupRoutingGlobals(ctlMessages, fallbackMessages)
    return {
      GetTime = function()
        return 100
      end,
      IsInGroup = function()
        return true
      end,
      IsInRaid = function()
        return false
      end,
      ChatThrottleLib = ctlMessages and {
        SendAddonMessage = function(_self, priority, prefix, text, chattype)
          table.insert(ctlMessages, { priority = priority, prefix = prefix, text = text, chattype = chattype })
        end,
      } or nil,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          if fallbackMessages then
            table.insert(fallbackMessages, { prefix = prefix, message = message, channel = channel })
          end
          return true
        end,
      },
    }
  end

  test("Sync routes send through ChatThrottleLib with correct priority per message type", function()
    local ctlMessages = {}
    WithGlobals(SetupRoutingGlobals(ctlMessages, nil), function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendKick({ hasKick = true, onCooldown = false, cooldownRemain = 0 })
      addon.Sync.SendStats({ isVisible = true, specID = 72, ilvl = 615, rio = 3210 })
      addon.Sync.SendKey({ isVisible = true, mapID = 2649, level = 14 })
      addon.Sync.SendDps({ isVisible = true, dps = 100000 })
      addon.Sync.SendLoc({ isVisible = true, mapID = 2649 })
      addon.Sync.SendTarget({ isVisible = true, mapID = 2649, level = 14 })
      addon.Sync.SendRefreshRequest({ force = true })
      addon.Sync.SendShareKeysRequest()
      addon.Sync.SendHello({ force = true, version = "0.9.175", protocolVersion = 2, source = "test" })

      local byKind = {}
      for _, m in ipairs(ctlMessages) do
        byKind[m.text:match("^(%a+)") or m.text] = m
      end

      Assert.Equal(byKind["KICK"].priority, "ALERT", "KICK must use ALERT priority")
      Assert.Equal(byKind["REQSYNC"].priority, "ALERT", "REQSYNC must use ALERT priority")
      Assert.Equal(byKind["SHAREKEYS"].priority, "ALERT", "SHAREKEYS must use ALERT priority")
      Assert.Equal(byKind["STATS"].priority, "BULK", "STATS must use BULK priority")
      Assert.Equal(byKind["DPS"].priority, "BULK", "DPS must use BULK priority")
      Assert.Equal(byKind["LOC"].priority, "BULK", "LOC must use BULK priority")
      Assert.Equal(byKind["KEY"].priority, "NORMAL", "KEY must use NORMAL priority")
      Assert.Equal(byKind["TARGET"].priority, "NORMAL", "TARGET must use NORMAL priority")
      Assert.Equal(byKind["HELLO"].priority, "NORMAL", "HELLO must use NORMAL priority")
    end)
  end)

  test("Sync falls back to raw C_ChatInfo.SendAddonMessage when ChatThrottleLib is absent", function()
    local fallbackMessages = {}
    WithGlobals(SetupRoutingGlobals(nil, fallbackMessages), function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SendKick({ hasKick = true, onCooldown = false, cooldownRemain = 0 })

      Assert.Equal(#fallbackMessages, 1, "send without ChatThrottleLib must dispatch via C_ChatInfo")
      Assert.Equal(fallbackMessages[1].prefix, "ISILIVE", "fallback dispatch must use isiLive prefix")
      Assert.True(fallbackMessages[1].message:match("^KICK:") ~= nil, "fallback dispatch must carry kick payload")
    end)
  end)

  test("ChatThrottleLib drops queued INSTANCE_CHAT addon messages after instance group leave", function()
    local sentMessages = {}
    local callbackDidSend = nil
    local inInstanceGroup = true

    WithGlobals({
      ChatThrottleLib = false,
      LE_PARTY_CATEGORY_INSTANCE = 2,
      GetTime = function()
        return 100
      end,
      GetFramerate = function()
        return 60
      end,
      IsInGroup = function(category)
        if category == 2 then
          return inInstanceGroup
        end
        return inInstanceGroup
      end,
      UnitInRaid = function()
        return false
      end,
      UnitInParty = function()
        return inInstanceGroup
      end,
      hooksecurefunc = function() end,
      wipe = function(t)
        for key in pairs(t) do
          t[key] = nil
        end
      end,
      unpack = rawget(table, "unpack"),
      CreateFrame = function()
        return {
          SetScript = function() end,
          RegisterEvent = function() end,
          Show = function() end,
          Hide = function() end,
        }
      end,
      C_ChatInfo = {
        SendAddonMessage = function(prefix, message, channel)
          table.insert(sentMessages, { prefix = prefix, message = message, channel = channel })
          return true
        end,
      },
    }, function()
      LoadAddonModules({ "ChatThrottleLib.lua" })

      local ctl = Assert.NotNil(rawget(_G, "ChatThrottleLib"), "ChatThrottleLib must load into globals")
      ctl.bQueueing = true
      ctl:SendAddonMessage(
        "NORMAL",
        "ISILIVE",
        "HELLO:0.9.293",
        "INSTANCE_CHAT",
        nil,
        "leave-test",
        function(_, didSend)
          callbackDidSend = didSend
        end
      )

      inInstanceGroup = false
      ctl.Prio.NORMAL.avail = 1000
      ctl:Despool(ctl.Prio.NORMAL)

      Assert.Equal(#sentMessages, 0, "queued INSTANCE_CHAT send must be dropped after instance group leave")
      Assert.Equal(callbackDidSend, false, "ChatThrottleLib callback must report that the queued send was dropped")
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
          return true
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
          return true
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
  RegisterSyncRuntimeLogBurstTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterStatsSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterKeySyncStatsTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterProcessMessageTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterDpsLocSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterChatThrottleLibRoutingTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterSyncResetTests(test, Assert, WithGlobals, LoadAddonModules)
end
