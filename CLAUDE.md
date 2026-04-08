# Project Instructions

## Language

- Chat responses and thinking: always in German (Deutsch)
- Code and code comments: always in English

## Adding a new UI language

`isiLive_languages.lua` is the single source of truth for supported languages. To add a language:

1. Add an entry to `Languages.SUPPORTED` in `isiLive_languages.lua` (tag, cmdAliases, buttonLabel).
2. Add the full string table to `isiLive_texts.lua` (copy enUS, translate all keys).
3. Add language display names to `LANGUAGE_NAME_BY_LOCALE` in `isiLive_locale.lua`.
4. Add `LANG_SET_XX` and update `LANG_USAGE` / `HELP_LANG` in all three locale tables in `isiLive_texts.lua`.
5. Add coverage tests in `testmodul/isilive_test_scenarios_locale.lua`.

Everything else (commands, settings buttons, locale resolution) picks up the new entry automatically.

## Button text length

Action buttons in the main UI are 120×24px. `SetFlatButtonText` clamps the label automatically, but visually truncated text is bad UX. Keep button label strings short:

- Target: ≤ 14 characters for full-width action buttons (readycheck, countdown, share keys, refresh).
- Use the existing `_SHORT` / `_hModeText` keys for compact layouts.
- When adding translations, check all `BTN_*` keys and shorten aggressively if needed (abbreviations are fine).
