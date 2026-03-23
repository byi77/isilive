local _, addonTable = ...

addonTable = addonTable or {}

local StringUtils = {}
addonTable.StringUtils = StringUtils

--- Trims leading and trailing whitespace from a string.
--- @param value string|nil
--- @return string
function StringUtils.Trim(value)
  if type(value) ~= "string" then
    return ""
  end
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Removes all whitespace from a string.
--- @param value string|nil
--- @return string
function StringUtils.StripWhitespace(value)
  if type(value) ~= "string" then
    return ""
  end
  return (value:gsub("%s+", ""))
end

--- Normalizes a realm name by stripping spaces, dashes, dots, parens, and quotes.
--- Canonical pattern shared by Sync.NormalizePlayerKey, Stats.NormalizeName,
--- and Locale.NormalizeRealmLookupKey.
--- @param realm string|nil
--- @return string
function StringUtils.NormalizeRealmName(realm)
  if type(realm) ~= "string" then
    return ""
  end
  return (realm:gsub("[%s%-%.%(%)'`]", ""))
end
