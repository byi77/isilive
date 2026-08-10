return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  -- Display sanity bounds. Without them a broken or hostile peer can publish a
  -- key level or rating up to MAX_SAFE_INTEGER, which renders straight into
  -- everyone's roster and blows up the column layout. Out-of-range values are
  -- treated as unresolved rather than clamped: a clamped number would be a
  -- fabricated value, which the no-guess contract forbids.
  test("Sync rejects out-of-range key levels instead of publishing them", function()
    WithGlobals({
      strsplit = function(_sep, str, _max)
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      Assert.True(addon.Sync.SetPlayerKeyInfo("Player", "Realm", 2649, 500), "an in-range key level must be stored")
      Assert.Equal(addon.Sync.GetPlayerKeyInfo("Player", "Realm").level, 500, "in-range level must survive")

      addon.Sync.SetPlayerKeyInfo("Player", "Realm", 2649, 9007199254740991)
      Assert.Equal(addon.Sync.GetPlayerKeyInfo("Player", "Realm"), nil, "an absurd key level must clear, not render")
    end)
  end)

  test("Sync rejects out-of-range ilvl and rating instead of publishing them", function()
    WithGlobals({
      strsplit = function(_sep, str, _max)
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      addon.Sync.SetPlayerStatsInfo("Player", "Realm", 250, 9007199254740991, 3000)
      local stats = addon.Sync.GetPlayerStatsInfo("Player", "Realm")
      Assert.Equal(stats.ilvl, nil, "an absurd item level must stay unresolved")
      Assert.Equal(stats.rio, 3000, "the in-range rating alongside it must still be kept")

      addon.Sync.SetPlayerStatsInfo("Other", "Realm", 250, 640, 9007199254740991)
      local otherStats = addon.Sync.GetPlayerStatsInfo("Other", "Realm")
      Assert.Equal(otherStats.rio, nil, "an absurd rating must stay unresolved")
      Assert.Equal(otherStats.ilvl, 640, "the in-range item level alongside it must still be kept")
    end)
  end)

  -- TARGET carries a key level just like KEY does, and it renders straight into
  -- the kill row as "+<level>". It was left out when the KEY/STATS bounds were
  -- added, so it accepted any positive number up to MAX_SAFE_INTEGER.
  test("Sync rejects out-of-range target key levels instead of publishing them", function()
    WithGlobals({
      strsplit = function(_sep, str, _max)
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      Assert.True(
        addon.Sync.SetPlayerTargetInfo("Player", "Realm", 2649, 500),
        "an in-range target key level must be stored"
      )
      Assert.Equal(addon.Sync.GetPlayerTargetInfo("Player", "Realm").level, 500, "in-range target level must survive")

      addon.Sync.SetPlayerTargetInfo("Other", "Realm", 2649, 9007199254740991)
      local target = addon.Sync.GetPlayerTargetInfo("Other", "Realm")
      Assert.NotNil(target, "the target entry itself must survive: the map id is still valid")
      Assert.Equal(target.mapID, 2649, "the in-range map id alongside it must still be kept")
      Assert.Equal(target.level, nil, "an absurd target key level must stay unresolved, not render")
    end)
  end)

  -- DPS renders into the roster's DPS column. Unlike ilvl/rio it had no upper
  -- bound at all, so a broken or hostile peer could publish MAX_SAFE_INTEGER.
  test("Sync rejects out-of-range dps instead of publishing it", function()
    WithGlobals({
      strsplit = function(_sep, str, _max)
        return str
      end,
      GetRealmName = function()
        return "Realm"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_sync.lua" })

      Assert.True(addon.Sync.SetPlayerDpsInfo("Player", "Realm", 1500000), "an in-range dps value must be stored")
      Assert.Equal(addon.Sync.GetPlayerDpsInfo("Player", "Realm").dps, 1500000, "in-range dps must survive")

      addon.Sync.SetPlayerDpsInfo("Other", "Realm", 9007199254740991)
      Assert.Equal(addon.Sync.GetPlayerDpsInfo("Other", "Realm"), nil, "an absurd dps value must clear, not render")
    end)
  end)
end
