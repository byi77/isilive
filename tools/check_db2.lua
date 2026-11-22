#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Game data check and next-season draft (rule 265, maintainability package 6
-- L and M). Reads Blizzard's client tables (DB2) of one build as CSV, as
-- exported by wago.tools (/db2/<table>/csv?version=<version>; their
-- robots.txt allows exactly these CSV exports and /api/), and
--
--  1. checks every ID the addon ships in data/ against that build: spells
--     (spell manifest, interrupts, defensive manifest casts and auras,
--     consumables, portals of the active and the prepared season), items,
--     challenge maps, LFG activities (exist, belong to
--     the challenge map's instance and are keystone activities) and
--     specializations (manifest specs exist; a regular spec of a playable class
--     missing from data/isiLive_specs.lua is reported); every defensive spec
--     must be a spec of the record's class in data/isiLive_specs.lua, and, when
--     the cooldown tables are present, every defensive `cooldown` must match
--     DB2 (rule 267, see DeriveCooldownSeconds);
--  2. reads the newest Mythic+ dungeon rotation (MythicPlusSeasonTrackedMap).
--     When no configured season has that map set, it drafts the next season:
--     intake rows for docs/SEASON_INTAKE.md (Status `candidate`, with source
--     and date) and a manifest skeleton for data/isiLive_seasons.lua. Portal
--     spells are the Hero's Path flyout spells whose name subtext equals the
--     dungeon name; anything not unique stays `unresolved`. Short codes,
--     display order and the portal navigator are never drafted.
--
-- Usage (from repo root):
--   lua tools/check_db2.lua --db2=<dir> [--version=<build>] [--season-id=<id>] [--date=YYYY-MM-DD]
--
-- <dir> holds: SpellName.csv, Spell.csv, SpellFlyoutItem.csv, Item.csv,
-- MapChallengeMode.csv, MapChallengeMode.deDE.csv, GroupFinderActivity.csv,
-- ChrSpecialization.csv, MythicPlusSeasonTrackedMap.csv; optional
-- SpellCooldowns.csv, SpellCategories.csv and SpellCategory.csv for the
-- defensive cooldown check (skipped with a note when one is missing).
-- Exit codes: 0 all IDs found and the newest rotation is a configured season,
-- 1 missing or inconsistent IDs or an unknown next season, 2 input error.

local M = {}

local KEYSTONE_DIFFICULTY_ID = 8
local PLAYABLE_CLASS_MAX = 13
local REGULAR_SPEC_ORDER_MAX = 3

local function ReadData(path)
  local addonTable = {}
  local chunk, err = loadfile(path)
  if not chunk then
    return nil, err
  end
  local ok, runErr = pcall(chunk, "isiLive", addonTable)
  if not ok then
    return nil, runErr
  end
  return addonTable
end

-- One CSV line into fields: quoted fields may hold commas and doubled quotes.
function M.ParseLine(line)
  local out, pos, len = {}, 1, #line
  while pos <= len + 1 do
    if line:sub(pos, pos) == '"' then
      local parts, i = {}, pos + 1
      while true do
        local q = line:find('"', i, true)
        if not q then
          parts[#parts + 1] = line:sub(i)
          pos = len + 2
          break
        end
        if line:sub(q + 1, q + 1) == '"' then
          parts[#parts + 1] = line:sub(i, q)
          i = q + 2
        else
          parts[#parts + 1] = line:sub(i, q - 1)
          pos = q + 2
          break
        end
      end
      out[#out + 1] = table.concat(parts)
    else
      local comma = line:find(",", pos, true) or (len + 1)
      out[#out + 1] = line:sub(pos, comma - 1)
      pos = comma + 1
    end
  end
  return out
end

-- Rows of a CSV as tables keyed by column name. `keep(idText)` may skip rows
-- by the text of the first field before the line is parsed (large tables).
function M.ReadCsv(path, keep)
  local file = io.open(path, "rb")
  if not file then
    return nil, "missing " .. path
  end
  local header
  local rows = {}
  local pending
  for rawLine in file:lines() do
    local line = rawLine:gsub("\r$", "")
    -- A quoted field may span lines (descriptions): join until the quotes balance.
    if pending then
      line = pending .. "\n" .. line
      pending = nil
    end
    local _, quotes = line:gsub('"', "")
    if quotes % 2 == 1 then
      pending = line
      line = nil
    end
    if line == nil then -- luacheck: ignore 542
      -- waiting for the rest of a multi-line record
    elseif not header then
      header = M.ParseLine(line)
    elseif line ~= "" then
      local first = line:match('^"?([^,"]*)')
      if not keep or keep(first) then
        local fields = M.ParseLine(line)
        local row = {}
        for index, name in ipairs(header) do
          row[name] = fields[index]
        end
        rows[#rows + 1] = row
      end
    end
  end
  file:close()
  return rows
end

-- IDs present in the first column of a table (SpellName, Item).
local function ReadIdSet(path, wanted)
  local file = io.open(path, "rb")
  if not file then
    return nil, "missing " .. path
  end
  local found = {}
  local first = true
  for line in file:lines() do
    if first then
      first = false
    else
      local id = tonumber(line:match("^(%d+),"))
      if id and wanted[id] then
        found[id] = true
      end
    end
  end
  file:close()
  return found
end

local function Num(value)
  return tonumber(value)
end

local function SortedKeys(set)
  local keys = {}
  for key in pairs(set) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)
  return keys
end

-- Every spell, item, map and activity the addon ships, each with a label.
function M.CollectShippedIDs(data)
  local ids = { spells = {}, items = {}, maps = {}, activities = {} }
  local function AddSpell(id, label)
    if type(id) == "number" then
      ids.spells[id] = ids.spells[id] or label
    end
  end
  local spells = data.SpellManifest or {}
  for _, listName in ipairs({ "battleRes", "lustCasts", "lustSated" }) do
    for _, record in ipairs(spells[listName] or {}) do
      AddSpell(record.id, listName .. " " .. tostring(record.name))
    end
  end
  for key, id in pairs(spells.icons or {}) do
    AddSpell(id, "icon " .. key)
  end
  AddSpell(spells.powerInfusion, "Power Infusion")
  local defensives = data.DefensiveManifest or {}
  for castID, record in pairs(defensives.spells or {}) do
    AddSpell(castID, "defensive cast " .. tostring(record.name))
    AddSpell(record.aura, "defensive aura " .. tostring(record.name))
  end
  AddSpell(defensives.forbearance, "Forbearance")
  local interrupts = data.InterruptManifest or {}
  for specID, record in pairs(interrupts.specs or {}) do
    AddSpell(record.spellID, "interrupt spec " .. specID)
    for _, entry in ipairs(record.spells or {}) do
      AddSpell(entry.spellID, "interrupt spec " .. specID)
      for _, castID in ipairs(entry.castSpellIDs or {}) do
        AddSpell(castID, "interrupt cast spec " .. specID)
      end
    end
  end
  for class, list in pairs(interrupts.classAlternatives or {}) do
    for _, id in ipairs(list) do
      AddSpell(id, "interrupt " .. class)
    end
  end
  for id in pairs(interrupts.extraCooldowns or {}) do
    AddSpell(id, "interrupt extra")
  end
  for setName, set in pairs((data.ConsumableData or {}).sets or {}) do
    for _, category in ipairs({ "food", "flask", "augmentRune" }) do
      for _, id in ipairs(set[category] or {}) do
        AddSpell(id, "consumable " .. setName .. " " .. category)
      end
    end
  end
  for key, id in pairs(data.ItemManifest or {}) do
    if type(id) == "number" then
      ids.items[id] = key
    end
  end
  local manifest = data.SeasonManifest or {}
  for _, seasonID in ipairs({ manifest.activeSeasonID, manifest.upcomingSeasonID }) do
    local season = seasonID and manifest.seasons[seasonID]
    for _, dungeon in ipairs(season and season.dungeons or {}) do
      ids.maps[dungeon.mapID] = seasonID
      for _, spellID in ipairs(dungeon.portalSpellIDs or {}) do
        AddSpell(spellID, "portal " .. seasonID .. " map " .. dungeon.mapID)
      end
      for _, activityID in ipairs(dungeon.activityIDs or {}) do
        ids.activities[activityID] = dungeon.mapID
      end
    end
  end
  return ids
end

--- Base cooldown of a spell in whole seconds from the DB2 rows (rule 267):
-- the ChargeRecoveryTime of its ChargeCategory when that category has one,
-- otherwise the larger of RecoveryTime and CategoryRecoveryTime. Only rows of
-- DifficultyID 0. Returns nil when DB2 has no cooldown for the spell.
function M.DeriveCooldownSeconds(spellID, cooldownTables)
  local ms = nil
  for _, row in ipairs(cooldownTables.categoriesBySpell[spellID] or {}) do
    if Num(row.DifficultyID) == 0 then
      local category = cooldownTables.categoryByID[Num(row.ChargeCategory)]
      local recovery = category and Num(category.ChargeRecoveryTime) or 0
      if recovery and recovery > 0 then
        ms = recovery
      end
    end
  end
  if not ms then
    for _, row in ipairs(cooldownTables.cooldownsBySpell[spellID] or {}) do
      if Num(row.DifficultyID) == 0 then
        local value = math.max(Num(row.RecoveryTime) or 0, Num(row.CategoryRecoveryTime) or 0)
        if value > 0 then
          ms = math.max(ms or 0, value)
        end
      end
    end
  end
  return ms and math.floor(ms / 1000 + 0.5) or nil
end

-- Defensive manifest (rule 267): specs belong to the record's class, and the
-- shipped cooldowns match DB2 when the cooldown tables were loaded.
local function CheckDefensives(db2, data, lines, ErrorLine)
  local defensives = (data.DefensiveManifest or {}).spells or {}
  local specs = (data.SpecManifest or {}).specs or {}
  local checked, withoutCooldown = 0, {}
  for _, castID in ipairs(SortedKeys(defensives)) do
    local record = defensives[castID]
    checked = checked + 1
    for _, specID in ipairs(record.specs or {}) do
      local spec = specs[specID]
      if not spec or spec.class ~= record.class then
        ErrorLine(
          string.format(
            "defensive %d (%s): spec %d is no %s spec",
            castID,
            tostring(record.name),
            specID,
            tostring(record.class)
          )
        )
      end
    end
    if record.cooldown == nil then
      withoutCooldown[#withoutCooldown + 1] = tostring(castID)
    elseif db2.cooldownTables then
      local derived = M.DeriveCooldownSeconds(castID, db2.cooldownTables)
      if derived ~= record.cooldown then
        ErrorLine(
          string.format(
            "defensive cooldown %d (%s): manifest %s s, DB2 %s s",
            castID,
            tostring(record.name),
            tostring(record.cooldown),
            tostring(derived)
          )
        )
      end
    end
  end
  local cooldownStatus = db2.cooldownTables and "checked against DB2"
    or "not checked (SpellCooldowns/SpellCategories/SpellCategory missing)"
  lines[#lines + 1] = string.format(
    "- Defensives: %d spells, cooldowns %s%s",
    checked,
    cooldownStatus,
    #withoutCooldown > 0 and (", without verified cooldown: " .. table.concat(withoutCooldown, ", ")) or ""
  )
end

local function FormatTimer(seconds)
  seconds = tonumber(seconds) or 0
  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

--- Checks and draft. `db2` is the loaded tables (see LoadTables), `data` the
-- addon data. Returns code, markdown report.
function M.Evaluate(db2, data, opts)
  opts = opts or {}
  local lines = { string.format("## Game data (DB2) %s", opts.version or "") }
  local problems = 0
  local function Problem(text)
    problems = problems + 1
    lines[#lines + 1] = "- MISSING " .. text
  end

  local ids = M.CollectShippedIDs(data)
  local mapByID = {}
  for _, row in ipairs(db2.maps) do
    mapByID[Num(row.ID)] = row
  end
  local deNameByID = {}
  for _, row in ipairs(db2.mapsDe or {}) do
    deNameByID[Num(row.ID)] = row.Name_lang
  end
  local activityByID = {}
  for _, row in ipairs(db2.activities) do
    activityByID[Num(row.ID)] = row
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "### Shipped IDs"
  local counts = { spells = 0, items = 0, maps = 0, activities = 0 }
  for _, id in ipairs(SortedKeys(ids.spells)) do
    counts.spells = counts.spells + 1
    if not db2.spellIDs[id] then
      Problem(string.format("spell %d (%s)", id, ids.spells[id]))
    end
  end
  for _, id in ipairs(SortedKeys(ids.items)) do
    counts.items = counts.items + 1
    if not db2.itemIDs[id] then
      Problem(string.format("item %d (%s)", id, ids.items[id]))
    end
  end
  for _, id in ipairs(SortedKeys(ids.maps)) do
    counts.maps = counts.maps + 1
    if not mapByID[id] then
      Problem(string.format("challenge map %d (%s)", id, ids.maps[id]))
    end
  end
  for _, id in ipairs(SortedKeys(ids.activities)) do
    counts.activities = counts.activities + 1
    local mapID = ids.activities[id]
    local activity = activityByID[id]
    local map = mapByID[mapID]
    if not activity then
      Problem(string.format("LFG activity %d (map %d)", id, mapID))
    elseif map and Num(activity.MapID) ~= Num(map.MapID) then
      problems = problems + 1
      lines[#lines + 1] = string.format(
        "- ERROR LFG activity %d is instance %s, map %d is instance %s",
        id,
        tostring(activity.MapID),
        mapID,
        tostring(map.MapID)
      )
    elseif Num(activity.DifficultyID) ~= KEYSTONE_DIFFICULTY_ID then
      problems = problems + 1
      lines[#lines + 1] = string.format(
        "- ERROR LFG activity %d is no keystone activity (difficulty %s)",
        id,
        tostring(activity.DifficultyID)
      )
    end
  end
  local specs = (data.SpecManifest or {}).specs or {}
  local clientSpecs = {}
  for _, row in ipairs(db2.specs) do
    local classID, order = Num(row.ClassID), Num(row.OrderIndex)
    if classID and classID >= 1 and classID <= PLAYABLE_CLASS_MAX and order and order <= REGULAR_SPEC_ORDER_MAX then
      clientSpecs[Num(row.ID)] = row.Name_lang
    end
  end
  for _, specID in ipairs(SortedKeys(clientSpecs)) do
    if not specs[specID] then
      Problem(string.format("spec %d (%s) in data/isiLive_specs.lua", specID, tostring(clientSpecs[specID])))
    end
  end
  for _, specID in ipairs(SortedKeys(specs)) do
    if not clientSpecs[specID] then
      Problem(string.format("spec %d of data/isiLive_specs.lua in the client", specID))
    end
  end
  CheckDefensives(db2, data, lines, function(text)
    problems = problems + 1
    lines[#lines + 1] = "- ERROR " .. text
  end)
  lines[#lines + 1] = string.format(
    "- Checked: %d spells, %d items, %d challenge maps, %d LFG activities, %d specs",
    counts.spells,
    counts.items,
    counts.maps,
    counts.activities,
    #SortedKeys(clientSpecs)
  )

  -- Newest rotation.
  lines[#lines + 1] = ""
  lines[#lines + 1] = "### Newest Mythic+ rotation"
  local newest, rotation = nil, {}
  for _, row in ipairs(db2.tracked) do
    local display = Num(row.DisplaySeasonID)
    if display and (not newest or display > newest) then
      newest = display
    end
  end
  for _, row in ipairs(db2.tracked) do
    if Num(row.DisplaySeasonID) == newest then
      rotation[#rotation + 1] = Num(row.MapChallengeModeID)
    end
  end
  table.sort(rotation)
  local rotationKey = table.concat(rotation, ",")
  local known
  for seasonID, season in pairs((data.SeasonManifest or {}).seasons or {}) do
    local maps = {}
    for _, dungeon in ipairs(season.dungeons or {}) do
      maps[#maps + 1] = dungeon.mapID
    end
    table.sort(maps)
    if table.concat(maps, ",") == rotationKey then
      known = seasonID
    end
  end
  lines[#lines + 1] = string.format("- Display season %s: maps %s", tostring(newest), rotationKey)
  if known then
    lines[#lines + 1] = string.format("- Status: configured as `%s`", known)
  else
    problems = problems + 1
    lines[#lines + 1] = "- Status: NEW season, not in data/isiLive_seasons.lua. Draft below; verify every ID before"
      .. " setting `verified`. Short codes, display order and the portal navigator are decided by hand."
    local draft = M.Draft(db2, rotation, mapByID, deNameByID, opts)
    for _, line in ipairs(draft) do
      lines[#lines + 1] = line
    end
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = problems == 0 and "- Result: ok" or string.format("- Result: %d finding(s)", problems)
  return problems == 0 and 0 or 1, table.concat(lines, "\n")
end

--- Intake rows and manifest skeleton for an unknown rotation.
function M.Draft(db2, rotation, mapByID, deNameByID, opts)
  local seasonID = opts.seasonID or "next_season"
  local source = string.format(
    "wago.tools DB2 %s (MythicPlusSeasonTrackedMap, MapChallengeMode, GroupFinderActivity, Spell, SpellFlyoutItem)",
    opts.version or "unresolved"
  )
  local date = opts.date or os.date("!%Y-%m-%d")
  local flyoutSpells = {}
  for _, row in ipairs(db2.flyoutItems) do
    flyoutSpells[Num(row.SpellID)] = true
  end
  local subtextBySpell = db2.subtextBySpell or {}
  local out = {
    "",
    "#### Intake rows (docs/SEASON_INTAKE.md)",
    "",
    "| Season | Dungeon | ChallengeMapID | PortalSpellID | LFGActivityID | Source | VerifiedAt | Status | Notiz |",
    "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
  }
  local skeleton = {
    "",
    "#### Manifest skeleton (data/isiLive_seasons.lua)",
    "",
    "```lua",
    string.format("%s = {", seasonID),
    '  label = "TODO",',
    "  autoDetectFromChallengeMaps = false, -- true once every row is verified",
    "  requiresForces = false,",
    "  inactivePortalMessageByLocale = {},",
    "  -- portalNavigator = { zone = ..., titleByLocale = ..., slots = ... }, -- by hand",
    "  dungeons = {",
  }
  for _, mapID in ipairs(rotation) do
    local map = mapByID[mapID] or {}
    local name = map.Name_lang or "unresolved"
    local instance = Num(map.MapID)
    local activities = {}
    for _, row in ipairs(db2.activities) do
      if instance and Num(row.MapID) == instance and Num(row.DifficultyID) == KEYSTONE_DIFFICULTY_ID then
        activities[#activities + 1] = Num(row.ID)
      end
    end
    table.sort(activities)
    local portals = {}
    for spellID in pairs(flyoutSpells) do
      if subtextBySpell[spellID] ~= nil and subtextBySpell[spellID] == name then
        portals[#portals + 1] = spellID
      end
    end
    table.sort(portals)
    local portal = #portals == 1 and tostring(portals[1]) or "unresolved"
    local activity = #activities == 1 and tostring(activities[1]) or "unresolved"
    local notes = {
      "deDE " .. tostring(deNameByID[mapID] or "unresolved"),
      "instance " .. tostring(instance or "unresolved"),
      "timer " .. FormatTimer(map.CriteriaCount_0),
    }
    if #portals ~= 1 then
      notes[#notes + 1] = "portal candidates " .. (#portals > 0 and table.concat(portals, "/") or "none")
    end
    if #activities ~= 1 then
      notes[#notes + 1] = "activity candidates " .. (#activities > 0 and table.concat(activities, "/") or "none")
    end
    out[#out + 1] = string.format(
      "| %s | %s | %d | %s | %s | %s | %s | candidate | %s |",
      seasonID,
      name,
      mapID,
      portal,
      activity,
      source,
      date,
      table.concat(notes, "; ")
    )
    skeleton[#skeleton + 1] = "    {"
    skeleton[#skeleton + 1] = string.format("      mapID = %d,", mapID)
    skeleton[#skeleton + 1] =
      string.format("      activityIDs = { %s },", #activities == 1 and activity or "--[[TODO]]")
    skeleton[#skeleton + 1] = string.format("      portalSpellIDs = { %s },", #portals == 1 and portal or "--[[TODO]]")
    skeleton[#skeleton + 1] = "      displayOrder = nil, -- TODO"
    skeleton[#skeleton + 1] =
      string.format("      names = { enUS = %q, deDE = %q },", name, tostring(deNameByID[mapID] or "TODO"))
    skeleton[#skeleton + 1] = "      -- shortCodes = { default = ..., deDE = ... }, -- by hand"
    skeleton[#skeleton + 1] = "    },"
  end
  skeleton[#skeleton + 1] = "  },"
  skeleton[#skeleton + 1] = "},"
  skeleton[#skeleton + 1] = "```"
  for _, line in ipairs(skeleton) do
    out[#out + 1] = line
  end
  return out
end

--- Loads the CSV tables of `dir`, reading only what the checks need.
function M.LoadTables(dir, data)
  local ids = M.CollectShippedIDs(data)
  local db2 = {}
  local err
  db2.spellIDs, err = ReadIdSet(dir .. "/SpellName.csv", ids.spells)
  if not db2.spellIDs then
    return nil, err
  end
  db2.itemIDs, err = ReadIdSet(dir .. "/Item.csv", ids.items)
  if not db2.itemIDs then
    return nil, err
  end
  for key, file in pairs({
    maps = "MapChallengeMode.csv",
    mapsDe = "MapChallengeMode.deDE.csv",
    activities = "GroupFinderActivity.csv",
    specs = "ChrSpecialization.csv",
    tracked = "MythicPlusSeasonTrackedMap.csv",
    flyoutItems = "SpellFlyoutItem.csv",
  }) do
    db2[key], err = M.ReadCsv(dir .. "/" .. file)
    if not db2[key] then
      return nil, err
    end
  end
  local flyoutSpells = {}
  for _, row in ipairs(db2.flyoutItems) do
    flyoutSpells[tostring(Num(row.SpellID))] = true
  end
  local spellRows
  spellRows, err = M.ReadCsv(dir .. "/Spell.csv", function(first)
    return flyoutSpells[first] == true
  end)
  if not spellRows then
    return nil, err
  end
  db2.subtextBySpell = {}
  for _, row in ipairs(spellRows) do
    db2.subtextBySpell[Num(row.ID)] = row.NameSubtext_lang
  end
  db2.cooldownTables = M.LoadCooldownTables(dir, data)
  return db2
end

--- Optional cooldown tables for the defensive cooldown check (rule 267).
-- Returns nil when one of the three files is missing.
function M.LoadCooldownTables(dir, data)
  local wanted = {}
  for castID in pairs((data.DefensiveManifest or {}).spells or {}) do
    wanted[tostring(castID)] = true
  end
  local function BySpell(rows)
    local out = {}
    for _, row in ipairs(rows) do
      local id = Num(row.SpellID)
      if id then
        out[id] = out[id] or {}
        out[id][#out[id] + 1] = row
      end
    end
    return out
  end
  local function KeepSpell(path)
    -- The spell ID is the last column; read every row and filter after parsing.
    local rows = M.ReadCsv(path)
    if not rows then
      return nil
    end
    local kept = {}
    for _, row in ipairs(rows) do
      if wanted[tostring(Num(row.SpellID))] then
        kept[#kept + 1] = row
      end
    end
    return kept
  end
  local cooldowns = KeepSpell(dir .. "/SpellCooldowns.csv")
  local categories = KeepSpell(dir .. "/SpellCategories.csv")
  local categoryRows = M.ReadCsv(dir .. "/SpellCategory.csv")
  if not cooldowns or not categories or not categoryRows then
    return nil
  end
  local categoryByID = {}
  for _, row in ipairs(categoryRows) do
    categoryByID[Num(row.ID)] = row
  end
  return { cooldownsBySpell = BySpell(cooldowns), categoriesBySpell = BySpell(categories), categoryByID = categoryByID }
end

function M.LoadShippedData()
  local data = {}
  for _, path in ipairs({
    "data/isiLive_seasons.lua",
    "data/isiLive_spells.lua",
    "data/isiLive_specs.lua",
    "data/isiLive_interrupts.lua",
    "data/isiLive_defensives.lua",
    "data/isiLive_consumables.lua",
    "data/isiLive_items.lua",
  }) do
    local loaded, err = ReadData(path)
    if not loaded then
      return nil, path .. ": " .. tostring(err)
    end
    for key, value in pairs(loaded) do
      data[key] = value
    end
  end
  return data
end

function M.Main(argv)
  local args = {}
  for _, value in ipairs(argv or {}) do
    local key, val = value:match("^%-%-([%w_%-]+)=(.*)$")
    if key then
      args[key] = val
    end
  end
  if not args.db2 then
    io.stderr:write("usage: lua tools/check_db2.lua --db2=<dir> [--version=<build>] [--season-id=<id>]\n")
    return 2
  end
  local data, dataErr = M.LoadShippedData()
  if not data then
    io.write("## Game data (DB2)\n\n- Status: unresolved\n- Reason: ", tostring(dataErr), "\n")
    return 2
  end
  local db2, err = M.LoadTables(args.db2, data)
  if not db2 then
    io.write("## Game data (DB2)\n\n- Status: unresolved\n- Reason: ", tostring(err), "\n")
    return 2
  end
  local code, report = M.Evaluate(db2, data, {
    version = args.version,
    seasonID = args["season-id"],
    date = args.date,
  })
  io.write(report, "\n")
  return code
end

if ... == "module" then
  return M
end

os.exit(M.Main(arg))
