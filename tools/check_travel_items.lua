#!/usr/bin/env lua
---@diagnostic disable: undefined-global
-- Validates data/isiLive_travel_items.lua (hearthstone toys, mount spells and
-- fixed travel items) and docs/TRAVEL_INTAKE.md as its collection surface.
-- Every `verified` data entry needs a matching `verified` intake row and vice
-- versa; `legacy` entries predate the intake and are exempt from the row check.

local DEFAULT_INTAKE_PATH = "docs/TRAVEL_INTAKE.md"
local DEFAULT_DATA_PATH = "data/isiLive_travel_items.lua"
local SEASON_INTAKE_TOOL_PATH = "tools/check_season_intake.lua"

local DATA_STATUS_VALUES = { legacy = true, verified = true }

-- Section heading → { id column, data kind }.
local SECTIONS = {
  { heading = "Ruhestein%-Intake", key = "hearthstones", idField = "ToyID", label = "hearthstone" },
  { heading = "Mount%-Intake", key = "mounts", idField = "SpellID", label = "mount" },
  { heading = "Reise%-Item%-Intake", key = "items", idField = "ItemID", label = "travel item" },
}

-- Scalar travel items: manifest ID field → its verification field.
local SCALAR_ITEMS = {
  { idField = "defaultHearthstoneItemID", verificationField = "defaultHearthstoneVerification" },
  { idField = "dalaranHearthstoneToyID", verificationField = "dalaranHearthstoneVerification" },
  { idField = "arcantinaKeyItemID", verificationField = "arcantinaKeyVerification" },
}

local function ReadFile(path)
  local file, err = io.open(path, "rb")
  if not file then
    return nil, string.format("cannot read %s: %s", tostring(path), tostring(err))
  end
  local content = file:read("*a") or ""
  file:close()
  return content
end

local function LoadIntakeHelpers()
  local chunk, err = loadfile(SEASON_INTAKE_TOOL_PATH)
  if not chunk then
    return nil, "cannot load " .. SEASON_INTAKE_TOOL_PATH .. ": " .. tostring(err)
  end
  return chunk()
end

local function LoadManifest(path)
  local chunk, err = loadfile(path)
  if not chunk then
    return nil, string.format("cannot load %s: %s", tostring(path), tostring(err))
  end
  local addonTable = {}
  local ok, runErr = pcall(chunk, "isiLive", addonTable)
  if not ok then
    return nil, string.format("load error in %s: %s", tostring(path), tostring(runErr))
  end
  if type(addonTable.TravelItemManifest) ~= "table" then
    return nil, "addonTable.TravelItemManifest missing"
  end
  return addonTable.TravelItemManifest
end

local function ParseTables(content, helpers)
  local tables = {}
  for _, section in ipairs(SECTIONS) do
    tables[section.key] = {}
  end
  local current
  local header
  for line in tostring(content or ""):gmatch("[^\r\n]+") do
    if line:find("^## ") then
      current = nil
      header = nil
      for _, section in ipairs(SECTIONS) do
        if line:find("^## " .. section.heading) then
          current = section.key
        end
      end
    elseif current then
      local cells = helpers.SplitMarkdownRow(line)
      if cells then
        if not header then
          header = cells
        elseif not helpers.IsSeparatorRow(cells) then
          local row = {}
          for index, column in ipairs(header) do
            row[column] = cells[index] or ""
          end
          tables[current][#tables[current] + 1] = row
        end
      end
    end
  end
  return tables
end

local function IsPositiveIntegerNumber(value)
  return type(value) == "number" and value > 0 and value == math.floor(value)
end

local function ValidateVerification(errors, label, verification, helpers)
  if type(verification) ~= "table" then
    errors[#errors + 1] = label .. " has no verification block"
    return nil
  end
  local status = verification.status
  if not DATA_STATUS_VALUES[status] then
    errors[#errors + 1] = label .. " has invalid verification.status '" .. tostring(status) .. "'"
    return nil
  end
  if type(verification.source) ~= "string" or verification.source == "" then
    errors[#errors + 1] = label .. " has no verification.source"
  end
  if status == "verified" and not helpers.IsDate(verification.verifiedAt) then
    errors[#errors + 1] = label .. " is verified without a YYYY-MM-DD verification.verifiedAt"
  end
  return status
end

local function ValidateRequires(errors, label, requires)
  if requires == nil then
    return
  end
  if type(requires) ~= "table" then
    errors[#errors + 1] = label .. " has a non-table requires block"
    return
  end
  local hasCovenant = requires.covenantID ~= nil or requires.renownCriteria ~= nil
  local hasRace = requires.raceIDs ~= nil
  if hasCovenant == hasRace then
    errors[#errors + 1] = label .. " requires exactly one of covenantID/renownCriteria or raceIDs"
    return
  end
  if hasCovenant then
    if not IsPositiveIntegerNumber(requires.covenantID) or not IsPositiveIntegerNumber(requires.renownCriteria) then
      errors[#errors + 1] = label .. " requires positive integer covenantID and renownCriteria"
    end
  else
    if type(requires.raceIDs) ~= "table" or #requires.raceIDs == 0 then
      errors[#errors + 1] = label .. " requires a non-empty raceIDs list"
      return
    end
    for _, raceID in ipairs(requires.raceIDs) do
      if not IsPositiveIntegerNumber(raceID) then
        errors[#errors + 1] = label .. " has a non-integer race ID"
      end
    end
  end
  for key in pairs(requires) do
    if key ~= "covenantID" and key ~= "renownCriteria" and key ~= "raceIDs" then
      errors[#errors + 1] = label .. " has unknown requires key '" .. tostring(key) .. "'"
    end
  end
end

-- Collects every data entry as { kind, id, status, verifiedAt, label }.
local function CollectDataEntries(errors, manifest, helpers)
  local entries = { hearthstones = {}, mounts = {}, items = {} }
  local seenIDs = {}
  local function Register(kind, id, verification, label)
    if not IsPositiveIntegerNumber(id) then
      errors[#errors + 1] = label .. " has no positive integer ID"
      return
    end
    local status = ValidateVerification(errors, label, verification, helpers)
    local seenKey = (kind == "mounts" and "spell:" or "item:") .. tostring(id)
    if seenIDs[seenKey] then
      errors[#errors + 1] = string.format("ID %d is duplicated between %s and %s", id, seenIDs[seenKey], label)
    end
    seenIDs[seenKey] = label
    entries[kind][#entries[kind] + 1] = {
      id = id,
      status = status,
      verifiedAt = type(verification) == "table" and verification.verifiedAt or nil,
      label = label,
    }
  end

  if not IsPositiveIntegerNumber(manifest.covenantRenownAchievementID) then
    errors[#errors + 1] = "covenantRenownAchievementID must be a positive integer"
  end

  local toys = manifest.hearthstoneToys
  if type(toys) ~= "table" or #toys == 0 then
    errors[#errors + 1] = "hearthstoneToys must be a non-empty list"
  else
    for index, entry in ipairs(toys) do
      local label = string.format("hearthstoneToys[%d]", index)
      if type(entry) ~= "table" then
        errors[#errors + 1] = label .. " must be a table"
      else
        label = label .. " (" .. tostring(entry.id) .. ")"
        if type(entry.englishName) ~= "string" or entry.englishName == "" then
          errors[#errors + 1] = label .. " has no englishName"
        end
        ValidateRequires(errors, label, entry.requires)
        Register("hearthstones", entry.id, entry.verification, label)
      end
    end
  end

  for _, scalar in ipairs(SCALAR_ITEMS) do
    Register("items", manifest[scalar.idField], manifest[scalar.verificationField], scalar.idField)
  end

  local mountSpells = manifest.mountSpells
  if type(mountSpells) ~= "table" then
    errors[#errors + 1] = "mountSpells must be a table"
  else
    local keys = {}
    for key in pairs(mountSpells) do
      keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
      local entry = mountSpells[key]
      local label = "mountSpells." .. tostring(key)
      if type(entry) ~= "table" then
        errors[#errors + 1] = label .. " must be a table"
      else
        Register("mounts", entry.spellID, entry.verification, label)
      end
    end
  end

  return entries
end

local function ValidateIntake(errors, tables, entries, helpers)
  for _, section in ipairs(SECTIONS) do
    local seen = {}
    local dataByID = {}
    for _, entry in ipairs(entries[section.key]) do
      dataByID[entry.id] = entry
    end
    local verifiedRowsByID = {}
    for _, row in ipairs(tables[section.key]) do
      local label = string.format("%s row %s", section.label, tostring(row.Name))
      helpers.ValidateRow(errors, label, row, { section.idField })
      helpers.RegisterUnique(errors, seen, section.idField, row[section.idField], label)
      local patch = helpers.Trim(row.Patch)
      if patch ~= "unresolved" and not patch:match("^%d+%.%d+[%.%d]*$") then
        errors[#errors + 1] = label .. " has invalid Patch '" .. tostring(row.Patch) .. "'"
      end
      if helpers.Trim(row.Status) == "verified" then
        local id = tonumber(row[section.idField])
        local entry = id and dataByID[id] or nil
        if not entry then
          errors[#errors + 1] = label .. " is verified but " .. section.idField .. " is missing from the data file"
        elseif entry.status ~= "verified" then
          errors[#errors + 1] = label .. " is verified but " .. entry.label .. " is not marked verified"
        elseif entry.verifiedAt ~= helpers.Trim(row.VerifiedAt) then
          errors[#errors + 1] = label .. " VerifiedAt does not match " .. entry.label
        end
        if id then
          verifiedRowsByID[id] = true
        end
      end
    end
    for _, entry in ipairs(entries[section.key]) do
      if entry.status == "verified" and not verifiedRowsByID[entry.id] then
        errors[#errors + 1] = entry.label .. " is verified but has no verified intake row"
      end
    end
  end
end

local M = {}

function M.Check(opts)
  opts = opts or {}
  local errors = {}
  local helpers, helperErr = LoadIntakeHelpers()
  if not helpers then
    errors[#errors + 1] = helperErr
  end
  local manifest, manifestErr = LoadManifest(opts.dataPath or DEFAULT_DATA_PATH)
  if not manifest then
    errors[#errors + 1] = manifestErr
  end
  local content, readErr = ReadFile(opts.intakePath or DEFAULT_INTAKE_PATH)
  if not content then
    errors[#errors + 1] = readErr
  end

  local counts = { legacy = 0, verified = 0 }
  if helpers and manifest and content then
    local entries = CollectDataEntries(errors, manifest, helpers)
    ValidateIntake(errors, ParseTables(content, helpers), entries, helpers)
    for _, kind in ipairs({ "hearthstones", "mounts", "items" }) do
      for _, entry in ipairs(entries[kind]) do
        if counts[entry.status] then
          counts[entry.status] = counts[entry.status] + 1
        end
      end
    end
  end

  local lines = {
    "## Travel Items Check",
    "",
    "- Status: " .. (#errors == 0 and "valid" or "invalid"),
    string.format("- Data entries: %d verified, %d legacy", counts.verified, counts.legacy),
  }
  if #errors > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "### Fehler"
    for _, err in ipairs(errors) do
      lines[#lines + 1] = "- " .. err
    end
  end
  return #errors == 0, { errors = errors, counts = counts, summary = table.concat(lines, "\n") .. "\n" }
end

local cliArg = rawget(_G, "arg")
local isDirectRun = type(cliArg) == "table"
  and type(cliArg[0]) == "string"
  and cliArg[0]:find("check_travel_items.lua", 1, true) ~= nil

if isDirectRun then
  local ok, result = M.Check({})
  io.write(result.summary)
  if not ok then
    os.exit(1)
  end
end

return M
