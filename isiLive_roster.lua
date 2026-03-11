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
  local createColor = _G.CreateColor
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
  local getReadyCheckStatus = _G.GetReadyCheckStatus
  if type(getReadyCheckStatus) ~= "function" then
    return nil
  end

  local ok, status = pcall(getReadyCheckStatus, unit)
  if not ok then
    return nil
  end

  return status
end

function Roster.BuildOrderedRoster(roster, rolePriority, unitPriority)
  local orderedRoster = {}
  for unit, info in pairs(roster or {}) do
    table.insert(orderedRoster, { unit = unit, info = info })
  end

  table.sort(orderedRoster, function(a, b)
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
  local isReadyCheckActive = opts.isReadyCheckActive

  local colorHex
  if info.isGhost then
    colorHex = "ff808080" -- Grey
  else
    local classColors = type(rawget(_G, "RAID_CLASS_COLORS")) == "table" and rawget(_G, "RAID_CLASS_COLORS") or nil
    local classColor = (classColors and classColors[info.class]) or { r = 1, g = 1, b = 1 }
    colorHex = BuildColorHexSafe(classColor.r, classColor.g, classColor.b)
  end

  if isReadyCheckActive and unit then
    local status = GetReadyCheckStatusSafe(unit)
    if status == "ready" then
      colorHex = "ff00ff00" -- Green
    elseif status == "notready" then
      colorHex = "ffff0000" -- Red
    elseif status == "waiting" then
      colorHex = "ffffff00" -- Yellow
    end
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
    specText = truncateName(specText, 6)
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
  local addonMarker = info.hasIsiLive and syncMarker or ""
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
  }
end
