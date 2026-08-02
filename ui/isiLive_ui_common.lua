local _, addonTable = ...

addonTable = addonTable or {}

-- Lua 5.1 (WoW client) exposes global `unpack`; Lua 5.4 (local tooling) only
-- has `table.unpack`. Bridge locally so this file works under both without
-- depending on the entrypoint script to have set up a global compat shim.
local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local UICommon = {}
addonTable.UICommon = UICommon

UICommon.DEFAULT_BG_ALPHA = 0.50
UICommon.STRUCTURAL_TINT_ALPHA_FACTOR = 0.24
UICommon.CYRILLIC_FONT_PATH = "Fonts\\ARIALN.TTF"
UICommon.LOCALE_FONT_OVERRIDES = {
  ruRU = UICommon.CYRILLIC_FONT_PATH,
}

UICommon.Colors = {
  BG_PRIMARY = { 0.08, 0.08, 0.12, UICommon.DEFAULT_BG_ALPHA },
  BG_SECONDARY = { 0.12, 0.12, 0.18, 0.7 },
  BORDER_DEFAULT = { 0.35, 0.35, 0.50, 0.65 },
  ACCENT_GOLD = { 1, 0.82, 0 },
  ACCENT_BLUE = { 0.3, 0.65, 1 },
  TEXT_NORMAL = { 0.85, 0.85, 0.9 },
  TEXT_DIM = { 0.5, 0.5, 0.6 },
  HOVER_HIGHLIGHT = { 1, 1, 1, 0.10 },
  ROW_ALT = { 1, 1, 1, 0.03 },

  -- Extracted 2026-07-22 from ui/*.lua literal SetTextColor/SetVertexColor/
  -- SetColorTexture call sites (UI modernization pass). Each entry preserves
  -- the exact original arity (3 = RGB, alpha left untouched by the widget
  -- API; 4 = RGBA) so migrating a call site to `unpack(...)` is behavior-
  -- neutral. Values are extracted verbatim, not semantically merged with
  -- near-identical tones — unifying visually-similar colors is a separate,
  -- deliberate design decision this pass deliberately did not make.
  WHITE_OPAQUE = { 1, 1, 1, 1 },
  WHITE_RGB = { 1, 1, 1 },
  GOLD_TITLE = { 1, 0.85, 0 },
  GOLD_TITLE_OPAQUE = { 1, 0.85, 0, 1 },
  GOLD_LABEL_ALT = { 1, 0.82, 0.18 },
  GOLD_MAINFRAME_LABEL = { 1, 0.85, 0.2, 1 },
  GOLD_TARGET_TEXT = { 1.0, 0.84, 0.35 },
  MUTED_GOLD_PCT_TEXT = { 0.9, 0.82, 0.45 },
  LIGHT_GOLD_LABEL = { 1, 0.92, 0.45, 1 },
  AMBER_BETA_LABEL = { 1, 0.83, 0.35, 0.95 },
  AMBER_SUPPORT_NOTICE = { 1, 0.75, 0.2, 1 },
  ORANGE_RAID_NOTICE = { 1, 0.5, 0 },
  ORANGE_WARNING_LABEL = { 1, 0.55, 0.2, 1 },
  WARM_WHITE_TEXT = { 1, 0.92, 0.7 },
  BLUE_VERSION_TEXT = { 0.55, 0.75, 1.0 },
  LIGHT_BLUE_PULL_TEXT = { 0.6, 0.85, 1.0 },
  LIGHT_BLUE_LEVEL_TEXT = { 0.65, 0.85, 1.0 },
  LIGHT_BLUE_MAINFRAME_LABEL = { 0.75, 0.9, 1, 1 },
  PALE_BLUE_SUBTITLE = { 0.88, 0.92, 1, 1 },
  CYAN_EYEBROW = { 0.46, 0.94, 1 },
  CYAN_DIRECTION = { 0.38, 0.92, 1 },
  CYAN_GUIDE_LINE = { 0.2, 0.8, 1, 0.28 },
  BLUE_SEPARATOR = { 0.36, 0.71, 1, 0.55 },
  BLUE_ICON_CORE = { 0.1, 0.45, 1, 0.92 },
  BLUE_ACTION_BG = { 0.04, 0.18, 0.32, 0.62 },
  BLUE_HOVER_GLOW = { 0.3, 0.65, 1, 0.2 },
  BLUE_ROW_HIGHLIGHT = { 0.3, 0.65, 1, 0.08 },
  BLUE_PULL_BAR = { 0.4, 0.7, 1.0, 0.7 },
  STEEL_BLUE_OVERLAY = { 0.15, 0.35, 0.55, 0.25 },
  DEEP_BLUE_ICON_BG = { 0.05, 0.2, 0.34, 0.65 },
  DARK_SLATE_ICON_BG = { 0.13, 0.15, 0.18, 0.55 },
  SLATE_DETAIL_TEXT = { 0.62, 0.68, 0.76 },
  GREEN_HINT_TEXT = { 0.45, 0.85, 0.45 },
  SUCCESS_GREEN_BAR = { 0.2, 0.75, 0.35 },
  GRAY_INACTIVE = { 0.5, 0.5, 0.5 },
  GRAY_SUBLINE = { 0.7, 0.7, 0.7 },
  GRAY_MUTED_PCT = { 0.4, 0.4, 0.5 },
  LIGHT_GRAY_ARROW = { 0.8, 0.8, 0.8 },
  DARK_GRAY_BAR_BG = { 0.12, 0.12, 0.12 },
  NEAR_BLACK_BACKDROP = { 0.02, 0.02, 0.02, 0.5 },
  RED_DANGER_OVERLAY = { 0.4, 0.05, 0.05, 0.55 },
  TRANSPARENT = { 0, 0, 0, 0 },
  BLACK_OVERLAY_28 = { 0, 0, 0, 0.28 },
  BLACK_OVERLAY_35 = { 0, 0, 0, 0.35 },
  BLACK_OVERLAY_50 = { 0, 0, 0, 0.5 },
  BLACK_OVERLAY_60 = { 0, 0, 0, 0.6 },
  BLACK_OVERLAY_62 = { 0, 0, 0, 0.62 },
  TOOLTIP_BG_BLACK = { 0, 0, 0, 0.92 },
  BG_NOTICE_CARD = { 0.05, 0.05, 0.08, 0.75 },
  BG_NOTICE_CARD_BASE = { 0.05, 0.05, 0.08 },
  GOLD_SEPARATOR_BASE = { 1, 0.9, 0.45 },

  -- Deliberate semantic design tokens. Unlike the compatibility colors above,
  -- these values define the shared modern isiLive visual language and may be
  -- consumed by new reusable components across UI surfaces.
  SURFACE_MAIN_FRAME = { 0.035, 0.045, 0.065 },
  SURFACE_TITLE_BAR = { 0.025, 0.055, 0.085, 0.82 },
  SURFACE_ACTION_PRIMARY = { 0.035, 0.16, 0.27, 0.92 },
  SURFACE_ACTION_PRIMARY_HOVER = { 0.055, 0.24, 0.39, 0.96 },
  SURFACE_ACTION_PRIMARY_PRESSED = { 0.025, 0.11, 0.19, 0.98 },
  SURFACE_ACTION_SECONDARY = { 0.065, 0.075, 0.11, 0.88 },
  SURFACE_ACTION_SECONDARY_HOVER = { 0.10, 0.13, 0.19, 0.94 },
  SURFACE_ACTION_SECONDARY_PRESSED = { 0.04, 0.05, 0.08, 0.98 },
  BORDER_ACTION_PRIMARY = { 0.28, 0.68, 1, 0.72 },
  BORDER_ACTION_SECONDARY = { 0.32, 0.40, 0.52, 0.62 },
  BORDER_TITLE_BAR = { 0.26, 0.62, 0.92, 0.38 },
  TEXT_HEADING = { 0.93, 0.96, 1 },
  TEXT_SECTION = { 0.64, 0.80, 0.96 },
  TEXT_SUPPORTING = { 0.58, 0.65, 0.74 },
  SURFACE_RUN_ZONE = { 0.035, 0.055, 0.085, 0.86 },
  BORDER_RUN_ZONE = { 0.22, 0.48, 0.72, 0.54 },
  SURFACE_NOTICE = { 0.035, 0.05, 0.075, 0.90 },
  BORDER_NOTICE = { 0.24, 0.55, 0.82, 0.58 },
  ACCENT_NOTICE_TOP = { 0.24, 0.72, 1, 0.72 },
  SURFACE_COMPACT_OVERLAY = { 0.025, 0.04, 0.06, 0.78 },
  TEXT_ALERT_DANGER = { 1, 0.14, 0.16 },

  -- Restrained danger states for the shared close control. Only hover and
  -- press expose red; the default state uses the quiet secondary surface.
  SURFACE_CLOSE_DANGER_HOVER = { 0.22, 0.045, 0.06, 0.96 },
  BORDER_CLOSE_DANGER_HOVER = { 1, 0.32, 0.36, 0.86 },
  SURFACE_CLOSE_DANGER_PRESSED = { 0.12, 0.02, 0.03, 0.98 },
  BORDER_CLOSE_DANGER_PRESSED = { 0.92, 0.22, 0.28, 0.92 },
  TEXT_CLOSE_DANGER_PRESSED = { 1, 0.62, 0.66, 1 },
}

UICommon.Theme = {
  spacing = {
    xs = 4,
    sm = 8,
    md = 12,
    lg = 16,
  },
  typography = {
    title = "GameFontNormalLarge",
    body = "GameFontNormalSmall",
    data = "GameFontHighlightSmall",
  },
  color = {
    surface = {
      main = UICommon.Colors.SURFACE_MAIN_FRAME,
      title = UICommon.Colors.SURFACE_TITLE_BAR,
      raised = UICommon.Colors.BG_SECONDARY,
      run = UICommon.Colors.SURFACE_RUN_ZONE,
      notice = UICommon.Colors.SURFACE_NOTICE,
    },
    text = {
      primary = UICommon.Colors.TEXT_HEADING,
      secondary = UICommon.Colors.TEXT_SECTION,
      supporting = UICommon.Colors.TEXT_SUPPORTING,
    },
    accent = UICommon.Colors.ACCENT_BLUE,
  },
}

function UICommon.GetLocalizedText(key, fallback)
  if type(key) ~= "string" or key == "" then
    return fallback or ""
  end

  local textTables = addonTable.Texts
      and type(addonTable.Texts.GetLocaleTables) == "function"
      and addonTable.Texts.GetLocaleTables()
    or nil
  local getLocale = rawget(_G, "GetLocale")
  local localeKey = type(getLocale) == "function" and getLocale() or "enUS"
  local labels = type(textTables) == "table" and (textTables[localeKey] or textTables.enUS) or nil
  if type(labels) == "table" then
    local value = labels[key]
    if type(value) == "string" and value ~= "" then
      return value
    end
  end

  return fallback or ""
end

local function ResolveActiveLocale(localeTag)
  if type(localeTag) == "string" and localeTag ~= "" then
    return localeTag
  end

  local db = rawget(_G, "IsiLiveDB")
  if type(db) == "table" and type(db.locale) == "string" and db.locale ~= "" then
    return db.locale
  end

  local getLocale = rawget(_G, "GetLocale")
  if type(getLocale) == "function" then
    local ok, locale = pcall(getLocale)
    if ok and type(locale) == "string" and locale ~= "" then
      return locale
    end
  end

  return "enUS"
end

-- Shared addon-locale resolution: explicit tag, then the stored addon locale,
-- then the client locale, and finally enUS. Exported so UI modules consume the
-- one chain instead of re-implementing it; internal callers keep the local
-- upvalue.
UICommon.ResolveActiveLocale = ResolveActiveLocale

function UICommon.GetLocaleFontPath(localeTag)
  return UICommon.LOCALE_FONT_OVERRIDES[ResolveActiveLocale(localeTag)]
end

local function ApplyFontPath(fontString, fontPath)
  if
    type(fontString) ~= "table"
    or type(fontString.GetFont) ~= "function"
    or type(fontString.SetFont) ~= "function"
  then
    return false
  end

  if type(fontPath) ~= "string" or fontPath == "" then
    return false
  end

  local _, fontSize, fontFlags = fontString:GetFont()
  if type(fontSize) ~= "number" then
    return false
  end

  fontString:SetFont(fontPath, fontSize, fontFlags)
  return true
end

local function CaptureReadableFontBaseline(fontString)
  if
    type(fontString) ~= "table"
    or type(fontString.GetFont) ~= "function"
    or type(fontString.SetFont) ~= "function"
  then
    return nil
  end

  if type(fontString._isiLiveReadableFontBaseline) == "table" then
    return fontString._isiLiveReadableFontBaseline
  end

  local fontPath, fontSize, fontFlags = fontString:GetFont()
  if type(fontPath) ~= "string" or type(fontSize) ~= "number" then
    return nil
  end

  fontString._isiLiveReadableFontBaseline = {
    path = fontPath,
    size = fontSize,
    flags = fontFlags,
  }
  return fontString._isiLiveReadableFontBaseline
end

function UICommon.ApplyLocaleFont(fontString, localeTag)
  return ApplyFontPath(fontString, UICommon.GetLocaleFontPath(localeTag))
end

function UICommon.TextNeedsCyrillicFont(text)
  if type(text) ~= "string" or text == "" then
    return false
  end

  return text:find("[\208-\211][\128-\191]") ~= nil
end

function UICommon.ApplyReadableFontForText(fontString, text, localeTag)
  local baseline = CaptureReadableFontBaseline(fontString)
  if UICommon.TextNeedsCyrillicFont(text) then
    return ApplyFontPath(fontString, UICommon.CYRILLIC_FONT_PATH)
  end

  if UICommon.ApplyLocaleFont(fontString, localeTag) then
    return true
  end

  if baseline then
    return ApplyFontPath(fontString, baseline.path)
  end

  return false
end

function UICommon.SetReadableText(fontString, text, localeTag)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return false
  end

  local value = tostring(text or "")
  UICommon.ApplyReadableFontForText(fontString, value, localeTag)
  fontString:SetText(value)
  return true
end

function UICommon.IsSecretValue(value)
  local isSecretValue = rawget(_G, "issecretvalue")
  if type(isSecretValue) ~= "function" then
    return false
  end

  local ok, result = pcall(isSecretValue, value)
  return ok and result == true
end

function UICommon.MeasureFontStringWidthSafe(fontString)
  if type(fontString) ~= "table" or type(fontString.GetStringWidth) ~= "function" then
    return nil
  end

  local ok, width = pcall(fontString.GetStringWidth, fontString)
  if not ok or UICommon.IsSecretValue(width) or width == nil then
    return nil
  end

  local numberOk, numericWidth = pcall(tonumber, width)
  if not numberOk or UICommon.IsSecretValue(numericWidth) or numericWidth == nil then
    return nil
  end

  local positiveOk, isPositive = pcall(function()
    return numericWidth > 0
  end)
  if not positiveOk or not isPositive then
    return nil
  end

  local ceilOk, ceiledWidth = pcall(math.ceil, numericWidth)
  if ceilOk and type(ceiledWidth) == "number" then
    return ceiledWidth
  end
  return nil
end

function UICommon.GetBackgroundAlpha()
  local db = rawget(_G, "IsiLiveDB")
  if type(db) == "table" and type(db.bgAlpha) == "number" then
    return db.bgAlpha
  end
  return UICommon.DEFAULT_BG_ALPHA
end

local backgroundAlphaSurfaces = setmetatable({}, { __mode = "k" })

local function PaintBackgroundAlphaSurface(target, surface, alpha)
  local method = type(target) == "table" and target[surface.methodName] or nil
  local color = surface.color
  if type(method) ~= "function" or type(color) ~= "table" then
    return
  end

  method(target, color[1], color[2], color[3], alpha * surface.alphaFactor)
end

function UICommon.RegisterBackgroundAlphaSurface(target, methodName, color, alphaFactor)
  if
    type(target) ~= "table"
    or type(target[methodName]) ~= "function"
    or type(color) ~= "table"
    or type(alphaFactor) ~= "number"
  then
    return false
  end

  local surface = {
    methodName = methodName,
    color = color,
    alphaFactor = alphaFactor,
  }
  backgroundAlphaSurfaces[target] = surface
  PaintBackgroundAlphaSurface(target, surface, UICommon.GetBackgroundAlpha())
  return true
end

-- Apply the configured background alpha to the BG_PRIMARY palette and to the
-- main / panel / settings frames in one place. Used by the ADDON_LOADED
-- restore path as well as the live settings slider and the reset-defaults
-- action — keeping the palette mutation and the frame paints in sync.
function UICommon.ApplyBgAlpha(frames, alpha)
  if type(alpha) ~= "number" then
    return
  end

  if type(UICommon.Colors) == "table" and type(UICommon.Colors.BG_PRIMARY) == "table" then
    UICommon.Colors.BG_PRIMARY[4] = alpha
  end

  frames = type(frames) == "table" and frames or {}

  local mainFrame = frames.mainFrame
  if mainFrame and type(mainFrame.SetBackdropColor) == "function" then
    local surface = UICommon.Colors.SURFACE_MAIN_FRAME
    mainFrame:SetBackdropColor(surface[1], surface[2], surface[3], alpha)
  end

  local bg = UICommon.Colors and UICommon.Colors.BG_PRIMARY or { 0.08, 0.08, 0.12, alpha }

  local panelFrame = frames.panelFrame
  if panelFrame and type(panelFrame.SetBackdropColor) == "function" then
    panelFrame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
  end

  local settingsCanvas = frames.settingsCanvas
  if settingsCanvas and type(settingsCanvas.SetBackdropColor) == "function" then
    settingsCanvas:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
  end

  for target, surface in pairs(backgroundAlphaSurfaces) do
    PaintBackgroundAlphaSurface(target, surface, alpha)
  end
end

local BACKDROP_PANEL = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  edgeSize = 1,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local BACKDROP_FLAT_BUTTON = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  edgeSize = 1,
  insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local BACKDROP_BG_ONLY = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
}

UICommon.BACKDROP_PRESETS = {
  PRIMARY = {
    backdrop = BACKDROP_PANEL,
    bgColor = function()
      local bg = UICommon.Colors.BG_PRIMARY
      return bg[1], bg[2], bg[3], UICommon.GetBackgroundAlpha()
    end,
    borderColor = UICommon.Colors.BORDER_DEFAULT,
  },
  MAIN_FRAME = {
    backdrop = BACKDROP_PANEL,
    bgColor = function()
      local surface = UICommon.Colors.SURFACE_MAIN_FRAME
      return surface[1], surface[2], surface[3], UICommon.GetBackgroundAlpha()
    end,
    borderColor = UICommon.Colors.BORDER_TITLE_BAR,
  },
  NOTICE = {
    backdrop = BACKDROP_PANEL,
    bgColor = UICommon.Colors.SURFACE_NOTICE,
    borderColor = UICommon.Colors.BORDER_NOTICE,
  },
  TOOLTIP = {
    backdrop = BACKDROP_PANEL,
    bgColor = UICommon.Colors.SURFACE_NOTICE,
    borderColor = UICommon.Colors.BORDER_NOTICE,
  },
  CLOSE_BUTTON = {
    backdrop = BACKDROP_PANEL,
    bgColor = UICommon.Colors.SURFACE_ACTION_SECONDARY,
    borderColor = UICommon.Colors.BORDER_ACTION_SECONDARY,
  },
  FLAT_BUTTON = {
    backdrop = BACKDROP_FLAT_BUTTON,
    bgColor = UICommon.Colors.BG_SECONDARY,
    borderColor = UICommon.Colors.BORDER_DEFAULT,
  },
  TITLE_BUTTON = {
    backdrop = BACKDROP_FLAT_BUTTON,
    bgColor = UICommon.Colors.SURFACE_ACTION_SECONDARY,
    borderColor = UICommon.Colors.BORDER_ACTION_SECONDARY,
  },
  BUTTON_BG = {
    backdrop = BACKDROP_BG_ONLY,
    bgColor = UICommon.Colors.BG_SECONDARY,
  },
  CD_BOX = {
    backdrop = BACKDROP_FLAT_BUTTON,
    bgColor = UICommon.Colors.SURFACE_RUN_ZONE,
    backgroundAlphaFactor = UICommon.STRUCTURAL_TINT_ALPHA_FACTOR,
    borderColor = UICommon.Colors.BORDER_RUN_ZONE,
  },
  MPLUS_BOX = {
    backdrop = BACKDROP_FLAT_BUTTON,
    bgColor = UICommon.Colors.SURFACE_RUN_ZONE,
    backgroundAlphaFactor = UICommon.STRUCTURAL_TINT_ALPHA_FACTOR,
    borderColor = UICommon.Colors.BORDER_RUN_ZONE,
  },
}

function UICommon.ApplyBackdrop(frame, presetName)
  if type(frame) ~= "table" or type(frame.SetBackdrop) ~= "function" then
    return false
  end
  local preset = UICommon.BACKDROP_PRESETS[presetName]
  if not preset then
    return false
  end
  frame:SetBackdrop(preset.backdrop)
  if preset.bgColor and preset.backgroundAlphaFactor then
    UICommon.RegisterBackgroundAlphaSurface(frame, "SetBackdropColor", preset.bgColor, preset.backgroundAlphaFactor)
  elseif preset.bgColor and type(frame.SetBackdropColor) == "function" then
    if type(preset.bgColor) == "function" then
      frame:SetBackdropColor(preset.bgColor())
    else
      local c = preset.bgColor
      frame:SetBackdropColor(c[1], c[2], c[3], c[4])
    end
  end
  if preset.borderColor and type(frame.SetBackdropBorderColor) == "function" then
    local bc = preset.borderColor
    frame:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4])
  end
  return true
end

local ACTION_BUTTON_STYLE_BY_ROLE = {
  primary = {
    defaultBg = UICommon.Colors.SURFACE_ACTION_PRIMARY,
    hoverBg = UICommon.Colors.SURFACE_ACTION_PRIMARY_HOVER,
    pressedBg = UICommon.Colors.SURFACE_ACTION_PRIMARY_PRESSED,
    border = UICommon.Colors.BORDER_ACTION_PRIMARY,
    text = UICommon.Colors.TEXT_HEADING,
  },
  secondary = {
    defaultBg = UICommon.Colors.SURFACE_ACTION_SECONDARY,
    hoverBg = UICommon.Colors.SURFACE_ACTION_SECONDARY_HOVER,
    pressedBg = UICommon.Colors.SURFACE_ACTION_SECONDARY_PRESSED,
    border = UICommon.Colors.BORDER_ACTION_SECONDARY,
    text = UICommon.Colors.TEXT_NORMAL,
  },
  title = {
    defaultBg = UICommon.Colors.SURFACE_ACTION_SECONDARY,
    hoverBg = UICommon.Colors.SURFACE_ACTION_SECONDARY_HOVER,
    pressedBg = UICommon.Colors.SURFACE_ACTION_SECONDARY_PRESSED,
    border = UICommon.Colors.BORDER_TITLE_BAR,
    text = UICommon.Colors.TEXT_SECTION,
  },
}

local function ApplyColorTuple(target, methodName, color)
  local method = type(target) == "table" and target[methodName] or nil
  if type(method) ~= "function" or type(color) ~= "table" then
    return
  end
  method(target, color[1], color[2], color[3], color[4] or 1)
end

function UICommon.ApplyActionButtonVisual(button, role, state)
  if type(button) ~= "table" then
    return false
  end
  local resolvedRole = ACTION_BUTTON_STYLE_BY_ROLE[role] and role or "secondary"
  local style = ACTION_BUTTON_STYLE_BY_ROLE[resolvedRole]
  local resolvedState = state == "hover" and "hover" or (state == "pressed" and "pressed" or "default")
  local background = resolvedState == "hover" and style.hoverBg
    or (resolvedState == "pressed" and style.pressedBg or style.defaultBg)

  ApplyColorTuple(button, "SetBackdropColor", background)
  ApplyColorTuple(button, "SetBackdropBorderColor", style.border)
  ApplyColorTuple(button._flatLabel, "SetTextColor", style.text)
  button._isiLiveSemanticRole = resolvedRole
  button._isiLiveVisualState = resolvedState
  return true
end

function UICommon.CreateActionButton(parent, opts)
  opts = opts or {}
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return nil
  end

  local button = createFrame("Button", opts.name, parent, opts.template or "BackdropTemplate")
  button:SetSize(tonumber(opts.width) or 120, tonumber(opts.height) or 24)
  UICommon.ApplyBackdrop(button, "FLAT_BUTTON")
  if type(button.EnableMouse) == "function" then
    button:EnableMouse(true)
  end
  if type(button.RegisterForClicks) == "function" then
    button:RegisterForClicks("LeftButtonUp")
  end

  if type(button.CreateFontString) == "function" then
    local label = button:CreateFontString(nil, "OVERLAY", opts.fontObject or UICommon.Theme.typography.body)
    if type(label.SetPoint) == "function" then
      label:SetPoint("CENTER", button, "CENTER", 0, 0)
    end
    button._flatLabel = label
  end

  local role = ACTION_BUTTON_STYLE_BY_ROLE[opts.role] and opts.role or "secondary"
  function button:SetSemanticRole(nextRole)
    role = ACTION_BUTTON_STYLE_BY_ROLE[nextRole] and nextRole or "secondary"
    UICommon.ApplyActionButtonVisual(self, role, "default")
  end

  if type(button.HookScript) == "function" then
    button:HookScript("OnEnter", function(self)
      UICommon.ApplyActionButtonVisual(self, role, "hover")
    end)
    button:HookScript("OnLeave", function(self)
      UICommon.ApplyActionButtonVisual(self, role, "default")
    end)
    button:HookScript("OnMouseDown", function(self)
      UICommon.ApplyActionButtonVisual(self, role, "pressed")
    end)
    button:HookScript("OnMouseUp", function(self)
      local isMouseOver = type(self.IsMouseOver) == "function" and self:IsMouseOver()
      UICommon.ApplyActionButtonVisual(self, role, isMouseOver and "hover" or "default")
    end)
  end

  UICommon.ApplyActionButtonVisual(button, role, "default")
  return button
end

function UICommon.CreatePanelChrome(parent, opts)
  opts = opts or {}
  if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then
    return nil
  end

  local height = tonumber(opts.height) or 27
  local titleBar = parent:CreateTexture(nil, "BACKGROUND")
  titleBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
  titleBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
  titleBar:SetHeight(height)
  UICommon.RegisterBackgroundAlphaSurface(
    titleBar,
    "SetColorTexture",
    UICommon.Colors.SURFACE_TITLE_BAR,
    UICommon.STRUCTURAL_TINT_ALPHA_FACTOR
  )

  local separator = parent:CreateTexture(nil, "ARTWORK")
  separator:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -(height + 1))
  separator:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -(height + 1))
  separator:SetHeight(1)
  ApplyColorTuple(separator, "SetColorTexture", UICommon.Colors.BORDER_TITLE_BAR)

  return {
    titleBar = titleBar,
    separator = separator,
    height = height,
  }
end

function UICommon.CreateNoticeChrome(parent)
  if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then
    return nil
  end

  local accent = parent:CreateTexture(nil, "ARTWORK")
  accent:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
  accent:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
  accent:SetHeight(2)
  ApplyColorTuple(accent, "SetColorTexture", UICommon.Colors.ACCENT_NOTICE_TOP)
  parent._isiLiveSurfaceRole = "notice"
  return accent
end

local TOOLTIP_HORIZONTAL_PADDING = 10
local TOOLTIP_VERTICAL_PADDING = 10
local TOOLTIP_LINE_SPACING = 3
local TOOLTIP_MIN_HEIGHT = 28
local TOOLTIP_WIDTH = 200
local TOOLTIP_TEXT_WIDTH = TOOLTIP_WIDTH - (TOOLTIP_HORIZONTAL_PADDING * 2)

local function AcquireTooltipLine(tooltip, index)
  if type(tooltip) ~= "table" or type(index) ~= "number" or index < 1 then
    return nil
  end

  tooltip._isiLiveTooltipLines = tooltip._isiLiveTooltipLines or {}
  local line = tooltip._isiLiveTooltipLines[index]
  if line or type(tooltip.CreateFontString) ~= "function" then
    return line
  end

  line = tooltip:CreateFontString(nil, "OVERLAY", index == 1 and "GameTooltipHeaderText" or "GameTooltipText")
  if type(line.SetWidth) == "function" then
    line:SetWidth(TOOLTIP_TEXT_WIDTH)
  end
  if type(line.SetJustifyH) == "function" then
    line:SetJustifyH("LEFT")
  end
  if type(line.SetWordWrap) == "function" then
    line:SetWordWrap(true)
  end
  if type(line.SetNonSpaceWrap) == "function" then
    line:SetNonSpaceWrap(true)
  end
  if type(line.SetMaxLines) == "function" then
    line:SetMaxLines(0)
  end
  tooltip._isiLiveTooltipLines[index] = line
  return line
end

local function LayoutTooltipLines(tooltip)
  if type(tooltip) ~= "table" then
    return
  end

  local lines = tooltip._isiLiveTooltipLines or {}
  local lineCount = tonumber(tooltip._isiLiveTooltipLineCount) or 0
  local tooltipHeight = TOOLTIP_VERTICAL_PADDING
  local previousLine = nil
  for index, line in ipairs(lines) do
    local isActiveLine = index <= lineCount
    if type(line) == "table" and type(line.SetPoint) == "function" then
      if type(line.ClearAllPoints) == "function" then
        line:ClearAllPoints()
      end
      if previousLine == nil then
        line:SetPoint("TOPLEFT", tooltip, "TOPLEFT", TOOLTIP_HORIZONTAL_PADDING, -TOOLTIP_VERTICAL_PADDING)
      else
        line:SetPoint("TOPLEFT", previousLine, "BOTTOMLEFT", 0, -TOOLTIP_LINE_SPACING)
      end
    end
    if isActiveLine then
      local lineHeight = 16
      if type(line) == "table" and type(line.GetStringHeight) == "function" then
        local ok, measuredHeight = pcall(line.GetStringHeight, line)
        local measuredHeightValue = tonumber(measuredHeight)
        if ok and measuredHeightValue and measuredHeightValue > 0 then
          lineHeight = math.max(measuredHeightValue, 14)
        end
      end
      tooltipHeight = tooltipHeight + lineHeight
      if previousLine ~= nil then
        tooltipHeight = tooltipHeight + TOOLTIP_LINE_SPACING
      end
      previousLine = line
    end
  end
  tooltipHeight = tooltipHeight + TOOLTIP_VERTICAL_PADDING

  if type(tooltip.SetSize) == "function" then
    tooltip:SetSize(TOOLTIP_WIDTH, math.max(TOOLTIP_MIN_HEIGHT, tooltipHeight))
  elseif type(tooltip.SetWidth) == "function" and type(tooltip.SetHeight) == "function" then
    tooltip:SetWidth(TOOLTIP_WIDTH)
    tooltip:SetHeight(math.max(TOOLTIP_MIN_HEIGHT, tooltipHeight))
  elseif type(tooltip.SetHeight) == "function" then
    tooltip:SetHeight(math.max(TOOLTIP_MIN_HEIGHT, tooltipHeight))
  end
end

local function PositionPrivateTooltip(tooltip)
  if type(tooltip) ~= "table" then
    return
  end

  if type(tooltip.ClearAllPoints) == "function" then
    tooltip:ClearAllPoints()
  end

  local owner = tooltip._isiLiveTooltipOwner
  local anchor = tooltip._isiLiveTooltipAnchor or "ANCHOR_CURSOR"
  if type(tooltip.SetPoint) ~= "function" then
    return
  end

  if anchor == "ANCHOR_TOP" and owner then
    tooltip:SetPoint("BOTTOM", owner, "TOP", 0, 8)
    return
  end

  if anchor == "ANCHOR_CURSOR" and type(rawget(_G, "GetCursorPosition")) == "function" then
    local tooltipParent = rawget(_G, "UIParent") or owner
    local x, y = rawget(_G, "GetCursorPosition")()
    local scale = 1
    if type(tooltipParent) == "table" and type(tooltipParent.GetEffectiveScale) == "function" then
      local ok, tooltipScale = pcall(tooltipParent.GetEffectiveScale, tooltipParent)
      local tooltipScaleValue = tonumber(tooltipScale)
      if ok and tooltipScaleValue and tooltipScaleValue > 0 then
        scale = tooltipScaleValue
      end
    end

    if tooltipParent then
      tooltip:SetPoint("BOTTOMLEFT", tooltipParent, "BOTTOMLEFT", (x / scale) + 16, (y / scale) + 16)
      return
    end
  end

  if owner then
    tooltip:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
  end
end

-- Modern API first, legacy global last. The order matters: the global
-- GetSpellInfo is the deprecated pre-11.0 signature and only survives as a
-- compatibility shim, so it must never win over C_Spell. Mirrors
-- ResolveSpellNameByID in isiLive_ui_game_menu_mounts.lua -- keep the two in
-- step if either changes.
local function ResolveSpellName(spellID)
  local spellAPI = rawget(_G, "C_Spell")

  local getSpellName = type(spellAPI) == "table" and spellAPI.GetSpellName or nil
  if type(getSpellName) == "function" then
    local ok, spellName = pcall(getSpellName, spellID)
    if ok and type(spellName) == "string" and spellName ~= "" then
      return spellName
    end
  end

  local getSpellInfo = type(spellAPI) == "table" and spellAPI.GetSpellInfo or nil
  if type(getSpellInfo) == "function" then
    local ok, spellInfo = pcall(getSpellInfo, spellID)
    if ok and type(spellInfo) == "table" and type(spellInfo.name) == "string" and spellInfo.name ~= "" then
      return spellInfo.name
    end
  end

  local legacyGetSpellInfo = rawget(_G, "GetSpellInfo")
  if type(legacyGetSpellInfo) == "function" then
    local ok, spellName = pcall(legacyGetSpellInfo, spellID)
    if ok and type(spellName) == "string" and spellName ~= "" then
      return spellName
    end
  end

  return nil
end

local function EnsurePrivateTooltipAPI(tooltip)
  if type(tooltip) ~= "table" then
    return nil
  end
  if tooltip._isiLiveTooltipReady == true then
    return tooltip
  end

  tooltip._isiLiveTooltipReady = true
  tooltip._isIsiLiveTooltip = true
  tooltip._isiLiveTooltipNativeShow = tooltip.Show
  tooltip._isiLiveTooltipNativeHide = tooltip.Hide

  function tooltip:ClearLines()
    local lines = self._isiLiveTooltipLines or {}
    for _, line in ipairs(lines) do
      if type(line) == "table" and type(line.Hide) == "function" then
        line:Hide()
      end
    end
    self._isiLiveTooltipLineCount = 0
  end

  function tooltip:SetOwner(anchorFrame, anchor)
    self._isiLiveTooltipOwner = anchorFrame
    self._isiLiveTooltipAnchor = anchor
    PositionPrivateTooltip(self)
  end

  function tooltip:SetText(text, r, g, b)
    self:ClearLines()
    local line = AcquireTooltipLine(self, 1)
    if type(line) ~= "table" then
      return
    end
    if type(line.SetTextColor) == "function" then
      line:SetTextColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1)
    end
    UICommon.SetReadableText(line, text)
    if type(line.Show) == "function" then
      line:Show()
    end
    self._isiLiveTooltipLineCount = 1
    LayoutTooltipLines(self)
  end

  function tooltip:AddLine(text, r, g, b)
    local index = (tonumber(self._isiLiveTooltipLineCount) or 0) + 1
    local line = AcquireTooltipLine(self, index)
    if type(line) ~= "table" then
      return
    end
    if type(line.SetTextColor) == "function" then
      line:SetTextColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1)
    end
    UICommon.SetReadableText(line, text)
    if type(line.Show) == "function" then
      line:Show()
    end
    self._isiLiveTooltipLineCount = index
    LayoutTooltipLines(self)
  end

  function tooltip:SetSpellByID(spellID)
    local spellName = ResolveSpellName(spellID) or ("Spell " .. tostring(spellID or "?"))
    self:SetText(spellName, 1, 1, 1)
  end

  function tooltip:Show()
    self._isiLiveTooltipShown = true
    PositionPrivateTooltip(self)
    if type(self._isiLiveTooltipNativeShow) == "function" then
      pcall(self._isiLiveTooltipNativeShow, self)
    end
  end

  function tooltip:Hide()
    self._isiLiveTooltipShown = false
    self:ClearLines()
    if type(self._isiLiveTooltipNativeHide) == "function" then
      pcall(self._isiLiveTooltipNativeHide, self)
    end
  end

  return tooltip
end

local function ApplyCloseButtonBackdrop(button)
  UICommon.ApplyBackdrop(button, "CLOSE_BUTTON")
end

local CLOSE_BUTTON_STYLE = {
  default = {
    background = UICommon.Colors.SURFACE_ACTION_SECONDARY,
    border = UICommon.Colors.BORDER_ACTION_SECONDARY,
    text = UICommon.Colors.TEXT_SUPPORTING,
  },
  hover = {
    background = UICommon.Colors.SURFACE_CLOSE_DANGER_HOVER,
    border = UICommon.Colors.BORDER_CLOSE_DANGER_HOVER,
    text = UICommon.Colors.TEXT_HEADING,
  },
  pressed = {
    background = UICommon.Colors.SURFACE_CLOSE_DANGER_PRESSED,
    border = UICommon.Colors.BORDER_CLOSE_DANGER_PRESSED,
    text = UICommon.Colors.TEXT_CLOSE_DANGER_PRESSED,
  },
}

local function CreateCloseButtonLabel(button)
  if type(button.CreateFontString) ~= "function" then
    return nil
  end

  local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  label:SetPoint("CENTER", button, "CENTER", 0, 0)
  label:SetText("×")
  button._isiLiveCloseButtonLabel = label
  return label
end

local function ApplyCloseButtonVisual(button, label, state)
  local resolvedState = CLOSE_BUTTON_STYLE[state] and state or "default"
  local style = CLOSE_BUTTON_STYLE[resolvedState]
  ApplyColorTuple(button, "SetBackdropColor", style.background)
  ApplyColorTuple(button, "SetBackdropBorderColor", style.border)
  ApplyColorTuple(label, "SetTextColor", style.text)
  button._isiLiveVisualState = resolvedState
end

local function AttachCloseButtonVisualStates(button, label, opts)
  if not label then
    return
  end

  opts = opts or {}
  local titleText = UICommon.GetLocalizedText(opts.tooltipTitleKey, opts.tooltipTitle or "")
  local bodyText = UICommon.GetLocalizedText(opts.tooltipBodyKey, opts.tooltipBody or "")
  local anchor = type(opts.tooltipAnchor) == "string" and opts.tooltipAnchor or "ANCHOR_LEFT"

  button:SetScript("OnEnter", function()
    ApplyCloseButtonVisual(button, label, "hover")
    local tooltip = rawget(_G, "GameTooltip")
    if tooltip and type(tooltip.SetOwner) == "function" and (titleText ~= "" or bodyText ~= "") then
      tooltip:SetOwner(button, anchor)
      if titleText ~= "" then
        tooltip:AddLine(titleText)
      end
      if bodyText ~= "" then
        tooltip:AddLine(bodyText, 0.8, 0.8, 0.8)
      end
      tooltip:Show()
    end
  end)

  button:SetScript("OnLeave", function()
    ApplyCloseButtonVisual(button, label, "default")
    local tooltip = rawget(_G, "GameTooltip")
    if tooltip and type(tooltip.Hide) == "function" then
      tooltip:Hide()
    end
  end)

  button:SetScript("OnMouseDown", function()
    ApplyCloseButtonVisual(button, label, "pressed")
  end)

  button:SetScript("OnMouseUp", function()
    local isMouseOver = type(button.IsMouseOver) == "function" and button:IsMouseOver()
    ApplyCloseButtonVisual(button, label, isMouseOver and "hover" or "default")
  end)
end

function UICommon.CreateCloseButton(parent, opts)
  opts = opts or {}
  local button = CreateFrame("Button", opts.name, parent, "BackdropTemplate")
  local size = tonumber(opts.size) or 20
  button:SetSize(size, size)

  local point = opts.point
  if type(point) == "table" then
    button:SetPoint(point[1], point[2], point[3], point[4], point[5])
  else
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, -2)
  end

  local strata = opts.frameStrata or (parent and parent.GetFrameStrata and parent:GetFrameStrata()) or "MEDIUM"
  button:SetFrameStrata(strata)

  local level = tonumber(opts.frameLevel) or ((parent and parent.GetFrameLevel and parent:GetFrameLevel()) or 1) + 20
  button:SetFrameLevel(level)

  ApplyCloseButtonBackdrop(button)
  local label = CreateCloseButtonLabel(button)
  ApplyCloseButtonVisual(button, label, "default")
  AttachCloseButtonVisualStates(button, label, {
    tooltipTitleKey = opts.tooltipTitleKey,
    tooltipTitle = opts.tooltipTitle,
    tooltipBodyKey = opts.tooltipBodyKey,
    tooltipBody = opts.tooltipBody,
    tooltipAnchor = opts.tooltipAnchor,
  })

  return button
end

-- Legacy name kept as an alias so a missed call site fails visibly at review
-- time instead of silently at runtime. No in-repo caller uses it any more, and
-- `addonTable` is private to this addon, so nothing outside can reach it
-- either -- see docs/ARCHITECTURE.md and rules 27 / 104.
UICommon.CreateRedCloseButton = UICommon.CreateCloseButton

function UICommon.CreatePrivateTooltip(parent)
  local tooltipParent = rawget(_G, "UIParent") or parent
  local tooltipFrame = CreateFrame("Frame", nil, tooltipParent, "BackdropTemplate")
  local tooltip = EnsurePrivateTooltipAPI(tooltipFrame)
  if type(tooltip) ~= "table" then
    return nil
  end

  if not UICommon.ApplyBackdrop(tooltip, "TOOLTIP") and type(tooltip.CreateTexture) == "function" then
    tooltip._isiLiveTooltipBackground = tooltip._isiLiveTooltipBackground or tooltip:CreateTexture(nil, "BACKGROUND")
    if type(tooltip._isiLiveTooltipBackground.SetAllPoints) == "function" then
      tooltip._isiLiveTooltipBackground:SetAllPoints()
    end
    if type(tooltip._isiLiveTooltipBackground.SetColorTexture) == "function" then
      tooltip._isiLiveTooltipBackground:SetColorTexture(unpack(UICommon.Colors.TOOLTIP_BG_BLACK))
    end
  end

  if type(tooltip.SetFrameStrata) == "function" then
    tooltip:SetFrameStrata("TOOLTIP")
  end
  if type(tooltip.SetClampedToScreen) == "function" then
    tooltip:SetClampedToScreen(true)
  end
  if type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end

  return tooltip
end

function UICommon.PreparePrivateTooltip(tooltip, anchorFrame, anchor)
  tooltip = EnsurePrivateTooltipAPI(tooltip)
  if type(tooltip) ~= "table" then
    return nil
  end

  if type(tooltip.ClearLines) == "function" then
    tooltip:ClearLines()
  end

  local resolvedAnchor = type(anchor) == "string" and anchor or "ANCHOR_CURSOR"
  if type(tooltip.SetOwner) == "function" then
    tooltip:SetOwner(anchorFrame, resolvedAnchor)
  end
  tooltip._isiLiveTooltipOwner = anchorFrame
  tooltip._isiLiveTooltipAnchor = resolvedAnchor

  return tooltip
end

function UICommon.HidePrivateTooltip(tooltip)
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end
