local _, addonTable = ...

addonTable = addonTable or {}

local HearthstoneDebug = {}
addonTable.HearthstoneDebug = HearthstoneDebug

local function ValueText(value)
  if value == nil then
    return "nil"
  end
  if type(value) == "boolean" then
    return value and "true" or "false"
  end
  return tostring(value)
end

local function IsOwnedToy(toyID)
  local playerHasToy = rawget(_G, "PlayerHasToy")
  if type(playerHasToy) ~= "function" then
    return nil, "unavailable"
  end
  local ok, owned = pcall(playerHasToy, toyID)
  if not ok then
    return nil, "error:" .. tostring(owned)
  end
  return owned == true, nil
end

local function ReadToyInfo(toyID)
  local toyBox = rawget(_G, "C_ToyBox")
  if type(toyBox) ~= "table" or type(toyBox.GetToyInfo) ~= "function" then
    return nil, "unavailable"
  end
  local ok, itemID, name, icon = pcall(toyBox.GetToyInfo, toyID)
  if not ok then
    return nil, "error:" .. tostring(itemID)
  end
  return {
    itemID = itemID,
    name = name,
    icon = icon,
  }
end

local function CollectKnownToyIDs()
  local travel = addonTable.UIGameMenuTravel
  if type(travel) ~= "table" or type(travel.GetKnownHearthstoneToyIDs) ~= "function" then
    return {}
  end
  local ids = travel.GetKnownHearthstoneToyIDs()
  if type(ids) ~= "table" then
    return {}
  end
  return ids
end

function HearthstoneDebug.BuildDumpLines()
  local lines = {}
  local ids = CollectKnownToyIDs()
  lines[#lines + 1] = "[HEARTH] knownToyCount=" .. tostring(#ids)

  for _, toyID in ipairs(ids) do
    local owned, ownedErr = IsOwnedToy(toyID)
    local info, infoErr = ReadToyInfo(toyID)
    lines[#lines + 1] = string.format(
      "[HEARTH] toy=%s owned=%s name=%s itemID=%s icon=%s ownedSource=%s infoSource=%s",
      ValueText(toyID),
      ValueText(owned),
      ValueText(info and info.name),
      ValueText(info and info.itemID),
      ValueText(info and info.icon),
      ValueText(ownedErr or "ok"),
      ValueText(infoErr or "ok")
    )
  end

  return lines
end

function HearthstoneDebug.PrintDump(printFn)
  printFn = type(printFn) == "function" and printFn or print
  for _, line in ipairs(HearthstoneDebug.BuildDumpLines()) do
    printFn(line)
  end
end
