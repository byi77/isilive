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

  local function CreateFrameStub(_frameType, _name, _parent, _template)
    local frame = {
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

    frame.SetSize = function(_self, _w, _h) end
    frame.SetPoint = function(_self, _point, _x, _y) end
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

    table.insert(createdFrames, frame)
    return frame
  end

  return CreateFrameStub, createdFrames
end

local function RegisterTeleportResolverTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Teleport resolves shared-map spell IDs as deterministic sorted map list", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      local mapIDs = addon.Teleport.ResolveSeason3MapIDsBySpellID(367416)

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

      Assert.Equal(addon.Teleport.GetSeason3DungeonShortCode(2649, "deDE"), "PRI", "deDE should map PSF to PRI")
      Assert.Equal(addon.Teleport.GetSeason3DungeonShortCode(2830, "deDE"), "BIO", "deDE should map EDA to BIO")
      Assert.Equal(addon.Teleport.GetSeason3DungeonShortCode(2287, "deDE"), "HDS", "deDE should map HOA to HDS")
      Assert.Equal(addon.Teleport.GetSeason3DungeonShortCode(2773, "deDE"), "SCH", "deDE should map OFG to SCH")
      Assert.Equal(addon.Teleport.GetSeason3DungeonShortCode(2660, "deDE"), "AK", "deDE should keep AK")
      Assert.Equal(addon.Teleport.GetSeason3DungeonShortCode(2441, "deDE"), "TAZ", "deDE should keep TAZ")
      Assert.Equal(addon.Teleport.GetSeason3DungeonShortCode(2662, "deDE"), "MB", "deDE should map DB to MB")
      Assert.Equal(
        addon.Teleport.GetSeason3DungeonShortCode(542, "deDE"),
        "BIO",
        "challenge-map alias should resolve to same localized short code list"
      )
      Assert.Equal(
        addon.Teleport.ResolveSeason3TeleportSpellIDByMapID(542),
        1237215,
        "challenge-map alias should resolve to canonical teleport spell"
      )
      Assert.Equal(addon.Teleport.GetSeason3DungeonShortCode(2649, "enUS"), "PSF", "enUS should keep PSF")
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

      Assert.Equal(
        addon.Teleport.GetSeason3DungeonShortCode(392, "deDE"),
        "TAZ",
        "challenge-map aliases resolved by map name should use localized short code"
      )
      Assert.Equal(
        addon.Teleport.GetSeason3DungeonShortCode(505, "deDE"),
        "MB",
        "challenge-map aliases resolved by map name should use dawnbreaker short code"
      )
      Assert.Equal(
        addon.Teleport.ResolveSeason3TeleportSpellIDByMapID(505),
        445414,
        "runtime map-name alias should resolve canonical teleport spell"
      )

      local keyChanged = addon.Sync.SetPlayerKeyInfo("Tester", "Realm", 505, 12)
      local keyInfo = addon.Sync.GetPlayerKeyInfo("Tester", "Realm")
      Assert.True(keyChanged, "sync key cache should accept first normalized challenge-map update")
      Assert.Equal(keyInfo and keyInfo.mapID, 2662, "sync key cache should store canonical map id after normalization")
    end)
  end)

  test("Teleport short-code resolver does not guess acronyms when no season mapping exists", function()
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
      local shortCode = addon.Teleport.GetSeason3DungeonShortCode(9999, "enUS")
      Assert.Equal(shortCode, "9999", "unknown maps should fallback to mapID instead of guessed acronyms")
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
      local info = addon.Teleport.GetSeason3TeleportInfoByMapID(2662)
      Assert.NotNil(info, "known map should still resolve teleport info")
      Assert.Nil(info.mapName, "map name must stay unresolved when API provides no concrete name")
    end)
  end)

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
      local mapFirst = addon.Teleport.ResolveSeason3MapIDByActivityID(9900)
      local mapSecond = addon.Teleport.ResolveSeason3MapIDByActivityID(9900)
      local first = addon.Teleport.ResolveSeason3TeleportSpellIDByActivityID(9900)
      local second = addon.Teleport.ResolveSeason3TeleportSpellIDByActivityID(9900)

      Assert.Equal(mapFirst, 2662, "activity map should resolve directly from activity info")
      Assert.Equal(mapSecond, 2662, "activity map resolver should use cached value")
      Assert.Equal(first, 445414, "activity map should resolve to mapped teleport spell")
      Assert.Equal(second, 445414, "cached activity map should keep same resolved spell")
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
      local spellID = addon.Teleport.ResolveSeason3TeleportSpellID(nil, "Queue to Tazavesh Gambit")
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
      local spellID = addon.Teleport.ResolveSeason3TeleportSpellID(nil, "Biokuppel Al'dani")
      Assert.Nil(spellID, "localized name-only resolution must stay nil in strict mode")
    end)
  end)

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
      local first = addon.Teleport.ResolveSeason3TeleportSpellIDByActivityID(9910)
      local second = addon.Teleport.ResolveSeason3TeleportSpellIDByActivityID(9910)

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

      local first = addon.Teleport.ResolveSeason3TeleportSpellIDByActivityID(9911)
      Assert.Nil(first, "first resolve must stay nil while map data is missing")

      exposeMap = true
      local second = addon.Teleport.ResolveSeason3TeleportSpellIDByActivityID(9911)
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
      local entries = addon.Teleport.BuildSeason3TeleportEntries()

      local sharedSpellCount = 0
      for _, info in ipairs(entries) do
        if info.spellID == 367416 then
          sharedSpellCount = sharedSpellCount + 1
        end
      end

      Assert.Equal(#entries, 7, "8 maps with one shared spell should render as 7 unique teleport entries")
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

local function RegisterTeleportUITests(test, Assert, WithGlobals, LoadAddonModules)
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
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterTeleportResolverTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportEntryAndCombatTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportUITests(test, Assert, WithGlobals, LoadAddonModules)
end
