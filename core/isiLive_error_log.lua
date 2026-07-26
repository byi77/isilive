local _, addonTable = ...

addonTable = addonTable or {}

-- Always-on error capture for isiLive's own code. Hooks into WoW's global
-- error handler chain (geterrorhandler / seterrorhandler) and persists a
-- bounded ring of error entries into IsiLiveDB.errorLog. Survives /reload
-- and account-wide login. Visible in-game via /isilive errorlog.
--
-- Design constraints:
--   1. Always-on, no opt-in. Errors are rare and valuable; we want them
--      captured even from users who never enable runtimeLog.
--   2. Chain-of-responsibility: the previous error handler (often
--      BugSack / !BugGrabber / Blizzard's BasicScriptErrors) is ALWAYS
--      called. We are an additional subscriber, never a replacement.
--   3. Filter to isiLive code: only capture errors whose stack trace
--      mentions "isiLive". Bypassing this would flood the buffer with
--      Plater / WeakAuras / Blizzard UI errors that aren't ours to fix.
--   4. Dedup: identical errors fire repeatedly during a single combat
--      tick. Increment a counter on the existing entry instead of
--      appending 200 duplicates.
--   5. Bounded ring: hard cap at MAX_ENTRIES, no unbounded growth.
--   6. Defensive: every internal step is pcall-wrapped. An error in the
--      error logger itself must NOT cause a secondary cascade.
local ErrorLog = {}
addonTable.ErrorLog = ErrorLog

local MAX_ENTRIES = 100
local FILTER_TOKEN = "isiLive"
-- Upper bound for the stack probe. Deep enough for real WoW call chains,
-- bounded so a runaway stack cannot make error handling itself expensive.
local MAX_STACK_PROBE_LEVELS = 60

local installedHandler = nil
local installed = false

local function GetDB()
  return rawget(_G, "IsiLiveDB")
end

local function EnsureStorage()
  local db = GetDB()
  if type(db) ~= "table" then
    return nil
  end
  if type(db.errorLog) ~= "table" then
    db.errorLog = {}
  end
  return db.errorLog
end

-- Ordering key for the ring buffer. MUST be a cross-session epoch: entries are
-- persisted in SavedVariables and TrimToCap evicts by the lowest lastSeen.
-- GetTime() is session-relative (seconds since client start), so after a
-- /reload every fresh entry would sort BELOW entries carried over from a long
-- previous session and get evicted first -- the buffer would freeze on stale
-- content and drop exactly the errors the user just reproduced.
--
-- time() is the Unix epoch and stays monotonic across reloads and relogs.
-- GetTime() remains a fallback only. The return value is always numeric so a
-- mixed-type lastSeen can never collapse to 0 in TrimToCap.
--
-- Entries written by older versions carry a GetTime()-epoch stamp (small
-- numbers). They therefore sort below every new time()-epoch entry and are
-- evicted first, which is the desired direction -- no migration needed.
local function NowTimestamp()
  local timeFn = rawget(_G, "time")
  if type(timeFn) == "function" then
    local ok, value = pcall(timeFn)
    if ok and type(value) == "number" and value > 0 then
      return value
    end
  end
  local getTime = rawget(_G, "GetTime")
  if type(getTime) == "function" then
    local ok, value = pcall(getTime)
    if ok and type(value) == "number" then
      return value
    end
  end
  return 0
end

local function NowDisplayTimestamp()
  local dateFn = rawget(_G, "date")
  if type(dateFn) == "function" then
    local ok, value = pcall(dateFn, "%Y-%m-%d %H:%M:%S")
    if ok and type(value) == "string" then
      return value
    end
  end
  return tostring(NowTimestamp())
end

-- Detects whether a given error message text mentions isiLive. The match is
-- intentionally permissive (any case) so manually-thrown errors with
-- "isiLive: ..." prefixes also surface.
local function MentionsIsiLive(text)
  if type(text) ~= "string" or text == "" then
    return false
  end
  if text:find(FILTER_TOKEN, 1, true) then
    return true
  end
  if text:lower():find(FILTER_TOKEN:lower(), 1, true) then
    return true
  end
  return false
end

-- This module's own chunk identity. Capture() always runs with
-- isiLive_error_log.lua frames on the stack (error handler -> Capture ->
-- pcall -> probe), and every one of those frame sources contains the string
-- "isiLive". Without excluding them the probe below would report a match for
-- literally every error, so they have to be filtered out by identity.
--
-- Resolved via the function form of getinfo (not a numeric level), which is
-- independent of how deep this chunk is called from.
local OWN_SOURCE, OWN_SHORT_SOURCE
local function ResolveOwnChunkIdentity() end
do
  local debugLib = rawget(_G, "debug")
  if type(debugLib) == "table" and type(debugLib.getinfo) == "function" then
    local ok, info = pcall(debugLib.getinfo, ResolveOwnChunkIdentity, "S")
    if ok and type(info) == "table" then
      OWN_SOURCE = info.source
      OWN_SHORT_SOURCE = info.short_src
    end
  end
end

-- Walks the live stack for a frame that belongs to isiLive but not to this
-- module. Replaces the previous "format a full traceback, then string-match
-- it" approach for two reasons:
--
--   1. Correctness. A traceback taken here ALWAYS contains this module's own
--      frames, so matching "isiLive" against it was true unconditionally and
--      the isiLive filter (design constraint 3) never actually rejected
--      anything on the live path -- foreign addon errors filled the ring.
--   2. Cost. Install() routes EVERY addon's errors through Capture(). The
--      reject path must not pay for debug.traceback string formatting; a
--      getinfo walk allocates no traceback and bails at the first hit.
--
-- Also strictly more accurate than scanning a traceback string: Lua elides
-- middle frames in deep tracebacks, where an isiLive frame could hide.
local function StackMentionsIsiLive()
  local debugLib = rawget(_G, "debug")
  if type(debugLib) ~= "table" or type(debugLib.getinfo) ~= "function" then
    return false
  end
  local getinfo = debugLib.getinfo
  local ok, found = pcall(function()
    -- Levels are relative to this closure, which itself lives in this chunk
    -- and is skipped by the OWN_SOURCE check like every other own frame.
    for level = 1, MAX_STACK_PROBE_LEVELS do
      local info = getinfo(level, "S")
      if type(info) ~= "table" then
        return false
      end
      local source = info.source
      local shortSrc = info.short_src
      local isOwnFrame = (OWN_SOURCE ~= nil and source == OWN_SOURCE)
        or (OWN_SHORT_SOURCE ~= nil and shortSrc == OWN_SHORT_SOURCE)
      if not isOwnFrame and (MentionsIsiLive(source) or MentionsIsiLive(shortSrc)) then
        return true
      end
    end
    return false
  end)
  return ok and found == true
end

-- Decides whether an error belongs to isiLive. Runs BEFORE any traceback is
-- built so the reject path stays cheap. An explicitly supplied stack is
-- trusted as-is (callers that pass one have already resolved the frames).
local function IsIsiLiveError(message, stack)
  if MentionsIsiLive(message) then
    return true
  end
  if type(stack) == "string" then
    return MentionsIsiLive(stack)
  end
  return StackMentionsIsiLive()
end

-- Enriches the raw error message with a stack traceback. Scoped via pcall
-- so a broken debug library cannot itself trigger an error during error
-- handling.
local function CaptureStack(message)
  local debugLib = rawget(_G, "debug")
  if type(debugLib) ~= "table" or type(debugLib.traceback) ~= "function" then
    return tostring(message)
  end
  local ok, value = pcall(debugLib.traceback, tostring(message), 2)
  if ok and type(value) == "string" then
    return value
  end
  return tostring(message)
end

-- Looks up an existing entry with the same fullText. Returns the entry and
-- its index, or nil for both. fullText already includes traceback if present.
local function FindExistingEntry(storage, fullText)
  if type(storage) ~= "table" or type(fullText) ~= "string" then
    return nil, nil
  end
  for index, entry in ipairs(storage) do
    if type(entry) == "table" and entry.fullText == fullText then
      return entry, index
    end
  end
  return nil, nil
end

-- Trims the storage to MAX_ENTRIES by dropping the oldest entries (entries
-- with the lowest lastSeen timestamps). Idempotent.
local function TrimToCap(storage)
  if type(storage) ~= "table" then
    return
  end
  while #storage > MAX_ENTRIES do
    -- Find oldest by lastSeen and drop it.
    local oldestIndex = 1
    local oldestSeen = nil
    for i, entry in ipairs(storage) do
      local seen = type(entry) == "table" and tonumber(entry.lastSeen) or 0
      if oldestSeen == nil or seen < oldestSeen then
        oldestSeen = seen
        oldestIndex = i
      end
    end
    table.remove(storage, oldestIndex)
  end
end

--- Captures an error into the ring buffer. Public so manually-detected
--- internal errors (e.g. validator violations) can also feed in.
-- @param message string Raw error message.
-- @param stack string|nil Optional traceback (auto-generated if absent).
-- @param source string|nil Optional source label (e.g. "controller_wiring").
function ErrorLog.Capture(message, stack, source)
  local ok, err = pcall(function()
    -- Filter first: Install() delivers every addon's errors here, and the
    -- traceback below is the expensive part. Nothing before this point may
    -- allocate per-error.
    if not IsIsiLiveError(message, stack) then
      return
    end

    local storage = EnsureStorage()
    if not storage then
      return
    end

    local fullText = type(stack) == "string" and stack or CaptureStack(message)
    local existing = FindExistingEntry(storage, fullText)
    local now = NowTimestamp()
    if existing then
      existing.count = (tonumber(existing.count) or 1) + 1
      existing.lastSeen = now
      existing.lastSeenDisplay = NowDisplayTimestamp()
      return
    end

    local entry = {
      message = tostring(message or ""),
      fullText = fullText,
      source = type(source) == "string" and source or nil,
      count = 1,
      firstSeen = now,
      lastSeen = now,
      firstSeenDisplay = NowDisplayTimestamp(),
      lastSeenDisplay = NowDisplayTimestamp(),
    }
    storage[#storage + 1] = entry
    TrimToCap(storage)
  end)
  -- If the error logger itself errors, fall through silently; the original
  -- error has already been forwarded to the upstream handler by Install().
  if not ok then
    local chatFrame = rawget(_G, "DEFAULT_CHAT_FRAME")
    if type(chatFrame) == "table" and type(chatFrame.AddMessage) == "function" then
      -- Last-resort visibility for development builds. In live, swallowed.
      pcall(chatFrame.AddMessage, chatFrame, "|cffff4040[isiLive ErrorLog]|r capture failure: " .. tostring(err))
    end
  end
end

--- Installs the error-handler hook. Idempotent — calling twice has no effect.
-- Chains to whatever handler was previously installed (Blizzard default,
-- BugSack, etc.) so we never silence other addons' error UIs.
function ErrorLog.Install()
  if installed then
    return
  end

  local getEH = rawget(_G, "geterrorhandler")
  local setEH = rawget(_G, "seterrorhandler")
  if type(getEH) ~= "function" or type(setEH) ~= "function" then
    return
  end

  local previous = getEH()
  installedHandler = function(message)
    -- Always forward to the previous handler FIRST so other listeners
    -- (BugSack, BasicScriptErrors) receive the error even if our capture
    -- raises secondarily.
    if type(previous) == "function" then
      pcall(previous, message)
    end
    ErrorLog.Capture(message, nil, nil)
  end
  setEH(installedHandler)
  installed = true
end

--- Returns the most recent N entries (oldest-first within the returned slice).
-- @param limit number|nil Default 10, max 100.
-- @return table list of entry tables
function ErrorLog.GetTail(limit)
  local storage = EnsureStorage()
  if not storage then
    return {}
  end
  local clampedLimit = tonumber(limit) or 10
  if clampedLimit < 1 then
    clampedLimit = 1
  elseif clampedLimit > MAX_ENTRIES then
    clampedLimit = MAX_ENTRIES
  end
  local total = #storage
  if total == 0 then
    return {}
  end
  local startIndex = math.max(1, total - clampedLimit + 1)
  local result = {}
  for i = startIndex, total do
    result[#result + 1] = storage[i]
  end
  return result
end

--- Returns the total number of distinct entries currently stored.
function ErrorLog.GetCount()
  local storage = EnsureStorage()
  return type(storage) == "table" and #storage or 0
end

--- Clears all stored error entries. Reversible only via re-occurrence.
function ErrorLog.Clear()
  local storage = EnsureStorage()
  if storage then
    for i = #storage, 1, -1 do
      storage[i] = nil
    end
  end
end

--- Returns the hard cap on entries (for tests and slash-command UX).
function ErrorLog.GetMaxEntries()
  return MAX_ENTRIES
end

--- Reports whether Install() ran successfully.
function ErrorLog.IsInstalled()
  return installed
end

return ErrorLog
