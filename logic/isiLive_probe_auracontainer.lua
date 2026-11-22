local _, addonTable = ...

addonTable = addonTable or {}

-- Probe mode (rule 239), aura container probes: groundwork for a group
-- defensive/external cooldown tracker for party members without isiLive.
-- Inside a key, party casts and party auras are secret for addon code (probe
-- log 2026-11-21). Blizzard's AuraContainer (CustomAuraContainerTemplate)
-- filters auras in secure code and only sizes itself; these probes check
-- whether that size can drive a display through secret values:
--
--   P1 visible  one small movable "isiLive Probe" frame with a row per
--               party1..4: a container on the defensive ID list and, when the
--               client accepts the filter, one on HELPFUL|EXTERNAL_DEFENSIVE
--               and one on HELPFUL|BIG_DEFENSIVE (the user takes screenshots)
--   P2 sensor   per party1..4 an invisible container (alpha 0, just left of
--               the screen) with one aura frame laid out sensorStride wide:
--               with a matching aura it reaches across the screen, so
--               IsMouseOver with a huge vertical reach answers "active".
--               The answer goes through C_CurveUtil.EvaluateColorValueFromBoolean
--               into StatusBar:SetValue, both of which accept secret values.
--   P3 combat   once per run, one second into a pull: SetUnit (same token),
--               SetEnabled(false/true), Hide/Show on a test container; blocked
--               calls show up as action_blocked lines (ProbeLog).
--   P4 secrets  C_Secrets answers for the ID list and Forbearance, once outside
--               a key and once in it.
--   P5 cursor   every sensor read notes whether GetCursorPosition is readable
--               and inside the screen (IsMouseOver depends on the cursor).
--
-- Frames are created only out of combat, never in a raid and never with
-- probe mode off (it is off after every load). Every hook starts with
-- IsEnabled(). Every value coming from the client is checked with
-- IsSecretValue before any comparison or conversion and only ever written as
-- the word "secret". UNIT_AURA is used as a trigger only; its payload is not
-- read here.
local ProbeLog = assert(addonTable.ProbeLog, "isiLive: ProbeLog missing")
local ProbeAuraContainer = {}
addonTable.ProbeAuraContainer = ProbeAuraContainer
local IsSecretValue = addonTable.Validators.IsSecretValue

local Internal = assert(ProbeLog.Internal, "isiLive: ProbeLog.Internal missing")
local Append = Internal.Append
local TakeBudget = Internal.TakeBudget
local YesNo = Internal.YesNo
local IsKeyActive = Internal.IsKeyActive
local ReadInCombat = Internal.ReadInCombat
local TimerAfter = Internal.TimerAfter

local LIMITS = {
  tickSeconds = 0.5, -- sensor reads while in combat
  ticksPerRun = 4000, -- about 33 minutes of combat
  auraTriggerDelaySeconds = 0.1, -- the container lays out on its next update
  sensorLinesPerPhase = 40,
  sensorLinesPerSegment = 8,
  tallyLinesPerRun = 120,
  setupLinesPerRun = 40,
  combatOpsPerRun = 1,
  combatOpsDelaySeconds = 1,
  secretsLinesPerRun = 24,
  secrecyIdsPerLine = 10,
  suspendRetrySeconds = 2,
}
ProbeAuraContainer.LIMITS = LIMITS

-- Sensor geometry: the container sits sensorOffsetX left of the screen edge;
-- one matching aura lays out one frame sensorStride wide, which reaches across
-- every screen. IsMouseOver(top, bottom, left, right) widens the hit box by
-- mouseOverReach up and down only, so the answer follows the width.
local GEOMETRY = {
  sensorStride = 60000,
  sensorOffsetX = -16,
  mouseOverReach = 100000,
  icon = 18,
  iconsPerColumn = 4,
  nameWidth = 90,
  columnWidth = 80,
  rowHeight = 22,
  headerHeight = 34,
  barWidth = 40,
  barHeight = 10,
}
ProbeAuraContainer.GEOMETRY = GEOMETRY

local PARTY_UNITS = { "party1", "party2", "party3", "party4" }
local UNIT_INDEX = { party1 = 1, party2 = 2, party3 = 3, party4 = 4 }
local CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
local FILTER_HELPFUL = "HELPFUL"
-- Visible columns: the ID list and the two Blizzard defensive filters.
local COLUMNS = {
  { key = "ids", filter = FILTER_HELPFUL, useIdList = true, label = "PROBE_AC_COL_IDS", fallback = "IDs" },
  {
    key = "ext",
    filter = "HELPFUL|EXTERNAL_DEFENSIVE",
    label = "PROBE_AC_COL_EXTERNAL",
    fallback = "EXT",
  },
  { key = "big", filter = "HELPFUL|BIG_DEFENSIVE", label = "PROBE_AC_COL_BIG", fallback = "BIG" },
}
local PHASE_SUFFIX = { pull = "Pull", between = "Between", outside = "Outside", unknown = "Unknown" }
local TALLY_PHASES = { "pull", "between", "unknown", "outside" }
local TALLY_FIELDS = {
  "reads",
  "overTrue",
  "overFalse",
  "overSecret",
  "overError",
  "overOther",
  "curveOk",
  "curveSecret",
  "curveError",
  "barOk",
  "barError",
  "cursorIn",
  "cursorOut",
  "cursorReadable",
  "cursorSecret",
  "cursorUnknown",
}

--- True while probe mode is on (ProbeLog owns the switch).
function ProbeAuraContainer.IsEnabled()
  return ProbeLog.IsEnabled()
end

-- Module state. `frames` exists after the first successful build of this
-- load; the containers cannot be destroyed, only disabled (suspended).
local frames = nil
local suspended = false
local suspendRetryPending = false
local segment = 0
local segmentLines = 0
local tally = {}
local seenSegment = {}
local lastReadable = {}
local pendingAura = {}
local tickGeneration = 0
local ticking = false
local runFlags = { secrets = {}, combatOps = false }

-- Spell data (rule 239): the records of data/isiLive_defensives.lua marked
-- `probe = true`, in manifest order.
local function ReadSpellData()
  local manifest = addonTable.DefensiveManifest
  local list = type(manifest) == "table" and manifest.list or nil
  local auraIds, castIds, auraSet = {}, {}, {}
  for _, record in ipairs(type(list) == "table" and list or {}) do
    if type(record) == "table" and record.probe == true and type(record.aura) == "number" then
      auraIds[#auraIds + 1] = record.aura
      auraSet[record.aura] = true
      castIds[#castIds + 1] = type(record.cast) == "number" and record.cast or record.aura
    end
  end
  local forbearance = type(manifest) == "table" and manifest.forbearance or nil
  return auraIds, castIds, auraSet, type(forbearance) == "number" and forbearance or nil
end

-- Localized frame text; English fallback while the UI layer is missing.
local function Text(key, fallback)
  local uiCommon = addonTable.UICommon
  local getText = type(uiCommon) == "table" and uiCommon.GetLocalizedText or nil
  if type(getText) == "function" then
    local ok, value = pcall(getText, key, fallback)
    if ok and type(value) == "string" and value ~= "" then
      return value
    end
  end
  return fallback
end

-- A short, space-free error text for the log ("none" without error).
local function ErrorText(err)
  if err == nil then
    return "none"
  end
  if IsSecretValue(err) then
    return "secret"
  end
  -- Drop the "<file>:<line>: " location; the message is what tells the cause.
  local message = tostring(err):gsub("^[^:]*:%d+:%s*", "")
  local text = message:gsub("%s+", "_"):gsub("[^%w_%.:%-']", "")
  if text == "" then
    return "unknown"
  end
  return text:sub(1, 80)
end

-- Calls object:methodName(...) under pcall. Returns the status
-- ("ok" / "api_missing" / "error"), the first result and the error.
local function CallMethod(object, methodName, ...)
  if type(object) ~= "table" then
    return "api_missing", nil, nil
  end
  local okLookup, method = pcall(function()
    return object[methodName]
  end)
  if not okLookup or type(method) ~= "function" then
    return "api_missing", nil, nil
  end
  local ok, result = pcall(method, object, ...)
  if not ok then
    return "error", nil, result
  end
  return "ok", result, nil
end

local function IsReadablyInRaid()
  local party = addonTable.ProbeParty
  local check = type(party) == "table" and party.IsReadablyInRaid or nil
  return type(check) == "function" and check() == true
end

-- outside (no key), pull (key, in combat), between (key, out of combat) or
-- unknown (key, combat state not readable).
local function ReadPhase()
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

local function IsReadablyOutOfCombat()
  return ReadInCombat() == "no"
end

local function TallyFor(phase)
  local entry = tally[phase]
  if not entry then
    entry = {}
    for _, field in ipairs(TALLY_FIELDS) do
      entry[field] = 0
    end
    tally[phase] = entry
  end
  return entry
end

local function FlushTally(moment)
  for _, phase in ipairs(TALLY_PHASES) do
    local entry = tally[phase]
    if entry and entry.reads > 0 then
      tally[phase] = nil
      if TakeBudget("acTallyLines", LIMITS.tallyLinesPerRun, "ac_tally") then
        local parts = {}
        for _, field in ipairs(TALLY_FIELDS) do
          parts[#parts + 1] = string.format("%s=%d", field, entry[field])
        end
        Append(
          string.format(
            "[PROBE] event=ac_tally at=%s phase=%s inKey=%s %s",
            moment,
            phase,
            YesNo(phase ~= "outside"),
            table.concat(parts, " ")
          )
        )
      end
    end
  end
end

-- AuraUtil.IsValidFilterString(filter): valid / invalid / secret / error / api_missing.
local function CheckFilter(filter)
  local auraUtil = rawget(_G, "AuraUtil")
  local check = type(auraUtil) == "table" and rawget(auraUtil, "IsValidFilterString") or nil
  if type(check) ~= "function" then
    return "api_missing"
  end
  local ok, valid = pcall(check, filter)
  if not ok then
    return "error"
  end
  if IsSecretValue(valid) then
    return "secret"
  end
  return valid == true and "valid" or "invalid"
end

-- C_XMLUtil.GetTemplateInfo(name): yes / no / secret / error / api_missing.
local function CheckTemplate()
  local xmlUtil = rawget(_G, "C_XMLUtil")
  local getInfo = type(xmlUtil) == "table" and rawget(xmlUtil, "GetTemplateInfo") or nil
  if type(getInfo) ~= "function" then
    return "api_missing"
  end
  local ok, info = pcall(getInfo, CONTAINER_TEMPLATE)
  if not ok then
    return "error"
  end
  if IsSecretValue(info) then
    return "secret"
  end
  return info ~= nil and "yes" or "no"
end

-- GetCursorPosition: in / out (of the screen) / readable (no screen size) /
-- secret / error / api_missing.
local function ReadCursor()
  local getCursor = rawget(_G, "GetCursorPosition")
  if type(getCursor) ~= "function" then
    return "api_missing"
  end
  local ok, x, y = pcall(getCursor)
  if not ok then
    return "error"
  end
  if IsSecretValue(x) or IsSecretValue(y) then
    return "secret"
  end
  if type(x) ~= "number" or type(y) ~= "number" then
    return "error"
  end
  local uiParent = rawget(_G, "UIParent")
  local scaleStatus, scale = CallMethod(uiParent, "GetEffectiveScale")
  local widthStatus, width = CallMethod(uiParent, "GetWidth")
  local heightStatus, height = CallMethod(uiParent, "GetHeight")
  if scaleStatus ~= "ok" or widthStatus ~= "ok" or heightStatus ~= "ok" then
    return "readable"
  end
  if IsSecretValue(scale) or IsSecretValue(width) or IsSecretValue(height) then
    return "readable"
  end
  if type(scale) ~= "number" or type(width) ~= "number" or type(height) ~= "number" or scale <= 0 then
    return "readable"
  end
  local uiX, uiY = x / scale, y / scale
  if uiX >= 0 and uiY >= 0 and uiX <= width and uiY <= height then
    return "in"
  end
  return "out"
end

local function NewFrame(frameType, parent, template)
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return nil, "api_missing", nil
  end
  local ok, frame = pcall(createFrame, frameType, nil, parent, template)
  if not ok then
    return nil, "error", frame
  end
  if type(frame) ~= "table" then
    return nil, "error", nil
  end
  return frame, "ok", nil
end

-- initializeFrame callbacks run once per aura frame the container creates.
local function InitVisibleButton(button)
  CallMethod(button, "SetSize", GEOMETRY.icon, GEOMETRY.icon)
  local textureStatus, texture = CallMethod(button, "CreateTexture", nil, "ARTWORK")
  if textureStatus == "ok" and type(texture) == "table" then
    CallMethod(texture, "SetAllPoints", button)
    CallMethod(button, "SetIcon", texture)
  end
end

local function InitSensorButton(button)
  CallMethod(button, "SetSize", 1, 1)
  CallMethod(button, "EnableMouse", false)
end

-- One configured container: create, place, add the group, set the unit,
-- enable. place(container) sizes and anchors it before AddAuraGroup, which
-- forbids untrusted layout scripts on the container from then on. Returns
-- the container (or nil) and the status of the first failing step.
local function BuildContainer(parent, unit, filter, groupOptions, place)
  local container, status, err = NewFrame("AuraContainer", parent, CONTAINER_TEMPLATE)
  if not container then
    return nil, "create_" .. status, err
  end
  place(container)
  local groupStatus, _, groupErr = CallMethod(container, "AddAuraGroup", "isiLiveProbe", filter, groupOptions)
  if groupStatus ~= "ok" then
    return container, "group_" .. groupStatus, groupErr
  end
  local unitStatus, _, unitErr = CallMethod(container, "SetUnit", unit)
  if unitStatus ~= "ok" then
    return container, "unit_" .. unitStatus, unitErr
  end
  local enableStatus, _, enableErr = CallMethod(container, "SetEnabled", true)
  if enableStatus ~= "ok" then
    return container, "enable_" .. enableStatus, enableErr
  end
  return container, "ok", nil
end

local function NewFontString(parent, template)
  local status, fontString = CallMethod(parent, "CreateFontString", nil, "OVERLAY", template)
  return status == "ok" and type(fontString) == "table" and fontString or nil
end

local function SetFontText(fontString, text)
  if fontString then
    CallMethod(fontString, "SetText", text)
  end
end

-- The visible probe frame (P1): title, column headers, four rows.
local function BuildRoot()
  local uiParent = rawget(_G, "UIParent")
  local root = NewFrame("Frame", uiParent)
  if not root then
    return nil
  end
  local width = GEOMETRY.nameWidth + #COLUMNS * GEOMETRY.columnWidth + GEOMETRY.barWidth + 16
  local height = GEOMETRY.headerHeight + #PARTY_UNITS * GEOMETRY.rowHeight + 6
  CallMethod(root, "SetSize", width, height)
  CallMethod(root, "SetPoint", "CENTER", uiParent, "CENTER", 0, 220)
  CallMethod(root, "SetFrameStrata", "HIGH")
  CallMethod(root, "SetClampedToScreen", true)
  CallMethod(root, "SetMovable", true)
  CallMethod(root, "EnableMouse", true)
  CallMethod(root, "RegisterForDrag", "LeftButton")
  CallMethod(root, "SetScript", "OnDragStart", function(self)
    CallMethod(self, "StartMoving")
  end)
  CallMethod(root, "SetScript", "OnDragStop", function(self)
    CallMethod(self, "StopMovingOrSizing")
  end)
  local bgStatus, background = CallMethod(root, "CreateTexture", nil, "BACKGROUND")
  if bgStatus == "ok" and type(background) == "table" then
    CallMethod(background, "SetAllPoints", root)
    CallMethod(background, "SetColorTexture", 0, 0, 0, 0.7)
  end
  local title = NewFontString(root, "GameFontNormalSmall")
  if title then
    CallMethod(title, "SetPoint", "TOPLEFT", root, "TOPLEFT", 6, -4)
    SetFontText(title, Text("PROBE_AC_TITLE", "isiLive Probe"))
  end
  local hint = NewFontString(root, "GameFontDisableSmall")
  if hint then
    CallMethod(hint, "SetPoint", "TOPRIGHT", root, "TOPRIGHT", -6, -4)
    SetFontText(hint, Text("PROBE_AC_HINT", "drag to move"))
  end
  for index, column in ipairs(COLUMNS) do
    local header = NewFontString(root, "GameFontHighlightSmall")
    if header then
      local x = GEOMETRY.nameWidth + (index - 1) * GEOMETRY.columnWidth
      CallMethod(header, "SetPoint", "TOPLEFT", root, "TOPLEFT", x, -18)
      SetFontText(header, Text(column.label, column.fallback))
    end
  end
  local sensorHeader = NewFontString(root, "GameFontHighlightSmall")
  if sensorHeader then
    CallMethod(
      sensorHeader,
      "SetPoint",
      "TOPLEFT",
      root,
      "TOPLEFT",
      GEOMETRY.nameWidth + #COLUMNS * GEOMETRY.columnWidth,
      -18
    )
    SetFontText(sensorHeader, Text("PROBE_AC_COL_SENSOR", "Sensor"))
  end
  return root
end

-- The sensor bar of one row: driven only by StatusBar:SetValue(<maybe secret>).
local function BuildBar(root, rowY)
  local bar = NewFrame("StatusBar", root)
  if not bar then
    return nil
  end
  CallMethod(bar, "SetSize", GEOMETRY.barWidth, GEOMETRY.barHeight)
  CallMethod(
    bar,
    "SetPoint",
    "TOPLEFT",
    root,
    "TOPLEFT",
    GEOMETRY.nameWidth + #COLUMNS * GEOMETRY.columnWidth,
    rowY - 4
  )
  CallMethod(bar, "SetStatusBarTexture", "Interface\\Buttons\\WHITE8X8")
  CallMethod(bar, "SetStatusBarColor", 0.3, 0.8, 1, 1)
  CallMethod(bar, "SetMinMaxValues", 0, 1)
  CallMethod(bar, "SetValue", 0)
  local bgStatus, background = CallMethod(bar, "CreateTexture", nil, "BACKGROUND")
  if bgStatus == "ok" and type(background) == "table" then
    CallMethod(background, "SetAllPoints", bar)
    CallMethod(background, "SetColorTexture", 0.2, 0.2, 0.2, 0.8)
  end
  return bar
end

local function VisibleGroupOptions(column, auraSet)
  local options = {
    maxFrameCount = GEOMETRY.iconsPerColumn,
    initializeFrame = InitVisibleButton,
    layout = { elementWidth = GEOMETRY.icon + 1, elementHeight = GEOMETRY.icon },
  }
  if column.useIdList then
    options.candidateFilters = { includeSpellIDs = auraSet }
  end
  return options
end

local function SensorGroupOptions(auraSet)
  return {
    maxFrameCount = 1,
    candidateFilters = { includeSpellIDs = auraSet },
    initializeFrame = InitSensorButton,
    layout = { elementWidth = GEOMETRY.sensorStride, elementHeight = 1 },
  }
end

-- The plain name of a party unit, or "-" (missing, secret or unreadable).
local function ReadUnitName(unit)
  local unitName = rawget(_G, "UnitName")
  if type(unitName) ~= "function" then
    return "-"
  end
  local ok, name = pcall(unitName, unit)
  if not ok or IsSecretValue(name) or type(name) ~= "string" or name == "" then
    return "-"
  end
  return name
end

local function RefreshNames()
  if not frames then
    return
  end
  for index, unit in ipairs(PARTY_UNITS) do
    local row = frames.rows[index]
    if row and row.name then
      SetFontText(row.name, string.format("%s %s", unit, ReadUnitName(unit)))
    end
  end
end

local function TakeSetupLine()
  return TakeBudget("acSetupLines", LIMITS.setupLinesPerRun, "ac_setup")
end

local function BuildFrames(moment)
  local auraIds, _, auraSet = ReadSpellData()
  local filterState = {}
  for _, column in ipairs(COLUMNS) do
    filterState[column.key] = column.filter == FILTER_HELPFUL and "valid" or CheckFilter(column.filter)
  end
  local template = CheckTemplate()
  if TakeSetupLine() then
    local idTexts = {}
    for _, id in ipairs(auraIds) do
      idTexts[#idTexts + 1] = string.format("%d", id)
    end
    Append(
      string.format(
        "[PROBE] event=ac_config at=%s inKey=%s template=%s auraIDs=%d extFilter=%s bigFilter=%s stride=%d "
          .. "offsetX=%d reach=%d tick=%.1f cursor=%s idList=%s",
        moment,
        YesNo(IsKeyActive()),
        template,
        #auraIds,
        filterState.ext,
        filterState.big,
        GEOMETRY.sensorStride,
        GEOMETRY.sensorOffsetX,
        GEOMETRY.mouseOverReach,
        LIMITS.tickSeconds,
        ReadCursor(),
        #idTexts > 0 and table.concat(idTexts, ",") or "none"
      )
    )
  end
  local root = BuildRoot()
  if not root then
    if TakeSetupLine() then
      Append(string.format("[PROBE] event=ac_setup unit=frame status=create_error at=%s", moment))
    end
    return nil
  end
  local built = { root = root, rows = {}, sensors = {}, containers = {} }
  local uiParent = rawget(_G, "UIParent")
  for index, unit in ipairs(PARTY_UNITS) do
    local rowY = -(GEOMETRY.headerHeight + (index - 1) * GEOMETRY.rowHeight)
    local row = { name = NewFontString(root, "GameFontHighlightSmall"), columns = {} }
    if row.name then
      CallMethod(row.name, "SetPoint", "TOPLEFT", root, "TOPLEFT", 6, rowY - 4)
    end
    local statuses, firstErr = {}, nil
    for columnIndex, column in ipairs(COLUMNS) do
      local state = filterState[column.key]
      if state == "invalid" or state == "secret" or state == "error" then
        statuses[column.key] = "skipped_filter_" .. state
      else
        local x = GEOMETRY.nameWidth + (columnIndex - 1) * GEOMETRY.columnWidth
        local container, status, err = BuildContainer(
          root,
          unit,
          column.filter,
          VisibleGroupOptions(column, auraSet),
          function(new)
            CallMethod(new, "SetPoint", "TOPLEFT", root, "TOPLEFT", x, rowY)
          end
        )
        if container then
          built.containers[#built.containers + 1] = container
          row.columns[column.key] = container
        end
        statuses[column.key] = status
        firstErr = firstErr or err
      end
    end
    local sensor, sensorStatus, sensorErr = BuildContainer(
      uiParent,
      unit,
      FILTER_HELPFUL,
      SensorGroupOptions(auraSet),
      function(new)
        CallMethod(new, "SetSize", 1, 1)
        CallMethod(new, "SetPoint", "TOPLEFT", uiParent, "TOPLEFT", GEOMETRY.sensorOffsetX, 0)
        CallMethod(new, "SetAlpha", 0)
        CallMethod(new, "EnableMouse", false)
      end
    )
    if sensor then
      built.sensors[index] = sensor
      built.containers[#built.containers + 1] = sensor
    end
    firstErr = firstErr or sensorErr
    row.bar = BuildBar(root, rowY)
    built.rows[index] = row
    if TakeSetupLine() then
      Append(
        string.format(
          "[PROBE] event=ac_setup unit=%s ids=%s ext=%s big=%s sensor=%s bar=%s error=%s",
          unit,
          statuses.ids,
          statuses.ext,
          statuses.big,
          sensorStatus,
          row.bar and "ok" or "create_error",
          ErrorText(firstErr)
        )
      )
    end
  end
  -- P3 test container: same ID filter as the sensors, alpha 0 inside the frame.
  local ops, opsStatus, opsErr = BuildContainer(
    root,
    PARTY_UNITS[1],
    FILTER_HELPFUL,
    SensorGroupOptions(auraSet),
    function(new)
      CallMethod(new, "SetSize", 1, 1)
      CallMethod(new, "SetPoint", "BOTTOMRIGHT", root, "BOTTOMRIGHT", -2, 2)
      CallMethod(new, "SetAlpha", 0)
    end
  )
  if ops then
    built.ops = ops
    built.containers[#built.containers + 1] = ops
  end
  if TakeSetupLine() then
    Append(string.format("[PROBE] event=ac_setup unit=ops status=%s error=%s", opsStatus, ErrorText(opsErr)))
  end
  CallMethod(root, "Show")
  return built
end

local function SetContainersEnabled(enabled)
  if not frames then
    return
  end
  for _, container in ipairs(frames.containers) do
    CallMethod(container, "SetEnabled", enabled)
  end
end

local function StopTicker()
  tickGeneration = tickGeneration + 1
  ticking = false
end

-- Hides the frame and disables every container (probe off, raid). Out of
-- combat only; in combat it retries every suspendRetrySeconds.
local function Suspend(reason)
  if not frames or suspended then
    return
  end
  StopTicker()
  if not IsReadablyOutOfCombat() then
    if not suspendRetryPending then
      suspendRetryPending = true
      TimerAfter(LIMITS.suspendRetrySeconds, function()
        suspendRetryPending = false
        if not ProbeAuraContainer.IsEnabled() or IsReadablyInRaid() then
          Suspend(reason)
        end
      end)
    end
    return
  end
  suspended = true
  CallMethod(frames.root, "Hide")
  SetContainersEnabled(false)
  if TakeSetupLine() then
    Append(string.format("[PROBE] event=ac_suspended reason=%s", reason))
  end
end

-- Builds the frames on first use or wakes them up again. Never in combat,
-- never in a raid, never with probe mode off.
local function EnsureFrames(moment)
  if not ProbeAuraContainer.IsEnabled() then
    return false
  end
  if IsReadablyInRaid() then
    Suspend("raid")
    return false
  end
  if not IsReadablyOutOfCombat() then
    if not frames and TakeSetupLine() then
      Append(string.format("[PROBE] event=ac_setup unit=frame status=deferred_in_combat at=%s", moment))
    end
    return frames ~= nil and not suspended
  end
  if not frames then
    frames = BuildFrames(moment)
    suspended = false
  elseif suspended then
    suspended = false
    CallMethod(frames.root, "Show")
    SetContainersEnabled(true)
    if TakeSetupLine() then
      Append(string.format("[PROBE] event=ac_resumed at=%s", moment))
    end
  end
  RefreshNames()
  return frames ~= nil
end

local function TakeSensorLine(phase)
  if segmentLines >= LIMITS.sensorLinesPerSegment then
    return false
  end
  if not TakeBudget("acSensor" .. PHASE_SUFFIX[phase], LIMITS.sensorLinesPerPhase, "ac_sensor_" .. phase) then
    return false
  end
  segmentLines = segmentLines + 1
  return true
end

-- P2: one sensor read for party<index>.
local function ReadSensor(index, trigger)
  if not frames or suspended then
    return
  end
  local sensor = frames.sensors[index]
  if not sensor then
    return
  end
  local unit = PARTY_UNITS[index]
  local phase, inKey, inCombat = ReadPhase()
  local entry = TallyFor(phase)
  entry.reads = entry.reads + 1

  local reach = GEOMETRY.mouseOverReach
  local overStatus, over = CallMethod(sensor, "IsMouseOver", reach, -reach, 0, 0)
  local overText
  local overUsable = false
  if overStatus ~= "ok" then
    entry.overError = entry.overError + 1
    overText = overStatus
  elseif IsSecretValue(over) then
    entry.overSecret = entry.overSecret + 1
    overText, overUsable = "secret", true
  elseif over == true then
    entry.overTrue = entry.overTrue + 1
    overText, overUsable = "true", true
  elseif over == false then
    entry.overFalse = entry.overFalse + 1
    overText, overUsable = "false", true
  else
    entry.overOther = entry.overOther + 1
    overText = "not_a_boolean"
  end

  local curveText, curveSecretText, value = "skipped", "n/a", nil
  if overUsable then
    local curveUtil = rawget(_G, "C_CurveUtil")
    local evaluate = type(curveUtil) == "table" and rawget(curveUtil, "EvaluateColorValueFromBoolean") or nil
    if type(evaluate) ~= "function" then
      curveText = "api_missing"
      entry.curveError = entry.curveError + 1
    else
      local ok, result = pcall(evaluate, over, 1, 0)
      if ok then
        entry.curveOk = entry.curveOk + 1
        curveText, value = "ok", result
        local resultSecret = IsSecretValue(result)
        if resultSecret then
          entry.curveSecret = entry.curveSecret + 1
        end
        curveSecretText = YesNo(resultSecret)
      else
        entry.curveError = entry.curveError + 1
        curveText = "error"
      end
    end
  end

  local barText = "skipped"
  local row = frames.rows[index]
  if curveText == "ok" and row and row.bar then
    barText = CallMethod(row.bar, "SetValue", value)
    if barText == "ok" then
      entry.barOk = entry.barOk + 1
    else
      entry.barError = entry.barError + 1
    end
  end

  local widthStatus, width = CallMethod(sensor, "GetWidth")
  local widthText = widthStatus
  if widthStatus == "ok" then
    if IsSecretValue(width) then
      widthText = "secret"
    elseif type(width) == "number" then
      widthText = string.format("%.0f", width)
    else
      widthText = "nil"
    end
  end

  local cursor = ReadCursor()
  if cursor == "in" then
    entry.cursorIn = entry.cursorIn + 1
  elseif cursor == "out" then
    entry.cursorOut = entry.cursorOut + 1
  elseif cursor == "readable" then
    entry.cursorReadable = entry.cursorReadable + 1
  elseif cursor == "secret" then
    entry.cursorSecret = entry.cursorSecret + 1
  else
    entry.cursorUnknown = entry.cursorUnknown + 1
  end

  -- A line for the first read of a unit per segment and for every change of
  -- a readable answer; secret answers cannot be compared.
  local readable = (overText == "true" or overText == "false") and overText or nil
  local changed = readable ~= nil and lastReadable[unit] ~= nil and lastReadable[unit] ~= readable
  if readable ~= nil then
    lastReadable[unit] = readable
  end
  local first = seenSegment[unit] ~= segment
  seenSegment[unit] = segment
  if not first and not changed then
    return
  end
  if not TakeSensorLine(phase) then
    return
  end
  Append(
    string.format(
      "[PROBE] event=ac_sensor unit=%s trigger=%s phase=%s inKey=%s inCombat=%s over=%s curve=%s curveSecret=%s "
        .. "bar=%s width=%s cursor=%s change=%s",
      unit,
      trigger,
      phase,
      YesNo(inKey),
      inCombat,
      overText,
      curveText,
      curveSecretText,
      barText,
      widthText,
      cursor,
      YesNo(changed)
    )
  )
end

local function ReadAllSensors(trigger)
  for index = 1, #PARTY_UNITS do
    ReadSensor(index, trigger)
  end
end

local function Tick(generation)
  if generation ~= tickGeneration or not ProbeAuraContainer.IsEnabled() then
    return
  end
  if not frames or suspended or ReadInCombat() ~= "yes" or IsReadablyInRaid() then
    ticking = false
    return
  end
  if not TakeBudget("acTicks", LIMITS.ticksPerRun, "ac_tick") then
    ticking = false
    return
  end
  ReadAllSensors("tick")
  TimerAfter(LIMITS.tickSeconds, function()
    Tick(generation)
  end)
end

local function StartTicker()
  if ticking or not frames or suspended then
    return
  end
  tickGeneration = tickGeneration + 1
  ticking = true
  local generation = tickGeneration
  if not TimerAfter(LIMITS.tickSeconds, function()
    Tick(generation)
  end) then
    ticking = false
  end
end

-- yes / no / secret / error / api_missing for a C_Secrets predicate.
local function DescribePredicate(fn, ...)
  if type(fn) ~= "function" then
    return "api_missing"
  end
  local ok, value = pcall(fn, ...)
  if not ok then
    return "error"
  end
  if IsSecretValue(value) then
    return "secret"
  end
  if value == true then
    return "yes"
  end
  return value == false and "no" or "nil"
end

-- Enum.SecrecyLevel name of a secrecy answer (looked up at run time).
local function DescribeSecrecy(fn, spellID)
  if type(fn) ~= "function" then
    return "api_missing"
  end
  local ok, value = pcall(fn, spellID)
  if not ok then
    return "error"
  end
  if IsSecretValue(value) then
    return "secret"
  end
  if type(value) ~= "number" then
    return value == nil and "nil" or "other"
  end
  local enum = rawget(_G, "Enum")
  local levels = type(enum) == "table" and rawget(enum, "SecrecyLevel") or nil
  if type(levels) == "table" then
    for name, level in pairs(levels) do
      if not IsSecretValue(level) and level == value and type(name) == "string" then
        return name
      end
    end
  end
  return string.format("level%d", value)
end

local function AppendSecrecyLines(kind, inKey, values)
  local parts = math.max(1, math.ceil(#values / LIMITS.secrecyIdsPerLine))
  for part = 1, parts do
    if not TakeBudget("acSecretsLines", LIMITS.secretsLinesPerRun, "ac_secrets") then
      return
    end
    local first = (part - 1) * LIMITS.secrecyIdsPerLine + 1
    local chunk = {}
    for index = first, math.min(#values, first + LIMITS.secrecyIdsPerLine - 1) do
      chunk[#chunk + 1] = values[index]
    end
    Append(
      string.format(
        "[PROBE] event=ac_secrecy kind=%s inKey=%s part=%d/%d values=%s",
        kind,
        YesNo(inKey),
        part,
        parts,
        #chunk > 0 and table.concat(chunk, ",") or "none"
      )
    )
  end
end

-- P4: C_Secrets answers, once outside a key and once inside per run.
local function RunSecrets(moment)
  local inKey = IsKeyActive()
  local class = inKey and "key" or "outside"
  if runFlags.secrets[class] then
    return
  end
  runFlags.secrets[class] = true
  if not TakeBudget("acSecretsLines", LIMITS.secretsLinesPerRun, "ac_secrets") then
    return
  end
  local secrets = rawget(_G, "C_Secrets")
  if type(secrets) ~= "table" then
    Append(string.format("[PROBE] event=ac_secrets at=%s inKey=%s api=missing", moment, YesNo(inKey)))
    return
  end
  Append(
    string.format(
      "[PROBE] event=ac_secrets at=%s inKey=%s inCombat=%s aurasSecret=%s cooldownsSecret=%s hasRestrictions=%s",
      moment,
      YesNo(inKey),
      ReadInCombat(),
      DescribePredicate(rawget(secrets, "ShouldAurasBeSecret")),
      DescribePredicate(rawget(secrets, "ShouldCooldownsBeSecret")),
      DescribePredicate(rawget(secrets, "HasSecretRestrictions"))
    )
  )
  local auraIds, castIds, _, forbearance = ReadSpellData()
  local auraSecrecy = rawget(secrets, "GetSpellAuraSecrecy")
  local auraValues = {}
  for _, id in ipairs(auraIds) do
    auraValues[#auraValues + 1] = string.format("%d:%s", id, DescribeSecrecy(auraSecrecy, id))
  end
  if forbearance then
    auraValues[#auraValues + 1] = string.format("%d:%s", forbearance, DescribeSecrecy(auraSecrecy, forbearance))
  end
  AppendSecrecyLines("aura", inKey, auraValues)
  local cooldownSecrecy = rawget(secrets, "GetSpellCooldownSecrecy")
  local cooldownSecret = rawget(secrets, "ShouldSpellCooldownBeSecret")
  local cooldownValues = {}
  for _, id in ipairs(castIds) do
    cooldownValues[#cooldownValues + 1] =
      string.format("%d:%s/%s", id, DescribeSecrecy(cooldownSecrecy, id), DescribePredicate(cooldownSecret, id))
  end
  AppendSecrecyLines("cooldown", inKey, cooldownValues)
end

-- P3: container calls in combat lockdown, once per run. ADDON_ACTION_BLOCKED
-- lines between the begin and end markers belong to these calls.
local function RunCombatOps()
  if not ProbeAuraContainer.IsEnabled() or not frames or suspended or not frames.ops then
    return
  end
  if ReadInCombat() ~= "yes" then
    -- The pull ended within the delay: try again at the next one.
    runFlags.combatOps = false
    return
  end
  if not TakeBudget("acCombatOps", LIMITS.combatOpsPerRun, "ac_combat_ops") then
    return
  end
  local ops = frames.ops
  Append(string.format("[PROBE] event=ac_combat_ops stage=begin inKey=%s inCombat=yes", YesNo(IsKeyActive())))
  local results, firstErr = {}, nil
  local function Run(label, methodName, ...)
    local status, _, err = CallMethod(ops, methodName, ...)
    results[label] = status
    firstErr = firstErr or err
  end
  Run("setUnit", "SetUnit", PARTY_UNITS[1])
  Run("setEnabledOff", "SetEnabled", false)
  Run("setEnabledOn", "SetEnabled", true)
  Run("hide", "Hide")
  Run("show", "Show")
  local shownStatus, shown = CallMethod(ops, "IsShown")
  local shownText = shownStatus
  if shownStatus == "ok" then
    if IsSecretValue(shown) then
      shownText = "secret"
    else
      shownText = YesNo(shown == true)
    end
  end
  Append(
    string.format(
      "[PROBE] event=ac_combat_ops stage=end setUnit=%s setEnabledOff=%s setEnabledOn=%s hide=%s show=%s "
        .. "shownAfter=%s error=%s",
      results.setUnit,
      results.setEnabledOff,
      results.setEnabledOn,
      results.hide,
      results.show,
      shownText,
      ErrorText(firstErr)
    )
  )
end

local function ScheduleCombatOps()
  if runFlags.combatOps or not frames or suspended then
    return
  end
  runFlags.combatOps = true
  if not TimerAfter(LIMITS.combatOpsDelaySeconds, RunCombatOps) then
    RunCombatOps()
  end
end

--- Segment boundary from ProbeLog (combat edges, key start, key end): the
-- tallies go out, the per-segment line count starts over, and the moment
-- drives the ticker, the combat calls and the secrets check.
function ProbeAuraContainer.NextSegment(moment)
  if not ProbeAuraContainer.IsEnabled() then
    return
  end
  FlushTally(moment)
  segment = segment + 1
  segmentLines = 0
  if moment == "key_start" then
    -- ProbeLog resets the run budgets right after this call.
    runFlags = { secrets = {}, combatOps = false }
    return
  end
  if moment == "combat_start" then
    if frames and not suspended and not IsReadablyInRaid() then
      StartTicker()
      ScheduleCombatOps()
    end
    RunSecrets(moment)
    return
  end
  StopTicker()
  -- combat_end, key_completed, key_reset: out of combat again.
  EnsureFrames(moment)
  RunSecrets(moment)
end

--- Writes the open tallies (before the report); nothing with probe mode off.
function ProbeAuraContainer.FlushTally(moment)
  if ProbeAuraContainer.IsEnabled() then
    FlushTally(moment)
  end
end

--- /isilive probe on (slash command or settings): build or wake the frames.
function ProbeAuraContainer.OnProbeEnabled(moment)
  if not ProbeAuraContainer.IsEnabled() then
    return
  end
  EnsureFrames(moment)
  RunSecrets(moment)
  if frames and not suspended and ReadInCombat() == "yes" then
    StartTicker()
  end
end

--- /isilive probe off: hide the frame and disable the containers.
function ProbeAuraContainer.OnProbeDisabled()
  StopTicker()
  pendingAura = {}
  Suspend("probe_off")
end

--- PLAYER_ENTERING_WORLD / ZONE_CHANGED_NEW_AREA (ProbeLog, raid excluded by
-- the caller): build the frames if still missing, refresh the names.
function ProbeAuraContainer.OnZoneChanged(moment)
  if not ProbeAuraContainer.IsEnabled() then
    return
  end
  EnsureFrames(moment)
end

--- GROUP_ROSTER_UPDATE (dispatcher, once per raid transition and on every
-- party roster change): the raid switches the probe frames off (rule 11),
-- the way back wakes them up; the row names follow the roster.
function ProbeAuraContainer.OnRosterUpdate(inRaid)
  if not ProbeAuraContainer.IsEnabled() then
    return
  end
  if inRaid == true then
    Suspend("raid")
    return
  end
  EnsureFrames("roster")
end

--- UNIT_AURA of a party unit (existing dispatcher path, raid excluded by the
-- caller): only a trigger. The container lays out on its next update, so the
-- sensor of that unit is read auraTriggerDelaySeconds later, at most one
-- pending read per unit.
function ProbeAuraContainer.OnPartyAura(unit)
  if not ProbeAuraContainer.IsEnabled() then
    return
  end
  if IsSecretValue(unit) or type(unit) ~= "string" then
    return
  end
  local index = UNIT_INDEX[unit]
  if not index then
    return
  end
  if not frames and not EnsureFrames("unit_aura") then
    return
  end
  if suspended or pendingAura[index] then
    return
  end
  pendingAura[index] = true
  local function ReadLater()
    pendingAura[index] = nil
    if ProbeAuraContainer.IsEnabled() and not IsReadablyInRaid() then
      ReadSensor(index, "unit_aura")
    end
  end
  if not TimerAfter(LIMITS.auraTriggerDelaySeconds, ReadLater) then
    ReadLater()
  end
end

-- Test surface: the built frames (nil before the first build).
function ProbeAuraContainer._GetFrames()
  return frames
end
