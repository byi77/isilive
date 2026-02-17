local _, addonTable = ...

addonTable = addonTable or {}

local ContextHelpers = {}
addonTable.ContextHelpers = ContextHelpers

function ContextHelpers.GetAddonVersionRaw(addonName)
  local legacyGetAddOnMetadata = rawget(_G, "GetAddOnMetadata")
  local version = nil
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    version = C_AddOns.GetAddOnMetadata(addonName, "Version")
  elseif legacyGetAddOnMetadata then
    version = legacyGetAddOnMetadata(addonName, "Version")
  end
  return tostring(version or "?")
end

function ContextHelpers.CreateRealmInfoGetter()
  local realmInfoLib
  return function()
    if realmInfoLib ~= nil then
      return realmInfoLib
    end
    if LibStub and LibStub.GetLibrary then
      realmInfoLib = LibStub:GetLibrary("LibRealmInfo", true)
    else
      realmInfoLib = false
    end
    return realmInfoLib or nil
  end
end

function ContextHelpers.GetUnitServerLanguage(isiLiveLocale, getRealmInfoLib, unit, realm)
  return isiLiveLocale.GetUnitServerLanguage(unit, realm, getRealmInfoLib)
end

function ContextHelpers.BuildDummyRoster(opts)
  return opts.demoBuildDummyRoster({
    getUnitNameAndRealm = opts.getUnitNameAndRealm,
    getUnitServerLanguage = function(unit, realm)
      return opts.getUnitServerLanguage(unit, realm)
    end,
    getUnitRole = opts.getUnitRole,
    getPlayerSpecName = opts.getPlayerSpecName,
    getUnitRio = opts.getUnitRio,
  })
end
