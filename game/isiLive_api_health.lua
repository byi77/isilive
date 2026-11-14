local _, addonTable = ...

addonTable = addonTable or {}

-- Patch-day self test (`/isilive selftest`, rule 251). Many isiLive features
-- fail closed and silently when Blizzard renames, removes or masks an API
-- (TTK, nameplate forces, damage meter, LFG detection). This report lists,
-- per feature, whether the Blizzard APIs it reads still exist, so a patch
-- shows at once which feature went dark. It only reads: no API is called
-- except the side-effect-free probes below, each under pcall.
local ApiHealth = {}
addonTable.ApiHealth = ApiHealth

local IsSecretValue = addonTable.Validators.IsSecretValue

-- { feature, root, function }. `root = nil` names a global function. The list
-- covers the Blizzard surfaces docs/WARTUNG.md section 3 names as the first to
-- break after a patch; extend it with every new API surface a feature needs.
ApiHealth.CHECKS = {
  { "Instance", nil, "GetInstanceInfo" },
  { "Instance", "C_Map", "GetBestMapForUnit" },
  { "M+ key", "C_ChallengeMode", "GetActiveChallengeMapID" },
  { "M+ key", "C_ChallengeMode", "GetActiveKeystoneInfo" },
  { "M+ key", "C_ChallengeMode", "GetMapUIInfo" },
  { "M+ key", "C_ChallengeMode", "GetDeathCount" },
  { "M+ key", "C_ChallengeMode", "GetChallengeCompletionInfo" },
  { "Season", "C_ChallengeMode", "GetMapTable" },
  { "Season", "C_MythicPlus", "RequestMapInfo" },
  { "Item level colours", "C_MythicPlus", "GetRewardLevelFromKeystoneLevel" },
  { "LFG personal best", "C_MythicPlus", "GetSeasonBestForMap" },
  { "Rating", "C_PlayerInfo", "GetPlayerMythicPlusRatingSummary" },
  { "Killtracker", "C_ScenarioInfo", "GetScenarioStepInfo" },
  { "Killtracker", "C_ScenarioInfo", "GetCriteriaInfo" },
  { "DPS / kicks", "C_DamageMeter", "GetCombatSessionFromType" },
  { "TTK", "C_CurveUtil", "CreateCurve" },
  { "TTK", nil, "UnitHealthPercent" },
  { "Nameplates", "C_NamePlate", "GetNamePlateForUnit" },
  { "LFG", "C_LFGList", "GetActivityInfoTable" },
  { "LFG", "C_LFGList", "GetActiveEntryInfo" },
  { "LFG", "C_LFGList", "GetSearchResultInfo" },
  { "Sync", "C_ChatInfo", "SendAddonMessage" },
  { "Sync", "C_ChatInfo", "RegisterAddonMessagePrefix" },
  { "Sync", "C_ChatInfo", "InChatMessagingLockdown" },
  { "Cooldowns", "C_Spell", "GetSpellCooldown" },
  { "Cooldowns", "C_Spell", "GetSpellName" },
  { "Auras", "C_UnitAuras", "GetAuraDataByIndex" },
  { "Auras", "C_UnitAuras", "GetPlayerAuraBySpellID" },
  { "Keystone link", "C_Container", "GetContainerItemLink" },
  { "Item level", "C_Item", "GetAverageItemLevel" },
  { "Inspect", "C_PaperDollInfo", "GetInspectItemLevel" },
  { "Invite navigation", "C_EncounterJournal", "GetDungeonEntrancesForMap" },
  { "Timers", "C_Timer", "After" },
  { "Secret values", nil, "issecretvalue" }, -- secret-value-ok: presence check only, never called
}

local function ResolveFunction(rootName, fnName)
  if rootName == nil then
    return rawget(_G, fnName)
  end
  local root = rawget(_G, rootName)
  if type(root) ~= "table" then
    return nil
  end
  return rawget(root, fnName)
end

local function QualifiedName(rootName, fnName)
  return rootName and (rootName .. "." .. fnName) or fnName
end

-- Side-effect-free live probes: they show that a present API still answers
-- the way isiLive reads it.
local function ProbeMapTable()
  local fn = ResolveFunction("C_ChallengeMode", "GetMapTable")
  local ok, maps = pcall(fn)
  if not ok then
    return false, "error"
  end
  if IsSecretValue(maps) or type(maps) ~= "table" then
    return false, "no table"
  end
  return true, string.format("%d maps", #maps)
end

local function ProbeCurve()
  local fn = ResolveFunction("C_CurveUtil", "CreateCurve")
  local ok, curve = pcall(fn)
  if not ok then
    return false, "error"
  end
  -- The curve is userdata in the client; only nil means failure.
  if curve == nil then
    return false, "no curve"
  end
  return true, "curve created"
end

local PROBES = {
  ["C_ChallengeMode.GetMapTable"] = ProbeMapTable,
  ["C_CurveUtil.CreateCurve"] = ProbeCurve,
}

--- Runs every check. Returns the result rows and the counts.
-- Row: { feature, name, status = "ok" | "missing" | "error", detail }.
function ApiHealth.Run()
  local rows = {}
  local counts = { ok = 0, missing = 0, error = 0 }
  for _, check in ipairs(ApiHealth.CHECKS) do
    local feature, rootName, fnName = check[1], check[2], check[3]
    local name = QualifiedName(rootName, fnName)
    local status, detail = "ok", nil
    if type(ResolveFunction(rootName, fnName)) ~= "function" then
      status = "missing"
    else
      local probe = PROBES[name]
      if probe then
        local probeOk, probeDetail = probe()
        status = probeOk and "ok" or "error"
        detail = probeDetail
      end
    end
    counts[status] = counts[status] + 1
    rows[#rows + 1] = { feature = feature, name = name, status = status, detail = detail }
  end
  return rows, counts
end

local STATUS_TEXT = { ok = "ok", missing = "MISSING", error = "ERROR" }

--- Report lines: failures first (they are what a patch day needs), then a
-- summary line. `verbose = true` also lists every passing check.
function ApiHealth.BuildReportLines(verbose)
  local rows, counts = ApiHealth.Run()
  local lines = {}
  for _, wanted in ipairs({ "missing", "error", "ok" }) do
    if wanted ~= "ok" or verbose then
      for _, row in ipairs(rows) do
        if row.status == wanted then
          local detail = row.detail and (" (" .. row.detail .. ")") or ""
          lines[#lines + 1] =
            string.format("[SELFTEST] %s %s - %s%s", STATUS_TEXT[row.status], row.name, row.feature, detail)
        end
      end
    end
  end
  lines[#lines + 1] = string.format(
    "[SELFTEST] %d ok, %d missing, %d error of %d Blizzard APIs",
    counts.ok,
    counts.missing,
    counts.error,
    #rows
  )
  return lines, counts
end

function ApiHealth.PrintReport(printFn, verbose)
  printFn = type(printFn) == "function" and printFn or print
  local lines = ApiHealth.BuildReportLines(verbose)
  for _, line in ipairs(lines) do
    printFn(line)
  end
end
