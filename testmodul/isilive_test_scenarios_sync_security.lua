---@diagnostic disable: undefined-global

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Sync ProcessAddonMessage rejects untrusted ISILIVE receive channels", function()
    WithGlobals({
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      local whisperedKey =
        addon.Sync.ProcessAddonMessage("ISILIVE", "KEY:2649:15", "Peer-Realm", "MyPlayer", "Realm", "WHISPER")
      Assert.Nil(whisperedKey, "state payloads must not be accepted by whisper")
      local raidHello =
        addon.Sync.ProcessAddonMessage("ISILIVE", "HELLO:1.0", "Peer-Realm", "MyPlayer", "Realm", "RAID")
      Assert.Nil(raidHello, "ISILIVE group protocol must not be accepted from raid channel")
      local whisperedAck =
        addon.Sync.ProcessAddonMessage("ISILIVE", "ACK:1.0", "Peer-Realm", "MyPlayer", "Realm", "WHISPER")
      Assert.NotNil(whisperedAck, "the explicit HELLO acknowledgement remains whisper-compatible")
    end)
  end)

  test("Sync ProcessAddonMessage rejects spoofed announce casters", function()
    WithGlobals({
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      local spoofedCombat = addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "BRLUST:BR:Victim-Realm:20484",
        "Attacker-Realm",
        "MyPlayer",
        "Realm",
        "PARTY"
      )
      Assert.Nil(spoofedCombat.combatAnnounce, "BR/Lust caster must match the authenticated message sender")
      local spoofedPi = addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "PI:Victim-Realm:MyPlayer-Realm:10060",
        "Attacker-Realm",
        "MyPlayer",
        "Realm",
        "PARTY"
      )
      Assert.Nil(spoofedPi.powerInfusionAnnounce, "PI caster must match the authenticated message sender")
    end)
  end)

  test("Sync ProcessAddonMessage rejects non-finite numeric payloads without dispatch errors", function()
    WithGlobals({
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      local valid =
        addon.Sync.ProcessAddonMessage("ISILIVE", "KEY:2649:15:123:peer", "Peer-Realm", "MyPlayer", "Realm", "PARTY")
      Assert.True(valid.keyUpdated, "precondition must store a valid peer key")
      local ok, result = pcall(
        addon.Sync.ProcessAddonMessage,
        "ISILIVE",
        "KEY:1e309:1e309:1e309:peer",
        "Peer-Realm",
        "MyPlayer",
        "Realm",
        "PARTY"
      )
      Assert.True(ok, "non-finite numeric wire values must not throw")
      Assert.False(result.keyUpdated, "non-finite key values must not update state")
      local retained = addon.Sync.GetPlayerKeyInfo("Peer", "Realm")
      Assert.NotNil(retained, "non-finite key values must not clear prior verified state")
      Assert.Equal(retained.mapID, 2649, "prior verified map must remain unchanged")
      Assert.Equal(retained.level, 15, "prior verified level must remain unchanged")

      local nonFiniteHello = addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "HELLO:1.0:2:1e309:peer",
        "Infinite-Realm",
        "MyPlayer",
        "Realm",
        "PARTY"
      )
      Assert.False(nonFiniteHello.shouldAck, "non-finite HELLO metadata must not trigger a reply")
      Assert.Nil(addon.Sync.GetPlayerHelloInfo("Infinite", "Realm"), "non-finite HELLO metadata must not be stored")
    end)
  end)
end
