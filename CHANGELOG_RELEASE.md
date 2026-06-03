# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.297`.

Highlights:
- Fixed in-key BR/Bloodlust peer announcements by allowing incoming `BRLUST` addon-sync payloads through the combat event gate.
- Fixed local BR/Bloodlust sender detection when the active challenge map API is masked, including owned pet Bloodlust casts.
- Stabilized M+ forces nameplate percentage anchoring around third-party nameplates and zero offsets.
- Restored compact M+ forces nameplate percentages by making the remaining-needed suffix opt-in again.
- Fixed M+ forces nameplate position and font-size settings under external nameplate addons by anchoring to the observed healthbar while avoiding inherited nameplate scaling.
- Hardened the Battle Res combat sound with a separate fallback playback path without changing the Bloodlust sound asset.
- Fixed Battle Res-ready TTS to use directly observed known BR charge data and play once when the displayed BR charge count increases.
