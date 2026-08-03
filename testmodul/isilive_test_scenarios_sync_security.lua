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

  test("Sync strips UI markup and caps length in peer addon version strings", function()
    WithGlobals({
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      -- A modified peer client can put anything in the HELLO version field.
      -- The roster tooltip renders it verbatim, so WoW escape sequences must
      -- not survive being stored.
      addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "HELLO:|cffff0000EVIL|r:1:100:hello",
        "Markup-Realm",
        "MyPlayer",
        "Realm",
        "PARTY"
      )
      local markupInfo = addon.Sync.GetPlayerHelloInfo("Markup", "Realm")
      Assert.NotNil(markupInfo, "a HELLO with a markup version must still register the peer")
      Assert.True(
        markupInfo.addonVersion:find("|", 1, true) == nil,
        "stored addon version must not keep the WoW escape pipe"
      )
      Assert.Equal(markupInfo.addonVersion, "cffff0000EVILr", "markup characters must be stripped, text kept")

      -- Texture escapes are the other rendering vector.
      addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "HELLO:|TInterfaceIconsINV_Misc_Bomb_01|t:1:100:hello",
        "Texture-Realm",
        "MyPlayer",
        "Realm",
        "PARTY"
      )
      local textureInfo = addon.Sync.GetPlayerHelloInfo("Texture", "Realm")
      Assert.NotNil(textureInfo, "a HELLO with a texture version must still register the peer")
      Assert.True(
        textureInfo.addonVersion:find("|", 1, true) == nil,
        "stored addon version must not keep texture escape pipes"
      )

      -- A long version string must not be able to stretch the tooltip line.
      addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "HELLO:" .. string.rep("9", 120) .. ":1:100:hello",
        "Longver-Realm",
        "MyPlayer",
        "Realm",
        "PARTY"
      )
      local longInfo = addon.Sync.GetPlayerHelloInfo("Longver", "Realm")
      Assert.NotNil(longInfo, "a HELLO with an overlong version must still register the peer")
      Assert.True(#longInfo.addonVersion <= 32, "stored addon version must be capped at 32 characters")

      -- Ordinary SemVer must pass through untouched.
      addon.Sync.ProcessAddonMessage(
        "ISILIVE",
        "HELLO:0.9.366:1:100:hello",
        "Plain-Realm",
        "MyPlayer",
        "Realm",
        "PARTY"
      )
      local plainInfo = addon.Sync.GetPlayerHelloInfo("Plain", "Realm")
      Assert.NotNil(plainInfo, "a plain HELLO must register the peer")
      Assert.Equal(plainInfo.addonVersion, "0.9.366", "a normal SemVer version must survive normalization unchanged")
    end)
  end)
end
