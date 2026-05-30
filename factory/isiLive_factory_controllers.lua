local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

return {
  InitializeFactoryPrimaryControllers = FI.InitializeFactoryPrimaryControllers,
  InitializeFactoryRefreshAndStatusControllers = FI.InitializeFactoryRefreshAndStatusControllers,
  InitializeFactorySecondaryControllers = FI.InitializeFactorySecondaryControllers,
}
