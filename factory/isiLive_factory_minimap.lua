local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

-- Shared by the minimap button and the AddonCompartment entry, so both
-- launchers behave the same: left click toggles the window, right click
-- opens the settings.
local function HandleLauncherClick(ctx, mouseButton, source)
  local logf = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
  if logf then
    logf("[UI] btn_click name=%s mouseButton=%s", tostring(source), tostring(mouseButton))
  end
  if mouseButton == "RightButton" then
    local blizzardSettings = rawget(_G, "Settings")
    if type(blizzardSettings) == "table" and type(blizzardSettings.OpenToCategory) == "function" then
      if ctx.settingsPanel and ctx.settingsPanel.category then
        blizzardSettings.OpenToCategory(ctx.settingsPanel.category.ID)
      end
    end
  elseif ctx.ToggleMainFrameVisibility then
    ctx.ToggleMainFrameVisibility()
  end
end

local function ShowLauncherTooltip(ctx, owner, anchor)
  local GameTooltip = rawget(_G, "GameTooltip")
  if not GameTooltip or type(owner) ~= "table" then
    return
  end
  local L = type(ctx.GetL) == "function" and ctx.GetL() or {}
  GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
  GameTooltip:AddLine("isiLive")
  GameTooltip:AddLine(L.TOOLTIP_MINIMAP_TOGGLE_WINDOW or "Left-click to toggle window.", 0.8, 0.8, 0.8)
  GameTooltip:AddLine(L.TOOLTIP_MINIMAP_OPEN_SETTINGS or "Right-click to open settings.", 0.8, 0.8, 0.8)
  GameTooltip:Show()
end

local function HideLauncherTooltip()
  local GameTooltip = rawget(_G, "GameTooltip")
  if GameTooltip then
    GameTooltip:Hide()
  end
end

-- AddonCompartment entry (the addon list behind the minimap's addon button).
-- The TOC names these globals in ## AddonCompartmentFunc / FuncOnEnter /
-- FuncOnLeave; the client calls them with (addonName, mouseButton) and
-- (addonName, menuButton). They stay registered whether or not the minimap
-- button is shown.
local function RegisterAddonCompartmentHandlers(ctx)
  rawset(_G, "isiLive_OnAddonCompartmentClick", function(_addonName, mouseButton)
    HandleLauncherClick(ctx, mouseButton, "compartment")
  end)
  rawset(_G, "isiLive_OnAddonCompartmentEnter", function(_addonName, menuButton)
    ShowLauncherTooltip(ctx, menuButton, "ANCHOR_LEFT")
  end)
  rawset(_G, "isiLive_OnAddonCompartmentLeave", function()
    HideLauncherTooltip()
  end)
end

local function CreateFactoryMinimapButton(ctx)
  local Minimap = rawget(_G, "Minimap")
  if not Minimap then
    return nil
  end

  local btn = CreateFrame("Button", "isiLiveMinimapButton", Minimap)
  btn:SetSize(28, 28)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)

  local overlay = btn:CreateTexture(nil, "OVERLAY")
  overlay:SetSize(53, 53)
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  overlay:SetPoint("TOPLEFT")

  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetTexture("Interface\\Icons\\inv_misc_key_15")
  icon:SetPoint("TOPLEFT", 7, -6)

  -- This runs at file load, before SavedVariables exist; PLAYER_LOGIN below
  -- re-reads the stored angle.
  local DEFAULT_MINIMAP_ANGLE = 225
  local function ReadStoredAngle()
    local db = rawget(_G, "IsiLiveDB")
    local angle = type(db) == "table" and db.minimapAngle or nil
    if type(angle) ~= "number" or angle ~= angle or angle == math.huge or angle == -math.huge then
      return DEFAULT_MINIMAP_ANGLE
    end
    return angle % 360
  end
  local minimapAngle = ReadStoredAngle()
  local radius = 80
  local getCursorPosition = rawget(_G, "GetCursorPosition")

  local function UpdatePosition()
    local rad = math.rad(minimapAngle)
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
  end

  UpdatePosition()

  local isDragging = false
  local function UpdateDragPosition()
    if not isDragging or type(getCursorPosition) ~= "function" then
      return
    end
    local mx, my = Minimap:GetCenter()
    local cx, cy = getCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    UpdatePosition()
  end
  btn:RegisterForDrag("LeftButton")
  btn:SetScript("OnDragStart", function()
    isDragging = true
    btn:SetScript("OnUpdate", UpdateDragPosition)
  end)
  btn:SetScript("OnDragStop", function()
    isDragging = false
    btn:SetScript("OnUpdate", nil)
    if type(getCursorPosition) ~= "function" then
      return
    end
    local mx, my = Minimap:GetCenter()
    local cx, cy = getCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    -- atan2 yields -180..180; the schema keeps the angle in [0, 360).
    minimapAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
    if IsiLiveDB then
      IsiLiveDB.minimapAngle = minimapAngle
    end
    UpdatePosition()
  end)

  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:SetScript("OnClick", function(_, mouseButton)
    HandleLauncherClick(ctx, mouseButton, "minimap")
  end)
  btn:SetScript("OnEnter", function(self)
    ShowLauncherTooltip(ctx, self, "ANCHOR_LEFT")
  end)
  btn:SetScript("OnLeave", HideLauncherTooltip)

  -- Apply visibility on PLAYER_LOGIN when SavedVariables are available.
  -- Mimics LibDBIcon pattern: register once, then show/hide based on db setting.
  local loginFrame = CreateFrame("Frame")
  loginFrame:RegisterEvent("PLAYER_LOGIN")
  loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    minimapAngle = ReadStoredAngle()
    UpdatePosition()
    local savedDb = rawget(_G, "IsiLiveDB")
    if savedDb and savedDb.showMinimapButton then
      btn:Show()
    else
      btn:Hide()
    end
  end)

  return btn
end
FI.CreateFactoryMinimapButton = CreateFactoryMinimapButton
FI.RegisterAddonCompartmentHandlers = RegisterAddonCompartmentHandlers
