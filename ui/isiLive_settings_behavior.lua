local _, addonTable = ...
addonTable = addonTable or {}

local SettingsBehavior = {}
addonTable.SettingsBehavior = SettingsBehavior

local CreateSectionHeader = addonTable.SettingsControls.CreateSectionHeader
local CreateSectionNote = addonTable.SettingsControls.CreateSectionNote
local CreateSettingsCheckbox = addonTable.SettingsControls.CreateSettingsCheckbox
local DESCRIPTION_WIDTH = 620

local function DescriptionOptions(descriptionText)
  return {
    descriptionText = descriptionText,
    descriptionWidth = DESCRIPTION_WIDTH,
    descriptionWordWrap = true,
  }
end

local function SetDescription(control, text)
  if type(control) == "table" and control.description and type(control.description.SetText) == "function" then
    control.description:SetText(text or "")
  end
end

function SettingsBehavior.BuildSection(canvas, yOffset, labels, config, controls)
  controls.behaviorHeader, yOffset =
    CreateSectionHeader(canvas, yOffset, labels.SETTINGS_SECTION_BEHAVIOR or "Behavior")
  controls.behaviorHint, yOffset = CreateSectionNote(
    canvas,
    yOffset,
    labels.SETTINGS_SECTION_BEHAVIOR_HINT or "Sync, auto-open, combat, and raid handling."
  )
  if controls.behaviorHint then
    controls.behaviorHint._sectionKey = "SETTINGS_SECTION_BEHAVIOR"
  end

  controls.sync, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_SYNC_ENABLED or "Addon Sync",
    function()
      local db = config.getDB()
      return db.syncEnabled ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.syncEnabled = checked
      if type(config.onSyncToggle) == "function" then
        config.onSyncToggle(checked)
      end
    end,
    "SETTINGS_SYNC_ENABLED",
    DescriptionOptions(
      labels.SETTINGS_SYNC_ENABLED_DESC
        or "Shares key, roster, target, DPS, location, and kick data with isiLive group members."
    )
  )

  controls.lockMainFramePosition, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_LOCK_MAIN_FRAME_POSITION or "Lock main frame position",
    function()
      local db = config.getDB()
      return db.lockMainFramePosition ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.lockMainFramePosition = checked
      if type(config.onMainFramePositionLockToggle) == "function" then
        config.onMainFramePositionLockToggle(checked)
      end
    end,
    "SETTINGS_LOCK_MAIN_FRAME_POSITION",
    DescriptionOptions(
      labels.SETTINGS_LOCK_MAIN_FRAME_POSITION_DESC
        or "Prevents dragging the main isiLive window and keeps the saved position unchanged."
    )
  )

  controls.combatFadeMM, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_COMBAT_FADE_MM or "Fade out in Combat (M2 only)",
    function()
      local db = config.getDB()
      return db.combatFadeMM == true
    end,
    function(checked)
      local db = config.getDB()
      db.combatFadeMM = checked
      if type(config.onCombatFadeMMToggle) == "function" then
        config.onCombatFadeMMToggle(checked)
      end
    end,
    "SETTINGS_COMBAT_FADE_MM",
    DescriptionOptions(
      labels.SETTINGS_COMBAT_FADE_MM_DESC
        or "Fades the M+ layout during combat so nameplates and the dungeon view stay clear."
    )
  )

  -- Group the four auto-show/hide triggers together with an explanatory note.
  -- They are evaluated independently; multiple can be active at once.
  controls.autoTriggersNote, yOffset = CreateSectionNote(
    canvas,
    yOffset,
    labels.SETTINGS_AUTO_TRIGGERS_NOTE or "Automatic show/hide: each trigger below is independent. Hover for details."
  )
  if controls.autoTriggersNote then
    controls.autoTriggersNote._sectionKey = "SETTINGS_AUTO_TRIGGERS_NOTE"
  end

  controls.autoShowStartup, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_AUTO_SHOW_MAIN_FRAME_ON_STARTUP or "Show on Login / Reload",
    function()
      local db = config.getDB()
      return db.autoShowMainFrameOnStartup ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.autoShowMainFrameOnStartup = checked
      if type(config.onAutoShowMainFrameOnStartupToggle) == "function" then
        config.onAutoShowMainFrameOnStartupToggle(checked)
      end
    end,
    "SETTINGS_AUTO_SHOW_MAIN_FRAME_ON_STARTUP",
    DescriptionOptions(
      labels.SETTINGS_AUTO_SHOW_MAIN_FRAME_ON_STARTUP_DESC
        or "Opens isiLive automatically after login or UI reload unless raid mode blocks it."
    )
  )

  controls.autoOpen, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_AUTO_OPEN_QUEUE or "Auto-Open on M+ Queue",
    function()
      local db = config.getDB()
      return db.autoOpenOnQueue ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.autoOpenOnQueue = checked
      if type(config.onAutoOpenQueueToggle) == "function" then
        config.onAutoOpenQueueToggle(checked)
      end
    end,
    "SETTINGS_AUTO_OPEN_QUEUE",
    DescriptionOptions(
      labels.SETTINGS_AUTO_OPEN_QUEUE_DESC or "Opens isiLive automatically when you join a Mythic+ Group Finder queue."
    )
  )

  controls.autoOpenKeyEnd, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_AUTO_OPEN_MAIN_FRAME_ON_KEY_END or "Auto-Open on Key End",
    function()
      local db = config.getDB()
      return db.autoOpenMainFrameOnKeyEnd ~= false
    end,
    function(checked)
      local db = config.getDB()
      db.autoOpenMainFrameOnKeyEnd = checked
      if type(config.onAutoOpenMainFrameOnKeyEndToggle) == "function" then
        config.onAutoOpenMainFrameOnKeyEndToggle(checked)
      end
    end,
    "SETTINGS_AUTO_OPEN_MAIN_FRAME_ON_KEY_END",
    DescriptionOptions(
      labels.SETTINGS_AUTO_OPEN_MAIN_FRAME_ON_KEY_END_DESC
        or "Reopens isiLive after a Mythic+ run ends while you are still grouped."
    )
  )

  controls.autoCloseOnKeyStart, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_AUTO_CLOSE_ON_KEY_START or "Auto-close when key starts",
    function()
      local db = config.getDB()
      return db.autoCloseOnKeyStart == true
    end,
    function(checked)
      local db = config.getDB()
      db.autoCloseOnKeyStart = checked
      if type(config.onAutoCloseOnKeyStartToggle) == "function" then
        config.onAutoCloseOnKeyStartToggle(checked)
      end
    end,
    "SETTINGS_AUTO_CLOSE_ON_KEY_START",
    DescriptionOptions(
      labels.SETTINGS_AUTO_CLOSE_ON_KEY_START_DESC or "Closes the main window when a Mythic+ key starts."
    )
  )

  controls.autoCloseOnSoloChange, yOffset = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels.SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE or "Auto-close when leaving the group",
    function()
      local db = config.getDB()
      return db.autoCloseOnSoloChange == true
    end,
    function(checked)
      local db = config.getDB()
      db.autoCloseOnSoloChange = checked
      if type(config.onAutoCloseOnSoloChangeToggle) == "function" then
        config.onAutoCloseOnSoloChangeToggle(checked)
      end
    end,
    "SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE",
    DescriptionOptions(
      labels.SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE_DESC or "Closes the main window when you leave the group."
    )
  )

  -- Raid behaviour is a one-option future stub. Rendering it as a selector
  -- with a single button confuses users more than it informs them. Show a
  -- status note that explains the current always-hide behaviour instead;
  -- db.raidTransitionBehavior stays in the schema so the stub is still
  -- threaded through the runtime untouched.
  controls.raidBehaviorNote, yOffset = CreateSectionNote(
    canvas,
    yOffset,
    labels.SETTINGS_RAID_TRANSITION_NOTE or "Raid: main window hides automatically while in a raid group."
  )
  if controls.raidBehaviorNote then
    controls.raidBehaviorNote._sectionKey = "SETTINGS_RAID_TRANSITION_NOTE"
  end

  return yOffset
end

local function SetLocalizedText(control, labels, key, fallback)
  if control and type(control.SetText) == "function" then
    control:SetText(labels[key] or fallback)
  end
end

function SettingsBehavior.RefreshControls(controls, labels, db)
  if controls.behaviorHeader then
    controls.behaviorHeader:SetText(labels.SETTINGS_SECTION_BEHAVIOR or "Behavior")
  end
  SetLocalizedText(
    controls.behaviorHint,
    labels,
    "SETTINGS_SECTION_BEHAVIOR_HINT",
    "Sync, auto-open, combat, and raid handling."
  )
  SetLocalizedText(
    controls.autoTriggersNote,
    labels,
    "SETTINGS_AUTO_TRIGGERS_NOTE",
    "Automatic show/hide: each trigger below is independent."
  )
  SetLocalizedText(
    controls.raidBehaviorNote,
    labels,
    "SETTINGS_RAID_TRANSITION_NOTE",
    "Raid: main window hides automatically while in a raid group."
  )

  if controls.sync then
    controls.sync.label:SetText(labels.SETTINGS_SYNC_ENABLED or "Addon Sync")
    SetDescription(
      controls.sync,
      labels.SETTINGS_SYNC_ENABLED_DESC
        or "Shares key, roster, target, DPS, location, and kick data with isiLive group members."
    )
    controls.sync.check:SetChecked(db.syncEnabled ~= false)
  end
  if controls.autoOpen then
    controls.autoOpen.label:SetText(labels.SETTINGS_AUTO_OPEN_QUEUE or "Auto-Open on M+ Queue")
    SetDescription(
      controls.autoOpen,
      labels.SETTINGS_AUTO_OPEN_QUEUE_DESC or "Opens isiLive automatically when you join a Mythic+ Group Finder queue."
    )
    controls.autoOpen.check:SetChecked(db.autoOpenOnQueue ~= false)
  end
  if controls.autoCloseOnKeyStart then
    controls.autoCloseOnKeyStart.label:SetText(labels.SETTINGS_AUTO_CLOSE_ON_KEY_START or "Auto-close when key starts")
    SetDescription(
      controls.autoCloseOnKeyStart,
      labels.SETTINGS_AUTO_CLOSE_ON_KEY_START_DESC or "Closes the main window when a Mythic+ key starts."
    )
    controls.autoCloseOnKeyStart.check:SetChecked(db.autoCloseOnKeyStart == true)
  end
  if controls.autoCloseOnSoloChange then
    controls.autoCloseOnSoloChange.label:SetText(
      labels.SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE or "Auto-close when leaving the group"
    )
    SetDescription(
      controls.autoCloseOnSoloChange,
      labels.SETTINGS_AUTO_CLOSE_ON_SOLO_CHANGE_DESC or "Closes the main window when you leave the group."
    )
    controls.autoCloseOnSoloChange.check:SetChecked(db.autoCloseOnSoloChange == true)
  end
  if controls.lockMainFramePosition then
    controls.lockMainFramePosition.label:SetText(labels.SETTINGS_LOCK_MAIN_FRAME_POSITION or "Lock main frame position")
    SetDescription(
      controls.lockMainFramePosition,
      labels.SETTINGS_LOCK_MAIN_FRAME_POSITION_DESC
        or "Prevents dragging the main isiLive window and keeps the saved position unchanged."
    )
    controls.lockMainFramePosition.check:SetChecked(db.lockMainFramePosition ~= false)
  end
  if controls.combatFadeMM then
    controls.combatFadeMM.label:SetText(labels.SETTINGS_COMBAT_FADE_MM or "Fade out in Combat (M2 only)")
    SetDescription(
      controls.combatFadeMM,
      labels.SETTINGS_COMBAT_FADE_MM_DESC
        or "Fades the M+ layout during combat so nameplates and the dungeon view stay clear."
    )
    controls.combatFadeMM.check:SetChecked(db.combatFadeMM == true)
  end
  if controls.autoShowStartup then
    controls.autoShowStartup.label:SetText(labels.SETTINGS_AUTO_SHOW_MAIN_FRAME_ON_STARTUP or "Show on Login / Reload")
    SetDescription(
      controls.autoShowStartup,
      labels.SETTINGS_AUTO_SHOW_MAIN_FRAME_ON_STARTUP_DESC
        or "Opens isiLive automatically after login or UI reload unless raid mode blocks it."
    )
    controls.autoShowStartup.check:SetChecked(db.autoShowMainFrameOnStartup ~= false)
  end
  if controls.autoOpenKeyEnd then
    controls.autoOpenKeyEnd.label:SetText(labels.SETTINGS_AUTO_OPEN_MAIN_FRAME_ON_KEY_END or "Auto-Open on Key End")
    SetDescription(
      controls.autoOpenKeyEnd,
      labels.SETTINGS_AUTO_OPEN_MAIN_FRAME_ON_KEY_END_DESC
        or "Reopens isiLive after a Mythic+ run ends while you are still grouped."
    )
    controls.autoOpenKeyEnd.check:SetChecked(db.autoOpenMainFrameOnKeyEnd ~= false)
  end
  if controls.raidBehavior then
    controls.raidBehavior.UpdateHighlight()
  end
end
