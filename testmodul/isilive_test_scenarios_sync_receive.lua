---@diagnostic disable: undefined-global

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

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterProcessMessageReceiveTests(test, Assert, WithGlobals, LoadAddonModules)
end
