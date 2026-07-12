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
      summary:find("- Active season: midnight_s1", 1, true) ~= nil,
      "season readiness inspect must report the persisted active season"
    )
    Assert.True(
      summary:find("| midnight_s2 | Midnight Season 2 | no | 0 | 0 | mapToTeleport is empty | - |", 1, true) ~= nil,
      "season readiness inspect must leave incomplete prepared season data unresolved"
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
      summary:find("| Altar of Fangs | unresolved | unresolved |", 1, true) ~= nil,
      "MDT preview inspect must not fabricate a candidate when no MDT file is available"
    )
  end)

  test("MDT season preview lists textual candidates from a cloned MDT tree", function()
    local tool = LoadTool("tools/inspect_mdt_season_preview.lua")
    local root = "tools/cache/test_mdt_preview"
    EnsureDir(root)
    WriteFile(
      root .. (IsWindows() and "\\DungeonData.lua" or "/DungeonData.lua"),
      'local dungeonName = "Altar of Fangs"\n'
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
      summary:find("| Altar of Fangs | ", 1, true) ~= nil and summary:find("DungeonData.lua", 1, true) ~= nil,
      "MDT preview must report the candidate file containing the planned dungeon name"
    )
    Assert.True(
      summary:find('local dungeonName = "Altar of Fangs"', 1, true) ~= nil,
      "MDT preview must include the matched source line as inspect context"
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

  test("Season intake check accepts current planned dungeon intake progress", function()
    local tool = LoadTool("tools/check_season_intake.lua")
    local ok, result = tool.Check()

    Assert.True(ok, "live season intake file should be structurally valid")
    Assert.True(
      result.summary:find("- Dungeon progress: 0/8 verified, 8 partial, 0 candidate, 0 unresolved", 1, true) ~= nil,
      "season intake summary must expose current intake progress"
    )
    Assert.True(
      result.summary:find("| Altar of Fangs | unresolved | unresolved | 1933 | partial |", 1, true) ~= nil,
      "season intake summary must include the verified Altar of Fangs Mythic+ activity"
    )
    Assert.True(
      result.summary:find("| Ruby Life Pools | unresolved | 393256 | 1176 | partial |", 1, true) ~= nil,
      "season intake summary must include the verified Ruby Life Pools Mythic+ LFG activity"
    )
    Assert.True(
      result.summary:find("| King's Rest | unresolved | unresolved | 514 | partial |", 1, true) ~= nil,
      "season intake summary must include the verified King's Rest Mythic+ activity"
    )
    Assert.True(
      result.summary:find("| Temple of Sethraliss | unresolved | unresolved | 504 | partial |", 1, true)
        ~= nil,
      "season intake summary must include the verified Temple of Sethraliss Mythic+ activity"
    )
    Assert.True(
      result.summary:find("| Murder Row | unresolved | unresolved | 1950 | partial |", 1, true) ~= nil,
      "season intake summary must include the verified Murder Row Mythic+ activity"
    )
    Assert.True(
      result.summary:find("| Den of Nalorakk | unresolved | unresolved | 1952 | partial |", 1, true) ~= nil,
      "season intake summary must include the verified Den of Nalorakk Mythic+ activity"
    )
    Assert.True(
      result.summary:find("| The Blinding Vale | unresolved | unresolved | 1949 | partial |", 1, true)
        ~= nil,
      "season intake summary must include the verified The Blinding Vale Mythic+ activity"
    )
    Assert.True(
      result.summary:find("| Voidscar Arena | unresolved | unresolved | 1951 | partial |", 1, true) ~= nil,
      "season intake summary must include the verified Voidscar Arena Mythic+ activity"
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
