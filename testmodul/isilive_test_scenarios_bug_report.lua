---@diagnostic disable: undefined-global

-- Bug report export (rule 254, logic/isiLive_bug_report.lua and
-- ui/isiLive_bug_report_window.lua).

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  local function Contains(text, needle)
    return tostring(text):find(needle, 1, true) ~= nil
  end

  -- Group of the player Isi (realm Blackmoore) with Anna-Tichondrius in party1.
  local function GroupEnv(extra)
    local env = {
      getBuildInfo = function()
        return "12.0.5", "64321"
      end,
      getLocale = function()
        return "deDE"
      end,
      dateFn = function()
        return "2026-11-18 20:00:00"
      end,
      unitName = function(unit)
        if unit == "player" then
          return "Isi", nil
        elseif unit == "party1" then
          return "Anna", "Tichondrius"
        end
        return nil
      end,
      getNumGroupMembers = function()
        return 2
      end,
      isInRaid = function()
        return false
      end,
      getRealmName = function()
        return "Blackmoore"
      end,
      errorLog = {
        GetTail = function()
          return {}
        end,
      },
    }
    for key, value in pairs(extra or {}) do
      env[key] = value
    end
    return env
  end

  test("BugReport replaces character names with SELF and P pseudonyms", function()
    local BugReport = LoadAddonModules({ "isiLive_bug_report.lua" }).BugReport
    local text = BugReport.BuildText(GroupEnv({
      runtimeLines = {
        "seq=1 t=1.0 [ROSTER] event=member_joined unit=party1 name=Anna class=MAGE",
        "seq=2 t=2.0 [SHAREKEYS] event=received sender=Felix-Tichondrius",
        "seq=3 t=3.0 [SYNC] event=send_ack target=Felix sent=true",
        "seq=4 t=4.0 [SEASON] event=instance name=Ara-Kara type=party",
        "seq=5 t=5.0 [LFG] event=listing leader=Isi-Blackmoore mapID=2660",
        "seq=6 t=6.0 [DPS] event=row unit=party2 name=Müller realm=Blackmoore",
        "seq=7 t=7.0 [UI] event=btn_click name=Minimap leader=nil",
      },
      errorLog = {
        GetTail = function()
          return {
            { message = "isiLive_group.lua:12: bad Anna", count = 2, firstSeenDisplay = "a", lastSeenDisplay = "b" },
          }
        end,
      },
    }))
    Assert.False(Contains(text, "Anna"), "group member name is replaced everywhere")
    Assert.False(Contains(text, "Felix"), "a sender name is replaced, also as a bare token")
    Assert.False(Contains(text, "Isi-"), "own name is replaced")
    Assert.False(Contains(text, "Müller"), "UTF-8 name from a [DPS] line is replaced")
    Assert.False(Contains(text, "Blackmoore"), "own realm is replaced")
    Assert.True(Contains(text, "name=P1 class=MAGE"), "first other name becomes P1")
    Assert.True(Contains(text, "sender=P2"), "second other name becomes P2")
    Assert.True(Contains(text, "target=P2 sent=true"), "the same name keeps its pseudonym")
    Assert.True(Contains(text, "leader=SELF"), "own name becomes SELF")
    Assert.True(Contains(text, "name=Ara-Kara"), "a dungeon name outside the name fields stays")
    Assert.True(Contains(text, "name=Minimap leader=nil"), "placeholders and button names stay")
    Assert.True(Contains(text, "realm=REALM"), "the own realm becomes REALM")
    Assert.True(Contains(text, "bad P1"), "errors are scrubbed too")
    Assert.True(Contains(text, "(x2)"), "error repeat count is kept")
    Assert.True(Contains(text, "client=12.0.5 build=64321 locale=deDE"), "header names the client")
  end)

  test("BugReport keeps errors and drops the oldest runtime lines past the size cap", function()
    local BugReport = LoadAddonModules({ "isiLive_bug_report.lua" }).BugReport
    local lines = {}
    for i = 1, 400 do
      lines[i] = string.format("seq=%d t=%d.0 [RUNTIME] event=tick n=%d", i, i, i)
    end
    local text, stats = BugReport.BuildText(GroupEnv({
      runtimeLines = lines,
      maxTextBytes = 4000,
      errorLog = {
        GetTail = function()
          return { { message = "isiLive.lua:1: boom", count = 1 } }
        end,
      },
    }))
    Assert.True(#text <= 4000, "report stays within the cap")
    Assert.True(Contains(text, "boom"), "errors always stay")
    Assert.True(Contains(text, "seq=400 "), "the newest line stays")
    Assert.False(Contains(text, "seq=1 "), "the oldest line is dropped")
    Assert.Equal(stats.runtimeLinesTotal, 400, "total line count is reported")
    Assert.True(stats.runtimeLines < 400 and stats.runtimeLines > 0, "kept line count is reported")
    local seqA = tonumber(text:match("seq=(%d+) t=[%d%.]+ %[RUNTIME%] event=tick n=%d+\n"))
    Assert.True(seqA ~= nil and seqA == 400 - stats.runtimeLines + 1, "kept lines stay in log order")
  end)

  test("BugReport encodes gzip and Base64 between prefix and suffix and fails closed", function()
    local BugReport = LoadAddonModules({ "isiLive_bug_report.lua" }).BugReport
    local seenMethod = nil
    local encodingUtil = {
      CompressString = function(text, method)
        seenMethod = method
        return "Z(" .. text .. ")"
      end,
      EncodeBase64 = function(data)
        return "B64[" .. data .. "]"
      end,
    }
    local enum = { CompressionMethod = { Deflate = 0, Zlib = 1, Gzip = 2 } }
    local encoded = BugReport.Encode("hello", { encodingUtil = encodingUtil, enum = enum })
    Assert.Equal(encoded, "!isiLive:1!B64[Z(hello)]!End:isiLive:1!", "prefix, payload, suffix")
    Assert.Equal(seenMethod, 2, "gzip is read from Enum.CompressionMethod")

    local missing, reason = BugReport.Encode("hello", { encodingUtil = {}, enum = enum })
    Assert.Nil(missing, "no string without the encoding API")
    Assert.Equal(reason, "encoding_unavailable", "reason names the missing API")
    local noGzip, reason2 = BugReport.Encode("hello", { encodingUtil = encodingUtil, enum = {} })
    Assert.Nil(noGzip, "no string without the gzip enum")
    Assert.Equal(reason2, "encoding_unavailable", "missing enum is the same reason")
  end)

  test("BugReport /isilive report opens the copy window with URL and selected string", function()
    local frames = {}
    local function NewRegion()
      local region = { points = {}, text = nil }
      local function noop() end
      setmetatable(region, {
        __index = function(_, key)
          return noop
        end,
      })
      function region.SetText(self, text)
        self.text = text
      end
      function region.GetText(self)
        return self.text
      end
      function region.CreateFontString(_self)
        return NewRegion()
      end
      function region.CreateTexture(_self)
        return NewRegion()
      end
      function region.SetFocus(self)
        self.focused = true
      end
      function region.HighlightText(self)
        self.highlighted = true
      end
      function region.Show(self)
        self.shown = true
      end
      function region.Hide(self)
        self.shown = false
      end
      return region
    end
    local printed = {}
    WithGlobals({
      SlashCmdList = {},
      UIParent = NewRegion(),
      UISpecialFrames = {},
      CreateFrame = function()
        local frame = NewRegion()
        frames[#frames + 1] = frame
        return frame
      end,
      C_EncodingUtil = {
        CompressString = function(text)
          return text
        end,
        EncodeBase64 = function(data)
          return "QUJD" .. tostring(#data)
        end,
      },
      Enum = { CompressionMethod = { Gzip = 2 } },
      UnitName = function()
        return "Isi"
      end,
      GetNumGroupMembers = function()
        return 0
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_commands.lua", "isiLive_bug_report_window.lua" })
      addon.Commands.RegisterSlashCommands({
        printFn = function(line)
          printed[#printed + 1] = line
        end,
      })
      SlashCmdList["ISILIVE"]("report")
      local window = addon.BugReportWindow.GetFrame()
      Assert.NotNil(window, "the command opens the window")
      Assert.True(window.shown, "window is shown")
      Assert.Equal(window.urlBox:GetText(), addon.BugReport.REPORT_URL, "URL box carries the report page")
      local code = window.codeBox:GetText()
      Assert.True(code:find("^!isiLive:1!QUJD") ~= nil, "string box carries the export string")
      Assert.True(code:find("!End:isiLive:1!$") ~= nil, "export string ends with the suffix")
      Assert.True(window.codeBox.focused and window.codeBox.highlighted, "string is focused and selected")
    end)
    Assert.Equal(#printed, 0, "no chat output on success")
  end)
end
