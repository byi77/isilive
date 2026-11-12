# Security Policy

## Supported versions

Only the latest release of isiLive (CurseForge, Wago, GitHub Releases) receives
fixes. Please update before reporting.

## Reporting a vulnerability

Please do **not** open a public issue for security problems.

Report them privately through GitHub:
**Security → Report a vulnerability** on
[github.com/byi77/isilive](https://github.com/byi77/isilive/security/advisories/new).

Useful details:

- isiLive version and game client version
- what another player (or a crafted addon message, chat line or link) can make
  isiLive do, and the steps to reproduce it
- relevant `/isilive log` output, if available

You will get an answer as soon as possible. Confirmed issues are fixed in the
next release and credited in the changelog unless you prefer otherwise.

## Scope

In scope: anything in this repository — the addon code, its sync protocol
(`ISILIVE` / LibKeystone addon messages) and the GitHub workflows.

Out of scope: World of Warcraft itself, Blizzard APIs and third-party addons.
