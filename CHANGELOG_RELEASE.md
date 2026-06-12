# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.309`.

Highlights:
- New ready-check completion sound: `BttF_Tinkle.wav` plays once when all five party members are ready, with its own Sounds settings toggle and preview button.
- New tank / healer death alert: a big red animated on-screen warning with a TTS voice alert ("Tank died" / "Healer died") fires when the tank or healer dies during an active M+ run — including your own death.
- One alert per death: detection is edge-triggered, a revive re-arms it, and DPS deaths, disconnects, and out-of-key deaths stay silent.
- A single new toggle in the Sounds settings section enables or disables the on-screen text and both voice alerts together.
- Locale string tables were split into per-language files for faster maintenance; no user-visible changes.
