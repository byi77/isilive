# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.426`.

Version 0.9.426: live LFG bonus-heart updates, client-localized Augmentation
recognition and settings layout refresh after language changes.

<!-- highlights-reviewed-for: 0.9.426 -->

Highlights:
- **Current LFG bonus hearts.** Search-result and player specialization changes refresh existing hearts. Re-enabling bonus markers also refreshes applicant hearts immediately.
- **Lighter applicant rows.** Flags and hearts share one verified member read per row, reuse Blizzard's member updates and skip applicant reads for unowned tooltips.
- **Augmentation in every client language.** Spec text is matched against Blizzard's verified localized name; unreadable results remain unresolved.
- **Settings follow language changes.** Existing controls, navigation targets and scroll bounds are remeasured without rebuilding the panel.
- **Safer previews and lighter scans.** Demo exit preserves the preview during combat; request exit again outside combat. Exhaustion scans stop at confirmed empty slots, and non-NPC mob tooltips skip Forces database lookups.
