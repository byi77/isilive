# isiLive Release Changelog

Full changelog in the repository:
https://github.com/byi77/isilive/blob/main/docs/CHANGELOG.md

Current release: `0.9.343`.

Highlights:
- Hardened AddOn sync against invalid channels, spoofed BR/PI casters, and
  non-finite numeric payloads while retaining legacy HELLO compatibility.
- Reduced idle runtime work by giving polling tickers explicit lifecycles and
  removing hidden or inactive frame-update handlers.
- Added ready, not-ready, and waiting icons to roster Ready Check states so the
  result no longer depends on row color alone.
