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

-- Static map: LFG activity ID -> challenge map ID for all active-season dungeons.
-- Primary fast path: zero-latency, no API call, taint-safe.
-- The LFG API (C_LFGList.GetActivityInfoTable) can return tainted/secret values
-- during raid state or when the API cache is cold (first event after login).
-- The static map guarantees a correct answer even in those edge cases.
-- New season: add entries here AND in SeasonData.mapToTeleport — both must stay in sync.
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

-- Normalise a string for keyword matching: lowercase, strip non-word chars,
-- collapse whitespace. Stripping non-ASCII avoids broken multibyte sequences
-- from tainted/locale LFG API strings.
local function Norm(s)
  local ok, result = pcall(function()
    s = (s or ""):lower()
    s = s:gsub("[^%a%d%'%s]", " ")
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

-- Resolve mapID from a single activityID.
-- Resolution order:
--   1. ACTIVITY_TO_MAP  — static, zero-latency, taint-safe (primary)
--   2. Name-based keyword matching — fallback for activity stubs without a mapID field
local function MapIDFromActivityID(activityID)
  if not activityID then
    return nil
  end
  local numID = tonumber(activityID)
  if not numID or numID <= 0 then
    return nil
  end

  -- 1. Static map: fast, taint-safe, reliable even when the API cache is cold
  if ACTIVITY_TO_MAP[numID] then
    return ACTIVITY_TO_MAP[numID]
  end

  -- 2. Name-based keyword fallback (handles activity stubs without a mapID field)
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
-- mapID currently highlighted (invite accepted or own queue) — nil = none
local detectedMapID = nil

-- Injected by the factory after UpdateMPlusTeleportButton is available.
-- Replaces the previous direct _factoryCtx access (ARCH-1 fix).
local highlightCallback = nil

-- Injected by the factory so chat messages follow the player's locale setting.
-- MINOR-1 fix: removes hardcoded German strings.
local localeGetter = nil

function LFGDetect.GetDetectedMapID()
  return detectedMapID
end

-- Called once from InitializeFactoryPrimaryControllers to wire the callbacks.
function LFGDetect.SetHighlightCallback(fn)
  highlightCallback = type(fn) == "function" and fn or nil
end

function LFGDetect.SetLocaleGetter(fn)
  localeGetter = type(fn) == "function" and fn or nil
end

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

-- BUG-1 fix: soundContext propagated so own-queue updates suppress the portal sound.
-- ARCH-1 fix: uses the injected highlightCallback instead of reaching into _factoryCtx.
local function TriggerHighlightUpdate(soundContext)
  if type(highlightCallback) == "function" then
    highlightCallback(soundContext)
  end
end

local function OnInviteAccepted(searchResultID)
  local mapID = pendingInvites[searchResultID]
  if mapID then
    detectedMapID = mapID
    local L = localeGetter and localeGetter() or {}
    Print(string.format(L.LFG_DETECT_INVITE or "LFG invite detected: %s", GetDungeonName(mapID)))
    pendingInvites = {}
    TriggerHighlightUpdate() -- no soundContext: portal sound is intended for accepted invites
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
  -- BUG-3 fix: normalize to lowercase so casing variations from the Blizzard API
  -- ("Invited", "InviteAccepted", …) are handled the same as the lowercase form.
  local normalizedStatus = type(newStatus) == "string" and string.lower(newStatus) or ""
  if normalizedStatus == "invited" then
    OnInvited(searchResultID)
  elseif normalizedStatus == "inviteaccepted" then
    OnInviteAccepted(searchResultID)
  elseif NEGATIVE_STATUSES[normalizedStatus] then
    OnInviteDeclined(searchResultID)
  end
end

-- ---------------------------------------------------------------------------
-- Own queue detection (active listing + 5s poll)
-- ---------------------------------------------------------------------------

-- BUG-2 fix: pendingInvites is NOT cleared here. The 5s ticker calls CheckActiveGroup
-- which calls ClearDetectedState when no active listing exists. If a player received
-- an invite (no own listing) and the ticker fires before they accept, pendingInvites
-- must survive so OnInviteAccepted can still resolve the mapID.
-- pendingInvites is only cleared in ClearAllState (group-leave / key-start).
--
-- BUG-LFG-4 fix: only clear state that the queue-listing path owns.
-- lastQueueMapID is set exclusively by CheckActiveGroup when an active listing is
-- found. Invite-set detectedMapID (lastQueueMapID == nil) must survive the 5s ticker
-- so the portal highlight stays active until the player enters the dungeon or leaves
-- the group (both handled by ClearAllState).
local function ClearDetectedState()
  if lastQueueMapID ~= nil then
    detectedMapID = nil
    lastQueueMapID = nil
    TriggerHighlightUpdate("queue")
  end
end

-- Full reset: called on group-leave and challenge-start where pending invite state
-- is no longer relevant.
local function ClearAllState()
  local hadState = detectedMapID ~= nil or lastQueueMapID ~= nil or next(pendingInvites) ~= nil
  detectedMapID = nil
  lastQueueMapID = nil
  pendingInvites = {}
  if hadState then
    TriggerHighlightUpdate("queue")
  end
end

local function CheckActiveGroup()
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" or type(C_LFGList_ref.GetActiveEntryInfo) ~= "function" then
    return
  end

  local ok, info = pcall(C_LFGList_ref.GetActiveEntryInfo)
  if not ok or not info then
    -- No active listing — clear all state
    ClearDetectedState()
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
    detectedMapID = mapID
    local L = localeGetter and localeGetter() or {}
    Print(string.format(L.LFG_DETECT_QUEUE or "LFG listing detected: %s", GetDungeonName(mapID)))
    TriggerHighlightUpdate("queue") -- BUG-1: own listing → suppress portal sound
  elseif not mapID and lastQueueMapID ~= nil then
    lastQueueMapID = nil
    detectedMapID = nil
    TriggerHighlightUpdate("queue")
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
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

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
  elseif event == "GROUP_ROSTER_UPDATE" then
    local isInGroup = rawget(_G, "IsInGroup")
    local isInRaid = rawget(_G, "IsInRaid")
    local inGroup = (type(isInGroup) == "function" and isInGroup()) or (type(isInRaid) == "function" and isInRaid())
    if not inGroup then
      -- Left all groups — full reset including pending invites
      ClearAllState()
      return
    end
    -- Joined a group: if we have a pending invite but detectedMapID was not set
    -- yet (e.g. inviteaccepted fired before GROUP_ROSTER_UPDATE settled),
    -- apply it now.
    if not detectedMapID then
      local resultID, mapID = next(pendingInvites)
      if resultID and mapID then
        detectedMapID = mapID
        local L = localeGetter and localeGetter() or {}
    Print(string.format(L.LFG_DETECT_INVITE or "LFG invite detected: %s", GetDungeonName(mapID)))
        pendingInvites = {}
        TriggerHighlightUpdate() -- no soundContext: portal sound intended here
      else
        CheckActiveGroup()
      end
    end
  elseif event == "CHALLENGE_MODE_START" then
    -- Key started — full reset, invite state no longer relevant
    ClearAllState()
  end
end)
