# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.391`.

<!-- highlights-reviewed-for: 0.9.391 -->

Highlights:
- **German reads properly again.** 110 strings were written with `ue` / `ae` / `oe` instead of real umlauts — "verfuegbar", "zuruecksetzen", "Schriftgroesse". German was the only language affected; every other one already used its accents.
- **Turkish, French, Spanish and Portuguese accents fixed** in the LFG group-bonus description. Turkish suffered most, because `i` and `ı` are different letters there.
- **Six languages are fully translated** (0.9.390): around 105 strings each were still English — the demo simulator, the `/isilive` help, the dungeon and invite notices, the teleport tooltips and the LFG bonus labels.
- **Right-click to whisper works across the whole roster row again**, and role markers no longer linger on players who died mid-fight.
