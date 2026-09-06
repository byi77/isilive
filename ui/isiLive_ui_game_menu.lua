local _, addonTable = ...

addonTable = addonTable or {}

local UI = addonTable.UI or {}
addonTable.UI = UI
local IsSecretValue = addonTable.Validators.IsSecretValue
local GameMenuPanel = assert(addonTable.UIGameMenuPanel, "isiLive: UIGameMenuPanel missing")
local ResolvePanelUIButtonSize =
  assert(GameMenuPanel.ResolveButtonSize, "isiLive: UIGameMenuPanel.ResolveButtonSize missing")
local CreatePanelUIButton = assert(GameMenuPanel.CreateButton, "isiLive: UIGameMenuPanel.CreateButton missing")
local ApplyPanelUIBackdrop = assert(GameMenuPanel.ApplyBackdrop, "isiLive: UIGameMenuPanel.ApplyBackdrop missing")
local CreatePanelUIHeaderChrome =
  assert(GameMenuPanel.CreateHeaderChrome, "isiLive: UIGameMenuPanel.CreateHeaderChrome missing")
local GameMenuActions = assert(addonTable.UIGameMenuActions, "isiLive: UIGameMenuActions missing")
local MergePanelUIActions =
  assert(GameMenuActions.MergePanelUIActions, "isiLive: UIGameMenuActions.MergePanelUIActions missing")
local BuildAddonPanelUIActions =
  assert(GameMenuActions.BuildAddonPanelUIActions, "isiLive: UIGameMenuActions.BuildAddonPanelUIActions missing")
local ResolveVisibleAddonPanelEntries = assert(
  GameMenuActions.ResolveVisibleAddonPanelEntries,
  "isiLive: UIGameMenuActions.ResolveVisibleAddonPanelEntries missing"
)
local GameMenuMounts = assert(addonTable.UIGameMenuMounts, "isiLive: UIGameMenuMounts missing")
local ResolveVisibleMountPanelEntries = assert(
  GameMenuMounts.ResolveVisibleMountPanelEntries,
  "isiLive: UIGameMenuMounts.ResolveVisibleMountPanelEntries missing"
)
local MOUNT_PANEL_UI_ENTRIES =
  assert(GameMenuMounts.MOUNT_PANEL_UI_ENTRIES, "isiLive: UIGameMenuMounts.MOUNT_PANEL_UI_ENTRIES missing")
local GameMenuTravel = assert(addonTable.UIGameMenuTravel, "isiLive: UIGameMenuTravel missing")
local SECOND_PANEL_UI_ENTRIES =
  assert(GameMenuTravel.SECOND_PANEL_UI_ENTRIES, "isiLive: UIGameMenuTravel.SECOND_PANEL_UI_ENTRIES missing")
local CollectOwnedHearthstoneToys =
  assert(GameMenuTravel.CollectOwnedHearthstoneToys, "isiLive: UIGameMenuTravel.CollectOwnedHearthstoneToys missing")
local ResolveHearthstoneChoice =
  assert(GameMenuTravel.ResolveHearthstoneChoice, "isiLive: UIGameMenuTravel.ResolveHearthstoneChoice missing")
local DALARAN_HEARTHSTONE_TOY_ID =
  assert(GameMenuTravel.DALARAN_HEARTHSTONE_TOY_ID, "isiLive: UIGameMenuTravel.DALARAN_HEARTHSTONE_TOY_ID missing")
local IsDalaranHearthstoneAvailable = assert(
  GameMenuTravel.IsDalaranHearthstoneAvailable,
  "isiLive: UIGameMenuTravel.IsDalaranHearthstoneAvailable missing"
)
local PANEL_UI_BUTTON_GAP = GameMenuPanel.BUTTON_GAP
local PANEL_UI_SECTION_BREAK_GAP = GameMenuPanel.SECTION_BREAK_GAP
local SECOND_PANEL_GAP = 10
local PANEL_UI_ENTRIES = {
  {
    id = "professions",
    labelKey = "BTN_GAMEMENU_PROFESSIONS",
    fallbackText = "Professions",
    iconAtlas = "UI-HUD-MicroMenu-Professions-Up",
  },
  {
    id = "talents",
    labelKey = "BTN_GAMEMENU_TALENTS",
    fallbackText = "Talents",
    iconAtlas = "UI-HUD-MicroMenu-SpecTalents-Up",
  },
  {
    id = "spellbook",
    labelKey = "BTN_GAMEMENU_SPELLBOOK",
    fallbackText = "Spellbook",
    icon = "Interface\\Icons\\INV_Misc_Book_09",
  },
  {
    id = "achievements",
    labelKey = "BTN_GAMEMENU_ACHIEVEMENTS",
    fallbackText = "Achievements",
    iconAtlas = "UI-HUD-MicroMenu-Achievements-Up",
  },
  {
    id = "quests",
    labelKey = "BTN_GAMEMENU_QUESTS",
    fallbackText = "Quests",
    iconAtlas = "UI-HUD-MicroMenu-Questlog-Up",
  },
  {
    id = "dungeons",
    labelKey = "BTN_GAMEMENU_DUNGEONS",
    fallbackText = "Dungeons",
    iconAtlas = "UI-HUD-MicroMenu-Groupfinder-Up",
  },
  {
    id = "journal",
    labelKey = "BTN_GAMEMENU_JOURNAL",
    fallbackText = "Journal",
    iconAtlas = "UI-HUD-MicroMenu-AdventureGuide-Up",
  },
  {
    id = "collections",
    labelKey = "BTN_GAMEMENU_COLLECTIONS",
    fallbackText = "Collections",
    iconAtlas = "UI-HUD-MicroMenu-Collections-Up",
  },
  {
    id = "guild",
    labelKey = "BTN_GAMEMENU_GUILD",
    fallbackText = "Guild",
    iconAtlas = "UI-HUD-MicroMenu-GuildCommunities-Up",
  },
  {
    id = "reloadui",
    labelKey = "BTN_GAMEMENU_RELOADUI",
    fallbackText = "ReloadUI",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    gapBefore = PANEL_UI_SECTION_BREAK_GAP,
    secureMacroText = "/click GameMenuButtonContinue\n/reload",
  },
}
local housingSecureButton = nil
local housingDataEventFrame = nil
local hearthstoneSecureButton = nil
local hearthstoneToysEventFrame = nil
local dalaranHearthstoneSecureButton = nil
local dalaranHearthstoneToysEventFrame = nil
-- pendingHousingApply caches the most recent PLAYER_HOUSE_LIST_UPDATED payload
-- when SetAttribute is blocked by combat lockdown. The panelUISecureRetryFrame
-- below drains this on PLAYER_REGEN_ENABLED so the housing-teleport button gets
-- its `teleporthome` attributes after combat ends, instead of staying
-- permanently unconfigured.
local pendingHousingApply = nil

local function ApplyHousingAttributes(info, btn)
  if type(info) ~= "table" or type(btn) ~= "table" or type(btn.SetAttribute) ~= "function" then
    return false
  end
  local inCombat = rawget(_G, "InCombatLockdown")
  if type(inCombat) == "function" and inCombat() then
    pendingHousingApply = info
    return false
  end
  btn:SetAttribute("type", "teleporthome")
  btn:SetAttribute("house-neighborhood-guid", info.neighborhoodGUID)
  btn:SetAttribute("house-guid", info.houseGUID)
  btn:SetAttribute("house-plot-id", info.plotID)
  pendingHousingApply = nil
  return true
end

local panelUIState = nil
local secondPanelUIState = nil
local thirdPanelUIState = nil
local mountPanelUIState = nil
local PositionPanelUIButtons
local ApplyPanelUISecureState
local ApplyPanelUILocalization
local HideGameMenuFrame
local RunAfterGameMenuClose
local panelUISecureRetryFrame
local pendingPanelUISecureStateRefresh = {}

local function IsPanelUISecureMacroButton(button)
  return type(button) == "table" and type(button._secureMacroText) == "string" and button._secureMacroText ~= ""
end

local function IsChallengeModeActiveForSecureUI()
  local challengeMode = rawget(_G, "C_ChallengeMode")
  if type(challengeMode) ~= "table" then
    return false
  end
  if type(challengeMode.IsChallengeModeActive) == "function" then
    local ok, active = pcall(challengeMode.IsChallengeModeActive)
    if ok and not IsSecretValue(active) and active == true then
      return true
    end
  end
  if type(challengeMode.GetActiveChallengeMapID) == "function" then
    local ok, mapID = pcall(challengeMode.GetActiveChallengeMapID)
    if ok and not IsSecretValue(mapID) and tonumber(mapID) ~= nil then
      return true
    end
  end
  return false
end

local function IsPanelUISecureUpdateBlocked(state)
  if type(state) == "table" and type(state.isInCombat) == "function" and state.isInCombat() == true then
    return true
  end
  return IsChallengeModeActiveForSecureUI()
end

local function ClearQueuedPanelUISecureState(state)
  if pendingPanelUISecureStateRefresh[state] ~= true then
    return
  end

  pendingPanelUISecureStateRefresh[state] = nil
end

local function QueuePanelUISecureStateRefresh(state)
  if type(state) ~= "table" then
    return
  end

  pendingPanelUISecureStateRefresh[state] = true
end

panelUISecureRetryFrame = CreateFrame("Frame")
-- PLAYER_REGEN_ENABLED is registered statically at module load to avoid a
-- dynamic RegisterEvent from handlers dispatched by protected code, which
-- raises ADDON_ACTION_FORBIDDEN in 12.0+.
panelUISecureRetryFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
panelUISecureRetryFrame:SetScript("OnEvent", function(_, event)
  if event ~= "PLAYER_REGEN_ENABLED" then
    return
  end

  -- Drain a combat-deferred housing-button apply first. ApplyHousingAttributes
  -- clears pendingHousingApply on success; if it's still blocked (e.g. some
  -- other combat-lockdown source) we leave it for the next regen tick.
  if pendingHousingApply ~= nil then
    ApplyHousingAttributes(pendingHousingApply, housingSecureButton)
  end

  if next(pendingPanelUISecureStateRefresh) == nil then
    return
  end

  local queuedStates = {}
  for state in pairs(pendingPanelUISecureStateRefresh) do
    queuedStates[#queuedStates + 1] = state
    pendingPanelUISecureStateRefresh[state] = nil
  end

  for _, state in ipairs(queuedStates) do
    ApplyPanelUISecureState(state, true)
  end
end)

local function ResolveSecureClickBinding()
  local getCVarBool = rawget(_G, "GetCVarBool")
  local useOnKeyDown = type(getCVarBool) == "function" and getCVarBool("ActionButtonUseKeyDown") == true
  return useOnKeyDown and "LeftButtonDown" or "LeftButtonUp", useOnKeyDown
end

local function IsPanelUIEnabled(state)
  if type(state) ~= "table" then
    return false
  end

  if type(state.isEnabled) == "function" then
    return state.isEnabled() ~= false
  end

  return true
end

-- Picks a random entry from `pool` that differs from `current` when possible.
--
-- The previous shape was `repeat pick = pool[math.random(1, #pool)] until pick
-- ~= current`, guarded only by an `#pool == 1` special case. That loop never
-- terminates when every remaining entry equals `current` -- which happens the
-- moment the owned-toy list contains the same ID twice. The catalogue has no
-- duplicates today, so this was latent rather than live, but the failure mode
-- is a frozen client on a hearthstone click, so the loop gets a hard bound
-- instead of relying on the data staying clean. After MAX_PICK_ATTEMPTS we
-- accept a repeat of the current toy: rerolling the same mount is a cosmetic
-- miss, hanging the client is not.
local MAX_PICK_ATTEMPTS = 10

local function PickDifferentEntry(pool, current)
  local size = #pool
  if size == 0 then
    return nil
  end
  if size == 1 then
    return pool[1]
  end
  local pick = pool[math.random(1, size)]
  local attempts = 1
  while pick == current and attempts < MAX_PICK_ATTEMPTS do
    pick = pool[math.random(1, size)]
    attempts = attempts + 1
  end
  return pick
end

local function RefreshPanelUISecureButton(button)
  if type(button) ~= "table" or type(button.SetAttribute) ~= "function" then
    return
  end

  local clickBinding, useOnKeyDown = ResolveSecureClickBinding()
  if type(button.RegisterForClicks) == "function" then
    button:RegisterForClicks(clickBinding)
  end

  if type(button._actionId) == "string" and button._actionId == "hearthstone" then
    local db = rawget(_G, "IsiLiveDB") or {}
    local explicitToyId, explicitItemString = ResolveHearthstoneChoice(db.hearthstoneChoice)
    if explicitToyId then
      button:SetAttribute("type", "toy")
      button:SetAttribute("toy", explicitToyId)
      button._hearthstoneOwnedToys = { explicitToyId }
    elseif explicitItemString then
      button:SetAttribute("type", "item")
      button:SetAttribute("item", explicitItemString)
      button._hearthstoneOwnedToys = nil
    else
      local collect = addonTable.UI and addonTable.UI.CollectOwnedHearthstoneToys
      local pool = type(collect) == "function" and collect() or {}
      if type(pool) == "table" and #pool > 0 then
        button._hearthstoneOwnedToys = pool
        button:SetAttribute("type", "toy")
        button:SetAttribute("toy", pool[math.random(1, #pool)])
      else
        button:SetAttribute("type", "item")
        button:SetAttribute("item", "item:6948")
        button._hearthstoneOwnedToys = nil
      end
    end
    return
  end

  if type(button._actionId) == "string" and button._actionId == "dalaran_hearthstone" then
    button._available = IsDalaranHearthstoneAvailable()
    if button._available then
      button:SetAttribute("type", "toy")
      button:SetAttribute("toy", DALARAN_HEARTHSTONE_TOY_ID)
    end
    return
  end

  if not IsPanelUISecureMacroButton(button) then
    return
  end

  button:SetAttribute("type", "macro")
  button:SetAttribute("type1", "macro")
  button:SetAttribute("*type1", "macro")
  button:SetAttribute("useOnKeyDown", useOnKeyDown)
  button:SetAttribute("macrotext", button._secureMacroText)
  button:SetAttribute("macrotext1", button._secureMacroText)
end

local function RefreshPanelUISecureButtons(state)
  if type(state) ~= "table" then
    return
  end

  if IsPanelUISecureUpdateBlocked(state) then
    QueuePanelUISecureStateRefresh(state)
    return
  end

  for _, button in ipairs(state.buttons or {}) do
    RefreshPanelUISecureButton(button)
  end

  ClearQueuedPanelUISecureState(state)
end

local function SyncPanelUIButtonVisibility(button, visible)
  if type(button) ~= "table" then
    return
  end

  if visible then
    if type(button.Show) == "function" then
      button:Show()
    end
    return
  end

  if type(button.Hide) == "function" then
    button:Hide()
  end
end

local function IsPanelUIButtonAvailable(button)
  return type(button) == "table" and button._available ~= false
end

local function SyncPanelUISecureButtonVisibility(state)
  if type(state) ~= "table" then
    return
  end

  if IsPanelUISecureUpdateBlocked(state) then
    QueuePanelUISecureStateRefresh(state)
    return
  end

  local visible = IsPanelUIEnabled(state)
  for _, button in ipairs(state.buttons or {}) do
    if button._isSecurePanelAction == true then
      SyncPanelUIButtonVisibility(button, visible and IsPanelUIButtonAvailable(button))
    end
  end

  ClearQueuedPanelUISecureState(state)
end

local function SyncPanelUIButtonInteractivity(state)
  if type(state) ~= "table" then
    return
  end

  for _, button in ipairs(state.buttons or {}) do
    if button._isSecurePanelAction ~= true then
      if type(button.EnableMouse) == "function" then
        button:EnableMouse(true)
      end
      if type(button.SetAlpha) == "function" then
        button:SetAlpha(1)
      end
    end
  end
end

local function AttachPanelUIOnShow(state)
  local gameMenuFrame = state and state.gameMenuFrame or nil
  if type(gameMenuFrame) ~= "table" or type(gameMenuFrame.HookScript) ~= "function" then
    return
  end
  gameMenuFrame:HookScript("OnShow", function()
    if type(state.isEnabled) == "function" and not state.isEnabled() then
      return
    end
    if type(state.onShowRefresh) == "function" then
      state.onShowRefresh(state)
      return
    end
    ApplyPanelUISecureState(state)
  end)
end

local function InitializePanelUIChrome(state)
  local gameMenuFrame = state and state.gameMenuFrame or nil
  if type(gameMenuFrame) ~= "table" then
    return nil
  end

  local frameStrata = type(gameMenuFrame.GetFrameStrata) == "function" and gameMenuFrame:GetFrameStrata() or nil
  local baseFrameLevel = type(gameMenuFrame.GetFrameLevel) == "function" and gameMenuFrame:GetFrameLevel() or 1
  state.frameStrata = frameStrata
  state.baseFrameLevel = baseFrameLevel
  state.buttonWidth, state.buttonHeight = ResolvePanelUIButtonSize(gameMenuFrame)

  local panelFrame = CreateFrame("Frame", nil, gameMenuFrame, "BackdropTemplate")
  if frameStrata ~= nil and type(panelFrame.SetFrameStrata) == "function" then
    panelFrame:SetFrameStrata(frameStrata)
  end
  if type(panelFrame.SetFrameLevel) == "function" then
    panelFrame:SetFrameLevel(baseFrameLevel + 10)
  end
  if type(panelFrame.EnableMouse) == "function" then
    panelFrame:EnableMouse(true)
  end
  ApplyPanelUIBackdrop(panelFrame)
  state.hostFrame = panelFrame
  state.panelFrame = panelFrame

  AttachPanelUIOnShow(state)
  CreatePanelUIHeaderChrome(state)
  return panelFrame
end

local function AttachPanelUIStateMethods(state)
  function state.ApplyLocalization()
    ApplyPanelUISecureState(state)
    ApplyPanelUILocalization(state)
  end

  state.SyncVisibility = function()
    ApplyPanelUISecureState(state)
  end
end

local function ResolvePanelUIGetL(opts)
  return type(opts) == "table" and type(opts.getL) == "function" and opts.getL or function()
    return {}
  end
end

local function ApplyReusablePanelUIOptions(state, opts)
  if type(state) ~= "table" then
    return
  end
  opts = opts or {}
  if type(opts.getL) == "function" then
    state.getL = opts.getL
  end
  state.isEnabled = opts.isEnabled
  state.isInCombat = type(opts.isInCombat) == "function" and opts.isInCombat or nil
end

local function CreatePanelUIState(gameMenuFrame, opts, extra)
  local state = {
    gameMenuFrame = gameMenuFrame,
    getL = ResolvePanelUIGetL(opts),
    isEnabled = opts and opts.isEnabled or nil,
    isInCombat = opts and type(opts.isInCombat) == "function" and opts.isInCombat or nil,
    buttons = {},
    buttonsById = {},
    anchor = nil,
  }
  for key, value in pairs(extra or {}) do
    state[key] = value
  end
  return state
end

local function RefreshPanelUIState(state)
  ApplyPanelUISecureState(state)
  ApplyPanelUILocalization(state)
  return state
end

local function RefreshSecondPanelTravelEntries(state)
  if type(state) ~= "table" then
    return false
  end
  if IsPanelUISecureUpdateBlocked(state) then
    QueuePanelUISecureStateRefresh(state)
    return false
  end

  local dalaranButton = state.buttonsById and state.buttonsById.dalaran_hearthstone or nil
  if type(dalaranButton) == "table" then
    dalaranButton._available = IsDalaranHearthstoneAvailable()
    if dalaranButton._available == true then
      RefreshPanelUISecureButton(dalaranButton)
    end
  end
  return true
end

local function RefreshMountPanelEntries(state)
  if type(state) ~= "table" then
    return false
  end
  if IsPanelUISecureUpdateBlocked(state) then
    QueuePanelUISecureStateRefresh(state)
    return false
  end

  local visibleById = {}
  for _, entry in ipairs(ResolveVisibleMountPanelEntries()) do
    if type(entry.id) == "string" then
      visibleById[entry.id] = entry
    end
  end

  for _, button in ipairs(state.buttons or {}) do
    local entry = visibleById[button._actionId]
    if type(entry) == "table" then
      button._available = true
      button._secureMacroText = entry.secureMacroText
      RefreshPanelUISecureButton(button)
    else
      button._available = false
      button._secureMacroText = nil
    end
  end
  return true
end

PositionPanelUIButtons = function(state, opts)
  return GameMenuPanel.PositionButtons(state, {
    isButtonAvailable = IsPanelUIButtonAvailable,
    isSecureUpdateBlocked = IsPanelUISecureUpdateBlocked,
    queueSecureStateRefresh = QueuePanelUISecureStateRefresh,
    clearQueuedState = ClearQueuedPanelUISecureState,
    isEnabled = IsPanelUIEnabled,
  }, opts)
end
ApplyPanelUISecureState = function(state, force)
  if type(state) ~= "table" then
    return false
  end

  if not force and IsPanelUISecureUpdateBlocked(state) then
    QueuePanelUISecureStateRefresh(state)
    return false
  end

  PositionPanelUIButtons(state)
  RefreshPanelUISecureButtons(state)
  SyncPanelUISecureButtonVisibility(state)
  SyncPanelUIButtonInteractivity(state)
  ClearQueuedPanelUISecureState(state)
  return true
end

HideGameMenuFrame = function(gameMenuFrame)
  if type(gameMenuFrame) ~= "table" then
    return false
  end

  local hideUIPanel = rawget(_G, "HideUIPanel")
  if type(hideUIPanel) == "function" then
    local ok = pcall(hideUIPanel, gameMenuFrame)
    if ok then
      return true
    end
  end

  if type(gameMenuFrame.Hide) == "function" then
    gameMenuFrame:Hide()
    return true
  end

  return false
end

local GAME_MENU_CLOSE_RETRY_DELAY_SECONDS = 0.05
local GAME_MENU_CLOSE_RETRY_MAX_ATTEMPTS = 10

RunAfterGameMenuClose = function(gameMenuFrame, callback, attempt)
  if type(callback) ~= "function" then
    return
  end

  if type(gameMenuFrame) ~= "table" or type(gameMenuFrame.IsShown) ~= "function" or gameMenuFrame:IsShown() ~= true then
    callback()
    return
  end

  attempt = tonumber(attempt) or 1
  if attempt > GAME_MENU_CLOSE_RETRY_MAX_ATTEMPTS then
    return
  end

  local timer = rawget(_G, "C_Timer")
  local after = type(timer) == "table" and rawget(timer, "After") or nil
  if type(after) == "function" then
    after(GAME_MENU_CLOSE_RETRY_DELAY_SECONDS, function()
      RunAfterGameMenuClose(gameMenuFrame, callback, attempt + 1)
    end)
    return
  end

  if type(gameMenuFrame.IsShown) ~= "function" or gameMenuFrame:IsShown() ~= true then
    callback()
  end
end

-- Closes the game menu once a secure panel action has fired.
--
-- The secure travel and mount buttons are children of GameMenuFrame, so the
-- menu stays open behind the cast they start. Pressing ESC to get rid of it
-- then cancels that cast, and isiLive cannot prevent that from inside
-- Blizzard's ESC chain -- see rule 110, where that attempt is recorded as
-- withdrawn. Closing the menu ourselves removes the reason to press ESC at all,
-- and matches what the non-secure panel buttons already do.
--
-- PostClick rather than PreClick: the button is a child of the very frame being
-- hidden, and hiding a secure button's parent while its click is still being
-- processed is not something to rely on. Once the action has fired it is safe.
--
-- Combat is deliberately left alone. Rule 47 forbids Show/Hide mutations on the
-- ESC panel during lockdown, and HideUIPanel on GameMenuFrame is exactly that;
-- in combat the menu simply stays open as before.
local function AttachSecurePanelButtonAutoClose(button, gameMenuFrame)
  if type(button) ~= "table" or type(button.HookScript) ~= "function" then
    return false
  end
  if type(gameMenuFrame) ~= "table" then
    return false
  end

  button:HookScript("PostClick", function()
    local inCombat = rawget(_G, "InCombatLockdown")
    if type(inCombat) == "function" and inCombat() then
      return
    end
    HideGameMenuFrame(gameMenuFrame)
  end)
  return true
end

local function BindNonSecurePanelButtonOnClick(button, state)
  if type(button) ~= "table" or type(button.SetScript) ~= "function" then
    return
  end
  button:SetScript("OnClick", function(self)
    if type(state.isInCombat) == "function" and state.isInCombat() == true then
      return
    end
    local action = state.actions and state.actions[self._actionId]
    if type(action) ~= "function" then
      return
    end
    HideGameMenuFrame(state.gameMenuFrame)
    RunAfterGameMenuClose(state.gameMenuFrame, action)
  end)
end

ApplyPanelUILocalization = function(state)
  if type(state) ~= "table" then
    return
  end

  local L = type(state.getL) == "function" and state.getL() or {}
  for _, button in ipairs(state.buttons or {}) do
    local text = type(L[button._labelKey]) == "string" and L[button._labelKey] or button._fallbackText
    if type(button.SetText) == "function" then
      button:SetText(text)
    end
  end
end

function UI.EnsurePanelUI(opts)
  opts = opts or {}

  local gameMenuFrame = opts.gameMenuFrame or rawget(_G, "GameMenuFrame")
  if type(gameMenuFrame) ~= "table" then
    return nil
  end

  local actionOverrides = opts.panelActions or opts.microMenuActions

  if type(panelUIState) == "table" and panelUIState.gameMenuFrame == gameMenuFrame then
    ApplyReusablePanelUIOptions(panelUIState, opts)
    panelUIState.actions = MergePanelUIActions(opts.isInCombat, actionOverrides)
    return RefreshPanelUIState(panelUIState)
  end

  local state = CreatePanelUIState(gameMenuFrame, opts, {
    actions = MergePanelUIActions(opts.isInCombat, actionOverrides),
    headerLKey = "PANEL_HEADER_TOOLING",
  })

  InitializePanelUIChrome(state)
  local panelFrame = state.panelFrame
  local frameStrata = state.frameStrata
  local baseFrameLevel = state.baseFrameLevel

  for index, entry in ipairs(PANEL_UI_ENTRIES) do
    local buttonTemplate = type(entry.secureMacroText) == "string" and "SecureActionButtonTemplate,BackdropTemplate"
      or "BackdropTemplate"
    local buttonParent = type(entry.secureMacroText) == "string" and gameMenuFrame or panelFrame
    local button = CreatePanelUIButton(
      buttonParent,
      frameStrata,
      baseFrameLevel,
      10 + index,
      entry.iconAtlas or entry.icon,
      buttonTemplate,
      type(entry.secureMacroText) == "string"
    )

    button._actionId = entry.id
    button._labelKey = entry.labelKey
    button._fallbackText = entry.fallbackText
    button._gapBefore = math.max(0, tonumber(entry.gapBefore) or PANEL_UI_BUTTON_GAP)
    button._verticalIndex = index
    button._secureMacroText = entry.secureMacroText
    button._isSecurePanelAction = type(entry.secureMacroText) == "string"

    if not (type(entry.secureMacroText) == "string" and type(button.SetAttribute) == "function") then
      BindNonSecurePanelButtonOnClick(button, state)
    end

    state.buttons[index] = button
    state.buttonsById[entry.id] = button
  end

  AttachPanelUIStateMethods(state)

  panelUIState = state
  return RefreshPanelUIState(state)
end

UI.EnsureGameMenuMicroButtons = UI.EnsurePanelUI

function UI.EnsureSecondPanelUI(opts)
  opts = opts or {}

  local gameMenuFrame = opts.gameMenuFrame or rawget(_G, "GameMenuFrame")
  if type(gameMenuFrame) ~= "table" then
    return nil
  end

  local firstPanelState = opts.firstPanelState
  if type(firstPanelState) ~= "table" or type(firstPanelState.panelFrame) ~= "table" then
    return nil
  end

  if type(secondPanelUIState) == "table" and secondPanelUIState.gameMenuFrame == gameMenuFrame then
    ApplyReusablePanelUIOptions(secondPanelUIState, opts)
    secondPanelUIState.positionAnchorFrame = firstPanelState.panelFrame
    RefreshSecondPanelTravelEntries(secondPanelUIState)
    return RefreshPanelUIState(secondPanelUIState)
  end

  local state = CreatePanelUIState(gameMenuFrame, opts, {
    positionAnchorFrame = firstPanelState.panelFrame,
    positionOffsetX = -SECOND_PANEL_GAP,
    headerLKey = "PANEL_HEADER_TRAVEL",
    onShowRefresh = function(refreshState)
      RefreshSecondPanelTravelEntries(refreshState)
      ApplyPanelUISecureState(refreshState)
      ApplyPanelUILocalization(refreshState)
    end,
  })

  InitializePanelUIChrome(state)
  local panelFrame = state.panelFrame
  local frameStrata = state.frameStrata
  local baseFrameLevel = state.baseFrameLevel

  for index, entry in ipairs(SECOND_PANEL_UI_ENTRIES) do
    local resolvedMacroText = type(entry.secureMacroText) == "function" and entry.secureMacroText()
      or entry.secureMacroText
    local isSecureMacro = type(resolvedMacroText) == "string"
    local isSecure = isSecureMacro or entry.isSecure == true
    local buttonTemplate = isSecure and "SecureActionButtonTemplate,BackdropTemplate" or "BackdropTemplate"
    local buttonParent = isSecure and gameMenuFrame or panelFrame
    local button = CreatePanelUIButton(
      buttonParent,
      frameStrata,
      baseFrameLevel,
      10 + index,
      entry.iconAtlas or entry.icon,
      buttonTemplate,
      isSecure
    )

    button._actionId = entry.id
    button._labelKey = entry.labelKey
    button._fallbackText = entry.fallbackText
    button._gapBefore = math.max(0, tonumber(entry.gapBefore) or PANEL_UI_BUTTON_GAP)
    button._verticalIndex = index
    button._secureMacroText = resolvedMacroText
    button._isSecurePanelAction = isSecure
    button._panelUIState = state

    if isSecure then
      AttachSecurePanelButtonAutoClose(button, gameMenuFrame)
    end

    if
      (entry.id == "hearthstone" or entry.id == "dalaran_hearthstone" or entry.id == "housing_plot")
      and type(button.SetAttribute) == "function"
    then
      if IsPanelUISecureUpdateBlocked(state) then
        QueuePanelUISecureStateRefresh(state)
      else
        local clickBinding, useOnKeyDown = ResolveSecureClickBinding()
        if type(button.RegisterForClicks) == "function" then
          button:RegisterForClicks(clickBinding)
        end
        button:SetAttribute("useOnKeyDown", useOnKeyDown)
      end
    end

    if entry.id == "hearthstone" and type(button.SetAttribute) == "function" then
      if IsPanelUISecureUpdateBlocked(state) then
        QueuePanelUISecureStateRefresh(state)
      else
        RefreshPanelUISecureButton(button)
      end

      hearthstoneSecureButton = button
      if not hearthstoneToysEventFrame then
        hearthstoneToysEventFrame = CreateFrame("Frame")
        hearthstoneToysEventFrame:SetScript("OnEvent", function(_, event)
          if event ~= "TOYS_UPDATED" then
            return
          end
          local btn = hearthstoneSecureButton
          if type(btn) ~= "table" or type(btn.SetAttribute) ~= "function" then
            return
          end
          local inCombat = rawget(_G, "InCombatLockdown")
          if type(inCombat) == "function" and inCombat() then
            QueuePanelUISecureStateRefresh(btn._panelUIState)
            return
          end
          -- Respect a user-set choice in the settings: if a fixed toy or
          -- explicit item is selected, do not override it on TOYS_UPDATED.
          local db = rawget(_G, "IsiLiveDB") or {}
          local explicitToyId, explicitItemString = ResolveHearthstoneChoice(db.hearthstoneChoice)
          if explicitToyId or explicitItemString then
            return
          end
          local refreshed = CollectOwnedHearthstoneToys()
          if #refreshed == 0 then
            return
          end
          btn._hearthstoneOwnedToys = refreshed
          btn:SetAttribute("type", "toy")
          btn:SetAttribute("toy", refreshed[math.random(1, #refreshed)])
        end)
      end
      hearthstoneToysEventFrame:RegisterEvent("TOYS_UPDATED")

      if type(button.HookScript) == "function" or type(button.SetScript) == "function" then
        local function PickRandomHearthstoneToy()
          local inCombat = rawget(_G, "InCombatLockdown")
          if type(inCombat) == "function" and inCombat() then
            return
          end
          local db = rawget(_G, "IsiLiveDB") or {}
          local explicitToyId, explicitItemString = ResolveHearthstoneChoice(db.hearthstoneChoice)
          if explicitToyId or explicitItemString then
            return
          end
          local pool = button._hearthstoneOwnedToys
          if type(pool) ~= "table" or #pool == 0 then
            pool = CollectOwnedHearthstoneToys()
            if #pool == 0 then
              return
            end
            button._hearthstoneOwnedToys = pool
          end
          local current = button:GetAttribute("toy")
          local pick = PickDifferentEntry(pool, current)
          button:SetAttribute("type", "toy")
          button:SetAttribute("toy", pick)
        end

        if type(button.HookScript) == "function" then
          button:HookScript("PreClick", PickRandomHearthstoneToy)
        else
          button:SetScript("PreClick", PickRandomHearthstoneToy)
        end
      end
    elseif entry.id == "dalaran_hearthstone" and type(button.SetAttribute) == "function" then
      dalaranHearthstoneSecureButton = button
      button._available = IsDalaranHearthstoneAvailable()
      if button._available == true then
        if IsPanelUISecureUpdateBlocked(state) then
          QueuePanelUISecureStateRefresh(state)
        else
          RefreshPanelUISecureButton(button)
        end
      end

      if not dalaranHearthstoneToysEventFrame then
        dalaranHearthstoneToysEventFrame = CreateFrame("Frame")
        dalaranHearthstoneToysEventFrame:SetScript("OnEvent", function(_, event)
          if event ~= "TOYS_UPDATED" then
            return
          end
          local btn = dalaranHearthstoneSecureButton
          local refreshState = btn and btn._panelUIState or nil
          if type(refreshState) ~= "table" then
            return
          end
          RefreshSecondPanelTravelEntries(refreshState)
          RefreshPanelUIState(refreshState)
        end)
      end
      dalaranHearthstoneToysEventFrame:RegisterEvent("TOYS_UPDATED")
    elseif entry.id == "housing_plot" and type(button.SetAttribute) == "function" then
      housingSecureButton = button
      if not housingDataEventFrame then
        housingDataEventFrame = CreateFrame("Frame")
        -- Stay registered for the whole session. Earlier revisions self-
        -- unregistered after the first fire, which left the button without a
        -- `type` attribute (and silently click-dead) whenever the initial
        -- PLAYER_HOUSE_LIST_UPDATED arrived with no houses yet or with the
        -- player still in combat. The combat-deferred path goes through
        -- pendingHousingApply / panelUISecureRetryFrame.
        housingDataEventFrame:SetScript("OnEvent", function(_, event, housingInfo)
          if event ~= "PLAYER_HOUSE_LIST_UPDATED" then
            return
          end
          local info = type(housingInfo) == "table" and housingInfo[1] or nil
          if type(info) ~= "table" then
            return
          end
          ApplyHousingAttributes(info, housingSecureButton)
        end)
      end
      housingDataEventFrame:RegisterEvent("PLAYER_HOUSE_LIST_UPDATED")
      local cHousing = rawget(_G, "C_Housing")
      if type(cHousing) == "table" and type(cHousing.GetPlayerOwnedHouses) == "function" then
        pcall(cHousing.GetPlayerOwnedHouses)
      end
    elseif not isSecureMacro then
      BindNonSecurePanelButtonOnClick(button, state)
    end

    state.buttons[index] = button
    state.buttonsById[entry.id] = button
  end

  AttachPanelUIStateMethods(state)

  secondPanelUIState = state
  RefreshSecondPanelTravelEntries(state)
  return RefreshPanelUIState(state)
end

function UI.EnsureMountPanelUI(opts)
  opts = opts or {}

  local gameMenuFrame = opts.gameMenuFrame or rawget(_G, "GameMenuFrame")
  if type(gameMenuFrame) ~= "table" then
    return nil
  end

  local travelPanelState = opts.travelPanelState or opts.secondPanelState
  if type(travelPanelState) ~= "table" or type(travelPanelState.panelFrame) ~= "table" then
    return nil
  end

  if type(mountPanelUIState) == "table" and mountPanelUIState.gameMenuFrame == gameMenuFrame then
    ApplyReusablePanelUIOptions(mountPanelUIState, opts)
    mountPanelUIState.positionAnchorFrame = travelPanelState.panelFrame
    RefreshMountPanelEntries(mountPanelUIState)
    return RefreshPanelUIState(mountPanelUIState)
  end

  local state = CreatePanelUIState(gameMenuFrame, opts, {
    positionAnchorFrame = travelPanelState.panelFrame,
    positionOffsetX = 0,
    positionOffsetY = -SECOND_PANEL_GAP,
    positionPoint = "TOPLEFT",
    positionRelativePoint = "BOTTOMLEFT",
    headerLKey = "PANEL_HEADER_MOUNTS",
    buttons = {},
    buttonsById = {},
    anchor = nil,
    onShowRefresh = function(refreshState)
      RefreshMountPanelEntries(refreshState)
      ApplyPanelUISecureState(refreshState)
      ApplyPanelUILocalization(refreshState)
    end,
  })

  InitializePanelUIChrome(state)
  local frameStrata = state.frameStrata
  local baseFrameLevel = state.baseFrameLevel

  for index, entry in ipairs(MOUNT_PANEL_UI_ENTRIES) do
    local button = CreatePanelUIButton(
      gameMenuFrame,
      frameStrata,
      baseFrameLevel,
      10 + index,
      entry.iconAtlas or entry.icon,
      "SecureActionButtonTemplate,BackdropTemplate",
      true
    )

    button._actionId = entry.id
    button._labelKey = entry.labelKey
    button._fallbackText = entry.fallbackText
    button._gapBefore = math.max(0, tonumber(entry.gapBefore) or PANEL_UI_BUTTON_GAP)
    button._verticalIndex = index
    button._secureMacroText = nil
    button._isSecurePanelAction = true
    button._available = false

    AttachSecurePanelButtonAutoClose(button, gameMenuFrame)

    state.buttons[index] = button
    state.buttonsById[entry.id] = button
  end

  AttachPanelUIStateMethods(state)

  mountPanelUIState = state
  RefreshMountPanelEntries(state)
  return RefreshPanelUIState(state)
end

function UI.EnsureThirdPanelUI(opts)
  opts = opts or {}

  local gameMenuFrame = opts.gameMenuFrame or rawget(_G, "GameMenuFrame")
  if type(gameMenuFrame) ~= "table" then
    return nil
  end

  local secondPanelState = opts.secondPanelState
  if type(secondPanelState) ~= "table" or type(secondPanelState.panelFrame) ~= "table" then
    return nil
  end

  if type(thirdPanelUIState) == "table" and thirdPanelUIState.gameMenuFrame == gameMenuFrame then
    ApplyReusablePanelUIOptions(thirdPanelUIState, opts)
    thirdPanelUIState.positionAnchorFrame = secondPanelState.panelFrame
    thirdPanelUIState.actions = BuildAddonPanelUIActions(opts.panelActions)
    return RefreshPanelUIState(thirdPanelUIState)
  end

  local entries = ResolveVisibleAddonPanelEntries()
  if #entries == 0 then
    return nil
  end
  local state = CreatePanelUIState(gameMenuFrame, opts, {
    actions = BuildAddonPanelUIActions(opts.panelActions),
    positionAnchorFrame = secondPanelState.panelFrame,
    positionOffsetX = -SECOND_PANEL_GAP,
    headerLKey = "PANEL_HEADER_ADDONS",
  })

  InitializePanelUIChrome(state)
  local panelFrame = state.panelFrame
  local frameStrata = state.frameStrata
  local baseFrameLevel = state.baseFrameLevel

  for index, entry in ipairs(entries) do
    local button = CreatePanelUIButton(
      panelFrame,
      frameStrata,
      baseFrameLevel,
      10 + index,
      entry.iconAtlas or entry.icon,
      "BackdropTemplate"
    )

    button._actionId = entry.id
    button._labelKey = entry.labelKey
    button._fallbackText = entry.fallbackText
    button._gapBefore = math.max(0, tonumber(entry.gapBefore) or PANEL_UI_BUTTON_GAP)
    button._verticalIndex = index
    button._isSecurePanelAction = false
    BindNonSecurePanelButtonOnClick(button, state)

    state.buttons[index] = button
    state.buttonsById[entry.id] = button
  end

  AttachPanelUIStateMethods(state)

  thirdPanelUIState = state
  return RefreshPanelUIState(state)
end

-- Exposed for deterministic coverage of the bounded random pick. The live
-- caller is the hearthstone PreClick hook, which cannot be driven to the
-- pathological all-duplicates pool without a frame + secure button harness.
UI._Test_PickDifferentEntry = PickDifferentEntry
