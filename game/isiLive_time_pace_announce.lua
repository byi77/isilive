local _, addonTable = ...
addonTable = addonTable or {}

-- Pace announce (rule 255): a click on the time pace badge posts the badge's
-- expectation as one English line to the group chat, e.g.
--   "KR +15 expected: INTIME - 1:12 spare. Go for it! (via isiLive M+Addon)"
--   "KR +15 expected: OUT-OF-TIME - 2:30 over. Sorry boys and girls. (via isiLive M+Addon)"
-- The line is English in every UI language so every group member can read
-- it. It goes to the group chat only (INSTANCE_CHAT / PARTY through
-- ContextHelpers.SendPartyChatMessage), never to say, guild or whisper. The
-- click is a hardware event on a plain (non-secure) frame, so it also works
-- in combat.
local TimePaceAnnounce = {}
addonTable.TimePaceAnnounce = TimePaceAnnounce

-- At most one post per this many seconds; a repeated click inside the window
-- is dropped silently.
TimePaceAnnounce.COOLDOWN_SECONDS = 10

local BRAND_SUFFIX = "(via isiLive M+Addon)"

-- Expectation word and the short call-out behind the margin, per outcome.
-- A close call stays encouraging on both sides: it is not decided yet.
local OUTCOME_WORDING = {
  intime = { expectation = "INTIME", callout = "Go for it!" },
  intime_close = { expectation = "INTIME (close)", callout = "Push it!" },
  late_close = { expectation = "OUT-OF-TIME (close)", callout = "Every second counts!" },
  late = { expectation = "OUT-OF-TIME", callout = "Sorry boys and girls." },
}

local lastSentAt = nil

local function IsFiniteNumber(value)
  local validators = addonTable.Validators
  if type(validators) == "table" and type(validators.IsFiniteNumber) == "function" then
    return validators.IsFiniteNumber(value)
  end
  return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function IsSecret(value)
  local validators = addonTable.Validators
  return type(validators) == "table"
    and type(validators.IsSecretValue) == "function"
    and validators.IsSecretValue(value) == true
end

-- Forecast minus time limit of a TimePace status (negative = on time), or nil.
local function StatusDelta(status)
  if type(status) ~= "table" then
    return nil
  end
  local delta = nil
  if status.mode == "reference" then
    delta = status.delta
  elseif status.mode == "projection" and IsFiniteNumber(status.projected) and IsFiniteNumber(status.timeLimit) then
    delta = status.projected - status.timeLimit
  end
  return IsFiniteNumber(delta) and delta or nil
end

local function FormatClock(seconds)
  local whole = math.floor(math.abs(seconds) + 0.5)
  return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

local function ClassifyDelta(delta)
  local pace = addonTable.TimePace
  if type(pace) == "table" and type(pace.ClassifyDelta) == "function" then
    return pace.ClassifyDelta(delta)
  end
  return nil
end

--- Builds the English chat line for a TimePace status.
-- The expectation word follows the badge's verdict: "ontime" -> INTIME,
-- "late" -> OUT-OF-TIME; "tight" picks the side by the forecast's sign and
-- adds "(close)". The margin names its own direction ("spare" or "over");
-- a fixed call-out per outcome follows it (OUTCOME_WORDING).
-- @param status table|nil TimePace.GetStatus result (as shown by the badge)
-- @param dungeonCode string|nil English dungeon short code ("KR")
-- @param keyLevel number|nil running key level
-- @return string|nil line, nil when the status carries no answer
function TimePaceAnnounce.BuildLine(status, dungeonCode, keyLevel)
  local delta = StatusDelta(status)
  if not delta then
    return nil
  end
  local verdict = status.verdict
  if verdict ~= "ontime" and verdict ~= "tight" and verdict ~= "late" then
    verdict = ClassifyDelta(delta)
  end
  local outcome
  if verdict == "tight" then
    outcome = delta <= 0 and "intime_close" or "late_close"
  else
    outcome = verdict == "ontime" and "intime" or verdict == "late" and "late" or nil
  end
  local wording = outcome and OUTCOME_WORDING[outcome] or nil
  if not wording then
    return nil
  end
  local margin = FormatClock(delta) .. (delta <= 0 and " spare" or " over")
  local key = "Key"
  if type(dungeonCode) == "string" and dungeonCode ~= "" and type(keyLevel) == "number" and keyLevel > 0 then
    key = string.format("%s +%d", dungeonCode, keyLevel)
  end
  return string.format("%s expected: %s - %s. %s %s", key, wording.expectation, margin, wording.callout, BRAND_SUFFIX)
end

-- Running key from the client: map ID and level, or nil outside a key.
-- Masked or missing values count as "no key".
local function ReadActiveKey()
  local challengeMode = rawget(_G, "C_ChallengeMode")
  if type(challengeMode) ~= "table" then
    return nil
  end
  local getMapID = rawget(challengeMode, "GetActiveChallengeMapID")
  local getKeystone = rawget(challengeMode, "GetActiveKeystoneInfo")
  if type(getMapID) ~= "function" or type(getKeystone) ~= "function" then
    return nil
  end
  -- Both results are rejected by IsSecret (Validators.IsSecretValue) on the
  -- next line before any other use.
  local okMap, mapID = pcall(getMapID) -- secret-value-ok
  local okLevel, level = pcall(getKeystone) -- secret-value-ok
  if not okMap or not okLevel or IsSecret(mapID) or IsSecret(level) then
    return nil
  end
  if type(mapID) ~= "number" or mapID <= 0 or type(level) ~= "number" or level <= 0 then
    return nil
  end
  return mapID, level
end

local function ShortCodeOf(mapID)
  local teleport = addonTable.Teleport
  if type(teleport) ~= "table" or type(teleport.GetDungeonShortCode) ~= "function" then
    return nil
  end
  local ok, code = pcall(teleport.GetDungeonShortCode, mapID, "enUS")
  return ok and type(code) == "string" and code ~= "" and code or nil
end

local function DefaultNow()
  local getTime = rawget(_G, "GetTime")
  if type(getTime) == "function" then
    local ok, now = pcall(getTime)
    if ok and IsFiniteNumber(now) then
      return now
    end
  end
  return nil
end

local function Helpers()
  local helpers = addonTable.ContextHelpers
  return type(helpers) == "table" and helpers or {}
end

--- Posts the expectation of `status` to the group chat.
-- Outcomes: "sent", "no_status" (nothing to say), "cooldown" (repeat inside
-- COOLDOWN_SECONDS), "no_key" (no key running: the line is returned as a
-- preview and nothing is sent), "no_group" (not in a group), "send_failed".
-- @param status table|nil the status the badge shows
-- @return string outcome
-- @return string|nil line the line that was (or would have been) posted
function TimePaceAnnounce.Announce(status)
  local mapID, keyLevel = ReadActiveKey()
  local line = TimePaceAnnounce.BuildLine(status, mapID and ShortCodeOf(mapID) or nil, keyLevel)
  if not line then
    return "no_status", nil
  end
  if not mapID then
    return "no_key", line
  end
  local now = DefaultNow()
  if now and lastSentAt and now - lastSentAt < TimePaceAnnounce.COOLDOWN_SECONDS then
    return "cooldown", line
  end
  local helpers = Helpers()
  if type(helpers.ResolveGroupChatChannel) ~= "function" or not helpers.ResolveGroupChatChannel() then
    return "no_group", line
  end
  if type(helpers.SendPartyChatMessage) ~= "function" or helpers.SendPartyChatMessage(line) ~= true then
    return "send_failed", line
  end
  lastSentAt = now
  return "sent", line
end

--- Test seam: forgets the last post time.
function TimePaceAnnounce.ResetCooldown()
  lastSentAt = nil
end
