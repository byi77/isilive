local _, addonTable = ...

addonTable = addonTable or {}

local MplusTimer = {}
addonTable.MplusTimer = MplusTimer

-- Internal state
local state = {
  running = false,
  completed = false,
  timer = 0,
  timeLimit = 0,
  timeLimits = { 0, 0, 0 }, -- +1, +2, +3
  deaths = 0,
  deathTimeLost = 0,
}

local tickFrame
local tickAccum = 0

local function EnsureTickFrame()
  if not tickFrame then
    tickFrame = CreateFrame("Frame")
  end
  return tickFrame
end

-- Called every 0.1s while the key is running
local function OnUpdate()
  if not state.running then
    return
  end
  -- GetWorldElapsedTime returns (timerType, elapsedTime, ...) — use select(2, ...) for elapsed
  local ok, _, elapsedTime = pcall(GetWorldElapsedTime, 1)
  if ok and type(elapsedTime) == "number" then
    state.timer = elapsedTime
  end
end

local function LoadKeyTimeLimits(mapId)
  if type(mapId) ~= "number" or mapId <= 0 then
    return
  end
  local challengeMode = rawget(_G, "C_ChallengeMode")
  if type(challengeMode) ~= "table" or type(challengeMode.GetMapUIInfo) ~= "function" then
    return
  end
  local ok, _, _, timeLimit = pcall(challengeMode.GetMapUIInfo, mapId)
  if not ok or type(timeLimit) ~= "number" or timeLimit <= 0 then
    return
  end
  state.timeLimit = timeLimit
  -- +3 = 60%, +2 = 80%, +1 = 100%
  state.timeLimits = {
    timeLimit,
    timeLimit * 0.8,
    timeLimit * 0.6,
  }
end

-- Death time penalties only apply at key level 4 and above.
local DEATH_PENALTY_MIN_LEVEL = 4

local function StartTimer()
  local challengeMode = rawget(_G, "C_ChallengeMode")
  local hasChallengeAPI = type(challengeMode) == "table"

  local mapId
  if hasChallengeAPI and type(challengeMode.GetActiveChallengeMapID) == "function" then
    local ok, id = pcall(challengeMode.GetActiveChallengeMapID)
    if ok and type(id) == "number" then
      mapId = id
    end
  end
  LoadKeyTimeLimits(mapId)

  local keyLevel = 0
  if hasChallengeAPI and type(challengeMode.GetActiveKeystoneInfo) == "function" then
    local ok, level = pcall(challengeMode.GetActiveKeystoneInfo)
    if ok and type(level) == "number" then
      keyLevel = level
    end
  end
  state.keyLevel = keyLevel
  state.deathPenaltyActive = keyLevel >= DEATH_PENALTY_MIN_LEVEL

  state.timer = 0
  state.deaths = 0
  state.deathTimeLost = 0
  state.running = true
  state.completed = false
  tickAccum = 0
  EnsureTickFrame():SetScript("OnUpdate", function(_, elapsed)
    tickAccum = tickAccum + elapsed
    if tickAccum >= 0.1 then
      tickAccum = 0
      OnUpdate()
    end
  end)
end

local function StopTimer(completed)
  state.running = false
  state.completed = completed == true
  if tickFrame then
    tickFrame:SetScript("OnUpdate", nil)
  end
  tickAccum = 0
end

local function ResetTimerState()
  StopTimer(false)
  state.timer = 0
  state.deaths = 0
  state.deathTimeLost = 0
  state.timeLimit = 0
  state.timeLimits = { 0, 0, 0 }
  state.keyLevel = 0
  state.deathPenaltyActive = false
end

local function UpdateDeaths()
  local challengeMode = rawget(_G, "C_ChallengeMode")
  if type(challengeMode) ~= "table" or type(challengeMode.GetDeathCount) ~= "function" then
    return
  end
  local ok, count, timeLost = pcall(challengeMode.GetDeathCount)
  if ok then
    if type(count) == "number" then
      state.deaths = count
    end
    -- Keep previous timeLost when the API momentarily returns nil (secret-value
    -- masking in tainted mid-key contexts). Without this guard the UI flickers
    -- 75s -> 0 -> 75s on every transient mask.
    if type(timeLost) == "number" then
      state.deathTimeLost = timeLost
    end
  end
end

local demoData = nil

function MplusTimer.SetDemoData(data)
  demoData = data
end

function MplusTimer.ClearDemoData()
  demoData = nil
end

-- Public: returns a snapshot of the current M+ timer state.
-- timeRemaining1/2/3 = seconds until +1/+2/+3 cutoff (negative = already missed)
function MplusTimer.GetTimerData()
  if demoData then
    return demoData
  end
  return {
    running = state.running,
    completed = state.completed,
    timer = state.timer,
    timeLimit = state.timeLimit,
    keyLevel = state.keyLevel or 0,
    timeRemaining1 = state.timeLimits[1] - state.timer,
    timeRemaining2 = state.timeLimits[2] - state.timer,
    timeRemaining3 = state.timeLimits[3] - state.timer,
    deaths = state.deaths,
    deathTimeLost = state.deathPenaltyActive and state.deathTimeLost or 0,
  }
end

function MplusTimer.HandleEvent(event)
  if event == "CHALLENGE_MODE_START" then
    StartTimer()
  elseif event == "CHALLENGE_MODE_COMPLETED" then
    ResetTimerState()
  elseif event == "CHALLENGE_MODE_RESET" then
    ResetTimerState()
  elseif event == "CHALLENGE_MODE_DEATH_COUNT_UPDATED" then
    UpdateDeaths()
  elseif event == "PLAYER_ENTERING_WORLD" then
    if state.completed and not state.running then
      ResetTimerState()
    end
  end
end
