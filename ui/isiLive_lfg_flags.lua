local _, addonTable = ...
addonTable = addonTable or {}

-- Lua 5.1 (WoW client) exposes global `unpack`; Lua 5.4 (local tooling) only
-- has `table.unpack`. Bridge locally so this file works under both without
-- depending on the entrypoint script to have set up a global compat shim.
local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local LFGFlags = {}
addonTable.LFGFlags = LFGFlags

local UICommon = addonTable.UICommon
local BonusModel = assert(addonTable.LFGBonusModel, "isiLive: LFGBonusModel missing")
local ViewHooks = assert(addonTable.LFGViewHooks, "isiLive: LFGViewHooks missing")
local APPLICANT_BONUS_TEXT_COLOR = BonusModel.APPLICANT_BONUS_TEXT_COLOR
local SEARCH_RESULT_BONUS_TEXTURE = BonusModel.SEARCH_RESULT_BONUS_TEXTURE
local SEARCH_RESULT_BONUS_MAX_MARKERS = BonusModel.SEARCH_RESULT_BONUS_MAX_MARKERS
local CLASS_TOKENS = BonusModel.CLASS_TOKENS
local CLASS_BONUSES = BonusModel.CLASS_BONUSES
local SPEC_BONUSES = BonusModel.SPEC_BONUSES
local SPEC_CLASS_TOKENS = BonusModel.SPEC_CLASS_TOKENS
local IsSecretValue = assert(BonusModel.IsSecretValue, "isiLive: LFGBonusModel.IsSecretValue missing")
local ResolveClassToken = assert(BonusModel.ResolveClassToken, "isiLive: LFGBonusModel.ResolveClassToken missing")
local ReadPositiveNumber = assert(BonusModel.ReadPositiveNumber, "isiLive: LFGBonusModel.ReadPositiveNumber missing")
local ResolveSpecIDFromText =
  assert(BonusModel.ResolveSpecIDFromText, "isiLive: LFGBonusModel.ResolveSpecIDFromText missing")
local ResolvePlayerBonusProfile =
  assert(BonusModel.ResolvePlayerBonusProfile, "isiLive: LFGBonusModel.ResolvePlayerBonusProfile missing")
local ResolveLocalizedText =
  assert(BonusModel.ResolveLocalizedText, "isiLive: LFGBonusModel.ResolveLocalizedText missing")
local BuildBonusCacheKey = assert(BonusModel.BuildBonusCacheKey, "isiLive: LFGBonusModel.BuildBonusCacheKey missing")
local BuildBonusSuffix = assert(BonusModel.BuildBonusSuffix, "isiLive: LFGBonusModel.BuildBonusSuffix missing")
local AddRelevantSearchResultBonusKeys =
  assert(BonusModel.AddRelevantSearchResultBonusKeys, "isiLive: LFGBonusModel.AddRelevantSearchResultBonusKeys missing")
local BuildSearchResultBonusBadgeText =
  assert(BonusModel.BuildSearchResultBonusBadgeText, "isiLive: LFGBonusModel.BuildSearchResultBonusBadgeText missing")
local BuildApplicantBonusBadge =
  assert(BonusModel.BuildApplicantBonusBadge, "isiLive: LFGBonusModel.BuildApplicantBonusBadge missing")
local CountApplicantBonusMarkers =
  assert(BonusModel.CountApplicantBonusMarkers, "isiLive: LFGBonusModel.CountApplicantBonusMarkers missing")
local BuildApplicantBonusMarkerBadge =
  assert(BonusModel.BuildApplicantBonusMarkerBadge, "isiLive: LFGBonusModel.BuildApplicantBonusMarkerBadge missing")
local BuildRosterBonusMarkerBadge =
  assert(BonusModel.BuildRosterBonusMarkerBadge, "isiLive: LFGBonusModel.BuildRosterBonusMarkerBadge missing")
local BuildRosterBonusTooltipLine =
  assert(BonusModel.BuildRosterBonusTooltipLine, "isiLive: LFGBonusModel.BuildRosterBonusTooltipLine missing")

-- Internal helpers exposed for tests via addonTable._LFGFlagsInternal.
-- Production callers continue to use the local references defined below.
local LI = addonTable._LFGFlagsInternal or {}
addonTable._LFGFlagsInternal = LI

local FLAG_WIDTH = 11
local FLAG_HEIGHT = 8
local APPLICANT_BONUS_ICON_SIZE = 10
local APPLICANT_BONUS_ICON_GAP = 0
local SEARCH_RESULT_FLAG_X = 2
local SEARCH_RESULT_FLAG_Y = 10
local SEARCH_RESULT_FLAG_ACTIVITY_NAME_OFFSET_Y = -2
local SEARCH_RESULT_DUNGEON_NAME_SHIFT_X = FLAG_WIDTH + 4
local APPLICANT_FLAG_NAME_SHIFT_X = FLAG_WIDTH + 4
local SEARCH_RESULT_BONUS_RIGHT_X = -44
local SEARCH_RESULT_BONUS_Y = -16
local SEARCH_RESULT_BONUS_WIDTH = 52
-- Extra tolerance ONLY. StripSearchResultKeystoneSuffix resolves the label
-- from the client-localized global DUNGEON_DIFFICULTY_MYTHIC_KEYSTONE first
-- and merely unions these on top, so every locale is already covered without
-- them. They stay as a safety net for clients where the global is missing.
local SEARCH_RESULT_KEYSTONE_LABELS = {
  ["Mythic Keystone"] = true, -- i18n-ok: additive to the localized global
  ["Mythischer Schl\195\188sselstein"] = true, -- i18n-ok: additive to the localized global
}
-- Blizzard global string keys used to recognise client-localized LFG text.
-- Never compare against literal German/English strings here: the addon
-- supports 8 locales and the WoW client renders these in its own language, so
-- a literal match silently fails on every other client. Every key below was
-- read from a live client via a _G reverse lookup, not guessed.
local PROMOTION_OFFERED_PLAYSTYLE_GLOBAL = "GROUP_FINDER_GENERAL_PLAYSTYLE4"
local PROVING_GROUND_TITLE_GLOBAL = "LFG_LIST_PROVING_GROUND_TITLE"
-- Ordered by specificity: the LFG tooltip header first, generic member labels
-- as fallback. Format specifiers are stripped, leaving the literal prefix.
local MEMBERS_HEADER_GLOBALS = {
  "LFG_LIST_TOOLTIP_MEMBERS", -- "Members: %d (%d/%d/%d)"
  "LFG_LIST_TOOLTIP_MEMBERS_SIMPLE", -- "Members: %d"
  "MEMBERS_COLON",
  "MEMBERS",
}

local function ReadGlobalString(key)
  local value = rawget(_G, key)
  if type(value) ~= "string" or value == "" then
    return nil
  end
  return value
end

local getRealmInfoLib
local getLanguageTag
local getFlagTexturePath
local lfgFlagsEnabled = true
local lfgGroupBonusesEnabled = true

-- resultID -> tag string|false cache; cleared on new search.
local resultTagCache = {}
local resultBonusBadgeCache = {}
local resultMemberBonusCache = {}

local hookedApplicantMembers = setmetatable({}, { __mode = "k" })

-- -------------------------------------------------------------------------
-- Helpers
-- -------------------------------------------------------------------------

local function SplitNameRealm(fullName)
  if not fullName then
    return nil, nil
  end
  -- Split on FIRST dash so realms with embedded hyphens (e.g. "Area-52") stay
  -- intact. Greedy "^(.+)-(.+)$" would split "Player-Area-52" into
  -- ("Player-Area", "52"), diverging from the four other name-realm splitters
  -- in the codebase which all consume the first dash only.
  local dash = string.find(fullName, "-", 1, true)
  if not dash then
    return fullName, nil
  end
  return string.sub(fullName, 1, dash - 1), string.sub(fullName, dash + 1)
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

local function ResolveLanguageTagFromName(fullName)
  local name, realm = SplitNameRealm(fullName)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  if not realm then
    local getRealmName = rawget(_G, "GetRealmName")
    if type(getRealmName) == "function" then
      local ok, realmName = pcall(getRealmName)
      if ok and type(realmName) == "string" and realmName ~= "" then
        realm = realmName
      end
    end
  end
  if type(realm) ~= "string" or realm == "" or type(getLanguageTag) ~= "function" then
    return nil
  end
  local ok, tag = pcall(getLanguageTag, realm)
  if ok and type(tag) == "string" and tag ~= "" and tag ~= "??" then
    return tag
  end
  return nil
end

local function ExtractMemberInfoFromTable(info)
  if type(info) ~= "table" or IsSecretValue(info) then
    return nil
  end
  local classToken = ResolveClassToken(info.classFilename or info.classFileName or info.classToken or info.class)
  local specID = ReadPositiveNumber(info.specID or info.specId or info.specializationID or info.specializationId)
  if specID and SPEC_CLASS_TOKENS[specID] ~= classToken then
    specID = nil
  end
  specID = specID or ResolveSpecIDFromText(info.specName or info.specializationName or info.spec, classToken)
  local className = type(info.className) == "string" and info.className
    or type(info.localizedClassName) == "string" and info.localizedClassName
    or nil
  local specName = type(info.specName) == "string" and info.specName
    or type(info.specializationName) == "string" and info.specializationName
    or nil
  if not classToken or not CLASS_TOKENS[classToken] then
    return nil
  end
  return {
    classToken = classToken,
    specID = specID,
    className = className,
    specName = specName,
  }
end

local function ExtractMemberInfoFromValues(...)
  local classToken, specID, className, specName
  local pendingNumericSpecID
  local pendingSpecText
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    local numericValue = ReadPositiveNumber(value)
    if numericValue and SPEC_BONUSES[numericValue] then
      if classToken and SPEC_CLASS_TOKENS[numericValue] == classToken then
        specID = specID or numericValue
      elseif not classToken then
        pendingNumericSpecID = pendingNumericSpecID or numericValue
      end
    elseif type(value) == "string" and value ~= "" and not IsSecretValue(value) then
      local token = ResolveClassToken(value)
      if token and CLASS_TOKENS[token] then
        classToken = classToken or token
        if not specID and pendingNumericSpecID and SPEC_CLASS_TOKENS[pendingNumericSpecID] == classToken then
          specID = pendingNumericSpecID
        end
      else
        local resolvedSpecID = ResolveSpecIDFromText(value, classToken)
        if resolvedSpecID then
          specID = specID or resolvedSpecID
        elseif not pendingSpecText and ResolveSpecIDFromText(value, "EVOKER") then
          pendingSpecText = value
        end
        if (resolvedSpecID or pendingSpecText == value) and not specName then
          specName = value
        elseif index > 1 and not className then
          className = value
        end
      end
    end
  end
  if not specID and classToken == "EVOKER" then
    specID = ResolveSpecIDFromText(pendingSpecText, classToken)
  end
  if not classToken then
    return nil
  end
  return {
    classToken = classToken,
    specID = specID,
    className = className,
    specName = specName,
  }
end

local function GetSearchResultMemberCount(resultID)
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" or type(C_LFGList_ref.GetSearchResultInfo) ~= "function" then
    return nil
  end
  local ok, info = pcall(C_LFGList_ref.GetSearchResultInfo, resultID)
  if not ok or type(info) ~= "table" or IsSecretValue(info) then
    return nil
  end
  return ReadPositiveNumber(info.numMembers or info.numMember or info.memberCount)
end

local function ReadSearchResultMemberInfo(resultID, memberIndex)
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" or type(C_LFGList_ref.GetSearchResultPlayerInfo) ~= "function" then
    return nil
  end
  local values = { pcall(C_LFGList_ref.GetSearchResultPlayerInfo, resultID, memberIndex) }
  if values[1] ~= true then
    return nil
  end
  if type(values[2]) == "table" then
    return ExtractMemberInfoFromTable(values[2])
  end
  table.remove(values, 1)
  local unpack_ref = rawget(_G, "unpack") or rawget(table, "unpack")
  return ExtractMemberInfoFromValues(unpack_ref(values))
end

local function BuildSearchResultMemberBonuses(resultID)
  if not lfgGroupBonusesEnabled then
    return nil
  end
  if not resultID then
    return nil
  end
  local profile = ResolvePlayerBonusProfile()
  local cacheKey = BuildBonusCacheKey(resultID, profile)
  if resultMemberBonusCache[cacheKey] ~= nil then
    return resultMemberBonusCache[cacheKey] or nil
  end
  local memberCount = GetSearchResultMemberCount(resultID)
  if not memberCount then
    resultMemberBonusCache[cacheKey] = false
    return nil
  end
  local members = {}
  local hasBonus = false
  for index = 1, memberCount do
    local member = ReadSearchResultMemberInfo(resultID, index)
    if member then
      member.suffix = BuildBonusSuffix(member.classToken, member.specID, profile)
      if member.suffix then
        hasBonus = true
      end
    end
    members[index] = member
  end
  resultMemberBonusCache[cacheKey] = hasBonus and members or false
  return resultMemberBonusCache[cacheKey] or nil
end

local function BuildSearchResultBonusBadge(resultID)
  if not lfgGroupBonusesEnabled then
    return nil
  end
  if not resultID then
    return nil
  end
  local profile = ResolvePlayerBonusProfile()
  local cacheKey = BuildBonusCacheKey(resultID, profile)
  if resultBonusBadgeCache[cacheKey] ~= nil then
    local cached = resultBonusBadgeCache[cacheKey]
    if type(cached) == "table" then
      return cached.badge, cached.color
    end
    return nil
  end
  local memberCount = GetSearchResultMemberCount(resultID)
  if not memberCount then
    resultBonusBadgeCache[cacheKey] = false
    return nil
  end
  local relevantBonusCount = 0
  local seenBonusKeys = {}
  for index = 1, memberCount do
    local member = ReadSearchResultMemberInfo(resultID, index)
    if member then
      relevantBonusCount = relevantBonusCount
        + AddRelevantSearchResultBonusKeys(member.classToken, member.specID, profile, seenBonusKeys)
    end
  end
  local badge = BuildSearchResultBonusBadgeText(relevantBonusCount)
  if badge then
    resultBonusBadgeCache[cacheKey] = { badge = badge, color = APPLICANT_BONUS_TEXT_COLOR }
    return badge, APPLICANT_BONUS_TEXT_COLOR
  end
  resultBonusBadgeCache[cacheKey] = false
  return nil
end

local function ReadApplicantInfo(applicantID)
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" or type(C_LFGList_ref.GetApplicantInfo) ~= "function" then
    return nil
  end
  local ok, info = pcall(C_LFGList_ref.GetApplicantInfo, applicantID)
  if not ok or type(info) ~= "table" or IsSecretValue(info) then
    return nil
  end
  return info
end

local function ReadApplicantMemberInfo(applicantID, memberIndex)
  local C_LFGList_ref = rawget(_G, "C_LFGList")
  if type(C_LFGList_ref) ~= "table" or type(C_LFGList_ref.GetApplicantMemberInfo) ~= "function" then
    return nil
  end
  local result = { pcall(C_LFGList_ref.GetApplicantMemberInfo, applicantID, memberIndex) }
  if not result[1] then
    return nil
  end
  local classToken = result[3]
  local localizedClass = result[4]
  local specID = result[17]
  classToken = ResolveClassToken(classToken) or ResolveClassToken(localizedClass)
  if not classToken then
    return nil
  end
  return {
    name = type(result[2]) == "string" and result[2] or nil,
    classToken = classToken,
    specID = ReadPositiveNumber(specID),
    className = type(localizedClass) == "string" and localizedClass or nil,
  }
end

local function BuildApplicantMemberBonuses(applicantID)
  if not lfgGroupBonusesEnabled then
    return nil
  end
  if not applicantID then
    return nil
  end
  local info = ReadApplicantInfo(applicantID)
  local memberCount = info and ReadPositiveNumber(info.numMembers or info.numMember or info.memberCount)
  if not memberCount then
    return nil
  end
  local profile = ResolvePlayerBonusProfile()
  local members = {}
  local hasBonus = false
  for index = 1, memberCount do
    local member = ReadApplicantMemberInfo(applicantID, index)
    if member then
      member.suffix = BuildBonusSuffix(member.classToken, member.specID, profile)
      if member.suffix then
        hasBonus = true
      end
    end
    members[index] = member
  end
  return hasBonus and members or nil
end

local function BuildSingleApplicantMemberSuffix(applicantID, memberIndex)
  if not lfgGroupBonusesEnabled then
    return nil
  end
  local member = applicantID and memberIndex and ReadApplicantMemberInfo(applicantID, memberIndex) or nil
  if not member then
    return nil
  end
  return BuildBonusSuffix(member.classToken, member.specID, ResolvePlayerBonusProfile())
end

local function BuildSingleApplicantMemberBadge(applicantID, memberIndex)
  if not lfgGroupBonusesEnabled then
    return nil, nil, 0
  end
  local member = applicantID and memberIndex and ReadApplicantMemberInfo(applicantID, memberIndex) or nil
  if not member then
    return nil, nil, 0
  end
  local profile = ResolvePlayerBonusProfile()
  return BuildApplicantBonusMarkerBadge(member.classToken, member.specID, profile),
    APPLICANT_BONUS_TEXT_COLOR,
    CountApplicantBonusMarkers(member.classToken, member.specID, profile)
end

local function StripColorCodes(text)
  if type(text) ~= "string" then
    return ""
  end
  local stripped = text:gsub("|c%x%x%x%x%x%x%x%x", "")
  stripped = stripped:gsub("|r", "")
  return stripped
end

-- Detects the "promotion offered" playstyle row. Compares against the
-- client-localized Blizzard global instead of a literal, so this works on all
-- supported locales rather than only deDE. Uses a substring match because the
-- rendered cell may carry padding or trailing punctuation the raw global does
-- not have. Fails closed when the global is unavailable.
local function IsSearchResultPromotionOfferedRow(button)
  local playstyle = type(button) == "table" and rawget(button, "Playstyle") or nil
  if type(playstyle) ~= "table" or type(playstyle.GetText) ~= "function" then
    return false
  end
  local expected = ReadGlobalString(PROMOTION_OFFERED_PLAYSTYLE_GLOBAL)
  if not expected then
    return false
  end
  local text = StripColorCodes(playstyle:GetText())
  if text == "" then
    return false
  end
  return string.find(text, StripColorCodes(expected), 1, true) ~= nil
end

local function ClearSearchResultBonusCache(resultID)
  if resultID == nil then
    resultBonusBadgeCache = {}
    resultMemberBonusCache = {}
    return
  end
  local prefix = tostring(resultID) .. "|"
  for cacheKey in pairs(resultBonusBadgeCache) do
    if string.sub(tostring(cacheKey), 1, #prefix) == prefix then
      resultBonusBadgeCache[cacheKey] = nil
    end
  end
  for cacheKey in pairs(resultMemberBonusCache) do
    if string.sub(tostring(cacheKey), 1, #prefix) == prefix then
      resultMemberBonusCache[cacheKey] = nil
    end
  end
end

local function HasExistingBonusSuffix(text)
  local plain = StripColorCodes(text)
  local textsModule = addonTable.Texts
  local getLocaleTables = type(textsModule) == "table" and textsModule.GetLocaleTables or nil
  local locales = type(getLocaleTables) == "function" and getLocaleTables() or nil
  local function containsBonusText(bonus)
    if type(bonus) ~= "table" or type(locales) ~= "table" or type(bonus.textKey) ~= "string" then
      return false
    end
    for _, localeTable in pairs(locales) do
      local bonusText = type(localeTable) == "table" and localeTable[bonus.textKey] or nil
      if type(bonusText) == "string" and bonusText ~= "" and string.find(plain, bonusText, 1, true) then
        return true
      end
    end
    return false
  end
  for _, bonuses in pairs(CLASS_BONUSES) do
    for _, bonus in ipairs(bonuses) do
      if containsBonusText(bonus) then
        return true
      end
    end
  end
  for _, bonuses in pairs(SPEC_BONUSES) do
    for _, bonus in ipairs(bonuses) do
      if containsBonusText(bonus) then
        return true
      end
    end
  end
  return false
end

-- Resolves the client-localized prefix of the tooltip's member-section header
-- (e.g. "Members:" from "Members: %d (%d/%d/%d)") by cutting the Blizzard
-- global at its first format specifier. Returns nil when no candidate global
-- exists, which makes the caller fail closed.
local resolvedMembersHeaderNeedle = nil
local resolvedMembersHeaderChecked = false

local function ResolveMembersHeaderNeedle()
  if resolvedMembersHeaderChecked then
    return resolvedMembersHeaderNeedle
  end
  resolvedMembersHeaderChecked = true
  for _, key in ipairs(MEMBERS_HEADER_GLOBALS) do
    local raw = ReadGlobalString(key)
    if raw then
      local head = string.match(raw, "^(.-)%%") or raw
      head = StripColorCodes(head):gsub("%s+$", "")
      if head ~= "" then
        resolvedMembersHeaderNeedle = head
        return resolvedMembersHeaderNeedle
      end
    end
  end
  return nil
end

local function GetTooltipLine(index)
  return rawget(_G, "GameTooltipTextLeft" .. tostring(index))
end

local function ResolveBonusTooltipPrefix()
  local tooltipText = ResolveLocalizedText("LFG_BONUS_TOOLTIP_FMT") or "Group bonus: %s"
  local markerStart = string.find(tooltipText, "%%s")
  if markerStart and markerStart > 1 then
    return string.sub(tooltipText, 1, markerStart - 1)
  end
  return "Group bonus: "
end

local function TooltipHasApplicantBonusLine(suffix)
  if type(suffix) ~= "string" or suffix == "" then
    return false
  end
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.NumLines) ~= "function" then
    return false
  end
  local ok, numLines = pcall(tooltip.NumLines, tooltip)
  numLines = ok and tonumber(numLines) or nil
  if not numLines or numLines <= 0 then
    return false
  end
  local suffixPlain = StripColorCodes(suffix)
  local prefixPlain = StripColorCodes(ResolveBonusTooltipPrefix())
  for index = 1, numLines do
    local line = GetTooltipLine(index)
    local text = line and type(line.GetText) == "function" and line:GetText() or nil
    local plain = StripColorCodes(text)
    if string.find(plain, prefixPlain, 1, true) and string.find(plain, suffixPlain, 1, true) then
      return true
    end
  end
  return false
end

local function HideTooltipLine(line)
  if type(line) ~= "table" then
    return
  end
  if type(line.SetText) == "function" then
    line:SetText("")
  end
  if type(line.Hide) == "function" then
    line:Hide()
  end
end

-- Hides Blizzard's Proving Grounds block (title line plus its value line) from
-- the applicant tooltip before isiLive appends its own group-bonus line.
-- Keyed off the client-localized global; without it nothing is hidden, which
-- is the safe direction (a stale line beats hiding the wrong one).
local function HideApplicantProvingGroundTooltipLines()
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.NumLines) ~= "function" then
    return
  end
  local provingGroundTitle = StripColorCodes(ReadGlobalString(PROVING_GROUND_TITLE_GLOBAL))
  if provingGroundTitle == "" then
    return
  end
  local ok, numLines = pcall(tooltip.NumLines, tooltip)
  numLines = ok and tonumber(numLines) or nil
  if not numLines or numLines <= 0 then
    return
  end
  for index = 1, numLines do
    local line = GetTooltipLine(index)
    local text = line and type(line.GetText) == "function" and line:GetText() or nil
    local plain = StripColorCodes(text)
    if provingGroundTitle ~= "" and string.find(plain, provingGroundTitle, 1, true) then
      HideTooltipLine(line)
      HideTooltipLine(GetTooltipLine(index + 1))
      return
    end
  end
end

-- Collects the tooltip's member rows: the first `memberCount` non-empty lines
-- after the localized member-section header.
--
-- Knowing the member count removes the need for a section END marker, which
-- previously matched literal German/English words ("Erstellt" / "Created" /
-- "Beste" / "Best"). It also removes the old "no header found -> use EVERY
-- non-empty line" fallback: on any locale whose header did not match, that
-- pulled the group title and activity lines into the candidate set, where an
-- LFG title naming a class and spec could absorb a member's bonus marker.
-- Without a resolvable header this now returns nothing and no marker is
-- written, which is the safe direction.
local function CollectTooltipMemberLines(memberCount)
  memberCount = tonumber(memberCount)
  if not memberCount or memberCount <= 0 then
    return {}
  end
  local needle = ResolveMembersHeaderNeedle()
  if not needle then
    return {}
  end
  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) ~= "table" or type(tooltip.NumLines) ~= "function" then
    return {}
  end
  local ok, numLines = pcall(tooltip.NumLines, tooltip)
  numLines = ok and tonumber(numLines) or nil
  if not numLines or numLines <= 0 then
    return {}
  end
  local memberLines = {}
  local inMembers = false
  for index = 1, numLines do
    local line = GetTooltipLine(index)
    local text = line and type(line.GetText) == "function" and line:GetText() or nil
    if type(text) == "string" and text ~= "" then
      if inMembers then
        table.insert(memberLines, {
          index = index,
          line = line,
          text = text,
        })
        if #memberLines >= memberCount then
          break
        end
      elseif string.find(StripColorCodes(text), needle, 1, true) then
        inMembers = true
      end
    end
  end
  return memberLines
end

local function TextContainsAll(text, ...)
  local plain = string.lower(StripColorCodes(text))
  for index = 1, select("#", ...) do
    local needle = select(index, ...)
    if type(needle) == "string" and needle ~= "" then
      local normalizedNeedle = string.lower(needle)
      if not string.find(plain, normalizedNeedle, 1, true) then
        return false
      end
    end
  end
  return true
end

local function MatchMemberLine(member, memberLines, usedLines)
  if type(member) ~= "table" or not member.suffix then
    return nil
  end
  if member.className and member.specName then
    for _, candidate in ipairs(memberLines) do
      if not usedLines[candidate.index] and TextContainsAll(candidate.text, member.className, member.specName) then
        return candidate
      end
    end
  end
  if member.specName then
    for _, candidate in ipairs(memberLines) do
      if not usedLines[candidate.index] and TextContainsAll(candidate.text, member.specName) then
        return candidate
      end
    end
  end
  return nil
end

local function ApplyGroupBonusTooltipLines(resultID)
  if not lfgGroupBonusesEnabled then
    return
  end
  local members = BuildSearchResultMemberBonuses(resultID)
  if type(members) ~= "table" then
    return
  end
  local memberLines = CollectTooltipMemberLines(#members)
  if #memberLines == 0 then
    return
  end

  local usedLines = {}
  local unmatchedMembers = {}
  for index, member in ipairs(members) do
    if type(member) == "table" and member.suffix then
      local line = MatchMemberLine(member, memberLines, usedLines)
      if line then
        usedLines[line.index] = true
        if type(line.line.SetText) == "function" and not HasExistingBonusSuffix(line.text) then
          line.line:SetText(line.text .. " " .. member.suffix)
        end
      else
        table.insert(unmatchedMembers, { index = index, member = member })
      end
    end
  end

  if #unmatchedMembers == 0 or #memberLines ~= #members then
    return
  end
  for _, unresolved in ipairs(unmatchedMembers) do
    local line = memberLines[unresolved.index]
    local member = unresolved.member
    if
      line
      and not usedLines[line.index]
      and type(line.line.SetText) == "function"
      and not HasExistingBonusSuffix(line.text)
    then
      usedLines[line.index] = true
      line.line:SetText(line.text .. " " .. member.suffix)
    end
  end
end

local function BuildCombinedSuffixFromMembers(members)
  if type(members) ~= "table" then
    return nil
  end
  local parts = {}
  local seen = {}
  for _, member in ipairs(members) do
    if type(member) == "table" and type(member.suffix) == "string" and member.suffix ~= "" then
      local plain = StripColorCodes(member.suffix)
      if not seen[plain] then
        seen[plain] = true
        table.insert(parts, member.suffix)
      end
    end
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts, " ")
end

local function ResolveApplicantIDFromButton(button)
  if type(button) ~= "table" then
    return nil
  end
  local candidate = rawget(button, "applicantID")
    or rawget(button, "applicantId")
    or rawget(button, "id")
    or rawget(button, "ID")
  local numericCandidate = ReadPositiveNumber(candidate)
  if numericCandidate then
    return numericCandidate
  end
  local parent = type(button.GetParent) == "function" and button:GetParent() or nil
  if type(parent) == "table" then
    return ResolveApplicantIDFromButton(parent)
  end
  return nil
end

local function ApplyApplicantBonusToButton(button, applicantIDOverride)
  if not lfgGroupBonusesEnabled then
    return
  end
  local applicantID = ReadPositiveNumber(applicantIDOverride) or ResolveApplicantIDFromButton(button)
  local members = applicantID and BuildApplicantMemberBonuses(applicantID) or nil
  local suffix = BuildCombinedSuffixFromMembers(members)
  if not suffix then
    return
  end

  local tooltip = rawget(_G, "GameTooltip")
  if type(tooltip) == "table" and type(tooltip.AddLine) == "function" and type(tooltip.Show) == "function" then
    local owner = type(tooltip.GetOwner) == "function" and tooltip:GetOwner() or nil
    if owner == button or owner == rawget(button, "InviteButton") or owner == rawget(button, "DeclineButton") then
      if TooltipHasApplicantBonusLine(suffix) then
        return
      end
      local tooltipText = ResolveLocalizedText("LFG_BONUS_TOOLTIP_FMT") or "Group bonus: %s"
      tooltip:AddLine(string.format(tooltipText, suffix), 0.85, 0.85, 0.9)
      tooltip:Show()
    end
  end
end

local function ResolveApplicantClassAnchor(member)
  if type(member) ~= "table" then
    return nil
  end
  local classAnchorKeys = {
    "ClassIcon",
    "Class",
    "ClassButton",
    "ClassIconTexture",
    "SpecIcon",
    "Spec",
    "SpecIconTexture",
  }
  for _, key in ipairs(classAnchorKeys) do
    local value = rawget(member, key)
    if type(value) == "table" then
      return value
    end
  end
  return nil
end

local function ResolveApplicantBonusAnchor(member)
  local classAnchor = ResolveApplicantClassAnchor(member)
  if classAnchor then
    return classAnchor
  end
  local nameText = type(member) == "table" and rawget(member, "Name") or nil
  if type(nameText) == "table" then
    return nameText
  end
  return nil
end

local function AnchorApplicantBonusBadge(member, badgeText)
  if type(member) ~= "table" or type(badgeText) ~= "table" or type(badgeText.SetPoint) ~= "function" then
    return
  end
  if type(badgeText.ClearAllPoints) == "function" then
    badgeText:ClearAllPoints()
  end
  local bonusAnchor = ResolveApplicantBonusAnchor(member)
  if bonusAnchor then
    badgeText:SetPoint("LEFT", bonusAnchor, "RIGHT", 5, 0)
    return
  end
  badgeText:SetPoint("LEFT", member, "LEFT", 104, 0)
end

local function HideApplicantBonusIcons(member)
  if type(member) ~= "table" or type(member._isiLiveBonusBadgeIcons) ~= "table" then
    return
  end
  for _, icon in ipairs(member._isiLiveBonusBadgeIcons) do
    if type(icon) == "table" and type(icon.Hide) == "function" then
      icon:Hide()
    end
  end
end

local function ResolveApplicantBonusTextureOwner(member)
  if type(member) ~= "table" then
    return nil
  end
  if type(member.CreateTexture) == "function" then
    return member
  end
  local parent = type(member.GetParent) == "function" and member:GetParent() or nil
  if type(parent) == "table" and type(parent.CreateTexture) == "function" then
    return parent
  end
  local nameText = rawget(member, "Name")
  local nameParent = type(nameText) == "table" and type(nameText.GetParent) == "function" and nameText:GetParent()
    or nil
  if type(nameParent) == "table" and type(nameParent.CreateTexture) == "function" then
    return nameParent
  end
  return nil
end

local function ClearApplicantBonusMarker(member)
  if type(member) ~= "table" then
    return
  end
  if member._isiLiveBonusText and type(member._isiLiveBonusText.SetText) == "function" then
    member._isiLiveBonusText:SetText("")
    if type(member._isiLiveBonusText.Hide) == "function" then
      member._isiLiveBonusText:Hide()
    end
  end
  if member._isiLiveBonusBadge and type(member._isiLiveBonusBadge.SetText) == "function" then
    member._isiLiveBonusBadge:SetText("")
    if type(member._isiLiveBonusBadge.Hide) == "function" then
      member._isiLiveBonusBadge:Hide()
    end
  end
  HideApplicantBonusIcons(member)
end

local function EnsureApplicantFlagTexture(member)
  local textureOwner = ResolveApplicantBonusTextureOwner(member)
  if type(member) ~= "table" or not textureOwner then
    return nil
  end
  if type(member._isiApplicantFlagTex) == "table" then
    return member._isiApplicantFlagTex
  end
  local tex = textureOwner:CreateTexture(nil, "OVERLAY")
  if type(tex.SetSize) == "function" then
    tex:SetSize(FLAG_WIDTH, FLAG_HEIGHT)
  end
  if type(tex.Hide) == "function" then
    tex:Hide()
  end
  member._isiApplicantFlagTex = tex
  return tex
end

local function RestoreApplicantNameAnchor(member)
  if type(member) ~= "table" then
    return
  end
  local nameText = rawget(member, "Name")
  local stored = rawget(member, "_isiApplicantNameOriginalPoint")
  if type(nameText) ~= "table" or type(stored) ~= "table" or type(nameText.SetPoint) ~= "function" then
    return
  end
  if type(nameText.ClearAllPoints) == "function" then
    nameText:ClearAllPoints()
  end
  nameText:SetPoint(stored.point, stored.relativeTo, stored.relativePoint, stored.offsetX, stored.offsetY)
end

local function AnchorApplicantFlag(member, nameText, tex)
  if
    type(member) ~= "table"
    or type(nameText) ~= "table"
    or type(tex) ~= "table"
    or type(tex.SetPoint) ~= "function"
    or type(nameText.SetPoint) ~= "function"
  then
    return
  end
  local stored = rawget(member, "_isiApplicantNameOriginalPoint")
  if type(stored) ~= "table" and type(nameText.GetPoint) == "function" then
    local point, relativeTo, relativePoint, offsetX, offsetY = nameText:GetPoint(1)
    if type(point) == "string" then
      stored = {
        point = point,
        relativeTo = relativeTo or member,
        relativePoint = relativePoint or point,
        offsetX = tonumber(offsetX) or 0,
        offsetY = tonumber(offsetY) or 0,
      }
      member._isiApplicantNameOriginalPoint = stored
    end
  end
  if type(stored) ~= "table" then
    if type(tex.ClearAllPoints) == "function" then
      tex:ClearAllPoints()
    end
    tex:SetPoint("LEFT", member, "LEFT", 6, 0)
    return
  end
  if type(tex.ClearAllPoints) == "function" then
    tex:ClearAllPoints()
  end
  tex:SetPoint(stored.point, stored.relativeTo, stored.relativePoint, stored.offsetX, stored.offsetY)
  if type(nameText.ClearAllPoints) == "function" then
    nameText:ClearAllPoints()
  end
  nameText:SetPoint(
    stored.point,
    stored.relativeTo,
    stored.relativePoint,
    stored.offsetX + APPLICANT_FLAG_NAME_SHIFT_X,
    stored.offsetY
  )
end

local function ApplyApplicantFlagToMemberFrame(member, applicantID, memberIndex)
  if type(member) ~= "table" then
    return
  end
  local tex = EnsureApplicantFlagTexture(member)
  if not tex then
    return
  end
  local function hide()
    if type(tex.Hide) == "function" then
      tex:Hide()
    end
    RestoreApplicantNameAnchor(member)
  end
  if not lfgFlagsEnabled then
    hide()
    return
  end
  applicantID = ReadPositiveNumber(applicantID)
  memberIndex = ReadPositiveNumber(memberIndex or rawget(member, "memberIdx"))
  if not applicantID or not memberIndex then
    hide()
    return
  end
  member._isiApplicantID = applicantID
  member._isiApplicantMemberIndex = memberIndex
  local applicantMember = ReadApplicantMemberInfo(applicantID, memberIndex)
  local tag = applicantMember and ResolveLanguageTagFromName(applicantMember.name)
  local path = tag and type(getFlagTexturePath) == "function" and getFlagTexturePath(tag)
  if not path then
    hide()
    return
  end
  if type(tex.SetTexture) == "function" then
    tex:SetTexture(path)
  end
  local nameText = rawget(member, "Name")
  AnchorApplicantFlag(member, nameText, tex)
  if type(tex.Show) == "function" then
    tex:Show()
  end
end

local function AnchorApplicantBonusIcon(member, icon, index)
  if type(member) ~= "table" or type(icon) ~= "table" or type(icon.SetPoint) ~= "function" then
    return
  end
  if type(icon.ClearAllPoints) == "function" then
    icon:ClearAllPoints()
  end
  if index and index > 1 and type(member._isiLiveBonusBadgeIcons) == "table" then
    local previousIcon = member._isiLiveBonusBadgeIcons[index - 1]
    if type(previousIcon) == "table" then
      icon:SetPoint("LEFT", previousIcon, "RIGHT", APPLICANT_BONUS_ICON_GAP, 0)
      return
    end
  end
  local bonusAnchor = ResolveApplicantBonusAnchor(member)
  if bonusAnchor then
    icon:SetPoint("LEFT", bonusAnchor, "RIGHT", 5, 0)
    return
  end
  icon:SetPoint("LEFT", member, "LEFT", 104, 0)
end

local function ApplyApplicantBonusIconMarkers(member, markerCount)
  markerCount = math.min(SEARCH_RESULT_BONUS_MAX_MARKERS, math.floor(tonumber(markerCount) or 0))
  local textureOwner = ResolveApplicantBonusTextureOwner(member)
  if markerCount <= 0 or type(member) ~= "table" or not textureOwner then
    return false
  end
  member._isiLiveBonusBadgeIcons = member._isiLiveBonusBadgeIcons or {}
  for index = 1, SEARCH_RESULT_BONUS_MAX_MARKERS do
    local icon = member._isiLiveBonusBadgeIcons[index]
    if type(icon) ~= "table" then
      icon = textureOwner:CreateTexture(nil, "OVERLAY")
      member._isiLiveBonusBadgeIcons[index] = icon
    end
    if type(icon) == "table" then
      if type(icon.SetSize) == "function" then
        icon:SetSize(APPLICANT_BONUS_ICON_SIZE, APPLICANT_BONUS_ICON_SIZE)
      end
      if type(icon.SetTexture) == "function" then
        icon:SetTexture(SEARCH_RESULT_BONUS_TEXTURE)
      end
      if type(icon.SetTexCoord) == "function" then
        icon:SetTexCoord(0, 1, 0, 1)
      end
      if type(icon.SetVertexColor) == "function" then
        icon:SetVertexColor(
          unpack((type(UICommon) == "table" and UICommon.Colors and UICommon.Colors.WHITE_OPAQUE) or { 1, 1, 1, 1 })
        )
      end
      AnchorApplicantBonusIcon(member, icon, index)
      if index <= markerCount then
        if type(icon.Show) == "function" then
          icon:Show()
        end
      elseif type(icon.Hide) == "function" then
        icon:Hide()
      end
    end
  end
  return true
end

local function ApplyApplicantBonusToMemberFrame(member, applicantID, memberIndex)
  if type(member) ~= "table" then
    return
  end
  hookedApplicantMembers[member] = true
  ApplyApplicantFlagToMemberFrame(member, applicantID, memberIndex)
  applicantID = ReadPositiveNumber(applicantID)
  memberIndex = ReadPositiveNumber(memberIndex or rawget(member, "memberIdx"))
  local badge, markerCount
  if applicantID and memberIndex then
    badge, _, markerCount = BuildSingleApplicantMemberBadge(applicantID, memberIndex)
  end
  local nameText = rawget(member, "Name")
  if type(nameText) ~= "table" or type(nameText.GetText) ~= "function" or type(nameText.SetText) ~= "function" then
    return
  end
  ClearApplicantBonusMarker(member)
  if not badge then
    return
  end
  if ApplyApplicantBonusIconMarkers(member, markerCount) then
    return
  end
end

local function ApplyApplicantMembersFromButton(button, applicantIDOverride)
  if type(button) ~= "table" then
    return
  end
  local applicantID = ReadPositiveNumber(applicantIDOverride) or ReadPositiveNumber(rawget(button, "applicantID"))
  local members = rawget(button, "Members")
  if not applicantID or type(members) ~= "table" then
    return
  end
  for index, member in pairs(members) do
    if type(member) == "table" then
      ApplyApplicantBonusToMemberFrame(member, applicantID, ReadPositiveNumber(rawget(member, "memberIdx")) or index)
    end
  end
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
  tex:SetPoint("LEFT", button, "LEFT", SEARCH_RESULT_FLAG_X, SEARCH_RESULT_FLAG_Y)

  tex:Hide()
  button._isiFlagTex = tex
  return tex
end

local function StripSearchResultKeystoneSuffix(text)
  if type(text) ~= "string" or text == "" then
    return text
  end
  local labels = {}
  local liveLabel = rawget(_G, "DUNGEON_DIFFICULTY_MYTHIC_KEYSTONE")
  if type(liveLabel) == "string" and liveLabel ~= "" then
    labels[liveLabel] = true
  end
  for label in pairs(SEARCH_RESULT_KEYSTONE_LABELS) do
    labels[label] = true
  end
  for label in pairs(labels) do
    local suffix = " (" .. label .. ")"
    if string.sub(text, -string.len(suffix)) == suffix then
      return string.sub(text, 1, string.len(text) - string.len(suffix))
    end
  end
  return text
end

local function ApplySearchResultActivityNameText(activityName)
  if
    type(activityName) ~= "table"
    or type(activityName.GetText) ~= "function"
    or type(activityName.SetText) ~= "function"
  then
    return
  end
  if rawget(activityName, "_isiActivityNameCleaning") == true then
    return
  end
  local currentText = activityName:GetText()
  local displayText = StripSearchResultKeystoneSuffix(currentText)
  if displayText == currentText then
    return
  end
  activityName._isiActivityNameCleaning = true
  activityName:SetText(displayText)
  activityName._isiActivityNameCleaning = nil
end

local function HookSearchResultActivityNameText(activityName)
  if
    type(activityName) ~= "table"
    or rawget(activityName, "_isiActivityNameTextHooked") == true
    or type(activityName.SetText) ~= "function"
  then
    return
  end
  local hooksecurefuncRef = rawget(_G, "hooksecurefunc")
  if type(hooksecurefuncRef) ~= "function" then
    return
  end
  activityName._isiActivityNameTextHooked = true
  pcall(hooksecurefuncRef, activityName, "SetText", function(self)
    ApplySearchResultActivityNameText(self)
  end)
end

local function GetStoredActivityNamePoint(button, activityName)
  local stored = rawget(button, "_isiActivityNameOriginalPoint")
  if type(stored) == "table" and rawget(button, "_isiActivityNameOriginalRegion") == activityName then
    return stored
  end
  if type(activityName.GetPoint) ~= "function" then
    return nil
  end
  local point, relativeTo, relativePoint, offsetX, offsetY = activityName:GetPoint(1)
  if type(point) ~= "string" then
    return nil
  end
  stored = {
    point = point,
    relativeTo = relativeTo or button,
    relativePoint = relativePoint or point,
    offsetX = tonumber(offsetX) or 0,
    offsetY = tonumber(offsetY) or 0,
  }
  button._isiActivityNameOriginalPoint = stored
  button._isiActivityNameOriginalRegion = activityName
  return stored
end

local function GetStoredPlaystylePoint(button, playstyle)
  local stored = rawget(button, "_isiPlaystyleOriginalPoint")
  if type(stored) == "table" and rawget(button, "_isiPlaystyleOriginalRegion") == playstyle then
    return stored
  end
  if type(playstyle) ~= "table" or type(playstyle.GetPoint) ~= "function" then
    return nil
  end
  local point, relativeTo, relativePoint, offsetX, offsetY = playstyle:GetPoint(1)
  if type(point) ~= "string" then
    return nil
  end
  stored = {
    point = point,
    relativeTo = relativeTo or button,
    relativePoint = relativePoint or point,
    offsetX = tonumber(offsetX) or 0,
    offsetY = tonumber(offsetY) or 0,
  }
  button._isiPlaystyleOriginalPoint = stored
  button._isiPlaystyleOriginalRegion = playstyle
  return stored
end

local function RestoreSearchResultPlaystyle(button, activityName, playstyleOriginalPoint)
  local playstyle = rawget(button, "Playstyle")
  if
    type(playstyle) ~= "table"
    or type(playstyle.SetPoint) ~= "function"
    or type(playstyleOriginalPoint) ~= "table"
  then
    return
  end
  local offsetX = playstyleOriginalPoint.offsetX
  if playstyleOriginalPoint.relativeTo == activityName then
    offsetX = offsetX - SEARCH_RESULT_DUNGEON_NAME_SHIFT_X
  end
  if type(playstyle.ClearAllPoints) == "function" then
    playstyle:ClearAllPoints()
  end
  playstyle:SetPoint(
    playstyleOriginalPoint.point,
    playstyleOriginalPoint.relativeTo,
    playstyleOriginalPoint.relativePoint,
    offsetX,
    playstyleOriginalPoint.offsetY
  )
end

local function AnchorSearchResultDungeonName(button)
  local activityName = rawget(button, "ActivityName")
  if type(activityName) ~= "table" or type(activityName.SetPoint) ~= "function" then
    return
  end
  HookSearchResultActivityNameText(activityName)
  local originalPoint = GetStoredActivityNamePoint(button, activityName)
  local playstyleOriginalPoint = GetStoredPlaystylePoint(button, rawget(button, "Playstyle"))
  if originalPoint then
    if type(activityName.ClearAllPoints) == "function" then
      activityName:ClearAllPoints()
    end
    activityName:SetPoint(
      originalPoint.point,
      originalPoint.relativeTo,
      originalPoint.relativePoint,
      originalPoint.offsetX + SEARCH_RESULT_DUNGEON_NAME_SHIFT_X,
      originalPoint.offsetY
    )

    local flagTex = EnsureFlagTexture(button)
    if type(flagTex.ClearAllPoints) == "function" then
      flagTex:ClearAllPoints()
    end
    flagTex:SetPoint(
      originalPoint.point,
      originalPoint.relativeTo,
      originalPoint.relativePoint,
      originalPoint.offsetX,
      originalPoint.offsetY + SEARCH_RESULT_FLAG_ACTIVITY_NAME_OFFSET_Y
    )
    RestoreSearchResultPlaystyle(button, activityName, playstyleOriginalPoint)
  end
  ApplySearchResultActivityNameText(activityName)
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

local function ConfigureSearchResultBonusBadgeText(badgeText)
  if type(badgeText.SetJustifyH) == "function" then
    badgeText:SetJustifyH("RIGHT")
  end
  if type(badgeText.SetWidth) == "function" then
    badgeText:SetWidth(SEARCH_RESULT_BONUS_WIDTH)
  end
  if type(badgeText.SetHeight) == "function" then
    badgeText:SetHeight(14)
  end
  if type(badgeText.SetShadowColor) == "function" then
    badgeText:SetShadowColor(0, 0, 0, 1)
  end
  if type(badgeText.SetShadowOffset) == "function" then
    badgeText:SetShadowOffset(1, -1)
  end
end

local function EnsureSearchResultBonusBadges(button)
  if type(button._isiSearchBonusBadges) == "table" then
    return button._isiSearchBonusBadges
  end
  if type(button.CreateFontString) ~= "function" then
    return nil
  end
  local badges = {}
  local badgeText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ConfigureSearchResultBonusBadgeText(badgeText)
  if type(badgeText.Hide) == "function" then
    badgeText:Hide()
  end
  badges[1] = badgeText
  button._isiSearchBonusBadges = badges
  return badges
end

local function AnchorSearchResultBonusBadge(button, badgeText)
  if type(badgeText) ~= "table" or type(badgeText.SetPoint) ~= "function" then
    return
  end
  if type(badgeText.ClearAllPoints) == "function" then
    badgeText:ClearAllPoints()
  end
  badgeText:SetPoint("RIGHT", button, "RIGHT", SEARCH_RESULT_BONUS_RIGHT_X, SEARCH_RESULT_BONUS_Y)
end

local function HideSearchResultBonusBadges(badges)
  if type(badges) ~= "table" then
    return
  end
  for _, badgeText in ipairs(badges) do
    if type(badgeText) == "table" then
      if type(badgeText.SetText) == "function" then
        badgeText:SetText("")
      end
      if type(badgeText.Hide) == "function" then
        badgeText:Hide()
      end
    end
  end
end

local function ApplySearchResultBonusBadge(button, resultID)
  local badges = EnsureSearchResultBonusBadges(button)
  if not badges then
    return
  end
  if IsSearchResultPromotionOfferedRow(button) then
    HideSearchResultBonusBadges(badges)
    return
  end
  local badge, badgeColor
  if lfgGroupBonusesEnabled then
    badge, badgeColor = BuildSearchResultBonusBadge(resultID)
  end
  if not badge then
    HideSearchResultBonusBadges(badges)
    return
  end
  local badgeText = badges[1]
  AnchorSearchResultBonusBadge(button, badgeText)
  if badgeColor and type(badgeText.SetTextColor) == "function" then
    badgeText:SetTextColor(badgeColor[1], badgeColor[2], badgeColor[3], badgeColor[4])
  end
  badgeText:SetText(badge)
  if type(badgeText.Show) == "function" then
    badgeText:Show()
  end
end

-- -------------------------------------------------------------------------
-- Hooking search-result buttons
-- -------------------------------------------------------------------------

local function UpdateButton(button)
  -- resultID is a direct field on the Blizzard LFG search result button.
  local resultID = rawget(button, "resultID")
  AnchorSearchResultDungeonName(button)
  ApplyFlagToButton(button, resultID)
  ApplySearchResultBonusBadge(button, resultID)
end

ViewHooks.Configure({
  applyApplicantMembersFromButton = ApplyApplicantMembersFromButton,
  applyApplicantBonusToButton = ApplyApplicantBonusToButton,
  resolveApplicantIDFromButton = ResolveApplicantIDFromButton,
  applyApplicantBonusToMemberFrame = ApplyApplicantBonusToMemberFrame,
  showApplicantMemberTooltip = function(member)
    HideApplicantProvingGroundTooltipLines()
    local parent = type(member) == "table" and type(member.GetParent) == "function" and member:GetParent() or nil
    local applicantID = parent and rawget(parent, "applicantID") or nil
    local memberIndex = type(member) == "table" and rawget(member, "memberIdx") or nil
    local suffix = BuildSingleApplicantMemberSuffix(applicantID, memberIndex)
    local tooltip = rawget(_G, "GameTooltip")
    if
      suffix
      and type(tooltip) == "table"
      and type(tooltip.AddLine) == "function"
      and type(tooltip.Show) == "function"
    then
      tooltip:AddLine(" ")
      local tooltipText = ResolveLocalizedText("LFG_BONUS_TOOLTIP_FMT") or "Group bonus: %s"
      tooltip:AddLine(string.format(tooltipText, suffix), 0.20, 1.00, 0.20)
      tooltip:Show()
    end
  end,
  updateSearchButton = UpdateButton,
  applyGroupBonusTooltipLines = ApplyGroupBonusTooltipLines,
  clearSearchCaches = function()
    resultTagCache = {}
    ClearSearchResultBonusCache()
  end,
  refreshSearchResultTooltip = function(resultID)
    ClearSearchResultBonusCache(resultID)
    ViewHooks.ForEachSearchButton(function(button)
      if rawget(button, "resultID") == resultID then
        ApplyFlagToButton(button, resultID)
        ApplySearchResultBonusBadge(button, resultID)
      end
    end)
    ApplyGroupBonusTooltipLines(resultID)
  end,
})

-- -------------------------------------------------------------------------
-- Panel wiring
-- -------------------------------------------------------------------------

-- Expose internal helpers under addonTable._LFGFlagsInternal so the
-- test suite can drive them directly. The production code paths
-- continue to call the local references; assigning them to LI is
-- behaviour-neutral.
LI.SplitNameRealm = SplitNameRealm
LI.GetTagForResult = GetTagForResult
LI.EnsureFlagTexture = EnsureFlagTexture
LI.StripSearchResultKeystoneSuffix = StripSearchResultKeystoneSuffix
LI.ApplySearchResultActivityNameText = ApplySearchResultActivityNameText
LI.HookSearchResultActivityNameText = HookSearchResultActivityNameText
LI.AnchorSearchResultDungeonName = AnchorSearchResultDungeonName
LI.ApplyFlagToButton = ApplyFlagToButton
LI.UpdateButton = UpdateButton
LI.HookButton = ViewHooks.HookButton
LI.HookButtons = ViewHooks.HookButtons
LI.RefreshAll = ViewHooks.RefreshAll
LI.BuildBonusSuffix = BuildBonusSuffix
LI.BuildSearchResultMemberBonuses = BuildSearchResultMemberBonuses
LI.BuildSearchResultBonusBadge = BuildSearchResultBonusBadge
LI.BuildApplicantMemberBonuses = BuildApplicantMemberBonuses
LI.ApplyApplicantBonusToMemberFrame = ApplyApplicantBonusToMemberFrame
LI.ApplyApplicantFlagToMemberFrame = ApplyApplicantFlagToMemberFrame
LI.ApplyApplicantMembersFromButton = ApplyApplicantMembersFromButton
LI.HookApplicantButton = ViewHooks.HookApplicantButton
LI.ApplyApplicantBonusToButton = ApplyApplicantBonusToButton
LI.ApplyGroupBonusTooltipLines = ApplyGroupBonusTooltipLines
LI.ResolvePlayerBonusProfile = ResolvePlayerBonusProfile
LI.BuildApplicantBonusBadge = BuildApplicantBonusBadge
LI.BuildApplicantBonusMarkerBadge = BuildApplicantBonusMarkerBadge
LI.BuildRosterBonusMarkerBadge = BuildRosterBonusMarkerBadge
LI.BuildRosterBonusTooltipLine = BuildRosterBonusTooltipLine
LI.ResolveApplicantClassAnchor = ResolveApplicantClassAnchor
LI.ResolveApplicantBonusAnchor = ResolveApplicantBonusAnchor
LI.AnchorApplicantBonusBadge = AnchorApplicantBonusBadge
LI.ResolveApplicantIDFromButton = ResolveApplicantIDFromButton
LI.ResolveApplicantBonusTextureOwner = ResolveApplicantBonusTextureOwner
LI.ClearApplicantBonusMarker = ClearApplicantBonusMarker
LI.HideApplicantProvingGroundTooltipLines = HideApplicantProvingGroundTooltipLines
LI.IsSearchResultPromotionOfferedRow = IsSearchResultPromotionOfferedRow
LI.ResetCacheForTests = function()
  resultTagCache = {}
  resultBonusBadgeCache = {}
  resultMemberBonusCache = {}
end
LI.GetCacheForTests = function()
  return resultTagCache
end

function LFGFlags.HookSearchPanel()
  ViewHooks.HookSearchPanel()
end

-- -------------------------------------------------------------------------
-- Public: called from factory
-- -------------------------------------------------------------------------

function LFGFlags.SetEnabled(enabled)
  lfgFlagsEnabled = enabled ~= false
  if not lfgFlagsEnabled then
    ViewHooks.ForEachSearchButton(function(button)
      local tex = rawget(button, "_isiFlagTex")
      if tex and type(tex.Hide) == "function" then
        tex:Hide()
      end
    end)
    for member in pairs(hookedApplicantMembers) do
      local tex = rawget(member, "_isiApplicantFlagTex")
      if tex and type(tex.Hide) == "function" then
        tex:Hide()
      end
    end
  else
    ViewHooks.ForEachSearchButton(UpdateButton)
    for member in pairs(hookedApplicantMembers) do
      ApplyApplicantFlagToMemberFrame(
        member,
        rawget(member, "_isiApplicantID"),
        rawget(member, "_isiApplicantMemberIndex") or rawget(member, "memberIdx")
      )
    end
  end
end

function LFGFlags.SetGroupBonusesEnabled(enabled)
  lfgGroupBonusesEnabled = enabled ~= false
  BonusModel.SetEnabled(lfgGroupBonusesEnabled)
  ClearSearchResultBonusCache()
  ViewHooks.ForEachSearchButton(function(button)
    ApplySearchResultBonusBadge(button, rawget(button, "resultID"))
  end)
  if lfgGroupBonusesEnabled then
    return
  end
  for member in pairs(hookedApplicantMembers) do
    ClearApplicantBonusMarker(member)
  end
end

function LFGFlags.BuildRosterBonusMarkerBadge(classToken, specID)
  return BuildRosterBonusMarkerBadge(classToken, specID)
end

function LFGFlags.BuildRosterBonusTooltipLine(classToken, specID)
  return BuildRosterBonusTooltipLine(classToken, specID)
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

  ViewHooks.RegisterWhenAvailable(function()
    LFGFlags.HookSearchPanel()
  end)
end
