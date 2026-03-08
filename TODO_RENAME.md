# TODO Rename: `isiLive` -> `isiKeyMPlus`

Zieltermin: nach `v0.9.70`

## Zielbild

- Addon-Name: `isiKeyMPlus`
- Addon-Ordner: `isiKeyMPlus`
- TOC: `isiKeyMPlus.toc`
- SavedVariables: `IsiKeyMPlusDB`
- Addon-Prefix: `ISIKEYMPLUS`
- Slash-Befehle: `/isikeymplus`, `/isk`
- Kein Legacy-Fallback auf `isiLive`
- Kein Import von `IsiLiveDB`
- Kein Alt-Sync mit `ISILIVE`

## Geltungsbereich

- Aktiver Stand muss vollstaendig auf `isiKeyMPlus` umgestellt werden.
- Historische Verweise in `CHANGELOG.md` duerfen `isiLive` weiter nennen, wenn sie klar den Zustand vor dem Rename beschreiben.

## Phase 1 - Freeze

- Nach `v0.9.70` Feature-Freeze fuer den Rename.
- Arbeitsbranch anlegen: `rename/isikeymplus-hardcut`
- Vollscan vor Start:
  - `isiLive`
  - `IsiLiveDB`
  - `ISILIVE`
  - `SLASH_ISILIVE`
  - `isiLive_release_`
  - `isiLive_alpha_`
  - `isiLive_beta_`
  - `isiLiveMainFrame`

## Phase 2 - Technischer Hardcut

- Addon-Ordner `isiLive` -> `isiKeyMPlus`
- `isiLive.toc` -> `isiKeyMPlus.toc`
- `isiLive.lua` -> `isiKeyMPlus.lua`
- alle `isiLive_*.lua` -> `isiKeyMPlus_*.lua`
- alle `testmodul/isilive_*` -> `testmodul/isikeymplus_*`
- `IsiLiveDB` -> `IsiKeyMPlusDB`
- `ISILIVE` -> `ISIKEYMPLUS`
- `SLASH_ISILIVE*` entfernen und auf neue Slash-Namen umstellen
- globale UI-Namen wie `isiLiveMainFrame` auf `isiKeyMPlusMainFrame`
- keine Migrations- oder Kompatibilitaetsbruecke

## Phase 3 - Tests, Doku, CI, Release

- Test-Harness und Szenario-Lader auf neue Dateinamen ziehen
- Sync-Tests auf `ISIKEYMPLUS`
- Command-Tests auf neue Slash-Befehle
- aktive Doku auf neuen Namen umstellen:
  - `README.md`
  - `ARCHITECTURE.md`
  - `RULES.md`
  - `RULES_LOGIC.md`
  - `ARCHITECTURE_RULES.md`
  - `RELEASE.md`
  - `TODO.md`
- GitHub-Workflows und Tag-Praefixe umstellen:
  - `isiKeyMPlus_release_*`
  - `isiKeyMPlus_alpha_*`
  - `isiKeyMPlus_beta_*`
- `.pkgmeta` auf `package-as: isiKeyMPlus`

## Phase 4 - Repo, CurseForge, Release

- GitHub-Repo auf `isiKeyMPlus` umbenennen
- CurseForge-Projektname auf `isiKeyMPlus`
- CurseForge-Slug auf neuen Namen ziehen
- CurseForge-Beschreibung und Branding pruefen
- ZIP/AddOn-Ordner im Paket auf `isiKeyMPlus` pruefen
- Rename-Branch erst nach gruener CI und Ingame-Smoke nach `main` mergen

## Gates am Rename-Tag

- `stylua --check .`
- `luacheck --exclude-files ".luarocks/**" -- .`
- `lua tools/validate_architecture_rules.lua`
- `lua tools/validate_usecases.lua`
- `powershell -ExecutionPolicy Bypass -File tools/validate_ci_local.ps1`

## Ingame-Smoke

- Addon laedt ohne Fehler
- `/isikeymplus`
- `/isk`
- UI oeffnen/schliessen
- Group join / leave
- Queue / Highlight
- Sync mit zwei Clients
- Ready-Check
- Hidden-Mode
- Teleport-UI

## Suchliste fuer den Hardcut

- `isiLive`
- `IsiLiveDB`
- `ISILIVE`
- `SLASH_ISILIVE`
- `isiLive_release_`
- `isiLive_alpha_`
- `isiLive_beta_`
- `isiLiveMainFrame`
