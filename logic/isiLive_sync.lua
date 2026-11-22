local _, addonTable = ...

addonTable = addonTable or {}

-- Sync facade: the public addonTable.Sync surface. Owns the outgoing message
-- senders with their cooldown and dedupe state, the trace loggers and the
-- canonical peer key. Wire encoding lives in logic/isiLive_sync_codec.lua,
-- received peer data in logic/isiLive_sync_peer_state.lua, channel and
-- dispatch in logic/isiLive_sync_transport.lua and the receive parser in
-- logic/isiLive_sync_receive.lua.
local Sync = {}
addonTable.Sync = Sync
local StringUtils = addonTable.StringUtils
local SyncCodec = addonTable.SyncCodec
local SyncTransport = addonTable.SyncTransport
local Unpack = rawget(_G, "unpack") or rawget(table, "unpack")

local ISILIVE_SYNC_PREFIX = "ISILIVE"
local LIBKEYSTONE_SYNC_PREFIX = "LibKS"
local LIBKEYSTONE_SOURCE = "libks"
local ISILIVE_HELLO_COOLDOWN = 8
local ISILIVE_KEY_COOLDOWN = 5
local ISILIVE_STATS_COOLDOWN = 5
local ISILIVE_TARGET_COOLDOWN = 5
local ISILIVE_REFRESH_REQUEST_COOLDOWN = 1
local ISILIVE_SHAREKEYS_CD_COOLDOWN = 1
local ISILIVE_SHAREKEYS_CD_MAX_SECONDS = 30
local LIBKEYSTONE_REQUEST_COOLDOWN = 3
local POWER_INFUSION_SPELL_ID = addonTable.SpellManifest.powerInfusion

local ToFiniteNumber = SyncCodec.ToFiniteNumber
local FormatBytes = SyncCodec.FormatBytes
local GetSyncTimestamp = SyncCodec.GetSyncTimestamp
local NormalizeSyncSource = SyncCodec.NormalizeSyncSource
local NormalizeSyncProtocolVersion = SyncCodec.NormalizeSyncProtocolVersion
local NormalizeKeyPayload = SyncCodec.NormalizeKeyPayload
local NormalizeStatsPayload = SyncCodec.NormalizeStatsPayload
local NormalizeDpsPayload = SyncCodec.NormalizeDpsPayload
local NormalizeRunKicksSuffix = SyncCodec.NormalizeRunKicksSuffix
local NormalizeRunKicksMissedSuffix = SyncCodec.NormalizeRunKicksMissedSuffix
local NormalizeLocPayload = SyncCodec.NormalizeLocPayload
local NormalizeTargetPayload = SyncCodec.NormalizeTargetPayload
local EncodeKickSpellSuffix = SyncCodec.EncodeKickSpellSuffix
local EncodeKickExtrasSuffix = SyncCodec.EncodeKickExtrasSuffix
local EncodeDefPayload = SyncCodec.EncodeDefPayload
local IsSyncEnabled = SyncTransport.IsSyncEnabled
local SafeBooleanCall = SyncTransport.SafeBooleanCall
local ResolveSendChannel = SyncTransport.ResolveSendChannel
local DispatchAddonMessage = SyncTransport.DispatchAddonMessage
local IsBlockedBySendGate = SyncTransport.IsBlockedBySendGate
local IsAddonChatLockedDown = SyncTransport.IsAddonChatLockedDown

-- Architecture note: Module-level singleton state (intentional deviation from CreateController pattern).
--
-- Rationale: The addon runs exactly one Sync instance per session. Cooldown timestamps
-- (lastIsiLive*At) are addon-wide send rate-limiters. Payload dedup trackers (last*PayloadSent)
-- suppress identical re-sends within the same session. Received peer data lives in the one
-- peer-state store created below (logic/isiLive_sync_peer_state.lua) and must survive across
-- controller re-creations during the same session.
--
-- Reset contract: ClearKnownUsers() resets ALL mutable state (cooldowns, dedup trackers,
-- and the peer-state store) and is called by isiLive_controller_wiring.lua and isiLive_keysync.lua
-- on group disband. This ensures a clean slate when the player joins a new group.
local lastIsiLiveHelloAt = 0
local lastIsiLiveKeyAt = 0
local lastIsiLiveStatsAt = 0
local lastIsiLiveDpsAt = 0
local lastIsiLiveLocAt = 0
local lastIsiLiveTargetAt = 0
local lastIsiLiveKickAt = 0
local lastIsiLiveRefreshRequestAt = 0
local lastIsiLiveShareKeysCdAt = 0
local lastLibKeystoneRequestAt = 0
local lastKeyPayloadSent = nil
local lastStatsPayloadSent = nil
local lastDpsPayloadSent = nil
local lastLocPayloadSent = nil
local lastTargetPayloadSent = nil
local lastKickPayloadSent = nil
-- send_kick trace state: the kick poll calls SendKick every 0.5 s while a
-- cooldown runs, so the trace only records a change of what it reports (see
-- TraceKickSend). kickSendLockedDown remembers a send skipped because addon
-- chat was locked down, so the first send after the lockdown bypasses the
-- dedupe gate.
local lastKickTrace = {}
local kickTraceRepeats = 0
local kickSendLockedDown = false
-- DEF bucket (rule 267): last send time, dedupe key (payload without the
-- remain seconds) and the lockdown flag that forces the first send after it.
local ISILIVE_DEF_GATE_SECONDS = 1
local ISILIVE_DEF_HEARTBEAT_SECONDS = 15
local lastIsiLiveDefAt = nil
local lastDefDedupeKey = nil
local defSendLockedDown = false
local NORMALIZED_KEY_CACHE_LIMIT = 256
local normalizedKeyCache = {}
local normalizedKeyCacheSize = 0
local syncDebugTrace = nil
local syncDebugTraceDeep = nil
-- Optional "would this level be recorded" checks paired with the trace
-- loggers. The runtime logger is always wired, but recording is off by
-- default; without the check every sync message built an argument table and
-- a closure only for the logger to drop them.
local syncTraceActive = nil
local syncDeepTraceActive = nil

--- Sets the trace logger for sync send/receive events.
-- @param fn function|nil Receives a lazy builder function; call it to materialise the string. Pass nil to disable.
-- @param isActive function|nil Optional check; when it returns false the
--   message is neither built nor handed to fn.
function Sync.SetTraceLogger(fn, isActive)
  syncDebugTrace = type(fn) == "function" and fn or nil
  syncTraceActive = type(isActive) == "function" and isActive or nil
end

--- Sets the deep-trace logger for high-frequency suppression events (e.g. cooldown blocks).
-- @param fn function|nil Same lazy-builder contract as SetTraceLogger. Pass nil to disable.
-- @param isActive function|nil Same contract as for SetTraceLogger.
function Sync.SetDeepTraceLogger(fn, isActive)
  syncDebugTraceDeep = type(fn) == "function" and fn or nil
  syncDeepTraceActive = type(isActive) == "function" and isActive or nil
end

local function IsTraceLoggerActive(traceFn)
  local isActive = nil
  if traceFn == syncDebugTrace then
    isActive = syncTraceActive
  elseif traceFn == syncDebugTraceDeep then
    isActive = syncDeepTraceActive
  end
  return isActive == nil or isActive() == true
end

local function SyncLogInternal(traceFn, event, formatText, ...)
  if not traceFn or not IsTraceLoggerActive(traceFn) then
    return
  end
  local argCount = select("#", ...)
  local args = { ... }
  traceFn(function()
    local data = formatText
    if type(formatText) == "function" then
      data = formatText()
    elseif argCount > 0 then
      data = string.format(tostring(formatText or ""), Unpack(args))
    end
    return string.format("[SYNC] %s %s", event, data or "")
  end)
end

local function SyncLog(event, formatText, ...)
  SyncLogInternal(syncDebugTrace, event, formatText, ...)
end

local function SyncLogDeep(event, formatText, ...)
  SyncLogInternal(syncDebugTraceDeep, event, formatText, ...)
end

-- True when a SyncLog / SyncLogDeep line would be recorded. Lets hot callers
-- skip building tostring() arguments that the logger would discard.
local function IsSyncLogActive()
  return syncDebugTrace ~= nil and IsTraceLoggerActive(syncDebugTrace)
end

local function IsSyncLogDeepActive()
  return syncDebugTraceDeep ~= nil and IsTraceLoggerActive(syncDebugTraceDeep)
end

--- Normalizes a name/realm pair into a stable, case-insensitive lookup key.
-- Handles combined "Name-Realm" form and falls back to GetRealmName() when realm is empty.
-- Realm normalization strips spaces, dashes, dots, parens, and quotes.
-- @param name string Player name, or "Name-Realm" combined form.
-- @param realm string|nil Realm name; optional when name already contains "-Realm".
-- @return string Lowercase key of the form "name-realm".
-- @see StringUtils.NormalizeRealmName
-- Realm normalization is identical to NormalizeName() in isiLive_stats.lua:
-- both strip spaces, dashes, dots, parens, and quotes from the realm.
function Sync.NormalizePlayerKey(name, realm)
  local n = name and tostring(name) or ""
  local r = realm and tostring(realm) or ""

  if r == "" and string.find(n, "-", 1, true) then
    local dash = string.find(n, "-", 1, true)
    if dash then
      r = string.sub(n, dash + 1)
      n = string.sub(n, 1, dash - 1)
    end
  end

  if r == "" then
    local getRealmName = rawget(_G, "GetRealmName")
    r = type(getRealmName) == "function" and getRealmName() or ""
  end

  n = tostring(n)
  r = tostring(r)
  -- One received sync message normalizes the same few players ~35 times
  -- (sender, self, alias registration and every roster backfill lookup), so
  -- the key is cached per resolved (name, realm) pair. The cap bounds a long
  -- session; dropping the cache only costs a recomputation per player.
  local byRealm = normalizedKeyCache[n]
  local cachedKey = byRealm and byRealm[r]
  if cachedKey then
    return cachedKey
  end

  -- Strict normalization via shared StringUtils:
  -- Name: strip all whitespace; Realm: strip spaces/dashes/dots/parens/quotes
  local n_clean = StringUtils.StripWhitespace(n)
  local r_clean = StringUtils.NormalizeRealmName(r)
  local key = string.lower(n_clean .. "-" .. r_clean)
  if normalizedKeyCacheSize >= NORMALIZED_KEY_CACHE_LIMIT then
    normalizedKeyCache = {}
    normalizedKeyCacheSize = 0
  end
  if not normalizedKeyCache[n] then
    normalizedKeyCache[n] = {}
  end
  normalizedKeyCache[n][r] = key
  normalizedKeyCacheSize = normalizedKeyCacheSize + 1
  return key
end

--- True for the two addon-message prefixes isiLive processes (ISILIVE and
-- LibKS). Lets the receive path drop foreign addon traffic before any work.
-- @param prefix string
-- @return boolean
function Sync.IsSyncPrefix(prefix)
  return prefix == ISILIVE_SYNC_PREFIX or prefix == LIBKEYSTONE_SYNC_PREFIX
end

--- Returns the ISILIVE addon message prefix used for all sync payloads.
-- @return string
function Sync.GetPrefix()
  return ISILIVE_SYNC_PREFIX
end

--- Returns the current sync protocol version number (currently 2).
-- @return number
function Sync.GetProtocolVersion()
  return SyncCodec.PROTOCOL_VERSION
end

-- Received peer data (known users, HELLO/ACK, KEY/STATS/DPS/LOC/TARGET,
-- kick state and run kicks). The store keys peers through the facade, so a
-- later NormalizePlayerKey change applies to every bucket.
local peerState = addonTable.SyncPeerState
peerState.Bind({
  normalizePlayerKey = function(name, realm)
    return Sync.NormalizePlayerKey(name, realm)
  end,
})
for _, name in ipairs({
  "MarkUser",
  "IsUserKnown",
  "IsUnitKnown",
  "SetPlayerHelloInfo",
  "SetPlayerHelloAckInfo",
  "GetPlayerHelloInfo",
  "HasPeerReported",
  "SetPlayerKeyInfo",
  "GetPlayerKeyInfo",
  "SetPlayerStatsInfo",
  "GetPlayerStatsInfo",
  "SetPlayerDpsInfo",
  "GetPlayerDpsInfo",
  "SetPlayerRunKicksCast",
  "GetPlayerRunKicksCast",
  "SetPlayerKickInfo",
  "GetPlayerKickInfo",
  "ClearPlayerKickInfo",
  "GetKickInfoGeneration",
  "SetPlayerLocInfo",
  "GetPlayerLocInfo",
  "SetPlayerTargetInfo",
  "GetPlayerTargetInfo",
  "GetPlayerSyncSummary",
}) do
  Sync[name] = assert(peerState[name], "SyncPeerState is missing " .. name)
end

--- Returns the current group addon sync channel, or nil when not in a group or raid.
-- Priority: raid hard-off, then INSTANCE_CHAT > verified home PARTY.
-- @return string|nil "INSTANCE_CHAT", "PARTY", or nil.
Sync.GetAddonSyncChannel = SyncTransport.GetAddonSyncChannel

--- Registers ISILIVE and LibKS addon message prefixes with C_ChatInfo.
-- Must be called once (on PLAYER_LOGIN) before addon messages can be received.
function Sync.RegisterPrefix()
  SyncTransport.RegisterPrefixes({ ISILIVE_SYNC_PREFIX, LIBKEYSTONE_SYNC_PREFIX })
end

--- Resets all session-wide sync state: known users, per-player caches, send cooldowns, and dedup trackers.
-- Called on group disband to ensure a clean slate for the next group.
-- @see isiLive_controller_wiring.lua, isiLive_keysync.lua
function Sync.ClearKnownUsers()
  peerState.Reset()
  lastIsiLiveHelloAt = 0
  lastIsiLiveKeyAt = 0
  lastIsiLiveStatsAt = 0
  lastIsiLiveDpsAt = 0
  lastIsiLiveLocAt = 0
  lastIsiLiveTargetAt = 0
  lastIsiLiveKickAt = 0
  lastIsiLiveRefreshRequestAt = 0
  lastIsiLiveShareKeysCdAt = 0
  lastLibKeystoneRequestAt = 0
  lastKeyPayloadSent = nil
  lastStatsPayloadSent = nil
  lastDpsPayloadSent = nil
  lastLocPayloadSent = nil
  lastTargetPayloadSent = nil
  lastKickPayloadSent = nil
  lastKickTrace = {}
  kickTraceRepeats = 0
  lastIsiLiveDefAt = nil
  lastDefDedupeKey = nil
  defSendLockedDown = false
  local defensiveStore = addonTable.DefensiveStore
  if type(defensiveStore) == "table" and type(defensiveStore.ClearPeers) == "function" then
    defensiveStore.ClearPeers()
  end
end

--- Whispers the HELLO acknowledgement to one peer.
-- Honors the sync setting like every other sender and shares the throttled
-- dispatch path, so a burst of HELLOs cannot bypass ChatThrottleLib.
-- @param target string Sender of the HELLO ("Name-Realm").
-- @param versionRaw string Local addon version.
-- @return boolean true if the message was accepted for dispatch.
function Sync.SendAck(target, versionRaw)
  if type(target) ~= "string" or target == "" then
    return false
  end
  local chatInfo = rawget(_G, "C_ChatInfo")
  if type(chatInfo) ~= "table" or type(chatInfo.SendAddonMessage) ~= "function" then
    return false
  end
  if not IsSyncEnabled() then
    return false
  end
  local sent =
    DispatchAddonMessage(ISILIVE_SYNC_PREFIX, "ACK:" .. tostring(versionRaw or ""), "WHISPER", "NORMAL", target)
  SyncLog("send_ack", "target=%s sent=%s", target, tostring(sent))
  return sent == true
end

--- Broadcasts a HELLO announcement to the group.
-- Rate-limited by ISILIVE_HELLO_COOLDOWN (8 s). Suppressed when isVisible==false unless allowHidden==true.
-- @param opts table {version:string, protocolVersion:number, source:string,
--   isVisible:boolean, allowHidden:boolean, force:boolean}
function Sync.SendHello(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local getTimeFn = rawget(_G, "GetTime")
  local now = type(getTimeFn) == "function" and getTimeFn() or 0
  if not opts.force and (now - lastIsiLiveHelloAt) < ISILIVE_HELLO_COOLDOWN then
    return
  end

  local payload = string.format(
    "HELLO:%s:%d:%d:%s",
    tostring(opts.version or "?"),
    NormalizeSyncProtocolVersion(opts.protocolVersion),
    GetSyncTimestamp() or 0,
    NormalizeSyncSource(opts.source) or "local"
  )
  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "NORMAL")
  if sent == true then
    lastIsiLiveHelloAt = now
  end
  SyncLog(
    "send_hello",
    "version=%s channel=%s source=%s sent=%s",
    tostring(opts.version or "?"),
    tostring(channel),
    tostring(opts.source or "local"),
    tostring(sent)
  )
end

--- Broadcasts the local player's keystone to the group.
-- Deduplicated (onlyIfChanged) and rate-limited by ISILIVE_KEY_COOLDOWN (5 s).
-- @param opts table {mapID:number, level:number, capturedAt:number, source:string,
--   isVisible:boolean, allowHidden:boolean, force:boolean, onlyIfChanged:boolean}
function Sync.SendKey(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local payload, numericMapID, numericLevel = NormalizeKeyPayload(opts.mapID, opts.level, opts.capturedAt, opts.source)
  local dedupePayload = string.format("KEY:%d:%d", tonumber(numericMapID) or 0, tonumber(numericLevel) or 0)
  local blocked, now = IsBlockedBySendGate(
    opts,
    lastKeyPayloadSent,
    lastIsiLiveKeyAt,
    dedupePayload,
    ISILIVE_KEY_COOLDOWN,
    function(reason, remain)
      if reason == "unchanged" then
        SyncLogDeep(
          "send_key_blocked",
          "reason=unchanged mapID=%s level=%s",
          tostring(numericMapID),
          tostring(numericLevel)
        )
      else
        SyncLogDeep(
          "send_key_blocked",
          "reason=cooldown mapID=%s level=%s remain=%.1f",
          tostring(numericMapID),
          tostring(numericLevel),
          remain
        )
      end
    end
  )
  if blocked then
    return
  end

  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "NORMAL", nil, function()
    if lastKeyPayloadSent == dedupePayload then
      lastKeyPayloadSent = nil
    end
  end)
  if sent == true then
    lastIsiLiveKeyAt = now
    lastKeyPayloadSent = dedupePayload
  end
  SyncLog(
    "send_key",
    "mapID=%s level=%s channel=%s sent=%s",
    tostring(numericMapID),
    tostring(numericLevel),
    tostring(channel),
    tostring(sent)
  )
end

--- Broadcasts the local player's stats (spec/ilvl/rio) to the group.
-- Deduplicated and rate-limited by ISILIVE_STATS_COOLDOWN (5 s).
-- @param opts table {specID:number, ilvl:number, rio:number, capturedAt:number,
--   source:string, isVisible:boolean, allowHidden:boolean, force:boolean, onlyIfChanged:boolean}
function Sync.SendStats(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local payload, numericSpecID, numericIlvl, numericRio =
    NormalizeStatsPayload(opts.specID, opts.ilvl, opts.rio, opts.capturedAt, opts.source)
  local dedupePayload =
    string.format("STATS:%d:%d:%d", tonumber(numericSpecID) or 0, tonumber(numericIlvl) or 0, tonumber(numericRio) or 0)
  local blocked, now =
    IsBlockedBySendGate(opts, lastStatsPayloadSent, lastIsiLiveStatsAt, dedupePayload, ISILIVE_STATS_COOLDOWN, nil)
  if blocked then
    return
  end

  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "BULK", nil, function()
    if lastStatsPayloadSent == dedupePayload then
      lastStatsPayloadSent = nil
    end
  end)
  if sent == true then
    lastIsiLiveStatsAt = now
    lastStatsPayloadSent = dedupePayload
  end
  SyncLog(
    "send_stats",
    "specID=%s ilvl=%s rio=%s channel=%s sent=%s",
    tostring(numericSpecID),
    tostring(numericIlvl),
    tostring(numericRio),
    tostring(channel),
    tostring(sent)
  )
end

--- Broadcasts the local player's last-run DPS to the group, plus the own
-- interrupt casts of that run as the tagged KC suffix when known (rule 238)
-- and the own missed kicks as the KM suffix after it (rule 240).
-- Deduplicated and rate-limited by ISILIVE_STATS_COOLDOWN (5 s).
-- @param opts table {dps:number, capturedAt:number, source:string,
--   kicksCast:number|nil, kicksMapID:number|nil, kicksLevel:number|nil,
--   kicksMissed:number|nil, isVisible:boolean, allowHidden:boolean,
--   force:boolean, onlyIfChanged:boolean}
function Sync.SendDps(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local payload, numericDps = NormalizeDpsPayload(opts.dps, opts.capturedAt, opts.source)
  local kicksSuffix, numericCast = NormalizeRunKicksSuffix(opts.kicksCast, opts.kicksMapID, opts.kicksLevel)
  kicksSuffix = kicksSuffix .. NormalizeRunKicksMissedSuffix(opts.kicksMissed, numericCast)
  payload = payload .. kicksSuffix
  local dedupePayload = string.format("DPS:%d%s", tonumber(numericDps) or 0, kicksSuffix)
  local blocked, now =
    IsBlockedBySendGate(opts, lastDpsPayloadSent, lastIsiLiveDpsAt, dedupePayload, ISILIVE_STATS_COOLDOWN, nil)
  if blocked then
    return
  end

  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "BULK", nil, function()
    if lastDpsPayloadSent == dedupePayload then
      lastDpsPayloadSent = nil
    end
  end)
  if sent == true then
    lastIsiLiveDpsAt = now
    lastDpsPayloadSent = dedupePayload
  end
  SyncLog(
    "send_dps",
    "dps=%s kicks=%s channel=%s sent=%s",
    tostring(numericDps),
    kicksSuffix ~= "" and kicksSuffix or "-",
    tostring(channel),
    tostring(sent)
  )
end

--- Sends the update-notice version ping ("VER:<version>") to the guild.
-- Honors the sync setting, needs a guild and stays silent during the 12.0
-- addon chat lockdown. Bulk priority: the ping is never time-critical.
-- @param versionRaw string Local addon version.
-- @return boolean true if the message was accepted for dispatch.
function Sync.SendGuildVersion(versionRaw)
  if type(versionRaw) ~= "string" or versionRaw == "" then
    return false
  end
  local chatInfo = rawget(_G, "C_ChatInfo")
  if type(chatInfo) ~= "table" or type(chatInfo.SendAddonMessage) ~= "function" then
    return false
  end
  if not IsSyncEnabled() then
    return false
  end
  local isInGuild = rawget(_G, "IsInGuild")
  if type(isInGuild) ~= "function" or not SafeBooleanCall(isInGuild) then
    return false
  end
  if IsAddonChatLockedDown() then
    return false
  end
  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, "VER:" .. versionRaw, "GUILD", "BULK")
  SyncLog("send_guild_version", "version=%s sent=%s", versionRaw, tostring(sent))
  return sent == true
end

-- Traces a SendKick outcome only when what it reports changes: hasKick,
-- onCooldown, the cooldown running or done (remain > 0), the channel or the
-- send result ("true", "false", "lockdown"). The running remain itself is not
-- part of it -- it changes every second. The next logged line carries the
-- number of identical outcomes it stood for (repeats). While addon chat stays
-- locked down nothing goes out, so a lockdown is one line however often the
-- cooldown state flips under it (log 2026-11-14: ~60 lockdown lines per key,
-- one per cooldown change).
local function TraceKickSend(hasKick, onCooldown, remain, channel, sent)
  local trace = lastKickTrace
  local running = remain > 0
  if sent == "lockdown" and trace.sent == "lockdown" then
    kickTraceRepeats = kickTraceRepeats + 1
    return
  end
  if
    trace.hasKick == hasKick
    and trace.onCooldown == onCooldown
    and trace.running == running
    and trace.channel == channel
    and trace.sent == sent
  then
    kickTraceRepeats = kickTraceRepeats + 1
    return
  end
  lastKickTrace = { hasKick = hasKick, onCooldown = onCooldown, running = running, channel = channel, sent = sent }
  local repeats = kickTraceRepeats
  kickTraceRepeats = 0
  SyncLog(
    "send_kick",
    "hasKick=%s onCooldown=%s remain=%s channel=%s sent=%s repeats=%d",
    tostring(hasKick),
    tostring(onCooldown),
    tostring(remain),
    tostring(channel),
    tostring(sent),
    repeats
  )
end

--- Broadcasts the local player's kick/interrupt availability to the group.
-- Rate-limited to 1 s; deduplicated by payload string. While addon chat is
-- locked down nothing is dispatched; the first send after it bypasses the
-- dedupe gate so peers converge at once.
-- @param opts table {hasKick:boolean, onCooldown:boolean, cooldownRemain:number, spellID:number|nil, force:boolean}
function Sync.SendKick(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local hasKick = opts.hasKick
  if hasKick ~= true and hasKick ~= false then
    return
  end
  local onCooldown = opts.onCooldown
  if onCooldown ~= true and onCooldown ~= false then
    return
  end
  local cooldownRemain = ToFiniteNumber(opts.cooldownRemain)
  if hasKick == true then
    if cooldownRemain == nil or cooldownRemain < 0 then
      return
    end
  elseif onCooldown == true then
    return
  end
  local encodedHasKick = hasKick == true
  local encodedOnCooldown = encodedHasKick and (onCooldown == true and 1 or 0) or -1
  local remain = 0
  if encodedHasKick and cooldownRemain then
    remain = math.ceil(cooldownRemain)
  end
  local extrasSuffix = EncodeKickExtrasSuffix(opts.extras)
  local spellSuffix = EncodeKickSpellSuffix(opts.spellID, encodedHasKick)
  local payload = string.format("KICK:%d:%d%s%s", encodedOnCooldown, remain, extrasSuffix, spellSuffix)
  if IsAddonChatLockedDown() then
    kickSendLockedDown = true
    TraceKickSend(hasKick, onCooldown, remain, channel, "lockdown")
    return false
  end
  local gateOpts = kickSendLockedDown and { force = true } or opts
  local blocked, now = IsBlockedBySendGate(gateOpts, lastKickPayloadSent, lastIsiLiveKickAt, payload, 1, nil)
  if blocked then
    return false
  end
  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "ALERT")
  if sent == true then
    lastIsiLiveKickAt = now
    lastKickPayloadSent = payload
    kickSendLockedDown = false
  end
  TraceKickSend(hasKick, onCooldown, remain, channel, tostring(sent == true))
  return sent == true
end

--- Broadcasts the own defensive cooldowns (DEF bucket, rule 267).
-- Event-driven: a changed state (spell, state or charges; the remain seconds
-- alone are no change) goes out at most once per second; an unchanged state
-- is repeated as a heartbeat every 15 s. `force` (REQSYNC answer, explicit
-- resend) skips both gates. While addon chat is locked down nothing is
-- dispatched; the first send after it is forced. NORMAL priority.
-- The caller owns the feature gates (settings, KEY profile, rule 109).
-- @param opts table {entries:table, force:boolean}
-- @return boolean true when the payload was accepted for dispatch.
function Sync.SendDef(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return false
  end
  local payload, dedupeKey = EncodeDefPayload(opts.entries)
  if not payload then
    SyncLog("send_def", "channel=%s sent=invalid", tostring(channel))
    return false
  end
  if IsAddonChatLockedDown() then
    if not defSendLockedDown then
      SyncLog("send_def", "channel=%s sent=lockdown", tostring(channel))
    end
    defSendLockedDown = true
    return false
  end
  local getTimeFn = rawget(_G, "GetTime")
  local now = type(getTimeFn) == "function" and getTimeFn() or 0
  local force = opts.force == true or defSendLockedDown or lastIsiLiveDefAt == nil
  if not force then
    local since = now - lastIsiLiveDefAt
    if since < ISILIVE_DEF_GATE_SECONDS then
      return false
    end
    if dedupeKey == lastDefDedupeKey and since < ISILIVE_DEF_HEARTBEAT_SECONDS then
      return false
    end
  end
  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "NORMAL")
  if sent == true then
    lastIsiLiveDefAt = now
    lastDefDedupeKey = dedupeKey
    defSendLockedDown = false
  end
  SyncLog("send_def", "channel=%s bytes=%d sent=%s", tostring(channel), #payload, tostring(sent == true))
  return sent == true
end

-- Received DEF entries go to the defensive store, which applies its own
-- intake gate (settings, KEY profile, raid; wired by the factory).
local function ApplyDefPayload(senderKey, entries, receivedAt)
  local defensiveStore = addonTable.DefensiveStore
  if type(defensiveStore) ~= "table" or type(defensiveStore.SetPeer) ~= "function" then
    return false
  end
  return defensiveStore.SetPeer(senderKey, entries, receivedAt) == true
end

--- Broadcasts the local player's current location to the group: legacy
-- UiMapID in field 2 plus the party instance ID in the "IN" suffix (rule 194).
-- Deduplicated and rate-limited by ISILIVE_STATS_COOLDOWN (5 s).
-- @param opts table {mapID:number, instanceID:number, capturedAt:number, source:string,
--   isVisible:boolean, allowHidden:boolean, force:boolean, onlyIfChanged:boolean}
function Sync.SendLoc(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local payload, numericMapID, _, _, numericInstanceID =
    NormalizeLocPayload(opts.mapID, opts.capturedAt, opts.source, opts.instanceID)
  local dedupePayload = string.format("LOC:%d:IN:%d", numericMapID or 0, numericInstanceID or 0)
  local blocked, now =
    IsBlockedBySendGate(opts, lastLocPayloadSent, lastIsiLiveLocAt, dedupePayload, ISILIVE_STATS_COOLDOWN, nil)
  if blocked then
    return
  end

  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "BULK", nil, function()
    if lastLocPayloadSent == dedupePayload then
      lastLocPayloadSent = nil
    end
  end)
  if sent == true then
    lastIsiLiveLocAt = now
    lastLocPayloadSent = dedupePayload
  end
  SyncLog(
    "send_loc",
    "mapID=%s instanceID=%s channel=%s sent=%s",
    tostring(numericMapID),
    tostring(numericInstanceID),
    tostring(channel),
    tostring(sent)
  )
end

--- Broadcasts the local player's target keystone (desired dungeon/level) to the group.
-- Deduplicated and rate-limited by ISILIVE_TARGET_COOLDOWN (5 s).
-- @param opts table {mapID:number, level:number, levelText:string, capturedAt:number, source:string,
--   isVisible:boolean, allowHidden:boolean, force:boolean}
function Sync.SendTarget(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local payload, numericMapID, numericLevel, _, _, normalizedLevelText =
    NormalizeTargetPayload(opts.mapID, opts.level, opts.capturedAt, opts.source, opts.levelText)
  local dedupePayload = string.format(
    "TARGET:%d:%d:%s",
    tonumber(numericMapID) or 0,
    tonumber(numericLevel) or 0,
    normalizedLevelText or ""
  )
  local blocked, now =
    IsBlockedBySendGate(opts, lastTargetPayloadSent, lastIsiLiveTargetAt, dedupePayload, ISILIVE_TARGET_COOLDOWN, nil)
  if blocked then
    return
  end

  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "NORMAL", nil, function()
    if lastTargetPayloadSent == dedupePayload then
      lastTargetPayloadSent = nil
    end
  end)
  if sent == true then
    lastIsiLiveTargetAt = now
    lastTargetPayloadSent = dedupePayload
  end
  SyncLog(
    "send_target",
    "mapID=%s level=%s levelText=%s channel=%s sent=%s",
    tostring(numericMapID),
    tostring(numericLevel),
    tostring(normalizedLevelText),
    tostring(channel),
    tostring(sent)
  )
end

-- GetUnitName(unit, true) omits the realm for players on the local realm, the
-- local player included. Announce payloads carry the realm explicitly so
-- receivers on another realm -- including builds older than 0.9.454, which
-- resolve a bare name against their own realm -- match the caster to the
-- sender.
local function QualifyAnnounceName(name)
  if string.find(name, "-", 1, true) then
    return name
  end
  local getRealm = rawget(_G, "GetNormalizedRealmName")
  local ok, realm = false, nil
  if type(getRealm) == "function" then
    ok, realm = pcall(getRealm)
  end
  if not ok or type(realm) ~= "string" or realm == "" then
    getRealm = rawget(_G, "GetRealmName")
    ok, realm = false, nil
    if type(getRealm) == "function" then
      ok, realm = pcall(getRealm)
    end
  end
  if not ok or type(realm) ~= "string" or realm == "" or realm:find("[:|%c]") then
    return name
  end
  return name .. "-" .. realm
end

--- Broadcasts a BR / Bloodlust combat announcement to all isiLive peers.
-- Sender-side dedup is handled upstream by combat_events.HandleUnitSpellcastSucceeded
-- (per source+spellID, 3 s window), so this function does not gate again. Suppressed
-- when no group channel is available; isVisible / allowHidden semantics follow
-- ResolveSendChannel.
-- @param opts table {kind:"BR"|"LUST", caster:string, spellID:number,
--   isVisible:boolean, allowHidden:boolean}
function Sync.SendCombatAnnounce(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end
  local kind = tostring(opts.kind or "")
  if kind ~= "BR" and kind ~= "LUST" then
    return
  end
  local caster = tostring(opts.caster or "")
  if caster == "" or string.find(caster, ":", 1, true) then
    return
  end
  caster = QualifyAnnounceName(caster)
  local spellID = ToFiniteNumber(opts.spellID) or 0
  local payload = string.format("BRLUST:%s:%s:%d", kind, caster, spellID)
  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "NORMAL")
  SyncLog(
    "send_combat_announce",
    "kind=%s caster=%s spellID=%d channel=%s sent=%s",
    kind,
    caster,
    spellID,
    tostring(channel),
    tostring(sent)
  )
end

--- Broadcasts a verified Power Infusion announcement to all isiLive peers.
-- Sender-side verification is owned by PiTracker: this function only transports
-- already resolved caster/recipient names and does not infer missing data.
-- @param opts table {caster:string, recipient:string, spellID:number,
--   isVisible:boolean, allowHidden:boolean}
function Sync.SendPowerInfusionAnnounce(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end
  local caster = tostring(opts.caster or "")
  local recipient = tostring(opts.recipient or "")
  if caster == "" or recipient == "" or string.find(caster, ":", 1, true) or string.find(recipient, ":", 1, true) then
    return
  end
  caster = QualifyAnnounceName(caster)
  recipient = QualifyAnnounceName(recipient)
  local spellID = ToFiniteNumber(opts.spellID) or POWER_INFUSION_SPELL_ID
  if spellID ~= POWER_INFUSION_SPELL_ID then
    return
  end
  local payload = string.format("PI:%s:%s:%d", caster, recipient, spellID)
  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "NORMAL")
  SyncLog(
    "send_power_infusion",
    "caster=%s recipient=%s spellID=%d channel=%s sent=%s",
    caster,
    recipient,
    spellID,
    tostring(channel),
    tostring(sent)
  )
end

--- Broadcasts a REQSYNC request, asking all peers to re-send their current sync snapshot.
-- Rate-limited by ISILIVE_REFRESH_REQUEST_COOLDOWN (1 s).
-- @param opts table|nil {force:boolean}
function Sync.SendRefreshRequest(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return
  end

  local getTimeFn = rawget(_G, "GetTime")
  local now = type(getTimeFn) == "function" and getTimeFn() or 0
  if not opts.force and (now - lastIsiLiveRefreshRequestAt) < ISILIVE_REFRESH_REQUEST_COOLDOWN then
    return
  end
  -- Addon chat is locked down in a key from the first pull until after the
  -- key (probe 2026-11-12): nothing would go out, so nothing is attempted.
  if IsAddonChatLockedDown() then
    SyncLog("send_reqsync", "channel=%s sent=lockdown", tostring(channel))
    return
  end

  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, "REQSYNC", channel, "ALERT")
  if sent == true then
    lastIsiLiveRefreshRequestAt = now
  end
  SyncLog("send_reqsync", "channel=%s sent=%s", tostring(channel), tostring(sent))
end

--- Sends a LibKeystone "R" request to the party asking peers to reply with their key data.
-- Only sent in party (not raid). Rate-limited by LIBKEYSTONE_REQUEST_COOLDOWN (3 s).
-- @param opts table|nil {force:boolean}
-- @return boolean true if the message was sent; false if suppressed.
function Sync.SendLibKeystoneRequest(opts)
  local chatInfo = rawget(_G, "C_ChatInfo")
  if type(chatInfo) ~= "table" or type(chatInfo.SendAddonMessage) ~= "function" then
    return false
  end
  if not IsSyncEnabled() then
    return false
  end
  opts = opts or {}

  local libKsChannel = Sync.GetAddonSyncChannel()
  if not libKsChannel then
    return false
  end

  local getTimeFn = rawget(_G, "GetTime")
  local now = type(getTimeFn) == "function" and getTimeFn() or 0
  if not opts.force and (now - lastLibKeystoneRequestAt) < LIBKEYSTONE_REQUEST_COOLDOWN then
    return false
  end

  local sent = DispatchAddonMessage(LIBKEYSTONE_SYNC_PREFIX, "R", libKsChannel, "NORMAL")
  if sent == true then
    lastLibKeystoneRequestAt = now
  end
  SyncLog("send_libkeystone_request", "channel=%s sent=%s", tostring(libKsChannel), tostring(sent))
  return sent == true
end

--- Sends the local player's keystone and rio to party in LibKeystone format ("level,mapID,rio").
-- Only sent in party (not raid). No cooldown — caller is responsible for throttling.
-- @param opts table {mapID:number, level:number, rio:number}
-- @return boolean true if the message was sent; false if suppressed.
function Sync.SendLibKeystonePartyData(opts)
  local chatInfo = rawget(_G, "C_ChatInfo")
  if type(chatInfo) ~= "table" or type(chatInfo.SendAddonMessage) ~= "function" then
    return false
  end
  if not IsSyncEnabled() then
    return false
  end
  opts = opts or {}

  local libKsChannel = Sync.GetAddonSyncChannel()
  if not libKsChannel then
    return false
  end

  local payload, numericLevel, numericMapID, numericRio =
    SyncCodec.NormalizeLibKeystonePartyPayload(opts.mapID, opts.level, opts.rio)
  local sent = DispatchAddonMessage(LIBKEYSTONE_SYNC_PREFIX, payload, libKsChannel, "NORMAL")
  SyncLog(
    "send_libkeystone_party",
    "channel=%s level=%s mapID=%s rio=%s sent=%s",
    tostring(libKsChannel),
    tostring(numericLevel),
    tostring(numericMapID),
    tostring(numericRio),
    tostring(sent)
  )
  return sent == true
end

--- Broadcasts a SHAREKEYS request, asking all peers to announce their keystones in group chat.
-- No cooldown on the request itself; receivers handle their own rate-limiting.
-- @return boolean true if the message was sent; false when not in a group.
function Sync.SendShareKeysRequest()
  local channel = ResolveSendChannel({})
  if not channel then
    return false
  end
  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, "SHAREKEYS", channel, "ALERT")
  SyncLog("send_sharekeys", "channel=%s sent=%s", tostring(channel), tostring(sent))
  return sent == true
end

--- Broadcasts the remaining share-keys button cooldown to the group.
-- Sent as part of the hello-ack / REQSYNC state fan-out so a freshly joined
-- peer mirrors the lock instead of immediately re-triggering a SHAREKEYS wave.
-- Rate-limited by ISILIVE_SHAREKEYS_CD_COOLDOWN (1 s); remain is clamped to
-- 1..ISILIVE_SHAREKEYS_CD_MAX_SECONDS (30 s, the button debounce window).
-- @param opts table {remain:number, force:boolean}
-- @return boolean true if the message was sent; false if suppressed or invalid.
function Sync.SendShareKeysCooldown(opts)
  opts = opts or {}
  local channel = ResolveSendChannel(opts)
  if not channel then
    return false
  end

  local remain = ToFiniteNumber(opts.remain)
  if not remain or remain <= 0 then
    return false
  end
  remain = math.ceil(remain)
  if remain > ISILIVE_SHAREKEYS_CD_MAX_SECONDS then
    remain = ISILIVE_SHAREKEYS_CD_MAX_SECONDS
  end

  local getTimeFn = rawget(_G, "GetTime")
  local now = type(getTimeFn) == "function" and getTimeFn() or 0
  if not opts.force and (now - lastIsiLiveShareKeysCdAt) < ISILIVE_SHAREKEYS_CD_COOLDOWN then
    return false
  end

  local payload = string.format("SKCD:%d", remain)
  local sent = DispatchAddonMessage(ISILIVE_SYNC_PREFIX, payload, channel, "NORMAL")
  if sent == true then
    lastIsiLiveShareKeysCdAt = now
  end
  SyncLog("send_sharekeys_cd", "remain=%d channel=%s sent=%s", remain, tostring(channel), tostring(sent))
  return sent == true
end

local receiveFactory = addonTable.SyncReceiveFactory
if type(receiveFactory) == "function" then
  Sync.ProcessAddonMessage = receiveFactory({
    Sync = Sync,
    ISILIVE_SYNC_PREFIX = ISILIVE_SYNC_PREFIX,
    LIBKEYSTONE_SYNC_PREFIX = LIBKEYSTONE_SYNC_PREFIX,
    LIBKEYSTONE_SOURCE = LIBKEYSTONE_SOURCE,
    ISILIVE_SHAREKEYS_CD_MAX_SECONDS = ISILIVE_SHAREKEYS_CD_MAX_SECONDS,
    POWER_INFUSION_SPELL_ID = POWER_INFUSION_SPELL_ID,
    ToFiniteNumber = ToFiniteNumber,
    IsExplicitNonFiniteNumber = SyncCodec.IsExplicitNonFiniteNumber,
    IsPlainPeerName = SyncCodec.IsPlainPeerName,
    SyncLog = SyncLog,
    SyncLogDeep = SyncLogDeep,
    IsSyncLogActive = IsSyncLogActive,
    IsSyncLogDeepActive = IsSyncLogDeepActive,
    FormatBytes = FormatBytes,
    SplitPayload = SyncCodec.SplitPayload,
    ParseKickPayload = SyncCodec.ParseKickPayload,
    ParseDefPayload = SyncCodec.ParseDefPayload,
    ApplyDefPayload = ApplyDefPayload,
    IsSyncEnabled = IsSyncEnabled,
  })
end
