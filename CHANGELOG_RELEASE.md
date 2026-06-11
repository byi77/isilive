# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.306`.

Highlights:
- Share Keys button cooldown is now mirrored to freshly joined group members via a new `SKCD` sync payload (hello-ack / REQSYNC fan-out), applied with max-merge and clamped to the 30s window.
- Closed the double-post gap: an incoming `SHAREKEYS` shortly after a local Share Keys click no longer re-posts the own keystone.
- Added deterministic SKCD coverage including an end-to-end sender-to-receiver wire-bytes chain.
