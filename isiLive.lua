local addonName, addonTable = ...

-- Delegate to the Composition Root Factory
local Factory = addonTable.Factory
if type(Factory) == "table" and type(Factory.InitializeAddon) == "function" then
  Factory.InitializeAddon(addonName, addonTable)
else
  print("isiLive: Error - Factory module not found or missing InitializeAddon.")
end
