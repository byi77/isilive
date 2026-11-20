local addonName, addonTable = ...

addonTable = addonTable or {}

local WagoStats = {}
addonTable.WagoStats = WagoStats

-- Usage statistics through Wago Analytics (rule 257). The WagoAnalytics
-- addon ships with the Wago App, not with isiLive; it stores the values in
-- its own SavedVariables and the app uploads them (the user can opt out in
-- the app). Without that addon, or without the X-Wago-ID in the TOC, nothing
-- happens. isiLive only reports a few anonymous feature flags and a session
-- counter, never names, and turns off the library's Lua error reports.

local registered -- the WagoAnalytics handle, false once registration failed

local function ReadWagoId()
  local cAddOns = rawget(_G, "C_AddOns")
  local getMetadata = type(cAddOns) == "table" and cAddOns.GetAddOnMetadata or nil
  if type(getMetadata) ~= "function" then
    return nil
  end
  local ok, wagoId = pcall(getMetadata, addonName or "isiLive", "X-Wago-ID")
  if ok and type(wagoId) == "string" and wagoId ~= "" then
    return wagoId
  end
  return nil
end

function WagoStats.GetHandle()
  if registered ~= nil then
    return registered or nil
  end
  registered = false
  local lib = rawget(_G, "WagoAnalytics")
  local wagoId = ReadWagoId()
  if type(lib) ~= "table" or type(lib.Register) ~= "function" or not wagoId then
    return nil
  end
  local ok, handle = pcall(lib.Register, lib, wagoId, { reportErrors = false })
  if ok and type(handle) == "table" then
    registered = handle
  end
  return registered or nil
end

-- Once per session at PLAYER_LOGIN: one session, the active design and
-- whether TTK is on.
function WagoStats.Report(db)
  local handle = WagoStats.GetHandle()
  if not handle then
    return false
  end
  db = type(db) == "table" and db or {}
  local design = db.uiDesign == "classic" and "classic" or "modern"
  pcall(handle.IncrementCounter, handle, "sessions", 1)
  pcall(handle.Switch, handle, "design_modern", design == "modern")
  pcall(handle.Switch, handle, "design_classic", design == "classic")
  pcall(handle.Switch, handle, "ttk_enabled", db.ttkEnabled ~= false)
  return true
end

local createFrame = rawget(_G, "CreateFrame")
if type(createFrame) == "function" then
  local loginFrame = createFrame("Frame")
  addonTable.EventUtils.SafeRegisterEvent(loginFrame, "PLAYER_LOGIN")
  loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    WagoStats.Report(rawget(_G, "IsiLiveDB"))
  end)
end
