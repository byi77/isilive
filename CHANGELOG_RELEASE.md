# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.397`.

<!-- highlights-reviewed-for: 0.9.397 -->

Highlights:
- **The DPS column works again.** It had been showing a leftover number for the local player and a dash for everyone else -- and the real cause turned out to be deeper than the first fix assumed: the call that reads a finished key's identity was removed from the game in patch 12.0, so no completed key ever reached the damage meter at all. That call is replaced, a finished key no longer opens a phantom second run over its own result, and a capture that finds nothing leaves the previous one intact. A key you abandon or leave mid-run is now recorded too, instead of leaving the column on the previous run. And the last thing standing in the way is gone: as a key ends, the game hands out its damage numbers in a protected form, and touching one that way aborted the entire key-completion handler before it could record anything. The per-run RIO delta also stays visible after you leave the group, next to the name, ilvl and rating the rows already keep.
- **Pick the font the interface uses.** A new selector in the Display settings offers the fonts WoW ships -- Friz Quadrata, Arial Narrow, Morpheus and Skurri. Languages that need their own font keep it, and a Cyrillic name stays readable even under a Latin-only pick. The default is the font every previous version used, so nothing changes until you choose something, and switching takes effect right away without a reload.
- **Your own deaths are counted correctly again.** The skull marker next to your name stayed at a single death for a whole key, because the health stream carries no guaranteed sample while you are dead or running back as a ghost. Own deaths now also come from `PLAYER_DEAD` / `PLAYER_UNGHOST`, and every party slot is re-checked whenever the game registers a death.
- **Ready-check row colors fill the whole row** instead of stopping behind the Kick column. The hover and click area is unchanged, so the management buttons on the right stay usable.
- **Changing the UI scale no longer moves the window.** A frame parked away from the screen centre jumped as soon as the scale slider moved; the stored position is now converted along with the scale. The demo simulator tablet also docks correctly at scales other than 100%.
