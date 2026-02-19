local _, addonTable = ...

addonTable = addonTable or {}

local Highlight = {}
addonTable.Highlight = Highlight

local function TryGet(obj, key1, key2, key3)
  if not obj then
    return nil
  end
  return rawget(obj, key1) or rawget(obj, key2) or rawget(obj, key3)
end

local function GetNormalizedActiveEntryInfo()
  if not (C_LFGList and C_LFGList.GetActiveEntryInfo) then
    return nil
  end

  local ok, r1, r2, _, _, r5, r6, r7 = pcall(C_LFGList.GetActiveEntryInfo)
  if not ok then
    return nil
  end

  if type(r1) == "table" then
    local activityID = tonumber(TryGet(r1, "activityID", "activity", nil))

    if not activityID then
      local activityIDsTable = TryGet(r1, "activityIDs", "activities", nil)
      if type(activityIDsTable) == "table" then
        for _, id in pairs(activityIDsTable) do
          local numID = tonumber(id)
          if numID and numID > 0 then
            activityID = numID
            break
          end
        end
      end
    end

    return {
      active = TryGet(r1, "active", "isActive", nil),
      activityID = activityID,
      primaryActivityID = tonumber(TryGet(r1, "primaryActivityID", "primaryActivity", nil)),
      mapID = tonumber(TryGet(r1, "mapID", "mapId", nil)),
      activityIDs = TryGet(r1, "activityIDs", "activities", nil),
      name = type(TryGet(r1, "name", "listingName", nil)) == "string" and TryGet(r1, "name", "listingName", nil) or nil,
      activityName = type(TryGet(r1, "activityName", nil, nil)) == "string" and TryGet(r1, "activityName", nil, nil)
        or nil,
      title = type(TryGet(r1, "title", "groupTitle", nil)) == "string" and TryGet(r1, "title", "groupTitle", nil)
        or nil,
    }
  end

  local entry = {}
  if type(r1) == "boolean" then
    entry.active = r1
    if type(r2) == "number" and r2 > 0 then
      entry.activityID = r2
    end

    local tupleName = nil
    if type(r5) == "string" and r5 ~= "" then
      tupleName = r5
    elseif type(r6) == "string" and r6 ~= "" then
      tupleName = r6
    elseif type(r7) == "string" and r7 ~= "" then
      tupleName = r7
    end

    if tupleName then
      entry.name = tupleName
    end
  end

  return entry
end

local function ResolveActiveListingTeleportSpellID(
  resolveSeason3TeleportSpellID,
  resolveSeason3TeleportSpellIDByMapID,
  entryInfo
)
  if type(entryInfo) ~= "table" then
    return nil
  end

  local activeValue = rawget(entryInfo, "active")
  local activeStateIsKnown = type(activeValue) == "boolean"
  local hasActiveListing = (not activeStateIsKnown) or activeValue == true
  if not hasActiveListing then
    return nil
  end

  if entryInfo.mapID then
    local mapSpellID = resolveSeason3TeleportSpellIDByMapID(entryInfo.mapID)
    if mapSpellID then
      return mapSpellID
    end
  end

  local candidates = {}
  local seen = {}
  local function addCandidate(id)
    local numericID = tonumber(id)
    if not numericID or numericID <= 0 or seen[numericID] then
      return
    end
    seen[numericID] = true
    table.insert(candidates, numericID)
  end

  addCandidate(entryInfo.activityID)
  addCandidate(entryInfo.primaryActivityID)
  if type(entryInfo.activityIDs) == "table" then
    for _, id in pairs(entryInfo.activityIDs) do
      addCandidate(id)
    end
  end

  for _, hostedActivityID in ipairs(candidates) do
    local hostedSpellID = resolveSeason3TeleportSpellID(hostedActivityID, nil)
    if hostedSpellID then
      return hostedSpellID
    end
  end

  local nameCandidates = { entryInfo.activityName, entryInfo.name, entryInfo.title }
  for _, listingName in ipairs(nameCandidates) do
    if type(listingName) == "string" and listingName ~= "" then
      local hostedSpellID = resolveSeason3TeleportSpellID(nil, listingName)
      if hostedSpellID then
        return hostedSpellID
      end
    end
  end

  return nil
end

local function BuildCurrentDungeonContext(resolveSeason3MapIDsBySpellID, resolveSeason3TeleportSpellIDByMapID)
  local currentMapID = nil
  local currentMapResolved = false
  local currentMapTeleportSpellID = nil
  local currentMapSpellResolved = false

  local function ResolveCurrentMapID()
    if not currentMapResolved then
      currentMapResolved = true
      if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
        local challengeMapID = C_ChallengeMode.GetActiveChallengeMapID()
        if type(challengeMapID) == "number" and challengeMapID > 0 then
          currentMapID = challengeMapID
        end
      end
      if not currentMapID and C_Map and C_Map.GetBestMapForUnit then
        local mapID = C_Map.GetBestMapForUnit("player")
        if type(mapID) == "number" and mapID > 0 then
          currentMapID = mapID
        end
      end
    end
    return currentMapID
  end

  local function IsCurrentDungeonSpell(spellID)
    if not spellID then
      return false
    end

    local mapID = ResolveCurrentMapID()

    if mapID then
      local targetMapIDs = resolveSeason3MapIDsBySpellID(spellID)
      if type(targetMapIDs) == "table" then
        for _, targetMapID in ipairs(targetMapIDs) do
          if targetMapID and targetMapID == mapID then
            return true
          end
        end
      end
    end

    if not currentMapSpellResolved then
      currentMapSpellResolved = true
      if mapID then
        currentMapTeleportSpellID = resolveSeason3TeleportSpellIDByMapID(mapID)
      end
    end

    return currentMapTeleportSpellID and currentMapTeleportSpellID == spellID
  end

  return {
    GetCurrentMapID = ResolveCurrentMapID,
    IsCurrentDungeonSpell = IsCurrentDungeonSpell,
  }
end

local function ResolveMapIDFromActivityID(activityID)
  if not activityID or not (C_LFGList and C_LFGList.GetActivityInfoTable) then
    return nil
  end

  local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
  if not ok or type(info) ~= "table" then
    return nil
  end

  local mapID = tonumber(rawget(info, "mapID") or rawget(info, "mapId"))
  if mapID and mapID > 0 then
    return mapID
  end

  return nil
end

local function ResolveActiveTeleportSpellID(
  deps,
  getActiveListingTarget,
  latestQueueActivityID,
  latestQueueDungeonName,
  latestQueueTeleportSpellID
)
  local dungeonContext =
    BuildCurrentDungeonContext(deps.resolveSeason3MapIDsBySpellID, deps.resolveSeason3TeleportSpellIDByMapID)
  local currentMapID = dungeonContext.GetCurrentMapID()

  local activeTarget = getActiveListingTarget()
  if type(activeTarget) == "table" and activeTarget.spellID then
    local activeTargetMapID = tonumber(activeTarget.mapID)
    if activeTargetMapID and currentMapID then
      if currentMapID ~= activeTargetMapID then
        return activeTarget.spellID
      end
    elseif not dungeonContext.IsCurrentDungeonSpell(activeTarget.spellID) then
      return activeTarget.spellID
    end
  end

  if not deps.isInGroup() then
    return nil
  end

  local queueTargetMapID = ResolveMapIDFromActivityID(latestQueueActivityID)
  local queueSpellID = deps.resolveSeason3TeleportSpellID(latestQueueActivityID, latestQueueDungeonName)
  if queueTargetMapID then
    if currentMapID and currentMapID == queueTargetMapID then
      return nil
    end
    return latestQueueTeleportSpellID or queueSpellID
  end

  if latestQueueTeleportSpellID and not dungeonContext.IsCurrentDungeonSpell(latestQueueTeleportSpellID) then
    return latestQueueTeleportSpellID
  end

  if queueSpellID and not dungeonContext.IsCurrentDungeonSpell(queueSpellID) then
    return queueSpellID
  end

  return nil
end

function Highlight.CreateController(opts)
  opts = opts or {}
  local resolveSeason3MapIDBySpellID = opts.resolveSeason3MapIDBySpellID or function(_spellID)
    return nil
  end
  local deps = {
    isInGroup = opts.isInGroup or function()
      return false
    end,
    resolveSeason3TeleportSpellID = opts.resolveSeason3TeleportSpellID or function(_activityID, _dungeonName)
      return nil
    end,
    resolveSeason3TeleportSpellIDByMapID = opts.resolveSeason3TeleportSpellIDByMapID or function(_mapID)
      return nil
    end,
    resolveSeason3MapIDBySpellID = resolveSeason3MapIDBySpellID,
    resolveSeason3MapIDsBySpellID = opts.resolveSeason3MapIDsBySpellID or function(spellID)
      local mapID = resolveSeason3MapIDBySpellID(spellID)
      if mapID then
        return { mapID }
      end
      return nil
    end,
  }

  local controller = {}

  function controller.GetNormalizedActiveEntryInfo()
    return GetNormalizedActiveEntryInfo()
  end

  function controller.ResolveActiveListingTeleportSpellID(entryInfo)
    return ResolveActiveListingTeleportSpellID(
      deps.resolveSeason3TeleportSpellID,
      deps.resolveSeason3TeleportSpellIDByMapID,
      entryInfo
    )
  end

  function controller.ResolveActiveTeleportSpellID(
    latestQueueActivityID,
    latestQueueDungeonName,
    latestQueueTeleportSpellID
  )
    local function getActiveListingTarget()
      local entryInfo = controller.GetNormalizedActiveEntryInfo()
      local spellID = controller.ResolveActiveListingTeleportSpellID(entryInfo)
      if not spellID then
        return nil
      end

      local mapID = nil
      if type(entryInfo) == "table" then
        mapID = tonumber(rawget(entryInfo, "mapID") or rawget(entryInfo, "mapId"))
        if not mapID then
          mapID = controller.ResolveMapIDFromActivityID(entryInfo.activityID)
        end
      end

      return {
        spellID = spellID,
        mapID = mapID,
      }
    end

    return ResolveActiveTeleportSpellID(
      deps,
      getActiveListingTarget,
      latestQueueActivityID,
      latestQueueDungeonName,
      latestQueueTeleportSpellID
    )
  end

  function controller.ResolveMapIDFromActivityID(activityID)
    return ResolveMapIDFromActivityID(activityID)
  end

  function controller.ResolveJoinedKeyMapID(activityID, spellID)
    local mapID = controller.ResolveMapIDFromActivityID(activityID)
    if mapID then
      return mapID
    end
    local mappedMapIDs = deps.resolveSeason3MapIDsBySpellID(spellID)
    if type(mappedMapIDs) == "table" then
      if #mappedMapIDs == 1 then
        return mappedMapIDs[1]
      end
      return nil
    end
    return deps.resolveSeason3MapIDBySpellID(spellID)
  end

  return controller
end
