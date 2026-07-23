local _, addonTable = ...

addonTable = addonTable or {}

local KillTrack = {}
addonTable.KillTrack = KillTrack
local IsSecretValue = addonTable.Validators.IsSecretValue

-- Optional sink for drift warnings (API-total vs DB-total).
-- The factory wires this to ctx.runtimeLogController.Logf so divergences land
-- in /isilive log dump output without spamming the chat frame.
local debugLogger = nil

local lastDriftKey = nil

local function GetMatchingForcesDB()
  local seasonData = addonTable.SeasonData
  if type(seasonData) == "table" and type(seasonData.GetMatchingForcesData) == "function" then
    return seasonData.GetMatchingForcesData()
  end
  return addonTable.MPlusForces
end

local state = {
  active = false,
  percent = 0,
  rawCount = 0,
  total = 0,
  mapID = nil,
}

-- Pull prediction state (delta-based, Midnight-compatible).
-- Records rawCount at combat start; diff = kills during this pull.
local pull = {
  inCombat = false,
  startRawCount = 0,
  startTotal = 0,
  pullPercent = 0,
  displayUntil = 0, -- pullPercent stays visible until this GetTime() stamp
}

-- Post-combat grace window: the final SCENARIO_CRITERIA_UPDATE often lags
-- PLAYER_REGEN_ENABLED by ~0.3s; 2s covers late fires and lets the player
-- read the pull delta before it resets.
local POST_COMBAT_GRACE_SECONDS = 2.0

local demoData = nil
local updateCallbacks = {}
local refreshTicker = nil
local nowFn = nil

local function Now()
  if type(nowFn) == "function" then
    return nowFn()
  end
  local getTime = rawget(_G, "GetTime")
  if type(getTime) == "function" then
    return getTime()
  end
  return 0
end

local function NotifyUpdate()
  for i = 1, #updateCallbacks do
    local cb = updateCallbacks[i]
    if type(cb) == "function" then
      pcall(cb)
    end
  end
end

local function FindEnemyForcesCriteria()
  if not C_ScenarioInfo or type(C_ScenarioInfo.GetScenarioStepInfo) ~= "function" then
    return nil
  end
  local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
  if not stepInfo or not stepInfo.numCriteria then
    return nil
  end
  if IsSecretValue(stepInfo.numCriteria) then
    return nil
  end
  for i = 1, stepInfo.numCriteria do
    local okCrit, cInfo = pcall(C_ScenarioInfo.GetCriteriaInfo, i)
    if okCrit and cInfo and cInfo.isWeightedProgress then
      return cInfo
    end
  end
  return nil
end

local function ReadLiveData()
  local mapID = nil
  local challengeMode = rawget(_G, "C_ChallengeMode")
  if type(challengeMode) == "table" and type(challengeMode.GetActiveChallengeMapID) == "function" then
    local ok, id = pcall(challengeMode.GetActiveChallengeMapID)
    if ok and not IsSecretValue(id) and type(id) == "number" and id > 0 then
      mapID = id
    end
  end
  if not mapID then
    state.active = false
    state.percent = 0
    state.rawCount = 0
    state.total = 0
    state.mapID = nil
    return
  end

  state.active = true
  state.mapID = mapID

  local cInfo = FindEnemyForcesCriteria()
  if not cInfo then
    state.percent = 0
    state.rawCount = 0
    state.total = 0
    return
  end

  -- Resolve API-total (live) and DB-total (deterministic, MDT-synced).
  -- API has primacy because rawCount comes from the same API call -- using a
  -- different total denominator would produce off-by-fraction percentages
  -- after a Blizzard-side patch shift. DB-total is a fallback for the rare
  -- case where Blizzard taints / nils the field.
  local apiTotalRaw = cInfo.totalQuantity
  local apiTotal = nil
  if apiTotalRaw and not IsSecretValue(apiTotalRaw) then
    local n = tonumber(apiTotalRaw)
    if n and n > 0 then
      apiTotal = n
    end
  end

  local dbTotal = nil
  local mplusForces = GetMatchingForcesDB()
  if type(mplusForces) == "table" and type(mplusForces.dungeonTotal) == "table" then
    local entry = mplusForces.dungeonTotal[mapID]
    if type(entry) == "table" then
      local n = tonumber(entry.total)
      if n and n > 0 then
        dbTotal = n
      end
    end
  end

  local total = apiTotal or dbTotal
  if not total or total <= 0 then
    state.percent = 0
    state.rawCount = 0
    state.total = 0
    return
  end
  state.total = total

  -- Drift-detection: if both totals exist and disagree, surface once via the
  -- runtime-log sink. Suppresses repeat-spam by remembering the last key we
  -- already reported (mapID + values).
  if apiTotal and dbTotal and apiTotal ~= dbTotal and type(debugLogger) == "function" then
    local key = string.format("%d:%d:%d", mapID, apiTotal, dbTotal)
    if lastDriftKey ~= key then
      lastDriftKey = key
      pcall(
        debugLogger,
        "[KILLTRACK] mapID=%d total drift: api=%d db=%d (using api; check tools/sync_mdt_forces.lua)",
        mapID,
        apiTotal,
        dbTotal
      )
    end
  end

  local rawCount = 0
  local qStr = cInfo.quantityString
  if qStr and not IsSecretValue(qStr) then
    rawCount = tonumber(qStr:match("(%d+)")) or 0
  else
    local qty = cInfo.quantity
    if qty and not IsSecretValue(qty) then
      rawCount = tonumber(qty) or 0
    end
  end
  state.rawCount = rawCount
  state.percent = (rawCount / total) * 100
end

function KillTrack.SetDebugLogger(fn)
  if type(fn) == "function" or fn == nil then
    debugLogger = fn
  end
end

local function UpdatePullPercent()
  if not state.active then
    pull.pullPercent = 0
    return
  end
  local total = state.total
  if total <= 0 then
    pull.pullPercent = 0
    return
  end
  local gained = state.rawCount - pull.startRawCount
  if gained < 0 then
    gained = 0
  end
  pull.pullPercent = (gained / total) * 100
  if pull.inCombat and pull.pullPercent > 0 then
    pull.displayUntil = Now() + POST_COMBAT_GRACE_SECONDS
  end
end

local function ShouldDisplayPull()
  if pull.inCombat then
    return true
  end
  if pull.pullPercent > 0 and Now() < pull.displayUntil then
    return true
  end
  return false
end

local function StartRefreshTicker()
  if refreshTicker ~= nil then
    return
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) ~= "table" or type(timer.NewTicker) ~= "function" then
    return
  end
  refreshTicker = timer.NewTicker(0.5, function()
    if not state.active then
      return
    end
    ReadLiveData()
    UpdatePullPercent()
    NotifyUpdate()
  end)
end

local function StopRefreshTicker()
  if refreshTicker and type(refreshTicker.Cancel) == "function" then
    pcall(refreshTicker.Cancel, refreshTicker)
  end
  refreshTicker = nil
end

function KillTrack.GetData()
  if demoData then
    return demoData
  end
  local displayPull = ShouldDisplayPull()
  return {
    active = state.active,
    percent = state.percent,
    rawCount = state.rawCount,
    total = state.total,
    mapID = state.mapID,
    inCombat = displayPull,
    pullPercent = displayPull and pull.pullPercent or 0,
  }
end

function KillTrack.SetDemoData(data)
  demoData = data
  NotifyUpdate()
end

function KillTrack.ClearDemoData()
  demoData = nil
  NotifyUpdate()
end

-- Subscribe a callback fired whenever KillTrack state changes (scenario
-- criteria, combat transitions, ticker). UI uses this to refresh the kill
-- bar reliably instead of depending on the roster render loop.
function KillTrack.OnUpdate(callback)
  if type(callback) ~= "function" then
    return
  end
  for i = 1, #updateCallbacks do
    if updateCallbacks[i] == callback then
      return
    end
  end
  table.insert(updateCallbacks, callback)
end

-- Exposed for tests: drive the event loop directly.
function KillTrack._DispatchEvent(event)
  if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
    state.active = false
    state.percent = 0
    state.rawCount = 0
    state.total = 0
    state.mapID = nil
    pull.inCombat = false
    pull.pullPercent = 0
    pull.displayUntil = 0
    StopRefreshTicker()
    NotifyUpdate()
  elseif event == "CHALLENGE_MODE_START" then
    ReadLiveData()
    if state.active then
      StartRefreshTicker()
    end
    NotifyUpdate()
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- Refresh baseline from live data first: state.rawCount may be stale if
    -- no SCENARIO_CRITERIA_UPDATE has fired since the last pull ended.
    ReadLiveData()
    if state.active then
      pull.inCombat = true
      pull.startRawCount = state.rawCount
      pull.startTotal = state.total
      pull.pullPercent = 0
    end
    NotifyUpdate()
  elseif event == "PLAYER_REGEN_ENABLED" then
    ReadLiveData()
    UpdatePullPercent()
    pull.inCombat = false
    pull.displayUntil = Now() + POST_COMBAT_GRACE_SECONDS
    NotifyUpdate()
    local timer = rawget(_G, "C_Timer")
    if type(timer) == "table" and type(timer.After) == "function" then
      timer.After(POST_COMBAT_GRACE_SECONDS + 0.1, function()
        if not pull.inCombat then
          pull.pullPercent = 0
          pull.displayUntil = 0
          NotifyUpdate()
        end
      end)
    end
  else
    ReadLiveData()
    UpdatePullPercent()
    if state.active then
      StartRefreshTicker()
    else
      StopRefreshTicker()
    end
    NotifyUpdate()
  end
end

function KillTrack.HandleEvent(event)
  KillTrack._DispatchEvent(event)
end
