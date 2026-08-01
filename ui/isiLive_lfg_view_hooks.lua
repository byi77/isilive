local _, addonTable = ...
addonTable = addonTable or {}

local Hooks = {}
addonTable.LFGViewHooks = Hooks

local callbacks
local hookedSearchButtons = setmetatable({}, { __mode = "k" })
local hookedApplicantButtons = setmetatable({}, { __mode = "k" })

local function RequireCallbacks()
  return assert(callbacks, "isiLive: LFGViewHooks callbacks missing")
end

local function CreateEventFrame()
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return nil
  end
  return createFrame("Frame")
end

local function ScheduleAfter(delay, callback)
  local timer = rawget(_G, "C_Timer")
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    return false
  end
  timer.After(delay, callback)
  return true
end

local function HookGlobalFunction(name, callback)
  local hooksecurefuncRef = rawget(_G, "hooksecurefunc")
  if type(hooksecurefuncRef) ~= "function" then
    return false
  end
  return pcall(hooksecurefuncRef, name, callback) == true
end

local function HookApplicantButton(button, applicantIDOverride)
  local cb = RequireCallbacks()
  if not button or hookedApplicantButtons[button] then
    cb.applyApplicantMembersFromButton(button, applicantIDOverride)
    cb.applyApplicantBonusToButton(button, applicantIDOverride)
    return
  end
  hookedApplicantButtons[button] = true
  if type(button.HookScript) == "function" then
    button:HookScript("OnEnter", function(self)
      cb.applyApplicantBonusToButton(self)
    end)
  end
  local inviteButton = rawget(button, "InviteButton")
  if
    type(inviteButton) == "table"
    and type(inviteButton.HookScript) == "function"
    and not hookedApplicantButtons[inviteButton]
  then
    hookedApplicantButtons[inviteButton] = true
    inviteButton:HookScript("OnEnter", function(self)
      cb.applyApplicantBonusToButton(self, cb.resolveApplicantIDFromButton(button))
    end)
  end
  cb.applyApplicantMembersFromButton(button, applicantIDOverride)
  cb.applyApplicantBonusToButton(button, applicantIDOverride)
end

local function HookApplicantButtonsFromViewer(viewer)
  if type(viewer) ~= "table" then
    return
  end
  local scrollFrame = rawget(viewer, "ScrollFrame")
  local buttons = type(scrollFrame) == "table" and rawget(scrollFrame, "buttons") or nil
  if type(buttons) == "table" then
    for _, button in ipairs(buttons) do
      HookApplicantButton(button)
    end
  end
  local scrollBox = rawget(viewer, "ScrollBox")
  if type(scrollBox) == "table" and type(scrollBox.GetFrames) == "function" then
    for _, button in pairs(scrollBox:GetFrames() or {}) do
      HookApplicantButton(button)
    end
  end
end

local function HookNamedApplicantButtons()
  for index = 1, 20 do
    local button = rawget(_G, "LFGListApplicationViewerScrollFrameButton" .. tostring(index))
    if type(button) == "table" then
      HookApplicantButton(button)
    end
  end
end

local function HookApplicationViewer()
  local cb = RequireCallbacks()
  local LFGListFrameRef = rawget(_G, "LFGListFrame")
  local viewer = LFGListFrameRef and rawget(LFGListFrameRef, "ApplicationViewer") or nil
  HookApplicantButtonsFromViewer(viewer)
  HookNamedApplicantButtons()

  local ScrollBoxUtil_ref = rawget(_G, "ScrollBoxUtil")
  local scrollBox = type(viewer) == "table" and rawget(viewer, "ScrollBox") or nil
  if type(ScrollBoxUtil_ref) == "table" and type(ScrollBoxUtil_ref.OnViewFramesChanged) == "function" and scrollBox then
    ScrollBoxUtil_ref:OnViewFramesChanged(scrollBox, function(buttons)
      if type(buttons) == "table" then
        for _, button in pairs(buttons) do
          HookApplicantButton(button)
        end
      end
    end)
  end

  local hooksecurefuncRef = rawget(_G, "hooksecurefunc")
  if type(hooksecurefuncRef) ~= "function" then
    return
  end
  pcall(hooksecurefuncRef, "LFGListApplicationViewer_UpdateResults", function(self)
    HookApplicantButtonsFromViewer(self)
    HookNamedApplicantButtons()
  end)
  pcall(hooksecurefuncRef, "LFGListApplicationViewer_UpdateApplicant", function(button, applicantID)
    HookApplicantButton(button, applicantID)
  end)
  pcall(hooksecurefuncRef, "LFGListApplicationViewer_UpdateApplicantMember", function(member, applicantID, memberIndex)
    cb.applyApplicantBonusToMemberFrame(member, applicantID, memberIndex)
  end)
  pcall(hooksecurefuncRef, "LFGListApplicantMember_OnEnter", function(member)
    cb.showApplicantMemberTooltip(member)
  end)
end

local function UpdateButton(button)
  RequireCallbacks().updateSearchButton(button)
end

local function HookButton(button)
  local cb = RequireCallbacks()
  if not button or hookedSearchButtons[button] then
    return
  end
  hookedSearchButtons[button] = true
  button:HookScript("OnEnter", function(self)
    UpdateButton(self)
    cb.applyGroupBonusTooltipLines(rawget(self, "resultID"))
    ScheduleAfter(0, function()
      cb.applyGroupBonusTooltipLines(rawget(self, "resultID"))
    end)
  end)
  UpdateButton(button)
end

local function HookButtons(buttons)
  for _, button in pairs(buttons) do
    HookButton(button)
  end
end

local function RefreshAll()
  for button in pairs(hookedSearchButtons) do
    UpdateButton(button)
  end
end

function Hooks.Configure(value)
  assert(type(value) == "table", "isiLive: LFGViewHooks.Configure expects callbacks")
  callbacks = value
end

function Hooks.HookSearchPanel()
  local cb = RequireCallbacks()
  local LFGListFrameRef = rawget(_G, "LFGListFrame")
  if not LFGListFrameRef or not LFGListFrameRef.SearchPanel or not LFGListFrameRef.SearchPanel.ScrollBox then
    return
  end
  local searchBox = LFGListFrameRef.SearchPanel.ScrollBox
  HookApplicationViewer()

  local ScrollBoxUtil_ref = rawget(_G, "ScrollBoxUtil")
  if type(ScrollBoxUtil_ref) == "table" and type(ScrollBoxUtil_ref.OnViewFramesChanged) == "function" then
    ScrollBoxUtil_ref:OnViewFramesChanged(searchBox, HookButtons)
    if type(ScrollBoxUtil_ref.OnViewScrollChanged) == "function" then
      ScrollBoxUtil_ref:OnViewScrollChanged(searchBox, RefreshAll)
    end
  else
    local eventFrame = CreateEventFrame()
    if eventFrame then
      eventFrame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
      eventFrame:SetScript("OnEvent", function()
        ScheduleAfter(0.1, function()
          if type(searchBox.GetFrames) == "function" then
            HookButtons(searchBox:GetFrames() or {})
          end
          ScheduleAfter(0.3, RefreshAll)
        end)
      end)
    end
  end

  HookGlobalFunction("LFGListSearchPanel_DoSearch", cb.clearSearchCaches)
  HookGlobalFunction("LFGListUtil_SetSearchEntryTooltip", function(_, resultID)
    if not resultID then
      return
    end
    cb.refreshSearchResultTooltip(resultID)
  end)
end

function Hooks.RegisterWhenAvailable(hookSearchPanel)
  hookSearchPanel = type(hookSearchPanel) == "function" and hookSearchPanel or Hooks.HookSearchPanel
  local LFGListFrameRef = rawget(_G, "LFGListFrame")
  if LFGListFrameRef and LFGListFrameRef.SearchPanel then
    hookSearchPanel()
    return
  end
  local eventFrame = CreateEventFrame()
  if eventFrame then
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(self, _, name)
      if name ~= "Blizzard_LFGList" then
        return
      end
      self:UnregisterEvent("ADDON_LOADED")
      hookSearchPanel()
    end)
  end
end

function Hooks.ForEachSearchButton(callback)
  for button in pairs(hookedSearchButtons) do
    callback(button)
  end
end

Hooks.HookApplicantButton = HookApplicantButton
Hooks.HookButtons = HookButtons
Hooks.HookButton = HookButton
Hooks.RefreshAll = RefreshAll
