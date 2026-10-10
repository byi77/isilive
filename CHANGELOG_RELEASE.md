# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.429`.

Version 0.9.429: separate Soul Reaper warning windows around Dark Transformation.

<!-- highlights-reviewed-for: 0.9.429 -->

Highlights:
- **Soul Reaper timing.** The optional red cross lasts seven seconds after Dark Transformation and returns seven seconds before it is ready again. Putrefy's warning keeps its separate 15-second window.
- **Independent Putrefy warning.** Putrefy retains its 15-second warning and charge guard while Soul Reaper uses its own timers.
- **Stable deadlines.** Refreshes keep warning deadlines, and callbacks from an earlier cast cannot clear a newer warning.
- **Regression coverage.** Automated checks cover both Soul Reaper windows, independent Putrefy timing, recasts, overlapping phases and overlay reuse.
