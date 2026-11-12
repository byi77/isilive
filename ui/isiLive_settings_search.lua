local _, addonTable = ...
addonTable = addonTable or {}

-- Search inside isiLive's config window (rule 241, stage 2 of rule 237).
-- The settings content is a list of layout rows (SettingsLayout.RegisterLayout);
-- every row knows the frames and regions it created. A search hides the rows
-- that do not match and lets SettingsLayout.Relayout close the gaps; an empty
-- search shows exactly the rows it hid and the layout is the original one.
--
-- Matching: every word of the query must occur in the control's label,
-- description, English tags (CONTROL_TAGS / SECTION_TAGS, so "interrupt"
-- finds the kick options in every language), section heading or navigation
-- label. Texts are normalized by SettingsSearch.Normalize: color codes and
-- textures are dropped, ASCII is lower-cased, and the letters of the five UI
-- languages fold to a common form (case and accents: "É" -> "e", "ß" -> "ss",
-- Turkish "İ"/"ı" -> "i", Cyrillic "Д" -> "д", "ё" -> "е"). Lua's string.lower
-- works on bytes, so the folding works on whole UTF-8 sequences from a table.
-- Limit: letters outside ASCII, Latin-1, the Turkish / French extras and the
-- basic Cyrillic block (U+0400-U+045F) are compared byte for byte, i.e.
-- case-sensitively; they never break a multibyte sequence.
local SettingsSearch = {}
addonTable.SettingsSearch = SettingsSearch

-- Delay between the last keystroke and the filter pass.
SettingsSearch.DEBOUNCE_SECONDS = 0.15

-- English keywords for every control of a navigation section.
SettingsSearch.SECTION_TAGS = {
  general = { "general" },
  display = { "display", "appearance" },
  behavior = { "behavior", "behaviour" },
  nameplates = { "nameplate", "plate", "forces", "count" },
  sounds = { "sound", "audio", "alert" },
  raid = { "raid" },
  chat = { "chat", "announce" },
  esc = { "esc", "menu", "shortcut" },
  admin = { "admin", "debug", "log" },
  reset = { "reset", "default" },
  vip = { "vip", "mute" },
}

-- English keywords per control key (GetSearchEntries keys).
SettingsSearch.CONTROL_TAGS = {
  lang = { "language", "locale" },
  defaultLayout = { "layout", "mode" },
  uiDesign = { "design", "theme", "modern", "classic", "style" },
  uiScale = { "scale", "size", "zoom" },
  bgAlpha = { "opacity", "transparency", "alpha", "background" },
  uiFontFamily = { "font", "typeface" },
  displayReset = { "reset", "default" },
  statsBoxEnabled = { "stats", "statsbox" },
  statsBoxLocked = { "stats", "statsbox", "lock" },
  statsBoxBgAlpha = { "stats", "statsbox", "opacity" },
  statsBoxFontSizeOffset = { "stats", "statsbox", "font" },
  statsBoxDisplayMode = { "stats", "statsbox" },
  statsBoxShowLeech = { "stats", "statsbox" },
  statsBoxShowSpeed = { "stats", "statsbox" },
  statsBoxShowDurability = { "stats", "statsbox", "repair" },
  statsBoxShowStamina = { "stats", "statsbox" },
  statsBoxShowAvoidance = { "stats", "statsbox" },
  minimapBtn = { "minimap", "icon" },
  portalNavigator = { "teleport", "portal", "timeways", "navigator" },
  forcesPace = { "pace", "killtracker", "forces" },
  timePace = { "pace", "killtracker", "timer" },
  ttk = { "ttk", "time to kill" },
  ttkImportant = { "ttk", "time to kill" },
  loadoutCheck = { "talent", "loot", "loadout", "spec" },
  instanceResetButton = { "reset", "instance" },
  missedKickAlert = { "interrupt", "kick" },
  missedKickOnlyInKey = { "interrupt", "kick" },
  missedKickSound = { "interrupt", "kick", "sound" },
  lfgFlags = { "lfg", "group finder", "flag", "language" },
  lfgGroupBonuses = { "lfg", "group finder", "buff" },
  tooltipFlags = { "tooltip", "flag", "language" },
  acceptedInviteNotice = { "invite", "lfg" },
  groupJoinNotice = { "invite", "lfg", "target" },
  sync = { "sync", "share" },
  lockMainFramePosition = { "lock", "move", "position" },
  editModeIntegration = { "edit mode", "move", "position", "layout", "scale" },
  combatFadeMM = { "combat", "fade" },
  autoShowStartup = { "auto", "login", "reload" },
  autoOpen = { "auto", "queue" },
  autoOpenKeyEnd = { "auto", "key" },
  autoCloseOnKeyStart = { "auto", "key" },
  autoCloseOnSoloChange = { "auto", "group" },
  nameplateDisplayMode = { "nameplate", "tooltip" },
  nameplateShowPercent = { "nameplate", "percent" },
  nameplateShowRemaining = { "nameplate", "remaining" },
  nameplateFontSize = { "nameplate", "font" },
  nameplatePosition = { "nameplate", "anchor" },
  nameplateXOffset = { "nameplate", "offset" },
  nameplateYOffset = { "nameplate", "offset" },
  soundChannelSelector = { "sound", "channel", "master", "sfx" },
  -- Sound alert checkboxes, listed as "soundChecks.<sound key>".
  soundChecks = {
    leader_transfer = { "leader", "lead" },
    group_join = { "group", "full" },
    ready_check_complete = { "ready check" },
    portal_available = { "summon", "portal" },
    group_invite = { "invite" },
    group_removed = { "removed", "kicked" },
    battle_res = { "battle res", "brez", "combat res" },
    battle_res_ready = { "battle res", "brez", "combat res" },
    bloodlust = { "bloodlust", "heroism", "lust" },
    bloodlust_soon = { "bloodlust", "heroism", "lust" },
    bloodlust_ready = { "bloodlust", "heroism", "lust", "sated" },
    power_infusion_received = { "power infusion" },
    pet_stuck = { "pet" },
    tank_died = { "tank", "death" },
    healer_died = { "healer", "death" },
  },
  incomingSummonLoopCheck = { "summon", "repeat" },
  groupInviteLoopCheck = { "invite", "repeat" },
  bloodlustReadyReminderCheck = { "bloodlust", "heroism", "lust", "repeat" },
  ownTankDiedSoundCheck = { "tank", "death" },
  ownHealerDiedSoundCheck = { "healer", "death" },
  raidIncomingSummonSound = { "summon", "sound" },
  raidPetStuckSound = { "pet", "sound" },
  raidLeaderTransferSound = { "leader", "sound" },
  chatAnnounceBR = { "battle res", "brez", "combat res" },
  chatAnnounceLust = { "bloodlust", "heroism", "lust" },
  powerInfusionTextAlert = { "power infusion" },
  instanceResetAnnounce = { "reset", "instance" },
  escPanel = { "teleport", "portal", "hearthstone", "mount" },
  hearthstoneSelect = { "hearthstone", "hs", "toy", "home" },
  combatLog = { "combat log", "logging", "warcraftlogs", "wcl" },
  dmReset = { "damage meter", "meter" },
  queueDebug = { "queue" },
  clearQueueDebugBtn = { "queue", "clear" },
  runtimeLog = { "runtime" },
  clearRuntimeLogBtn = { "runtime", "clear" },
  probeLog = { "probe", "api" },
  resetUiBtn = { "position", "resetui" },
  resetDBBtn = { "settings", "factory" },
  vipAstralAurochsSound = { "mount", "sound" },
  vipGrandExpeditionYakSound = { "mount", "sound" },
  vipGrandExpeditionYakVendorSound = { "mount", "vendor", "sound" },
  vipGildedBrutosaurSound = { "mount", "sound" },
  vipBloodlustDebuffButtonWarning = { "bloodlust", "sated", "button" },
  vipDkSoulReaperWarning = { "death knight", "dk" },
  vipDkPutrefyWarning = { "death knight", "dk" },
  vipDkApocalypseHorseSound = { "death knight", "dk", "sound" },
  vipDkGhoulReminder = { "death knight", "dk", "pet" },
}

-- English tags of a control key; "<group>.<key>" reads the nested group.
function SettingsSearch.GetControlTags(key)
  local tags = SettingsSearch.CONTROL_TAGS
  local group, member = tostring(key or ""):match("^([^.]+)%.(.+)$")
  if group and type(tags[group]) == "table" then
    return tags[group][member] or {}
  end
  local direct = tags[key]
  if type(direct) == "table" and direct[1] ~= nil then
    return direct
  end
  return {}
end

local function EncodeUtf8(codepoint)
  if codepoint < 0x80 then
    return string.char(codepoint)
  end
  if codepoint < 0x800 then
    return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + (codepoint % 0x40))
  end
  return string.char(
    0xE0 + math.floor(codepoint / 0x1000),
    0x80 + (math.floor(codepoint / 0x40) % 0x40),
    0x80 + (codepoint % 0x40)
  )
end

-- Multibyte UTF-8 letter -> folded form. ASCII is lower-cased separately.
local FOLD = {}
do
  -- Latin-1 supplement U+00C0..U+00FF, upper and lower half fold alike.
  local latin1 = {
    "a",
    "a",
    "a",
    "a",
    "a",
    "a",
    "ae",
    "c",
    "e",
    "e",
    "e",
    "e",
    "i",
    "i",
    "i",
    "i",
    "d",
    "n",
    "o",
    "o",
    "o",
    "o",
    "o",
    false, -- U+00D7 multiplication sign
    "o",
    "u",
    "u",
    "u",
    "u",
    "y",
    "th",
    "ss",
  }
  for index, folded in ipairs(latin1) do
    if folded then
      FOLD[EncodeUtf8(0xBF + index)] = folded
      if index ~= 32 then
        FOLD[EncodeUtf8(0xDF + index)] = folded
      end
    end
  end
  FOLD[EncodeUtf8(0xFF)] = "y"
  -- Turkish and French letters outside Latin-1.
  local extras = {
    [0x011E] = "g",
    [0x011F] = "g",
    [0x0130] = "i",
    [0x0131] = "i",
    [0x015E] = "s",
    [0x015F] = "s",
    [0x0152] = "oe",
    [0x0153] = "oe",
    [0x0178] = "y",
  }
  for codepoint, folded in pairs(extras) do
    FOLD[EncodeUtf8(codepoint)] = folded
  end
  -- Cyrillic: А..Я -> а..я, Ѐ..Џ -> ѐ..џ; Ё/ё fold to е.
  for codepoint = 0x0410, 0x042F do
    FOLD[EncodeUtf8(codepoint)] = EncodeUtf8(codepoint + 0x20)
  end
  for codepoint = 0x0400, 0x040F do
    FOLD[EncodeUtf8(codepoint)] = EncodeUtf8(codepoint + 0x50)
  end
  FOLD[EncodeUtf8(0x0401)] = EncodeUtf8(0x0435)
  FOLD[EncodeUtf8(0x0451)] = EncodeUtf8(0x0435)
end
SettingsSearch._FOLD = FOLD

-- Returns the comparable form of a text (see the header comment).
function SettingsSearch.Normalize(text)
  if type(text) ~= "string" or text == "" then
    return ""
  end
  local value = text
  value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
  value = value:gsub("|r", "")
  value = value:gsub("|T.-|t", " ")
  value = value:gsub("|A.-|a", " ")
  value = value:gsub("|n", " ")
  value = value:gsub("[A-Z]", string.lower)
  value = value:gsub("[\192-\244][\128-\191]*", FOLD)
  value = value:gsub("%s+", " ")
  return value
end

-- Splits a query into normalized words; an empty or blank query has none.
function SettingsSearch.Tokenize(query)
  local words = {}
  for word in SettingsSearch.Normalize(query):gmatch("%S+") do
    words[#words + 1] = word
  end
  return words
end

local function MatchesAll(haystack, words)
  for _, word in ipairs(words) do
    if not haystack:find(word, 1, true) then
      return false
    end
  end
  return true
end

local function ReadText(region)
  if type(region) == "table" and type(region.GetText) == "function" then
    local text = region:GetText()
    if type(text) == "string" then
      return text
    end
  end
  return ""
end

local function IsShown(object)
  if type(object.IsShown) == "function" then
    return object:IsShown() == true
  end
  return object.hidden ~= true
end

-- Row model of the built content, made once on the first search: the owner
-- row of every claimed object (the row of the object it is anchored to, such
-- as a label or preview button next to a checkbox, else its creation row),
-- plus the section block (heading row) and navigation section of every row.
-- Returns nil when the rows carry no widget lists (parent without
-- GetChildren / GetRegions): then nothing can be hidden.
local function BuildModel(content, sections)
  local rows = type(content) == "table" and content._isiLiveSettingsRows or nil
  if type(rows) ~= "table" or #rows == 0 then
    return nil
  end
  local creationRow = {}
  for index, row in ipairs(rows) do
    if type(row.regions) ~= "table" then
      return nil
    end
    for _, object in ipairs(row.regions) do
      creationRow[object] = index
    end
  end

  -- The claimed ancestor of a region (a button's label -> the button).
  local function ContentLevel(object)
    local current = object
    for _ = 1, 20 do
      if type(current) ~= "table" then
        return nil
      end
      if creationRow[current] then
        return current
      end
      current = type(current.GetParent) == "function" and current:GetParent() or nil
    end
    return nil
  end

  local ownerRow = {}
  local function ResolveOwner(object, depth)
    if ownerRow[object] then
      return ownerRow[object]
    end
    local row = creationRow[object]
    if depth < 10 and type(object.GetPoint) == "function" then
      local _, relativeTo = object:GetPoint(1)
      local anchor = relativeTo ~= object and ContentLevel(relativeTo) or nil
      if anchor and anchor ~= object then
        row = ResolveOwner(anchor, depth + 1) or row
      end
    end
    ownerRow[object] = row
    return row
  end

  local objectsByRow = {}
  for index in ipairs(rows) do
    objectsByRow[index] = {}
  end
  for object in pairs(creationRow) do
    table.insert(objectsByRow[ResolveOwner(object, 0)], object)
  end

  local headerOf, navOf = {}, {}
  local currentHeader = nil
  for index, row in ipairs(rows) do
    if row.kind == "header" then
      currentHeader = index
    end
    headerOf[index] = currentHeader
    for _, section in ipairs(sections) do
      if type(section.startY) == "number" and row.startY <= section.startY then
        navOf[index] = section.key
      end
    end
  end

  return {
    rows = rows,
    objectsByRow = objectsByRow,
    headerOf = headerOf,
    navOf = navOf,
    RowOf = function(region)
      local object = ContentLevel(region)
      return object and ResolveOwner(object, 0) or nil
    end,
  }
end

-- Searchable words of a row's surroundings: section heading, navigation
-- label and the navigation section's English tags.
local function BuildContextReader(model, sections)
  local navLabels = {}
  for _, section in ipairs(sections) do
    navLabels[section.key] = SettingsSearch.Normalize(section.label)
  end
  return function(index)
    local parts = {}
    local header = model.headerOf[index]
    if header then
      parts[#parts + 1] = SettingsSearch.Normalize(ReadText(model.rows[header].text))
    end
    local nav = model.navOf[index]
    if nav then
      parts[#parts + 1] = navLabels[nav] or ""
      for _, tag in ipairs(SettingsSearch.SECTION_TAGS[nav] or {}) do
        parts[#parts + 1] = tag
      end
    end
    return table.concat(parts, " ")
  end
end

-- Matches every labelled control against `words`.
local function MatchEntries(model, entries, words, Context)
  local hits = { entryRows = {}, visible = {}, keys = {}, matchCount = 0, sectionHits = {}, headerHasHit = {} }
  for _, entry in ipairs(entries) do
    local index = model.RowOf(entry.region)
    if index then
      hits.entryRows[index] = true
      local parts = {
        SettingsSearch.Normalize(entry.label),
        SettingsSearch.Normalize(entry.description),
        Context(index),
      }
      for _, tag in ipairs(SettingsSearch.GetControlTags(entry.key)) do
        parts[#parts + 1] = tag
      end
      if MatchesAll(table.concat(parts, " "), words) then
        hits.visible[index] = true
        hits.keys[entry.key] = true
        hits.matchCount = hits.matchCount + 1
        if model.navOf[index] then
          hits.sectionHits[model.navOf[index]] = true
        end
        if model.headerOf[index] then
          hits.headerHasHit[model.headerOf[index]] = true
        end
      end
    end
  end
  return hits
end

-- A preview follows the hits of its own controls (previewFor) or, without
-- that list, any hit in its block.
local function IsPreviewShown(row, header, hits)
  if type(row.previewFor) == "table" then
    for _, key in ipairs(row.previewFor) do
      if hits.keys[key] then
        return true
      end
    end
    return false
  end
  return header ~= nil and hits.headerHasHit[header] == true
end

-- Decides the visibility of every row for `words`.
local function Evaluate(model, words, entries, sections)
  local Context = BuildContextReader(model, sections)
  local hits = MatchEntries(model, entries, words, Context)

  -- A heading whose own words (heading, navigation label, section tags)
  -- match opens its whole block.
  local openHeader = {}
  for index, row in ipairs(model.rows) do
    if row.kind == "header" and MatchesAll(Context(index), words) then
      openHeader[index] = true
      hits.headerHasHit[index] = true
      if model.navOf[index] then
        hits.sectionHits[model.navOf[index]] = true
      end
    end
  end

  local visible = {}
  local previousVisible = false
  for index, row in ipairs(model.rows) do
    local header = model.headerOf[index]
    local show = hits.visible[index] == true
    if row.kind == "header" then
      show = hits.headerHasHit[index] == true
    elseif header and openHeader[header] then
      show = true
    elseif row.kind == "preview" then
      show = IsPreviewShown(row, header, hits)
    elseif not hits.entryRows[index] and row.kind == nil and #model.objectsByRow[index] == 0 then
      -- A spacer whose widgets hang off the row above follows that row.
      show = previousVisible
    end
    visible[index] = show
    previousVisible = show
  end
  return visible, hits.matchCount, hits.sectionHits
end

-- opts.content: the scroll child holding the rows.
-- opts.getEntries(): labelled controls (SettingsPanel.GetSearchEntries).
-- opts.getSections(): navigation sections in order, each
--   { key = <nav key>, label = <current label>, startY = <original y> }.
function SettingsSearch.Create(opts)
  opts = opts or {}
  local content = opts.content
  local getEntries = type(opts.getEntries) == "function" and opts.getEntries or function()
    return {}
  end
  local getSections = type(opts.getSections) == "function" and opts.getSections or function()
    return {}
  end
  local search = { query = "", words = {} }
  local model = nil
  local hiddenObjects = {}

  local function EnsureModel()
    if not model then
      model = BuildModel(content, getSections())
    end
    return model
  end

  function search.IsActive()
    return #search.words > 0
  end

  function search.GetQuery()
    return search.query
  end

  -- Shows exactly what the last Apply hid and clears the row flags.
  function search.Restore()
    if model then
      for _, row in ipairs(model.rows) do
        row.searchHidden = nil
      end
    end
    for index = #hiddenObjects, 1, -1 do
      local object = hiddenObjects[index]
      if type(object.Show) == "function" then
        object:Show()
      end
      hiddenObjects[index] = nil
    end
  end

  -- Filters the rows for `query`. Returns { active, available, matchCount,
  -- visibleRows, sectionHits = { [navKey] = true } }. The caller relayouts.
  function search.Apply(query)
    search.Restore()
    search.query = type(query) == "string" and query or ""
    search.words = SettingsSearch.Tokenize(search.query)
    local result = { active = #search.words > 0, matchCount = 0, sectionHits = {}, available = true, visibleRows = 0 }
    if not result.active then
      return result
    end
    local m = EnsureModel()
    if not m then
      result.available = false
      return result
    end
    local visible, matchCount, sectionHits = Evaluate(m, search.words, getEntries(), getSections())
    result.matchCount = matchCount
    result.sectionHits = sectionHits
    for index, row in ipairs(m.rows) do
      if visible[index] then
        result.visibleRows = result.visibleRows + 1
      else
        row.searchHidden = true
        for _, object in ipairs(m.objectsByRow[index]) do
          if IsShown(object) and type(object.Hide) == "function" then
            object:Hide()
            hiddenObjects[#hiddenObjects + 1] = object
          end
        end
      end
    end
    return result
  end

  return search
end
