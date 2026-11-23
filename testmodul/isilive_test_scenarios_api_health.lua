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
    -- Rule 268: the estimate sensors need Blizzard's aura container template.
    globals.C_XMLUtil.GetTemplateInfo = function(name)
      return name == "CustomAuraContainerTemplate" and { type = "AuraContainer" } or nil
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

  -- Rule 269: the outlined font of the defensive icon numbers can vanish in a
  -- patch; the self test names it, the cell keeps the plain font.
  test("ApiHealth reports a missing defensive icon font as MISSING", function()
    local checks = LoadAddonModules({ "isiLive_api_health.lua" }).ApiHealth.CHECKS
    local globals = BuildAllPresentGlobals(checks)
    local present, missing
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_api_health.lua" })
      addon.RosterDefensiveCell = { ICON_FONT = "TestIconFontOutline" }
      _G.TestIconFontOutline = {}
      local _, counts = addon.ApiHealth.BuildReportLines(false)
      present = counts
      _G.TestIconFontOutline = nil
      local lines
      lines, missing = addon.ApiHealth.BuildReportLines(false)
      missing.text = table.concat(lines, "\n")
    end)
    Assert.Equal(present.missing, 0, "the font object is there")
    Assert.Equal(present.ok, #checks + 1, "one extra row for the font")
    Assert.Equal(missing.missing, 1, "a dropped font object is missing")
    Assert.True(
      missing.text:find("MISSING TestIconFontOutline - Defensives (plain font used instead)", 1, true) ~= nil,
      "the line names the font and the fallback"
    )
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

  -- Rule 261: data checks. The IDs come from the shipped manifest of the
  -- active season (read at run time, no season literal).
  test("ApiHealth data checks report season IDs the client no longer resolves", function()
    local probe = LoadAddonModules({ "isiLive_season_data.lua" })
    local season = probe.SeasonData.GetSeasonConfig()
    local mapIDs = probe.SeasonData.GetOrderedMapIDs()
    local firstMapID = mapIDs[1]
    local removedSpellID = season.mapToTeleport[firstMapID]
    removedSpellID = type(removedSpellID) == "table" and removedSpellID[1] or removedSpellID
    local driftedActivityID
    for activityID, mapID in pairs(season.activityToMap) do
      if mapID == firstMapID then
        driftedActivityID = activityID
      end
    end
    local lines, dataCounts
    WithGlobals({
      C_Spell = {
        GetSpellName = function(spellID)
          return spellID ~= removedSpellID and ("Spell " .. spellID) or nil
        end,
      },
      C_ChallengeMode = {
        GetMapUIInfo = function(mapID)
          return "Map " .. mapID, mapID, 1800, nil, nil, mapID + 5000
        end,
      },
      C_LFGList = {
        GetActivityInfoTable = function(activityID)
          local mapID = season.activityToMap[activityID]
          local instanceID = activityID == driftedActivityID and 1 or mapID + 5000
          return { mapID = instanceID, fullName = "Activity " .. activityID }
        end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_season_data.lua",
        "isiLive_spells.lua",
        "isiLive_consumables.lua",
        "isiLive_api_health.lua",
      })
      local reportLines, _, reportDataCounts = addon.ApiHealth.BuildReportLines(false)
      lines, dataCounts = reportLines, reportDataCounts
    end)
    local joined = table.concat(lines, "\n")
    Assert.True(
      joined:find(string.format("MISSING portal spell %d - Season data", removedSpellID), 1, true) ~= nil,
      "a portal spell the client no longer knows is reported"
    )
    Assert.True(
      joined:find(string.format("ERROR LFG activity %d - Season data (instance 1,", driftedActivityID), 1, true) ~= nil,
      "an activity that moved to another instance is reported"
    )
    Assert.Equal(dataCounts.missing, 1, "exactly the removed spell is missing")
    Assert.Equal(dataCounts.error, 1, "exactly the drifted activity is wrong")
    Assert.True(joined:find("data IDs", 1, true) ~= nil, "the data checks end with their own summary")
  end)

  test("ApiHealth patch watch stays silent for a clean client and runs once per build", function()
    local checks = LoadAddonModules({ "isiLive_api_health.lua" }).ApiHealth.CHECKS
    local printed, build = {}, "70001"
    local db = {}
    WithGlobals(BuildAllPresentGlobals(checks), function()
      local addon = LoadAddonModules({ "isiLive_api_health.lua" })
      local watch = addon.ApiHealth.CreatePatchWatch({
        getDB = function()
          return db
        end,
        printFn = function(line)
          printed[#printed + 1] = line
        end,
        getBuild = function()
          return build
        end,
        after = function(_delay, fn)
          fn()
        end,
      })
      watch.OnLogin()
      Assert.Equal(db.selftestBuild, "70001", "the checked build is stored")
      Assert.Equal(#printed, 0, "a clean client prints nothing")
      watch.OnLogin()
      Assert.Nil(watch.CheckNow(), "the same build is not checked again")
    end)
  end)

  test("ApiHealth data checks cover interrupt spells and the keystone item", function()
    local kickIDs = LoadAddonModules({ "isiLive_kick_tracker.lua" }).KickTracker.GetInterruptSpellIDs()
    Assert.True(#kickIDs > 0, "the kick tracker lists its interrupt spells")
    local removedKickID = kickIDs[1]
    local rows
    WithGlobals({
      C_Spell = {
        GetSpellName = function(spellID)
          return spellID ~= removedKickID and ("Spell " .. spellID) or nil
        end,
      },
      C_Item = {
        GetItemInfoInstant = function(_itemID)
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua", "isiLive_api_health.lua" })
      rows = addon.ApiHealth.RunDataChecks()
    end)
    local missing = {}
    for _, row in ipairs(rows) do
      if row.status == "missing" then
        missing[row.name .. " - " .. row.feature] = true
      end
    end
    Assert.True(missing["interrupt spell " .. removedKickID .. " - Kicks"], "a removed interrupt spell is reported")
    local keystoneItemID = LoadAddonModules({}).ItemManifest.mythicKeystone
    Assert.True(missing["item " .. keystoneItemID .. " - Items"], "an unknown keystone item is reported")
  end)

  test("Item manifest owns the keystone item ID", function()
    local keystoneItemID = tostring(LoadAddonModules({}).ItemManifest.mythicKeystone)
    local handle = assert(io.open("isiLive.toc", "rb"))
    local toc = handle:read("*a")
    handle:close()
    local offenders = {}
    for line in toc:gmatch("[^\r\n]+") do
      local path = line:match("^%s*([%w_/]+%.lua)%s*$")
      if path and not path:match("^libs/") and not path:match("^data/") then
        local file = assert(io.open(path, "rb"))
        local content = file:read("*a")
        file:close()
        if content:find(keystoneItemID, 1, true) then
          offenders[#offenders + 1] = path
        end
      end
    end
    Assert.Equal(table.concat(offenders, ", "), "", "no runtime file repeats the keystone item ID")
  end)

  test("ApiHealth accepts the fallback API the runtime uses when the first one is missing", function()
    local checks = LoadAddonModules({ "isiLive_api_health.lua" }).ApiHealth.CHECKS
    local function Report(withGlobal)
      local globals = BuildAllPresentGlobals(checks)
      globals.C_Item.GetAverageItemLevel = nil
      globals.GetAverageItemLevel = withGlobal and Noop or nil
      local lines, counts
      WithGlobals(globals, function()
        local addon = LoadAddonModules({ "isiLive_api_health.lua" })
        lines, counts = addon.ApiHealth.BuildReportLines(true)
      end)
      return table.concat(lines, "\n"), counts
    end
    local text, counts = Report(true)
    Assert.Equal(counts.missing, 0, "the global item level API covers the missing C_Item one")
    Assert.True(
      text:find("ok C_Item.GetAverageItemLevel - Item level (via GetAverageItemLevel)", 1, true) ~= nil,
      "verbose mode names the fallback in use"
    )
    text, counts = Report(false)
    Assert.Equal(counts.missing, 1, "without either API the check is missing")
    Assert.True(text:find("MISSING C_Item.GetAverageItemLevel - Item level", 1, true) ~= nil, "named as before")
  end)

  -- Package 5 O: a specialization the client knows but data/isiLive_specs.lua
  -- lacks (a new spec of an expansion) is reported on patch day.
  test("ApiHealth data checks report a client specialization missing from the spec manifest", function()
    local rows
    WithGlobals({
      GetNumClasses = function()
        return 1
      end,
      GetNumSpecializationsForClassID = function(classID)
        return classID == 1 and 2 or 0
      end,
      GetSpecializationInfoForClassID = function(_classID, specIndex)
        if specIndex == 1 then
          return 71, "Arms"
        end
        return 9999, "Brand New"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_specs.lua", "isiLive_api_health.lua" })
      rows = addon.ApiHealth.RunDataChecks()
    end)
    local byName = {}
    for _, row in ipairs(rows) do
      if row.feature == "Specs" then
        byName[row.name] = row
      end
    end
    Assert.Equal(byName["spec 71"].status, "ok", "a manifest spec passes")
    Assert.Equal(byName["spec 9999"].status, "missing", "the unknown client spec is missing")
    Assert.True(byName["spec 9999"].detail:find("Brand New", 1, true) ~= nil, "the row names the client's spec")
  end)
end
