-- Pinpoints the "background flickers and disappears after READY_CHECK_FINISHED" bug
-- by replacing the row.readyCheckBackground frame with a mock that records every
-- Show/Hide/SetColorTexture call. Then exercises the renders that follow FINISHED
-- (RefreshReadyCheckStateImpl + RenderRosterImpl + a follow-up RenderRosterImpl
-- triggered by a fake GROUP_ROSTER_UPDATE-like event) and asserts the row
-- background state at every step.
--
-- End-to-end discipline (CLAUDE.md "Tests & simulators: end-to-end by default"):
-- the real RenderRosterImpl + RefreshReadyCheckStateImpl from the production
-- render module are driven against frame mocks that record every Show/Hide/
-- SetColorTexture call. Asserts use the shared Check/os.exit(1) pattern so a
-- regression in the hold-after-FINISHED contract breaks CI rather than just
-- printing different log lines.
--
-- COMPONENT-ONLY exception (per CLAUDE.md): the simulator reaches into
-- _RosterPanelInternal via Reflection (`addon._RosterInternal or
-- addon._RosterPanelInternal`). The roster_panel module exposes its render
-- impl only through this internal table; no public surface accepts the
-- mock state object the test feeds. Documented here so future cleanup
-- knows the boundary leak is intentional.
---@diagnostic disable-next-line: undefined-global
local io = io
---@diagnostic disable-next-line: undefined-global
local load = load
---@diagnostic disable-next-line: undefined-global
local os = os

local function LoadLocal(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  local chunk, err = (loadstring or load)(source, "@" .. path)
  assert(chunk, err)
  return chunk()
end

local Harness = LoadLocal("testmodul/isilive_test_harness.lua")
local RosterMocks = LoadLocal("testmodul/isilive_test_render_roster_mocks.lua")

local failures = 0

local function Check(condition, message)
  if condition then
    print("  [CHECK PASS] " .. message)
    return
  end
  failures = failures + 1
  print("  [CHECK FAIL] " .. message)
end

-- Match against READY_CHECK_BACKGROUND_COLORS.r in roster.lua.
local LABEL_GREEN = "GREEN"
local LABEL_RED = "RED"
local LABEL_YELLOW = "YELLOW"
local LABEL_NONE = "(none)"

local function ColorLabelOf(color)
  if type(color) ~= "table" then
    return LABEL_NONE
  end
  if color[1] == 0.08 then
    return LABEL_GREEN
  elseif color[1] == 0.48 then
    return LABEL_RED
  elseif color[1] == 0.55 then
    return LABEL_YELLOW
  end
  return string.format("rgba(%.2f,%.2f,%.2f,%.2f)", color[1], color[2], color[3], color[4])
end

local function CountVisibleByColor(memberRows)
  local visible = 0
  local byColor = { [LABEL_GREEN] = 0, [LABEL_RED] = 0, [LABEL_YELLOW] = 0 }
  for i = 1, 5 do
    local bg = memberRows[i].readyCheckBackground
    if bg.visible then
      visible = visible + 1
      local label = ColorLabelOf(bg.lastColor)
      byColor[label] = (byColor[label] or 0) + 1
    end
  end
  return visible, byColor
end

local function ExpectVisibleCounts(memberRows, expectedVisible, expectedByColor, message)
  local visible, byColor = CountVisibleByColor(memberRows)
  local mismatches = {}
  if visible ~= expectedVisible then
    mismatches[#mismatches + 1] = string.format("visible=%d (expected %d)", visible, expectedVisible)
  end
  for label, expectedCount in pairs(expectedByColor) do
    if (byColor[label] or 0) ~= expectedCount then
      mismatches[#mismatches + 1] = string.format("%s=%d (expected %d)", label, byColor[label] or 0, expectedCount)
    end
  end
  Check(#mismatches == 0, message .. (mismatches[1] and (" — " .. table.concat(mismatches, ", ")) or ""))
end

-- Simulated state (same as the lifecycle simulator) ----------------------------------------
local sim = {
  now = 100,
  isReadyCheckActive = false,
  readyCheckStatus = {},
  readyUntilByUnit = {},
  declinedUntilByUnit = {},
}

local roster = {
  player = { name = "Tank", class = "WARRIOR", role = "TANK" },
  party1 = { name = "Healer", class = "PRIEST", role = "HEALER" },
  party2 = { name = "Dps1", class = "MAGE", role = "DAMAGER" },
  party3 = { name = "Dps2", class = "ROGUE", role = "DAMAGER" },
  party4 = { name = "Dps3", class = "WARLOCK", role = "DAMAGER" },
}

local rolePriority = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }
local unitPriority = { player = 1, party1 = 2, party2 = 3, party3 = 4, party4 = 5 }

-- Frame mock factories ----------------------------------------------------------------------

local frameLog = {}
local function LogFrame(slot, action, detail)
  table.insert(frameLog, string.format("    [%d] row=%s %s%s", #frameLog + 1, slot, action, detail or ""))
end

local function MakeBackgroundMock(slot)
  local mock = {
    visible = false,
    lastColor = nil,
  }
  function mock:Show()
    self.visible = true
    LogFrame(slot, "Background:Show", "")
  end
  function mock:Hide()
    self.visible = false
    LogFrame(slot, "Background:Hide", "")
  end
  function mock:SetColorTexture(r, g, b, a)
    self.lastColor = { r, g, b, a }
    LogFrame(slot, "Background:SetColorTexture", string.format(" rgba=(%.2f,%.2f,%.2f,%.2f)", r, g, b, a))
  end
  function mock:SetAllPoints() end
  return mock
end

local NoOp = RosterMocks.NoOp
local MakeFontStringMock = RosterMocks.MakeFontStringMock
-- This sim instruments background mocks with frameLog; route them through
-- the shared MakeFrameMock via opts.makeTexture so background-from-frame
-- creation stays observable.
local function MakeFrameMock()
  return RosterMocks.MakeFrameMock({
    makeTexture = function()
      return MakeBackgroundMock("?")
    end,
  })
end

-- Build a memberRows table that already has 5 rows wired up with our mocks.
local function BuildMemberRows()
  local rows = {}
  for i = 1, 5 do
    local row = {
      readyCheckBackground = MakeBackgroundMock(i),
      hoverFrame = MakeFrameMock(),
      spec = MakeFontStringMock(),
      name = MakeFontStringMock(),
      realm = MakeFontStringMock(),
      key = MakeFontStringMock(),
      ilvl = MakeFontStringMock(),
      rio = MakeFontStringMock(),
      dps = MakeFontStringMock(),
      kick = MakeFontStringMock(),
      roleButton = nil,
      unit = nil,
    }
    rows[i] = row
  end
  return rows
end

-- Stub state object passed to RenderRosterImpl / RefreshReadyCheckStateImpl ------------------

local function BuildState(memberRows, addonRoster)
  return RosterMocks.BuildDefaultRenderState(memberRows, addonRoster, {
    mainFrame = MakeFrameMock(),
    shareKeysButton = (function()
      local btn = MakeFrameMock()
      btn.SetEnabled = NoOp
      btn.SetAlpha = NoOp
      btn.SetShareKeysAvailable = NoOp
      return btn
    end)(),
    rolePriority = rolePriority,
    unitPriority = unitPriority,
    isReadyCheckActive = function()
      return sim.isReadyCheckActive
    end,
    getReadyCheckReadyUntil = function(unit)
      return sim.readyUntilByUnit[unit]
    end,
    getReadyCheckDeclinedUntil = function(unit)
      return sim.declinedUntilByUnit[unit]
    end,
    getTime = function()
      return sim.now
    end,
  })
end

-- Run scenario -------------------------------------------------------------------------------

local function ResetLog()
  frameLog = {}
end

local function PrintLog(label)
  print(
    string.format(
      "\n---- %s [t=%d, active=%s, frameCallsRecorded=%d]",
      label,
      sim.now,
      tostring(sim.isReadyCheckActive),
      #frameLog
    )
  )
  for _, entry in ipairs(frameLog) do
    print(entry)
  end
end

local function PrintBackgroundStates(label, memberRows)
  print(string.format("\n>>> %s — current visible state of each row's background:", label))
  for i = 1, 5 do
    local bg = memberRows[i].readyCheckBackground
    local color = bg.lastColor
    local colorStr = color and string.format("rgba=(%.2f,%.2f,%.2f,%.2f)", color[1], color[2], color[3], color[4])
      or "(none)"
    print(string.format("    row[%d]: visible=%s color=%s", i, tostring(bg.visible), colorStr))
  end
end

Harness.WithGlobals({
  GetReadyCheckStatus = function(unit)
    return sim.readyCheckStatus[unit]
  end,
  -- GetReadyCheckStatusSafe bails out through Validators.IsExistingUnit before
  -- it reads any status, so every simulated unit has to exist. Without this
  -- stub every row reports visible=0 and no colour at all.
  UnitExists = function(unit)
    return roster[unit] ~= nil
  end,
  RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PRIEST = { r = 1, g = 1, b = 1 },
    MAGE = { r = 0.41, g = 0.8, b = 0.94 },
    ROGUE = { r = 1, g = 0.96, b = 0.41 },
    WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
  },
  CreateColor = function(r, g, b)
    return {
      GenerateHexColor = function()
        return string.format("ff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
      end,
    }
  end,
  UnitIsConnected = function()
    return true
  end,
  GetTime = function()
    return sim.now
  end,
  IsAddOnLoaded = function()
    return false
  end,
  C_AddOns = nil,
  GetAddOnMetadata = function()
    return nil
  end,
  CreateFrame = MakeFrameMock,
}, function()
  -- Load roster (provides Roster.BuildDisplayData + BuildOrderedRoster) and roster_panel_render.
  local addon = Harness.LoadAddonModules({ "isiLive_roster.lua", "isiLive_roster_panel_render.lua" })
  local RI = addon._RosterInternal or addon._RosterPanelInternal
  -- Try common internal table names; the render module exposes RI = RosterPanelInternal
  if not RI then
    -- Fallback: search addon table for RenderRosterImpl
    for _, v in pairs(addon) do
      if type(v) == "table" and type(v.RenderRosterImpl) == "function" then
        RI = v
        break
      end
    end
  end
  if not RI then
    error("could not locate RosterPanelInternal — render module did not expose RI")
  end

  local memberRows = BuildMemberRows()
  local state = BuildState(memberRows, addon)

  -- ===== Simulate the bug path =====
  print("========== Frame-mock reproducer for 'background flickers, disappears after FINISHED' ==========")

  -- Phase 1: ready check active, all "waiting"
  sim.isReadyCheckActive = true
  for unit in pairs(roster) do
    sim.readyCheckStatus[unit] = "waiting"
  end
  ResetLog()
  RI.RefreshReadyCheckStateImpl(state, roster)
  PrintLog("Phase 1: READY_CHECK fired → RefreshReadyCheckStateImpl (live: yellow for everyone)")
  PrintBackgroundStates("after phase 1", memberRows)
  ExpectVisibleCounts(memberRows, 5, { [LABEL_YELLOW] = 5 }, "phase 1: 5 yellow rows visible (all waiting)")

  -- Phase 2: confirms received
  sim.readyCheckStatus.player = "ready"
  sim.readyCheckStatus.party1 = "ready"
  sim.readyCheckStatus.party2 = "notready"
  -- party3 + party4 stay "waiting" (no answer)
  ResetLog()
  RI.RefreshReadyCheckStateImpl(state, roster)
  PrintLog("Phase 2: confirms in → RefreshReadyCheckStateImpl (live: green/red/yellow)")
  PrintBackgroundStates("after phase 2", memberRows)
  ExpectVisibleCounts(
    memberRows,
    5,
    { [LABEL_GREEN] = 2, [LABEL_RED] = 1, [LABEL_YELLOW] = 2 },
    "phase 2: 2 green (player+party1) + 1 red (party2) + 2 yellow (party3+4 no-answer)"
  )

  -- Phase 3: READY_CHECK_FINISHED — simulate post-finish state.
  -- WoW clears the live status and the event handler promotes ready/declined to hold.
  sim.now = sim.now + 3
  sim.isReadyCheckActive = false
  for unit in pairs(sim.readyCheckStatus) do
    sim.readyCheckStatus[unit] = nil
  end
  -- player + party1 → ready hold
  sim.readyUntilByUnit.player = sim.now + 20
  sim.readyUntilByUnit.party1 = sim.now + 20
  -- party2 → declined hold (explicit notready)
  sim.declinedUntilByUnit.party2 = sim.now + 20
  -- party3 + party4 → declined hold (promoted from waiting)
  sim.declinedUntilByUnit.party3 = sim.now + 20
  sim.declinedUntilByUnit.party4 = sim.now + 20

  ResetLog()
  RI.RefreshReadyCheckStateImpl(state, roster)
  PrintLog("Phase 3a: READY_CHECK_FINISHED → RefreshReadyCheckStateImpl (hold: green/red)")
  PrintBackgroundStates("after phase 3a (hold should be ON)", memberRows)
  ExpectVisibleCounts(
    memberRows,
    5,
    { [LABEL_GREEN] = 2, [LABEL_RED] = 3 },
    "phase 3a: 2 green (held ready) + 3 red (declined-promotion incl. no-answer)"
  )

  -- Phase 4: simulate a follow-up generic UI rerender — this is what the user
  -- sees as "background disappears". A GROUP_ROSTER_UPDATE-like event, or
  -- INSPECT_READY, or any ChatMsgAddon → ctx.updateUI() → RenderRosterImpl.
  -- This is the regression pin for the "hold flickers off after FINISHED" bug:
  -- if a renderer side-path ever overrides the hold, this assert fails.
  ResetLog()
  RI.RenderRosterImpl(state, roster)
  PrintLog("Phase 3b: follow-up RenderRosterImpl (the suspected override path)")
  PrintBackgroundStates("after phase 3b — IS THE HOLD STILL ON?", memberRows)
  ExpectVisibleCounts(
    memberRows,
    5,
    { [LABEL_GREEN] = 2, [LABEL_RED] = 3 },
    "phase 3b: hold survives a follow-up RenderRosterImpl (regression pin)"
  )

  -- Phase 5: another follow-up shortly after
  sim.now = sim.now + 2
  ResetLog()
  RI.RenderRosterImpl(state, roster)
  PrintLog("Phase 3c: another RenderRosterImpl 2s later")
  PrintBackgroundStates("after phase 3c", memberRows)
  ExpectVisibleCounts(
    memberRows,
    5,
    { [LABEL_GREEN] = 2, [LABEL_RED] = 3 },
    "phase 3c: hold still on after a second follow-up RenderRosterImpl"
  )
end)

if failures > 0 then
  print(string.format("\nReady-check frame-overrides simulator failed: %d check(s) failed", failures))
  os.exit(1)
end

print("\nReady-check frame-overrides simulator passed.")
