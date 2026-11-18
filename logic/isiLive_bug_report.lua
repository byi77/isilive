local _, addonTable = ...

addonTable = addonTable or {}

-- Bug report export (rule 254): `/isilive report` packs the error log and the
-- runtime log ring into one copyable string for the bug report page
-- (REPORT_URL). Bug fixing only: no statistics, no run history, nothing is
-- kept or counted once the string is built.
--
--   text   = header + error log + runtime log, character names pseudonymised
--   string = PREFIX .. Base64(Gzip(text)) .. SUFFIX
--
-- The page decodes the string in the browser, shows the plain text and sends
-- it on request. The prefix names the format version; the suffix lets the
-- page detect a string that was cut off while copying.
--
-- Pseudonyms: the player is SELF, everybody else P1, P2, ... in order of first
-- appearance. Names come from the current group and from the log fields that
-- carry a character name (sender=, leader=, and name= / realm= of the
-- [ROSTER] and [DPS] lines). Every token equal to such a name (bare or
-- Name-Realm) is replaced anywhere in the report, the own realm becomes
-- REALM. Values from the client are checked with IsSecretValue first.
--
-- Fail-closed: without C_EncodingUtil (CompressString, EncodeBase64) or
-- Enum.CompressionMethod.Gzip no string is built and the caller gets nil plus
-- a reason.
local BugReport = {}
addonTable.BugReport = BugReport

local IsSecretValue = addonTable.Validators and addonTable.Validators.IsSecretValue
  or function(_value)
    return false
  end

local FORMAT_VERSION = 1
BugReport.FORMAT_VERSION = FORMAT_VERSION
BugReport.PREFIX = "!isiLive:" .. FORMAT_VERSION .. "!"
BugReport.SUFFIX = "!End:isiLive:" .. FORMAT_VERSION .. "!"
BugReport.REPORT_URL = "https://byi77.github.io/isilive-report/"
-- Upper bound for the plain report text. The oldest runtime lines are dropped
-- first; errors and the header always stay. ~120 KB of log text compresses to
-- roughly 25-35 KB of Base64, which a single-line EditBox still handles.
BugReport.MAX_TEXT_BYTES = 120000
local MAX_ERROR_ENTRIES = 100

local readLog = nil
local getAddonVersion = nil
local getRuntimeLogEnabled = nil
local getRuntimeLogLevel = nil

-- Wired by the frame bridge (same shape as ProbeLog.Attach).
function BugReport.Attach(opts)
  opts = type(opts) == "table" and opts or {}
  readLog = type(opts.readLog) == "function" and opts.readLog or nil
  getAddonVersion = type(opts.getAddonVersion) == "function" and opts.getAddonVersion or nil
  getRuntimeLogEnabled = type(opts.getRuntimeLogEnabled) == "function" and opts.getRuntimeLogEnabled or nil
  getRuntimeLogLevel = type(opts.getRuntimeLogLevel) == "function" and opts.getRuntimeLogLevel or nil
end

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b, c, d = pcall(fn, ...)
  if not ok then
    return nil
  end
  return a, b, c, d
end

-- Plain string from the client, or nil for missing / secret / non-string.
local function ReadableString(value)
  if value == nil or IsSecretValue(value) or type(value) ~= "string" or value == "" then
    return nil
  end
  return value
end

---------------------------------------------------------------------------
-- Pseudonymisation
---------------------------------------------------------------------------

-- Field values that are placeholders, not names.
local NON_NAME_VALUES = {
  ["nil"] = true,
  ["none"] = true,
  ["unknown"] = true,
  ["true"] = true,
  ["false"] = true,
  ["?"] = true,
  ["-"] = true,
  ["secret"] = true,
}

-- Characters that end a token. A name never contains any of them; "-" stays
-- inside the token so Name-Realm is one token.
local TOKEN_PATTERN = "[^%s=,;:%(%)%[%]{}\"'|/<>]+"

local function NewNameTable()
  return { map = {}, nextIndex = 1, realm = nil }
end

local function StripRealm(name)
  local base = name:match("^(.-)%-[^%-]+$")
  if base and base ~= "" then
    return base
  end
  return name
end

local function IsNameCandidate(value)
  if type(value) ~= "string" or value == "" then
    return false
  end
  if NON_NAME_VALUES[value:lower()] then
    return false
  end
  if value:find("^%d") or value:find("[=%.]") then
    return false
  end
  return true
end

local function AddName(names, rawName, pseudonym)
  if not IsNameCandidate(rawName) then
    return
  end
  local base = StripRealm(rawName)
  if names.map[base] then
    return
  end
  if not pseudonym then
    pseudonym = "P" .. tostring(names.nextIndex)
    names.nextIndex = names.nextIndex + 1
  end
  names.map[base] = pseudonym
end

-- Log fields whose value is a character name. Tag-scoped entries only count
-- on lines with that tag: name= also carries dungeon, toy and button names.
local NAME_FIELDS_ANY_TAG = { "sender", "leader" }
local NAME_FIELDS_BY_TAG = {
  ["[ROSTER]"] = { "name" },
  ["[DPS]"] = { "name" },
}

local function HarvestNamesFromLine(names, line)
  for _, field in ipairs(NAME_FIELDS_ANY_TAG) do
    for value in line:gmatch("%f[%w]" .. field .. "=(" .. TOKEN_PATTERN .. ")") do
      AddName(names, value)
    end
  end
  for tag, fields in pairs(NAME_FIELDS_BY_TAG) do
    if line:find(tag, 1, true) then
      for _, field in ipairs(fields) do
        for value in line:gmatch("%f[%w]" .. field .. "=(" .. TOKEN_PATTERN .. ")") do
          AddName(names, value)
        end
      end
    end
  end
end

local function HarvestGroupNames(names, unitNameFn, numGroupMembersFn, isInRaidFn)
  if type(unitNameFn) ~= "function" then
    return
  end
  local playerName = ReadableString(SafeCall(unitNameFn, "player"))
  if playerName then
    AddName(names, playerName, "SELF")
  end
  local count = tonumber(SafeCall(numGroupMembersFn)) or 0
  local inRaid = SafeCall(isInRaidFn) == true
  local prefix = inRaid and "raid" or "party"
  local last = inRaid and math.min(count, 40) or math.min(math.max(count - 1, 0), 4)
  for i = 1, last do
    local name, realm = SafeCall(unitNameFn, prefix .. tostring(i))
    name = ReadableString(name)
    if name then
      AddName(names, name)
    end
    realm = ReadableString(realm)
    if name and realm then
      AddName(names, name .. "-" .. realm)
    end
  end
end

local function ScrubToken(names, token)
  local direct = names.map[token]
  if direct then
    return direct
  end
  local base, realmPart = token:match("^(.-)%-([^%-]+)$")
  if base and names.map[base] then
    return names.map[base]
  end
  if names.realm and (token == names.realm or realmPart == names.realm) then
    if base and base ~= "" then
      return base .. "-REALM"
    end
    return "REALM"
  end
  return nil
end

function BugReport.ScrubLine(names, line)
  local text = tostring(line or "")
  return (text:gsub(TOKEN_PATTERN, function(token)
    return ScrubToken(names, token)
  end))
end

---------------------------------------------------------------------------
-- Report text
---------------------------------------------------------------------------

local function FormatErrorEntry(entry)
  if type(entry) ~= "table" then
    return nil
  end
  local countSuffix = (tonumber(entry.count) or 1) > 1 and string.format(" (x%d)", entry.count) or ""
  local first = entry.firstSeenDisplay or tostring(entry.firstSeen or "?")
  local last = entry.lastSeenDisplay or tostring(entry.lastSeen or "?")
  local lines = { string.format("[%s..%s%s] %s", first, last, countSuffix, tostring(entry.message or "")) }
  if type(entry.fullText) == "string" and entry.fullText ~= entry.message then
    for detail in entry.fullText:gmatch("[^\n]+") do
      lines[#lines + 1] = "    " .. detail
    end
  end
  return lines
end

local function ReadClientInfo(env)
  local version, build = SafeCall(env.getBuildInfo)
  return ReadableString(version) or "unknown", ReadableString(build) or "unknown"
end

-- Builds the plain report text.
-- env (all optional, defaults read the WoW globals): getBuildInfo, getLocale,
-- dateFn, unitName, getNumGroupMembers, isInRaid, getRealmName, errorLog,
-- runtimeLines (array, overrides the attached reader), maxTextBytes.
-- Returns text, stats { errors, runtimeLines, runtimeLinesTotal, bytes }.
function BugReport.BuildText(env)
  env = type(env) == "table" and env or {}
  env.getBuildInfo = env.getBuildInfo or rawget(_G, "GetBuildInfo")
  local getLocaleFn = env.getLocale or rawget(_G, "GetLocale")
  local dateFn = env.dateFn or rawget(_G, "date")
  local errorLog = env.errorLog or addonTable.ErrorLog
  local maxBytes = tonumber(env.maxTextBytes) or BugReport.MAX_TEXT_BYTES

  local names = NewNameTable()
  local realm = ReadableString(SafeCall(env.getRealmName or rawget(_G, "GetNormalizedRealmName")))
  names.realm = realm
  HarvestGroupNames(
    names,
    env.unitName or rawget(_G, "UnitName"),
    env.getNumGroupMembers or rawget(_G, "GetNumGroupMembers"),
    env.isInRaid or rawget(_G, "IsInRaid")
  )

  local runtimeLines = env.runtimeLines
  if type(runtimeLines) ~= "table" then
    runtimeLines = SafeCall(readLog, "") or {}
  end
  local errorEntries = {}
  if type(errorLog) == "table" and type(errorLog.GetTail) == "function" then
    errorEntries = SafeCall(errorLog.GetTail, MAX_ERROR_ENTRIES) or {}
  end

  for _, line in ipairs(runtimeLines) do
    HarvestNamesFromLine(names, tostring(line))
  end

  local clientVersion, clientBuild = ReadClientInfo(env)
  local header = {
    "isiLive bug report v" .. tostring(FORMAT_VERSION),
    string.format(
      "addon=%s client=%s build=%s locale=%s created=%s",
      tostring(SafeCall(getAddonVersion) or "unknown"),
      clientVersion,
      clientBuild,
      tostring(ReadableString(SafeCall(getLocaleFn)) or "unknown"),
      tostring(SafeCall(dateFn, "%Y-%m-%d %H:%M:%S") or "unknown")
    ),
    string.format(
      "runtimeLog=%s level=%s errors=%d runtimeLines=%d",
      SafeCall(getRuntimeLogEnabled) == true and "on" or "off",
      tostring(SafeCall(getRuntimeLogLevel) or "normal"),
      #errorEntries,
      #runtimeLines
    ),
  }

  local errorBlock = { "", string.format("== errors (%d) ==", #errorEntries) }
  for _, entry in ipairs(errorEntries) do
    local formatted = FormatErrorEntry(entry)
    if formatted then
      for _, line in ipairs(formatted) do
        errorBlock[#errorBlock + 1] = BugReport.ScrubLine(names, line)
      end
    end
  end

  local fixedBytes = 0
  for _, line in ipairs(header) do
    fixedBytes = fixedBytes + #line + 1
  end
  for _, line in ipairs(errorBlock) do
    fixedBytes = fixedBytes + #line + 1
  end

  -- Newest lines first until the budget is spent, then restore the order.
  local budget = maxBytes - fixedBytes - 64
  local kept = {}
  for i = #runtimeLines, 1, -1 do
    local scrubbed = BugReport.ScrubLine(names, runtimeLines[i])
    local cost = #scrubbed + 1
    if budget - cost < 0 then
      break
    end
    budget = budget - cost
    kept[#kept + 1] = scrubbed
  end

  local out = {}
  for _, line in ipairs(header) do
    out[#out + 1] = line
  end
  for _, line in ipairs(errorBlock) do
    out[#out + 1] = line
  end
  out[#out + 1] = ""
  out[#out + 1] = string.format("== runtime log (last %d of %d) ==", #kept, #runtimeLines)
  for i = #kept, 1, -1 do
    out[#out + 1] = kept[i]
  end

  local text = table.concat(out, "\n")
  return text,
    {
      errors = #errorEntries,
      runtimeLines = #kept,
      runtimeLinesTotal = #runtimeLines,
      runtimeLogEnabled = SafeCall(getRuntimeLogEnabled) == true,
      bytes = #text,
    }
end

---------------------------------------------------------------------------
-- Encoding
---------------------------------------------------------------------------

-- Returns the export string, or nil plus a reason ("encoding_unavailable",
-- "encoding_failed").
function BugReport.Encode(text, env)
  env = type(env) == "table" and env or {}
  local encodingUtil = env.encodingUtil or rawget(_G, "C_EncodingUtil")
  local enum = env.enum or rawget(_G, "Enum")
  local methods = type(enum) == "table" and enum.CompressionMethod or nil
  local gzip = type(methods) == "table" and methods.Gzip or nil
  if
    type(encodingUtil) ~= "table"
    or type(encodingUtil.CompressString) ~= "function"
    or type(encodingUtil.EncodeBase64) ~= "function"
    or gzip == nil
  then
    return nil, "encoding_unavailable"
  end
  local ok, encoded = pcall(function()
    local compressed = encodingUtil.CompressString(tostring(text or ""), gzip)
    return encodingUtil.EncodeBase64(compressed)
  end)
  if not ok or type(encoded) ~= "string" or encoded == "" then
    return nil, "encoding_failed"
  end
  return BugReport.PREFIX .. encoded .. BugReport.SUFFIX
end

-- Builds and encodes in one step. Returns exportString, stats or nil, reason.
function BugReport.Build(env)
  local text, stats = BugReport.BuildText(env)
  local exportString, reason = BugReport.Encode(text, env)
  if not exportString then
    return nil, reason
  end
  stats.encodedBytes = #exportString
  return exportString, stats
end

---------------------------------------------------------------------------
-- Command
---------------------------------------------------------------------------

-- /isilive report: builds the string and opens the copy window.
function BugReport.HandleCommand(ctx)
  local L = type(ctx.getL) == "function" and ctx.getL() or {}
  local printFn = ctx.printNoLogFn or ctx.printFn or print
  local exportString, statsOrReason = BugReport.Build()
  if not exportString then
    printFn(L.BUG_REPORT_ENCODING_UNAVAILABLE or "isiLive: bug report could not be built on this client.")
    return false, statsOrReason
  end
  local window = addonTable.BugReportWindow
  if type(window) == "table" and type(window.Show) == "function" then
    window.Show(exportString, statsOrReason, L)
  end
  return true, statsOrReason
end

return BugReport
