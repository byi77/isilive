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
    previewVariant = opts.previewVariant,
    includeGhostMember = opts.includeGhostMember,
    getUnitNameAndRealm = opts.getUnitNameAndRealm,
    getUnitClass = opts.getUnitClass,
    getUnitServerLanguage = opts.getUnitServerLanguage,
    getUnitRole = opts.getUnitRole,
    getPlayerSpecName = opts.getPlayerSpecName,
    getUnitRio = opts.getUnitRio,
  })
end

function ContextHelpers.BuildKeystoneChatLink(mapID, level)
  local numericMapID = math.floor(tonumber(mapID) or 0)
  local numericLevel = math.floor(tonumber(level) or 0)
  if numericMapID <= 0 or numericLevel <= 0 then
    return nil
  end

  local mythicPlusApi = rawget(_G, "C_MythicPlus")
  if mythicPlusApi and type(mythicPlusApi.GetOwnedKeystoneLink) == "function" then
    local okLink, ownedLink = pcall(mythicPlusApi.GetOwnedKeystoneLink)
    if
      okLink
      and type(ownedLink) == "string"
      and ownedLink ~= ""
      and ownedLink:find("|Hkeystone:", 1, true)
      and not ownedLink:find("^|Hkeystone:[^|]+|h%[Keystone%]|h$")
    then
      return ownedLink
    end
  end

  local dungeonName = nil
  if C_ChallengeMode and type(C_ChallengeMode.GetMapUIInfo) == "function" then
    local okName, localizedName = pcall(C_ChallengeMode.GetMapUIInfo, numericMapID)
    if okName and type(localizedName) == "string" and localizedName ~= "" then
      dungeonName = localizedName
    end
  end

  local dungeonLabel = dungeonName and string.format("Keystone: %s +%d", dungeonName, numericLevel)
    or string.format("Keystone +%d", numericLevel)
  return string.format(
    "|cffa335ee|Hkeystone:180653:%d:%d:0:0:0:0|h[%s]|h|r",
    numericMapID,
    numericLevel,
    dungeonLabel
  )
end
