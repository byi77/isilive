local _, addonTable = ...

addonTable = addonTable or {}

local ChatHistory = {}
addonTable.ChatHistory = ChatHistory

-- Chat history (rule 253): Up / Down in the chat input step through the lines
-- the player sent (the game's own edit box history, which normally needs
-- Alt), and the lines are kept in IsiLiveDB.chatHistoryLines so they survive
-- /reload and restarts.
--
-- Only the game's own edit box methods are called, and AddHistoryLine is
-- hooked with hooksecurefunc, so no chat code is replaced.

ChatHistory.MAX_LINES = 100

local hooked = setmetatable({}, { __mode = "k" })
local restoring = false
local typed = setmetatable({}, { __mode = "k" }) -- last non-empty text per box
local addedByGame = false
local dbRef

local Validators = addonTable.Validators

local function IsSecret(value)
  return Validators ~= nil and Validators.IsSecretValue(value) == true
end

local function IsEnabled()
  return type(dbRef) == "table" and dbRef.chatHistoryEnabled ~= false
end

function ChatHistory.GetEditBoxes()
  local boxes = {}
  local count = rawget(_G, "NUM_CHAT_WINDOWS")
  count = type(count) == "number" and count or 10
  for i = 1, count do
    local box = rawget(_G, "ChatFrame" .. i .. "EditBox")
    if type(box) == "table" and type(box.AddHistoryLine) == "function" then
      boxes[#boxes + 1] = box
    end
  end
  return boxes
end

-- Every line the game adds to an edit box history (each sent line, slash
-- commands too) goes to the saved list; a repeat moves to the end. With the
-- setting off nothing is saved.
function ChatHistory.Remember(_box, line)
  if restoring or not IsEnabled() or IsSecret(line) or type(line) ~= "string" then
    return
  end
  line = line:match("^%s*(.-)%s*$")
  if line == "" then
    return
  end
  addedByGame = true
  local list = dbRef.chatHistoryLines
  if type(list) ~= "table" then
    list = {}
    dbRef.chatHistoryLines = list
  end
  for i = #list, 1, -1 do
    if list[i] == line then
      table.remove(list, i)
    end
  end
  list[#list + 1] = line
  while #list > ChatHistory.MAX_LINES do
    table.remove(list, 1)
  end
end

local function ApplyArrowMode(box)
  if type(box.SetAltArrowKeyMode) == "function" then
    -- false: Up / Down without Alt walk the history, Left / Right move the cursor.
    pcall(box.SetAltArrowKeyMode, box, not IsEnabled())
  end
end

-- Own walk through the saved list: a client may reset the edit box's arrow
-- mode or not walk its history at all, so Up / Down set the text themselves.
-- walkPos = index into chatHistoryLines, nil = not walking (empty line).
local walkPos = setmetatable({}, { __mode = "k" })
local lastStep = setmetatable({}, { __mode = "k" })

function ChatHistory.Step(box, key)
  if not IsEnabled() or (key ~= "UP" and key ~= "DOWN") then
    return
  end
  -- OnArrowPressed and OnKeyDown can both report the same key press.
  local getTime = rawget(_G, "GetTime")
  local now = type(getTime) == "function" and getTime() or nil
  if now ~= nil and lastStep[box] == now then
    return
  end
  lastStep[box] = now
  local list = dbRef.chatHistoryLines
  if type(list) ~= "table" or #list == 0 then
    return
  end
  local position = walkPos[box]
  if key == "UP" then
    position = math.max(1, (position or #list + 1) - 1)
  elseif position then
    position = position + 1
    if position > #list then
      position = nil
    end
  else
    return
  end
  walkPos[box] = position
  local text = position and list[position] or ""
  pcall(box.SetText, box, text)
  if type(box.SetCursorPosition) == "function" then
    pcall(box.SetCursorPosition, box, #text)
  end
end

-- Slash commands the game does not put into the history itself (e.g.
-- /console) are taken from the text that was in the box when Enter was
-- pressed. The game's clearing of the box is not user input, so the typed
-- text survives it; deleting the text by hand forgets it.
function ChatHistory.HookEnter(box)
  box:HookScript("OnTextChanged", function(self, userInput)
    local text = self:GetText()
    if IsSecret(text) then
      typed[self] = nil
    elseif text ~= "" then
      typed[self] = text
    elseif userInput then
      typed[self] = nil
    end
  end)
  box:HookScript("OnEditFocusGained", function(self)
    typed[self] = nil
    walkPos[self] = nil
    addedByGame = false
    ApplyArrowMode(self) -- a client may reset it when the box opens
  end)
  box:HookScript("OnArrowPressed", ChatHistory.Step)
  if type(box.HasScript) == "function" and box:HasScript("OnKeyDown") then
    box:HookScript("OnKeyDown", ChatHistory.Step)
  end
  box:HookScript("OnEnterPressed", function(self)
    local text = typed[self]
    typed[self] = nil
    walkPos[self] = nil
    if not addedByGame and type(text) == "string" and IsEnabled() then
      pcall(self.AddHistoryLine, self, text)
    end
    addedByGame = false
  end)
end

-- Saved lines go back into each edit box history (oldest
-- first, so Up starts with the newest line), then new lines are recorded.
function ChatHistory.Setup(db)
  if type(db) ~= "table" then
    return
  end
  dbRef = db
  if type(db.chatHistoryLines) ~= "table" then
    db.chatHistoryLines = {}
  end
  local hook = rawget(_G, "hooksecurefunc")
  for _, box in ipairs(ChatHistory.GetEditBoxes()) do
    if not hooked[box] then
      hooked[box] = true
      if type(box.SetHistoryLines) == "function" then
        pcall(box.SetHistoryLines, box, ChatHistory.MAX_LINES)
      end
      if IsEnabled() then
        restoring = true
        for _, line in ipairs(db.chatHistoryLines) do
          if type(line) == "string" then
            pcall(box.AddHistoryLine, box, line)
          end
        end
        restoring = false
      end
      if type(hook) == "function" then
        pcall(hook, box, "AddHistoryLine", ChatHistory.Remember)
      end
      if type(box.HookScript) == "function" then
        ChatHistory.HookEnter(box)
      end
    end
    ApplyArrowMode(box)
  end
end

-- Saved variables are loaded at PLAYER_LOGIN (same pattern as the minimap
-- button in factory/isiLive_factory_minimap.lua).
local createFrame = rawget(_G, "CreateFrame")
if type(createFrame) == "function" then
  local loginFrame = createFrame("Frame")
  addonTable.EventUtils.SafeRegisterEvent(loginFrame, "PLAYER_LOGIN")
  loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ChatHistory.Setup(rawget(_G, "IsiLiveDB"))
  end)
end

-- Settings toggle: arrow mode follows the setting at once.
function ChatHistory.Apply()
  for _, box in ipairs(ChatHistory.GetEditBoxes()) do
    ApplyArrowMode(box)
  end
end
