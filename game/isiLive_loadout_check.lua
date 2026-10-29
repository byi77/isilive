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

-- Enum.LoadConfigResult: Error (0) rejects the load; LoadInProgress (2) means
-- the talent commit only started and can still fail (CONFIG_COMMIT_FAILED);
-- NoChangesNecessary (1) and Ready (3) are done at once.
local LOAD_CONFIG_RESULT_ERROR = 0
local LOAD_CONFIG_RESULT_IN_PROGRESS = 2
-- A started commit that reports neither success nor failure is checked
-- against the active talents after this long.
local PENDING_LOAD_TIMEOUT_SECONDS = 10

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

-- Same follow-up as Blizzard's talent frame: keep the dropdown in sync. Only
-- called once the talents really changed.
local function DefaultMarkLoadoutSelected(specID, configID)
  SafeCall(GetNamespaceFunction("C_ClassTalents", "UpdateLastSelectedSavedConfigID"), specID, configID)
end

-- Returns true when the load is done, "pending" while the commit still runs
-- (the caller marks the loadout selected only after it succeeded), false on
-- a rejected load.
local function DefaultLoadLoadout(specID, configID)
  local ok, result = SafeCall(GetNamespaceFunction("C_ClassTalents", "LoadConfig"), configID, true)
  result = ok and Plain(result) or nil
  if type(result) ~= "number" or result == LOAD_CONFIG_RESULT_ERROR then
    return false
  end
  if result == LOAD_CONFIG_RESULT_IN_PROGRESS then
    return "pending"
  end
  DefaultMarkLoadoutSelected(specID, configID)
  return true
end

local function ReadImportString(configID)
  local ok, text = SafeCall(GetNamespaceFunction("C_Traits", "GenerateImportString"), configID)
  text = ok and Plain(text) or nil
  if type(text) ~= "string" or text == "" then
    return nil
  end
  return text
end

-- True when the active talents differ from the saved loadout `configID`
-- (changed in the talent tree without saving). Both sides are compared as
-- talent export strings. Fails closed: without both strings there is no claim.
local function DefaultIsLoadoutModified(_, configID)
  if not configID then
    return false
  end
  local okActive, activeID = SafeCall(GetNamespaceFunction("C_ClassTalents", "GetActiveConfigID"))
  activeID = okActive and PositiveNumber(activeID) or nil
  if not activeID or activeID == configID then
    return false
  end
  local activeText, savedText = ReadImportString(activeID), ReadImportString(configID)
  if not activeText or not savedText then
    return false
  end
  return activeText ~= savedText
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
  markLoadoutSelected = DefaultMarkLoadoutSelected,
  isLoadoutModified = DefaultIsLoadoutModified,
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

local SUMMARY_ICONS = {
  ok = "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:14:14:0:0|t",
  mismatch = "|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:14:14:0:0|t",
  unknown = "|TInterface\\RAIDFRAME\\ReadyCheck-Waiting:14:14:0:0|t",
}
-- Fallbacks match the loadout card's status colours (SUCCESS_GREEN_BAR,
-- TEXT_ALERT_DANGER); "unknown" keeps the row's own text colour.
local SUMMARY_COLOR_TOKENS = { ok = "SUCCESS_GREEN_BAR", mismatch = "TEXT_ALERT_DANGER" }
local SUMMARY_COLOR_FALLBACKS = { ok = "ff33d94d", mismatch = "ffff2429" }
-- One status per line, read like a checklist.
local SUMMARY_FIELD_PART_GAP = "\n"

local function SummaryColorHex(status)
  local colors = addonTable.UICommon and addonTable.UICommon.Colors
  local color = type(colors) == "table" and colors[SUMMARY_COLOR_TOKENS[status] or ""] or nil
  if type(color) == "table" and type(color[1]) == "number" then
    return string.format(
      "ff%02x%02x%02x",
      math.floor(color[1] * 255 + 0.5),
      math.floor(color[2] * 255 + 0.5),
      math.floor(color[3] * 255 + 0.5)
    )
  end
  return SUMMARY_COLOR_FALLBACKS[status]
end

local function CountEntries(map)
  local count = 0
  for _ in pairs(map) do
    count = count + 1
  end
  return count
end

--- Pure comparison of the live state against a stored target.
--- @param live table { specID, specName, loadouts, selectedLoadoutID, specs, lootSpecID,
---   loadoutModified (active talents differ from the selected loadout),
---   pendingLoadoutID (talent switch still committing) }
--- @param target table|nil stored { configID, configName, lootSpecID }
--- @return table model consumed by the card
function LoadoutCheck.BuildModel(live, target)
  local loadouts = live.loadouts or {}
  local selected = live.selectedLoadoutID and FindByID(loadouts, live.selectedLoadoutID) or nil
  local pending = live.pendingLoadoutID and FindByID(loadouts, live.pendingLoadoutID) or nil
  local talents = {
    currentID = selected and selected.id or nil,
    currentName = selected and selected.name or nil,
    -- The selected loadout, but its talents were changed without saving.
    modified = selected ~= nil and live.loadoutModified == true,
    pendingID = pending and pending.id or nil,
    pendingName = pending and pending.name or nil,
    targetID = nil,
    targetName = nil,
    status = "unknown",
    options = {},
  }
  local talentsJudged = false
  if type(target) == "table" and target.configID then
    talentsJudged = true
    talents.targetID = target.configID
    local targetEntry = FindByID(loadouts, target.configID)
    talents.targetName = targetEntry and targetEntry.name or target.configName
    -- A changed, unsaved tree is not the remembered loadout any more.
    local matches = talents.currentID == target.configID and not talents.modified
    talents.status = matches and "ok" or "mismatch"
  end
  -- Until the commit is through, nothing is judged: it can still fail.
  if talents.pendingID then
    talents.status = "pending"
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

  local hasTarget = talentsJudged or loot.status ~= "unknown"
  local talentsOk = talents.status == "ok" or (talents.status == "unknown" and not talents.modified)
  return {
    specID = live.specID,
    specName = live.specName,
    talents = talents,
    loot = loot,
    hasTarget = hasTarget,
    allOk = hasTarget and talentsOk and loot.status ~= "mismatch",
  }
end

local function SummaryLootName(text, isSpecDefault, name)
  if isSpecDefault then
    return string.format(text("LOADOUT_CHECK_LOOT_CURRENT_SPEC", "Current spec (%s)"), name or "?")
  end
  return name or "?"
end

--- Status parts of the accepted-invite summary for a model.
--- @param model table from BuildModel
--- @param text function(key, fallback) localized text
--- @param hasTarget boolean false: nothing confirmed for the spec, the current state stays unjudged
--- @return table|nil { parts = { { status = "ok"|"mismatch"|"unknown", text } }, allOk }
function LoadoutCheck.BuildSummaryParts(model, text, hasTarget)
  if type(model) ~= "table" then
    return nil
  end
  if not hasTarget then
    local currentName = model.talents.currentName or text("LOADOUT_CHECK_NO_LOADOUT", "no saved loadout")
    if model.talents.modified then
      currentName = string.format(text("LOADOUT_CHECK_MODIFIED_NAME", "%s (changed, not saved)"), currentName)
    end
    local unjudged = string.format(
      text("LOADOUT_CHECK_SUMMARY_UNJUDGED", "%s · Loot: %s (not remembered for this dungeon yet)"),
      currentName,
      SummaryLootName(text, model.loot.currentIsSpecDefault, model.loot.currentName)
    )
    return { parts = { { status = "unknown", text = unjudged } }, allOk = false }
  end
  local parts = {}
  if model.talents.status == "pending" then
    parts[#parts + 1] = {
      status = "unknown",
      text = string.format(
        text("LOADOUT_CHECK_SUMMARY_TALENTS_PENDING", "Talents: switching to %s"),
        model.talents.pendingName or "?"
      ),
    }
  elseif model.talents.status == "ok" then
    parts[#parts + 1] = { status = "ok", text = text("LOADOUT_CHECK_SUMMARY_TALENTS_OK", "Talents OK") }
  elseif model.talents.modified and model.talents.currentID == model.talents.targetID then
    parts[#parts + 1] = {
      status = "mismatch",
      text = string.format(
        text("LOADOUT_CHECK_SUMMARY_TALENTS_MODIFIED", "Talents: %s changed, not saved"),
        model.talents.currentName or "?"
      ),
    }
  elseif model.talents.status == "mismatch" then
    parts[#parts + 1] = {
      status = "mismatch",
      text = string.format(
        text("LOADOUT_CHECK_SUMMARY_TALENTS_MISMATCH", "Talents: %s expected"),
        model.talents.targetName or "?"
      ),
    }
  end
  if model.loot.status == "ok" then
    parts[#parts + 1] = { status = "ok", text = text("LOADOUT_CHECK_SUMMARY_LOOT_OK", "Loot OK") }
  elseif model.loot.status == "mismatch" then
    parts[#parts + 1] = {
      status = "mismatch",
      text = string.format(
        text("LOADOUT_CHECK_SUMMARY_LOOT_MISMATCH", "Loot: %s expected"),
        SummaryLootName(text, model.loot.targetIsSpecDefault, model.loot.targetName)
      ),
    }
  end
  if #parts == 0 then
    return nil
  end
  return { parts = parts, allOk = model.allOk }
end

--- Plain one-line text of a summary ("Talents OK · Loot: Fire expected").
function LoadoutCheck.FormatSummaryText(summary)
  local texts = {}
  for i, part in ipairs(summary.parts) do
    texts[i] = part.text
  end
  local result = table.concat(texts, " · ")
  if summary.suffix then
    result = result .. " " .. summary.suffix
  end
  return result
end

--- Notice field of a summary: one line per part, led by its ready-check
--- icon in its status colour, so the row reads at a glance; any mismatch puts
--- the row on the warning strip (steady, no blink).
--- @return table { value = string, warning = boolean }
function LoadoutCheck.FormatSummaryField(summary)
  local texts = {}
  local hasMismatch = false
  for i, part in ipairs(summary.parts) do
    local piece = SUMMARY_ICONS[part.status] .. " " .. part.text
    local colorHex = SummaryColorHex(part.status)
    if colorHex then
      piece = "|c" .. colorHex .. piece .. "|r"
    end
    texts[i] = piece
    hasMismatch = hasMismatch or part.status == "mismatch"
  end
  local value = table.concat(texts, SUMMARY_FIELD_PART_GAP)
  if summary.suffix then
    value = value .. " " .. summary.suffix
  end
  return { value = value, warning = hasMismatch }
end

-- The per-character target table in `db`; with `createMissing` it is
-- created (up to MAX_CHARACTER_ENTRIES characters).
local function GetCharacterStore(db, characterKey, createMissing)
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
  -- Talent switch whose commit still runs: { specID, configID, name, token }.
  -- The loadout counts as selected only after the commit succeeded.
  local pendingLoad = nil

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
    return GetCharacterStore(getDB(), api.getCharacterKey(), createMissing)
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
    local selectedLoadoutID = api.getSelectedLoadoutID(specID)
    local pendingLoadoutID = pendingLoad and pendingLoad.specID == specID and pendingLoad.configID or nil
    return {
      specID = specID,
      specName = specName,
      loadouts = api.getSavedLoadouts(specID) or {},
      selectedLoadoutID = selectedLoadoutID,
      -- While a switch commits, the active talents are in flux.
      loadoutModified = not pendingLoadoutID and api.isLoadoutModified(specID, selectedLoadoutID) == true,
      pendingLoadoutID = pendingLoadoutID,
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

  -- Summary of the dungeon with `mapID` as status parts (see
  -- LoadoutCheck.BuildSummaryParts); nil without a current spec.
  local function BuildSummary(mapID)
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
    local summary = LoadoutCheck.BuildSummaryParts(LoadoutCheck.BuildModel(live, target), Text, target ~= nil)
    if summary and sourceMapID then
      summary.suffix = string.format(
        Text("LOADOUT_CHECK_SUMMARY_FROM", "(as %s)"),
        api.getDungeonName(sourceMapID) or Text("LOADOUT_CHECK_SUMMARY_OTHER_DUNGEON", "another dungeon")
      )
    end
    return summary
  end

  --- One-line summary for another card (accepted invite) about the dungeon
  -- with `mapID`; nil without a confirmed target for it and the current spec.
  function controller.GetSummary(mapID)
    local summary = BuildSummary(mapID)
    if not summary then
      return nil
    end
    return LoadoutCheck.FormatSummaryText(summary), summary.allOk
  end

  --- The same summary as an accepted-invite field: status icon and colour per
  -- part, warning strip on a mismatch.
  function controller.GetSummaryField(mapID)
    local summary = BuildSummary(mapID)
    return summary and LoadoutCheck.FormatSummaryField(summary) or nil
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

  -- Ends a running talent switch: on success the loadout becomes the selected
  -- one, on failure the card shows the unchanged talents again.
  function controller.FinishPendingLoad(succeeded)
    local finished = pendingLoad
    if not finished then
      return false
    end
    pendingLoad = nil
    if succeeded then
      api.markLoadoutSelected(finished.specID, finished.configID)
    else
      printMessage(
        string.format(
          Text("LOADOUT_CHECK_COMMIT_FAILED", "The talent switch to %s was interrupted."),
          finished.name or "?"
        )
      )
    end
    controller.Refresh()
    return true
  end

  function controller.SelectLoadout(configID)
    local live = active and ReadLive() or nil
    local loadout = live and FindByID(live.loadouts, configID) or nil
    if not live or not loadout or pendingLoad or RefuseInCombat() then
      return false
    end
    local result = api.loadLoadout(live.specID, configID)
    if not result then
      printMessage(Text("LOADOUT_CHECK_LOAD_FAILED", "The talent loadout could not be loaded."))
      return false
    end
    if result == "pending" then
      local token = {}
      pendingLoad = { specID = live.specID, configID = configID, name = loadout.name, token = token }
      -- No result event at all: the active talents decide whether it worked.
      api.after(PENDING_LOAD_TIMEOUT_SECONDS, function()
        if pendingLoad and pendingLoad.token == token then
          controller.FinishPendingLoad(api.isLoadoutModified(live.specID, configID) ~= true)
        end
      end)
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
    -- Mid-switch the selected loadout is still the old one; wait for the commit.
    if live.pendingLoadoutID then
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

  --- Simulation tablet: opens the real card for `mapID` without the group and
  -- dungeon gate (no group exists in the preview). Everything else is live:
  -- the player's loadouts and loot spec, real switches, real confirmation for
  -- that dungeon. Also shown when all matches, so the card can be checked.
  function controller.ShowPreview(mapID, dungeonName)
    if type(mapID) ~= "number" or not IsEnabled() then
      return false
    end
    active = { mapID = mapID, dungeonName = dungeonName, instanceID = nil, preview = true }
    Render()
    return active ~= nil
  end

  function controller.HidePreview()
    if active and active.preview then
      HideCard()
    end
  end

  function controller.HandleEvent(event)
    if event == "PLAYER_ENTERING_WORLD" then
      controller.ScheduleEvaluate()
    elseif event == "CHALLENGE_MODE_START" or event == "GROUP_LEFT" then
      HideCard()
    elseif event == "CONFIG_COMMIT_FAILED" and pendingLoad then
      controller.FinishPendingLoad(false)
    elseif event == "TRAIT_CONFIG_UPDATED" and pendingLoad then
      -- The commit went through: the active talents now carry the new loadout.
      controller.FinishPendingLoad(true)
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
  "CONFIG_COMMIT_FAILED",
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

--- The summary as an accepted-invite field ({ value, warning }), or nil.
function LoadoutCheck.GetSummaryField(mapID)
  if not controllerInstance then
    return nil
  end
  return controllerInstance.GetSummaryField(mapID)
end

--- Opens the real card for the simulation tablet (see controller.ShowPreview).
function LoadoutCheck.ShowPreview(mapID, dungeonName)
  if not controllerInstance then
    return false
  end
  return controllerInstance.ShowPreview(mapID, dungeonName)
end

function LoadoutCheck.HidePreview()
  if controllerInstance then
    controllerInstance.HidePreview()
  end
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
