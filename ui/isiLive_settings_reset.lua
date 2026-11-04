local _, addonTable = ...
addonTable = addonTable or {}

local SettingsReset = {}
addonTable.SettingsReset = SettingsReset

local Colors = addonTable.UICommon and addonTable.UICommon.Colors or {}
local ApplyBackdrop = addonTable.UICommon and addonTable.UICommon.ApplyBackdrop

local RESET_CONFIRM_POPUP_PREFIX = "ISILIVE_CONFIRM_RESET_ACTION_"
local pendingResetConfirmActions = {}
local YES_TEXT = rawget(_G, "YES") or "Yes"
local NO_TEXT = rawget(_G, "NO") or "No"

-- Blizzard reuses the StaticPopupN frames for unrelated dialogs, so everything
-- StyleResetConfirmPopup changes is snapshotted first and put back when our
-- popup hides (RestoreResetConfirmPopup).
local function SafeGet(obj, method)
  if type(obj) ~= "table" or type(obj[method]) ~= "function" then
    return nil
  end
  local ok, a, b, c, d = pcall(obj[method], obj)
  if ok then
    return a, b, c, d
  end
  return nil
end

local function SnapshotResetConfirmPopup(dialog)
  if dialog._isiLiveOrig then
    return
  end
  local orig = {
    movable = SafeGet(dialog, "IsMovable"),
    resizable = SafeGet(dialog, "IsResizable"),
    backdrop = SafeGet(dialog, "GetBackdrop"),
    buttons = {},
  }
  if dialog.text then
    local r, g, b, a = SafeGet(dialog.text, "GetTextColor")
    orig.textColor = r and { r, g, b, a } or nil
  end
  for index, button in ipairs({ dialog.button1, dialog.button2 }) do
    local w, h = SafeGet(button, "GetSize")
    orig.buttons[index] = { width = w, height = h }
  end
  dialog._isiLiveOrig = orig
end

local function RestoreResetConfirmPopup(dialog)
  if type(dialog) ~= "table" or not dialog._isiLiveOrig then
    return
  end
  local orig = dialog._isiLiveOrig
  dialog._isiLiveOrig = nil
  if orig.movable ~= nil and type(dialog.SetMovable) == "function" then
    dialog:SetMovable(orig.movable)
  end
  if orig.resizable ~= nil and type(dialog.SetResizable) == "function" then
    dialog:SetResizable(orig.resizable)
  end
  if type(dialog.SetBackdrop) == "function" then
    pcall(dialog.SetBackdrop, dialog, orig.backdrop)
  end
  if orig.textColor and dialog.text and type(dialog.text.SetTextColor) == "function" then
    local c = orig.textColor
    dialog.text:SetTextColor(c[1], c[2], c[3], c[4] or 1)
  end
  for index, button in ipairs({ dialog.button1, dialog.button2 }) do
    if type(button) == "table" then
      button._isiLiveStyled = false
      if button._isiLiveBackdropSet and type(button.SetBackdrop) == "function" then
        button._isiLiveBackdropSet = nil
        pcall(button.SetBackdrop, button, nil)
      end
      local size = orig.buttons[index]
      if size and size.width and size.height and type(button.SetSize) == "function" then
        button:SetSize(size.width, size.height)
      end
      if button._isiLiveHoverGlow and type(button._isiLiveHoverGlow.Hide) == "function" then
        button._isiLiveHoverGlow:Hide()
      end
    end
  end
end

local function StyleResetConfirmPopup(dialog)
  if type(dialog) ~= "table" then
    return
  end
  SnapshotResetConfirmPopup(dialog)
  if type(ApplyBackdrop) == "function" then
    ApplyBackdrop(dialog, "NOTICE")
  end
  if type(dialog.SetMovable) == "function" then
    dialog:SetMovable(false)
  end
  if type(dialog.SetResizable) == "function" then
    dialog:SetResizable(false)
  end
  if dialog.text and type(dialog.text.SetTextColor) == "function" then
    local tn = Colors.TEXT_NORMAL or { 0.85, 0.85, 0.9 }
    dialog.text:SetTextColor(tn[1], tn[2], tn[3], 1)
    if type(dialog.text.SetWordWrap) == "function" then
      dialog.text:SetWordWrap(true)
    end
  end
  local accent = Colors.ACCENT_BLUE or { 0.3, 0.65, 1 }
  local buttons = { dialog.button1, dialog.button2 }
  for index, button in ipairs(buttons) do
    if type(button) == "table" then
      if type(button.SetSize) == "function" then
        button:SetSize(96, 22)
      end
      if type(button.SetBackdrop) == "function" then
        button:SetBackdrop({
          bgFile = "Interface\\Buttons\\WHITE8X8",
          edgeFile = "Interface\\Buttons\\WHITE8X8",
          edgeSize = 1,
          insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        button._isiLiveBackdropSet = true
        button:SetBackdropColor(0.12, 0.12, 0.18, 0.95)
        button:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.45)
      elseif type(ApplyBackdrop) == "function" then
        ApplyBackdrop(button, "FLAT_BUTTON")
      end
      if button._isiLiveHoverGlow == nil and type(button.CreateTexture) == "function" then
        local glow = button:CreateTexture(nil, "BACKGROUND", nil, -1)
        if type(glow.SetAllPoints) == "function" then
          glow:SetAllPoints()
        end
        if type(glow.SetColorTexture) == "function" then
          glow:SetColorTexture(accent[1], accent[2], accent[3], 0.12)
        end
        if type(glow.Hide) == "function" then
          glow:Hide()
        end
        button._isiLiveHoverGlow = glow
      end
      local text = button.GetText and button:GetText() or (index == 1 and YES_TEXT or NO_TEXT)
      if type(button.SetText) == "function" then
        button:SetText(text)
      end
      button._isiLiveStyled = true
      if not button._isiLiveHoverHooked then
        -- HookScript keeps Blizzard's own handlers intact; the hover visuals
        -- only apply while the button carries our popup styling.
        local hook = type(button.HookScript) == "function" and button.HookScript or button.SetScript
        if type(hook) == "function" then
          button._isiLiveHoverHooked = true
          hook(button, "OnEnter", function(self)
            if not self._isiLiveStyled then
              return
            end
            if type(self.SetBackdropBorderColor) == "function" then
              self:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.85)
            end
            if self._isiLiveHoverGlow and type(self._isiLiveHoverGlow.Show) == "function" then
              self._isiLiveHoverGlow:Show()
            end
          end)
          hook(button, "OnLeave", function(self)
            if not self._isiLiveStyled then
              return
            end
            if type(self.SetBackdropBorderColor) == "function" then
              self:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.45)
            end
            if self._isiLiveHoverGlow and type(self._isiLiveHoverGlow.Hide) == "function" then
              self._isiLiveHoverGlow:Hide()
            end
          end)
        end
      end
    end
  end
end

SettingsReset.RestorePopupStyle = RestoreResetConfirmPopup

function SettingsReset.ShowResetConfirmation(dialogKey, confirmText, onAccept)
  local popupName = RESET_CONFIRM_POPUP_PREFIX .. tostring(dialogKey or "DEFAULT")
  local dialogs = rawget(_G, "StaticPopupDialogs")
  local showPopup = rawget(_G, "StaticPopup_Show")
  if type(dialogs) ~= "table" or type(showPopup) ~= "function" then
    if type(onAccept) == "function" then
      onAccept()
    end
    return
  end
  local dialog = dialogs[popupName]
  if not dialog then
    dialogs[popupName] = {
      text = confirmText or "Do you really want to reset?",
      button1 = YES_TEXT,
      button2 = NO_TEXT,
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
      OnShow = function(self)
        StyleResetConfirmPopup(self)
      end,
      OnAccept = function()
        local action = pendingResetConfirmActions[popupName]
        pendingResetConfirmActions[popupName] = nil
        if type(action) == "function" then
          action()
        end
      end,
      OnCancel = function()
        pendingResetConfirmActions[popupName] = nil
      end,
      OnHide = function(self)
        pendingResetConfirmActions[popupName] = nil
        RestoreResetConfirmPopup(self)
      end,
    }
  else
    dialog.text = confirmText or dialog.text
  end
  pendingResetConfirmActions[popupName] = onAccept
  showPopup(popupName)
end
