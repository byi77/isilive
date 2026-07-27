---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function LoadErrorLog(globals)
    local addon
    WithGlobals(globals or {}, function()
      addon = LoadAddonModules({ "isiLive_error_log.lua" })
    end)
    return addon.ErrorLog
  end

  local function ResetIsiLiveDB()
    rawset(_G, "IsiLiveDB", {})
  end

  -- ----------------------------------------------------------------------
  -- Capture filter: only isiLive-mentioning errors land in the buffer
  -- ----------------------------------------------------------------------

  test("ErrorLog.Capture stores an error mentioning isiLive", function()
    ResetIsiLiveDB()
    local ErrorLog = LoadErrorLog()
    ErrorLog.Capture("isiLive: something broke", "stack-trace-with-isiLive-frame", nil)
    Assert.Equal(ErrorLog.GetCount(), 1, "isiLive-mentioning error must be captured")
  end)

  test("ErrorLog.Capture skips errors that do not mention isiLive (filter)", function()
    ResetIsiLiveDB()
    local ErrorLog = LoadErrorLog()
    ErrorLog.Capture("Plater: tooltip rendering failed", "Plater stack frame only", nil)
    ErrorLog.Capture("Blizzard UI: SetPoint failed", "FrameXML/Frame.lua:42", nil)
    Assert.Equal(ErrorLog.GetCount(), 0, "non-isiLive errors must be filtered out")
  end)

  test("ErrorLog.Capture detects isiLive in stack trace even if message does not mention it", function()
    ResetIsiLiveDB()
    local ErrorLog = LoadErrorLog()
    ErrorLog.Capture("attempt to index nil value", "Interface\\AddOns\\isiLive\\logic\\foo.lua:10", nil)
    Assert.Equal(ErrorLog.GetCount(), 1, "stack-frame-detected isiLive error must be captured")
  end)

  -- ----------------------------------------------------------------------
  -- Dedup: identical errors increment the count, do not duplicate
  -- ----------------------------------------------------------------------

  test("ErrorLog.Capture deduplicates identical errors via count++", function()
    ResetIsiLiveDB()
    local ErrorLog = LoadErrorLog()
    for _ = 1, 50 do
      ErrorLog.Capture("isiLive: storm", "isiLive-stack-A", nil)
    end
    Assert.Equal(ErrorLog.GetCount(), 1, "50 identical errors must collapse to 1 entry")
    local entries = ErrorLog.GetTail(10)
    Assert.Equal(entries[1].count, 50, "count must be 50")
  end)

  test("ErrorLog.Capture creates separate entries for different errors", function()
    ResetIsiLiveDB()
    local ErrorLog = LoadErrorLog()
    ErrorLog.Capture("isiLive: error A", "isiLive-stack-A", nil)
    ErrorLog.Capture("isiLive: error B", "isiLive-stack-B", nil)
    Assert.Equal(ErrorLog.GetCount(), 2, "different errors must be distinct entries")
  end)

  -- ----------------------------------------------------------------------
  -- Bounded ring: cap at MAX_ENTRIES
  -- ----------------------------------------------------------------------

  test("ErrorLog enforces MAX_ENTRIES cap (100)", function()
    ResetIsiLiveDB()
    local ErrorLog = LoadErrorLog()
    Assert.Equal(ErrorLog.GetMaxEntries(), 100, "MAX_ENTRIES must be 100")
    -- Push 150 distinct errors to exceed the cap.
    for i = 1, 150 do
      ErrorLog.Capture(string.format("isiLive: error %d", i), string.format("isiLive-stack-%d", i), nil)
    end
    Assert.True(ErrorLog.GetCount() <= 100, "ring buffer must cap at 100 entries")
  end)

  -- ----------------------------------------------------------------------
  -- Chain-of-responsibility: previous handler is always called
  -- ----------------------------------------------------------------------

  test("ErrorLog.Install chains to previous error handler", function()
    ResetIsiLiveDB()
    local previousCalls = {}
    local previousHandler = function(message)
      previousCalls[#previousCalls + 1] = message
    end
    local installedHandler
    -- Install() reads geterrorhandler/seterrorhandler from _G, so the call
    -- must happen INSIDE the WithGlobals scope (otherwise the test globals
    -- are gone by the time Install() runs).
    WithGlobals({
      geterrorhandler = function()
        return previousHandler
      end,
      seterrorhandler = function(h)
        installedHandler = h
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_error_log.lua" })
      addon.ErrorLog.Install()
      Assert.Equal(addon.ErrorLog.IsInstalled(), true, "Install() must mark installed")
      Assert.Equal(type(installedHandler), "function", "seterrorhandler must receive a function")
      installedHandler("isiLive: test error")
      Assert.Equal(#previousCalls, 1, "previous handler must be called")
      Assert.Equal(previousCalls[1], "isiLive: test error", "previous handler must receive the error message")
    end)
  end)

  test("ErrorLog.Install is idempotent", function()
    ResetIsiLiveDB()
    local setCalls = 0
    WithGlobals({
      geterrorhandler = function()
        return nil
      end,
      seterrorhandler = function()
        setCalls = setCalls + 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_error_log.lua" })
      addon.ErrorLog.Install()
      addon.ErrorLog.Install()
      addon.ErrorLog.Install()
      Assert.Equal(setCalls, 1, "seterrorhandler must be called exactly once across multiple Install() calls")
    end)
  end)

  -- ----------------------------------------------------------------------
  -- Boundary: missing globals
  -- ----------------------------------------------------------------------

  test("ErrorLog.Install no-ops when geterrorhandler is missing", function()
    ResetIsiLiveDB()
    WithGlobals({
      geterrorhandler = false, -- explicit nil-out via false-sentinel pattern
      seterrorhandler = false,
    }, function()
      local addon = LoadAddonModules({ "isiLive_error_log.lua" })
      local ok = pcall(addon.ErrorLog.Install)
      Assert.True(ok, "Install() must not throw when error-handler globals are absent")
      Assert.Equal(addon.ErrorLog.IsInstalled(), false, "IsInstalled() must report false")
    end)
  end)

  test("ErrorLog.Capture handles nil IsiLiveDB gracefully", function()
    rawset(_G, "IsiLiveDB", nil)
    local ErrorLog = LoadErrorLog()
    local ok = pcall(ErrorLog.Capture, "isiLive: error", "isiLive-stack", nil)
    Assert.True(ok, "Capture must not throw when IsiLiveDB is nil")
  end)

  -- ----------------------------------------------------------------------
  -- GetTail / Clear / GetCount API
  -- ----------------------------------------------------------------------

  test("ErrorLog.GetTail returns the most recent entries", function()
    ResetIsiLiveDB()
    local ErrorLog = LoadErrorLog()
    for i = 1, 5 do
      ErrorLog.Capture(string.format("isiLive: error %d", i), string.format("isiLive-stack-%d", i), nil)
    end
    local tail = ErrorLog.GetTail(3)
    Assert.Equal(#tail, 3, "GetTail(3) must return 3 entries")
    Assert.Equal(tail[#tail].message, "isiLive: error 5", "last entry must be the most recent")
  end)

  test("ErrorLog.GetTail clamps limit to [1, 100]", function()
    ResetIsiLiveDB()
    local ErrorLog = LoadErrorLog()
    for i = 1, 10 do
      ErrorLog.Capture(string.format("isiLive: error %d", i), string.format("isiLive-stack-%d", i), nil)
    end
    Assert.Equal(#ErrorLog.GetTail(0), 1, "limit 0 clamps to 1")
    Assert.Equal(#ErrorLog.GetTail(1000), 10, "limit 1000 clamps to total count")
  end)

  test("ErrorLog.Clear empties the buffer", function()
    ResetIsiLiveDB()
    local ErrorLog = LoadErrorLog()
    ErrorLog.Capture("isiLive: error", "isiLive-stack", nil)
    Assert.Equal(ErrorLog.GetCount(), 1, "pre-Clear count")
    ErrorLog.Clear()
    Assert.Equal(ErrorLog.GetCount(), 0, "post-Clear count must be 0")
  end)

  -- ----------------------------------------------------------------------
  -- Schema-sanitizer integration: maxMapEntries trim on errorLog
  -- ----------------------------------------------------------------------

  test("DBSchema sanitizer trims errorLog when over maxMapEntries cap", function()
    local addon = LoadAddonModules({ "isiLive_db_schema.lua" })
    local DBSchema = addon.DBSchema
    -- Fabricate an oversized errorLog with 250 entries (cap is 200 in schema).
    local oversized = {}
    for i = 1, 250 do
      oversized[i] = { message = "fake-" .. i, count = 1 }
    end
    local db = { errorLog = oversized }
    DBSchema.Sanitize(db)
    local count = 0
    for _ in pairs(db.errorLog) do
      count = count + 1
    end
    Assert.True(count <= 200, "errorLog must be trimmed to <= 200 by sanitizer")
  end)

  test("DBSchema sanitizer trims rioBaseline when over maxMapEntries cap", function()
    local addon = LoadAddonModules({ "isiLive_db_schema.lua" })
    local DBSchema = addon.DBSchema
    -- Simulate a rioBaseline that grew to 6000 entries (cap is 5000).
    local oversized = {}
    for i = 1, 6000 do
      oversized["Player" .. i .. "-Realm"] = 2400
    end
    local db = { rioBaseline = oversized }
    DBSchema.Sanitize(db)
    local count = 0
    for _ in pairs(db.rioBaseline) do
      count = count + 1
    end
    Assert.True(count <= 5000, "rioBaseline must be trimmed to <= 5000 by sanitizer")
  end)

  test("DBSchema sanitizer trims stats.playerLastRunByCharacter when over cap", function()
    local addon = LoadAddonModules({ "isiLive_db_schema.lua" })
    local DBSchema = addon.DBSchema
    local oversized = {}
    for i = 1, 5500 do
      oversized["Player" .. i .. "-Realm"] = { dps = 2000000 }
    end
    local db = { stats = { playerLastRunByCharacter = oversized } }
    DBSchema.Sanitize(db)
    local count = 0
    for _ in pairs(db.stats.playerLastRunByCharacter) do
      count = count + 1
    end
    Assert.True(count <= 5000, "playerLastRunByCharacter must be trimmed to <= 5000")
  end)

  test("DBSchema sanitizer leaves under-cap maps untouched", function()
    local addon = LoadAddonModules({ "isiLive_db_schema.lua" })
    local DBSchema = addon.DBSchema
    local intact = {}
    for i = 1, 100 do
      intact["Player" .. i .. "-Realm"] = 2400
    end
    local db = { rioBaseline = intact }
    DBSchema.Sanitize(db)
    local count = 0
    for _ in pairs(db.rioBaseline) do
      count = count + 1
    end
    Assert.Equal(count, 100, "under-cap rioBaseline must be preserved exactly")
  end)

  test("DBSchema sanitizer logs trim action via callback", function()
    local addon = LoadAddonModules({ "isiLive_db_schema.lua" })
    local DBSchema = addon.DBSchema
    local oversized = {}
    for i = 1, 6000 do
      oversized["Player" .. i .. "-Realm"] = 2400
    end
    local db = { rioBaseline = oversized }
    local trimMessages = {}
    DBSchema.Sanitize(db, function(msg)
      if type(msg) == "string" and msg:find("trimmed", 1, true) then
        trimMessages[#trimMessages + 1] = msg
      end
    end)
    Assert.True(#trimMessages > 0, "trim action must be logged via callback")
    Assert.True(trimMessages[1]:find("rioBaseline", 1, true) ~= nil, "trim log must name the trimmed field")
  end)

  -- ----------------------------------------------------------------------
  -- Branch coverage for timestamp helpers, MentionsIsiLive case-insensitivity,
  -- CaptureStack happy path, and the inner-pcall fallback when capture itself
  -- raises.
  -- ----------------------------------------------------------------------

  test("ErrorLog.Capture prefers the cross-session time() epoch over GetTime()", function()
    ResetIsiLiveDB()
    local unixNow = 1782000000
    WithGlobals({
      time = function()
        return unixNow
      end,
      GetTime = function()
        return 12345.678 -- session-relative, must NOT win
      end,
      date = function(fmt)
        return fmt == "%H:%M:%S" and "11:22:33" or "2026-05-06 11:22:33"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_error_log.lua" })
      addon.ErrorLog.Capture("isiLive: bang", "isiLive-stack-T", nil)
      local entries = addon.ErrorLog.GetTail(1)
      Assert.Equal(entries[1].firstSeen, unixNow, "firstSeen must use the Unix epoch from time()")
      Assert.Equal(entries[1].lastSeen, unixNow, "lastSeen must use the Unix epoch from time()")
      Assert.Equal(
        entries[1].firstSeenDisplay,
        "2026-05-06 11:22:33",
        "firstSeenDisplay must use date('%Y-%m-%d %H:%M:%S')"
      )
    end)
  end)

  test("ErrorLog.Capture falls back to GetTime() when time() is unavailable", function()
    ResetIsiLiveDB()
    local now = 12345.678
    WithGlobals({
      time = false, -- removes the time() branch entirely
      GetTime = function()
        return now
      end,
      date = function(fmt)
        return fmt == "%H:%M:%S" and "11:22:33" or "2026-05-06 11:22:33"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_error_log.lua" })
      addon.ErrorLog.Capture("isiLive: bang", "isiLive-stack-T", nil)
      local entries = addon.ErrorLog.GetTail(1)
      Assert.Equal(entries[1].firstSeen, now, "firstSeen must fall back to the numeric GetTime() value")
    end)
  end)

  -- Regression guard: lastSeen is the TrimToCap eviction key AND is persisted
  -- into SavedVariables. A non-numeric stamp collapses to 0 in TrimToCap and
  -- would make that entry the permanent eviction victim.
  test("ErrorLog.Capture timestamps stay numeric when neither time() nor GetTime() is available", function()
    ResetIsiLiveDB()
    WithGlobals({
      time = false,
      GetTime = false,
      date = function(fmt)
        return fmt == "%H:%M:%S" and "09:08:07" or "2026-05-06 09:08:07"
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_error_log.lua" })
      addon.ErrorLog.Capture("isiLive: bang", "isiLive-stack-T", nil)
      local entries = addon.ErrorLog.GetTail(1)
      Assert.Equal(type(entries[1].firstSeen), "number", "firstSeen must never be a string")
      Assert.Equal(type(entries[1].lastSeen), "number", "lastSeen must never be a string")
      Assert.Equal(entries[1].firstSeenDisplay, "2026-05-06 09:08:07", "human-readable display still comes from date()")
    end)
  end)

  -- Regression guard for the eviction-order bug: entries carried over from a
  -- previous session (old GetTime() epoch, small numbers) must be evicted
  -- BEFORE freshly captured ones, not the other way round.
  test("ErrorLog trims legacy GetTime-epoch entries before fresh time()-epoch entries", function()
    ResetIsiLiveDB()
    WithGlobals({
      time = function()
        return 1782000000
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_error_log.lua" })
      local db = rawget(_G, "IsiLiveDB")
      db.errorLog = {}
      -- Simulate a previous session: GetTime()-epoch stamps.
      for i = 1, addon.ErrorLog.GetMaxEntries() do
        db.errorLog[i] = {
          message = string.format("isiLive: legacy %d", i),
          fullText = string.format("isiLive-legacy-stack-%d", i),
          count = 1,
          firstSeen = i,
          lastSeen = i,
        }
      end
      addon.ErrorLog.Capture("isiLive: fresh error", "isiLive-fresh-stack", nil)
      Assert.Equal(addon.ErrorLog.GetCount(), addon.ErrorLog.GetMaxEntries(), "cap must still hold")
      local survived = false
      for _, entry in ipairs(addon.ErrorLog.GetTail(addon.ErrorLog.GetMaxEntries())) do
        if entry.fullText == "isiLive-fresh-stack" then
          survived = true
        end
      end
      Assert.True(survived, "the freshly captured error must survive the trim, not be evicted first")
    end)
  end)

  test("ErrorLog.Capture matches isiLive case-insensitively in the message text", function()
    ResetIsiLiveDB()
    local ErrorLog = LoadErrorLog()
    -- "ISILIVE" upper-case in the message — first-pass `find` misses (FILTER_TOKEN
    -- is "isiLive"), but the lower-case branch must catch it.
    ErrorLog.Capture("ERROR FROM ISILIVE: boom", "no-match-stack", nil)
    Assert.Equal(ErrorLog.GetCount(), 1, "case-insensitive lower-case branch must catch upper-case isiLive mentions")
  end)

  test("ErrorLog.Capture stack capture falls back to plain message when debug.traceback is unavailable", function()
    ResetIsiLiveDB()
    -- No `stack` arg passed (stack=nil). CaptureStack triggers; with debug.traceback
    -- unavailable it falls back to tostring(message). The message itself contains
    -- "isiLive" so MentionsIsiLive matches. Mutate debug.traceback in place so
    -- luacov's debug.sethook stays intact for instrumentation.
    local debugLib = rawget(_G, "debug")
    local originalTraceback = debugLib and debugLib.traceback or nil
    if type(debugLib) == "table" then
      debugLib.traceback = "not-a-function"
    end

    local addon = LoadAddonModules({ "isiLive_error_log.lua" })
    addon.ErrorLog.Capture("isiLive: boom without stack", nil, nil)

    if type(debugLib) == "table" then
      debugLib.traceback = originalTraceback
    end

    Assert.Equal(addon.ErrorLog.GetCount(), 1, "must capture even when debug.traceback is unavailable")
    local entries = addon.ErrorLog.GetTail(1)
    Assert.Equal(
      entries[1].fullText,
      "isiLive: boom without stack",
      "fullText falls back to tostring(message) when no traceback"
    )
  end)

  test("ErrorLog.Capture stack capture uses debug.traceback when it is callable", function()
    ResetIsiLiveDB()
    -- Wrap (not replace) debug.traceback so luacov's debug.sethook keeps working.
    local debugLib = rawget(_G, "debug")
    local originalTraceback = debugLib and debugLib.traceback or nil
    if type(debugLib) == "table" then
      debugLib.traceback = function(msg, _level)
        return tostring(msg) .. "\n[mock-stack-frame] isiLive"
      end
    end

    local addon = LoadAddonModules({ "isiLive_error_log.lua" })
    -- Message mentions isiLive, so the filter accepts it without the probe;
    -- this pins that the stored fullText still carries the traceback output.
    addon.ErrorLog.Capture("isiLive: plain bang", nil, nil)

    if type(debugLib) == "table" then
      debugLib.traceback = originalTraceback
    end

    Assert.Equal(addon.ErrorLog.GetCount(), 1, "isiLive-mentioning message must be captured")
    local entries = addon.ErrorLog.GetTail(1)
    Assert.True(
      entries[1].fullText:find("[mock-stack-frame] isiLive", 1, true) ~= nil,
      "fullText must include the debug.traceback output"
    )
  end)

  -- ----------------------------------------------------------------------
  -- Live-path filter: Install() routes EVERY addon's errors through
  -- Capture(stack=nil). The isiLive frame probe must reject foreign errors
  -- WITHOUT building a traceback first.
  -- ----------------------------------------------------------------------

  -- Builds a caller whose chunk source is `sourceName` and runs it on its own
  -- coroutine stack. The coroutine matters: debug.getinfo walks only the
  -- current coroutine, so the probe sees exactly [error-log frames, caller]
  -- instead of also seeing this scenario file -- whose own name contains
  -- "isilive" and would make every probe assertion pass vacuously.
  --
  -- Lua 5.1 (WoW client and CI) compiles source strings via loadstring(); its
  -- load() takes a reader FUNCTION and silently fails on a string. Lua 5.4
  -- (local tooling) dropped loadstring() and accepts the string in load().
  -- Bridge both, otherwise these scenarios pass locally and fail in CI.
  local CompileChunk = rawget(_G, "loadstring") or load

  local function CaptureFromChunk(Capture, sourceName, message)
    local chunk =
      CompileChunk("local Capture, message = ... return function() Capture(message, nil, nil) end", "=" .. sourceName)
    Assert.Equal(type(chunk), "function", "caller chunk must compile: " .. sourceName)
    coroutine.wrap(chunk(Capture, message))()
  end

  test("ErrorLog.Capture rejects a foreign error raised from a non-isiLive frame (stack=nil)", function()
    ResetIsiLiveDB()
    local addon = LoadAddonModules({ "isiLive_error_log.lua" })
    CaptureFromChunk(addon.ErrorLog.Capture, "Interface/AddOns/Plater/Plater.lua", "Plater: tooltip rendering failed")
    Assert.Equal(addon.ErrorLog.GetCount(), 0, "a foreign frame must not pass the isiLive filter")
  end)

  test("ErrorLog.Capture accepts a foreign message raised from an isiLive frame (stack=nil)", function()
    ResetIsiLiveDB()
    local addon = LoadAddonModules({ "isiLive_error_log.lua" })
    -- Blizzard-side message (no isiLive token) but the call chain runs through
    -- isiLive code -- the v0.9.208 SetPoint(nil) crash class.
    CaptureFromChunk(
      addon.ErrorLog.Capture,
      "Interface/AddOns/isiLive/ui/isiLive_ui_main_frame.lua",
      "FrameXML/Frame.lua:42: bad argument"
    )
    Assert.Equal(addon.ErrorLog.GetCount(), 1, "an isiLive frame must pass the filter even with a foreign message")
  end)

  test("ErrorLog.Capture does not treat its own module frames as an isiLive match", function()
    ResetIsiLiveDB()
    local addon = LoadAddonModules({ "isiLive_error_log.lua" })
    -- isiLive_error_log.lua is always on the stack during Capture(). If its
    -- own frames counted, this foreign error would be captured -- which is
    -- exactly the regression this probe replaces.
    CaptureFromChunk(
      addon.ErrorLog.Capture,
      "Interface/AddOns/WeakAuras/WeakAuras.lua",
      "WeakAuras: aura update failed"
    )
    Assert.Equal(addon.ErrorLog.GetCount(), 0, "own error-log frames must be excluded from the probe")
  end)

  -- NOTE: the "debug.getinfo unavailable" guard in StackMentionsIsiLive has no
  -- scenario on purpose. luacov's debug hook resolves the GLOBAL `debug` table
  -- at call time (luacov/hook.lua), so both stubbing `_G.debug` and mutating
  -- `debug.getinfo` in place crash the instrumented coverage run. The guard
  -- fails closed by construction (returns false -> error is not captured),
  -- which is the safe direction.

  test("ErrorLog.Capture keeps message-based detection independent of the stack probe", function()
    ResetIsiLiveDB()
    local addon = LoadAddonModules({ "isiLive_error_log.lua" })
    -- Raised from a foreign frame, but the message itself names isiLive: the
    -- message branch must accept it without relying on the probe at all.
    CaptureFromChunk(
      addon.ErrorLog.Capture,
      "Interface/AddOns/Plater/Plater.lua",
      "isiLive: raised through a foreign call site"
    )
    Assert.Equal(addon.ErrorLog.GetCount(), 1, "message-based detection must work from any call site")
  end)
end
