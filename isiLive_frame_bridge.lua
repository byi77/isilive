local _, addonTable = ...

addonTable = addonTable or {}

local FrameBridge = {}
addonTable.FrameBridge = FrameBridge

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: FrameBridge requires " .. name)
  return value
end

function FrameBridge.CreateContext(opts)
  opts = opts or {}

  local createCenterNotice = RequireFunction(opts.createCenterNotice, "createCenterNotice")
  local createInviteHint = RequireFunction(opts.createInviteHint, "createInviteHint")
  local createMainFrame = RequireFunction(opts.createMainFrame, "createMainFrame")
  local isInGroup = RequireFunction(opts.isInGroup, "isInGroup")
  local onShownInGroup = RequireFunction(opts.onShownInGroup, "onShownInGroup")
  local onShownNoGroup = RequireFunction(opts.onShownNoGroup, "onShownNoGroup")
  local isInCombat = RequireFunction(opts.isInCombat, "isInCombat")
  local resolveTeleportSpellID = RequireFunction(opts.resolveTeleportSpellID, "resolveTeleportSpellID")
  local applySecureSpellToButton = RequireFunction(opts.applySecureSpellToButton, "applySecureSpellToButton")
  local isSpellKnown = RequireFunction(opts.isSpellKnown, "isSpellKnown")
  local getTeleportCooldownRemaining = RequireFunction(opts.getTeleportCooldownRemaining, "getTeleportCooldownRemaining")
  local formatCooldownSeconds = RequireFunction(opts.formatCooldownSeconds, "formatCooldownSeconds")
  local getL = RequireFunction(opts.getL, "getL")

  local centerNotice = createCenterNotice({
    parent = opts.parent,
    minHeight = tonumber(opts.centerNoticeMinHeight) or 70,
    maxHeight = tonumber(opts.centerNoticeMaxHeight) or 220,
    paddingX = tonumber(opts.centerNoticePaddingX) or 20,
    paddingY = tonumber(opts.centerNoticePaddingY) or 12,
    buttonHeight = tonumber(opts.centerNoticeButtonHeight) or 36,
    buttonGap = tonumber(opts.centerNoticeButtonGap) or 8,
    isInCombat = isInCombat,
    resolveTeleportSpellID = resolveTeleportSpellID,
    applySecureSpellToButton = applySecureSpellToButton,
    isSpellKnown = isSpellKnown,
    getTeleportCooldownRemaining = getTeleportCooldownRemaining,
    formatCooldownSeconds = formatCooldownSeconds,
    getL = getL,
  })

  local inviteHint = createInviteHint({
    parent = opts.parent,
    mainFrameGlobalName = tostring(opts.mainFrameGlobalName or "isiLiveMainFrame"),
  })

  local mainUI = createMainFrame({
    minHeight = tonumber(opts.mainFrameMinHeight) or 200,
    parent = opts.parent,
    isInCombat = isInCombat,
    onShownInGroup = onShownInGroup,
    onShownNoGroup = onShownNoGroup,
  })

  local context = {
    centerNotice = centerNotice,
    centerNoticeFrame = centerNotice.frame,
    centerNoticeTeleportButton = centerNotice.teleportButton,
    inviteHint = inviteHint,
    mainUI = mainUI,
    mainFrame = mainUI.frame,
  }

  function context.SetCenterNoticeVisible(visible)
    centerNotice.SetVisible(visible)
  end

  function context.UpdateCenterTeleportButtonVisual(spellID, isEnabled, inCombatBlocked)
    centerNotice.UpdateTeleportButtonVisual(spellID, isEnabled, inCombatBlocked)
  end

  function context.ShowCenterNotice(message, durationSeconds, dungeonName, activityID, showOptions)
    centerNotice.Show(message, durationSeconds, dungeonName, activityID, showOptions)
  end

  function context.ShowInviteHint(message, durationSeconds)
    inviteHint.Show(message, durationSeconds)
  end

  function context.SetMainFrameVisible(visible)
    mainUI.SetVisible(visible)
  end

  function context.SetMainFrameHeightSafe(height)
    mainUI.SetHeightSafe(height)
  end

  function context.ToggleMainFrameVisibility()
    mainUI.ToggleVisibility(isInGroup())
  end

  return context
end
