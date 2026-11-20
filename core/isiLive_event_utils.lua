local _, addonTable = ...

addonTable = addonTable or {}

local EventUtils = {}
addonTable.EventUtils = EventUtils

-- Patch-safe event registration (rule 258). Frame:RegisterEvent raises
-- "Attempt to register unknown event" for an event Blizzard removed or
-- renamed. Unprotected, that error aborted every registration loop it sat in
-- (the dispatcher registry holds 47 events), so one renamed event silenced
-- most of the addon on patch day. Every registration in production code goes
-- through these helpers instead; tools/check_wow_api_compliance.lua forbids
-- direct calls. A failed event is skipped, the rest still registers, and the
-- failure is kept for `/isilive selftest` (ApiHealth).
local registrationFailures = {}
local registrationFailureOrder = {}

local function NoteRegistrationFailure(event, reason)
  local key = tostring(event)
  if registrationFailures[key] == nil then
    registrationFailureOrder[#registrationFailureOrder + 1] = key
  end
  registrationFailures[key] = tostring(reason or "error")
end

--- true/false from C_EventUtils.IsEventValid, nil when the client cannot say.
function EventUtils.IsEventValid(event)
  if type(event) ~= "string" or event == "" then
    return false
  end
  local api = rawget(_G, "C_EventUtils")
  local isEventValid = type(api) == "table" and api.IsEventValid or nil
  if type(isEventValid) ~= "function" then
    return nil
  end
  local ok, valid = pcall(isEventValid, event)
  if not ok or type(valid) ~= "boolean" then
    return nil
  end
  return valid
end

local function SafeRegister(frame, method, event, ...)
  if type(frame) ~= "table" then
    return false
  end
  local register = frame[method]
  if type(register) ~= "function" then
    return false
  end
  if EventUtils.IsEventValid(event) == false then
    NoteRegistrationFailure(event, "unknown event")
    return false
  end
  local ok, err = pcall(register, frame, event, ...)
  if not ok then
    NoteRegistrationFailure(event, err)
    return false
  end
  return true
end

--- Registers one event; returns true on success. Never raises.
function EventUtils.SafeRegisterEvent(frame, event)
  return SafeRegister(frame, "RegisterEvent", event)
end

--- Registers one unit event (at most two units, Blizzard's limit). Never raises.
function EventUtils.SafeRegisterUnitEvent(frame, event, ...)
  return SafeRegister(frame, "RegisterUnitEvent", event, ...)
end

--- Registers every event of a list; returns the number registered.
function EventUtils.SafeRegisterEvents(frame, events)
  local registered = 0
  for _, event in ipairs(type(events) == "table" and events or {}) do
    if EventUtils.SafeRegisterEvent(frame, event) then
      registered = registered + 1
    end
  end
  return registered
end

--- Failed registrations in first-seen order: { { event, reason }, ... }.
function EventUtils.GetRegistrationFailures()
  local failures = {}
  for _, event in ipairs(registrationFailureOrder) do
    failures[#failures + 1] = { event = event, reason = registrationFailures[event] }
  end
  return failures
end

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
  elseif type(value) == "number" then
    local enumRef = rawget(_G, "Enum")
    local statusEnum = type(enumRef) == "table" and enumRef.LFGListApplicationStatus or nil
    if type(statusEnum) == "table" then
      for key, enumValue in pairs(statusEnum) do
        if enumValue == value then
          if ContainsNegativeKeyword(string.lower(tostring(key))) then
            return true
          end
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
