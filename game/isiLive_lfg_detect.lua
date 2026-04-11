local _, addonTable = ...

addonTable = addonTable or {}

-- ---------------------------------------------------------------------------
-- LFG Dungeon Detection
-- Detects which dungeon the player received an invite for, or which dungeon
-- they queued for via their own active LFG listing.
-- Outputs a chat message with the detected dungeon name.
-- ---------------------------------------------------------------------------

local LFGDetect = {}
addonTable.LFGDetect = LFGDetect

-- Static map: LFG activity ID -> challenge map ID (our mapID convention).
-- Activity IDs are the numeric identifiers Blizzard assigns to LFG activities.
local ACTIVITY_TO_MAP = {
  [1542] = 557, -- Windrunner Spire
  [182] = 161, -- Skyreach
  [486] = 239, -- Seat of the Triumvirate
  [1770] = 556, -- Pit of Saron
  [1768] = 559, -- Nexus-Point Xenas
  [1764] = 560, -- Maisara Caverns
  [1760] = 558, -- Magisters' Terrace
  [1160] = 402, -- Algeth'ar Academy
}

-- Normalise a string for keyword matching: lowercase, collapse whitespace.
-- We do NOT strip non-ASCII characters — Blizzard names contain umlauts and
-- typographic apostrophes which must survive for matching.
local function Norm(s)
  local ok, result = pcall(function()
    s = (s or ""):lower()
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s", ""):gsub("%s$", "")
    return s
  end)
  return ok and result or ""
end

-- Keyword triggers per mapID — fallback when activity ID lookup fails.
-- Use short ASCII substrings that appear in both enUS and deDE names,
-- plus locale-specific variants where needed.
local MAP_TRIGGERS = {
  [557] = { "windrunner", "spire", "windl" }, -- "Windrunner Spire" / "Windläuferturm"
  [558] = { "magister", "terrace" }, -- "Magisters' Terrace" / "Terrasse der Magister"
  [559] = { "nexus", "xenas" }, -- "Nexus-Point Xenas" / "Nexuspunkt Xenas"
  [560] = { "maisara", "caverns", "kavernen" }, -- "Maisara Caverns" / "Maisarakavernen"
  [402] = { "algethar", "algeth", "academy", "akademie" }, -- "Algeth'ar Academy" / "Akademie von Algeth'ar"
  [556] = { "saron", "pit" }, -- "Pit of Saron" / "Grube von Saron"
  [239] = { "triumvirate", "triumvirats" }, -- "Seat of the Triumvirate" / "Sitz des Triumvirats"
  [161] = { "skyreach", "himmelsnadel" }, -- "Skyreach" / "Die Himmelsnadel"
}

local function MatchMapIDFromName(name)
  local n = Norm(name)
  if n == "" then
    return nil
  end
  for mapID, triggers in pairs(MAP_TRIGGERS) do
    for _, trig in ipairs(triggers) do
      if n:find(trig, 1, true) then
        return mapID
      end
    end
  end
  return nil
end

-- Resolve mapID from a single activityID: static map first, then API name fallback.
local function MapIDFromActivityID(activityID)
  if not activityID then
    return nil
  end
  local numID = tonumber(activityID)
  if not numID or numID <= 0 then
    return nil
  end

  -- 1. Static map (fast path)
  if ACTIVITY_TO_MAP[numID] then
    return ACTIVITY_TO_MAP[numID]
  end

  -- 2. API name fallback
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" then
    return nil
  end

  local fullName = nil
  if type(C_LFGList_ref.GetActivityFullName) == "function" then
    local ok, result = pcall(C_LFGList_ref.GetActivityFullName, numID)
    if ok then
      fullName = result
    end
  end
  if not fullName or fullName == "" then
    if type(C_LFGList_ref.GetActivityInfoTable) == "function" then
      local ok, info = pcall(C_LFGList_ref.GetActivityInfoTable, numID)
      if ok and type(info) == "table" then
        fullName = info.fullName or info.shortName
      end
    end
  end

  if type(fullName) == "string" and fullName ~= "" then
    return MatchMapIDFromName(fullName)
  end

  return nil
end

-- Resolve mapID from a table of activityIDs.
local function MapIDFromActivityIDs(activityIDs)
  if type(activityIDs) ~= "table" then
    return nil
  end
  for _, actID in pairs(activityIDs) do
    local mapID = MapIDFromActivityID(actID)
    if mapID then
      return mapID
    end
  end
  return nil
end

local function GetDungeonName(mapID)
  local SeasonData = addonTable.SeasonData
  if type(SeasonData) == "table" and type(SeasonData.GetDungeonName) == "function" then
    local name = SeasonData.GetDungeonName(mapID)
    if type(name) == "string" and name ~= "" then
      return name
    end
  end
  return tostring(mapID)
end

local function Print(msg)
  local frame = rawget(_G, "DEFAULT_CHAT_FRAME")
  if type(frame) == "table" and type(frame.AddMessage) == "function" then
    frame:AddMessage("|cff9be28f[isiLive]|r " .. tostring(msg))
  end
end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

-- [searchResultID] = mapID  — pending invites not yet accepted
local pendingInvites = {}
-- mapID of the last detected own queue listing (nil = no active listing)
local lastQueueMapID = nil

-- ---------------------------------------------------------------------------
-- Invite detection
-- ---------------------------------------------------------------------------

local function OnInvited(searchResultID)
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" then
    return
  end

  local info = nil
  if type(searchResultID) == "number" and searchResultID > 0 then
    local ok, result = pcall(C_LFGList_ref.GetSearchResultInfo, searchResultID)
    if ok then
      info = result
    end
  end

  local mapID = nil

  -- Try activityIDs table first (most reliable)
  if type(info) == "table" and type(info.activityIDs) == "table" then
    mapID = MapIDFromActivityIDs(info.activityIDs)
  end

  -- Try single activityID
  if not mapID and type(info) == "table" and info.activityID then
    mapID = MapIDFromActivityID(info.activityID)
  end

  -- Name fallback
  if not mapID and type(info) == "table" then
    local listName = info.name or ""
    if listName == "" then
      listName = (info.comment or "") .. " " .. (info.voiceChat or "")
    end
    mapID = MatchMapIDFromName(listName)
  end

  if mapID then
    pendingInvites[searchResultID] = mapID
  end
end

local function OnInviteAccepted(searchResultID)
  local mapID = pendingInvites[searchResultID]
  if mapID then
    Print("Invite erkannt: " .. GetDungeonName(mapID))
    pendingInvites = {}
  end
end

local function OnInviteDeclined(searchResultID)
  pendingInvites[searchResultID] = nil
end

local NEGATIVE_STATUSES = {
  declined = true,
  declined_full = true,
  declined_delisted = true,
  cancelled = true,
  failed = true,
  timedout = true,
  invitedeclined = true,
}

local function HandleApplicationStatus(searchResultID, newStatus)
  if newStatus == "invited" then
    OnInvited(searchResultID)
  elseif newStatus == "inviteaccepted" then
    OnInviteAccepted(searchResultID)
  elseif NEGATIVE_STATUSES[newStatus] then
    OnInviteDeclined(searchResultID)
  end
end

-- ---------------------------------------------------------------------------
-- Own queue detection (active listing + 5s poll)
-- ---------------------------------------------------------------------------

local function CheckActiveGroup()
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" or type(C_LFGList_ref.GetActiveEntryInfo) ~= "function" then
    return
  end

  local ok, info = pcall(C_LFGList_ref.GetActiveEntryInfo)
  if not ok or not info then
    -- No active listing
    if lastQueueMapID ~= nil then
      lastQueueMapID = nil
    end
    return
  end

  local mapID = nil

  if type(info.activityIDs) == "table" then
    mapID = MapIDFromActivityIDs(info.activityIDs)
  end
  if not mapID and info.activityID then
    mapID = MapIDFromActivityID(info.activityID)
  end
  if not mapID and type(info.name) == "string" then
    mapID = MatchMapIDFromName(info.name)
  end

  if mapID and mapID ~= lastQueueMapID then
    lastQueueMapID = mapID
    Print("Queue erkannt: " .. GetDungeonName(mapID))
  elseif not mapID and lastQueueMapID ~= nil then
    lastQueueMapID = nil
  end
end

-- ---------------------------------------------------------------------------
-- Event frame
-- ---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
frame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
frame:RegisterEvent("CHALLENGE_MODE_START")

frame:SetScript("OnEvent", function(_self, event, ...)
  if event == "PLAYER_LOGIN" then
    local C_Timer_ref = rawget(_G, "C_Timer")
    if type(C_Timer_ref) == "table" and type(C_Timer_ref.NewTicker) == "function" then
      C_Timer_ref.NewTicker(5, CheckActiveGroup)
    end
  elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
    local searchResultID, newStatus = ...
    HandleApplicationStatus(searchResultID, newStatus)
  elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
    CheckActiveGroup()
  elseif event == "CHALLENGE_MODE_START" then
    -- Key started — clear state, no longer relevant
    pendingInvites = {}
    lastQueueMapID = nil
  end
end)
