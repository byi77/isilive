local _, addonTable = ...
addonTable = addonTable or {}

local RI = addonTable._RosterInternal or {}
addonTable._RosterInternal = RI

local function ApplyFontStringSize(fontString, size)
  if fontString == nil then
    return
  end
  if type(fontString.GetFont) ~= "function" or type(fontString.SetFont) ~= "function" then
    return
  end

  local fontPath, _, fontFlags = fontString:GetFont()
  if type(fontPath) ~= "string" or fontPath == "" then
    return
  end

  local uiCommon = addonTable and addonTable.UICommon
  local localeFontPath = type(uiCommon) == "table"
      and type(uiCommon.GetLocaleFontPath) == "function"
      and uiCommon.GetLocaleFontPath()
    or nil
  fontString:SetFont(localeFontPath or fontPath, size, fontFlags)
end

local function FormatMplusTime(seconds)
  local abs = math.abs(seconds)
  local m = math.floor(abs / 60)
  local s = math.floor(abs % 60)
  return string.format("%d:%02d", m, s)
end

local function SetFontStringTextColorSafe(fontString, r, g, b)
  if fontString and type(fontString.SetTextColor) == "function" then
    fontString:SetTextColor(r, g, b)
  end
end

-- Design-aware token paint (rule 233). Bare UICommon stubs without the
-- design registry paint the token directly.
local function PaintToken(region, methodName, token, alpha)
  local uiCommon = addonTable.UICommon or {}
  if type(uiCommon.PaintToken) == "function" then
    return uiCommon.PaintToken(region, methodName, token, alpha)
  end
  local color = type(uiCommon.Colors) == "table" and uiCommon.Colors[token] or nil
  local method = type(region) == "table" and region[methodName] or nil
  if type(color) == "table" and type(method) == "function" then
    method(region, color[1], color[2], color[3], alpha or color[4] or 1)
  end
end

-- Public surface of RosterPanel.CreateController (ui/isiLive_roster_panel.lua);
-- declared here to keep that file inside its size budget.
---@class RosterPanelController
---@field GetRefreshButton fun(): table
---@field GetCountdownCancelButton fun(): table
---@field GetStatusLine fun(): table
---@field SetCountdownCancelText fun(text: string)
---@field TriggerShareKeysCooldown fun(seconds: number)
---@field GetShareKeysCooldownRemaining fun(): number
---@field GetShareKeysLocalCooldownRemaining fun(): number
---@field ClearShareKeysCooldown fun()
---@field ApplyLocalization fun()
---@field IsCollapsed fun(): boolean
---@field GetLayoutMode fun(): string
---@field RestoreSavedState fun()
---@field RefreshLayoutState fun()
---@field SetCollapseChangedHandler fun(handler: fun(isCollapsed: boolean))
---@field SetLayoutChangedHandler fun(handler: fun(layoutMode: string))
---@field UpdateLeaderButtons fun()
---@field ApplyPendingLeaderButtonUpdates fun()
---@field RenderRoster fun(roster: table)
---@field FlushHiddenRender fun()
---@field IsHiddenRenderPending fun(): boolean
---@field RefreshReadyCheckState fun(roster: table)
---@field RefreshSystemOptionToggles fun()
---@field RefreshKickColumn fun()
---@field SetCdController fun(ctrl: table)
---@field RefreshCdTracker fun()
---@field RefreshKillTrackRow fun()
---@field PlayKillTrackRunEnd fun(outcome: "timed"|"late"|"abandoned"|"left")
---@field ClearKillTrackRunEnd fun()
---@field MarkCdTrackerDirty fun()

RI.ApplyFontStringSize = ApplyFontStringSize
RI.PaintToken = PaintToken
RI.FormatMplusTime = FormatMplusTime
RI.SetFontStringTextColorSafe = SetFontStringTextColorSafe
