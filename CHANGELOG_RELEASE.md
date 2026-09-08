# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.388`.

<!-- highlights-reviewed-for: 0.9.388 -->

Highlights:
- **The VIP Unholy Death Knight warning matches patch 12.1.** Soul Reaper no
  longer consumes Putrefy charges, so the two buttons stopped sharing a
  resource. The Putrefy warning now watches its own charges and stays out of
  the way when you are holding two or more, where saving one would only run
  the recharge into its cap.
- **The warning window follows the real Dark Transformation cooldown.** It was
  a fixed 30-second wait, which only lined up while that cooldown was exactly
  45 seconds. It now reads the live cooldown and always covers the last 15
  seconds before Dark Transformation returns.
- **You can try the warning from the demo simulator.** Alerts now has a VIP DK
  warning action that skips the cooldown wait and nothing else, so you no
  longer have to cast Dark Transformation in a real fight to see it.
