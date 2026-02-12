local addonName, addonTable = ...

addonTable = addonTable or {}

local Teleport = {}
addonTable.Teleport = Teleport

local TWW_SEASON3_MAP_TO_TELEPORT = {
    [499] = 445444,  -- Priory of the Sacred Flame
    [542] = 1237215, -- Eco-Dome Al'dani
    [378] = 354465,  -- Halls of Atonement
    [525] = 1216786, -- Operation: Floodgate
    [503] = 445417,  -- Ara-Kara, City of Echoes
    [392] = 367416,  -- Tazavesh: So'leah's Gambit
    [505] = 445414,  -- The Dawnbreaker
}

local TWW_SEASON3_NAME_ALIASES = {
    ["priory of the sacred flame"] = 499,
    ["eco dome aldani"] = 542,
    ["eco dome al dani"] = 542,
    ["halls of atonement"] = 378,
    ["operation floodgate"] = 525,
    ["ara kara city of echoes"] = 503,
    ["arakara city of echoes"] = 503,
    ["tazavesh soleahs gambit"] = 392,
    ["tazavesh so leahs gambit"] = 392,
    ["the dawnbreaker"] = 505,
}

local season3TeleportByName = nil

local function NormalizeDungeonName(name)
    if not name or name == "" then return nil end
    local low = string.lower(tostring(name))
    low = low:gsub("|c%x%x%x%x%x%x%x%x", "")
    low = low:gsub("|r", "")
    low = low:gsub("[%p]", " ")
    low = low:gsub("%s+", " ")
    low = low:gsub("^%s+", "")
    low = low:gsub("%s+$", "")
    if low == "" then return nil end
    return low
end

function Teleport.GetSeason3TeleportInfoByMapID(mapID)
    local numericMapID = tonumber(mapID)
    if not numericMapID then return nil end

    local spellID = TWW_SEASON3_MAP_TO_TELEPORT[numericMapID]
    if not spellID then return nil end

    local icon
    if C_Spell and C_Spell.GetSpellTexture then
        icon = C_Spell.GetSpellTexture(spellID)
    end
    if not icon then
        icon = "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    local mapName = (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(numericMapID)) or tostring(numericMapID)
    return {
        mapID = numericMapID,
        mapName = mapName,
        spellID = spellID,
        icon = icon,
    }
end

function Teleport.ResolveSeason3TeleportSpellIDByMapID(mapID)
    local info = Teleport.GetSeason3TeleportInfoByMapID(mapID)
    return info and info.spellID or nil
end

local function BuildSeason3TeleportNameCache()
    season3TeleportByName = season3TeleportByName or {}

    for mapID in pairs(TWW_SEASON3_MAP_TO_TELEPORT) do
        local info = Teleport.GetSeason3TeleportInfoByMapID(mapID)
        if info then
            local normalized = NormalizeDungeonName(info.mapName)
            if normalized then
                season3TeleportByName[normalized] = info.spellID
            end
        end
    end

    for aliasName, mapID in pairs(TWW_SEASON3_NAME_ALIASES) do
        local spellID = Teleport.ResolveSeason3TeleportSpellIDByMapID(mapID)
        if spellID then
            season3TeleportByName[aliasName] = spellID
        end
    end

    return season3TeleportByName
end

function Teleport.ResolveSeason3TeleportSpellIDByActivityID(activityID)
    if not (activityID and C_LFGList and C_LFGList.GetActivityInfoTable) then
        return nil
    end
    local info = C_LFGList.GetActivityInfoTable(activityID)
    if not info then return nil end

    local mapID = tonumber(rawget(info, "mapID") or rawget(info, "mapId"))
    if mapID then
        local spellID = Teleport.ResolveSeason3TeleportSpellIDByMapID(mapID)
        if spellID then
            return spellID, mapID
        end
    end
    return nil
end

function Teleport.ResolveSeason3TeleportSpellID(activityID, dungeonName)
    local resolvedDungeonName = dungeonName

    local spellFromActivityID = Teleport.ResolveSeason3TeleportSpellIDByActivityID(activityID)
    if spellFromActivityID then
        return spellFromActivityID
    end

    if activityID and C_LFGList and C_LFGList.GetActivityInfoTable then
        local info = C_LFGList.GetActivityInfoTable(activityID)
        if info then
            resolvedDungeonName = resolvedDungeonName
                or rawget(info, "fullName")
                or rawget(info, "shortName")
                or rawget(info, "activityName")
        end
    end

    local normalized = NormalizeDungeonName(resolvedDungeonName)
    if not normalized then return nil end

    local cache = BuildSeason3TeleportNameCache()
    return cache[normalized]
end

function Teleport.ApplySecureSpellToButton(button, spellID)
    if not button or not spellID then return false end

    local spellValue = spellID
    if C_Spell and C_Spell.GetSpellName then
        local spellName = C_Spell.GetSpellName(spellID)
        if spellName and spellName ~= "" then
            spellValue = spellName
        end
    end

    button.spellID = spellID
    button:SetAttribute("type", "spell")
    button:SetAttribute("type1", "spell")
    button:SetAttribute("*type1", "spell")
    button:SetAttribute("useOnKeyDown", true)
    button:SetAttribute("spell", spellValue)
    button:SetAttribute("spell1", spellValue)
    return true
end

function Teleport.BuildSeason3TeleportEntries()
    local entries = {}
    for mapID in pairs(TWW_SEASON3_MAP_TO_TELEPORT) do
        local info = Teleport.GetSeason3TeleportInfoByMapID(mapID)
        if info then
            table.insert(entries, info)
        end
    end
    table.sort(entries, function(a, b)
        return tostring(a.mapName) < tostring(b.mapName)
    end)
    return entries
end

