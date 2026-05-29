# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.288`.

Highlights:
- Modernized the accepted-invite center notice into the new info-card layout with a wide right-side portal action area.
- Reworked the Timeways Portal Navigator into a five-position crescent view with verified teleport spell icons on occupied portals and the empty center `Heaven` portal muted.
- Reworked the non-Mythic dungeon-entry notice into the same rich center-card layout with a dominant blinking red warning row.
- Restyled the shared close button with a darker red panel, warm gold border, red glow, and WoW panel close textures.
- Removed the abandoned experimental LFG invite-list modules and their unused locale strings.
- Kept the active LFGDetect invite and accepted-notice flow intact.
- Added architecture coverage so the removed invite-list modules stay absent from TOC, guards, and tests.
- Enlarged the accepted-invite centerbox portal button, moved it right, and removed the redundant teleport header.
- Added a separate group-join target notice setting for the verified fallback center notice.
- Demo mode temporarily enables both notice preview settings and restores the user's values on exit.
- Added configurable StatsBox detail rows for Leech, Speed, Durability, Stamina, and Avoidance.
- Polished Settings language spacing, stronger section headers, and distinct child-group separators.
- Kept the StatsBox settings as one coherent block without an internal separator.
- Updated the release-gate scenario baseline to 1901 deterministic scenarios.
