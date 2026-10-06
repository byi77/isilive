# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current version: `0.9.415`.

Version 0.9.415: Less work per combat event in Mythic+ keys and in the open world.

<!-- highlights-reviewed-for: 0.9.415 -->

Highlights:
- **Aura updates no longer rescan per event.** Player aura and charge updates share one cooldown-tracker pass per 0.1 seconds. In a test with 1,000 aura updates the hidden-window key path dropped from 40,000 aura-slot reads to one scan.
- **Peer kick countdowns refresh only the kick column.** Kick packets from group members no longer rebuild the whole roster every second, and your own echoed kick packet is ignored.
- **Mob nameplate percentages reuse their overlays.** Overlays are pooled instead of creating a new frame per nameplate cycle, each refresh reads the forces data once instead of per plate, and overlays are only re-anchored when their target or appearance changes.
- **Only your group's aura and health events reach the addon.** Nameplate, target and boss ticks are filtered by the client, and health ticks of living group members skip the death-alert lookups.
