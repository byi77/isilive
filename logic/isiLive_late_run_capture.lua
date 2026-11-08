local _, addonTable = ...

addonTable = addonTable or {}

-- Late run capture (rule 118, RULE-KEYENDE-RUN-IDENTITAET). All state lives on
-- the event-handler context: pendingLateRunCapture (the open window) and
-- lateRunCaptureArmedSignature (one window per run). The callers -- the
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

local function LogLateRunCapture(ctx, eventName, pending, extra)
  if type(ctx.logRuntimeTracef) ~= "function" then
    return
  end
  local runInfo = type(pending) == "table" and pending.runInfo or nil
  ctx.logRuntimeTracef(
    "[STATS] late_capture state=%s mapID=%s level=%s attempts=%s %s",
    tostring(eventName),
    tostring(runInfo and runInfo.mapID),
    tostring(runInfo and runInfo.level),
    tostring(type(pending) == "table" and pending.attempts or 0),
    tostring(extra or "")
  )
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
    return false
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
  local captured = ctx.recordRun(runInfo.mapID, runInfo.level, runInfo.onTime, pending.roster, {
    overallOnly = true,
    phase = "late",
    trigger = trigger,
  }) == true
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
  if type(ctx.pendingLateRunCapture) ~= "table" or ReadIsInInstance() ~= false then
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
