local _, addonTable = ...

addonTable = addonTable or {}

local ContextHelpers = addonTable.ContextHelpers or {}
addonTable.ContextHelpers = ContextHelpers

function ContextHelpers.GetAddonVersionRaw(addonName)
  local version = nil
  local cAddOns = rawget(_G, "C_AddOns")
  if type(cAddOns) == "table" and type(cAddOns.GetAddOnMetadata) == "function" then
    version = cAddOns.GetAddOnMetadata(addonName, "Version")
  else
    local legacyGetAddOnMetadata = rawget(_G, "GetAddOnMetadata")
    if type(legacyGetAddOnMetadata) == "function" then
      version = legacyGetAddOnMetadata(addonName, "Version")
    end
  end
  return tostring(version or "?")
end

function ContextHelpers.CreateRealmInfoGetter()
  local realmInfoLib
  return function()
    if realmInfoLib ~= nil then
      return realmInfoLib
    end
    local libStub = rawget(_G, "LibStub")
    if type(libStub) == "table" and type(libStub.GetLibrary) == "function" then
      realmInfoLib = libStub:GetLibrary("LibRealmInfo", true)
    else
      realmInfoLib = false
    end
    return realmInfoLib
  end
end

function ContextHelpers.GetUnitServerLanguage(isiLiveLocale, getRealmInfoLib, unit, realm)
  return isiLiveLocale.GetUnitServerLanguage(unit, realm, getRealmInfoLib)
end

function ContextHelpers.IsMplusTimerRunning()
  local mplusTimer = addonTable.MplusTimer
  if type(mplusTimer) ~= "table" or type(mplusTimer.GetTimerData) ~= "function" then
    return false
  end
  local data = mplusTimer.GetTimerData()
  return type(data) == "table" and data.running == true
end

function ContextHelpers.IsTrackedPartyRunActive(ctx)
  local runtimeState = type(ctx) == "table" and ctx.runtimeState or nil
  if type(runtimeState) == "table" and type(runtimeState.IsTrackedPartyRunActive) == "function" then
    return runtimeState.IsTrackedPartyRunActive() == true
  end
  if type(ctx) == "table" and type(ctx.IsTrackedPartyRunActive) == "function" then
    return ctx.IsTrackedPartyRunActive() == true
  end
  return false
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

local function IsUsableKeystoneChatLink(link)
  if type(link) ~= "string" or link == "" then
    return false
  end
  return link:find("|Hkeystone:", 1, true) ~= nil or link:find("|Hitem:180653", 1, true) ~= nil
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
    if okLink and IsUsableKeystoneChatLink(ownedLink) then
      return ownedLink
    end
  end

  -- Fallback: GetOwnedKeystoneLink was removed in recent WoW retail.
  -- Scan bags for the Mythic Keystone item (itemID 180653) and return its real link.
  -- Some clients expose it as |Hkeystone:...|h, others as the Keystone item hyperlink.
  -- manually constructed |Hkeystone:...|h links are silently dropped by the chat server.
  local containerApi = rawget(_G, "C_Container")
  if
    containerApi
    and type(containerApi.GetContainerNumSlots) == "function"
    and type(containerApi.GetContainerItemID) == "function"
    and type(containerApi.GetContainerItemLink) == "function"
  then
    for bagID = 0, 5 do
      local okSlots, numSlots = pcall(containerApi.GetContainerNumSlots, bagID)
      if okSlots and type(numSlots) == "number" and numSlots > 0 then
        for slotID = 1, numSlots do
          local okID, itemID = pcall(containerApi.GetContainerItemID, bagID, slotID)
          if okID and itemID == 180653 then
            local okBagLink, bagLink = pcall(containerApi.GetContainerItemLink, bagID, slotID)
            if okBagLink and IsUsableKeystoneChatLink(bagLink) then
              return bagLink
            end
          end
        end
      end
    end
  end

  local dungeonName = nil
  local challengeModeApi = rawget(_G, "C_ChallengeMode")
  if type(challengeModeApi) == "table" and type(challengeModeApi.GetMapUIInfo) == "function" then
    local okName, localizedName = pcall(challengeModeApi.GetMapUIInfo, numericMapID)
    if okName and type(localizedName) == "string" and localizedName ~= "" then
      dungeonName = localizedName
    end
  end

  local dungeonLabel = dungeonName and string.format("Keystone: %s +%d", dungeonName, numericLevel)
    or string.format("Keystone +%d", numericLevel)
  -- Plain-text fallback: WoW drops addon-sent chat messages that contain |c...|r color codes
  -- wrapping square brackets — the server treats them as fake item links. Send without color.
  return string.format("[%s]", dungeonLabel)
end

local function ResolveOwnedKeystoneSnapshot(opts)
  opts = opts or {}

  local getOwnedKeystoneSnapshot = type(opts.getOwnedKeystoneSnapshot) == "function" and opts.getOwnedKeystoneSnapshot
    or nil
  if getOwnedKeystoneSnapshot then
    local mapID, level = getOwnedKeystoneSnapshot()
    local numericMapID = tonumber(mapID)
    local numericLevel = tonumber(level)
    if numericMapID and numericMapID > 0 and numericLevel and numericLevel > 0 then
      return math.floor(numericMapID), math.floor(numericLevel)
    end
  end

  local getRoster = type(opts.getRoster) == "function" and opts.getRoster or nil
  if getRoster then
    local roster = getRoster()
    local playerInfo = type(roster) == "table" and roster.player or nil
    local numericMapID = tonumber(playerInfo and playerInfo.keyMapID)
    local numericLevel = tonumber(playerInfo and playerInfo.keyLevel)
    if numericMapID and numericMapID > 0 and numericLevel and numericLevel > 0 then
      return math.floor(numericMapID), math.floor(numericLevel)
    end
  end

  return nil, nil
end

function ContextHelpers.BuildOwnKeystoneAnnounceLine(opts)
  opts = opts or {}

  local keyMapID, keyLevel = ResolveOwnedKeystoneSnapshot(opts)
  if not keyMapID or not keyLevel then
    return nil
  end

  local keyLink = ContextHelpers.BuildKeystoneChatLink(keyMapID, keyLevel)
  if not keyLink then
    local shortCode = type(opts.getDungeonShortCode) == "function" and opts.getDungeonShortCode(keyMapID) or nil
    keyLink = shortCode and string.format("%s +%d", tostring(shortCode), keyLevel)
      or string.format("Keystone +%d", keyLevel)
  end

  local L = type(opts.getL) == "function" and opts.getL() or {}
  local announcePrefix = tostring(L.ANNOUNCE_PREFIX or "PartyKeys:"):gsub("%s+", "")
  return string.format("[isiLive] %s %s", announcePrefix, keyLink)
end

local function SafeBooleanCall(fn, ...)
  local ok, result = pcall(fn, ...)
  return ok and result == true
end

-- Returns the correct chat channel for the current group context.
-- Instance groups (M+, LFG, dungeon finder) must use INSTANCE_CHAT. PARTY is
-- only valid for a verified home party; otherwise the helper fails closed.
function ContextHelpers.ResolveGroupChatChannel()
  local isInGroup = rawget(_G, "IsInGroup")
  if type(isInGroup) ~= "function" then
    return nil
  end
  local instanceCategory = rawget(_G, "LE_PARTY_CATEGORY_INSTANCE")
  if instanceCategory ~= nil and SafeBooleanCall(isInGroup, instanceCategory) then
    return "INSTANCE_CHAT"
  end

  local homeCategory = rawget(_G, "LE_PARTY_CATEGORY_HOME")
  if homeCategory ~= nil and SafeBooleanCall(isInGroup, homeCategory) then
    return "PARTY"
  end

  local unitInParty = rawget(_G, "UnitInParty")
  if type(unitInParty) == "function" then
    if SafeBooleanCall(unitInParty, "player") then
      return "PARTY"
    end
    return nil
  end

  if SafeBooleanCall(isInGroup) then
    return "PARTY"
  end

  return nil
end

function ContextHelpers.SendPartyChatMessage(message)
  if type(message) ~= "string" or message == "" then
    return false
  end

  local channel = ContextHelpers.ResolveGroupChatChannel()
  if not channel then
    return false
  end

  local sendChatMessage = rawget(_G, "SendChatMessage")
  if type(sendChatMessage) == "function" then
    local ok = pcall(sendChatMessage, message, channel)
    if ok then
      return true
    end
  end

  local chatInfo = rawget(_G, "C_ChatInfo")
  local sendChatMessageCompat = type(chatInfo) == "table" and chatInfo.SendChatMessage or nil
  if type(sendChatMessageCompat) == "function" then
    local ok = pcall(sendChatMessageCompat, message, channel)
    if ok then
      return true
    end
  end

  return false
end
