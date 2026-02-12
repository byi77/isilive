local _, addonTable = ...

addonTable = addonTable or {}

local Roster = {}
addonTable.Roster = Roster

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
    totalMembers = totalMembers + 1
    if info.hasIsiLive then
      syncedMembers = syncedMembers + 1
    end
  end
  return totalMembers >= 2 and syncedMembers == totalMembers
end

function Roster.BuildDisplayData(info, opts)
  opts = opts or {}
  local truncateName = opts.truncateName
  local getLanguageFlagMarkup = opts.getLanguageFlagMarkup
  local syncMarker = opts.syncMarker or ""
  local fullSyncMarker = opts.fullSyncMarker or ""
  local hasFullSync = opts.hasFullSync == true

  local classColor = RAID_CLASS_COLORS[info.class] or { r = 1, g = 1, b = 1 }
  local colorHex = CreateColor(classColor.r, classColor.g, classColor.b):GenerateHexColor()

  local displayName = info.name or ""
  if truncateName then
    displayName = truncateName(displayName, 10)
  end

  local languageText = info.language or "??"
  local languageShort = tostring(languageText):upper():sub(1, 2)
  if not languageShort or #languageShort < 2 then
    languageShort = "??"
  end
  local flagMarkup = getLanguageFlagMarkup and getLanguageFlagMarkup(languageShort) or "|cffbfbfbf??|r"
  local languageDisplay = string.format("%s |cffd9d9d9%s|r", flagMarkup, languageShort)

  local specText = info.spec or "-"
  if info.spec and truncateName then
    specText = truncateName(info.spec, 15)
  end
  local ilvlText = info.ilvl and tostring(math.floor(info.ilvl)) or "-"
  local rioText = info.rio and tostring(math.floor(info.rio)) or "-"
  local addonMarker = info.hasIsiLive and (hasFullSync and fullSyncMarker or syncMarker) or ""

  return {
    colorHex = colorHex,
    displayName = displayName,
    languageDisplay = languageDisplay,
    specText = specText,
    ilvlText = ilvlText,
    rioText = rioText,
    addonMarker = addonMarker,
  }
end
