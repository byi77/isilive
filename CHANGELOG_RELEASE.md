# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.348`.

Highlights:
- Fixed a queued-chat channel guard in the bundled ChatThrottleLib: messages
  queued via `SendChatMessage` under bandwidth throttling read the wrong
  internal field for their channel, silently bypassing the raid/party/
  instance-chat availability check.
- Deduplicated Mythic+ timer and tracked-run state checks into a shared
  helper and removed unused combat-log wiring left over from a pre-12.0
  implementation.
- Hardened the inspect controller's `NotifyInspect` call with the same
  protected-API guard used everywhere else in that module.
- Unified the settings-reset confirmation dialog's hover accent color and
  fixed editor lint warnings on settings UI separator textures.
