local _, addonTable = ...

addonTable = addonTable or {}

local FrameBridge = {}
addonTable.FrameBridge = FrameBridge

local function RequireFunction(value, name)
  return addonTable.Validators.RequireFunction(value, name, "FrameBridge")
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
  local isRaidGroup = type(opts.isRaidGroup) == "function" and opts.isRaidGroup or function()
    return false
  end
  local resolveTeleportSpellID = RequireFunction(opts.resolveTeleportSpellID, "resolveTeleportSpellID")
  local applySecureSpellToButton = RequireFunction(opts.applySecureSpellToButton, "applySecureSpellToButton")
  local isSpellKnown = RequireFunction(opts.isSpellKnown, "isSpellKnown")
  local getTeleportCooldownRemaining =
    RequireFunction(opts.getTeleportCooldownRemaining, "getTeleportCooldownRemaining")
  local formatCooldownSeconds = RequireFunction(opts.formatCooldownSeconds, "formatCooldownSeconds")
  local getL = RequireFunction(opts.getL, "getL")
  local resolveMapIDBySpellID = type(opts.resolveMapIDBySpellID) == "function" and opts.resolveMapIDBySpellID
    or function(_spellID)
      return nil
    end
  local resolveMapIDByActivityID = type(opts.resolveMapIDByActivityID) == "function" and opts.resolveMapIDByActivityID
    or function(_activityID)
      return nil
    end
  local getDungeonName = type(opts.getDungeonName) == "function" and opts.getDungeonName
    or function(_mapID, _localeTag)
      return nil
    end

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
    resolveMapIDBySpellID = resolveMapIDBySpellID,
    resolveMapIDByActivityID = resolveMapIDByActivityID,
    applySecureSpellToButton = applySecureSpellToButton,
    isSpellKnown = isSpellKnown,
    getTeleportCooldownRemaining = getTeleportCooldownRemaining,
    formatCooldownSeconds = formatCooldownSeconds,
    getDungeonName = getDungeonName,
    getL = getL,
  })

  local inviteHint = createInviteHint({
    parent = opts.parent,
    mainFrameGlobalName = tostring(opts.mainFrameGlobalName or "isiLiveMainFrame"),
  })

  local mainUI = createMainFrame({
    minHeight = tonumber(opts.mainFrameMinHeight) or 212,
    parent = opts.parent,
    isInCombat = isInCombat,
    isRaidGroup = isRaidGroup,
    isDragLocked = type(opts.isMainFrameDragLocked) == "function" and opts.isMainFrameDragLocked or function()
      return true
    end,
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

  function context.ShowCenterNotice(message, durationSeconds, _dungeonName, _activityID, showOptions)
    centerNotice.Show(message, durationSeconds, nil, nil, showOptions)
  end

  function context.ShowInviteHint(message, durationSeconds)
    inviteHint.Show(message, durationSeconds)
  end

  function context.SetMainFrameVisible(visible, showOpts)
    showOpts = type(showOpts) == "table" and showOpts or {}
    if visible and type(isRaidGroup) == "function" and isRaidGroup() then
      return false
    end
    local didShow = mainUI.SetVisible(visible)
    if visible and didShow == true then
      if showOpts.skipShowCallbacks == true then
        return didShow
      end
      if isInGroup() then
        onShownInGroup()
      else
        onShownNoGroup()
      end
    end
    return didShow
  end

  function context.SetMainFrameHeightSafe(height)
    mainUI.SetHeightSafe(height)
  end

  function context.SetMainFrameWidthSafe(width)
    mainUI.SetWidthSafe(width)
  end

  function context.IsMainFrameVisible()
    return mainUI.frame:IsShown() == true
  end

  function context.ToggleMainFrameVisibility()
    if type(isRaidGroup) == "function" and isRaidGroup() and not mainUI.frame:IsShown() then
      return
    end
    mainUI.ToggleVisibility(isInGroup())
  end

  return context
end
