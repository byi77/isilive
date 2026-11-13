local _, addonTable = ...

addonTable = addonTable or {}

-- Update notice: tells the player in chat once per session when another
-- isiLive client (group HELLO/ACK or the guild VER ping) runs a newer release.
-- The guild ping is sent once after login; a client that sees an older guild
-- version answers with its own after a random delay, unless another client
-- with the same or a newer version answered first (rule 247).
local VersionNotice = {}
addonTable.VersionNotice = VersionNotice

local MAX_VERSION_LENGTH = 24
local MAX_VERSION_PARTS = 4
local LOGIN_ANNOUNCE_DELAY_SECONDS = 15
local REPLY_DELAY_MIN_SECONDS = 2
local REPLY_DELAY_MAX_SECONDS = 12
local REPLY_COOLDOWN_SECONDS = 300

--- Parses a dotted numeric release version ("0.9.516").
-- @param text any
-- @return table|nil Numeric parts, or nil for anything that is not 1-4 dot-separated integers.
function VersionNotice.ParseVersion(text)
  if type(text) ~= "string" or text == "" or #text > MAX_VERSION_LENGTH then
    return nil
  end
  if not text:match("^%d+[%.%d]*$") or text:find("..", 1, true) or text:sub(-1) == "." then
    return nil
  end
  local parts = {}
  for digits in text:gmatch("%d+") do
    parts[#parts + 1] = tonumber(digits)
  end
  if #parts > MAX_VERSION_PARTS then
    return nil
  end
  return parts
end

--- Compares two release versions part by part; missing parts count as 0.
-- @return number|nil -1, 0 or 1; nil when either side is not a valid version.
function VersionNotice.Compare(a, b)
  local left = VersionNotice.ParseVersion(a)
  local right = VersionNotice.ParseVersion(b)
  if not left or not right then
    return nil
  end
  for index = 1, MAX_VERSION_PARTS do
    local l = left[index] or 0
    local r = right[index] or 0
    if l ~= r then
      return l < r and -1 or 1
    end
  end
  return 0
end

local function DefaultAfter(delay, fn)
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    timer.After(delay, fn)
  end
end

local function DefaultGetTime()
  local getTime = rawget(_G, "GetTime")
  return type(getTime) == "function" and getTime() or 0
end

local function DefaultRandom(low, high)
  return math.random(low, high)
end

--- Creates the per-session notice controller.
-- @param deps table {getOwnVersion:fn():string, isNoticeEnabled:fn():boolean,
--   showNotice:fn(peerVersion, ownVersion), sendGuildVersion:fn(version):boolean,
--   after:fn(delay, fn)|nil, getTime:fn()|nil, random:fn(lo, hi)|nil}
function VersionNotice.Create(deps)
  deps = deps or {}
  local after = type(deps.after) == "function" and deps.after or DefaultAfter
  local getTime = type(deps.getTime) == "function" and deps.getTime or DefaultGetTime
  local random = type(deps.random) == "function" and deps.random or DefaultRandom

  local notifiedVersion = nil
  local loginAnnounced = false
  local lastReplyAt = nil
  local pendingReplyToken = nil
  local nextToken = 0

  local controller = {}

  local function GetOwnVersion()
    local own = type(deps.getOwnVersion) == "function" and deps.getOwnVersion() or nil
    return VersionNotice.ParseVersion(own) and own or nil
  end

  local function SendGuildVersion()
    local own = GetOwnVersion()
    if not own or type(deps.sendGuildVersion) ~= "function" then
      return false
    end
    return deps.sendGuildVersion(own) == true
  end

  local function ScheduleGuildReply()
    if pendingReplyToken then
      return
    end
    if lastReplyAt and (getTime() - lastReplyAt) < REPLY_COOLDOWN_SECONDS then
      return
    end
    nextToken = nextToken + 1
    local token = nextToken
    pendingReplyToken = token
    after(random(REPLY_DELAY_MIN_SECONDS, REPLY_DELAY_MAX_SECONDS), function()
      if pendingReplyToken ~= token then
        return
      end
      pendingReplyToken = nil
      if SendGuildVersion() then
        lastReplyAt = getTime()
      end
    end)
  end

  --- Handles a peer version from the group handshake or the guild ping.
  -- @param version string Peer addon version.
  -- @param fromGuild boolean true for a guild VER message.
  -- @return boolean true when the chat notice was shown.
  function controller.NotePeerVersion(version, fromGuild)
    local own = GetOwnVersion()
    local cmp = own and VersionNotice.Compare(version, own) or nil
    if cmp == nil then
      return false
    end
    if fromGuild == true then
      if cmp >= 0 then
        -- Someone at least as new already answered the older client.
        pendingReplyToken = nil
      else
        ScheduleGuildReply()
      end
    end
    if cmp <= 0 then
      return false
    end
    if notifiedVersion and VersionNotice.Compare(version, notifiedVersion) <= 0 then
      return false
    end
    if type(deps.isNoticeEnabled) == "function" and deps.isNoticeEnabled() ~= true then
      return false
    end
    notifiedVersion = version
    if type(deps.showNotice) == "function" then
      deps.showNotice(version, own)
    end
    return true
  end

  --- Schedules the one guild VER ping of this session (PLAYER_LOGIN).
  function controller.OnLogin()
    if loginAnnounced then
      return
    end
    loginAnnounced = true
    after(LOGIN_ANNOUNCE_DELAY_SECONDS, SendGuildVersion)
  end

  return controller
end
