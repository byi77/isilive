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
local Unpack = rawget(_G, "unpack") or rawget(table, "unpack")
local Validators = addonTable.Validators or {}
local EntryResolver = assert(addonTable.LFGEntryResolver, "isiLive: LFGEntryResolver missing")
local MapIDFromActivityID =
  assert(EntryResolver.MapIDFromActivityID, "isiLive: LFGEntryResolver.MapIDFromActivityID missing")
local MapIDFromActivityIDs =
  assert(EntryResolver.MapIDFromActivityIDs, "isiLive: LFGEntryResolver.MapIDFromActivityIDs missing")

local function IsSecretValue(value)
  local validator = rawget(Validators, "IsSecretValue")
  return type(validator) == "function" and validator(value) == true
end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

-- [searchResultID] = { mapID, leaderName }  — pending invites not yet accepted.
-- leaderName is the LFG group leader as returned by C_LFGList.GetSearchResultInfo;
-- used later as a tie-breaker when multiple roster members hold a key for the same
-- dungeon (the leader is in practice the key owner).
local pendingInvites = {}
local suppressedInviteAccepts = {}
-- mapID of the last detected own queue listing (nil = no active listing)
local lastQueueMapID = nil
-- mapID currently highlighted (invite or accepted invite, or own queue) — nil = none
local detectedMapID = nil
-- mapID from a just-accepted invite that is waiting for the roster to settle.
-- This prevents a transient non-group roster update from clearing a valid highlight.
local pendingAcceptedInviteMapID = nil
-- Leader name of the LFG group whose invite produced the current detectedMapID
-- (nil = detectedMapID was not set via invite path, or roster is post-reset).
-- Consumers use this to disambiguate ResolveActiveKeyOwnerUnit when the roster
-- contains multiple members with the same keyMapID.
local activeInviteLeader = nil
local activeInviteGroupName = nil
local activeQueueListingLeaderName = nil
local activeQueueListingGroupName = nil
-- Hint key level parsed from the LFG group title (e.g. "+13 Competitive" → 13).
-- Used as a last-resort fallback for the "Ziel-Dungeon: X +N" announce when
-- neither a roster owner nor a synced target supplies a level (typical for
-- groups whose leader does not run isiLive). nil = no hint available.
local activeInviteTitleLevel = nil
local activeInviteTitleLevelText = nil
-- searchResultID of the invite the player actually accepted (nil before accept
-- or after a full reset). Used by OnInviteDeclined to ignore decline/delisted
-- events for *other* parallel listings — without this guard, any same-mapID
-- decline (very common in push lobbies that post several +N variants for the
-- same dungeon) would null out the active invite state and force the status
-- announce to fall back on a worse level source.
local acceptedInviteSearchResultID = nil
-- Tracks whether GROUP_ROSTER_UPDATE has reported an established group since
-- the last accept. Used by PARTY_LEADER_CHANGED to distinguish two paths:
--   * Initial convert-to-party-lead right after accept: WoW fires
--     LFG_LIST_APPLICATION_STATUS_UPDATED(inviteaccepted) -> PARTY_LEADER_CHANGED
--     -> GROUP_ROSTER_UPDATE. The PLC here is the listing owner forming the
--     group, NOT a handoff away from them. The active-invite identity captured
--     during accept is still authoritative and must not be cleared.
--   * Real handoff later in the run: GROUP_ROSTER_UPDATE has long since fired,
--     so the flag is true. PLC at this point is a genuine leader change, the
--     listing identity is stale, and ClearAcceptedInviteListingIdentity runs
--     as before.
-- The flag flips back to false on every accept and on every group leave so
-- the next cycle starts fresh.
local rosterEstablishedSinceAccept = false

-- Last searchResultID for which MaybeShowAcceptedInviteNotice rendered the
-- Center Notice. Used to swallow same-searchResultID replays of
-- LFG_LIST_APPLICATION_STATUS_UPDATED=inviteaccepted (Blizzard has shipped
-- duplicate-fire bugs for this event before). Reset only on ClearAllStateImpl
-- (group-leave / explicit full reset), because a key-start is not a fresh
-- invite cycle and must not allow the accepted-invite notice to replay.
local lastShownNoticeSearchResultID = nil
local acceptedInviteNoticeBlockedUntilReset = false
local lastFiredTargetDungeonChatSearchResultID = nil
local pendingTargetDungeonChatEntry = nil
local pendingTargetDungeonChatSearchResultID = nil

-- Injected by the factory after UpdateMPlusTeleportButton is available.
-- Replaces the previous direct _factoryCtx access (ARCH-1 fix).
local highlightCallback = nil
local groupRosterTraceLogger = nil

-- Post-accept Center Notice plumbing. The factory injects:
--   * acceptedInviteNoticeCallback(payload): renders the modern center notice
--     with dungeon name + key level + group title + teleport button. nil disables.
--   * acceptedInviteNoticeEnabledFn(): reads IsiLiveDB.acceptedInviteNoticeEnabled
--     (~= false). nil treats the feature as enabled.
-- Source of truth is exclusively the pendingInvites entry of the accepted
-- searchResultID — never roster data, never sync data. Sibling listings cannot
-- influence the notice content.
local acceptedInviteNoticeCallback = nil
local acceptedInviteNoticeEnabledFn = nil

-- Retained as no-op compatibility hooks for older glue. Raid accepted-invite
-- notices are intentionally removed from runtime.

-- Direct-push hook for the target-dungeon chat announce. The Center Notice
-- already renders the listing's "+N" synchronously from entry.titleLevel —
-- this hook feeds the **same** payload to the status controller so the chat
-- line is guaranteed to match the notice. Replaces the previous resolver-
-- driven path for the LFG-accept trigger, which had to fight a 3-source
-- chain (LFG-title hint -> roster owner -> synced target) + a 3-second
-- defer + race guards just to recover what was already in entry.titleLevel
-- at the moment of accept.
--
-- The resolver-driven MaybeAnnounceTargetDungeonChat path stays for other
-- triggers (manual /invite without LFG context, peer-sync target updates,
-- pre-formed groups), so this hook is purely additive — it short-circuits
-- the LFG-accept case and locks the lock-in flag so the resolver does not
-- announce a second time.
local targetDungeonChatCallback = nil
local targetDungeonChatEnabledFn = nil

local debugLog = nil
local debugTrace = nil
local debugTraceDeep = nil
local lastRosterUpdateSignature = nil
local TriggerHighlightUpdate

local function GetGroupMemberCount()
  local getNumGroupMembers = rawget(_G, "GetNumGroupMembers")
  if type(getNumGroupMembers) ~= "function" then
    return nil
  end

  local ok, count = pcall(getNumGroupMembers)
  if not ok then
    return nil
  end

  count = tonumber(count)
  if not count then
    return nil
  end

  return math.max(0, math.floor(count))
end

-- Called once from InitializeFactoryPrimaryControllers to wire the callbacks.
function LFGDetect.SetHighlightCallback(fn)
  highlightCallback = type(fn) == "function" and fn or nil
  if highlightCallback and detectedMapID then
    -- If the callback is wired after the LFG state was already resolved,
    -- replay the current state once so the UI cannot miss the highlight.
    TriggerHighlightUpdate("queue")
  end
end

function LFGDetect.SetGroupRosterTraceLogger(fn)
  groupRosterTraceLogger = type(fn) == "function" and fn or nil
end

-- Retained as no-op compatibility hooks for older glue. The pre-accept LFG
-- invite hint was removed from runtime.
function LFGDetect.SetInviteHintCallback(_fn) end

function LFGDetect.SetInviteHintEnabledFn(_fn) end

function LFGDetect.SetInviteHintLocaleFn(_fn) end

function LFGDetect.SetAcceptedInviteNoticeCallback(fn)
  acceptedInviteNoticeCallback = type(fn) == "function" and fn or nil
end

function LFGDetect.SetAcceptedInviteNoticeEnabledFn(fn)
  acceptedInviteNoticeEnabledFn = type(fn) == "function" and fn or nil
end

function LFGDetect.SetAcceptedRaidInviteNoticeCallback(_fn)
  return nil
end

function LFGDetect.SetAcceptedRaidInviteNoticeEnabledFn(_fn)
  return nil
end

function LFGDetect.SetTargetDungeonChatCallback(fn)
  targetDungeonChatCallback = type(fn) == "function" and fn or nil
end

function LFGDetect.SetTargetDungeonChatEnabledFn(fn)
  targetDungeonChatEnabledFn = type(fn) == "function" and fn or nil
end

function LFGDetect.SetLogger(fn)
  debugLog = type(fn) == "function" and fn or nil
end

function LFGDetect.SetTraceLogger(fn)
  debugTrace = type(fn) == "function" and fn or nil
end

function LFGDetect.SetDeepTraceLogger(fn)
  debugTraceDeep = type(fn) == "function" and fn or nil
end

local function LogInternal(traceFn, event, formatText, ...)
  if not traceFn and not debugLog then
    return
  end
  local argCount = select("#", ...)
  if traceFn then
    local args = { ... }
    traceFn(function()
      local data = formatText
      if argCount > 0 then
        data = string.format(tostring(formatText or ""), Unpack(args))
      end
      return string.format("[LFG] %s %s", event, data or "")
    end)
    return
  end
  local data = formatText
  if argCount > 0 then
    data = string.format(tostring(formatText or ""), ...)
  end
  if debugLog then
    debugLog(string.format("[LFG] %s %s", event, data or ""))
  end
end

local function Log(event, formatText, ...)
  LogInternal(debugTrace, event, formatText, ...)
end

local function LogDeep(event, formatText, ...)
  LogInternal(debugTraceDeep, event, formatText, ...)
end

local function EmitGroupRosterTrace(inGroup, groupMemberCount, detectedBefore)
  if type(groupRosterTraceLogger) ~= "function" then
    return
  end

  groupRosterTraceLogger({
    event = "GROUP_ROSTER_UPDATE",
    inGroup = inGroup == true,
    members = groupMemberCount,
    detectedBefore = detectedBefore,
    detectedAfter = detectedMapID,
    pendingAccept = pendingAcceptedInviteMapID,
    latestQueueMap = lastQueueMapID,
  })
end

-- ---------------------------------------------------------------------------
-- Invite detection
-- ---------------------------------------------------------------------------

local function ResolveInviteEntry(searchResultID)
  return EntryResolver.ResolveInviteEntry(searchResultID, Log)
end

local function RefreshInviteEntryOnAccept(searchResultID, cachedEntry)
  return EntryResolver.RefreshInviteEntryOnAccept(searchResultID, cachedEntry, Log)
end

local function ResolveRaidInviteEntry(searchResultID)
  return EntryResolver.ResolveRaidInviteEntry(searchResultID)
end

local function ResolveEntryTitleLevel(entry)
  return EntryResolver.ResolveEntryTitleLevel(entry, Log)
end

local ResolveEntryTitleLevelText =
  assert(EntryResolver.ResolveEntryTitleLevelText, "isiLive: LFGEntryResolver.ResolveEntryTitleLevelText missing")
local function ClearPendingTargetDungeonChat()
  pendingTargetDungeonChatEntry = nil
  pendingTargetDungeonChatSearchResultID = nil
end

local function GetLocalPlayerFullName()
  local isExistingUnit = rawget(Validators, "IsExistingUnit")
  if type(isExistingUnit) ~= "function" or not isExistingUnit("player") then
    return nil
  end
  local unitFullNameFn = rawget(_G, "UnitFullName")
  if type(unitFullNameFn) ~= "function" then
    return nil
  end
  local ok, name, realm = pcall(unitFullNameFn, "player")
  if not ok or IsSecretValue(name) or IsSecretValue(realm) or type(name) ~= "string" or name == "" then
    return nil
  end
  if type(realm) == "string" and realm ~= "" then
    return name .. "-" .. realm
  end
  return name
end

-- Exposed for callers that hold a raw entry table (e.g. tests pinning the
-- divergence-recovery contract, or future consumers that bypass the
-- MaybeShow* helpers). Mirrors the Get* naming used by the rest of the
-- module's public surface.
LFGDetect.ResolveEntryTitleLevel = ResolveEntryTitleLevel

-- Fires the direct-push target-dungeon chat hook with the listing payload.
-- The listing's titleLevel is the same field the Center Notice uses, so the
-- chat line and the notice surface identical "+N" without going through the
-- resolver chain (LFG-title hint, roster owner, synced target). Silently
-- no-ops when the callback is unwired (early-load races, tests).
local function MaybeFireTargetDungeonChatFromAccept(entry, searchResultID)
  if type(targetDungeonChatCallback) ~= "function" then
    return
  end
  if type(entry) ~= "table" or not entry.mapID then
    return
  end
  if type(targetDungeonChatEnabledFn) == "function" and targetDungeonChatEnabledFn() == false then
    return
  end
  local resolvedLevel = ResolveEntryTitleLevel(entry)
  local resolvedLevelText = not resolvedLevel and ResolveEntryTitleLevelText(entry) or nil
  if
    (resolvedLevel or resolvedLevelText)
    and searchResultID ~= nil
    and searchResultID == lastFiredTargetDungeonChatSearchResultID
  then
    Log("chat_skip_duplicate", "searchResultID=%s", tostring(searchResultID))
    return
  end
  targetDungeonChatCallback({
    mapID = entry.mapID,
    activityID = entry.activityID,
    level = resolvedLevel,
    levelText = resolvedLevelText,
    leaderName = entry.leaderName,
    -- groupName is the raw listing title — may be plain ("+12 Push") or
    -- Blizzard pipe-markup ("|Kk584|k"). Either way the chat frame
    -- renders it correctly when printed, so the status controller
    -- appends it to the chat line whenever a parsed level is missing.
    groupName = entry.groupName,
    searchResultID = searchResultID,
  })
  if (resolvedLevel or resolvedLevelText) and searchResultID ~= nil then
    lastFiredTargetDungeonChatSearchResultID = searchResultID
  end
end

local function FlushPendingTargetDungeonChat()
  if pendingTargetDungeonChatEntry == nil then
    return
  end
  local entry = pendingTargetDungeonChatEntry
  local searchResultID = pendingTargetDungeonChatSearchResultID
  ClearPendingTargetDungeonChat()
  MaybeFireTargetDungeonChatFromAccept(entry, searchResultID)
end

local function QueueTargetDungeonChatFromAccept(entry, searchResultID)
  if type(entry) ~= "table" or not entry.mapID then
    return
  end
  MaybeFireTargetDungeonChatFromAccept(entry, searchResultID)
end

-- Renders the post-accept Center Notice. Pulls ALL data from the supplied
-- entry — the pendingInvites snapshot of the searchResultID the player just
-- accepted. Sibling listings (other searchResultIDs in pendingInvites) cannot
-- influence the payload. No roster lookup, no sync data, no LFG-title
-- re-parse: if entry.titleLevel is nil (group title without "+N"), the notice
-- renders without a level — never inferred.
local function MaybeShowAcceptedInviteNotice(entry, searchResultID)
  if type(acceptedInviteNoticeCallback) ~= "function" then
    return
  end
  if type(entry) ~= "table" or not entry.mapID then
    return
  end
  if type(acceptedInviteNoticeEnabledFn) == "function" and acceptedInviteNoticeEnabledFn() == false then
    return
  end
  if acceptedInviteNoticeBlockedUntilReset then
    Log("notice_skip_after_key_start", "searchResultID=%s", tostring(searchResultID))
    return
  end
  -- Swallow same-searchResultID replays of LFG_LIST_APPLICATION_STATUS_UPDATED
  -- =inviteaccepted (Blizzard duplicate-fire). Mirrors the Status controller's
  -- lock-in on the chat path. Cleared only by full reset so key-start and
  -- post-start event replays cannot surface the accepted-invite notice again.
  if searchResultID ~= nil and searchResultID == lastShownNoticeSearchResultID then
    Log("notice_skip_duplicate", "searchResultID=%s", tostring(searchResultID))
    return
  end
  lastShownNoticeSearchResultID = searchResultID

  acceptedInviteNoticeCallback({
    mapID = entry.mapID,
    activityID = entry.activityID,
    level = ResolveEntryTitleLevel(entry),
    leaderName = entry.leaderName,
    groupName = entry.groupName,
    comment = entry.comment,
    searchResultID = searchResultID,
  })
end

local function OnInvited(searchResultID)
  suppressedInviteAccepts[searchResultID] = nil
  local entry = ResolveInviteEntry(searchResultID)
  if entry then
    pendingInvites[searchResultID] = entry
    Log(
      "state_set",
      "var=pendingInvites[%s] mapID=%s leader=%s titleLevel=%s",
      tostring(searchResultID),
      tostring(entry.mapID),
      tostring(entry.leaderName),
      tostring(entry.titleLevel)
    )
  end
end

-- BUG-1 fix: soundContext propagated so own-queue and invite updates suppress the portal sound.
-- ARCH-1 fix: uses the injected highlightCallback instead of reaching into _factoryCtx.
TriggerHighlightUpdate = function(soundContext)
  Log("highlight_trigger", "soundContext=%s detectedMapID=%s", tostring(soundContext), tostring(detectedMapID))
  if type(highlightCallback) == "function" then
    highlightCallback(soundContext)
  end
end

local function OnInviteAccepted(searchResultID)
  local entry = pendingInvites[searchResultID]
  if entry == nil and not suppressedInviteAccepts[searchResultID] then
    entry = ResolveInviteEntry(searchResultID)
  end
  if entry ~= nil and not suppressedInviteAccepts[searchResultID] then
    entry = RefreshInviteEntryOnAccept(searchResultID, entry)
  end
  local mapID = type(entry) == "table" and entry.mapID or nil
  local leaderName = type(entry) == "table" and entry.leaderName or nil
  -- ResolveEntryTitleLevel falls back to ParseTitleKeyLevel(entry.groupName)
  -- when entry.titleLevel is nil — covers the case where the cached
  -- pendingInvites entry lost the level but kept the group name (the bug
  -- where the Center Notice showed "Gruppe: +13 Competitive" while the
  -- dungeon row and the chat line dropped the "+13").
  local titleLevel = ResolveEntryTitleLevel(entry)
  local titleLevelText = not titleLevel and ResolveEntryTitleLevelText(entry) or nil
  Log(
    "invite_accepted",
    "searchResultID=%s mapID=%s leader=%s titleLevel=%s",
    tostring(searchResultID),
    tostring(mapID),
    tostring(leaderName),
    tostring(titleLevel)
  )
  if mapID then
    pendingInvites[searchResultID] = nil
    activeInviteLeader = leaderName
    activeInviteGroupName = type(entry.groupName) == "string" and entry.groupName ~= "" and entry.groupName or nil
    activeInviteTitleLevel = titleLevel
    activeInviteTitleLevelText = titleLevelText
    acceptedInviteSearchResultID = searchResultID
    pendingAcceptedInviteMapID = mapID
    -- Fresh accept: the upcoming PARTY_LEADER_CHANGED is the initial
    -- convert-to-party-lead, not a handoff. See state-block comment above.
    rosterEstablishedSinceAccept = false
    if detectedMapID ~= mapID then
      Log("state_set", "var=detectedMapID before=%s after=%s", tostring(detectedMapID), tostring(mapID))
      detectedMapID = mapID
      Log("state_set", "var=pendingAcceptedInviteMapID val=%s", tostring(mapID))
    end
    Log("state_set", "var=activeInviteLeader val=%s", tostring(leaderName))
    Log("state_set", "var=activeInviteGroupName val=%s", tostring(activeInviteGroupName))
    Log("state_set", "var=activeInviteTitleLevel val=%s", tostring(titleLevel))
    Log("state_set", "var=activeInviteTitleLevelText val=%s", tostring(titleLevelText))
    Log("state_set", "var=acceptedInviteSearchResultID val=%s", tostring(searchResultID))
    MaybeShowAcceptedInviteNotice(entry, searchResultID)
    -- Announce chat with the SAME entry the notice just rendered before the
    -- highlight refresh can synchronously re-enter the resolver-driven status
    -- path with stale queue-state text.
    QueueTargetDungeonChatFromAccept(entry, searchResultID)
    TriggerHighlightUpdate("invite")
    return
  end

  -- Raid fallback: the M+ resolver dropped the listing (Raid filter), so the
  -- M+ side never sees it. Try the Raid-only resolver. On a hit, consume the
  -- pending entry and stop — no notice / detectedMapID / activeInviteLeader /
  -- highlight update / chat announce is touched for Raid.
  local raidEntry = ResolveRaidInviteEntry(searchResultID)
  if type(raidEntry) == "table" and raidEntry.mapID then
    Log(
      "raid_invite_accepted",
      "searchResultID=%s mapID=%s leader=%s",
      tostring(searchResultID),
      tostring(raidEntry.mapID),
      tostring(raidEntry.leaderName)
    )
    pendingInvites[searchResultID] = nil
  end
end

local function OnInviteDeclined(searchResultID)
  local entry = pendingInvites[searchResultID]
  local mapID = type(entry) == "table" and entry.mapID or nil
  Log("invite_declined", "searchResultID=%s mapID=%s", tostring(searchResultID), tostring(mapID))
  pendingInvites[searchResultID] = false
  suppressedInviteAccepts[searchResultID] = true
  -- A decline/delisted event for a *different* parallel listing (very common in
  -- push lobbies that post "+12", "+13", "+14" variants of the same dungeon)
  -- must not erase the active-invite state of the listing the player actually
  -- accepted — otherwise the LFG-title level hint disappears and downstream
  -- consumers (status announce, owner resolve) fall back to a worse level
  -- source.
  if acceptedInviteSearchResultID ~= nil and searchResultID ~= acceptedInviteSearchResultID then
    Log(
      "invite_declined_ignored",
      "searchResultID=%s reason=other_listing accepted=%s",
      tostring(searchResultID),
      tostring(acceptedInviteSearchResultID)
    )
    return
  end
  -- Negative status for the SAME searchResultID after a successful accept:
  -- Blizzard fires `declined_delisted` / `declined_full` for the accepted
  -- listing the moment the group fills (typical with auto-accept on the last
  -- open slot — "Die Gruppe '+12 Relaxed' ist voll und wurde abgemeldet").
  -- That is post-accept cleanup, not a real decline of our spot, so the
  -- accepted-invite state (detectedMapID, activeInviteLeader,
  -- activeInviteTitleLevel) must stay until group-leave clears it via
  -- ClearAllStateImpl. Without this guard, the chat target-dungeon announce
  -- loses its LFG-title hint and falls back to a worse level source (roster
  -- owner / synced target — surfaces wrong "+N" e.g. the player's own key).
  if searchResultID == acceptedInviteSearchResultID then
    Log(
      "invite_declined_post_accept_ignored",
      "searchResultID=%s reason=listing_delisted_after_accept",
      tostring(searchResultID)
    )
    return
  end
  if mapID and detectedMapID == mapID then
    detectedMapID = nil
    activeInviteLeader = nil
    activeInviteGroupName = nil
    activeQueueListingLeaderName = nil
    activeQueueListingGroupName = nil
    activeInviteTitleLevel = nil
    activeInviteTitleLevelText = nil
    acceptedInviteSearchResultID = nil
    ClearPendingTargetDungeonChat()
    TriggerHighlightUpdate("queue")
  end
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
-- pendingInvites is only cleared in ClearAllState (group-leave or explicit factory reset).
--
-- BUG-LFG-4 fix: only clear state that the queue-listing path owns.
-- lastQueueMapID is set exclusively by CheckActiveGroup when an active listing is
-- found. Invite-set detectedMapID (lastQueueMapID == nil) must survive the 5s ticker
-- so the portal highlight stays active until the player enters the dungeon or leaves
-- the group (both handled by ClearAllStateImpl).
local function ClearDetectedState()
  if lastQueueMapID ~= nil then
    Log("clear_detected_state", "path=queue_ticker lastQueueMapID=%s", tostring(lastQueueMapID))
    detectedMapID = nil
    lastQueueMapID = nil
    activeInviteLeader = nil
    activeInviteGroupName = nil
    activeQueueListingLeaderName = nil
    activeQueueListingGroupName = nil
    activeInviteTitleLevel = nil
    activeInviteTitleLevelText = nil
    acceptedInviteSearchResultID = nil
    ClearPendingTargetDungeonChat()
    TriggerHighlightUpdate("queue")
  end
end

-- Full reset: called on group-leave and explicit factory reset where pending invite
-- state is no longer relevant.
--
-- BUG-RAID-LEAVE-M+-INVITE fix: pending invites are dropped here, but they are
-- NOT promoted to the suppressed-accepts bucket. That bucket exists only to
-- guard the decline -> stray accept race for the SAME searchResultID; a reset
-- from group-leave is unrelated. Sweeping pending invites into suppressed
-- silently killed legitimate next-invite accepts in the real-world sequence:
-- (1) user holds both a Raid and an M+ LFG application open in parallel,
-- (2) Raid leader invites + user accepts -> joins raid, (3) user leaves raid,
-- ClearAllStateImpl runs and moves every remaining pendingInvite (including
-- the still-open M+ application slot) into suppressedInviteAccepts, then (4)
-- the M+ inviteaccepted event arrives but the suppressed bucket blocks the
-- ResolveInviteEntry fallback in OnInviteAccepted -> mapID resolves to nil,
-- so no Center Notice, no Target-Dungeon chat announce, no teleport highlight.
local function ClearAllStateImpl()
  local hadState = detectedMapID ~= nil
    or lastQueueMapID ~= nil
    or next(pendingInvites) ~= nil
    or pendingAcceptedInviteMapID ~= nil
    or activeInviteLeader ~= nil
    or activeInviteGroupName ~= nil
    or activeQueueListingLeaderName ~= nil
    or activeQueueListingGroupName ~= nil
    or activeInviteTitleLevel ~= nil
    or activeInviteTitleLevelText ~= nil
    or acceptedInviteSearchResultID ~= nil
    or pendingTargetDungeonChatEntry ~= nil
  Log("clear_all_state", "hadState=%s", tostring(hadState))
  detectedMapID = nil
  lastQueueMapID = nil
  pendingAcceptedInviteMapID = nil
  activeInviteLeader = nil
  activeInviteGroupName = nil
  activeQueueListingLeaderName = nil
  activeQueueListingGroupName = nil
  activeInviteTitleLevel = nil
  activeInviteTitleLevelText = nil
  acceptedInviteSearchResultID = nil
  rosterEstablishedSinceAccept = false
  lastShownNoticeSearchResultID = nil
  acceptedInviteNoticeBlockedUntilReset = false
  lastFiredTargetDungeonChatSearchResultID = nil
  ClearPendingTargetDungeonChat()
  pendingInvites = {}
  -- Reset alongside pendingInvites: entries are added per declined invite and
  -- were otherwise never dropped in bulk, so the map grew for the whole
  -- session and carried decline state across unrelated groups. Search result
  -- IDs are assigned by the LFG system and can be reused.
  suppressedInviteAccepts = {}
  if hadState then
    TriggerHighlightUpdate("queue")
  end
end

function LFGDetect.GetDetectedMapID()
  return detectedMapID
end

function LFGDetect.GetActiveInviteLeader()
  return activeInviteLeader
end

function LFGDetect.GetActiveInviteGroupName()
  return activeInviteGroupName
end

function LFGDetect.GetActiveQueueListingLeaderName()
  return activeQueueListingLeaderName
end

function LFGDetect.GetActiveQueueListingGroupName()
  return activeQueueListingGroupName
end

-- Hint level parsed from the leader's free-form LFG group title
-- (e.g. "+13 Competitive" → 13). Used as a last-resort fallback for the
-- "Ziel-Dungeon: X +N" announce when no roster owner / synced target supplies
-- a level. nil = no hint available (no invite-accepted state, or no "+N"
-- pattern in the title).
function LFGDetect.GetActiveInviteTitleLevel()
  return activeInviteTitleLevel
end

function LFGDetect.GetActiveInviteTitleLevelText()
  return activeInviteTitleLevelText
end

-- searchResultID of the invite the player actually accepted. Exposed for tests
-- (the production code reads the module-local directly). nil = no accepted
-- invite, or state was reset.
function LFGDetect.GetAcceptedInviteSearchResultID()
  return acceptedInviteSearchResultID
end

function LFGDetect.ClearAllState()
  ClearAllStateImpl()
end

local function CheckActiveGroup()
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" or type(C_LFGList_ref.GetActiveEntryInfo) ~= "function" then
    return
  end

  local ok, info = pcall(C_LFGList_ref.GetActiveEntryInfo)
  if not ok or not info then
    -- No active listing:
    -- - while grouped, keep the current detected state so the highlight can
    --   survive roster settling until the player actually enters the dungeon
    --   or leaves the group.
    -- - while not grouped, only clear queue-owned state.
    -- - while an invite was just accepted, protect the state until
    --   GROUP_ROSTER_UPDATE fires. IsInGroup() can still return false in the
    --   window between LFG_LIST_APPLICATION_STATUS_UPDATED=inviteaccepted and
    --   the delayed GROUP_ROSTER_UPDATE; clearing here races the highlight off.
    local isInGroup = rawget(_G, "IsInGroup")
    local isInRaid = rawget(_G, "IsInRaid")
    local inGroup = (type(isInGroup) == "function" and isInGroup()) or (type(isInRaid) == "function" and isInRaid())
    if not inGroup and pendingAcceptedInviteMapID == nil then
      ClearDetectedState()
    end
    return
  end

  local mapID = nil

  local hasActivityIDs = type(info.activityIDs) == "table" and next(info.activityIDs) ~= nil
  if hasActivityIDs then
    mapID = MapIDFromActivityIDs(info.activityIDs)
  end
  if not mapID and not hasActivityIDs and info.activityID then
    mapID = MapIDFromActivityID(info.activityID)
  end

  if mapID and mapID ~= lastQueueMapID then
    Log("queue_listing_detected", "mapID=%s lastQueueMapID=%s", tostring(mapID), tostring(lastQueueMapID))
    lastQueueMapID = mapID
    detectedMapID = mapID
    activeQueueListingGroupName = type(info.name) == "string" and info.name ~= "" and info.name or nil
    activeQueueListingLeaderName = type(info.leaderName) == "string" and info.leaderName ~= "" and info.leaderName
      or GetLocalPlayerFullName()
    Log("state_set", "var=lastQueueMapID val=%s", tostring(mapID))
    Log("state_set", "var=detectedMapID val=%s", tostring(mapID))
    Log("state_set", "var=activeQueueListingGroupName val=%s", tostring(activeQueueListingGroupName))
    Log("state_set", "var=activeQueueListingLeaderName val=%s", tostring(activeQueueListingLeaderName))
    TriggerHighlightUpdate("queue") -- BUG-1: own listing → suppress portal sound
  elseif mapID then
    activeQueueListingGroupName = type(info.name) == "string" and info.name ~= "" and info.name or nil
    activeQueueListingLeaderName = type(info.leaderName) == "string" and info.leaderName ~= "" and info.leaderName
      or GetLocalPlayerFullName()
  elseif not mapID and lastQueueMapID ~= nil then
    Log("queue_listing_cleared", "no_active_entry")
    lastQueueMapID = nil
    detectedMapID = nil
    activeQueueListingLeaderName = nil
    activeQueueListingGroupName = nil
    TriggerHighlightUpdate("queue")
  end
end

-- Authoritative lookup: ask the WoW LFG API which application currently
-- carries the "inviteaccepted" status. Returns the matching searchResultID,
-- or nil when no application is in that state (or the API is unavailable /
-- tainted). Caller MUST treat nil as "do not know yet" — never guess.
local function FindAcceptedSearchResultID()
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" then
    return nil
  end
  if type(C_LFGList_ref.GetApplications) ~= "function" then
    return nil
  end
  if type(C_LFGList_ref.GetApplicationInfo) ~= "function" then
    return nil
  end

  local ok, apps = pcall(C_LFGList_ref.GetApplications)
  if not ok or type(apps) ~= "table" then
    return nil
  end

  for _, applicationID in ipairs(apps) do
    local infoOk, searchResultID, appStatus = pcall(C_LFGList_ref.GetApplicationInfo, applicationID)
    if infoOk and type(appStatus) == "string" then
      if string.lower(appStatus) == "inviteaccepted" then
        local numericSearchResultID = tonumber(searchResultID)
        if numericSearchResultID and numericSearchResultID > 0 then
          return numericSearchResultID
        end
      end
    end
  end
  return nil
end

-- Resolves which pendingInvites entry the player has just accepted, for use
-- in the GROUP_ROSTER_UPDATE race-recovery branch (when GROUP_ROSTER_UPDATE
-- arrives before LFG_LIST_APPLICATION_STATUS_UPDATED("inviteaccepted")).
--
-- Resolution priority — strictly deterministic, never picks 1-of-N:
--   1. WoW LFG API authoritative: status == "inviteaccepted" on one of the
--      player's own applications. Single source of truth from Blizzard.
--   2. Unambiguous fallback: exactly one pendingInvites entry exists. With
--      a single candidate there is nothing to guess.
--   3. Nil — defer. Multiple pendingInvites with no API disambiguation must
--      wait for the explicit inviteaccepted event, which carries its own
--      authoritative searchResultID.
--
-- Returns (searchResultID, entry) on success; (nil, nil) when the caller
-- should defer. The entry table is read from pendingInvites first; when the
-- API names an ID we never observed via OnInvited (e.g. very short listings)
-- we re-resolve live via ResolveInviteEntry rather than fabricate values.
local function ResolveAcceptedPendingInvite()
  local apiSearchResultID = FindAcceptedSearchResultID()
  if apiSearchResultID then
    local entry = pendingInvites[apiSearchResultID]
    if type(entry) ~= "table" then
      entry = ResolveInviteEntry(apiSearchResultID)
    end
    if type(entry) == "table" and entry.mapID then
      Log(
        "accept_resolved",
        "source=api searchResultID=%s mapID=%s",
        tostring(apiSearchResultID),
        tostring(entry.mapID)
      )
      return apiSearchResultID, entry
    end
    Log("accept_resolve_failed", "source=api searchResultID=%s reason=no_entry", tostring(apiSearchResultID))
    return nil, nil
  end

  local count, soleID, soleEntry = 0, nil, nil
  for id, entry in pairs(pendingInvites) do
    if type(entry) == "table" then
      count = count + 1
      if count > 1 then
        Log("accept_deferred", "reason=ambiguous_pending count=%s", "multi")
        return nil, nil
      end
      soleID, soleEntry = id, entry
    end
  end
  if count == 1 and type(soleEntry) == "table" and soleEntry.mapID then
    Log(
      "accept_resolved",
      "source=single_pending searchResultID=%s mapID=%s",
      tostring(soleID),
      tostring(soleEntry.mapID)
    )
    return soleID, soleEntry
  end
  return nil, nil
end

-- Clears the LFG-listing identity (leader / title level / accepted search-
-- result-ID + detectedMapID) but does NOT touch pendingInvites / queue
-- state. Used by post-challenge cleanup and by the leader-change path: in
-- both cases the previous listing identity has stopped being authoritative,
-- so downstream consumers (status target-dungeon resolver, owner resolver)
-- should use the UnitIsGroupLeader / roster resolver instead.
local function ClearAcceptedInviteListingIdentity(reason)
  if
    detectedMapID == nil
    and activeInviteLeader == nil
    and activeInviteGroupName == nil
    and activeInviteTitleLevel == nil
    and activeInviteTitleLevelText == nil
    and acceptedInviteSearchResultID == nil
    and pendingTargetDungeonChatEntry == nil
    and pendingAcceptedInviteMapID == nil
  then
    return
  end
  Log(
    "clear_accepted_invite_identity",
    "reason=%s detectedMapID=%s activeInviteLeader=%s activeInviteTitleLevel=%s",
    tostring(reason),
    tostring(detectedMapID),
    tostring(activeInviteLeader),
    tostring(activeInviteTitleLevel)
  )
  detectedMapID = nil
  activeInviteLeader = nil
  activeInviteGroupName = nil
  activeInviteTitleLevel = nil
  activeInviteTitleLevelText = nil
  acceptedInviteSearchResultID = nil
  pendingAcceptedInviteMapID = nil
  lastFiredTargetDungeonChatSearchResultID = nil
  ClearPendingTargetDungeonChat()
  TriggerHighlightUpdate("queue")
end

function LFGDetect.HandleEvent(event, ...)
  if event == "PLAYER_LOGIN" then
    CheckActiveGroup()
  elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
    local searchResultID, newStatus = ...
    HandleApplicationStatus(searchResultID, newStatus)
  elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
    CheckActiveGroup()
  elseif event == "CHALLENGE_MODE_START" then
    -- Key start closes the accepted-invite notice window for the current
    -- group. Keep detectedMapID / active invite identity alive for target
    -- resolution, but do not let late LFG or roster replays re-render the
    -- "Invite accepted" Center Notice.
    acceptedInviteNoticeBlockedUntilReset = true
  elseif event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
    -- The run ended (completed or aborted). The LFG-listing identity that
    -- brought the group together is no longer authoritative for whatever
    -- key the group decides to play next — a pre-formed-group continuation
    -- is not a fresh LFG invite. Letting activeInviteTitleLevel /
    -- activeInviteLeader bleed into the next key surfaces the previous
    -- listing's "+N" on the new dungeon. ClearAllStateImpl (group-leave)
    -- stays the only thing that drops pendingInvites; this clears only the
    -- accepted-invite identity slots.
    ClearAcceptedInviteListingIdentity(event)
  elseif event == "PARTY_LEADER_CHANGED" then
    -- Leader changed: the active-invite identity belongs to the previous
    -- leader's listing. Whoever is now leader holds a fresh authority and
    -- should be resolved via UnitIsGroupLeader instead of the stale name.
    -- Skip when no listing identity was captured to begin with so the
    -- log stays quiet for solo / pre-formed groups.
    --
    -- Initial-convert guard: WoW also fires PARTY_LEADER_CHANGED when the
    -- listing owner forms the freshly accepted group (before the first
    -- GROUP_ROSTER_UPDATE). That PLC is not a handoff — it is the listing
    -- owner taking the lead they already had — and the captured identity
    -- (leader / title-level / searchResultID) is still authoritative.
    -- Once GROUP_ROSTER_UPDATE reports inGroup=true (rosterEstablishedSinceAccept),
    -- any further PLC is treated as a genuine handoff and clears as before.
    if not rosterEstablishedSinceAccept then
      Log(
        "plc_initial_convert_keep",
        "leader=%s titleLevel=%s",
        tostring(activeInviteLeader),
        tostring(activeInviteTitleLevel)
      )
    elseif activeInviteLeader ~= nil or acceptedInviteSearchResultID ~= nil then
      ClearAcceptedInviteListingIdentity("PARTY_LEADER_CHANGED")
    end
  elseif event == "GROUP_ROSTER_UPDATE" then
    local detectedBefore = detectedMapID
    local isInGroup = rawget(_G, "IsInGroup")
    local isInRaid = rawget(_G, "IsInRaid")
    local inGroup = (type(isInGroup) == "function" and isInGroup()) or (type(isInRaid) == "function" and isInRaid())
    local memberCount = GetGroupMemberCount()
    local rosterSignature =
      string.format("%s|%s|%s", tostring(inGroup), tostring(memberCount), tostring(pendingAcceptedInviteMapID))
    local rosterLogFn = rosterSignature == lastRosterUpdateSignature and LogDeep or Log
    lastRosterUpdateSignature = rosterSignature
    rosterLogFn(
      "group_roster_update",
      "inGroup=%s memberCount=%s pendingAccept=%s",
      tostring(inGroup),
      tostring(memberCount),
      tostring(pendingAcceptedInviteMapID)
    )
    if not inGroup then
      local groupMemberCount = GetGroupMemberCount()
      if groupMemberCount and groupMemberCount > 0 then
        pendingAcceptedInviteMapID = nil
        EmitGroupRosterTrace(false, groupMemberCount, detectedBefore)
        return
      end
      if groupMemberCount == 0 then
        if pendingAcceptedInviteMapID then
          EmitGroupRosterTrace(false, groupMemberCount, detectedBefore)
          return
        end
        -- Left all groups — full reset including pending invites.
        ClearAllStateImpl()
        EmitGroupRosterTrace(false, groupMemberCount, detectedBefore)
        return
      end
      ClearAllStateImpl()
      EmitGroupRosterTrace(false, groupMemberCount, detectedBefore)
      return
    end
    local groupMemberCount = GetGroupMemberCount()
    pendingAcceptedInviteMapID = nil
    -- inGroup=true reached: the group has formed. Any future
    -- PARTY_LEADER_CHANGED is a genuine handoff, not the initial convert.
    rosterEstablishedSinceAccept = true
    FlushPendingTargetDungeonChat()
    -- Joined a group: if we have a pending invite but detectedMapID was not
    -- set yet (e.g. GROUP_ROSTER_UPDATE arrived before the inviteaccepted
    -- status event), resolve deterministically — never guess 1-of-N.
    --
    -- ResolveAcceptedPendingInvite asks the WoW LFG API first (status ==
    -- "inviteaccepted") and falls back to the unambiguous single-pending
    -- case. With multiple parallel applications the player can be applied
    -- to several listings at once (different dungeons, different key
    -- levels); the prior `next(pendingInvites)` shortcut could surface a
    -- non-accepted entry, consume it, and leave the real inviteaccepted
    -- handler unable to recover its data.
    if not detectedMapID then
      -- Recovery requires at least one cached pendingInvites table entry.
      -- ClearAllStateImpl wipes pendingInvites alongside detectedMapID /
      -- lastShownNoticeSearchResultID / acceptedInviteNoticeBlockedUntilReset
      -- (post-key-start via checkIfEnteredTargetDungeon, post-leave). If a
      -- late GROUP_ROSTER_UPDATE then re-enters this branch with an empty
      -- cache, ResolveAcceptedPendingInvite would otherwise fall back to a
      -- fresh ResolveInviteEntry via the live LFG API — and the listing's
      -- applicationStatus can still report "inviteaccepted" for a brief
      -- window after the consume, rebuilding the entry from scratch and
      -- re-firing the Center Notice / direct-push chat for an
      -- already-consumed accept cycle. Bailing here keeps the
      -- post-key-start / post-leave reset terminal.
      local hasPendingTableEntry = false
      for _, pendingEntry in pairs(pendingInvites) do
        if type(pendingEntry) == "table" then
          hasPendingTableEntry = true
          break
        end
      end
      local resultID, entry
      if hasPendingTableEntry then
        resultID, entry = ResolveAcceptedPendingInvite()
      end
      if resultID and entry then
        detectedMapID = entry.mapID
        activeInviteLeader = entry.leaderName
        activeInviteGroupName = type(entry.groupName) == "string" and entry.groupName ~= "" and entry.groupName or nil
        activeInviteTitleLevel = ResolveEntryTitleLevel(entry)
        activeInviteTitleLevelText = not activeInviteTitleLevel and ResolveEntryTitleLevelText(entry) or nil
        acceptedInviteSearchResultID = resultID
        pendingInvites[resultID] = nil
        TriggerHighlightUpdate("invite")
        MaybeShowAcceptedInviteNotice(entry, resultID)
        MaybeFireTargetDungeonChatFromAccept(entry, resultID)
      else
        -- "No pending invites at all" means no entry with a table value:
        -- OnInviteDeclined writes `false` sentinels into pendingInvites
        -- (line ~554) which `next()` happily returns as non-nil, so the
        -- recovery fallback to CheckActiveGroup would otherwise be neutralised
        -- after the first decline in a push-lobby spam scenario.
        if not hasPendingTableEntry then
          -- Safe to fall back to own-listing detection. With pending invites
          -- present we defer instead, so a queue-listing mapID cannot leak in
          -- over an unresolved invite.
          CheckActiveGroup()
        end
      end
    end
    EmitGroupRosterTrace(true, groupMemberCount, detectedBefore)
  end
end
