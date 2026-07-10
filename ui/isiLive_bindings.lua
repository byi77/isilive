local _, addonTable = ...

addonTable = addonTable or {}

local Bindings = {}
addonTable.Bindings = Bindings

local function RequireFunction(value, name)
  return addonTable.Validators.RequireFunction(value, name, "Bindings")
end

local function CreateHiddenBindingButton(globalName, yOffset, clickHandler)
  local button = CreateFrame("Button", globalName, UIParent)
  button:SetSize(1, 1)
  button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -100, yOffset)
  button:SetAlpha(0)
  button:EnableMouse(true)
  button:RegisterForClicks("AnyDown", "AnyUp")
  button:SetScript("OnClick", function(_, _, down)
    if down == false then
      return
    end
    clickHandler()
  end)
  return button
end

function Bindings.CreateController(opts)
  opts = opts or {}

  local onToggleMainFrame = RequireFunction(opts.onToggleMainFrame, "onToggleMainFrame")
  local onToggleTestMode = RequireFunction(opts.onToggleTestMode, "onToggleTestMode")

  local pendingBindingApply = false
  local bindingOwnerFrame = CreateFrame("Frame", "isiLiveBindingOwnerFrame", UIParent)
  local bindingWatchTicker

  local toggleBindingButton = CreateHiddenBindingButton("isiLiveToggleBindingButton", -100, onToggleMainFrame)
  local testModeBindingButton = CreateHiddenBindingButton("isiLiveTestModeBindingButton", -102, onToggleTestMode)

  local function IsCombatLockdownActive()
    local inCombat = rawget(_G, "InCombatLockdown")
    return type(inCombat) == "function" and inCombat() == true
  end

  local function ApplyHotkeyBindings()
    if not (toggleBindingButton and testModeBindingButton) then
      return
    end
    if IsCombatLockdownActive() then
      pendingBindingApply = true
      return
    end

    local clearOverride = rawget(_G, "ClearOverrideBindings")
    if type(clearOverride) == "function" then
      clearOverride(bindingOwnerFrame)
    end
    local setOverride = rawget(_G, "SetOverrideBindingClick")
    if type(setOverride) ~= "function" then
      -- Without the binding API there is nothing more we can do; leave the
      -- pending flag set so a later ApplyHotkeyBindings() call can retry.
      pendingBindingApply = true
      return
    end
    setOverride(bindingOwnerFrame, true, "CTRL-F9", "isiLiveToggleBindingButton", "LeftButton")
    setOverride(bindingOwnerFrame, true, "CTRL-ALT-F9", "isiLiveTestModeBindingButton", "LeftButton")
    setOverride(bindingOwnerFrame, true, "ALT-CTRL-F9", "isiLiveTestModeBindingButton", "LeftButton")
    pendingBindingApply = false
  end

  local function ExpectedBindingPresent()
    local getBindingAction = rawget(_G, "GetBindingAction")
    if type(getBindingAction) ~= "function" then
      return false
    end
    local a1 = getBindingAction("CTRL-F9", true)
    local a2 = getBindingAction("CTRL-ALT-F9", true)
    local a3 = getBindingAction("ALT-CTRL-F9", true)
    local ok1 = a1 and a1:find("isiLiveToggleBindingButton", 1, true)
    local ok2 = (a2 and a2:find("isiLiveTestModeBindingButton", 1, true))
      or (a3 and a3:find("isiLiveTestModeBindingButton", 1, true))
    return ok1 and ok2
  end

  local function StartBindingWatchdog()
    if bindingWatchTicker then
      return
    end
    local timer = rawget(_G, "C_Timer")
    if type(timer) ~= "table" or type(timer.NewTicker) ~= "function" then
      return
    end
    bindingWatchTicker = timer.NewTicker(5, function()
      if not ExpectedBindingPresent() then
        if IsCombatLockdownActive() then
          pendingBindingApply = true
        else
          ApplyHotkeyBindings()
        end
      end
    end)
  end

  local function StopBindingWatchdog()
    if bindingWatchTicker and type(bindingWatchTicker.Cancel) == "function" then
      bindingWatchTicker:Cancel()
    end
    bindingWatchTicker = nil
  end

  local controller = {}

  function controller.ApplyHotkeyBindings()
    ApplyHotkeyBindings()
  end

  function controller.StartBindingWatchdog()
    StartBindingWatchdog()
  end

  function controller.StopBindingWatchdog()
    StopBindingWatchdog()
  end

  function controller.GetPendingBindingApply()
    return pendingBindingApply
  end

  return controller
end
