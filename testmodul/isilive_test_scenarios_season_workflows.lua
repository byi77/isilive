---@diagnostic disable: undefined-global

local ioLib = rawget(_G, "io")
local osLib = rawget(_G, "os")

local function LoadTool(path)
  local chunk, err = loadfile(path)
  if not chunk then
    error(string.format("cannot load %s: %s", tostring(path), tostring(err)))
  end
  return chunk("module")
end

local function IsWindows()
  return package.config:sub(1, 1) == "\\"
end

local function EnsureDir(path)
  local command
  if IsWindows() then
    command = 'mkdir "' .. path .. '" >nul 2>nul'
  else
    command = "mkdir -p '" .. path:gsub("'", "'\\''") .. "' >/dev/null 2>/dev/null"
  end
  osLib.execute(command)
end

local function WriteFile(path, content)
  local file, err = ioLib.open(path, "wb")
  if not file then
    error(string.format("cannot write %s: %s", tostring(path), tostring(err)))
  end
  file:write(content)
  file:close()
end

local function ReadFile(path)
  local file, err = ioLib.open(path, "rb")
  if not file then
    error(string.format("cannot read %s: %s", tostring(path), tostring(err)))
  end
  local content = file:read("*a") or ""
  file:close()
  return content
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Season readiness inspect reports active and prepared seasons without fetching data", function()
    local tool = LoadTool("tools/inspect_season_readiness.lua")
    local summary = tool.BuildSummary()

    Assert.True(
      summary:find("## isiLive Season Readiness", 1, true) ~= nil,
      "season readiness inspect must emit a markdown heading"
    )
    Assert.True(
      summary:find("- Active season: midnight_s2", 1, true) ~= nil,
      "season readiness inspect must report the persisted active season"
    )
    Assert.True(
      summary:find("| midnight_s1 | Midnight Season 1 | yes | 8 | 0 | - | - |", 1, true) ~= nil,
      "season readiness inspect must keep the non-active season manually activatable"
    )
    Assert.True(
      summary:find("- Matches active season: yes", 1, true) ~= nil,
      "season readiness inspect must compare the forces DB season against the active season"
    )
  end)

  test("MDT season preview marks missing candidates unresolved instead of inventing IDs", function()
    local tool = LoadTool("tools/inspect_mdt_season_preview.lua")
    local summary = tool.BuildSummary({
      seasonID = "midnight_s2",
      mdtPath = "tools/cache/does-not-exist",
    })

    Assert.True(
      summary:find("- Season: midnight_s2", 1, true) ~= nil,
      "MDT preview inspect must report the requested season"
    )
    Assert.True(
      summary:find(
        "| Altar of Fangs | 588 | unresolved | unresolved | unresolved: candidate file is missing |",
        1,
        true
      ) ~= nil,
      "MDT preview inspect must not fabricate a candidate when no MDT file is available"
    )
    Assert.True(summary:find("- Forces-ready: no", 1, true) ~= nil, "missing MDT data must fail closed")
  end)

  test("MDT season preview lists textual candidates from a cloned MDT tree", function()
    local tool = LoadTool("tools/inspect_mdt_season_preview.lua")
    local root = "tools/cache/test_mdt_preview"
    EnsureDir(root)
    WriteFile(
      root .. (IsWindows() and "\\DungeonData.lua" or "/DungeonData.lua"),
      [[local dungeonIndex = 1
MDT.mapInfo[dungeonIndex] = { mapID = 588, englishName = "Altar of Fangs" }
MDT.dungeonTotalCount[dungeonIndex] = { normal = 100 }
MDT.dungeonEnemies[dungeonIndex] = { { id = 7, count = 5, name = "Test Enemy" } }
]]
    )
    WriteFile(
      root .. (IsWindows() and "\\MythicDungeonTools.toc" or "/MythicDungeonTools.toc"),
      "## Version: test-mdt\n"
    )

    local summary = tool.BuildSummary({
      seasonID = "midnight_s2",
      mdtPath = root,
    })

    Assert.True(summary:find("- MDT version: test-mdt", 1, true) ~= nil, "MDT preview must report TOC version")
    Assert.True(
      summary:find("- Candidate matches: 1", 1, true) ~= nil,
      "MDT preview must expose a machine-readable candidate count for workflow notifications"
    )
    Assert.True(
      summary:find("| Altar of Fangs | 588 | ", 1, true) ~= nil and summary:find("DungeonData.lua", 1, true) ~= nil,
      "MDT preview must report the candidate file containing the planned dungeon name"
    )
    Assert.True(
      summary:find('MDT.mapInfo[dungeonIndex] = { mapID = 588, englishName = "Altar of Fangs" }', 1, true) ~= nil,
      "MDT preview must include the matched source line as inspect context"
    )
    Assert.True(
      summary:find("- Forces-ready dungeons: 1/8", 1, true) ~= nil
        and summary:find("- Forces-ready: no", 1, true) ~= nil,
      "MDT preview must not declare the season ready until all eight dungeons are usable"
    )
  end)

  test("MDT season preview rejects textual stubs with the wrong map id", function()
    local tool = LoadTool("tools/inspect_mdt_season_preview.lua")
    local root = "tools/cache/test_mdt_preview_stub"
    EnsureDir(root)
    WriteFile(
      root .. (IsWindows() and "\\MurderRow.lua" or "/MurderRow.lua"),
      [[local dungeonIndex = 1
MDT.mapInfo[dungeonIndex] = { mapID = 12345, englishName = "Murder Row" }
MDT.dungeonTotalCount[dungeonIndex] = { normal = 100 }
MDT.dungeonEnemies[dungeonIndex] = { { id = 7, count = 5 } }
]]
    )

    local summary = tool.BuildSummary({ seasonID = "midnight_s2", mdtPath = root })
    Assert.True(
      summary:find("mapID mismatch: expected 587, got 12345", 1, true) ~= nil,
      "textual MDT stubs with placeholder map IDs must remain unresolved"
    )
    Assert.True(summary:find("- Forces-ready: no", 1, true) ~= nil, "a placeholder map ID must not notify")
  end)

  test("MDT season preview continues past an invalid textual candidate to a usable dungeon file", function()
    local tool = LoadTool("tools/inspect_mdt_season_preview.lua")
    local root = "tools/cache/test_mdt_preview_multiple_candidates"
    EnsureDir(root)
    WriteFile(
      root .. (IsWindows() and "\\A_TextCandidate.lua" or "/A_TextCandidate.lua"),
      'local label = "Altar of Fangs"\n'
    )
    WriteFile(
      root .. (IsWindows() and "\\B_AltarOfFangs.lua" or "/B_AltarOfFangs.lua"),
      [[local dungeonIndex = 1
MDT.mapInfo[dungeonIndex] = { mapID = 588, englishName = "Altar of Fangs" }
MDT.dungeonTotalCount[dungeonIndex] = { normal = 100 }
MDT.dungeonEnemies[dungeonIndex] = { { id = 7, count = 5 } }
]]
    )

    local summary = tool.BuildSummary({ seasonID = "midnight_s2", mdtPath = root })
    Assert.True(
      summary:find("B_AltarOfFangs.lua", 1, true) ~= nil and summary:find("| ready |", 1, true) ~= nil,
      "a prior non-dungeon text hit must not hide a later structurally usable candidate"
    )
    Assert.True(
      summary:find("- Forces-ready dungeons: 1/8", 1, true) ~= nil,
      "the usable later candidate must count toward availability"
    )
  end)

  test("MDT forces sync executes dungeon data without ambient globals", function()
    local tool = LoadTool("tools/sync_mdt_forces.lua")
    local root = "tools/cache/test_mdt_sandbox"
    EnsureDir(root)
    local safePath = root .. (IsWindows() and "\\Safe.lua" or "/Safe.lua")
    local unsafePath = root .. (IsWindows() and "\\Unsafe.lua" or "/Unsafe.lua")
    WriteFile(
      safePath,
      [[local addonName = ...
local dungeonIndex = 1
for _, zone in ipairs({ 10, 20 }) do
  MDT.zoneIdToDungeonIdx[zone] = dungeonIndex
end
MDT.mapInfo[dungeonIndex] = { mapID = 42, englishName = addonName }
MDT.dungeonTotalCount[dungeonIndex] = { normal = 100 }
MDT.dungeonEnemies[dungeonIndex] = { { id = 7, count = 5, name = "Safe" } }
]]
    )
    WriteFile(unsafePath, [[os.execute("must-not-run")]])

    local sandbox = tool.BuildSandbox()
    local debugLib = rawget(_G, "debug")
    local previousHook, previousMask, previousCount = debugLib.gethook()
    local sentinelHook = function() end
    debugLib.sethook(sentinelHook, "", 1000000)
    local safeOk, safeErr = tool.LoadDungeonFile(safePath, sandbox)
    local restoredHook, restoredMask, restoredCount = debugLib.gethook()
    if previousHook then
      debugLib.sethook(previousHook, previousMask or "", previousCount or 0)
    else
      debugLib.sethook()
    end
    Assert.True(safeOk, "declarative MDT data must load in the restricted environment: " .. tostring(safeErr))
    Assert.Equal(sandbox.mapInfo[1].mapID, 42, "safe data must populate the injected MDT table")
    Assert.Equal(restoredHook, sentinelHook, "sandbox execution must restore an existing instrumentation hook")
    Assert.Equal(restoredMask, "", "sandbox execution must restore the instrumentation hook mask")
    Assert.Equal(restoredCount, 1000000, "sandbox execution must restore the instrumentation hook count")

    local unsafeOk, unsafeErr = tool.LoadDungeonFile(unsafePath, sandbox)
    Assert.False(unsafeOk, "third-party MDT data must not reach ambient os functions")
    Assert.True(
      tostring(unsafeErr):find("global 'os'", 1, true) ~= nil,
      "sandbox rejection must identify the unavailable ambient global"
    )
  end)

  test("MDT forces sync accepts only an exact source commit", function()
    local tool = LoadTool("tools/sync_mdt_forces.lua")
    local exact = "0123456789ABCDEF0123456789ABCDEF01234567"
    Assert.Equal(
      tool.NormalizeSourceCommit(exact),
      exact:lower(),
      "an exact 40-character hexadecimal git commit must be normalized"
    )
    Assert.Nil(tool.NormalizeSourceCommit("01234567"), "an abbreviated git commit must remain unresolved")
    Assert.Nil(
      tool.NormalizeSourceCommit("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"),
      "a non-hexadecimal source identifier must remain unresolved"
    )
  end)

  test("Season intake check accepts current planned dungeon intake progress", function()
    local tool = LoadTool("tools/check_season_intake.lua")
    local ok, result = tool.Check()

    Assert.True(ok, "live season intake file should be structurally valid")
    Assert.True(
      result.summary:find("- Dungeon progress: 8/8 verified, 0 partial, 0 candidate, 0 unresolved", 1, true) ~= nil,
      "season intake summary must expose current intake progress"
    )
    Assert.True(
      result.summary:find("| Altar of Fangs | 588 | 1286812 | 1933 | verified |", 1, true) ~= nil,
      "season intake summary must include the verified Altar of Fangs mapping"
    )
    Assert.True(
      result.summary:find("| Ruby Life Pools | 399 | 393256 | 1176 | verified |", 1, true) ~= nil,
      "season intake summary must include the verified Ruby Life Pools mapping"
    )
    Assert.True(
      result.summary:find("| King's Rest | 249 | 1286831 | 514 | verified |", 1, true) ~= nil,
      "season intake summary must include the verified King's Rest mapping"
    )
    Assert.True(
      result.summary:find("| Temple of Sethraliss | 250 | 1286828 | 504 | verified |", 1, true) ~= nil,
      "season intake summary must include the verified Temple of Sethraliss mapping"
    )
    Assert.True(
      result.summary:find("| Murder Row | 587 | 1286809 | 1950 | verified |", 1, true) ~= nil,
      "season intake summary must include the verified Murder Row mapping"
    )
    Assert.True(
      result.summary:find("| Den of Nalorakk | 586 | 1286807 | 1952 | verified |", 1, true) ~= nil,
      "season intake summary must include the verified Den of Nalorakk mapping"
    )
    Assert.True(
      result.summary:find("| The Blinding Vale | 584 | 1286801 | 1949 | verified |", 1, true) ~= nil,
      "season intake summary must include the verified The Blinding Vale mapping"
    )
    Assert.True(
      result.summary:find("| Voidscar Arena | 585 | 1286804 | 1951 | verified |", 1, true) ~= nil,
      "season intake summary must include the verified Voidscar Arena mapping"
    )
    Assert.Equal(#result.tables.dungeons, 8, "markdown parsing must preserve exactly eight dungeon rows")
    Assert.Equal(
      result.tables.dungeons[1].Season,
      "midnight_s2",
      "markdown parsing must preserve the Season column on Lua 5.1 and newer"
    )
    Assert.Equal(
      result.tables.dungeons[1].Dungeon,
      "Altar of Fangs",
      "markdown parsing must preserve the Dungeon column on Lua 5.1 and newer"
    )
    Assert.Equal(
      result.tables.dungeons[1].Status,
      "verified",
      "markdown parsing must preserve later columns on Lua 5.1 and newer"
    )
  end)

  test("Season intake check rejects IDs that diverge from the season manifest", function()
    local tool = LoadTool("tools/check_season_intake.lua")
    local path = "tools/cache/test_season_intake_manifest_drift.md"
    EnsureDir("tools/cache")
    local content = ReadFile("docs/SEASON_INTAKE.md")
    local changed, replacementCount = content:gsub(
      "| midnight_s2 | Altar of Fangs | 588 | 1286812 | 1933 |",
      "| midnight_s2 | Altar of Fangs | 588 | 1286812 | 1934 |",
      1
    )
    Assert.Equal(replacementCount, 1, "test fixture must change exactly one verified activity id")
    WriteFile(path, changed)

    local ok, result = tool.Check({ intakePath = path })
    Assert.False(ok, "intake data must not drift from the runtime season manifest")
    Assert.True(
      result.summary:find("LFGActivityID does not match the season manifest", 1, true) ~= nil,
      "drift error must name the mismatched manifest field"
    )
  end)

  test("Season intake check infers one exact intake season and rejects ambiguous files", function()
    local tool = LoadTool("tools/check_season_intake.lua")
    local inferredOk, inferred = tool.Check()
    Assert.True(inferredOk, "one exact season in the intake must be inferred")
    Assert.Equal(inferred.seasonID, "midnight_s2", "inferred season must come from the intake rows")

    local path = "tools/cache/test_season_intake_ambiguous.md"
    EnsureDir("tools/cache")
    local content = ReadFile("docs/SEASON_INTAKE.md")
    WriteFile(path, content .. [[

## Dungeon-Intake

| Season | Dungeon | ChallengeMapID | PortalSpellID | LFGActivityID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| another_season | Example | unresolved | unresolved | unresolved | unresolved | unresolved | unresolved | test |
]])

    local ok, result = tool.Check({ intakePath = path })
    Assert.False(ok, "multiple intake seasons must require an explicit season selection")
    Assert.True(
      result.summary:find("contains multiple seasons", 1, true) ~= nil,
      "ambiguous intake failure must identify the multiple-season source"
    )
  end)

  test("Season intake check rejects concrete IDs without source metadata", function()
    local tool = LoadTool("tools/check_season_intake.lua")
    local path = "tools/cache/test_season_intake_invalid.md"
    EnsureDir("tools/cache")
    WriteFile(
      path,
      [[# Season-Intake

## Dungeon-Intake

| Season | Dungeon | ChallengeMapID | PortalSpellID | LFGActivityID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
|midnight_s2|Altar of Fangs|101|unresolved|unresolved|unresolved|unresolved|partial|test|
|midnight_s2|Murder Row|unresolved|unresolved|unresolved|unresolved|unresolved|unresolved|test|
|midnight_s2|Den of Nalorakk|unresolved|unresolved|unresolved|unresolved|unresolved|unresolved|test|
|midnight_s2|The Blinding Vale|unresolved|unresolved|unresolved|unresolved|unresolved|unresolved|test|
|midnight_s2|Voidscar Arena|unresolved|unresolved|unresolved|unresolved|unresolved|unresolved|test|
|midnight_s2|King's Rest|unresolved|unresolved|unresolved|unresolved|unresolved|unresolved|test|
|midnight_s2|Ruby Life Pools|unresolved|unresolved|unresolved|unresolved|unresolved|unresolved|test|
|midnight_s2|Temple of Sethraliss|unresolved|unresolved|unresolved|unresolved|unresolved|unresolved|test|

## Ruhestein-Intake

| Season | Name | ToyID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- |
| midnight_s2 | unresolved | unresolved | unresolved | unresolved | unresolved | test |

## Mount-Intake

| Season | Name | SpellID | Source | VerifiedAt | Status | Notiz |
| --- | --- | --- | --- | --- | --- | --- |
| midnight_s2 | unresolved | unresolved | unresolved | unresolved | unresolved | test |
]]
    )

    local ok, result = tool.Check({ intakePath = path })

    Assert.False(ok, "season intake must reject partial concrete data without source metadata")
    Assert.True(
      result.summary:find("without Source", 1, true) ~= nil,
      "season intake failure must name the missing source metadata"
    )
  end)
end
