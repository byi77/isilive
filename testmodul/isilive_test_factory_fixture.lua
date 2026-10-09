---@diagnostic disable: undefined-global, undefined-field, unused-local, unused-vararg

local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack")) or nil

-- Composition-root integration test for factory/isiLive_factory.lua.
--
-- The existing factory_primary/factory_secondary scenarios stub every
-- isiLive module and call InitializeFactory*Controllers directly; they
-- never exercise Factory.InitializeAddon end-to-end. This file does:
-- it loads all real isiLive modules under a minimal WoW-API stub and
-- runs Factory.InitializeAddon("isiLive", addonTable). That drives
-- CreateFactoryContext + the four Initialize* phases +
-- FinalizeFactoryRuntime + FinalizeFactorySettings on a single happy
-- path, covering the otherwise-unreachable orchestration bodies.

local function BuildFrameStub()
  local frame = {
    _scripts = {},
    _registeredEvents = {},
    _points = {},
    _textures = {},
    _fontStrings = {},
    _children = {},
    _shown = false,
    _alpha = 1,
    _scale = 1,
    _size = { 0, 0 },
    _movable = false,
    _clampedToScreen = false,
    _backdrop = nil,
    _backdropColor = { 0, 0, 0, 0 },
    _frameStrata = "MEDIUM",
    _frameLevel = 1,
    _clipsChildren = false,
    _hyperlinksEnabled = false,
    _attributes = {},
  }

  -- Every single Widget method is a no-op that returns self where
  -- plausible. The addon's UI layer calls dozens of these; any missing
  -- one would blow up the composition. We therefore install a metatable
  -- catch-all for unknown methods so new WoW widget calls do not break
  -- the test whenever isiLive adds UI code.
  local explicit = {}
  function explicit:SetScript(name, fn)
    self._scripts[name] = fn
  end
  function explicit:GetScript(name)
    return self._scripts[name]
  end
  function explicit:RegisterEvent(event)
    self._registeredEvents[event] = true
  end
  function explicit:RegisterUnitEvent(event, ...)
    self._registeredEvents[event] = { ... }
  end
  function explicit:UnregisterEvent(event)
    self._registeredEvents[event] = nil
  end
  function explicit:UnregisterAllEvents()
    self._registeredEvents = {}
  end
  function explicit:IsEventRegistered(event)
    return self._registeredEvents[event] == true
  end
  function explicit:SetPoint(...)
    self._points[#self._points + 1] = { ... }
  end
  function explicit:ClearAllPoints()
    self._points = {}
  end
  function explicit:IsShown()
    return self._shown == true
  end
  function explicit:IsVisible()
    return self._shown == true and (self._parent == nil or self._parent:IsVisible())
  end
  function explicit:RefreshVisibility()
    local visible = self:IsVisible()
    if visible ~= (self._visible == true) then
      self._visible = visible
      local callback = self._scripts[visible and "OnShow" or "OnHide"]
      if callback then
        callback(self)
      end
    end
    for _, child in ipairs(self._children) do
      child:RefreshVisibility()
    end
  end
  function explicit:Show()
    self._shown = true
    self:RefreshVisibility()
  end
  function explicit:Hide()
    self._shown = false
    self:RefreshVisibility()
  end
  function explicit:GetParent()
    return self._parent
  end
  function explicit:SetParent(parent)
    if self._parent then
      for index, child in ipairs(self._parent._children) do
        if child == self then
          table.remove(self._parent._children, index)
          break
        end
      end
    end
    self._parent = parent
    if parent then
      parent._children[#parent._children + 1] = self
    end
    self:RefreshVisibility()
  end
  function explicit:SetAlpha(a)
    self._alpha = a
  end
  function explicit:GetAlpha()
    return self._alpha
  end
  function explicit:SetScale(s)
    self._scale = s
  end
  function explicit:GetScale()
    return self._scale
  end
  function explicit:GetEffectiveScale()
    return self._scale
  end
  function explicit:SetSize(w, h)
    self._size = { w, h }
  end
  function explicit:GetSize()
    return self._size[1], self._size[2]
  end
  function explicit:GetWidth()
    return self._size[1] or 0
  end
  function explicit:GetHeight()
    return self._size[2] or 0
  end
  function explicit:SetWidth(w)
    self._size[1] = w
  end
  function explicit:SetHeight(h)
    self._size[2] = h
  end
  function explicit:SetMovable(v)
    self._movable = v
  end
  function explicit:IsMovable()
    return self._movable == true
  end
  function explicit:SetClampedToScreen(v)
    self._clampedToScreen = v
  end
  function explicit:SetClipsChildren(v)
    self._clipsChildren = v
  end
  function explicit:SetBackdrop(b)
    self._backdrop = b
  end
  function explicit:GetBackdrop()
    return self._backdrop
  end
  function explicit:SetBackdropColor(r, g, b, a)
    self._backdropColor = { r, g, b, a }
  end
  function explicit:GetBackdropColor()
    local c = self._backdropColor
    return c[1], c[2], c[3], c[4]
  end
  function explicit:SetBackdropBorderColor(_r, _g, _b, _a) end
  function explicit:SetFrameStrata(s)
    self._frameStrata = s
  end
  function explicit:GetFrameStrata()
    return self._frameStrata
  end
  function explicit:SetFrameLevel(l)
    self._frameLevel = l
  end
  function explicit:GetFrameLevel()
    return self._frameLevel
  end
  function explicit:GetName()
    return self._name
  end
  function explicit:CreateTexture(_name, _layer)
    local t = BuildFrameStub()
    self._textures[#self._textures + 1] = t
    return t
  end
  function explicit:CreateFontString(_name, _layer, _template)
    local fs = BuildFrameStub()
    fs._text = ""
    function fs:SetText(text)
      self._text = text or ""
    end
    function fs:GetText()
      return self._text
    end
    function fs:SetFont(_path, _size, _flags) end
    function fs:SetTextColor(_r, _g, _b, _a) end
    function fs:SetJustifyH(_j) end
    function fs:SetJustifyV(_j) end
    self._fontStrings[#self._fontStrings + 1] = fs
    return fs
  end
  function explicit:SetAttribute(k, v)
    self._attributes[k] = v
  end
  function explicit:GetAttribute(k)
    return self._attributes[k]
  end
  function explicit:SetAttributeNoHandler(k, v)
    self._attributes[k] = v
  end
  function explicit:EnableMouse(_v) end
  function explicit:EnableMouseWheel(_v) end
  function explicit:EnableKeyboard(_v) end
  function explicit:SetHyperlinksEnabled(v)
    self._hyperlinksEnabled = v
  end
  function explicit:RegisterForClicks(...) end
  function explicit:RegisterForDrag(...) end
  function explicit:StartMoving() end
  function explicit:StopMovingOrSizing() end
  function explicit:GetCenter()
    return 0, 0
  end
  function explicit:GetLeft()
    return 0
  end
  function explicit:GetRight()
    return 0
  end
  function explicit:GetTop()
    return 0
  end
  function explicit:GetBottom()
    return 0
  end
  function explicit:SetTexture(_p) end
  function explicit:SetTexCoord(...) end
  function explicit:SetColorTexture(...) end
  function explicit:SetVertexColor(...) end
  function explicit:SetBlendMode(_m) end
  function explicit:SetDrawLayer(...) end
  function explicit:GetObjectType()
    return "Frame"
  end
  function explicit:HookScript(name, fn)
    local existing = self._scripts[name]
    if existing then
      local combined = function(...)
        existing(...)
        fn(...)
      end
      self._scripts[name] = combined
    else
      self._scripts[name] = fn
    end
  end
  function explicit:SetPropagateKeyboardInput(_v) end
  function explicit:SetResizable(_v) end
  function explicit:SetMinResize(...) end
  function explicit:SetMaxResize(...) end
  function explicit:SetClampRectInsets(...) end
  function explicit:SetUserPlaced(_v) end
  function explicit:IsUserPlaced()
    return false
  end
  function explicit:IsForbidden()
    return false
  end
  function explicit:IsProtected()
    return false, false
  end
  function explicit:SetMouseMotionEnabled(_v) end
  function explicit:SetMouseClickEnabled(_v) end
  function explicit:IsMouseEnabled()
    return false
  end
  function explicit:GetNormalTexture()
    local t = BuildFrameStub()
    return t
  end
  function explicit:GetHighlightTexture()
    local t = BuildFrameStub()
    return t
  end
  function explicit:GetPushedTexture()
    local t = BuildFrameStub()
    return t
  end
  function explicit:SetNormalTexture(_t) end
  function explicit:SetHighlightTexture(_t) end
  function explicit:SetPushedTexture(_t) end
  function explicit:GetFontString()
    local fs = BuildFrameStub()
    return fs
  end
  function explicit:SetText(_t) end
  function explicit:SetDisabledFontObject(_f) end
  function explicit:SetNormalFontObject(_f) end
  function explicit:SetHighlightFontObject(_f) end
  function explicit:SetDisabled(_v) end
  function explicit:Disable() end
  function explicit:Enable() end
  function explicit:IsEnabled()
    return true
  end
  function explicit:Click(...) end
  function explicit:GetChildren()
    return unpack(self._children or {})
  end
  function explicit:GetNumChildren()
    return #(self._children or {})
  end
  function explicit:SetID(_id) end
  function explicit:GetID()
    return 0
  end
  function explicit:SetShown(v)
    if v then
      explicit.Show(self)
    else
      explicit.Hide(self)
    end
  end

  for k, v in pairs(explicit) do
    frame[k] = v
  end

  setmetatable(frame, {
    __index = function(t, key)
      -- Any unknown WoW widget method becomes a silent no-op that
      -- returns the frame so chaining like frame:SetSize(..):Show() does
      -- not blow up the composition. Only synthesize for PascalCase
      -- method names (WoW widget convention) - internal isiLive fields
      -- use snake_case or _leadingUnderscore and must resolve to nil so
      -- `self._someCache or {}` works correctly in addon code.
      if type(key) ~= "string" or key:sub(1, 1):match("[A-Z]") == nil then
        return nil
      end
      local fn = function()
        return t
      end
      t[key] = fn
      return fn
    end,
  })

  return frame
end

local function BuildCooldownFrameStub()
  local cd = BuildFrameStub()
  function cd:SetCooldown(_start, _duration) end
  function cd:Clear() end
  function cd:SetDrawBling(_v) end
  function cd:SetDrawEdge(_v) end
  function cd:SetDrawSwipe(_v) end
  function cd:SetHideCountdownNumbers(_v) end
  return cd
end

local function BuildCreateFrame()
  return function(frameType, _name, parent, _template, _id)
    local frame = frameType == "Cooldown" and BuildCooldownFrameStub() or BuildFrameStub()
    frame:SetParent(parent)
    return frame
  end
end

local function BuildGlobals()
  local uiParent = BuildFrameStub()
  uiParent:Show()
  local db = {
    locale = "enUS",
    syncEnabled = true,
    autoOpenOnQueue = true,
    autoCloseMainFrame = false,
    autoShowMainFrameOnStartup = true,
    autoOpenMainFrameOnKeyEnd = true,
    lockMainFramePosition = true,
    runtimeLogLevel = "normal",
  }

  local globals = {
    UIParent = uiParent,
    WorldFrame = BuildFrameStub(),
    Minimap = BuildFrameStub(),
    GameTooltip = BuildFrameStub(),
    DEFAULT_CHAT_FRAME = BuildFrameStub(),
    CreateFrame = BuildCreateFrame(),
    GetLocale = function()
      return "enUS"
    end,
    GetAddOnMetadata = function(_, field)
      if field == "Version" then
        return "0.9.120"
      end
      return nil
    end,
    C_AddOns = {
      GetAddOnMetadata = function(_, field)
        if field == "Version" then
          return "0.9.120"
        end
        return nil
      end,
      IsAddOnLoaded = function()
        return false
      end,
    },
    IsInGroup = function()
      return false
    end,
    IsInRaid = function()
      return false
    end,
    GetNumGroupMembers = function()
      return 0
    end,
    UnitExists = function(unit)
      return unit == "player"
    end,
    UnitIsGroupLeader = function()
      return true
    end,
    UnitName = function(unit)
      if unit == "player" then
        return "Tester", "Realm"
      end
      return nil
    end,
    UnitFullName = function(unit)
      if unit == "player" then
        return "Tester", "Realm"
      end
      return nil
    end,
    GetUnitName = function(unit, _withRealm)
      if unit == "player" then
        return "Tester-Realm"
      end
      return unit
    end,
    UnitClass = function(unit)
      if unit == "player" then
        return "Mage", "MAGE", 8
      end
      return nil
    end,
    UnitRace = function()
      return "Human", "Human", 1
    end,
    UnitSex = function()
      return 2
    end,
    UnitLevel = function()
      return 80
    end,
    UnitGUID = function()
      return "Player-1-12345"
    end,
    UnitGroupRolesAssigned = function()
      return "DAMAGER"
    end,
    GetRealmName = function()
      return "Realm"
    end,
    GetNormalizedRealmName = function()
      return "Realm"
    end,
    GetTime = function()
      return 0
    end,
    InCombatLockdown = function()
      return false
    end,
    GetRaidTargetIndex = function()
      return nil
    end,
    SetRaidTarget = function() end,
    ReloadUI = function() end,
    hooksecurefunc = function() end,
    issecure = function()
      return true
    end,
    InterfaceOptions_AddCategory = function() end,
    Settings = {
      RegisterAddOnCategory = function() end,
      RegisterCanvasLayoutCategory = function(_, _name)
        return { ID = "isiLive-settings" }
      end,
      OpenToCategory = function() end,
    },
    C_Timer = {
      NewTicker = function(_interval, _callback)
        return { Cancel = function() end }
      end,
      NewTimer = function(_seconds, _callback)
        return { Cancel = function() end }
      end,
      After = function(_seconds, _callback) end,
    },
    C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return nil
      end,
      GetActiveKeystoneInfo = function()
        return 0, {}, 0
      end,
      GetMapUIInfo = function()
        return "Dungeon", 1, 1
      end,
    },
    C_Spell = {
      GetSpellInfo = function()
        return {
          name = "Spell",
          iconID = 0,
          spellID = 0,
        }
      end,
      GetSpellTexture = function()
        return nil
      end,
      GetSpellCooldown = function()
        return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 }
      end,
      IsSpellKnown = function()
        return false
      end,
      IsSpellUsable = function()
        return false
      end,
      GetSpellName = function()
        return "Spell"
      end,
    },
    C_Container = {
      GetContainerItemLink = function()
        return nil
      end,
      GetContainerNumSlots = function()
        return 0
      end,
      GetContainerItemInfo = function()
        return nil
      end,
    },
    C_Map = {
      GetBestMapForUnit = function()
        return nil
      end,
      GetMapInfo = function()
        return { name = "Map", mapType = 3 }
      end,
    },
    C_MythicPlus = {
      GetOwnedKeystoneChallengeMapID = function()
        return nil
      end,
      GetOwnedKeystoneLevel = function()
        return nil
      end,
      RequestMapInfo = function() end,
      GetSeasonBestForMap = function() end,
    },
    C_LFGList = {
      HasActiveEntryInfo = function()
        return false
      end,
      GetActiveEntryInfo = function()
        return nil
      end,
      GetApplications = function()
        return {}
      end,
    },
    GetSubZoneText = function()
      return ""
    end,
    GetZoneText = function()
      return ""
    end,
    GetRealZoneText = function()
      return ""
    end,
    GetInstanceInfo = function()
      return "None", "none"
    end,
    GetInspectSpecialization = function()
      return 0
    end,
    GetSpecialization = function()
      return 1
    end,
    GetSpecializationInfo = function()
      return 62, "Arcane", "desc", 0, "DAMAGER"
    end,
    GetSpecializationInfoForClassID = function()
      return 62, "Arcane", "desc", 0, "DAMAGER"
    end,
    Mixin = function(target, ...)
      for i = 1, select("#", ...) do
        local source = select(i, ...)
        if type(source) == "table" then
          for k, v in pairs(source) do
            target[k] = v
          end
        end
      end
      return target
    end,
    CreateFromMixins = function(...)
      local target = {}
      for i = 1, select("#", ...) do
        local source = select(i, ...)
        if type(source) == "table" then
          for k, v in pairs(source) do
            target[k] = v
          end
        end
      end
      return target
    end,
    SlashCmdList = {},
    IsiLiveDB = db,
    SOUNDKIT = {},
    PlaySoundFile = function() end,
    PlaySound = function() end,
    GameFontHighlight = {},
    GameFontNormal = {},
    GameFontNormalSmall = {},
    GameFontHighlightSmall = {},
    GameFontNormalLarge = {},
    GameFontHighlightLarge = {},
    ChatFontNormal = {},
    GameTooltipText = {},
    format = string.format,
    strsplit = function(sep, str)
      local parts = {}
      for part in tostring(str):gmatch("([^" .. sep .. "]+)") do
        table.insert(parts, part)
      end
      return unpack(parts)
    end,
    strtrim = function(s)
      return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
    end,
    strjoin = function(sep, ...)
      return table.concat({ ... }, sep)
    end,
    gsub = string.gsub,
    strlen = string.len,
    strlower = string.lower,
    strupper = string.upper,
    strsub = string.sub,
    strfind = string.find,
    strmatch = string.match,
    strrep = string.rep,
    strrev = string.reverse,
    strbyte = string.byte,
    strchar = string.char,
    strformat = string.format,
    wipe = function(t)
      if type(t) == "table" then
        for k in pairs(t) do
          t[k] = nil
        end
      end
      return t
    end,
    tContains = function(t, value)
      for _, v in ipairs(t or {}) do
        if v == value then
          return true
        end
      end
      return false
    end,
    tInvert = function(t)
      local r = {}
      for k, v in pairs(t or {}) do
        r[v] = k
      end
      return r
    end,
    tDeleteItem = function() end,
    max = math.max,
    min = math.min,
    abs = math.abs,
    floor = math.floor,
    ceil = math.ceil,
    CopyTable = function(t)
      local r = {}
      for k, v in pairs(t or {}) do
        r[k] = v
      end
      return r
    end,
    LibStub = function()
      return nil
    end,
    GetAddOnEnableState = function()
      return 2
    end,
    IsAddOnLoaded = function()
      return false
    end,
    debugprofilestop = function()
      return 0
    end,
    geterrorhandler = function()
      return function() end
    end,
    SetOverrideBindingClick = function() end,
    ClearOverrideBindings = function() end,
    GetBindingKey = function() end,
    SetBinding = function() end,
    SaveBindings = function() end,
    LoadBindings = function() end,
    GetCurrentBindingSet = function()
      return 1
    end,
    RegisterAddonMessagePrefix = function() end,
    C_ChatInfo = {
      RegisterAddonMessagePrefix = function()
        return true
      end,
      SendAddonMessage = function() end,
    },
    SendAddonMessage = function() end,
    SendChatMessage = function() end,
    ChatFrame_AddMessageEventFilter = function() end,
    ChatFrame1 = BuildFrameStub(),
    MinimapButtonFrame = nil,
    BackdropTemplateMixin = {
      OnBackdropLoaded = function() end,
    },
    SquareButton_SetIcon = function() end,
    RAID_CLASS_COLORS = setmetatable({}, {
      __index = function()
        return { r = 1, g = 1, b = 1, colorStr = "ffffffff" }
      end,
    }),
    CLASS_SORT_ORDER = {},
    LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, {
      __index = function(_, k)
        return k
      end,
    }),
    LOCALIZED_CLASS_NAMES_FEMALE = setmetatable({}, {
      __index = function(_, k)
        return k
      end,
    }),
  }

  return globals, db
end

-- All real isiLive files must be loaded for the composition to wire. Pull the
-- complete ordered list from the harness FILE_PATHS so new modules are picked
-- up automatically when they are added.
local function GetAllIsiLiveFiles()
  -- Mirrors tools/usecase_scenarios ordering constraints; deps are declared
  -- via IMPLICIT_DEPENDENCIES in the harness so we just hand in the full list.
  return {
    "isiLive_validation_helpers.lua",
    "isiLive_string_utils.lua",
    "isiLive_sound_utils.lua",
    "isiLive_event_utils.lua",
    "isiLive_runtime_state.lua",
    "isiLive_bootstrap.lua",
    "isiLive_context_helpers.lua",
    "isiLive_action_button_overlay.lua",
    "isiLive_runtime_setup.lua",
    "isiLive_log_buffer.lua",
    "isiLive_runtime_log.lua",
    "isiLive_guards.lua",
    "realm_language_data.lua",
    "isiLive_languages.lua",
    "isiLive_locale.lua",
    "isiLive_texts.lua",
    "isiLive_spell_utils.lua",
    "isiLive_cd_tracker.lua",
    "isiLive_season_data.lua",
    "isiLive_teleport.lua",
    "isiLive_teleport_debug.lua",
    "isiLive_units.lua",
    "isiLive_mplus_timer.lua",
    "isiLive_kick_tracker.lua",
    "isiLive_lfg_detect.lua",
    "isiLive_combat_events.lua",
    "isiLive_pi_tracker.lua",
    "isiLive_bloodlust_button_warning.lua",
    "isiLive_vip_dk_assist.lua",
    "isiLive_death_watch.lua",
    "isiLive_death_alert.lua",
    "isiLive_killtrack.lua",
    "isiLive_bindings.lua",
    "isiLive_ui_common.lua",
    "isiLive_teleport_ui.lua",
    "isiLive_trace_chat_frame.lua",
    "isiLive_notice.lua",
    "isiLive_status.lua",
    "isiLive_roster.lua",
    "isiLive_roster_tooltip.lua",
    "isiLive_mob_tooltip.lua",
    "isiLive_lfg_flags.lua",
    "isiLive_mob_nameplate.lua",
    "isiLive_roster_layout.lua",
    "isiLive_roster_panel_helpers.lua",
    "isiLive_roster_panel_chrome.lua",
    "isiLive_roster_panel_cd_row.lua",
    "isiLive_roster_panel_kill_row.lua",
    "isiLive_roster_panel_render.lua",
    "isiLive_roster_panel.lua",
    "isiLive_ui.lua",
    "isiLive_settings.lua",
    "isiLive_leader_watch.lua",
    "isiLive_demo.lua",
    "isiLive_test_mode.lua",
    "isiLive_sync.lua",
    "isiLive_keysync.lua",
    "isiLive_refresh.lua",
    "isiLive_highlight.lua",
    "isiLive_group.lua",
    "isiLive_queue.lua",
    "isiLive_queue_debug.lua",
    "isiLive_stats.lua",
    "isiLive_inspect.lua",
    "isiLive_events.lua",
    "isiLive_event_handlers_queue.lua",
    "isiLive_event_handlers_challenge.lua",
    "isiLive_event_handlers_runtime.lua",
    "isiLive_event_handlers.lua",
    "isiLive_commands.lua",
    "isiLive_controller_wiring.lua",
    "isiLive_config_builders.lua",
    "isiLive_frame_bridge.lua",
    "isiLive_controller_init.lua",
    "isiLive_factory_frame_bridge.lua",
    "isiLive_factory_kick_tracker.lua",
    "isiLive_factory_cd_tracker.lua",
    "isiLive_factory_status_helpers.lua",
    "isiLive_factory_runtime_helpers.lua",
    "isiLive_factory_demo.lua",
    "isiLive_factory_testmode_bindings.lua",
    "isiLive_factory_combat_announces.lua",
    "isiLive_factory_death_alert.lua",
    "isiLive_factory_localization.lua",
    "isiLive_factory_refresh.lua",
    "isiLive_factory_notices.lua",
    "isiLive_factory_lfg_wiring.lua",
    "isiLive_factory_secondary_runtime.lua",
    "isiLive_factory_primary.lua",
    "isiLive_factory_status.lua",
    "isiLive_factory_secondary.lua",
    "isiLive_factory_controllers.lua",
    "isiLive_factory_minimap.lua",
    "isiLive_factory.lua",
  }
end

return { buildGlobals = BuildGlobals, moduleFiles = GetAllIsiLiveFiles }
