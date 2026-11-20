local _, addonTable = ...

addonTable = addonTable or {}

-- Sync transport: the sync setting, group-channel resolution, prefix
-- registration, the throttled dispatch through ChatThrottleLib and the shared
-- dedupe/cooldown send gate. Stateless: the Sync senders own their cooldown
-- timestamps and dedupe payloads and pass them in.
local SyncTransport = {}
addonTable.SyncTransport = SyncTransport

local function IsSyncEnabled()
  local db = rawget(_G, "IsiLiveDB")
  return not db or db.syncEnabled ~= false
end

local function SafeBooleanCall(fn, ...)
  local ok, result = pcall(fn, ...)
  return ok and not addonTable.Validators.IsSecretValue(result) and result == true
end

-- Numeric fallbacks for the party-category constants. The bundled
-- ChatThrottleLib guards the same call the same way (`LE_PARTY_CATEGORY_INSTANCE
-- or 2`). Without the fallback a missing global skips the instance-group check
-- entirely and the resolver falls through to a PARTY answer -- which Blizzard
-- rejects with ERR_NOT_IN_GROUP while the player is only in an automatic
-- instance group, surfacing as a chat error nobody asked for.
local PARTY_CATEGORY_HOME = 1
local PARTY_CATEGORY_INSTANCE = 2

local function ResolvePartyCategory(globalName, numericFallback)
  local value = rawget(_G, globalName)
  if value == nil then
    return numericFallback
  end
  return value
end

local function IsVerifiedInstanceGroup()
  local isInGroup = rawget(_G, "IsInGroup")
  if type(isInGroup) ~= "function" then
    return false
  end
  local instanceCategory = ResolvePartyCategory("LE_PARTY_CATEGORY_INSTANCE", PARTY_CATEGORY_INSTANCE)
  return SafeBooleanCall(isInGroup, instanceCategory)
end

local function IsVerifiedHomeParty()
  local isInGroup = rawget(_G, "IsInGroup")
  local homeCategory = ResolvePartyCategory("LE_PARTY_CATEGORY_HOME", PARTY_CATEGORY_HOME)
  if type(isInGroup) == "function" and SafeBooleanCall(isInGroup, homeCategory) then
    return true
  end

  local unitInParty = rawget(_G, "UnitInParty")
  if type(unitInParty) == "function" then
    return SafeBooleanCall(unitInParty, "player")
  end

  return type(isInGroup) == "function" and SafeBooleanCall(isInGroup)
end

local function IsVerifiedRaid()
  local isInRaid = rawget(_G, "IsInRaid")
  return type(isInRaid) == "function" and SafeBooleanCall(isInRaid)
end

--- Returns the current group addon sync channel, or nil when not in a group or raid.
-- Priority: raid hard-off, then INSTANCE_CHAT > verified home PARTY.
-- @return string|nil "INSTANCE_CHAT", "PARTY", or nil.
local function GetAddonSyncChannel()
  if IsVerifiedRaid() then
    return nil
  end
  if IsVerifiedInstanceGroup() then
    return "INSTANCE_CHAT"
  end
  if IsVerifiedHomeParty() then
    return "PARTY"
  end
  return nil
end

-- Registers each addon message prefix with C_ChatInfo.
local function RegisterPrefixes(prefixes)
  local chatInfo = rawget(_G, "C_ChatInfo")
  if type(chatInfo) == "table" and type(chatInfo.RegisterAddonMessagePrefix) == "function" then
    for _, prefix in ipairs(prefixes) do
      pcall(chatInfo.RegisterAddonMessagePrefix, prefix)
    end
  end
end

-- Common pre-send guard shared by Send* functions: API availability, sync-enabled,
-- caller visibility, and channel resolution. Returns the outgoing channel string,
-- or nil when the send should be suppressed.
local function ResolveSendChannel(opts)
  local chatInfo = rawget(_G, "C_ChatInfo")
  if type(chatInfo) ~= "table" or type(chatInfo.SendAddonMessage) ~= "function" then
    return nil
  end
  if not IsSyncEnabled() then
    return nil
  end
  if opts.isVisible == false and opts.allowHidden ~= true then
    return nil
  end
  return GetAddonSyncChannel()
end

-- Routes an addon message through ChatThrottleLib when the embedded lib is
-- present (priority-queued, fair-shared with other addons). Falls back to
-- raw C_ChatInfo.SendAddonMessage if the lib is unavailable. Returns true
-- if the message was accepted for dispatch (either enqueued by CTL or
-- handed to Blizzard), false if it was rejected outright. CTL reports a drop
-- through its callback: synchronously for an unavailable channel, later for a
-- queued message; onDropped covers the later case. CTL discards the Blizzard
-- send result, so a server rejection stays invisible on this path.
local function DispatchAddonMessage(prefix, payload, channel, priority, target, onDropped)
  local ctl = rawget(_G, "ChatThrottleLib")
  if ctl and type(ctl.SendAddonMessage) == "function" then
    local accepted = true
    local function OnCtlResult(_, didSend)
      if didSend == false then
        accepted = false
        if onDropped then
          onDropped()
        end
      end
    end
    local ok =
      pcall(ctl.SendAddonMessage, ctl, priority or "NORMAL", prefix, payload, channel, target, nil, OnCtlResult)
    return ok and accepted
  end
  local chatInfo = rawget(_G, "C_ChatInfo")
  if type(chatInfo) == "table" and type(chatInfo.SendAddonMessage) == "function" then
    local ok, result = pcall(chatInfo.SendAddonMessage, prefix, payload, channel, target)
    -- Enum.SendAddonMessageResult.Success is 0. Every other numeric result
    -- is an explicit rejection (including throttling), not a Lua exception.
    return ok and result ~= false and (type(result) ~= "number" or result == 0)
  end
  return false
end

-- Shared dedupe/cooldown gate for Send* functions that share the pattern
-- "skip if identical payload and still in cooldown window".
-- Returns (blocked:boolean, now:number). onBlocked, if provided, is called with
-- ("unchanged") or ("cooldown", remainSeconds) for deep-trace logging.
local function IsBlockedBySendGate(opts, lastPayload, lastAt, dedupePayload, cooldown, onBlocked)
  local getTimeFn = rawget(_G, "GetTime")
  local now = type(getTimeFn) == "function" and getTimeFn() or 0
  if opts.force then
    return false, now
  end
  if opts.onlyIfChanged == true and dedupePayload == lastPayload then
    if onBlocked then
      onBlocked("unchanged", 0)
    end
    return true, now
  end
  if dedupePayload == lastPayload and (now - lastAt) < cooldown then
    if onBlocked then
      onBlocked("cooldown", cooldown - (now - lastAt))
    end
    return true, now
  end
  return false, now
end

-- C_ChatInfo.InChatMessagingLockdown() (12.0, warcraft.wiki.gg): true while
-- the client restricts addon chat. Missing API, error or a secret answer count
-- as "not locked": the send is attempted as before.
local function IsAddonChatLockedDown()
  local chatInfo = rawget(_G, "C_ChatInfo")
  local inLockdown = type(chatInfo) == "table" and chatInfo.InChatMessagingLockdown or nil
  if type(inLockdown) ~= "function" then
    return false
  end
  local ok, restricted = pcall(inLockdown)
  return ok and not addonTable.Validators.IsSecretValue(restricted) and restricted == true
end

SyncTransport.IsSyncEnabled = IsSyncEnabled
SyncTransport.SafeBooleanCall = SafeBooleanCall
SyncTransport.GetAddonSyncChannel = GetAddonSyncChannel
SyncTransport.RegisterPrefixes = RegisterPrefixes
SyncTransport.ResolveSendChannel = ResolveSendChannel
SyncTransport.DispatchAddonMessage = DispatchAddonMessage
SyncTransport.IsBlockedBySendGate = IsBlockedBySendGate
SyncTransport.IsAddonChatLockedDown = IsAddonChatLockedDown
