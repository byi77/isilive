# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.393`.

<!-- highlights-reviewed-for: 0.9.393 -->

Highlights:
- **The DPS column stays filled after a key.** Finishing a key and then leaving the group emptied the whole column: the dungeon still reports the keystone difficulty after the timer stops, so the addon opened a second, phantom run and recorded it -- with no damage-meter data left to read -- on top of the key's own numbers. A run that captures nothing now leaves the last one alone.
- **Your own deaths are counted correctly again.** The skull marker next to your name stayed at a single death for a whole key, because the health stream carries no guaranteed sample while you are dead or running back as a ghost. Own deaths now also come from `PLAYER_DEAD` / `PLAYER_UNGHOST`, and every party slot is re-checked whenever the game registers a death.
- **The death count is shown from the first death on.** A bare skull used to mean "exactly one death", which read as a marker without a value.
- **Ready-check row colors fill the whole row** instead of stopping behind the Kick column. The hover and click area is unchanged, so the management buttons on the right stay usable.
- **Changing the UI scale no longer moves the window.** A frame parked away from the screen centre jumped as soon as the scale slider moved; the stored position is now converted along with the scale. The demo simulator tablet also docks correctly at scales other than 100%.
