local _, addonTable = ...

addonTable = addonTable or {}

local Resolver = {}
addonTable.LFGEntryResolver = Resolver

-- Runtime cache for Blizzard-resolved activity IDs that are not present in the
-- active season manifest. Verified static mappings remain owned by SeasonData.
local ACTIVITY_TO_MAP = {}

function Resolver.MapIDFromActivityID(activityID)
  if not activityID then
    return nil
  end
  local numID = tonumber(activityID)
  if not numID or numID <= 0 then
    return nil
  end

  local seasonData = addonTable.SeasonData
  if type(seasonData) == "table" and type(seasonData.GetMapIDByActivityID) == "function" then
    local mapID = seasonData.GetMapIDByActivityID(numID)
    if mapID then
      return mapID
    end
  end
  if ACTIVITY_TO_MAP[numID] then
    return ACTIVITY_TO_MAP[numID]
  end

  local lfgList = rawget(_G, "C_LFGList")
  if type(lfgList) == "table" and type(lfgList.GetActivityInfoTable) == "function" then
    local ok, info = pcall(lfgList.GetActivityInfoTable, numID)
    if ok and type(info) == "table" and rawget(info, "isMythicPlusActivity") == true then
      local mapID = tonumber(rawget(info, "mapID") or rawget(info, "mapId"))
      if mapID and mapID > 0 then
        ACTIVITY_TO_MAP[numID] = mapID
        return mapID
      end
    end
  end

  return nil
end

local function MapIDFromRaidActivityID(activityID)
  local numID = tonumber(activityID)
  if not numID or numID <= 0 then
    return nil
  end
  local lfgList = rawget(_G, "C_LFGList")
  if type(lfgList) ~= "table" or type(lfgList.GetActivityInfoTable) ~= "function" then
    return nil
  end
  local ok, info = pcall(lfgList.GetActivityInfoTable, numID)
  if not ok or type(info) ~= "table" then
    return nil
  end
  if rawget(info, "isMythicPlusActivity") == true then
    return nil
  end
  if tonumber(rawget(info, "categoryID")) ~= 3 then
    return nil
  end
  local mapID = tonumber(rawget(info, "mapID") or rawget(info, "mapId"))
  if mapID and mapID > 0 then
    return mapID
  end
  return nil
end

function Resolver.MapIDFromActivityIDs(activityIDs)
  if type(activityIDs) ~= "table" then
    return nil
  end

  local resolvedMapID = nil
  for _, actID in pairs(activityIDs) do
    local numericActivityID = tonumber(actID)
    if numericActivityID and numericActivityID > 0 then
      local mapID = Resolver.MapIDFromActivityID(numericActivityID)
      if not mapID then
        return nil
      end
      if resolvedMapID and resolvedMapID ~= mapID then
        return nil
      end
      resolvedMapID = mapID
    end
  end
  return resolvedMapID
end

function Resolver.ParseTitleKeyLevel(title)
  if type(title) ~= "string" or title == "" then
    return nil
  end
  local best = nil
  for digits in string.gmatch(title, "%+[^%a%d]-(%d+)") do
    local level = tonumber(digits)
    if level and level >= 1 and level <= 40 and (not best or level > best) then
      best = level
    end
  end
  if best then
    return best
  end
  for digits in string.gmatch(title, "(%d+)[^%a%d]-%+") do
    local level = tonumber(digits)
    if level and level >= 1 and level <= 40 and (not best or level > best) then
      best = level
    end
  end
  return best
end

function Resolver.ResolveInviteEntry(searchResultID, log)
  local lfgList = rawget(_G, "C_LFGList")
  if type(lfgList) ~= "table" then
    return nil
  end

  local info = nil
  if type(searchResultID) == "number" and searchResultID > 0 then
    local ok, result = pcall(lfgList.GetSearchResultInfo, searchResultID)
    if ok then
      info = result
    end
  end

  local mapID = nil
  if type(info) == "table" and type(info.activityIDs) == "table" and next(info.activityIDs) ~= nil then
    mapID = Resolver.MapIDFromActivityIDs(info.activityIDs)
  elseif type(info) == "table" and info.activityID then
    mapID = Resolver.MapIDFromActivityID(info.activityID)
  end

  if type(log) == "function" then
    log(
      "invite_received",
      "searchResultID=%s activityID=%s mapID=%s",
      tostring(searchResultID),
      tostring(info and info.activityID),
      tostring(mapID)
    )
  end
  if not mapID then
    return nil
  end

  local leaderName = nil
  if type(info) == "table" and type(info.leaderName) == "string" and info.leaderName ~= "" then
    leaderName = info.leaderName
  end
  local titleLevel = nil
  local groupName = nil
  local primaryActivityID = nil
  local comment = nil
  if type(info) == "table" then
    titleLevel = Resolver.ParseTitleKeyLevel(info.name)
    if type(info.name) == "string" and info.name ~= "" then
      groupName = info.name
    end
    if type(info.comment) == "string" and info.comment ~= "" then
      comment = info.comment
    end
    if type(info.activityIDs) == "table" then
      for _, actID in ipairs(info.activityIDs) do
        local numericActID = tonumber(actID)
        if numericActID and numericActID > 0 then
          primaryActivityID = numericActID
          break
        end
      end
    end
    if not primaryActivityID and info.activityID then
      local numericActID = tonumber(info.activityID)
      if numericActID and numericActID > 0 then
        primaryActivityID = numericActID
      end
    end
  end

  return {
    mapID = mapID,
    leaderName = leaderName,
    titleLevel = titleLevel,
    groupName = groupName,
    activityID = primaryActivityID,
    comment = comment,
  }
end

local function MergeAcceptedInviteEntry(cachedEntry, freshEntry)
  if type(freshEntry) ~= "table" then
    return cachedEntry
  end
  if type(cachedEntry) ~= "table" then
    return freshEntry
  end

  local merged = {}
  for key, value in pairs(cachedEntry) do
    merged[key] = value
  end
  for _, key in ipairs({ "mapID", "leaderName", "titleLevel", "groupName", "activityID", "comment" }) do
    if freshEntry[key] ~= nil then
      merged[key] = freshEntry[key]
    end
  end
  return merged
end

function Resolver.RefreshInviteEntryOnAccept(searchResultID, cachedEntry, log)
  local freshEntry = Resolver.ResolveInviteEntry(searchResultID, log)
  if type(freshEntry) == "table" then
    return MergeAcceptedInviteEntry(cachedEntry, freshEntry)
  end
  return cachedEntry
end

function Resolver.ResolveRaidInviteEntry(searchResultID)
  local lfgList = rawget(_G, "C_LFGList")
  if type(lfgList) ~= "table" or type(lfgList.GetSearchResultInfo) ~= "function" then
    return nil
  end
  if type(searchResultID) ~= "number" or searchResultID <= 0 then
    return nil
  end
  local ok, info = pcall(lfgList.GetSearchResultInfo, searchResultID)
  if not ok or type(info) ~= "table" then
    return nil
  end
  local mapID = nil
  if type(info.activityIDs) == "table" then
    for _, actID in ipairs(info.activityIDs) do
      local numericActID = tonumber(actID)
      if numericActID and numericActID > 0 then
        local resolved = MapIDFromRaidActivityID(numericActID)
        if resolved then
          mapID = resolved
          break
        end
      end
    end
  end
  if not mapID and info.activityID then
    mapID = MapIDFromRaidActivityID(info.activityID)
  end
  if not mapID then
    return nil
  end
  local leaderName = type(info.leaderName) == "string" and info.leaderName ~= "" and info.leaderName or nil
  local groupName = type(info.name) == "string" and info.name ~= "" and info.name or nil
  local comment = type(info.comment) == "string" and info.comment ~= "" and info.comment or nil
  return {
    mapID = mapID,
    leaderName = leaderName,
    groupName = groupName,
    comment = comment,
  }
end

function Resolver.ResolveEntryTitleLevel(entry, log)
  if type(entry) ~= "table" then
    return nil
  end
  local level = tonumber(entry.titleLevel)
  if level and level > 0 then
    return math.floor(level)
  end
  if type(entry.groupName) == "string" and entry.groupName ~= "" then
    local parsed = Resolver.ParseTitleKeyLevel(entry.groupName)
    if parsed and parsed > 0 then
      if type(log) == "function" then
        log(
          "title_level_fallback",
          "groupName=%q stored_titleLevel=%s parsed=%d",
          tostring(entry.groupName),
          tostring(entry.titleLevel),
          parsed
        )
      end
      return parsed
    end
  end
  return nil
end

function Resolver.ResolveEntryTitleLevelText(entry)
  if type(entry) ~= "table" then
    return nil
  end
  local groupName = entry.groupName
  if type(groupName) ~= "string" or groupName == "" then
    return nil
  end
  if string.match(groupName, "^|Kk%d+|k$") then
    return groupName
  end
  return nil
end
