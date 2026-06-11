# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.307`.

Highlights:
- Kick tracking now reconciles observed local interrupts with exact Blizzard cooldown data after the cast event, improving talent- and pet-sensitive cooldown accuracy.
- Early inactive cooldown reads no longer clear an observed interrupt cooldown, so the roster kick column stays fail-closed instead of flipping to ready too soon.
- Added deterministic coverage for observed-cast refinement, early inactive cooldown reads, and the post-cast factory reconcile path.
