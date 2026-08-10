-- Standalone CLI tool: regression pin for the tank/healer role-icon macro.
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
--   * If info.name is missing/empty, no macro is set (no partial macro).
--
-- This drives the real RenderRosterImpl from roster_panel_render.lua against
-- frame mocks that capture every SetAttribute call. The roster mixes locales
-- and same-realm/cross-realm to catch any byte mangling or token regression.
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

-- ----------------------------------------------------------------------
-- Sim-local mocks. The role button is created with SecureActionButtonTemplate;
-- production calls SetAttribute("type1"|"type2"|"macrotext1"|"macrotext2"|...).
-- We capture each attribute keyed by the unit so the roster-name assertions
-- can look up per row. Frame + font-string mocks come from the shared
-- testmodul/isilive_test_render_roster_mocks.lua helper.
-- ----------------------------------------------------------------------
local MakeFrameMock = RosterMocks.MakeFrameMock
local MakeFontStringMock = RosterMocks.MakeFontStringMock

local function MakeRoleButtonMock()
  local icon = {
    SetAllPoints = NoOp,
    SetTexture = NoOp,
    SetTexCoord = NoOp,
    SetVertexColor = NoOp,
    SetDesaturated = NoOp,
    Show = NoOp,
    Hide = NoOp,
  }
  local mock = {
    _attributes = {},
    _shown = false,
    icon = icon,
  }
  function mock:SetAttribute(key, value)
    self._attributes[key] = value
  end
  function mock:GetAttribute(key)
    return self._attributes[key]
  end
  function mock:Show()
    self._shown = true
  end
  function mock:Hide()
    self._shown = false
  end
  mock.SetSize = NoOp
  mock.SetPoint = NoOp
  mock.SetFrameLevel = NoOp
  mock.RegisterForClicks = NoOp
  mock.SetScript = NoOp
  mock.HookScript = NoOp
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
  }
end

local function BuildMemberRows()
  local rows = {}
  for i = 1, 5 do
    rows[i] = {
      roleButton = MakeRoleButtonMock(),
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

local function BuildState(memberRows, addonRoster)
  return RosterMocks.BuildDefaultRenderState(memberRows, addonRoster)
end

local function FindRowForUnit(memberRows, unit)
  for i = 1, #memberRows do
    if memberRows[i].unit == unit then
      return memberRows[i]
    end
  end
  return nil
end

-- Combat state for the InCombatLockdown stub installed in WithGlobals below.
-- roster_layout's IsCombatLockdownActive re-reads the global on every call, so
-- flipping this mid-scenario switches the production branch under test.
local inCombat = false
local function SetCombat(active)
  inCombat = active and true or false
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
  -- would silently run the not-in-combat branch — which is exactly how the
  -- combat-lockdown staleness bug (scenario 7) stayed invisible here. The real
  -- helper re-reads the InCombatLockdown global on every call, so scenarios can
  -- flip combat state at will via Harness.WithGlobals below.
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
    local state = BuildState(memberRows, addon)
    local roster = {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER" },
      party2 = { name = "Bob", realm = "", class = "MAGE", role = "DAMAGER" },
      party3 = { name = "Carl", realm = "", class = "ROGUE", role = "DAMAGER" },
      party4 = { name = "Dave", realm = "", class = "WARLOCK", role = "DAMAGER" },
    }
    RI.RenderRosterImpl(state, roster)

    local tank = FindRowForUnit(memberRows, "player")
    Check(tank ~= nil, "TANK row rendered")
    if tank then
      Check(
        tank.roleButton:GetAttribute("macrotext1") == "/target Felix\n/tm 6\n/targetlasttarget",
        "TANK macrotext1 = '/target Felix\\n/tm 6\\n/targetlasttarget' (no realm, no token)"
      )
      Check(
        tank.roleButton:GetAttribute("macrotext2") == "/target Felix\n/tm 0\n/targetlasttarget",
        "TANK macrotext2 (clear) = '/target Felix\\n/tm 0\\n/targetlasttarget'"
      )
    end

    local heal = FindRowForUnit(memberRows, "party1")
    Check(heal ~= nil, "HEALER row rendered")
    if heal then
      Check(
        heal.roleButton:GetAttribute("macrotext1") == "/target Anna\n/tm 4\n/targetlasttarget",
        "HEALER macrotext1 = '/target Anna\\n/tm 4\\n/targetlasttarget'"
      )
    end

    for _, unit in ipairs({ "party2", "party3", "party4" }) do
      local dps = FindRowForUnit(memberRows, unit)
      if dps then
        Check(
          dps.roleButton:GetAttribute("macrotext1") == nil,
          "DAMAGER " .. unit .. " macrotext1 is nil (no marker for DPS)"
        )
      end
    end
  end

  -- ----------------------------------------------------------------------
  -- Scenario 2: cross-realm — realm suffix appended exactly as whisper does.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 2: cross-realm name-realm suffix ==========")
  do
    local memberRows = BuildMemberRows()
    local state = BuildState(memberRows, addon)
    local roster = {
      player = { name = "Felix", realm = "Tichondrius", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "TwistingNether", class = "PRIEST", role = "HEALER" },
    }
    RI.RenderRosterImpl(state, roster)

    local tank = FindRowForUnit(memberRows, "player")
    if tank then
      Check(
        tank.roleButton:GetAttribute("macrotext1") == "/target Felix-Tichondrius\n/tm 6\n/targetlasttarget",
        "TANK cross-realm macrotext1 has '-Tichondrius' suffix"
      )
    end

    local heal = FindRowForUnit(memberRows, "party1")
    if heal then
      Check(
        heal.roleButton:GetAttribute("macrotext1") == "/target Anna-TwistingNether\n/tm 4\n/targetlasttarget",
        "HEALER cross-realm macrotext1 has '-TwistingNether' suffix"
      )
    end
  end

  -- ----------------------------------------------------------------------
  -- Scenario 3: UTF-8 multi-byte names from every LFG-supported locale must
  -- pass through byte-for-byte. This is the regression pin against any
  -- accidental sanitization / transliteration.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 3: UTF-8 multi-byte names pass through unchanged ==========")
  do
    local cases = {
      -- { locale, tank, healer, expectedTankFragment, expectedHealerFragment }
      -- Decimal escapes (\DDD) are Lua 5.1 compatible; \xHH would only work on 5.2+.
      -- ü=\195\188, ä=\195\164, é=\195\169, î=\195\174, í=\195\173,
      -- ã=\195\163, ç=\195\167, ò=\195\178, ì=\195\172, Ç=\195\135,
      -- ğ=\196\159, ı=\196\177, İ=\196\176
      { "deDE", "M\195\188ller", "Sch\195\164fer", "M\195\188ller", "Sch\195\164fer" },
      { "frFR", "S\195\169bastien", "Beno\195\174t", "S\195\169bastien", "Beno\195\174t" },
      { "esES", "Luc\195\173a", "Jos\195\169", "Luc\195\173a", "Jos\195\169" },
      { "ptBR", "Jo\195\163o", "Concei\195\167\195\163o", "Jo\195\163o", "Concei\195\167\195\163o" },
      { "itIT", "Niccol\195\178", "Beatr\195\172ce", "Niccol\195\178", "Beatr\195\172ce" },
      -- Cyrillic Юрий = \208\174\209\128\208\184\208\185, Алекс = \208\144\208\187\208\181\208\186\209\129
      {
        "ruRU",
        "\208\174\209\128\208\184\208\185",
        "\208\144\208\187\208\181\208\186\209\129",
        "\208\174\209\128\208\184\208\185",
        "\208\144\208\187\208\181\208\186\209\129",
      },
      -- Turkish Çağrı = \195\135a\196\159r\196\177, İlhan = \196\176lhan
      { "trTR", "\195\135a\196\159r\196\177", "\196\176lhan", "\195\135a\196\159r\196\177", "\196\176lhan" },
    }
    for _, case in ipairs(cases) do
      local locale, tankName, healerName, tankExpect, healerExpect = case[1], case[2], case[3], case[4], case[5]
      local memberRows = BuildMemberRows()
      local state = BuildState(memberRows, addon)
      local roster = {
        player = { name = tankName, realm = "", class = "WARRIOR", role = "TANK" },
        party1 = { name = healerName, realm = "", class = "PRIEST", role = "HEALER" },
      }
      RI.RenderRosterImpl(state, roster)

      local tank = FindRowForUnit(memberRows, "player")
      if tank then
        local m1 = tank.roleButton:GetAttribute("macrotext1") or ""
        Check(
          m1 == "/target " .. tankExpect .. "\n/tm 6\n/targetlasttarget",
          locale .. ": TANK macrotext1 has UTF-8 name byte-for-byte (" .. tankExpect .. ")"
        )
      end

      local heal = FindRowForUnit(memberRows, "party1")
      if heal then
        local m1 = heal.roleButton:GetAttribute("macrotext1") or ""
        Check(
          m1 == "/target " .. healerExpect .. "\n/tm 4\n/targetlasttarget",
          locale .. ": HEALER macrotext1 has UTF-8 name byte-for-byte (" .. healerExpect .. ")"
        )
      end
    end
  end

  -- ----------------------------------------------------------------------
  -- Scenario 4: hard ban on unit tokens. No macrotext anywhere may contain
  -- partyN / raidN / target / focus / boss / nameplate — those are the
  -- secret-unit-token forms that 12.0.5 silently breaks.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 4: no macrotext contains a unit token ==========")
  do
    local memberRows = BuildMemberRows()
    local state = BuildState(memberRows, addon)
    local roster = {
      player = { name = "Felix", realm = "Tichondrius", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "Tichondrius", class = "PRIEST", role = "HEALER" },
    }
    RI.RenderRosterImpl(state, roster)

    local TOKEN_PATTERNS = {
      "/target party",
      "/target raid",
      "/target target",
      "/target focus",
      "/target boss",
      "/target nameplate",
      "/target arena",
    }
    for i = 1, #memberRows do
      for _, attr in ipairs({ "macrotext1", "macrotext2" }) do
        local m = memberRows[i].roleButton:GetAttribute(attr)
        if type(m) == "string" then
          for _, bad in ipairs(TOKEN_PATTERNS) do
            Check(m:find(bad, 1, true) == nil, string.format("row %d %s does NOT contain '%s'", i, attr, bad))
          end
        end
      end
    end
  end

  -- ----------------------------------------------------------------------
  -- Scenario 5: defensive — empty / nil name drops the macro entirely.
  -- Rather than emit a partial "/target \n/tm 6\n..." which would target
  -- nothing and mark the previous target.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 5: missing name => no macro at all ==========")
  do
    local memberRows = BuildMemberRows()
    local state = BuildState(memberRows, addon)
    local roster = {
      player = { name = "", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { class = "PRIEST", role = "HEALER" },
    }
    RI.RenderRosterImpl(state, roster)

    local tank = FindRowForUnit(memberRows, "player")
    if tank then
      Check(tank.roleButton:GetAttribute("macrotext1") == nil, "empty-name TANK: macrotext1 is nil")
      Check(tank.roleButton:GetAttribute("macrotext2") == nil, "empty-name TANK: macrotext2 is nil")
    end

    local heal = FindRowForUnit(memberRows, "party1")
    if heal then
      Check(heal.roleButton:GetAttribute("macrotext1") == nil, "missing-name HEALER: macrotext1 is nil")
      Check(heal.roleButton:GetAttribute("macrotext2") == nil, "missing-name HEALER: macrotext2 is nil")
    end
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
    local state = BuildState(memberRows, addon)
    local roster = {
      player = { name = "Pinto", realm = "Stormrage", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Cross", realm = "Tichondrius", class = "PRIEST", role = "HEALER" },
    }
    RI.RenderRosterImpl(state, roster)

    local tank = FindRowForUnit(memberRows, "player")
    if tank then
      Check(
        tank.roleButton:GetAttribute("macrotext1") == "/target Pinto\n/tm 6\n/targetlasttarget",
        "TANK home-realm match: macrotext1 must drop the '-Stormrage' suffix"
      )
      Check(
        tank.roleButton:GetAttribute("macrotext2") == "/target Pinto\n/tm 0\n/targetlasttarget",
        "TANK home-realm match: macrotext2 must drop the '-Stormrage' suffix"
      )
    end

    local heal = FindRowForUnit(memberRows, "party1")
    if heal then
      Check(
        heal.roleButton:GetAttribute("macrotext1") == "/target Cross-Tichondrius\n/tm 4\n/targetlasttarget",
        "HEALER cross-realm: macrotext1 must keep the '-Tichondrius' suffix"
      )
    end
  end

  -- ----------------------------------------------------------------------
  -- Scenario 6: type1/type2 are wired so the secure handler routes the
  -- click to the macro. Without these, the macrotext is dead weight.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 6: type1/type2 = 'macro' for active rows ==========")
  do
    local memberRows = BuildMemberRows()
    local state = BuildState(memberRows, addon)
    local roster = {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER" },
    }
    RI.RenderRosterImpl(state, roster)

    local tank = FindRowForUnit(memberRows, "player")
    if tank then
      Check(tank.roleButton:GetAttribute("type1") == "macro", "TANK type1 = 'macro'")
      Check(tank.roleButton:GetAttribute("type2") == "macro", "TANK type2 = 'macro'")
    end
    local heal = FindRowForUnit(memberRows, "party1")
    if heal then
      Check(heal.roleButton:GetAttribute("type1") == "macro", "HEALER type1 = 'macro'")
      Check(heal.roleButton:GetAttribute("type2") == "macro", "HEALER type2 = 'macro'")
    end
  end

  -- ----------------------------------------------------------------------
  -- Scenario 7: combat lockdown must never leave a STALE macro on the button.
  --
  -- SetAttribute is forbidden during combat lockdown, so production skips the
  -- whole roleButton block while InCombatLockdown() is true. The danger is not
  -- the skipped write — it is what stays behind: the macro from the PREVIOUS
  -- render still names the previous occupant of that row. A click then targets
  -- and marks the wrong player, which is the exact failure class CLAUDE.md
  -- records for v0.9.203 and v0.9.208.
  --
  -- Roster churn mid-combat is routine in a key: a death re-sorts rows (ghosts
  -- sort last), a role swap re-sorts them, a disconnect drops a member. So the
  -- contract is: while a row's macro cannot be rewritten, that row must not
  -- offer a clickable marker at all. Hide() is not protected, so hiding is
  -- always available even in combat.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 7: combat lockdown must not leave a stale macro ==========")
  do
    local memberRows = BuildMemberRows()
    local state = BuildState(memberRows, addon)

    -- Render A, out of combat: Felix tanks, Anna heals.
    SetCombat(false)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER" },
    })

    local tankRowBefore = FindRowForUnit(memberRows, "player")
    Check(
      tankRowBefore ~= nil
        and tankRowBefore.roleButton:GetAttribute("macrotext1") == "/target Felix\n/tm 6\n/targetlasttarget",
      "pre-combat baseline: TANK row macro targets Felix"
    )

    -- Combat starts. Anna leaves the group and Zara joins as healer; the roster
    -- rebuilds and party1 is now a different character. Production cannot
    -- rewrite macrotext here.
    SetCombat(true)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Zara", realm = "", class = "MAGE", role = "HEALER" },
    })

    local healRow = FindRowForUnit(memberRows, "party1")
    if healRow then
      local macro = healRow.roleButton:GetAttribute("macrotext1")
      local namesStalePlayer = type(macro) == "string" and macro:find("Anna", 1, true) ~= nil
      local isClickable = healRow.roleButton._shown == true

      -- The button may keep a stale macro string (SetAttribute is forbidden),
      -- but it must not simultaneously be shown — that combination is what
      -- marks the wrong player.
      Check(
        not (namesStalePlayer and isClickable),
        "in combat: healer row must not be BOTH shown AND still naming the departed player"
      )
    end

    -- Combat ends: the deferred render must reconcile the button with reality.
    SetCombat(false)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Zara", realm = "", class = "MAGE", role = "HEALER" },
    })

    local healAfter = FindRowForUnit(memberRows, "party1")
    if healAfter then
      Check(
        healAfter.roleButton:GetAttribute("macrotext1") == "/target Zara\n/tm 4\n/targetlasttarget",
        "post-combat: healer row macro targets the current occupant (Zara)"
      )
      Check(healAfter.roleButton._shown == true, "post-combat: healer role button is shown again")
    end
  end

  -- ----------------------------------------------------------------------
  -- Scenario 8: group SHRINK during combat must also drop the marker.
  --
  -- Same failure class as scenario 7, reached through the other code path:
  -- when the group shrinks, the vacated rows go through ClearMemberRow instead
  -- of the per-member render loop. A row cleared in combat keeps whatever macro
  -- it last held, so a leftover button would still target the member who left.
  -- Hide() is not protected, so clearing a row must hide its role button
  -- regardless of combat state.
  -- ----------------------------------------------------------------------
  print("\n========== Scenario 8: combat group shrink hides the vacated row's marker ==========")
  do
    local memberRows = BuildMemberRows()
    local state = BuildState(memberRows, addon)

    SetCombat(false)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
      party1 = { name = "Anna", realm = "", class = "PRIEST", role = "HEALER" },
    })

    local healerRowIndex
    for i = 1, #memberRows do
      if memberRows[i].unit == "party1" then
        healerRowIndex = i
      end
    end
    Check(healerRowIndex ~= nil, "pre-shrink baseline: healer occupies a row")

    -- Anna leaves mid-pull; only the tank remains. The healer's row is cleared.
    SetCombat(true)
    RI.RenderRosterImpl(state, {
      player = { name = "Felix", realm = "", class = "WARRIOR", role = "TANK" },
    })

    if healerRowIndex then
      local vacated = memberRows[healerRowIndex]
      local macro = vacated.roleButton:GetAttribute("macrotext1")
      local namesDepartedPlayer = type(macro) == "string" and macro:find("Anna", 1, true) ~= nil
      Check(
        not (namesDepartedPlayer and vacated.roleButton._shown == true),
        "in combat: vacated row must not keep a shown marker naming the departed player"
      )
    end
  end
end)

if failures > 0 then
  print(string.format("\nRole-marker macro simulator failed: %d check(s) failed", failures))
  print("If you are intentionally changing the macro contract, update CLAUDE.md")
  print('"Role-marker click feature: target by character name" first, then update')
  print("this simulator to encode the new contract.")
  os.exit(1)
end

print("\nRole-marker macro simulator passed.")
