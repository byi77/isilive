return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

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
      local first = addon.Teleport.ResolveSeason3TeleportSpellIDByActivityID(9900)
      local second = addon.Teleport.ResolveSeason3TeleportSpellIDByActivityID(9900)

      Assert.Equal(first, 445414, "activity map should resolve to mapped teleport spell")
      Assert.Equal(second, 445414, "cached activity map should keep same resolved spell")
    end)

    Assert.Equal(activityInfoCalls, 1, "activity lookup should be cached after first successful resolve")
  end)

  test("Teleport resolves Tazavesh via dungeon-name fallback tokens", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
      C_ChallengeMode = {
        GetMapUIInfo = function(mapID)
          if mapID == 2441 then
            return "Tazavesh: Streets of Wonder"
          end
          if mapID == 2442 then
            return "Tazavesh: So'leah's Gambit"
          end
          return "Map " .. tostring(mapID)
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      local spellID = addon.Teleport.ResolveSeason3TeleportSpellID(nil, "Queue to Tazavesh Gambit")
      Assert.Equal(spellID, 367416, "Tazavesh token matching should resolve shared teleport spell")
    end)
  end)

  test("Teleport resolves Eco-Dome via localized dungeon-name fallback tokens", function()
    local createFrameStub = BuildCreateFrameStub()

    WithGlobals({
      CreateFrame = createFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
      })
      local spellID = addon.Teleport.ResolveSeason3TeleportSpellID(nil, "Biokuppel Al'dani")
      Assert.Equal(spellID, 1237215, "localized Biokuppel token should resolve Eco-Dome teleport spell")
    end)
  end)

  test("Teleport resolves activity fallback by localized name when mapID is missing", function()
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

      Assert.Equal(first, 1237215, "activity name fallback should resolve Eco-Dome teleport spell")
      Assert.Equal(second, 1237215, "name-fallback result should be cached")
    end)

    Assert.Equal(activityInfoCalls, 1, "activity lookup should be cached after name-fallback resolve")
  end)

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
