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

  local function SyncLeaderStateSilently()
    local isLeader = isPlayerLeader()
    local wasGroupLeader = getWasGroupLeader()

    if wasGroupLeader == nil or isLeader ~= wasGroupLeader then
      setWasGroupLeader(isLeader)
    end
  end

  local function PlayLeadTransferSound()
    local playSoundFile = rawget(_G, "PlaySoundFile")
    if type(playSoundFile) ~= "function" then
      return
    end
    playSoundFile("Interface\\AddOns\\isiLive\\sounds\\CartoonVoiceBaritone.ogg", "Master")
  end

  function controller.UpdateLeaderState(event)
    local isLeader = isPlayerLeader()
    local wasGroupLeader = getWasGroupLeader()

    if wasGroupLeader == nil then
      setWasGroupLeader(isLeader)
      return
    end

    if isLeader ~= wasGroupLeader then
      local L = getL()
      if isLeader then
        if event == "PARTY_LEADER_CHANGED" then
          showCenterNotice(L.LEAD_TRANSFERRED_CENTER, 20)
          PlayLeadTransferSound()
        else
          printFn(L.LEAD_GAINED)
        end
      else
        printFn(L.LEAD_LOST)
      end
      setWasGroupLeader(isLeader)
    end
    updateLeaderButtons()
  end

  function controller.Start()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PARTY_LEADER_CHANGED")
    frame:SetScript("OnEvent", function(_, event)
      if isStopped() then
        setWasGroupLeader(nil)
        return
      end
      if not isMainFrameShown() then
        if event == "PARTY_LEADER_CHANGED" then
          local wasGroupLeader = getWasGroupLeader()
          if wasGroupLeader ~= nil and not wasGroupLeader and isPlayerLeader() then
            PlayLeadTransferSound()
          end
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
