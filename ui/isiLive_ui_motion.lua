local _, addonTable = ...

addonTable = addonTable or {}

-- Shared motion vocabulary and decorative alpha transitions for UICommon.
--
-- Extracted from `ui/isiLive_ui_common.lua` along a clear UI responsibility:
-- motion tokens, reduced-motion handling and the per-frame transition
-- registry. Loaded before ui_common (TOC order); ui_common calls
-- `UIMotion.Install(UICommon)` at the point where this block used to live, so
-- every public `UICommon.*` name exists at the same time as before and no
-- caller changes. Helpers read `UICommon.*` lazily at call time.
local UIMotion = {}
addonTable.UIMotion = UIMotion

-- Bound by Install; every helper below runs only after that.
local UICommon

-- Shared motion vocabulary. New animations take their durations and easing
-- from here instead of inventing literals, so the addon moves at one tempo.
-- `fast` is the existing Center-Notice fade and must stay 0.14 s.
local MOTION = {
  duration = {
    fast = 0.14,
    normal = 0.2,
    slow = 0.35,
  },
  smoothing = {
    enter = "OUT",
    exit = "IN",
    loop = "IN_OUT",
  },
}

-- Every transition that is decorative registers here. Switching reduced
-- motion on stops all of them at once and leaves each frame at its resting
-- alpha, so the setting takes effect without a reload. Weak keys: a frame
-- that goes away must not be kept alive by this table.
local motionTransitions = setmetatable({}, { __mode = "k" })

local function IsReducedMotionEnabled()
  local db = rawget(_G, "IsiLiveDB")
  return type(db) == "table" and db.reduceMotion == true
end

local function ResolveMotionDuration(token)
  if type(token) == "number" and token >= 0 then
    return token
  end
  local durations = UICommon.Motion.duration
  return durations[token] or durations.normal
end

-- Only a transition that is actually running gets stopped and put back to
-- its resting alpha. An idle one is left alone: its frame's alpha may since
-- have been set by someone else (the main frame's combat fade, for one).
local function SettleMotionTransition(frame, transition)
  local group = transition.group
  if not (group and group.IsPlaying and group:IsPlaying()) then
    return
  end
  if group.Stop then
    group:Stop()
  end
  if type(frame.SetAlpha) == "function" then
    frame:SetAlpha(transition.restAlpha or 1)
  end
end

-- Show/hide motion state per frame (ShowAnimated / HideAnimated). Weak keys
-- like the transition registry above.
local motionStates = setmetatable({}, { __mode = "k" })

-- Forward declaration: settles every running show/hide when reduced motion
-- is switched on (defined with the show/hide motion below).
local SettleAllShowHideMotion

local function SetReducedMotionEnabled(enabled)
  local db = rawget(_G, "IsiLiveDB")
  if type(db) ~= "table" then
    return false
  end
  db.reduceMotion = enabled == true
  if not db.reduceMotion then
    return true
  end
  for frame, transitions in pairs(motionTransitions) do
    for _, transition in pairs(transitions) do
      SettleMotionTransition(frame, transition)
    end
  end
  SettleAllShowHideMotion()
  return true
end

local function GetMotionTransition(frame, key)
  local transitions = motionTransitions[frame]
  return transitions and transitions[key] or nil
end

local function CreateAlphaTransition(frame, key, opts)
  local group = frame:CreateAnimationGroup()
  local alpha = group:CreateAnimation("Alpha")
  alpha:SetFromAlpha(tonumber(opts.fromAlpha) or 0)
  alpha:SetToAlpha(tonumber(opts.toAlpha) or 1)
  alpha:SetDuration(UICommon.ResolveMotionDuration(opts.duration))
  alpha:SetSmoothing(opts.smoothing or UICommon.Motion.smoothing.enter)

  local transition = { group = group, restAlpha = 1 }
  if type(group.SetScript) == "function" then
    group:SetScript("OnFinished", function()
      if type(frame.SetAlpha) == "function" then
        frame:SetAlpha(transition.restAlpha or 1)
      end
    end)
  end

  motionTransitions[frame] = motionTransitions[frame] or {}
  motionTransitions[frame][key] = transition
  return transition
end

-- Plays a decorative alpha transition on `frame` and settles it at its
-- current alpha afterwards. The animation is built once per (frame, key) and
-- restarted on later calls. Returns false without touching the frame when
-- reduced motion is on or the frame cannot animate.
--
-- opts: fromAlpha, toAlpha (defaults 0 -> 1), duration (Motion token or
-- seconds), smoothing (defaults to the enter easing).
local function IsShowHideMotionPlaying(frame)
  local state = motionStates[frame]
  local group = state and state.group
  return group ~= nil and type(group.IsPlaying) == "function" and group:IsPlaying() == true
end

local function PlayAlphaTransition(frame, key, opts)
  if UICommon.IsReducedMotionEnabled() then
    return false
  end
  if type(frame) ~= "table" or type(frame.CreateAnimationGroup) ~= "function" or type(key) ~= "string" then
    return false
  end
  -- A running show/hide owns the frame's alpha; a decorative transition on
  -- top of it would make the card jump (one alpha motion per frame).
  if IsShowHideMotionPlaying(frame) then
    return false
  end
  local transition = GetMotionTransition(frame, key) or CreateAlphaTransition(frame, key, opts or {})
  if type(frame.GetAlpha) == "function" then
    transition.restAlpha = frame:GetAlpha()
  end
  -- One alpha transition per frame at a time: a newer one replaces a running
  -- sibling instead of stacking two fades.
  for otherKey, other in pairs(motionTransitions[frame]) do
    local otherGroup = other.group
    if otherKey ~= key and otherGroup.IsPlaying and otherGroup:IsPlaying() and otherGroup.Stop then
      otherGroup:Stop()
    end
  end
  local group = transition.group
  if group.IsPlaying and group:IsPlaying() and group.Stop then
    group:Stop()
  end
  group:Play()
  return true
end

local function PlayNoticeTransition(parent)
  local played = UICommon.PlayAlphaTransition(parent, "notice", {
    fromAlpha = 0.86,
    toAlpha = 1,
    duration = "fast",
  })
  if played then
    parent._isiLiveNoticeTransition = GetMotionTransition(parent, "notice").group
  end
  return played
end

-- Entrance of a notice card that was hidden: a full fade from transparent
-- over the `normal` duration, clearly noticeable without moving the card.
-- PlayNoticeTransition stays the quieter refresh for a card already on screen.
local function PlayNoticeEntrance(parent)
  local played = UICommon.PlayAlphaTransition(parent, "noticeEntrance", {
    fromAlpha = 0,
    toAlpha = 1,
    duration = "normal",
  })
  if played then
    parent._isiLiveNoticeEntrance = GetMotionTransition(parent, "noticeEntrance").group
  end
  return played
end

-- ---------------------------------------------------------------------------
-- Show / hide motion (rule 242): ShowAnimated(frame, kind) and
-- HideAnimated(frame, kind) replace a bare Show() / Hide() on isiLive's own
-- frames. One alpha target per frame: every call animates from the alpha the
-- frame has right now to the new target, so a quick show/hide/show neither
-- flickers nor leaves a half-transparent frame behind. Hiding switches the
-- frame's mouse off at once and calls the real Hide() only when the fade has
-- finished. Reduced motion applies every change at once. Built on
-- AnimationGroups only: nothing runs while no frame is changing (rule 168).
--
-- Combat: a protected frame (or one with secure children, IsProtected())
-- never gets Show/Hide/EnableMouse/SetPoint during combat lockdown. Hiding it
-- only fades its alpha and lays a plain mouse blocker over it; the real Hide()
-- follows at PLAYER_REGEN_ENABLED, where the runtime lifecycle calls
-- ApplyDeferredShowHide. Showing a hidden protected frame in combat is
-- deferred the same way (rules 46, 121).
-- ---------------------------------------------------------------------------

-- Per kind: entrance/exit duration tokens and the entrance slide (pixels the
-- frame starts above its anchor). Cards arrive with a short slide from above;
-- windows only fade so they are usable at once.
local SHOW_HIDE_KINDS = {
  card = { enter = "normal", exit = "fast", slide = 7 },
  window = { enter = "fast", exit = "fast", slide = 0 },
}
MOTION.showHide = SHOW_HIDE_KINDS

local function CallFrameMethod(frame, methodName, ...)
  local method = type(frame) == "table" and frame[methodName] or nil
  if type(method) == "function" then
    return method(frame, ...)
  end
  return nil
end

local function IsInCombatLockdown()
  local inCombat = rawget(_G, "InCombatLockdown")
  return type(inCombat) == "function" and inCombat() == true
end

-- True while Show/Hide/EnableMouse/SetPoint on `frame` would be blocked: in
-- combat for a protected frame, or for one its owner declared protected
-- (opts.protected, e.g. the main window with its secure buttons). The owner
-- may also supply its own combat check (opts.isInCombat).
local function IsShowHideBlocked(frame)
  local state = motionStates[frame]
  local inCombat
  if state and type(state.isInCombat) == "function" then
    inCombat = state.isInCombat() == true
  else
    inCombat = IsInCombatLockdown()
  end
  if not inCombat then
    return false
  end
  return (state ~= nil and state.protected == true) or CallFrameMethod(frame, "IsProtected") == true
end

local function ResolveShowHideKind(kind)
  return SHOW_HIDE_KINDS[kind] or SHOW_HIDE_KINDS.window
end

local function GetShowHideState(frame, opts)
  local state = motionStates[frame]
  if not state then
    state = { token = 0 }
    motionStates[frame] = state
  end
  if type(opts) == "table" then
    if opts.protected ~= nil then
      state.protected = opts.protected == true
    end
    if type(opts.isInCombat) == "function" then
      state.isInCombat = opts.isInCombat
    end
  end
  return state
end

local function ClampUnit(value)
  value = tonumber(value) or 0
  if value < 0 then
    return 0
  elseif value > 1 then
    return 1
  end
  return value
end

local function AnimationProgress(animation)
  if type(animation) ~= "table" then
    return 1
  end
  local progress = CallFrameMethod(animation, "GetSmoothProgress")
  if type(progress) ~= "number" then
    progress = CallFrameMethod(animation, "GetProgress")
  end
  return ClampUnit(progress)
end

local function IsGroupPlaying(state)
  local group = state.group
  return group ~= nil and CallFrameMethod(group, "IsPlaying") == true
end

-- Alpha and slide offset the frame shows right now, mid-animation included.
local function CurrentAlpha(frame, state)
  if IsGroupPlaying(state) and state.alphaAnim then
    local progress = AnimationProgress(state.alphaAnim)
    return state.fromAlpha + (state.toAlpha - state.fromAlpha) * progress
  end
  local alpha = CallFrameMethod(frame, "GetAlpha")
  return type(alpha) == "number" and ClampUnit(alpha) or 1
end

local function CurrentOffset(state)
  if IsGroupPlaying(state) and state.slideAnim and (state.fromOffset or 0) ~= 0 then
    return state.fromOffset * (1 - AnimationProgress(state.slideAnim))
  end
  return 0
end

local function StopShowHideGroup(state)
  state.token = state.token + 1
  if IsGroupPlaying(state) then
    CallFrameMethod(state.group, "Stop")
  end
end

-- Decorative transitions (PlayAlphaTransition) yield to a show/hide.
local function StopDecorativeTransitions(frame)
  for _, transition in pairs(motionTransitions[frame] or {}) do
    local group = transition.group
    if group and CallFrameMethod(group, "IsPlaying") == true then
      CallFrameMethod(group, "Stop")
    end
  end
end

-- One group per frame, built on the first animated show/hide: an instant
-- translation to the start offset (order 1) and the alpha fade plus the
-- slide back to the anchor (order 2).
local function EnsureShowHideGroup(frame, state)
  if state.group then
    return true
  end
  if type(frame.CreateAnimationGroup) ~= "function" then
    return false
  end
  local group = frame:CreateAnimationGroup()
  if type(group) ~= "table" or type(group.CreateAnimation) ~= "function" then
    return false
  end
  local lift = group:CreateAnimation("Translation")
  CallFrameMethod(lift, "SetOrder", 1)
  CallFrameMethod(lift, "SetDuration", 0)
  local alpha = group:CreateAnimation("Alpha")
  CallFrameMethod(alpha, "SetOrder", 2)
  local slide = group:CreateAnimation("Translation")
  CallFrameMethod(slide, "SetOrder", 2)
  CallFrameMethod(group, "SetToFinalAlpha", true)
  CallFrameMethod(group, "SetScript", "OnFinished", function()
    local finish = state.onFinish
    state.onFinish = nil
    if type(finish) == "function" then
      finish()
    end
  end)
  state.group = group
  state.liftAnim = lift
  state.alphaAnim = alpha
  state.slideAnim = slide
  return true
end

local function RememberAndDisableMouse(frame, state)
  if state.mouseDisabled then
    return
  end
  if CallFrameMethod(frame, "IsMouseEnabled") == true then
    state.mouseDisabled = true
    CallFrameMethod(frame, "EnableMouse", false)
  end
end

local function RestoreMouse(frame, state)
  if state.mouseDisabled then
    state.mouseDisabled = nil
    CallFrameMethod(frame, "EnableMouse", true)
  end
end

-- Plain (never protected) frame over a protected frame that fades out in
-- combat, so its invisible secure children cannot be clicked until the real
-- Hide() after combat.
local function SetShroud(frame, state, shrouded)
  local blocker = state.blocker
  if not shrouded then
    if blocker then
      CallFrameMethod(blocker, "Hide")
    end
    return
  end
  local createFrame = rawget(_G, "CreateFrame")
  if not blocker and type(createFrame) == "function" then
    blocker = createFrame("Frame", nil, CallFrameMethod(frame, "GetParent") or rawget(_G, "UIParent"))
    CallFrameMethod(blocker, "SetAllPoints", frame)
    CallFrameMethod(blocker, "EnableMouse", true)
    state.blocker = blocker
  end
  if blocker then
    local strata = CallFrameMethod(frame, "GetFrameStrata")
    if type(strata) == "string" then
      CallFrameMethod(blocker, "SetFrameStrata", strata)
    end
    local level = CallFrameMethod(frame, "GetFrameLevel")
    CallFrameMethod(blocker, "SetFrameLevel", (tonumber(level) or 0) + 50)
    CallFrameMethod(blocker, "Show")
  end
end

local function RunCallback(callback, frame)
  if type(callback) == "function" then
    callback(frame)
  end
end

-- End of a hide: the real Hide(), then alpha and mouse back to normal so a
-- later plain Show() is visible and clickable. Deferred while blocked.
local function FinishHide(frame, state)
  if IsShowHideBlocked(frame) then
    CallFrameMethod(frame, "SetAlpha", 0)
    SetShroud(frame, state, true)
    state.deferred = "hide"
    return false
  end
  state.deferred = nil
  CallFrameMethod(frame, "Hide")
  CallFrameMethod(frame, "SetAlpha", 1)
  RestoreMouse(frame, state)
  SetShroud(frame, state, false)
  local onHidden = state.onHidden
  state.onHidden = nil
  RunCallback(onHidden, frame)
  return true
end

-- Animates `frame` from its current alpha and offset to `targetAlpha`.
-- `opts`: fromAlpha (forced start), duration (token), smoothing, fromOffset
-- (extra slide start in pixels, positive = above the anchor), onFinish.
-- Returns false when nothing was played (reduced motion, no animation
-- support, nothing to move); the caller then applies the end state itself.
local function PlayShowHide(frame, state, targetAlpha, opts)
  local fromAlpha = opts.fromAlpha or CurrentAlpha(frame, state)
  local fromOffset = (tonumber(opts.fromOffset) or 0) + CurrentOffset(state)
  StopShowHideGroup(state)
  StopDecorativeTransitions(frame)
  state.onFinish = nil
  state.userFinish = nil
  state.fromOffset = 0
  if UICommon.IsReducedMotionEnabled() or not EnsureShowHideGroup(frame, state) then
    return false
  end
  local fullDuration = UICommon.ResolveMotionDuration(opts.duration)
  local distance = math.abs(targetAlpha - fromAlpha)
  -- The alpha distance sets the time (a reversed fade takes only the part
  -- still to go); a pure slide (alpha unchanged) takes the full duration.
  local share = distance
  if share <= 0.001 and math.abs(fromOffset) >= 0.5 then
    share = 1
  end
  if share <= 0.001 then
    return false
  end
  local duration = fullDuration * math.min(1, share)
  CallFrameMethod(frame, "SetAlpha", fromAlpha)
  state.fromAlpha = fromAlpha
  state.toAlpha = targetAlpha
  state.fromOffset = fromOffset
  CallFrameMethod(state.liftAnim, "SetOffset", 0, fromOffset)
  CallFrameMethod(state.alphaAnim, "SetFromAlpha", fromAlpha)
  CallFrameMethod(state.alphaAnim, "SetToAlpha", targetAlpha)
  CallFrameMethod(state.alphaAnim, "SetDuration", duration)
  CallFrameMethod(state.alphaAnim, "SetSmoothing", opts.smoothing or UICommon.Motion.smoothing.enter)
  CallFrameMethod(state.slideAnim, "SetOffset", 0, -fromOffset)
  CallFrameMethod(state.slideAnim, "SetDuration", duration)
  CallFrameMethod(state.slideAnim, "SetSmoothing", UICommon.Motion.smoothing.enter)
  local token = state.token
  state.userFinish = opts.onFinish
  state.onFinish = function()
    if state.token ~= token then
      return
    end
    state.fromOffset = 0
    state.userFinish = nil
    CallFrameMethod(frame, "SetAlpha", targetAlpha)
    if type(opts.onFinish) == "function" then
      opts.onFinish()
    end
  end
  CallFrameMethod(state.group, "Play")
  return true
end

-- Called from the PLAYER_REGEN_ENABLED handler of the runtime lifecycle.
local function ApplyDeferredShowHide()
  for frame, state in pairs(motionStates) do
    if state.deferred == "hide" and state.visible == false then
      FinishHide(frame, state)
    elseif state.deferred == "show" then
      state.deferred = nil
      UICommon.ShowAnimated(frame, state.kind)
    end
  end
end

-- Shows `frame` with the motion of `kind` ("card" or "window").
-- opts.instant: no animation (alpha 1 at once); opts.onShown: called once
-- the frame is fully visible; opts.protected / opts.isInCombat: see
-- IsShowHideBlocked (remembered per frame). Returns true when the frame is (becoming)
-- visible, false when the show waits for the end of combat.
local function ShowAnimated(frame, kind, opts)
  if type(frame) ~= "table" then
    return false
  end
  opts = opts or {}
  local state = GetShowHideState(frame, opts)
  local motion = ResolveShowHideKind(kind)
  state.kind = kind
  local blocked = IsShowHideBlocked(frame)
  local function FinishShow()
    RunCallback(opts.onShown, frame)
  end

  if CallFrameMethod(frame, "IsShown") ~= true then
    StopShowHideGroup(state)
    state.onHidden = nil
    if blocked then
      state.deferred = "show"
      state.visible = nil
      return false
    end
    state.deferred = nil
    state.visible = true
    RestoreMouse(frame, state)
    SetShroud(frame, state, false)
    CallFrameMethod(frame, "SetAlpha", opts.instant and 1 or 0)
    CallFrameMethod(frame, "Show")
    local played = not opts.instant
      and PlayShowHide(frame, state, 1, {
        fromAlpha = 0,
        fromOffset = motion.slide,
        duration = motion.enter,
        smoothing = UICommon.Motion.smoothing.enter,
        onFinish = FinishShow,
      })
    if not played then
      CallFrameMethod(frame, "SetAlpha", 1)
      FinishShow()
    end
    return true
  end

  -- Already shown: either fully visible (nothing to do) or fading out /
  -- shrouded in combat, which this reverses from the current alpha.
  if state.visible ~= false then
    if state.deferred == "show" then
      state.deferred = nil
    end
    return true
  end
  state.visible = true
  state.deferred = nil
  state.onHidden = nil
  SetShroud(frame, state, false)
  if not blocked then
    RestoreMouse(frame, state)
  end
  local played = PlayShowHide(frame, state, 1, {
    duration = motion.enter,
    smoothing = UICommon.Motion.smoothing.enter,
    onFinish = FinishShow,
  })
  if not played then
    CallFrameMethod(frame, "SetAlpha", 1)
    FinishShow()
  end
  return true
end

-- Hides `frame` with the motion of `kind`. opts.onHidden runs after the
-- real Hide() (at once when the frame is already hidden). Returns true when
-- a hide is running or waiting for the end of combat.
local function HideAnimated(frame, kind, opts)
  if type(frame) ~= "table" then
    return false
  end
  opts = opts or {}
  local state = GetShowHideState(frame, opts)
  local motion = ResolveShowHideKind(kind)
  state.kind = kind
  if CallFrameMethod(frame, "IsShown") ~= true then
    StopShowHideGroup(state)
    if state.deferred == "show" then
      state.deferred = nil
    end
    state.visible = false
    RunCallback(opts.onHidden, frame)
    return false
  end
  if opts.onHidden then
    state.onHidden = opts.onHidden
  end
  local blocked = IsShowHideBlocked(frame)
  if state.visible == false then
    -- Already on its way out; a hide that waited for combat may finish now.
    if state.deferred == "hide" and not blocked then
      FinishHide(frame, state)
    end
    return true
  end
  state.visible = false

  if blocked then
    -- Alpha only: the real Hide() waits for PLAYER_REGEN_ENABLED.
    state.deferred = "hide"
    SetShroud(frame, state, true)
    local played = PlayShowHide(frame, state, 0, {
      duration = motion.exit,
      smoothing = UICommon.Motion.smoothing.exit,
    })
    if not played then
      CallFrameMethod(frame, "SetAlpha", 0)
    end
    return true
  end

  RememberAndDisableMouse(frame, state)
  local played = PlayShowHide(frame, state, 0, {
    duration = motion.exit,
    smoothing = UICommon.Motion.smoothing.exit,
    onFinish = function()
      FinishHide(frame, state)
    end,
  })
  if not played then
    FinishHide(frame, state)
  end
  return true
end

-- Slides an already visible frame from `fromOffsetY` pixels (positive =
-- above) back to its anchor over `normal`, e.g. when a card stack reflows.
-- A running entrance keeps its alpha target and still reports its end.
local function PlaySlide(frame, fromOffsetY)
  if type(frame) ~= "table" or math.abs(tonumber(fromOffsetY) or 0) < 0.5 then
    return false
  end
  local state = GetShowHideState(frame)
  if state.visible == false or IsShowHideBlocked(frame) then
    return false
  end
  local running = IsGroupPlaying(state)
  local pendingFinish = running and state.userFinish or nil
  local targetAlpha = running and state.toAlpha or CurrentAlpha(frame, state)
  local played = PlayShowHide(frame, state, targetAlpha, {
    fromOffset = fromOffsetY,
    duration = "normal",
    smoothing = UICommon.Motion.smoothing.enter,
    onFinish = pendingFinish,
  })
  if not played then
    CallFrameMethod(frame, "SetAlpha", targetAlpha)
    if type(pendingFinish) == "function" then
      pendingFinish()
    end
  end
  return played
end

-- True from HideAnimated until the next ShowAnimated (fade-out running,
-- or waiting in combat for the real Hide()).
local function IsHiding(frame)
  local state = motionStates[frame]
  return state ~= nil and state.visible == false and CallFrameMethod(frame, "IsShown") == true
end

-- Reduced motion switched on: every running show/hide jumps to its end.
SettleAllShowHideMotion = function()
  for frame, state in pairs(motionStates) do
    if IsGroupPlaying(state) then
      local finish = state.userFinish
      StopShowHideGroup(state)
      state.onFinish = nil
      state.userFinish = nil
      state.fromOffset = 0
      CallFrameMethod(frame, "SetAlpha", state.visible == false and 0 or 1)
      if type(finish) == "function" then
        finish()
      end
    end
  end
end

-- Fade-in of a window that something else already showed (e.g. the ESC
-- panel, which appears with Blizzard's game menu): alpha 0 -> 1 over `fast`,
-- alpha only and therefore combat safe.
local function PlayWindowEntrance(frame)
  return PlayAlphaTransition(frame, "windowEntrance", {
    fromAlpha = 0,
    toAlpha = 1,
    duration = SHOW_HIDE_KINDS.window.enter,
  })
end

-- Attaches the motion surface to the UICommon facade. Called exactly once by
-- ui/isiLive_ui_common.lua while that file loads.
function UIMotion.Install(target)
  UICommon = target
  target.IsReducedMotionEnabled = IsReducedMotionEnabled
  target.Motion = MOTION
  target.ResolveMotionDuration = ResolveMotionDuration
  target.SetReducedMotionEnabled = SetReducedMotionEnabled
  target.PlayAlphaTransition = PlayAlphaTransition
  target.PlayNoticeTransition = PlayNoticeTransition
  target.PlayNoticeEntrance = PlayNoticeEntrance
  target.PlayWindowEntrance = PlayWindowEntrance
  target.ShowAnimated = ShowAnimated
  target.HideAnimated = HideAnimated
  target.PlaySlide = PlaySlide
  target.IsHiding = IsHiding
  target.IsShowHideBlocked = IsShowHideBlocked
  target.ApplyDeferredShowHide = ApplyDeferredShowHide
end

UIMotion.ShowAnimated = ShowAnimated
UIMotion.HideAnimated = HideAnimated
UIMotion.PlaySlide = PlaySlide
UIMotion.IsHiding = IsHiding
UIMotion.ApplyDeferredShowHide = ApplyDeferredShowHide
