local _, addonTable = ...

addonTable = addonTable or {}

local Actions = {}
addonTable.UIGameMenuActions = Actions

local ADDON_PANEL_UI_ENTRIES = {
  {
    id = "isilive",
    labelKey = "BTN_ADDON_ISILIVE",
    fallbackText = "isiLive",
    addonNames = { "isiLive" },
    slashText = "/isilive settings",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    skipLoadCheck = true,
  },
  {
    id = "mdt",
    labelKey = "BTN_ADDON_MDT",
    fallbackText = "MDT",
    addonNames = { "MythicDungeonTools" },
    slashText = "/mdt",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
  },
  {
    id = "mrt",
    labelKey = "BTN_ADDON_MRT",
    fallbackText = "MRT",
    addonNames = { "MRT", "ExRT" },
    slashText = "/mrt",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
  },
  {
    id = "dbm",
    labelKey = "BTN_ADDON_DBM",
    fallbackText = "DBM",
    addonNames = { "DBM-Core" },
    slashText = "/dbm",
    icon = "Interface\\Icons\\INV_Misc_Bell_01",
  },
  {
    id = "bigwigs",
    labelKey = "BTN_ADDON_BIGWIGS",
    fallbackText = "BigWigs",
    addonNames = { "BigWigs" },
    slashText = "/bigwigs",
    icon = "Interface\\AddOns\\BigWigs\\Media\\Icons\\minimap_raid.tga",
  },
  {
    id = "details",
    labelKey = "BTN_ADDON_DETAILS",
    fallbackText = "Details",
    addonNames = { "Details" },
    slashText = "/details options",
    slashTextByLocale = {
      deDE = "/details optionen",
    },
    icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
  },
  {
    id = "simc",
    labelKey = "BTN_ADDON_SIMC",
    fallbackText = "SimC",
    addonNames = { "Simulationcraft", "SimulationCraft" },
    slashText = "/simc",
    icon = "Interface\\Icons\\INV_Scroll_03",
  },
  {
    id = "platynator",
    labelKey = "BTN_ADDON_PLATYNATOR",
    fallbackText = "Platynator",
    addonNames = { "Platynator" },
    slashText = "/platynator",
    icon = "Interface\\Icons\\INV_Misc_EngGizmos_30",
  },
}

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return false
  end

  local secureCall = rawget(_G, "securecallfunction")
  if type(secureCall) == "function" then
    local ok = pcall(secureCall, fn, ...)
    return ok
  end

  local ok = pcall(fn, ...)
  return ok
end

local IsAddOnLoaded

local function EnsureAddOnLoaded(addOnName)
  if type(addOnName) ~= "string" or addOnName == "" then
    return false
  end

  local cAddOns = rawget(_G, "C_AddOns")
  if
    type(cAddOns) == "table"
    and type(cAddOns.IsAddOnLoaded) == "function"
    and type(cAddOns.LoadAddOn) == "function"
  then
    local loadedOk, isLoaded = pcall(cAddOns.IsAddOnLoaded, addOnName)
    if loadedOk and isLoaded then
      return true
    end
    pcall(cAddOns.LoadAddOn, addOnName)
    return IsAddOnLoaded(addOnName)
  end

  local loadAddOn = rawget(_G, "UIParentLoadAddOn")
  if type(loadAddOn) == "function" then
    pcall(loadAddOn, addOnName)
    return IsAddOnLoaded(addOnName)
  end

  return false
end

local function IsAddOnInstalled(addOnName)
  if type(addOnName) ~= "string" or addOnName == "" then
    return false
  end

  local cAddOns = rawget(_G, "C_AddOns")
  if type(cAddOns) == "table" and type(cAddOns.GetAddOnInfo) == "function" then
    local ok, info = pcall(cAddOns.GetAddOnInfo, addOnName)
    if ok and info ~= nil then
      return true
    end
  end

  local getAddOnInfo = rawget(_G, "GetAddOnInfo")
  if type(getAddOnInfo) == "function" then
    local ok, nameOrTitle = pcall(getAddOnInfo, addOnName)
    if ok and nameOrTitle ~= nil then
      return true
    end
  end

  return false
end

local function ResolveCurrentCharacterName()
  local unitName = rawget(_G, "UnitName")
  if type(unitName) ~= "function" then
    return nil
  end

  local ok, name = pcall(unitName, "player")
  if not ok or type(name) ~= "string" or name == "" then
    return nil
  end

  return name
end

local function IsEnabledStateForCurrentCharacter(state, hasCurrentCharacter)
  if type(state) == "boolean" then
    return state == true
  end
  if type(state) ~= "number" then
    return false
  end
  if hasCurrentCharacter then
    return state == 2
  end
  return state == 2
end

local function IsAddOnEnabled(addOnName)
  if type(addOnName) ~= "string" or addOnName == "" then
    return false
  end

  local currentCharacter = ResolveCurrentCharacterName()
  local hasCurrentCharacter = type(currentCharacter) == "string" and currentCharacter ~= ""
  local cAddOns = rawget(_G, "C_AddOns")
  if type(cAddOns) == "table" and type(cAddOns.GetAddOnEnableState) == "function" then
    local ok, state = pcall(cAddOns.GetAddOnEnableState, addOnName, currentCharacter)
    if ok then
      return IsEnabledStateForCurrentCharacter(state, hasCurrentCharacter)
    end
  end

  local getAddOnEnableState = rawget(_G, "GetAddOnEnableState")
  if type(getAddOnEnableState) == "function" then
    local ok, state = pcall(getAddOnEnableState, currentCharacter, addOnName)
    if ok then
      return IsEnabledStateForCurrentCharacter(state, hasCurrentCharacter)
    end
  end

  return false
end

function IsAddOnLoaded(addOnName)
  if type(addOnName) ~= "string" or addOnName == "" then
    return false
  end

  local cAddOns = rawget(_G, "C_AddOns")
  if type(cAddOns) == "table" and type(cAddOns.IsAddOnLoaded) == "function" then
    local ok, isLoaded = pcall(cAddOns.IsAddOnLoaded, addOnName)
    return ok and isLoaded == true
  end

  local isAddOnLoaded = rawget(_G, "IsAddOnLoaded")
  if type(isAddOnLoaded) == "function" then
    local ok, isLoaded = pcall(isAddOnLoaded, addOnName)
    return ok and isLoaded == true
  end

  return false
end

local function ResolveEnabledAddOnName(addOnNames)
  if type(addOnNames) ~= "table" then
    return nil
  end

  for _, addOnName in ipairs(addOnNames) do
    if IsAddOnInstalled(addOnName) and IsAddOnEnabled(addOnName) then
      return addOnName
    end
  end

  return nil
end

local function ParseSlashCommandText(slashText)
  if type(slashText) ~= "string" or slashText == "" then
    return nil, nil
  end

  local command, args = slashText:match("^(%S+)%s*(.-)$")
  if type(command) ~= "string" or command == "" then
    return nil, nil
  end

  return string.lower(command), args or ""
end

local function ResolveLocaleSlashText(entry)
  if type(entry) ~= "table" then
    return nil
  end

  local byLocale = entry.slashTextByLocale
  local getLocale = rawget(_G, "GetLocale")
  local locale = type(getLocale) == "function" and getLocale() or nil
  if type(byLocale) == "table" and type(locale) == "string" and type(byLocale[locale]) == "string" then
    return byLocale[locale]
  end

  return entry.slashText
end

local function FindSlashHandlerByCommandAlias(commandText)
  if type(commandText) ~= "string" or commandText == "" then
    return nil
  end

  local slashCmdList = rawget(_G, "SlashCmdList")
  if type(slashCmdList) ~= "table" then
    return nil
  end

  local normalizedCommand = string.lower(commandText)
  for slashId, handler in pairs(slashCmdList) do
    if type(slashId) == "string" and type(handler) == "function" then
      for index = 1, 20 do
        local alias = rawget(_G, "SLASH_" .. slashId .. tostring(index))
        if type(alias) == "string" and string.lower(alias) == normalizedCommand then
          return handler
        end
      end
    end
  end

  return nil
end

local function RunSlashText(slashText)
  local commandText, args = ParseSlashCommandText(slashText)
  if not commandText then
    return false, "invalid"
  end

  local handler = FindSlashHandlerByCommandAlias(commandText)
  if type(handler) == "function" then
    local ok = SafeCall(handler, args or "")
    return ok, ok and nil or "handler_failed"
  end

  return false, "missing_handler"
end

local ADDON_SLASH_RETRY_DELAY_SECONDS = 0.25
local ADDON_SLASH_RETRY_MAX_ATTEMPTS = 12

local function RetrySlashTextWhenHandlerAppears(slashText, attempt)
  attempt = tonumber(attempt) or 1
  if attempt > ADDON_SLASH_RETRY_MAX_ATTEMPTS then
    return
  end

  local timer = rawget(_G, "C_Timer")
  local after = type(timer) == "table" and rawget(timer, "After") or nil
  if type(after) ~= "function" then
    return
  end

  after(ADDON_SLASH_RETRY_DELAY_SECONDS, function()
    local ok, reason = RunSlashText(slashText)
    if ok or reason ~= "missing_handler" then
      return
    end
    RetrySlashTextWhenHandlerAppears(slashText, attempt + 1)
  end)
end

local function RunSlashTextWithHandlerRetry(slashText)
  local ok, reason = RunSlashText(slashText)
  if ok or reason ~= "missing_handler" then
    return ok
  end

  RetrySlashTextWhenHandlerAppears(slashText, 1)
  return false
end

local function ClickButtonSecure(button)
  if type(button) ~= "table" or type(button.Click) ~= "function" then
    return false
  end

  return SafeCall(button.Click, button, "LeftButton", true)
end

local function ClickNamedButtonSecure(buttonName)
  if type(buttonName) ~= "string" or buttonName == "" then
    return false
  end

  return ClickButtonSecure(rawget(_G, buttonName))
end

local function IsNamedFrameShown(frameName)
  if type(frameName) ~= "string" or frameName == "" then
    return false
  end

  local frame = rawget(_G, frameName)
  return type(frame) == "table" and type(frame.IsShown) == "function" and frame:IsShown() == true
end

local function IsAnyNamedFrameShown(frameNames)
  if type(frameNames) ~= "table" then
    return false
  end

  for _, frameName in ipairs(frameNames) do
    if IsNamedFrameShown(frameName) then
      return true
    end
  end

  return false
end

local function OpenViaMicroButton(buttonName, targetFrameNames, fallbackFn, ...)
  if IsAnyNamedFrameShown(targetFrameNames) then
    return true
  end

  ClickNamedButtonSecure(buttonName)
  if IsAnyNamedFrameShown(targetFrameNames) then
    return true
  end

  SafeCall(fallbackFn, ...)
  return IsAnyNamedFrameShown(targetFrameNames)
end

local function BuildDefaultPanelUIActions(isInCombat)
  local function IsBlockedInCombat()
    return type(isInCombat) == "function" and isInCombat() == true
  end

  local function OpenProfessions()
    return OpenViaMicroButton(
      "ProfessionMicroButton",
      { "ProfessionsFrame", "ProfessionsBookFrame", "TradeSkillFrame" },
      rawget(_G, "ToggleProfessionsBook")
    )
  end

  local function OpenTalents()
    if IsBlockedInCombat() then
      return false
    end
    if ClickNamedButtonSecure("PlayerSpellsMicroButton") then
      return true
    end
    if ClickNamedButtonSecure("TalentMicroButton") then
      return true
    end

    EnsureAddOnLoaded("Blizzard_PlayerSpells")
    local playerSpellsUtil = rawget(_G, "PlayerSpellsUtil")
    if type(playerSpellsUtil) == "table" then
      if SafeCall(playerSpellsUtil.ToggleClassTalentFrame) then
        return true
      end

      local frameTabs = rawget(playerSpellsUtil, "FrameTabs")
      local classTalentsTab = type(frameTabs) == "table" and rawget(frameTabs, "ClassTalents") or nil
      if classTalentsTab ~= nil and SafeCall(rawget(_G, "TogglePlayerSpellsFrame"), classTalentsTab) then
        return true
      end

      if SafeCall(playerSpellsUtil.ToggleClassTalentOrSpecFrame) then
        return true
      end
    end

    return false
  end

  local function OpenSpellbook()
    if IsBlockedInCombat() then
      return false
    end

    EnsureAddOnLoaded("Blizzard_PlayerSpells")
    local playerSpellsUtil = rawget(_G, "PlayerSpellsUtil")
    if type(playerSpellsUtil) == "table" then
      local toggleSpellBookFrame = rawget(playerSpellsUtil, "ToggleSpellBookFrame")
      if type(toggleSpellBookFrame) == "function" and SafeCall(toggleSpellBookFrame) then
        return true
      end

      local frameTabs = rawget(playerSpellsUtil, "FrameTabs")
      local spellBookTab = type(frameTabs) == "table" and rawget(frameTabs, "SpellBook") or nil
      local togglePlayerSpellsFrame = rawget(_G, "TogglePlayerSpellsFrame")
      if
        spellBookTab ~= nil
        and type(togglePlayerSpellsFrame) == "function"
        and SafeCall(togglePlayerSpellsFrame, spellBookTab)
      then
        return true
      end
    end

    return ClickNamedButtonSecure("SpellbookMicroButton")
  end

  local function OpenAchievements()
    return OpenViaMicroButton("AchievementMicroButton", { "AchievementFrame" }, rawget(_G, "ToggleAchievementFrame"))
  end

  local function OpenQuestLog()
    EnsureAddOnLoaded("Blizzard_WorldMap")
    return OpenViaMicroButton("QuestLogMicroButton", { "QuestLogFrame", "WorldMapFrame" }, rawget(_G, "ToggleQuestLog"))
  end

  local function OpenDungeons()
    EnsureAddOnLoaded("Blizzard_GroupFinder")
    return OpenViaMicroButton("LFDMicroButton", { "PVEFrame" }, rawget(_G, "PVEFrame_ToggleFrame"))
  end

  local function OpenJournal()
    return OpenViaMicroButton("EJMicroButton", { "EncounterJournal" }, rawget(_G, "ToggleEncounterJournal"))
  end

  local function OpenCollections()
    return OpenViaMicroButton(
      "CollectionsMicroButton",
      { "CollectionsJournal" },
      rawget(_G, "ToggleCollectionsJournal")
    )
  end

  local function OpenGuild()
    EnsureAddOnLoaded("Blizzard_Communities")
    return OpenViaMicroButton("GuildMicroButton", { "CommunitiesFrame", "GuildFrame" }, rawget(_G, "ToggleGuildFrame"))
  end

  return {
    professions = OpenProfessions,
    talents = OpenTalents,
    spellbook = OpenSpellbook,
    achievements = OpenAchievements,
    quests = OpenQuestLog,
    dungeons = OpenDungeons,
    journal = OpenJournal,
    collections = OpenCollections,
    guild = OpenGuild,
  }
end

local function MergePanelUIActions(isInCombat, overrides)
  local actions = BuildDefaultPanelUIActions(isInCombat)
  if type(overrides) ~= "table" then
    return actions
  end

  for key, value in pairs(overrides) do
    if type(value) == "function" then
      actions[key] = value
    end
  end

  return actions
end

local function BuildAddonPanelUIActions(overrides)
  local actions = {}
  for _, entry in ipairs(ADDON_PANEL_UI_ENTRIES) do
    actions[entry.id] = function()
      local addOnName = ResolveEnabledAddOnName(entry.addonNames)
      if not addOnName then
        return false
      end
      if entry.skipLoadCheck ~= true and not EnsureAddOnLoaded(addOnName) then
        return false
      end
      return RunSlashTextWithHandlerRetry(ResolveLocaleSlashText(entry))
    end
  end
  if type(overrides) == "table" then
    for key, value in pairs(overrides) do
      if type(value) == "function" then
        actions[key] = value
      end
    end
  end
  return actions
end

local function ResolveVisibleAddonPanelEntries()
  local visible = {}
  for _, entry in ipairs(ADDON_PANEL_UI_ENTRIES) do
    local addOnName = ResolveEnabledAddOnName(entry.addonNames)
    if addOnName then
      visible[#visible + 1] = entry
    end
  end
  return visible
end

Actions.BuildDefaultPanelUIActions = BuildDefaultPanelUIActions
Actions.MergePanelUIActions = MergePanelUIActions
Actions.BuildAddonPanelUIActions = BuildAddonPanelUIActions
Actions.ResolveVisibleAddonPanelEntries = ResolveVisibleAddonPanelEntries
