local _, addonTable = ...
addonTable = addonTable or {}

local VipDkAssist = {}
addonTable.VipDkAssist = VipDkAssist
local IsSecretValue = addonTable.Validators.IsSecretValue
local ReadPlainNumber = addonTable.Validators.ReadPlainNumber

local DARK_TRANSFORMATION_SPELL_ID = 1233448
local SOUL_REAPER_SPELL_ID = 343294
local PUTREFY_SPELL_ID = 1247378
local UNHOLY_DEATH_KNIGHT_SPEC_ID = 252
-- Used only when the live Dark Transformation cooldown cannot be read: the
-- tooltip cooldown (45s) minus the warning window, i.e. the pre-12.1 constant.
local FALLBACK_WARNING_DELAY_SECONDS = 30
local WARNING_DURATION_SECONDS = 15
-- A cooldown read right after the cast can still report the GCD or a not yet
-- registered cooldown. Anything outside this band is treated as unreadable.
local MIN_TRUSTED_COOLDOWN_SECONDS = 5
local MAX_TRUSTED_COOLDOWN_SECONDS = 300
-- Putrefy (tooltip: 3 charges, 30s recharge) is only worth banking while a
-- single charge is left. At 2+ charges the recharge runs into the cap, so
-- holding the button wastes uses instead of saving one for Dark Transformation.
-- Deliberate decision 2026-09-08: guides disagree here -- one recommends
-- banking 2 charges for the Soul Reaper window, the other calls that wasted
-- uses. The user plays the spec and settled on 1. Do not "fix" this to 2.
local PUTREFY_BANK_CHARGE_LIMIT = 1
local GHOUL_REMINDER_WIDTH = 300
local GHOUL_REMINDER_HEIGHT = 60
local GHOUL_REMINDER_FONT_SIZE = 32
local GHOUL_REMINDER_STATE_DRIVER = "[spec:3,nopet,nomounted,novehicleui] show; hide"

local function DefaultTimerAfter(delaySeconds, callback)
  local timer = rawget(_G, "C_Timer")
  local newTimer = type(timer) == "table" and timer.NewTimer or nil
  if type(newTimer) == "function" then
    return newTimer(delaySeconds, callback)
  end
  local after = type(timer) == "table" and timer.After or nil
  if type(after) == "function" then
    after(delaySeconds, callback)
  end
  return nil
end

local function DefaultGetDB()
  return rawget(_G, "IsiLiveDB") or {}
end

local function DefaultGetL()
  local texts = addonTable.L
  if type(texts) == "table" then
    return texts
  end
  return {}
end

local function DefaultIsInCombat()
  local inCombatLockdown = rawget(_G, "InCombatLockdown")
  if type(inCombatLockdown) ~= "function" then
    return false
  end
  local ok, result = pcall(inCombatLockdown)
  return ok and result == true
end

-- Live remaining cooldown of Dark Transformation, or nil when it cannot be
-- trusted. The warning window is anchored to the real cooldown so a shortened
-- or reset Dark Transformation moves the window with it.
local function DefaultGetDarkTransformationCooldownRemaining()
  local spellUtils = addonTable.SpellUtils
  if type(spellUtils) ~= "table" or type(spellUtils.GetSpellCooldownSafe) ~= "function" then
    return nil
  end
  local okCooldown, start, duration, enabled = pcall(spellUtils.GetSpellCooldownSafe, DARK_TRANSFORMATION_SPELL_ID)
  if not okCooldown or enabled == false or enabled == 0 then
    return nil
  end
  if type(start) ~= "number" or type(duration) ~= "number" or start <= 0 or duration <= 0 then
    return nil
  end

  local getTime = rawget(_G, "GetTime")
  if type(getTime) ~= "function" then
    return nil
  end
  local okNow, now = pcall(getTime)
  if not okNow or IsSecretValue(now) or type(now) ~= "number" then
    return nil
  end

  local remaining = start + duration - now
  if remaining <= 0 then
    return nil
  end
  return remaining
end

-- Current Putrefy charges, or nil when the API is missing or masked.
local function DefaultGetPutrefyCharges()
  local cSpell = rawget(_G, "C_Spell")
  if type(cSpell) ~= "table" or type(cSpell.GetSpellCharges) ~= "function" then
    return nil
  end
  local ok, chargeInfoOrCharges = pcall(cSpell.GetSpellCharges, PUTREFY_SPELL_ID)
  if not ok or chargeInfoOrCharges == nil then
    return nil
  end
  -- Struct return since 11.0; the flat multi-return is kept for older stubs.
  if type(chargeInfoOrCharges) == "table" then
    return ReadPlainNumber(chargeInfoOrCharges, "currentCharges")
  end
  if IsSecretValue(chargeInfoOrCharges) or type(chargeInfoOrCharges) ~= "number" then
    return nil
  end
  return chargeInfoOrCharges
end

local function DefaultIsLocalUnholyDeathKnight()
  if not addonTable.Validators.IsExistingUnit("player") then
    return false
  end
  local unitClass = rawget(_G, "UnitClass")
  if type(unitClass) ~= "function" then
    return false
  end
  local okClass, _, classToken = pcall(unitClass, "player")
  if not okClass or IsSecretValue(classToken) or classToken ~= "DEATHKNIGHT" then
    return false
  end

  local specApi = rawget(_G, "C_SpecializationInfo")
  local getSpecialization = type(specApi) == "table" and specApi.GetSpecialization or rawget(_G, "GetSpecialization")
  local getSpecializationInfo = type(specApi) == "table" and specApi.GetSpecializationInfo
    or rawget(_G, "GetSpecializationInfo")
  if type(getSpecialization) ~= "function" or type(getSpecializationInfo) ~= "function" then
    return false
  end

  local okSpecIndex, specIndex = pcall(getSpecialization)
  if not okSpecIndex or IsSecretValue(specIndex) or type(specIndex) ~= "number" or specIndex <= 0 then
    return false
  end
  local okSpecInfo, specID = pcall(getSpecializationInfo, specIndex)
  return okSpecInfo and not IsSecretValue(specID) and tonumber(specID) == UNHOLY_DEATH_KNIGHT_SPEC_ID
end

local function DefaultGetActionSpellID(button)
  local helper = addonTable.ActionButtonOverlay
  if type(helper) == "table" and type(helper.GetActionSpellID) == "function" then
    return helper.GetActionSpellID(button)
  end
  return nil
end

local function DefaultScanButtonsForSpellID(getActionSpellID, targetSpellID)
  local helper = addonTable.ActionButtonOverlay
  if type(helper) == "table" and type(helper.ScanButtonsForSpellID) == "function" then
    return helper.ScanButtonsForSpellID(getActionSpellID, targetSpellID)
  end
  return {}
end

local function DefaultCreateOverlay(button)
  local helper = addonTable.ActionButtonOverlay
  if type(helper) == "table" and type(helper.CreateCrossOverlay) == "function" then
    return helper.CreateCrossOverlay(button)
  end
  return nil
end

local function SaveGhoulReminderPosition(frame, getDB)
  local db = getDB() or {}
  if type(db) ~= "table" or type(frame) ~= "table" or type(frame.GetPoint) ~= "function" then
    return
  end
  local point, _, relativePoint, x, y = frame:GetPoint()
  db.vipDkGhoulReminderPosition = {
    point = point or "CENTER",
    relativePoint = relativePoint or "CENTER",
    x = tonumber(x) or 0,
    y = tonumber(y) or 200,
  }
end

local function ApplyGhoulReminderPosition(frame, parent, getDB)
  local db = getDB() or {}
  local pos = type(db) == "table" and db.vipDkGhoulReminderPosition or nil
  if type(pos) ~= "table" then
    return
  end
  if
    type(pos.point) ~= "string"
    or pos.point == ""
    or type(pos.relativePoint) ~= "string"
    or pos.relativePoint == ""
    or type(pos.x) ~= "number"
    or type(pos.y) ~= "number"
    or type(frame.ClearAllPoints) ~= "function"
    or type(frame.SetPoint) ~= "function"
  then
    return
  end
  frame:ClearAllPoints()
  frame:SetPoint(pos.point, parent, pos.relativePoint, pos.x, pos.y)
end

local function DefaultCreateGhoulReminderFrame(parent, getDB, getL)
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return nil
  end
  parent = parent or rawget(_G, "UIParent")
  if type(parent) ~= "table" then
    return nil
  end

  local frame = createFrame("Frame", "isiLiveVipDkGhoulReminder", parent, "BackdropTemplate")
  frame:SetSize(GHOUL_REMINDER_WIDTH, GHOUL_REMINDER_HEIGHT)
  frame:SetPoint("CENTER", parent, "CENTER", 0, 200)
  frame:SetFrameStrata("HIGH")
  if type(frame.SetClampedToScreen) == "function" then
    frame:SetClampedToScreen(true)
  end
  if type(frame.SetMovable) == "function" then
    frame:SetMovable(true)
  end
  if type(frame.EnableMouse) == "function" then
    frame:EnableMouse(true)
  end
  if type(frame.RegisterForDrag) == "function" then
    frame:RegisterForDrag("LeftButton")
  end

  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(frame)
  bg:SetColorTexture(0, 0, 0, 0.18)
  frame.bg = bg

  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  text:SetPoint("CENTER", frame, "CENTER", 0, 0)
  text:SetTextColor(1, 0.16, 0.16, 1)
  text:SetText((getL() or {}).VIP_DK_GHOUL_REMINDER_TEXT or "SUMMON GHOUL")
  text:SetFont("Fonts\\FRIZQT__.TTF", GHOUL_REMINDER_FONT_SIZE, "OUTLINE")
  frame.text = text

  ApplyGhoulReminderPosition(frame, parent, getDB)

  frame:SetScript("OnDragStart", function(self)
    if type(self.StartMoving) == "function" then
      self:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function(self)
    if type(self.StopMovingOrSizing) == "function" then
      self:StopMovingOrSizing()
    end
    SaveGhoulReminderPosition(self, getDB)
  end)
  frame:Hide()
  return frame
end

function VipDkAssist.CreateController(opts)
  opts = opts or {}
  local getDB = type(opts.getDB) == "function" and opts.getDB or DefaultGetDB
  local isLocalUnholyDeathKnight = type(opts.isLocalUnholyDeathKnight) == "function" and opts.isLocalUnholyDeathKnight
    or DefaultIsLocalUnholyDeathKnight
  local getActionSpellID = type(opts.getActionSpellID) == "function" and opts.getActionSpellID
    or DefaultGetActionSpellID
  local scanSoulReaperButtons = type(opts.scanSoulReaperButtons) == "function" and opts.scanSoulReaperButtons
    or function()
      return DefaultScanButtonsForSpellID(getActionSpellID, SOUL_REAPER_SPELL_ID)
    end
  local scanPutrefyButtons = type(opts.scanPutrefyButtons) == "function" and opts.scanPutrefyButtons
    or function()
      return DefaultScanButtonsForSpellID(getActionSpellID, PUTREFY_SPELL_ID)
    end
  local createOverlay = type(opts.createOverlay) == "function" and opts.createOverlay or DefaultCreateOverlay
  local timerAfter = type(opts.timerAfter) == "function" and opts.timerAfter or DefaultTimerAfter
  local getL = type(opts.getL) == "function" and opts.getL or DefaultGetL
  local createGhoulReminderFrame = type(opts.createGhoulReminderFrame) == "function" and opts.createGhoulReminderFrame
    or DefaultCreateGhoulReminderFrame
  local registerStateDriver = type(opts.registerStateDriver) == "function" and opts.registerStateDriver
    or rawget(_G, "RegisterStateDriver")
  local unregisterStateDriver = type(opts.unregisterStateDriver) == "function" and opts.unregisterStateDriver
    or rawget(_G, "UnregisterStateDriver")
  local isInCombat = type(opts.isInCombat) == "function" and opts.isInCombat or DefaultIsInCombat
  local getDarkTransformationCooldownRemaining = type(opts.getDarkTransformationCooldownRemaining) == "function"
      and opts.getDarkTransformationCooldownRemaining
    or DefaultGetDarkTransformationCooldownRemaining
  local getPutrefyCharges = type(opts.getPutrefyCharges) == "function" and opts.getPutrefyCharges
    or DefaultGetPutrefyCharges

  local controller = {}
  local warningTimer = nil
  local hideTimer = nil
  local overlays = {}
  local warningActive = false
  local ghoulReminderFrame = nil
  local ghoulReminderDriverActive = false
  local pendingGhoulReminderApply = false

  local function CancelTimer(timer)
    if timer and type(timer.Cancel) == "function" then
      timer:Cancel()
    end
  end

  local function IsEnabled()
    local db = getDB() or {}
    return (db.vipDkSoulReaperWarningEnabled == true or db.vipDkPutrefyWarningEnabled == true)
      and isLocalUnholyDeathKnight() == true
  end

  local function IsGhoulReminderEnabled()
    local db = getDB() or {}
    return db.vipDkGhoulReminderEnabled == true and isLocalUnholyDeathKnight() == true
  end

  -- Since 12.1 Soul Reaper no longer consumes Putrefy charges, so the Putrefy
  -- warning has to stand on its own charge economy: bank the last charge for
  -- Dark Transformation, but never hold 2+ charges into the recharge cap.
  -- Unreadable charges keep the pre-12.1 behaviour rather than going silent.
  local function ShouldWarnPutrefy()
    local charges = getPutrefyCharges()
    if type(charges) ~= "number" then
      return true
    end
    return charges <= PUTREFY_BANK_CHARGE_LIMIT
  end

  local function GetEnabledScanners()
    local db = getDB() or {}
    local scanners = {}
    if db.vipDkSoulReaperWarningEnabled == true then
      scanners[#scanners + 1] = scanSoulReaperButtons
    end
    if db.vipDkPutrefyWarningEnabled == true and ShouldWarnPutrefy() then
      scanners[#scanners + 1] = scanPutrefyButtons
    end
    return scanners
  end

  -- Anchor the window to the live cooldown so it always covers the last
  -- WARNING_DURATION_SECONDS before Dark Transformation is actually ready.
  local function ResolveWarningDelay()
    local remaining = getDarkTransformationCooldownRemaining()
    if
      type(remaining) ~= "number"
      or remaining < MIN_TRUSTED_COOLDOWN_SECONDS
      or remaining > MAX_TRUSTED_COOLDOWN_SECONDS
    then
      return FALLBACK_WARNING_DELAY_SECONDS
    end
    local delay = remaining - WARNING_DURATION_SECONDS
    if delay < 0 then
      return 0
    end
    return delay
  end

  local function HideWarning()
    warningActive = false
    for _, overlay in ipairs(overlays) do
      if type(overlay.Hide) == "function" then
        overlay:Hide()
      end
    end
  end

  local function RebuildOverlays()
    HideWarning()
    overlays = {}
    for _, scanner in ipairs(GetEnabledScanners()) do
      local buttons = scanner() or {}
      for _, button in ipairs(buttons) do
        local overlay = createOverlay(button)
        if overlay then
          overlays[#overlays + 1] = overlay
        end
      end
    end
  end

  local function ShowWarning()
    hideTimer = nil
    if not IsEnabled() then
      HideWarning()
      return
    end

    RebuildOverlays()
    warningActive = #overlays > 0
    for _, overlay in ipairs(overlays) do
      if type(overlay.Show) == "function" then
        overlay:Show()
      end
    end

    hideTimer = timerAfter(WARNING_DURATION_SECONDS, function()
      hideTimer = nil
      HideWarning()
    end)
  end

  function controller.HandleUnitSpellcastSucceeded(unit, _, spellID)
    if unit ~= "player" then
      return
    end
    if tonumber(spellID) ~= DARK_TRANSFORMATION_SPELL_ID then
      return
    end

    CancelTimer(warningTimer)
    CancelTimer(hideTimer)
    warningTimer = nil
    hideTimer = nil
    HideWarning()

    if not IsEnabled() then
      return
    end

    warningTimer = timerAfter(ResolveWarningDelay(), function()
      warningTimer = nil
      ShowWarning()
    end)
  end

  function controller.Refresh()
    if warningActive then
      HideWarning()
      ShowWarning()
    end
    controller.ApplyGhoulReminder()
  end

  function controller.Stop()
    CancelTimer(warningTimer)
    CancelTimer(hideTimer)
    warningTimer = nil
    hideTimer = nil
    HideWarning()
  end

  function controller.HandlePlayerRegenEnabled()
    CancelTimer(hideTimer)
    hideTimer = nil
    HideWarning()
    controller.ApplyPendingGhoulReminder()
  end

  function controller.IsWarningActive()
    return warningActive
  end

  -- Simulator entry point: skips only the cooldown wait, never the guards. The
  -- class/spec check, the button resolution and the Putrefy charge guard all
  -- still run, so the preview shows what a real Dark Transformation would.
  -- Returns whether the warning actually became visible.
  function controller.ShowWarningPreview()
    CancelTimer(warningTimer)
    CancelTimer(hideTimer)
    warningTimer = nil
    hideTimer = nil
    ShowWarning()
    return warningActive
  end

  function controller.DisableGhoulReminder()
    if isInCombat() then
      pendingGhoulReminderApply = true
      return
    end
    if ghoulReminderFrame and ghoulReminderDriverActive and type(unregisterStateDriver) == "function" then
      unregisterStateDriver(ghoulReminderFrame, "visibility")
    end
    ghoulReminderDriverActive = false
    if ghoulReminderFrame and type(ghoulReminderFrame.Hide) == "function" then
      ghoulReminderFrame:Hide()
    end
  end

  function controller.ApplyGhoulReminder()
    if isInCombat() then
      pendingGhoulReminderApply = true
      return
    end
    pendingGhoulReminderApply = false
    if not IsGhoulReminderEnabled() then
      controller.DisableGhoulReminder()
      return
    end
    if not ghoulReminderFrame then
      ghoulReminderFrame = createGhoulReminderFrame(rawget(_G, "UIParent"), getDB, getL)
    end
    if not ghoulReminderFrame then
      return
    end
    if ghoulReminderFrame.text and type(ghoulReminderFrame.text.SetText) == "function" then
      ghoulReminderFrame.text:SetText((getL() or {}).VIP_DK_GHOUL_REMINDER_TEXT or "SUMMON GHOUL")
    end
    if type(registerStateDriver) == "function" then
      registerStateDriver(ghoulReminderFrame, "visibility", GHOUL_REMINDER_STATE_DRIVER)
      ghoulReminderDriverActive = true
    elseif type(ghoulReminderFrame.Show) == "function" then
      ghoulReminderFrame:Show()
    end
  end

  function controller.GetGhoulReminderFrame()
    return ghoulReminderFrame
  end

  function controller.ApplyPendingGhoulReminder()
    if pendingGhoulReminderApply and not isInCombat() then
      controller.ApplyGhoulReminder()
    end
  end

  return controller
end

local controllerInstance = nil

function VipDkAssist.SetDependencies(deps)
  if type(deps) ~= "table" then
    return
  end
  controllerInstance = VipDkAssist.CreateController(deps)
  controllerInstance.ApplyGhoulReminder()
end

-- Used by the demo simulation tablet. Returns false when the controller is not
-- wired or the guards suppressed the preview.
function VipDkAssist.ShowWarningPreview()
  if not controllerInstance or type(controllerInstance.ShowWarningPreview) ~= "function" then
    return false
  end
  return controllerInstance.ShowWarningPreview() == true
end

function VipDkAssist.HandleEvent(event, ...)
  if not controllerInstance then
    return
  end
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    controllerInstance.HandleUnitSpellcastSucceeded(...)
  elseif event == "PLAYER_REGEN_ENABLED" then
    controllerInstance.HandlePlayerRegenEnabled()
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    controllerInstance.Stop()
    controllerInstance.ApplyGhoulReminder()
  elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "UNIT_PET" then
    controllerInstance.ApplyGhoulReminder()
  end
end
