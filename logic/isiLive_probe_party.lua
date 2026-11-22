local _, addonTable = ...

addonTable = addonTable or {}

-- Probe mode (rule 239), party probes: are the UNIT_SPELLCAST_SUCCEEDED and
-- UNIT_AURA payloads of party members readable for an addon inside a key and
-- outside (groundwork for a group defensive tracker)? Split out of
-- logic/isiLive_probe_log.lua; ProbeLog keeps the session, the sink, the
-- per-run budgets and the key state and hands this module a narrow interface
-- (ProbeLog.Internal). ProbeLog calls NextSegment at every combat edge, key
-- start and key end and FlushTally before the report.
--
-- Every hook starts with IsEnabled(): with the mode off nothing else runs.
-- Every value coming from the client is checked with IsSecretValue before
-- any comparison, arithmetic or string conversion; a secret value is only
-- ever written as the word "secret".
local ProbeLog = assert(addonTable.ProbeLog, "isiLive: ProbeLog missing")
local ProbeParty = {}
addonTable.ProbeParty = ProbeParty
local IsSecretValue = addonTable.Validators.IsSecretValue

local Internal = assert(ProbeLog.Internal, "isiLive: ProbeLog.Internal missing")
local Append = Internal.Append
local TakeBudget = Internal.TakeBudget
local YesNo = Internal.YesNo
local IsKeyActive = Internal.IsKeyActive
local ReadInCombat = Internal.ReadInCombat

-- Detail lines per phase (pull, between pulls, outside a key, key with an
-- unreadable combat state), at most partyLinesPerSegment per kind between two
-- combat edges so the budget spreads over several pulls. Every event still
-- counts in the party_tally line written at the next edge. The per-run
-- counters live in ProbeLog's run state and start over at the key start.
local LIMITS = {
  partyCastLinesPerPhase = 40,
  partyAuraLinesPerPhase = 40,
  partyLinesPerSegment = 8,
  partyAuraScansPerRun = 40,
  partyAuraScanAuras = 8,
  partyAuraAddedExamined = 5,
  partyListLengthMax = 40,
  partyTallyLinesPerRun = 120,
}
ProbeParty.LIMITS = LIMITS

--- True while probe mode is on (ProbeLog owns the switch).
function ProbeParty.IsEnabled()
  return ProbeLog.IsEnabled()
end

-- Detail lines are budgeted per phase; the per-phase counters below count
-- every event and go out as one party_tally line per phase at the next combat
-- edge, key start, key end or report.
local PARTY_UNIT_SET = { party1 = true, party2 = true, party3 = true, party4 = true }
local PHASE_COUNTER_SUFFIX = { pull = "Pull", between = "Between", outside = "Outside", unknown = "Unknown" }
local TALLY_PHASES = { "pull", "between", "unknown", "outside" }
-- Aura fields a defensive tracker needs; read with rawget, never compared.
local AURA_FIELDS = { "spellId", "auraInstanceID", "expirationTime", "duration", "sourceUnit", "isHelpful" }
-- Name of the instance ID field, kept apart so a field-name check never reads
-- like a payload comparison.
local INSTANCE_ID_FIELD = AURA_FIELDS[2]

local partySegment = 0
local partySegmentLines = { Cast = 0, Aura = 0 }
local partyScanSegment = nil
local partyTally = {}

-- Phase of a party event: outside (no key), pull (key, in combat), between
-- (key, out of combat) or unknown (key, combat state not readable).
local function ReadPartyPhase()
  local inKey = IsKeyActive()
  local inCombat = ReadInCombat()
  local phase
  if not inKey then
    phase = "outside"
  elseif inCombat == "yes" then
    phase = "pull"
  elseif inCombat == "no" then
    phase = "between"
  else
    phase = "unknown"
  end
  return phase, inKey, inCombat
end

local function PartyTallyFor(phase)
  local tally = partyTally[phase]
  if not tally then
    tally = {
      casts = 0,
      castSpellSecret = 0,
      castSpellReadable = 0,
      castGuidSecret = 0,
      auraEvents = 0,
      auras = 0,
      auraSecret = 0,
      auraReadable = 0,
      auraErrors = 0,
    }
    partyTally[phase] = tally
  end
  return tally
end

local function FlushPartyTally(moment)
  for _, phase in ipairs(TALLY_PHASES) do
    local tally = partyTally[phase]
    if tally and (tally.casts > 0 or tally.auraEvents > 0) then
      partyTally[phase] = nil
      if TakeBudget("partyTallyLines", LIMITS.partyTallyLinesPerRun, "party_tally") then
        Append(
          string.format(
            "[PROBE] event=party_tally at=%s phase=%s inKey=%s casts=%d castSpellSecret=%d castSpellReadable=%d "
              .. "castGuidSecret=%d auraEvents=%d auras=%d auraSecret=%d auraReadable=%d auraErrors=%d",
            moment,
            phase,
            YesNo(phase ~= "outside"),
            tally.casts,
            tally.castSpellSecret,
            tally.castSpellReadable,
            tally.castGuidSecret,
            tally.auraEvents,
            tally.auras,
            tally.auraSecret,
            tally.auraReadable,
            tally.auraErrors
          )
        )
      end
    end
  end
end

-- A combat edge, key start or key end closes the current segment: the
-- tallies go out and the per-segment line counts and the scan start over.
local function NextPartySegment(moment)
  FlushPartyTally(moment)
  partySegment = partySegment + 1
  partySegmentLines = { Cast = 0, Aura = 0 }
end

local function TakePartyLineBudget(kind, phase)
  if partySegmentLines[kind] >= LIMITS.partyLinesPerSegment then
    return false
  end
  local limit = kind == "Cast" and LIMITS.partyCastLinesPerPhase or LIMITS.partyAuraLinesPerPhase
  local probeName = (kind == "Cast" and "party_cast_" or "party_aura_") .. phase
  if not TakeBudget("party" .. kind .. PHASE_COUNTER_SUFFIX[phase], limit, probeName) then
    return false
  end
  partySegmentLines[kind] = partySegmentLines[kind] + 1
  return true
end

-- A readable party token, or nil (secret, not a string, not party1..4).
local function ReadPartyUnit(unit)
  if IsSecretValue(unit) or type(unit) ~= "string" then
    return nil
  end
  return PARTY_UNIT_SET[unit] and unit or nil
end

-- Rule 11: no probe in a raid. Only a readable "true" counts as a raid; the
-- probe only reads, so an unreadable answer does not stop it.
local function IsReadablyInRaid()
  local isInRaid = rawget(_G, "IsInRaid")
  if type(isInRaid) ~= "function" then
    return false
  end
  local ok, value = pcall(isInRaid)
  if not ok or IsSecretValue(value) then
    return false
  end
  return value == true
end
ProbeParty.IsReadablyInRaid = IsReadablyInRaid

-- UnitGUID / UnitName for a unit as readable / secret / nil / error / api_missing.
local function DescribeUnitRead(fn, unit)
  if type(fn) ~= "function" then
    return "api_missing"
  end
  local ok, value = pcall(fn, unit)
  if not ok then
    return "error"
  end
  if IsSecretValue(value) then
    return "secret"
  end
  return value == nil and "nil" or "readable"
end

-- One field of a client table: state (readable / secret / nil / error) and the
-- plain value when readable. rawget never triggers a metamethod.
local function ReadClientField(tbl, key)
  local ok, value = pcall(rawget, tbl, key)
  if not ok then
    return "error", nil
  end
  if IsSecretValue(value) then
    return "secret", nil
  end
  if value == nil then
    return "nil", nil
  end
  return "readable", value
end

-- Field states of one aura record. Returns states, secret (any field secret
-- or the record itself), error (a read failed) and the readable instance ID.
local function DescribeAuraRecord(aura)
  local states = {}
  if IsSecretValue(aura) then
    for _, field in ipairs(AURA_FIELDS) do
      states[field] = "secret"
    end
    return states, true, false, nil
  end
  if type(aura) ~= "table" then
    for _, field in ipairs(AURA_FIELDS) do
      states[field] = "error"
    end
    return states, false, true, nil
  end
  local anySecret, anyError, instanceID = false, false, nil
  for _, field in ipairs(AURA_FIELDS) do
    local state, value = ReadClientField(aura, field)
    states[field] = state
    if state == "secret" then
      anySecret = true
    elseif state == "error" then
      anyError = true
    elseif field == INSTANCE_ID_FIELD and type(value) == "number" then
      instanceID = value
    end
  end
  return states, anySecret, anyError, instanceID
end

local function TallyAuraRecord(tally, isSecret, isError)
  tally.auras = tally.auras + 1
  if isError then
    tally.auraErrors = tally.auraErrors + 1
  elseif isSecret then
    tally.auraSecret = tally.auraSecret + 1
  else
    tally.auraReadable = tally.auraReadable + 1
  end
end

-- Reads a client list by index up to `max` entries. Returns the entries seen
-- (secret entries included), whether more may follow, and an error stage.
local function ReadClientList(list, max)
  local items = {}
  for index = 1, max do
    local ok, item = pcall(rawget, list, index)
    if not ok then
      return items, false, "list_index"
    end
    if IsSecretValue(item) then
      items[#items + 1] = item
    elseif item == nil then
      return items, false, nil
    else
      items[#items + 1] = item
    end
  end
  return items, true, nil
end

-- GetAuraDataByAuraInstanceID(unit, id) for a readable instance ID.
local function DescribeAuraByInstanceID(unit, instanceID)
  if instanceID == nil then
    return "no_id"
  end
  local unitAuras = rawget(_G, "C_UnitAuras")
  local fn = type(unitAuras) == "table" and rawget(unitAuras, "GetAuraDataByAuraInstanceID") or nil
  if type(fn) ~= "function" then
    return "api_missing"
  end
  local ok, aura = pcall(fn, unit, instanceID)
  if not ok then
    return "error"
  end
  if IsSecretValue(aura) then
    return "secret"
  end
  if type(aura) ~= "table" then
    return aura == nil and "nil" or "error"
  end
  local _, anySecret, anyError = DescribeAuraRecord(aura)
  if anyError then
    return "error"
  end
  return anySecret and "fields_secret" or "readable"
end

-- The UNIT_AURA payload (UnitAuraUpdateInfo): info / isFullUpdate / added
-- count and the field states of the first added aura. Every examined added
-- aura (at most partyAuraAddedExamined) counts in the tally.
local function DescribePartyAuraUpdate(info, tally)
  local result = { info = "table", full = "nil", added = "none", first = nil, firstID = nil, err = "none" }
  if IsSecretValue(info) then
    result.info = "secret"
    return result
  end
  if type(info) ~= "table" then
    result.info = info == nil and "nil" or "not_a_table"
    return result
  end
  local fullState, fullValue = ReadClientField(info, "isFullUpdate")
  if fullState == "readable" then
    result.full = YesNo(fullValue == true)
  else
    result.full = fullState
  end
  local listState, list = ReadClientField(info, "addedAuras")
  if listState == "secret" or listState == "error" then
    result.added = listState
    if listState == "error" then
      result.err = "added_read"
      tally.auraErrors = tally.auraErrors + 1
    end
    return result
  end
  if listState == "nil" then
    return result
  end
  if type(list) ~= "table" then
    result.added = "not_a_table"
    return result
  end
  local items, more, errStage = ReadClientList(list, LIMITS.partyListLengthMax)
  if errStage then
    result.err = errStage
    tally.auraErrors = tally.auraErrors + 1
  end
  result.added = string.format("%d%s", #items, more and "+" or "")
  for index = 1, math.min(#items, LIMITS.partyAuraAddedExamined) do
    local states, isSecret, isError, instanceID = DescribeAuraRecord(items[index])
    TallyAuraRecord(tally, isSecret, isError)
    if index == 1 then
      result.first = states
      result.firstID = instanceID
    end
  end
  return result
end

-- One HELPFUL scan per segment (first party UNIT_AURA after a combat edge):
-- GetAuraDataByIndex(unit, 1..partyAuraScanAuras) with secret counts per field.
local function ScanPartyAuras(unit, phase, inKey, inCombat, tally)
  if partyScanSegment == partySegment then
    return
  end
  partyScanSegment = partySegment
  if not TakeBudget("partyAuraScans", LIMITS.partyAuraScansPerRun, "party_aura_scan") then
    return
  end
  local unitAuras = rawget(_G, "C_UnitAuras")
  local byIndex = type(unitAuras) == "table" and rawget(unitAuras, "GetAuraDataByIndex") or nil
  if type(byIndex) ~= "function" then
    Append(string.format("[PROBE] event=party_aura_scan unit=%s phase=%s api=missing", unit, phase))
    return
  end
  local auras, auraSecret, readable, errors = 0, 0, 0, 0
  local errStage = "none"
  local fieldSecret = {}
  for _, field in ipairs(AURA_FIELDS) do
    fieldSecret[field] = 0
  end
  for index = 1, LIMITS.partyAuraScanAuras do
    local ok, aura = pcall(byIndex, unit, index, "HELPFUL")
    if not ok then
      errors = errors + 1
      errStage = "call"
      tally.auraErrors = tally.auraErrors + 1
      break
    end
    local auraIsSecret = IsSecretValue(aura)
    if not auraIsSecret and type(aura) ~= "table" then
      break
    end
    auras = auras + 1
    local states, isSecret, isError = DescribeAuraRecord(aura)
    TallyAuraRecord(tally, isSecret, isError)
    if auraIsSecret then
      auraSecret = auraSecret + 1
    elseif isError then
      errors = errors + 1
      errStage = "field_read"
    elseif not isSecret then
      readable = readable + 1
    end
    for _, field in ipairs(AURA_FIELDS) do
      if states[field] == "secret" then
        fieldSecret[field] = fieldSecret[field] + 1
      end
    end
  end
  Append(
    string.format(
      "[PROBE] event=party_aura_scan unit=%s phase=%s inKey=%s inCombat=%s auras=%d auraSecret=%d readable=%d "
        .. "spellIdSecret=%d auraInstanceIDSecret=%d expirationTimeSecret=%d durationSecret=%d "
        .. "sourceUnitSecret=%d isHelpfulSecret=%d errors=%d error=%s",
      unit,
      phase,
      YesNo(inKey),
      inCombat,
      auras,
      auraSecret,
      readable,
      fieldSecret.spellId,
      fieldSecret.auraInstanceID,
      fieldSecret.expirationTime,
      fieldSecret.duration,
      fieldSecret.sourceUnit,
      fieldSecret.isHelpful,
      errors,
      errStage
    )
  )
end

--- UNIT_SPELLCAST_SUCCEEDED of party1..4 (own frames, see the main chunk
-- below): spell ID, castGUID, UnitGUID and UnitName readable or secret.
function ProbeParty.OnPartyCast(unit, castGUID, spellID)
  if not ProbeParty.IsEnabled() then
    return
  end
  local partyUnit = ReadPartyUnit(unit)
  if not partyUnit or IsReadablyInRaid() then
    return
  end
  local phase, inKey, inCombat = ReadPartyPhase()
  local tally = PartyTallyFor(phase)
  tally.casts = tally.casts + 1
  local spellSecret = IsSecretValue(spellID)
  local spellText
  if spellSecret then
    tally.castSpellSecret = tally.castSpellSecret + 1
    spellText = "secret"
  elseif type(spellID) == "number" then
    tally.castSpellReadable = tally.castSpellReadable + 1
    spellText = string.format("%d", spellID)
  else
    spellText = spellID == nil and "nil" or "?"
  end
  -- castGuidSecret counts the masked castGUID of the event, the same value
  -- the line writes as castGUIDSecret (until 2026-11-21 it counted a masked
  -- UnitGUID instead and stayed 0 while every line said castGUIDSecret=yes).
  local castGuidSecret = IsSecretValue(castGUID)
  if castGuidSecret then
    tally.castGuidSecret = tally.castGuidSecret + 1
  end
  local guidState = DescribeUnitRead(rawget(_G, "UnitGUID"), partyUnit)
  if not TakePartyLineBudget("Cast", phase) then
    return
  end
  local castGuidText
  if castGuidSecret then
    castGuidText = "yes"
  else
    castGuidText = castGUID == nil and "nil" or "no"
  end
  Append(
    string.format(
      "[PROBE] event=party_cast unit=%s phase=%s inKey=%s inCombat=%s spellIDSecret=%s spellID=%s "
        .. "castGUIDSecret=%s unitGUID=%s unitName=%s",
      partyUnit,
      phase,
      YesNo(inKey),
      inCombat,
      YesNo(spellSecret),
      spellText,
      castGuidText,
      guidState,
      DescribeUnitRead(rawget(_G, "UnitName"), partyUnit)
    )
  )
end

--- UNIT_AURA of party1..4 (existing dispatcher path, raid mode excluded by
-- the caller): payload readability, one GetAuraDataByAuraInstanceID check
-- for the first added aura and one HELPFUL scan per segment.
function ProbeParty.OnPartyAura(unit, updateInfo)
  if not ProbeParty.IsEnabled() then
    return
  end
  local partyUnit = ReadPartyUnit(unit)
  if not partyUnit then
    return
  end
  local phase, inKey, inCombat = ReadPartyPhase()
  local tally = PartyTallyFor(phase)
  tally.auraEvents = tally.auraEvents + 1
  local update = DescribePartyAuraUpdate(updateInfo, tally)
  ScanPartyAuras(partyUnit, phase, inKey, inCombat, tally)
  if not TakePartyLineBudget("Aura", phase) then
    return
  end
  local fieldParts = {}
  for _, field in ipairs(AURA_FIELDS) do
    fieldParts[#fieldParts + 1] = field .. "=" .. (update.first and update.first[field] or "n/a")
  end
  local byInstance = update.first and DescribeAuraByInstanceID(partyUnit, update.firstID) or "n/a"
  Append(
    string.format(
      "[PROBE] event=party_aura unit=%s phase=%s inKey=%s inCombat=%s info=%s fullUpdate=%s added=%s %s "
        .. "byInstanceID=%s error=%s",
      partyUnit,
      phase,
      YesNo(inKey),
      inCombat,
      update.info,
      update.full,
      update.added,
      table.concat(fieldParts, " "),
      byInstance,
      update.err
    )
  )
end

--- Closes the current party segment (combat edge, key start, key end): the
-- open tallies go out and the per-segment line counts and the scan start over.
-- At the key start ProbeLog calls it before the budget reset, so the tallies
-- of the time before the key go out under the old budget.
ProbeParty.NextSegment = NextPartySegment

--- Writes the open tallies without closing the segment (before the report);
-- nothing with probe mode off.
function ProbeParty.FlushTally(moment)
  if ProbeParty.IsEnabled() then
    FlushPartyTally(moment)
  end
end

-- Party casts: UNIT_SPELLCAST_SUCCEEDED of party1..4, registered once in the
-- main chunk (rules 149 and 258). RegisterUnitEvent takes at most two units
-- per frame and a second call replaces the filter, so two frames carry
-- party1/party2 and party3/party4; the dispatcher keeps its player/pet
-- filter, so no existing handler sees a party cast. Only when a frame cannot
-- be created or has no RegisterUnitEvent does one frame take the event
-- unfiltered; OnPartyCast drops every unit outside party1..4 either way.
-- With probe mode off the handler costs one table read per party cast.
local PARTY_CAST_UNIT_PAIRS = { { "party1", "party2" }, { "party3", "party4" } }
do
  local createFrame = rawget(_G, "CreateFrame")
  local function OnPartyCastEvent(_, _, unit, castGUID, spellID)
    ProbeParty.OnPartyCast(unit, castGUID, spellID)
  end
  local function NewEventFrame()
    if type(createFrame) ~= "function" then
      return nil
    end
    local ok, frame = pcall(createFrame, "Frame")
    if not ok or type(frame) ~= "table" or type(frame.SetScript) ~= "function" then
      return nil
    end
    return frame
  end
  local frames = {}
  local filtered = true
  for index = 1, #PARTY_CAST_UNIT_PAIRS do
    local frame = NewEventFrame()
    if not frame then
      filtered = false
      break
    end
    frames[index] = frame
    if type(frame.RegisterUnitEvent) ~= "function" then
      filtered = false
    end
  end
  local eventUtils = addonTable.EventUtils
  if filtered then
    for index, frame in ipairs(frames) do
      frame:SetScript("OnEvent", OnPartyCastEvent)
      local pair = PARTY_CAST_UNIT_PAIRS[index]
      -- An unknown event fails on the first frame already (rule 258).
      if not eventUtils.SafeRegisterUnitEvent(frame, "UNIT_SPELLCAST_SUCCEEDED", pair[1], pair[2]) then
        break
      end
    end
  elseif frames[1] then
    frames = { frames[1] }
    frames[1]:SetScript("OnEvent", OnPartyCastEvent)
    eventUtils.SafeRegisterEvent(frames[1], "UNIT_SPELLCAST_SUCCEEDED")
  end
  ProbeParty._partyCastFrames = frames
  ProbeParty._partyCastFiltered = filtered and #frames > 0
end
