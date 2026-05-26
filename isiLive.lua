local addonName, addonTable = ...

-- Delegate to the Composition Root Factory
local Factory = addonTable.Factory
if type(Factory) == "table" and type(Factory.InitializeAddon) == "function" then
  Factory.InitializeAddon(addonName, addonTable)
else
  local message = "isiLive: Error - Factory module not found or missing InitializeAddon."
  local ErrorLog = addonTable.ErrorLog
  if type(ErrorLog) == "table" and type(ErrorLog.Capture) == "function" then
    ErrorLog.Capture(message, nil, "startup")
  end
  print(message)
end
