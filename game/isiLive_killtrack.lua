local _, addonTable = ...

addonTable = addonTable or {}

local KillTrack = {}
addonTable.KillTrack = KillTrack

local state = {
  active   = false,
  percent  = 0,
  rawCount = 0,
  total    = 0,
}

-- Pull prediction state (delta-based, Midnight-compatible)
-- In Midnight M+, all NPC identification APIs return secret values inside the
-- instance. The only viable approach is tracking the scenario quantity delta:
-- record rawCount at combat start, diff = kills so far in this pull.
local pull = {
  inCombat        = false,
  startRawCount   = 0,
  startTotal      = 0,
  pullPercent     = 0,  -- cached for display
}

local demoData = nil

local function FindEnemyForcesCriteria()
  if not C_ScenarioInfo or type(C_ScenarioInfo.GetScenarioStepInfo) ~= "function" then
    return nil
  end
  local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
  if not stepInfo or not stepInfo.numCriteria then return nil end
  local issecret = rawget(_G, "issecretvalue") or function() return false end
  if issecret(stepInfo.numCriteria) then return nil end
  for i = 1, stepInfo.numCriteria do
    local cInfo = C_ScenarioInfo.GetCriteriaInfo(i)
    if cInfo and cInfo.isWeightedProgress then
      return cInfo
    end
  end
  return nil
end

local function ReadLiveData()
  local issecret = rawget(_G, "issecretvalue") or function() return false end

  local mapID = nil
  if C_ChallengeMode and type(C_ChallengeMode.GetActiveChallengeMapID) == "function" then
    local ok, id = pcall(C_ChallengeMode.GetActiveChallengeMapID)
    if ok and type(id) == "number" and id > 0 and not issecret(id) then
      mapID = id
    end
  end
  if not mapID then
    state.active   = false
    state.percent  = 0
    state.rawCount = 0
    state.total    = 0
    return
  end

  state.active = true

  local cInfo = FindEnemyForcesCriteria()
  if not cInfo then
    state.percent  = 0
    state.rawCount = 0
    state.total    = 0
    return
  end

  local total = cInfo.totalQuantity
  if not total or issecret(total) or total <= 0 then
    state.percent  = 0
    state.rawCount = 0
    state.total    = 0
    return
  end
  state.total = total

  local rawCount = 0
  local qStr = cInfo.quantityString
  if qStr and not issecret(qStr) then
    rawCount = tonumber(qStr:match("(%d+)")) or 0
  else
    local qty = cInfo.quantity
    if qty and not issecret(qty) then
      rawCount = tonumber(qty) or 0
    end
  end
  state.rawCount = rawCount
  state.percent  = (rawCount / total) * 100
end

local function UpdatePullPercent()
  if not pull.inCombat or not state.active then
    pull.pullPercent = 0
    return
  end
  local total = state.total
  if total <= 0 then
    pull.pullPercent = 0
    return
  end
  local gained = state.rawCount - pull.startRawCount
  if gained < 0 then gained = 0 end
  pull.pullPercent = (gained / total) * 100
end

function KillTrack.GetData()
  if demoData then return demoData end
  return {
    active      = state.active,
    percent     = state.percent,
    rawCount    = state.rawCount,
    total       = state.total,
    inCombat    = pull.inCombat,
    pullPercent = pull.pullPercent,
  }
end

function KillTrack.SetDemoData(data)  demoData = data end
function KillTrack.ClearDemoData()   demoData = nil  end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("CHALLENGE_MODE_RESET")
eventFrame:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(_, event)
  if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
    state.active      = false
    state.percent     = 0
    state.rawCount    = 0
    state.total       = 0
    pull.inCombat     = false
    pull.pullPercent  = 0
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- Combat start: snapshot current raw count as pull baseline
    if state.active then
      pull.inCombat      = true
      pull.startRawCount = state.rawCount
      pull.startTotal    = state.total
      pull.pullPercent   = 0
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- Combat end: delay slightly to catch final SCENARIO_CRITERIA_UPDATE
    if C_Timer and C_Timer.After then
      C_Timer.After(0.5, function()
        pull.inCombat    = false
        pull.pullPercent = 0
      end)
    else
      pull.inCombat    = false
      pull.pullPercent = 0
    end
  else
    ReadLiveData()
    if pull.inCombat then
      UpdatePullPercent()
    end
  end
end)
