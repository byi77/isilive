---@diagnostic disable: undefined-global
local helpersChunk, helpersErr = loadfile("testmodul/isilive_test_ui_helpers.lua")
if not helpersChunk then
  error("cannot load UI helpers: " .. tostring(helpersErr))
end
local helpers = helpersChunk()
local BuildCreateFrameStub = helpers.BuildCreateFrameStub

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Settings panel exposes VIP guest sound toggle and applies astral aurochs muting", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    local muted = {}
    local unmuted = {}

    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      MuteSoundFile = function(id)
        muted[#muted + 1] = id
      end,
      UnmuteSoundFile = function(id)
        unmuted[#unmuted + 1] = id
      end,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_sound_utils.lua", "isiLive_settings.lua" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {
            SETTINGS_SECTION_VIP_GUESTS = "VIP Guest Settings",
            SETTINGS_SECTION_VIP_GUESTS_HINT = "Special sound controls.",
            SETTINGS_VIP_ASTRAL_AUROCHS_SOUND = "Mute Astral Aurochs mount sound",
            SETTINGS_VIP_GRAND_EXPEDITION_YAK_SOUND = "Mute Grand Expedition Yak mount sound",
            SETTINGS_VIP_GILDED_BRUTOSAUR_SOUND = "Mute Trader Brutosaur mount sound",
            SETTINGS_VIP_DK_SOUL_REAPER_WARNING = "Soul Reaper warning for Unholy DK",
            SETTINGS_VIP_DK_PUTREFY_WARNING = "Putrefy warning for Unholy DK",
            SETTINGS_VIP_BLOODLUST_DEBUFF_BUTTON_WARNING = "Bloodlust button warning while debuffed",
            SETTINGS_VIP_DK_APOCALYPSE_HORSE_SOUND = "Mute Riders of the Apocalypse horse sounds",
            SETTINGS_VIP_DK_GHOUL_REMINDER = "Show missing-ghoul reminder",
          }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })

      Assert.NotNil(panel, "settings panel should be created when Blizzard Settings API exists")
      Assert.Nil(db.vipAstralAurochsSoundMuted, "opening settings should not persist the default VIP mute state")

      local vipHeader = nil
      local aurochsCheck = nil
      local yakCheck = nil
      local brutosaurCheck = nil
      local soulReaperCheck = nil
      local putrefyCheck = nil
      local bloodlustDebuffCheck = nil
      local dkHorseCheck = nil
      local ghoulReminderCheck = nil
      for _, frame in ipairs(createdFrames) do
        if frame._sectionKey == "SETTINGS_SECTION_VIP_GUESTS" then
          vipHeader = vipHeader or frame
        end
        if frame._settingKey == "SETTINGS_VIP_ASTRAL_AUROCHS_SOUND" then
          aurochsCheck = frame
        elseif frame._settingKey == "SETTINGS_VIP_GRAND_EXPEDITION_YAK_SOUND" then
          yakCheck = frame
        elseif frame._settingKey == "SETTINGS_VIP_GILDED_BRUTOSAUR_SOUND" then
          brutosaurCheck = frame
        elseif frame._settingKey == "SETTINGS_VIP_DK_SOUL_REAPER_WARNING" then
          soulReaperCheck = frame
        elseif frame._settingKey == "SETTINGS_VIP_DK_PUTREFY_WARNING" then
          putrefyCheck = frame
        elseif frame._settingKey == "SETTINGS_VIP_BLOODLUST_DEBUFF_BUTTON_WARNING" then
          bloodlustDebuffCheck = frame
        elseif frame._settingKey == "SETTINGS_VIP_DK_APOCALYPSE_HORSE_SOUND" then
          dkHorseCheck = frame
        elseif frame._settingKey == "SETTINGS_VIP_DK_GHOUL_REMINDER" then
          ghoulReminderCheck = frame
        end
      end

      Assert.NotNil(vipHeader, "settings panel should create the VIP guest section")
      aurochsCheck = Assert.NotNil(aurochsCheck, "settings panel should create the astral aurochs sound checkbox")
      yakCheck = Assert.NotNil(yakCheck, "settings panel should create the grand expedition yak sound checkbox")
      brutosaurCheck = Assert.NotNil(brutosaurCheck, "settings panel should create the gilded brutosaur sound checkbox")
      soulReaperCheck = Assert.NotNil(soulReaperCheck, "settings panel should create the VIP DK Soul Reaper checkbox")
      putrefyCheck = Assert.NotNil(putrefyCheck, "settings panel should create the VIP DK Putrefy checkbox")
      bloodlustDebuffCheck =
        Assert.NotNil(bloodlustDebuffCheck, "settings panel should create the VIP Bloodlust debuff checkbox")
      dkHorseCheck = Assert.NotNil(dkHorseCheck, "settings panel should create the VIP DK horse-sound child checkbox")
      ghoulReminderCheck =
        Assert.NotNil(ghoulReminderCheck, "settings panel should create the VIP DK ghoul-reminder child checkbox")

      Assert.False(aurochsCheck:GetChecked(), "astral aurochs sound mute should default to off")
      Assert.False(yakCheck:GetChecked(), "grand expedition yak sound mute should default to off")
      Assert.False(brutosaurCheck:GetChecked(), "gilded brutosaur sound mute should default to off")
      Assert.False(soulReaperCheck:GetChecked(), "VIP DK Soul Reaper warning should default to off")
      Assert.False(putrefyCheck:GetChecked(), "VIP DK Putrefy warning should default to off")
      Assert.False(bloodlustDebuffCheck:GetChecked(), "VIP Bloodlust debuff button warning should default to off")
      Assert.False(dkHorseCheck:GetChecked(), "VIP DK horse-sound mute should default to off")
      Assert.False(ghoulReminderCheck:GetChecked(), "VIP DK ghoul reminder should default to off")

      local onClick =
        Assert.NotNil(aurochsCheck._scripts and aurochsCheck._scripts.OnClick or nil, "VIP checkbox needs OnClick")

      aurochsCheck:SetChecked(true)
      onClick(aurochsCheck)
      Assert.True(db.vipAstralAurochsSoundMuted, "checking the VIP sound option should persist muted=true")
      Assert.True(#muted >= 88, "checking the VIP sound option should mute every known astral aurochs file")
      Assert.Equal(muted[1], 7340960, "muting should include the model-sound first file")
      Assert.Equal(muted[#muted], 6788058, "muting should include the model loop tail file")

      aurochsCheck:SetChecked(false)
      onClick(aurochsCheck)
      Assert.False(db.vipAstralAurochsSoundMuted, "unchecking the VIP sound option should persist muted=false")
      Assert.Equal(#unmuted, #muted, "unchecking should unmute the same number of astral aurochs files")

      panel.Refresh()
      Assert.False(aurochsCheck:GetChecked(), "refresh should keep the unmuted VIP sound state")
      local yakOnClick =
        Assert.NotNil(yakCheck._scripts and yakCheck._scripts.OnClick or nil, "yak VIP checkbox needs OnClick")
      local brutosaurOnClick = Assert.NotNil(
        brutosaurCheck._scripts and brutosaurCheck._scripts.OnClick or nil,
        "brutosaur VIP checkbox needs OnClick"
      )
      muted = {}
      yakCheck:SetChecked(true)
      yakOnClick(yakCheck)
      Assert.True(db.vipGrandExpeditionYakSoundMuted, "checking the yak option should persist muted=true")
      Assert.Equal(muted[1], 613111, "yak muting should include the verified first model sound file")
      muted = {}
      brutosaurCheck:SetChecked(true)
      brutosaurOnClick(brutosaurCheck)
      Assert.True(db.vipGildedBrutosaurSoundMuted, "checking the brutosaur option should persist muted=true")
      Assert.Equal(muted[1], 1824124, "brutosaur muting should include the verified first model sound file")

      local soulReaperOnClick = Assert.NotNil(
        soulReaperCheck._scripts and soulReaperCheck._scripts.OnClick or nil,
        "Soul Reaper VIP checkbox needs OnClick"
      )
      soulReaperCheck:SetChecked(true)
      soulReaperOnClick(soulReaperCheck)
      Assert.True(db.vipDkSoulReaperWarningEnabled, "checking Soul Reaper warning should persist enabled=true")

      local putrefyOnClick = Assert.NotNil(
        putrefyCheck._scripts and putrefyCheck._scripts.OnClick or nil,
        "Putrefy VIP checkbox needs OnClick"
      )
      putrefyCheck:SetChecked(true)
      putrefyOnClick(putrefyCheck)
      Assert.True(db.vipDkPutrefyWarningEnabled, "checking Putrefy warning should persist enabled=true")

      local bloodlustOnClick = Assert.NotNil(
        bloodlustDebuffCheck._scripts and bloodlustDebuffCheck._scripts.OnClick or nil,
        "Bloodlust debuff VIP checkbox needs OnClick"
      )
      bloodlustDebuffCheck:SetChecked(true)
      bloodlustOnClick(bloodlustDebuffCheck)
      Assert.True(
        db.vipBloodlustDebuffButtonWarningEnabled,
        "checking Bloodlust debuff warning should persist enabled=true"
      )

      muted = {}
      local dkHorseOnClick = Assert.NotNil(
        dkHorseCheck._scripts and dkHorseCheck._scripts.OnClick or nil,
        "DK horse-sound child checkbox needs OnClick"
      )
      dkHorseCheck:SetChecked(true)
      dkHorseOnClick(dkHorseCheck)
      Assert.True(db.vipDkApocalypseHorseSoundMuted, "checking DK horse sound should persist muted=true")
      Assert.Equal(#muted, 3, "checking DK horse sound should mute the three known horse summon files")
      Assert.Equal(muted[1], 987917, "DK horse muting should include the first known horse summon file")

      local ghoulReminderOnClick = Assert.NotNil(
        ghoulReminderCheck._scripts and ghoulReminderCheck._scripts.OnClick or nil,
        "DK ghoul-reminder child checkbox needs OnClick"
      )
      ghoulReminderCheck:SetChecked(true)
      ghoulReminderOnClick(ghoulReminderCheck)
      Assert.True(db.vipDkGhoulReminderEnabled, "checking DK ghoul reminder should persist enabled=true")
    end)
  end)
end
