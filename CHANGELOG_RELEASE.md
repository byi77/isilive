# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.405`.

Version 0.9.405: Stats values and percentages stand out more clearly, and private tooltip cards now share consistent baseline width and spacing.

<!-- highlights-reviewed-for: 0.9.405 -->

Highlights:
- **Read notice types at a glance and find Settings faster.** Information, warnings, and portal actions now have distinct markers and a brief fade when a notice appears or changes status; an optional setting disables decorative fades and portal pulses. Ten always-visible Settings buttons jump directly to the chosen controls. Display settings show scale and opacity in a live preview and can restore their own defaults without resetting unrelated preferences.
- **Never miss a stuck pet again.** When your pet gets stuck and the game shows the red "No path available for your pet" message, isiLive now says "Check your pet!" (German clients: "Achte auf deinen Begleiter!") right away, so a pet stranded behind a pull no longer quietly halves your damage. It works in every client language, repeats at most every 5 seconds, and can be switched off under Sounds, where a preview button lets you hear it.
- **No more "Interface action failed" in combat.** The main window and the tank/healer marker icons hold buttons the game locks during combat, and isiLive still tried to hide, move or rescale them there. Dragging the window now simply waits until combat ends, and closing it, changing the UI scale or `/isilive resetui` are applied the moment combat ends. A marker icon whose player left the group mid-fight can no longer mark your current target instead.
- **The DPS column works again.** It had been showing a leftover number for the local player and a dash for everyone else -- and the real cause turned out to be deeper than the first fix assumed: the call that reads a finished key's identity was removed from the game in patch 12.0, so no completed key ever reached the damage meter at all. That call is replaced, a finished key no longer opens a phantom second run over its own result, and a capture that finds nothing leaves the previous one intact. A key you abandon or leave mid-run is now recorded too, instead of leaving the column on the previous run -- under its own dungeon and level, not those of an earlier key. And the last thing standing in the way is gone: as a key ends, the game hands out its damage numbers in a protected form, and touching one that way aborted the entire key-completion handler before it could record anything. The per-run RIO delta also stays visible after you leave the group, next to the name, ilvl and rating the rows already keep.
- **Read key values and details faster.** Compact M+ progress, Stats Box values and shared private tooltips use clearer hierarchy, consistent spacing and retained source formatting.
