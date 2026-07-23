local _, addonTable = ...

addonTable = addonTable or {}

local Highlight = {}
addonTable.Highlight = Highlight
local IsSecretValue = addonTable.Validators.IsSecretValue

local function TryGet(obj, key1, key2, key3)
  if not obj then
    return nil
  end
  -- rawget(obj, nil) is an error in standard Lua → check keys explicitly.
  -- Return the value directly (nil check instead of truthiness) so that
  -- false is correctly propagated (e.g. active=false on an inactive entry).
  if key1 ~= nil then
    local v = rawget(obj, key1)
    if v ~= nil then
      return v
    end
  end
  if key2 ~= nil then
    local v = rawget(obj, key2)
    if v ~= nil then
      return v
    end
  end
  if key3 ~= nil then
    local v = rawget(obj, key3)
    if v ~= nil then
      return v
    end
  end
  return nil
end

local function GetNormalizedActiveEntryInfo()
  local lfgListApi = rawget(_G, "C_LFGList")
  if type(lfgListApi) ~= "table" or type(lfgListApi.GetActiveEntryInfo) ~= "function" then
    return nil
  end

  local ok, r1, r2, _, _, r5, r6, r7 = pcall(lfgListApi.GetActiveEntryInfo)
  if not ok then
    return nil
  end

  if type(r1) == "table" then
    local activityID = tonumber(TryGet(r1, "activityID", "activity", nil))

    if not activityID then
      local activityIDsTable = TryGet(r1, "activityIDs", "activities", nil)
      if type(activityIDsTable) == "table" then
        local sortedIDs = {}
        for _, id in pairs(activityIDsTable) do
          local numID = tonumber(id)
          if numID and numID > 0 then
            sortedIDs[#sortedIDs + 1] = numID
          end
        end
        table.sort(sortedIDs)
        if sortedIDs[1] then
          activityID = sortedIDs[1]
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

    local tupleName
    for _, nameCandidate in ipairs({ r5, r6, r7 }) do
      if type(nameCandidate) == "string" and nameCandidate ~= "" then
        tupleName = nameCandidate
        break
      end
    end

    if tupleName then
      entry.name = tupleName
    end
  end

  return entry
end

local function IsExistingPlayerUnit()
  local unitExists = rawget(_G, "UnitExists")
  if type(unitExists) ~= "function" then
    return false
  end

  local ok, exists = pcall(unitExists, "player")
  return ok and not IsSecretValue(exists) and exists == true
end

local function ResolveCurrentMapID()
  -- Only the live player map should suppress the highlight. The active
  -- challenge map can become available before the player actually enters the
  -- dungeon, which would otherwise clear the highlight too early.
  local mapApi = rawget(_G, "C_Map")
  local getBestMapForUnit = type(mapApi) == "table" and rawget(mapApi, "GetBestMapForUnit") or nil
  if IsExistingPlayerUnit() and type(getBestMapForUnit) == "function" then
    local ok, mapID = pcall(getBestMapForUnit, "player")
    if ok and not IsSecretValue(mapID) and type(mapID) == "number" and mapID > 0 then
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
      if not activityMapID then
        return nil
      end
      if not seenMaps[activityMapID] then
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
  local logf = deps.logRuntimeTracef
  local currentMapID = ResolveCurrentMapID()
  if logf then
    logf(
      "[HIGHLIGHT] resolve_spell_id currentMapID=%s queueActivityID=%s queueMapID=%s",
      tostring(currentMapID),
      tostring(latestQueueActivityID),
      tostring(latestQueueMapID)
    )
  end

  local activeTarget = getActiveListingTarget()
  if type(activeTarget) == "table" and activeTarget.mapID and activeTarget.spellID then
    if not currentMapID or currentMapID ~= activeTarget.mapID then
      if logf then
        logf(
          "[HIGHLIGHT] spell_from_active_target mapID=%s spellID=%s",
          tostring(activeTarget.mapID),
          tostring(activeTarget.spellID)
        )
      end
      return activeTarget.spellID
    end
    if logf then
      logf(
        "[HIGHLIGHT] blocked_already_in_dungeon currentMapID=%s targetMapID=%s",
        tostring(currentMapID),
        tostring(activeTarget.mapID)
      )
    end
    return nil
  end

  if not deps.isInGroup() then
    if logf then
      logf("[HIGHLIGHT] blocked_not_in_group")
    end
    return nil
  end

  local queueMapID = tonumber(latestQueueMapID)
  if not queueMapID then
    queueMapID = ResolveMapIDFromActivityID(deps, latestQueueActivityID)
    if logf then
      logf(
        "[HIGHLIGHT] queue_map_from_activity activityID=%s resolved=%s",
        tostring(latestQueueActivityID),
        tostring(queueMapID)
      )
    end
  end

  if not queueMapID then
    if logf then
      logf("[HIGHLIGHT] blocked_no_queue_map")
    end
    return nil
  end

  if currentMapID and currentMapID == queueMapID then
    if logf then
      logf(
        "[HIGHLIGHT] blocked_already_in_dungeon currentMapID=%s queueMapID=%s",
        tostring(currentMapID),
        tostring(queueMapID)
      )
    end
    return nil
  end

  local spellID = deps.resolveTeleportSpellIDByMapID(queueMapID)
  if logf then
    logf("[HIGHLIGHT] spell_from_queue mapID=%s spellID=%s", tostring(queueMapID), tostring(spellID))
  end
  return spellID
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
    logRuntimeTracef = type(opts.logRuntimeTracef) == "function" and opts.logRuntimeTracef or nil,
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
