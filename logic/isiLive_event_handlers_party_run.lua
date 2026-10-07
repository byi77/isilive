local _, addonTable = ...

addonTable = addonTable or {}

-- Tracked non-challenge party run (M0) lifecycle, split out of
-- logic/isiLive_event_handlers_runtime.lua. The runtime lifecycle still owns
-- every event entry point (PLAYER_ENTERING_WORLD, the instance-context events,
-- GROUP_ROSTER_UPDATE) and calls the three exported functions below; this
-- module only owns the run state on ctx and its capture/retry logic.
local PartyRun = {}
addonTable.EventHandlersPartyRun = PartyRun
local IsSecretValue = addonTable.Validators.IsSecretValue
local GetInstanceInfoSafe = addonTable.Validators.GetInstanceInfoSafe

-- Which party difficulties open a tracked run is not decided here: the answer
-- comes from the full-profile table in core/isiLive_runtime_mode.lua, so the
-- last-run DPS snapshot follows the same contract as every other gated feature.
-- In practice this leaves difficultyID 23 (mythic without an inserted keystone,
-- i.e. M0), because a running keystone is already handled by the challenge
-- lifecycle and returns early below. Normal, heroic and timewalking runs used
-- to be tracked here and no longer are. Fails closed without the resolver.
--
-- The "returns early below" part only holds while the keystone is running.
-- C_ChallengeMode.GetActiveChallengeMapID() goes nil the moment the key ends,
-- while the instance keeps reporting difficultyID 8 until the player leaves --
-- so without the explicit exclusion below, every finished key opened a tracked
-- M0 run inside the just-completed dungeon. Leaving the group or the instance
-- then closed that phantom run and recorded it over the key's DPS snapshot
-- with whatever (usually nothing) the damage meter still reported.
-- difficultyID 8 means an inserted keystone, which is never the M0 case.
local MYTHIC_KEYSTONE_DIFFICULTY_ID = 8
local function IsTrackedPartyDifficulty(difficultyID)
  if difficultyID == MYTHIC_KEYSTONE_DIFFICULTY_ID then
    return false
  end
  local runtimeMode = addonTable.RuntimeMode
  if type(runtimeMode) ~= "table" or type(runtimeMode.IsFullProfileDifficulty) ~= "function" then
    return false
  end
  local ok, isTracked = pcall(runtimeMode.IsFullProfileDifficulty, difficultyID)
  return ok and isTracked == true
end
local NON_CHALLENGE_RUN_CAPTURE_RETRIES = 5
local NON_CHALLENGE_RUN_CAPTURE_RETRY_DELAY_SECONDS = 1
local function ResolveTrackedMythicZeroMapID()
  local okInstance, instanceInfo = false, nil
  if type(GetInstanceInfoSafe) == "function" then
    okInstance, instanceInfo = GetInstanceInfoSafe()
  end
  local rawInstanceMapID = instanceInfo and instanceInfo.instanceMapID or nil
  local instanceMapID = okInstance and tonumber(rawInstanceMapID) or nil
  if instanceMapID and instanceMapID > 0 then
    return math.floor(instanceMapID)
  end

  local mapApi = rawget(_G, "C_Map")
  local getBestMapForUnit = mapApi and rawget(mapApi, "GetBestMapForUnit") or nil
  local unitExistsFn = rawget(_G, "UnitExists")
  if type(getBestMapForUnit) ~= "function" or type(unitExistsFn) ~= "function" then
    return nil
  end
  local okUnit, unitExists = pcall(unitExistsFn, "player")
  if not okUnit or IsSecretValue(unitExists) or unitExists ~= true then
    return nil
  end

  local okMap, mapID = pcall(getBestMapForUnit, "player")
  mapID = okMap and not IsSecretValue(mapID) and tonumber(mapID) or nil
  if not mapID or mapID <= 0 then
    return nil
  end

  return math.floor(mapID)
end

local function ClearTrackedPartyRunState(ctx)
  ctx.activeMythicZeroMapID = nil
  ctx.activeMythicZeroRosterSnapshot = nil
  ctx.pendingMythicZeroRunCapture = nil
  if type(ctx.clearTrackedPartyRunInfo) == "function" then
    ctx.clearTrackedPartyRunInfo()
  end
end

local function GetTrackedMythicZeroState(ctx)
  if ctx.isInChallengeMode() then
    return false, nil, nil, nil
  end

  if type(GetInstanceInfoSafe) ~= "function" then
    return false, nil, nil, nil
  end
  local okInstance, instanceInfo = GetInstanceInfoSafe()
  -- The helper name is historical. The tracked run is now the M0 case only:
  -- a mythic party dungeon whose keystone has not been inserted yet. A running
  -- keystone returns early above and is recorded by the challenge lifecycle.
  local instanceName = instanceInfo and instanceInfo.instanceName or nil
  local instanceType = instanceInfo and instanceInfo.instanceType or nil
  local difficultyID = instanceInfo and instanceInfo.difficultyID or nil
  if not okInstance or instanceType ~= "party" or not IsTrackedPartyDifficulty(difficultyID) then
    return false, nil, nil, nil
  end

  return true, ResolveTrackedMythicZeroMapID(), difficultyID, instanceName
end

local function CloneRosterSnapshotForStats(roster)
  if type(roster) ~= "table" then
    return {}
  end

  local snapshot = {}
  for unit, info in pairs(roster) do
    if type(info) == "table" then
      local clonedInfo = {}
      for key, value in pairs(info) do
        clonedInfo[key] = value
      end
      snapshot[unit] = clonedInfo
    end
  end

  return snapshot
end

local function HasReliableTrackedMythicZeroRoster(ctx, roster)
  if type(roster) ~= "table" then
    return false
  end

  local memberCount = 0
  for unit, info in pairs(roster) do
    if type(info) == "table" and info.isGhost ~= true then
      memberCount = memberCount + 1
      if unit ~= "player" then
        return true
      end
    end
  end

  if memberCount == 0 then
    return false
  end

  return not ctx.isInGroup()
end

local RetryTrackedMythicZeroRunCapture

local function ScheduleTrackedMythicZeroRunRetry(ctx, runInfo, retriesRemaining)
  if
    type(runInfo) ~= "table"
    or retriesRemaining <= 0
    or not ctx.timerAfter
    or ctx.pendingMythicZeroRunCapture ~= runInfo
    or runInfo.retryScheduled
  then
    return false
  end

  runInfo.retryScheduled = true
  ctx.timerAfter(NON_CHALLENGE_RUN_CAPTURE_RETRY_DELAY_SECONDS, function()
    if ctx.pendingMythicZeroRunCapture ~= runInfo then
      return
    end

    runInfo.retryScheduled = false
    if RetryTrackedMythicZeroRunCapture(ctx, runInfo, retriesRemaining - 1) then
      ctx.updateUI()
    end
  end)

  return true
end

RetryTrackedMythicZeroRunCapture = function(ctx, runInfo, retriesRemaining)
  if type(runInfo) ~= "table" or ctx.pendingMythicZeroRunCapture ~= runInfo then
    return false
  end

  local capturedNow = ctx.recordRun(runInfo.mapID, 0, nil, runInfo.rosterSnapshot) ~= false
  if capturedNow then
    ctx.pendingMythicZeroRunCapture = nil
    return true
  end

  ScheduleTrackedMythicZeroRunRetry(ctx, runInfo, retriesRemaining or NON_CHALLENGE_RUN_CAPTURE_RETRIES)
  return false
end

local function UpdateTrackedMythicZeroRun(ctx)
  local isTrackedMythicZero, currentMapID, currentDifficultyID, currentInstanceName = GetTrackedMythicZeroState(ctx)
  local previousMapID = tonumber(ctx.activeMythicZeroMapID)
  local roster = ctx.getRoster()

  if isTrackedMythicZero then
    ctx.pendingMythicZeroRunCapture = nil
    if ctx.activeMythicZeroRosterSnapshot == nil and HasReliableTrackedMythicZeroRoster(ctx, roster) then
      ctx.activeMythicZeroRosterSnapshot = CloneRosterSnapshotForStats(roster)
    end
    if not previousMapID and currentMapID then
      ctx.activeMythicZeroMapID = currentMapID
    end
    if currentMapID and currentDifficultyID then
      if type(ctx.setTrackedPartyRunInfo) == "function" then
        ctx.setTrackedPartyRunInfo({
          mapID = currentMapID,
          difficultyID = currentDifficultyID,
          instanceName = currentInstanceName,
        })
      end
    elseif type(ctx.clearTrackedPartyRunInfo) == "function" then
      ctx.clearTrackedPartyRunInfo()
    end
    return
  end

  if previousMapID then
    local rosterSnapshot = ctx.activeMythicZeroRosterSnapshot
    if rosterSnapshot == nil and type(roster) == "table" and next(roster) ~= nil then
      rosterSnapshot = CloneRosterSnapshotForStats(roster)
    end
    if rosterSnapshot ~= nil then
      local runInfo = {
        mapID = previousMapID,
        rosterSnapshot = rosterSnapshot,
        retryScheduled = false,
      }
      ctx.pendingMythicZeroRunCapture = runInfo
      RetryTrackedMythicZeroRunCapture(ctx, runInfo, NON_CHALLENGE_RUN_CAPTURE_RETRIES)
    end
  end
  ctx.activeMythicZeroMapID = nil
  ctx.activeMythicZeroRosterSnapshot = nil
  if type(ctx.clearTrackedPartyRunInfo) == "function" then
    ctx.clearTrackedPartyRunInfo()
  end
end

local function CaptureTrackedMythicZeroRosterSnapshotIfPending(ctx)
  if ctx.activeMythicZeroRosterSnapshot ~= nil or not ctx.activeMythicZeroMapID then
    return false
  end

  local isTrackedMythicZero = GetTrackedMythicZeroState(ctx)
  if not isTrackedMythicZero then
    return false
  end

  local roster = ctx.getRoster()
  if type(roster) ~= "table" or next(roster) == nil then
    return false
  end

  ctx.activeMythicZeroRosterSnapshot = CloneRosterSnapshotForStats(roster)
  return true
end

PartyRun.ClearTrackedPartyRunState = ClearTrackedPartyRunState
PartyRun.UpdateTrackedMythicZeroRun = UpdateTrackedMythicZeroRun
PartyRun.CaptureTrackedMythicZeroRosterSnapshotIfPending = CaptureTrackedMythicZeroRosterSnapshotIfPending
