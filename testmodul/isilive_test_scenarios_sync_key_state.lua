---@diagnostic disable: undefined-global

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
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
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
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
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
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
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
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
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
      IsInGroup = function(category)
        -- Home party only. The instance category must answer false, otherwise
        -- this stub describes a player in a home party AND an instance group
        -- at once, for which INSTANCE_CHAT is the correct channel.
        return category ~= 2
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

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterStatsSyncTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterKeySyncStatsTests(test, Assert, WithGlobals, LoadAddonModules)
end
