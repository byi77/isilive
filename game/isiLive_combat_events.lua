local _, addonTable = ...
addonTable = addonTable or {}

local CombatEvents = {}
addonTable.CombatEvents = CombatEvents

-- Battle-Res spells a player can cast on a dead ally in combat.
local BR_SPELL_IDS = {
  [20484] = true, -- Rebirth (Druid)
  [61999] = true, -- Raise Ally (Death Knight)
  [391054] = true, -- Intercession (Paladin)
  [20707] = true, -- Soulstone Resurrection (Warlock)
}

-- Bloodlust / Heroism / Time Warp variant cast spell IDs. UNIT_SPELLCAST_SUCCEEDED
-- fires exactly once per completed cast, so only the cast-triggering IDs belong
-- here (the corresponding Sated / Exhaustion debuffs never produce a cast event).
local LUST_CAST_IDS = {
  [2825] = true, -- Bloodlust (Shaman)
  [32182] = true, -- Heroism (Shaman)
  [80353] = true, -- Time Warp (Mage)
  [264667] = true, -- Primal Rage (Hunter Ferocity Pet)
  [390386] = true, -- Fury of the Aspects (Evoker)
  [466904] = true, -- Harrier's Cry (Marksmanship Hunter)
  [381301] = true, -- Feral Hide Drums
  [178207] = true, -- Drums of Fury
  [230935] = true, -- Drums of the Mountain
  [256740] = true, -- Drums of the Maelstrom
  [292463] = true, -- Drums of Deathly Ferocity
  [90355] = true, -- Ancient Hysteria (Core Hound)
  [160452] = true, -- Netherwinds (Nether Ray Pet)
}

local DEDUP_WINDOW_SECONDS = 3

local function DefaultGetTime()
  local fn = rawget(_G, "GetTime")
  return type(fn) == "function" and fn() or 0
end

local function DefaultIsInKey()
  local api = rawget(_G, "C_ChallengeMode")
  if type(api) ~= "table" or type(api.GetActiveChallengeMapID) ~= "function" then
    return false
  end
  local ok, mapID = pcall(api.GetActiveChallengeMapID)
  if not ok then
    return false
  end
  return type(mapID) == "number" and mapID > 0
end

-- Resolves a unit token (e.g. "party2") to a display-ready name. Prefers
-- GetUnitName(unit, true) so cross-realm players keep their realm suffix.
local function BuildDefaultGetUnitName()
  return function(unit)
    local getUnitNameFn = rawget(_G, "GetUnitName")
    if type(getUnitNameFn) == "function" then
      local ok, name = pcall(getUnitNameFn, unit, true)
      if ok and type(name) == "string" and name ~= "" then
        return name
      end
    end
    local unitNameFn = rawget(_G, "UnitName")
    if type(unitNameFn) == "function" then
      local ok, name = pcall(unitNameFn, unit)
      if ok and type(name) == "string" and name ~= "" then
        return name
      end
    end
    return unit
  end
end

function CombatEvents.CreateController(opts)
  opts = opts or {}
  local getTime = type(opts.getTime) == "function" and opts.getTime or DefaultGetTime
  local isInKey = type(opts.isInKey) == "function" and opts.isInKey or DefaultIsInKey
  local getUnitName = type(opts.getUnitName) == "function" and opts.getUnitName or BuildDefaultGetUnitName()
  local broadcast = type(opts.broadcastCombatAnnounce) == "function" and opts.broadcastCombatAnnounce
    or function(_kind, _sourceName, _spellID) end
  local getDB = type(opts.getDB) == "function" and opts.getDB or function()
    return {}
  end

  local controller = {}
  local recent = {}
  -- Cache the isInKey() result so a pull of casts (BR + Bloodlust both trigger
  -- many UNIT_SPELLCAST_SUCCEEDED in seconds) does not hit
  -- pcall(C_ChallengeMode.GetActiveChallengeMapID) on every cast. The cache is
  -- invalidated in Reset() which fires on CHALLENGE_MODE_START / COMPLETED /
  -- RESET — exactly the events at which the value can change.
  local cachedInKey = nil

  local function IsInKeyCached()
    if cachedInKey == nil then
      cachedInKey = isInKey() == true
    end
    return cachedInKey
  end

  local function IsEnabledForBR()
    local db = getDB() or {}
    return db.chatAnnounceBR ~= false
  end

  local function IsEnabledForLust()
    local db = getDB() or {}
    return db.chatAnnounceLust ~= false
  end

  local function ShouldDedup(sourceName, spellID)
    if type(sourceName) ~= "string" or sourceName == "" or type(spellID) ~= "number" then
      return false
    end
    local key = sourceName .. "|" .. spellID
    local now = getTime()
    local last = recent[key]
    if last and (now - last) < DEDUP_WINDOW_SECONDS then
      return true
    end
    -- Sweep only runs on the dedup-miss path (the early `return true` above
    -- short-circuits a hit before we get here). Drops entries that fell out
    -- of the dedup window before writing the new timestamp. Reset() still
    -- clears the whole table on CHALLENGE_MODE_*; this in-line sweep keeps
    -- the map bounded across long sessions where those events do not fire
    -- (e.g. raid hopping without entering a key).
    for prevKey, prevWhen in pairs(recent) do
      if prevWhen and (now - prevWhen) >= DEDUP_WINDOW_SECONDS then
        recent[prevKey] = nil
      end
    end
    recent[key] = now
    return false
  end

  -- Only self-casts: the 12.0.0 Secret Values system masks spellID for other
  -- players' UNIT_SPELLCAST_SUCCEEDED events inside M+ / boss restriction
  -- zones, which makes BR_SPELL_IDS[spellID] throw "table index is secret".
  -- Each isiLive client detects exactly its own cast and broadcasts via the
  -- isiLive addon-message channel (BRLUST payload). All isiLive peers render
  -- the announcement locally; non-isiLive players see nothing. The previous
  -- SendChatMessage path was removed because 12.0 raises ADDON_ACTION_FORBIDDEN
  -- when the protected SendChatMessage is invoked from a tainted M+/boss
  -- execution context.
  function controller.HandleUnitSpellcastSucceeded(unit, _, spellID)
    if unit ~= "player" and unit ~= "pet" then
      return
    end
    if not IsInKeyCached() then
      return
    end
    if type(spellID) ~= "number" then
      return
    end
    local kind
    if BR_SPELL_IDS[spellID] then
      if unit ~= "player" then
        return
      end
      if not IsEnabledForBR() then
        return
      end
      kind = "BR"
    elseif LUST_CAST_IDS[spellID] then
      if not IsEnabledForLust() then
        return
      end
      kind = "LUST"
    else
      return
    end
    local sourceName = getUnitName(unit == "pet" and "player" or unit)
    if ShouldDedup(sourceName or "", spellID) then
      return
    end
    broadcast(kind, sourceName, spellID)
  end

  function controller.Reset()
    recent = {}
    cachedInKey = nil
  end

  -- Test-only hook: exposes the live size of the dedup map so the unit
  -- test for ShouldDedup's expiry sweep can verify the map stays bounded.
  -- Production paths never read this; the name carries the `_Test_` prefix
  -- so a stray production-side call is immediately visible in review.
  function controller._Test_GetRecentSize()
    local n = 0
    for _ in pairs(recent) do
      n = n + 1
    end
    return n
  end

  return controller
end

-- COMBAT_LOG_EVENT_UNFILTERED was removed from the public addon API in patch
-- 12.0.0 (Midnight) and raises ADDON_ACTION_FORBIDDEN on every
-- registration attempt, so we listen to UNIT_SPELLCAST_SUCCEEDED instead.
-- That event is not taint-sensitive, fires once per completed cast, and
-- exposes enough info (unit token + spell ID) to announce BR / Bloodlust
-- without needing combat-log access.
local controllerInstance = nil

function CombatEvents.SetDependencies(deps)
  if type(deps) ~= "table" then
    return
  end
  controllerInstance = CombatEvents.CreateController(deps)
end

function CombatEvents.HandleEvent(event, ...)
  if not controllerInstance then
    return
  end
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    controllerInstance.HandleUnitSpellcastSucceeded(...)
    return
  end
  if event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
    controllerInstance.Reset()
  end
end
