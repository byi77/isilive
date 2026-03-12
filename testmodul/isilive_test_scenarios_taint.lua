---@diagnostic disable: undefined-global

local function RegisterProtectedApiTraps()
  local protectedFunctions = {
    "SetRaidTarget",
    "TargetUnit",
    "FocusUnit",
    "AssistUnit",
    "CastSpell",
    "CastSpellByName",
    "UseAction",
    "AttackTarget",
    "ClearTarget",
  }

  local traps = {}
  for _, funcName in ipairs(protectedFunctions) do
    traps[funcName] = _G[funcName]
    _G[funcName] = function()
      error("TAINT VIOLATION: Attempted to call protected function '" .. funcName .. "' from insecure addon code!")
    end
  end

  return function()
    for funcName, original in pairs(traps) do
      _G[funcName] = original
    end
  end
end

local function NewRecordedTexture()
  return {
    SetAllPoints = function() end,
    SetColorTexture = function() end,
    SetHeight = function() end,
    SetPoint = function() end,
    SetTexture = function(self, texture)
      self.texture = texture
    end,
    SetTexCoord = function(self, ...)
      self.texCoord = { ... }
    end,
    Hide = function(self)
      self.hidden = true
    end,
    Show = function(self)
      self.hidden = false
    end,
  }
end

local function NewRecordedFontString()
  return {
    SetPoint = function() end,
    ClearAllPoints = function() end,
    SetWidth = function(self, width)
      self.width = width
    end,
    SetJustifyH = function() end,
    GetFont = function()
      return "font", 10, ""
    end,
    SetFont = function() end,
    SetTextColor = function() end,
    SetShadowOffset = function() end,
    SetText = function(self, text)
      self.text = text
    end,
    SetWordWrap = function() end,
    SetNonSpaceWrap = function() end,
    SetMaxLines = function() end,
    GetStringHeight = function()
      return 14
    end,
    Hide = function(self)
      self.hidden = true
    end,
    Show = function(self)
      self.hidden = false
    end,
  }
end

local function NewRecordedFrame(createdFrames, frameType, name, parent, template)
  local frame = {
    _frameType = frameType,
    _name = name,
    _parent = parent,
    _template = template,
    _attributes = {},
    _shown = true,
  }

  function frame:SetSize(width, height)
    self.width = width
    self.height = height
  end

  function frame:SetHeight(height)
    self.height = height
  end

  function frame:SetWidth(width)
    self.width = width
  end

  function frame:SetPoint(...)
    self.point = { ... }
  end

  function frame:ClearAllPoints()
    self.point = nil
  end

  function frame:SetScript(script, handler)
    self[script] = handler
  end

  function frame:SetText(text)
    self.text = text
  end

  function frame:SetEnabled(enabled)
    self.enabled = enabled and true or false
  end

  function frame:SetAlpha(alpha)
    self.alpha = alpha
  end

  function frame:SetChecked(checked)
    self.checked = checked and true or false
  end

  function frame:GetChecked()
    return self.checked
  end

  function frame:SetAttribute(key, value)
    self._attributes[key] = value
  end

  function frame:GetAttribute(key)
    return self._attributes[key]
  end

  function frame.EnableMouse() end
  function frame.SetBackdrop() end
  function frame.SetBackdropColor() end
  function frame.SetFrameStrata() end
  function frame.SetClampedToScreen() end

  function frame.CreateTexture()
    return NewRecordedTexture()
  end

  function frame.CreateFontString()
    return NewRecordedFontString()
  end

  function frame:Hide()
    self._shown = false
  end

  function frame:Show()
    self._shown = true
  end

  function frame:IsShown()
    return self._shown
  end

  table.insert(createdFrames, frame)
  return frame
end

local function NewRecordedMainFrame(createdFrames)
  local frame = NewRecordedFrame(createdFrames, "Frame", "MainFrame", nil, nil)

  function frame.GetWidth()
    return 420
  end

  function frame.GetEffectiveScale()
    return 1
  end

  return frame
end

local function BuildOrderedRosterFromTable(roster)
  local units = {}
  for unit in pairs(roster or {}) do
    table.insert(units, unit)
  end
  table.sort(units)

  local ordered = {}
  for _, unit in ipairs(units) do
    table.insert(ordered, {
      unit = unit,
      info = roster[unit],
    })
  end
  return ordered
end

local function BuildRosterDisplayData(info)
  return {
    colorHex = "ffffffff",
    displayName = tostring(info.name or ""),
    languageDisplay = "",
    specText = tostring(info.spec or ""),
    ilvlText = "-",
    rioText = "-",
    keyText = "-",
    addonMarker = "",
    atDungeonMarker = "",
    readyCheckMarkup = "",
  }
end

local function BuildRosterPanelController(WithGlobals, LoadAddonModules)
  local createdFrames = {}
  local addon

  local stubs = {
    CreateFrame = function(frameType, name, parent, template)
      return NewRecordedFrame(createdFrames, frameType, name, parent, template)
    end,
    InCombatLockdown = function()
      return false
    end,
    UIParent = {
      GetEffectiveScale = function()
        return 1
      end,
    },
    C_CVar = {
      GetCVar = function()
        return "0"
      end,
      SetCVar = function() end,
    },
  }

  WithGlobals(stubs, function()
    addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
  end)

  local controller
  WithGlobals(stubs, function()
    controller = addon.RosterPanel.CreateController({
      mainFrame = NewRecordedMainFrame(createdFrames),
      getL = function()
        return {}
      end,
      isPlayerLeader = function()
        return true
      end,
      getAddonVersionText = function()
        return "vTest"
      end,
      updateStatusLine = function() end,
      setMainFrameHeightSafe = function() end,
      buildOrderedRoster = function(roster)
        return BuildOrderedRosterFromTable(roster)
      end,
      hasFullSync = function()
        return false
      end,
      buildDisplayData = function(info)
        return BuildRosterDisplayData(info)
      end,
      truncateName = function(name)
        return name
      end,
      getShortSpecLabel = function(spec)
        return spec
      end,
      getLanguageFlagMarkup = function()
        return ""
      end,
      getDungeonShortCode = function()
        return ""
      end,
      resolveActiveKeyOwnerUnit = function()
        return nil
      end,
      getRoster = function()
        return {}
      end,
      rolePriority = { TANK = 1, HEALER = 2, DAMAGER = 3 },
      unitPriority = { player = 1, party1 = 2, party2 = 3, party3 = 4, party4 = 5 },
      isInGroup = function()
        return true
      end,
      isRaidGroup = function()
        return false
      end,
    })
  end)

  return controller, createdFrames, stubs
end

local function FindSecureRoleButton(createdFrames, unit)
  for _, frame in ipairs(createdFrames) do
    if frame._template == "SecureActionButtonTemplate" then
      if unit == nil or frame:GetAttribute("unit") == unit then
        return frame
      end
    end
  end
  return nil
end

local function RegisterGroupTaintTests(test, Assert, _WithGlobals, LoadAddonModules)
  test("TAINT: Group update logic relies purely on deps and touches no globals", function()
    local cleanupTraps = RegisterProtectedApiTraps()

    local addon = LoadAddonModules({ "isiLive_group.lua" })
    local roster = {}
    local controller = addon.Group.CreateController({
      isInGroup = function()
        return true
      end,
      getNumGroupMembers = function()
        return 2
      end,
      getRoster = function()
        return roster
      end,
      setRoster = function(value)
        roster = value
      end,
      getUnitNameAndRealm = function(unit)
        return (unit == "player" and "Me" or "You"), "Realm"
      end,
      getUnitRole = function()
        return "DAMAGER"
      end,
      unitHasIsiLive = function()
        return false
      end,
    })

    local ok, err = pcall(function()
      controller.HandleGroupRosterUpdate()
    end)

    cleanupTraps()

    Assert.True(ok, "Group update crashed or hit a taint trap: " .. tostring(err))
  end)
end

local function RegisterRosterPanelTaintTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster role icon is a secure action button", function()
    local controller, createdFrames, stubs = BuildRosterPanelController(WithGlobals, LoadAddonModules)

    WithGlobals(stubs, function()
      controller.RenderRoster({
        player = { name = "Tank", role = "TANK", class = "WARRIOR" },
      })
    end)

    local roleButton = FindSecureRoleButton(createdFrames, "player")
    Assert.NotNil(roleButton, "tank row should create a role button")
    Assert.Equal(roleButton._template, "SecureActionButtonTemplate", "role icon must use a secure action button")
    Assert.Equal(roleButton:GetAttribute("type"), "macro", "role button must be wired as a secure macro action")
  end)

  test("Roster role icon click applies Blue Square to Tank unit", function()
    local cleanupTraps = RegisterProtectedApiTraps()
    local controller, createdFrames, stubs = BuildRosterPanelController(WithGlobals, LoadAddonModules)

    local ok, err = pcall(function()
      WithGlobals(stubs, function()
        controller.RenderRoster({
          player = { name = "Tank", role = "TANK", class = "WARRIOR" },
        })
      end)
    end)

    cleanupTraps()

    Assert.True(ok, "tank render crashed or hit a taint trap: " .. tostring(err))
    local roleButton = FindSecureRoleButton(createdFrames, "player")
    Assert.NotNil(roleButton, "tank row should create a role button")
    Assert.Equal(roleButton:GetAttribute("macrotext"), "/tm @player 6", "tank role button must mark Blue Square")
  end)

  test("Roster role icon click applies Green Triangle to Healer unit", function()
    local cleanupTraps = RegisterProtectedApiTraps()
    local controller, createdFrames, stubs = BuildRosterPanelController(WithGlobals, LoadAddonModules)

    local ok, err = pcall(function()
      WithGlobals(stubs, function()
        controller.RenderRoster({
          party1 = { name = "Heal", role = "HEALER", class = "PRIEST" },
        })
      end)
    end)

    cleanupTraps()

    Assert.True(ok, "healer render crashed or hit a taint trap: " .. tostring(err))
    local roleButton = FindSecureRoleButton(createdFrames, "party1")
    Assert.NotNil(roleButton, "healer row should create a role button")
    Assert.Equal(roleButton:GetAttribute("macrotext"), "/tm @party1 4", "healer role button must mark Green Triangle")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterGroupTaintTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelTaintTests(test, Assert, WithGlobals, LoadAddonModules)
end
