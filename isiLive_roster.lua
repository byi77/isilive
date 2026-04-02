local _, addonTable = ...

addonTable = addonTable or {}

local Roster = {}
addonTable.Roster = Roster

local function CreateRoleIcon(coords)
  return string.format("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:%s|t", coords)
end

local ROLE_ICONS = {
  TANK = CreateRoleIcon("0:19:22:41"),
  HEALER = CreateRoleIcon("20:39:1:20"),
  DAMAGER = CreateRoleIcon("20:39:22:41"),
}

local LEADER_MARKER = " |TInterface\\GroupFrame\\UI-Group-LeaderIcon:16:16|t"
local READY_CHECK_WAITING_MARKUP = "|TInterface\\RAIDFRAME\\ReadyCheck-Waiting:16:16:0:0|t "
local READY_CHECK_BACKGROUND_COLORS = {
  ready = { 0.08, 0.5, 0.16, 0.42 },
  notready = { 0.48, 0.12, 0.12, 0.34 },
  waiting = { 0.55, 0.4, 0.08, 0.32 },
}

local function NormalizeDisplayedKeyShortCode(shortCode)
  local text = tostring(shortCode or ""):gsub("%s+", "")
  if text == "" then
    return "?"
  end
  if text:match("^%d+$") then
    return "?"
  end
  return string.upper(string.sub(text, 1, 4))
end

local function BuildColorHexSafe(r, g, b)
  local createColor = rawget(_G, "CreateColor")
  if type(createColor) == "function" then
    local okColor, color = pcall(createColor, r, g, b)
    if okColor and type(color) == "table" and type(color.GenerateHexColor) == "function" then
      local okHex, hex = pcall(color.GenerateHexColor, color)
      if okHex and type(hex) == "string" and hex ~= "" then
        return hex
      end
    end
  end

  local rr = math.max(0, math.min(255, math.floor((tonumber(r) or 1) * 255)))
  local gg = math.max(0, math.min(255, math.floor((tonumber(g) or 1) * 255)))
  local bb = math.max(0, math.min(255, math.floor((tonumber(b) or 1) * 255)))
  return string.format("ff%02x%02x%02x", rr, gg, bb)
end

local function GetReadyCheckStatusSafe(unit)
  local getReadyCheckStatus = rawget(_G, "GetReadyCheckStatus")
  if type(getReadyCheckStatus) ~= "function" then
    return nil
  end

  local ok, status = pcall(getReadyCheckStatus, unit)
  if not ok then
    return nil
  end

  return status
end

local IsExistingUnit = addonTable.Validators.IsExistingUnit

local function IsUnitConnectedSafe(unit)
  if not IsExistingUnit(unit) then
    return true
  end

  local unitIsConnected = rawget(_G, "UnitIsConnected")
  if type(unitIsConnected) ~= "function" then
    return true
  end

  local ok, isConnected = pcall(unitIsConnected, unit)
  if not ok then
    return true
  end

  return isConnected ~= false
end

function Roster.BuildOrderedRoster(roster, rolePriority, unitPriority)
  local orderedRoster = {}
  for unit, info in pairs(roster or {}) do
    table.insert(orderedRoster, { unit = unit, info = info })
  end

  table.sort(orderedRoster, function(a, b)
    local ghostA = a.info.isGhost == true
    local ghostB = b.info.isGhost == true
    if ghostA ~= ghostB then
      return not ghostA
    end
    local roleA = rolePriority[a.info.role or "NONE"] or rolePriority.NONE or 99
    local roleB = rolePriority[b.info.role or "NONE"] or rolePriority.NONE or 99
    if roleA ~= roleB then
      return roleA < roleB
    end
    local unitA = unitPriority[a.unit] or 99
    local unitB = unitPriority[b.unit] or 99
    return unitA < unitB
  end)

  return orderedRoster
end

function Roster.HasFullSync(roster)
  local totalMembers = 0
  local syncedMembers = 0
  for _, info in pairs(roster or {}) do
    if not info.isGhost then
      totalMembers = totalMembers + 1
      if info.hasIsiLive then
        syncedMembers = syncedMembers + 1
      end
    end
  end
  return totalMembers >= 2 and syncedMembers == totalMembers
end

function Roster.BuildDisplayData(info, opts)
  opts = opts or {}
  local unit = opts.unit
  local truncateName = opts.truncateName
  local getShortSpecLabel = opts.getShortSpecLabel
  local getLanguageFlagMarkup = opts.getLanguageFlagMarkup
  local getDungeonShortCode = opts.getDungeonShortCode
  local getRioDelta = opts.getRioDelta
  local syncMarker = opts.syncMarker or ""
  local syncBadge = opts.syncBadge or ""
  local syncSummary = opts.syncSummary
  local isReadyCheckActive = opts.isReadyCheckActive
  local getReadyCheckReadyUntil = opts.getReadyCheckReadyUntil
  local getReadyCheckDeclinedUntil = opts.getReadyCheckDeclinedUntil
  local getTime = opts.getTime

  local isOffline = not info.isGhost and unit and not IsUnitConnectedSafe(unit)

  local colorHex
  if info.isGhost or isOffline then
    colorHex = "ff808080" -- Grey
  else
    local classColors = type(rawget(_G, "RAID_CLASS_COLORS")) == "table" and rawget(_G, "RAID_CLASS_COLORS") or nil
    local classColor = (classColors and classColors[info.class]) or { r = 1, g = 1, b = 1 }
    colorHex = BuildColorHexSafe(classColor.r, classColor.g, classColor.b)
  end

  local readyCheckStatus = nil
  local readyCheckBackgroundColor = nil
  local readyCheckMarkup = ""
  local readyUntil = nil
  local declinedUntil = nil
  if type(getReadyCheckReadyUntil) == "function" and unit then
    readyUntil = tonumber(getReadyCheckReadyUntil(unit))
  end
  if type(getReadyCheckDeclinedUntil) == "function" and unit then
    declinedUntil = tonumber(getReadyCheckDeclinedUntil(unit))
  end
  local now = type(getTime) == "function" and tonumber(getTime()) or nil
  if not isOffline and not info.isGhost and isReadyCheckActive and unit then
    local status = GetReadyCheckStatusSafe(unit)
    if READY_CHECK_BACKGROUND_COLORS[status] then
      readyCheckStatus = status
      readyCheckBackgroundColor = READY_CHECK_BACKGROUND_COLORS[status]
      if status == "waiting" then
        readyCheckMarkup = READY_CHECK_WAITING_MARKUP
      end
    end
  elseif not isOffline and not info.isGhost and readyUntil and now and readyUntil > now then
    readyCheckStatus = "ready"
    readyCheckBackgroundColor = READY_CHECK_BACKGROUND_COLORS.ready
  elseif not isOffline and not info.isGhost and declinedUntil and now and declinedUntil > now then
    readyCheckStatus = "notready"
    readyCheckBackgroundColor = READY_CHECK_BACKGROUND_COLORS.notready
  end

  local displayName = info.name or ""
  if truncateName then
    displayName = truncateName(displayName, 12)
  end

  local lang = tostring(info.language or "")
  local languageShort = #lang >= 2 and lang:upper():sub(1, 2) or "??"
  local flagMarkup = getLanguageFlagMarkup and getLanguageFlagMarkup(languageShort) or "|cffbfbfbf??|r"
  local languageDisplay = flagMarkup

  local specText = info.spec or "-"
  if info.spec and getShortSpecLabel then
    specText = getShortSpecLabel(specText) or specText
  end
  if info.spec and truncateName then
    specText = truncateName(specText, 5)
  end
  local ilvlText = info.ilvl and tostring(math.floor(info.ilvl)) or "-"

  local rioDelta = nil
  if type(getRioDelta) == "function" then
    rioDelta = tonumber(getRioDelta(info, unit))
  end
  local rioText = info.rio and tostring(math.floor(info.rio)) or "-"
  if rioDelta and info.rio then
    rioDelta = math.max(0, math.floor(rioDelta))
    rioText = string.format("(+%d)%s", rioDelta, rioText)
  end
  local keyText = "-"
  if info.keyMapID and info.keyLevel then
    local shortCode = getDungeonShortCode and getDungeonShortCode(info.keyMapID) or tostring(info.keyMapID)
    keyText = string.format("%s +%d", NormalizeDisplayedKeyShortCode(shortCode), tonumber(info.keyLevel) or 0)
  end
  local addonMarker = ""
  if info.hasIsiLive then
    addonMarker = addonMarker .. syncMarker
  end
  if info.isLeader then
    addonMarker = addonMarker .. LEADER_MARKER
  end
  if type(syncSummary) == "table" then
    addonMarker = addonMarker .. syncBadge
  end
  local atDungeonMarker = opts.isAtDungeon and "|TInterface\\MINIMAP\\Minimap_Summon_Icon:12:12:0:0|t" or ""
  local roleIconMarkup = ROLE_ICONS[info.role] or ""

  return {
    colorHex = colorHex,
    displayName = displayName,
    languageDisplay = languageDisplay,
    specText = specText,
    ilvlText = ilvlText,
    rioText = rioText,
    keyText = keyText,
    addonMarker = addonMarker,
    atDungeonMarker = atDungeonMarker,
    roleIconMarkup = roleIconMarkup,
    readyCheckStatus = readyCheckStatus,
    readyCheckBackgroundColor = readyCheckBackgroundColor,
    readyCheckMarkup = readyCheckMarkup,
  }
end
