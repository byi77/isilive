-- Standalone CLI tool: regression pin for the Mark-T/H role-marker macro.
--
-- Hard contract enforced by this simulator (see CLAUDE.md "Role-marker click
-- feature: target by character name"):
--
--   * The macro must target by CHARACTER NAME, never by unit token.
--     /target party1 is broken in WoW 12.0.5 (party tokens are secret unit
--     tokens; the slash command silently fails from secure macros).
--   * Same-realm units use bare "/target Name", cross-realm units use
--     "/target Name-Realm" — same shape as the existing whisper code.
--   * UTF-8 character names are passed through byte-for-byte. WoW's slash-
--     command parser handles Müller / Sébastien / Юрий / José / Çağrı /
--     Lucía / Aleksandr natively. We must NOT normalize or transliterate.
--   * One guarded block per role, tank before healer:
--     /cleartarget, /target <name>, /tm [exists] <n>, /targetlasttarget.
--   * A member without a name is skipped (no partial block); without tank and
--     healer the button carries no macro at all.
--   * The row role icons are display-only: no secure template, no mouse.
--
-- This drives the real RenderRosterImpl from roster_panel_render.lua against
-- frame mocks that capture every SetAttribute call on the Mark-T/H button.
-- The roster mixes locales and same-realm/cross-realm to catch any byte
-- mangling or token regression.
--
-- End-to-end discipline (CLAUDE.md "Tests & simulators: end-to-end by default"):
-- the real RenderRosterImpl is loaded; frame mocks record SetAttribute. Same
-- module-boundary exception as simulate_ready_check_frame_overrides.
---@diagnostic disable: undefined-global
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
local NoOp = RosterMocks.NoOp

local failures = 0

local function Check(condition, message)
  if condition then
    print("  [CHECK PASS] " .. message)
    return
  end
  failures = failures + 1
  print("  [CHECK FAIL] " .. message)
end

-- Expected macro for an ordered list of { name, marker } blocks.
local function Macro(blocks)
  local lines = {}
  for _, block in ipairs(blocks) do
    lines[#lines + 1] = "/cleartarget"
    lines[#lines + 1] = "/target " .. block[1]
    lines[#lines + 1] = "/tm [exists] " .. tostring(block[2])
    lines[#lines + 1] = "/targetlasttarget"
  end
  return table.concat(lines, "\n")
end

-- ----------------------------------------------------------------------
-- Sim-local mocks. The Mark-T/H button is created with
-- SecureActionButtonTemplate; production calls
-- SetAttribute("type1"|"type2"|"macrotext1"|"macrotext2"). Frame + font-string
-- mocks come from the shared testmodul/isilive_test_render_roster_mocks.lua.
-- ----------------------------------------------------------------------
local MakeFrameMock = RosterMocks.MakeFrameMock
local MakeFontStringMock = RosterMocks.MakeFontStringMock

-- Combat state for the InCombatLockdown stub installed in WithGlobals below.
-- roster_layout's IsCombatLockdownActive re-reads the global on every call, so
-- flipping this mid-scenario switches the production branch under test.
local inCombat = false
local function SetCombat(active)
  inCombat = active and true or false
end

-- The Mark-T/H button is a SecureActionButtonTemplate frame, i.e. protected.
-- The real client refuses Show / Hide / SetAttribute / EnableMouse /
-- re-anchoring on it from addon code during combat lockdown: the call does not
-- run and ADDON_ACTION_BLOCKED fires. The mock reproduces both halves -- no
-- state change, and a recorded violation -- so a production path that relies
-- on a blocked call cannot pass here while failing in game.
local function MakeMarkButtonMock()
  local mock = {
    _attributes = {},
    _shown = true,
    _blockedCalls = 0,
    _attributeWrites = 0,
  }
  local function Blocked(self)
    if inCombat then
      self._blockedCalls = self._blockedCalls + 1
      return true
    end
    return false
  end
  function mock:SetAttribute(key, value)
    if Blocked(self) then
      return
    end
    self._attributeWrites = self._attributeWrites + 1
    self._attributes[key] = value
  end
  function mock:GetAttribute(key)
    return self._attributes[key]
  end
  function mock:Show()
    if not Blocked(self) then
      self._shown = true
    end
  end
  function mock:Hide()
    if not Blocked(self) then
      self._shown = false
    end
  end
  function mock:EnableMouse()
    Blocked(self)
  end
  function mock:SetSize()
    Blocked(self)
  end
  function mock:SetPoint()
    Blocked(self)
  end
  return mock
end

-- Display-only row role icon: a plain frame, free to Show/Hide in combat.
local function MakeRoleIconMock()
  local mock = {
    _shown = false,
    _mouseEnabled = false,
    icon = {
      SetAllPoints = NoOp,
      SetTexture = NoOp,
      SetTexCoord = NoOp,
    },
  }
  function mock:Show()
    self._shown = true
  end
  function mock:Hide()
    self._shown = false
  end
  function mock:EnableMouse(flag)
    self._mouseEnabled = flag and true or false
  end
  return mock
end

local function MakeBackgroundMock()
  return {
    visible = false,
    Show = function(self)
      self.visible = true
    end,
    Hide = function(self)
      self.visible = false
    end,
    SetColorTexture = NoOp,
    SetAllPoints = NoOp,
    SetPoint = NoOp,
  }
end

local function BuildMemberRows()
  local rows = {}
  for i = 1, 5 do
    rows[i] = {
      roleIcon = MakeRoleIconMock(),
      readyCheckBackground = MakeBackgroundMock(),
      hoverFrame = MakeFrameMock(),
      spec = MakeFontStringMock(),
      name = MakeFontStringMock(),
      realm = MakeFontStringMock(),
      key = MakeFontStringMock(),
      ilvl = MakeFontStringMock(),
      rio = MakeFontStringMock(),
      dps = MakeFontStringMock(),
      kick = MakeFontStringMock(),
    }
  end
  return rows
end

-- Returns the render state plus the Mark-T/H button mock it renders into.
local function BuildState(memberRows, addonRoster)
  local state = RosterMocks.BuildDefaultRenderState(memberRows, addonRoster)
  local markButton = MakeMarkButtonMock()
  state.uiRef = state.uiRef or {}
  state.uiRef.markRolesButton = markButton
  return state, markButton
end

local function FindRowForUnit(memberRows, unit)
  for i = 1, #memberRows do
    if memberRows[i].unit == unit then
      return memberRows[i]
    end
  end
  return nil
end

-- Scenarios 9 to 11 live in their own functions: folded into the WithGlobals
-- callback they pushed it past the 420-line hard metrics gate.
local function RunAttributeWriteScenario(RI, addon)
  -- ----------------------------------------------------------------------
  -- Scenario 11: unchanged renders write no secure attributes.
  --
  -- Every sync packet, roster update and CD pass re-renders the roster. The
  -- Mark-T/H button only needs a write when its macro changes; the comparison
  -- runs against the last macro actually written, so a change still lands.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 11: unchanged renders skip the secure attribute writes ==========")
  do
    local memberRows = BuildMemberRows()
    local state, markButton = BuildState(memberRows, addon)
    local roster = {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER" },
    }

    SetCombat(false)
    RI.RenderRosterImpl(state, roster)
    local firstWrites = markButton._attributeWrites
    Check(firstWrites > 0, "first render: the Mark-T/H button receives its macros")
    for _ = 1, 50 do
      RI.RenderRosterImpl(state, roster)
    end
    Check(markButton._attributeWrites == firstWrites, "50 unchanged renders: no further SetAttribute call")

    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Zara", realm = "", class = "MAGE", role = "HEALER" },
    })
    Check(markButton._attributeWrites > firstWrites, "a new healer must rewrite the macro")
    Check(
      markButton:GetAttribute("macrotext1") == Macro({ { "Felix", 6 }, { "Zara", 4 } }),
      "the rewritten macro targets the new healer"
    )
  end
end

local function RunRoleIconScenarios(RI, addon)
  -- ----------------------------------------------------------------------
  -- Scenario 9: row role icons are display-only.
  --
  -- The icon sits at frameLevel + 10 above the row's hoverFrame. With mouse
  -- input it would swallow the row's tooltip and right-click whisper, and it
  -- carries no macro since marking moved to the Mark-T/H button.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 9: row role icons are display-only ==========")
  do
    local memberRows = BuildMemberRows()
    local state = BuildState(memberRows, addon)

    SetCombat(false)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER" },
      party2 = { name = "Bob", realm = "", class = "MAGE", role = "DAMAGER" },
    })

    for _, unit in ipairs({ "player", "party1", "party2" }) do
      local row = FindRowForUnit(memberRows, unit)
      Check(row ~= nil, unit .. " row rendered")
      if row then
        Check(row.roleIcon._shown == true, unit .. " row shows its role icon")
        Check(row.roleIcon._mouseEnabled == false, unit .. " role icon takes no mouse input")
      end
    end
  end

  -- ----------------------------------------------------------------------
  -- Scenario 10: a healer who turns into a ghost in combat drops out of the
  -- Mark-T/H macro once combat ends.
  --
  -- In combat the protected button cannot be rewritten (SetAttribute is
  -- blocked), so the renderer must not even try; the display-only icon may
  -- hide right away. The out-of-combat re-render removes the healer block.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 10: ghost healer leaves the macro after combat ==========")
  do
    local memberRows = BuildMemberRows()
    local state, markButton = BuildState(memberRows, addon)

    SetCombat(false)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER" },
    })
    local macroBefore = markButton:GetAttribute("macrotext1")
    Check(macroBefore == Macro({ { "Felix", 6 }, { "Anna", 4 } }), "pre-combat baseline: tank and healer marked")

    SetCombat(true)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER", isGhost = true },
    })
    Check(markButton:GetAttribute("macrotext1") == macroBefore, "in combat: the macro is unchanged")
    Check(markButton._blockedCalls == 0, "in combat: no protected call is attempted on the Mark-T/H button")
    local healRow = FindRowForUnit(memberRows, "party1")
    Check(healRow ~= nil and healRow.roleIcon._shown == false, "in combat: the ghost's display icon hides")

    SetCombat(false)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER", isGhost = true },
    })
    Check(
      markButton:GetAttribute("macrotext1") == Macro({ { "Felix", 6 } }),
      "post-combat: the ghost healer is no longer marked"
    )
  end
end

-- ----------------------------------------------------------------------
-- Scenario 12: a macro left stale by a combat render is rewritten when the
-- window, closed in combat, is reopened without its show callbacks.
--
-- The roster shifts in combat while the window is open: the render runs but
-- cannot write the secure macro. The window is closed in combat, the hide
-- lands after combat (no render: the window is no longer shown), and a queue
-- highlight later reopens it with skipShowCallbacks. Only the OnShow flush
-- (FlushHiddenRender) runs then, so the combat render itself must have left
-- the roster marked stale.
--
-- COMPONENT-ONLY: drives the real RosterPanel controller (RenderRoster and
-- FlushHiddenRender, which the main frame's OnShow calls) with the shared
-- roster-panel frame mocks. The full dispatcher path (PLAYER_REGEN_ENABLED,
-- SetMainFrameVisible with skipShowCallbacks) is pinned end to end by the
-- usecase test "Mplus stress: a role macro left stale in combat is rewritten
-- when a closed window reopens"; there a post-combat kill-track repaint also
-- marks the hidden roster stale, which this scenario keeps out of the way.
-- ----------------------------------------------------------------------
local function RunStaleCombatRenderScenario()
  print("\n========== Scenario 12: combat-stale macro is rewritten on a callback-free reopen ==========")
  local helperChunk = assert(loadfile("testmodul/isilive_test_scenarios_roster_panel.lua"))
  local helperAddon = {}
  helperChunk("isiLive", helperAddon)
  local H = helperAddon._RosterPanelTests
  local createdFrames, createdFontStrings = {}, {}
  local shownState = { value = true }
  local roster = {
    player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
    party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER" },
  }
  local function CountRoleButtonsTargeting(name)
    local wanted = "\n/target " .. name .. "\n"
    local count = 0
    for _, frame in ipairs(createdFrames) do
      local macro = frame.attributes and frame.attributes.macrotext1
      if type(macro) == "string" and macro:find(wanted, 1, true) then
        count = count + 1
      end
    end
    return count
  end
  Harness.WithGlobals({
    CreateFrame = function()
      return H.NewRecordedFrame(createdFrames, createdFontStrings)
    end,
    InCombatLockdown = function()
      return inCombat
    end,
    GetRealmName = function()
      return "Stormrage"
    end,
    GameTooltip = { SetOwner = NoOp, SetText = NoOp, AddLine = NoOp, Show = NoOp, Hide = NoOp },
  }, function()
    local addon = Harness.LoadAddonModules({
      "isiLive_roster.lua",
      "isiLive_roster_layout.lua",
      "isiLive_roster_panel_render.lua",
      "isiLive_roster_panel.lua",
    })
    local controller = H.BuildHiddenSettingTestController(addon, createdFontStrings, {
      mainFrameShownState = shownState,
      getRoster = function()
        return roster
      end,
      buildOrderedRoster = function(currentRoster, rolePriority, unitPriority)
        return addon.Roster.BuildOrderedRoster(currentRoster, rolePriority, unitPriority)
      end,
      buildDisplayData = function(info)
        return {
          colorHex = "ffffffff",
          displayName = info.name,
          languageDisplay = "",
          specText = "-",
          ilvlText = "-",
          rioText = "-",
          keyText = "-",
          addonMarker = "",
          atDungeonMarker = "",
          readyCheckMarkup = "",
          roleIconMarkup = "",
        }
      end,
      rolePriority = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 },
      unitPriority = { player = 1, party1 = 2, party2 = 3, party3 = 4, party4 = 5 },
    })

    SetCombat(false)
    controller.RenderRoster(roster)
    Check(CountRoleButtonsTargeting("Anna") == 1, "pre-combat baseline: the Mark-T/H macro targets Anna")

    -- Combat: Anna leaves, Zara takes the healer slot; the window is still open.
    SetCombat(true)
    roster = {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Zara", realm = "", class = "MAGE", role = "HEALER" },
    }
    controller.RenderRoster(roster)
    Check(CountRoleButtonsTargeting("Zara") == 0, "in combat: the macro is not rewritten")

    -- Closed in combat, hidden after combat: no render runs on the hidden window.
    SetCombat(false)
    shownState.value = false

    -- Reopened with skipShowCallbacks: OnShow runs only the hidden-render flush.
    shownState.value = true
    controller.FlushHiddenRender()
    Check(
      CountRoleButtonsTargeting("Anna") == 0,
      "after reopen: the Mark-T/H macro no longer targets the departed Anna"
    )
    Check(CountRoleButtonsTargeting("Zara") == 1, "after reopen: the Mark-T/H macro targets the current healer Zara")
  end)
  SetCombat(false)
end

-- ----------------------------------------------------------------------
-- Run.
-- ----------------------------------------------------------------------
Harness.WithGlobals({
  GetReadyCheckStatus = function()
    return nil
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
    return 100
  end,
  IsAddOnLoaded = function()
    return false
  end,
  C_AddOns = nil,
  GetAddOnMetadata = function()
    return nil
  end,
  -- Home realm distinct from any realm name used in scenarios below so the
  -- home-realm-strip path can be exercised in isolation without disturbing
  -- the existing cross-realm assertions (Tichondrius / TwistingNether).
  GetRealmName = function()
    return "Stormrage"
  end,
  InCombatLockdown = function()
    return inCombat
  end,
  CreateFrame = MakeFrameMock,
}, function()
  -- isiLive_roster_layout.lua is loaded for its real IsCombatLockdownActive.
  -- roster_panel_render.lua captures `RI.IsCombatLockdownActive or <false stub>`
  -- into a local at load time, so without the layout module every scenario
  -- would silently run the not-in-combat branch. The real helper re-reads the
  -- InCombatLockdown global on every call, so scenarios can flip combat state.
  local addon = Harness.LoadAddonModules({
    "isiLive_roster.lua",
    "isiLive_roster_layout.lua",
    "isiLive_roster_panel_render.lua",
  })
  local RI = addon._RosterInternal or addon._RosterPanelInternal
  if not RI then
    for _, v in pairs(addon) do
      if type(v) == "table" and type(v.RenderRosterImpl) == "function" then
        RI = v
        break
      end
    end
  end
  assert(RI, "could not locate RosterPanelInternal")

  -- ----------------------------------------------------------------------
  -- Scenario 1: same-realm same-locale (English) — sanity baseline.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 1: same-realm baseline (no realm suffix) ==========")
  do
    local memberRows = BuildMemberRows()
    local state, markButton = BuildState(memberRows, addon)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER" },
      party2 = { name = "Bob", realm = "", class = "MAGE", role = "DAMAGER" },
      party3 = { name = "Carl", realm = "", class = "ROGUE", role = "DAMAGER" },
      party4 = { name = "Dave", realm = "", class = "WARLOCK", role = "DAMAGER" },
    })

    Check(
      markButton:GetAttribute("macrotext1") == Macro({ { "Felix", 6 }, { "Anna", 4 } }),
      "macrotext1 marks bare 'Felix' (6) then bare 'Anna' (4) behind the [exists] guard"
    )
    Check(
      markButton:GetAttribute("macrotext2") == Macro({ { "Felix", 0 }, { "Anna", 0 } }),
      "macrotext2 clears both markers on the same names"
    )
    for _, dpsName in ipairs({ "Bob", "Carl", "Dave" }) do
      Check(
        markButton:GetAttribute("macrotext1"):find("/target " .. dpsName, 1, true) == nil,
        "DAMAGER " .. dpsName .. " is not part of the macro"
      )
    end
  end

  -- ----------------------------------------------------------------------
  -- Scenario 2: cross-realm — realm suffix appended exactly as whisper does.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 2: cross-realm name-realm suffix ==========")
  do
    local memberRows = BuildMemberRows()
    local state, markButton = BuildState(memberRows, addon)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "Tichondrius", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "TwistingNether", class = "PRIEST", role = "HEALER" },
    })
    Check(
      markButton:GetAttribute("macrotext1") == Macro({ { "Felix-Tichondrius", 6 }, { "Anna-TwistingNether", 4 } }),
      "cross-realm macrotext1 keeps the '-Tichondrius' and '-TwistingNether' suffixes"
    )
  end

  -- ----------------------------------------------------------------------
  -- Scenario 3: UTF-8 multi-byte names from every LFG-supported locale must
  -- pass through byte-for-byte. This is the regression pin against any
  -- accidental sanitization / transliteration.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 3: UTF-8 multi-byte names pass through unchanged ==========")
  do
    local cases = {
      -- { locale, tank, healer }
      -- Decimal escapes (\DDD) are Lua 5.1 compatible; \xHH would only work on 5.2+.
      -- ü=\195\188, ä=\195\164, é=\195\169, î=\195\174, í=\195\173,
      -- ã=\195\163, ç=\195\167, ò=\195\178, ì=\195\172, Ç=\195\135,
      -- ğ=\196\159, ı=\196\177, İ=\196\176
      { "deDE", "M\195\188ller", "Sch\195\164fer" },
      { "frFR", "S\195\169bastien", "Beno\195\174t" },
      { "esES", "Luc\195\173a", "Jos\195\169" },
      { "ptBR", "Jo\195\163o", "Concei\195\167\195\163o" },
      { "itIT", "Niccol\195\178", "Beatr\195\172ce" },
      -- Cyrillic Юрий = \208\174\209\128\208\184\208\185, Алекс = \208\144\208\187\208\181\208\186\209\129
      { "ruRU", "\208\174\209\128\208\184\208\185", "\208\144\208\187\208\181\208\186\209\129" },
      -- Turkish Çağrı = \195\135a\196\159r\196\177, İlhan = \196\176lhan
      { "trTR", "\195\135a\196\159r\196\177", "\196\176lhan" },
    }
    for _, case in ipairs(cases) do
      local locale, tankName, healerName = case[1], case[2], case[3]
      local memberRows = BuildMemberRows()
      local state, markButton = BuildState(memberRows, addon)
      RI.RenderRosterImpl(state, {
        player = { name = tankName, realm = "", class = "WARRIOR", role = "TANK" },
        party1 = { name = healerName, realm = "", class = "PRIEST", role = "HEALER" },
      })
      Check(
        markButton:GetAttribute("macrotext1") == Macro({ { tankName, 6 }, { healerName, 4 } }),
        locale .. ": macrotext1 carries both UTF-8 names byte-for-byte (" .. tankName .. ", " .. healerName .. ")"
      )
    end
  end

  -- ----------------------------------------------------------------------
  -- Scenario 4: hard ban on unit tokens. No macrotext may contain partyN /
  -- raidN / target / focus / boss / nameplate — those are the secret-unit-token
  -- forms that 12.0.5 silently breaks.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 4: no macrotext contains a unit token ==========")
  do
    local memberRows = BuildMemberRows()
    local state, markButton = BuildState(memberRows, addon)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "Tichondrius", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "Tichondrius", class = "PRIEST", role = "HEALER" },
    })

    local TOKEN_PATTERNS = {
      "/target party",
      "/target raid",
      "/target target",
      "/target focus",
      "/target boss",
      "/target nameplate",
      "/target arena",
      "/target player",
    }
    for _, attr in ipairs({ "macrotext1", "macrotext2" }) do
      local m = markButton:GetAttribute(attr)
      Check(type(m) == "string", attr .. " is written")
      if type(m) == "string" then
        for _, bad in ipairs(TOKEN_PATTERNS) do
          Check(m:find(bad, 1, true) == nil, string.format("%s does NOT contain '%s'", attr, bad))
        end
      end
    end
  end

  -- ----------------------------------------------------------------------
  -- Scenario 5: defensive — empty / nil names are skipped entirely. Rather
  -- than emit a partial "/target \n/tm 6" which would target nothing; with
  -- neither name usable the button carries no macro at all.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 5: missing name => no macro block ==========")
  do
    local memberRows = BuildMemberRows()
    local state, markButton = BuildState(memberRows, addon)
    RI.RenderRosterImpl(state, {
      player = { name = "", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { class = "PRIEST", role = "HEALER" },
    })
    Check(markButton:GetAttribute("macrotext1") == nil, "nameless tank and healer: macrotext1 is nil")
    Check(markButton:GetAttribute("macrotext2") == nil, "nameless tank and healer: macrotext2 is nil")

    RI.RenderRosterImpl(state, {
      player = { name = "", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER" },
    })
    Check(
      markButton:GetAttribute("macrotext1") == Macro({ { "Anna", 4 } }),
      "nameless tank: only the healer block is written"
    )
  end

  -- ----------------------------------------------------------------------
  -- Scenario 6b: home-realm strip. Units.GetUnitNameAndRealm fills realm with
  -- GetRealmName() for the local player when UnitFullName returns blank, so
  -- info.realm always carries the home realm string. /target Pinto-Stormrage
  -- (or worse, /target Pinto-Twisting Nether with a space) does NOT acquire
  -- the local-realm Pinto, but /target Pinto does. The macro builder must
  -- strip the realm suffix when info.realm matches GetRealmName().
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 6b: home-realm matches => strip realm suffix ==========")
  do
    local memberRows = BuildMemberRows()
    local state, markButton = BuildState(memberRows, addon)
    RI.RenderRosterImpl(state, {
      player = { name = "Pinto", realm = "Stormrage", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Cross", realm = "Tichondrius", class = "PRIEST", role = "HEALER" },
    })
    Check(
      markButton:GetAttribute("macrotext1") == Macro({ { "Pinto", 6 }, { "Cross-Tichondrius", 4 } }),
      "home-realm tank drops '-Stormrage', cross-realm healer keeps '-Tichondrius'"
    )
    Check(
      markButton:GetAttribute("macrotext2") == Macro({ { "Pinto", 0 }, { "Cross-Tichondrius", 0 } }),
      "the clear macro uses the same stripped names"
    )
  end

  -- ----------------------------------------------------------------------
  -- Scenario 6: type1/type2 are wired so the secure handler routes the
  -- click to the macro. Without these, the macrotext is dead weight.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 6: type1/type2 = 'macro' ==========")
  do
    local memberRows = BuildMemberRows()
    local state, markButton = BuildState(memberRows, addon)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER" },
    })
    Check(markButton:GetAttribute("type1") == "macro", "type1 = 'macro'")
    Check(markButton:GetAttribute("type2") == "macro", "type2 = 'macro'")
  end

  -- ----------------------------------------------------------------------
  -- Scenario 7: roster churn during combat lockdown.
  --
  -- SetAttribute on the protected Mark-T/H button is blocked for addon code in
  -- combat (ADDON_ACTION_BLOCKED). The renderer must not attempt it -- a blocked
  -- call changes nothing and only raises the "interface action failed" error.
  -- The button keeps the macro of the previous render until combat ends; the
  -- PLAYER_REGEN_ENABLED re-render must then reconcile it with the group.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 7: combat churn attempts no protected call ==========")
  do
    local memberRows = BuildMemberRows()
    local state, markButton = BuildState(memberRows, addon)

    SetCombat(false)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER" },
    })
    Check(
      markButton:GetAttribute("macrotext1") == Macro({ { "Felix", 6 }, { "Anna", 4 } }),
      "pre-combat baseline: macro marks Felix and Anna"
    )

    -- Combat starts. Anna leaves the group and Zara joins as healer.
    SetCombat(true)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Zara", realm = "", class = "MAGE", role = "HEALER" },
    })
    Check(markButton._blockedCalls == 0, "in combat: no protected call is attempted on the Mark-T/H button")

    SetCombat(false)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Zara", realm = "", class = "MAGE", role = "HEALER" },
    })
    Check(
      markButton:GetAttribute("macrotext1") == Macro({ { "Felix", 6 }, { "Zara", 4 } }),
      "post-combat: the macro marks the current healer (Zara)"
    )
  end

  -- ----------------------------------------------------------------------
  -- Scenario 8: group SHRINK during combat.
  --
  -- The healer leaves mid-pull. In combat the protected button must not be
  -- touched; after combat the healer block must be gone.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 8: combat group shrink, healer block dropped after combat ==========")
  do
    local memberRows = BuildMemberRows()
    local state, markButton = BuildState(memberRows, addon)

    SetCombat(false)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER" },
    })

    SetCombat(true)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
    })
    Check(markButton._blockedCalls == 0, "in combat: a group shrink attempts no protected call")

    SetCombat(false)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
    })
    Check(
      markButton:GetAttribute("macrotext1") == Macro({ { "Felix", 6 } }),
      "post-combat: only the tank block remains"
    )
  end

  RunAttributeWriteScenario(RI, addon)

  RunRoleIconScenarios(RI, addon)
end)

RunStaleCombatRenderScenario()

if failures > 0 then
  print(string.format("\nRole-marker macro simulator failed: %d check(s) failed", failures))
  print("If you are intentionally changing the macro contract, update CLAUDE.md")
  print('"Role-marker click feature: target by character name" first, then update')
  print("this simulator to encode the new contract.")
  os.exit(1)
end

print("\nRole-marker macro simulator passed.")
