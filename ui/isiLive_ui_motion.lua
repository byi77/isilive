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
local function PlayAlphaTransition(frame, key, opts)
  if UICommon.IsReducedMotionEnabled() then
    return false
  end
  if type(frame) ~= "table" or type(frame.CreateAnimationGroup) ~= "function" or type(key) ~= "string" then
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
end
