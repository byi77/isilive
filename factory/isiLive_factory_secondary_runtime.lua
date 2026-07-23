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
    elseif resolved == "esES" then
      langMsgKey = "LANG_SET_ES"
    elseif resolved == "ptBR" then
      langMsgKey = "LANG_SET_PT"
    elseif resolved == "itIT" then
      langMsgKey = "LANG_SET_IT"
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

    local currentMapID = nil
    local mapApi = rawget(_G, "C_Map")
    local getBestMapForUnit = type(mapApi) == "table" and rawget(mapApi, "GetBestMapForUnit") or nil
    local unitExists = rawget(_G, "UnitExists")
    if type(getBestMapForUnit) == "function" and type(unitExists) == "function" then
      local okUnit, playerExists = pcall(unitExists, "player")
      if okUnit and not addonTable.Validators.IsSecretValue(playerExists) and playerExists == true then
        local okMap, mapID = pcall(getBestMapForUnit, "player")
        if okMap and not addonTable.Validators.IsSecretValue(mapID) and type(mapID) == "number" and mapID > 0 then
          currentMapID = mapID
        end
      end
    end
    if not currentMapID then
      return
    end

    local matched = currentMapID == targetMapID
    local logTarget = matched and logFn or logDeepFn
    if logTarget then
      logTarget(
        string.format(
          "[STATE] check_entered_target_dungeon targetMapID=%s currentMapID=%s match=%s",
          tostring(targetMapID),
          tostring(currentMapID),
          tostring(matched)
        )
      )
    end
    if targetMapID and currentMapID == targetMapID then
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

FI.RegisterBlizzardUnitLanguageTooltip = RegisterBlizzardUnitLanguageTooltip
FI.InitializeFactorySecondaryRuntimeMethods = InitializeFactorySecondaryRuntimeMethods

return {
  RegisterBlizzardUnitLanguageTooltip = RegisterBlizzardUnitLanguageTooltip,
  InitializeFactorySecondaryRuntimeMethods = InitializeFactorySecondaryRuntimeMethods,
}
