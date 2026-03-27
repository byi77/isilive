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
    SetBlendMode = function(self, mode)
      self.blendMode = mode
    end,
    SetVertexColor = function(self, ...)
      self.vertexColor = { ... }
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
    SetJustifyV = function() end,
    GetFont = function()
      return "font", 10, ""
    end,
    SetFont = function() end,
    SetTextColor = function() end,
    SetShadowOffset = function() end,
    SetText = function(self, text)
      self.text = text
    end,
    GetText = function(self)
      return self.text
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

local function NewRecordedAnimationGroup()
  local group = {
    playing = false,
  }

  function group.SetLooping(_self, _mode) end

  function group.CreateAnimation(_self, _kind)
    return {
      SetScale = function() end,
      SetDuration = function() end,
      SetSmoothing = function() end,
      SetOrder = function() end,
      SetFromAlpha = function() end,
      SetToAlpha = function() end,
      SetTarget = function() end,
    }
  end

  function group:IsPlaying()
    return self.playing == true
  end

  function group:Play()
    self.playing = true
  end

  function group:Stop()
    self.playing = false
  end

  return group
end

local function NewRecordedFrame(createdFrames, frameType, name, parent, template)
  local frame = {
    _frameType = frameType,
    _name = name,
    _parent = parent,
    _template = template,
    _attributes = {},
    _shown = true,
    _events = {},
    _scripts = {},
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
    self._scripts[script] = handler
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

  function frame:IsProtected()
    return self._template == "SecureActionButtonTemplate"
  end

  function frame:RegisterEvent(event)
    self._events[event] = true
  end

  function frame:UnregisterEvent(event)
    self._events[event] = nil
  end

  function frame:IsEventRegistered(event)
    return self._events[event] == true
  end

  function frame:FireEvent(event, ...)
    local onEvent = self._scripts.OnEvent
    if onEvent then
      onEvent(self, event, ...)
    end
  end

  function frame.EnableMouse(_self) end
  function frame.RegisterForClicks(_self) end
  function frame.RegisterForDrag(_self) end
  function frame.SetMovable(_self) end
  function frame:StartMoving()
    self._startMovingCalls = (self._startMovingCalls or 0) + 1
  end
  function frame:StopMovingOrSizing()
    self._stopMovingCalls = (self._stopMovingCalls or 0) + 1
  end
  function frame.SetBackdrop(_self) end
  function frame.SetBackdropColor(_self) end
  function frame:SetFrameStrata(value)
    self._frameStrata = value
  end
  function frame:GetFrameStrata()
    return self._frameStrata or "MEDIUM"
  end
  function frame:SetFrameLevel(value)
    self._frameLevel = value
  end
  function frame:GetFrameLevel()
    return self._frameLevel or 1
  end
  function frame.SetClampedToScreen(_self) end
  function frame.SetAllPoints(_self) end
  function frame.SetDrawEdge(_self, _value) end
  function frame:SetNormalTexture(texture)
    self.normalTexture = texture
  end
  function frame:SetPushedTexture(texture)
    self.pushedTexture = texture
  end
  function frame:SetHighlightTexture(texture)
    self.highlightTexture = texture
  end
  function frame:SetShown(shown)
    self._shown = shown and true or false
  end
  function frame:SetScale(value)
    self._scale = value
  end

  function frame.CreateTexture()
    return NewRecordedTexture()
  end

  function frame:CreateFontString()
    local fontString = NewRecordedFontString()
    self._fontStrings = self._fontStrings or {}
    table.insert(self._fontStrings, fontString)
    return fontString
  end

  function frame.CreateAnimationGroup(_self)
    return NewRecordedAnimationGroup()
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

  function frame:GetFrameStrata()
    return self._frameStrata or "MEDIUM"
  end

  function frame:GetFrameLevel()
    return self._frameLevel or 1
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

local function BuildRosterPanelController(WithGlobals, LoadAddonModules, overrides)
  local createdFrames = {}
  local addon
  local mainFrame
  overrides = overrides or {}
  local decorateFrame = type(overrides.decorateFrame) == "function" and overrides.decorateFrame or nil

  local stubs = {
    CreateFrame = function(frameType, name, parent, template)
      local frame = NewRecordedFrame(createdFrames, frameType, name, parent, template)
      if decorateFrame then
        local decoratedFrame = decorateFrame(frame, frameType, name, parent, template)
        if decoratedFrame ~= nil then
          frame = decoratedFrame
        end
      end
      return frame
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
  for key, value in pairs(overrides.stubs or {}) do
    stubs[key] = value
  end

  WithGlobals(stubs, function()
    addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
  end)

  local controller
  WithGlobals(stubs, function()
    mainFrame = NewRecordedMainFrame(createdFrames)
    local controllerOpts = {
      mainFrame = mainFrame,
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
      setMainFrameWidthSafe = function() end,
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
    }
    for key, value in pairs(overrides.opts or {}) do
      controllerOpts[key] = value
    end
    controller = addon.RosterPanel.CreateController(controllerOpts)
  end)

  return controller, createdFrames, stubs, mainFrame
end

local function FindSecureRoleButton(createdFrames, unit)
  for _, frame in ipairs(createdFrames) do
    if frame._template == "SecureActionButtonTemplate" then
      local macrotext1 = frame:GetAttribute("macrotext1")
      if unit == nil or (type(macrotext1) == "string" and macrotext1:find("/target " .. unit, 1, true) ~= nil) then
        return frame
      end
    end
  end
  return nil
end

local function FindCombatRetryFrame(createdFrames)
  for _, frame in ipairs(createdFrames) do
    if frame:IsEventRegistered("PLAYER_REGEN_ENABLED") then
      return frame
    end
  end
  return nil
end

local function FindTankHelperButtons(createdFrames)
  local buttons = {}
  for _, frame in ipairs(createdFrames) do
    if frame._template == "SecureActionButtonTemplate" and type(frame.GetAttribute) == "function" then
      if frame:GetAttribute("type1") == "worldmarker" and frame:GetAttribute("type2") == "worldmarker" then
        table.insert(buttons, frame)
      end
    end
  end
  return buttons
end

local function FindCollapseButton(createdFrames)
  for _, frame in ipairs(createdFrames) do
    if frame._collapseLayoutMode == "compact_vertical" then
      return frame
    end
  end
  return nil
end

local function FindHorizontalCollapseButton(createdFrames)
  for _, frame in ipairs(createdFrames) do
    if frame._collapseLayoutMode == "compact_horizontal" then
      return frame
    end
  end
  return nil
end

local function RequireNonNil(value, message)
  assert(value ~= nil, message or "expected non-nil value")
  return value
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

local function RegisterTeleportTaintTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TAINT: Teleport secure spell apply avoids attribute writes during combat", function()
    local createdFrames = {}
    local inCombat = true
    local attributes = {}

    local button = {
      SetAttribute = function(_self, key, value)
        if inCombat then
          error("secure attribute write attempted during combat")
        end
        attributes[key] = value
      end,
      EnableMouse = function(_self, value)
        attributes.enableMouse = value
      end,
    }

    WithGlobals({
      CreateFrame = function(frameType, name, parent, template)
        return NewRecordedFrame(createdFrames, frameType, name, parent, template)
      end,
      InCombatLockdown = function()
        return inCombat
      end,
      C_Spell = {
        GetSpellName = function(spellID)
          return "Spell-" .. tostring(spellID)
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_teleport.lua" })

      local ok, err = pcall(function()
        local applied = addon.Teleport.ApplySecureSpellToButton(button, 445414)
        Assert.False(applied, "combat apply must defer secure spell attributes")
      end)
      Assert.True(ok, "combat deferral must not attempt secure attributes immediately: " .. tostring(err))

      local retryFrame = FindCombatRetryFrame(createdFrames)
      Assert.NotNil(retryFrame, "combat deferral should register a regen retry frame")
      retryFrame = RequireNonNil(retryFrame, "combat deferral should register a regen retry frame")

      inCombat = false
      retryFrame:FireEvent("PLAYER_REGEN_ENABLED")

      Assert.Equal(attributes.type, "spell", "regen retry should restore spell action type")
      Assert.Equal(attributes.spell, "Spell-445414", "regen retry should restore spell payload")
      Assert.True(attributes.enableMouse, "regen retry should re-enable mouse interaction")
    end)
  end)

  test("TAINT: TeleportUI keeps insecure teleport buttons combat-safe while secure spell apply is deferred", function()
    local cleanupTraps = RegisterProtectedApiTraps()
    local createdFrames = {}
    local inCombat = true

    local ok, err = pcall(function()
      WithGlobals({
        CreateFrame = function(frameType, name, parent, template)
          return NewRecordedFrame(createdFrames, frameType, name, parent, template)
        end,
        InCombatLockdown = function()
          return inCombat
        end,
        UIParent = {
          GetEffectiveScale = function()
            return 1
          end,
        },
        C_Spell = {
          GetSpellName = function(spellID)
            return "Spell-" .. tostring(spellID)
          end,
          GetSpellTexture = function()
            return nil
          end,
        },
      }, function()
        local addon = LoadAddonModules({
          "isiLive_ui_common.lua",
          "isiLive_teleport.lua",
          "isiLive_teleport_ui.lua",
        })

        local controller = addon.TeleportUI.CreateController({
          mainFrame = NewRecordedMainFrame(createdFrames),
          applySecureSpellToButton = addon.Teleport.ApplySecureSpellToButton,
          getEntries = function()
            return {
              { spellID = 445414, mapID = 2662, mapName = "The Dawnbreaker" },
            }
          end,
          getL = function()
            return {}
          end,
          isSpellKnown = function()
            return true
          end,
          getTeleportCooldownRemaining = function()
            return 0
          end,
          formatCooldownSeconds = function()
            return ""
          end,
          getSpellCooldownSafe = function()
            return 0, 0, true
          end,
          applyCooldownFrameSafe = function() end,
          getSpellTexture = function()
            return nil
          end,
          isInCombat = function()
            return inCombat
          end,
        })

        controller.BuildButtons()
        controller.UpdateButtons(445414)

        local button = controller.GetButtons()[1]
        Assert.NotNil(button, "TeleportUI should create one teleport button")
        Assert.Equal(
          button._template,
          "InsecureActionButtonTemplate",
          "TeleportUI grid button must stay insecure to avoid protected-parent taint"
        )

        local retryFrame = FindCombatRetryFrame(createdFrames)
        Assert.NotNil(retryFrame, "combat teleport update should queue regen retry")
        retryFrame = RequireNonNil(retryFrame, "combat teleport update should queue regen retry")

        inCombat = false
        retryFrame:FireEvent("PLAYER_REGEN_ENABLED")

        Assert.Equal(button:GetAttribute("type"), "spell", "regen retry should eventually restore teleport spell type")
      end)
    end)

    cleanupTraps()
    Assert.True(ok, "TeleportUI combat path must not hit protected globals or crash: " .. tostring(err))
  end)
end

local function RegisterRosterPanelRoleButtonTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster role icon is a secure action button", function()
    local controller, createdFrames, stubs = BuildRosterPanelController(WithGlobals, LoadAddonModules)

    WithGlobals(stubs, function()
      controller.RenderRoster({
        player = { name = "Tank", role = "TANK", class = "WARRIOR" },
      })
    end)

    local roleButton = FindSecureRoleButton(createdFrames, "player")
    Assert.NotNil(roleButton, "tank row should create a role button")
    roleButton = RequireNonNil(roleButton, "tank row should create a role button")
    Assert.Equal(roleButton._template, "SecureActionButtonTemplate", "role icon must use a secure action button")
    Assert.Equal(roleButton:GetAttribute("type1"), "macro", "left click must be wired as a secure macro action")
    Assert.Equal(roleButton:GetAttribute("type2"), "macro", "right click must be wired as a secure macro action")
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
    roleButton = RequireNonNil(roleButton, "tank row should create a role button")
    Assert.Equal(
      roleButton:GetAttribute("macrotext1"),
      "/target player\n/tm 6\n/targetlasttarget",
      "tank role button must mark Blue Square"
    )
    Assert.Equal(
      roleButton:GetAttribute("macrotext2"),
      "/target player\n/tm 0\n/targetlasttarget",
      "tank role button right click must clear marker"
    )
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
    roleButton = RequireNonNil(roleButton, "healer row should create a role button")
    Assert.Equal(
      roleButton:GetAttribute("macrotext1"),
      "/target party1\n/tm 4\n/targetlasttarget",
      "healer role button must mark Green Triangle"
    )
    Assert.Equal(
      roleButton:GetAttribute("macrotext2"),
      "/target party1\n/tm 0\n/targetlasttarget",
      "healer role button right click must clear marker"
    )
  end)
end

local function RegisterRosterPanelReadyCheckTaintTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TAINT: Ready-check refresh preserves secure role button attributes", function()
    local readyCheckActive = false
    local roster = {
      player = { name = "Tank", role = "TANK", class = "WARRIOR" },
    }
    local controller, createdFrames, stubs = BuildRosterPanelController(WithGlobals, LoadAddonModules, {
      opts = {
        buildDisplayData = function(info)
          return {
            colorHex = readyCheckActive and "ff00ff00" or "ffffffff",
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
        end,
        getRoster = function()
          return roster
        end,
        isReadyCheckActive = function()
          return readyCheckActive
        end,
      },
    })

    WithGlobals(stubs, function()
      controller.RenderRoster(roster)
    end)

    local roleButton = FindSecureRoleButton(createdFrames, "player")
    Assert.NotNil(roleButton, "tank row should create a secure role button before ready-check refresh")
    local type1Before = roleButton:GetAttribute("type1")
    local type2Before = roleButton:GetAttribute("type2")
    local macrotext1Before = roleButton:GetAttribute("macrotext1")
    local macrotext2Before = roleButton:GetAttribute("macrotext2")

    readyCheckActive = true
    WithGlobals(stubs, function()
      controller.RefreshReadyCheckState(roster)
    end)

    Assert.Equal(
      roleButton:GetAttribute("type1"),
      type1Before,
      "ready-check refresh must not rewrite the secure left-click role-button type"
    )
    Assert.Equal(
      roleButton:GetAttribute("type2"),
      type2Before,
      "ready-check refresh must not rewrite the secure right-click role-button type"
    )
    Assert.Equal(
      roleButton:GetAttribute("macrotext1"),
      macrotext1Before,
      "ready-check refresh must preserve the secure left-click role-button macro"
    )
    Assert.Equal(
      roleButton:GetAttribute("macrotext2"),
      macrotext2Before,
      "ready-check refresh must preserve the secure right-click role-button macro"
    )
  end)

  test("Ready-check dedicated refresh resets spec color after a ready-check rerender", function()
    local function findFontStringByText(mainFrameRef, expectedText)
      for _, fontString in ipairs(mainFrameRef._fontStrings or {}) do
        if fontString:GetText() == expectedText then
          return fontString
        end
      end
      return nil
    end

    local readyCheckActive = false
    local roster = {
      player = {
        name = "Tank",
        role = "TANK",
        class = "WARRIOR",
        spec = "Prot",
      },
    }
    local controller, createdFrames, stubs, mainFrame = BuildRosterPanelController(WithGlobals, LoadAddonModules, {
      opts = {
        buildDisplayData = function(info)
          return {
            colorHex = readyCheckActive and "ff00ff00" or "ffc69b6d",
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
        end,
        getRoster = function()
          return roster
        end,
        isReadyCheckActive = function()
          return readyCheckActive
        end,
      },
    })

    WithGlobals(stubs, function()
      controller.RenderRoster(roster)
    end)

    local roleButton = FindSecureRoleButton(createdFrames, "player")
    Assert.NotNil(roleButton, "tank row should create a secure role button before ready-check refresh")
    Assert.NotNil(
      findFontStringByText(mainFrame, "|cffc69b6dProt|r"),
      "initial render must show the class-colored spec text"
    )

    readyCheckActive = true
    WithGlobals(stubs, function()
      controller.RenderRoster(roster)
    end)
    Assert.NotNil(
      findFontStringByText(mainFrame, "|cff00ff00Prot|r"),
      "full rerender during ready check must recolor the spec text"
    )

    readyCheckActive = false
    WithGlobals(stubs, function()
      controller.RefreshReadyCheckState(roster)
    end)

    Assert.NotNil(
      findFontStringByText(mainFrame, "|cffc69b6dProt|r"),
      "dedicated ready-check refresh must restore the class-colored spec text after ready check ends"
    )
  end)
end

local function RegisterRosterPanelCombatTaintTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TAINT: M+Marker buttons stay secure world-marker buttons and touch no protected globals", function()
    local cleanupTraps = RegisterProtectedApiTraps()
    local ok, err = pcall(function()
      local _, createdFrames = BuildRosterPanelController(WithGlobals, LoadAddonModules)
      local tankButtons = FindTankHelperButtons(createdFrames)
      Assert.Equal(#tankButtons, 8, "M+Marker should expose eight secure world-marker buttons")
    end)

    cleanupTraps()
    Assert.True(ok, "tank helper setup must not touch protected globals: " .. tostring(err))
  end)

  test("TAINT: M2 roster rerender skips secure tank-helper layout mutations during combat", function()
    local inCombat = false
    local controller, createdFrames, stubs = BuildRosterPanelController(WithGlobals, LoadAddonModules, {
      decorateFrame = function(frame, _frameType, _name, _parent, template)
        if template == "SecureActionButtonTemplate" then
          local baseSetSize = frame.SetSize
          local baseSetPoint = frame.SetPoint
          local baseClearAllPoints = frame.ClearAllPoints

          function frame:SetSize(width, height)
            if inCombat then
              error("secure SetSize must not run during combat rerender")
            end
            baseSetSize(self, width, height)
          end

          function frame:SetPoint(...)
            if inCombat then
              error("secure SetPoint must not run during combat rerender")
            end
            baseSetPoint(self, ...)
          end

          function frame:ClearAllPoints()
            if inCombat then
              error("secure ClearAllPoints must not run during combat rerender")
            end
            baseClearAllPoints(self)
          end
        end

        return frame
      end,
      stubs = {
        IsiLiveDB = {
          rosterDefaultLayoutMode = "compact_main_horizontal",
        },
      },
    })

    WithGlobals(stubs, function()
      controller.RestoreSavedState()
      controller.RenderRoster({
        player = { name = "Tank", role = "TANK", class = "WARRIOR" },
      })
    end)

    local tankButtons = FindTankHelperButtons(createdFrames)
    Assert.Equal(#tankButtons, 8, "secure world-marker buttons should exist before combat rerender")

    inCombat = true
    stubs.InCombatLockdown = function()
      return true
    end

    local ok, err = pcall(function()
      WithGlobals(stubs, function()
        controller.RenderRoster({
          player = { name = "Tank", role = "TANK", class = "WARRIOR" },
        })
      end)
    end)

    Assert.True(ok, "combat rerender must not mutate secure tank-helper layout: " .. tostring(err))
  end)

  test("TAINT: Collapse click switches layout during combat while secure roster buttons exist", function()
    local controller, createdFrames, stubs = BuildRosterPanelController(WithGlobals, LoadAddonModules)

    WithGlobals(stubs, function()
      controller.RenderRoster({
        player = { name = "Tank", role = "TANK", class = "WARRIOR" },
      })
    end)

    local collapseButton = FindCollapseButton(createdFrames)
    local roleButton = FindSecureRoleButton(createdFrames, "player")

    Assert.NotNil(collapseButton, "collapse button should exist")
    Assert.NotNil(roleButton, "secure role button should exist before combat collapse test")
    collapseButton = RequireNonNil(collapseButton, "collapse button should exist")
    Assert.False(controller.IsCollapsed(), "panel should start expanded")

    stubs.InCombatLockdown = function()
      return true
    end

    local ok, err = pcall(function()
      WithGlobals(stubs, function()
        collapseButton.OnClick(collapseButton)
      end)
    end)

    Assert.True(ok, "combat collapse click must not crash on secure child buttons: " .. tostring(err))
    Assert.True(controller.IsCollapsed(), "combat collapse click should switch to the requested compact layout")
  end)

  test("TAINT: Horizontal collapse click switches layout during combat while secure roster buttons exist", function()
    local controller, createdFrames, stubs = BuildRosterPanelController(WithGlobals, LoadAddonModules)

    WithGlobals(stubs, function()
      controller.RenderRoster({
        player = { name = "Tank", role = "TANK", class = "WARRIOR" },
      })
    end)

    local collapseButton = FindHorizontalCollapseButton(createdFrames)
    local roleButton = FindSecureRoleButton(createdFrames, "player")

    Assert.NotNil(collapseButton, "horizontal collapse button should exist")
    Assert.NotNil(roleButton, "secure role button should exist before combat collapse test")
    collapseButton = RequireNonNil(collapseButton, "horizontal collapse button should exist")
    Assert.False(controller.IsCollapsed(), "panel should start expanded")

    stubs.InCombatLockdown = function()
      return true
    end

    local ok, err = pcall(function()
      WithGlobals(stubs, function()
        collapseButton.OnClick(collapseButton)
      end)
    end)

    Assert.True(ok, "combat horizontal collapse click must not crash on secure child buttons: " .. tostring(err))
    Assert.True(
      controller.IsCollapsed(),
      "combat horizontal collapse click should switch to the requested compact layout"
    )
  end)
end

local function RegisterNoticeTaintTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TAINT: Center notice teleport button stays insecure and avoids secure apply while in combat", function()
    local createdFrames = {}
    local inCombat = true
    local applyCalls = 0

    WithGlobals({
      CreateFrame = function(frameType, name, parent, template)
        return NewRecordedFrame(createdFrames, frameType, name, parent, template)
      end,
      UIParent = NewRecordedMainFrame(createdFrames),
      InCombatLockdown = function()
        return inCombat
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local notice = addon.Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return inCombat
        end,
        resolveTeleportSpellID = function()
          return 445414
        end,
        applySecureSpellToButton = function()
          applyCalls = applyCalls + 1
          error("secure spell apply must not run from in-combat notice configuration")
        end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function()
          return ""
        end,
        getL = function()
          return {}
        end,
      })

      local ok, err = pcall(function()
        local configured = notice.ConfigureTeleportButton("The Dawnbreaker", 2662)
        Assert.True(configured, "notice should resolve a teleport button when spell is available")
      end)

      Assert.True(ok, "combat notice configuration must avoid secure spell apply: " .. tostring(err))
      Assert.Equal(
        notice.teleportButton._template,
        "InsecureActionButtonTemplate",
        "center notice teleport button must stay insecure to avoid protected-parent taint"
      )
      Assert.Equal(applyCalls, 0, "combat notice configuration must not call secure spell apply")
      Assert.Equal(notice.teleportButton.spellID, 445414, "combat notice path should still store resolved spell id")
      Assert.True(notice.teleportButton.inCombatBlocked, "combat notice path should flag teleport button as blocked")
    end)
  end)

  test("TAINT: portal navigator supports an independent frame name", function()
    local createdFrames = {}

    WithGlobals({
      CreateFrame = function(frameType, name, parent, template)
        return NewRecordedFrame(createdFrames, frameType, name, parent, template)
      end,
      UIParent = NewRecordedMainFrame(createdFrames),
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })

      local portalNotice = addon.Notice.CreatePortalNavigatorNotice({
        parent = UIParent,
        frameName = "isiLivePortalNavigatorNotice",
        isInCombat = function()
          return false
        end,
      })

      Assert.Equal(
        portalNotice.frame._name,
        "isiLivePortalNavigatorNotice",
        "portal navigator notice should use its own frame name"
      )
      Assert.NotNil(portalNotice.closeButton, "portal navigator notice should still expose a close button")
      Assert.NotNil(portalNotice.entries, "portal navigator notice should expose entry widgets")
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterGroupTaintTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTeleportTaintTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRoleButtonTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelReadyCheckTaintTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelCombatTaintTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterNoticeTaintTests(test, Assert, WithGlobals, LoadAddonModules)
end
