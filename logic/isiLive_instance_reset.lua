local _, addonTable = ...
addonTable = addonTable or {}

-- Instance reset after a key (rule 235).
--
-- A key that ends in a dungeon of the active season (completed or reset by an
-- abandon) arms the module; the first instance change that leaves the player
-- outside any instance turns that into a "reset pending" mark for one hour.
-- While the mark stands, the group leader sees a reset button with the leader
-- buttons of the main window. A click calls ResetInstances(); the result only
-- counts once the client confirms it with the localized INSTANCE_RESET_SUCCESS
-- system message, which clears the mark.
--
-- The mark lives in session memory only: instance locks are per character
-- and IsiLiveDB is account-wide, so a persisted mark could surface on the
-- wrong character. After a reload the button stays away (fail closed).
--
-- Events reach the module through the main dispatcher (static registry in
-- core/isiLive_bootstrap.lua); it never registers events itself.

local InstanceReset = {}
addonTable.InstanceReset = InstanceReset

local IsSecretValue = addonTable.Validators.IsSecretValue

local PENDING_LIFETIME_SECONDS = 3600
-- A success message within this window after our own click is announced; a
-- reset done by somebody else (or through the portrait menu) is not.
local OWN_REQUEST_WINDOW_SECONDS = 10

local SUCCESS_GLOBAL = "INSTANCE_RESET_SUCCESS"
local FAILED_GLOBALS = { "INSTANCE_RESET_FAILED", "INSTANCE_RESET_FAILED_OFFLINE" }

local function CallPlain(fn, ...)
  if type(fn) ~= "function" then
    return false, nil, nil
  end
  local ok, first, second = pcall(fn, ...)
  if not ok then
    return false, nil, nil
  end
  return true, first, second
end

local function DefaultNow()
  local ok, value = CallPlain(rawget(_G, "GetTime"))
  if not ok or IsSecretValue(value) or type(value) ~= "number" then
    return nil
  end
  return value
end

-- true / false when the client answers readably, nil otherwise.
local function DefaultIsInInstance()
  local ok, inInstance = CallPlain(rawget(_G, "IsInInstance"))
  if not ok or IsSecretValue(inInstance) then
    return nil
  end
  if inInstance == true or inInstance == 1 then
    return true
  end
  if inInstance == false or inInstance == nil or inInstance == 0 then
    return false
  end
  return nil
end

local function ReadPlainTrue(globalName, ...)
  local ok, value = CallPlain(rawget(_G, globalName), ...)
  if not ok or IsSecretValue(value) then
    return nil
  end
  return value == true
end

local function DefaultIsInGroup()
  return ReadPlainTrue("IsInGroup")
end

local function DefaultIsInRaid()
  return ReadPlainTrue("IsInRaid")
end

local function DefaultIsGroupLeader()
  return ReadPlainTrue("UnitIsGroupLeader", "player")
end

local function ReadPlainMapID(value)
  if IsSecretValue(value) or type(value) ~= "number" or value <= 0 or value ~= math.floor(value) then
    return nil
  end
  return value
end

local function DefaultGetActiveChallengeMapID()
  local challengeMode = rawget(_G, "C_ChallengeMode")
  local ok, mapID = CallPlain(type(challengeMode) == "table" and challengeMode.GetActiveChallengeMapID or nil)
  return ok and ReadPlainMapID(mapID) or nil
end

local function DefaultGetCompletionMapID()
  local challengeMode = rawget(_G, "C_ChallengeMode")
  local ok, info = CallPlain(type(challengeMode) == "table" and challengeMode.GetChallengeCompletionInfo or nil)
  if not ok or IsSecretValue(info) or type(info) ~= "table" then
    return nil
  end
  local readField = addonTable.Validators.ReadPlainField
  local mapID = type(readField) == "function" and readField(info, "mapChallengeModeID") or nil
  return ReadPlainMapID(mapID)
end

local function DefaultIsSeasonDungeon(mapID)
  local seasonData = addonTable.SeasonData
  if type(seasonData) ~= "table" or type(seasonData.GetMapToTeleport) ~= "function" then
    return false
  end
  local normalized = mapID
  if type(seasonData.NormalizeMapID) == "function" then
    normalized = seasonData.NormalizeMapID(mapID)
  end
  local maps = seasonData.GetMapToTeleport()
  return type(maps) == "table" and normalized ~= nil and maps[normalized] ~= nil
end

local function DefaultResetInstances()
  local resetInstances = rawget(_G, "ResetInstances")
  if type(resetInstances) ~= "function" then
    return false
  end
  local ok = pcall(resetInstances)
  return ok == true
end

local function DefaultSendPartyChat(message)
  local helpers = addonTable.ContextHelpers
  if type(helpers) ~= "table" or type(helpers.SendPartyChatMessage) ~= "function" then
    return false
  end
  return helpers.SendPartyChatMessage(message) == true
end

local function DefaultAfter(delay, callback)
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    timer.After(delay, callback)
    return true
  end
  return false
end

local deps = {}
local state = {}

local function ResetState()
  state.trackedKeyMapID = nil
  state.armedMapID = nil
  state.pendingAt = nil
  state.pendingMapID = nil
  state.expiryToken = 0
  state.lastRequestAt = nil
end

local function ResetDependencies()
  deps.getDB = function()
    return rawget(_G, "IsiLiveDB") or {}
  end
  deps.getL = function()
    return {}
  end
  deps.trace = nil
  deps.onStateChanged = nil
  deps.now = DefaultNow
  deps.isInInstance = DefaultIsInInstance
  deps.isInGroup = DefaultIsInGroup
  deps.isInRaid = DefaultIsInRaid
  deps.isGroupLeader = DefaultIsGroupLeader
  deps.getActiveChallengeMapID = DefaultGetActiveChallengeMapID
  deps.getCompletionMapID = DefaultGetCompletionMapID
  deps.isSeasonDungeon = DefaultIsSeasonDungeon
  deps.resetInstances = DefaultResetInstances
  deps.sendPartyChat = DefaultSendPartyChat
  deps.after = DefaultAfter
end

-- Demo preview mark (feature demo and simulation tablet action C12). It
-- stands in for "pending, outside, party leader" so the button can be shown
-- through its real visibility and placement path without any group or
-- instance state. It never reaches ResetInstances() or the party chat, is
-- independent of the real pending mark and lives in session memory only.
local demo = { active = false, onReset = nil }

ResetState()
ResetDependencies()

local function Trace(buildMessage)
  if type(deps.trace) == "function" then
    deps.trace(buildMessage)
  end
end

local function NotifyStateChanged()
  if type(deps.onStateChanged) == "function" then
    deps.onStateChanged()
  end
end

local function GetDB()
  local db = deps.getDB()
  return type(db) == "table" and db or {}
end

--- Injects the factory dependencies. Only the keys present in `opts` are
--- replaced; the WoW API adapters keep their defaults unless overridden.
function InstanceReset.SetDependencies(opts)
  if type(opts) ~= "table" then
    return
  end
  for key, value in pairs(opts) do
    if type(value) == "function" then
      deps[key] = value
    end
  end
end

--- Turns a Blizzard format string ("%s has been reset.") into an anchored Lua
--- pattern with one capture per placeholder. Magic characters are escaped
--- first, so the localized text matches literally. Returns nil for anything
--- that is not a readable, non-empty string.
function InstanceReset.BuildSystemMessagePattern(formatText)
  if IsSecretValue(formatText) or type(formatText) ~= "string" or formatText == "" then
    return nil
  end
  local escaped = formatText:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
  -- Positional placeholders ("%1$s") first, then plain ones ("%s", "%d").
  escaped = escaped:gsub("%%%%%d+%%%$[sd]", "(.+)")
  escaped = escaped:gsub("%%%%[sd]", "(.+)")
  return "^" .. escaped .. "$"
end

local function MatchGlobalFormat(globalName, message)
  local pattern = InstanceReset.BuildSystemMessagePattern(rawget(_G, globalName))
  if not pattern then
    return nil
  end
  local ok, capture = pcall(string.match, message, pattern)
  if not ok then
    return nil
  end
  return capture
end

local function ClearPending(reason)
  if state.pendingAt == nil then
    return false
  end
  local mapID = state.pendingMapID
  state.pendingAt = nil
  state.pendingMapID = nil
  state.expiryToken = state.expiryToken + 1
  Trace(function()
    return string.format("[INSTANCE_RESET] pending_cleared reason=%s map=%s", tostring(reason), tostring(mapID))
  end)
  return true
end

local function IsPendingFresh(now)
  if state.pendingAt == nil then
    return false
  end
  if now == nil then
    return false
  end
  if now - state.pendingAt >= PENDING_LIFETIME_SECONDS then
    ClearPending("expired")
    return false
  end
  return true
end

local function ScheduleExpiry()
  local token = state.expiryToken
  deps.after(PENDING_LIFETIME_SECONDS, function()
    if state.expiryToken ~= token or state.pendingAt == nil then
      return
    end
    if not IsPendingFresh(deps.now()) then
      NotifyStateChanged()
    end
  end)
end

-- Turns an armed key end into the pending mark once the player is readably
-- outside of every instance. Inside (or unreadable) the arm waits.
local function PromoteArmedKeyWhenOutside()
  if state.armedMapID == nil or deps.isInInstance() ~= false then
    return false
  end
  local now = deps.now()
  if now == nil then
    return false
  end
  state.pendingAt = now
  state.pendingMapID = state.armedMapID
  state.armedMapID = nil
  state.expiryToken = state.expiryToken + 1
  ScheduleExpiry()
  Trace(function()
    return string.format("[INSTANCE_RESET] pending map=%s", tostring(state.pendingMapID))
  end)
  return true
end

local function ArmKeyEnd(mapID, outcome)
  state.trackedKeyMapID = nil
  if mapID == nil or deps.isSeasonDungeon(mapID) ~= true then
    Trace(function()
      return string.format("[INSTANCE_RESET] key_end_ignored outcome=%s map=%s", tostring(outcome), tostring(mapID))
    end)
    return
  end
  state.armedMapID = mapID
  Trace(function()
    return string.format("[INSTANCE_RESET] armed outcome=%s map=%s", tostring(outcome), tostring(mapID))
  end)
end

local function IsOwnRequestRecent(now)
  return state.lastRequestAt ~= nil and now ~= nil and now - state.lastRequestAt <= OWN_REQUEST_WINDOW_SECONDS
end

local function AnnounceReset(instanceName)
  local db = GetDB()
  local announceEnabled = db.instanceResetAnnounce == true
  if not announceEnabled or deps.isInGroup() ~= true then
    return
  end
  local L = deps.getL() or {}
  local template = L.INSTANCE_RESET_ANNOUNCE
  if type(template) ~= "string" or template == "" then
    return
  end
  local ok, message = pcall(string.format, template, tostring(instanceName or ""))
  if ok and type(message) == "string" then
    deps.sendPartyChat(message)
  end
end

local function HandleSystemMessage(message)
  if IsSecretValue(message) or type(message) ~= "string" or message == "" then
    return
  end
  local instanceName = MatchGlobalFormat(SUCCESS_GLOBAL, message)
  if instanceName then
    local now = deps.now()
    local ownRequest = IsOwnRequestRecent(now)
    local cleared = ClearPending("reset_success")
    if ownRequest then
      -- One announce per click, even when several instances report a reset.
      state.lastRequestAt = nil
      AnnounceReset(instanceName)
    end
    if cleared then
      NotifyStateChanged()
    end
    return
  end
  for _, globalName in ipairs(FAILED_GLOBALS) do
    if MatchGlobalFormat(globalName, message) then
      -- The client already prints the reason; the mark stays for a retry.
      Trace(function()
        return string.format("[INSTANCE_RESET] reset_failed kind=%s", globalName)
      end)
      return
    end
  end
end

--- Event entry point, fed by the main dispatcher's lifecycle handlers.
function InstanceReset.HandleEvent(event, ...)
  if event == "CHALLENGE_MODE_START" then
    state.trackedKeyMapID = deps.getActiveChallengeMapID()
    state.armedMapID = nil
  elseif event == "CHALLENGE_MODE_COMPLETED" then
    ArmKeyEnd(deps.getActiveChallengeMapID() or deps.getCompletionMapID() or state.trackedKeyMapID, "completed")
    if PromoteArmedKeyWhenOutside() then
      NotifyStateChanged()
    end
  elseif event == "CHALLENGE_MODE_RESET" then
    -- Only a run seen running counts as abandoned; a reset without one is not
    -- a key end.
    if state.trackedKeyMapID ~= nil then
      ArmKeyEnd(state.trackedKeyMapID, "abandoned")
      if PromoteArmedKeyWhenOutside() then
        NotifyStateChanged()
      end
    end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    -- A reload inside a running key misses CHALLENGE_MODE_START.
    local activeMapID = deps.getActiveChallengeMapID()
    if activeMapID ~= nil then
      state.trackedKeyMapID = activeMapID
    end
    PromoteArmedKeyWhenOutside()
    if state.pendingAt ~= nil then
      -- Entering or leaving an instance flips the outside condition.
      NotifyStateChanged()
    end
  elseif event == "CHAT_MSG_SYSTEM" then
    HandleSystemMessage(...)
  end
end

--- True while a reset is pending (not expired), regardless of where the
--- player stands or the group state.
function InstanceReset.IsPending()
  return IsPendingFresh(deps.now())
end

--- The button shows only with the setting on, a fresh pending mark, readably
--- outside any instance, in a party (not a raid) and as readable group leader.
--- Every unreadable or secret answer hides it. The demo mark replaces every
--- condition but the setting (the demo enables it through its own snapshot).
function InstanceReset.ShouldShowButton()
  local db = GetDB()
  local buttonEnabled = db.instanceResetButtonEnabled == true
  if not buttonEnabled then
    return false
  end
  if demo.active then
    return true
  end
  if not IsPendingFresh(deps.now()) then
    return false
  end
  if deps.isInInstance() ~= false then
    return false
  end
  if deps.isInGroup() ~= true or deps.isInRaid() ~= false then
    return false
  end
  return deps.isGroupLeader() == true
end

--- Button click. Re-checks every show condition, then calls ResetInstances()
--- defensively. Returns true when the call went out. While the demo mark
--- stands, a click only drops that mark (the button goes away as after a
--- confirmed reset) and hands over to the demo's own callback; it never
--- resets, never announces and returns false.
function InstanceReset.RequestReset()
  if demo.active then
    local onReset = demo.onReset
    demo.active = false
    demo.onReset = nil
    Trace(function()
      return "[INSTANCE_RESET] demo_click reset=false"
    end)
    NotifyStateChanged()
    if type(onReset) == "function" then
      onReset()
    end
    return false
  end
  if not InstanceReset.ShouldShowButton() then
    return false
  end
  local ok = deps.resetInstances() == true
  if ok then
    state.lastRequestAt = deps.now()
  end
  Trace(function()
    return string.format("[INSTANCE_RESET] reset_requested ok=%s map=%s", tostring(ok), tostring(state.pendingMapID))
  end)
  return ok
end

--- Re-evaluates the button after a settings toggle.
function InstanceReset.ApplySettings()
  NotifyStateChanged()
end

--- Sets or drops the demo preview mark. `onReset` runs once when the demo
--- button is clicked. Re-evaluates the button and returns true when the
--- mark changed.
function InstanceReset.SetDemoActive(active, onReset)
  local nextActive = active == true
  demo.onReset = nextActive and type(onReset) == "function" and onReset or nil
  if demo.active == nextActive then
    return false
  end
  demo.active = nextActive
  Trace(function()
    return string.format("[INSTANCE_RESET] demo active=%s", tostring(nextActive))
  end)
  NotifyStateChanged()
  return true
end

function InstanceReset.IsDemoActive()
  return demo.active == true
end

InstanceReset.PENDING_LIFETIME_SECONDS = PENDING_LIFETIME_SECONDS
