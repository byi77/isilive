# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.427`.

Version 0.9.427: verified Bloodlust readiness and season-backed portal resolution.

<!-- highlights-reviewed-for: 0.9.427 -->

Highlights:
- **Reliable Bloodlust-ready cues.** Unreadable exhaustion data stays unresolved and cannot trigger ready sounds, reminders or a ready display.
- **Verified activity portals.** Known season activities resolve their portals even when live LFG data is unavailable; cached portals cannot outlive their season mapping.
- **Stronger regression checks.** Visible and hidden Mythic+ workloads enforce API, frame, render and retained-memory budgets, with parent visibility modeled in the shared test fixture.
