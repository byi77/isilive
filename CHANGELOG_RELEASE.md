# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.287`.

Highlights:
- Removed the abandoned experimental LFG invite-list modules and their unused locale strings.
- Kept the active LFGDetect invite and accepted-notice flow intact.
- Added architecture coverage so the removed invite-list modules stay absent from TOC, guards, and tests.
- Enlarged the accepted-invite centerbox portal button, moved it right, and removed the redundant teleport header.
- Added a separate group-join target notice setting for the verified fallback center notice.
- Demo mode temporarily enables both notice preview settings and restores the user's values on exit.
- Added configurable StatsBox detail rows for Leech, Speed, Durability, Stamina, and Avoidance.
- Polished Settings language spacing, stronger section headers, and distinct child-group separators.
- Kept the StatsBox settings as one coherent block without an internal separator.
- Updated the release-gate scenario baseline to 1892 deterministic scenarios.
