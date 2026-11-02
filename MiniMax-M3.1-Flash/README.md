# MorphHealth

**MH-PERSONAL-3 · Fassung 1.0-rc3**

MorphHealth ist eine lokale Android-App (Flutter) mit vier voneinander
unabhängig nutzbaren Bereichen: **Ernährungstagebuch** mit Open Food Facts,
**persönlicher Periodentracker**, **Gewicht** und **Symptome**. Die App
arbeitet ohne Konto, ohne Backend und ohne Netzverbindung; nur die optionale
Lebensmittelsuche braucht das Internet. Alle Gesundheitsdaten liegen
verschlüsselt auf dem Gerät.

---

## 1. Inhalt

```text
.
├── app/                                  Flutter-Anwendung
│   ├── lib/main.dart                     Einstiegspunkt
│   ├── lib/src/                          UI, Zustand, Plattformkanäle
│   ├── packages/morphhealth_core/        gemeinsamer, reiner Dart-Kern
│   │   ├── lib/                          Datenmodell, Speicher, Dienste
│   │   ├── bin/mh.dart                   Wartungszugang (JSON Lines)
│   │   └── test/                         33 Unit- und Integrationstests
│   ├── test/                             6 Widget-Tests
│   ├── android/                          Android-Projekt (Package-ID …local)
│   └── pubspec.lock                      aufgelöste, gepinnte Abhängigkeiten
├── artifacts/morphhealth.apk             installierbare Release-APK
├── tools/                                Hilfsskripte (Konfiguration, UI-Automation)
├── mh                                    lokaler Wartungszugang (ausführbar)
├── build.sh                              baut APK und mh
├── check.sh                              Analyse, Tests, CLI-Rauchtest
├── README.md                             dieses Dokument
├── SECURITY.md                           Sicherheitskonzept
├── SPEC.md                               Auftrag (unverändert)
└── ENVIRONMENT.json                      Umgebung (unverändert, schreibgeschützt)
```

## 2. Bauen und starten

Voraussetzungen: Flutter 3.41.9 / Dart 3.11.5, Android SDK (Plattform 36,
Build-Tools 36.1.0), JDK 17 oder 21, Python 3.

```bash
./build.sh          # erzeugt artifacts/morphhealth.apk und build/mh
./check.sh          # Analyzer, Tests, CLI-Rauchtest
```

Einzelschritte:

```bash
python3 tools/generate_food_api_config.py      # liest ENVIRONMENT.json
(cd app/packages/morphhealth_core && dart pub get)
(cd app && flutter pub get)
(cd app && flutter build apk --release)         # → app/build/app/outputs/flutter-apk/
(cd app/packages/morphhealth_core && dart compile exe bin/mh.dart -o ../../build/mh)
```

Installieren und starten (Referenzgerät `emulator-5560`):

```bash
adb -s emulator-5560 reverse tcp:8788 tcp:8788     # Lebensmittelendpunkt
adb -s emulator-5560 install -r -t artifacts/morphhealth.apk
adb -s emulator-5560 shell am start -n de.themorpheus.morphhealth.local/.MainActivity
```

Ohne `adb reverse` funktioniert die App vollständig offline; nur Suche und
Barcode-Lookup brauchen den Endpunkt.

## 3. Bedienung

### 3.1 Übersicht

Startbildschirm mit den vier Bereichen. Welche Bereiche erscheinen, legt der
Nutzer unter *Einstellungen → Bereiche in der Übersicht* fest. Jede Karte
öffnet den passenden Bereich, „Tag im Detail“ öffnet die Tagesansicht.

### 3.2 Ernährungstagebuch

* Tabs: **Tag**, **Nährwerte**, **Verlauf**, **Tagesziele**.
* Datum über die Pfeile, den Datumswähler oder „Heute“ wechseln.
* **Eintrag hinzufügen** öffnet fünf Quellen:
  * *Lebensmittel suchen* – Volltextsuche in Open Food Facts
    (`GET {base}/cgi/search.pl`), Treffer mit Name, Marke, kcal/100 g.
  * *Barcode eingeben* – Produktabruf (`GET {base}/api/v3.6/product/{barcode}.json`).
  * *Eigene Lebensmittel* – selbst angelegte Lebensmittel, voll bearbeitbar.
  * *Zuletzt erfasst* – bereits protokollierte Lebensmittel erneut erfassen.
  * *Favoriten* – als Favorit markierte Lebensmittel.
* Beim Speichern werden Menge (g, ml, Portion), Mahlzeit (Frühstück,
  Mittagessen, Abendessen, Snack), Datum, Uhrzeit und Notiz festgehalten.
  Einträge sind später änderbar und löschbar.
* **Erneut erfassen** (Symbol ↻) öffnet einen bereits protokollierten
  Eintrag mit denselben Werten als Vorlage für einen neuen Eintrag – für
  wiederkehrende Mahlzeiten ohne erneute Suche.
* **Wasser & Koffein**: Schnellerfassung für Wasser (200/250/500 ml,
  konfigurierbar), zusätzliches Koffein in mg. Koffein aus Lebensmitteln wird
  zusätzlich gezählt.
* **Nährwerte**: Energie, Protein, Kohlenhydrate, Fett sowie gesättigte
  Fettsäuren, Zucker, Ballaststoffe, Salz, Natrium, Koffein und alle 21
  Mikronährstoffe (Vitamine A, C, D, E, K, B1, B2, B3, B5, B6, B7, B9, B12;
  Kalzium, Eisen, Magnesium, Kalium, Zink, Selen, Jod, Phosphor).
* **Verlauf**: ein auswählbarer Nährwert über 7 oder 28 Tage.
* **Tagesziele**: freiwillig für Wasser, Kalorien und die drei Makronährstoffe.

### 3.3 Periodentracker

* Tabs: **Kalender**, **Historie**, **Einschätzung**.
* Kalender zeigt erfasste Perioden, das erwartete Fenster und Symptompunkte;
  Monate sind frei durchblätterbar. Ein Tag öffnet seine Symptome und das
  Tagesdetail.
* Erfassung: Beginn, Ende (optional, solange die Periode andauert),
  Blutungsstärke (keine, nur Schmierblutung, leicht, mittel, stark),
  Spotting-Kennzeichnung und Notiz. Alles später korrigierbar und löschbar.
* **Einschätzung** wertet die eigene Historie aus: Zyklustag, Ø Zykluslänge,
  beobachtete Spanne, Ø Periodenlänge, erwarteter nächster Beginn und das
  daraus folgende Zeitfenster – jeweils mit Klartextbegründung. Die Einschätzung
  ist ausdrücklich persönliche Dokumentation, keine Diagnose und keine
  Verhütungs- oder Eisprungberechnung.
* Wer nur dokumentieren will, lässt den Bereich als Tagebuch nutzen.

### 3.4 Gewicht und Symptome

* **Gewicht**: Einträge mit Datum, Anzeige in kg oder lb (Einstellung),
  Bearbeiten, Löschen, Verlauf über 7 oder 28 Tage, Durchschnitt sowie Minimum
  und Maximum.
* **Symptome**: freier Name, Intensität 0–10, Datum und Uhrzeit, optionale
  Notiz. Verlauf je Symptom auswählbar, über 7 oder 28 Tage.

### 3.5 Verlauf (Historie)

Eine Suche über alle vier Bereiche. Filter: Zeitraum, Bereich und Freitext.
Treffer lassen sich öffnen und bearbeiten.

### 3.6 Tagesdetail

Ernährung, Wasser/Koffein, Gewicht, Periodenaufzeichnung und Symptome eines
Tages in einer Ansicht.

### 3.7 Einstellungen

Sprache (Deutsch voreingestellt, Englisch vollständig), Gewichtseinheit,
sichtbare Bereiche, Tagesziele, Datenexport, Datenimport, verschlüsselte
Sicherung, Wiederherstellung, vollständiges Löschen sowie Anzeige und
Überschreibung des Lebensmitteldienstes.

## 4. Der lokale Wartungszugang `mh`

`mh` ist ein schmaler JSON-Lines-Zugang auf **dieselben** Daten und
Funktionen wie die App. Er läuft als eigener Linux-Prozess, nicht als
öffentlich erreichbarer Dienst.

```bash
./mh --data-dir /abs/pfad --key-file /abs/pfad/z Keydatei \
     [--now 2026-09-23T10:00:00+02:00] \
     [--food-base-url https://host] [--food-user-agent "MorphHealth/1.0-rc3"]
```

| Option | Bedeutung |
|---|---|
| `--data-dir` | persistenter Arbeitsdatenbestand (wird bei Bedarf angelegt) |
| `--key-file` | Datei mit **32 rohen Bytes**; muss außerhalb von `--data-dir` liegen |
| `--now` | fixiert die fachliche Uhr des Prozesses (RFC3339); ohne Option die Systemuhr |
| `--food-base-url` | Origin des lesenden Open-Food-Facts-Endpunktes |
| `--food-user-agent` | User-Agent der Anfragen |

Schlüsseldatei erzeugen:

```bash
head -c 32 /dev/urandom > ~/.morphhealth.key && chmod 600 ~/.morphhealth.key
```

### 4.1 Protokoll

* Eine Anfrage ist **eine JSON-Zeile** mit `request_id` und `op`.
* Eine Antwort ist **eine JSON-Zeile** mit demselben `request_id`, `ok` und
  entweder `data` oder `error`.
* Nach jeder Anfrage wird genau eine Zeile geschrieben und sofort geflusht.
* Auf stdout steht nichts außer den Antwortzeilen; Hinweise gehen nach stderr.
* EOF auf stdin beendet den Prozess.

Anfrage:

```json
{"request_id": 1, "op": "nutrition.day", "date": "2026-09-23"}
```

Antwort:

```json
{"request_id": 1, "ok": true, "data": {"date": "2026-09-23", "calories_kcal": 0.0, "…": "…"}}
```

Fehler:

```json
{"request_id": 1, "ok": false, "error": {"code": "missing_field", "message": "\"date\" is required."}}
```

### 4.2 Operationen

| `op` | Weitere Eingabe | `data` |
|---|---|---|
| `describe` | – | Beschreibung aller Datenformate, Ein-/Ausgaben und ein importierbares Beispieldokument |
| `portable.export` | `ack_plaintext: true` (Pflicht) | vollständiger Export im portablen Format (`document`, `format`, `version`, `counts`) |
| `portable.import` | `document`, `confirm_replace: true` (Pflicht) | `{"imported": true, "counts": {…}}` |
| `nutrition.day` | `date` (`YYYY-MM-DD`) | Tageswerte: `calories_kcal`, `protein_g`, `carbohydrates_g`, `fat_g`, `saturated_fat_g`, `sugars_g`, `fiber_g`, `salt_g`, `sodium_mg`, `caffeine_mg`, `water_ml`, `nutrients`, `entries`, `water_entries`, `caffeine_entries` |
| `cycle.forecast` | `on` (`YYYY-MM-DD`), optional `lang` | `cycle_day`, `average_cycle_length`, `min_cycle_length`, `max_cycle_length`, `average_period_length`, `last_period_start`, `last_period_end`, `predicted_next_start`, `predicted_window_start`, `predicted_window_end`, `days_until_predicted_start`, `beyond_observed_range`, `inside_recorded_period`, `explanation` |
| `food.search` | `q`, optional `page` | `query`, `page`, `page_size`, `total`, `count`, `items[]` mit `barcode`, `name`, `brand`, `image_url`, `quantity`, `serving_g`, `serving_label`, `energy_kcal_per_100`, `nutriscore`, `nova_group` und – soweit die Suchantwort sie liefert – `nutrients_per_100` |
| `food.lookup` | `barcode` | `found`, optional `message`, optional `food` mit `nutrients_per_100` |

Beispiel:

```bash
printf '%s\n' \
  '{"request_id":1,"op":"describe"}' \
  '{"request_id":2,"op":"nutrition.day","date":"2026-09-23"}' \
  '{"request_id":3,"op":"cycle.forecast","on":"2026-09-23"}' \
  '{"request_id":4,"op":"food.search","q":"hafermilch","page":1}' \
  '{"request_id":5,"op":"food.lookup","barcode":"5411188137979"}' \
| ./mh --data-dir /tmp/mh-data --key-file ~/.morphhealth.key
```

`describe` liefert die vollständige, maschinenlesbare Beschreibung der
Formate – ein Entwickler braucht keine Rückfragen.

### 4.3 Beziehung zwischen App und `mh`

Beide greifen auf denselben Code zu (`app/packages/morphhealth_core`):
denselben verschlüsselten Speicher, dieselbe Tagesberechnung, dieselbe
Zyklusauswertung, denselben Open-Food-Facts-Client, dasselbe Exportformat.
Der Wartungszugang ist eine **weitere Aufrufmöglichkeit**, keine zweite
Implementierung. Die Datenverzeichnisse liegen an verschiedenen Orten
(App-Sandbox auf dem Gerät, Arbeitsverzeichnis auf dem Host); übertragen
werden Daten mit dem portablen Dokument oder der verschlüsselten Sicherung.

## 5. Datenformate

### 5.1 Lokaler Speicher (siehe `SECURITY.md`)

```text
<data-dir>/manifest.json   Format, Version, KDF, Salt – keine Gesundheitsdaten
<data-dir>/records.bin     ausschließlich AES-256-GCM-verschlüsselte Datensätze
<data-dir>/store.lock      Sperrdatei gegen parallele Schreiber
```

### 5.2 Portables Dokument

JSON-Objekt mit `format: "morphhealth.portable"`, `version: 1`,
`exported_at`, `app`, `counts` und den Abschnitten `foods`,
`journal_entries`, `intake_entries`, `periods`, `weights`, `symptoms`, `goals`,
`settings`. Einheiten: Nährwerte in g je 100 g (Energie kcal/kJ), Wasser in ml,
Koffein in mg, Gewicht in kg, Intensität 0–10. Das vollständige Beispiel
liefert `mh describe`.

### 5.3 Verschlüsselte Sicherung (`*.mhbackup`)

Binärer Container `MHBACKUP` mit Argon2id-Parametern, Salt, Nonce, GCM-Tag und
dem verschlüsselten portablen Dokument. Die Passphrase schützt die Datei, die
Datei ist vollständig selbständig und damit für eine frische Installation
geeignet.

## 6. Wesentliche Entscheidungen

* **Ein gemeinsamer Kern statt zwei Implementierungen.** Der gesamte
  Produktcode liegt in `app/packages/morphhealth_core` (reines Dart, keine
  Flutter-Abhängigkeit). App und `mh` verwenden dieselben Klassen. Das ist die
  Voraussetzung dafür, dass der Wartungszugang wirklich dieselben Daten und
  Funktionen sieht.
* **Eigener verschlüsselter Speicher statt Datenbank.** Bewusst kein SQLite:
  der Kern soll ohne Native-Bibliotheken auf Android *und* auf dem Linux-Host
  laufen. Format: anhängendes, AES-256-GCM-verschlüsseltes Protokoll mit
  Index im Speicher, verdichtet bei Bedarf. 10.000 Einträge lassen sich damit
  in rund einer halben Sekunde laden (gemessen, siehe Abschnitt 7).
* **Schlüssel im Android Keystore.** Der 32-Byte-Hauptschlüssel wird
  zufällig erzeugt und mit einem nicht exportierbaren Keystore-Schlüssel
  verschlüsselt abgelegt. Der Keystore-Schlüssel selbst verlässt die App nie.
* **Nährwert-Schnappschuss je Eintrag.** Jeder Tagebucheintrag merkt sich die
  Nährwerte des Lebensmittels zum Zeitpunkt des Erfassens. Wird das
  Lebensmittel später gelöscht, bleiben die Tageszahlen korrekt; wird es
  geändert, zählt die Änderung für bestehende Einträge (wie erwartet).
* **Milliliter = Gramm.** Für Getränke wird 1 ml wie 1 g behandelt; die
  Nährwerte des Lebensmittels gelten je 100 g bzw. je 100 ml. Das ist die
  übliche Vereinfachung von Lebensmittel-Apps und in den Grenzen genannt.
* **Ein auswählbarer Nährwertverlauf** statt vieler gleichzeitig offener
  Diagramme – so verlangt es der Auftrag.
* **Werte kommen aus Open Food Facts, nicht aus einer Datenbank im Gerät.**
  Die App liest nur; eine Beitragsfunktion ist nicht Teil des Auftrags.
* **Kein Kamera-Scanner.** Der Auftrag nennt ihn ausdrücklich als
  Nichtumfang; der Barcode wird von Hand eingegeben.
* **Sprachkatalog im Kern.** Ein einziger Katalog für DE und EN, damit App
  und CLI dieselben Formulierungen verwenden.

## 7. Tatsächlich durchgeführte Tests

### 7.1 Statische Analyse

| Umfang | Ergebnis |
|---|---|
| `dart analyze` (Kern, inklusive `bin/mh.dart` und `test/`) | keine Befunde |
| `flutter analyze` (App inklusive `test/`) | keine Befunde |

### 7.2 Automatisierte Tests

| Suite | Umfang | Ergebnis |
|---|---|---|
| `app/packages/morphhealth_core/test` | 33 Tests: Nährstoffregister, Datumsrechnung, Übersetzungen, verschlüsselter Speicher (Neustart, falscher Schlüssel, Klartextprüfung, Grabsteine, Verdichtung, Sperre, `replaceAll`), Tagesberechnung (g/ml/Portion, Schnappschuss nach Löschung, Koffein), Zyklusauswertung, Historiefilter, Export/Import, Sicherungscontainer, Lebensmittelvertrag gegen einen lokalen Server auf einem anderen Origin, Leistung | **33/33 bestanden** |
| `app/test` | 6 Widget-Tests: Übersicht, Tagessumme, Zykluseinschätzung, Sprachumschaltung, Lebensmittelauswahl, Historienfreitext | **6/6 bestanden** |
| `./check.sh` | Analyzer + beide Suiten + CLI-Rauchtest (einschließlich der Schutzmechanismen von `portable.export` und `portable.import`) | bestanden |

Gemessene Laufzeit im Leistungstest (10.000 Tagebucheinträge, Referenzhost;
Werte streuen zwischen den Läufen):

| Schritt | Dauer |
|---|---|
| 10.000 Einträge schreiben | ≈ 2,7–3,9 s |
| Speicher öffnen und laden | ≈ 0,48–0,63 s |
| Tagesabfrage + Volltextsuche über 10.000 Einträge | ≈ 42–62 ms |

### 7.3 Manuelle Prüfungen auf dem Referenzgerät

Gerät: `emulator-5560`, Android 15 / API 35, x86_64, 1080 × 2400 bei 420 dpi.

* Release-APK installiert und gestartet, Package-ID `de.themorpheus.morphhealth.local`,
  ABIs `arm64-v8a`, `armeabi-v7a`, `x86_64`.
* Übersicht mit allen vier Bereichen, Tagessumme, Wasserschnellerfassung.
* Lebensmittelsuche gegen den bereitgestellten Open-Food-Facts-Endpunkt
  (`adb reverse tcp:8788 tcp:8788`), Produktabruf per Barcode.
* Tagebucheintrag speichern, erneut erfassen (Vorlage aus dem letzten Eintrag)
  und wieder löschen; Tagessumme folgt jeder Änderung.
* Kalender mit Periode, Historie und persönlicher Einschätzung (aus drei
  erfassten Perioden: Ø Zyklus 39,5 Tage, Ø Periodenlänge 5 Tage, erwarteter
  nächster Beginn 1. Dezember 2026).
* Gewichtseintrag (68,4 kg) mit Verlauf, Durchschnitt und Minimum/Maximum;
  Umschaltung des Zeitraums 7/28 Tage.
* Symptomeintrag („Kopfschmerzen“, Intensität 7/10) mit Filter je Symptom und
  Verlauf über 7/28 Tage.
* Tagesdetail über alle vier Bereiche.
* Verlauf mit Freitextfilter.
* Einstellungen, Sprachumschaltung Deutsch → Englisch (die gesamte Oberfläche
  wechselt sofort, auch Navigation und Dialoge).
* Export über den Android-Dokumentdialog: die Datei
  `morphhealth-export-<datum>.json` enthält alle acht Datensätze im
  dokumentierten Format; der Import derselben Datei stellt den Bestand wieder
  her.
* Verschlüsselte Sicherung über den Dokumentdialog: die Datei
  `morphhealth-backup-<datum>.mhbackup` trägt die Kennung `MHBACKUP` und
  enthält keinen lesbaren Klartext (geprüft: keine der erfassten Begriffe
  kommt im Container vor).
* Wiederherstellung: mit **falscher** Passphrase „Wrong passphrase or damaged
  file“, mit **richtiger** Passphrase wird der Datenbestand des Backups
  übernommen (ein nach dem Backup geänderter Datensatz verschwindet wieder).
* Vollständiges Löschen des lokalen Datenbestands: die Übersicht ist danach
  leer (0 kcal, „No period recorded yet“, „— kg“).
* **Sicherung auf frischer Installation:** nach dem Löschen stellt dieselbe
  `.mhbackup`-Datei den vollständigen Bestand wieder her (33 kcal, 250 ml
  Wasser, drei Perioden, 68,4 kg, Symptom) – die Sicherung ist damit zur
  Übernahme auf eine frische Installation geeignet.

### 7.4 CLI-Prüfungen

* Alle sieben Operationen über eine Pipe beantwortet, je eine Zeile pro
  Anfrage.
* `portable.export` ohne `ack_plaintext` wird mit `ack_required` abgewiesen.
* `portable.import` ohne `confirm_replace` wird mit `confirm_required`
  abgewiesen.
* `food.lookup` für `5411188137979` liefert die vollständigen Nährwerte je
  100 g (u. a. Vitamin B12, Selen, Zink).
* Der Lebensmittelvertrag ist zusätzlich automatisiert geprüft: ein Test
  startet einen lokalen Server auf einem **anderen** Origin als den im
  Umgebungsmanifest hinterlegten und belegt, dass dieselbe Fachlogik dort
  unverändert funktioniert (Suche, Produktabruf, Nährwertzuordnung,
  User-Agent-Header).
* Falsche Passphrase ⇒ `BackupException`, richtige Passphrase ⇒ Dokument.

## 8. Bekannte Grenzen und Einschränkungen

* **Milliliter werden wie Gramm gerechnet.** Bei Getränken mit stark
  abweichender Dichte (Alkohol, Sirup) entstehen dadurch kleine Abweichungen.
* **Mengenangaben ohne Lebensmittel.** Der Tagessummen-Kaloriengehalt eines
  Produkts ohne Nährwertdaten (selten im Datenbestand) wird nicht geschätzt.
* **Der Export im Klartext.** `portable.export` liefert bewusst unverschlüsseltes
  JSON; das ist protokolliert und in `SECURITY.md` beschrieben. Für den Weg
  über Dateisysteme ist die verschlüsselte Sicherung gedacht.
* **Ein Gerät, ein Datenbestand.** Es gibt keine Synchronisation zwischen
  Geräten; die Übertragung erfolgt über Export/Sicherung.
* **Kein Kamerascanner.** Der Barcode wird von Hand eingegeben.
* **Der Emulator zeigt gelegentlich einen System-UI-ANR.** Das ist eine
  Eigenheit des softwaregerenderten Referenzemulators (swiftshader) und kein
  Fehler der App; die App bleibt bedienbar.
* **Der Gradle-Build lädt beim ersten Mal** Android-Plugin und Gradle
  distribution aus dem Netz; die Abhängigkeiten sind in `pubspec.lock`
  gepinnt, die Gradle-Version in `android/gradle/wrapper/gradle-wrapper.properties`.
* **Die Release-APK ist mit dem Debug-Schlüssel signiert**, weil im
  Benchmark keine eigene Signaturinfrastruktur bereitsteht. Für eine
  Store-Veröffentlichung müsste ein echtes Release-Keystore eingebunden
  werden (nicht Teil des Auftrags).
* **`flutter build apk` erzeugt ein Universal-APK** (56 MB) mit drei
  ABIs. Ein architekturspezifisches APK wäre kleiner.

## 9. Nichtumfang

Wie im Auftrag gefordert, sind nicht enthalten: Schlaf, Schritte,
Wearables, Health Connect, BLE, Konten, Backend, Synchronisation, iOS,
medizinische Dokumente, OCR, Foto-Kalorien, Barcode-Kamera, Laufzeit-LLMs,
Medikamentenverwaltung, automatische Ernährungspläne, Rezepteditor,
Benachrichtigungen und Store-Veröffentlichung.

## 10. Lizenz und Datenquellen

Open Food Facts (ODbL) liefert die Produktdaten. Die Datenbank wird nur
gelesen; eigene Lebensmittel bleiben lokale Nutzerdaten und werden nicht
übertragen.
