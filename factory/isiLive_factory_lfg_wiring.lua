local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local BuildLFGGroupRosterTraceLogger = FI.BuildLFGGroupRosterTraceLogger

local function InitializeFactoryLfgWiringControllers(ctx, modules)
  ctx.GetNormalizedActiveEntryInfo = function()
    return ctx.highlightController.GetNormalizedActiveEntryInfo()
  end
  ctx.ResolveActiveTeleportSpellID = function()
    local _, latestQueueActivityID, _, latestQueueMapID = ctx.runtimeState.GetLatestQueueState()
    local effectiveQueueMapID = latestQueueMapID
    local localTargetMapID = ctx.ResolveLocalStatusTargetMapID and ctx.ResolveLocalStatusTargetMapID() or nil
    if localTargetMapID then
      effectiveQueueMapID = localTargetMapID
    else
      local syncedTargetInfo = ctx.ResolveSyncedTargetInfo and ctx.ResolveSyncedTargetInfo() or nil
      if type(syncedTargetInfo) == "table" then
        effectiveQueueMapID = tonumber(syncedTargetInfo.mapID) or effectiveQueueMapID
      end
    end

    return ctx.highlightController.ResolveActiveTeleportSpellID(latestQueueActivityID, effectiveQueueMapID)
  end
  ctx.ResolveJoinedKeyMapID = function(activityID, spellID)
    return ctx.highlightController.ResolveJoinedKeyMapID(activityID, spellID)
  end
  ctx.ResolveActiveKeyOwnerUnit = function()
    local targetMapID = nil
    if type(ctx.ResolveStatusTargetMapID) == "function" then
      targetMapID = ctx.ResolveStatusTargetMapID()
    end

    local preferredOwnerName = nil
    local lfgDetect = addonTable.LFGDetect
    if type(lfgDetect) == "table" and type(lfgDetect.GetActiveInviteLeader) == "function" then
      preferredOwnerName = lfgDetect.GetActiveInviteLeader()
    end

    -- Fallback: when no LFG-leader hint is available (pre-formed group, or
    -- after invite-accepted state was cleared), use the observed group leader
    -- only as a disambiguation hint. This does not prove key ownership; the
    -- downstream resolver still requires a matching verified key map and fails
    -- closed instead of picking an arbitrary same-dungeon key.
    if type(preferredOwnerName) ~= "string" or preferredOwnerName == "" then
      local roster = ctx.GetRoster() or {}
      local unitIsGroupLeaderFn = rawget(_G, "UnitIsGroupLeader")
      if type(unitIsGroupLeaderFn) == "function" then
        for unit, info in pairs(roster) do
          if type(unit) == "string" and unit ~= "" and type(info) == "table" and not info.isGhost then
            local okLeader, isLeader = pcall(unitIsGroupLeaderFn, unit)
            if okLeader and isLeader == true then
              preferredOwnerName = addonTable.StringUtils.BuildQualifiedName(info.name, info.realm)
              break
            end
          end
        end
      end
    end

    return ctx.keySyncController.ResolveActiveKeyOwnerUnit(ctx.GetRoster(), targetMapID, preferredOwnerName)
  end
  ctx.UpdateMPlusTeleportButton = function(soundContext)
    local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
    local logfDeep = ctx.runtimeLogController and ctx.runtimeLogController.LogfDeep or nil
    local traceDeep = ctx.runtimeLogController and ctx.runtimeLogController.TraceDeep or nil
    if soundContext and logf then
      logf("[TP] update_button_called soundContext=%s", tostring(soundContext))
    elseif logfDeep then
      logfDeep("[TP] update_button_called soundContext=%s", tostring(soundContext))
    end
    -- Priority 1: LFGDetect (invite accepted / own active listing). This is
    -- the strongest direct signal from the current LFG flow and must
    -- outrank sync/queue/listing resolution, which can otherwise surface a
    -- stale or peer-synced mapID that overrides the just-accepted invite.
    local resolvedSpellID = nil
    local lfgDetect = addonTable.LFGDetect
    local detectedMapID = type(lfgDetect) == "table"
        and type(lfgDetect.GetDetectedMapID) == "function"
        and lfgDetect.GetDetectedMapID()
      or nil
    if traceDeep then
      traceDeep(function()
        return string.format("[TP] lfg_detected_map detectedMapID=%s", tostring(detectedMapID))
      end)
    end
    if detectedMapID then
      resolvedSpellID = modules.teleport.ResolveTeleportSpellIDByMapID(detectedMapID)
      if traceDeep then
        traceDeep(function()
          return string.format(
            "[TP] spell_from_lfg mapID=%s resolvedSpellID=%s",
            tostring(detectedMapID),
            tostring(resolvedSpellID)
          )
        end)
      end
    end
    if not resolvedSpellID then
      resolvedSpellID = ctx.ResolveActiveTeleportSpellID()
      if traceDeep then
        traceDeep(function()
          return string.format("[TP] spell_from_active resolvedSpellID=%s", tostring(resolvedSpellID))
        end)
      end
    end
    if traceDeep then
      traceDeep(function()
        return string.format(
          "[TP] frame_show_check spellFound=%s soundContext=%s frameShown=%s",
          tostring(resolvedSpellID ~= nil),
          tostring(soundContext),
          tostring(ctx.mainFrame and ctx.mainFrame:IsShown())
        )
      end)
    end
    if
      resolvedSpellID
      and (soundContext == "queue" or soundContext == "invite")
      and type(ctx.mainFrame) == "table"
      and type(ctx.mainFrame.IsShown) == "function"
      and ctx.mainFrame:IsShown() ~= true
      and type(ctx.SetMainFrameVisible) == "function"
    then
      ctx.SetMainFrameVisible(true, {
        reason = "lfg-highlight",
        skipShowCallbacks = true,
      })
    end
    if traceDeep then
      traceDeep(function()
        return string.format("[TP] update_buttons_called resolvedSpellID=%s", tostring(resolvedSpellID))
      end)
    end
    ctx.teleportUIController.UpdateButtons(resolvedSpellID, soundContext)
  end

  -- ARCH-1 fix: inject UpdateMPlusTeleportButton into LFGDetect so the game-layer
  -- module no longer needs to reach into _factoryCtx directly.
  local lfgDetect = addonTable.LFGDetect
  if type(lfgDetect) == "table" then
    if type(lfgDetect.SetHighlightCallback) == "function" then
      lfgDetect.SetHighlightCallback(ctx.UpdateMPlusTeleportButton)
    end
    if type(lfgDetect.SetGroupRosterTraceLogger) == "function" then
      lfgDetect.SetGroupRosterTraceLogger(BuildLFGGroupRosterTraceLogger(ctx, modules))
    end
    if type(lfgDetect.SetTraceLogger) == "function" then
      lfgDetect.SetTraceLogger(ctx.runtimeLogController and ctx.runtimeLogController.Trace or nil)
    end
    if type(lfgDetect.SetDeepTraceLogger) == "function" then
      lfgDetect.SetDeepTraceLogger(ctx.runtimeLogController and ctx.runtimeLogController.TraceDeep or nil)
    end
    if type(lfgDetect.SetLogger) == "function" then
      lfgDetect.SetLogger(nil)
    end
    -- Post-accept Center Notice plumbing. Triggered from OnInviteAccepted with
    -- a payload extracted exclusively from the accepted searchResultID's
    -- pendingInvites entry. Sibling listings (different searchResultID) cannot
    -- influence the rendered content. Level is taken straight from
    -- entry.titleLevel; when nil (group title without "+N"), the headline is
    -- rendered without a level suffix; never inferred from roster/sync data.
    -- Raid-only mirror is wired in the same helper so the M+ pipeline stays
    -- untouched for Raid invites.
    local factoryNotices = FI.FactoryNotices or {}
    local wireAcceptedInviteNoticeCallbacks = factoryNotices.WireAcceptedInviteNoticeCallbacks
    if type(wireAcceptedInviteNoticeCallbacks) == "function" then
      wireAcceptedInviteNoticeCallbacks(ctx, modules, lfgDetect)
    end
  end
end

FI.InitializeFactoryLfgWiringControllers = InitializeFactoryLfgWiringControllers

return {
  InitializeFactoryLfgWiringControllers = InitializeFactoryLfgWiringControllers,
}
