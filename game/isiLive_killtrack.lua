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
  pullPercent = 0,
  displayUntil = 0, -- pullPercent stays visible until this GetTime() stamp
  -- Bumped whenever a combat end schedules a new grace window. The delayed
  -- clear carries the value it was scheduled with, so a callback left over
  -- from an earlier pull cannot cut a newer pull's window short.
  displayGeneration = 0,
}

-- Post-combat grace window: the final SCENARIO_CRITERIA_UPDATE often lags
-- PLAYER_REGEN_ENABLED by ~0.3s; 2s covers late fires and lets the player
-- read the pull delta before it resets.
local POST_COMBAT_GRACE_SECONDS = 2.0

local demoData = nil
local updateCallbacks = {}
local refreshTicker = nil
local pollingSuspended = false
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

-- Enemy-forces criteria ID of the current key. Some boss fights add their own
-- weighted progress bar next to enemy forces; outside such a fight enemy
-- forces is the only weighted criterion, so whenever exactly one weighted
-- criterion is readable its ID is locked in and preferred afterwards.
-- Cleared on CHALLENGE_MODE_START / RESET / COMPLETED.
local lockedForcesCriteriaID = nil

-- Reads every scenario criterion once. Returns a scan table and whether the
-- step itself was readable:
--   weighted = { { index, info }, ... } weighted-progress criteria
--   bosses = { { index, completed }, ... } every non-weighted criterion
--   bossesResolved = false when any boss field was secret / unreadable
--   incomplete = true when any criterion could not be classified at all
local function ReadScenarioCriteria()
  local scenarioInfo = rawget(_G, "C_ScenarioInfo")
  if
    type(scenarioInfo) ~= "table"
    or type(scenarioInfo.GetScenarioStepInfo) ~= "function"
    or type(scenarioInfo.GetCriteriaInfo) ~= "function"
  then
    return nil, false
  end
  local okStep, stepInfo = pcall(scenarioInfo.GetScenarioStepInfo)
  if not okStep or IsSecretValue(stepInfo) or type(stepInfo) ~= "table" then
    return nil, false
  end
  local scan = { weighted = {}, bosses = {}, bossesResolved = true, incomplete = false }
  local numCriteria = stepInfo.numCriteria
  if numCriteria == nil then
    return scan, true
  end
  if
    IsSecretValue(numCriteria)
    or type(numCriteria) ~= "number"
    or numCriteria < 0
    or numCriteria % 1 ~= 0
    or numCriteria ~= numCriteria
    or numCriteria == math.huge
  then
    return nil, false
  end
  for i = 1, numCriteria do
    local okCrit, cInfo = pcall(scenarioInfo.GetCriteriaInfo, i)
    local readable = okCrit and not IsSecretValue(cInfo) and type(cInfo) == "table"
    local isWeightedProgress = readable and cInfo.isWeightedProgress or nil
    if not readable or IsSecretValue(isWeightedProgress) then
      -- Unclassifiable: could be enemy forces or a boss. Neither the boss
      -- list nor an unlocked forces choice can be trusted for this read.
      scan.incomplete = true
      scan.bossesResolved = false
    elseif isWeightedProgress == true then
      scan.weighted[#scan.weighted + 1] = { index = i, info = cInfo }
    else
      local completed = cInfo.completed
      if IsSecretValue(completed) or (completed ~= nil and type(completed) ~= "boolean") then
        -- A masked boss state must never become a kill.
        scan.bossesResolved = false
      else
        scan.bosses[#scan.bosses + 1] = { index = i, completed = completed == true }
      end
    end
  end
  return scan, true
end

local function ReadCriteriaNumber(cInfo, field)
  local value = cInfo[field]
  if value == nil or IsSecretValue(value) then
    return nil
  end
  return tonumber(value)
end

-- Picks the enemy-forces criterion out of the weighted ones. Returns the
-- criterion info (or nil when there is none) and whether the choice is
-- resolved. Order: a single weighted criterion in a fully readable step
-- (locks its ID), then the locked ID, then -- only for a fully readable
-- step -- the weighted criterion with the largest readable total (lowest
-- index on ties).
local function SelectEnemyForcesCriteria(scan)
  local weighted = scan.weighted
  if #weighted == 1 and not scan.incomplete then
    local criteriaID = ReadCriteriaNumber(weighted[1].info, "criteriaID")
    if criteriaID then
      lockedForcesCriteriaID = criteriaID
    end
    return weighted[1].info, true
  end
  if lockedForcesCriteriaID ~= nil then
    for i = 1, #weighted do
      if ReadCriteriaNumber(weighted[i].info, "criteriaID") == lockedForcesCriteriaID then
        return weighted[i].info, true
      end
    end
  end
  if scan.incomplete then
    return nil, false
  end
  if #weighted == 0 then
    return nil, true
  end
  local best, bestTotal = nil, nil
  for i = 1, #weighted do
    local total = ReadCriteriaNumber(weighted[i].info, "totalQuantity")
    if total and total > 0 and (bestTotal == nil or total > bestTotal) then
      best, bestTotal = weighted[i].info, total
    end
  end
  if not best then
    return nil, false
  end
  return best, true
end

local function ObservePace(snapshot)
  local pace = addonTable.ForcesPace
  if type(pace) == "table" and type(pace.Observe) == "function" then
    pcall(pace.Observe, snapshot)
  end
end

-- Applies the enemy-forces criterion to `state`. Returns true only when the
-- resulting percentage comes from a verified read of this call.
local function ApplyEnemyForces(cInfo, mapID)
  if not cInfo then
    state.percent = 0
    state.rawCount = 0
    state.total = 0
    return false
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
    return false
  end
  -- `total` is deliberately not written to state yet: the snapshot has to move
  -- as one piece. Committing the new total before the count is known can leave
  -- a state whose three fields contradict each other -- rawCount 40 against
  -- total 200 while percent still reads 40 -- which no consumer can detect.

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

  local rawCount = nil
  local qStr = cInfo.quantityString
  if qStr and not IsSecretValue(qStr) then
    rawCount = tonumber(qStr:match("(%d+)"))
  end
  if rawCount == nil then
    local qty = cInfo.quantity
    if qty and not IsSecretValue(qty) then
      rawCount = tonumber(qty)
    end
  end

  -- Once enemy forces are complete the game stops updating the value, so a
  -- completed criterion reads as 100% regardless of the last count.
  local completed = cInfo.completed
  if not IsSecretValue(completed) and completed == true then
    state.total = total
    if rawCount ~= nil then
      state.rawCount = rawCount
    end
    state.percent = 100
    return true
  end

  if rawCount == nil then
    -- Neither source is readable: both were masked, or the string carried no
    -- digits. Zeroing here would replace a verified 40% with a synthetic 0%
    -- and, worse, look exactly like real progress. The complete previous
    -- snapshot -- total included -- stays until a readable update arrives.
    return false
  end
  state.total = total
  state.rawCount = rawCount
  state.percent = (rawCount / total) * 100
  return true
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

  local scan, scanResolved = ReadScenarioCriteria()
  if scanResolved ~= true then
    return
  end
  local snapshot = {
    mapID = mapID,
    bosses = scan.bosses,
    bossesResolved = scan.bossesResolved,
    percentResolved = false,
  }

  local cInfo, criteriaResolved = SelectEnemyForcesCriteria(scan)
  if criteriaResolved ~= true then
    ObservePace(snapshot)
    return
  end

  state.active = true
  state.mapID = mapID
  snapshot.percentResolved = ApplyEnemyForces(cInfo, mapID)
  snapshot.percent = state.percent
  ObservePace(snapshot)
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

-- Forward declaration: the ticker closure in StartRefreshTicker cancels itself
-- via StopRefreshTicker, which is defined below.
local StopRefreshTicker

local function StartRefreshTicker()
  if pollingSuspended or refreshTicker ~= nil then
    return
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) ~= "table" or type(timer.NewTicker) ~= "function" then
    return
  end
  refreshTicker = timer.NewTicker(0.5, function()
    -- ReadLiveData() below can clear state.active itself (map ID gone). Cancel
    -- from inside instead of only early-returning, otherwise the ticker keeps
    -- firing as a no-op until the next HandleEvent -- or forever, if none
    -- arrives.
    if not state.active then
      StopRefreshTicker()
      return
    end
    ReadLiveData()
    UpdatePullPercent()
    NotifyUpdate()
  end)
end

function StopRefreshTicker()
  if refreshTicker and type(refreshTicker.Cancel) == "function" then
    pcall(refreshTicker.Cancel, refreshTicker)
  end
  refreshTicker = nil
end

-- Raid suppression owns timer lifetime without discarding verified run data.
function KillTrack.SetPollingSuspended(suspended)
  pollingSuspended = suspended == true
  if pollingSuspended then
    StopRefreshTicker()
  elseif state.active then
    StartRefreshTicker()
  end
end

-- Learned forces target for the next boss of the active run, or nil.
local function ResolvePaceTarget()
  if not state.active then
    return nil
  end
  local pace = addonTable.ForcesPace
  if type(pace) ~= "table" or type(pace.GetPaceTarget) ~= "function" then
    return nil
  end
  local ok, target = pcall(pace.GetPaceTarget, state.mapID)
  if ok and type(target) == "number" then
    return target
  end
  return nil
end

local function CallPace(method)
  local pace = addonTable.ForcesPace
  if type(pace) == "table" and type(pace[method]) == "function" then
    pcall(pace[method])
  end
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
    paceTarget = ResolvePaceTarget(),
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
    if event == "CHALLENGE_MODE_COMPLETED" then
      -- Last chance to see the final boss kill before learning; the scenario
      -- may already be torn down, in which case this read changes nothing.
      ReadLiveData()
      CallPace("CommitRun")
    else
      CallPace("DiscardRun")
    end
    lockedForcesCriteriaID = nil
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
    lockedForcesCriteriaID = nil
    CallPace("BeginRun")
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
      pull.pullPercent = 0
    end
    NotifyUpdate()
  elseif event == "PLAYER_REGEN_ENABLED" then
    ReadLiveData()
    UpdatePullPercent()
    pull.inCombat = false
    pull.displayUntil = Now() + POST_COMBAT_GRACE_SECONDS
    pull.displayGeneration = pull.displayGeneration + 1
    local scheduledGeneration = pull.displayGeneration
    NotifyUpdate()
    local timer = rawget(_G, "C_Timer")
    if type(timer) == "table" and type(timer.After) == "function" then
      timer.After(POST_COMBAT_GRACE_SECONDS + 0.1, function()
        -- A short re-pull inside the grace window ends with its own combat end
        -- and its own generation. Without this check the older callback fires
        -- mid-window and wipes the newer pull's percentage off the row.
        if pull.displayGeneration ~= scheduledGeneration then
          return
        end
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
