---@diagnostic disable: undefined-global

-- Patch-day self test (rule 251, game/isiLive_api_health.lua).

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  local function Noop() end

  -- Every API in ApiHealth.CHECKS present, with the probes answering.
  local function BuildAllPresentGlobals(addonCheckList)
    local globals = {}
    for _, check in ipairs(addonCheckList) do
      local rootName, fnName = check[2], check[3]
      if rootName == nil then
        globals[fnName] = Noop
      else
        globals[rootName] = globals[rootName] or {}
        globals[rootName][fnName] = Noop
      end
    end
    globals.C_ChallengeMode.GetMapTable = function()
      return { 1, 2, 3 }
    end
    globals.C_CurveUtil.CreateCurve = function()
      return {}
    end
    return globals
  end

  test("ApiHealth reports a clean client with every Blizzard API present", function()
    local checks = LoadAddonModules({ "isiLive_api_health.lua" }).ApiHealth.CHECKS
    local lines, counts
    WithGlobals(BuildAllPresentGlobals(checks), function()
      local addon = LoadAddonModules({ "isiLive_api_health.lua" })
      lines, counts = addon.ApiHealth.BuildReportLines(false)
    end)
    Assert.Equal(counts.missing, 0, "nothing is missing")
    Assert.Equal(counts.error, 0, "no probe fails")
    Assert.Equal(counts.ok, #checks, "every check passes")
    Assert.Equal(#lines, 1, "a clean client prints only the summary")
    Assert.True(lines[1]:find(string.format("%d ok, 0 missing, 0 error", #checks), 1, true) ~= nil, "summary")
  end)

  test("ApiHealth lists missing APIs and failed probes first and every check in verbose mode", function()
    local checks = LoadAddonModules({ "isiLive_api_health.lua" }).ApiHealth.CHECKS
    local globals = BuildAllPresentGlobals(checks)
    globals.C_DamageMeter = nil
    globals.UnitHealthPercent = nil
    globals.C_ChallengeMode.GetMapTable = function()
      error("removed")
    end
    globals.C_CurveUtil.CreateCurve = function()
      return nil
    end
    local lines, counts, verboseLines
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_api_health.lua" })
      lines, counts = addon.ApiHealth.BuildReportLines(false)
      verboseLines = addon.ApiHealth.BuildReportLines(true)
    end)
    Assert.Equal(counts.missing, 2, "the damage meter and UnitHealthPercent are missing")
    Assert.Equal(counts.error, 2, "the map table and curve probes fail")
    Assert.Equal(#lines, 5, "four failure lines and the summary")
    Assert.True(lines[1]:find("MISSING", 1, true) ~= nil, "missing APIs come first")
    local joined = table.concat(lines, "\n")
    Assert.True(
      joined:find("MISSING C_DamageMeter.GetCombatSessionFromType - DPS / kicks", 1, true) ~= nil,
      "the line names the API and the feature it breaks"
    )
    Assert.True(joined:find("MISSING UnitHealthPercent - TTK", 1, true) ~= nil, "global APIs are named bare")
    Assert.True(joined:find("ERROR C_ChallengeMode.GetMapTable - Season (error)", 1, true) ~= nil, "probe error")
    Assert.True(joined:find("ERROR C_CurveUtil.CreateCurve - TTK (no curve)", 1, true) ~= nil, "probe detail")
    Assert.Equal(#verboseLines, #checks + 1, "verbose mode lists every check and the summary")
  end)
end
