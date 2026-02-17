local _, addonTable = ...

addonTable = addonTable or {}

local Bindings = {}
addonTable.Bindings = Bindings

local function RequireFunction(value, name)
  assert(type(value) == "function", "isiLive: Bindings requires " .. name)
  return value
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

  local function ApplyHotkeyBindings()
    if not (toggleBindingButton and testModeBindingButton) then
      return
    end
    if InCombatLockdown and InCombatLockdown() then
      pendingBindingApply = true
      return
    end

    if ClearOverrideBindings then
      ClearOverrideBindings(bindingOwnerFrame)
    end
    SetOverrideBindingClick(bindingOwnerFrame, true, "CTRL-F9", "isiLiveToggleBindingButton", "LeftButton")
    SetOverrideBindingClick(bindingOwnerFrame, true, "CTRL-ALT-F9", "isiLiveTestModeBindingButton", "LeftButton")
    SetOverrideBindingClick(bindingOwnerFrame, true, "ALT-CTRL-F9", "isiLiveTestModeBindingButton", "LeftButton")
    pendingBindingApply = false
  end

  local function ExpectedBindingPresent()
    local a1 = GetBindingAction("CTRL-F9", true)
    local a2 = GetBindingAction("CTRL-ALT-F9", true)
    local a3 = GetBindingAction("ALT-CTRL-F9", true)
    local ok1 = a1 and a1:find("isiLiveToggleBindingButton", 1, true)
    local ok2 = (a2 and a2:find("isiLiveTestModeBindingButton", 1, true))
      or (a3 and a3:find("isiLiveTestModeBindingButton", 1, true))
    return ok1 and ok2
  end

  local function StartBindingWatchdog()
    if bindingWatchTicker or not C_Timer or not C_Timer.NewTicker then
      return
    end
    bindingWatchTicker = C_Timer.NewTicker(5, function()
      if not ExpectedBindingPresent() then
        if InCombatLockdown and InCombatLockdown() then
          pendingBindingApply = true
        else
          ApplyHotkeyBindings()
        end
      end
    end)
  end

  local controller = {}

  function controller.ApplyHotkeyBindings()
    ApplyHotkeyBindings()
  end

  function controller.StartBindingWatchdog()
    StartBindingWatchdog()
  end

  function controller.GetPendingBindingApply()
    return pendingBindingApply
  end

  return controller
end
