local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

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
    ctx.UpdateCountdownCancelButton()
    if ctx.centerNoticeTeleportButton and ctx.centerNoticeTeleportButton:IsShown() then
      local spellID = ctx.centerNoticeTeleportButton.spellID
      local enabled = spellID and ctx.IsSpellKnownSafe(spellID) and not ctx.centerNoticeTeleportButton.inCombatBlocked
      ctx.UpdateCenterTeleportButtonVisual(spellID, enabled, ctx.centerNoticeTeleportButton.inCombatBlocked)
    end
    ctx.UpdateMPlusTeleportButton()
    ctx.UpdateStatusLine()
    if ctx.settingsPanel and type(ctx.settingsPanel.Refresh) == "function" then
      ctx.settingsPanel.Refresh()
    end
  end
end

FI.InitializeFactoryLocalizationControllers = InitializeFactoryLocalizationControllers

return {
  InitializeFactoryLocalizationControllers = InitializeFactoryLocalizationControllers,
}
