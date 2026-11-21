---@diagnostic disable: undefined-global
-- Patch watch tools (rule 262): tools/check_toc_interface.lua and
-- tools/check_api_surface.lua, driven with small synthetic inputs so the
-- tests need no network and no clone of Blizzard's documentation.

local osLib = rawget(_G, "os")
local ioLib = rawget(_G, "io")

local function LoadTool(path)
  local chunk = assert(loadfile(path))
  return chunk("module")
end

local function IsWindows()
  return package.config:sub(1, 1) == "\\"
end

local function EnsureDir(path)
  if IsWindows() then
    osLib.execute('mkdir "' .. path:gsub("/", "\\") .. '" >nul 2>nul')
  else
    osLib.execute("mkdir -p '" .. path .. "' >/dev/null 2>/dev/null")
  end
end

local function WriteFile(path, content)
  local file = assert(ioLib.open(path, "wb"))
  file:write(content)
  file:close()
end

local function VersionTable(versionName)
  return table.concat({
    "Region!STRING:0|BuildConfig!HEX:16|BuildId!DEC:4|VersionsName!String:0",
    "## seqn = 1",
    "eu|abc|1|" .. versionName,
    "us|abc|1|" .. versionName,
    "",
  }, "\n")
end

-- One documentation file in Blizzard's generated format.
local function DocFile(functions, events, enumFields)
  local lines = { "local Doc =", "{", '  Name = "Doc",', '  Type = "System",', '  Namespace = "C_Test",' }
  lines[#lines + 1] = "  Functions ="
  lines[#lines + 1] = "  {"
  for _, fn in ipairs(functions) do
    lines[#lines + 1] = string.format(
      '    { Name = "%s", Type = "Function", Arguments = { %s }, Returns = { %s } },',
      fn[1],
      fn[2],
      fn[3]
    )
  end
  lines[#lines + 1] = "  },"
  lines[#lines + 1] = "  Events ="
  lines[#lines + 1] = "  {"
  for _, event in ipairs(events) do
    lines[#lines + 1] =
      string.format('    { Name = "E", Type = "Event", LiteralName = "%s", Payload = { %s } },', event[1], event[2])
  end
  lines[#lines + 1] = "  },"
  lines[#lines + 1] = "  Tables ="
  lines[#lines + 1] = "  {"
  local fields = {}
  for _, field in ipairs(enumFields) do
    fields[#fields + 1] = string.format('{ Name = "%s", Type = "TestKind", EnumValue = 0 }', field)
  end
  lines[#lines + 1] = string.format(
    '    { Name = "TestKind", Type = "Enumeration", NumValues = Enum.TestKindMeta.NumValues, Fields = { %s } },',
    table.concat(fields, ", ")
  )
  lines[#lines + 1] = "  },"
  lines[#lines + 1] = "};"
  lines[#lines + 1] = "APIDocumentation:AddDocumentationTable(Doc);"
  return table.concat(lines, "\n")
end

local function Arg(name, typeName, nilable)
  return string.format('{ Name = "%s", Type = "%s", Nilable = %s }', name, typeName, tostring(nilable == true))
end

return function(test, ctx)
  local Assert = ctx.assert

  test("TOC interface check reports a missing interface of a client newer than live", function()
    local tool = LoadTool("tools/check_toc_interface.lua")
    local live = tool.ParseVersions(VersionTable("12.1.5.70961"))
    Assert.Equal(live.name, "12.1.5.70961", "the us row is read")
    Assert.Equal(tool.InterfaceOf(live), 120105, "MAJOR plus two-digit MINOR and PATCH")
    local toc = tool.ParseTocInterfaces("## Title: x\n## Interface: 120105, 120107\n")
    local versions = {
      wow = live,
      wowt = tool.ParseVersions(VersionTable("12.2.0.71500")),
      wowxptr = tool.ParseVersions(VersionTable("12.1.5.70340")),
      wow_beta = tool.ParseVersions(VersionTable("12.0.1.66220")),
    }
    local code, report = tool.Evaluate(versions, toc)
    Assert.Equal(code, 1, "the newer PTR interface is missing")
    Assert.True(report:find("Missing: `120200` (PTR)", 1, true) ~= nil, "the report names the missing interface")
    Assert.Nil(report:find("`120001`", 1, true), "an older beta is not required")

    versions.wowt = tool.ParseVersions(VersionTable("12.1.7.70986"))
    code = tool.Evaluate(versions, toc)
    Assert.Equal(code, 0, "every relevant interface is listed")
    code = tool.Evaluate({ wowt = versions.wowt }, toc)
    Assert.Equal(code, 2, "without a live version the check is unresolved")
  end)

  -- Package 5 N: the season doctor on the shipped data; the simulator runs are
  -- replaced by a stub so the test stays fast and deterministic.
  test("Season doctor passes the shipped active season and lists open steps for another season", function()
    local doctor = LoadTool("tools/season_doctor.lua")
    local simRuns = {}
    local function Sim(ok)
      return function(seasonID, locale)
        simRuns[#simRuns + 1] = seasonID .. ":" .. locale
        return ok
      end
    end
    local manifest = assert(loadfile("testmodul/isilive_test_fixture_seasons.lua"))().ShippedManifest()

    -- A fixed date keeps the forces expiry out of the test; the lifetime gate
    -- checks the real date in CI.
    local code, report = doctor.Run({ season = manifest.activeSeasonID, runSim = Sim(true), today = "2026-01-01" })
    Assert.Equal(code, 0, "the shipped active season passes every automatic check:\n" .. report)
    Assert.Equal(#simRuns, 2, "the season smoke runs in enUS and deDE")
    Assert.True(report:find("Still to do by hand", 1, true) ~= nil, "the in-game steps are listed")

    code, report = doctor.Run({ season = manifest.activeSeasonID, runSim = Sim(false), today = "2026-01-01" })
    Assert.Equal(code, 1, "a failed simulator run fails the doctor")
    Assert.True(report:find("[ ] wowsim season_smoke enUS", 1, true) ~= nil, "the failed run is listed as open")

    local other
    for seasonID in pairs(manifest.seasons) do
      if seasonID ~= manifest.activeSeasonID and seasonID ~= manifest.upcomingSeasonID then
        other = seasonID
      end
    end
    if other then
      code, report = doctor.Run({ season = other, noSim = true })
      Assert.Equal(code, 1, "a season that is neither active nor prepared has open steps")
      Assert.True(report:find("[ ] upcomingSeasonID", 1, true) ~= nil, "it asks for upcomingSeasonID")
    end
    code = doctor.Run({ season = "no_such_season", noSim = true })
    Assert.Equal(code, 2, "an unknown season is unresolved")
  end)

  test("API surface check reports removed and changed surface isiLive uses", function()
    local tool = LoadTool("tools/check_api_surface.lua")
    local sep = IsWindows() and "\\" or "/"
    local root = "tools" .. sep .. "cache" .. sep .. "test_api_surface"
    EnsureDir(root .. sep .. "live")
    EnsureDir(root .. sep .. "ptr")
    WriteFile(
      root .. sep .. "live" .. sep .. "TestDocumentation.lua",
      DocFile({
        { "Gone", "", "" },
        { "AddsOptional", Arg("a", "number"), "" },
        { "AddsRequired", Arg("a", "number"), "" },
        { "AddsReturn", "", Arg("r", "number") },
        { "Unused", "", "" },
      }, {
        { "TEST_GONE", "" },
        { "TEST_SHIFTED", Arg("a", "bool") .. ", " .. Arg("b", "bool") },
        { "TEST_ACKED", Arg("a", "bool") },
      }, { "Kept", "Dropped" })
    )
    WriteFile(
      root .. sep .. "ptr" .. sep .. "TestDocumentation.lua",
      DocFile({
        { "AddsOptional", Arg("a", "number") .. ", " .. Arg("b", "number", true), "" },
        { "AddsRequired", Arg("a", "number") .. ", " .. Arg("b", "number"), "" },
        { "AddsReturn", "", Arg("r", "number") .. ", " .. Arg("s", "number") },
        { "Unused", "", "" },
      }, {
        { "TEST_SHIFTED", Arg("a", "bool") .. ", " .. Arg("x", "bool") .. ", " .. Arg("b", "bool") },
        { "TEST_ACKED", Arg("x", "bool") .. ", " .. Arg("a", "bool") },
      }, { "Kept" })
    )
    local source = table.concat({
      "C_Test.Gone() C_Test.AddsOptional(1) C_Test.AddsRequired(1) C_Test.AddsReturn()",
      'local api = rawget(_G, "C_Missing") rawget(api, "NotDocumented")',
      'Register("TEST_GONE") Register("TEST_SHIFTED") Register("TEST_ACKED")',
      "local kind = Enum.TestKind.Kept + Enum.TestKind.Dropped",
    }, "\n")
    local opts = {
      live = root .. "/live",
      target = root .. "/ptr",
      label = "ptr",
      liveVersion = "12.1.5 (1)",
      targetVersion = "12.1.7 (2)",
      texts = { source },
      acknowledged = {
        TEST_ACKED = { detail = "payload `(a:bool)` -> `(x:bool, a:bool)`", reason = "reads no payload" },
      },
    }
    local code, report = tool.Run(opts)
    Assert.Equal(code, 1, "removed and changed surface fails the check")
    local function Row(kind, name)
      return report:find(string.format("| %s | `%s` |", kind, name), 1, true) ~= nil
    end
    Assert.True(Row("removed", "C_Test.Gone"), "a removed function is reported")
    Assert.True(Row("extended", "C_Test.AddsOptional"), "an appended optional argument is compatible")
    Assert.True(Row("changed", "C_Test.AddsRequired"), "an appended required argument breaks callers")
    Assert.True(Row("extended", "C_Test.AddsReturn"), "an appended return value is compatible")
    Assert.True(Row("removed", "TEST_GONE"), "a removed event is reported")
    Assert.True(Row("changed", "TEST_SHIFTED"), "a payload value inserted in the middle shifts positions")
    Assert.True(Row("acknowledged", "TEST_ACKED"), "an acknowledged exact change is marked")
    Assert.True(Row("removed", "Enum.TestKind.Dropped"), "a removed enum field is reported")
    Assert.Nil(report:find("C_Test.Unused", 1, true), "surface isiLive does not use stays out")
    Assert.True(report:find("C_Missing.NotDocumented", 1, true) ~= nil, "undocumented names are listed, not compared")

    opts.texts = { 'C_Test.AddsReturn() Register("TEST_ACKED")' }
    code = tool.Run(opts)
    Assert.Equal(code, 0, "only compatible or acknowledged rows keep the check green")

    -- Once no finding needs the acknowledgement it is reported for removal.
    opts.texts = { "C_Test.AddsReturn()" }
    local staleCode, staleReport = tool.Run(opts)
    Assert.Equal(staleCode, 0, "a stale acknowledgement fails nothing")
    Assert.True(
      staleReport:find("remove them from tools/patch_watch_ack.lua: TEST_ACKED", 1, true) ~= nil,
      "the stale acknowledgement is named"
    )
    opts.texts = { 'C_Test.AddsReturn() Register("TEST_ACKED")' }

    opts.targetVersion = "12.1.5 (3)"
    local skippedCode, skipped = tool.Run(opts)
    Assert.Equal(skippedCode, 0, "a target that is not newer than live is skipped")
    Assert.True(skipped:find("skipped", 1, true) ~= nil, "the skip is reported")
  end)

  -- Rule 265 (package 6 L/M): game data check and next-season draft on small
  -- synthetic DB2 tables; the real CSV download is the patch-watch workflow's job.
  local function Db2Fixture()
    local data = {
      SpellManifest = { battleRes = { { id = 100, name = "Res" } }, lustCasts = {}, lustSated = {}, icons = {} },
      InterruptManifest = {
        specs = { [71] = { spellID = 200, cd = 15 } },
        classAlternatives = {},
        extraCooldowns = {},
      },
      ConsumableData = { sets = { fixture = { flask = { 300 } } } },
      ItemManifest = { mythicKeystone = 400 },
      SpecManifest = { specs = { [71] = { class = "WARRIOR" } } },
      SeasonManifest = {
        activeSeasonID = "fixture_active",
        seasons = {
          fixture_active = {
            dungeons = {
              { mapID = 11, activityIDs = { 111 }, portalSpellIDs = { 500 } },
              { mapID = 12, activityIDs = { 112 }, portalSpellIDs = { 501 } },
            },
          },
        },
      },
    }
    local db2 = {
      spellIDs = { [100] = true, [200] = true, [300] = true, [500] = true, [501] = true },
      itemIDs = { [400] = true },
      maps = {
        { ID = "11", Name_lang = "Old One", MapID = "9011", CriteriaCount_0 = "1800" },
        { ID = "12", Name_lang = "Old Two", MapID = "9012", CriteriaCount_0 = "1800" },
        { ID = "21", Name_lang = "New One", MapID = "9021", CriteriaCount_0 = "1980" },
        { ID = "22", Name_lang = "New Two", MapID = "9022", CriteriaCount_0 = "2040" },
      },
      mapsDe = { { ID = "21", Name_lang = "Neu Eins" }, { ID = "22", Name_lang = "Neu Zwei" } },
      activities = {
        { ID = "111", MapID = "9011", DifficultyID = "8" },
        { ID = "112", MapID = "9012", DifficultyID = "8" },
        { ID = "121", MapID = "9021", DifficultyID = "8" },
        { ID = "122", MapID = "9022", DifficultyID = "8" },
        { ID = "123", MapID = "9022", DifficultyID = "8" },
      },
      specs = {
        { ID = "71", ClassID = "1", OrderIndex = "0", Name_lang = "Arms" },
        { ID = "1446", ClassID = "1", OrderIndex = "4", Name_lang = "Initial" },
      },
      tracked = {
        { MapChallengeModeID = "11", DisplaySeasonID = "1" },
        { MapChallengeModeID = "12", DisplaySeasonID = "1" },
      },
      flyoutItems = { { SpellID = "600" }, { SpellID = "601" }, { SpellID = "602" } },
      subtextBySpell = { [600] = "New One", [601] = "New Two", [602] = "New Two" },
    }
    return data, db2
  end

  test("Game data check finds every shipped ID and accepts a configured rotation", function()
    local tool = LoadTool("tools/check_db2.lua")
    local data, db2 = Db2Fixture()
    local code, report = tool.Evaluate(db2, data, { version = "1.2.3.4" })
    Assert.Equal(code, 0, "every shipped ID exists:\n" .. report)
    Assert.True(report:find("configured as `fixture_active`", 1, true) ~= nil, "the rotation is known")

    db2.spellIDs[200] = nil
    db2.activities[2] = { ID = "112", MapID = "9099", DifficultyID = "8" }
    db2.specs[#db2.specs + 1] = { ID = "72", ClassID = "1", OrderIndex = "1", Name_lang = "Fury" }
    code, report = tool.Evaluate(db2, data, { version = "1.2.3.4" })
    Assert.Equal(code, 1, "findings fail the check")
    Assert.True(report:find("MISSING spell 200 (interrupt spec 71)", 1, true) ~= nil, "a removed spell is named")
    Assert.True(report:find("ERROR LFG activity 112 is instance 9099", 1, true) ~= nil, "an activity drift is named")
    Assert.True(report:find("MISSING spec 72 (Fury) in data/isiLive_specs.lua", 1, true) ~= nil, "a new spec")
    Assert.Nil(report:find("1446", 1, true), "starter specs are no regular specs")
  end)

  test("Game data check drafts an unknown rotation without guessing ambiguous IDs", function()
    local tool = LoadTool("tools/check_db2.lua")
    local data, db2 = Db2Fixture()
    db2.tracked[#db2.tracked + 1] = { MapChallengeModeID = "21", DisplaySeasonID = "2" }
    db2.tracked[#db2.tracked + 1] = { MapChallengeModeID = "22", DisplaySeasonID = "2" }
    local code, report =
      tool.Evaluate(db2, data, { version = "1.2.3.4", seasonID = "fixture_next", date = "2026-11-20" })
    Assert.Equal(code, 1, "an unknown next season opens the issue")
    Assert.True(report:find("NEW season", 1, true) ~= nil, "the new rotation is announced")
    Assert.True(
      report:find("| fixture_next | New One | 21 | 600 | 121 | wago.tools DB2 1.2.3.4", 1, true) ~= nil,
      "a unique portal and activity are drafted with their source"
    )
    Assert.True(
      report:find("| 2026-11-20 | candidate | deDE Neu Eins; instance 9021; timer 33:00 |", 1, true) ~= nil,
      "notes"
    )
    Assert.True(
      report:find("| fixture_next | New Two | 22 | unresolved | unresolved |", 1, true) ~= nil,
      "two portal and two activity candidates stay unresolved"
    )
    Assert.True(report:find("portal candidates 601/602; activity candidates 122/123", 1, true) ~= nil, "listed")
    Assert.True(report:find('names = { enUS = "New One", deDE = "Neu Eins" }', 1, true) ~= nil, "skeleton names")
    Assert.Nil(report:find("\n      shortCodes = {", 1, true), "short codes are never drafted (only a by-hand comment)")
  end)

  test("Game data CSV reader keeps quoted commas, doubled quotes and multi-line fields", function()
    local tool = LoadTool("tools/check_db2.lua")
    local fields = tool.ParseLine('"Kings\' Rest, Old",249,"say ""hi""",')
    Assert.Equal(fields[1], "Kings' Rest, Old", "quoted comma")
    Assert.Equal(fields[2], "249", "plain field")
    Assert.Equal(fields[3], 'say "hi"', "doubled quotes")
    Assert.Equal(fields[4], "", "trailing empty field")
    local path = (os.getenv("TEMP") or "/tmp") .. "/isilive_db2_multiline.csv"
    local file = assert(io.open(path, "wb"))
    file:write('Name_lang,Description_lang,ID\n"Arms","Line one\nline two, with comma",71\n"Fury","x",72\n')
    file:close()
    local rows = tool.ReadCsv(path)
    os.remove(path)
    Assert.Equal(#rows, 2, "a quoted line break stays inside one record")
    Assert.Equal(rows[1].ID, "71", "the record after the line break keeps its columns")
    Assert.Equal(rows[2].Name_lang, "Fury", "the next record parses normally")
  end)
end
