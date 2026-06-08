# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.302`.

Highlights:
- Fixed ESC Addons shortcuts so all supported external addon buttons wait for the Game Menu to close before dispatching the verified slash handler.
- Mirrored Blizzard's slash handler call shape by passing the default chat edit box to registered handlers.
- Kept the no-chat-fallback contract intact: missing or failed handlers stay silent instead of writing slash text into chat.
