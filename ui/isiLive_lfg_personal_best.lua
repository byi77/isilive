local _, addonTable = ...
addonTable = addonTable or {}

local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local PersonalBest = {}
addonTable.LFGPersonalBest = PersonalBest

local states = setmetatable({}, { __mode = "k" })
local hookedProviders = setmetatable({}, { __mode = "k" })
local LABEL_WIDTH = 76

local function IsSecret(value)
  return addonTable.Validators.IsSecretValue(value)
end

local function ReadLevel(info)
  if IsSecret(info) or type(info) ~= "table" then
    return nil
  end
  local level = rawget(info, "level")
  if IsSecret(level) or type(level) ~= "number" or level <= 0 or level >= math.huge or level % 1 ~= 0 then
    return nil
  end
  return level
end

function PersonalBest.GetText(resultID)
  if IsSecret(resultID) or type(resultID) ~= "number" then
    return nil
  end
  local lfg = rawget(_G, "C_LFGList")
  local mythic = rawget(_G, "C_MythicPlus")
  if
    type(lfg) ~= "table"
    or type(lfg.GetSearchResultInfo) ~= "function"
    or type(mythic) ~= "table"
    or type(mythic.GetSeasonBestForMap) ~= "function"
  then
    return nil
  end
  local ok, info = pcall(lfg.GetSearchResultInfo, resultID)
  if not ok or IsSecret(info) or type(info) ~= "table" then
    return nil
  end
  local activityIDs = rawget(info, "activityIDs")
  if IsSecret(activityIDs) then
    return nil
  end
  local resolver = addonTable.LFGEntryResolver
  local mapID
  if type(activityIDs) == "table" and next(activityIDs) ~= nil then
    for _, activityID in pairs(activityIDs) do
      if IsSecret(activityID) then
        return nil
      end
    end
    mapID = resolver.MapIDFromActivityIDs(activityIDs)
  else
    local activityID = rawget(info, "activityID")
    if not IsSecret(activityID) then
      mapID = resolver.MapIDFromActivityID(activityID)
    end
  end
  if not mapID then
    return nil
  end
  local success, timed, overtime = pcall(mythic.GetSeasonBestForMap, mapID)
  if not success or IsSecret(timed) or IsSecret(overtime) then
    return nil
  end
  local timedLevel, overtimeLevel = ReadLevel(timed), ReadLevel(overtime)
  -- A malformed response is unknown, not evidence of an absent completion.
  if (timed ~= nil and not timedLevel) or (overtime ~= nil and not overtimeLevel) then
    return nil
  end
  -- Same pick as Blizzard's Mythic+ tab: an overtime run only counts when it
  -- scored more than the timed one. A depleted +13 must not hide a timed +12.
  local level = timedLevel or overtimeLevel
  if timedLevel and overtimeLevel then
    local timedScore, overtimeScore = rawget(timed, "dungeonScore"), rawget(overtime, "dungeonScore")
    if
      not IsSecret(timedScore)
      and not IsSecret(overtimeScore)
      and type(timedScore) == "number"
      and type(overtimeScore) == "number"
      and overtimeScore > timedScore
    then
      level = overtimeLevel
    end
  end
  local format = addonTable.LFGBonusModel.ResolveLocalizedText("LFG_PERSONAL_BEST_FMT")
  if not format then
    return nil
  end
  return string.format(format, level and ("+" .. level) or "-")
end

local function SetText(region, text)
  local common = addonTable.UICommon
  if type(common) == "table" and type(common.SetReadableText) == "function" then
    common.SetReadableText(region, text)
  else
    region:SetText(text)
  end
end

local function ReadCoordinate(region, method)
  if not region or type(region[method]) ~= "function" then
    return nil
  end
  local ok, value = pcall(region[method], region)
  if
    not ok
    or IsSecret(value)
    or type(value) ~= "number"
    or value ~= value
    or value <= -math.huge
    or value >= math.huge
  then
    return nil
  end
  return value
end

local function UpdateDungeonWidth(button, state, shown)
  local name = rawget(button, "ActivityName")
  if not name or type(name.SetWidth) ~= "function" then
    return
  end
  local width = ReadCoordinate(name, "GetWidth")
  if not width then
    return
  end
  local original = width == state.renderedWidth and state.originalWidth or width
  local available = original
  if shown then
    local left = ReadCoordinate(name, "GetLeft")
    local personalLeft = ReadCoordinate(state.label, "GetLeft")
    if left and personalLeft then
      available = math.max(1, math.min(original, personalLeft - left - 6))
    end
  end
  name:SetWidth(available)
  state.originalWidth, state.renderedWidth = original, available
end

local function GetProvider(button)
  -- Verified in the installed PGF Init.lua and Modules/RatingInfo.lua.
  local pgf = rawget(_G, "PremadeGroupsFilter")
  local provider = type(pgf) == "table" and rawget(pgf, "Debug") or nil
  if type(provider) ~= "table" or type(provider.ratingInfoFrames) ~= "table" then
    return nil
  end
  local hook = rawget(_G, "hooksecurefunc")
  if not hookedProviders[provider] and type(hook) == "function" and type(provider.AddRatingInfo) == "function" then
    hookedProviders[provider] = pcall(hook, provider, "AddRatingInfo", function(row)
      PersonalBest.Apply(row)
    end)
  end
  return provider.ratingInfoFrames[button]
end

function PersonalBest.Apply(button)
  if type(button) ~= "table" then
    return
  end
  local frame = GetProvider(button)
  -- Suppress only the provider's best-level line; its overall rating remains.
  local leaderLevel = frame and frame.ExtraText
  if leaderLevel and type(leaderLevel.Hide) == "function" then
    leaderLevel:Hide()
  end
  local text = PersonalBest.GetText(rawget(button, "resultID"))
  local state = states[button]
  if not state and text and type(button.CreateFontString) == "function" then
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetWidth(LABEL_WIDTH)
    label:SetHeight(15)
    label:SetJustifyH("RIGHT")
    local colors = type(addonTable.UICommon) == "table" and addonTable.UICommon.Colors
    label:SetTextColor(unpack((colors and colors.BLUE_VERSION_TEXT) or { 0.55, 0.75, 1.0 }))
    label:SetWordWrap(false)
    state = { label = label }
    states[button] = state
  end
  if not state then
    return
  end
  local label = state.label
  label:ClearAllPoints()
  if frame and type(frame.IsShown) == "function" and frame:IsShown() then
    label:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  else
    -- The same right-hand column, independent of PGF's installation/settings.
    label:SetPoint("BOTTOMRIGHT", button, "RIGHT", -115, -15)
  end
  SetText(label, text or "")
  if text then
    label:Show()
  else
    label:Hide()
  end
  UpdateDungeonWidth(button, state, text ~= nil)
end
