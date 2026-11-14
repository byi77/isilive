local _, addonTable = ...
addonTable = addonTable or {}

-- Run focus (rule 248): while a key runs, the M+ layout keeps only its run
-- zone -- the CD row (battle res, Bloodlust, M+ timer, deaths) and the
-- killtracker row (forces, pace, section target) -- and slides everything
-- above it away. By default the window keeps its bottom edge, so the run
-- zone never moves; with runFocusAnchor "top" it keeps its top edge and the
-- run zone moves up to where the title bar was. A key start only arms it: the animated collapse starts when the key
-- countdown (START_TIMER, ChallengeModeCountdown) shows 5, or at the latest
-- when the M+ timer starts (WORLD_STATE_TIMER_START). A completed key expands
-- 4 s later, a reset key or leaving the instance expands at once (a pending
-- collapse is cancelled), and a login or /reload inside a running key starts
-- collapsed.
--
-- Mechanics:
--   * Hide pass: every candidate (all child frames of the main window except
--     the run zone, the resize grip and combat blockers, plus the panel's own
--     regions and the title band) is hidden as the last writer: the layout
--     pass and every roster render end in RI.RunFocusPass, child frames get an
--     OnShow hook. Secure frames are never hidden in combat; they are
--     shrouded (RI.SetCombatShrouded) until combat ends.
--   * Height: a filter on the main frame's height controller turns every full
--     height request into the collapsed or animated height.
--   * Combat: the main frame is protected in combat (it parents secure
--     buttons), so re-anchoring, resizing and clipping wait for
--     PLAYER_REGEN_ENABLED; the content is hidden right away.
local RunFocus = {}
addonTable.RunFocus = RunFocus

local RI = addonTable._RosterInternal or {}
addonTable._RosterInternal = RI

local LAYOUT_MODE_RUN = "compact_main_horizontal"
local COLLAPSE_SECONDS = 0.45
local EXPAND_SECONDS = 0.5
-- Share of the animation that carries the fade (start of a collapse, end of
-- an expand); the height moves over the whole duration.
-- Two phases, so the run zone never slides over half-faded content: a
-- collapse fades the rest out during the first FADE_SHARE of the time and
-- folds the window during the last FOLD_SHARE; an expand folds open first and
-- fades in at the end.
local FADE_SHARE = 0.35
local FOLD_SHARE = 0.7
local COMPLETED_EXPAND_DELAY_SECONDS = 4
-- runFocusExpandOutOfCombat: seconds out of combat before the window opens,
-- so chain pulls do not flap.
local PEEK_DEBOUNCE_SECONDS = 1.5
-- The collapse starts when the key countdown shows this second.
local COUNTDOWN_COLLAPSE_AT_SECONDS = 5
-- Enum.StartTimerType.ChallengeModeCountdown; type 2 is the leader's pull
-- timer (PlayerCountdown) and never collapses.
local START_TIMER_CHALLENGE_FALLBACK = 1
local COMPACT_TOP_PADDING = 8

local PHASE_IDLE = "idle"
local PHASE_COLLAPSING = "collapsing"
local PHASE_COLLAPSED = "collapsed"
local PHASE_EXPANDING = "expanding"

RunFocus.COLLAPSE_SECONDS = COLLAPSE_SECONDS
RunFocus.EXPAND_SECONDS = EXPAND_SECONDS
RunFocus.COMPLETED_EXPAND_DELAY_SECONDS = COMPLETED_EXPAND_DELAY_SECONDS

local function IsInCombat()
  local inCombat = rawget(_G, "InCombatLockdown")
  return type(inCombat) == "function" and inCombat() == true
end

local function IsSecretValue(value)
  local validators = addonTable.Validators
  return type(validators) == "table"
    and type(validators.IsSecretValue) == "function"
    and validators.IsSecretValue(value) == true
end

local function IsKeyActive()
  local challengeMode = rawget(_G, "C_ChallengeMode")
  local isActive = type(challengeMode) == "table" and challengeMode.IsChallengeModeActive or nil
  if type(isActive) ~= "function" then
    return false
  end
  local ok, active = pcall(isActive)
  if not ok or IsSecretValue(active) then
    return false
  end
  return active == true
end

local function IsProtectedObject(obj)
  if type(obj.IsProtected) ~= "function" then
    return false
  end
  local ok, protected = pcall(obj.IsProtected, obj)
  return ok and protected == true
end

local function IsShownObject(obj)
  return type(obj.IsShown) == "function" and obj:IsShown() == true
end

local function GetAlpha(obj)
  return type(obj.GetAlpha) == "function" and tonumber(obj:GetAlpha()) or 1
end

local function SetAlpha(obj, alpha)
  if type(obj.SetAlpha) == "function" then
    obj:SetAlpha(alpha)
  end
end

local function EaseOut(progress)
  local inverse = 1 - progress
  return 1 - inverse * inverse * inverse
end

-- Anchor point coordinates of a rect, in the object's own units.
local function PointCoords(obj, point)
  local left, right = obj:GetLeft(), obj:GetRight()
  local top, bottom = obj:GetTop(), obj:GetBottom()
  if not (tonumber(left) and tonumber(right) and tonumber(top) and tonumber(bottom)) then
    return nil
  end
  local x = (left + right) / 2
  if point:find("LEFT", 1, true) then
    x = left
  elseif point:find("RIGHT", 1, true) then
    x = right
  end
  local y = (top + bottom) / 2
  if point:find("TOP", 1, true) then
    y = top
  elseif point:find("BOTTOM", 1, true) then
    y = bottom
  end
  return x, y
end

-- Re-anchors the frame at `point` of its parent without moving it on screen.
-- Returns false when the geometry is not readable yet.
local function AnchorPreserving(frame, parent, point)
  if type(frame.GetLeft) ~= "function" or type(parent) ~= "table" or type(parent.GetLeft) ~= "function" then
    return false
  end
  local frameX, frameY = PointCoords(frame, point)
  local parentX, parentY = PointCoords(parent, point)
  if not (frameX and parentX) then
    return false
  end
  local frameScale = type(frame.GetEffectiveScale) == "function" and tonumber(frame:GetEffectiveScale()) or 1
  local parentScale = type(parent.GetEffectiveScale) == "function" and tonumber(parent:GetEffectiveScale()) or 1
  if not (frameScale and frameScale > 0 and parentScale) then
    return false
  end
  local ratio = parentScale / frameScale
  frame:ClearAllPoints()
  frame:SetPoint(point, parent, point, frameX - parentX * ratio, frameY - parentY * ratio)
  return true
end

-- Edge that stays put while collapsed: "bottom" (default, the window folds
-- down onto the run zone) or "top" (the run zone moves up to where the title
-- bar was). Anything else fails closed to "bottom".
local ANCHOR_POINTS = { bottom = "BOTTOMLEFT", top = "TOPLEFT" }

function RunFocus.NormalizeAnchor(value)
  return value == "top" and "top" or "bottom"
end

local function GetCompactHeight()
  local offset = tonumber(RI.CD_TRACKER_ROW_BOTTOM_OFFSET) or 40
  local rowHeight = tonumber(RI.CD_TRACKER_ROW_HEIGHT) or 24
  return offset + rowHeight + COMPACT_TOP_PADDING
end
RunFocus.GetCompactHeight = GetCompactHeight

-- The focus object `f` carries ui, frame, parent, the deps callbacks, the
-- run state and the animation driver; the functions below act on it.

local function IsKeep(f, obj)
  return obj == f.ui.cdTrackerRow
    or obj == f.ui.killTrackRow
    or obj == f.resizeGrip
    or obj == f.frame.Selection
    or obj._isiLiveIsCombatBlocker == true
end

local function AddCandidate(f, list, seen, obj)
  if type(obj) == "table" and not seen[obj] and type(obj.Hide) == "function" and not IsKeep(f, obj) then
    seen[obj] = true
    list[#list + 1] = obj
  end
end

-- Everything the run focus hides: all child frames except the run zone and
-- the window tools, plus the panel's own regions (title, headers, member row
-- cells, column guides) and the title band of the window decor.
local function BuildCandidates(f)
  local list, seen = {}, {}
  local frame, ui = f.frame, f.ui
  if type(frame.GetChildren) == "function" then
    for _, child in ipairs({ frame:GetChildren() }) do
      AddCandidate(f, list, seen, child)
    end
  end
  for _, rule in ipairs(RI.UI_VISIBILITY_RULES or {}) do
    AddCandidate(f, list, seen, ui[rule[1]])
  end
  for _, guide in ipairs(ui.m2ColumnGuides or {}) do
    AddCandidate(f, list, seen, guide)
  end
  for _, row in pairs(ui.memberRows or {}) do
    for _, value in pairs(row) do
      if type(value) == "table" and type(value.GetParent) == "function" and value:GetParent() == frame then
        AddCandidate(f, list, seen, value)
      end
    end
  end
  for _, region in ipairs(frame._isiLiveTitleBandRegions or {}) do
    AddCandidate(f, list, seen, region)
  end
  return list
end

local HideObject
local ReapplyAnchor

local function HookOnShow(f, obj)
  if f.hooked[obj] or type(obj.HookScript) ~= "function" then
    return
  end
  f.hooked[obj] = true
  obj:HookScript("OnShow", function(self)
    local phase = f.state.phase
    if phase == PHASE_COLLAPSED or phase == PHASE_COLLAPSING then
      HideObject(f, self)
    end
  end)
end

-- Secure frames are never hidden in combat: they are shrouded (alpha 0 plus
-- a mouse blocker) until the post-combat pass hides them for real.
HideObject = function(f, obj)
  local state = f.state
  if state.phase == PHASE_COLLAPSING and state.fade and state.fade[obj] then
    return
  end
  if IsInCombat() and IsProtectedObject(obj) then
    if not state.shrouded[obj] and IsShownObject(obj) and type(RI.SetCombatShrouded) == "function" then
      RI.SetCombatShrouded(obj, true)
      state.shrouded[obj] = true
      state.hidden[obj] = true
    end
    return
  end
  if state.shrouded[obj] then
    RI.SetCombatShrouded(obj, false)
    state.shrouded[obj] = nil
  end
  if IsShownObject(obj) then
    state.hidden[obj] = true
    obj:Hide()
  end
  HookOnShow(f, obj)
end

local function HideAll(f)
  for _, obj in ipairs(BuildCandidates(f)) do
    HideObject(f, obj)
  end
end

-- Gives back what the run focus hid; owner code corrects the rest.
local function RestoreHidden(f)
  local state = f.state
  for obj in pairs(state.hidden) do
    if state.shrouded[obj] then
      RI.SetCombatShrouded(obj, false)
    elseif type(obj.Show) == "function" then
      obj:Show()
    end
  end
  state.hidden = {}
  state.shrouded = {}
end

local function SetClip(f, on)
  if type(f.frame.SetClipsChildren) == "function" and not IsInCombat() then
    f.frame:SetClipsChildren(on == true)
  end
end

local function CurrentHeight(f)
  return type(f.frame.GetHeight) == "function" and tonumber(f.frame:GetHeight()) or GetCompactHeight()
end

local function TargetFullHeight(f)
  local requested = f.getRequestedHeight and tonumber(f.getRequestedHeight()) or nil
  return requested or f.state.fullHeight or CurrentHeight(f)
end

local function ApplyFrameHeight(f, height)
  if not IsInCombat() and type(f.frame.SetHeight) == "function" then
    f.frame:SetHeight(height)
  end
end

-- Height filter on the main frame's controller.
local function FilterHeight(f, height)
  local state = f.state
  if state.phase == PHASE_COLLAPSING or state.phase == PHASE_EXPANDING then
    return state.animHeight or height
  end
  if state.phase == PHASE_COLLAPSED and not state.geometryPending then
    return GetCompactHeight()
  end
  return height
end

local function StopDriver(f)
  if f.driver then
    f.driver:SetScript("OnUpdate", nil)
  end
end

local function CaptureFade(f, startAtZero)
  local fade = {}
  for _, obj in ipairs(BuildCandidates(f)) do
    if IsShownObject(obj) and not f.state.shrouded[obj] then
      fade[obj] = GetAlpha(obj)
      if startAtZero then
        SetAlpha(obj, 0)
      end
    end
  end
  return fade
end

local function RestoreFadeAlpha(f)
  for obj, base in pairs(f.state.fade or {}) do
    SetAlpha(obj, base)
  end
  f.state.fade = nil
end

local function FinishCollapse(f)
  StopDriver(f)
  RestoreFadeAlpha(f)
  f.state.phase = PHASE_COLLAPSED
  f.state.animHeight = nil
  HideAll(f)
  SetClip(f, false)
  ApplyFrameHeight(f, GetCompactHeight())
end

local function FinishExpand(f)
  local state = f.state
  StopDriver(f)
  RestoreFadeAlpha(f)
  state.phase = PHASE_IDLE
  state.animHeight = nil
  state.expandPending = false
  SetClip(f, false)
  ApplyFrameHeight(f, TargetFullHeight(f))
  -- Back on the anchor point the window had before the run, so later roster
  -- height changes grow it the way they did before.
  if state.originalPoint and not IsInCombat() then
    AnchorPreserving(f.frame, f.parent, state.originalPoint)
  end
  state.originalPoint = nil
end

-- Combat started mid-animation: freeze the geometry, finish when it ends.
local function FreezeForCombat(f)
  local state = f.state
  StopDriver(f)
  RestoreFadeAlpha(f)
  if state.phase == PHASE_COLLAPSING then
    state.phase = PHASE_COLLAPSED
    state.geometryPending = true
    HideAll(f)
  else
    state.expandPending = true
  end
end

local function StepAnimation(f, elapsed)
  local state = f.state
  if IsInCombat() then
    FreezeForCombat(f)
    return
  end
  state.elapsed = state.elapsed + (tonumber(elapsed) or 0)
  local progress = state.duration > 0 and math.min(1, state.elapsed / state.duration) or 1
  local collapsing = state.phase == PHASE_COLLAPSING
  local toHeight = collapsing and GetCompactHeight() or TargetFullHeight(f)
  local fold, visibility
  if collapsing then
    fold = math.max(0, (progress - (1 - FOLD_SHARE)) / FOLD_SHARE)
    visibility = 1 - math.min(1, progress / FADE_SHARE)
  else
    fold = math.min(1, progress / FOLD_SHARE)
    visibility = math.max(0, (progress - (1 - FADE_SHARE)) / FADE_SHARE)
  end
  state.animHeight = state.fromHeight + (toHeight - state.fromHeight) * EaseOut(fold)
  ApplyFrameHeight(f, state.animHeight)
  for obj, base in pairs(state.fade or {}) do
    SetAlpha(obj, base * visibility)
  end
  if progress >= 1 then
    if collapsing then
      FinishCollapse(f)
    else
      FinishExpand(f)
    end
  end
end

local function StartDriver(f, duration)
  local createFrame = rawget(_G, "CreateFrame")
  if not f.driver and type(createFrame) == "function" then
    f.driver = createFrame("Frame")
  end
  if not f.driver then
    return false
  end
  local state = f.state
  state.elapsed = 0
  state.duration = duration
  state.fromHeight = CurrentHeight(f)
  state.animHeight = state.fromHeight
  SetClip(f, true)
  f.driver:SetScript("OnUpdate", function(_self, elapsed)
    StepAnimation(f, elapsed)
  end)
  return true
end

local function CanAnimate(f)
  return type(f.frame.IsVisible) == "function" and f.frame:IsVisible() == true
end

-- Out of combat with a readable rect: pin the chosen edge and remember the
-- anchor point to return to.
local function PinEdge(f)
  if IsInCombat() then
    return false
  end
  local state = f.state
  if not state.originalPoint and type(f.frame.GetPoint) == "function" then
    local point = f.frame:GetPoint()
    state.originalPoint = type(point) == "string" and point or "CENTER"
  end
  state.fullHeight = CurrentHeight(f)
  state.pinnedAnchor = RunFocus.NormalizeAnchor(f.getAnchor())
  return AnchorPreserving(f.frame, f.parent, ANCHOR_POINTS[state.pinnedAnchor])
end

-- Shrinks the frame for content that is already hidden.
local function CompleteCollapseGeometry(f, animate)
  if not PinEdge(f) then
    f.state.geometryPending = true
    return
  end
  f.state.geometryPending = false
  if animate and CanAnimate(f) and StartDriver(f, COLLAPSE_SECONDS) then
    f.state.phase = PHASE_COLLAPSING
    return
  end
  FinishCollapse(f)
end

local function Collapse(f, animate)
  local state = f.state
  if state.phase == PHASE_COLLAPSED or state.phase == PHASE_COLLAPSING then
    return
  end
  StopDriver(f)
  RestoreFadeAlpha(f)
  if IsInCombat() then
    state.phase = PHASE_COLLAPSED
    state.geometryPending = true
    HideAll(f)
    return
  end
  if animate and CanAnimate(f) and PinEdge(f) then
    state.fade = CaptureFade(f, false)
    state.phase = PHASE_COLLAPSING
    if StartDriver(f, COLLAPSE_SECONDS) then
      HideAll(f)
      return
    end
    state.fade = nil
  end
  state.phase = PHASE_COLLAPSED
  HideAll(f)
  CompleteCollapseGeometry(f, false)
end

local function Expand(f, animate)
  local state = f.state
  if state.phase == PHASE_IDLE or state.phase == PHASE_EXPANDING then
    return
  end
  if IsInCombat() then
    state.expandPending = true
    return
  end
  StopDriver(f)
  RestoreFadeAlpha(f)
  local hadGeometry = not state.geometryPending
  state.geometryPending = false
  state.phase = PHASE_EXPANDING
  state.animHeight = CurrentHeight(f)
  RestoreHidden(f)
  f.refreshOwners()
  if animate and hadGeometry and CanAnimate(f) then
    state.fade = CaptureFade(f, true)
    if StartDriver(f, EXPAND_SECONDS) then
      return
    end
  end
  FinishExpand(f)
end

-- The test mode (demo switch, /isilive runfocus) is an explicit request and
-- ignores the setting; a raid or another layout still wins.
local function IsWanted(f)
  local state = f.state
  if f.isRaidGroup() or f.ui.layoutMode ~= LAYOUT_MODE_RUN then
    return false
  end
  if state.testMode then
    return true
  end
  -- `peek`: opened out of combat inside a running key (runFocusExpandOutOfCombat).
  return f.isEnabled() and (state.keyRunning or state.holdAfterCompletion) and not state.peek
end

local function Evaluate(f, animate)
  if IsWanted(f) then
    Collapse(f, animate)
  else
    Expand(f, animate)
  end
end

-- Hide pass, the last writer after every layout pass and roster render. It
-- also follows a layout switch (Edit Mode, raid) while a key runs.
local function Pass(f)
  if f.title then
    f.title.Layout(f.state.phase)
  end
  local phase = f.state.phase
  if phase == PHASE_EXPANDING then
    return
  end
  if phase == PHASE_IDLE then
    if IsWanted(f) then
      Collapse(f, false)
    end
    return
  end
  if not IsWanted(f) then
    Expand(f, false)
    return
  end
  HideAll(f)
end

-- Ends the key (or the armed countdown); the token bump turns every pending
-- countdown or hold timer into a no-op.
local function EndKey(f)
  local state = f.state
  state.keyRunning = false
  state.armed = false
  state.holdAfterCompletion = false
  state.holdToken = state.holdToken + 1
  state.peek = false
  state.peekToken = state.peekToken + 1
end

-- The countdown is over (or about to be): the key counts as running.
local function CollapseForRunningKey(f)
  local state = f.state
  if not state.armed then
    return
  end
  state.armed = false
  state.keyRunning = true
  Evaluate(f, true)
end

local function ChallengeCountdownType()
  local enum = rawget(_G, "Enum")
  local timerTypes = type(enum) == "table" and rawget(enum, "StartTimerType") or nil
  local value = type(timerTypes) == "table" and rawget(timerTypes, "ChallengeModeCountdown") or nil
  return type(value) == "number" and value or START_TIMER_CHALLENGE_FALLBACK
end

-- Seconds until the countdown shows COUNTDOWN_COLLAPSE_AT_SECONDS, or nil
-- when the payload is masked or no number.
local function SecondsUntilCollapse(timeRemaining)
  if IsSecretValue(timeRemaining) or type(timeRemaining) ~= "number" then
    return nil
  end
  local ok, delay = pcall(function()
    return timeRemaining - COUNTDOWN_COLLAPSE_AT_SECONDS
  end)
  return ok and type(delay) == "number" and delay or nil
end

-- START_TIMER: only the key countdown of an armed key counts; the collapse
-- starts when it shows 5. A masked payload waits for the timer start.
local function OnStartTimer(f, timerType, timeRemaining)
  local state = f.state
  if not state.armed or IsSecretValue(timerType) or timerType ~= ChallengeCountdownType() then
    return
  end
  local delay = SecondsUntilCollapse(timeRemaining)
  if delay == nil then
    return
  end
  if delay <= 0 then
    CollapseForRunningKey(f)
    return
  end
  local timer = rawget(_G, "C_Timer")
  local after = type(timer) == "table" and timer.After or nil
  if type(after) ~= "function" then
    return
  end
  local token = state.holdToken
  after(delay, function()
    if token == state.holdToken then
      CollapseForRunningKey(f)
    end
  end)
end

-- A completed key keeps the run zone for a moment, so the end banner and the
-- final time are read before the roster slides back.
-- Only a collapsed window holds; otherwise no timer is needed.
local function HoldAfterCompletion(f)
  local state = f.state
  EndKey(f)
  if state.phase ~= PHASE_COLLAPSED and state.phase ~= PHASE_COLLAPSING then
    Evaluate(f, true)
    return
  end
  state.holdAfterCompletion = true
  local token = state.holdToken
  local timer = rawget(_G, "C_Timer")
  local after = type(timer) == "table" and timer.After or nil
  if type(after) ~= "function" then
    state.holdAfterCompletion = false
    Evaluate(f, true)
    return
  end
  after(COMPLETED_EXPAND_DELAY_SECONDS, function()
    if token ~= state.holdToken then
      return
    end
    state.holdAfterCompletion = false
    Evaluate(f, true)
  end)
end

-- runFocusExpandOutOfCombat: after PEEK_DEBOUNCE_SECONDS out of combat in a
-- running key, the collapsed window opens; a new combat start cancels it.
local function SchedulePeek(f)
  local state = f.state
  if not f.expandOutOfCombat() or state.testMode or not state.keyRunning or state.peek then
    return
  end
  if state.phase ~= PHASE_COLLAPSED and state.phase ~= PHASE_COLLAPSING then
    return
  end
  local timer = rawget(_G, "C_Timer")
  local after = type(timer) == "table" and timer.After or nil
  if type(after) ~= "function" then
    return
  end
  state.peekToken = state.peekToken + 1
  local token = state.peekToken
  after(PEEK_DEBOUNCE_SECONDS, function()
    if token ~= state.peekToken or IsInCombat() or not state.keyRunning or not f.expandOutOfCombat() then
      return
    end
    state.peek = true
    Evaluate(f, true)
  end)
end

-- PLAYER_REGEN_DISABLED fires before the lockdown starts, so the protected
-- main frame can still be re-anchored and resized here: the opened window
-- collapses at once, without an animation.
local function OnCombatStarted(f)
  local state = f.state
  state.peekToken = state.peekToken + 1
  if state.peek then
    state.peek = false
    Evaluate(f, false)
  end
end

local function OnCombatEnded(f)
  local state = f.state
  if not state.expandPending and not (state.phase == PHASE_COLLAPSED and state.geometryPending) then
    SchedulePeek(f)
  end
  if state.anchorPending then
    state.anchorPending = false
    ReapplyAnchor(f)
  end
  if state.expandPending then
    state.expandPending = false
    if state.phase == PHASE_EXPANDING then
      FinishExpand(f)
    else
      Evaluate(f, true)
    end
    return
  end
  if state.phase == PHASE_COLLAPSED and state.geometryPending then
    HideAll(f)
    CompleteCollapseGeometry(f, true)
    SchedulePeek(f)
  end
end

-- The anchor setting changed while collapsed: expand and collapse again at
-- once on the new edge (out of combat; in combat at PLAYER_REGEN_ENABLED).
-- Returns true when it took over the refresh.
ReapplyAnchor = function(f)
  local state = f.state
  if state.phase ~= PHASE_COLLAPSED or state.geometryPending then
    return false
  end
  if state.pinnedAnchor == RunFocus.NormalizeAnchor(f.getAnchor()) then
    return false
  end
  if IsInCombat() then
    state.anchorPending = true
    return true
  end
  state.anchorPending = false
  Expand(f, false)
  Evaluate(f, false)
  return true
end

local function BuildController(f)
  local state = f.state
  local controller = {}
  function controller.Pass()
    Pass(f)
  end
  -- Key start only arms: the collapse waits for the countdown (START_TIMER)
  -- or, as a fallback, for the M+ timer start.
  function controller.OnKeyStart()
    EndKey(f)
    state.armed = true
  end
  function controller.OnStartTimer(timerType, timeRemaining)
    OnStartTimer(f, timerType, timeRemaining)
  end
  function controller.OnKeyTimerStarted()
    CollapseForRunningKey(f)
  end
  function controller.OnKeyCompleted()
    HoldAfterCompletion(f)
  end
  function controller.OnKeyReset()
    EndKey(f)
    Evaluate(f, true)
  end
  -- Login, /reload or a zone change. Only a login or reload may start the
  -- focus (instantly); a zone change only ends it once the key is gone.
  function controller.OnEnteringWorld(isLoginOrReload)
    local active = IsKeyActive()
    if isLoginOrReload then
      state.keyRunning = active
      Evaluate(f, false)
    elseif (state.keyRunning or state.armed) and not active then
      EndKey(f)
      Evaluate(f, false)
    end
  end
  function controller.OnCombatStarted()
    OnCombatStarted(f)
  end
  function controller.OnCombatEnded()
    OnCombatEnded(f)
  end
  -- The main frame was shown: a collapse that waited for a readable rect
  -- finishes now.
  function controller.OnFrameShown()
    if state.phase == PHASE_COLLAPSED and state.geometryPending and not IsInCombat() then
      CompleteCollapseGeometry(f, false)
    end
  end
  function controller.Refresh()
    if not f.isEnabled() then
      state.holdToken = state.holdToken + 1
    end
    if state.peek and not f.expandOutOfCombat() then
      state.peek = false
    end
    if f.title then
      f.title.Refresh()
      f.title.Layout(state.phase)
    end
    if ReapplyAnchor(f) then
      return
    end
    Evaluate(f, true)
  end
  function controller.SetTestMode(active)
    state.testMode = active == true
    Evaluate(f, true)
    return state.testMode
  end
  function controller.ToggleTestMode()
    return controller.SetTestMode(not state.testMode)
  end
  function controller.IsTestMode()
    return state.testMode
  end
  function controller.IsActive()
    return state.phase == PHASE_COLLAPSED or state.phase == PHASE_COLLAPSING
  end
  function controller.GetPhase()
    return state.phase
  end
  return controller
end

--- Creates the run focus for one roster panel and main window.
--- deps: ui (roster panel ui), frame (main frame), parent, resizeGrip,
--- setHeightFilter, getRequestedHeight, isRaidGroup, isEnabled,
--- refreshOwners (re-runs layout, roster render, teleport row and leader
--- buttons after an expand).
function RunFocus.Create(deps)
  deps = type(deps) == "table" and deps or {}
  if type(deps.ui) ~= "table" or type(deps.frame) ~= "table" then
    return nil
  end
  local frame = deps.frame
  local function Fn(value, fallback)
    return type(value) == "function" and value or fallback
  end
  local f = {
    ui = deps.ui,
    frame = frame,
    parent = deps.parent or (type(frame.GetParent) == "function" and frame:GetParent()) or nil,
    resizeGrip = deps.resizeGrip,
    isRaidGroup = Fn(deps.isRaidGroup, function()
      return false
    end),
    isEnabled = Fn(deps.isEnabled, function()
      return false
    end),
    refreshOwners = Fn(deps.refreshOwners, function() end),
    getAnchor = Fn(deps.getAnchor, function()
      return "bottom"
    end),
    expandOutOfCombat = Fn(deps.expandOutOfCombat, function()
      return false
    end),
    getRequestedHeight = Fn(deps.getRequestedHeight, nil),
    hooked = setmetatable({}, { __mode = "k" }),
    state = {
      phase = PHASE_IDLE,
      keyRunning = false,
      holdAfterCompletion = false,
      holdToken = 0,
      testMode = false,
      -- CHALLENGE_MODE_START seen, countdown not yet at 5.
      armed = false,
      peek = false,
      peekToken = 0,
      -- Content hidden, while anchor / height / clip still wait for a moment
      -- out of combat with a readable rect.
      geometryPending = false,
      expandPending = false,
      hidden = {},
      shrouded = {},
    },
  }
  local controller = BuildController(f)
  -- Title-bar switch for runFocusEnabled (ui/isiLive_run_focus_title.lua).
  if type(deps.getText) == "function" and type(RunFocus.CreateTitleToggle) == "function" then
    f.title = RunFocus.CreateTitleToggle({
      frame = frame,
      ui = deps.ui,
      getText = deps.getText,
      isEnabled = f.isEnabled,
      onToggle = function()
        local db = rawget(_G, "IsiLiveDB")
        if type(db) == "table" then
          db.runFocusEnabled = not f.isEnabled()
        end
        controller.Refresh()
        if type(deps.onEnabledToggled) == "function" then
          deps.onEnabledToggled()
        end
      end,
    })
    controller.titleButton = f.title and f.title.button or nil
  end
  if type(deps.setHeightFilter) == "function" then
    deps.setHeightFilter(function(height)
      return FilterHeight(f, height)
    end)
  end
  if type(frame.HookScript) == "function" then
    frame:HookScript("OnShow", function()
      controller.OnFrameShown()
    end)
  end
  return controller
end

local activeController = nil

-- Roster renders and ready-check refreshes end with the hide pass, so a row
-- the render shows again never stays visible (last writer).
local function WrapRosterPanel(rosterPanel, controller)
  for _, name in ipairs({ "RenderRoster", "RefreshReadyCheckState" }) do
    local original = rosterPanel[name]
    if type(original) == "function" then
      rosterPanel[name] = function(...)
        local result = original(...)
        controller.Pass()
        return result
      end
    end
  end
end

local function RegisterEvents(events, controller)
  events:SetScript("OnEvent", function(_self, event, isInitialLogin, isReloadingUi)
    if event == "START_TIMER" then
      controller.OnStartTimer(isInitialLogin, isReloadingUi)
    elseif event == "WORLD_STATE_TIMER_START" then
      controller.OnKeyTimerStarted()
    elseif event == "CHALLENGE_MODE_START" then
      controller.OnKeyStart()
    elseif event == "CHALLENGE_MODE_COMPLETED" then
      controller.OnKeyCompleted()
    elseif event == "CHALLENGE_MODE_RESET" then
      controller.OnKeyReset()
    elseif event == "PLAYER_ENTERING_WORLD" then
      controller.OnEnteringWorld(isInitialLogin == true or isReloadingUi == true)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
      controller.OnEnteringWorld(false)
    elseif event == "PLAYER_REGEN_DISABLED" then
      controller.OnCombatStarted()
    elseif event == "PLAYER_REGEN_ENABLED" then
      controller.OnCombatEnded()
    end
  end)
  for _, event in ipairs({
    "CHALLENGE_MODE_START",
    "START_TIMER",
    "WORLD_STATE_TIMER_START",
    "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET",
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
  }) do
    events:RegisterEvent(event)
  end
end

--- Installs the run focus on the roster panel and main window (rule 248) and
--- owns its event frame. Events are registered here, at load time, never from
--- an event handler. opts: rosterPanel, mainUI, isRaidGroup, refreshOwners.
function RunFocus.Install(opts)
  opts = type(opts) == "table" and opts or {}
  local rosterPanel = opts.rosterPanel
  local mainUI = opts.mainUI
  local createFrame = rawget(_G, "CreateFrame")
  if
    type(rosterPanel) ~= "table"
    or type(rosterPanel.AttachRunFocus) ~= "function"
    or type(mainUI) ~= "table"
    or type(mainUI.frame) ~= "table"
    or type(createFrame) ~= "function"
  then
    return nil
  end
  local controller
  local ui = rosterPanel.AttachRunFocus({
    Pass = function()
      if controller then
        controller.Pass()
      end
    end,
  })
  controller = RunFocus.Create({
    ui = ui,
    frame = mainUI.frame,
    parent = rawget(_G, "UIParent"),
    resizeGrip = mainUI.resizeGrip,
    setHeightFilter = mainUI.SetHeightFilter,
    getRequestedHeight = mainUI.GetRequestedHeight,
    isRaidGroup = opts.isRaidGroup,
    refreshOwners = opts.refreshOwners,
    -- Pattern B: runFocusEnabled is off until the player turns it on.
    isEnabled = function()
      local db = rawget(_G, "IsiLiveDB")
      return type(db) == "table" and db.runFocusEnabled == true
    end,
    getAnchor = function()
      local db = rawget(_G, "IsiLiveDB")
      return RunFocus.NormalizeAnchor(type(db) == "table" and db.runFocusAnchor or nil)
    end,
    expandOutOfCombat = function()
      local db = rawget(_G, "IsiLiveDB")
      return type(db) == "table" and db.runFocusExpandOutOfCombat == true
    end,
    getText = opts.getText,
    onEnabledToggled = opts.onEnabledToggled,
  })
  if not controller then
    rosterPanel.AttachRunFocus(nil)
    return nil
  end
  WrapRosterPanel(rosterPanel, controller)
  activeController = controller
  controller.eventFrame = createFrame("Frame")
  RegisterEvents(controller.eventFrame, controller)
  return controller
end

--- Settings toggle (runFocusEnabled): re-evaluates at once.
function RunFocus.Refresh()
  if activeController then
    activeController.Refresh()
  end
end

--- Test mode (demo switch, /isilive runfocus): shows the run focus without a
--- key and regardless of the setting. Returns the new state (false when the
--- run focus is not installed).
function RunFocus.SetTestMode(active)
  if not activeController then
    return false
  end
  return activeController.SetTestMode(active)
end

function RunFocus.ToggleTestMode()
  if not activeController then
    return false
  end
  return activeController.ToggleTestMode()
end

function RunFocus.IsTestMode()
  return activeController ~= nil and activeController.IsTestMode() == true
end

function RunFocus.GetActiveController()
  return activeController
end
