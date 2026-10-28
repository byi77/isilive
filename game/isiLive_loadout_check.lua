local _, addonTable = ...
addonTable = addonTable or {}

local LoadoutCheck = {}
addonTable.LoadoutCheck = LoadoutCheck

-- Pre-key loadout check: entering a dungeon of the active M+ season (Mythic
-- difficulty, no key running, in a party) compares the active talent loadout
-- and the loot specialization against the state the player last confirmed for
-- this dungeon and spec. A card shows the result, offers one-click switches to
-- every saved loadout and loot spec, and "confirm" stores the current state as
-- the new target. Without a stored target nothing is judged (no-guess rule):
-- the card only shows the current state and offers to remember it.
--
-- Storage: IsiLiveDB.loadoutCheck[characterGUID][specID][challengeMapID] =
--   { configID = n|nil, configName = s|nil, lootSpecID = n }
-- Keyed by character GUID because talent config IDs belong to one character;
-- IsiLiveDB itself is account-wide.

local IsSecretValue = addonTable.Validators.IsSecretValue

-- 23 = Mythic party difficulty, the state of a keystone dungeon before the key
-- is inserted. 8 (Mythic Keystone) means the key is already running.
local MYTHIC_PARTY_DIFFICULTY_ID = 23
local EVALUATE_DELAY_SECONDS = 2
local MAX_CHARACTER_ENTRIES = 200

-- Enum.LoadConfigResult.Error; every other result means the load was accepted.
local LOAD_CONFIG_RESULT_ERROR = 0

local function Plain(value)
  if IsSecretValue(value) then
    return nil
  end
  return value
end

local function PositiveNumber(value)
  value = Plain(value)
  if type(value) ~= "number" or value <= 0 then
    return nil
  end
  return value
end

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return false
  end
  return pcall(fn, ...)
end

local function GetNamespaceFunction(namespace, member)
  local ns = rawget(_G, namespace)
  if type(ns) ~= "table" then
    return nil
  end
  local fn = rawget(ns, member)
  return type(fn) == "function" and fn or nil
end

local function GetSpecFunctions()
  local specApi = rawget(_G, "C_SpecializationInfo")
  local getSpecialization = type(specApi) == "table" and specApi.GetSpecialization or rawget(_G, "GetSpecialization")
  local getSpecializationInfo = type(specApi) == "table" and specApi.GetSpecializationInfo
    or rawget(_G, "GetSpecializationInfo")
  return getSpecialization, getSpecializationInfo
end

local function GetClassSpecCount()
  local okCount, count = SafeCall(rawget(_G, "GetNumSpecializations"))
  count = okCount and PositiveNumber(count) or nil
  if count then
    return count
  end
  local okClass, _, _, classID = SafeCall(rawget(_G, "UnitClass"), "player")
  classID = okClass and PositiveNumber(classID) or nil
  local okForClass, countForClass =
    SafeCall(GetNamespaceFunction("C_SpecializationInfo", "GetNumSpecializationsForClassID"), classID)
  return okForClass and PositiveNumber(countForClass) or nil
end

local function DefaultGetCurrentSpec()
  local getSpecialization, getSpecializationInfo = GetSpecFunctions()
  local okIndex, specIndex = SafeCall(getSpecialization)
  specIndex = okIndex and PositiveNumber(specIndex) or nil
  if not specIndex then
    return nil
  end
  local okInfo, specID, specName = SafeCall(getSpecializationInfo, specIndex)
  specID = okInfo and PositiveNumber(specID) or nil
  if not specID then
    return nil
  end
  return specID, type(Plain(specName)) == "string" and specName or nil
end

local function DefaultGetClassSpecs()
  local _, getSpecializationInfo = GetSpecFunctions()
  local specs = {}
  for index = 1, GetClassSpecCount() or 0 do
    local ok, specID, specName = SafeCall(getSpecializationInfo, index)
    specID = ok and PositiveNumber(specID) or nil
    if specID and type(Plain(specName)) == "string" then
      specs[#specs + 1] = { id = specID, name = specName }
    end
  end
  return specs
end

local function ReadConfigName(configID)
  local okInfo, info = SafeCall(GetNamespaceFunction("C_Traits", "GetConfigInfo"), configID)
  local name = okInfo and type(info) == "table" and Plain(info.name) or nil
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return name
end

local function DefaultGetSavedLoadouts(specID)
  local ok, configIDs = SafeCall(GetNamespaceFunction("C_ClassTalents", "GetConfigIDsBySpecID"), specID)
  local loadouts = {}
  if not ok or type(configIDs) ~= "table" then
    return loadouts
  end
  for _, rawID in ipairs(configIDs) do
    local configID = PositiveNumber(rawID)
    local name = configID and ReadConfigName(configID) or nil
    if name then
      loadouts[#loadouts + 1] = { id = configID, name = name }
    end
  end
  return loadouts
end

-- The loadout the talent frame shows as selected. The starter build has no
-- saved config of its own, so it reads as "no loadout" (nil).
local function DefaultGetSelectedLoadoutID(specID)
  local okStarter, starterActive = SafeCall(GetNamespaceFunction("C_ClassTalents", "GetStarterBuildActive"))
  if okStarter and Plain(starterActive) == true then
    return nil
  end
  local ok, configID = SafeCall(GetNamespaceFunction("C_ClassTalents", "GetLastSelectedSavedConfigID"), specID)
  return ok and PositiveNumber(configID) or nil
end

local function DefaultLoadLoadout(specID, configID)
  local ok, result = SafeCall(GetNamespaceFunction("C_ClassTalents", "LoadConfig"), configID, true)
  result = ok and Plain(result) or nil
  if type(result) ~= "number" or result == LOAD_CONFIG_RESULT_ERROR then
    return false
  end
  -- Same follow-up as Blizzard's talent frame: keep the dropdown in sync.
  SafeCall(GetNamespaceFunction("C_ClassTalents", "UpdateLastSelectedSavedConfigID"), specID, configID)
  return true
end

local function DefaultGetLootSpecID()
  local ok, lootSpecID = SafeCall(rawget(_G, "GetLootSpecialization"))
  lootSpecID = ok and Plain(lootSpecID) or nil
  if type(lootSpecID) ~= "number" or lootSpecID < 0 then
    return nil
  end
  return lootSpecID
end

local function DefaultSetLootSpecID(specID)
  local ok = SafeCall(rawget(_G, "SetLootSpecialization"), specID)
  return ok == true
end

local function DefaultIsInCombat()
  local ok, result = SafeCall(rawget(_G, "InCombatLockdown"))
  return ok and result == true
end

local function DefaultGetCharacterKey()
  local ok, guid = SafeCall(rawget(_G, "UnitGUID"), "player")
  guid = ok and Plain(guid) or nil
  if type(guid) ~= "string" or guid == "" then
    return nil
  end
  return guid
end

local function DefaultIsChallengeActive()
  local ok, active = SafeCall(GetNamespaceFunction("C_ChallengeMode", "IsChallengeModeActive"))
  return ok and Plain(active) == true
end

local function DefaultIsInGroup()
  local ok, inGroup = SafeCall(rawget(_G, "IsInGroup"))
  return ok and Plain(inGroup) == true
end

local function DefaultIsRaidContext()
  return addonTable.RuntimeMode.IsRaidContext() == true
end

-- Challenge-map ID and display name of the season dungeon the player stands
-- in, or nil. Only the instance ID links the location to a challenge map
-- (see Validators.ResolveChallengeMapInstanceID).
local function DefaultResolveSeasonDungeon()
  local validators = addonTable.Validators
  local ok, instanceInfo = validators.GetInstanceInfoSafe()
  if not ok or type(instanceInfo) ~= "table" or instanceInfo.difficultyID ~= MYTHIC_PARTY_DIFFICULTY_ID then
    return nil
  end
  local currentInstanceID = validators.GetPartyInstanceIDFromInfo(ok, instanceInfo)
  local seasonData = addonTable.SeasonData
  if not currentInstanceID or type(seasonData) ~= "table" or type(seasonData.GetOrderedMapIDs) ~= "function" then
    return nil
  end
  for _, mapID in ipairs(seasonData.GetOrderedMapIDs()) do
    if validators.ResolveChallengeMapInstanceID(mapID) == currentInstanceID then
      local name = type(instanceInfo.instanceName) == "string" and instanceInfo.instanceName or nil
      return mapID, name, currentInstanceID
    end
  end
  return nil
end

local function DefaultNow()
  local ok, now = SafeCall(rawget(_G, "time"))
  return ok and type(now) == "number" and now or nil
end

-- Localized dungeon name of a challenge map, as the client reports it.
local function DefaultGetDungeonName(mapID)
  local ok, name = SafeCall(GetNamespaceFunction("C_ChallengeMode", "GetMapUIInfo"), mapID)
  name = ok and Plain(name) or nil
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return name
end

local function DefaultAfter(delaySeconds, callback)
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    timer.After(delaySeconds, callback)
    return
  end
  callback()
end

local function DefaultGetDB()
  return rawget(_G, "IsiLiveDB") or {}
end

local function DefaultGetL()
  return {}
end

local function DefaultPrint(message)
  print("isiLive: " .. tostring(message or ""))
end

local DEFAULT_API = {
  getCurrentSpec = DefaultGetCurrentSpec,
  getClassSpecs = DefaultGetClassSpecs,
  getSavedLoadouts = DefaultGetSavedLoadouts,
  getSelectedLoadoutID = DefaultGetSelectedLoadoutID,
  loadLoadout = DefaultLoadLoadout,
  getLootSpecID = DefaultGetLootSpecID,
  setLootSpecID = DefaultSetLootSpecID,
  isInCombat = DefaultIsInCombat,
  getCharacterKey = DefaultGetCharacterKey,
  isChallengeActive = DefaultIsChallengeActive,
  isInGroup = DefaultIsInGroup,
  isRaidContext = DefaultIsRaidContext,
  resolveSeasonDungeon = DefaultResolveSeasonDungeon,
  after = DefaultAfter,
  now = DefaultNow,
  getDungeonName = DefaultGetDungeonName,
}

local function FindByID(list, id)
  for _, entry in ipairs(list) do
    if entry.id == id then
      return entry
    end
  end
  return nil
end

local function CountEntries(map)
  local count = 0
  for _ in pairs(map) do
    count = count + 1
  end
  return count
end

--- Pure comparison of the live state against a stored target.
--- @param live table { specID, specName, loadouts, selectedLoadoutID, specs, lootSpecID }
--- @param target table|nil stored { configID, configName, lootSpecID }
--- @return table model consumed by the card
function LoadoutCheck.BuildModel(live, target)
  local loadouts = live.loadouts or {}
  local selected = live.selectedLoadoutID and FindByID(loadouts, live.selectedLoadoutID) or nil
  local talents = {
    currentID = selected and selected.id or nil,
    currentName = selected and selected.name or nil,
    targetID = nil,
    targetName = nil,
    status = "unknown",
    options = {},
  }
  if type(target) == "table" and target.configID then
    talents.targetID = target.configID
    local targetEntry = FindByID(loadouts, target.configID)
    talents.targetName = targetEntry and targetEntry.name or target.configName
    talents.status = talents.currentID == target.configID and "ok" or "mismatch"
  end
  for _, loadout in ipairs(loadouts) do
    talents.options[#talents.options + 1] = {
      id = loadout.id,
      name = loadout.name,
      active = loadout.id == talents.currentID,
      target = loadout.id == talents.targetID,
    }
  end

  -- Loot spec 0 means "current specialization": compare the effective spec so
  -- 0 and the explicit current spec count as the same loot.
  local function Effective(lootSpecID)
    if lootSpecID == 0 then
      return live.specID
    end
    return lootSpecID
  end
  local loot = {
    currentID = live.lootSpecID,
    targetID = nil,
    status = "unknown",
    options = {},
  }
  if type(target) == "table" and type(target.lootSpecID) == "number" and live.lootSpecID ~= nil then
    loot.targetID = target.lootSpecID
    loot.status = Effective(live.lootSpecID) == Effective(target.lootSpecID) and "ok" or "mismatch"
  end
  loot.options[1] = {
    id = 0,
    specID = live.specID,
    name = live.specName,
    isCurrentSpec = true,
    active = live.lootSpecID == 0,
    target = loot.targetID == 0,
  }
  for _, spec in ipairs(live.specs or {}) do
    loot.options[#loot.options + 1] = {
      id = spec.id,
      specID = spec.id,
      name = spec.name,
      active = live.lootSpecID == spec.id,
      target = loot.targetID == spec.id,
    }
  end
  local currentLoot = live.lootSpecID == 0 and loot.options[1] or FindByID(loot.options, live.lootSpecID)
  loot.currentName = currentLoot and currentLoot.name or nil
  loot.currentIsSpecDefault = live.lootSpecID == 0
  local targetLoot = loot.targetID == 0 and loot.options[1] or FindByID(loot.options, loot.targetID)
  loot.targetName = targetLoot and targetLoot.name or nil
  loot.targetIsSpecDefault = loot.targetID == 0

  local hasTarget = talents.status ~= "unknown" or loot.status ~= "unknown"
  return {
    specID = live.specID,
    specName = live.specName,
    talents = talents,
    loot = loot,
    hasTarget = hasTarget,
    allOk = hasTarget and talents.status ~= "mismatch" and loot.status ~= "mismatch",
  }
end

function LoadoutCheck.CreateController(opts)
  opts = opts or {}
  local api = {}
  for key, fn in pairs(DEFAULT_API) do
    api[key] = type(opts[key]) == "function" and opts[key] or fn
  end
  local getDB = type(opts.getDB) == "function" and opts.getDB or DefaultGetDB
  local getL = type(opts.getL) == "function" and opts.getL or DefaultGetL
  local printMessage = type(opts.print) == "function" and opts.print or DefaultPrint
  local card = opts.card

  local controller = {}
  -- Instance the card was already handled for (shown, confirmed or closed);
  -- cleared on leaving it so the next entry checks again.
  local handledInstanceID = nil
  local active = nil -- { mapID, dungeonName, instanceID } while the card is up
  local evaluateToken = 0

  local function Text(key, fallback)
    local L = getL() or {}
    local value = L[key]
    if type(value) == "string" and value ~= "" then
      return value
    end
    return fallback
  end

  local function LootName(isSpecDefault, name)
    if isSpecDefault then
      return string.format(Text("LOADOUT_CHECK_LOOT_CURRENT_SPEC", "Current spec (%s)"), name or "?")
    end
    return name or "?"
  end

  local function IsEnabled()
    local db = getDB() or {}
    return db.loadoutCheckEnabled ~= false
  end

  local function GetCard()
    if card == nil and type(addonTable.LoadoutCheckCard) == "table" then
      card = addonTable.LoadoutCheckCard.Create()
    end
    return card
  end

  local function HideCard()
    active = nil
    if card and type(card.Hide) == "function" then
      card:Hide()
    end
  end

  local function GetStore(createMissing)
    local db = getDB()
    local characterKey = api.getCharacterKey()
    if type(db) ~= "table" or not characterKey then
      return nil
    end
    if type(db.loadoutCheck) ~= "table" then
      if not createMissing then
        return nil
      end
      db.loadoutCheck = {}
    end
    local byCharacter = db.loadoutCheck[characterKey]
    if type(byCharacter) ~= "table" then
      if not createMissing then
        return nil
      end
      if CountEntries(db.loadoutCheck) >= MAX_CHARACTER_ENTRIES then
        return nil
      end
      byCharacter = {}
      db.loadoutCheck[characterKey] = byCharacter
    end
    return byCharacter
  end

  local function ReadTarget(specID, mapID)
    local store = GetStore(false)
    local bySpec = store and store[specID] or nil
    local target = type(bySpec) == "table" and bySpec[mapID] or nil
    if type(target) ~= "table" then
      return nil
    end
    local configID = PositiveNumber(target.configID)
    local lootSpecID = type(target.lootSpecID) == "number" and target.lootSpecID >= 0 and target.lootSpecID or nil
    if not configID and not lootSpecID then
      return nil
    end
    local confirmedAt = target.confirmedAt
    return {
      configID = configID,
      configName = type(target.configName) == "string" and target.configName or nil,
      lootSpecID = lootSpecID,
      confirmedAt = type(confirmedAt) == "number" and confirmedAt or 0,
    }
  end

  -- Most recently confirmed target of the same spec in another dungeon; the
  -- invite summary offers it as a suggestion when this dungeon has none (user
  -- decision 2026-10-28). Entries without a timestamp count as oldest, ties
  -- go to the lower map ID so the choice is deterministic.
  local function FindLatestOtherTarget(specID, excludeMapID)
    local store = GetStore(false)
    local bySpec = store and store[specID] or nil
    if type(bySpec) ~= "table" then
      return nil
    end
    local bestMapID, bestTarget = nil, nil
    for mapID in pairs(bySpec) do
      local target = type(mapID) == "number" and mapID ~= excludeMapID and ReadTarget(specID, mapID) or nil
      if
        target
        and (
          not bestTarget
          or target.confirmedAt > bestTarget.confirmedAt
          or (target.confirmedAt == bestTarget.confirmedAt and mapID < bestMapID)
        )
      then
        bestMapID, bestTarget = mapID, target
      end
    end
    return bestTarget, bestMapID
  end

  local function ReadLive()
    local specID, specName = api.getCurrentSpec()
    if not specID then
      return nil
    end
    return {
      specID = specID,
      specName = specName,
      loadouts = api.getSavedLoadouts(specID) or {},
      selectedLoadoutID = api.getSelectedLoadoutID(specID),
      specs = api.getClassSpecs() or {},
      lootSpecID = api.getLootSpecID(),
    }
  end

  local function BuildCurrentModel()
    if not active then
      return nil
    end
    local live = ReadLive()
    if not live then
      return nil
    end
    local model = LoadoutCheck.BuildModel(live, ReadTarget(live.specID, active.mapID))
    model.mapID = active.mapID
    model.dungeonName = active.dungeonName
    model.inCombat = api.isInCombat()
    return model
  end

  local function Render()
    local model = BuildCurrentModel()
    if not model then
      HideCard()
      return
    end
    local target = GetCard()
    if target and type(target.Show) == "function" then
      target:Show(model, controller)
    end
  end

  local function IsQualifyingContext()
    return IsEnabled() and not api.isRaidContext() and api.isInGroup() and not api.isChallengeActive()
  end

  function controller.Evaluate()
    if not IsQualifyingContext() then
      handledInstanceID = nil
      HideCard()
      return false
    end
    local mapID, dungeonName, instanceID = api.resolveSeasonDungeon()
    if not mapID then
      handledInstanceID = nil
      HideCard()
      return false
    end
    if handledInstanceID == instanceID then
      return false
    end
    handledInstanceID = instanceID
    active = { mapID = mapID, dungeonName = dungeonName, instanceID = instanceID }
    -- Everything matches the confirmed target: one green chat line instead of
    -- the card. A missing target or any difference still shows the card.
    local model = BuildCurrentModel()
    if model and model.allOk then
      active = nil
      printMessage(
        "|cff33ff99"
          .. string.format(
            Text("LOADOUT_CHECK_CHAT_OK", "Talents (%s) and loot spec (%s) match for %s."),
            model.talents.currentName or "-",
            LootName(model.loot.currentIsSpecDefault, model.loot.currentName),
            dungeonName or "?"
          )
          .. "|r"
      )
      return false
    end
    Render()
    return active ~= nil
  end

  --- One-line summary for another card (accepted invite) about the dungeon
  -- with `mapID`; nil without a confirmed target for it and the current spec.
  function controller.GetSummary(mapID)
    if not IsEnabled() or type(mapID) ~= "number" then
      return nil
    end
    local live = ReadLive()
    if not live then
      return nil
    end
    local target = ReadTarget(live.specID, mapID)
    local sourceMapID = nil
    if not target then
      target, sourceMapID = FindLatestOtherTarget(live.specID, mapID)
    end
    local model = LoadoutCheck.BuildModel(live, target)
    if not target then
      -- Nothing confirmed for this spec at all: the current state, unjudged.
      return string.format(
        Text("LOADOUT_CHECK_SUMMARY_UNJUDGED", "%s · Loot: %s (not remembered for this dungeon yet)"),
        model.talents.currentName or Text("LOADOUT_CHECK_NO_LOADOUT", "no saved loadout"),
        LootName(model.loot.currentIsSpecDefault, model.loot.currentName)
      ),
        false
    end
    local parts = {}
    if model.talents.status == "ok" then
      parts[#parts + 1] = Text("LOADOUT_CHECK_SUMMARY_TALENTS_OK", "Talents OK")
    elseif model.talents.status == "mismatch" then
      parts[#parts + 1] = string.format(
        Text("LOADOUT_CHECK_SUMMARY_TALENTS_MISMATCH", "Talents: %s expected"),
        model.talents.targetName or "?"
      )
    end
    if model.loot.status == "ok" then
      parts[#parts + 1] = Text("LOADOUT_CHECK_SUMMARY_LOOT_OK", "Loot OK")
    elseif model.loot.status == "mismatch" then
      parts[#parts + 1] = string.format(
        Text("LOADOUT_CHECK_SUMMARY_LOOT_MISMATCH", "Loot: %s expected"),
        LootName(model.loot.targetIsSpecDefault, model.loot.targetName)
      )
    end
    if #parts == 0 then
      return nil
    end
    local text = table.concat(parts, " · ")
    if sourceMapID then
      text = text
        .. " "
        .. string.format(
          Text("LOADOUT_CHECK_SUMMARY_FROM", "(as %s)"),
          api.getDungeonName(sourceMapID) or Text("LOADOUT_CHECK_SUMMARY_OTHER_DUNGEON", "another dungeon")
        )
    end
    return text, model.allOk
  end

  function controller.ScheduleEvaluate()
    evaluateToken = evaluateToken + 1
    local token = evaluateToken
    api.after(EVALUATE_DELAY_SECONDS, function()
      if token == evaluateToken then
        controller.Evaluate()
      end
    end)
  end

  function controller.Refresh()
    if active then
      Render()
    end
  end

  function controller.GetText(key, fallback)
    return Text(key, fallback)
  end

  function controller.IsActive()
    return active ~= nil
  end

  function controller.GetModel()
    return BuildCurrentModel()
  end

  local function RefuseInCombat()
    if api.isInCombat() then
      printMessage(Text("LOADOUT_CHECK_COMBAT_BLOCKED", "Talents and loot spec cannot be changed in combat."))
      return true
    end
    return false
  end

  function controller.SelectLoadout(configID)
    local live = active and ReadLive() or nil
    if not live or not FindByID(live.loadouts, configID) or RefuseInCombat() then
      return false
    end
    if not api.loadLoadout(live.specID, configID) then
      printMessage(Text("LOADOUT_CHECK_LOAD_FAILED", "The talent loadout could not be loaded."))
      return false
    end
    Render()
    return true
  end

  function controller.SelectLootSpec(lootSpecID)
    local live = active and ReadLive() or nil
    if not live or type(lootSpecID) ~= "number" then
      return false
    end
    if lootSpecID ~= 0 and not FindByID(live.specs, lootSpecID) then
      return false
    end
    if RefuseInCombat() or not api.setLootSpecID(lootSpecID) then
      return false
    end
    Render()
    return true
  end

  -- Confirm: the current state becomes the target for this dungeon and spec.
  function controller.Confirm()
    local live = active and ReadLive() or nil
    if not live then
      HideCard()
      return false
    end
    local store = GetStore(true)
    if store then
      local selected = live.selectedLoadoutID and FindByID(live.loadouts, live.selectedLoadoutID) or nil
      store[live.specID] = type(store[live.specID]) == "table" and store[live.specID] or {}
      store[live.specID][active.mapID] = {
        configID = selected and selected.id or nil,
        configName = selected and selected.name or nil,
        lootSpecID = live.lootSpecID,
        confirmedAt = api.now(),
      }
    end
    HideCard()
    return store ~= nil
  end

  function controller.Dismiss()
    HideCard()
  end

  function controller.HandleEvent(event)
    if event == "PLAYER_ENTERING_WORLD" then
      controller.ScheduleEvaluate()
    elseif event == "CHALLENGE_MODE_START" or event == "GROUP_LEFT" then
      HideCard()
    elseif
      event == "PLAYER_SPECIALIZATION_CHANGED"
      or event == "TRAIT_CONFIG_UPDATED"
      or event == "TRAIT_CONFIG_LIST_UPDATED"
      or event == "ACTIVE_COMBAT_CONFIG_CHANGED"
      or event == "PLAYER_LOOT_SPEC_UPDATED"
      or event == "PLAYER_REGEN_DISABLED"
      or event == "PLAYER_REGEN_ENABLED"
    then
      controller.Refresh()
    end
  end

  return controller
end

local EVENTS = {
  "PLAYER_ENTERING_WORLD",
  "CHALLENGE_MODE_START",
  "GROUP_LEFT",
  "PLAYER_SPECIALIZATION_CHANGED",
  "TRAIT_CONFIG_UPDATED",
  "TRAIT_CONFIG_LIST_UPDATED",
  "ACTIVE_COMBAT_CONFIG_CHANGED",
  "PLAYER_LOOT_SPEC_UPDATED",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
}

local controllerInstance = nil
local eventFrame = nil

function LoadoutCheck.SetDependencies(deps)
  if type(deps) ~= "table" then
    return
  end
  controllerInstance = LoadoutCheck.CreateController(deps)
end

function LoadoutCheck.GetController()
  return controllerInstance
end

--- Summary line for the accepted-invite card, or nil.
function LoadoutCheck.GetSummary(mapID)
  if not controllerInstance then
    return nil
  end
  return controllerInstance.GetSummary(mapID)
end

function LoadoutCheck.HandleEvent(event, unit)
  if not controllerInstance then
    return
  end
  if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= nil and unit ~= "player" then
    return
  end
  controllerInstance.HandleEvent(event)
end

--- Creates the module's own event frame once. Called from the factory at load
-- (never from a protected-dispatch handler), so registration stays static.
function LoadoutCheck.Install()
  if eventFrame then
    return true
  end
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return false
  end
  local ok, frame = pcall(createFrame, "Frame")
  if not ok or type(frame) ~= "table" then
    return false
  end
  frame:SetScript("OnEvent", function(_, event, arg1)
    LoadoutCheck.HandleEvent(event, arg1)
  end)
  for i = 1, #EVENTS do
    frame:RegisterEvent(EVENTS[i])
  end
  eventFrame = frame
  return true
end
