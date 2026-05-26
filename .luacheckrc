-- .luacheckrc
return {
  max_line_length = 120,
  std = "lua51+wow_isiLive",

  files = {
    ["locale/isiLive_texts.lua"] = {
      ignore = {
        "631", -- locale strings are translation data and may exceed the code line budget
      },
    },
    ["locale\\isiLive_texts.lua"] = {
      ignore = {
        "631",
      },
    },
    ["testmodul/"] = {
      ignore = {
        "212", -- unused argument (mock stubs intentionally match real method signatures)
        "432", -- shadowing upvalue argument (nested self-stubs in mock tables)
        "211/state",
        "211/_state",
        "211/db",
        "211/_ctx",
        "211/_modules",
      },
    },
    ["tools/simulate_ready_check_frame_overrides.lua"] = {
      ignore = {
        "212", -- unused argument (frame-mock stubs intentionally match WoW Frame method signatures)
      },
    },
    ["tools\\simulate_ready_check_frame_overrides.lua"] = {
      ignore = {
        "212",
      },
    },
    ["tools/simulate_nameplate_keystart.lua"] = {
      ignore = {
        "212", -- frame-mock stubs intentionally match WoW Frame method signatures
      },
    },
    ["tools\\simulate_nameplate_keystart.lua"] = {
      ignore = {
        "212",
      },
    },
    -- Optional event-handler callback stubs intentionally accept and discard
    -- the WoW event vararg signature so live handlers can be drop-in
    -- replacements without the call sites checking arity.
    ["factory/isiLive_controller_wiring.lua"] = { ignore = { "212" } },
    ["factory\\isiLive_controller_wiring.lua"] = { ignore = { "212" } },
    ["logic/isiLive_event_handlers.lua"] = { ignore = { "212" } },
    ["logic\\isiLive_event_handlers.lua"] = { ignore = { "212" } },
    ["logic/isiLive_event_handlers_runtime.lua"] = { ignore = { "212" } },
    ["logic\\isiLive_event_handlers_runtime.lua"] = { ignore = { "212" } },
    ["logic/isiLive_event_handlers_challenge.lua"] = { ignore = { "212" } },
    ["logic\\isiLive_event_handlers_challenge.lua"] = { ignore = { "212" } },
    ["logic/isiLive_event_handlers_queue.lua"] = { ignore = { "212" } },
    ["logic\\isiLive_event_handlers_queue.lua"] = { ignore = { "212" } },
  },

  exclude_files = {
    "%.git/",
    "%.git\\",
    "%.luarocks/",
    "%.luarocks\\",
    "build/",
    "build\\",
    "libs/",
    "libs\\",
    "Libs/",
    "Libs\\",
    "vendor/",
    "vendor\\",
    "externals/",
    "externals\\",
    "tools/cache/",
    "tools\\cache\\",
    "realm_language_data%.lua$",
  },

  stds = {
    wow_isiLive = {
      globals = {
        "IsiLiveDB",
        "SLASH_ISILIVE1",
        "SLASH_ISILIVE2",
        "SlashCmdList",
        "IsiLiveRealmLocaleByExactName",
        "IsiLiveRealmLocaleByNormalizedName",
      },
      read_globals = {
        "GetLocale",
        "CreateFrame",
        "UIParent",
        "GameTooltip",
        "DEFAULT_CHAT_FRAME",
        "print",

        "C_Timer",
        "C_AddOns",
        "C_Container",
        "C_Map",
        "C_QuestLog",
        "C_Spell",
        "C_Item",

        "UnitName",
        "UnitGUID",
        "GetTime",
        "GetWorldElapsedTime",
        "InCombatLockdown",
        "IsAddOnLoaded",
        "GetAddOnMetadata",
        "hooksecurefunc",
        "SecureCmdOptionParse",

        "strtrim",
        "strsplit",
        "date",
        "wipe",
        "issecretvalue",

        "Enum",
        "LE_PARTY_CATEGORY_INSTANCE",
        "SOUNDKIT",
        "RAID_CLASS_COLORS",

        "C_ChallengeMode",
        "C_ScenarioInfo",
        "C_ChatInfo",
        "C_LFGList",
        "C_PaperDollInfo",
        "C_PartyInfo",
        "C_PlayerInfo",
        "C_SpellBook",
        "CanInspect",
        "CheckInteractDistance",
        "ClearInspectPlayer",
        "ClearOverrideBindings",
        "DoReadyCheck",
        "GetAverageItemLevel",
        "GetBindingAction",
        "GetInspectSpecialization",
        "GetInstanceInfo",
        "GetNumGroupMembers",
        "GetRealmName",
        "GetSpecialization",
        "GetSpecializationRole",
        "GetSpecializationInfo",
        "GetSpecializationInfoByID",
        "IsInGroup",
        "IsInRaid",
        "ChatThrottleLib",
        "LibStub",
        "NotifyInspect",
        "PlaySound",
        "SendChatMessage",
        "SetOverrideBindingClick",
        "UnitClass",
        "UnitExists",
        "UnitFullName",
        "UnitGroupRolesAssigned",
        "UnitIsGroupLeader",
        "UnitIsUnit",
        "UnitIsVisible",
        "CreateColor",
      },
    },
  },
}
