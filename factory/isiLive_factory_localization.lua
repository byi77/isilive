local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

-- The open navigator holds finished texts, also the demo one; both come from
-- the same builder.
local function RefreshPortalNavigator(ctx, modules)
  local notice = ctx.portalNavigatorNotice
  local frame = type(notice) == "table" and notice.frame or nil
  if type(frame) ~= "table" or not frame:IsShown() or type(notice.Relabel) ~= "function" then
    return
  end
  local teleport = modules.teleport
  local layout = modules.status.BuildPortalNavigatorLayout({
    getL = ctx.GetL,
    getLocaleTag = ctx.GetActiveLocaleTag,
    getTeleportInfoByMapID = type(teleport) == "table" and teleport.GetTeleportInfoByMapID or nil,
  })
  if type(layout) == "table" then
    notice.Relabel(layout)
  end
end

-- Open center cards hold finished texts too, the demo stack included.
local function RefreshCenterNotices(ctx)
  local notices = { ctx.centerNotice }
  for _, notice in ipairs(ctx.demoCenterNotices or {}) do
    notices[#notices + 1] = notice
  end
  for _, notice in ipairs(notices) do
    if type(notice.RefreshLocalized) == "function" then
      notice.RefreshLocalized()
    end
  end
end

local function RefreshLoadoutCard()
  local loadoutCheck = addonTable.LoadoutCheck
  local controller = type(loadoutCheck) == "table"
      and type(loadoutCheck.GetController) == "function"
      and loadoutCheck.GetController()
    or nil
  if type(controller) == "table" and type(controller.Refresh) == "function" then
    controller.Refresh()
  end
end

local function InitializeFactoryLocalizationControllers(ctx, modules)
  ctx.ApplyLocalizationToUI = function()
    if modules.ui and type(modules.ui.EnsurePanelUI) == "function" then
      ctx.panelUI = modules.ui.EnsurePanelUI({
        getL = ctx.GetL,
        isInCombat = ctx.IsInCombat,
        isEnabled = function()
          return not IsiLiveDB or IsiLiveDB.showEscPanel ~= false
        end,
      })
    end
    if modules.ui and type(modules.ui.EnsureSecondPanelUI) == "function" then
      ctx.secondPanelUI = modules.ui.EnsureSecondPanelUI({
        getL = ctx.GetL,
        isInCombat = ctx.IsInCombat,
        isEnabled = function()
          return not IsiLiveDB or IsiLiveDB.showEscPanel ~= false
        end,
        firstPanelState = ctx.panelUI,
      })
    end
    if modules.ui and type(modules.ui.EnsureMountPanelUI) == "function" then
      ctx.mountPanelUI = modules.ui.EnsureMountPanelUI({
        getL = ctx.GetL,
        isInCombat = ctx.IsInCombat,
        isEnabled = function()
          return not IsiLiveDB or IsiLiveDB.showEscPanel ~= false
        end,
        travelPanelState = ctx.secondPanelUI,
      })
    end
    if modules.ui and type(modules.ui.EnsureThirdPanelUI) == "function" then
      ctx.thirdPanelUI = modules.ui.EnsureThirdPanelUI({
        getL = ctx.GetL,
        isInCombat = ctx.IsInCombat,
        isEnabled = function()
          return not IsiLiveDB or IsiLiveDB.showEscPanel ~= false
        end,
        secondPanelState = ctx.secondPanelUI,
        panelActions = {
          isilive = function()
            local blizzardSettings = rawget(_G, "Settings")
            if type(blizzardSettings) ~= "table" or type(blizzardSettings.OpenToCategory) ~= "function" then
              return false
            end
            if ctx.settingsPanel and ctx.settingsPanel.category then
              blizzardSettings.OpenToCategory(ctx.settingsPanel.category.ID)
              return true
            end
            return false
          end,
        },
      })
    end
    ctx.rosterPanelController.ApplyLocalization()
    -- The kill row writes its texts only on refresh, also while the demo runs.
    if type(ctx.rosterPanelController.RefreshKillTrackRow) == "function" then
      ctx.rosterPanelController.RefreshKillTrackRow()
    end
    ctx.UpdateCountdownCancelButton()
    if ctx.centerNoticeTeleportButton and ctx.centerNoticeTeleportButton:IsShown() then
      local spellID = ctx.centerNoticeTeleportButton.spellID
      local enabled = spellID and ctx.IsSpellKnownSafe(spellID) and not ctx.centerNoticeTeleportButton.inCombatBlocked
      ctx.UpdateCenterTeleportButtonVisual(spellID, enabled, ctx.centerNoticeTeleportButton.inCombatBlocked)
    end
    ctx.UpdateMPlusTeleportButton()
    ctx.UpdateStatusLine()
    -- Roster key column and tooltips: abbreviations follow the language.
    if type(ctx.UpdateUI) == "function" then
      -- The demo roster's own row has no stored key, so a plain render blanks it.
      if ctx.keySyncController and type(ctx.RefreshLocalPlayerKey) == "function" then
        ctx.RefreshLocalPlayerKey()
      end
      ctx.UpdateUI()
    end
    RefreshPortalNavigator(ctx, modules)
    RefreshCenterNotices(ctx)
    RefreshLoadoutCard()
    if ctx.settingsPanel and type(ctx.settingsPanel.Refresh) == "function" then
      ctx.settingsPanel.Refresh()
    end
  end
end

FI.InitializeFactoryLocalizationControllers = InitializeFactoryLocalizationControllers

return {
  InitializeFactoryLocalizationControllers = InitializeFactoryLocalizationControllers,
}
