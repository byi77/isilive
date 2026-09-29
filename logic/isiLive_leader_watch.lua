local _, addonTable = ...

addonTable = addonTable or {}

local LeaderWatch = {}
addonTable.LeaderWatch = LeaderWatch

local function RequireFunction(value, name)
  return addonTable.Validators.RequireFunction(value, name, "LeaderWatch")
end

function LeaderWatch.CreateController(opts)
  opts = opts or {}

  local isPlayerLeader = RequireFunction(opts.isPlayerLeader, "isPlayerLeader")
  local getWasGroupLeader = RequireFunction(opts.getWasGroupLeader, "getWasGroupLeader")
  local setWasGroupLeader = RequireFunction(opts.setWasGroupLeader, "setWasGroupLeader")
  local isStopped = RequireFunction(opts.isStopped, "isStopped")
  local isMainFrameShown = RequireFunction(opts.isMainFrameShown, "isMainFrameShown")
  local showCenterNotice = RequireFunction(opts.showCenterNotice, "showCenterNotice")
  local printFn = RequireFunction(opts.printFn, "printFn")
  local getL = RequireFunction(opts.getL, "getL")
  local updateLeaderButtons = RequireFunction(opts.updateLeaderButtons, "updateLeaderButtons")
  local logRuntimeTracef = type(opts.logRuntimeTracef) == "function" and opts.logRuntimeTracef or nil

  local controller = {}

  local function GetLeaderState()
    local isLeader = isPlayerLeader()
    local wasGroupLeader = getWasGroupLeader()
    return isLeader, wasGroupLeader
  end

  local function SyncLeaderStateSilently()
    local isLeader, wasGroupLeader = GetLeaderState()

    if wasGroupLeader == nil or isLeader ~= wasGroupLeader then
      setWasGroupLeader(isLeader)
    end
  end

  -- GROUP_ROSTER_UPDATE survives the raid hard-off and reaches this controller
  -- too, so the raid gate has to sit on the sound itself: a raid plays the
  -- lead-transfer sound only with the raid opt-in (rule 144).
  local function IsLeadSoundBlockedByRaid()
    local runtimeMode = addonTable.RuntimeMode
    if type(runtimeMode) ~= "table" or type(runtimeMode.IsRaidContext) ~= "function" then
      return false
    end
    if runtimeMode.IsRaidContext() ~= true then
      return false
    end
    local soundUtils = addonTable.SoundUtils
    return type(soundUtils) ~= "table"
      or type(soundUtils.IsRaidOptInEnabled) ~= "function"
      or soundUtils.IsRaidOptInEnabled("leader_transfer") ~= true
  end

  local function PlayLeadTransferSound()
    if IsLeadSoundBlockedByRaid() then
      return
    end
    local soundUtils = addonTable.SoundUtils
    if type(soundUtils) == "table" and type(soundUtils.PlayKey) == "function" then
      soundUtils.PlayKey("leader_transfer")
      return
    end
    if type(soundUtils) == "table" and type(soundUtils.Play) == "function" then
      soundUtils.Play("Interface\\AddOns\\isiLive\\sounds\\CartoonVoiceBaritone.ogg")
    end
  end

  local function HandleLeaderGain(visible)
    if visible then
      local L = getL()
      showCenterNotice(L.LEAD_TRANSFERRED_CENTER, 20)
    end
    PlayLeadTransferSound()
  end

  function controller.UpdateLeaderState(_event)
    local isLeader, wasGroupLeader = GetLeaderState()

    if wasGroupLeader == nil then
      setWasGroupLeader(isLeader)
      return
    end

    if isLeader ~= wasGroupLeader then
      local L = getL()
      if isLeader then
        if logRuntimeTracef then
          logRuntimeTracef("[LEADER] gained isLeader=%s", tostring(isLeader))
        end
        HandleLeaderGain(true)
      else
        if logRuntimeTracef then
          logRuntimeTracef("[LEADER] lost isLeader=%s", tostring(isLeader))
        end
        printFn(L.LEAD_LOST)
      end
      setWasGroupLeader(isLeader)
    end
    updateLeaderButtons()
  end

  function controller.HandleEvent(event)
    if isStopped() then
      setWasGroupLeader(nil)
      return
    end
    if not isMainFrameShown() then
      local isLeader, wasGroupLeader = GetLeaderState()
      if wasGroupLeader ~= nil and not wasGroupLeader and isLeader then
        HandleLeaderGain(false)
      end
      SyncLeaderStateSilently()
      return
    end
    controller.UpdateLeaderState(event)
  end

  function controller.Start()
    SyncLeaderStateSilently()
    return controller
  end

  return controller
end
