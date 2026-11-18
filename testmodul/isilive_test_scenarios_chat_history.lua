---@diagnostic disable: undefined-global

-- Chat history (rule 253, game/isiLive_chat_history.lua).

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  -- Chat input with the game's history methods and script hooks.
  local function NewEditBox()
    local box = { history = {}, text = "", hooks = {} }
    function box:AddHistoryLine(line)
      self.history[#self.history + 1] = line
    end
    function box:SetHistoryLines(count)
      self.maxLines = count
    end
    function box:SetAltArrowKeyMode(value)
      self.altArrow = value
    end
    function box:GetText()
      return self.text
    end
    -- Sets the text like the game: OnTextChanged with userInput.
    function box:SetText(text, userInput)
      self.text = text
      for _, fn in ipairs(self.hooks.OnTextChanged or {}) do
        fn(self, userInput == true)
      end
    end
    function box:HookScript(script, fn)
      self.hooks[script] = self.hooks[script] or {}
      table.insert(self.hooks[script], fn)
    end
    function box:Fire(script)
      for _, fn in ipairs(self.hooks[script] or {}) do
        fn(self)
      end
    end
    function box:FireKey(script, key)
      for _, fn in ipairs(self.hooks[script] or {}) do
        fn(self, key)
      end
    end
    return box
  end

  local function HookSecureFunc(tbl, name, fn)
    local original = tbl[name]
    tbl[name] = function(...)
      original(...)
      fn(...)
    end
  end

  local function WithChat(box, fn)
    WithGlobals({
      NUM_CHAT_WINDOWS = 1,
      ChatFrame1EditBox = box,
      hooksecurefunc = HookSecureFunc,
    }, function()
      fn(LoadAddonModules({ "isiLive_chat_history.lua" }).ChatHistory)
    end)
  end

  test("ChatHistory saves sent lines, moves repeats to the end and caps the list", function()
    local box = NewEditBox()
    local db = {}
    WithChat(box, function(ChatHistory)
      ChatHistory.Setup(db)
      box:AddHistoryLine("/w Friend hi")
      box:AddHistoryLine("  hello  ")
      box:AddHistoryLine("/w Friend hi")
      Assert.Equal(#db.chatHistoryLines, 2, "a repeat is stored once")
      Assert.Equal(db.chatHistoryLines[1], "hello", "trimmed line")
      Assert.Equal(db.chatHistoryLines[2], "/w Friend hi", "the repeat moved to the end")
      for i = 1, ChatHistory.MAX_LINES + 5 do
        box:AddHistoryLine("line " .. i)
      end
      Assert.Equal(#db.chatHistoryLines, ChatHistory.MAX_LINES, "capped at MAX_LINES")
      Assert.Equal(db.chatHistoryLines[#db.chatHistoryLines], "line " .. (ChatHistory.MAX_LINES + 5), "newest last")
    end)
  end)

  test("ChatHistory restores saved lines and walks them without Alt", function()
    local box = NewEditBox()
    local db = { chatHistoryLines = { "first", "second" } }
    WithChat(box, function(ChatHistory)
      ChatHistory.Setup(db)
      Assert.Equal(box.history[1], "first", "oldest first")
      Assert.Equal(box.history[2], "second", "newest last, so Up starts with it")
      Assert.Equal(#db.chatHistoryLines, 2, "restoring does not save the lines again")
      Assert.Equal(box.altArrow, false, "Up / Down without Alt")
      Assert.Equal(box.maxLines, ChatHistory.MAX_LINES, "edit box keeps MAX_LINES")
    end)
  end)

  test("ChatHistory keeps slash commands the game sends without a history line", function()
    local box = NewEditBox()
    local db = {}
    WithChat(box, function(ChatHistory)
      ChatHistory.Setup(db)
      box:Fire("OnEditFocusGained")
      box:SetText("/console gxRestart", true)
      box:SetText("", false)
      box:Fire("OnEnterPressed")
      Assert.Equal(db.chatHistoryLines[1], "/console gxRestart", "/console saved from the typed text")
      Assert.Equal(box.history[1], "/console gxRestart", "and walkable with Up")

      box:Fire("OnEditFocusGained")
      box:SetText("hello", true)
      box:AddHistoryLine("hello")
      local count = #box.history
      box:Fire("OnEnterPressed")
      Assert.Equal(#box.history, count, "no double line when the game added it")

      box:Fire("OnEditFocusGained")
      box:SetText("/console x", true)
      box:SetText("", true)
      box:Fire("OnEnterPressed")
      Assert.Equal(db.chatHistoryLines[#db.chatHistoryLines], "hello", "text deleted by hand is not saved")
    end)
  end)

  test("ChatHistory walks the saved lines with Up and Down itself", function()
    local box = NewEditBox()
    local db = { chatHistoryLines = { "first", "second", "third" } }
    local clock = 0
    WithGlobals({
      GetTime = function()
        clock = clock + 1
        return clock
      end,
    }, function()
      WithChat(box, function(ChatHistory)
        ChatHistory.Setup(db)
        box.altArrow = true -- a client resets the mode when the box opens
        box:Fire("OnEditFocusGained")
        Assert.Equal(box.altArrow, false, "arrow mode set again on open")
        box:FireKey("OnArrowPressed", "UP")
        Assert.Equal(box.text, "third", "Up shows the newest line")
        box:FireKey("OnArrowPressed", "UP")
        Assert.Equal(box.text, "second", "Up again shows the one before")
        box:FireKey("OnArrowPressed", "DOWN")
        Assert.Equal(box.text, "third", "Down goes back")
        box:FireKey("OnArrowPressed", "DOWN")
        Assert.Equal(box.text, "", "Down past the newest line empties the box")
        box:FireKey("OnArrowPressed", "LEFT")
        Assert.Equal(box.text, "", "Left / Right stay with the cursor")
      end)
    end)
  end)

  test("ChatHistory steps once when one key press is reported twice", function()
    local box = NewEditBox()
    local db = { chatHistoryLines = { "first", "second" } }
    WithGlobals({
      GetTime = function()
        return 5
      end,
    }, function()
      WithChat(box, function(ChatHistory)
        ChatHistory.Setup(db)
        box:FireKey("OnArrowPressed", "UP")
        box:FireKey("OnKeyDown", "UP")
        box:FireKey("OnArrowPressed", "UP")
        Assert.Equal(box.text, "second", "same frame -> one step")
      end)
    end)
  end)

  test("ChatHistory saves nothing and keeps Alt mode with the setting off", function()
    local box = NewEditBox()
    local db = { chatHistoryEnabled = false, chatHistoryLines = { "old" } }
    WithChat(box, function(ChatHistory)
      ChatHistory.Setup(db)
      Assert.Equal(#box.history, 0, "saved lines are not restored")
      Assert.Equal(box.altArrow, true, "game Alt mode stays")
      box:AddHistoryLine("secret plan")
      box:Fire("OnEditFocusGained")
      box:SetText("/console y", true)
      box:Fire("OnEnterPressed")
      Assert.Equal(#db.chatHistoryLines, 1, "nothing saved")
      db.chatHistoryEnabled = true
      ChatHistory.Apply()
      Assert.Equal(box.altArrow, false, "switching on applies at once")
    end)
  end)
end
