---@diagnostic disable: undefined-global

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
  f:write('  season = "midnight_s1",\n')
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

  test("mplus_db_lifetime: returns 2 when expiresAt is missing entirely", function()
    local tool = LoadTool()
    local path = TempPath("isilive_mplus_db_noexpiry.lua")
    WriteRawFixture(path, "local _, addonTable = ...\naddonTable.MPlusForces = { dungeonTotal = {}, byNpcId = {} }\n")
    local code = tool.Check(path, { today = "2026-04-21" })
    Assert.Equal(2, code, "absent expiresAt must be a structural error")
    os.remove(path)
  end)

  test("mplus_db_lifetime: returns 2 when active season and DB season diverge", function()
    local tool = LoadTool()
    local path = TempPath("isilive_mplus_db_wrongseason.lua")
    WriteRawFixture(
      path,
      "local _, addonTable = ...\n"
        .. 'addonTable.MPlusForces = { season = "midnight_s1", expiresAt = "2030-01-01", '
        .. "dungeonTotal = {}, byNpcId = {} }\n"
    )
    local code, msg = tool.Check(path, { today = "2026-04-21", activeSeasonID = "midnight_s2" })
    Assert.Equal(2, code, "season mismatch must be a structural error")
    Assert.True(tostring(msg):find("season mismatch", 1, true) ~= nil, "message must name the season mismatch")
    os.remove(path)
  end)

  test("mplus_db_lifetime: shipped DB file passes under current date override", function()
    local tool = LoadTool()
    -- Use the shipped DB and a today value known to be before the current
    -- expiresAt. This locks in the loader contract and the real file's shape.
    local code, msg = tool.Check("data/isiLive_mplus_forces.lua", { today = "2026-04-21" })
    Assert.Equal(0, code, "shipped DB must pass under the reference today: " .. tostring(msg))
  end)
end
