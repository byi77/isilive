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

  local function PlayLeadTransferSound()
    local db = rawget(_G, "IsiLiveDB")
    if db and db.soundLeadEnabled == false then
      return
    end
    addonTable.SoundUtils.Play("Interface\\AddOns\\isiLive\\sounds\\CartoonVoiceBaritone.ogg")
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
        HandleLeaderGain(true)
      else
        printFn(L.LEAD_LOST)
      end
      setWasGroupLeader(isLeader)
    end
    updateLeaderButtons()
  end

  function controller.Start()
    SyncLeaderStateSilently()

    local frame = CreateFrame("Frame")
    controller.frame = frame
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PARTY_LEADER_CHANGED")
    frame:SetScript("OnEvent", function(_, event)
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
    end)
    return frame
  end

  return controller
end
