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
  local ok, _, _, timeLimit = pcall(C_ChallengeMode.GetMapUIInfo, mapId)
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
  local mapId
  do
    local ok, id = pcall(C_ChallengeMode.GetActiveChallengeMapID)
    if ok and type(id) == "number" then
      mapId = id
    end
  end
  LoadKeyTimeLimits(mapId)

  local keyLevel = 0
  do
    local ok, level = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
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
  tickFrame:SetScript("OnUpdate", function(_, elapsed)
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
  tickFrame:SetScript("OnUpdate", nil)
  tickAccum = 0
end

local function UpdateDeaths()
  local ok, count, timeLost = pcall(C_ChallengeMode.GetDeathCount)
  if ok then
    state.deaths = count or 0
    state.deathTimeLost = timeLost or 0
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

-- Event registration
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("CHALLENGE_MODE_RESET")
eventFrame:RegisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED")

eventFrame:SetScript("OnEvent", function(_, event)
  if event == "CHALLENGE_MODE_START" then
    StartTimer()
  elseif event == "CHALLENGE_MODE_COMPLETED" then
    StopTimer(true)
  elseif event == "CHALLENGE_MODE_RESET" then
    StopTimer(false)
    state.timer = 0
    state.deaths = 0
    state.deathTimeLost = 0
    state.timeLimit = 0
    state.timeLimits = { 0, 0, 0 }
  elseif event == "CHALLENGE_MODE_DEATH_COUNT_UPDATED" then
    UpdateDeaths()
  end
end)

tickFrame = CreateFrame("Frame")
