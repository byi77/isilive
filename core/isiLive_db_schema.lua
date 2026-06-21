local _, addonTable = ...

addonTable = addonTable or {}

-- Centralized schema + migration framework for IsiLiveDB.
--
-- Two orthogonal concerns:
--   1. SCHEMA describes the CURRENT shape of IsiLiveDB. Sanitize() validates
--      every read-relevant field, fills missing defaults, repairs wrong types,
--      clamps out-of-range numbers, resets invalid enums.
--   2. MIGRATIONS holds versioned step functions that transform older shapes
--      into the current shape (renames, removals, type changes, splits).
--      Stamped via db.__schemaVersion; each step runs at most once per user.
--
-- Lifecycle: called once from HandleAddonLoadedEvent in
-- logic/isiLive_event_handlers_runtime.lua, AFTER WoW restored IsiLiveDB but
-- BEFORE any live module reads from it. This is the only legitimate
-- mutation-on-load entry point; per-field defensive defaults at read sites
-- can be removed (see logic/isiLive_event_handlers_runtime.lua position +
-- uiScale fallbacks for the canonical examples).
--
-- IMPORTANT: the sanitizer NEVER deletes unknown fields. Old versions or
-- manual user edits may leave fields the current schema does not know about;
-- preserving them across a /reload prevents data loss when a future schema
-- bump migrates them. Removals always go through MIGRATIONS, never via
-- silent drop.
local DBSchema = {}
addonTable.DBSchema = DBSchema

-- Bump every time MIGRATIONS gains a new step.
local LATEST_SCHEMA_VERSION = 3

-- Migrations transform db FROM version (key-1) TO version (key). Only steps
-- with key > db.__schemaVersion run. Each step is responsible for ONE atomic
-- transition (e.g. "renamed showDpsColumn -> showDpsBar in v0.9.211").
--
-- New steps go at the bottom; never re-key an existing step (would cause
-- duplicate migration on already-upgraded users).
--
-- Step signature:
--   function(db, log)
--     -- mutate db; call log("...message...") for each correction.
--     -- return true when the migration changed the db.
--   end
local MIGRATIONS = {
  -- [2] = function(db, log)
  --   if db.showDpsColumn ~= nil then
  --     db.showDpsBar = db.showDpsColumn == true
  --     db.showDpsColumn = nil
  --     log("migrated showDpsColumn -> showDpsBar")
  --     return true
  --   end
  -- end,
  [2] = function(db, log)
    if
      db.autoCloseMainFrame == true
      and rawget(db, "autoCloseOnKeyStart") == nil
      and rawget(db, "autoCloseOnSoloChange") == nil
    then
      db.autoCloseOnKeyStart = true
      db.autoCloseOnSoloChange = true
      db.autoCloseMainFrame = false
      log("migrated autoCloseMainFrame -> autoCloseOnKeyStart/autoCloseOnSoloChange")
      return true
    end
    return false
  end,
  [3] = function(db, log)
    if rawget(db, "vipAstralAurochsSoundEnabled") == nil then
      return false
    end
    if rawget(db, "vipAstralAurochsSoundMuted") == nil then
      db.vipAstralAurochsSoundMuted = db.vipAstralAurochsSoundEnabled == false
    end
    db.vipAstralAurochsSoundEnabled = nil
    log("migrated vipAstralAurochsSoundEnabled -> vipAstralAurochsSoundMuted")
    return true
  end,
}

-- ----------------------------------------------------------------------
-- Schema definition.
--
-- Field shape:
--   { type = "boolean" | "number" | "string" | "table",
--     default = <value> | function() return <value> end,
--     min = <number>,            -- for type="number"; clamped (not reset)
--     max = <number>,            -- for type="number"; clamped
--     enum = { "a", "b", ... },  -- for type="string"; reset on mismatch
--     fields = { ... }           -- for type="table"; recursive sub-schema
--   }
--
-- Defaults that are tables MUST be functions (otherwise every fresh-install
-- user shares the same mutable reference, which causes random churn).
-- ----------------------------------------------------------------------
local SCHEMA = {
  -- Frame anchor + size persistence.
  position = {
    type = "table",
    default = function()
      return { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    end,
    fields = {
      point = { type = "string", default = "CENTER" },
      relativePoint = { type = "string", default = "CENTER" },
      x = { type = "number", default = 0 },
      y = { type = "number", default = 0 },
    },
  },
  statsBoxPosition = {
    type = "table",
    default = function()
      return { point = "CENTER", relativePoint = "CENTER", x = 320, y = 120 }
    end,
    fields = {
      point = { type = "string", default = "CENTER" },
      relativePoint = { type = "string", default = "CENTER" },
      x = { type = "number", default = 320 },
      y = { type = "number", default = 120 },
    },
  },
  uiScale = { type = "number", default = 1.0, min = 0.5, max = 2.0 },
  bgAlpha = { type = "number", default = 0.5, min = 0.0, max = 1.0 },
  lockMainFramePosition = { type = "boolean", default = true },
  statsBoxEnabled = { type = "boolean", default = false },
  statsBoxLocked = { type = "boolean", default = false },
  statsBoxBgAlpha = { type = "number", default = 0.0, min = 0.0, max = 1.0 },
  statsBoxFontSizeOffset = { type = "number", default = 0, min = -3, max = 3 },
  statsBoxDisplayMode = { type = "string", default = "both", enum = { "both", "value", "percent" } },
  statsBoxShowLeech = { type = "boolean", default = true },
  statsBoxShowSpeed = { type = "boolean", default = true },
  statsBoxShowDurability = { type = "boolean", default = false },
  statsBoxShowStamina = { type = "boolean", default = false },
  statsBoxShowAvoidance = { type = "boolean", default = false },

  -- Locale + addon-level toggles.
  locale = { type = "string", default = "enUS" },
  syncEnabled = { type = "boolean", default = true },

  -- Auto-show / auto-close behaviour.
  autoShowMainFrameOnStartup = { type = "boolean", default = true },
  -- Legacy single-toggle; superseded by the two split fields below. Kept in
  -- the schema so versioned migrations can detect and clear old saves.
  autoCloseMainFrame = { type = "boolean", default = false },
  autoCloseOnKeyStart = { type = "boolean", default = false },
  autoCloseOnSoloChange = { type = "boolean", default = false },
  autoOpenMainFrameOnKeyEnd = { type = "boolean", default = true },
  autoOpenOnQueue = { type = "boolean", default = true },

  -- Combat behaviour.
  combatFadeMM = { type = "boolean", default = false },
  raidTransitionBehavior = { type = "string", default = "hide", enum = { "hide" } },

  -- Roster layout / appearance.
  rosterLayoutMode = {
    type = "string",
    default = "compact_main_horizontal",
    enum = { "expanded", "compact_vertical", "compact_horizontal", "compact_main_horizontal" },
  },
  rosterDefaultLayoutMode = {
    type = "string",
    default = "compact_main_horizontal",
    enum = { "last_used", "expanded", "compact_vertical", "compact_horizontal", "compact_main_horizontal" },
  },
  nameMaxChars = { type = "number", default = 10, min = 5, max = 20 },
  teleportColumns = { type = "number", default = 4, min = 2, max = 6 },

  -- ESC menu strips.
  showEscPanel = { type = "boolean", default = true },
  showPortalNavigator = { type = "boolean", default = true },
  hearthstoneChoice = { type = "string", default = "random" },

  -- Minimap button.
  showMinimapButton = { type = "boolean", default = false },
  minimapAngle = { type = "number", default = 225, min = 0, max = 360 },

  -- LFG flags + tooltip flags.
  lfgFlagsEnabled = { type = "boolean", default = true },
  lfgGroupBonusesEnabled = { type = "boolean", default = true },
  tooltipFlagsEnabled = { type = "boolean", default = true },
  acceptedInviteNoticeEnabled = { type = "boolean", default = true },
  groupJoinNoticeEnabled = { type = "boolean", default = true },

  -- Mob nameplate / forces overlay.
  mobNameplateEnabled = { type = "boolean", default = true },
  mplusForcesEstimate = { type = "boolean", default = false },
  mobNameplateShowPercent = { type = "boolean", default = true },
  mobNameplateShowRemaining = { type = "boolean", default = false },
  mobNameplateRemainingDefaultMigrated = { type = "boolean", default = false },
  mobNameplateFontSize = { type = "number", default = 14, min = 8, max = 28 },
  mobNameplatePosition = {
    type = "string",
    default = "RIGHT",
    enum = { "LEFT", "RIGHT", "TOP", "BOTTOM" },
  },
  mobNameplateXOffset = { type = "number", default = 0, min = -200, max = 200 },
  mobNameplateYOffset = { type = "number", default = 0, min = -200, max = 200 },

  -- Sound cues.
  soundOutputChannel = { type = "string", default = "Master", enum = { "Master", "SFX" } }, -- sound-ok
  soundBattleResEnabled = { type = "boolean", default = true },
  soundBattleResReadyEnabled = { type = "boolean", default = true },
  soundBloodlustEnabled = { type = "boolean", default = true },
  soundBloodlustReadyEnabled = { type = "boolean", default = true },
  soundBloodlustReadyReminderEnabled = { type = "boolean", default = true },
  soundGroupJoinEnabled = { type = "boolean", default = true },
  soundLeadEnabled = { type = "boolean", default = true },
  soundPortalAvailableEnabled = { type = "boolean", default = true },
  soundIncomingSummonLoopEnabled = { type = "boolean", default = true },
  soundReadyCheckCompleteEnabled = { type = "boolean", default = true },
  soundTankDiedEnabled = { type = "boolean", default = true },
  soundHealerDiedEnabled = { type = "boolean", default = true },
  soundOwnTankDiedEnabled = { type = "boolean", default = true },
  soundOwnHealerDiedEnabled = { type = "boolean", default = true },
  deathAlertEnabled = { type = "boolean", default = true },
  vipAstralAurochsSoundMuted = { type = "boolean", default = false },
  vipGrandExpeditionYakSoundMuted = { type = "boolean", default = false },
  vipGildedBrutosaurSoundMuted = { type = "boolean", default = false },

  -- Combat-event chat announces.
  chatAnnounceBR = { type = "boolean", default = true },
  chatAnnounceLust = { type = "boolean", default = true },

  -- Persistent runtime caches (open-shape tables: per-player keys -> values).
  -- maxMapEntries caps unbounded growth: when the count exceeds the cap, the
  -- sanitizer drops oldest-first by random eviction (see TrimMap). This is
  -- a panic-mode size guard, not a normal eviction policy. Realistic users
  -- should never hit these caps; if they do, something is wrong upstream
  -- and the trim event is logged loudly.
  rioBaseline = {
    type = "table",
    default = function()
      return {}
    end,
    maxMapEntries = 5000,
  },
  stats = {
    type = "table",
    default = function()
      return {}
    end,
    fields = {
      playerLastRunByCharacter = {
        type = "table",
        default = function()
          return {}
        end,
        maxMapEntries = 5000,
      },
    },
  },
  reloadRosterMirror = {
    type = "table",
    default = function()
      return {}
    end,
    maxMapEntries = 5000,
  },

  -- Error-log ring buffer (always-on, capped by ErrorLog module's hard
  -- limit). Schema declaration ensures the field exists with a table
  -- default; the actual ring management lives in core/isiLive_error_log.lua.
  errorLog = {
    type = "table",
    default = function()
      return {}
    end,
    maxMapEntries = 200, -- defensive: ErrorLog enforces 100; schema is the safety net
  },
}

-- Persisted runtime-debug fields are intentionally NOT in the schema:
--   queueDebug, runtimeLogEnabled
-- Both are reset to false in HandleAddonLoadedEvent regardless of saved
-- value (see logic/isiLive_event_handlers_runtime.lua line ~333). Adding
-- them here would just create churn since they get overwritten ms later.
-- runtimeLogLevel is also NOT in the schema; it's set via debug commands
-- and the in-memory runtime-log module owns its own validation.

local function ResolveDefault(schema)
  if type(schema.default) == "function" then
    return schema.default()
  end
  return schema.default
end

-- Recursively validates a single field. Self-heals via:
--   missing      -> default
--   wrong type   -> default + log
--   out-of-range -> clamp + log
--   bad enum     -> default + log
--   nested table -> recurse into fields sub-schema
local function ValidateField(parent, key, schema, log, path)
  local fullPath = path and (path .. "." .. key) or key
  local value = parent[key]

  -- Step 1: ensure the slot holds a value of the correct type.
  if value == nil then
    parent[key] = ResolveDefault(schema)
    log(string.format("filled missing %s with default", fullPath))
    value = parent[key]
  elseif type(value) ~= schema.type then
    log(string.format("reset %s: expected %s, got %s", fullPath, schema.type, type(value)))
    parent[key] = ResolveDefault(schema)
    value = parent[key]
  end

  -- Step 2: type-specific constraints.
  if schema.type == "number" then
    if schema.min ~= nil and value < schema.min then
      parent[key] = schema.min
      log(string.format("clamped %s from %s to min %s", fullPath, tostring(value), tostring(schema.min)))
    elseif schema.max ~= nil and value > schema.max then
      parent[key] = schema.max
      log(string.format("clamped %s from %s to max %s", fullPath, tostring(value), tostring(schema.max)))
    end
    return
  end

  if schema.type == "string" and schema.enum then
    local found = false
    for _, allowed in ipairs(schema.enum) do
      if value == allowed then
        found = true
        break
      end
    end
    if not found then
      parent[key] = ResolveDefault(schema)
      log(string.format("reset %s: %q not in enum", fullPath, tostring(value)))
    end
    return
  end

  -- Step 3a: enforce map-size cap (panic-mode guard against unbounded
  -- growth). Counts entries via pairs() since ipairs() does not capture
  -- string-keyed maps. When over cap, drops first-fit entries until at
  -- cap; eviction order is intentionally arbitrary (we just need to
  -- bound size, not preserve a specific ordering policy).
  if schema.type == "table" and schema.maxMapEntries then
    local count = 0
    for _ in pairs(value) do
      count = count + 1
    end
    if count > schema.maxMapEntries then
      local toRemove = count - schema.maxMapEntries
      local removed = 0
      for k in pairs(value) do
        if removed >= toRemove then
          break
        end
        value[k] = nil
        removed = removed + 1
      end
      log(
        string.format("trimmed %s: removed %d entries (was %d, cap %d)", fullPath, removed, count, schema.maxMapEntries)
      )
    end
  end

  -- Step 3b: recurse into nested fields. Runs both for already-existing
  -- table values AND for tables that were just defaulted in step 1, so
  -- nested subfields get filled in a single pass.
  if schema.type == "table" and schema.fields then
    for fieldName, fieldSchema in pairs(schema.fields) do
      ValidateField(value, fieldName, fieldSchema, log, fullPath)
    end
  end
end

local function ApplyMigrations(db, log)
  local from = tonumber(db.__schemaVersion) or 0
  if from >= LATEST_SCHEMA_VERSION then
    return 0
  end
  local applied = 0
  for v = from + 1, LATEST_SCHEMA_VERSION do
    local migration = MIGRATIONS[v]
    if type(migration) == "function" then
      if migration(db, log) == true then
        applied = applied + 1
      end
    end
  end
  db.__schemaVersion = LATEST_SCHEMA_VERSION
  return applied
end

--- Sanitizes the IsiLiveDB table in-place.
-- @param db table The IsiLiveDB SavedVariables table (must be a table).
-- @param logFn function|nil Optional callback for each correction message.
-- @return number, number corrections applied, migrations applied
function DBSchema.Sanitize(db, logFn)
  if type(db) ~= "table" then
    return 0, 0
  end

  local corrections = 0
  local log = function(message)
    corrections = corrections + 1
    if type(logFn) == "function" then
      logFn(message)
    end
  end

  local migrationsApplied = ApplyMigrations(db, log)

  for fieldName, fieldSchema in pairs(SCHEMA) do
    ValidateField(db, fieldName, fieldSchema, log, nil)
  end

  return corrections, migrationsApplied
end

--- Returns the latest schema version stamped by Sanitize.
-- @return number
function DBSchema.GetSchemaVersion()
  return LATEST_SCHEMA_VERSION
end

--- Returns the field names known to the current schema (for static gates).
-- @return table<string, true>
function DBSchema.GetKnownFieldNames()
  local names = {}
  for fieldName in pairs(SCHEMA) do
    names[fieldName] = true
  end
  return names
end

return DBSchema
