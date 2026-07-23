local _, addonTable = ...

addonTable = addonTable or {}

local Demo = {}
addonTable.Demo = Demo

local SeasonData = addonTable.SeasonData or {}
local IsSecretValue = addonTable.Validators.IsSecretValue

local DUMMY_MEMBERS = {
  tank = {
    name = "Stormbreaker",
    realm = "Blackmoore",
    language = "EN",
    class = "DRUID",
    role = "TANK",
    spec = "Wachter",
    ilvl = 272,
    rio = 3120,
    keyMapID = 559, -- Nexus-Point Xenas
    keyLevel = 10,
    syncKickOnCooldown = false,
    isDemoEntry = true,
  },
  healer = {
    name = "Velindra",
    realm = "Hyjal",
    language = "FR",
    class = "PRIEST",
    role = "HEALER",
    spec = "Holy",
    ilvl = 268,
    rio = 2980,
    keyMapID = 560, -- Maisara Caverns
    keyLevel = 9,
    isDemoEntry = true,
  },
  dd1 = {
    name = "Zephyrax",
    realm = "Kazzak",
    language = "ES",
    class = "MAGE",
    role = "DAMAGER",
    spec = "Frost",
    ilvl = 275,
    rio = 3210,
    keyMapID = 557, -- Windrunner Spire
    keyLevel = 11,
    syncKickOnCooldown = true,
    syncKickRemain = 14,
    syncDps = 148000,
    isDemoEntry = true,
  },
  dd2 = {
    name = "Thornwall",
    realm = "Blackhand",
    language = "IT",
    class = "PALADIN",
    role = "DAMAGER",
    spec = "Retri",
    ilvl = 269,
    rio = 2870,
    keyMapID = 558, -- Magisters' Terrace
    keyLevel = 8,
    syncHasKick = true,
    syncKickOnCooldown = false,
    syncKickExtras = {
      [31935] = { cooldownRemain = 21 },
    },
    syncDps = 152000,
    isDemoEntry = true,
  },
  dd3 = {
    name = "Ravencast",
    realm = "Antonidas",
    language = "PT",
    class = "HUNTER",
    role = "DAMAGER",
    spec = "Marksmanship",
    ilvl = 271,
    rio = 3050,
    keyMapID = 402, -- Algeth'ar Academy
    keyLevel = 10,
    syncKickOnCooldown = true,
    syncKickRemain = 6,
    syncDps = 145000,
    isDemoEntry = true,
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
  if type(unit) ~= "string" or unit == "" then
    return nil, nil
  end

  local unitExists = rawget(_G, "UnitExists")
  if type(unitExists) ~= "function" then
    return nil, nil
  end

  local okExists, exists = pcall(unitExists, unit)
  if not okExists or IsSecretValue(exists) or exists ~= true then
    return nil, nil
  end

  local name, realm = nil, nil
  local unitFullName = rawget(_G, "UnitFullName")
  if type(unitFullName) == "function" then
    local okFullName, fullName, fullRealm = pcall(unitFullName, unit)
    if okFullName and not IsSecretValue(fullName) and not IsSecretValue(fullRealm) then
      name = fullName
      realm = fullRealm
    end
  end

  if not name then
    local unitName = rawget(_G, "UnitName")
    if type(unitName) == "function" then
      local okName, fallbackName = pcall(unitName, unit)
      if okName and not IsSecretValue(fallbackName) then
        name = fallbackName
      end
    end
  end

  if addonTable.StringUtils.IsBlank(realm) then
    local getRealmName = rawget(_G, "GetRealmName")
    local okRealm, fallbackRealm = false, nil
    if type(getRealmName) == "function" then
      okRealm, fallbackRealm = pcall(getRealmName)
    end
    realm = okRealm and not IsSecretValue(fallbackRealm) and fallbackRealm or ""
  end
  return name, realm
end

local function DefaultGetUnitClass(unit)
  if type(unit) ~= "string" or unit == "" then
    return nil, nil
  end

  local unitExists = rawget(_G, "UnitExists")
  if type(unitExists) ~= "function" then
    return nil, nil
  end

  local okExists, exists = pcall(unitExists, unit)
  if not okExists or IsSecretValue(exists) or exists ~= true then
    return nil, nil
  end

  local unitClass = rawget(_G, "UnitClass")
  if type(unitClass) ~= "function" then
    return nil, nil
  end

  local okClass, localizedClass, classToken = pcall(unitClass, unit)
  if not okClass or IsSecretValue(localizedClass) or IsSecretValue(classToken) then
    return nil, nil
  end

  return localizedClass, classToken
end

local function ResolvePlayerIlvl()
  local cItem = rawget(_G, "C_Item")
  if type(cItem) == "table" and type(cItem.GetAverageItemLevel) == "function" then
    local ok, avgIlvl = pcall(cItem.GetAverageItemLevel)
    if ok and not IsSecretValue(avgIlvl) and type(avgIlvl) == "number" and avgIlvl > 0 then
      return avgIlvl
    end
  end

  local legacy = rawget(_G, "GetAverageItemLevel")
  if type(legacy) == "function" then
    local ok, avgIlvl, equippedIlvl = pcall(legacy)
    if not ok or IsSecretValue(avgIlvl) or IsSecretValue(equippedIlvl) then
      return nil
    end
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
  local getUnitClass = opts.getUnitClass or DefaultGetUnitClass
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
  local _, playerClass = getUnitClass("player")
  local playerLanguage = getUnitServerLanguage("player", playerRealm) or "DE"
  local playerRole = getUnitRole("player")
  local playerSpec = getPlayerSpecName()
  local playerRio = getUnitRio("player")
  local playerIlvl = ResolvePlayerIlvl()
  local playerKeyMapID, playerKeyLevel = ResolvePlayerKeystone()
  local includeGhostMember = opts.previewVariant == "full" or opts.includeGhostMember == true
  local fallbackRealm = ""
  if not playerRealm then
    local getRealmName = rawget(_G, "GetRealmName")
    if type(getRealmName) == "function" then
      local okRealm, resolvedRealm = pcall(getRealmName)
      if okRealm and not IsSecretValue(resolvedRealm) and type(resolvedRealm) == "string" then
        fallbackRealm = resolvedRealm
      end
    end
  end

  local roster = {
    ["player"] = {
      name = playerName or "Player",
      realm = playerRealm or fallbackRealm,
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

  -- Avoid showing a dummy with the same class as the player.
  -- Replacement pool: classes not already used by other dummies.
  local usedClasses = { [playerClass or ""] = true }
  for _, member in ipairs(fill) do
    usedClasses[member.class] = true
  end
  local CLASS_FALLBACKS = {
    {
      class = "WARRIOR",
      name = "Ironclad",
      role = "DAMAGER",
      spec = "Arms",
      syncDps = 149000,
      syncKickOnCooldown = false,
    },
    {
      class = "ROGUE",
      name = "Shadowstep",
      role = "DAMAGER",
      spec = "Assassination",
      syncDps = 153000,
      syncKickOnCooldown = true,
      syncKickRemain = 9,
    },
    {
      class = "DEATHKNIGHT",
      name = "Frostmourne",
      role = "DAMAGER",
      spec = "Frost",
      syncDps = 147000,
      syncKickOnCooldown = false,
    },
    {
      class = "MONK",
      name = "Serenova",
      role = "DAMAGER",
      spec = "Windwalker",
      syncDps = 150000,
      syncKickOnCooldown = false,
    },
    {
      class = "DEMONHUNTER",
      name = "Felstrike",
      role = "DAMAGER",
      spec = "Havoc",
      syncDps = 154000,
      syncKickOnCooldown = true,
      syncKickRemain = 3,
    },
    {
      class = "SHAMAN",
      name = "Stormbind",
      role = "DAMAGER",
      spec = "Enhancement",
      syncDps = 146000,
      syncKickOnCooldown = false,
    },
    {
      class = "EVOKER",
      name = "Ashwing",
      role = "DAMAGER",
      spec = "Devastation",
      syncDps = 151000,
      syncKickOnCooldown = false,
    },
  }
  for i, member in ipairs(fill) do
    if playerClass and member.class == playerClass then
      for _, fb in ipairs(CLASS_FALLBACKS) do
        if not usedClasses[fb.class] then
          local replacement = CopyRosterEntry(member)
          replacement.class = fb.class
          replacement.name = fb.name
          replacement.role = fb.role
          replacement.spec = fb.spec
          replacement.syncDps = fb.syncDps
          replacement.syncKickOnCooldown = fb.syncKickOnCooldown
          replacement.syncKickRemain = fb.syncKickRemain
          usedClasses[fb.class] = true
          fill[i] = replacement
          break
        end
      end
    end
  end

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
