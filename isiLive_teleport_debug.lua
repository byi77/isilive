local _, addonTable = ...

addonTable = addonTable or {}

local TeleportDebug = {}
addonTable.TeleportDebug = TeleportDebug

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: TeleportDebug requires " .. name)
  return value
end

function TeleportDebug.CreateController(opts)
  opts = opts or {}

  local printFn = opts.printFn or print
  local getL = opts.getL or function()
    return {}
  end
  local updateMPlusTeleportButton = RequireFunction(opts.updateMPlusTeleportButton, "updateMPlusTeleportButton")
  local resolveActiveTeleportSpellID =
    RequireFunction(opts.resolveActiveTeleportSpellID, "resolveActiveTeleportSpellID")
  local isSpellKnownSafe = RequireFunction(opts.isSpellKnownSafe, "isSpellKnownSafe")
  local getTeleportCooldownRemaining =
    RequireFunction(opts.getTeleportCooldownRemaining, "getTeleportCooldownRemaining")
  local formatCooldownSeconds = RequireFunction(opts.formatCooldownSeconds, "formatCooldownSeconds")
  local getLatestQueueState = RequireFunction(opts.getLatestQueueState, "getLatestQueueState")
  local resolveSeason3TeleportSpellIDByActivityID =
    RequireFunction(opts.resolveSeason3TeleportSpellIDByActivityID, "resolveSeason3TeleportSpellIDByActivityID")
  local getNormalizedActiveEntryInfo =
    RequireFunction(opts.getNormalizedActiveEntryInfo, "getNormalizedActiveEntryInfo")
  local resolveSeason3TeleportSpellID =
    RequireFunction(opts.resolveSeason3TeleportSpellID, "resolveSeason3TeleportSpellID")
  local getCenterNoticeTeleportButton =
    RequireFunction(opts.getCenterNoticeTeleportButton, "getCenterNoticeTeleportButton")
  local getMplusTeleportButtons = RequireFunction(opts.getMplusTeleportButtons, "getMplusTeleportButtons")
  local showCenterNotice = RequireFunction(opts.showCenterNotice, "showCenterNotice")
  local setLatestQueueState = RequireFunction(opts.setLatestQueueState, "setLatestQueueState")

  assert(type(printFn) == "function", "isiLive: TeleportDebug requires printFn")
  assert(type(getL) == "function", "isiLive: TeleportDebug requires getL")

  local controller = {}

  function controller.PrintTeleportDebug()
    updateMPlusTeleportButton()
    local latestQueueDungeonName, latestQueueActivityID, latestQueueTeleportSpellID = getLatestQueueState()
    local resolvedSpellID = resolveActiveTeleportSpellID()
    local resolvedKnown = resolvedSpellID and isSpellKnownSafe(resolvedSpellID) or false
    local resolvedCooldown = resolvedSpellID and getTeleportCooldownRemaining(resolvedSpellID) or 0

    local function DumpButtonState(label, button)
      if not button then
        printFn(label .. ": <missing>")
        return
      end
      local attrType = button:GetAttribute("type")
      local attrSpell = button:GetAttribute("spell")
      local spellID = button.spellID
      local known = spellID and isSpellKnownSafe(spellID) or false
      local cooldown = spellID and getTeleportCooldownRemaining(spellID) or 0
      printFn(
        string.format(
          "%s shown=%s spellID=%s attr(type=%s spell=%s) known=%s cd=%s active=%s map=%s",
          label,
          tostring(button:IsShown()),
          tostring(spellID),
          tostring(attrType),
          tostring(attrSpell),
          tostring(known),
          formatCooldownSeconds(cooldown),
          tostring(button.isActiveTarget == true),
          tostring(button.mapName)
        )
      )
    end

    printFn(
      string.format(
        "TP target dungeon=%s activityID=%s queueSpellID=%s resolvedSpellID=%s known=%s cd=%s inCombat=%s",
        tostring(latestQueueDungeonName),
        tostring(latestQueueActivityID),
        tostring(latestQueueTeleportSpellID),
        tostring(resolvedSpellID),
        tostring(resolvedKnown),
        formatCooldownSeconds(resolvedCooldown),
        tostring(InCombatLockdown and InCombatLockdown())
      )
    )

    local resolvedByActivity = resolveSeason3TeleportSpellIDByActivityID(latestQueueActivityID)
    printFn(string.format("TP resolve detail byActivity=%s", tostring(resolvedByActivity)))

    local entryInfo = getNormalizedActiveEntryInfo()
    if type(entryInfo) == "table" then
      local hostedID = tonumber(entryInfo.activityID)
      local hostedSpell = resolveSeason3TeleportSpellID(hostedID, nil)
      if not hostedSpell and type(entryInfo.activityIDs) == "table" then
        for _, id in pairs(entryInfo.activityIDs) do
          local numID = tonumber(id)
          if numID then
            local spell = resolveSeason3TeleportSpellID(numID, nil)
            if spell then
              hostedID = numID
              hostedSpell = spell
              break
            end
          end
        end
      end

      printFn(
        string.format(
          "TP host detail active=%s activityID=%s spell=%s",
          tostring(entryInfo.active),
          tostring(hostedID),
          tostring(hostedSpell)
        )
      )
    else
      printFn("TP host detail active=nil activityID=nil spell=nil")
    end

    DumpButtonState("TP center", getCenterNoticeTeleportButton())
    for i, button in ipairs(getMplusTeleportButtons() or {}) do
      DumpButtonState("TP grid[" .. i .. "]", button)
    end
  end

  function controller.ForceTeleportTestTarget()
    local L = getL()
    local dungeon = L.TESTALL_DUMMY_DUNGEON or "The Dawnbreaker"
    local spellID = resolveSeason3TeleportSpellID(nil, dungeon)
    setLatestQueueState(dungeon, nil, spellID)
    updateMPlusTeleportButton()
    local msg = string.format(L.JOINED_FROM_QUEUE_DUNGEON, L.TESTALL_DUMMY_GROUP or L.UNKNOWN_GROUP, dungeon)
    showCenterNotice(msg, 20, dungeon, nil)
    printFn("Teleport test target set: " .. tostring(dungeon))
  end

  return controller
end
