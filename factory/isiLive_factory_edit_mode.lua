local _, addonTable = ...
addonTable = addonTable or {}

-- Wires the Blizzard Edit Mode integration (ui/isiLive_edit_mode.lua, rule
-- 243) to the main window, the roster layout and the setters the settings
-- panel uses, so the Edit Mode dialog changes the same values the same way.
local FactoryEditMode = {}
addonTable.FactoryEditMode = FactoryEditMode

local function RefreshSettingsPanel(ctx)
  if ctx.settingsPanel and type(ctx.settingsPanel.Refresh) == "function" then
    ctx.settingsPanel.Refresh()
  end
end

--- Installs the integration once the main window, the roster panel and the
--- settings panel exist. Returns the controller or nil (no library, e.g. a
--- client without Edit Mode, or no main window).
function FactoryEditMode.Install(ctx)
  local editMode = addonTable.EditMode
  local mainUI = ctx and ctx.mainUI
  if type(editMode) ~= "table" or type(editMode.Install) ~= "function" or type(mainUI) ~= "table" then
    return nil
  end
  local roster = ctx.rosterPanelController
  return editMode.Install({
    lib = addonTable.LibEditMode,
    frame = ctx.mainFrame or mainUI.frame,
    mainUI = mainUI,
    getLayoutMode = function()
      return roster and type(roster.GetLayoutMode) == "function" and roster.GetLayoutMode() or nil
    end,
    setLayoutMode = function(mode)
      if roster and type(roster.SetLayoutMode) == "function" then
        roster.SetLayoutMode(mode)
      end
    end,
    applyBgAlpha = function(value)
      local uiCommon = addonTable.UICommon
      if type(uiCommon) == "table" and type(uiCommon.ApplyBgAlpha) == "function" then
        uiCommon.ApplyBgAlpha({
          mainFrame = ctx.mainFrame,
          panelFrame = ctx.panelUI and ctx.panelUI.panelFrame,
          settingsWindow = ctx.settingsPanel and ctx.settingsPanel.windowFrame,
        }, value)
      end
    end,
    isLocked = function()
      if type(mainUI.GetDragLocked) == "function" then
        return mainUI.GetDragLocked() == true
      end
      local db = rawget(_G, "IsiLiveDB")
      return not (type(db) == "table" and db.lockMainFramePosition == false)
    end,
    setLocked = function(locked)
      local db = rawget(_G, "IsiLiveDB")
      if type(db) == "table" then
        db.lockMainFramePosition = locked == true
      end
      if type(mainUI.SetDragLocked) == "function" then
        mainUI.SetDragLocked(locked == true)
      end
    end,
    isInCombat = function()
      local inCombat = rawget(_G, "InCombatLockdown")
      return type(inCombat) == "function" and inCombat() == true
    end,
    getText = function(key, fallback)
      local L = type(ctx.GetL) == "function" and ctx.GetL() or nil
      local text = type(L) == "table" and L[key] or nil
      return type(text) == "string" and text or fallback
    end,
    onValuesChanged = function()
      RefreshSettingsPanel(ctx)
    end,
  })
end

--- Features installed after every window exists: the Edit Mode integration
--- (ctx.editModeController) and the live kicks between pulls (rule 245,
--- ctx.liveKicksFrame, factory/isiLive_factory_live_kicks.lua).
function FactoryEditMode.InstallLate(ctx)
  ctx.editModeController = FactoryEditMode.Install(ctx)
  local liveKicks = addonTable.FactoryLiveKicks
  if type(liveKicks) == "table" and type(liveKicks.Install) == "function" then
    ctx.liveKicksFrame = liveKicks.Install(ctx)
  end
end
