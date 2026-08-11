local _, addonTable = ...

addonTable = addonTable or {}

local SeasonDebug = {}
addonTable.SeasonDebug = SeasonDebug
local IsSecretValue = addonTable.Validators.IsSecretValue
local GetInstanceInfoSafe = addonTable.Validators.GetInstanceInfoSafe

local function ValueText(value)
  if value == nil then
    return "nil"
  end
  if type(value) == "boolean" then
    return value and "true" or "false"
  end
  return tostring(value)
end

-- Packs a pcall result into { n = count, [1..n] = values }. A plain
-- `{ pcall(f) }` plus `table.remove` breaks when the called function returns a
-- nil in the middle: the array then has a hole and `#results` is undefined, so
-- the trailing values can silently disappear. Blizzard season APIs regularly
-- return nil for unavailable fields, which is exactly this dump's subject.
local function PackCallResults(...)
  local count = select("#", ...)
  local packed = { n = count - 1 }
  for index = 2, count do
    packed[index - 1] = (select(index, ...))
  end
  return (select(1, ...)), packed
end

local function SafeCallTable(rootName, fnName, ...)
  local root = rawget(_G, rootName)
  if type(root) ~= "table" or type(root[fnName]) ~= "function" then
    return false, "unavailable"
  end
  local ok, results = PackCallResults(pcall(root[fnName], ...))
  if not ok then
    return false, "error:" .. tostring(results[1])
  end
  return true, results
end

local function AppendReadiness(lines)
  local seasonData = addonTable.SeasonData
  if type(seasonData) ~= "table" then
    lines[#lines + 1] = "[SEASON] SeasonData unavailable"
    return
  end

  local activeID = type(seasonData.GetActiveSeasonID) == "function" and seasonData.GetActiveSeasonID() or nil
  lines[#lines + 1] = "[SEASON] activeSeasonID=" .. ValueText(activeID)

  if type(seasonData.GetAvailableSeasonIDs) == "function" then
    local ids = seasonData.GetAvailableSeasonIDs()
    if type(ids) == "table" then
      lines[#lines + 1] = "[SEASON] available=" .. table.concat(ids, ",")
    end
  end

  if type(seasonData.GetSeasonReadiness) == "function" then
    local readiness = seasonData.GetSeasonReadiness(activeID)
    lines[#lines + 1] = string.format(
      "[SEASON] readiness id=%s ready=%s mapped=%s aliases=%s",
      ValueText(readiness and readiness.seasonID),
      ValueText(readiness and readiness.isReady),
      ValueText(readiness and readiness.mappedDungeonCount),
      ValueText(readiness and readiness.aliasCount)
    )
    if type(readiness) == "table" then
      for _, err in ipairs(readiness.errors or {}) do
        lines[#lines + 1] = "[SEASON] error=" .. tostring(err)
      end
      for _, warning in ipairs(readiness.warnings or {}) do
        lines[#lines + 1] = "[SEASON] warning=" .. tostring(warning)
      end
    end
  end

  local forces = addonTable.MPlusForces
  if type(forces) == "table" then
    lines[#lines + 1] = string.format(
      "[SEASON] forces season=%s mdtVersion=%s generatedAt=%s expiresAt=%s dungeons=%s npcs=%s",
      ValueText(forces.season),
      ValueText(forces.mdtVersion),
      ValueText(forces.generatedAt),
      ValueText(forces.expiresAt),
      ValueText(forces.dungeonCount),
      ValueText(forces.npcCount)
    )
  else
    lines[#lines + 1] = "[SEASON] forces unavailable"
  end
end

local function AppendInstanceInfo(lines)
  if type(GetInstanceInfoSafe) ~= "function" then
    lines[#lines + 1] = "[SEASON] GetInstanceInfo=unavailable"
    return
  end

  local ok, instanceInfo = GetInstanceInfoSafe()
  if not ok then
    lines[#lines + 1] = "[SEASON] GetInstanceInfo=unavailable"
    return
  end

  lines[#lines + 1] = string.format(
    "[SEASON] instance name=%s type=%s difficultyID=%s mapID=%s groupSize=%s instanceID=%s",
    ValueText(instanceInfo.instanceName),
    ValueText(instanceInfo.instanceType),
    ValueText(instanceInfo.difficultyID),
    ValueText(instanceInfo.instanceMapID),
    ValueText(instanceInfo.maxPlayers),
    ValueText(instanceInfo.instanceID)
  )
end

local function AppendMapInfo(lines)
  local unitExists = rawget(_G, "UnitExists")
  if type(unitExists) == "function" then
    local okUnit, exists = pcall(unitExists, "player")
    if not okUnit or IsSecretValue(exists) or exists ~= true then
      lines[#lines + 1] = "[SEASON] playerUnitExists=false"
      return
    end
  end

  local ok, result = SafeCallTable("C_Map", "GetBestMapForUnit", "player")
  if ok then
    lines[#lines + 1] = "[SEASON] playerBestMapID=" .. ValueText(result[1])
  else
    lines[#lines + 1] = "[SEASON] playerBestMapID=" .. tostring(result)
  end
end

local function AppendChallengeInfo(lines)
  local okMap, mapResult = SafeCallTable("C_ChallengeMode", "GetActiveChallengeMapID")
  lines[#lines + 1] = "[SEASON] activeChallengeMapID=" .. (okMap and ValueText(mapResult[1]) or tostring(mapResult))

  local okLevel, levelResult = SafeCallTable("C_ChallengeMode", "GetActiveKeystoneInfo")
  if okLevel then
    lines[#lines + 1] = string.format(
      "[SEASON] activeKeystone level=%s affix1=%s affix2=%s affix3=%s affix4=%s",
      ValueText(levelResult[1]),
      ValueText(levelResult[2]),
      ValueText(levelResult[3]),
      ValueText(levelResult[4]),
      ValueText(levelResult[5])
    )
  else
    lines[#lines + 1] = "[SEASON] activeKeystone=" .. tostring(levelResult)
  end
end

local function AppendLfgInfo(lines)
  local ok, result = SafeCallTable("C_LFGList", "GetActiveEntryInfo")
  if not ok then
    lines[#lines + 1] = "[SEASON] activeLfgEntry=" .. tostring(result)
    return
  end

  local entryInfo = result[1]
  if type(entryInfo) == "table" then
    lines[#lines + 1] = string.format(
      "[SEASON] activeLfgEntry activityID=%s activityIDs=%s name=%s",
      ValueText(entryInfo.activityID),
      type(entryInfo.activityIDs) == "table" and table.concat(entryInfo.activityIDs, ",")
        or ValueText(entryInfo.activityIDs),
      ValueText(entryInfo.name)
    )
  else
    lines[#lines + 1] = "[SEASON] activeLfgEntry=" .. ValueText(entryInfo)
  end
end

function SeasonDebug.BuildDumpLines()
  local lines = {}
  AppendReadiness(lines)
  AppendInstanceInfo(lines)
  AppendMapInfo(lines)
  AppendChallengeInfo(lines)
  AppendLfgInfo(lines)
  return lines
end

function SeasonDebug.PrintDump(printFn)
  printFn = type(printFn) == "function" and printFn or print
  for _, line in ipairs(SeasonDebug.BuildDumpLines()) do
    printFn(line)
  end
end
