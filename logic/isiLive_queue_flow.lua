local _, addonTable = ...

addonTable = addonTable or {}

local QueueFlow = {}
addonTable.QueueFlow = QueueFlow

local function RequireFunction(value, name)
  return addonTable.Validators.RequireFunction(value, name, "QueueFlow")
end

local function AnnounceQueuedGroupJoin(deps)
  local L = deps.getL()
  local pending = deps.getPendingQueueJoinInfo()
  if not pending then
    return
  end

  if deps.isPlayerLeader() then
    deps.setPendingQueueJoinInfo(nil)
    return
  end

  local groupName = pending.groupName or L.UNKNOWN_GROUP
  local separator = "|cffffffff----------------------------------------|r"
  deps.printFn(separator)
  deps.printFn("|cffffffff" .. L.CHAT_QUEUE_PREFIX .. " | " .. string.format(L.JOINED_FROM_QUEUE, groupName) .. "|r")
  deps.printFn(separator)
  deps.setPendingQueueJoinInfo(nil)
end

local function CaptureQueueJoinCandidate(deps, ...)
  if deps.isInChallengeMode() then
    return
  end

  -- New queue-search phase starts outside a group: reset pending state.
  if not deps.isInGroup() then
    deps.setPendingQueueJoinInfo(nil)
  end

  local args = { ... }
  -- Minimal capture: just store that we came from a queue (no dungeon resolution).
  -- We only need to know the group name for the announcement.
  local groupName = nil
  if type(args[1]) == "table" then
    local data = args[1]
    groupName = data.groupName or data.name
  elseif type(args[1]) == "string" then
    -- positional args: first string that doesn't look like a status is the group name
    local val = args[1]
    local low = string.lower(val)
    if not (low:find("invite") or low:find("accept") or low == "applied" or low:find("declin")) then
      groupName = val
    end
  end
  if groupName == "" then
    groupName = nil
  end

  local pending = deps.getPendingQueueJoinInfo()
  if not pending then
    if not groupName then
      return
    end
    deps.setPendingQueueJoinInfo({ groupName = groupName, capturedAt = deps.getTimeFn() })
  end

  -- Race guard: GROUP_ROSTER_UPDATE can happen before the final LFG payload.
  -- If already grouped, announce immediately.
  if deps.isInGroup() then
    AnnounceQueuedGroupJoin(deps)
  end
end

function QueueFlow.CreateController(opts)
  opts = opts or {}

  local deps = {
    getL = RequireFunction(opts.getL, "getL"),
    getPendingQueueJoinInfo = RequireFunction(opts.getPendingQueueJoinInfo, "getPendingQueueJoinInfo"),
    setPendingQueueJoinInfo = RequireFunction(opts.setPendingQueueJoinInfo, "setPendingQueueJoinInfo"),
    printFn = opts.printFn or print,
    isInChallengeMode = RequireFunction(opts.isInChallengeMode, "isInChallengeMode"),
    isInGroup = RequireFunction(opts.isInGroup, "isInGroup"),
    isPlayerLeader = RequireFunction(opts.isPlayerLeader, "isPlayerLeader"),
    getTimeFn = opts.getTimeFn or GetTime,
  }

  assert(type(deps.printFn) == "function", "isiLive: QueueFlow requires printFn")
  assert(type(deps.getTimeFn) == "function", "isiLive: QueueFlow requires getTimeFn")

  local controller = {}

  function controller.CaptureQueueJoinCandidate(...)
    CaptureQueueJoinCandidate(deps, ...)
  end

  function controller.AnnounceQueuedGroupJoin()
    AnnounceQueuedGroupJoin(deps)
  end

  return controller
end
