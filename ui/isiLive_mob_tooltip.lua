local _, addonTable = ...
addonTable = addonTable or {}

local MobTooltip = {}
addonTable.MobTooltip = MobTooltip

local enabled = true
local tdpRegistered = false
local clearHooked = false
local getLocale = function()
  return {}
end

-- Prevents stacking the same line on tooltip rerenders (TooltipDataProcessor
-- fires on every refresh, including hover-over-self reflow). Keyed by the
-- tooltip frame reference; in production only GameTooltip ever shows up here
-- (TooltipDataProcessor.Unit fires against the shared tooltip), and the
-- OnTooltipCleared hook wires the cache reset for it. If a future caller
-- routes a custom tooltip through AppendForcesLine, drop a matching cleanup
-- there too.
local lastAppendedKey = {}

local function IsSecretValue(v)
  local fn = rawget(_G, "issecretvalue")
  return type(fn) == "function" and fn(v) == true
end

local function GetForcesDB()
  local seasonData = addonTable.SeasonData
  local db
  if type(seasonData) == "table" and type(seasonData.GetMatchingForcesData) == "function" then
    db = seasonData.GetMatchingForcesData()
  else
    db = addonTable.MPlusForces
  end
  if type(db) ~= "table" then
    return nil
  end
  if type(db.byNpcId) ~= "table" or type(db.dungeonTotal) ~= "table" then
    return nil
  end
  return db
end

local function GetActiveChallengeMapID()
  local api = rawget(_G, "C_ChallengeMode")
  if type(api) ~= "table" or type(api.GetActiveChallengeMapID) ~= "function" then
    return nil
  end
  local ok, mapID = pcall(api.GetActiveChallengeMapID)
  if not ok or type(mapID) ~= "number" or mapID <= 0 or IsSecretValue(mapID) then
    return nil
  end
  return mapID
end

-- Returns npcID as a number, or nil if the GUID is not a Creature/Vehicle.
local function NpcIdFromGuid(guid)
  if type(guid) ~= "string" or guid == "" then
    return nil
  end
  local kind, _, _, _, _, npcStr = guid:match("^(%a+)%-(%d+)%-(%d+)%-(%d+)%-(%d+)%-(%d+)%-")
  if kind ~= "Creature" and kind ~= "Vehicle" then
    return nil
  end
  return tonumber(npcStr)
end

local function ResolveGuid(tooltipData)
  if type(tooltipData) == "table" then
    local candidate = tooltipData.guid
    if type(candidate) == "string" and not IsSecretValue(candidate) and candidate ~= "" then
      return candidate
    end
  end
  local unitGUIDFn = rawget(_G, "UnitGUID")
  if type(unitGUIDFn) ~= "function" then
    return nil
  end
  local ok, guid = pcall(unitGUIDFn, "mouseover")
  if ok and type(guid) == "string" and not IsSecretValue(guid) and guid ~= "" then
    return guid
  end
  return nil
end

local function AppendForcesLine(tooltip, data)
  if enabled == false then
    return
  end
  if type(tooltip) ~= "table" or type(tooltip.AddLine) ~= "function" then
    return
  end

  local activeMapID = GetActiveChallengeMapID() -- secret-value-ok: file-local helper is pcall-protected
  if not activeMapID then
    return
  end

  local db = GetForcesDB()
  if not db then
    return
  end

  local guid = ResolveGuid(data)
  local npcId = NpcIdFromGuid(guid)
  if not npcId then
    return
  end

  local entry = db.byNpcId[npcId]
  if type(entry) ~= "table" or entry.mapID ~= activeMapID then
    return
  end

  local dungeon = db.dungeonTotal[activeMapID]
  local total = dungeon and tonumber(dungeon.total) or 0
  local count = tonumber(entry.count) or 0
  if total <= 0 or count <= 0 then
    return
  end

  local percent = (count / total) * 100
  local key = tostring(guid) .. ":" .. tostring(npcId)
  if lastAppendedKey[tooltip] == key then
    return
  end
  lastAppendedKey[tooltip] = key

  -- Format makes it unambiguous that this is the mob's contribution, not the
  -- current dungeon progress: "+5 Fortschritt (1.16% von 431)" reads as
  -- "this mob adds +5 to your progress counter, which is 1.16% of the 431-total".
  local L = getLocale()
  if type(L) ~= "table" then
    L = {}
  end
  local fmt = type(L.TOOLTIP_MOB_PROGRESS_LINE) == "string" and L.TOOLTIP_MOB_PROGRESS_LINE
    or "+%d progress (%.2f%% of %d)"
  tooltip:AddLine(string.format(fmt, count, percent, total), 0.4, 0.8, 1)
end

local function HookTooltipClear()
  if clearHooked then
    return
  end
  local gameTooltip = rawget(_G, "GameTooltip")
  if type(gameTooltip) ~= "table" or type(gameTooltip.HookScript) ~= "function" then
    return
  end
  gameTooltip:HookScript("OnTooltipCleared", function(self)
    lastAppendedKey[self] = nil
  end)
  clearHooked = true
end

function MobTooltip.SetEnabled(flag)
  enabled = flag ~= false
end

function MobTooltip.SetLocaleGetter(fn)
  if type(fn) == "function" then
    getLocale = fn
  end
end

function MobTooltip.Register()
  if not tdpRegistered then
    local tdp = rawget(_G, "TooltipDataProcessor")
    local enumRef = rawget(_G, "Enum")
    local dataType = type(enumRef) == "table" and enumRef.TooltipDataType or nil
    if
      type(tdp) ~= "table"
      or type(tdp.AddTooltipPostCall) ~= "function"
      or type(dataType) ~= "table"
      or dataType.Unit == nil
    then
      return false
    end

    tdp.AddTooltipPostCall(dataType.Unit, function(self, data)
      AppendForcesLine(self, data)
    end)
    tdpRegistered = true
  end

  -- Retry the OnTooltipCleared hook every Register() call until it actually
  -- attaches. In production GameTooltip is constructed by Blizzard before any
  -- addon code runs so the very first attempt succeeds; this loop is just
  -- defensive against a Register() that fires before GameTooltip is ready.
  HookTooltipClear()
  return true
end

return MobTooltip
