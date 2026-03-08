local _, addonTable = ...

addonTable = addonTable or {}

local TeleportDebug = {}
addonTable.TeleportDebug = TeleportDebug

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: TeleportDebug requires " .. name)
  return value
end

local function DumpButtonState(deps, label, button)
  if not button then
    deps.printFn(label .. ": <missing>")
    return
  end
  local attrType = button:GetAttribute("type")
  local attrSpell = button:GetAttribute("spell")
  local spellID = button.spellID
  local known = spellID and deps.isSpellKnownSafe(spellID) or false
  local cooldown = spellID and deps.getTeleportCooldownRemaining(spellID) or 0
  deps.printFn(
    string.format(
      "%s shown=%s spellID=%s attr(type=%s spell=%s) known=%s cd=%s active=%s map=%s",
      label,
      tostring(button:IsShown()),
      tostring(spellID),
      tostring(attrType),
      tostring(attrSpell),
      tostring(known),
      deps.formatCooldownSeconds(cooldown),
      tostring(button.isActiveTarget == true),
      tostring(button.mapName)
    )
  )
end

local function ResolveHostedSpell(entryInfo, resolveMapIDByActivityID, resolveTeleportSpellIDByMapID)
  if type(entryInfo) ~= "table" then
    return nil, nil, nil
  end

  local hostedID = tonumber(entryInfo.activityID)
  local hostedMapID = resolveMapIDByActivityID(hostedID)
  local hostedSpell = hostedMapID and resolveTeleportSpellIDByMapID(hostedMapID) or nil
  if hostedSpell or type(entryInfo.activityIDs) ~= "table" then
    return hostedID, hostedMapID, hostedSpell
  end

  for _, id in pairs(entryInfo.activityIDs) do
    local numID = tonumber(id)
    if numID then
      local mapID = resolveMapIDByActivityID(numID)
      local spell = mapID and resolveTeleportSpellIDByMapID(mapID) or nil
      if spell then
        return numID, mapID, spell
      end
    end
  end

  return hostedID, hostedMapID, hostedSpell
end

local function PrintTeleportDebug(deps)
  deps.updateMPlusTeleportButton()
  local latestQueueDungeonName, latestQueueActivityID, latestQueueTeleportSpellID, latestQueueMapID =
    deps.getLatestQueueState()
  local resolvedSpellID = deps.resolveActiveTeleportSpellID()
  local resolvedKnown = resolvedSpellID and deps.isSpellKnownSafe(resolvedSpellID) or false
  local resolvedCooldown = resolvedSpellID and deps.getTeleportCooldownRemaining(resolvedSpellID) or 0

  deps.printFn(
    string.format(
      "TP target dungeon=%s activityID=%s mapID=%s queueSpellID=%s resolvedSpellID=%s known=%s cd=%s inCombat=%s",
      tostring(latestQueueDungeonName),
      tostring(latestQueueActivityID),
      tostring(latestQueueMapID),
      tostring(latestQueueTeleportSpellID),
      tostring(resolvedSpellID),
      tostring(resolvedKnown),
      deps.formatCooldownSeconds(resolvedCooldown),
      tostring(InCombatLockdown and InCombatLockdown())
    )
  )

  local resolvedMap = deps.resolveMapIDByActivityID(latestQueueActivityID)
  local resolvedByActivity = deps.resolveTeleportSpellIDByActivityID(latestQueueActivityID)
  local resolvedByMap = resolvedMap and deps.resolveTeleportSpellIDByMapID(resolvedMap) or nil
  deps.printFn(
    string.format(
      "TP resolve detail byActivity(map=%s spell=%s) byMapSpell=%s",
      tostring(resolvedMap),
      tostring(resolvedByActivity),
      tostring(resolvedByMap)
    )
  )

  local entryInfo = deps.getNormalizedActiveEntryInfo()
  local hostedID, hostedMapID, hostedSpell =
    ResolveHostedSpell(entryInfo, deps.resolveMapIDByActivityID, deps.resolveTeleportSpellIDByMapID)
  deps.printFn(
    string.format(
      "TP host detail active=%s activityID=%s mapID=%s spell=%s",
      tostring(type(entryInfo) == "table" and entryInfo.active or nil),
      tostring(hostedID),
      tostring(hostedMapID),
      tostring(hostedSpell)
    )
  )

  DumpButtonState(deps, "TP center", deps.getCenterNoticeTeleportButton())
  for i, button in ipairs(deps.getMplusTeleportButtons() or {}) do
    DumpButtonState(deps, "TP grid[" .. i .. "]", button)
  end
end

local function ForceTeleportTestTarget(deps)
  local L = deps.getL()
  local dungeon = L.TESTALL_DUMMY_DUNGEON or "The Dawnbreaker"
  local targetMapID = 2662
  local spellID = deps.resolveTeleportSpellIDByMapID(targetMapID)
  deps.setLatestQueueState(dungeon, nil, spellID, targetMapID)
  deps.updateMPlusTeleportButton()
  local msg = string.format(L.JOINED_FROM_QUEUE_DUNGEON, L.TESTALL_DUMMY_GROUP or L.UNKNOWN_GROUP, dungeon)
  deps.showCenterNotice(msg, 20, dungeon, nil)
  deps.printFn("Teleport test target set: " .. tostring(dungeon))
end

function TeleportDebug.CreateController(opts)
  opts = opts or {}

  local deps = {
    printFn = opts.printFn or print,
    getL = opts.getL or function()
      return {}
    end,
    updateMPlusTeleportButton = RequireFunction(opts.updateMPlusTeleportButton, "updateMPlusTeleportButton"),
    resolveActiveTeleportSpellID = RequireFunction(opts.resolveActiveTeleportSpellID, "resolveActiveTeleportSpellID"),
    isSpellKnownSafe = RequireFunction(opts.isSpellKnownSafe, "isSpellKnownSafe"),
    getTeleportCooldownRemaining = RequireFunction(opts.getTeleportCooldownRemaining, "getTeleportCooldownRemaining"),
    formatCooldownSeconds = RequireFunction(opts.formatCooldownSeconds, "formatCooldownSeconds"),
    getLatestQueueState = RequireFunction(opts.getLatestQueueState, "getLatestQueueState"),
    resolveMapIDByActivityID = RequireFunction(opts.resolveMapIDByActivityID, "resolveMapIDByActivityID"),
    resolveTeleportSpellIDByActivityID = RequireFunction(
      opts.resolveTeleportSpellIDByActivityID,
      "resolveTeleportSpellIDByActivityID"
    ),
    resolveTeleportSpellIDByMapID = RequireFunction(
      opts.resolveTeleportSpellIDByMapID,
      "resolveTeleportSpellIDByMapID"
    ),
    getNormalizedActiveEntryInfo = RequireFunction(opts.getNormalizedActiveEntryInfo, "getNormalizedActiveEntryInfo"),
    getCenterNoticeTeleportButton = RequireFunction(
      opts.getCenterNoticeTeleportButton,
      "getCenterNoticeTeleportButton"
    ),
    getMplusTeleportButtons = RequireFunction(opts.getMplusTeleportButtons, "getMplusTeleportButtons"),
    showCenterNotice = RequireFunction(opts.showCenterNotice, "showCenterNotice"),
    setLatestQueueState = RequireFunction(opts.setLatestQueueState, "setLatestQueueState"),
  }

  assert(type(deps.printFn) == "function", "isiLive: TeleportDebug requires printFn")
  assert(type(deps.getL) == "function", "isiLive: TeleportDebug requires getL")

  local controller = {}

  function controller.PrintTeleportDebug()
    PrintTeleportDebug(deps)
  end

  function controller.ForceTeleportTestTarget()
    ForceTeleportTestTarget(deps)
  end

  return controller
end
