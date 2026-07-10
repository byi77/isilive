local _, addonTable = ...

addonTable = addonTable or {}

local LogBuffer = {}
addonTable.LogBuffer = LogBuffer

local function ClampLimit(limit, defaultValue, minValue, maxValue)
  local value = tonumber(limit) or defaultValue
  if value < minValue then
    value = minValue
  elseif value > maxValue then
    value = maxValue
  end
  return math.floor(value)
end

local function RingIndex(head, offset, cap)
  return ((head - 1 + offset) % cap) + 1
end

local function NormalizeRing(logs, cap)
  local count = tonumber(logs._count)
  local head = tonumber(logs._head)
  local oldCap = #logs
  if count and head and count >= 0 and count <= oldCap and head >= 1 and head <= math.max(1, oldCap) then
    if oldCap > cap or count > cap or head > cap then
      local keep = math.min(count, cap)
      local compacted = {}
      for offset = count - keep, count - 1 do
        compacted[#compacted + 1] = logs[RingIndex(head, offset, oldCap)]
      end
      for i = 1, oldCap do
        logs[i] = nil
      end
      for i = 1, keep do
        logs[i] = compacted[i]
      end
      logs._count = keep
      logs._head = 1
      return keep, 1
    end
    return count, head
  end

  local total = #logs
  local keep = total
  if keep > cap then
    keep = cap
  end
  local startIndex = total - keep + 1
  if startIndex < 1 then
    startIndex = 1
  end

  for i = 1, keep do
    logs[i] = logs[startIndex + i - 1]
  end
  for i = keep + 1, total do
    logs[i] = nil
  end

  logs._count = keep
  logs._head = 1
  return keep, 1
end

function LogBuffer.Normalize(logs, maxEntries)
  assert(type(logs) == "table", "isiLive: LogBuffer.Normalize requires logs table")
  local cap = math.max(1, math.floor(tonumber(maxEntries) or #logs))
  NormalizeRing(logs, cap)
  return logs
end

function LogBuffer.EnsureSavedTable(key)
  assert(type(key) == "string" and key ~= "", "isiLive: LogBuffer requires non-empty key")

  return function()
    -- SavedVariables are restored before ADDON_LOADED and every consumer of
    -- this closure (queue_debug, runtime_log) runs from post-ADDON_LOADED
    -- contexts. Lazy-allocating IsiLiveDB here would race the
    -- SavedVariables restore and wipe other settings, so on the (theoretical)
    -- pre-load callsite we hand back a transient buffer instead. Logs written
    -- to it never persist; this is acceptable for the unreachable edge case.
    local db = rawget(_G, "IsiLiveDB")
    if type(db) ~= "table" then
      return {}
    end
    if type(db[key]) ~= "table" then
      db[key] = {}
    end
    return db[key]
  end
end

function LogBuffer.SanitizeMessage(message)
  local text = tostring(message or "")
  -- Keep SavedVariables debug logs ASCII-friendly for easier external parsing.
  -- Collapse each full UTF-8 multi-byte sequence into a single "?" first so a
  -- single character does not become multiple "?"s. Any remaining high bytes
  -- (invalid / stray) also get replaced with "?".
  local sanitized = text:gsub("[\194-\244][\128-\191]+", "?"):gsub("[\128-\255]", "?")
  return sanitized
end

function LogBuffer.Append(logs, timestamp, message, maxEntries)
  assert(type(logs) == "table", "isiLive: LogBuffer.Append requires logs table")
  local cap = tonumber(maxEntries) or #logs
  if cap < 1 then
    cap = 1
  end

  local count, head = NormalizeRing(logs, cap)
  local timestampText = tostring(timestamp or "")
  local messageText = LogBuffer.SanitizeMessage(message)
  local entry = timestampText ~= "" and string.format("%s %s", timestampText, messageText) or messageText
  if count < cap then
    logs[RingIndex(head, count, cap)] = entry
    logs._count = count + 1
    logs._head = head
    return
  end

  logs[head] = entry
  logs._count = cap
  logs._head = RingIndex(head, 1, cap)
end

function LogBuffer.Count(logs)
  assert(type(logs) == "table", "isiLive: LogBuffer.Count requires logs table")
  return tonumber(logs._count) or #logs
end

function LogBuffer.GetTail(logs, limit, defaultLimit, maxLimit)
  assert(type(logs) == "table", "isiLive: LogBuffer.GetTail requires logs table")

  local cap = #logs
  if cap < 1 then
    return {}
  end

  -- Normalize before reading so we tolerate SavedVariables corruption
  -- (missing _count/_head, or values outside the expected range).
  local total, head = NormalizeRing(logs, cap)
  local count = ClampLimit(limit, tonumber(defaultLimit) or 20, 1, tonumber(maxLimit) or 100)
  if count > total then
    count = total
  end

  local out = {}
  for offset = total - count, total - 1 do
    out[#out + 1] = logs[RingIndex(head, offset, cap)]
  end
  return out
end
