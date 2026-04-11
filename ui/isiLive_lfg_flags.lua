local _, addonTable = ...
addonTable = addonTable or {}

local LFGFlags = {}
addonTable.LFGFlags = LFGFlags

local FLAG_WIDTH = 16
local FLAG_HEIGHT = 12

-- Injected via Register().
local getRealmInfoLib
local getLanguageTag
local getFlagTexturePath
local lfgFlagsEnabled = true

-- resultID -> tag string|false cache; cleared on new search.
local resultTagCache = {}

-- WeakTable so recycled Blizzard buttons don't prevent GC.
local hooked = setmetatable({}, { __mode = "k" })

-- -------------------------------------------------------------------------
-- Helpers
-- -------------------------------------------------------------------------

local function SplitNameRealm(fullName)
  if not fullName then
    return nil, nil
  end
  local name, realm = fullName:match("^(.+)-(.+)$")
  return name or fullName, realm
end

local function GetTagForResult(resultID)
  local cached = resultTagCache[resultID]
  if cached ~= nil then
    return cached or nil
  end
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" then
    return nil
  end
  local ok, info = pcall(C_LFGList_ref.GetSearchResultInfo, resultID)
  if not ok or not info then
    resultTagCache[resultID] = false
    return nil
  end
  local issecretvalue_ref = rawget(_G, "issecretvalue")
  if type(issecretvalue_ref) == "function" and issecretvalue_ref(info) then
    resultTagCache[resultID] = false
    return nil
  end
  local leaderName = info.leaderName
  if not leaderName then
    resultTagCache[resultID] = false
    return nil
  end
  local _, realm = SplitNameRealm(leaderName)
  if not realm then
    local getRealmName = rawget(_G, "GetRealmName")
    if type(getRealmName) == "function" then
      realm = getRealmName()
    end
  end
  local tag
  if type(getLanguageTag) == "function" and realm then
    local tagOk, tagResult = pcall(getLanguageTag, realm)
    if tagOk and type(tagResult) == "string" and tagResult ~= "" and tagResult ~= "??" then
      tag = tagResult
    end
  end
  resultTagCache[resultID] = tag or false
  return tag
end

-- -------------------------------------------------------------------------
-- Per-button flag texture
-- -------------------------------------------------------------------------

local function EnsureFlagTexture(button)
  if button._isiFlagTex then
    return button._isiFlagTex
  end
  local tex = button:CreateTexture(nil, "OVERLAY")
  tex:SetSize(FLAG_WIDTH, FLAG_HEIGHT)

  -- Place flag to the right of the Playstyle label (e.g. "Entspannt", "Kompetitiv").
  -- Playstyle sits at x=10, W=53, so RIGHT edge is at ~63. We add a small gap.
  local playstyleFS = rawget(button, "Playstyle")
  if playstyleFS and type(playstyleFS.GetRight) == "function" then
    tex:SetPoint("LEFT", playstyleFS, "RIGHT", 4, 0)
  else
    tex:SetPoint("LEFT", button, "LEFT", 67, 0)
  end

  tex:Hide()
  button._isiFlagTex = tex
  return tex
end

local function ApplyFlagToButton(button, resultID)
  local tex = EnsureFlagTexture(button)
  local tag = lfgFlagsEnabled and resultID and GetTagForResult(resultID)
  local path = tag and type(getFlagTexturePath) == "function" and getFlagTexturePath(tag)
  if path then
    tex:SetTexture(path)
    tex:Show()
  else
    tex:Hide()
  end
end

-- -------------------------------------------------------------------------
-- Hooking search-result buttons
-- -------------------------------------------------------------------------

local function UpdateButton(button)
  -- resultID is a direct field on the Blizzard LFG search result button.
  ApplyFlagToButton(button, rawget(button, "resultID"))
end

local function HookButton(button)
  if not button or hooked[button] then
    return
  end
  hooked[button] = true
  button:HookScript("OnEnter", function(self)
    UpdateButton(self)
  end)
  UpdateButton(button)
end

local function HookButtons(buttons)
  for _, btn in pairs(buttons) do
    HookButton(btn)
  end
end

local function RefreshAll()
  for btn in pairs(hooked) do
    UpdateButton(btn)
  end
end

-- -------------------------------------------------------------------------
-- Panel wiring
-- -------------------------------------------------------------------------

function LFGFlags.HookSearchPanel()
  local LFGListFrameRef = rawget(_G, "LFGListFrame")
  if not LFGListFrameRef or not LFGListFrameRef.SearchPanel or not LFGListFrameRef.SearchPanel.ScrollBox then
    return
  end
  local searchBox = LFGListFrameRef.SearchPanel.ScrollBox

  local ScrollBoxUtil_ref = rawget(_G, "ScrollBoxUtil")
  if type(ScrollBoxUtil_ref) == "table" and type(ScrollBoxUtil_ref.OnViewFramesChanged) == "function" then
    ScrollBoxUtil_ref:OnViewFramesChanged(searchBox, HookButtons)
    if type(ScrollBoxUtil_ref.OnViewScrollChanged) == "function" then
      ScrollBoxUtil_ref:OnViewScrollChanged(searchBox, RefreshAll)
    end
  else
    -- ScrollBoxUtil not available: hook on search results event instead.
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    eventFrame:SetScript("OnEvent", function()
      C_Timer.After(0.1, function()
        if type(searchBox.GetFrames) == "function" then
          HookButtons(searchBox:GetFrames() or {})
        end
        -- resultID is set by Blizzard after the initial populate; refresh again.
        C_Timer.After(0.3, RefreshAll)
      end)
    end)
  end

  -- Clear result cache on new search so stale language data is not shown.
  pcall(hooksecurefunc, "LFGListSearchPanel_DoSearch", function()
    resultTagCache = {}
  end)

  -- Extra trigger: update the specific button when Blizzard activates it.
  pcall(hooksecurefunc, "LFGListUtil_SetSearchEntryTooltip", function(_, resultID)
    if not resultID then
      return
    end
    for btn in pairs(hooked) do
      if rawget(btn, "resultID") == resultID then
        ApplyFlagToButton(btn, resultID)
      end
    end
  end)
end

-- -------------------------------------------------------------------------
-- Public: called from factory
-- -------------------------------------------------------------------------

function LFGFlags.SetEnabled(enabled)
  lfgFlagsEnabled = enabled ~= false
  if not lfgFlagsEnabled then
    for btn in pairs(hooked) do
      local tex = rawget(btn, "_isiFlagTex")
      if tex and type(tex.Hide) == "function" then
        tex:Hide()
      end
    end
  else
    for btn in pairs(hooked) do
      UpdateButton(btn)
    end
  end
end

function LFGFlags.Register(deps)
  if type(deps) ~= "table" then
    return
  end

  local localeModule = deps.localeModule
  getRealmInfoLib = deps.getRealmInfoLib

  if type(localeModule) == "table" then
    if type(localeModule.GetUnitServerLanguage) == "function" then
      getLanguageTag = function(realm)
        return localeModule.GetUnitServerLanguage(nil, realm, getRealmInfoLib)
      end
    end
    if type(localeModule.GetLanguageFlagTexturePath) == "function" then
      getFlagTexturePath = function(tag)
        return localeModule.GetLanguageFlagTexturePath(tag)
      end
    end
  end

  local LFGListFrameRef = rawget(_G, "LFGListFrame")
  if LFGListFrameRef and LFGListFrameRef.SearchPanel then
    LFGFlags.HookSearchPanel()
  else
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(self, _, name)
      if name ~= "Blizzard_LFGList" then
        return
      end
      self:UnregisterEvent("ADDON_LOADED")
      LFGFlags.HookSearchPanel()
    end)
  end
end
