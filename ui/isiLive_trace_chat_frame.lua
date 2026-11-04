local _, addonTable = ...

addonTable = addonTable or {}

local TraceChatFrame = {}
addonTable.TraceChatFrame = TraceChatFrame

local FRAME_NAME = "isiLive Trace"

local function FindExistingFrame()
  local numWindows = tonumber(rawget(_G, "NUM_CHAT_WINDOWS")) or 10
  local getChatWindowInfo = rawget(_G, "GetChatWindowInfo")
  if type(getChatWindowInfo) ~= "function" then
    return nil
  end
  for i = 1, numWindows do
    local name = getChatWindowInfo(i)
    if name == FRAME_NAME then
      return rawget(_G, "ChatFrame" .. i)
    end
  end
  return nil
end

local function CreateNewFrame()
  local fcfOpen = rawget(_G, "FCF_OpenNewWindow")
  if type(fcfOpen) ~= "function" then
    return nil
  end
  local frame = fcfOpen(FRAME_NAME)
  if frame then
    local removeGroups = rawget(_G, "ChatFrame_RemoveAllMessageGroups")
    if type(removeGroups) == "function" then
      removeGroups(frame)
    end
  end
  return frame
end

function TraceChatFrame.CreateController()
  local controller = {}

  -- Never cache the ChatFrameN: after the user closes the tab Blizzard may
  -- reuse that slot for an unrelated window, so resolve by name every time.
  local function GetOrCreateFrame()
    return FindExistingFrame() or CreateNewFrame()
  end

  local function SelectTab(frame)
    local selectChat = rawget(_G, "FCF_SelectChatFrame")
    if type(selectChat) == "function" and frame then
      selectChat(frame)
    end
  end

  function controller.Open()
    local frame = GetOrCreateFrame()
    if frame and type(frame.Show) == "function" then
      frame:Show()
      SelectTab(frame)
    end
  end

  function controller.Close()
    local frame = FindExistingFrame()
    if not frame then
      return
    end
    local fcfClose = rawget(_G, "FCF_Close")
    if type(fcfClose) == "function" and pcall(fcfClose, frame) then
      return
    end
    if type(frame.Hide) == "function" then
      frame:Hide()
    end
  end

  function controller.Toggle()
    if controller.IsOpen() then
      controller.Close()
    else
      controller.Open()
    end
  end

  function controller.AddMessage(text, r, g, b)
    local frame = GetOrCreateFrame()
    if frame and type(frame.AddMessage) == "function" then
      frame:AddMessage(tostring(text), r or 0.7, g or 0.9, b or 1.0)
    end
  end

  function controller.IsOpen()
    local frame = FindExistingFrame()
    return frame ~= nil and type(frame.IsShown) == "function" and frame:IsShown() == true
  end

  return controller
end
