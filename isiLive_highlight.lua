local _, addonTable = ...

addonTable = addonTable or {}

local Highlight = {}
addonTable.Highlight = Highlight

function Highlight.CreateController(opts)
  opts = opts or {}
  local isInGroup = opts.isInGroup or function()
    return false
  end
  local resolveSeason3TeleportSpellID = opts.resolveSeason3TeleportSpellID
    or function(_activityID, _dungeonName)
      return nil
    end
  local resolveSeason3TeleportSpellIDByMapID = opts.resolveSeason3TeleportSpellIDByMapID
    or function(_mapID)
      return nil
    end
  local resolveSeason3MapIDBySpellID = opts.resolveSeason3MapIDBySpellID or function(_spellID)
    return nil
  end

  local controller = {}

  function controller.GetNormalizedActiveEntryInfo()
    if not (C_LFGList and C_LFGList.GetActiveEntryInfo) then
      return nil
    end

    local ok, r1, r2, _, _, r5, r6, r7 = pcall(C_LFGList.GetActiveEntryInfo)
    if not ok then
      return nil
    end

    if type(r1) == "table" then
      local function TryGet(obj, key1, key2, key3)
        if obj then
          return rawget(obj, key1) or rawget(obj, key2) or rawget(obj, key3)
        end
        return nil
      end

      -- Versuche activityID zu extrahieren
      local activityID = tonumber(TryGet(r1, "activityID", "activity", nil))

      -- Fallback: Wenn activityIDs (Plural) existiert, nimm den ersten Wert
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

      local entry = {
        active = TryGet(r1, "active", "isActive", nil),
        activityID = activityID,
        primaryActivityID = tonumber(TryGet(r1, "primaryActivityID", "primaryActivity", nil)),
        activityIDs = TryGet(r1, "activityIDs", "activities", nil),
        name = type(TryGet(r1, "name", "listingName", nil)) == "string" and TryGet(r1, "name", "listingName", nil)
          or nil,
        activityName = type(TryGet(r1, "activityName", nil, nil)) == "string" and TryGet(r1, "activityName", nil, nil)
          or nil,
        title = type(TryGet(r1, "title", "groupTitle", nil)) == "string" and TryGet(r1, "title", "groupTitle", nil)
          or nil,
      }

      return entry
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

  function controller.ResolveActiveListingTeleportSpellID(entryInfo)
    if type(entryInfo) ~= "table" then
      return nil
    end

    local activeValue = rawget(entryInfo, "active")
    local activeStateIsKnown = type(activeValue) == "boolean"
    local hasActiveListing = (not activeStateIsKnown) or activeValue == true
    if not hasActiveListing then
      return nil
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

    -- If the active listing cannot be resolved (common around full-group transitions),
    -- allow fallback to known queue/join target instead of dropping highlight abruptly.
    return nil
  end

  function controller.ResolveActiveTeleportSpellID(
    latestQueueActivityID,
    latestQueueDungeonName,
    latestQueueTeleportSpellID
  )
    -- Business rule: highlight only while grouped (joined group or self-hosted in group).
    if not isInGroup() then
      return nil
    end

    local entryInfo = controller.GetNormalizedActiveEntryInfo()
    local activeListingSpellID = controller.ResolveActiveListingTeleportSpellID(entryInfo)
    if activeListingSpellID then
      return activeListingSpellID
    end

    if latestQueueTeleportSpellID then
      return latestQueueTeleportSpellID
    end

    local queueSpellID = resolveSeason3TeleportSpellID(latestQueueActivityID, latestQueueDungeonName)
    if queueSpellID then
      return queueSpellID
    end

    -- Fallback: Try to get current active challenge map (for joined keys)
    if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
      local currentMapID = C_ChallengeMode.GetActiveChallengeMapID()
      if currentMapID then
        local spellID = resolveSeason3TeleportSpellIDByMapID(currentMapID)
        if spellID then
          return spellID
        end
      end
    end

    return nil
  end

  function controller.ResolveMapIDFromActivityID(activityID)
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

  function controller.ResolveJoinedKeyMapID(activityID, spellID)
    local mapID = controller.ResolveMapIDFromActivityID(activityID)
    if mapID then
      return mapID
    end
    return resolveSeason3MapIDBySpellID(spellID)
  end

  return controller
end
