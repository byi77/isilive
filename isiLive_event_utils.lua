local _, addonTable = ...

addonTable = addonTable or {}

local EventUtils = {}
addonTable.EventUtils = EventUtils

function EventUtils.IsNegativeApplicationStatusValue(value)
  if type(value) == "string" then
    local low = string.lower(value)
    if low:find("declin") or low:find("cancel") or low:find("failed") or low:find("timeout") then
      return true
    end
  elseif type(value) == "number" and Enum and Enum.LFGListApplicationStatus then
    for key, enumValue in pairs(Enum.LFGListApplicationStatus) do
      if enumValue == value then
        local keyText = string.lower(tostring(key))
        if keyText:find("declin") or keyText:find("cancel") or keyText:find("failed") or keyText:find("timeout") then
          return true
        end
      end
    end
  end

  return false
end

function EventUtils.IsNegativeApplicationStatusEvent(...)
  local appStatus = select(2, ...)
  if EventUtils.IsNegativeApplicationStatusValue(appStatus) then
    return true
  end

  local pendingStatus = select(3, ...)
  if EventUtils.IsNegativeApplicationStatusValue(pendingStatus) then
    return true
  end

  local count = select("#", ...)
  for i = 1, count do
    local value = select(i, ...)
    if type(value) == "string" and EventUtils.IsNegativeApplicationStatusValue(value) then
      return true
    end
  end
  return false
end
