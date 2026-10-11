# MorphHealth

MorphHealth ist ein persönliches Gesundheitstagebuch für Android: Ernährungstagebuch mit
Open-Food-Facts-Anbindung, persönlicher Periodentracker, Gewicht und Symptome.
Die App ist vollständig lokal nutzbar — ohne Konto, ohne eigenen Backend-Dienst und ohne
laufende Internetverbindung (die Online-Lebensmittelsuche ist die einzige Ausnahme).
Alle Gesundheitsdaten liegen verschlüsselt auf dem Gerät.

Auftrag: **MH-PERSONAL-3, Fassung 1.0-rc3** (siehe `SPEC.md`).
App-Version **1.0.0+1**, Package-ID **`de.themorpheus.morphhealth.local`**.

## Artefakte (Lieferumfang nach P09/P10)

```text
├── app/                        Flutter-Quellen, Assets, pubspec.lock (Einstieg: app/lib/main.dart)
├── artifacts/
│   ├── morphhealth.apk         Release-APK (ca. 20 MiB, x86_64-Unterstützung, debug-signiert)
│   ├── mh-cli/bundle/bin/mh    AOT-kompilierter Wartungszugang (mh, P10)
│   └── e2e-appdata/            Host-Kopie des echten App-Datenbestands nach dem E2E-Testlauf
├── build.sh                    baut APK + mh (ausführbar)
├── check.sh                    prüfen: analyze + Tests + Artefakte + mh-Smoke (ausführbar)
├── mh                          Starter für den Wartungszugang (ausführbar)
├── README.md                   diese Datei
├── SECURITY.md                 Sicherheitskonzept, Bibliotheken, Dateiformate
├── SPEC.md                     der Auftrag (unverändert)
└── ENVIRONMENT.json            Umgebungsbeschreibung (schreibgeschützt)
```

## Bedienung

Die gesamte Oberfläche ist auf **Deutsch und Englisch** verfügbar, Deutsch ist
voreingestellt (Einstellungen → Darstellung → Sprache: System / Deutsch / Englisch).

### Navigation

Unten liegt eine Navigationsleiste mit der **Übersicht** und den **vier Bereichen**
Ernährung, Zyklus, Gewicht und Symptome. In den Einstellungen lassen sich die vier
Bereiche einzeln aus- und einblenden (mindestens einer bleibt sichtbar); die
Navigationsleiste und die Übersichtskarten passen sich an. Oben rechts (auf der
Übersicht) erreichen Sie Suche (Historie), Verläufe und Einstellungen.

### Ernährung (P03)

- **Lebensmittel suchen**: Namensuche und Barcode-Eingabe gegen Open Food Facts
  (echter Datenbankabruf über HTTPS; ein Kamerascanner ist nicht Teil des Auftrags).
- **Erfassen**: Lebensmittel aus den Suchergebnissen, aus Favoriten oder eigene
  Lebensmittel; Menge in **Gramm, Milliliter oder Portionen**; Mahlzeit
  (Frühstück, Mittagessen, Abendessen, Snack); Datum und Uhrzeit; Notiz.
- Ein bereits protokollierter Verzehr lässt sich erneut erfassen ("wieder erfassen").
- Eigene Lebensmittel sind anlegbar, **bearbeitbar** und als Favoriten markierbar.
- Verzehreinträge sind nachträglich **korrigierbar und löschbar**.
- Pro Eintrag und pro Tag werden angezeigt: Kalorien, Protein, Kohlenhydrate, Fett,
  gesättigte Fettsäuren, Zucker, Ballaststoffe, Salz, Natrium, Koffein sowie die
  Mikronährstoffe Vitamin A, C, D, E, K, B1, B2, B3, B5, B6, B7, B9, B12 und die
  Mineralstoffe Kalzium, Eisen, Magnesium, Kalium, Zink, Selen, Jod, Phosphor
  (31 Nährstoffe insgesamt, Einheiten kcal/g/mg/µg).
- **Wasser und Koffein** werden direkt im Ernährungstagebuch erfasst, mit
  Schnellerfassung für häufige Mengen (Wasser: 200/250/330/500 ml; Koffein:
  40/80/120 mg).
- Freiwillige **Tagesziele** für Wasser, Kalorien, Protein, Kohlenhydrate und Fett
  (Einstellungen → Tagesziele; leer = kein Ziel).

### Zyklus (P04)

- Perioden mit Beginn und Ende erfassen, korrigieren und löschen; Blutungsstärke
  inklusive **Spotting** (pro Tag), Notizen.
- **Monatskalender** (auch ältere Monate über Kalendernavigation) und **Historie**.
- Die App wertet die persönliche Historie aus und zeigt eine **Einschätzung der
  nächsten Periode** (geschätzter Beginn mit Bereich, geschätztes Ende, laufender
  Zyklustag, Konfidenz) mit verständlicher Erklärung in der App-Sprache.
- Der Tracker ist auch **ausschließlich als Tagebuch** nutzbar (keine Verpflichtung
  zur Prognose-Nutzung). Es handelt sich um persönliche Dokumentation und Planung —
  keine Diagnosen, Eisprungberechnung, Verhütung oder medizinische Behandlung.
- Symptome sind im Zykluskalender und im Tageskontext erreichbar.

### Gewicht (P05)

- Einträge für ein gewähltes Datum (mit Uhrzeit und Notiz), Bearbeitung und Löschung.
- Eingabe und Anzeige in **kg oder lb** (umschaltbar in den Einstellungen).
- Verlauf über die letzten 7 oder 28 Tage (Verläufe-Ansicht).

### Symptome (P05)

- Frei wählbarer Name, **Intensität 0 bis 10**, Datum/Uhrzeit, optionale Notiz.
- Einträge sind bearbeitbar und löschbar.
- Symptomverlauf nach gewähltem Symptom betrachtbar.

### Übersicht, Tagesdetail, Verläufe, Historie (P06)

- Die **Übersicht** zeigt die vom Nutzer gewählten Bereiche als Karten (heute:
  Ernährung, Zyklus, Gewicht, Symptome) plus Schnellzugriffe.
- Das **gemeinsame Tagesdetail** führt Ernährung, Wasser/Koffein, Gewicht,
  Periodenaufzeichnungen und Symptome eines Tages zusammen (Tagesnavigation inklusive).
- **Verläufe** über 7 und 28 Tage; für Nährstoffe ein auswählbarer Verlauf
  (ein Nährstoff zur Zeit, statt vieler gleichzeitig geöffneter Diagramme).
- Die **Historie** ist durchsuchbar über alle vier Bereiche hinweg, mit Filtern
  für Datumsbereich, Bereich und Freitext; Einträge lassen sich von dort öffnen
  und bearbeiten.
- Kalendernavigation erlaubt auch die Betrachtung älterer Monate.

### Daten-Transfer (P07)

Einstellungen → Daten:

- **Export / Import**: vollständiger, maschinenlesbarer Klartext-Export
  (`morphhealth.portable` v1, JSON) und Import als Ersatz des Datenbestands.
  Der Export erfordert eine bewusste Bestätigung (Klartext-Hinweis), Dateien werden
  über das Storage Access Framework (SAF) gewählt — keine Speicherberechtigung nötig.
- **Sicherung erstellen / wiederherstellen**: passphrasengeschützte, verschlüsselte
  Sicherung (PBKDF2-HMAC-SHA256, AES-256-GCM), geeignet zur Übernahme auf eine
  frische Installation (enthält den vollständigen Datenbestand; die Schlüsseldatiei
  des Geräts wird nicht benötigt und nicht exportiert).
- **Alles löschen**: löscht den gesamten lokalen Datenbestand.

## Build und Start

Voraussetzungen und konkrete Versionen stehen im schreibgeschützten `ENVIRONMENT.json`
(Flutter 3.41.9 / Dart 3.11.5, Android SDK, JBR 21 für Gradle, adb, Emulator).

### App bauen

```bash
./build.sh
```

baut `artifacts/morphhealth.apk` (Release) und den Wartungszugang
`artifacts/mh-cli/bundle/bin/mh`. App-Version und Food-API-Origin werden per
`--dart-define` einkompiliert (Werte aus `ENVIRONMENT.json`). Dauer: wenige Minuten.

### Auf dem Referenzgerät (emulator-5560) starten

```bash
# Emulator starten (ENVIRONMENT.json: restart_command)
LD_LIBRARY_PATH=/nix/store/id0pwhcwsnp9vc76ghlawnmrvxziqfmf-morphhealth-emulator-libs/lib \
  /home/morpheus/Android/Sdk/emulator/emulator -avd morphhealth_ref_api35 -port 5560 \
  -writable-system -no-snapshot -no-audio -no-boot-anim -gpu swiftshader_indirect &

ADB=/home/morpheus/Android/Sdk/platform-tools/adb
$ADB -s emulator-5560 wait-for-device          # nie emulator-5556 verwenden!
$ADB -s emulator-5560 reverse tcp:8788 tcp:8788 # App → https://localhost:8788
$ADB -s emulator-5560 install -r artifacts/morphhealth.apk
$ADB -s emulator-5560 shell am start -n de.themorpheus.morphhealth.local/.MainActivity
```

Hinweis: Die in dieser Benchmark-Umgebung einkompilierte Food-API-URL ist
`https://localhost:8788` (Wert aus `ENVIRONMENT.json`); `adb reverse` reicht die
Anfragen des Emulators an den Host-Endpunkt durch. Für eine normale Produktinstallation
laut P08 ist der Origin `https://world.openfoodfacts.org` (per `--dart-define`
beim Build überschreibbar; siehe `build.sh`).

### Wartungszugang `mh` (P10)

```bash
./mh --data-dir ABS --key-file ABS [--now RFC3339]
     [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]
```

`mh` ist ein gesonderter lokaler Linux-Prozess (kein Netzwerkdienst) und nutzt
**dieselben Daten und Funktionen wie die App** (Repository, Tagesauswertung,
Zykluseinschätzung, OFF-Client — keine zweite Implementierung).

- `--data-dir`: persistenter Arbeitsdatenbestand (Verzeichnis mit `morphhealth.store`).
- `--key-file`: Schlüsseldatiei mit **32 rohen Bytes**, liegt **außerhalb** des
  Datenverzeichnisses. Ohne sie sind die verschlüsselten Daten nicht lesbar; sie wird
  nie exportiert. Beispiel: `head -c 32 /dev/urandom > /tmp/mh/master.key`.
  Entspricht die Datei der App-Installation, liest `mh` exakt deren Datenbestand
  (Interop App ↔ CLI, siehe Tests).
- `--now`: setzt die fachliche Uhr für diesen Prozess (RFC3339); sonst Systemuhr.
- `--food-base-url` / `--food-user-agent`: überschreiben die einkompilierten
  Defaults (der Starter `mh` setzt die Werte aus `ENVIRONMENT.json` als
  Umgebungsvariablen `MH_FOOD_BASE_URL` / `MH_FOOD_USER_AGENT`; Kommandozeilenflags
  gewinnen; Produkt-Default ohne alles: `https://world.openfoodfacts.org`).

**Protokoll**: JSON Lines auf stdin/stdout. Anfrage eine JSON-Zeile mit `request_id`
und `op`; Antwort eine Zeile mit derselben `request_id`, `ok` und `data` bzw.
`error` (`{code, message}`); Antwort wird sofort geflusht; kein Banner; EOF beendet
den Prozess.

| `op` | Weitere Eingabe | Inhalt von `data` |
|---|---|---|
| `describe` | keine | Beschreibung der Datenformate und Operationen inkl. Beispieldokument |
| `portable.export` | `ack_plaintext: true` | vollständiger Datenexport (`morphhealth.portable` v1) |
| `portable.import` | `document`, `confirm_replace: true` | übernimmt das Dokument als Ersatz des Arbeitsdatenbestands; Ergebnisbericht |
| `nutrition.day` | `date` (`YYYY-MM-DD`) | Ernährungsangaben des Tages (wie in der App) |
| `cycle.forecast` | `on` (`YYYY-MM-DD`) | persönliche Zykluseinschätzung für diesen Tag (inkl. Erklärung de/en) |
| `food.search` | `q`, `page` (optional, Standard 1) | Ergebnisse der Lebensmittelsuche |
| `food.lookup` | `barcode` | Produktabruf; `found: false` bei unbekanntem Barcode |

Beispiel:

```bash
printf '%s\n' '{"request_id":"1","op":"describe"}' | ./mh --data-dir /tmp/mh/data --key-file /tmp/mh/master.key
```

Die vollständige Feld-Dokumentation (Datenmodell, JSON-Felder, Datentypen,
Beispieldokument) liefert `describe` zur Laufzeit — so kann ein anderer Entwickler
den Zugang ohne Rückfragen verwenden.

### Prüfen

```bash
./check.sh
```

führt aus: `flutter analyze`, `flutter test` (Unit- und Widget-Tests), Artefakt-Prüfung
(APK + mh) und einen mh-Smoke-Test (`describe` + `portable.export` gegen einen
temporären Bestand mit frisch erzeugtem Schlüssel). Bricht bei jedem Fehler ab.

## Wesentliche Entscheidungen

1. **Scopes oberhalb von `MaterialApp`.** Strings- und Daten-Scope umschließen die
   gesamte App (nicht nur `MaterialApp.home`). Eine frühere Fassung hing die Scopes
   nur an die Home-Route; jedes per `Navigator.push` geöffnete Ziel (Suche, Dialoge)
   stürzte mit „Null check operator used on a null value" ab. Behoben und mit einem
   Regressions-Widget-Test abgesichert (`app/test/widget_test.dart`).
2. **`MainActivity` im Namespace-Paket.** Die Activity liegt unter
   `android/app/src/main/kotlin/de/themorpheus/morphhealth/local/MainActivity.kt`
   (Paket `de.themorpheus.morphhealth.local`). Eine frühere Ablage eine Ebene tiefer
   ließ R8 (Release-Shrinking des Flutter-Gradle-Plugins) die nur über das Manifest
   referenzierte Klasse entfernen → `ClassNotFoundException` beim Start. Im Dex
   verifiziert.
3. **`mh` als AOT-Binary + Starter-Wrapper.** `dart compile exe` verweigert
   Flutter-Pakete wegen der Build-Hooks der Plugin-Abhängigkeiten; `dart build cli`
   erzeugt ein eigenständiges AOT-Binary (`artifacts/mh-cli/bundle/bin/mh`), ignoriert
   aber `-D`-Defines. Deshalb setzt der POSIX-sh-Starter `mh` im Wurzelverzeichnis die
   Fach-Defaults (Version, Food-API-Origin) als Umgebungsvariablen
   (`MH_FOOD_BASE_URL`, `MH_FOOD_USER_AGENT`), die der CLI-Parser als Fallback nutzt;
   Kommandozeilenflags gewinnen.
4. **Debug-signierte Release-APK.** Es existiert kein Release-Keystore im Auftrag
   (Store-Veröffentlichung ist P11-Nichtumfang); die APK ist daher mit dem
   Android-Debug-Key signiert, damit sie lokal installierbar ist
   (`apksigner verify` bestanden).
5. **Reine Dart-Kryptografie** (`package:cryptography`, kein pointycastle): derselbe
   Krypto-Code läuft in der Android-App und im AOT-kompilierten CLI.
6. **Speicherorte:** Datenbestand und Schlüssel liegen im app-privaten
   Support-Verzeichnis (`getApplicationSupportDirectory`), auf dem Gerät unter
   `/data/data/de.themorpheus.morphhealth.local/files/morphhealth/` —
   `data/morphhealth.store` (Daten) und `master.key` (32-Byte-Schlüssel, **außerhalb**
   des Datenverzeichnisses). Hinweis: path_provider 2.x liefert hier `files/`, nicht
   `app_flutter/`.
7. **Atomare Schreibzugriffe** (tmp-Datei + rename) für den verschlüsselten Speicher.
8. **Ein verschlüsselter Store** (ganzes Dokument als eine Datei) statt vieler
   Dateien; 10.000 Tagebucheinträge (P06) bleiben dadurch unproblematisch.
9. **Eigene schlanke L10n-Schicht** (de/en) mit Systemsprachen-Fallback;
   `localeConfig` in der Manifest für de/en hinterlegt.
10. **Nur lesende HTTP-Anfragen** (P08), TLS-Verifikation nie deaktiviert; der
    Food-API-Origin ist per `--dart-define` einkompiliert, nicht im Fachcode
    verankert — die Integration läuft ohne Fachcode-Änderung an einem anderen
    Origin desselben Vertrags.

## Datenformate

Vollständige Byte-Layouts und die Bibliothekstabelle stehen in `SECURITY.md`.

- **Lokaler Speicher (`MHST`)**: `"MHST" | version u16 LE | reserved u16 LE |
  nonce 12 | ciphertext | mac 16` — AES-256-GCM, Nutzlast ist UTF-8-JSON des
  Daten-Dokuments.
- **Sicherung (`MHBK`)**: `"MHBK" | version u16 LE | kdfId u8 (=1:
  PBKDF2-HMAC-SHA256) | iterations u32 LE (600000) | salt 16 | nonce 12 |
  ciphertext | mac 16` — passphrasengeschützt, Nutzlast ist das portable Dokument.
- **Portables Dokument (`morphhealth.portable` v1)**: maschinenlesbarer Voll-Export,
  Top-Level `format`, `format_version`, `generator`, `data`; `data` enthält
  `settings`, `foods`, `nutrition_entries`, `water_entries`, `caffeine_entries`,
  `periods`, `weight_entries`, `symptom_entries`. 31 Nährstoffschlüssel
  (Einheiten kcal/g/mg/µg), Mengeneinheiten g/ml/Portion.
- **mh-Protokoll (P10)**: JSON Lines, siehe oben; Feld-Details via `describe`.

## Tatsächliche Tests (P12)

Alle Ergebnisse stammen aus echten Durchläufen in dieser Umgebung (2026-10-07):

- **`flutter analyze`**: keine Befunde („No issues found!").
- **`flutter test`**: 189 Tests bestanden (Unit-Tests inkl. mh-Service (15),
  Krypto-Container, Tagesauswertung, Zykluseinschätzung; Widget-Tests inkl.
  Regressions-Test für den Navigator-Scope-Fehler).
- **APK-Prüfung**: `aapt dump badging` — Package `de.themorpheus.morphhealth.local`,
  versionName 1.0.0, versionCode 1, minSdk 26, targetSdk 35, Label „MorphHealth",
  native-code arm64-v8a/armeabi-v7a/x86_64 (x86_64-Unterstützung nach P09);
  `apksigner verify` bestanden (Debug-Signatur).
- **Emulator-Smoke (emulator-5560, API 35)**: Installation erfolgreich, App startet
  und rendert (Screenshot-Analyse), Lebensmittelsuche „Nutella" in der App erzeugt
  einen echten API-Abruf — Access-Log des bereitgestellten Endpunkts:
  `GET /cgi/search.pl?search_terms=Nutella&...&fields=code,product_name,... 200`
  (Beweis: App → API mit einkompilierter Konfiguration über `adb reverse`).
- **CLI-Ende-zu-Ende gegen den echten App-Datenbestand** (Host-Kopie des vom Gerät
  gezogenen Stores, `artifacts/e2e-appdata`): alle 6 Leseoperationen erfolgreich —
  `describe`, `portable.export`, `nutrition.day` (leerer Tag: 0 kcal),
  `cycle.forecast` (`no_data`), `food.search` „Nutella" (erstes Ergebnis), 
  `food.lookup` Barcode `3017620425035` → Nutella, 539 kcal/100 g.
- **Import-Roundtrip**: 1 Lebensmittel (Haferflocken), 1 Verzehr (1,5 Portionen =
  60 g), 1 Wasser (500 ml), 2 Perioden (2026-09-01..05, 2026-10-01..05),
  1 Gewicht (72,5 kg), 1 Symptom per `portable.import` übernommen
  (`replaced: true`); danach `nutrition.day` = **223,2 kcal / 8,1 g Protein /
  500 ml Wasser** (372 kcal × 0,6portion ✓) und `cycle.forecast` =
  `before_next`, geschätzter nächster Beginn **2026-10-31** (Bereich 2026-10-29
  bis 11-02), geschätztes Ende 2026-11-04, Konfidenz `low`, deutsche Erklärung.
- **Interop CLI → App**: der per CLI geschriebene Store wurde zurück auf das Gerät
  gespielt (App force-stopped), Neustart: die importierte Haferflocken-Mahlzeit
  erscheint in der Ernährungsansicht (Pixel-Diff gegen Leer-Zustand bestätigt
  Neu-Render, keine Fehlerseite).
- **`./check.sh`**: kompletter Durchlauf bestanden (Exit 0): `flutter analyze` ohne
  Befunde, `flutter test` 189/189 bestanden, Artefakt-Prüfung (APK + mh) bestanden,
  mh-Smoke-Test (`describe` + `portable.export` gegen frischen temporären Bestand)
  bestanden.

## Bekannte Grenzen

- **Kein Kamerascanner** für Barcodes (P03: ausdrücklich nicht Teil des Auftrags);
  Barcodes werden eingegeben.
- **P11-Nichtumfang** ist nicht implementiert: kein Schlaf/Schritte/Watch/Health
  Connect/BLE, keine Konten, kein Backend, keine Multi-Device-Synchronisation,
  kein iOS, keine medizinischen Dokumente, kein OCR, keine Foto-Kalorienschätzung,
  keine Laufzeit-LLMs, keine Medikamentenverwaltung, keine automatischen
  Ernährungspläne, kein Rezepteditor, keine Benachrichtigungen, keine
  Store-Veröffentlichung.
- **Debug-signierte APK** (siehe Entscheidungen 4) — nicht für einen Store-Release
  geeignet; für diese Abgabe ohne Release-Keystore bewusst so gewählt.
- **`dart build cli` ist ein Dart-Preview-Kommando** — funktioniert stabil
  (Dart 3.11.5), ist aber als „preview" markiert.
- **Food-API-Origin dieser Build-Konfiguration** ist der Benchmark-Endpunkt
  `https://localhost:8788` (Wert aus `ENVIRONMENT.json`, via `adb reverse` auf dem
  Emulator erreichbar). Für eine Produktinstallation gegen
  `https://world.openfoodfacts.org` neu bauen (Werte in `build.sh`).
- **Zykluseinschätzung** ist eine einfache Auswertung der persönlichen Historie
  (mittlere Zykluslänge/-dauer), keine medizinische Aussage; Konfidenz wird
  mit ausgegeben.
- Der Datenbestand des Emulators enthält aktuell die E2E-Testdaten (geringe Menge);
  über Einstellungen → Daten → „Alles löschen" zurücksetzbar.
- Nur Android (P09). Keine Web-/Desktop-Builds erzeugt.
