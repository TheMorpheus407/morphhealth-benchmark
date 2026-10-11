# morphhealth (App-Quellen)

Flutter-Quellen der Android-App MorphHealth (Package-ID
`de.themorpheus.morphhealth.local`, Einstieg `lib/main.dart`).

Bedienung, Build/Start, Entscheidungen, Datenformate, Tests und bekannte
Grenzen sind in der **README.md im Wurzelverzeichnis** des Arbeitsverzeichnisses
dokumentiert; das Sicherheitskonzept in der **SECURITY.md** daneben.

Kurz:

```bash
../build.sh    # baut ../artifacts/morphhealth.apk und den Wartungszugang mh
../check.sh    # flutter analyze + flutter test + Artefakt- + mh-Smoke-Prüfung
```

Layout der Quellen:

```text
lib/main.dart                 Einstieg der App
bin/mh.dart                   CLI-Einstieg des Wartungszugangs (mh, SPEC P10)
lib/src/core/                 Uhr, Fehler, Parser, IDs
lib/src/crypto/               AES-256-GCM + PBKDF2-Container (MHST/MHBK)
lib/src/store/                verschlüsselter Speicher, Schlüsseldatiei, Backup
lib/src/model/                Domänenmodell + portables Dokument (JSON)
lib/src/data/                 Repository (einzige Schreib-/Lese-Schnittstelle)
lib/src/nutrients/            31 Nährstoffe (Definition, Einheiten, Aggregation)
lib/src/nutrition/            Tagesauswertung
lib/src/cycle/                Zykluseinschätzung aus der Historie
lib/src/food/                 Open-Food-Facts-Client (lesend, P08) + Mapping
lib/src/l10n/                 Strings de/en (eigene Schicht)
lib/src/ui/                   Screens, Shell, Widgets
lib/src/cli/                  mh-Fachlogik (JSON-Lines-Protokoll)
```
