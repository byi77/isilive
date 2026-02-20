---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Sync NormalizePlayerKey extracts name and realm correctly", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local parts = {}
        local pattern = "([^" .. sep .. "]*)"
        local count = 0
        for part in str:gmatch(pattern) do
          count = count + 1
          table.insert(parts, part)
          if max and count >= max then break end
        end
        return unpack(parts)
      end,
      GetRealmName = function() return "FallbackRealm" end,
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
        if not pos then return str end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str:sub(1, pos - 1)
      end,
      GetRealmName = function() return "FallbackRealm" end,
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
      GetRealmName = function() return "MyRealm" end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })
      local key = addon.Sync.NormalizePlayerKey("Solo", "")

      Assert.NotNil(key, "key must not be nil for empty realm")
      Assert.True(key:find("solo") ~= nil, "key must contain player name")
      Assert.True(key:find("myrealm") ~= nil, "key must use GetRealmName fallback")
    end)
  end)

  test("Sync MarkUser and IsUserKnown track players", function()
    WithGlobals({
      strsplit = function(_sep, str, _max) return str end,
      GetRealmName = function() return "Realm" end,
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
      strsplit = function(_sep, str, _max) return str end,
      GetRealmName = function() return "Realm" end,
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

  test("Sync ProcessAddonMessage handles HELLO and KEY payloads", function()
    WithGlobals({
      strsplit = function(sep, str, max)
        local pos = str:find(sep, 1, true)
        if not pos then return str end
        if max and max >= 2 then
          return str:sub(1, pos - 1), str:sub(pos + 1)
        end
        return str:sub(1, pos - 1)
      end,
      GetRealmName = function() return "Realm" end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      -- Test HELLO from another player
      local helloResult = addon.Sync.ProcessAddonMessage(
        "ISILIVE", "HELLO:0.9.36", "OtherPlayer-OtherRealm", "MyPlayer", "Realm"
      )
      Assert.NotNil(helloResult, "HELLO must return result")
      Assert.True(helloResult.shouldAck, "HELLO from different player must require ack")

      -- Test HELLO from self (should not ack)
      local selfResult = addon.Sync.ProcessAddonMessage(
        "ISILIVE", "HELLO:0.9.36", "MyPlayer-Realm", "MyPlayer", "Realm"
      )
      Assert.NotNil(selfResult, "self HELLO must return result")
      Assert.False(selfResult.shouldAck, "HELLO from self must not require ack")

      -- Test KEY message
      local keyResult = addon.Sync.ProcessAddonMessage(
        "ISILIVE", "KEY:2649:15", "OtherPlayer-OtherRealm", "MyPlayer", "Realm"
      )
      Assert.NotNil(keyResult, "KEY must return result")
      Assert.True(keyResult.keyUpdated, "first KEY must report update")

      -- Test wrong prefix is ignored
      local wrongPrefix = addon.Sync.ProcessAddonMessage(
        "WRONGPREFIX", "HELLO:1.0", "Someone-Realm", "MyPlayer", "Realm"
      )
      Assert.Nil(wrongPrefix, "wrong prefix must return nil")
    end)
  end)
end
