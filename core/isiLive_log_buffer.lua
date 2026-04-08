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

function LogBuffer.EnsureSavedTable(key)
  assert(type(key) == "string" and key ~= "", "isiLive: LogBuffer requires non-empty key")

  return function()
    local db = rawget(_G, "IsiLiveDB")
    if not db then
      db = {}
      IsiLiveDB = db
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
  return text:gsub("[\128-\255]", "")
end

function LogBuffer.Append(logs, timestamp, message, maxEntries)
  assert(type(logs) == "table", "isiLive: LogBuffer.Append requires logs table")
  local cap = tonumber(maxEntries) or #logs
  if cap < 1 then
    cap = 1
  end

  table.insert(logs, string.format("%s %s", tostring(timestamp), LogBuffer.SanitizeMessage(message)))

  -- Overflow: shift entries forward (O(n) instead of O(n²) via table.remove)
  local overflow = #logs - cap
  if overflow > 0 then
    local newLen = #logs - overflow
    for i = 1, newLen do
      logs[i] = logs[i + overflow]
    end
    for i = newLen + 1, #logs do
      logs[i] = nil
    end
  end
end

function LogBuffer.GetTail(logs, limit, defaultLimit, maxLimit)
  assert(type(logs) == "table", "isiLive: LogBuffer.GetTail requires logs table")

  local count = ClampLimit(limit, tonumber(defaultLimit) or 20, 1, tonumber(maxLimit) or 100)
  local total = #logs
  local startIndex = total - count + 1
  if startIndex < 1 then
    startIndex = 1
  end

  local out = {}
  for i = startIndex, total do
    out[#out + 1] = logs[i]
  end
  return out
end
