local _, addonTable = ...

addonTable = addonTable or {}

local RuntimeState = {}
addonTable.RuntimeState = RuntimeState

local function CopyTableShallow(source)
  local result = {}
  for key, value in pairs(source or {}) do
    result[key] = value
  end
  return result
end

local function NormalizeBoolean(value)
  return value and true or false
end

function RuntimeState.CreateController(opts)
  opts = opts or {}

  local state = {
    roster = type(opts.roster) == "table" and opts.roster or {},
    pendingQueueJoinInfo = opts.pendingQueueJoinInfo,
    activeJoinedKeyMapID = opts.activeJoinedKeyMapID,
    latestQueueDungeonName = opts.latestQueueDungeonName,
    latestQueueActivityID = opts.latestQueueActivityID,
    latestQueueTeleportSpellID = opts.latestQueueTeleportSpellID,
    latestQueueMapID = opts.latestQueueMapID,
    isStopped = NormalizeBoolean(opts.isStopped),
    isPaused = NormalizeBoolean(opts.isPaused),
    isTestMode = NormalizeBoolean(opts.isTestMode),
    isTestAllMode = NormalizeBoolean(opts.isTestAllMode),
    isReadyCheckActive = NormalizeBoolean(opts.isReadyCheckActive),
    readyCheckDeclinedUntilByUnit = type(opts.readyCheckDeclinedUntilByUnit) == "table" and CopyTableShallow(
      opts.readyCheckDeclinedUntilByUnit
    ) or {},
    wasGroupLeader = opts.wasGroupLeader,
    wasInGroup = NormalizeBoolean(opts.wasInGroup),
    wasRaidGroup = NormalizeBoolean(opts.wasRaidGroup),
    rioBaselineByPlayerKey = type(opts.rioBaselineByPlayerKey) == "table" and opts.rioBaselineByPlayerKey or {},
    hasRioBaselineSnapshot = NormalizeBoolean(opts.hasRioBaselineSnapshot),
    isRioDeltaDisplayEnabled = NormalizeBoolean(opts.isRioDeltaDisplayEnabled),
  }

  if next(state.rioBaselineByPlayerKey) ~= nil then
    state.hasRioBaselineSnapshot = true
  end

  local controller = {}

  function controller.GetRoster()
    return state.roster
  end

  function controller.SetRoster(value)
    state.roster = type(value) == "table" and value or {}
  end

  function controller.ForEachRosterInfo(visitor)
    if type(visitor) ~= "function" then
      return
    end
    for _, info in pairs(state.roster) do
      visitor(info)
    end
  end

  function controller.GetPendingQueueJoinInfo()
    return state.pendingQueueJoinInfo
  end

  function controller.SetPendingQueueJoinInfo(value)
    state.pendingQueueJoinInfo = value
  end

  function controller.GetActiveJoinedKeyMapID()
    return state.activeJoinedKeyMapID
  end

  function controller.SetActiveJoinedKeyMapID(value)
    state.activeJoinedKeyMapID = value
  end

  function controller.GetLatestQueueState()
    return state.latestQueueDungeonName,
      state.latestQueueActivityID,
      state.latestQueueTeleportSpellID,
      state.latestQueueMapID
  end

  function controller.SetLatestQueueState(dungeonName, activityID, teleportSpellID, mapID)
    state.latestQueueDungeonName = dungeonName
    state.latestQueueActivityID = activityID
    state.latestQueueTeleportSpellID = teleportSpellID
    state.latestQueueMapID = mapID
  end

  function controller.ClearLatestQueueTarget(optsClear)
    local clearOpts = optsClear or {}
    state.latestQueueDungeonName = nil
    state.latestQueueActivityID = nil
    state.latestQueueTeleportSpellID = nil
    state.latestQueueMapID = nil
    if clearOpts.keepActiveJoinedKey ~= true then
      state.activeJoinedKeyMapID = nil
    end
  end

  function controller.IsStopped()
    return state.isStopped
  end

  function controller.IsPaused()
    return state.isPaused
  end

  function controller.IsTestMode()
    return state.isTestMode
  end

  function controller.IsTestAllMode()
    return state.isTestAllMode
  end

  function controller.GetRuntimeFlags()
    return {
      isStopped = state.isStopped,
      isPaused = state.isPaused,
      isTestMode = state.isTestMode,
      isTestAllMode = state.isTestAllMode,
      wasGroupLeader = state.wasGroupLeader,
    }
  end

  function controller.PatchRuntimeFlags(patch)
    patch = patch or {}
    if patch.isStopped ~= nil then
      state.isStopped = NormalizeBoolean(patch.isStopped)
    end
    if patch.isPaused ~= nil then
      state.isPaused = NormalizeBoolean(patch.isPaused)
    end
    if patch.isTestMode ~= nil then
      state.isTestMode = NormalizeBoolean(patch.isTestMode)
    end
    if patch.isTestAllMode ~= nil then
      state.isTestAllMode = NormalizeBoolean(patch.isTestAllMode)
    end
    if patch.wasGroupLeader ~= nil then
      state.wasGroupLeader = patch.wasGroupLeader
    end
  end

  function controller.IsReadyCheckActive()
    return state.isReadyCheckActive
  end

  function controller.SetReadyCheckActive(value)
    state.isReadyCheckActive = NormalizeBoolean(value)
  end

  function controller.GetReadyCheckDeclinedUntil(unit)
    if type(unit) ~= "string" or unit == "" then
      return nil
    end
    return state.readyCheckDeclinedUntilByUnit[unit]
  end

  function controller.SetReadyCheckDeclinedUntil(unit, value)
    if type(unit) ~= "string" or unit == "" then
      return
    end

    local numericValue = tonumber(value)
    if numericValue and numericValue > 0 then
      state.readyCheckDeclinedUntilByUnit[unit] = numericValue
    else
      state.readyCheckDeclinedUntilByUnit[unit] = nil
    end
  end

  function controller.ClearAllReadyCheckDeclined()
    state.readyCheckDeclinedUntilByUnit = {}
  end

  function controller.ClearExpiredReadyCheckDeclined(now)
    local changed = false
    local numericNow = tonumber(now) or 0
    for unit, untilTime in pairs(state.readyCheckDeclinedUntilByUnit) do
      local numericUntil = tonumber(untilTime)
      if numericUntil == nil or numericUntil <= numericNow then
        state.readyCheckDeclinedUntilByUnit[unit] = nil
        changed = true
      end
    end
    return changed
  end

  function controller.GetWasInGroup()
    return state.wasInGroup
  end

  function controller.SetWasInGroup(value)
    state.wasInGroup = NormalizeBoolean(value)
  end

  function controller.GetWasRaidGroup()
    return state.wasRaidGroup
  end

  function controller.SetWasRaidGroup(value)
    state.wasRaidGroup = NormalizeBoolean(value)
  end

  function controller.GetWasGroupLeader()
    return state.wasGroupLeader
  end

  function controller.SetWasGroupLeader(value)
    state.wasGroupLeader = value
  end

  function controller.GetRioBaselineByPlayerKey()
    return state.rioBaselineByPlayerKey
  end

  function controller.SetRioBaselineByPlayerKey(value)
    state.rioBaselineByPlayerKey = type(value) == "table" and value or {}
    state.hasRioBaselineSnapshot = next(state.rioBaselineByPlayerKey) ~= nil
  end

  function controller.ClearRioBaseline()
    state.rioBaselineByPlayerKey = {}
    state.hasRioBaselineSnapshot = false
    state.isRioDeltaDisplayEnabled = false
  end

  function controller.HasRioBaselineSnapshot()
    return state.hasRioBaselineSnapshot
  end

  function controller.SetHasRioBaselineSnapshot(value)
    state.hasRioBaselineSnapshot = NormalizeBoolean(value)
  end

  function controller.IsRioDeltaDisplayEnabled()
    return state.isRioDeltaDisplayEnabled
  end

  function controller.SetRioDeltaDisplayEnabled(value)
    state.isRioDeltaDisplayEnabled = NormalizeBoolean(value)
  end

  function controller.GetSnapshot()
    return {
      roster = CopyTableShallow(state.roster),
      pendingQueueJoinInfo = state.pendingQueueJoinInfo,
      activeJoinedKeyMapID = state.activeJoinedKeyMapID,
      latestQueueDungeonName = state.latestQueueDungeonName,
      latestQueueActivityID = state.latestQueueActivityID,
      latestQueueTeleportSpellID = state.latestQueueTeleportSpellID,
      latestQueueMapID = state.latestQueueMapID,
      isStopped = state.isStopped,
      isPaused = state.isPaused,
      isTestMode = state.isTestMode,
      isTestAllMode = state.isTestAllMode,
      isReadyCheckActive = state.isReadyCheckActive,
      readyCheckDeclinedUntilByUnit = CopyTableShallow(state.readyCheckDeclinedUntilByUnit),
      wasGroupLeader = state.wasGroupLeader,
      wasInGroup = state.wasInGroup,
      wasRaidGroup = state.wasRaidGroup,
      rioBaselineByPlayerKey = CopyTableShallow(state.rioBaselineByPlayerKey),
      hasRioBaselineSnapshot = state.hasRioBaselineSnapshot,
      isRioDeltaDisplayEnabled = state.isRioDeltaDisplayEnabled,
    }
  end

  return controller
end
