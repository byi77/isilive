---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert

  -- Fallback fixture outside every season: challenge map 9588 -> instance
  -- 2900 -> journal instance 1300, entrance pin on zone 2400 ("Testzone").
  local function WithMaps(overrides, callback)
    local calls = { scans = 0, entrances = 0 }
    local maps = {
      [2400] = { mapID = 2400, name = "Testzone", mapType = 3, parentMapID = 2300 },
      [2300] = { mapID = 2300, name = "Kontinent", mapType = 2, parentMapID = 946 },
      [2401] = { mapID = 2401, name = "Altar innen", mapType = 4, parentMapID = 2400 },
      [2500] = { mapID = 2500, name = "Andere Zone", mapType = 3, parentMapID = 2300 },
      [2509] = overrides.coiledIsle,
      [2266] = overrides.hub,
    }
    local entrancesByZone = {
      [2400] = { { journalInstanceID = 1300, position = { x = 0.375, y = 0.4 } } },
      [2500] = { { journalInstanceID = 999, position = { x = 0.1, y = 0.1 } } },
    }
    local globals = {
      C_ChallengeMode = {
        GetMapUIInfo = function(mapID)
          if mapID == 9588 then
            return "Altar", 9588, 1800, nil, nil, 2900
          end
          return nil
        end,
      },
      C_EncounterJournal = {
        GetInstanceForGameMap = function(instanceID)
          return instanceID == 2900 and 1300 or nil
        end,
        GetDungeonEntrancesForMap = function(zoneMapID)
          calls.entrances = calls.entrances + 1
          return entrancesByZone[zoneMapID] or {}
        end,
      },
      EJ_GetInstanceInfo = function()
        calls.instanceInfo = (calls.instanceInfo or 0) + 1
        return "Altar", "", 0, overrides.buttonImage or 0, overrides.loreImage or 0, 0, overrides.dungeonAreaMapID or 0
      end,
      C_Map = {
        GetMapInfo = function(uiMapID)
          return maps[uiMapID]
        end,
        GetMapChildrenInfo = function(rootMapID, mapType, allDescendants)
          calls.scans = calls.scans + 1
          Assert.Equal(rootMapID, 946)
          Assert.Equal(mapType, 3)
          Assert.True(allDescendants)
          return { maps[2500], maps[2400] }
        end,
      },
    }
    for key, value in pairs(overrides.globals or {}) do
      globals[key] = value
    end
    ctx.with_globals(globals, function()
      local addon = ctx.load_modules({ "isiLive_dungeon_location.lua" })
      callback(addon.DungeonLocation, calls, entrancesByZone, addon)
    end)
  end

  test("Dungeon location scans zone entrances when the journal has no dungeon area map", function()
    WithMaps({}, function(location, calls)
      Assert.Equal(location.GetNavigationText(9588), "Testzone")
      Assert.Equal(calls.scans, 1)
      -- The dungeon -> zone mapping is static and cached.
      Assert.Equal(location.GetNavigationText(9588), "Testzone")
      Assert.Equal(calls.scans, 1)
    end)
  end)

  test("Dungeon location uses the parent zone of the dungeon area map first", function()
    WithMaps({ dungeonAreaMapID = 2401 }, function(location, calls)
      Assert.Equal(location.GetNavigationText(9588), "Testzone")
      Assert.Equal(calls.scans, 0)
      Assert.Equal(calls.entrances, 1)
    end)
  end)

  test("Dungeon location keeps the parent zone without coordinates when no entrance pin exists", function()
    WithMaps({ dungeonAreaMapID = 2401 }, function(location, _, entrancesByZone)
      entrancesByZone[2400] = {}
      Assert.Equal(location.GetNavigationText(9588), "Testzone")
    end)
  end)

  test("Dungeon location stays unresolved for unknown, masked or failing data", function()
    WithMaps({}, function(location, _, entrancesByZone)
      Assert.Nil(location.GetNavigationText(nil))
      Assert.Nil(location.GetNavigationText(-1))
      Assert.Nil(location.GetNavigationText(123))
      entrancesByZone[2400] = {}
      Assert.Nil(location.GetNavigationText(9588))
    end)
    WithMaps({
      globals = {
        C_EncounterJournal = {
          GetInstanceForGameMap = function()
            error("unavailable")
          end,
        },
      },
    }, function(location)
      Assert.Nil(location.GetNavigationText(9588))
    end)
    WithMaps({}, function(location, _, entrancesByZone, addon)
      local secret = {}
      addon.Validators.IsSecretValue = function(value)
        return value == secret
      end
      entrancesByZone[2400] = { { journalInstanceID = secret } }
      Assert.Nil(location.GetNavigationText(9588))
    end)
  end)

  test("Dungeon location zone and portal room follow the addon language, not the client", function()
    local db = { locale = "enUS" }
    WithMaps({
      hub = { mapID = 2266, name = "Die Jahrhundertschwelle", mapType = 3 },
      coiledIsle = { mapID = 2509, name = "Die Gewundene Insel", mapType = 3 },
      globals = {
        IsiLiveDB = db,
        GetLocale = function()
          return "deDE"
        end,
      },
    }, function(location, _, _, addon)
      addon.UICommon = {
        ResolveActiveLocale = function()
          return db.locale
        end,
      }
      Assert.Equal(location.GetNavigationText(588), "The Coiled Isle")
      Assert.Equal(location.GetPortalRoomName(399), "Millennia's Threshold")
      db.locale = "deDE"
      Assert.Equal(location.GetNavigationText(588), "Die Gewundene Insel", "the name must not be cached per language")
      Assert.Equal(location.GetPortalRoomName(399), "Die Jahrhundertschwelle")
    end)
  end)

  test("Dungeon location uses the curated season entrance with the client zone name", function()
    WithMaps({
      coiledIsle = { mapID = 2509, name = "Die Gewundene Insel", mapType = 3 },
      globals = {
        GetLocale = function()
          return "deDE"
        end,
      },
    }, function(location, calls)
      Assert.Equal(location.GetNavigationText(588), "Die Gewundene Insel")
      Assert.Equal(calls.scans, 0)
      Assert.Equal(calls.entrances, 0)
    end)
    WithMaps({}, function(location)
      Assert.Equal(location.GetNavigationText(588), "The Coiled Isle")
    end)
    WithMaps({
      globals = {
        GetLocale = function()
          return "deDE"
        end,
      },
    }, function(location)
      Assert.Equal(location.GetNavigationText(588), "Die gewundene Insel")
      -- Locales without a manifest name fall back to English.
      Assert.Equal(location.GetNavigationText(586), "Zul'Aman")
    end)
  end)

  test("Dungeon location has a valid curated entrance for every active season dungeon", function()
    WithMaps({}, function(_, _, _, addon)
      local seasonData = addon.SeasonData
      local season = seasonData.GetSeasonConfig()
      Assert.Equal(#season.manifestErrors, 0)
      for _, mapID in ipairs(seasonData.GetOrderedMapIDs()) do
        local entrance = seasonData.GetDungeonEntrance(mapID)
        Assert.NotNil(entrance, "missing entrance for mapID " .. tostring(mapID))
        Assert.True(entrance.uiMapID > 0 and entrance.zoneNames.enUS ~= "")
        Assert.True(entrance.x >= 0 and entrance.x <= 100 and entrance.y >= 0 and entrance.y <= 100)
      end
    end)
  end)

  test("Dungeon location mentions the season portal room only for dungeons with a portal there", function()
    WithMaps({
      hub = { mapID = 2266, name = "Jahrhundertschwelle", mapType = 3 },
      globals = {
        GetLocale = function()
          return "deDE"
        end,
      },
    }, function(location, _, _, addon)
      -- Ruby Life Pools has a portal-room slot in Season 2.
      Assert.Equal(location.GetPortalRoomName(399), "Jahrhundertschwelle")
      Assert.Equal(location.GetNavigationText(399, "Portal %s"), "The Waking Shores\nPortal Jahrhundertschwelle")
      -- Altar of Fangs has no portal there.
      Assert.Nil(location.GetPortalRoomName(588))
      Assert.Equal(location.GetNavigationText(588), "Die gewundene Insel")
      Assert.Nil(location.GetPortalRoomName(nil))
      addon.SeasonData.GetPortalNavigatorConfig = function()
        error("unavailable")
      end
      Assert.Nil(location.GetPortalRoomName(399))
    end)
    WithMaps({
      hub = { mapID = 2266, name = "Die Jahrhundertschwelle", mapType = 3 },
      globals = {
        GetLocale = function()
          return "deDE"
        end,
      },
    }, function(location)
      -- The map name's article is dropped from the short portal label.
      Assert.Equal(location.GetNavigationText(399, "Portal %s"), "The Waking Shores\nPortal Jahrhundertschwelle")
    end)
    WithMaps({}, function(location)
      -- Without client map info the manifest's first hub name is used.
      Assert.Equal(location.GetPortalRoomName(399), "Millennia's Threshold")
      Assert.Equal(location.GetNavigationText(399), "The Waking Shores\nPortal Millennia's Threshold")
    end)
  end)

  test("Dungeon artwork prefers the journal lore image cropped to a square", function()
    WithMaps({ loreImage = 1500001, buttonImage = 1500002 }, function(location, calls)
      local artwork = location.GetArtwork(9588)
      Assert.Equal(artwork.texture, 1500001)
      Assert.Equal(artwork.left, 91 / 512)
      Assert.Equal(artwork.right, 277 / 512)
      Assert.Equal(artwork.bottom, 186 / 256)
      local infoCalls = calls.instanceInfo
      Assert.Equal(location.GetArtwork(9588), artwork)
      Assert.Equal(calls.instanceInfo, infoCalls)
    end)
    WithMaps({ buttonImage = "UI-EJ-DUNGEONBUTTON-Test" }, function(location)
      local artwork = location.GetArtwork(9588)
      Assert.Equal(artwork.texture, "UI-EJ-DUNGEONBUTTON-Test")
      Assert.Equal(artwork.right, 135 / 256)
    end)
    WithMaps({}, function(location)
      -- No journal art and unknown maps leave the spell icon in place.
      Assert.Nil(location.GetArtwork(9588))
      Assert.Nil(location.GetArtwork(4242))
      Assert.Nil(location.GetArtwork(nil))
    end)
  end)
end
