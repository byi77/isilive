# TODO

## P0 - Reliability Gates

- [x] Deterministische Runtime-Usecase-Pruefung als Script angelegt (`tools/validate_usecases.lua`).
- [x] Release-Dokus auf harte Quality-Gates inkl. Usecase-Validator umgestellt (`README.md`, `RELEASE.md`).
- [ ] CI Workflow optional um `tools/validate_usecases.lua` erweitern (zusaetzlicher Runtime-Gate auf `main`).

## P1 - Hard Split `isiLive` -> `isiKeyMplus` (Planung)

### Final beschlossen (nicht mehr offen)

- [x] Zielname: `isiKeyMplus` (genau diese Schreibweise).
- [x] Modell: Hard-Split (`isiLive` Sunset + neues Addon `isiKeyMplus`).
- [x] Versionen:
  - `isiLive` Sunset-Release: `0.9.44`
  - `isiKeyMplus` Start-Release: `1.0.45`
- [x] Neuer Slash-Befehl: nur `/ikm`.
- [x] Kein Legacy-Slash-Alias `/isilive`.
- [x] Kein Dual-Listen des alten Sync-Prefix fuer eine Version.
- [x] Neues GitHub-Repo: `https://github.com/byi77/isiKeyMplus`
- [x] CurseForge Web-Schritte werden manuell gemacht (Projektseite/Projektverwaltung).
- [x] Umsetzungsregel: erst starten, wenn explizit `start` freigegeben wurde.

### A) Preflight (vor Umsetzung)

- [ ] Arbeitsbaum bereinigen und Start-Commit fuer reproduzierbaren Split markieren.
- [ ] Alten Stand fuer `isiLive` Sunset-Branch sichern.
- [ ] Neues Repo `byi77/isiKeyMplus` als eigenes Remote anbinden.

### B) `isiLive` Sunset (v0.9.44)

- [ ] Addon-Verhalten auf Migrations-Hinweis reduzieren:
  - Kein produktiver GUI-Flow mehr.
  - Beim Laden und bei Slash nur Hinweis anzeigen:
    - `deDE`: Bitte `isiLive` loeschen und `isiKeyMplus` installieren.
    - `enUS`: Please delete `isiLive` and install `isiKeyMplus`.
- [ ] Dokumentation auf Sunset umstellen (`README.md`, `CHANGELOG.md`, `RELEASE.md`).
- [ ] `isiLive.toc` auf `0.9.44` heben.
- [ ] Release-Tag erstellen: `isiLive_release_0.9.44`.

### C) Neues Addon `isiKeyMplus` (v1.0.45)

- [ ] Vollstaendiges Rename der Dateien via `git mv`:
  - `isiLive.toc` -> `isiKeyMplus.toc`
  - `isiLive.lua` -> `isiKeyMplus.lua`
  - `isiLive_*.lua` -> `isiKeyMplus_*.lua`
  - `testmodul/isilive_test_*.lua` -> `testmodul/isikeymplus_test_*.lua`
- [ ] Vollstaendiges Identifier- und String-Rename:
  - `isiLive` -> `isiKeyMplus`
  - `IsiLiveDB` -> `IsiKeyMplusDB`
  - `ISILIVE_` -> `ISIKEYMPLUS_`
  - Addon-Sync-Prefix auf neuen Wert fuer `isiKeyMplus` setzen.
- [ ] Slash-Command-System auf `/ikm` umstellen (ohne `/isilive` Alias).
- [ ] `.toc` auf neuen Namen/Version `1.0.45` und neue SavedVariables anpassen.
- [ ] `.pkgmeta` (`package-as`) auf `isiKeyMplus` umstellen.
- [ ] `.luacheckrc` und `tools/lua_metrics_check.lua` Prefix-Variablen umstellen.
- [ ] GitHub Workflows auf neue Tag-Prefixe umstellen:
  - `isiKeyMplus_release_*`
  - `isiKeyMplus_alpha_*`
  - `isiKeyMplus_beta_*`
- [ ] Release-Tag erstellen: `isiKeyMplus_release_1.0.45`.

### D) Quality-Gates fuer beide Straenge

- [ ] `stylua --check .`
- [ ] `luacheck --exclude-files ".luarocks/**" -- .`
- [ ] `lua tools/lua_metrics_check.lua`
- [ ] `lua tools/validate_usecases.lua`
- [ ] Kurz-Smoketest (Login, Slash, Message-Text Sunset / Kernfunktionen neues Addon).

### E) GitHub + Release-Ablauf

- [ ] `isiLive` Sunset-Commit+Tag in altes Repo pushen.
- [ ] `isiKeyMplus` Full-Rename-Commit+Tag in neues Repo pushen.
- [ ] Actions-Runs fuer beide Repos/Tags auf gruen validieren.

## P2 - Pre-Key Readiness / Informationen vor Key-Start

- [x] Key-Spalte anzeigen: Gruppenmitglieder-Key als `Shortcut +Stufe` (z. B. `DB +14`).
- [x] RIO-Delta-Anzeige: pro Spieler als Prefix `(+X)RIO`, niemals negativ (mindestens `+0`).
- [x] Testmodus zeigt sichtbare positive RIO-Delta-Vorschau (`/isilive test`, `/isilive testall`).
- [ ] **Next Week:** Off-Season Modus aktivieren (Teleport-Grid ausblenden/leeren, Non-Mythic Warnung deaktivieren).
- [ ] **Next Week:** Vorbereitung Midnight S1 (neue MapIDs/Spells recherchieren).

## P3 - Entschlackung `isiLive.lua` (nach Release `0.9.26`)

- [x] `v0.9.26` zuerst releasen (keine strukturellen Refactors im Release-Commit mischen).
- [x] Baseline dokumentieren: kurzer Ingame-Smoketest vor Refactor (Group join/leave, Queue/Teleport highlight, Key-Spalte, Refresh, Hidden/Sleep). Siehe `README.md` Abschnitt `Use Case / Logic Baseline (v0.9.38)`.
- [x] `isiLive_keysync.lua` extrahieren (Key-Sync + Active-Key-Owner-Logik), in `isiLive.lua` nur noch Aufrufe.
- [x] `isiLive_group.lua` extrahieren (Group-Lifecycle / Roster-Rebuild / Group-Leave-Cleanup).
- [x] `isiLive_highlight.lua` extrahieren (Active-Target-Resolver + Highlight-State-Entscheidung).
- [x] `isiLive_refresh.lua` extrahieren (voller Refresh-Flow inkl. forced HELLO/KEY + Inspect-Refresh).
- [x] Event-Dispatcher in `isiLive.lua` auf duenne Routing-Schicht reduzieren.
- [x] Nach jedem Schritt: `stylua --check .` + `luacheck --exclude-files ".luarocks/**" -- .` + `lua tools/lua_metrics_check.lua` + kurzer Ingame-Smoketest.
- [x] Zielgroesse: `isiLive.lua` deutlich reduzieren (Richtwert < ~1200 Zeilen) ohne Verhaltensaenderung.
