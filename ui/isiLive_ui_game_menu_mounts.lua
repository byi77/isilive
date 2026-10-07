local _, addonTable = ...

addonTable = addonTable or {}

local Mounts = {}
addonTable.UIGameMenuMounts = Mounts

local RANDOM_FAVORITE_MOUNT_SPELL_ID = 150544
local AH_MOUNT_SPELL_ID = 465235
local REPAIR_MOUNT_SPELL_ID = 122708
local MOUNT_PANEL_UI_ENTRIES = {
  {
    id = "favorite_mount",
    labelKey = "BTN_MOUNT_FAVORITE",
    fallbackText = "Favorite Mount",
    icon = 213588,
    spellID = RANDOM_FAVORITE_MOUNT_SPELL_ID,
    requiresFavorite = true,
  },
  {
    id = "auction_house_mount",
    labelKey = "BTN_MOUNT_AH",
    fallbackText = "AH Mount",
    icon = 1529269,
    spellID = AH_MOUNT_SPELL_ID,
  },
  {
    id = "repair_mount",
    labelKey = "BTN_MOUNT_REPAIR",
    fallbackText = "Repair Mount",
    icon = "Interface\\Icons\\Ability_Mount_TravellersYakMount",
    spellID = REPAIR_MOUNT_SPELL_ID,
  },
}

local function GetMountJournal()
  local mountJournal = rawget(_G, "C_MountJournal")
  if type(mountJournal) ~= "table" then
    return nil
  end
  return mountJournal
end

local function ReadMountInfoByID(mountJournal, mountID)
  if type(mountJournal) ~= "table" or type(mountJournal.GetMountInfoByID) ~= "function" then
    return nil
  end
  if type(mountID) ~= "number" or mountID <= 0 then
    return nil
  end

  local results = { pcall(mountJournal.GetMountInfoByID, mountID) }
  local ok = results[1]
  local spellID = results[3]
  local isUsable = results[6]
  local isFavorite = results[8]
  local shouldHideOnChar = results[11]
  local isCollected = results[12]
  if not ok or type(spellID) ~= "number" then
    return nil
  end

  return {
    mountID = mountID,
    spellID = spellID,
    isCollected = isCollected == true,
    isUsable = isUsable == true,
    isFavorite = isFavorite == true,
    shouldHideOnChar = shouldHideOnChar == true,
  }
end

local function IsMountUsableByID(mountJournal, mountID, info)
  if type(mountJournal) == "table" and type(mountJournal.GetMountUsabilityByID) == "function" then
    local ok, isUsable = pcall(mountJournal.GetMountUsabilityByID, mountID, true)
    if ok and type(isUsable) == "boolean" then
      return isUsable
    end
  end

  return type(info) == "table" and info.isUsable == true
end

local function IsCollectedMountSpellAvailable(spellID)
  local mountJournal = GetMountJournal()
  if type(mountJournal) ~= "table" or type(mountJournal.GetMountFromSpell) ~= "function" then
    return false
  end
  if type(spellID) ~= "number" then
    return false
  end

  local ok, mountID = pcall(mountJournal.GetMountFromSpell, spellID)
  if not ok or type(mountID) ~= "number" or mountID <= 0 then
    return false
  end

  local info = ReadMountInfoByID(mountJournal, mountID)
  return type(info) == "table"
    and info.spellID == spellID
    and info.isCollected == true
    and info.shouldHideOnChar ~= true
end

-- One pass over the whole mount journal (every mount in the game, collected
-- or not) per panel refresh. The ESC menu refreshes the panel on every
-- opening, and two separate passes -- "is there any favorite" and "which
-- favorites are usable here" -- each built two tables per journal entry.
-- Returns whether any collected, non-hidden favorite exists and the spell IDs
-- of those that are usable right now.
local function CollectFavoriteMounts()
  local usableSpellIDs = {}
  local mountJournal = GetMountJournal()
  if
    type(mountJournal) ~= "table"
    or type(mountJournal.GetMountIDs) ~= "function"
    or type(mountJournal.GetMountInfoByID) ~= "function"
  then
    return false, usableSpellIDs
  end

  local okIDs, mountIDs = pcall(mountJournal.GetMountIDs)
  if not okIDs or type(mountIDs) ~= "table" then
    return false, usableSpellIDs
  end

  local hasFavorite = false
  local getMountInfoByID = mountJournal.GetMountInfoByID
  for _, mountID in ipairs(mountIDs) do
    if type(mountID) == "number" and mountID > 0 then
      local ok, _, spellID, _, _, isUsable, _, isFavorite, _, _, shouldHideOnChar, isCollected =
        pcall(getMountInfoByID, mountID)
      if
        ok
        and type(spellID) == "number"
        and isFavorite == true
        and isCollected == true
        and shouldHideOnChar ~= true
      then
        hasFavorite = true
        if IsMountUsableByID(mountJournal, mountID, { isUsable = isUsable == true }) then
          usableSpellIDs[#usableSpellIDs + 1] = spellID
        end
      end
    end
  end
  return hasFavorite, usableSpellIDs
end

local function ResolveSpellNameByID(spellID)
  if type(spellID) ~= "number" then
    return nil
  end

  local cSpell = rawget(_G, "C_Spell")
  local getSpellName = type(cSpell) == "table" and cSpell.GetSpellName or nil
  if type(getSpellName) == "function" then
    local ok, spellName = pcall(getSpellName, spellID)
    if ok and type(spellName) == "string" and spellName ~= "" then
      return spellName
    end
  end

  local cSpellInfo = type(cSpell) == "table" and cSpell.GetSpellInfo or nil
  if type(cSpellInfo) == "function" then
    local ok, spellInfo = pcall(cSpellInfo, spellID)
    if ok and type(spellInfo) == "table" and type(spellInfo.name) == "string" and spellInfo.name ~= "" then
      return spellInfo.name
    end
  end

  local getSpellInfo = rawget(_G, "GetSpellInfo")
  if type(getSpellInfo) == "function" then
    local ok, spellName = pcall(getSpellInfo, spellID)
    if ok and type(spellName) == "string" and spellName ~= "" then
      return spellName
    end
  end

  return nil
end

local function ResolveMountMacroText(spellID)
  local spellName = ResolveSpellNameByID(spellID)
  if type(spellName) ~= "string" or spellName == "" then
    return nil
  end
  if spellName:find("\n", 1, true) or spellName:find("\r", 1, true) then
    return nil
  end

  return "/click GameMenuButtonContinue\n/cast " .. spellName
end

local function ResolveFavoriteMountMacroText(spellIDs)
  if type(spellIDs) ~= "table" or #spellIDs == 0 then
    return nil
  end

  local index = #spellIDs == 1 and 1 or math.random(1, #spellIDs)
  return ResolveMountMacroText(spellIDs[index])
end

local function CloneMountPanelEntryWithMacro(entry, favoriteSpellIDs)
  if type(entry) ~= "table" then
    return nil
  end

  local macroText = entry.requiresFavorite == true and ResolveFavoriteMountMacroText(favoriteSpellIDs)
    or ResolveMountMacroText(entry.spellID)
  if type(macroText) ~= "string" or macroText == "" then
    return nil
  end

  local clone = {}
  for key, value in pairs(entry) do
    clone[key] = value
  end
  clone.secureMacroText = macroText
  return clone
end

local function ResolveVisibleMountPanelEntries()
  local visible = {}
  local favoritesResolved = false
  local hasFavorite, favoriteSpellIDs = false, nil
  for _, entry in ipairs(MOUNT_PANEL_UI_ENTRIES) do
    local isVisible
    if entry.requiresFavorite == true then
      if not favoritesResolved then
        hasFavorite, favoriteSpellIDs = CollectFavoriteMounts()
        favoritesResolved = true
      end
      isVisible = hasFavorite
    else
      isVisible = IsCollectedMountSpellAvailable(entry.spellID)
    end
    if isVisible then
      local visibleEntry = CloneMountPanelEntryWithMacro(entry, favoriteSpellIDs)
      if visibleEntry ~= nil then
        visible[#visible + 1] = visibleEntry
      end
    end
  end
  return visible
end

Mounts.ResolveVisibleMountPanelEntries = ResolveVisibleMountPanelEntries
Mounts.MOUNT_PANEL_UI_ENTRIES = MOUNT_PANEL_UI_ENTRIES
