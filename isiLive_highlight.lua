local _, addonTable = ...

addonTable = addonTable or {}

local Highlight = {}
addonTable.Highlight = Highlight

local function TryGet(obj, key1, key2, key3)
  if not obj then
    return nil
  end
  -- rawget(obj, nil) ist in Standard-Lua ein Fehler → Keys explizit prüfen
  local v1 = key1 ~= nil and rawget(obj, key1) or nil
  local v2 = key2 ~= nil and rawget(obj, key2) or nil
  local v3 = key3 ~= nil and rawget(obj, key3) or nil
  return v1 or v2 or v3
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

local function ResolveCurrentMapID()
  if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
    local challengeMapID = C_ChallengeMode.GetActiveChallengeMapID()
    if type(challengeMapID) == "number" and challengeMapID > 0 then
      return challengeMapID
    end
  end

  if C_Map and C_Map.GetBestMapForUnit then
    local mapID = C_Map.GetBestMapForUnit("player")
    if type(mapID) == "number" and mapID > 0 then
      return mapID
    end
  end

  return nil
end

local function ResolveMapIDFromActivityID(deps, activityID)
  local numericActivityID = tonumber(activityID)
  if not numericActivityID or numericActivityID <= 0 then
    return nil
  end

  if not deps.resolveMapIDByActivityID then
    return nil
  end

  local resolved = deps.resolveMapIDByActivityID(numericActivityID)
  local resolvedMapID = tonumber(resolved)
  if resolvedMapID and resolvedMapID > 0 then
    return resolvedMapID
  end

  return nil
end

local function CollectUniqueActivityIDs(entryInfo)
  local out = {}
  local seen = {}

  local function add(id)
    local numericID = tonumber(id)
    if not numericID or numericID <= 0 or seen[numericID] then
      return
    end
    seen[numericID] = true
    table.insert(out, numericID)
  end

  add(entryInfo.activityID)
  add(entryInfo.primaryActivityID)
  if type(entryInfo.activityIDs) == "table" then
    for _, id in pairs(entryInfo.activityIDs) do
      add(id)
    end
  end

  return out
end

local function ResolveActiveListingTarget(deps, entryInfo)
  if type(entryInfo) ~= "table" then
    return nil
  end

  local activeValue = rawget(entryInfo, "active")
  if type(activeValue) == "boolean" and activeValue == false then
    return nil
  end

  local mapID = tonumber(rawget(entryInfo, "mapID") or rawget(entryInfo, "mapId"))
  if not mapID then
    local uniqueMaps = {}
    local seenMaps = {}
    for _, activityID in ipairs(CollectUniqueActivityIDs(entryInfo)) do
      local activityMapID = ResolveMapIDFromActivityID(deps, activityID)
      if activityMapID and not seenMaps[activityMapID] then
        seenMaps[activityMapID] = true
        table.insert(uniqueMaps, activityMapID)
      end
    end

    if #uniqueMaps == 1 then
      mapID = uniqueMaps[1]
    else
      mapID = nil
    end
  end

  if not mapID then
    return nil
  end

  local spellID = deps.resolveTeleportSpellIDByMapID(mapID)
  if not spellID then
    return nil
  end

  return {
    mapID = mapID,
    spellID = spellID,
  }
end

local function ResolveActiveTeleportSpellID(deps, getActiveListingTarget, latestQueueActivityID, latestQueueMapID)
  local currentMapID = ResolveCurrentMapID()

  local activeTarget = getActiveListingTarget()
  if type(activeTarget) == "table" and activeTarget.mapID and activeTarget.spellID then
    if not currentMapID or currentMapID ~= activeTarget.mapID then
      return activeTarget.spellID
    end
    return nil
  end

  if not deps.isInGroup() then
    return nil
  end

  local queueMapID = tonumber(latestQueueMapID)
  if not queueMapID then
    queueMapID = ResolveMapIDFromActivityID(deps, latestQueueActivityID)
  end

  if not queueMapID then
    return nil
  end

  if currentMapID and currentMapID == queueMapID then
    return nil
  end

  return deps.resolveTeleportSpellIDByMapID(queueMapID)
end

function Highlight.CreateController(opts)
  opts = opts or {}

  local deps = {
    isInGroup = opts.isInGroup or function()
      return false
    end,
    resolveTeleportSpellIDByMapID = opts.resolveTeleportSpellIDByMapID or function(_mapID)
      return nil
    end,
    resolveMapIDByActivityID = opts.resolveMapIDByActivityID or function(_activityID)
      return nil
    end,
  }

  local controller = {}

  function controller.GetNormalizedActiveEntryInfo()
    return GetNormalizedActiveEntryInfo()
  end

  function controller.ResolveMapIDFromActivityID(activityID)
    return ResolveMapIDFromActivityID(deps, activityID)
  end

  function controller.ResolveActiveListingTarget(entryInfo)
    return ResolveActiveListingTarget(deps, entryInfo)
  end

  function controller.ResolveActiveListingTeleportSpellID(entryInfo)
    local target = controller.ResolveActiveListingTarget(entryInfo)
    return target and target.spellID or nil
  end

  function controller.ResolveActiveTeleportSpellID(latestQueueActivityID, latestQueueMapID)
    local function getActiveListingTarget()
      local entryInfo = controller.GetNormalizedActiveEntryInfo()
      return controller.ResolveActiveListingTarget(entryInfo)
    end

    return ResolveActiveTeleportSpellID(deps, getActiveListingTarget, latestQueueActivityID, latestQueueMapID)
  end

  function controller.ResolveJoinedKeyMapID(activityID, _spellID)
    return controller.ResolveMapIDFromActivityID(activityID)
  end

  return controller
end
