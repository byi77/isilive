local _, addonTable = ...

addonTable = addonTable or {}

local EventUtils = {}
addonTable.EventUtils = EventUtils

local NEGATIVE_STATUS_KEYWORDS = { "declin", "cancel", "failed", "timeout" }

local function ContainsNegativeKeyword(text)
  for _, keyword in ipairs(NEGATIVE_STATUS_KEYWORDS) do
    if text:find(keyword) then
      return true
    end
  end
  return false
end

function EventUtils.IsNegativeApplicationStatusValue(value)
  if type(value) == "string" then
    if ContainsNegativeKeyword(string.lower(value)) then
      return true
    end
  elseif type(value) == "number" and Enum and Enum.LFGListApplicationStatus then
    for key, enumValue in pairs(Enum.LFGListApplicationStatus) do
      if enumValue == value then
        if ContainsNegativeKeyword(string.lower(tostring(key))) then
          return true
        end
      end
    end
  end

  return false
end

function EventUtils.IsNegativeApplicationStatusEvent(...)
  local count = select("#", ...)
  for i = 1, count do
    local value = select(i, ...)
    -- LFG_LIST_APPLICATION_STATUS_UPDATED usually carries an application/listing ID
    -- as first numeric argument. That ID must not be treated as status enum.
    local isFirstNumericIdentifier = (i == 1 and count > 1 and type(value) == "number")
    if not isFirstNumericIdentifier and EventUtils.IsNegativeApplicationStatusValue(value) then
      return true
    end
  end
  return false
end
