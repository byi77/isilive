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
  local createMainFrame = RequireFunction(opts.createMainFrame, "createMainFrame")
  local isInGroup = RequireFunction(opts.isInGroup, "isInGroup")
  local onShownInGroup = RequireFunction(opts.onShownInGroup, "onShownInGroup")
  local onShownNoGroup = RequireFunction(opts.onShownNoGroup, "onShownNoGroup")
  local isInCombat = RequireFunction(opts.isInCombat, "isInCombat")
  local onOpenSettings = type(opts.onOpenSettings) == "function" and opts.onOpenSettings or function() end
  local isRaidGroup = type(opts.isRaidGroup) == "function" and opts.isRaidGroup or function()
    return false
  end
  local resolveTeleportSpellID = RequireFunction(opts.resolveTeleportSpellID, "resolveTeleportSpellID")
  local resolveTeleportSpellIDByMapID = type(opts.resolveTeleportSpellIDByMapID) == "function"
      and opts.resolveTeleportSpellIDByMapID
    or function(_mapID)
      return nil
    end
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
    onOpenSettings = onOpenSettings,
  })

  local mainFrame = mainUI.frame
  local mainFrameStrata = type(mainFrame) == "table"
      and type(mainFrame.GetFrameStrata) == "function"
      and mainFrame:GetFrameStrata()
    or nil
  local mainFrameLevel = type(mainFrame) == "table"
      and type(mainFrame.GetFrameLevel) == "function"
      and mainFrame:GetFrameLevel()
    or nil

  local centerNotice = createCenterNotice({
    parent = opts.parent,
    minHeight = tonumber(opts.centerNoticeMinHeight) or 70,
    maxHeight = tonumber(opts.centerNoticeMaxHeight) or 220,
    paddingX = tonumber(opts.centerNoticePaddingX) or 20,
    paddingY = tonumber(opts.centerNoticePaddingY) or 12,
    buttonHeight = tonumber(opts.centerNoticeButtonHeight) or 36,
    buttonGap = tonumber(opts.centerNoticeButtonGap) or 8,
    frameStrata = mainFrameStrata,
    frameLevel = mainFrameLevel,
    isInCombat = isInCombat,
    resolveTeleportSpellID = resolveTeleportSpellID,
    resolveTeleportSpellIDByMapID = resolveTeleportSpellIDByMapID,
    resolveMapIDBySpellID = resolveMapIDBySpellID,
    resolveMapIDByActivityID = resolveMapIDByActivityID,
    applySecureSpellToButton = applySecureSpellToButton,
    isSpellKnown = isSpellKnown,
    getTeleportCooldownRemaining = getTeleportCooldownRemaining,
    formatCooldownSeconds = formatCooldownSeconds,
    getDungeonName = getDungeonName,
    getL = getL,
  })

  local context = {
    centerNotice = centerNotice,
    centerNoticeFrame = centerNotice.frame,
    centerNoticeTeleportButton = centerNotice.teleportButton,
    mainUI = mainUI,
    mainFrame = mainFrame,
  }

  function context.SetCenterNoticeVisible(visible)
    centerNotice.SetVisible(visible)
  end

  function context.UpdateCenterTeleportButtonVisual(spellID, isEnabled, inCombatBlocked)
    centerNotice.UpdateTeleportButtonVisual(spellID, isEnabled, inCombatBlocked)
  end

  -- Deliberately strips dungeonName / activityID: the runtime path is for
  -- generic notices that must not auto-configure a teleport button. The
  -- factory wrapper in factory/isiLive_factory_frame_bridge.lua reaches the
  -- center notice directly when dungeon context is intentional.
  function context.ShowCenterNotice(message, durationSeconds, _dungeonName, _activityID, showOptions)
    centerNotice.Show(message, durationSeconds, nil, nil, showOptions)
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
