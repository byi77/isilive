local _, addonTable = ...

addonTable = addonTable or {}

-- Late run capture (rule 118, RULE-KEYENDE-RUN-IDENTITAET). All state lives on
-- the event-handler context: pendingLateRunCapture (the open window),
-- lateRunCaptureArmedSignature (one window per run) and pendingLateRunKicks
-- (the kicks-only read of a run captured while its Interrupts list was not
-- fully readable). The callers -- the
-- challenge and runtime lifecycles -- apply the raid gate.
local LateRunCapture = {}
addonTable.LateRunCapture = LateRunCapture
local IsSecretValue = addonTable.Validators.IsSecretValue

-- The damage meter answers in Secret Values for a few seconds after
-- CHALLENGE_MODE_COMPLETED -- longer than the five 1 s retries of the
-- challenge lifecycle -- and is readable again once the addon restrictions
-- lift (seen outside the instance). A run whose capture failed stays pending
-- for this long and is retried on the restriction-lifted and
-- outside-the-instance triggers only, never on a timer.
local LATE_RUN_CAPTURE_WINDOW_SECONDS = 600
local LATE_RUN_CAPTURE_MAX_ATTEMPTS = 20

local function ReadNow(ctx)
  local getTime = type(ctx.getTime) == "function" and ctx.getTime or nil
  if not getTime then
    return nil
  end
  local ok, now = pcall(getTime)
  if not ok or IsSecretValue(now) or type(now) ~= "number" then
    return nil
  end
  return now
end

-- label: "late_capture" (the whole run) or "late_kicks" (landed kicks only).
local function LogLateWindow(ctx, label, eventName, pending, extra)
  if type(ctx.logRuntimeTracef) ~= "function" then
    return
  end
  local runInfo = type(pending) == "table" and pending.runInfo or nil
  ctx.logRuntimeTracef(
    "[STATS] %s state=%s mapID=%s level=%s attempts=%s %s",
    label,
    tostring(eventName),
    tostring(runInfo and runInfo.mapID),
    tostring(runInfo and runInfo.level),
    tostring(type(pending) == "table" and pending.attempts or 0),
    tostring(extra or "")
  )
end

local function LogLateRunCapture(ctx, eventName, pending, extra)
  LogLateWindow(ctx, "late_capture", eventName, pending, extra)
end

local function LogLateKicks(ctx, eventName, pending, extra)
  LogLateWindow(ctx, "late_kicks", eventName, pending, extra)
end

-- Names only: the late capture matches the meter against the group of the
-- run, so a member who leaves or joins afterwards does not change who belongs
-- to it.
local function CloneRosterForLateCapture(roster)
  local out = {}
  local any = false
  for unit, info in pairs(type(roster) == "table" and roster or {}) do
    if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
      out[unit] = { name = info.name, realm = info.realm }
      any = true
    end
  end
  return any and out or nil
end

-- true / false when the client answers readably, nil otherwise.
local function ReadIsInInstance()
  local isInInstance = rawget(_G, "IsInInstance")
  if type(isInInstance) ~= "function" then
    return nil
  end
  local ok, inInstance = pcall(isInInstance)
  if not ok or IsSecretValue(inInstance) then
    return nil
  end
  if inInstance == true or inInstance == 1 then
    return true
  end
  if inInstance == false or inInstance == nil or inInstance == 0 then
    return false
  end
  return nil
end

--- Drops a pending late run capture.
-- @param ctx table Event-handler context.
-- @param reason string Trace label (key_start, combat, expired, attempts, captured).
-- @return boolean true when a pending capture was dropped.
function LateRunCapture.Cancel(ctx, reason)
  local pending = ctx.pendingLateRunCapture
  if type(pending) ~= "table" then
    return false
  end
  ctx.pendingLateRunCapture = nil
  LogLateRunCapture(ctx, "cancel", pending, "reason=" .. tostring(reason))
  return true
end

--- Drops a pending kicks-only read (late kicks).
-- @param ctx table Event-handler context.
-- @param reason string Trace label (key_start, combat, expired, attempts, closed, superseded).
-- @return boolean true when a pending read was dropped.
function LateRunCapture.CancelKicks(ctx, reason)
  local pending = ctx.pendingLateRunKicks
  if type(pending) ~= "table" then
    return false
  end
  ctx.pendingLateRunKicks = nil
  LogLateKicks(ctx, "cancel", pending, "reason=" .. tostring(reason))
  return true
end

--- Drops both late windows: a new key resets the damage meter and new combat
-- extends the Overall session past the run, for DPS and kicks alike.
-- @return boolean true when anything was dropped.
function LateRunCapture.CancelAll(ctx, reason)
  local droppedRun = LateRunCapture.Cancel(ctx, reason)
  local droppedKicks = LateRunCapture.CancelKicks(ctx, reason)
  return droppedRun or droppedKicks
end

--- Opens the kicks-only window for a run whose DPS was captured while its
-- Interrupts list was not fully readable (the stats controller keeps the
-- landed kicks of that snapshot open). The window ends at `deadline` (the
-- late window of the key end) or LATE_RUN_CAPTURE_WINDOW_SECONDS from now.
-- @param ctx table Event-handler context.
-- @param runInfo table {mapID, level, onTime, signature}.
-- @param deadline number|nil GetTime() value the window ends at.
-- @return boolean true when the window was opened.
function LateRunCapture.ArmKicks(ctx, runInfo, deadline)
  local now = ReadNow(ctx)
  if type(runInfo) ~= "table" or not now then
    return false
  end
  deadline = type(deadline) == "number" and deadline or (now + LATE_RUN_CAPTURE_WINDOW_SECONDS)
  if deadline <= now then
    return false
  end
  local pending = {
    runInfo = runInfo,
    signature = runInfo.signature,
    deadline = deadline,
    attempts = 0,
  }
  ctx.pendingLateRunKicks = pending
  LogLateKicks(ctx, "armed", pending, "window=" .. tostring(deadline - now))
  if type(ctx.timerAfter) == "function" then
    ctx.timerAfter(deadline - now, function()
      if ctx.pendingLateRunKicks == pending then
        LateRunCapture.CancelKicks(ctx, "expired")
      end
    end)
  end
  return true
end

-- Kicks-only read on the same triggers as the late capture. Only a fully
-- readable Overall Interrupts list fills the captured run (no partial values).
local function TryKicks(ctx, trigger, opts)
  local pending = ctx.pendingLateRunKicks
  if type(pending) ~= "table" then
    return false
  end
  if ctx.lastRecordedRunSignature ~= pending.signature then
    LateRunCapture.CancelKicks(ctx, "superseded")
    return false
  end
  local now = ReadNow(ctx)
  if not now or now > pending.deadline then
    LateRunCapture.CancelKicks(ctx, "expired")
    return false
  end

  pending.attempts = pending.attempts + 1
  local runInfo = pending.runInfo
  local filled, kicksState = ctx.recordRun(runInfo.mapID, runInfo.level, runInfo.onTime, nil, {
    kicksOnly = true,
    overallOnly = true,
    phase = "late_kicks",
    trigger = trigger,
  })
  if filled ~= true then
    if kicksState == "none" then
      -- The stats controller closed the slot (a newer capture or run start).
      LateRunCapture.CancelKicks(ctx, "closed")
    elseif pending.attempts >= LATE_RUN_CAPTURE_MAX_ATTEMPTS then
      LateRunCapture.CancelKicks(ctx, "attempts")
    end
    return false
  end

  ctx.pendingLateRunKicks = nil
  LogLateKicks(ctx, "captured", pending, "trigger=" .. tostring(trigger))
  ctx.updateUI()
  -- Peers get the completed snapshot at once, like after the late capture.
  if not (type(opts) == "table" and opts.skipSync == true) and type(ctx.sendOwnKeySnapshot) == "function" then
    ctx.sendOwnKeySnapshot(true, "late-run-kicks", true)
  end
  return true
end

--- Opens the late window for a run whose capture just failed (once per run).
-- @param ctx table Event-handler context.
-- @param runInfo table {mapID, level, onTime, signature}.
-- @return boolean true when a window was opened.
function LateRunCapture.Arm(ctx, runInfo)
  if type(runInfo) ~= "table" then
    return false
  end
  -- One late window per run: a short retry that fails after the window
  -- closed must not open it again.
  if ctx.lateRunCaptureArmedSignature == runInfo.signature then
    return false
  end
  -- Without a readable clock the window cannot be bounded, and without the
  -- run's group nothing can be matched later: both fail closed.
  local now = ReadNow(ctx)
  local roster = CloneRosterForLateCapture(type(ctx.getRoster) == "function" and ctx.getRoster() or nil)
  if not now or not roster then
    return false
  end
  ctx.lateRunCaptureArmedSignature = runInfo.signature
  local pending = {
    runInfo = runInfo,
    signature = runInfo.signature,
    roster = roster,
    deadline = now + LATE_RUN_CAPTURE_WINDOW_SECONDS,
    attempts = 0,
  }
  ctx.pendingLateRunCapture = pending
  LogLateRunCapture(ctx, "armed", pending, "window=" .. tostring(LATE_RUN_CAPTURE_WINDOW_SECONDS))
  if type(ctx.timerAfter) == "function" then
    ctx.timerAfter(LATE_RUN_CAPTURE_WINDOW_SECONDS, function()
      if ctx.pendingLateRunCapture == pending then
        LateRunCapture.Cancel(ctx, "expired")
      end
    end)
  end
  return true
end

--- Retries the capture of a completed or abandoned run whose damage meter was
-- masked at the key end. Runs against the Overall session only and the group
-- of the run; bounded by LATE_RUN_CAPTURE_WINDOW_SECONDS and
-- LATE_RUN_CAPTURE_MAX_ATTEMPTS.
-- @param ctx table Event-handler context.
-- @param trigger string Trace label of the event that allowed the retry.
-- @param opts table|nil {skipSync=true} when the caller sends its own snapshot next.
-- @return boolean true when the run was captured now.
function LateRunCapture.Try(ctx, trigger, opts)
  local pending = ctx.pendingLateRunCapture
  if type(pending) ~= "table" then
    return TryKicks(ctx, trigger, opts)
  end
  if ctx.lastRecordedRunSignature == pending.signature and ctx.lastRecordedRunCaptured then
    LateRunCapture.Cancel(ctx, "captured")
    return false
  end
  local now = ReadNow(ctx)
  if not now or now > pending.deadline then
    LateRunCapture.Cancel(ctx, "expired")
    return false
  end

  pending.attempts = pending.attempts + 1
  local runInfo = pending.runInfo
  local result, kicksState = ctx.recordRun(runInfo.mapID, runInfo.level, runInfo.onTime, pending.roster, {
    overallOnly = true,
    phase = "late",
    trigger = trigger,
    kicksCast = runInfo.kicksCast,
    kicksMissed = runInfo.kicksMissed,
  })
  local captured = result == true
  if not captured then
    if pending.attempts >= LATE_RUN_CAPTURE_MAX_ATTEMPTS then
      LateRunCapture.Cancel(ctx, "attempts")
    end
    return false
  end

  ctx.pendingLateRunCapture = nil
  if ctx.lastRecordedRunSignature == pending.signature then
    ctx.lastRecordedRunCaptured = true
    ctx.pendingRecordedRunRetrySignature = nil
  end
  LogLateRunCapture(ctx, "captured", pending, "trigger=" .. tostring(trigger))
  -- DPS readable, Interrupts list not yet: the landed kicks stay open for the
  -- rest of the same window.
  if kicksState == "unreadable" then
    LateRunCapture.ArmKicks(ctx, runInfo, pending.deadline)
  end
  ctx.updateUI()
  -- Peers get the late value at once; the key-end snapshot carried none.
  if not (type(opts) == "table" and opts.skipSync == true) and type(ctx.sendOwnKeySnapshot) == "function" then
    ctx.sendOwnKeySnapshot(true, "late-run", true)
  end
  return true
end

--- Late-capture trigger for PLAYER_ENTERING_WORLD and ZONE_CHANGED_NEW_AREA:
-- only a readable "not in any instance" counts.
function LateRunCapture.TryOutsideInstance(ctx, trigger, opts)
  if type(ctx.pendingLateRunCapture) ~= "table" and type(ctx.pendingLateRunKicks) ~= "table" then
    return false
  end
  if ReadIsInInstance() ~= false then
    return false
  end
  return LateRunCapture.Try(ctx, trigger, opts)
end

-- ADDON_RESTRICTION_STATE_CHANGED (12.0.0, warcraft.wiki.gg): a restriction
-- type went to Enum.AddOnRestrictionState.Inactive. The enum is read at run
-- time; without it the event proves nothing and is ignored.
function LateRunCapture.IsRestrictionLiftedState(state)
  if IsSecretValue(state) or type(state) ~= "number" then
    return false
  end
  local enum = rawget(_G, "Enum")
  local states = type(enum) == "table" and enum.AddOnRestrictionState or nil
  local inactive = type(states) == "table" and states.Inactive or nil
  return type(inactive) == "number" and state == inactive
end
