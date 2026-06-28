local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local RegisterBlizzardUnitLanguageTooltip = FI.RegisterBlizzardUnitLanguageTooltip
local InitializeFactorySecondaryRuntimeMethods = FI.InitializeFactorySecondaryRuntimeMethods
local InitializeFactorySecondaryCdTracker = FI.InitializeFactorySecondaryCdTracker
local InitializeFactorySecondaryTestModeAndBindings = FI.InitializeFactorySecondaryTestModeAndBindings

local function InitializeFactorySecondaryControllers(ctx)
  local modules = ctx.modules
  local runtimeState = ctx.runtimeState
  local getTime = rawget(_G, "GetTime")
  local getUnitName = UnitName
  local getRealmName = GetRealmName

  local function IsMainFrameShown()
    return ctx.mainFrame and type(ctx.mainFrame.IsShown) == "function" and ctx.mainFrame:IsShown() == true
  end

  local function IsRaidModeActive()
    return type(ctx.IsRaidGroup) == "function" and ctx.IsRaidGroup() == true
  end

  local function IsGroupSyncActive()
    local isInGroup = type(ctx.IsInGroup) == "function" and ctx.IsInGroup or ctx.isInGroup
    if type(isInGroup) == "function" and isInGroup() == true then
      return true
    end
    return type(ctx.isInInstanceGroup) == "function" and ctx.isInInstanceGroup() == true
  end

  RegisterBlizzardUnitLanguageTooltip(ctx, modules)
  InitializeFactorySecondaryTestModeAndBindings(ctx, modules, runtimeState)
  InitializeFactorySecondaryRuntimeMethods(ctx, modules)
  InitializeFactorySecondaryCdTracker(ctx, modules, runtimeState, getTime, IsMainFrameShown, IsRaidModeActive)
  if type(FI.InitializeFactorySecondaryKickTracker) == "function" then
    FI.InitializeFactorySecondaryKickTracker(
      ctx,
      modules,
      getTime,
      getUnitName,
      getRealmName,
      IsMainFrameShown,
      IsRaidModeActive,
      IsGroupSyncActive
    )
  end
end

FI.InitializeFactorySecondaryControllers = InitializeFactorySecondaryControllers

return {
  InitializeFactorySecondaryControllers = InitializeFactorySecondaryControllers,
}
