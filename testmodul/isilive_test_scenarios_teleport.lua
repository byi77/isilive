local function BuildCreateFrameStub()
  local createdFrames = {}

  local function CreateFrameStub(_frameType)
    local frame = {
      _events = {},
      _scripts = {},
    }

    function frame:SetScript(name, handler)
      self._scripts[name] = handler
    end

    function frame:RegisterEvent(event)
      self._events[event] = true
    end

    function frame:UnregisterEvent(event)
      self._events[event] = nil
    end

    function frame:IsEventRegistered(event)
      return self._events[event] == true
    end

    function frame:FireEvent(event)
      local handler = self._scripts.OnEvent
      if handler then
        handler(self, event)
      end
    end

    table.insert(createdFrames, frame)
    return frame
  end

  return CreateFrameStub, createdFrames
end

local function BuildTeleportUICreateFrameStub()
  local createdFrames = {}

  local function CreateTextureStub()
    local texture = {}
    texture.SetAllPoints = function(_self) end
    texture.SetTexCoord = function(_self, _x1, _x2, _y1, _y2) end
    texture.SetTexture = function(_self, _value) end
    texture.SetColorTexture = function(_self, _r, _g, _b, _a) end
    texture.SetBlendMode = function(_self, _mode) end
    texture.SetVertexColor = function(_self, _r, _g, _b, _a) end
    texture.Hide = function(_self) end
    texture.Show = function(_self) end
    return texture
  end

  local function CreateAnimationGroupStub()
    local group = { playing = false }
    group.SetLooping = function(_self, _mode) end
    group.CreateAnimation = function(_group, _kind)
      local anim = {}
      anim.SetScale = function(_self, _x, _y) end
      anim.SetDuration = function(_self, _duration) end
      anim.SetSmoothing = function(_self, _value) end
      anim.SetOrder = function(_self, _value) end
      anim.SetFromAlpha = function(_self, _value) end
      anim.SetToAlpha = function(_self, _value) end
      anim.SetTarget = function(_self, _target) end
      return anim
    end
    function group:IsPlaying()
      return self.playing
    end
    function group:Play()
      self.playing = true
    end
    function group:Stop()
      self.playing = false
    end
    return group
  end

  local function CreateFrameStub(frameType, _name, _parent, _template)
    local frame = {
      _frameType = frameType,
      _events = {},
      _scripts = {},
      _attrs = {},
      _frameStrata = "MEDIUM",
      _frameLevel = 1,
    }

    function frame:SetScript(name, handler)
      self._scripts[name] = handler
    end

    function frame:RegisterEvent(event)
      self._events[event] = true
    end

    function frame:UnregisterEvent(event)
      self._events[event] = nil
    end

    function frame:IsEventRegistered(event)
      return self._events[event] == true
    end

    function frame:FireEvent(event)
      local handler = self._scripts.OnEvent
      if handler then
        handler(self, event)
      end
    end

    frame.SetSize = function(self, w, h)
      self.width = w
      self.height = h
    end
    frame.SetPoint = function(self, point, ...)
      local args = { ... }
      self._point = {
        point = point,
        relativeTo = #args >= 4 and args[1] or nil,
        relativePoint = #args >= 4 and args[2] or nil,
        x = #args >= 4 and args[3] or args[1] or 0,
        y = #args >= 4 and args[4] or args[2] or 0,
      }
    end
    frame.ClearAllPoints = function(self)
      self._point = nil
    end
    frame.EnableMouse = function(_self, _enabled) end
    frame.RegisterForClicks = function(_self, _down, _up) end
    function frame:SetFrameStrata(value)
      self._frameStrata = value
    end
    function frame:GetFrameStrata()
      return self._frameStrata
    end
    function frame:SetFrameLevel(value)
      self._frameLevel = value
    end
    function frame:GetFrameLevel()
      return self._frameLevel
    end
    frame.CreateTexture = function(_self, _texName, _layer)
      return CreateTextureStub()
    end
    frame.CreateAnimationGroup = function(_self)
      return CreateAnimationGroupStub()
    end
    function frame:SetAttribute(key, value)
      self._attrs[key] = value
    end
    function frame:GetAttribute(key)
      return self._attrs[key]
    end
    frame.SetScale = function(_self, _scale) end
    frame.SetAllPoints = function(_self) end
    frame.SetDrawEdge = function(_self, _enabled) end
    frame.SetClampedToScreen = function(_self, _enabled) end
    frame.Show = function(self)
      self._shown = true
    end
    frame.Hide = function(self)
      self._shown = false
    end
    frame.CreateFontString = function()
      local fontString = {
        _text = nil,
      }
      fontString.SetPoint = function() end
      fontString.SetText = function(self, value)
        self._text = value
      end
      fontString.Hide = function() end
      fontString.Show = function() end
      fontString.SetWidth = function() end
      fontString.SetJustifyH = function() end
      fontString.SetWordWrap = function() end
      fontString.SetNonSpaceWrap = function() end
      fontString.SetMaxLines = function() end
      fontString.SetTextColor = function() end
      fontString.GetStringHeight = function()
        return 16
      end
      return fontString
    end

    table.insert(createdFrames, frame)
    return frame
  end

  return CreateFrameStub, createdFrames
end

local function ActivateSeasonOrFail(Assert, addon, seasonID, opts)
  local ok, err = addon.SeasonData.SetActiveSeasonID(seasonID, opts)
  Assert.True(ok, tostring(err))
end

local function RegisterTeleportResolverCoreTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Teleport resolves shared-map spell IDs as deterministic sorted map list", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")
      local mapIDs = addon.Teleport.ResolveMapIDsBySpellID(367416)

      Assert.NotNil(mapIDs, "shared spell should map to map list")
      Assert.Equal(#mapIDs, 2, "shared tazavesh spell should map to exactly two dungeons")
      Assert.Equal(mapIDs[1], 2441, "first shared map should be sorted ascending")
      Assert.Equal(mapIDs[2], 2442, "second shared map should be sorted ascending")
    end)
  end)

  test("Teleport returns locale-specific dungeon short codes for deDE and keeps enUS defaults", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })

      Assert.Equal(addon.SeasonData.GetActiveSeasonID(), "midnight_s1", "runtime should default to midnight_s1")
      Assert.True(
        addon.SeasonData.HasActiveDungeons(),
        "runtime should expose the active Midnight Season 1 portal pool"
      )
      Assert.Equal(
        #addon.SeasonData.GetOrderedMapIDs(),
        8,
        "runtime should keep all 8 Midnight Season 1 dungeons in the active ordered map list"
      )

      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")

      Assert.Equal(addon.Teleport.GetDungeonShortCode(2649, "deDE"), "PRI", "deDE should map PSF to PRI")
      Assert.Equal(addon.Teleport.GetDungeonShortCode(2830, "deDE"), "BIO", "deDE should map EDA to BIO")
      Assert.Equal(addon.Teleport.GetDungeonShortCode(2287, "deDE"), "HDS", "deDE should map HOA to HDS")
      Assert.Equal(addon.Teleport.GetDungeonShortCode(2773, "deDE"), "SCH", "deDE should map OFG to SCH")
      Assert.Equal(addon.Teleport.GetDungeonShortCode(2660, "deDE"), "AK", "deDE should keep AK")
      Assert.Equal(addon.Teleport.GetDungeonShortCode(2441, "deDE"), "TAZ", "deDE should keep TAZ")
      Assert.Equal(addon.Teleport.GetDungeonShortCode(2662, "deDE"), "MB", "deDE should map DB to MB")
      Assert.Equal(
        addon.Teleport.GetDungeonShortCode(542, "deDE"),
        "BIO",
        "challenge-map alias should resolve to same localized short code list"
      )
      Assert.Equal(
        addon.Teleport.ResolveTeleportSpellIDByMapID(542),
        1237215,
        "challenge-map alias should resolve to canonical teleport spell"
      )
      Assert.Equal(addon.Teleport.GetDungeonShortCode(2649, "enUS"), "PSF", "enUS should keep PSF")
      Assert.Equal(
        addon.SeasonData.GetMapToTeleport()[2662],
        445414,
        "active season map->spell table should stay centralized"
      )
      Assert.Equal(
        addon.SeasonData.GetDungeonShortCode(2662, "frFR"),
        "DB",
        "unsupported locales should fallback to default"
      )
      Assert.Equal(
        addon.SeasonData.GetActiveSeasonID(),
        "test_season",
        "legacy season switch should work explicitly for mapping validation"
      )
      local orderedActiveMapIDs = addon.SeasonData.GetOrderedMapIDs()
      Assert.Equal(#orderedActiveMapIDs, 8, "active season ordered map list should include all mapped dungeons")
      Assert.Equal(orderedActiveMapIDs[1], 2287, "explicit season display order should place HOA first")
      Assert.Equal(orderedActiveMapIDs[2], 2441, "explicit season display order should keep Tazavesh slot stable")

      local availableSeasonIDs = addon.SeasonData.GetAvailableSeasonIDs()
      local hasPreparedMidnightSeason = false
      for _, seasonID in ipairs(availableSeasonIDs) do
        if seasonID == "midnight_s1" then
          hasPreparedMidnightSeason = true
          break
        end
      end
      Assert.True(hasPreparedMidnightSeason, "prepared midnight_s1 season scaffold should be registered")
      Assert.NotNil(
        next(addon.SeasonData.GetMapToTeleport("midnight_s1")),
        "midnight_s1 should expose filled live mappings once portal IDs are available"
      )
      Assert.Equal(
        #addon.SeasonData.GetOrderedMapIDs("midnight_s1"),
        8,
        "midnight_s1 should keep all 8 active ordered-map entries once mappings are provided"
      )
    end)
  end)
end

local function RegisterTeleportResolverAliasTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Teleport legacy Season3 wrappers mirror generic resolver outputs", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
      C_LFGList = {
        GetActivityInfoTable = function(activityID)
          if activityID == 9901 then
            return { mapID = 2662 }
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")

      Assert.Equal(
        addon.Teleport.ResolveSeason3MapIDByActivityID(9901),
        addon.Teleport.ResolveMapIDByActivityID(9901),
        "legacy activity->map wrapper should mirror generic resolver"
      )
      Assert.Equal(
        addon.Teleport.ResolveSeason3TeleportSpellIDByActivityID(9901),
        addon.Teleport.ResolveTeleportSpellIDByActivityID(9901),
        "legacy activity->spell wrapper should mirror generic resolver"
      )
      Assert.Equal(
        addon.Teleport.ResolveSeason3TeleportSpellIDByMapID(2662),
        addon.Teleport.ResolveTeleportSpellIDByMapID(2662),
        "legacy map->spell wrapper should mirror generic resolver"
      )
      Assert.Equal(
        addon.Teleport.GetSeason3DungeonShortCode(2662, "enUS"),
        addon.Teleport.GetDungeonShortCode(2662, "enUS"),
        "legacy short-code wrapper should mirror generic resolver"
      )
      Assert.Equal(
        #addon.Teleport.BuildSeason3TeleportEntries(),
        #addon.Teleport.BuildTeleportEntries(),
        "legacy entry builder should mirror generic resolver"
      )
    end)
  end)

  test("Teleport resolves challenge-map IDs by static alias list before short-code rendering", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
      C_ChallengeMode = {
        GetMapUIInfo = function(mapID)
          local names = {
            [2441] = "Tazavesh: Streets of Wonder",
            [392] = "Tazavesh: Streets of Wonder",
            [2662] = "The Dawnbreaker",
            [505] = "The Dawnbreaker",
          }
          return names[mapID]
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
        "isiLive_sync.lua",
      })
      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")

      Assert.Equal(
        addon.Teleport.GetDungeonShortCode(392, "deDE"),
        "TAZ",
        "challenge-map aliases resolved by map name should use localized short code"
      )
      Assert.Equal(
        addon.Teleport.GetDungeonShortCode(505, "deDE"),
        "MB",
        "challenge-map aliases resolved by map name should use dawnbreaker short code"
      )
      Assert.Equal(
        addon.Teleport.ResolveTeleportSpellIDByMapID(505),
        445414,
        "runtime map-name alias should resolve canonical teleport spell"
      )

      local keyChanged = addon.Sync.SetPlayerKeyInfo("Tester", "Realm", 505, 12)
      local keyInfo = addon.Sync.GetPlayerKeyInfo("Tester", "Realm")
      Assert.True(keyChanged, "sync key cache should accept first normalized challenge-map update")
      Assert.Equal(keyInfo and keyInfo.mapID, 2662, "sync key cache should store canonical map id after normalization")
    end)
  end)

  test("Teleport short-code resolver keeps unknown maps unresolved instead of showing map ids", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
      C_ChallengeMode = {
        GetMapUIInfo = function(_mapID)
          return "Mystery Dungeon Name"
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      local shortCode = addon.Teleport.GetDungeonShortCode(9999, "enUS")
      Assert.Nil(shortCode, "unknown maps should stay unresolved instead of showing numeric map ids")
    end)
  end)

  test("Teleport info keeps map name unresolved when API has no concrete name", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
      C_ChallengeMode = {
        GetMapUIInfo = function(_mapID)
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")
      local info = addon.Teleport.GetTeleportInfoByMapID(2662)
      Assert.NotNil(info, "known map should still resolve teleport info")
      Assert.Nil(info.mapName, "map name must stay unresolved when API provides no concrete name")
    end)
  end)
end

local function RegisterTeleportResolverActivityTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Teleport resolves activity map and caches activity lookups", function()
    local createFrameStub = BuildCreateFrameStub()
    local activityInfoCalls = 0

    WithGlobals({
      CreateFrame = createFrameStub,
      C_LFGList = {
        GetActivityInfoTable = function(activityID)
          activityInfoCalls = activityInfoCalls + 1
          if activityID == 9900 then
            return { mapID = 2662 }
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")
      local mapFirst = addon.Teleport.ResolveMapIDByActivityID(9900)
      local mapSecond = addon.Teleport.ResolveMapIDByActivityID(9900)
      local first = addon.Teleport.ResolveTeleportSpellIDByActivityID(9900)
      local second = addon.Teleport.ResolveTeleportSpellIDByActivityID(9900)
      local genericMap = addon.Teleport.ResolveMapIDByActivityID(9900)
      local genericActivitySpell = addon.Teleport.ResolveTeleportSpellIDByActivityID(9900)
      local genericMapSpell = addon.Teleport.ResolveTeleportSpellIDByMapID(2662)

      Assert.Equal(mapFirst, 2662, "activity map should resolve directly from activity info")
      Assert.Equal(mapSecond, 2662, "activity map resolver should use cached value")
      Assert.Equal(first, 445414, "activity map should resolve to mapped teleport spell")
      Assert.Equal(second, 445414, "cached activity map should keep same resolved spell")
      Assert.Equal(
        genericMap,
        2662,
        "generic activity map resolver should stay compatible with season-specific resolver"
      )
      Assert.Equal(
        genericActivitySpell,
        445414,
        "generic activity spell resolver should stay compatible with season-specific resolver"
      )
      Assert.Equal(
        genericMapSpell,
        445414,
        "generic map spell resolver should stay compatible with season-specific resolver"
      )
    end)

    Assert.Equal(activityInfoCalls, 1, "activity lookup should be cached after first successful resolve")
  end)

  test("Teleport does not resolve by dungeon name without activityID", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      local spellID = addon.Teleport.ResolveTeleportSpellID(nil, "Queue to Tazavesh Gambit")
      Assert.Nil(spellID, "name-only resolution must stay nil in strict mode")
    end)
  end)

  test("Teleport does not resolve localized dungeon names without activityID", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      local spellID = addon.Teleport.ResolveTeleportSpellID(nil, "Biokuppel Al'dani")
      Assert.Nil(spellID, "localized name-only resolution must stay nil in strict mode")
    end)
  end)
end

local function RegisterTeleportResolverRecoveryTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Teleport keeps activity unresolved when mapID is missing and retries unresolved lookups", function()
    local createFrameStub = BuildCreateFrameStub()
    local activityInfoCalls = 0

    WithGlobals({
      CreateFrame = createFrameStub,
      C_LFGList = {
        GetActivityInfoTable = function(activityID)
          activityInfoCalls = activityInfoCalls + 1
          if activityID == 9910 then
            return { fullName = "Biokuppel Al'dani" }
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      local first = addon.Teleport.ResolveTeleportSpellIDByActivityID(9910)
      local second = addon.Teleport.ResolveTeleportSpellIDByActivityID(9910)

      Assert.Nil(first, "activity without concrete mapID must remain unresolved")
      Assert.Nil(second, "unresolved activity result should stay nil")
    end)

    Assert.Equal(activityInfoCalls, 2, "unresolved map lookups should be retried (no negative cache lock)")
  end)

  test("Teleport unresolved activity lookup can recover when map data appears later", function()
    local createFrameStub = BuildCreateFrameStub()
    local activityInfoCalls = 0
    local exposeMap = false

    WithGlobals({
      CreateFrame = createFrameStub,
      C_LFGList = {
        GetActivityInfoTable = function(activityID)
          activityInfoCalls = activityInfoCalls + 1
          if activityID ~= 9911 then
            return nil
          end
          if exposeMap then
            return { mapID = 2662 }
          end
          return { fullName = "Late Map Payload" }
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")

      local first = addon.Teleport.ResolveTeleportSpellIDByActivityID(9911)
      Assert.Nil(first, "first resolve must stay nil while map data is missing")

      exposeMap = true
      local second = addon.Teleport.ResolveTeleportSpellIDByActivityID(9911)
      Assert.Equal(second, 445414, "resolver must recover once concrete map data appears")
    end)

    Assert.Equal(activityInfoCalls, 2, "resolver should query activity info again after unresolved first attempt")
  end)
end

local function RegisterTeleportEntryAndCombatTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Teleport entry builder de-duplicates shared spells for grid rendering", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
      C_ChallengeMode = {
        GetMapUIInfo = function(mapID)
          return "Map-" .. tostring(mapID)
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      addon.SeasonData.SEASONS.test_season = {
        mapToTeleport = {
          [2649] = 445444,
          [2830] = 1237215,
          [2287] = 354465,
          [2773] = 1216786,
          [2660] = 445417,
          [2441] = 367416,
          [2442] = 367416,
          [2662] = 445414,
        },
        displayOrder = { 2287, 2441, 2442, 2649, 2660, 2662, 2773, 2830 },
        shortCodesByLocale = {
          default = {
            [2649] = "PSF",
            [2830] = "EDA",
            [2287] = "HOA",
            [2773] = "OFG",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "DB",
          },
          deDE = {
            [2649] = "PRI",
            [2830] = "BIO",
            [2287] = "HDS",
            [2773] = "SCH",
            [2660] = "AK",
            [2441] = "TAZ",
            [2442] = "TAZ",
            [2662] = "MB",
          },
        },
        challengeMapAliases = {
          [378] = 2287,
          [391] = 2441,
          [392] = 2441,
          [499] = 2649,
          [503] = 2660,
          [505] = 2662,
          [525] = 2773,
          [542] = 2830,
        },
      }
      ActivateSeasonOrFail(Assert, addon, "test_season")
      local entries = addon.Teleport.BuildTeleportEntries()
      local genericEntries = addon.Teleport.BuildTeleportEntries()
      local expectedMapOrder = { 2287, 2441, 2649, 2660, 2662, 2773, 2830 }

      local sharedSpellCount = 0
      for index, info in ipairs(entries) do
        if info.spellID == 367416 then
          sharedSpellCount = sharedSpellCount + 1
        end
        Assert.Equal(
          info.mapID,
          expectedMapOrder[index],
          "teleport entries should keep deterministic slot order by canonical map sequence"
        )
      end

      Assert.Equal(#entries, 7, "8 maps with one shared spell should render as 7 unique teleport entries")
      Assert.Equal(
        #genericEntries,
        #entries,
        "generic teleport entry builder should mirror legacy season-specific behavior"
      )
      Assert.Equal(sharedSpellCount, 1, "shared teleport spell should appear exactly once")
    end)
  end)

  test("Teleport secure button updates are deferred during combat and applied after regen", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local inCombat = true

    local attributes = {}
    local button = {
      SetAttribute = function(_self, key, value)
        attributes[key] = value
      end,
      EnableMouse = function(_self, value)
        attributes.enableMouse = value
      end,
    }

    WithGlobals({
      CreateFrame = createFrameStub,
      InCombatLockdown = function()
        return inCombat
      end,
      C_Spell = {
        GetSpellName = function(spellID)
          return "Spell-" .. tostring(spellID)
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      local appliedInCombat = addon.Teleport.ApplySecureSpellToButton(button, 445414)
      Assert.False(appliedInCombat, "secure button update should defer during combat lockdown")
      Assert.Equal(#createdFrames, 1, "combat retry frame should be created once")
      Assert.True(
        createdFrames[1]:IsEventRegistered("PLAYER_REGEN_ENABLED"),
        "combat retry frame should register PLAYER_REGEN_ENABLED"
      )

      inCombat = false
      createdFrames[1]:FireEvent("PLAYER_REGEN_ENABLED")
      Assert.Equal(attributes.spell, "Spell-445414", "deferred update should apply spell attribute after combat")
      Assert.True(attributes.enableMouse, "deferred update should restore mouse interactions")
      Assert.False(
        createdFrames[1]:IsEventRegistered("PLAYER_REGEN_ENABLED"),
        "retry frame should unregister after draining pending updates"
      )
    end)
  end)
end

local function RegisterTeleportUIStrataAndTooltipTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TeleportUI buttons follow main-frame strata instead of forcing HIGH", function()
    local createFrameStub = BuildTeleportUICreateFrameStub()
    local mainFrame = {
      frameStrata = "MEDIUM",
      frameLevel = 7,
      GetFrameStrata = function(self)
        return self.frameStrata
      end,
      GetFrameLevel = function(self)
        return self.frameLevel
      end,
    }

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = mainFrame,
        applySecureSpellToButton = function(_button, _spellID)
          return true
        end,
        getEntries = function()
          return {
            { spellID = 445414, mapID = 2662, mapName = "The Dawnbreaker" },
          }
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function(_spellID)
          return true
        end,
        getTeleportCooldownRemaining = function(_spellID)
          return 0
        end,
        formatCooldownSeconds = function(sec)
          return tostring(sec or 0)
        end,
        getSpellCooldownSafe = function(_spellID)
          return 0, 0, true
        end,
        applyCooldownFrameSafe = function(_frame, _start, _duration, _enabled) end,
        getSpellTexture = function(_spellID)
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()
      local buttons = controller.GetButtons()
      Assert.Equal(#buttons, 1, "TeleportUI should create one button for one entry")
      Assert.Equal(buttons[1]:GetFrameStrata(), "MEDIUM", "button strata must match main frame strata")
      Assert.Equal(buttons[1]:GetFrameLevel(), 17, "button frame level should be main frame level plus offset")

      mainFrame.frameStrata = "LOW"
      mainFrame.frameLevel = 3
      controller.UpdateButtons(nil)

      Assert.Equal(buttons[1]:GetFrameStrata(), "LOW", "button strata should stay in sync with main frame")
      Assert.Equal(buttons[1]:GetFrameLevel(), 13, "button level should re-sync when main frame level changes")
    end)
  end)

  test("TeleportUI buttons use isolated cursor-anchored tooltips", function()
    local createFrameStub, createdFrames = BuildTeleportUICreateFrameStub()
    local sharedTooltipCalls = 0

    WithGlobals({
      CreateFrame = createFrameStub,
      GetSpellInfo = function()
        return "Pfad des drakonischen Diploms"
      end,
      GameTooltip = {
        SetOwner = function()
          sharedTooltipCalls = sharedTooltipCalls + 1
        end,
        SetSpellByID = function()
          sharedTooltipCalls = sharedTooltipCalls + 1
        end,
        AddLine = function()
          sharedTooltipCalls = sharedTooltipCalls + 1
        end,
        Show = function()
          sharedTooltipCalls = sharedTooltipCalls + 1
        end,
        Hide = function()
          sharedTooltipCalls = sharedTooltipCalls + 1
        end,
        SetText = function()
          sharedTooltipCalls = sharedTooltipCalls + 1
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
        },
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return { { spellID = 12345, mapID = 100, mapName = "Test Dungeon" } }
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getSpellCooldownSafe = function()
          return 0, 0, true
        end,
        applyCooldownFrameSafe = function() end,
        getSpellTexture = function()
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()
      local buttons = controller.GetButtons()
      local button = buttons[1]

      local onEnter = button._scripts.OnEnter
      Assert.NotNil(onEnter, "Teleport button must have OnEnter script")

      onEnter(button)

      local privateTooltip = nil
      for _, frame in ipairs(createdFrames) do
        if frame._isIsiLiveTooltip == true then
          privateTooltip = frame
          break
        end
      end

      Assert.NotNil(privateTooltip, "TeleportUI should allocate a private tooltip frame")
      Assert.Equal(
        privateTooltip._isiLiveTooltipAnchor,
        "ANCHOR_CURSOR",
        "private teleport tooltip must keep cursor anchor"
      )
      Assert.Equal(
        privateTooltip._isiLiveTooltipLines[1] and privateTooltip._isiLiveTooltipLines[1]._text or nil,
        "Test Dungeon",
        "teleport tooltip should prefer the dungeon name over the raw spell name"
      )
      Assert.Equal(sharedTooltipCalls, 0, "TeleportUI should not touch the shared Blizzard GameTooltip")
    end)
  end)
end

local function RegisterTeleportUIEmptyStateTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TeleportUI shows pre-season message when active portal pool is empty", function()
    local createFrameStub = BuildTeleportUICreateFrameStub()
    local emptyState = {
      text = nil,
      shown = false,
      SetPoint = function() end,
      SetWidth = function() end,
      SetJustifyH = function() end,
      SetTextColor = function() end,
      SetWordWrap = function() end,
      SetNonSpaceWrap = function() end,
      SetText = function(self, value)
        self.text = value
      end,
      Show = function(self)
        self.shown = true
      end,
      Hide = function(self)
        self.shown = false
      end,
    }

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
          CreateFontString = function()
            return emptyState
          end,
        },
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return {}
        end,
        getEmptyStateText = function()
          return "Midnight S1 launches March 18, 2026\nM+ available March 25, 2026"
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function()
          return false
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getSpellCooldownSafe = function()
          return 0, 0, true
        end,
        applyCooldownFrameSafe = function() end,
        getSpellTexture = function()
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()

      Assert.Equal(#controller.GetButtons(), 0, "pre-season empty state should not create teleport buttons")
      Assert.True(emptyState.shown, "pre-season empty state message should be visible")
      Assert.Equal(
        emptyState.text,
        "Midnight S1 launches March 18, 2026\nM+ available March 25, 2026",
        "empty state should show season message"
      )
    end)
  end)

  test("TeleportUI SetVisible hides travel buttons and empty state", function()
    local createFrameStub = BuildTeleportUICreateFrameStub()
    local emptyState = {
      text = nil,
      shown = false,
      SetPoint = function() end,
      SetWidth = function() end,
      SetJustifyH = function() end,
      SetTextColor = function() end,
      SetWordWrap = function() end,
      SetNonSpaceWrap = function() end,
      SetText = function(self, value)
        self.text = value
      end,
      Show = function(self)
        self.shown = true
      end,
      Hide = function(self)
        self.shown = false
      end,
    }

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
          CreateFontString = function()
            return emptyState
          end,
        },
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return {}
        end,
        getEmptyStateText = function()
          return "No teleports"
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function()
          return false
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getSpellCooldownSafe = function()
          return 0, 0, true
        end,
        applyCooldownFrameSafe = function() end,
        getSpellTexture = function()
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()
      Assert.True(emptyState.shown, "empty state should be visible before collapse hiding")

      controller.SetVisible(false)

      Assert.False(emptyState.shown, "empty state should hide when travel area is collapsed")
      Assert.Equal(#controller.GetButtons(), 0, "empty-state setup should still keep button list empty")
    end)
  end)

  test("TeleportUI keeps the legacy two-column travel grid", function()
    local createFrameStub = BuildTeleportUICreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
      IsiLiveDB = {
        teleportColumns = 4,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              SetTextColor = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetText = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
        },
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return {
            { spellID = 1, mapID = 1001, slotIndex = 1 },
            { spellID = 2, mapID = 1002, slotIndex = 2 },
            { spellID = 3, mapID = 1003, slotIndex = 3 },
            { spellID = 4, mapID = 1004, slotIndex = 4 },
          }
        end,
        getEmptyStateText = function()
          return nil
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getSpellCooldownSafe = function()
          return 0, 0, true
        end,
        applyCooldownFrameSafe = function() end,
        getSpellTexture = function()
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.BuildButtons()
      local buttons = controller.GetButtons()

      Assert.Equal(#buttons, 4, "travel grid should build one button per entry")
      Assert.Equal(
        buttons[1]._point and buttons[1]._point.x or nil,
        -60,
        "first column should keep the original left slot anchor"
      )
      Assert.Equal(
        buttons[2]._point and buttons[2]._point.x or nil,
        -28,
        "second column should keep the original right slot anchor"
      )
      Assert.Equal(
        buttons[3]._point and buttons[3]._point.x or nil,
        -60,
        "third button should wrap back to the left column on the second row"
      )
      Assert.Equal(
        buttons[4]._point and buttons[4]._point.x or nil,
        -28,
        "fourth button should stay in the right column on the second row"
      )
      Assert.Equal(
        buttons[1]._point and buttons[1]._point.y or nil,
        -60,
        "first travel row should stay under the header baseline"
      )
      Assert.Equal(buttons[2]._point and buttons[2]._point.y or nil, -60, "second button should stay on the first row")
      Assert.Equal(
        buttons[3]._point and buttons[3]._point.y or nil,
        -92,
        "third button should start the second row one slot below"
      )
      Assert.Equal(buttons[4]._point and buttons[4]._point.y or nil, -92, "fourth button should stay on the second row")
    end)
  end)

  test("TeleportUI M2 layout stacks portal buttons in one left-aligned row", function()
    local createFrameStub = BuildTeleportUICreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_ui_common.lua",
        "isiLive_teleport_ui.lua",
      })

      local controller = addon.TeleportUI.CreateController({
        mainFrame = {
          GetFrameLevel = function()
            return 10
          end,
          GetFrameStrata = function()
            return "MEDIUM"
          end,
          CreateFontString = function()
            return {
              SetPoint = function() end,
              SetWidth = function() end,
              SetJustifyH = function() end,
              SetTextColor = function() end,
              SetWordWrap = function() end,
              SetNonSpaceWrap = function() end,
              SetText = function() end,
              Hide = function() end,
              Show = function() end,
            }
          end,
        },
        applySecureSpellToButton = function()
          return true
        end,
        getEntries = function()
          return {
            { spellID = 1, mapID = 1001, slotIndex = 1 },
            { spellID = 2, mapID = 1002, slotIndex = 2 },
            { spellID = 3, mapID = 1003, slotIndex = 3 },
            { spellID = 4, mapID = 1004, slotIndex = 4 },
            { spellID = 5, mapID = 1005, slotIndex = 5 },
            { spellID = 6, mapID = 1006, slotIndex = 6 },
            { spellID = 7, mapID = 1007, slotIndex = 7 },
            { spellID = 8, mapID = 1008, slotIndex = 8 },
          }
        end,
        getEmptyStateText = function()
          return nil
        end,
        getL = function()
          return {}
        end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getSpellCooldownSafe = function()
          return 0, 0, true
        end,
        applyCooldownFrameSafe = function() end,
        getSpellTexture = function()
          return nil
        end,
        isInCombat = function()
          return false
        end,
      })

      controller.SetLayoutMode("compact_main_horizontal")
      controller.BuildButtons()
      local buttons = controller.GetButtons()

      Assert.Equal(#buttons, 8, "M2 portal row should still build one button per entry")
      Assert.Equal(buttons[1]._point and buttons[1]._point.point or nil, "BOTTOMLEFT", "M2 row should anchor from the bottom-left")
      Assert.Equal(buttons[1]._point and buttons[1]._point.x or nil, 10, "first M2 portal button should start at the left margin")
      Assert.Equal(buttons[1].width, 57, "M2 portal buttons should use the wider horizontal icon size")
      Assert.Equal(buttons[1].height, 32, "M2 portal buttons should use the wider horizontal icon size")
      Assert.Equal(buttons[2]._point and buttons[2]._point.x or nil, 71, "second M2 portal button should step to the right")
      Assert.Equal(buttons[3]._point and buttons[3]._point.x or nil, 132, "third M2 portal button should keep the same row")
      Assert.Equal(buttons[4]._point and buttons[4]._point.x or nil, 193, "fourth M2 portal button should keep the same row")
      Assert.Equal(buttons[5]._point and buttons[5]._point.x or nil, 254, "fifth M2 portal button should keep the same row")
      Assert.Equal(buttons[6]._point and buttons[6]._point.x or nil, 315, "sixth M2 portal button should keep the same row")
      Assert.Equal(buttons[7]._point and buttons[7]._point.x or nil, 376, "seventh M2 portal button should keep the same row")
      Assert.Equal(buttons[8]._point and buttons[8]._point.x or nil, 437, "eighth M2 portal button should keep the same row")
      Assert.Equal(buttons[1]._point and buttons[1]._point.y or nil, 42, "M2 portal row should sit below the management row")
      Assert.Equal(buttons[8]._point and buttons[8]._point.y or nil, 42, "all M2 portal buttons should share the same row")
    end)
  end)
end

local function RegisterTeleportUITests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportUIStrataAndTooltipTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportUIEmptyStateTests(test, Assert, WithGlobals, LoadAddonModules)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterTeleportResolverCoreTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportResolverAliasTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportResolverActivityTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportResolverRecoveryTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportEntryAndCombatTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportUITests(test, Assert, WithGlobals, LoadAddonModules)
end
