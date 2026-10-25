-- WoW API surface for one simulated client in the wowsim simulator.
--
-- Builds the global environment a client's copy of isiLive runs in. Every
-- group / unit / challenge-mode / scenario API reads the shared world model
-- (world.lua) from this client's perspective ("player" is this client's
-- member, party1..4 are the others in roster order). Output channels (print,
-- chat, addon messages, sounds) are routed into the world log so a scenario
-- run records what the player would have seen and heard.

local Api = {}

local Compat = require("compat")
local unpack = Compat.unpack

-- Tank and healer specialization IDs (warcraft.wiki.gg/wiki/SpecializationID);
-- every other spec is a damage dealer.
local SPEC_ROLES = {
  [250] = "TANK",
  [581] = "TANK",
  [104] = "TANK",
  [268] = "TANK",
  [66] = "TANK",
  [73] = "TANK",
  [105] = "HEALER",
  [1468] = "HEALER",
  [270] = "HEALER",
  [65] = "HEALER",
  [256] = "HEALER",
  [257] = "HEALER",
  [264] = "HEALER",
}

local CLASS_COLORS = {
  WARRIOR = { 0.78, 0.61, 0.43 },
  PALADIN = { 0.96, 0.55, 0.73 },
  HUNTER = { 0.67, 0.83, 0.45 },
  ROGUE = { 1.00, 0.96, 0.41 },
  PRIEST = { 1.00, 1.00, 1.00 },
  DEATHKNIGHT = { 0.77, 0.12, 0.23 },
  SHAMAN = { 0.00, 0.44, 0.87 },
  MAGE = { 0.25, 0.78, 0.92 },
  WARLOCK = { 0.53, 0.53, 0.93 },
  MONK = { 0.00, 1.00, 0.60 },
  DRUID = { 1.00, 0.49, 0.04 },
  DEMONHUNTER = { 0.64, 0.19, 0.79 },
  EVOKER = { 0.20, 0.58, 0.50 },
}

local CLASS_NAMES = {
  WARRIOR = "Warrior",
  PALADIN = "Paladin",
  HUNTER = "Hunter",
  ROGUE = "Rogue",
  PRIEST = "Priest",
  DEATHKNIGHT = "Death Knight",
  SHAMAN = "Shaman",
  MAGE = "Mage",
  WARLOCK = "Warlock",
  MONK = "Monk",
  DRUID = "Druid",
  DEMONHUNTER = "Demon Hunter",
  EVOKER = "Evoker",
}

local function Hex(c)
  return string.format(
    "ff%02x%02x%02x",
    math.floor(c[1] * 255 + 0.5),
    math.floor(c[2] * 255 + 0.5),
    math.floor(c[3] * 255 + 0.5)
  )
end

-- WoW's strsplit: `delimiters` is a set of characters, empty fields are kept.
local function StrSplit(delimiters, str, pieces)
  str = tostring(str or "")
  local out = {}
  local pattern = "[" .. delimiters:gsub("[%%%]%^%-]", "%%%0") .. "]"
  local start = 1
  while true do
    if pieces and #out == pieces - 1 then
      out[#out + 1] = str:sub(start)
      break
    end
    local s, e = str:find(pattern, start)
    if not s then
      out[#out + 1] = str:sub(start)
      break
    end
    out[#out + 1] = str:sub(start, s - 1)
    start = e + 1
  end
  return unpack(out)
end

local function StrTrim(s, chars)
  s = tostring(s or "")
  if chars then
    local set = "[" .. chars:gsub("[%%%]%^%-]", "%%%0") .. "]"
    return (s:gsub("^" .. set .. "+", ""):gsub(set .. "+$", ""))
  end
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Mixin(target, ...)
  for i = 1, select("#", ...) do
    local source = select(i, ...)
    if type(source) == "table" then
      for k, v in pairs(source) do
        target[k] = v
      end
    end
  end
  return target
end

local ColorMixin = {}
function ColorMixin:GetRGB()
  return self.r, self.g, self.b
end
function ColorMixin:GetRGBA()
  return self.r, self.g, self.b, self.a
end
function ColorMixin:GetRGBAsBytes()
  return math.floor(self.r * 255 + 0.5), math.floor(self.g * 255 + 0.5), math.floor(self.b * 255 + 0.5)
end
function ColorMixin:SetRGBA(r, g, b, a)
  self.r, self.g, self.b, self.a = r, g, b, a or 1
end
function ColorMixin:SetRGB(r, g, b)
  self.r, self.g, self.b = r, g, b
end
function ColorMixin:GenerateHexColor()
  return Hex({ self.r, self.g, self.b })
end
function ColorMixin:GenerateHexColorMarkup()
  return "|c" .. self:GenerateHexColor()
end
function ColorMixin:WrapTextInColorCode(text)
  return "|c" .. self:GenerateHexColor() .. tostring(text) .. "|r"
end
function ColorMixin:IsEqualTo(other)
  return other and self.r == other.r and self.g == other.g and self.b == other.b and self.a == other.a
end

local function CreateColor(r, g, b, a)
  local c = Mixin({}, ColorMixin)
  c:SetRGBA(r, g, b, a)
  return c
end

local STD_LIB_NAMES = {
  "assert",
  "collectgarbage",
  "error",
  "getmetatable",
  "ipairs",
  "load",
  "next",
  "pairs",
  "pcall",
  "rawequal",
  "rawget",
  "rawset",
  "select",
  "setmetatable",
  "tonumber",
  "tostring",
  "type",
  "xpcall",
  "string",
  "table",
  "math",
  "coroutine",
}

local function InstallLuaCore(ctx)
  local world = ctx.world
  local env = ctx.env
  for _, name in ipairs(STD_LIB_NAMES) do
    env[name] = _G[name]
  end
  -- Each client gets private copies of the mutable std tables so a module
  -- that adds helpers (string.split, table.wipe ...) cannot leak across.
  env.string = Mixin({}, string)
  env.table = Mixin({}, table)
  env.math = Mixin({}, math)
  env._G = env
  env.unpack = unpack
  env.getfenv = function()
    return env
  end
  env.setfenv = function() end
  env.debug = { traceback = debug.traceback, getinfo = debug.getinfo, profilestart = function() end }
  env.os = {
    time = function(t)
      if t then
        return os.time(t)
      end
      return math.floor(world.epoch + world.t)
    end,
    date = function(fmt, t)
      return os.date(fmt, t or math.floor(world.epoch + world.t))
    end,
    clock = function()
      return world.t
    end,
  }
  env.loadfile = nil -- addon code must not load files at runtime
  env.dofile = nil
  env.require = nil
  env.io = nil
  -- WoW's xpcall forwards extra arguments to the function, unlike stock 5.1.
  env.xpcall = function(fn, handler, ...)
    local n = select("#", ...)
    local args = { ... }
    return xpcall(function()
      return fn(unpack(args, 1, n))
    end, handler)
  end
  env.loadstring = rawget(_G, "loadstring")
    or function(source, chunkName)
      return load(source, chunkName, "t", env)
    end
end

local function InstallWowLuaExtensions(ctx)
  local world = ctx.world
  local client = ctx.client
  local engine = ctx.engine
  local env = ctx.env
  -- WoW Lua extensions -------------------------------------------------------
  env.bit = Compat.bit
  env.format = string.format
  env.strsplit = StrSplit
  env.strtrim = StrTrim
  env.strjoin = function(sep, ...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    return table.concat(parts, sep)
  end
  env.strconcat = function(...)
    return env.strjoin("", ...)
  end
  env.tostringall = function(...)
    local out = {}
    for i = 1, select("#", ...) do
      out[i] = tostring((select(i, ...)))
    end
    return unpack(out, 1, select("#", ...))
  end
  env.string.split = function(str, sep, pieces)
    return StrSplit(sep, str, pieces)
  end
  env.string.trim = StrTrim
  env.string.join = env.strjoin
  env.strlen = string.len
  env.strlower = string.lower
  env.strupper = string.upper
  env.strsub = string.sub
  env.strfind = string.find
  env.strmatch = string.match
  env.strrep = string.rep
  env.strrev = string.reverse
  env.strbyte = string.byte
  env.strchar = string.char
  env.gsub = string.gsub
  env.gmatch = string.gmatch
  env.strcmputf8i = function(a, b)
    a, b = tostring(a):lower(), tostring(b):lower()
    return a < b and -1 or (a > b and 1 or 0)
  end
  env.tinsert = table.insert
  env.tremove = table.remove
  env.sort = table.sort
  env.tconcat = table.concat
  env.table.wipe = function(t)
    for k in pairs(t) do
      t[k] = nil
    end
    return t
  end
  env.wipe = env.table.wipe
  env.table.getn = function(t)
    return #t
  end
  env.getn = env.table.getn
  env.table.removemulti = function(t, pos, count)
    for _ = 1, count do
      table.remove(t, pos)
    end
  end
  env.max, env.min, env.abs = math.max, math.min, math.abs
  env.floor, env.ceil, env.sqrt = math.floor, math.ceil, math.sqrt
  env.mod = math.fmod
  env.random = math.random
  env.fastrandom = math.random
  env.math.pow = function(a, b)
    return a ^ b
  end
  env.Round = function(v)
    return math.floor(v + 0.5)
  end
  env.Clamp = function(v, lo, hi)
    return math.min(math.max(v, lo), hi)
  end
  env.Saturate = function(v)
    return math.min(math.max(v, 0), 1)
  end
  env.Lerp = function(a, b, t)
    return a + (b - a) * t
  end
  env.date = env.os.date
  env.time = env.os.time
  env.utf8len = Compat.Utf8Len
  env.utf8sub = Compat.Utf8Sub
  env.Mixin = Mixin
  env.CreateFromMixins = function(...)
    return Mixin({}, ...)
  end
  env.CreateAndInitFromMixin = function(mixin, ...)
    local obj = Mixin({}, mixin)
    if obj.Init then
      obj:Init(...)
    end
    return obj
  end
  env.ColorMixin = ColorMixin
  env.CreateColor = CreateColor
  env.CopyTable = function(t, shallow)
    local function Copy(src)
      local r = {}
      for k, v in pairs(src) do
        r[k] = (type(v) == "table" and not shallow) and Copy(v) or v
      end
      return r
    end
    return Copy(t or {})
  end
  env.tContains = function(t, value)
    for _, v in pairs(t or {}) do
      if v == value then
        return true
      end
    end
    return false
  end
  env.tIndexOf = function(t, value)
    for i, v in ipairs(t or {}) do
      if v == value then
        return i
      end
    end
    return nil
  end
  env.tInvert = function(t)
    local r = {}
    for k, v in pairs(t or {}) do
      r[v] = k
    end
    return r
  end
  env.tDeleteItem = function(t, item)
    for i = #t, 1, -1 do
      if t[i] == item then
        table.remove(t, i)
      end
    end
  end
  env.tAppendAll = function(t, src)
    for _, v in ipairs(src or {}) do
      t[#t + 1] = v
    end
  end
  env.tCount = function(t)
    local n = 0
    for _ in pairs(t or {}) do
      n = n + 1
    end
    return n
  end
  env.AbbreviateNumbers = function(n)
    n = tonumber(n) or 0
    if n >= 1e9 then
      return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then
      return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then
      return string.format("%.1fK", n / 1e3)
    end
    return tostring(math.floor(n))
  end
  env.AbbreviateLargeNumbers = env.AbbreviateNumbers
  env.BreakUpLargeNumbers = function(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
  end
  env.SecondsToTime = function(s)
    s = math.floor(tonumber(s) or 0)
    return string.format("%d Min %d Sec", math.floor(s / 60), s % 60)
  end
  env.SecondsToClock = function(s)
    s = math.floor(tonumber(s) or 0)
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
  end
  env.issecretvalue = function()
    return false
  end
  env.issecrettable = function()
    return false
  end
  env.canaccessvalue = function()
    return true
  end
  env.canaccesstable = function()
    return true
  end
  env.issecure = function()
    return false
  end
  env.securecall = function(fn, ...)
    if type(fn) == "string" then
      fn = env[fn]
    end
    return fn(...)
  end
  env.securecallfunction = function(fn, ...)
    return fn(...)
  end
  env.securecallmethod = function(obj, method, ...)
    return obj[method](obj, ...)
  end
  env.hooksecurefunc = function(tbl, name, fn)
    if type(tbl) == "string" then
      tbl, name, fn = env, tbl, name
    end
    local original = tbl[name]
    if type(original) ~= "function" then
      return
    end
    tbl[name] = function(...)
      local r = { original(...) }
      fn(...)
      return unpack(r)
    end
  end
  env.geterrorhandler = function()
    return function(err)
      world.Log("error", "geterrorhandler: " .. tostring(err), client)
    end
  end
  env.seterrorhandler = function() end
  env.debugprofilestop = function()
    return world.t * 1000
  end
  env.debugstack = function()
    return debug.traceback()
  end
  env.GetTime = function()
    return world.t
  end
  env.GetTimePreciseSec = env.GetTime
  env.GetServerTime = function()
    return math.floor(world.epoch + world.t)
  end
  env.GetFramerate = function()
    return 60
  end
  env.GetTickTime = function()
    return 0.016
  end
  env.GetLocale = function()
    return client.locale or "enUS"
  end
  env.GetCurrentRegion = function()
    return 3
  end
  env.GetCurrentRegionName = function()
    return "EU"
  end
  env.GetBuildInfo = function()
    return "12.0.5", "70000", "Oct 1 2026", 120005
  end
  env.IsTestBuild = function()
    return false
  end
  env.IsPublicBuild = function()
    return true
  end
  env.GetScreenWidth = function()
    return engine.screenW
  end
  env.GetScreenHeight = function()
    return engine.screenH
  end
  env.GetPhysicalScreenSize = function()
    return engine.screenW, engine.screenH
  end
  env.GetCursorPosition = function()
    return engine.screenW / 2, engine.screenH / 2
  end
  env.IsShiftKeyDown = function()
    return false
  end
  env.IsControlKeyDown = function()
    return false
  end
  env.IsAltKeyDown = function()
    return false
  end
  env.IsModifierKeyDown = function()
    return false
  end
  env.IsMouseButtonDown = function()
    return false
  end
  env.GetMouseFoci = function()
    return {}
  end
  env.GetMouseFocus = function()
    return nil
  end
end

local function InstallOutput(ctx)
  local world = ctx.world
  local client = ctx.client
  local env = ctx.env
  -- Output ---------------------------------------------------------------------
  env.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    world.Log("print", table.concat(parts, " "), client)
  end
end

local function InstallFramesAndFonts(ctx)
  local world = ctx.world
  local client = ctx.client
  local engine = ctx.engine
  local env = ctx.env
  -- Frames and fonts -----------------------------------------------------------
  env.CreateFrame = engine.CreateFrame
  env.UIParent = engine.UIParent
  env.WorldFrame = engine.WorldFrame
  env.CreateFont = function(name)
    return engine.CreateFont(name)
  end
  local function FontObject(name, size, color, flags)
    env[name] = engine.CreateFont(name, "Fonts\\FRIZQT__.TTF", size, flags, color)
  end
  local GOLD, WHITE, GRAY, RED, GREEN =
    { 1, 0.82, 0, 1 }, { 1, 1, 1, 1 }, { 0.5, 0.5, 0.5, 1 }, { 1, 0.1, 0.1, 1 }, { 0.1, 1, 0.1, 1 }
  FontObject("GameFontNormal", 12, GOLD)
  FontObject("GameFontNormalSmall", 10, GOLD)
  FontObject("GameFontNormalSmall2", 11, GOLD)
  FontObject("GameFontNormalMed1", 13, GOLD)
  FontObject("GameFontNormalMed2", 14, GOLD)
  FontObject("GameFontNormalMed3", 14, GOLD)
  FontObject("GameFontNormalLarge", 16, GOLD)
  FontObject("GameFontNormalLarge2", 18, GOLD)
  FontObject("GameFontNormalHuge", 20, GOLD)
  FontObject("GameFontNormalHuge2", 24, GOLD)
  FontObject("GameFontNormalOutline", 12, GOLD, "OUTLINE")
  FontObject("GameFontNormalLargeOutline", 16, GOLD, "OUTLINE")
  FontObject("GameFontHighlight", 12, WHITE)
  FontObject("GameFontHighlightSmall", 10, WHITE)
  FontObject("GameFontHighlightSmall2", 11, WHITE)
  FontObject("GameFontHighlightMedium", 14, WHITE)
  FontObject("GameFontHighlightLarge", 16, WHITE)
  FontObject("GameFontHighlightHuge", 20, WHITE)
  FontObject("GameFontHighlightOutline", 12, WHITE, "OUTLINE")
  FontObject("GameFontHighlightLeft", 12, WHITE)
  FontObject("GameFontDisable", 12, GRAY)
  FontObject("GameFontDisableSmall", 10, GRAY)
  FontObject("GameFontDisableLarge", 16, GRAY)
  FontObject("GameFontRed", 12, RED)
  FontObject("GameFontRedSmall", 10, RED)
  FontObject("GameFontGreen", 12, GREEN)
  FontObject("GameFontGreenSmall", 10, GREEN)
  FontObject("GameFontWhite", 12, WHITE)
  FontObject("GameFontWhiteSmall", 10, WHITE)
  FontObject("GameFontBlack", 12, { 0, 0, 0, 1 })
  FontObject("GameTooltipText", 12, WHITE)
  FontObject("GameTooltipTextSmall", 10, WHITE)
  FontObject("GameTooltipHeaderText", 14, WHITE)
  FontObject("ChatFontNormal", 14, WHITE)
  FontObject("ChatFontSmall", 12, WHITE)
  FontObject("NumberFontNormal", 12, WHITE, "OUTLINE")
  FontObject("NumberFontNormalSmall", 10, WHITE, "OUTLINE")
  FontObject("NumberFontNormalLarge", 16, WHITE, "OUTLINE")
  FontObject("NumberFontNormalHuge", 30, WHITE, "OUTLINE")
  FontObject("SystemFont_Shadow_Med1", 13, WHITE)
  FontObject("SystemFont_Outline_Small", 10, WHITE, "OUTLINE")
  FontObject("SystemFont_Large", 16, WHITE)
  FontObject("SystemFont_Huge1", 20, WHITE)
  FontObject("QuestFont", 13, { 0.18, 0.12, 0.06, 1 })
  FontObject("Game15Font", 15, WHITE)
  FontObject("Game18Font", 18, WHITE)
  FontObject("Game24Font", 24, WHITE)
  env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
  env.UNIT_NAME_FONT = "Fonts\\FRIZQT__.TTF"
  env.DAMAGE_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
  env.NAMEPLATE_FONT = "Fonts\\FRIZQT__.TTF"

  engine.RegisterTemplate("BackdropTemplate", function() end)
  engine.RegisterTemplate("UIPanelButtonTemplate", function(f)
    f:SetNormalFontObject("GameFontNormal")
    f._bg = { 0.5, 0.05, 0.05, 1 }
    f._backdrop = { bgFile = "Interface\\Buttons\\UI-Panel-Button-Up" }
  end)
  engine.RegisterTemplate("UIPanelCloseButton", function(f)
    f:SetSize(24, 24)
    f:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
  end)
  engine.RegisterTemplate("UICheckButtonTemplate", function(f)
    f:SetSize(26, 26)
    f:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    f.Text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.Text:SetPoint("LEFT", f, "RIGHT", 2, 0)
    f.text = f.Text
  end)
  engine.RegisterTemplate("InputBoxTemplate", function(f)
    f:SetFontObject("ChatFontNormal")
    f._backdrop = { bgFile = "x", edgeFile = "x", edgeSize = 1 }
    f._bg = { 0, 0, 0, 0.6 }
    f._border = { 0.4, 0.4, 0.4, 1 }
  end)
  engine.RegisterTemplate("GameTooltipTemplate", function(f)
    f._backdrop = { bgFile = "x", edgeFile = "x", edgeSize = 1 }
    f._bg = { 0.05, 0.05, 0.1, 0.92 }
    f._border = { 0.6, 0.6, 0.6, 1 }
    f._strata = "TOOLTIP"
  end)
  engine.RegisterTemplate("SecureActionButtonTemplate", function() end)
  engine.RegisterTemplate("SecureHandlerStateTemplate", function() end)
  engine.RegisterTemplate("UIPanelScrollFrameTemplate", function(f)
    f.ScrollBar = engine.CreateFrame("Slider", nil, f)
  end)
  engine.RegisterTemplate("OptionsSliderTemplate", function(f)
    f.Text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.Text:SetPoint("BOTTOM", f, "TOP", 0, 0)
    f.Low = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.Low:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 0)
    f.High = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.High:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, 0)
  end)
  engine.RegisterTemplate("ChatConfigCheckButtonTemplate", function(f)
    f.Text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.Text:SetPoint("LEFT", f, "RIGHT", 2, 0)
  end)

  -- Tooltips and standard Blizzard frames the addon hooks into.
  local function StdTooltip(name)
    local tip = engine.CreateFrame("GameTooltip", name, engine.UIParent, "GameTooltipTemplate")
    tip:Hide()
    return tip
  end
  StdTooltip("GameTooltip")
  StdTooltip("ItemRefTooltip")
  StdTooltip("ShoppingTooltip1")
  StdTooltip("EmbeddedItemTooltip")
  local chatFrame = engine.CreateFrame("MessageFrame", "ChatFrame1", engine.UIParent)
  env.DEFAULT_CHAT_FRAME = chatFrame
  env.SELECTED_CHAT_FRAME = chatFrame
  env.NUM_CHAT_WINDOWS = 1
  env.ChatFrame1EditBox = engine.CreateFrame("EditBox", "ChatFrame1EditBox", chatFrame)
  env.ChatFrame1EditBox:Hide()
  chatFrame:SetPoint("BOTTOMLEFT", engine.UIParent, "BOTTOMLEFT", 30, 120)
  chatFrame:SetSize(430, 180)
  engine.onChatFrameMessage = function(frame, text)
    world.Log("print", text, client)
  end
  env.GetChatWindowInfo = function(i)
    return "General", 14, 1, 1, 1, 1, true, false, i
  end
  env.FCF_OpenNewWindow = function() end
  env.FCF_SelectChatFrame = function() end
  env.ChatFrame_RemoveAllMessageGroups = function() end
  env.ChatFrame_AddMessageEventFilter = function() end
  env.ChatFrame_RemoveMessageEventFilter = function() end
  env.ChatFrame_OpenChat = function() end
  env.ChatEdit_GetActiveWindow = function() end
  env.ChatEdit_InsertLink = function()
    return false
  end
  local function HiddenBlizzardFrame(name, frameType)
    local f = engine.CreateFrame(frameType or "Frame", name, engine.UIParent)
    f:Hide()
    return f
  end
  local gameMenu = HiddenBlizzardFrame("GameMenuFrame")
  gameMenu:SetPoint("CENTER")
  gameMenu:SetSize(220, 360)
  env.GameMenuFrameCloseButton = engine.CreateFrame("Button", "GameMenuFrameCloseButton", gameMenu)
  local pve = HiddenBlizzardFrame("PVEFrame")
  pve:SetSize(560, 430)
  pve:SetPoint("TOPLEFT", 16, -116)
  local lfgList = engine.CreateFrame("Frame", "LFGListFrame", pve)
  lfgList:SetAllPoints(pve)
  lfgList.SearchPanel = engine.CreateFrame("Frame", nil, lfgList)
  lfgList.ApplicationViewer = engine.CreateFrame("Frame", nil, lfgList)
  lfgList.SearchPanel.ScrollBox = engine.CreateFrame("Frame", nil, lfgList.SearchPanel)
  lfgList.ApplicationViewer.ScrollBox = engine.CreateFrame("Frame", nil, lfgList.ApplicationViewer)
  HiddenBlizzardFrame("LFGInvitePopup")
  HiddenBlizzardFrame("ReadyCheckFrame")
  HiddenBlizzardFrame("ReadyCheckListenerFrame")
  HiddenBlizzardFrame("StaticPopup1")
  HiddenBlizzardFrame("ChallengesKeystoneFrame")
  HiddenBlizzardFrame("ScenarioObjectiveTracker")
  HiddenBlizzardFrame("ObjectiveTrackerFrame")
  HiddenBlizzardFrame("SettingsPanel")
  HiddenBlizzardFrame("InterfaceOptionsFrame")
  HiddenBlizzardFrame("PlayerFrame")
  HiddenBlizzardFrame("TargetFrame")
  HiddenBlizzardFrame("CompactRaidFrameManager")
  HiddenBlizzardFrame("PartyFrame")
  local minimap = engine.CreateFrame("Frame", "Minimap", engine.UIParent)
  minimap:SetSize(200, 200)
  minimap:SetPoint("TOPRIGHT", engine.UIParent, "TOPRIGHT", -20, -20)
  minimap._backdrop = { bgFile = "x" }
  minimap._bg = { 0.1, 0.16, 0.1, 0.5 }
  env.MinimapCluster = engine.CreateFrame("Frame", "MinimapCluster", engine.UIParent)

  env.StaticPopupDialogs = {}
  env.StaticPopup_Show = function(which, text1)
    world.Log("note", "StaticPopup_Show " .. tostring(which) .. " " .. tostring(text1 or ""), client)
    return env.StaticPopup1
  end
  env.StaticPopup_Hide = function() end
  env.StaticPopup_Visible = function()
    return nil
  end
  env.HideUIPanel = function(f)
    if f and f.Hide then
      f:Hide()
    end
  end
  env.ShowUIPanel = function(f)
    if f and f.Show then
      f:Show()
    end
  end
  env.PVEFrame_ToggleFrame = function()
    env.PVEFrame:SetShown(not env.PVEFrame:IsShown())
  end
  env.ToggleGameMenu = function()
    env.GameMenuFrame:SetShown(not env.GameMenuFrame:IsShown())
  end
  for _, name in ipairs({
    "ToggleQuestLog",
    "ToggleProfessionsBook",
    "ToggleGuildFrame",
    "ToggleEncounterJournal",
    "ToggleCollectionsJournal",
    "ToggleAchievementFrame",
    "TogglePlayerSpellsFrame",
    "ToggleCharacter",
    "ToggleFriendsFrame",
  }) do
    env[name] = function()
      world.Log("note", name .. "()", client)
    end
  end
  env.UIParentLoadAddOn = function()
    return true
  end
  env.CooldownFrame_Set = function(cd, start, duration)
    if cd and cd.SetCooldown then
      cd:SetCooldown(start, duration)
    end
  end
  env.CooldownFrame_Clear = function(cd)
    if cd and cd.Clear then
      cd:Clear()
    end
  end
  env.SquareButton_SetIcon = function() end
  env.SetPortraitTexture = function() end
  env.SetPortraitToTexture = function() end
  env.RegisterStateDriver = function() end
  env.UnregisterStateDriver = function() end
  env.RegisterAttributeDriver = function() end
  env.GetUIPanel = function() end
  env.UISpecialFrames = {}
  env.BackdropTemplateMixin = {
    OnBackdropLoaded = function() end,
    SetBackdrop = function(self, b)
      self._backdrop = b
    end,
  }
  env.BACKDROP_TOOLTIP_16_16_5555 = { bgFile = "x", edgeFile = "x", edgeSize = 16 }
  env.TooltipDataProcessor = { AddTooltipPostCall = function() end }
  env.ScrollBoxUtil = {
    OnViewFramesChanged = function() end,
    OnViewScrollChanged = function() end,
  }
  env.ScrollUtil = { AddInitializedFrameCallback = function() end, AddAcquiredFrameCallback = function() end }
  env.EventRegistry = {
    RegisterCallback = function() end,
    UnregisterCallback = function() end,
    TriggerEvent = function() end,
  }
  env.Menu = { ModifyMenu = function() end }
  env.MenuUtil = { CreateContextMenu = function() end, CreateRadioMenu = function() end }
  -- Like the client, opening a canvas category shows Blizzard's SettingsPanel
  -- with the addon's registered frame docked into its content area.
  local settingsCategories = {}
  local function OpenSettingsCategory(categoryID)
    world.Log("note", "Settings.OpenToCategory " .. tostring(categoryID), client)
    local category = settingsCategories[categoryID] or settingsCategories[next(settingsCategories) or ""]
    local panel = env.SettingsPanel
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", engine.UIParent, "CENTER", 0, 0)
    panel:SetSize(1000, 720)
    panel:SetFrameStrata("HIGH")
    panel._backdrop = { bgFile = "x", edgeFile = "x", edgeSize = 1 }
    panel._bg = { 0.06, 0.06, 0.07, 0.97 }
    panel._border = { 0.35, 0.35, 0.38, 1 }
    if category and category.frame then
      local frame = category.frame
      frame:SetParent(panel)
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 230, -40)
      frame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -20, 20)
      frame:Show()
    end
    panel:Show()
  end
  env.Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
      local category = {
        ID = name or "isiLive",
        name = name,
        frame = frame,
      }
      function category.GetID()
        return category.ID
      end
      settingsCategories[category.ID] = category
      return category
    end,
    RegisterCanvasLayoutSubcategory = function(_, frame, name)
      return { ID = name, frame = frame }
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = OpenSettingsCategory,
  }
  env.SlashCmdList = env.SlashCmdList or {}
  env.hash_SlashCmdList = {}
end

local function InstallConstants(ctx)
  local world = ctx.world
  local env = ctx.env
  -- Constants ------------------------------------------------------------------
  env.YES, env.NO, env.OKAY, env.CANCEL, env.CLOSE, env.ACCEPT = "Yes", "No", "Okay", "Cancel", "Close", "Accept"
  env.NONE = "None"
  env.UNKNOWN = "Unknown"
  env.ERR_UNINVITE_YOU = "You have been removed from the group."
  env.ERR_PET_SPELL_NOPATH = "No path available"
  env.DUNGEON_DIFFICULTY_MYTHIC_KEYSTONE = "Mythic Keystone"
  env.LE_PARTY_CATEGORY_HOME = 1
  env.LE_PARTY_CATEGORY_INSTANCE = 2
  env.NORMAL_FONT_COLOR = CreateColor(1, 0.82, 0, 1)
  env.HIGHLIGHT_FONT_COLOR = CreateColor(1, 1, 1, 1)
  env.RED_FONT_COLOR = CreateColor(1, 0.1, 0.1, 1)
  env.GREEN_FONT_COLOR = CreateColor(0.1, 1, 0.1, 1)
  env.GRAY_FONT_COLOR = CreateColor(0.5, 0.5, 0.5, 1)
  env.DISABLED_FONT_COLOR = CreateColor(0.5, 0.5, 0.5, 1)
  env.WHITE_FONT_COLOR = CreateColor(1, 1, 1, 1)
  env.YELLOW_FONT_COLOR = CreateColor(1, 1, 0, 1)
  env.ORANGE_FONT_COLOR = CreateColor(1, 0.5, 0.25, 1)
  env.LIGHTBLUE_FONT_COLOR = CreateColor(0.53, 0.67, 1, 1)
  env.SOUNDKIT = setmetatable({}, {
    __index = function(t, k)
      local id = 800000 + (#tostring(k) * 97) % 9999
      rawset(t, k, id)
      return id
    end,
  })
  env.RAID_CLASS_COLORS = {}
  env.CLASS_SORT_ORDER = {}
  env.LOCALIZED_CLASS_NAMES_MALE = {}
  env.LOCALIZED_CLASS_NAMES_FEMALE = {}
  for file, c in pairs(CLASS_COLORS) do
    local color = CreateColor(c[1], c[2], c[3], 1)
    color.colorStr = Hex(c)
    env.RAID_CLASS_COLORS[file] = color
    env.CLASS_SORT_ORDER[#env.CLASS_SORT_ORDER + 1] = file
    env.LOCALIZED_CLASS_NAMES_MALE[file] = CLASS_NAMES[file]
    env.LOCALIZED_CLASS_NAMES_FEMALE[file] = CLASS_NAMES[file]
  end
  env.GetClassColor = function(file)
    local c = env.RAID_CLASS_COLORS[file]
    if not c then
      return 1, 1, 1, "ffffffff"
    end
    return c.r, c.g, c.b, c.colorStr
  end
  env.C_ClassColor = {
    GetClassColor = function(file)
      return env.RAID_CLASS_COLORS[file]
    end,
  }
  env.GetClassInfo = function(classID)
    for file, id in pairs(world.CLASS_IDS or {}) do
      if id == classID then
        return CLASS_NAMES[file], file, id
      end
    end
    return nil
  end
  env.GetNumClasses = function()
    return 13
  end
  env.Enum = {
    PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, RunicPower = 6 },
    ItemQuality = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 },
    ChatChannelType = { None = 0 },
    SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, ChannelThrottle = 8, GeneralError = 9 },
    TooltipDataType = { Unit = 2, Spell = 1, Item = 0 },
    LFGListFilter = { Recommended = 1, NotRecommended = 2 },
    VoiceTtsDestination = { LocalPlayback = 1 },
    DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3 },
    DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 },
  }
  env.C_Constants = {}
  env.Constants = {}
end

local function InstallCVarsAndBindings(ctx)
  local env = ctx.env
  -- CVars and bindings ----------------------------------------------------------
  local cvars = {
    uiScale = "1",
    useUiScale = "0",
    nameplateShowEnemies = "1",
    Sound_EnableAllSound = "1",
    Sound_MasterVolume = "1",
  }
  env.GetCVar = function(k)
    return cvars[k]
  end
  env.SetCVar = function(k, v)
    cvars[k] = tostring(v)
    return true
  end
  env.GetCVarBool = function(k)
    return cvars[k] == "1"
  end
  env.GetCVarDefault = function()
    return "0"
  end
  env.C_CVar =
    { GetCVar = env.GetCVar, SetCVar = env.SetCVar, GetCVarBool = env.GetCVarBool, RegisterCVar = function() end }
  env.GetBindingKey = function() end
  env.GetBindingAction = function()
    return ""
  end
  env.GetBindingText = function(k)
    return k
  end
  env.SetBinding = function()
    return true
  end
  env.SetBindingClick = function()
    return true
  end
  env.SetOverrideBindingClick = function() end
  env.SetOverrideBinding = function() end
  env.ClearOverrideBindings = function() end
  env.SaveBindings = function() end
  env.LoadBindings = function() end
  env.GetCurrentBindingSet = function()
    return 1
  end
end

local function InstallAddons(ctx)
  local env = ctx.env
  -- Addons -----------------------------------------------------------------------
  local addonMeta = ctx.addonMeta or {}
  local function GetAddOnMetadata(name, field)
    if name == "isiLive" or name == 1 then
      return addonMeta[field]
    end
    return nil
  end
  env.C_AddOns = {
    GetAddOnMetadata = GetAddOnMetadata,
    IsAddOnLoaded = function(name)
      return name == "isiLive", name == "isiLive"
    end,
    IsAddOnLoadOnDemand = function()
      return false
    end,
    LoadAddOn = function()
      return false, "MISSING"
    end,
    GetNumAddOns = function()
      return 1
    end,
    GetAddOnInfo = function(i)
      if i == 1 or i == "isiLive" then
        return "isiLive", addonMeta.Title, addonMeta.Notes, true, nil, "INSECURE", false
      end
      return nil
    end,
    GetAddOnEnableState = function(name)
      return (name == "isiLive") and 2 or 0
    end,
    GetAddOnDependencies = function() end,
    DoesAddOnExist = function(name)
      return name == "isiLive"
    end,
  }
  env.GetAddOnMetadata = GetAddOnMetadata
  env.IsAddOnLoaded = env.C_AddOns.IsAddOnLoaded
  env.GetAddOnInfo = env.C_AddOns.GetAddOnInfo
  env.GetAddOnEnableState = function(_, name)
    return env.C_AddOns.GetAddOnEnableState(name)
  end
  env.LibStub = nil
end

local function InstallSound(ctx)
  local world = ctx.world
  local client = ctx.client
  local env = ctx.env
  -- Sound ------------------------------------------------------------------------
  local soundHandle = 0
  env.PlaySound = function(kit, channel)
    soundHandle = soundHandle + 1
    world.Log("sound", string.format("PlaySound %s [%s]", tostring(kit), tostring(channel or "SFX")), client)
    return true, soundHandle
  end
  env.PlaySoundFile = function(path, channel)
    soundHandle = soundHandle + 1
    world.Log("sound", string.format("PlaySoundFile %s [%s]", tostring(path), tostring(channel or "SFX")), client)
    return true, soundHandle
  end
  env.StopSound = function() end
  env.C_Sound = {
    IsPlaying = function()
      return false
    end,
    PlayItemSound = function() end,
  }
  env.C_VoiceChat = {
    SpeakText = function(_, text)
      world.Log("sound", "TTS: " .. tostring(text), client)
    end,
    GetTtsVoices = function()
      return { { voiceID = 0, name = "Sim Voice" } }
    end,
  }
  env.C_TTSSettings = {
    GetVoiceOptionID = function()
      return 0
    end,
    GetSpeechRate = function()
      return 0
    end,
    GetSpeechVolume = function()
      return 100
    end,
  }
end

local function InstallTimers(ctx)
  local client = ctx.client
  local env = ctx.env
  local clock = ctx.world.clock
  -- Timers -----------------------------------------------------------------------
  local function NewTimerHandle(timer)
    local handle = {}
    function handle:Cancel()
      timer.cancelled = true
      handle._cancelled = true
    end
    function handle:IsCancelled()
      return handle._cancelled == true
    end
    return handle
  end
  local function ScheduleChecked(seconds, fn)
    local timer = clock.after(seconds, function()
      fn()
    end)
    timer.client = client
    return timer
  end
  env.C_Timer = {
    After = function(seconds, fn)
      ScheduleChecked(seconds, fn)
    end,
    NewTimer = function(seconds, fn)
      local handle
      local timer = ScheduleChecked(seconds, function()
        if not handle._cancelled then
          fn(handle)
        end
      end)
      handle = NewTimerHandle(timer)
      return handle
    end,
    NewTicker = function(seconds, fn, iterations)
      local handle = { _cancelled = false }
      local count = 0
      local function Tick()
        if handle._cancelled then
          return
        end
        count = count + 1
        fn(handle)
        if not handle._cancelled and (not iterations or count < iterations) then
          handle._timer = ScheduleChecked(seconds, Tick)
        end
      end
      handle._timer = ScheduleChecked(seconds, Tick)
      function handle:Cancel()
        handle._cancelled = true
        if handle._timer then
          handle._timer.cancelled = true
        end
      end
      function handle:IsCancelled()
        return handle._cancelled
      end
      return handle
    end,
  }
end

local function InstallUnits(ctx)
  local world = ctx.world
  local client = ctx.client
  local env = ctx.env
  -- Units ------------------------------------------------------------------------
  local function MemberByUnit(unit)
    if type(unit) ~= "string" then
      return nil
    end
    unit = unit:lower()
    if unit == "player" then
      return client.member
    end
    local idx = unit:match("^party(%d)$")
    if idx then
      if not client.member.inGroup then
        return nil
      end
      local others = {}
      for _, m in ipairs(world.members) do
        if m ~= client.member and m.inGroup then
          others[#others + 1] = m
        end
      end
      return others[tonumber(idx)]
    end
    local raidIdx = unit:match("^raid(%d+)$")
    if raidIdx then
      return nil
    end
    -- Names ("Tankbro" / "Tankbro-Blackrock") are valid unit IDs for group members.
    for _, m in ipairs(world.members) do
      if m.inGroup or m == client.member then
        if unit == m.name:lower() or unit == world.MemberFullName(m):lower() then
          return m
        end
      end
    end
    return nil
  end
  client.MemberByUnit = MemberByUnit
  local function UnitTokenOf(member)
    if member == client.member then
      return "player"
    end
    for i = 1, 4 do
      if MemberByUnit("party" .. i) == member then
        return "party" .. i
      end
    end
    return nil
  end
  client.UnitTokenOf = UnitTokenOf

  local function RealmOf(m)
    if m.realm == client.member.realm then
      return nil
    end
    return m.realm
  end

  env.UnitExists = function(unit)
    return MemberByUnit(unit) ~= nil
  end
  env.UnitName = function(unit)
    local m = MemberByUnit(unit)
    if not m then
      return nil
    end
    return m.name, RealmOf(m)
  end
  env.UnitNameUnmodified = env.UnitName
  env.UnitFullName = function(unit)
    local m = MemberByUnit(unit)
    if not m then
      return nil
    end
    if m == client.member then
      return m.name, m.realm
    end
    return m.name, RealmOf(m)
  end
  env.GetUnitName = function(unit, showServer)
    local m = MemberByUnit(unit)
    if not m then
      return nil
    end
    local realm = RealmOf(m)
    if showServer and realm then
      return m.name .. "-" .. realm
    end
    return m.name
  end
  env.UnitGUID = function(unit)
    local m = MemberByUnit(unit)
    return m and m.guid or nil
  end
  env.UnitTokenFromGUID = function(guid)
    for _, m in ipairs(world.members) do
      if m.guid == guid then
        return UnitTokenOf(m)
      end
    end
    return nil
  end
  env.UnitClass = function(unit)
    local m = MemberByUnit(unit)
    if not m then
      return nil
    end
    return CLASS_NAMES[m.class], m.class, m.classID
  end
  env.UnitClassBase = function(unit)
    local m = MemberByUnit(unit)
    if not m then
      return nil
    end
    return m.class, m.classID
  end
  env.UnitRace = function(unit)
    local m = MemberByUnit(unit)
    if not m then
      return nil
    end
    return m.raceFile, m.raceFile, 1
  end
  env.UnitSex = function(unit)
    local m = MemberByUnit(unit)
    return m and m.sex or nil
  end
  env.UnitLevel = function(unit)
    local m = MemberByUnit(unit)
    return m and m.level or 0
  end
  env.UnitEffectiveLevel = env.UnitLevel
  env.UnitGroupRolesAssigned = function(unit)
    local m = MemberByUnit(unit)
    if not m or not m.inGroup then
      return "NONE"
    end
    return m.role
  end
  env.UnitIsGroupLeader = function(unit)
    local m = MemberByUnit(unit)
    return m ~= nil and m.inGroup and world.members[world.leaderIndex] == m
  end
  env.UnitIsGroupAssistant = function()
    return false
  end
  env.UnitIsLieutenant = function()
    return false
  end
  env.UnitIsConnected = function(unit)
    local m = MemberByUnit(unit)
    return m ~= nil and m.connected
  end
  env.UnitIsVisible = function(unit)
    return MemberByUnit(unit) ~= nil
  end
  env.UnitInParty = function(unit)
    local m = MemberByUnit(unit)
    return m ~= nil and m.inGroup
  end
  env.UnitInRaid = function()
    return nil
  end
  env.UnitIsUnit = function(a, b)
    local ma, mb = MemberByUnit(a), MemberByUnit(b)
    return ma ~= nil and ma == mb
  end
  env.UnitIsPlayer = function(unit)
    return MemberByUnit(unit) ~= nil
  end
  env.UnitPlayerControlled = env.UnitIsPlayer
  env.UnitIsDead = function(unit)
    local m = MemberByUnit(unit)
    return m ~= nil and m.dead
  end
  env.UnitIsDeadOrGhost = env.UnitIsDead
  env.UnitIsGhost = function()
    return false
  end
  env.UnitIsFeignDeath = function()
    return false
  end
  env.UnitHealth = function(unit)
    local m = MemberByUnit(unit)
    if not m then
      return 0
    end
    return m.dead and 0 or math.floor(m.health * 500000)
  end
  env.UnitHealthMax = function(unit)
    return MemberByUnit(unit) and 500000 or 0
  end
  env.UnitHealthPercent = function(unit)
    local m = MemberByUnit(unit)
    if not m then
      return 0
    end
    return m.dead and 0 or m.health * 100
  end
  env.UnitPower = function()
    return 100
  end
  env.UnitPowerMax = function()
    return 100
  end
  env.UnitPowerType = function()
    return 0, "MANA"
  end
  env.UnitHasPowerType = function()
    return true
  end
  env.UnitAffectingCombat = function()
    return client.inCombat == true
  end
  env.UnitReaction = function()
    return 5
  end
  env.UnitCanAttack = function()
    return false
  end
  env.UnitCanCooperate = function()
    return true
  end
  env.UnitClassification = function()
    return "normal"
  end
  env.UnitCreatureType = function()
    return nil
  end
  env.UnitIsEnemy = function()
    return false
  end
  env.UnitIsFriend = function()
    return true
  end
  env.UnitStat = function()
    return 50000, 50000, 0, 0
  end
  env.UnitSpellHaste = function()
    return 25
  end
  env.UnitAura = function() end
  env.UnitBuff = function() end
  env.UnitDebuff = function() end
  env.UnitCastingInfo = function() end
  env.UnitChannelInfo = function() end
  env.UnitInRange = function()
    return true, true
  end
  env.UnitPosition = function()
    return 0, 0, 0, 0
  end
  env.UnitInPhase = function()
    return true
  end
  env.UnitPhaseReason = function()
    return nil
  end
  env.UnitHasVehicleUI = function()
    return false
  end
  env.UnitIsAFK = function()
    return false
  end
  env.UnitIsDND = function()
    return false
  end
  env.UnitFactionGroup = function()
    return "Alliance", "Alliance"
  end
  env.GetRealmName = function()
    return client.member.realm
  end
  env.GetNormalizedRealmName = function()
    return (client.member.realm:gsub("[%s%-']", ""))
  end
  env.GetRealmID = function()
    return 1403
  end
  env.Ambiguate = function(name, context)
    name = tostring(name or "")
    local base, realm = name:match("^([^%-]+)%-(.+)$")
    if base and realm == client.member.realm then
      return base
    end
    if context == "short" and base then
      return base
    end
    return name
  end
  env.C_PlayerInfo = {
    GetPlayerMythicPlusRatingSummary = function(unit)
      local m = MemberByUnit(unit)
      if not m then
        return nil
      end
      return { currentSeasonScore = m.rating, runs = {} }
    end,
    GUIDIsPlayer = function()
      return true
    end,
    UnitIsSameServer = function()
      return true
    end,
    GetClass = function()
      return CLASS_NAMES[client.member.class], client.member.class, client.member.classID
    end,
    IsPlayerNPERestricted = function()
      return false
    end,
    CanPlayerUseMountEquipment = function()
      return false
    end,
  }
  env.C_PlayerMythicPlus = env.C_PlayerInfo
end

local function InstallSpecs(ctx)
  local world = ctx.world
  local client = ctx.client
  local env = ctx.env
  local clock = ctx.world.clock
  local MemberByUnit = ctx.client.MemberByUnit
  -- Specs ----------------------------------------------------------------------
  local function SpecInfo(specID)
    local spec = world.specManifest[specID] or {}
    return specID, spec.name or ("Spec" .. tostring(specID)), "", 136243, SPEC_ROLES[specID] or "DAMAGER", spec.class
  end
  env.GetSpecialization = function()
    return client.member.specID and 1 or nil
  end
  env.GetSpecializationInfo = function(index)
    if index ~= 1 then
      return nil
    end
    return SpecInfo(client.member.specID)
  end
  env.GetSpecializationRole = function()
    return client.member.role
  end
  env.GetSpecializationInfoByID = function(specID)
    if not specID or specID == 0 then
      return nil
    end
    local id, name, desc, icon, role, class = SpecInfo(specID)
    return id, name, desc, icon, role, class, CLASS_NAMES[class or ""]
  end
  env.GetSpecializationInfoForClassID = function(classID, index)
    return nil
  end
  env.GetSpecializationRoleByID = function(specID)
    return SPEC_ROLES[specID] or "DAMAGER"
  end
  env.GetNumSpecializations = function()
    return 3
  end
  env.GetNumSpecializationsForClassID = function()
    return 3
  end
  env.C_SpecializationInfo = {
    GetSpecialization = env.GetSpecialization,
    GetSpecializationInfo = env.GetSpecializationInfo,
    IsInitialized = function()
      return true
    end,
  }
  env.GetInspectSpecialization = function(unit)
    local m = MemberByUnit(unit)
    return m and m.specID or 0
  end
  env.CanInspect = function(unit)
    return MemberByUnit(unit) ~= nil
  end
  env.CheckInteractDistance = function()
    return true
  end
  env.NotifyInspect = function(unit)
    local m = MemberByUnit(unit)
    if not m then
      return
    end
    clock.after(0.3, function()
      client.Fire("INSPECT_READY", m.guid)
    end)
  end
  env.ClearInspectPlayer = function() end
  env.C_PaperDollInfo = {
    GetInspectItemLevel = function(unit)
      local m = MemberByUnit(unit)
      return m and m.ilvl or 0
    end,
    OffhandHasWeapon = function()
      return false
    end,
  }
  env.GetAverageItemLevel = function()
    return client.member.ilvl, client.member.ilvl, client.member.ilvl
  end
  env.GetCombatRating = function()
    return 1000
  end
  env.GetCombatRatingBonus = function()
    return 10
  end
  env.GetInventoryItemDurability = function()
    return 100, 100
  end
  env.GetInventoryItemLink = function() end
  env.GetInventoryItemID = function() end
  env.C_Traits = { GetConfigInfo = function() end }
  env.C_ClassTalents = {
    GetActiveConfigID = function()
      return nil
    end,
  }
end

local function InstallGroup(ctx)
  local world = ctx.world
  local client = ctx.client
  local env = ctx.env
  local MemberByUnit = ctx.client.MemberByUnit
  -- Group --------------------------------------------------------------------
  local function GroupSize()
    if not client.member.inGroup then
      return 0
    end
    local n = 0
    for _, m in ipairs(world.members) do
      if m.inGroup then
        n = n + 1
      end
    end
    return n
  end
  env.IsInGroup = function(category)
    if category == env.LE_PARTY_CATEGORY_INSTANCE then
      return false
    end
    return GroupSize() > 1
  end
  env.IsInRaid = function()
    return false
  end
  env.IsInInstance = function()
    if world.instance then
      return true, world.instance.type or "party"
    end
    return false, "none"
  end
  env.GetNumGroupMembers = function()
    local n = GroupSize()
    return n > 1 and n or 0
  end
  env.GetNumSubgroupMembers = function()
    local n = GroupSize()
    return n > 1 and n - 1 or 0
  end
  env.UnitIsGroupLeader = env.UnitIsGroupLeader
  env.GetReadyCheckStatus = function(unit)
    local m = MemberByUnit(unit)
    return m and m.readyStatus or nil
  end
  env.GetReadyCheckTimeLeft = function()
    return 0
  end
  env.DoReadyCheck = function()
    world.Log("note", client.member.name .. " started a ready check", client)
    if world.onReadyCheck then
      world.onReadyCheck(client)
    end
  end
  env.ConfirmReadyCheck = function() end
  env.C_PartyInfo = {
    IsPartyFull = function()
      return GroupSize() >= 5
    end,
    DoCountdown = function(seconds)
      world.Log("note", client.member.name .. " started a countdown " .. tostring(seconds), client)
      return true
    end,
    LeaveParty = function()
      world.Log("note", client.member.name .. " leaves the party", client)
    end,
    InviteUnit = function(name)
      world.Log("note", "InviteUnit " .. tostring(name), client)
    end,
    ConvertToRaid = function() end,
    GetMinLevel = function()
      return 10
    end,
    IsDelveInProgress = function()
      return false
    end,
    IsChallengeModeKeystoneOwner = function()
      return false
    end,
  }
  env.InviteUnit = env.C_PartyInfo.InviteUnit
  env.LeaveParty = env.C_PartyInfo.LeaveParty
  env.SetRaidTarget = function(unit, index)
    world.Log("note", string.format("SetRaidTarget %s %s", tostring(unit), tostring(index)), client)
  end
  env.GetRaidTargetIndex = function()
    return nil
  end
  env.InCombatLockdown = function()
    return client.inCombat == true
  end
  env.IsResting = function()
    return world.instance == nil
  end
  env.C_IncomingSummon = {
    HasIncomingSummon = function()
      return false
    end,
    IncomingSummonStatus = function()
      return 0
    end,
  }
  env.C_SummonInfo = {
    GetSummonConfirmTimeLeft = function()
      return 0
    end,
  }
end

local function InstallZonesAndInstances(ctx)
  local world = ctx.world
  local env = ctx.env
  -- Zones and instances ----------------------------------------------------------
  env.GetZoneText = function()
    return world.instance and world.instance.name or world.zone
  end
  env.GetRealZoneText = env.GetZoneText
  env.GetSubZoneText = function()
    return ""
  end
  env.GetMinimapZoneText = env.GetZoneText
  env.GetInstanceInfo = function()
    local inst = world.instance
    if not inst then
      return world.zone, "none", 0, "", 0, 0, false, 2552, 0, nil
    end
    return inst.name,
      inst.type or "party",
      inst.difficultyID or 8,
      "Mythic Keystone",
      5,
      0,
      false,
      inst.instanceID or 0,
      5,
      nil
  end
  env.GetDifficultyInfo = function(id)
    if id == 8 then
      return "Mythic Keystone", "party", false, true
    end
    return "Normal", "party"
  end
  env.C_Map = {
    GetBestMapForUnit = function()
      return world.instance and world.instance.uiMapID or 2339
    end,
    GetMapInfo = function(mapID)
      local name = world.instance and world.instance.name or world.zone
      return { mapID = mapID, name = name, mapType = 3, parentMapID = 0 }
    end,
    GetPlayerMapPosition = function()
      return nil
    end,
  }
  env.EJ_GetInstanceInfo = function()
    return nil
  end
  env.C_EncounterJournal = {
    GetDungeonEntrancesForMap = function()
      return {}
    end,
    GetInstanceForGameMap = function()
      return nil
    end,
  }
end

local function InstallChallengeMode(ctx)
  local world = ctx.world
  local client = ctx.client
  local env = ctx.env
  -- Challenge mode / Mythic+ ---------------------------------------------------
  local function ChallengeMapInfo(mapID)
    local maps = world.challengeMaps or {}
    return maps[mapID]
  end
  env.C_ChallengeMode = {
    GetActiveChallengeMapID = function()
      local c = world.challenge
      if c and not c.completed then
        return c.mapID
      end
      return nil
    end,
    GetActiveKeystoneInfo = function()
      local c = world.challenge
      if not c then
        return 0, {}, false
      end
      return c.level, c.affixes or {}, true
    end,
    GetMapUIInfo = function(mapID)
      local info = ChallengeMapInfo(mapID)
      if not info then
        return nil
      end
      return info.name, mapID, info.timeLimit, 525134, 525134
    end,
    GetMapTable = function()
      local list = {}
      for mapID in pairs(world.challengeMaps or {}) do
        list[#list + 1] = mapID
      end
      table.sort(list)
      return list
    end,
    GetDeathCount = function()
      local c = world.challenge
      if not c then
        return 0, 0
      end
      return c.deaths or 0, c.timeLost or 0
    end,
    GetChallengeCompletionInfo = function()
      local c = world.challenge
      if not c or not c.completed then
        return {}
      end
      return {
        mapChallengeModeID = c.mapID,
        level = c.level,
        time = math.floor((c.completedTime or 0) * 1000),
        onTime = c.onTime,
        keystoneUpgradeLevels = c.upgrades or 0,
        practiceRun = false,
        isAffixRecord = false,
        isMapRecord = false,
        isEligibleForScore = true,
        members = {},
      }
    end,
    GetAffixInfo = function(affixID)
      return "Affix" .. tostring(affixID), "", 0
    end,
    IsChallengeModeActive = function()
      return world.challenge ~= nil and not world.challenge.completed
    end,
    GetKeystoneLevelRarityColor = function()
      return CreateColor(0.64, 0.21, 0.93, 1)
    end,
    GetPowerLevelDamageHealthMod = function()
      return 100, 100
    end,
    SlotKeystone = function() end,
    CanUseKeystoneInCurrentMap = function()
      return true
    end,
    HasSlottedKeystone = function()
      return false
    end,
    GetStartTime = function()
      return world.challenge and world.challenge.startedAt or nil
    end,
  }
  env.GetWorldElapsedTime = function(timerID)
    local c = world.challenge
    if not c or c.completed then
      return 0, 0, 0
    end
    return 1, math.floor(world.t - c.startedAt), 2
  end
  env.GetWorldElapsedTimers = function()
    return 1
  end
  env.C_MythicPlus = {
    GetOwnedKeystoneChallengeMapID = function()
      local k = client.member.key
      return k and k.mapID or nil
    end,
    GetOwnedKeystoneLevel = function()
      local k = client.member.key
      return k and k.level or nil
    end,
    GetOwnedKeystoneMapID = function()
      local k = client.member.key
      return k and k.mapID or nil
    end,
    RequestMapInfo = function() end,
    RequestRewards = function() end,
    RequestCurrentAffixes = function() end,
    GetCurrentAffixes = function()
      return { { id = 9 }, { id = 10 }, { id = 147 } }
    end,
    GetSeasonBestForMap = function()
      return nil
    end,
    GetSeasonBestAffixScoreInfoForMap = function()
      return nil
    end,
    GetCurrentSeason = function()
      return 16
    end,
    GetRunHistory = function()
      return {}
    end,
    IsMythicPlusActive = function()
      return true
    end,
    GetOwnedKeystone = function() end,
  }
  env.C_ScenarioInfo = {
    GetScenarioStepInfo = function()
      local s = world.scenario
      if not s then
        return nil
      end
      return {
        title = s.title or "Mythic+",
        description = "",
        numCriteria = #s.bosses + 1,
        stepID = 1,
        isBonusStep = false,
      }
    end,
    GetCriteriaInfo = function(index)
      local s = world.scenario
      if not s then
        return nil
      end
      local boss = s.bosses[index]
      if boss then
        return {
          description = boss.name,
          criteriaType = 165,
          completed = boss.done == true,
          quantity = boss.done and 1 or 0,
          totalQuantity = 1,
          quantityString = boss.done and "1" or "0",
          isWeightedProgress = false,
          isFormatted = false,
          criteriaID = 1000 + index,
          duration = 0,
          elapsed = 0,
          failed = false,
        }
      end
      if index == #s.bosses + 1 then
        local pct = s.forcesTotal > 0 and math.floor(s.forcesCurrent / s.forcesTotal * 100) or 0
        return {
          description = "Enemy Forces",
          criteriaType = 0,
          completed = s.forcesCurrent >= s.forcesTotal,
          quantity = pct,
          totalQuantity = s.forcesTotal,
          quantityString = tostring(s.forcesCurrent),
          isWeightedProgress = true,
          isFormatted = true,
          criteriaID = 999,
          duration = 0,
          elapsed = 0,
          failed = false,
        }
      end
      return nil
    end,
    GetScenarioInfo = function()
      local s = world.scenario
      if not s then
        return nil
      end
      return { name = s.title or "Mythic+", currentStage = 1, numStages = 1, flags = 0, isComplete = false }
    end,
  }
  env.C_Scenario = {
    IsInScenario = function()
      return world.scenario ~= nil
    end,
    GetInfo = function()
      return world.scenario and (world.scenario.title or "Mythic+") or nil
    end,
  }
  ctx.ChallengeMapInfo = ChallengeMapInfo
end

local function InstallBagsAndItems(ctx)
  local client = ctx.client
  local env = ctx.env
  local ChallengeMapInfo = ctx.ChallengeMapInfo
  -- Bags and items -------------------------------------------------------------
  local function KeystoneLink()
    local k = client.member.key
    if not k then
      return nil
    end
    local info = ChallengeMapInfo(k.mapID)
    local name = info and info.name or ("Map " .. k.mapID)
    return string.format(
      "|cffa335ee|Hkeystone:180653:%d:%d:9:10:147:0|h[Keystone: %s (%d)]|h|r",
      k.mapID,
      k.level,
      name,
      k.level
    )
  end
  env.C_Container = {
    GetContainerNumSlots = function(bag)
      return bag == 0 and 16 or 0
    end,
    GetContainerItemLink = function(bag, slot)
      if bag == 0 and slot == 1 then
        return KeystoneLink()
      end
      return nil
    end,
    GetContainerItemID = function(bag, slot)
      if bag == 0 and slot == 1 and client.member.key then
        return 180653
      end
      return nil
    end,
    GetContainerItemInfo = function(bag, slot)
      if bag == 0 and slot == 1 and client.member.key then
        return { itemID = 180653, hyperlink = KeystoneLink(), stackCount = 1, quality = 4, iconFileID = 525134 }
      end
      return nil
    end,
    GetItemCooldown = function()
      return 0, 0, 1
    end,
    PickupContainerItem = function() end,
  }
  env.NUM_BAG_SLOTS = 4
  env.BACKPACK_CONTAINER = 0
  env.C_Item = {
    GetAverageItemLevel = function()
      return client.member.ilvl, client.member.ilvl, client.member.ilvl
    end,
    GetItemInfo = function(id)
      return "Item " .. tostring(id), nil, 4, 700, 0, "Misc", "Misc", 1, "", 134400
    end,
    GetItemInfoInstant = function(id)
      return id, "Misc", "Misc", "", 134400, 0, 0
    end,
    GetItemNameByID = function(id)
      return "Item " .. tostring(id)
    end,
    GetItemIconByID = function()
      return 134400
    end,
    GetItemCount = function()
      return 0
    end,
    IsItemDataCachedByID = function()
      return true
    end,
    RequestLoadItemDataByID = function() end,
    GetItemCooldown = function()
      return 0, 0, 1
    end,
    IsUsableItem = function()
      return true
    end,
    DoesItemExistByID = function()
      return true
    end,
    GetItemSpell = function() end,
    GetItemQualityColor = function()
      return 0.64, 0.21, 0.93, "ffa335ee"
    end,
  }
  env.GetItemInfo = env.C_Item.GetItemInfo
  env.GetItemCount = env.C_Item.GetItemCount
  env.GetItemCooldown = env.C_Item.GetItemCooldown
  env.Item = {
    CreateFromItemID = function(_, id)
      return {
        ContinueOnItemLoad = function(_, fn)
          fn()
        end,
        GetItemName = function()
          return "Item " .. tostring(id)
        end,
        GetItemIcon = function()
          return 134400
        end,
        IsItemEmpty = function()
          return false
        end,
        GetItemID = function()
          return id
        end,
      }
    end,
  }
  env.PlayerHasToy = function()
    return false
  end
  env.C_ToyBox = {
    GetToyInfo = function(id)
      return id, "Toy " .. tostring(id), 134400
    end,
    IsToyUsable = function()
      return false
    end,
    GetNumToys = function()
      return 0
    end,
    GetNumFilteredToys = function()
      return 0
    end,
  }
  env.C_MountJournal = {
    GetMountIDs = function()
      return {}
    end,
    GetNumMounts = function()
      return 0
    end,
    GetMountInfoByID = function() end,
    GetNumDisplayedMounts = function()
      return 0
    end,
  }
  env.C_Housing = {}
  env.C_Covenants = {
    GetActiveCovenantID = function()
      return 0
    end,
  }
  env.GetAchievementCriteriaInfo = function() end
  env.GetAchievementInfo = function() end
end

local function InstallSpells(ctx)
  local client = ctx.client
  local env = ctx.env
  -- Spells -------------------------------------------------------------------
  env.C_Spell = {
    GetSpellInfo = function(id)
      if not id then
        return nil
      end
      return {
        name = "Spell " .. tostring(id),
        iconID = 136243,
        spellID = tonumber(id) or 0,
        castTime = 0,
        minRange = 0,
        maxRange = 40,
        originalIconID = 136243,
      }
    end,
    GetSpellName = function(id)
      return id and ("Spell " .. tostring(id)) or nil
    end,
    GetSpellTexture = function()
      return 136243, 136243
    end,
    GetSpellCooldown = function()
      return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 }
    end,
    GetSpellCharges = function()
      return nil
    end,
    IsSpellUsable = function()
      return true, false
    end,
    GetSpellLink = function(id)
      return string.format("|cff71d5ff|Hspell:%d:0|h[Spell %d]|h|r", id or 0, id or 0)
    end,
    DoesSpellExist = function()
      return true
    end,
    IsSpellDataCached = function()
      return true
    end,
    RequestLoadSpellData = function() end,
    GetSpellDescription = function()
      return ""
    end,
    GetOverrideSpell = function(id)
      return id
    end,
    GetBaseSpell = function(id)
      return id
    end,
    IsSpellPassive = function()
      return false
    end,
    GetSpellCooldownDuration = function()
      return nil
    end,
  }
  env.C_SpellBook = {
    IsSpellKnown = function(id)
      return client.knownSpells and client.knownSpells[id] == true or false
    end,
    IsSpellInSpellBook = function(id)
      return client.knownSpells and client.knownSpells[id] == true or false
    end,
    FindSpellBookSlotForSpell = function() end,
    GetSpellBookItemInfo = function() end,
  }
  env.IsSpellKnown = env.C_SpellBook.IsSpellKnown
  env.IsPlayerSpell = env.C_SpellBook.IsSpellKnown
  env.IsSpellKnownOrOverridesKnown = env.C_SpellBook.IsSpellKnown
  env.GetSpellBaseCooldown = function()
    return 0, 0
  end
  env.GetSpellInfo = nil -- removed in 12.0; must stay nil
  env.GetActionInfo = function() end
  env.GetMacroSpell = function() end
  env.GetMacroInfo = function() end
  env.GetNumMacros = function()
    return 0, 0
  end
  env.CreateMacro = function() end
  env.EditMacro = function() end
  env.C_ActionBar = {
    FindSpellActionButtons = function()
      return {}
    end,
    GetActionTexture = function() end,
    HasAction = function()
      return false
    end,
  }
  env.C_UnitAuras = {
    GetAuraDataByIndex = function() end,
    GetBuffDataByIndex = function() end,
    GetDebuffDataByIndex = function() end,
    GetPlayerAuraBySpellID = function() end,
    GetAuraDataBySpellName = function() end,
    GetAuraDataByAuraInstanceID = function() end,
    GetUnitAuras = function()
      return {}
    end,
    GetAuraSlots = function() end,
  }
  env.AuraUtil = {
    ForEachAura = function() end,
    FindAuraByName = function() end,
  }
  env.C_CurveUtil = {
    CreateCurve = function()
      return {
        AddPoint = function() end,
        SetType = function() end,
        Evaluate = function()
          return 0
        end,
      }
    end,
    CreateColorCurve = function()
      return { AddPoint = function() end, SetType = function() end }
    end,
  }
  env.CreateCooldownDuration = nil
  env.C_DurationUtil = {
    CreateDuration = function()
      return {
        SetTimeFromStart = function() end,
        GetRemainingDuration = function()
          return 0
        end,
      }
    end,
  }
  env.C_NamePlate = {
    GetNamePlates = function()
      return {}
    end,
    GetNamePlateForUnit = function() end,
  }
  env.C_DamageMeter = nil
  env.C_TooltipInfo = {
    GetUnit = function()
      return nil
    end,
    GetSpellByID = function()
      return nil
    end,
    GetHyperlink = function()
      return nil
    end,
  }
  env.C_QuestLog = {
    IsOnQuest = function()
      return false
    end,
    GetLogIndexForQuestID = function() end,
    IsQuestFlaggedCompleted = function()
      return false
    end,
  }
  env.C_LFGList = {
    HasActiveEntryInfo = function()
      return false
    end,
    GetActiveEntryInfo = function()
      return nil
    end,
    GetApplications = function()
      return {}
    end,
    GetSearchResults = function()
      return 0, {}
    end,
    GetSearchResultInfo = function()
      return nil
    end,
    GetSearchResultMemberInfo = function() end,
    GetApplicationInfo = function()
      return nil
    end,
    GetActivityInfoTable = function()
      return nil
    end,
    GetApplicants = function()
      return {}
    end,
    GetApplicantInfo = function() end,
    GetApplicantMemberInfo = function() end,
    GetApplicantDungeonScoreForListing = function() end,
    GetSearchResultLeaderInfo = function() end,
    CanActiveEntryUseAutoAccept = function()
      return false
    end,
  }
  env.C_LFGInfo = {
    IsInLFGFollowerDungeon = function()
      return false
    end,
  }
  env.IsInLFGDungeon = function()
    return false
  end
  env.HasLFGRestrictions = function()
    return false
  end
  env.C_Reputation = {}
  env.C_CreatureInfo = {
    GetClassInfo = function(id)
      local name, file = env.GetClassInfo(id)
      return name and { className = name, classFile = file, classID = id } or nil
    end,
  }
  env.C_FriendList = {
    IsFriend = function()
      return false
    end,
    IsOnIgnoredList = function()
      return false
    end,
  }
  env.C_BattleNet = { GetFriendAccountInfo = function() end }
  env.BNGetNumFriends = function()
    return 0, 0
  end
  env.C_GuildInfo = {
    IsGuildOfficer = function()
      return false
    end,
  }
  env.IsInGuild = function()
    return false
  end
  env.GetGuildInfo = function() end
end

local function InstallChatAndAddonMessages(ctx)
  local world = ctx.world
  local client = ctx.client
  local env = ctx.env
  -- Chat and addon messages -------------------------------------------------------
  client.prefixes = client.prefixes or {}
  env.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix)
      client.prefixes[prefix] = true
      return true
    end,
    IsAddonMessagePrefixRegistered = function(prefix)
      return client.prefixes[prefix] == true
    end,
    GetRegisteredAddonMessagePrefixes = function()
      local list = {}
      for p in pairs(client.prefixes) do
        list[#list + 1] = p
      end
      return list
    end,
    SendAddonMessage = function(prefix, message, channel, target)
      if #tostring(message) > 255 then
        world.Log("error", "SendAddonMessage > 255 bytes: " .. tostring(prefix), client)
        return false, 9
      end
      if not client.member.inGroup and (channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT") then
        return false, 9
      end
      world.SendAddonMessage(client, prefix, message, channel, target)
      return true, 0
    end,
    SendAddonMessageLogged = function(prefix, message, channel, target)
      return env.C_ChatInfo.SendAddonMessage(prefix, message, channel, target)
    end,
    SendChatMessage = function(text, chatType)
      world.SendChatMessage(client, text, chatType)
    end,
    InChatMessagingLockdown = function()
      return false
    end,
    GetChannelName = function()
      return 0
    end,
    IsTimerunningPlayer = function()
      return false
    end,
  }
  env.RegisterAddonMessagePrefix = env.C_ChatInfo.RegisterAddonMessagePrefix
  env.SendAddonMessage = env.C_ChatInfo.SendAddonMessage
  env.SendChatMessage = function(text, chatType)
    world.SendChatMessage(client, text, chatType)
  end
  env.BNSendWhisper = function() end
  env.GetChannelName = function()
    return 0
  end
  env.C_Club = {}
end

local function InstallMisc(ctx)
  local world = ctx.world
  local client = ctx.client
  local env = ctx.env
  -- Misc -------------------------------------------------------------------------
  env.ReloadUI = function()
    world.Log("note", "ReloadUI()", client)
  end
  env.Logout = function() end
  env.Quit = function() end
  env.RepopMe = function() end
  env.AcceptGroup = function() end
  env.DeclineGroup = function() end
  env.ConfirmSummon = function() end
  env.CancelSummon = function() end
  env.GetSummonConfirmTimeLeft = function()
    return 0
  end
  env.GetNetStats = function()
    return 0, 0, 30, 30
  end
  env.GetGameTime = function()
    return 20, 0
  end
  env.C_DateAndTime = {
    GetCurrentCalendarTime = function()
      local d = os.date("*t", math.floor(world.epoch + world.t))
      return { year = d.year, month = d.month, monthDay = d.day, weekday = d.wday, hour = d.hour, minute = d.min }
    end,
    GetServerTimeLocal = function()
      return math.floor(world.epoch + world.t)
    end,
    GetSecondsUntilWeeklyReset = function()
      return 3 * 86400
    end,
  }
  env.C_Calendar = {}
  env.C_CVar = env.C_CVar
  env.C_StorePublic = {
    IsDisabledByParentalControls = function()
      return false
    end,
  }
  env.C_EventUtils = {
    IsEventValid = function()
      return true
    end,
  }
  env.C_Texture = {
    GetAtlasInfo = function(atlas)
      return { width = 16, height = 16, file = atlas }
    end,
  }
  env.GetFileIDFromPath = function()
    return 0
  end
  env.C_UI = { Reload = env.ReloadUI }
  env.C_RestrictedActions = {
    IsAddOnRestrictionActive = function()
      return false
    end,
  }
  env.C_Secrets = {
    HasSecretRestrictions = function()
      return false
    end,
    ShouldUnitHealthMaxBeSecret = function()
      return false
    end,
  }
  env.C_Minimap = {}
  env.C_GamePad = {
    IsEnabled = function()
      return false
    end,
  }
  env.CombatLogGetCurrentEventInfo = nil
  env.GetCurrentKeyBoardFocus = function() end
  env.IsInCinematicScene = function()
    return false
  end
  env.InCinematic = function()
    return false
  end
  env.IsFalling = function()
    return false
  end
  env.IsMounted = function()
    return false
  end
  env.IsFlying = function()
    return false
  end
  env.IsIndoors = function()
    return false
  end
  env.IsOutdoors = function()
    return true
  end
  env.GetUnitSpeed = function()
    return 0
  end
  env.HasFullControl = function()
    return true
  end
end

function Api.Build(opts)
  local ctx = {
    world = assert(opts.world),
    client = assert(opts.client),
    engine = assert(opts.engine),
    env = assert(opts.env),
    addonMeta = opts.addonMeta or {},
  }
  InstallLuaCore(ctx)
  InstallWowLuaExtensions(ctx)
  InstallOutput(ctx)
  InstallFramesAndFonts(ctx)
  InstallConstants(ctx)
  InstallCVarsAndBindings(ctx)
  InstallAddons(ctx)
  InstallSound(ctx)
  InstallTimers(ctx)
  InstallUnits(ctx)
  InstallSpecs(ctx)
  InstallGroup(ctx)
  InstallZonesAndInstances(ctx)
  InstallChallengeMode(ctx)
  InstallBagsAndItems(ctx)
  InstallSpells(ctx)
  InstallChatAndAddonMessages(ctx)
  InstallMisc(ctx)
  -- Last: wraps tostring / string.format after every helper above captured them.
  Compat.ApplyLua51NumberSemantics(ctx.env)
end

return Api
