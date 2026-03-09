local _, addonTable = ...

addonTable = addonTable or {}

local Demo = {}
addonTable.Demo = Demo

local SeasonData = addonTable.SeasonData or {}

local DUMMY_MEMBERS = {
  tank = {
    name = "Atabey",
    realm = "Blackmoore",
    language = "EN",
    class = "DRUID",
    role = "TANK",
    spec = "Wachter",
    ilvl = 166,
    rio = 3850,
    keyMapID = 2649,
    keyLevel = 15,
  },
  healer = {
    name = "Nisan",
    realm = "Hyjal",
    language = "FR",
    class = "PRIEST",
    role = "HEALER",
    spec = "Holy",
    ilvl = 169,
    rio = 3810,
    keyMapID = 2287,
    keyLevel = 13,
  },
  dd1 = {
    name = "PumperDPS",
    realm = "Kazzak",
    language = "ES",
    class = "MAGE",
    role = "DAMAGER",
    spec = "Frost",
    ilvl = 170,
    rio = 3955,
    keyMapID = 2773,
    keyLevel = 16,
  },
  dd2 = {
    name = "Bircan",
    realm = "Blackhand",
    language = "IT",
    class = "PALADIN",
    role = "DAMAGER",
    spec = "Retri",
    ilvl = 164,
    rio = 3780,
    keyMapID = 2660,
    keyLevel = 12,
  },
  dd3 = {
    name = "Kurshad",
    realm = "Antonidas",
    language = "PT",
    class = "HUNTER",
    role = "DAMAGER",
    spec = "Marksmanship",
    ilvl = 164,
    rio = 3890,
    keyMapID = 2441,
    keyLevel = 14,
  },
}

local function CopyRosterEntry(entry)
  local copy = {}
  for key, value in pairs(entry or {}) do
    copy[key] = value
  end
  return copy
end

local function BuildGhostUnitKey(info)
  local name = tostring(info and info.name or "Ghost")
  local realm = tostring(info and info.realm or "")
  if realm ~= "" then
    return "ghost:" .. name .. "-" .. realm
  end
  return "ghost:" .. name
end

local function DefaultGetUnitNameAndRealm(unit)
  local name, realm = UnitFullName(unit)
  if not name then
    name = UnitName(unit)
  end
  if not realm or realm == "" then
    realm = GetRealmName() or ""
  end
  return name, realm
end

local function ResolvePlayerIlvl()
  if C_Item and C_Item.GetAverageItemLevel then
    local avgIlvl = C_Item.GetAverageItemLevel()
    if type(avgIlvl) == "number" and avgIlvl > 0 then
      return avgIlvl
    end
  elseif GetAverageItemLevel then
    local avgIlvl, equippedIlvl = GetAverageItemLevel()
    local resolvedIlvl = equippedIlvl or avgIlvl
    if type(resolvedIlvl) == "number" and resolvedIlvl > 0 then
      return resolvedIlvl
    end
  end

  return nil
end

local function ResolvePlayerKeystone()
  local mythicPlusApi = rawget(_G, "C_MythicPlus")
  if not mythicPlusApi then
    return nil, nil
  end

  local okLevel, ownedLevel = pcall(mythicPlusApi.GetOwnedKeystoneLevel)
  local okMapID, ownedMapID = pcall(mythicPlusApi.GetOwnedKeystoneChallengeMapID)
  if not okLevel or not okMapID then
    return nil, nil
  end

  ownedLevel = tonumber(ownedLevel)
  ownedMapID = tonumber(ownedMapID)
  if type(SeasonData.NormalizeMapID) == "function" then
    ownedMapID = SeasonData.NormalizeMapID(ownedMapID)
  end
  if ownedLevel and ownedLevel > 0 and ownedMapID and ownedMapID > 0 then
    return ownedMapID, ownedLevel
  end

  return nil, nil
end

local function BuildFillMembers(playerRole, dummies)
  local fill = {}
  if playerRole == "TANK" then
    table.insert(fill, dummies.healer)
    table.insert(fill, dummies.dd1)
    table.insert(fill, dummies.dd2)
    table.insert(fill, dummies.dd3)
  elseif playerRole == "HEALER" then
    table.insert(fill, dummies.tank)
    table.insert(fill, dummies.dd1)
    table.insert(fill, dummies.dd2)
    table.insert(fill, dummies.dd3)
  else
    -- DAMAGER or NONE
    table.insert(fill, dummies.tank)
    table.insert(fill, dummies.healer)
    table.insert(fill, dummies.dd1)
    table.insert(fill, dummies.dd2)
  end

  return fill
end

function Demo.BuildDummyRoster(opts)
  opts = opts or {}

  local getUnitNameAndRealm = opts.getUnitNameAndRealm or DefaultGetUnitNameAndRealm
  local getUnitServerLanguage = opts.getUnitServerLanguage or function(_unit, _realm)
    return nil
  end
  local getUnitRole = opts.getUnitRole or function(_unit)
    return "DAMAGER"
  end
  local getPlayerSpecName = opts.getPlayerSpecName or function()
    return nil
  end
  local getUnitRio = opts.getUnitRio or function(_unit)
    return nil
  end

  local playerName, playerRealm = getUnitNameAndRealm("player")
  local _, playerClass = UnitClass("player")
  local playerLanguage = getUnitServerLanguage("player", playerRealm) or "DE"
  local playerRole = getUnitRole("player")
  local playerSpec = getPlayerSpecName()
  local playerRio = getUnitRio("player")
  local playerIlvl = ResolvePlayerIlvl()
  local playerKeyMapID, playerKeyLevel = ResolvePlayerKeystone()
  local includeGhostMember = opts.previewVariant == "full" or opts.includeGhostMember == true

  local roster = {
    ["player"] = {
      name = playerName or UnitName("player") or "Player",
      realm = playerRealm or GetRealmName() or "",
      language = playerLanguage or "??",
      class = playerClass or "WARRIOR",
      role = playerRole or "DAMAGER",
      spec = playerSpec,
      ilvl = playerIlvl,
      rio = playerRio,
      hasIsiLive = true,
      keyMapID = playerKeyMapID,
      keyLevel = playerKeyLevel,
    },
  }

  local fill = BuildFillMembers(playerRole, DUMMY_MEMBERS)
  local activeSlots = includeGhostMember and 3 or 4
  for i = 1, math.min(activeSlots, #fill) do
    roster["party" .. i] = CopyRosterEntry(fill[i])
  end

  if includeGhostMember then
    local ghostEntry = CopyRosterEntry(DUMMY_MEMBERS.dd3)
    ghostEntry.isGhost = true
    roster[BuildGhostUnitKey(ghostEntry)] = ghostEntry
  end

  return roster
end
