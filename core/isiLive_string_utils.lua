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

--- Returns true when value is nil, not a string, or the empty string.
--- Equivalent to `not value or value == ""` for string-typed inputs.
--- @param value any
--- @return boolean
function StringUtils.IsBlank(value)
  return type(value) ~= "string" or value == ""
end

--- Builds a `name-realm` cross-realm target. Returns bare name when realm is
--- blank, nil when name is blank.
--- @param name string|nil
--- @param realm string|nil
--- @return string|nil
function StringUtils.BuildQualifiedName(name, realm)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  if type(realm) == "string" and realm ~= "" then
    return name .. "-" .. realm
  end
  return name
end

--- Builds a slash-target form (`name` or `name-realm`) for use in macros like
--- `/target` and `/whisper`. Strips the realm suffix when it matches the local
--- player's home realm — `/target Pella-Twisting Nether` does not acquire the
--- local-realm Pella, but `/target Pella` does. The home realm is resolved via
--- the optional `homeRealm` arg, falling back to the WoW global `GetRealmName()`
--- so callers don't have to thread it through.
--- @param name string|nil
--- @param realm string|nil
--- @param homeRealm string|nil
--- @return string|nil
function StringUtils.BuildSlashTargetName(name, realm, homeRealm)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  if type(realm) ~= "string" or realm == "" then
    return name
  end
  local resolvedHome = homeRealm
  if type(resolvedHome) ~= "string" or resolvedHome == "" then
    local getRealmName = rawget(_G, "GetRealmName")
    if type(getRealmName) == "function" then
      local ok, value = pcall(getRealmName)
      if ok and type(value) == "string" then
        resolvedHome = value
      end
    end
  end
  if type(resolvedHome) == "string" and resolvedHome ~= "" and realm == resolvedHome then
    return name
  end
  return name .. "-" .. realm
end
