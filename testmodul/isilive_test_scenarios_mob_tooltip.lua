---@diagnostic disable: undefined-global

local function MakeGameTooltip(tooltipLines)
  local tooltip = {
    _lineColors = {},
    AddLine = function(self, text, r, g, b)
      table.insert(tooltipLines, text)
      table.insert(self._lineColors, { r, g, b })
    end,
    HookScript = function(self, script, handler)
      self[script] = handler
    end,
  }
  return tooltip
end

local function NewMplusForcesDB()
  return {
    season = "midnight_s1",
    mdtVersion = "test",
    generatedAt = "2026-04-21",
    expiresAt = "2026-05-06",
    dungeonCount = 2,
    npcCount = 3,
    dungeonTotal = {
      [161] = { total = 431, name = "Skyreach" },
      [556] = { total = 643, name = "Pit of Saron" },
    },
    byNpcId = {
      [76132] = { count = 5, mapID = 161 }, -- Soaring Chakram Master
      [252551] = { count = 15, mapID = 556 }, -- Deathwhisper Necrolyte
      [999999] = { count = 0, mapID = 161 }, -- zero-count entry (should be skipped)
    },
  }
end

local function SetupTooltipEnv(WithGlobals, overrides, fn)
  overrides = overrides or {}
  local postCalls = {}
  local globals = {
    TooltipDataProcessor = {
      AddTooltipPostCall = function(dataType, callback)
        table.insert(postCalls, { dataType = dataType, callback = callback })
      end,
    },
    Enum = {
      TooltipDataType = {
        Unit = 1,
      },
    },
    C_ChallengeMode = overrides.C_ChallengeMode or {
      GetActiveChallengeMapID = function()
        return 161
      end,
    },
    UnitGUID = overrides.UnitGUID or function()
      return nil
    end,
    issecretvalue = overrides.issecretvalue,
    GameTooltip = overrides.GameTooltip,
  }
  if overrides.globals then
    for k, v in pairs(overrides.globals) do
      globals[k] = v
    end
  end
  WithGlobals(globals, function()
    fn(postCalls)
  end)
end

local function RegisterRegistrationTests(test, Assert, WithGlobals, LoadAddonModules)
  test("MobTooltip registers exactly one unit post-call with TooltipDataProcessor", function()
    SetupTooltipEnv(WithGlobals, {}, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" })
      local registered = addon.MobTooltip.Register()
      Assert.True(registered, "Register() should report success when TooltipDataProcessor is present")
      Assert.Equal(#postCalls, 1, "MobTooltip should register exactly one unit post-call")
      Assert.Equal(postCalls[1].dataType, 1, "MobTooltip must register against Enum.TooltipDataType.Unit")

      addon.MobTooltip.Register()
      Assert.Equal(#postCalls, 1, "Register() must be idempotent when called a second time")
    end)
  end)

  test("MobTooltip.Register returns false when TooltipDataProcessor is unavailable", function()
    WithGlobals({
      TooltipDataProcessor = nil,
      Enum = nil,
    }, function()
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" })
      local ok = addon.MobTooltip.Register()
      Assert.False(ok, "Register() should report failure when TooltipDataProcessor is missing")
    end)
  end)
end

local function RegisterTooltipRenderTests(test, Assert, WithGlobals, LoadAddonModules)
  test("MobTooltip appends forces line for matching creature in active M+ key", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, { GameTooltip = tooltip }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })
      addon.MobTooltip.Register()
      postCalls[1].callback(tooltip, {
        guid = "Creature-0-3889-161-12345-76132-0000ABCDEF",
      })
      Assert.Equal(#tooltipLines, 1, "tooltip should gain one forces line")
      -- 5 / 431 * 100 = 1.16%
      Assert.True(
        tooltipLines[1]:find("1.16", 1, true) ~= nil,
        "forces line should render the percent with two decimals: " .. tostring(tooltipLines[1])
      )
      Assert.True(
        tooltipLines[1]:find("+5", 1, true) ~= nil,
        "forces line should include the raw count: " .. tostring(tooltipLines[1])
      )
      Assert.Equal(tooltip._lineColors[1][1], 0.64, "forces tooltip line must use the shared cool text role")
      Assert.Equal(tooltip._lineColors[1][2], 0.80, "forces tooltip line must use the shared cool text role")
      Assert.Equal(tooltip._lineColors[1][3], 0.96, "forces tooltip line must use the shared cool text role")
    end)
  end)

  test("MobTooltip skips creatures belonging to a different dungeon than the active key", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, { GameTooltip = tooltip }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })
      addon.MobTooltip.Register()
      -- NPC 252551 is Pit of Saron (556); active map is Skyreach (161).
      postCalls[1].callback(tooltip, {
        guid = "Creature-0-3889-556-12345-252551-0000ABCDEF",
      })
      Assert.Equal(#tooltipLines, 0, "mismatched mapID must not append a forces line")
    end)
  end)

  test("MobTooltip skips player GUIDs", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, { GameTooltip = tooltip }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })
      addon.MobTooltip.Register()
      postCalls[1].callback(tooltip, {
        guid = "Player-3685-0ABCDEF1",
      })
      Assert.Equal(#tooltipLines, 0, "player GUIDs must not produce a forces line")
    end)
  end)

  test("MobTooltip skips NPCs absent from the DB", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, { GameTooltip = tooltip }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })
      addon.MobTooltip.Register()
      postCalls[1].callback(tooltip, {
        guid = "Creature-0-3889-161-12345-11111-0000ABCDEF",
      })
      Assert.Equal(#tooltipLines, 0, "unknown NPCs must not produce a forces line")
    end)
  end)

  test("MobTooltip skips NPC entries with zero count", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, { GameTooltip = tooltip }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })
      addon.MobTooltip.Register()
      postCalls[1].callback(tooltip, {
        guid = "Creature-0-3889-161-12345-999999-0000ABCDEF",
      })
      Assert.Equal(#tooltipLines, 0, "NPC entries with count=0 (bosses) must not produce a forces line")
    end)
  end)
end

local function RegisterGuardTests(test, Assert, WithGlobals, LoadAddonModules)
  test("MobTooltip suppresses the line when no M+ key is active", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, {
      GameTooltip = tooltip,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })
      addon.MobTooltip.Register()
      postCalls[1].callback(tooltip, {
        guid = "Creature-0-3889-161-12345-76132-0000ABCDEF",
      })
      Assert.Equal(#tooltipLines, 0, "no active key must suppress the forces line")
    end)
  end)

  test("MobTooltip honors issecretvalue on the active map ID", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    local secretMap = {}
    SetupTooltipEnv(WithGlobals, {
      GameTooltip = tooltip,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return secretMap
        end,
      },
      issecretvalue = function(value)
        return value == secretMap
      end,
    }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })
      addon.MobTooltip.Register()
      postCalls[1].callback(tooltip, {
        guid = "Creature-0-3889-161-12345-76132-0000ABCDEF",
      })
      Assert.Equal(#tooltipLines, 0, "secret-value map IDs must suppress the forces line")
    end)
  end)

  test("MobTooltip honors issecretvalue on tooltipData.guid and UnitGUID fallback", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    -- Real-engine secret GUIDs still have type "string"; only comparisons taint.
    -- Simulate by making issecretvalue() return true for these specific strings.
    local secretDataGuid = "Creature-0-3889-161-12345-76132-0000SECRET1"
    local secretMouseGuid = "Creature-0-3889-161-12345-76132-0000SECRET2"
    SetupTooltipEnv(WithGlobals, {
      GameTooltip = tooltip,
      UnitGUID = function()
        return secretMouseGuid
      end,
      issecretvalue = function(value)
        return value == secretDataGuid or value == secretMouseGuid
      end,
    }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })
      addon.MobTooltip.Register()
      -- tooltipData.guid is secret — must be rejected before the "" comparison / match.
      postCalls[1].callback(tooltip, { guid = secretDataGuid })
      Assert.Equal(#tooltipLines, 0, "secret tooltipData.guid must be ignored without error")
      -- UnitGUID fallback also returns a secret — must also be ignored.
      postCalls[1].callback(tooltip, { dataInstanceID = 42 })
      Assert.Equal(#tooltipLines, 0, "secret UnitGUID fallback must be ignored without error")
    end)
  end)

  test("MobTooltip.SetEnabled(false) suppresses the forces line", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, { GameTooltip = tooltip }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })
      addon.MobTooltip.Register()
      addon.MobTooltip.SetEnabled(false)
      postCalls[1].callback(tooltip, {
        guid = "Creature-0-3889-161-12345-76132-0000ABCDEF",
      })
      Assert.Equal(#tooltipLines, 0, "disabled MobTooltip must not render the forces line")

      addon.MobTooltip.SetEnabled(true)
      postCalls[1].callback(tooltip, {
        guid = "Creature-0-3889-161-12345-76132-0000ABCDEF",
      })
      Assert.Equal(#tooltipLines, 1, "re-enabled MobTooltip must render the forces line again")
    end)
  end)

  test("MobTooltip does nothing when the forces DB is not loaded", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, { GameTooltip = tooltip }, function(postCalls)
      -- No seeded MPlusForces → addonTable has no DB available.
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" })
      addon.MobTooltip.Register()
      postCalls[1].callback(tooltip, {
        guid = "Creature-0-3889-161-12345-76132-0000ABCDEF",
      })
      Assert.Equal(#tooltipLines, 0, "missing MPlusForces DB must be handled gracefully")
    end)
  end)

  test("MobTooltip hides a Forces DB that does not match the active season", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, { GameTooltip = tooltip }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, {
        SeasonData = {
          GetMatchingForcesData = function()
            return nil
          end,
        },
        MPlusForces = NewMplusForcesDB(),
      })
      addon.MobTooltip.Register()
      postCalls[1].callback(tooltip, {
        guid = "Creature-0-3889-161-12345-76132-0000ABCDEF",
      })
      Assert.Equal(#tooltipLines, 0, "mismatched season Forces must render no tooltip line")
    end)
  end)
end

local function RegisterDedupeTests(test, Assert, WithGlobals, LoadAddonModules)
  test("MobTooltip does not stack duplicate forces lines on repeated post-call fires", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, { GameTooltip = tooltip }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })
      addon.MobTooltip.Register()
      local data = { guid = "Creature-0-3889-161-12345-76132-0000ABCDEF" }
      postCalls[1].callback(tooltip, data)
      postCalls[1].callback(tooltip, data)
      postCalls[1].callback(tooltip, data)
      Assert.Equal(#tooltipLines, 1, "repeated fires on the same tooltip+guid must produce a single line")
    end)
  end)

  test("MobTooltip re-renders the line after OnTooltipCleared fires", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, { GameTooltip = tooltip }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })
      addon.MobTooltip.Register()
      local data = { guid = "Creature-0-3889-161-12345-76132-0000ABCDEF" }
      postCalls[1].callback(tooltip, data)
      Assert.Equal(#tooltipLines, 1, "initial fire should append one line")

      if type(tooltip.OnTooltipCleared) == "function" then
        tooltip:OnTooltipCleared()
      end
      postCalls[1].callback(tooltip, data)
      Assert.Equal(#tooltipLines, 2, "after clearing the tooltip, the line must be appended again")
    end)
  end)

  test("MobTooltip falls back to UnitGUID('mouseover') when tooltip data has no GUID", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, {
      GameTooltip = tooltip,
      UnitGUID = function(unit)
        if unit == "mouseover" then
          return "Creature-0-3889-161-12345-76132-0000ABCDEF"
        end
        return nil
      end,
      globals = {
        UnitExists = function(unit)
          return unit == "mouseover"
        end,
      },
    }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })
      addon.MobTooltip.Register()
      postCalls[1].callback(tooltip, { dataInstanceID = 42 })
      Assert.Equal(#tooltipLines, 1, "forces line should render via UnitGUID fallback")
    end)
  end)

  test("MobTooltip requires an existing mouseover before UnitGUID fallback", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, {
      GameTooltip = tooltip,
      UnitGUID = function()
        error("missing mouseover must stop before GUID lookup", 0)
      end,
      globals = {
        UnitExists = function()
          return false
        end,
      },
    }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })
      addon.MobTooltip.Register()
      postCalls[1].callback(tooltip, { dataInstanceID = 42 })
      Assert.Equal(#tooltipLines, 0, "missing mouseover must keep forces tooltip unresolved")
    end)
  end)

  test("MobTooltip tolerates SetLocaleGetter returning a non-table", function()
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, { GameTooltip = tooltip }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })
      addon.MobTooltip.Register()
      -- A buggy locale getter that returns nil instead of the expected table
      -- must not crash AppendForcesLine; the English fallback format kicks in.
      addon.MobTooltip.SetLocaleGetter(function()
        return nil
      end)
      postCalls[1].callback(tooltip, { guid = "Creature-0-3889-161-12345-76132-0000ABCDEF" })
      Assert.Equal(#tooltipLines, 1, "non-table locale must still produce a forces line via fallback format")
      Assert.True(
        tooltipLines[1]:find("+5", 1, true) ~= nil,
        "fallback format must include the raw count: " .. tostring(tooltipLines[1])
      )
    end)
  end)

  test("MobTooltip.Register re-attempts OnTooltipCleared hook on later calls if GameTooltip was missing", function()
    -- Models the (theoretical) ordering bug where Register fires before
    -- GameTooltip is constructed. The first call registers the TDP callback
    -- but cannot install the dedupe-clear hook; a follow-up Register() once
    -- GameTooltip is available must wire the hook so re-hovering the same mob
    -- doesn't silently lose the forces line.
    local tooltipLines = {}
    local tooltip = MakeGameTooltip(tooltipLines)
    SetupTooltipEnv(WithGlobals, { GameTooltip = nil }, function(postCalls)
      local addon = LoadAddonModules({ "isiLive_mob_tooltip.lua" }, { MPlusForces = NewMplusForcesDB() })

      -- First Register: GameTooltip missing, TDP wired, but no hook.
      Assert.True(addon.MobTooltip.Register(), "first Register call must succeed even without GameTooltip")
      Assert.Equal(#postCalls, 1, "TDP callback should be installed on the first Register call")
      Assert.Nil(tooltip.OnTooltipCleared, "GameTooltip was unavailable, so no clear hook attached yet")

      -- Now GameTooltip becomes available (e.g. Blizzard finished UI init).
      rawset(_G, "GameTooltip", tooltip)
      Assert.True(addon.MobTooltip.Register(), "second Register call must remain idempotent and succeed")
      Assert.Equal(#postCalls, 1, "second Register call must NOT install a duplicate TDP callback")
      Assert.NotNil(tooltip.OnTooltipCleared, "second Register call must install the OnTooltipCleared hook")

      -- Dedupe-clear should now work: render, clear, render again, expect two lines.
      local data = { guid = "Creature-0-3889-161-12345-76132-0000ABCDEF" }
      postCalls[1].callback(tooltip, data)
      tooltip:OnTooltipCleared()
      postCalls[1].callback(tooltip, data)
      Assert.Equal(#tooltipLines, 2, "after the deferred hook attaches, re-hover must restore the forces line")
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterRegistrationTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTooltipRenderTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterGuardTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterDedupeTests(test, Assert, WithGlobals, LoadAddonModules)
end
