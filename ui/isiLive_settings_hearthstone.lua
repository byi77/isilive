local _, addonTable = ...
addonTable = addonTable or {}

local SettingsHearthstone = {}
addonTable.SettingsHearthstone = SettingsHearthstone

local function RequestHearthstoneToyItemData(toyId)
  toyId = tonumber(toyId)
  if not toyId then
    return
  end
  local itemApi = rawget(_G, "C_Item")
  if type(itemApi) == "table" and type(itemApi.RequestLoadItemDataByID) == "function" then
    pcall(itemApi.RequestLoadItemDataByID, toyId)
    return
  end
  local itemFactory = rawget(_G, "Item")
  if type(itemFactory) == "table" and type(itemFactory.CreateFromItemID) == "function" then
    pcall(itemFactory.CreateFromItemID, toyId)
  end
end

local function ResolveHearthstoneSettingsLocale(config)
  if type(config) == "table" then
    if type(config.getCurrentLocale) == "function" then
      local ok, locale = pcall(config.getCurrentLocale)
      if ok and type(locale) == "string" and locale ~= "" then
        return locale
      end
    end
    if type(config.getDB) == "function" then
      local ok, db = pcall(config.getDB)
      if ok and type(db) == "table" and type(db.locale) == "string" and db.locale ~= "" then
        return db.locale
      end
    end
  end

  local getLocale = rawget(_G, "GetLocale")
  if type(getLocale) == "function" then
    local ok, locale = pcall(getLocale)
    if ok and type(locale) == "string" and locale ~= "" then
      return locale
    end
  end

  return "enUS"
end

local function ReadEnglishToyName(toyId)
  local getEnglishName = addonTable.UI and addonTable.UI.GetHearthstoneToyEnglishName
  if type(getEnglishName) ~= "function" then
    return nil
  end
  local name = getEnglishName(toyId)
  if type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- Blizzard item APIs answer in the client language only.
local function ReadClientToyName(toyId)
  local toyBox = rawget(_G, "C_ToyBox")
  if type(toyBox) == "table" and type(toyBox.GetToyInfo) == "function" then
    local ok, _, name = pcall(toyBox.GetToyInfo, toyId)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end

  local itemApi = rawget(_G, "C_Item")
  if type(itemApi) == "table" and type(itemApi.GetItemNameByID) == "function" then
    local ok, name = pcall(itemApi.GetItemNameByID, toyId)
    if ok and type(name) == "string" and name ~= "" then
      return name
    end
  end

  local getItemInfo = rawget(_G, "GetItemInfo")
  if type(getItemInfo) == "function" then
    local ok, itemName = pcall(getItemInfo, toyId)
    if ok and type(itemName) == "string" and itemName ~= "" then
      return itemName
    end
  end

  return nil
end

-- Same contract as the dungeon names in SeasonData: the live client name is
-- used only when the addon language is the client language (a frFR addon on a
-- deDE client would otherwise mix German toy names into French settings);
-- every other case, and a cold item cache, falls back to the English name.
local function ResolveHearthstoneToyDisplayName(toyId, config)
  toyId = tonumber(toyId)
  if not toyId then
    return nil
  end

  local languages = addonTable.Languages
  local addonLocale = ResolveHearthstoneSettingsLocale(config)
  if
    type(languages) == "table"
    and type(languages.IsClientLocale) == "function"
    and languages.IsClientLocale(addonLocale)
  then
    local clientName = ReadClientToyName(toyId)
    if clientName then
      return clientName
    end
    RequestHearthstoneToyItemData(toyId)
  end

  return ReadEnglishToyName(toyId)
end

function SettingsHearthstone.BuildOptions(config, labels)
  labels = type(labels) == "table" and labels or {}
  local options = {
    {
      value = "random",
      fallback = labels.SETTINGS_HEARTHSTONE_RANDOM or "Random owned Hearthstone",
    },
    {
      value = "item:6948",
      fallback = labels.SETTINGS_HEARTHSTONE_DEFAULT or "Default Hearthstone (6948)",
    },
  }

  local collectOwned = addonTable.UI and addonTable.UI.CollectOwnedHearthstoneToys
  if type(collectOwned) == "function" then
    local pool = collectOwned()
    if type(pool) == "table" and #pool > 0 then
      for _, toyId in ipairs(pool) do
        local itemLabel = ResolveHearthstoneToyDisplayName(toyId, config)
        if itemLabel then
          options[#options + 1] = {
            value = "toy:" .. tostring(toyId),
            fallback = itemLabel,
          }
        end
      end
    end
  end

  return options
end
