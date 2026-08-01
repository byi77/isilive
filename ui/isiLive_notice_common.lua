local _, addonTable = ...

addonTable = addonTable or {}

local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local NoticeCommon = {}
addonTable.NoticeCommon = NoticeCommon

local UICommon = assert(addonTable.UICommon, "isiLive: UICommon missing")
local applyReadableFontForText = assert(UICommon.ApplyReadableFontForText, "isiLive: UICommon font helper missing")
local setReadableText = UICommon.SetReadableText
local Colors = UICommon.Colors or {}

function NoticeCommon.ClampMovableFrameToScreen(frame)
  if type(frame) ~= "table" then
    return
  end
  if type(frame.SetClampedToScreen) == "function" then
    frame:SetClampedToScreen(true)
  end
  if type(frame.SetClampRectInsets) == "function" then
    frame:SetClampRectInsets(0, 0, 0, 0)
  end
end

function NoticeCommon.ApplyFrameLayer(frame, config)
  if type(frame) ~= "table" or type(config) ~= "table" then
    return
  end
  if config.frameStrata and type(frame.SetFrameStrata) == "function" then
    frame:SetFrameStrata(config.frameStrata)
  end
  if config.frameLevel and type(frame.SetFrameLevel) == "function" then
    frame:SetFrameLevel(config.frameLevel)
  end
end

function NoticeCommon.IncreaseFontSize(fontString, delta)
  local numericDelta = tonumber(delta) or 0
  if numericDelta <= 0 then
    return
  end
  if
    type(fontString) ~= "table"
    or type(fontString.GetFont) ~= "function"
    or type(fontString.SetFont) ~= "function"
  then
    return
  end

  local fontPath, fontSize, fontFlags = fontString:GetFont()
  local numericSize = tonumber(fontSize)
  if not fontPath or not numericSize then
    return
  end

  fontString:SetFont(fontPath, numericSize + numericDelta, fontFlags)
end

function NoticeCommon.SetReadableText(fontString, text)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return
  end

  local value = tostring(text or "")
  if type(setReadableText) == "function" then
    setReadableText(fontString, value)
  else
    applyReadableFontForText(fontString, value)
    fontString:SetText(value)
  end
end

function NoticeCommon.CreateBodyText(frame, config)
  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  NoticeCommon.IncreaseFontSize(text, config.fontDelta)
  text:SetTextColor(unpack(Colors.WARM_WHITE_TEXT or { 1, 0.92, 0.7 }))
  return text
end
