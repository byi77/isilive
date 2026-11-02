local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local function RegisterBlizzardUnitLanguageTooltip(ctx, modules)
  ctx.GetUnitServerLanguage = function(unit, realm)
    return modules.contextHelpers.GetUnitServerLanguage(modules.locale, ctx.GetRealmInfoLib, unit, realm)
  end

  local rosterTooltip = ctx.addonTable and ctx.addonTable.RosterUI
  if type(rosterTooltip) == "table" and type(rosterTooltip.RegisterBlizzardUnitLanguageTooltip) == "function" then
    rosterTooltip.RegisterBlizzardUnitLanguageTooltip({
      getUnitNameAndRealm = ctx.GetUnitNameAndRealm,
      getUnitServerLanguage = ctx.GetUnitServerLanguage,
      getRealmInfoLib = ctx.GetRealmInfoLib,
      getLanguageTooltipMarkup = ctx.GetLanguageTooltipMarkup,
    })
  end

  local lfgFlags = ctx.addonTable and ctx.addonTable.LFGFlags
  if type(lfgFlags) == "table" and type(lfgFlags.Register) == "function" then
    lfgFlags.Register({
      getRealmInfoLib = ctx.GetRealmInfoLib,
      localeModule = modules.locale,
    })
  end
end

local function InitializeFactorySecondaryRuntimeMethods(ctx, modules)
  ctx.SetLanguage = function(tag)
    local resolved = modules.locale.ResolveLocaleTag(tag)
    local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
    if logf then
      logf("[SETTINGS] set_language tag=%s resolved=%s", tostring(tag), tostring(resolved))
    end
    ctx.L = ctx.locales[resolved] or ctx.locales.enUS
    if IsiLiveDB then
      IsiLiveDB.locale = resolved
    end
    ctx.ApplyLocalizationToUI()
    local langMsgKey = "LANG_SET_EN"
    if resolved == "deDE" then
      langMsgKey = "LANG_SET_DE"
    elseif resolved == "frFR" then
      langMsgKey = "LANG_SET_FR"
    elseif resolved == "ruRU" then
      langMsgKey = "LANG_SET_RU"
    elseif resolved == "trTR" then
      langMsgKey = "LANG_SET_TR"
    end
    ctx.Print(ctx.L[langMsgKey])
  end
  ctx.SetLocaleTable = function(value)
    ctx.L = value
  end
  ctx.EnqueueInspect = function(unit)
    ctx.inspectController.EnqueueInspect(unit, ctx.GetRoster())
  end
  ctx.CheckIfEnteredTargetDungeon = function()
    local logFn = ctx.runtimeLogController and ctx.runtimeLogController.Log or nil
    local logDeepFn = ctx.runtimeLogController and ctx.runtimeLogController.LogDeep or nil
    local targetMapID = ctx.ResolveStatusTargetMapID()
    if not targetMapID then
      return
    end

    -- targetMapID is a challenge-mode map ID; the player's UiMapID lives in a
    -- different ID space and never equals it. Compare instance IDs instead
    -- (rule 193); any missing or masked value fails closed.
    local matched, currentInstanceID, targetInstanceID =
      addonTable.Validators.IsPlayerInChallengeMapInstance(targetMapID)
    if not currentInstanceID then
      return
    end

    local logTarget = matched and logFn or logDeepFn
    if logTarget then
      logTarget(
        string.format(
          "[STATE] check_entered_target_dungeon targetMapID=%s targetInstanceID=%s currentInstanceID=%s match=%s",
          tostring(targetMapID),
          tostring(targetInstanceID),
          tostring(currentInstanceID),
          tostring(matched)
        )
      )
    end
    if matched then
      if type(ctx.RememberEnteredTargetDungeon) == "function" then
        ctx.RememberEnteredTargetDungeon(targetMapID)
      end
      local lfgDetect = addonTable.LFGDetect
      if type(lfgDetect) == "table" and type(lfgDetect.ClearAllState) == "function" then
        lfgDetect.ClearAllState()
      end
      ctx.ClearLatestQueueTarget()
      ctx.UpdateMPlusTeleportButton()
      return
    end
  end
end

-- Applies the stored UI design (rule 233). Most frames are built at file load,
-- before SavedVariables exist, so the ADDON_LOADED pass of ApplyDBSettings
-- applies it and repaints through the background-opacity path when a color
-- actually changed. Unknown or missing values resolve to classic.
local function ApplyStoredUiDesign(ctx, db)
  local uiCommon = ctx.addonTable and ctx.addonTable.UICommon
  if type(uiCommon) ~= "table" or type(uiCommon.ApplyDesign) ~= "function" then
    return
  end
  local _, changed = uiCommon.ApplyDesign(db.uiDesign)
  if changed and type(ctx.RestoreBgAlpha) == "function" then
    ctx.RestoreBgAlpha(type(db.bgAlpha) == "number" and db.bgAlpha or uiCommon.GetBackgroundAlpha())
  end
end

-- A design switch is not live: it is stored and takes effect after /reload.
-- Prints the reload hint when the stored design differs from the active one.
local function AnnounceUiDesignChange(ctx, design)
  local uiCommon = ctx.addonTable and ctx.addonTable.UICommon
  if type(uiCommon) ~= "table" or design == uiCommon.GetActiveDesign() then
    return false
  end
  local L = (type(ctx.GetL) == "function" and ctx.GetL()) or {}
  local labelKey = design == "modern" and "SETTINGS_UI_DESIGN_MODERN" or "SETTINGS_UI_DESIGN_CLASSIC"
  local hint = L.UI_DESIGN_RELOAD_HINT or "Design set to %s. Type /reload to apply it."
  ctx.Print(string.format(hint, L[labelKey] or design))
  return true
end

-- Shared write path of the settings selector callback and /isilive design.
-- Returns the stored design (nil for an unknown name) and whether a reload is
-- needed to see it.
local function SetUiDesign(ctx, name)
  local uiCommon = ctx.addonTable and ctx.addonTable.UICommon
  local design = type(uiCommon) == "table" and uiCommon.NormalizeDesign(name) or nil
  local db = rawget(_G, "IsiLiveDB")
  if not design or type(db) ~= "table" then
    return nil, false
  end
  db.uiDesign = design
  if ctx.settingsPanel and type(ctx.settingsPanel.Refresh) == "function" then
    ctx.settingsPanel.Refresh()
  end
  return design, AnnounceUiDesignChange(ctx, design)
end

FI.RegisterBlizzardUnitLanguageTooltip = RegisterBlizzardUnitLanguageTooltip
FI.ApplyStoredUiDesign = ApplyStoredUiDesign
FI.AnnounceUiDesignChange = AnnounceUiDesignChange
FI.SetUiDesign = SetUiDesign
FI.InitializeFactorySecondaryRuntimeMethods = InitializeFactorySecondaryRuntimeMethods

return {
  RegisterBlizzardUnitLanguageTooltip = RegisterBlizzardUnitLanguageTooltip,
  InitializeFactorySecondaryRuntimeMethods = InitializeFactorySecondaryRuntimeMethods,
}
