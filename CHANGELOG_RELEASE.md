# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.414`.

Version 0.9.414: Lazy sync diagnostics and reliable CD polling after UI and raid transitions.

<!-- highlights-reviewed-for: 0.9.414 -->

Highlights:
- **No sender-byte formatting for unused logs.** Disabled logging and discarded deep traces skip sync byte dumps. Consumed deep traces and direct logging keep their original output.
- **Cooldown polling resumes when needed.** Visible active keys restart CD polling after raid return or reopening the main window. Hiding cancels the ticker immediately; repeated transitions keep exactly one ticker.
- **More regression coverage.** Logging-mode tests process 30,000 packets, and factory tests repeat 20 raid/party cycles with pending cooldown events and hidden returns. The original in-game frame spike still requires live profiling to establish its cause.
