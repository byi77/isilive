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

local function ResolveHostedSpell(entryInfo, resolveSeason3TeleportSpellID)
  if type(entryInfo) ~= "table" then
    return nil, nil
  end

  local hostedID = tonumber(entryInfo.activityID)
  local hostedSpell = resolveSeason3TeleportSpellID(hostedID, nil)
  if hostedSpell or type(entryInfo.activityIDs) ~= "table" then
    return hostedID, hostedSpell
  end

  for _, id in pairs(entryInfo.activityIDs) do
    local numID = tonumber(id)
    if numID then
      local spell = resolveSeason3TeleportSpellID(numID, nil)
      if spell then
        return numID, spell
      end
    end
  end

  return hostedID, hostedSpell
end

local function PrintTeleportDebug(deps)
  deps.updateMPlusTeleportButton()
  local latestQueueDungeonName, latestQueueActivityID, latestQueueTeleportSpellID = deps.getLatestQueueState()
  local resolvedSpellID = deps.resolveActiveTeleportSpellID()
  local resolvedKnown = resolvedSpellID and deps.isSpellKnownSafe(resolvedSpellID) or false
  local resolvedCooldown = resolvedSpellID and deps.getTeleportCooldownRemaining(resolvedSpellID) or 0

  deps.printFn(
    string.format(
      "TP target dungeon=%s activityID=%s queueSpellID=%s resolvedSpellID=%s known=%s cd=%s inCombat=%s",
      tostring(latestQueueDungeonName),
      tostring(latestQueueActivityID),
      tostring(latestQueueTeleportSpellID),
      tostring(resolvedSpellID),
      tostring(resolvedKnown),
      deps.formatCooldownSeconds(resolvedCooldown),
      tostring(InCombatLockdown and InCombatLockdown())
    )
  )

  local resolvedByActivity = deps.resolveSeason3TeleportSpellIDByActivityID(latestQueueActivityID)
  deps.printFn(string.format("TP resolve detail byActivity=%s", tostring(resolvedByActivity)))

  local entryInfo = deps.getNormalizedActiveEntryInfo()
  local hostedID, hostedSpell = ResolveHostedSpell(entryInfo, deps.resolveSeason3TeleportSpellID)
  deps.printFn(
    string.format(
      "TP host detail active=%s activityID=%s spell=%s",
      tostring(type(entryInfo) == "table" and entryInfo.active or nil),
      tostring(hostedID),
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
  local spellID = deps.resolveSeason3TeleportSpellID(nil, dungeon)
  deps.setLatestQueueState(dungeon, nil, spellID)
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
    resolveSeason3TeleportSpellIDByActivityID = RequireFunction(
      opts.resolveSeason3TeleportSpellIDByActivityID,
      "resolveSeason3TeleportSpellIDByActivityID"
    ),
    getNormalizedActiveEntryInfo = RequireFunction(opts.getNormalizedActiveEntryInfo, "getNormalizedActiveEntryInfo"),
    resolveSeason3TeleportSpellID = RequireFunction(
      opts.resolveSeason3TeleportSpellID,
      "resolveSeason3TeleportSpellID"
    ),
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
