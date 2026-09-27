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
  ACCENT_BLUE = { 0.3, 0.65, 1 },
  TEXT_NORMAL = { 0.85, 0.85, 0.9 },
  TEXT_DIM = { 0.5, 0.5, 0.6 },
  HOVER_HIGHLIGHT = { 1, 1, 1, 0.10 },
  ROW_ALT = { 1, 1, 1, 0.03 },

  -- Extracted 2026-07-22 from ui/*.lua literal SetTextColor/SetVertexColor/
  -- SetColorTexture call sites (UI modernization pass). Each entry preserves
  -- the exact original arity (3 = RGB, alpha left untouched by the widget
  -- API; 4 = RGBA) so migrating a call site to `unpack(...)` is behavior-
  -- neutral.
  --
  -- Consolidated 2026-09-27 (rule 142): a compatibility color that matched
  -- another token of the same meaning within 0.05 per channel was folded into
  -- it, preferring the semantic token below, and unused colors were dropped.
  -- New colors reuse an existing token when one is within that tolerance.
  WHITE_RGB = { 1, 1, 1 },
  GOLD_TITLE = { 1, 0.85, 0 },
  GOLD_LABEL_ALT = { 1, 0.82, 0.18 },
  GOLD_TARGET_TEXT = { 1.0, 0.84, 0.35 },
  MUTED_GOLD_PCT_TEXT = { 0.9, 0.82, 0.45 },
  AMBER_SUPPORT_NOTICE = { 1, 0.75, 0.2, 1 },
  ORANGE_RAID_NOTICE = { 1, 0.5, 0 },
  ORANGE_WARNING_LABEL = { 1, 0.55, 0.2, 1 },
  WARM_WHITE_TEXT = { 1, 0.92, 0.7 },
  BLUE_VERSION_TEXT = { 0.55, 0.75, 1.0 },
  LIGHT_BLUE_LEVEL_TEXT = { 0.65, 0.85, 1.0 },
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
  DARK_SLATE_ICON_BG = { 0.13, 0.15, 0.18, 0.55 },
  GREEN_HINT_TEXT = { 0.45, 0.85, 0.45 },
  SUCCESS_GREEN_BAR = { 0.2, 0.75, 0.35 },
  GRAY_INACTIVE = { 0.5, 0.5, 0.5 },
  GRAY_SUBLINE = { 0.7, 0.7, 0.7 },
  GRAY_MUTED_PCT = { 0.4, 0.4, 0.5 },
  LIGHT_GRAY_ARROW = { 0.8, 0.8, 0.8 },
  DARK_GRAY_BAR_BG = { 0.12, 0.12, 0.12 },
  RED_DANGER_OVERLAY = { 0.4, 0.05, 0.05, 0.55 },
  TRANSPARENT = { 0, 0, 0, 0 },
  BLACK_OVERLAY_28 = { 0, 0, 0, 0.28 },
  BLACK_OVERLAY_35 = { 0, 0, 0, 0.35 },
  BLACK_OVERLAY_50 = { 0, 0, 0, 0.5 },
  BLACK_OVERLAY_60 = { 0, 0, 0, 0.6 },
  TOOLTIP_BG_BLACK = { 0, 0, 0, 0.92 },
  BG_NOTICE_CARD = { 0.05, 0.05, 0.08, 0.75 },

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

  -- M+ timer timeline: quiet track and cutoff ticks, fill in the color of the
  -- chest grade that is still reachable.
  MPLUS_TIMELINE_TRACK = { 0, 0, 0, 0.45 },
  MPLUS_TIMELINE_TICK = { 0.9, 0.95, 1, 0.6 },
  MPLUS_GRADE3_FILL = { 0.3, 0.85, 0.4, 0.9 },
  MPLUS_GRADE2_FILL = { 1, 0.82, 0.2, 0.9 },
  MPLUS_GRADE1_FILL = { 0.85, 0.88, 0.95, 0.85 },
  MPLUS_OVERTIME_FILL = { 1, 0.3, 0.3, 0.9 },
  -- M+ killtracker: calm blue while forces are open, the shared success green
  -- (SUCCESS_GREEN_BAR) once 100% is reached.
  MPLUS_FORCES_PROGRESS_FILL = { 0.26, 0.56, 0.9 },

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

-- Supported languages that write decimals with a comma. Follows the addon
-- language like every other visible string, not the client locale.
local DECIMAL_COMMA_LOCALES = {
  deDE = true,
  frFR = true,
  esES = true,
  esMX = true,
  ptBR = true,
  itIT = true,
  ruRU = true,
  trTR = true,
}

function UICommon.GetDecimalSeparator(localeTag)
  return DECIMAL_COMMA_LOCALES[ResolveActiveLocale(localeTag)] and "," or "."
end

-- Formats a plain number with a fixed number of decimals and the decimal
-- separator of the addon language. Returns nil when the value cannot be
-- formatted (non-number or masked value).
function UICommon.FormatDecimal(value, decimals, localeTag)
  local places = math.max(0, math.floor(tonumber(decimals) or 0))
  local ok, text = pcall(string.format, "%." .. places .. "f", value)
  if not ok or type(text) ~= "string" then
    return nil
  end
  if UICommon.GetDecimalSeparator(localeTag) == "," then
    text = text:gsub("%.", ",")
  end
  return text
end

function UICommon.GetLocaleFontPath(localeTag)
  return UICommon.LOCALE_FONT_OVERRIDES[ResolveActiveLocale(localeTag)]
end

-- Every FontString that has been through ApplyLocaleFont, whether a font was
-- actually applied or not. Weak keys: a row that goes away must not be kept
-- alive by this table.
--
-- Tracking has to happen even when nothing is applied. The default selection
-- resolves to no path, so a string first seen under the default would never be
-- recorded -- and switching away from the default would then reach nothing.
local trackedFontStrings = setmetatable({}, { __mode = "k" })

local function TrackFontString(fontString)
  if
    type(fontString) == "table"
    and type(fontString.GetFont) == "function"
    and type(fontString.SetFont) == "function"
  then
    trackedFontStrings[fontString] = true
  end
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

-- Applies the font this string should carry: the locale override where the
-- client locale needs one, otherwise the user's pick. Kept under its original
-- name so the ~20 existing call sites pick up the user font without change.
--
-- GetPreferredFontPath lives in ui/isiLive_ui_fonts.lua. Harness setups that
-- load this module alone fall back to the locale override, which is exactly
-- the pre-font-selection behaviour.
function UICommon.ApplyLocaleFont(fontString, localeTag)
  TrackFontString(fontString)
  local resolve = UICommon.GetPreferredFontPath
  local fontPath = type(resolve) == "function" and resolve(localeTag) or UICommon.GetLocaleFontPath(localeTag)
  return ApplyFontPath(fontString, fontPath)
end

-- Re-applies the current font decision to every tracked FontString.
--
-- Needed because the ApplyLocaleFont call sites sit in the *creation* of rows,
-- headers and labels, not in their update path: roster rows are pooled and
-- reused, so a re-render alone leaves their font untouched. Text-carrying
-- strings go back through the readable path so the Cyrillic veto still wins.
function UICommon.RefreshTrackedFonts()
  local refreshed = 0
  for fontString in pairs(trackedFontStrings) do
    local text = type(fontString.GetText) == "function" and fontString:GetText() or nil
    if type(text) == "string" and text ~= "" and type(UICommon.ApplyReadableFontForText) == "function" then
      UICommon.ApplyReadableFontForText(fontString, text)
    else
      UICommon.ApplyLocaleFont(fontString)
    end
    refreshed = refreshed + 1
  end
  return refreshed
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

-- Re-exported from the shared validator so UI callers keep a single import.
UICommon.IsSecretValue = addonTable.Validators.IsSecretValue

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
    borderColor = UICommon.Colors.BORDER_ACTION_SECONDARY,
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
    borderColor = UICommon.Colors.BORDER_ACTION_SECONDARY,
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

local function CallMethod(target, methodName, ...)
  local method = type(target) == "table" and target[methodName] or nil
  if type(method) == "function" then
    return method(target, ...)
  end
  return nil
end

-- Client textures behind the semantic state icons. Only textures that other
-- maintained addons already load are used here, so every path is known to
-- exist in the client. Item icons carry the usual 0.08 icon-border crop.
local ICON_CROP = { 0.08, 0.92, 0.08, 0.92 }
UICommon.StateIcons = {
  lock = { path = "Interface\\PetBattles\\PetBattle-LockIcon" },
  cooldown = { path = "Interface\\Icons\\INV_Relics_Hourglass_02", texCoord = ICON_CROP },
  warning = { path = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew" },
  unavailable = { path = "Interface\\RAIDFRAME\\ReadyCheck-NotReady" },
  info = { path = "Interface\\common\\help-i" },
  action = { path = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" },
  death = {
    path = "Interface\\WorldStateFrame\\SkullBones",
    texCoord = { 0.046875, 0.453125, 0.046875, 0.46875 },
  },
  settings = { path = "Interface\\WorldMap\\GEAR_64GREY" },
}

-- Puts a named state icon onto a texture; `nil` clears and hides it.
function UICommon.ApplyStateIcon(texture, iconKey)
  if type(texture) ~= "table" then
    return false
  end
  local icon = iconKey and UICommon.StateIcons[iconKey] or nil
  if not icon then
    if type(texture.SetTexture) == "function" then
      texture:SetTexture(nil)
    end
    if type(texture.Hide) == "function" then
      texture:Hide()
    end
    texture._isiLiveStateIcon = nil
    return false
  end
  if type(texture.SetTexture) == "function" then
    texture:SetTexture(icon.path)
  end
  if type(texture.SetTexCoord) == "function" then
    local coords = icon.texCoord or { 0, 1, 0, 1 }
    texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  end
  if type(texture.Show) == "function" then
    texture:Show()
  end
  texture._isiLiveStateIcon = iconKey
  return true
end

local AVAILABILITY_ICON_KEYS = {
  cooldown = "cooldown",
  combat = "warning",
  leader = "lock",
  unavailable = "unavailable",
}

local ACTION_AVAILABILITY_COLORS = {
  cooldown = UICommon.Colors.MUTED_GOLD_PCT_TEXT,
  combat = UICommon.Colors.ORANGE_WARNING_LABEL,
  leader = UICommon.Colors.TEXT_SUPPORTING,
  unavailable = UICommon.Colors.TEXT_DIM,
}

function UICommon.ApplyActionButtonVisual(button, role, state)
  if type(button) ~= "table" then
    return false
  end
  local resolvedRole = ACTION_BUTTON_STYLE_BY_ROLE[role] and role or "secondary"
  local style = ACTION_BUTTON_STYLE_BY_ROLE[resolvedRole]
  local resolvedState = state == "hover" and "hover" or (state == "pressed" and "pressed" or "default")
  local background = resolvedState == "hover" and style.hoverBg
    or (resolvedState == "pressed" and style.pressedBg or style.defaultBg)
  local availability = button._isiLiveAvailability or "available"
  if availability ~= "available" then
    background = UICommon.Colors.SURFACE_ACTION_SECONDARY_PRESSED
  end

  ApplyColorTuple(button, "SetBackdropColor", background)
  ApplyColorTuple(button, "SetBackdropBorderColor", ACTION_AVAILABILITY_COLORS[availability] or style.border)
  ApplyColorTuple(
    button._flatLabel,
    "SetTextColor",
    availability == "available" and style.text or UICommon.Colors.TEXT_SUPPORTING
  )
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
  if type(button.CreateTexture) == "function" then
    local icon = button:CreateTexture(nil, "OVERLAY")
    CallMethod(icon, "SetSize", 12, 12)
    CallMethod(icon, "SetPoint", "LEFT", button, "LEFT", 5, 0)
    CallMethod(icon, "Hide")
    button._availabilityIcon = icon
  end

  local role = ACTION_BUTTON_STYLE_BY_ROLE[opts.role] and opts.role or "secondary"
  function button:SetAvailabilityState(nextState)
    self._isiLiveAvailability = AVAILABILITY_ICON_KEYS[nextState] and nextState or "available"
    UICommon.ApplyStateIcon(self._availabilityIcon, AVAILABILITY_ICON_KEYS[self._isiLiveAvailability])
    if type(self.SetAlpha) == "function" then
      self:SetAlpha(self._isiLiveAvailability == "available" and 1 or 0.72)
    end
    UICommon.ApplyActionButtonVisual(self, role, "default")
  end

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

-- Replaces the classic UICheckButtonTemplate art with the flat isiLive look:
-- a thin cool outline around a dark box, a filled accent square when checked
-- and a soft additive hover. Works on any CheckButton, so the template keeps
-- providing click handling, checked state and accessibility.
local function InsetRegion(region, anchor, inset)
  if type(region.ClearAllPoints) == "function" and type(region.SetPoint) == "function" then
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", anchor, "TOPLEFT", inset, -inset)
    region:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -inset, inset)
  end
end

-- Draw layers are set explicitly instead of trusting the template defaults:
-- outline BACKGROUND, box fill ARTWORK, check mark OVERLAY, so the mark can
-- never end up underneath the fill.
local function StyleCheckboxSlot(check, slot)
  local setter, getter = check["Set" .. slot.name], check["Get" .. slot.name]
  if type(setter) ~= "function" or type(getter) ~= "function" then
    return nil
  end
  setter(check, "Interface\\Buttons\\WHITE8X8")
  local texture = getter(check)
  if type(texture) ~= "table" then
    return nil
  end
  InsetRegion(texture, check, slot.inset)
  ApplyColorTuple(texture, "SetVertexColor", slot.color)
  if slot.layer and type(texture.SetDrawLayer) == "function" then
    texture:SetDrawLayer(slot.layer, 0)
  end
  if slot.blendMode and type(texture.SetBlendMode) == "function" then
    texture:SetBlendMode(slot.blendMode)
  end
  return texture
end

function UICommon.ApplyFlatCheckboxStyle(check)
  if type(check) ~= "table" then
    return false
  end
  local size = type(check.GetWidth) == "function" and tonumber(check:GetWidth()) or nil
  local large = (size or 24) >= 22
  local boxInset = large and 3 or 2
  local fillInset = boxInset + 1
  local markInset = boxInset + (large and 4 or 3)
  local colors = UICommon.Colors

  if not check._isiLiveFlatOutline and type(check.CreateTexture) == "function" then
    local outline = check:CreateTexture(nil, "BACKGROUND")
    InsetRegion(outline, check, boxInset)
    ApplyColorTuple(outline, "SetColorTexture", colors.BORDER_ACTION_PRIMARY)
    check._isiLiveFlatOutline = outline
  end

  local slots = {
    { name = "NormalTexture", inset = fillInset, color = colors.SURFACE_ACTION_SECONDARY_PRESSED, layer = "ARTWORK" },
    { name = "PushedTexture", inset = fillInset, color = colors.SURFACE_ACTION_PRIMARY_PRESSED, layer = "ARTWORK" },
    { name = "HighlightTexture", inset = fillInset, color = colors.HOVER_HIGHLIGHT, blendMode = "ADD" },
    { name = "CheckedTexture", inset = markInset, color = colors.ACCENT_BLUE, layer = "OVERLAY" },
    { name = "DisabledCheckedTexture", inset = markInset, color = colors.GRAY_INACTIVE, layer = "OVERLAY" },
  }
  for _, slot in ipairs(slots) do
    StyleCheckboxSlot(check, slot)
  end
  check._isiLiveFlatCheckbox = true
  return true
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

function UICommon.ApplyNoticeKind(parent, kind)
  if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then
    return false
  end
  local kinds = {
    info = { icon = "info", color = UICommon.Colors.ACCENT_NOTICE_TOP },
    warning = { icon = "warning", color = UICommon.Colors.TEXT_ALERT_DANGER },
    action = { icon = "action", color = UICommon.Colors.SUCCESS_GREEN_BAR },
  }
  local style = kinds[kind]
  if not style then
    return false
  end
  local rail = parent._isiLiveNoticeKindRail
  if not rail then
    rail = parent:CreateTexture(nil, "ARTWORK")
    rail:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -5)
    rail:SetPoint("TOPRIGHT", parent, "TOPLEFT", 4, -5)
    rail:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 1, 5)
    rail:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", 4, 5)
    parent._isiLiveNoticeKindRail = rail
  end
  ApplyColorTuple(rail, "SetColorTexture", style.color)
  local icon = parent._isiLiveNoticeKindIcon
  if not icon then
    icon = parent:CreateTexture(nil, "OVERLAY")
    CallMethod(icon, "SetSize", 16, 16)
    CallMethod(icon, "SetPoint", "TOPLEFT", parent, "TOPLEFT", 9, -7)
    parent._isiLiveNoticeKindIcon = icon
  end
  UICommon.ApplyStateIcon(icon, style.icon)
  local changed = parent._isiLiveNoticeKind ~= nil and parent._isiLiveNoticeKind ~= kind
  parent._isiLiveNoticeKind = kind
  return true, changed
end

function UICommon.IsReducedMotionEnabled()
  local db = rawget(_G, "IsiLiveDB")
  return type(db) == "table" and db.reduceMotion == true
end

-- Shared motion vocabulary. New animations take their durations and easing
-- from here instead of inventing literals, so the addon moves at one tempo.
-- `fast` is the existing Center-Notice fade and must stay 0.14 s.
UICommon.Motion = {
  duration = {
    fast = 0.14,
    normal = 0.2,
    slow = 0.35,
  },
  smoothing = {
    enter = "OUT",
    exit = "IN",
    loop = "IN_OUT",
  },
}

function UICommon.ResolveMotionDuration(token)
  if type(token) == "number" and token >= 0 then
    return token
  end
  local durations = UICommon.Motion.duration
  return durations[token] or durations.normal
end

-- Every transition that is decorative registers here. Switching reduced
-- motion on stops all of them at once and leaves each frame at its resting
-- alpha, so the setting takes effect without a reload. Weak keys: a frame
-- that goes away must not be kept alive by this table.
local motionTransitions = setmetatable({}, { __mode = "k" })

-- Only a transition that is actually running gets stopped and put back to
-- its resting alpha. An idle one is left alone: its frame's alpha may since
-- have been set by someone else (the main frame's combat fade, for one).
local function SettleMotionTransition(frame, transition)
  local group = transition.group
  if not (group and group.IsPlaying and group:IsPlaying()) then
    return
  end
  if group.Stop then
    group:Stop()
  end
  if type(frame.SetAlpha) == "function" then
    frame:SetAlpha(transition.restAlpha or 1)
  end
end

function UICommon.SetReducedMotionEnabled(enabled)
  local db = rawget(_G, "IsiLiveDB")
  if type(db) ~= "table" then
    return false
  end
  db.reduceMotion = enabled == true
  if not db.reduceMotion then
    return true
  end
  for frame, transitions in pairs(motionTransitions) do
    for _, transition in pairs(transitions) do
      SettleMotionTransition(frame, transition)
    end
  end
  return true
end

local function GetMotionTransition(frame, key)
  local transitions = motionTransitions[frame]
  return transitions and transitions[key] or nil
end

local function CreateAlphaTransition(frame, key, opts)
  local group = frame:CreateAnimationGroup()
  local alpha = group:CreateAnimation("Alpha")
  alpha:SetFromAlpha(tonumber(opts.fromAlpha) or 0)
  alpha:SetToAlpha(tonumber(opts.toAlpha) or 1)
  alpha:SetDuration(UICommon.ResolveMotionDuration(opts.duration))
  alpha:SetSmoothing(opts.smoothing or UICommon.Motion.smoothing.enter)

  local transition = { group = group, restAlpha = 1 }
  if type(group.SetScript) == "function" then
    group:SetScript("OnFinished", function()
      if type(frame.SetAlpha) == "function" then
        frame:SetAlpha(transition.restAlpha or 1)
      end
    end)
  end

  motionTransitions[frame] = motionTransitions[frame] or {}
  motionTransitions[frame][key] = transition
  return transition
end

-- Plays a decorative alpha transition on `frame` and settles it at its
-- current alpha afterwards. The animation is built once per (frame, key) and
-- restarted on later calls. Returns false without touching the frame when
-- reduced motion is on or the frame cannot animate.
--
-- opts: fromAlpha, toAlpha (defaults 0 -> 1), duration (Motion token or
-- seconds), smoothing (defaults to the enter easing).
function UICommon.PlayAlphaTransition(frame, key, opts)
  if UICommon.IsReducedMotionEnabled() then
    return false
  end
  if type(frame) ~= "table" or type(frame.CreateAnimationGroup) ~= "function" or type(key) ~= "string" then
    return false
  end
  local transition = GetMotionTransition(frame, key) or CreateAlphaTransition(frame, key, opts or {})
  if type(frame.GetAlpha) == "function" then
    transition.restAlpha = frame:GetAlpha()
  end
  -- One alpha transition per frame at a time: a newer one replaces a running
  -- sibling instead of stacking two fades.
  for otherKey, other in pairs(motionTransitions[frame]) do
    local otherGroup = other.group
    if otherKey ~= key and otherGroup.IsPlaying and otherGroup:IsPlaying() and otherGroup.Stop then
      otherGroup:Stop()
    end
  end
  local group = transition.group
  if group.IsPlaying and group:IsPlaying() and group.Stop then
    group:Stop()
  end
  group:Play()
  return true
end

function UICommon.PlayNoticeTransition(parent)
  local played = UICommon.PlayAlphaTransition(parent, "notice", {
    fromAlpha = 0.86,
    toAlpha = 1,
    duration = "fast",
  })
  if played then
    parent._isiLiveNoticeTransition = GetMotionTransition(parent, "notice").group
  end
  return played
end

-- Entrance of a notice card that was hidden: a full fade from transparent
-- over the `normal` duration, clearly noticeable without moving the card.
-- PlayNoticeTransition stays the quieter refresh for a card already on screen.
function UICommon.PlayNoticeEntrance(parent)
  local played = UICommon.PlayAlphaTransition(parent, "noticeEntrance", {
    fromAlpha = 0,
    toAlpha = 1,
    duration = "normal",
  })
  if played then
    parent._isiLiveNoticeEntrance = GetMotionTransition(parent, "noticeEntrance").group
  end
  return played
end

local TOOLTIP_HORIZONTAL_PADDING = 10
local TOOLTIP_VERTICAL_PADDING = 10
local TOOLTIP_LINE_SPACING = 3
local TOOLTIP_MIN_HEIGHT = 28
local TOOLTIP_WIDTH = 220
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
