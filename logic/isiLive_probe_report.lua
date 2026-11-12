local _, addonTable = ...

addonTable = addonTable or {}

-- Probe report (rule 239): `/isilive probe report` reads the `[PROBE]` lines
-- that probe mode wrote into the runtime log ring and turns them into one
-- verdict line per open question. Every verdict comes from logged fields
-- only; a question without matching lines is "unknown". The ring may hold
-- several keys and older line formats, so missing fields are tolerated and
-- simply do not count as evidence.
local ProbeReport = {}
addonTable.ProbeReport = ProbeReport

local TAG = "[PROBE]"

local KEY_END_PHASES = {
  key_completed = true,
  key_reset = true,
  ["key_completed+5s"] = true,
  ["key_reset+5s"] = true,
}
local LATE_PHASES = {
  post_key_outside_instance = true,
  post_key_restriction_lifted = true,
}

--- Parses one runtime log entry into a field table, or nil for a line that
-- is not a probe line. Values stay strings.
-- @param entry string e.g. "seq=4 t=10.000 [PROBE] event=meter phase=..."
-- @return table|nil {event = "meter", phase = "...", ...}
function ProbeReport.ParseLine(entry)
  local text = tostring(entry or "")
  local tagAt = text:find(TAG .. " ", 1, true)
  if not tagAt then
    return nil
  end
  local fields = {}
  for key, value in text:sub(tagAt + #TAG + 1):gmatch("(%w+)=(%S*)") do
    if fields[key] == nil then
      fields[key] = value
    end
  end
  if type(fields.event) ~= "string" or fields.event == "" then
    return nil
  end
  return fields
end

local function Count(value)
  local number = tonumber(value)
  if number == nil or number < 0 then
    return 0
  end
  return number
end

local function NewTally()
  return { readable = 0, secret = 0, total = 0 }
end

-- yes: only readable answers; no: only secret answers; partly: both;
-- unknown: neither.
local function Verdict(readable, secret)
  if readable > 0 and secret == 0 then
    return "yes"
  end
  if secret > 0 and readable == 0 then
    return "no"
  end
  if readable > 0 and secret > 0 then
    return "partly"
  end
  return "unknown"
end

-- One meter line: "secret" when any part of the session was masked,
-- "readable" for a present session with at least one fully readable source,
-- nil otherwise (no session, missing API, no sources).
local function ClassifyMeterLine(fields)
  if fields.api ~= nil then
    return nil
  end
  if
    fields.present == "secret"
    or fields.sources == "secret"
    or Count(fields.secretEntries) > 0
    or Count(fields.secretNames) > 0
    or Count(fields.secretAmounts) > 0
  then
    return "secret"
  end
  if fields.present == "yes" and Count(fields.sources) >= 1 then
    return "readable"
  end
  return nil
end

local function MeterGroup(phase)
  if phase == "between_pulls" then
    return "pulls"
  end
  if KEY_END_PHASES[phase] then
    return "keyEnd"
  end
  if LATE_PHASES[phase] then
    return "late"
  end
  return nil
end

-- One snapshot is a run of consecutive meter lines of one phase. The writer
-- always starts a snapshot with Overall x DamageDone (or a single api= line),
-- so that line opens a new one.
local function IsSnapshotStart(fields)
  if fields.api ~= nil then
    return true
  end
  local session = fields.session or ""
  local meter = fields.meter or ""
  return session:find("^Overall%(") ~= nil and meter:find("^DamageDone%(") ~= nil
end

local function FinishSnapshot(acc, snapshot)
  if not snapshot then
    return
  end
  local tally = acc.meter[snapshot.group]
  tally.total = tally.total + 1
  if snapshot.secret then
    tally.secret = tally.secret + 1
  elseif snapshot.readable then
    tally.readable = tally.readable + 1
  end
end

local function AddMeterLine(acc, fields)
  local group = MeterGroup(fields.phase)
  local current = acc.snapshot
  if current and (IsSnapshotStart(fields) or current.phase ~= fields.phase) then
    FinishSnapshot(acc, current)
    current = nil
  end
  if not group then
    acc.snapshot = nil
    return
  end
  if not current then
    current = { phase = fields.phase, group = group }
  end
  local class = ClassifyMeterLine(fields)
  if class == "secret" then
    current.secret = true
  elseif class == "readable" then
    current.readable = true
  end
  acc.snapshot = current
end

local function AddThreatLine(acc, fields)
  if fields.inKey ~= "yes" or fields.plates == nil then
    return
  end
  local threat = acc.threat
  threat.samples = threat.samples + 1
  threat.plateReadable = threat.plateReadable
    + Count(fields.threat0)
    + Count(fields.threat1)
    + Count(fields.threat2)
    + Count(fields.threat3)
  threat.plateSecret = threat.plateSecret + Count(fields.threatSecret)
  threat.canAttackSecret = threat.canAttackSecret + Count(fields.hostileSecret)
  -- `self=` exists since the K6 extension; older lines carry no own threat.
  if fields.self == "secret" then
    threat.selfSecret = threat.selfSecret + 1
  elseif fields.self ~= nil and tonumber(fields.self) ~= nil then
    threat.selfReadable = threat.selfReadable + 1
  end
end

local function WeaponSlotReadable(fields, prefix)
  return fields[prefix] == "yes"
    and tonumber(fields[prefix .. "Min"]) ~= nil
    and tonumber(fields[prefix .. "Enchant"]) ~= nil
end

local WEAPON_FIELDS = { "mh", "mhMin", "mhEnchant", "oh", "ohMin", "ohEnchant" }

local function AddReadyCheckLine(acc, fields)
  local auras = acc.auras
  if fields.auras ~= nil and tonumber(fields.auras) ~= nil then
    local masked = Count(fields.auraSecret) + Count(fields.spellIdSecret) + Count(fields.expirationSecret)
    if masked > 0 or fields.bySpellID == "secret" then
      auras.secret = auras.secret + 1
    elseif Count(fields.auras) >= 1 then
      auras.readable = auras.readable + 1
    end
  end
  local weapon = acc.weapon
  local weaponSecret = false
  for _, key in ipairs(WEAPON_FIELDS) do
    if fields[key] == "secret" then
      weaponSecret = true
    end
  end
  if weaponSecret then
    weapon.secret = weapon.secret + 1
  elseif WeaponSlotReadable(fields, "mh") or WeaponSlotReadable(fields, "oh") then
    weapon.readable = weapon.readable + 1
  end
end

local function AddOwnCastLine(acc, fields)
  local casts = acc.casts
  if fields.spellIDSecret == "yes" then
    casts.secret = casts.secret + 1
  elseif fields.spellIDSecret == "no" then
    casts.readable = casts.readable + 1
    if fields.kick == "yes" then
      casts.kickReadable = casts.kickReadable + 1
    end
  end
end

local function AddChatLockdownLine(acc, fields)
  if fields.inKey ~= "yes" or fields.value == nil then
    return
  end
  local chat = acc.chat
  chat.inKey = chat.inKey + 1
  if fields.value == "secret" then
    chat.secret = chat.secret + 1
  elseif fields.value == "yes" then
    chat.yes = chat.yes + 1
  elseif fields.value == "no" then
    chat.no = chat.no + 1
  end
end

local function AddKickLine(acc, fields)
  local kicks = acc.kicks
  kicks.total = kicks.total + 1
  local verdict = fields.verdict
  if verdict == "landed" or verdict == "missed" or verdict == "excluded" then
    kicks[verdict] = kicks[verdict] + 1
  end
  local ms = tonumber(fields.firstInterruptAfterMs)
  if ms ~= nil then
    kicks.timings[#kicks.timings + 1] = ms
  end
end

local function AddRestrictionLine(acc, fields)
  local restriction = acc.restriction
  restriction.total = restriction.total + 1
  if fields.type == "secret" or fields.state == "secret" then
    restriction.secret = restriction.secret + 1
  end
  local typeName = fields.type
  if typeName ~= nil and typeName ~= "secret" then
    typeName = typeName:match("^(%a[%w_]*)%(%d+%)$") or typeName
    if typeName ~= "" and not restriction.seen[typeName] then
      restriction.seen[typeName] = true
      restriction.types[#restriction.types + 1] = typeName
    end
  end
end

local function AddCapLine(acc, fields)
  local probe = fields.probe
  if type(probe) ~= "string" or probe == "" then
    return
  end
  if not acc.caps.seen[probe] then
    acc.caps.seen[probe] = 0
    acc.caps.order[#acc.caps.order + 1] = probe
  end
  acc.caps.seen[probe] = acc.caps.seen[probe] + 1
end

local LINE_HANDLERS = {
  threat = AddThreatLine,
  ready_check = AddReadyCheckLine,
  own_cast = AddOwnCastLine,
  chat_lockdown = AddChatLockdownLine,
  kick = AddKickLine,
  restriction = AddRestrictionLine,
  cap_reached = AddCapLine,
}

--- Tallies probe lines (oldest first) into the counters the report prints.
-- @param entries table runtime log entries; non-probe entries are skipped
-- @return table summary
function ProbeReport.Summarize(entries)
  local acc = {
    lines = 0,
    keys = 0,
    meter = { pulls = NewTally(), keyEnd = NewTally(), late = NewTally() },
    threat = {
      samples = 0,
      plateReadable = 0,
      plateSecret = 0,
      selfReadable = 0,
      selfSecret = 0,
      canAttackSecret = 0,
    },
    auras = NewTally(),
    weapon = NewTally(),
    casts = { readable = 0, secret = 0, kickReadable = 0 },
    chat = { inKey = 0, yes = 0, no = 0, secret = 0 },
    kicks = { total = 0, landed = 0, missed = 0, excluded = 0, timings = {} },
    restriction = { total = 0, secret = 0, types = {}, seen = {} },
    caps = { seen = {}, order = {} },
  }
  for _, entry in ipairs(type(entries) == "table" and entries or {}) do
    local fields = ProbeReport.ParseLine(entry)
    if fields then
      acc.lines = acc.lines + 1
      if fields.event == "meter" then
        AddMeterLine(acc, fields)
      else
        FinishSnapshot(acc, acc.snapshot)
        acc.snapshot = nil
        if fields.event == "key_start" then
          acc.keys = acc.keys + 1
        end
        local handler = LINE_HANDLERS[fields.event]
        if handler then
          handler(acc, fields)
        end
      end
    end
  end
  FinishSnapshot(acc, acc.snapshot)
  acc.snapshot = nil
  table.sort(acc.kicks.timings)
  return acc
end

-- min/median/max of the logged millisecond values; the median of an even
-- count is the lower middle value, so every printed number was logged.
local function TimingText(timings)
  local count = #timings
  if count == 0 then
    return "-"
  end
  local median = timings[math.floor((count + 1) / 2)]
  return string.format("%d/%d/%d", timings[1], median, timings[count])
end

local VERDICT_KEYS = {
  yes = "PROBE_REPORT_YES",
  no = "PROBE_REPORT_NO",
  partly = "PROBE_REPORT_PARTLY",
  unknown = "PROBE_REPORT_UNKNOWN",
}
local VERDICT_FALLBACK = { yes = "yes", no = "no", partly = "partly", unknown = "unknown" }

--- Builds the localized report lines from runtime log entries.
-- @param entries table runtime log entries (oldest first)
-- @param L table locale table (missing keys fall back to English)
-- @return table list of chat lines
function ProbeReport.BuildLines(entries, L)
  L = type(L) == "table" and L or {}
  local function Word(verdict)
    return L[VERDICT_KEYS[verdict]] or VERDICT_FALLBACK[verdict]
  end
  local s = ProbeReport.Summarize(entries)
  if s.lines == 0 then
    return {
      L.PROBE_REPORT_EMPTY
        or "Probe report: no [PROBE] lines in the runtime log. Turn on /isilive probe on and play a key first.",
    }
  end
  local out = {}
  local function Add(fmt, fallback, ...)
    out[#out + 1] = string.format(fmt or fallback, ...)
  end
  Add(L.PROBE_REPORT_HEADER, "Probe report (%d probe lines, %d key starts in the runtime log):", s.lines, s.keys)
  local pulls, keyEnd, late = s.meter.pulls, s.meter.keyEnd, s.meter.late
  Add(
    L.PROBE_REPORT_METER_PULLS,
    "K9 damage meter between pulls readable: %s (%d snapshots, %d secret)",
    Word(Verdict(pulls.readable, pulls.secret)),
    pulls.total,
    pulls.secret
  )
  Add(
    L.PROBE_REPORT_METER_AFTER,
    "K11 damage meter after the key: at the key end %s (%d snapshots, %d secret), later %s (%d snapshots, %d secret)",
    Word(Verdict(keyEnd.readable, keyEnd.secret)),
    keyEnd.total,
    keyEnd.secret,
    Word(Verdict(late.readable, late.secret)),
    late.total,
    late.secret
  )
  local threat = s.threat
  Add(
    L.PROBE_REPORT_THREAT,
    "K6 threat in the key: per nameplate %s (%d readable, %d secret), own threat %s (%d readable, %d secret), "
      .. "UnitCanAttack secret: %d",
    Word(Verdict(threat.plateReadable, threat.plateSecret)),
    threat.plateReadable,
    threat.plateSecret,
    Word(Verdict(threat.selfReadable, threat.selfSecret)),
    threat.selfReadable,
    threat.selfSecret,
    threat.canAttackSecret
  )
  Add(
    L.PROBE_REPORT_READY_CHECK,
    "K4 ready check: own buffs %s (%d readable, %d secret), weapon enchant %s (%d readable, %d secret)",
    Word(Verdict(s.auras.readable, s.auras.secret)),
    s.auras.readable,
    s.auras.secret,
    Word(Verdict(s.weapon.readable, s.weapon.secret)),
    s.weapon.readable,
    s.weapon.secret
  )
  -- A kick is only recognized from a readable spell ID, so "no" needs every
  -- logged own cast to be masked; readable non-kick casts alone stay unknown.
  local casts = s.casts
  local kickIds = "unknown"
  if casts.kickReadable > 0 then
    kickIds = "yes"
  elseif casts.secret > 0 and casts.readable == 0 then
    kickIds = "no"
  end
  Add(
    L.PROBE_REPORT_KICK_IDS,
    "Own interrupt spell IDs readable: %s (%d kick spells readable, %d own casts with a secret spell ID)",
    Word(kickIds),
    casts.kickReadable,
    casts.secret
  )
  local chat = s.chat
  local chatSeen = "unknown"
  if chat.yes > 0 then
    chatSeen = "yes"
  elseif chat.no > 0 then
    chatSeen = "no"
  end
  Add(
    L.PROBE_REPORT_CHAT_LOCKDOWN,
    "Chat lockdown seen in the key: %s (%d readings in the key, %d secret)",
    Word(chatSeen),
    chat.inKey,
    chat.secret
  )
  local kicks = s.kicks
  if kicks.total == 0 then
    Add(L.PROBE_REPORT_KICKS_NONE, "K3 kick timing: %s (no kick lines)", Word("unknown"))
  else
    Add(
      L.PROBE_REPORT_KICKS,
      "K3 kick timing: %d kicks, %d landed, %d missed, %d excluded; ms to the first hostile interrupt "
        .. "min/median/max %s (%d timed)",
      kicks.total,
      kicks.landed,
      kicks.missed,
      kicks.excluded,
      TimingText(kicks.timings),
      #kicks.timings
    )
  end
  local restriction = s.restriction
  Add(
    L.PROBE_REPORT_RESTRICTIONS,
    "Restriction changes seen: %s (%d changes, %d secret; types: %s)",
    Word(restriction.total > 0 and "yes" or "unknown"),
    restriction.total,
    restriction.secret,
    #restriction.types > 0 and table.concat(restriction.types, ", ") or "-"
  )
  if #s.caps.order > 0 then
    local parts = {}
    for _, probe in ipairs(s.caps.order) do
      parts[#parts + 1] = string.format("%s x%d", probe, s.caps.seen[probe])
    end
    Add(L.PROBE_REPORT_CAPS, "Probe budgets reached: %s", table.concat(parts, ", "))
  end
  return out
end
