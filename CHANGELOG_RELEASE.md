# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.300`.

Highlights:
- Hardened all external ESC Addons shortcuts against slower late slash-handler registration after a verified addon load.
- Kept addon shortcut dispatch fail-closed: no chat-edit fallback and no guessed internal handlers.
- Added a default-enabled Sound setting for disabling the 60-second Bloodlust-ready reminder loop.
- Suppressed Lua language-server diagnostics in local LuaFileSystem compatibility tooling without changing runtime behavior.
