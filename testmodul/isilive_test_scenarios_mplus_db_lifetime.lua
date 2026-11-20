---@diagnostic disable: undefined-global

local SHIPPED_ACTIVE_SEASON_ID =
  assert(loadfile("testmodul/isilive_test_fixture_seasons.lua"))().ShippedActiveSeasonID()

local TOOL_PATH = "tools/check_mplus_db_lifetime.lua"

local function LoadTool()
  -- Pass a non-nil arg so the tool's `... == nil` main-chunk branch is skipped
  -- and returns the module table instead of calling os.exit().
  local chunk, err = loadfile(TOOL_PATH)
  assert(chunk, err)
  return chunk("module")
end

local function WriteDBFixture(path, expiresAt)
  local f = assert(io.open(path, "w"))
  f:write("local _, addonTable = ...\n")
  f:write("addonTable.MPlusForces = {\n")
  f:write(string.format("  season = %q,\n", SHIPPED_ACTIVE_SEASON_ID))
  f:write('  sourceCommit = "0123456789abcdef0123456789abcdef01234567",\n')
  f:write(string.format("  expiresAt = %q,\n", tostring(expiresAt)))
  f:write("  dungeonTotal = {},\n")
  f:write("  byNpcId = {},\n")
  f:write("}\n")
  f:close()
end

local function WriteRawFixture(path, body)
  local f = assert(io.open(path, "w"))
  f:write(body)
  f:close()
end

local function TempPath(name)
  return os.getenv("TEMP") and (os.getenv("TEMP") .. "/" .. name) or ("/tmp/" .. name)
end

return function(test, ctx)
  local Assert = ctx.assert

  test("mplus_db_lifetime: returns 0 when today is before expiresAt", function()
    local tool = LoadTool()
    local path = TempPath("isilive_mplus_db_fresh.lua")
    WriteDBFixture(path, "2030-01-01")
    local code, msg = tool.Check(path, { today = "2026-04-21" })
    Assert.Equal(0, code, "fresh DB must pass: " .. tostring(msg))
    os.remove(path)
  end)

  test("mplus_db_lifetime: returns 0 when today equals expiresAt", function()
    local tool = LoadTool()
    local path = TempPath("isilive_mplus_db_boundary.lua")
    WriteDBFixture(path, "2026-05-06")
    local code = tool.Check(path, { today = "2026-05-06" })
    Assert.Equal(0, code, "DB is valid on the expiry day itself")
    os.remove(path)
  end)

  test("mplus_db_lifetime: returns 1 when today is after expiresAt", function()
    local tool = LoadTool()
    local path = TempPath("isilive_mplus_db_stale.lua")
    WriteDBFixture(path, "2026-05-06")
    local code, msg = tool.Check(path, { today = "2026-06-01" })
    Assert.Equal(1, code, "stale DB must fail")
    Assert.True(tostring(msg):find("expired on 2026-05-06", 1, true) ~= nil, "message must name the expiry date")
    Assert.True(
      tostring(msg):find("ISILIVE_ALLOW_STALE_MPLUS_DB", 1, true) ~= nil,
      "message must point at the bypass env var"
    )
    os.remove(path)
  end)

  test("mplus_db_lifetime: override=1 bypasses expired DB with exit 0", function()
    local tool = LoadTool()
    local path = TempPath("isilive_mplus_db_override.lua")
    WriteDBFixture(path, "2026-05-06")
    local code, msg = tool.Check(path, { today = "2026-06-01", override = "1" })
    Assert.Equal(0, code, "override=1 must bypass expiry")
    Assert.True(tostring(msg):find("bypassed", 1, true) ~= nil, "message must indicate the bypass was used")
    os.remove(path)
  end)

  test("mplus_db_lifetime: non-'1' override does not bypass expiry", function()
    local tool = LoadTool()
    local path = TempPath("isilive_mplus_db_badoverride.lua")
    WriteDBFixture(path, "2026-05-06")
    local code = tool.Check(path, { today = "2026-06-01", override = "true" })
    Assert.Equal(1, code, "only the literal string '1' bypasses; other truthy strings must fail")
    os.remove(path)
  end)

  test("mplus_db_lifetime: returns 2 when DB file is missing", function()
    local tool = LoadTool()
    local missing = TempPath("isilive_mplus_db_missing_" .. tostring(math.random(1e9)) .. ".lua")
    os.remove(missing)
    local code, msg = tool.Check(missing, { today = "2026-04-21" })
    Assert.Equal(2, code, "missing file must be a structural error")
    Assert.True(tostring(msg):find("cannot load", 1, true) ~= nil, "message must describe the load failure")
  end)

  test("mplus_db_lifetime: returns 2 when MPlusForces table is missing", function()
    local tool = LoadTool()
    local path = TempPath("isilive_mplus_db_notable.lua")
    WriteRawFixture(path, "local _, addonTable = ...\n-- no MPlusForces assigned\n")
    local code, msg = tool.Check(path, { today = "2026-04-21" })
    Assert.Equal(2, code, "missing MPlusForces must be a structural error")
    Assert.True(tostring(msg):find("MPlusForces", 1, true) ~= nil, "message must mention the missing table")
    os.remove(path)
  end)

  test("mplus_db_lifetime: returns 2 when expiresAt is malformed", function()
    local tool = LoadTool()
    local path = TempPath("isilive_mplus_db_badexpiry.lua")
    WriteDBFixture(path, "2026/05/06")
    local code, msg = tool.Check(path, { today = "2026-04-21" })
    Assert.Equal(2, code, "malformed expiresAt must be a structural error")
    Assert.True(tostring(msg):find("expiresAt", 1, true) ~= nil, "message must name the offending field")
    os.remove(path)
  end)

  test("mplus_db_lifetime: returns 2 when sourceCommit is missing or abbreviated", function()
    local tool = LoadTool()
    local path = TempPath("isilive_mplus_db_bad_source_commit.lua")
    WriteRawFixture(
      path,
      "local _, addonTable = ...\n"
        .. string.format(
          'addonTable.MPlusForces = { season = %q, sourceCommit = "01234567", ',
          SHIPPED_ACTIVE_SEASON_ID
        )
        .. 'expiresAt = "2030-01-01", dungeonTotal = {}, byNpcId = {} }\n'
    )
    local code, msg = tool.Check(path, { today = "2026-04-21" })
    Assert.Equal(2, code, "abbreviated source provenance must be a structural error")
    Assert.True(tostring(msg):find("sourceCommit", 1, true) ~= nil, "message must name sourceCommit")
    os.remove(path)
  end)

  test("mplus_db_lifetime: returns 2 when expiresAt is missing entirely", function()
    local tool = LoadTool()
    local path = TempPath("isilive_mplus_db_noexpiry.lua")
    WriteRawFixture(path, "local _, addonTable = ...\naddonTable.MPlusForces = { dungeonTotal = {}, byNpcId = {} }\n")
    -- An empty active season id skips the season match, so the expiry check
    -- runs whatever the shipped manifest's active season requires.
    local code = tool.Check(path, { today = "2026-04-21", activeSeasonID = "" })
    Assert.Equal(2, code, "absent expiresAt must be a structural error")
    os.remove(path)
  end)

  test("mplus_db_lifetime: returns 2 when active season and DB season diverge", function()
    local tool = LoadTool()
    local path = TempPath("isilive_mplus_db_wrongseason.lua")
    WriteRawFixture(
      path,
      "local _, addonTable = ...\n"
        .. 'addonTable.MPlusForces = { season = "fixture_other", expiresAt = "2030-01-01", '
        .. "dungeonTotal = {}, byNpcId = {} }\n"
    )
    local code, msg =
      tool.Check(path, { today = "2026-04-21", activeSeasonID = "fixture_active", requiresForces = true })
    Assert.Equal(2, code, "season mismatch must be a structural error")
    Assert.True(tostring(msg):find("season mismatch", 1, true) ~= nil, "message must name the season mismatch")
    os.remove(path)
  end)

  test("mplus_db_lifetime: skips the season match when the active season needs no forces", function()
    local tool = LoadTool()
    local path = TempPath("isilive_mplus_db_noforces.lua")
    -- A season may ship before MDT publishes its data (requiresForces = false).
    -- The stale DB is then unused at runtime and must not fail the build.
    WriteRawFixture(
      path,
      "local _, addonTable = ...\n"
        .. 'addonTable.MPlusForces = { season = "fixture_other", expiresAt = "2030-01-01", '
        .. "dungeonTotal = {}, byNpcId = {} }\n"
    )
    local code, msg =
      tool.Check(path, { today = "2026-04-21", activeSeasonID = "fixture_active", requiresForces = false })
    Assert.Equal(0, code, "a requiresForces = false season must not be blocked by a foreign DB: " .. tostring(msg))
    Assert.True(tostring(msg):find("requiresForces", 1, true) ~= nil, "message must name the skipped gate")
    os.remove(path)
  end)

  test("mplus_db_lifetime: structure gate enforces requiresForces through SeasonData", function()
    local tool = LoadTool()
    -- The shipped DB must cover the active season through the production
    -- SeasonData.GetForcesReadiness path -- the build gate that replaced the
    -- runtime activation coupling.
    local shippedCode, shippedMsg = tool.CheckStructure("data/isiLive_mplus_forces.lua")
    Assert.Equal(0, shippedCode, "shipped DB must match the active season structure: " .. tostring(shippedMsg))

    local path = TempPath("isilive_mplus_db_structure.lua")
    WriteDBFixture(path, "2030-01-01")
    -- A requiresForces = true season from a fixture manifest, so the check does
    -- not depend on what the shipped active season requires.
    local manifestPath = TempPath("isilive_mplus_db_structure_manifest.lua")
    WriteRawFixture(
      manifestPath,
      table.concat({
        "local _, addonTable = ...",
        'local F = assert(loadfile("testmodul/isilive_test_fixture_seasons.lua"))()',
        "local season = F.BuildSeason()",
        "season.requiresForces = true",
        'season.mdtDirectory = "Fixture"',
        'addonTable.SeasonManifest = { activeSeasonID = "fixture_forces", seasons = { fixture_forces = season } }',
        "",
      }, "\n")
    )
    WriteRawFixture(
      path,
      "local _, addonTable = ...\n"
        .. 'addonTable.MPlusForces = { season = "fixture_forces", expiresAt = "2030-01-01", '
        .. "dungeonTotal = {}, byNpcId = {} }\n"
    )
    local code, msg = tool.CheckStructure(path, { activeSeasonID = "fixture_forces", seasonDataPath = manifestPath })
    os.remove(manifestPath)
    Assert.Equal(2, code, "an empty DB for a requiresForces season must fail the structure gate")
    Assert.True(tostring(msg):find("missing a positive total", 1, true) ~= nil, "message must name the gap")

    -- A requiresForces = false season: the synthetic fixture, so the test does
    -- not pin any real historical season in the manifest.
    local FixtureSeasons = assert(loadfile("testmodul/isilive_test_fixture_seasons.lua"))()
    local skippedCode, skippedMsg = tool.CheckStructure(path, {
      activeSeasonID = FixtureSeasons.PREVIOUS_SEASON_ID,
      seasonDataPath = FixtureSeasons.MANIFEST_PATH,
    })
    Assert.Equal(0, skippedCode, "a requiresForces = false season must skip the structure gate")
    Assert.True(tostring(skippedMsg):find("skipped", 1, true) ~= nil, "message must name the skipped gate")
    os.remove(path)
  end)

  test("mplus_db_lifetime: shipped DB file passes under current date override", function()
    local tool = LoadTool()
    -- Use the shipped DB and a today value known to be before the current
    -- expiresAt. This locks in the loader contract and the real file's shape.
    local code, msg = tool.Check("data/isiLive_mplus_forces.lua", { today = "2026-04-21" })
    Assert.Equal(0, code, "shipped DB must pass under the reference today: " .. tostring(msg))
  end)

  test("shipped forces DB carries only the dungeons of its declared season", function()
    -- Regression: the generator swept its upstream source directory without
    -- filtering by season. That folder held exactly the Season 1 dungeons for
    -- one upstream generation and then started carrying Season 1 and Season 2
    -- side by side, which produced a 16-dungeon DB stamped
    -- season = <active season>. SeasonData rejects every out-of-season map id,
    -- so the active season turned "not ready" and both SetActiveSeasonID and
    -- the automatic season switch would have refused to run -- while the
    -- lifetime gate above stayed green, because it only read the header.
    -- Forces no longer gate activation (rule 97); the lifetime tool's
    -- CheckStructure step now fails the build for such a DB instead.
    local manifestChunk, manifestErr = loadfile("data/isiLive_seasons.lua")
    assert(manifestChunk, manifestErr)
    local manifestTable = {}
    manifestChunk("isiLive", manifestTable)
    local manifest = manifestTable.SeasonManifest

    local forcesChunk, forcesErr = loadfile("data/isiLive_mplus_forces.lua")
    assert(forcesChunk, forcesErr)
    local forcesTable = {}
    forcesChunk("isiLive", forcesTable)
    local forces = forcesTable.MPlusForces

    local season = manifest.seasons[forces.season]
    Assert.NotNil(season, "the DB must declare a season that exists in the manifest: " .. tostring(forces.season))

    local allowed = {}
    local expected = 0
    for _, dungeon in ipairs(season.dungeons or {}) do
      allowed[dungeon.mapID] = true
      expected = expected + 1
    end

    local actual = 0
    for mapID in pairs(forces.dungeonTotal or {}) do
      Assert.True(
        allowed[mapID] == true,
        string.format("dungeonTotal map id %s does not belong to season %s", tostring(mapID), tostring(forces.season))
      )
      actual = actual + 1
    end
    Assert.Equal(actual, expected, "the DB must cover every dungeon of its declared season and no others")

    for npcID, entry in pairs(forces.byNpcId or {}) do
      Assert.True(
        allowed[entry.mapID] == true,
        string.format(
          "npc id %s points at map %s outside season %s",
          tostring(npcID),
          tostring(entry.mapID),
          tostring(forces.season)
        )
      )
    end
  end)

  -- Rule 260: per-season sections. A fixture manifest keeps these tests free
  -- of real season IDs.
  local SECTION_COMMIT = "0123456789abcdef0123456789abcdef01234567"

  local function WriteSectionManifest(path)
    WriteRawFixture(
      path,
      table.concat({
        "local _, addonTable = ...",
        'local F = assert(loadfile("testmodul/isilive_test_fixture_seasons.lua"))()',
        "local nextSeason = F.BuildSeason()",
        "nextSeason.requiresForces = true",
        'nextSeason.mdtDirectory = "Fixture"',
        "addonTable.SeasonManifest = {",
        '  activeSeasonID = "fixture_active",',
        "  seasons = { fixture_active = F.BuildSeason(), fixture_next = nextSeason },",
        "}",
        "",
      }, "\n")
    )
  end

  -- opts: nextExpiresAt, nextCommit, nextTotals (false = no totals), alias, extra
  local function WriteSectionDB(path, opts)
    opts = opts or {}
    WriteRawFixture(
      path,
      table.concat({
        "local _, addonTable = ...",
        "local function Section(id, expiresAt, commit, withTotals)",
        "  local totals, npcs = {}, {}",
        "  for i = 1, 8 do",
        "    if withTotals then totals[90000 + i] = { total = 100 } end",
        "    npcs[80000 + i] = { count = 5, mapID = 90000 + i }",
        "  end",
        "  return { season = id, sourceCommit = commit, expiresAt = expiresAt, dungeonTotal = totals, byNpcId = npcs }",
        "end",
        "addonTable.MPlusForcesBySeason = {",
        string.format('  fixture_active = Section("fixture_active", "2030-01-01", %q, true),', SECTION_COMMIT),
        string.format(
          '  fixture_next = Section("fixture_next", %q, %q, %s),',
          opts.nextExpiresAt or "2030-01-01",
          opts.nextCommit or SECTION_COMMIT,
          tostring(opts.nextTotals ~= false)
        ),
        opts.extra
            and string.format('  %s = Section(%q, "2030-01-01", %q, true),', opts.extra, opts.extra, SECTION_COMMIT)
          or "",
        "}",
        string.format("addonTable.MPlusForces = addonTable.MPlusForcesBySeason.%s", opts.alias or "fixture_active"),
        "",
      }, "\n")
    )
  end

  local function CheckSections(dbOpts, checkOpts)
    local tool = LoadTool()
    local manifestPath = TempPath("isilive_forces_sections_manifest.lua")
    local dbPath = TempPath("isilive_forces_sections_db.lua")
    WriteSectionManifest(manifestPath)
    WriteSectionDB(dbPath, dbOpts)
    checkOpts = checkOpts or {}
    checkOpts.seasonDataPath = manifestPath
    checkOpts.today = checkOpts.today or "2026-11-20"
    local code, msg = tool.CheckSeasonSections(dbPath, checkOpts)
    os.remove(manifestPath)
    os.remove(dbPath)
    return code, tostring(msg)
  end

  test("mplus_db_lifetime: per-season sections pass when every section is fresh and complete", function()
    local code, msg = CheckSections()
    Assert.Equal(code, 0, "valid sections pass: " .. msg)
    Assert.True(msg:find("fixture_next", 1, true) ~= nil, "the prepared season section is checked")
  end)

  test("mplus_db_lifetime: per-season sections fail on an expired, unsourced or incomplete section", function()
    local code, msg = CheckSections({ nextExpiresAt = "2026-11-01" })
    Assert.Equal(code, 1, "an expired prepared section blocks the build: " .. msg)
    code = CheckSections({ nextExpiresAt = "2026-11-01" }, { override = "1" })
    Assert.Equal(code, 0, "the stale-DB override also covers prepared sections")
    code, msg = CheckSections({ nextCommit = "abc" })
    Assert.Equal(code, 2, "a section without an exact MDT commit fails: " .. msg)
    code, msg = CheckSections({ nextTotals = false })
    Assert.Equal(code, 2, "a requiresForces section without totals fails the structure: " .. msg)
    Assert.True(msg:find("fixture_next", 1, true) ~= nil, "the failure names the section")
  end)

  test("mplus_db_lifetime: per-season sections reject a foreign section or a wrong alias", function()
    local code, msg = CheckSections({ extra = "fixture_unknown" })
    Assert.Equal(code, 2, "a section of an unconfigured season fails: " .. msg)
    code, msg = CheckSections({ alias = "fixture_next" })
    Assert.Equal(code, 2, "MPlusForces must alias the active season: " .. msg)
  end)

  test("mplus_db_lifetime: shipped DB passes the per-season section gate", function()
    local tool = LoadTool()
    local code, msg = tool.CheckSeasonSections(nil, { today = "2026-01-01" })
    Assert.Equal(code, 0, "shipped sections must pass: " .. tostring(msg))
  end)
end
