# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.290`.

Highlights:
- Fixed Cyrillic LFG leader names in center notices by switching dynamic payload text to a Cyrillic-capable WoW font when needed.
- Extended Cyrillic-safe rendering to addon-owned roster rows, private tooltips, teleport empty-state text, and killtracker dungeon labels.
- Modernized the pre-accept LFG invite hint into the same info-card style and added dungeon, group, leader, and source rows.
- Added the modern LFG invite hint to demo mode so the pre-accept card can be inspected without a live invite.
- Kept the demo invite hint on a fixed high-priority demo anchor so it is not hidden by live fallback anchoring.
- Enlarged the center-notice portal button status text for the ready `Portal` label and active cooldown timer.
- Removed the redundant `BL:` prefix from the active Bloodlust tracker countdown.
- Added the started keystone level beside the active dungeon name on the lower M+ killtracker row.
- Refreshed the lower M+ killtracker row immediately when demo mode injects its active key preview.
- Reset the visible M+ timer row immediately when a key is completed or aborted.
- Added language flags to LFG applicant rows and moved applicant bonus hearts to the right of the class badge.
- Restored applicant name positioning when a reusable applicant row loses its language flag, including parent-frame texture fallback support.
- Forced applicant bonus hearts to use real `media/heart_bonus_green.tga` textures instead of the old FontString texture-markup fallback.
- Applied applicant bonus-heart textures directly from visible `button.Members` rows when Blizzard's member-update hook does not fire.
- Kept applicant bonus-heart textures visible in layouts where the role icon is outside the member-name frame, and resolved localized applicant class names through Blizzard class-name tables.
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
- Updated the release-gate scenario baseline to 1918 deterministic scenarios.
