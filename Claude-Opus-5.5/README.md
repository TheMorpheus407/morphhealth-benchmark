# MorphHealth

Persönliches Tagebuch für **Ernährung** (mit Open Food Facts), **Zyklus**, **Gewicht** und **Symptome** als native Android-App in Flutter – lokal, verschlüsselt, ohne Konto, ohne Werbung, ohne Telemetrie, ohne KI. Deutsch ist voreingestellt, Englisch vollständig verfügbar.

Umsetzung des Auftrags `SPEC.md` (MH-PERSONAL-3, Fassung 1.0-rc3-L1). Sicherheitskonzept: [`SECURITY.md`](SECURITY.md).

---

## Inhalt der Abgabe

| Pfad | Inhalt |
|---|---|
| `app/` | Flutter-Projekt (Einstieg `app/lib/main.dart`), `pubspec.yaml` + `pubspec.lock` |
| `app/lib/core/` | Fachkern in reinem Dart (Modell, Speicher, Krypto, Nährwerte, Zyklus-Einschätzung, Open Food Facts, Historie, Import/Export, Texte DE/EN, Wartungsprotokoll). Wird von der App **und** von `mh` verwendet. |
| `app/lib/ui/` | Android-Oberfläche (Material 3) |
| `app/android/…/MainActivity.kt`, `KeyVault.kt` | Plattformkanal: App-Datenverzeichnis, Android-Keystore, Dokumentauswahl (SAF) |
| `app/bin/mh.dart` | Einstiegspunkt des Wartungsprozesses |
| `app/test/`, `app/integration_test/` | Unit-, Widget-, Barrierefreiheits-, Layout-, Performance- und Gerätetests |
| `artifacts/morphhealth.apk` | Release-APK (armeabi-v7a, arm64-v8a, **x86_64**), Package-ID `de.themorpheus.morphhealth.local` |
| `artifacts/mh-linux-x64` | kompilierter Wartungsprozess (wird vom Starter `mh` genutzt) |
| `build.sh`, `check.sh`, `mh` | Build, Prüfungen, lokaler Wartungszugang |
| `docs/sample-data/morphhealth-sample-10k.json` | generierter Datenbestand (3,5 Jahre, 10.446 Tagebucheinträge) für Import- und Performanceproben |
| `docs/screenshots/` | Bildschirmfotos vom Referenzgerät |
| `docs/test-results/` | Protokoll des letzten vollständigen Prüflaufs (`./check.sh --device --online`) |

## Schnellstart

Voraussetzung ist die in `ENVIRONMENT.json` beschriebene Umgebung (Flutter 3.41.9 / Dart 3.11.5, Android SDK 36, JDK, Python 3, adb).

```bash
./build.sh                 # APK + mh-Binary nach artifacts/, SHA256SUMS
./check.sh                 # Analyse, Tests, mh-Ende-zu-Ende-Test, APK-Prüfung
./check.sh --device        # zusätzlich Integrationstests auf emulator-5560
./check.sh --online        # Online-Suche/-Abruf im mh-Test ist Pflicht (sonst übersprungen, falls der Server fehlt)

ADB=~/Android/Sdk/platform-tools/adb
$ADB -s emulator-5560 install -r artifacts/morphhealth.apk
$ADB -s emulator-5560 reverse tcp:8788 tcp:8788   # nur nötig, falls nicht schon eingerichtet
```

`build.sh` liest `food_api_base_url` und `food_api_user_agent` aus `ENVIRONMENT.json` und übergibt sie per `--dart-define` an den Build (Umgebungsvariablen `FOOD_API_BASE_URL` / `FOOD_API_USER_AGENT` haben Vorrang; ohne beides gilt `https://world.openfoodfacts.org`). Im Fachcode ist kein Server fest eingebaut. Auf dem Emulator ist `https://localhost:8788` über `adb reverse` erreichbar; das Zertifikat vertraut Android über den Systemspeicher, TLS-Prüfung bleibt aktiv.

Die APK wird mit einem lokal erzeugten Schlüssel signiert (`app/android/signing/`, Passwort in `app/android/key.properties`, beides wird beim ersten `build.sh` erzeugt). Das ist eine lokale Build-Signatur, kein Store-Schlüssel.

---

## Bedienung

Unten fünf Bereiche: **Übersicht · Ernährung · Zyklus · Gewicht · Symptome**. Oben rechts auf jeder Hauptseite: **Suche/Historie** (Lupe) und **Einstellungen** (Zahnrad).

**Erster Start.** Sprache (Deutsch/Englisch), welche Bereiche die Übersicht zeigt und ob die Online-Lebensmittelsuche erlaubt ist. Kein Konto, keine Registrierung.

**Übersicht.** Datumsnavigation (Pfeile, Tippen auf das Datum öffnet den Kalender, auch ältere Monate). Karten der gewählten Bereiche: Tagessumme mit Kalorien/Makros und freiwilligen Zielen, Wasser mit Schnellerfassung (150/250/330/500 ml, anpassbar), Koffein (40/80/120 mg, anpassbar), Zyklusstatus, letztes Gewicht, Symptome des Tages. „Übersicht anpassen“ blendet die vier Bereiche ein/aus (Daten bleiben erhalten). „Tagesdetail“ zeigt alles eines Tages zusammen.

**Ernährung – Tag.** Tagessumme, vier Mahlzeiten (Frühstück, Mittagessen, Abendessen, Snack) mit Einträgen (Menge, Uhrzeit, kcal · Protein · Kohlenhydrate · Fett), „Alle Nährwerte“ (alle 31 Nährwerte mit Abdeckungshinweis „Werte aus n von m Einträgen“ und Kennzeichnung von Schätzwerten), Wasser und zusätzliches Koffein (Einträge bearbeitbar/löschbar). Menü je Eintrag: **Erneut erfassen** (Tag, Uhrzeit, Mahlzeit wählbar) oder Löschen (mit Rückgängig). Tippen auf einen Eintrag korrigiert Menge, Einheit, Mahlzeit, Datum, Uhrzeit, Notiz.

**Lebensmittel hinzufügen.** Ein Suchfeld für Namen **oder** Barcode-Nummer:
- Name: sofortige Treffer auf dem Gerät (eigene Lebensmittel, Favoriten, zuletzt erfasste), Online-Suche in Open Food Facts per Enter/Knopf, 20 Treffer je Seite, „Weitere laden“.
- Ziffernfolge (6–14 Stellen): Produktabruf per Barcode (mit Prüfziffernhinweis bei Tippfehlern) plus eigene Lebensmittel mit diesem Barcode.
- Reiter **Favoriten**, **Zuletzt** (mit zuletzt verwendeter Menge), **Eigene** (anlegen, bearbeiten, löschen).
- Erfassen: Menge in **g, ml oder Portionen** (Schnellwahl ½/1/2 Portionen, 50–250 g/ml), Mahlzeit, Datum, Uhrzeit, Notiz, Live-Vorschau aller Nährwerte. Stern = Favorit.

**Eigene Lebensmittel.** Name, Marke, Barcode, Bezug (pro 100 g oder 100 ml), Portionsgröße und -bezeichnung, optionale Dichte, alle Nährwerte (Energie & Makros, gesättigte Fettsäuren, Zucker, Ballaststoffe, Salz, Natrium, Koffein, Vitamine A, C, D, E, K, B1, B2, B3, B5, B6, B7, B9, B12, Kalzium, Eisen, Magnesium, Kalium, Zink, Selen, Jod, Phosphor). Salz/Natrium ergänzen sich automatisch. Beim Ändern eines bereits verwendeten Lebensmittels fragt die App, ob bestehende Einträge die neuen Werte erhalten sollen.

**Ernährung – Verlauf.** Ein Nährwert (jeder der 31 Nährwerte, Wasser oder Koffein gesamt) über 7 oder 28 Tage bis zum gewählten Tag, mit Durchschnitt der erfassten Tage, Minimum, Maximum, Ziel-Linie und Tabellenansicht.

**Zyklus.** Statuskarte („Nächste Periode in etwa 4 Tagen“, „Periode · Tag 2“ …) mit Zeitraum, Verlässlichkeit und **„Wie entsteht diese Einschätzung?“** (Erklärung mit den verwendeten Zykluslängen, Median, Schwankung, Ausschlüssen). Knöpfe „Periode hat heute begonnen/heute beendet“ und „Periode nachtragen“. Ist eine Periode seit mehr als 14 Tagen offen (Ende vergessen), weist die Statuskarte darauf hin und bietet „Letzten Tag eintragen“ mit einem Vorschlag aus der eigenen typischen Periodendauer an. Monatskalender (beliebig zurückblättern): erfasste Perioden gefüllt, erwartete Periode umrandet, wahrscheinlicher Beginn schattiert, Tropfen = Blutung/Schmierblutung, Punkt = Symptome/Notiz. Tippen auf einen Tag: Blutungsstärke (keine, Schmierblutung, leicht, mittel, stark), Periode beginnen/beenden/bearbeiten, Tagesnotiz, **Symptome dieses Tages** (ansehen, erfassen), Tagesdetail. Darunter Auswertung (typischer Zyklus, typische Periodendauer, Diagramm der Zykluslängen) und die Periodenhistorie (Tippen = bearbeiten/löschen). In den Einstellungen lässt sich der Tracker als **reines Tagebuch** ohne Einschätzungen nutzen.

**Gewicht.** Einträge mit Datum, Uhrzeit, Notiz in **kg oder lb** (Eingabeeinheit je Eintrag, Anzeigeeinheit in den Einstellungen), Verlauf über 7/28/90/365 Tage oder alle, neutrale Veränderungsangabe.

**Symptome.** Frei wählbarer Name (mit Vorschlägen und bisher verwendeten Namen), Intensität 0–10, Datum, Uhrzeit, Notiz. Reiter „Verlauf“: ein Symptom auswählen, Verlauf über 7 oder 28 Tage (höchste Intensität je Tag), Anzahl, mittlere und höchste Intensität, alle Einträge dieses Symptoms.

**Historie (Lupe).** Durchsucht alle Einträge der vier Bereiche: Freitext (mehrere Wörter, z. B. „frühstück hafer“), Filter nach Bereich und Zeitraum, nach Tagen gruppiert. Tippen öffnet den passenden Editor.

**Einstellungen.** Sprache, Gewichtseinheit, Tagesziele (Kalorien, Protein, Kohlenhydrate, Fett, Wasser – alle freiwillig), Bereiche der Übersicht, Schnellerfassungswerte, Zyklus-Einschätzungen an/aus, Online-Lebensmittelsuche an/aus und Server-Adresse, **Daten exportieren (JSON)**, **Daten importieren (JSON)**, **verschlüsselte Sicherung erstellen/wiederherstellen**, **alle Daten löschen**, Datenschutz- und Lizenzhinweise.

---

## Wesentliche Entscheidungen

1. **Ein Kern für App und Wartungszugang.** Alle Fachfunktionen liegen in `app/lib/core/` (reines Dart, ohne Flutter-Abhängigkeit – von `check.sh` geprüft) hinter `MorphHealthService`. Die App und `mh` rufen dieselben Methoden auf (`nutritionDay`, `cycleForecast`, `searchFood`, `lookupBarcode`, `exportDocument`, `importDocument` …) und verwenden dasselbe verschlüsselte Speicherformat. `mh` ist damit keine zweite Implementierung.
2. **Eigener verschlüsselter Speicher statt SQLite/SQLCipher.** Datensatz im Speicher mit Tagesindizes, auf der Platte als verschlüsselter Snapshot plus verschlüsseltes Änderungsjournal (AES-256-GCM, atomares Ersetzen, Journal mit Längen-/Sequenzbindung). Gründe: identisches Format und identischer Code auf Android und im Linux-Prozess ohne native Bibliotheken; für 10.000+ Einträge schneller als nötig (siehe Tests); robuste Wiederherstellung nach Abbrüchen. Details in `SECURITY.md`.
3. **Einträge enthalten eine Kopie der Nährwerte** des Lebensmittels zum Zeitpunkt der Erfassung. Die Historie ändert sich nicht, wenn sich ein Produkt online ändert; bei eigenen Lebensmitteln entscheidet der Nutzer, ob bestehende Einträge mit aktualisiert werden.
4. **Nährwerte pro 100 g oder 100 ml, Schlüssel mit Einheit** (`vitamin_c_mg`, `vitamin_d_ug` …). Fehlende Werte sind „unbekannt“, nicht 0: Summen zeigen, aus wie vielen Einträgen sie stammen. Schätzwerte von Open Food Facts (`source: estimate`) werden gespeichert und mit „≈“/„geschätzt“ gekennzeichnet. g↔ml wird über eine optionale Dichte umgerechnet (sonst 1 g/ml mit Hinweis).
5. **Open-Food-Facts-Anbindung** nur lesend über die zwei Vertragsendpunkte mit Feldprojektion und eigenem User-Agent. Die Suche liefert das alte flache `nutriments`-Format, der v3.6-Produktabruf das neue `nutrition.aggregated_set`-Format – beide werden gelesen (Einheiten normalisiert, kJ→kcal, Salz↔Natrium). Beim Öffnen eines Suchtreffers lädt die App die vollständigen v3.6-Produktdaten nach. Anfragen nur auf ausdrückliche Aktion, 10 Minuten Zwischenspeicher, keine Produktbilder (Datensparsamkeit, offline nutzbar). Der Server ist zur Build-Zeit (aus `ENVIRONMENT.json`), zur Laufzeit (Einstellungen) und im CLI (`--food-base-url`) wählbar.
6. **Zyklus-Einschätzung** ausschließlich aus der eigenen Historie bis zum Betrachtungstag: Zykluslänge = Tage zwischen Periodenbeginnen; Werte unter 15 oder über 90 Tagen werden als wahrscheinlich fehlerhafte/fehlende Einträge ausgeschlossen und benannt; Median der letzten bis zu 6 Zyklen; Zeitraum ± max(1, ⌈Standardabweichung⌉) Tage (max. ± 10, bei nur einem Zyklus ± 3); Verlässlichkeit gut/mittel/grob; typische Periodendauer = Median der letzten abgeschlossenen Perioden. Status: vor dem Zeitraum, im Zeitraum, danach, in der Periode. Keine Eisprung-, Fruchtbarkeits- oder Verhütungsaussagen; der Hinweis steht in jeder Erklärung.
7. **Perioden sind explizite Zeiträume** (Beginn, Ende oder „dauert an“, keine Überschneidungen, nur die jüngste darf andauern). Blutungsstärke und Notizen werden je Tag erfasst – Schmierblutung auch außerhalb von Perioden. Leichte bis starke Blutung an einem Tag ohne Periode fragt nach: Periode beginnen, vorherige verlängern oder nur Blutung speichern.
8. **Zeitmodell:** lokale Kalendertage (`YYYY-MM-DD`) und optionale Uhrzeit (`HH:mm`) ohne Zeitzone – Tage verschieben sich nicht auf Reisen oder bei Sommerzeit. Zeitstempel (`created_at`/`updated_at`) sind UTC.
9. **Texte** DE/EN als typsichere Dart-Klassen im Kern (vollständig vom Compiler geprüft), damit auch `mh` die Erklärtexte der App in der eingestellten Sprache ausgibt.
10. **Kein Beschämen, keine Streaks:** Ziele sind optional, Fortschrittsbalken bleiben bei Überschreitung neutral, Gewichtsveränderungen werden sachlich ohne Bewertung angezeigt, keine Serien/Abzeichen.
11. **Barrierefreiheit:** vollständige Semantik (Kalendertage mit gesprochenem Status, Diagramme mit Zusammenfassung und Tabellenansicht), Tippflächen ≥ 48 dp, WCAG-Kontrast, keine reine Farbcodierung, Textgrößen bis 200 %, Hell/Dunkel nach Systemeinstellung. Automatisch geprüft (siehe Tests).
12. **Import ersetzt den gesamten Datenbestand** (wie `portable.import`), nach vollständiger Validierung; Zusammenführen ist bewusst nicht vorgesehen. Eine Sicherung ist der passphrasen-verschlüsselte Export und damit geräteunabhängig.

---

## Datenformate

Alle Formate sind maschinenlesbar in `./mh … describe` beschrieben (inkl. Feldtypen, Wertebereichen, Nährstoffliste und importierbarem Beispieldokument).

### `morphhealth.portable` (Version 1) – Export/Import, Inhalt von Sicherung und Speicher

JSON-Objekt:

```json
{
  "format": "morphhealth.portable", "version": 1,
  "exported_at": "2026-09-23T08:00:00.000Z", "app": {"name": "MorphHealth", "version": "1.0.0"},
  "settings": {"language": "de", "weight_unit": "kg", "overview_areas": ["nutrition","cycle","weight","symptoms"],
               "water_quick_ml": [150,250,330,500], "caffeine_quick_mg": [40,80,120],
               "cycle_predictions": true, "online_food_search": true,
               "goals": {"energy_kcal": 2000, "protein_g": null, "carbohydrates_g": null, "fat_g": null, "water_ml": 2000}},
  "foods": [...], "food_entries": [...], "water_entries": [...], "caffeine_entries": [...],
  "periods": [...], "cycle_days": [...], "weight_entries": [...], "symptom_entries": [...]
}
```

| Sammlung | Felder (Pflicht **fett**) |
|---|---|
| `foods` | `id`, `source` (`custom`/`open_food_facts`), **`name`**, `brand`, `barcode`, `basis` (`g`/`ml`), `serving_size`, `serving_label`, `density_g_per_ml`, `nutrients` {Schlüssel: Wert pro 100}, `estimated_nutrients` [Schlüssel], `favorite` |
| `food_entries` | `id`, **`date`**, `time`, **`meal`** (`breakfast`/`lunch`/`dinner`/`snack`), **`amount`**, **`unit`** (`g`/`ml`/`portion`), **`food`** (wie `foods` plus `ref`), `note` |
| `water_entries` | `id`, **`date`**, `time`, **`amount_ml`** |
| `caffeine_entries` | `id`, **`date`**, `time`, **`amount_mg`**, `label` |
| `periods` | `id`, **`start`**, `end` (null = dauert an), `note` |
| `cycle_days` | `id`, **`date`**, `flow` (`spotting`/`light`/`medium`/`heavy`), `note` – je Datum höchstens ein Eintrag |
| `weight_entries` | `id`, **`date`**, `time`, **`value`**, **`unit`** (`kg`/`lb`), `note` |
| `symptom_entries` | `id`, **`date`**, `time`, **`name`**, **`intensity`** (0–10), `note` |

Alle Datensätze haben optional `created_at`/`updated_at` (RFC 3339). Fehlende `id`s werden beim Import erzeugt, unbekannte Felder mit Warnung ignoriert, jeder Fehler (mit JSON-Pfad) verhindert den gesamten Import.

**Nährstoffschlüssel:** `energy_kcal`, `protein_g`, `carbohydrates_g`, `fat_g`, `saturated_fat_g`, `sugars_g`, `fiber_g`, `salt_g`, `sodium_mg`, `caffeine_mg`, `vitamin_a_ug`, `vitamin_c_mg`, `vitamin_d_ug`, `vitamin_e_mg`, `vitamin_k_ug`, `vitamin_b1_mg`, `vitamin_b2_mg`, `vitamin_b3_mg`, `vitamin_b5_mg`, `vitamin_b6_mg`, `vitamin_b7_ug`, `vitamin_b9_ug`, `vitamin_b12_ug`, `calcium_mg`, `iron_mg`, `magnesium_mg`, `potassium_mg`, `zinc_mg`, `selenium_ug`, `iodine_ug`, `phosphorus_mg`.

**Berechnung:** Menge in Bezugseinheit = `amount` (gleiche Einheit) · `amount × serving_size` (Portion) · `amount × Dichte` (ml→g) · `amount ÷ Dichte` (g→ml); Nährwert = Wert pro 100 × Menge ÷ 100.

### `morphhealth.backup` (Version 1) – verschlüsselte Sicherung (`*.mhbackup`)

JSON mit `kdf` (Argon2id, 64 MiB, 3 Durchläufe, Salz), `cipher` (AES-256-GCM) und `payload` = Base64(Nonce ‖ Chiffrat ‖ Tag) über gzip(portable-Dokument). Aufbau und Begründung in `SECURITY.md`.

### `morphhealth.store` (Version 1) – lokaler Speicher

Verzeichnis mit `morphhealth.snapshot`, `morphhealth.journal`, `morphhealth.lock`. Beschreibung in `SECURITY.md`.

---

## Wartungszugang `mh`

```text
./mh --data-dir ABS --key-file ABS [--now RFC3339] [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]
```

- **`--data-dir`**: absoluter Pfad des persistenten Arbeitsdatenbestands (wird angelegt). Gleiches Format wie auf dem Gerät.
- **`--key-file`**: absoluter Pfad einer Datei mit genau **32 rohen Bytes**, außerhalb des Datenverzeichnisses (sonst Abbruch). Der Inhalt ist der Hauptschlüssel; daraus wird per HKDF-SHA256 der AES-256-GCM-Schlüssel des Speichers abgeleitet. Ein neues Datenverzeichnis wird an den zuerst verwendeten Schlüssel gebunden; ein anderer Schlüssel führt zu `store_wrong_key`. Erzeugen: `head -c 32 /dev/urandom > /sicherer/ort/key.bin && chmod 600 /sicherer/ort/key.bin`. Ohne diese Datei sind die Daten nicht lesbar.
- **`--now`**: RFC-3339-Zeitpunkt, der als (eingefrorene) fachliche Uhr dient; der lokale Kalendertag ergibt sich aus dem angegebenen UTC-Versatz. Ohne Option: Systemuhr.
- **`--food-base-url` / `--food-user-agent`**: HTTPS-Origin und User-Agent für Open Food Facts. Fehlen sie, setzt der Starter `mh` die Werte aus `ENVIRONMENT.json`.
- Der Starter kompiliert `artifacts/mh-linux-x64` bei Bedarf neu (Meldungen nur auf stderr) und setzt `umask 077`.

Protokoll: je Zeile eine JSON-Anfrage mit `request_id` (beliebiger JSON-Wert, unverändert zurückgegeben) und `op`; je Anfrage genau eine Antwortzeile `{"request_id", "ok", "data" | "error": {"code", "message", "details"?}}`, sofort geflusht. stdout enthält nichts anderes. EOF beendet den Prozess.

| `op` | Eingabe | `data` |
|---|---|---|
| `describe` | – | Protokoll, Aufruf, Uhr, Speicherstatus, Operationen, Fehlercodes, Formate (portable, backup, store), Nährstoffliste, `example_document` |
| `portable.export` | `ack_plaintext: true` | vollständiges `morphhealth.portable`-Dokument |
| `portable.import` | `document`, `confirm_replace: true` | Bericht: `previous_counts`, `imported_counts`, `diary_entries`, `generated_ids`, `warnings` |
| `nutrition.day` | `date` | `totals` (alle 31 Nährwerte, `null` = unbekannt), `totals_detail` (Einheit, Anzahl Einträge mit Wert, Schätzwerte), `meals`, `entries` (je Eintrag Menge, Nährwerte), `water`, `caffeine` (aus Lebensmitteln, zusätzlich, gesamt), `goals`, `goal_progress` |
| `cycle.forecast` | `on` | `status`, `cycle_day`, `current_period`, `next_period` (erwarteter Beginn, Zeitraum, Tage bis Beginn/nach Zeitraum, erwartete Dauer), `upcoming_periods`, `confidence`, `basis` (Methode, verwendete/ausgeschlossene Zyklen, Median, Mittelwert, SD …), `summary` und `explanation` (Texte der App), `disclaimer`. Nur Perioden mit Beginn ≤ `on` zählen. |
| `food.search` | `q`, `page` (Standard 1) | `local_results` (Seite 1), `online` (`count`, `page_count`, `has_more`, `products` mit Nährwerten pro 100) |
| `food.lookup` | `barcode` | `found`, `product` (v3.6-Produkt, normalisiert) oder `null`, `local_matches`, `check_digit_valid` |

Beispiel:

```bash
head -c 32 /dev/urandom > /tmp/mh-key.bin
printf '%s\n' \
  '{"request_id":1,"op":"describe"}' \
  '{"request_id":2,"op":"cycle.forecast","on":"2026-09-23"}' \
  | ./mh --data-dir /tmp/mh-data --key-file /tmp/mh-key.bin --now 2026-09-23T10:00:00+02:00
```

Fehlercodes u. a.: `invalid_json`, `invalid_request`, `unknown_op`, `invalid_parameter`, `confirmation_required`, `validation_failed` (mit Liste `{path, message}`), `invalid_barcode`, `network_error`, `network_timeout`, `tls_error`, `rate_limited`, `upstream_http_error`, `upstream_invalid_response`, `store_wrong_key`, `store_corrupted`, `store_locked`, `internal_error`. Ein nicht erreichbarer Lebensmittelserver ist ein Fehler (`ok: false`); „nicht gefunden“ ist ein Ergebnis (`found: false`).

---

## Tests (tatsächlich ausgeführt, 23.09.2026)

Protokoll des letzten vollständigen Laufs von `./check.sh --device --online` (Ergebnis „All checks passed.“, Exit-Code 0): [`docs/test-results/check-device-2026-09-23.log`](docs/test-results/check-device-2026-09-23.log).

- **`flutter analyze`**: keine Befunde.
- **`flutter test`**: 82 Tests, alle bestanden (≈ 10 s):
  - Kern: Datum/Zeit/Uhr, **Krypto gegen Testvektoren** (HKDF RFC 5869, AES-GCM NIST SP 800-38D, Argon2id RFC 9106), Speicher (Verschlüsselung ohne Klartext, falscher Schlüssel, beschädigter Snapshot, abgeschnittener und manipulierter Journal-Eintrag, automatische Verdichtung, Sperre gegen zweiten Prozess, Ablehnung ungültiger Datensätze), portable Format (Rundlauf, Validierung mit Pfaden, erzeugte IDs), Sicherung (Rundlauf, falsche Passphrase, manipulierte Parameter, Übernahme in frischen Speicher mit anderem Geräteschlüssel), Nährwertberechnung (g/ml/Portion, Abdeckung, Koffein, Verläufe, erneut erfassen, Aktualisierung eigener Lebensmittel, Favoriten), Zyklus-Einschätzung (10 Szenarien), Perioden-Validierung, Symptome, Gewicht, Historie, OFF-Parser mit echten Antworten des bereitgestellten Servers, HTTP-Fehlerabbildung, Wartungsprotokoll (alle Operationen, Fehlerfälle).
  - **Performance** (Host, JIT, letzter Lauf): 10.446 Tagebucheinträge – Import 208 ms, Öffnen 134 ms, Tagesauswertung 4 ms, Historien-Index 110 ms, Filter 2 ms, Export 51 ms, Eintrag speichern 4 ms.
  - **Oberfläche**: alle 13 Bildschirme in DE und EN mit 100/130/200 % Schriftgröße ohne Layoutfehler (echte Roboto-Metrik, 1080 × 2400 px @ 420 dpi); **Android-Barrierefreiheitsrichtlinien** (Tippflächen ≥ 48 dp, beschriftete Ziele, WCAG-Kontrast) auf allen Bildschirmen in beiden Sprachen; Abläufe (Einführung, Wasser + Rückgängig, Sprachwechsel, Bereiche ausblenden, Eintrag korrigieren, vergessenes Periodenende bei 100 und 200 % Schrift).
- **`./check.sh`**: zusätzlich Ende-zu-Ende-Test des echten `./mh`-Prozesses (Import, `nutrition.day` = 578,9 kcal, Prognose, Export, Bestätigungspflicht, Online-Suche/-Abruf gegen den bereitgestellten Server) und APK-Prüfung (Package-ID, x86_64, Signatur).
- **Integrationstests auf emulator-5560** (`./check.sh --device`, Debug-Build): Einführung, Wasser, Online-Suche und Erfassung, Barcode-Abruf, Periodenbeginn, Historie, **keine Klartextdaten in den Gerätedateien**, Wiederöffnen mit Keystore-Schlüssel – bestanden. Gerätemessung mit 10.446 Einträgen (mehrere Läufe): Import 241–369 ms, Öffnen 207–273 ms, Journal-Schreiben 1–4 ms, Historien-Index 72–141 ms, Filter 2–3 ms.
- **Manuell auf dem Referenzgerät (Release-APK)** per adb/uiautomator geprüft: Einführung und Sprachwahl, Online-Suche „nutella“ (104 Treffer), Barcode 4000417025005 inkl. v3.6-Mikronährstoffe mit Schätzkennzeichnung, Erfassen/Korrigieren/erneut Erfassen/Löschen mit Rückgängig, eigenes Lebensmittel mit Portion, Favoriten, Wasser, Periode per Kalendertag und nachgetragene Periode, Erklärtext, Gewicht in kg und lb, Symptom mit Verlauf, Historie mit Text- und Bereichsfilter, Sprachwechsel, Export und Import über die Android-Dokumentauswahl, Sicherung, Wiederherstellung mit falscher und richtiger Passphrase, **Deinstallation → Neuinstallation → Wiederherstellung** (alle Daten und Einstellungen wieder da), alle Daten löschen, Import des 10k-Datenbestands (≈ 2 s inkl. Bedienung) und flüssige Nutzung von Verlauf, Kalender und Historie, Dunkelmodus.

## Bekannte Grenzen

- **Kein App-Sperrbildschirm** (PIN/Biometrie) und kein Bildschirmfoto-Schutz; die Daten sind auf dem Gerät verschlüsselt, während der Nutzung aber entsperrt im Arbeitsspeicher.
- Geht der Android-Keystore-Schlüssel verloren (z. B. Zurücksetzen des Geräts, gerätegebundene Übertragung), sind lokale Daten nicht mehr lesbar – dafür gibt es die verschlüsselte Sicherung. Android-Systembackups sind absichtlich ausgeschlossen.
- **Mikronährstoffe** sind bei Open Food Facts oft unvollständig oder nur geschätzt; die App zeigt das transparent, kann es aber nicht ausgleichen. Die Online-Suche braucht eine Verbindung und unterliegt den Ratenlimits des Servers; Produktbilder werden bewusst nicht geladen.
- Eine Portionsdefinition je Lebensmittel; g↔ml ohne hinterlegte Dichte mit 1 g/ml.
- Ziele gelten für alle Tage (keine zeitliche Historie von Zieländerungen). Als Lebensmittel erfasste Getränke zählen nicht automatisch zum Wasser.
- Import ersetzt immer den gesamten Bestand (kein Zusammenführen).
- Zyklus-Einschätzung ist eine einfache, erklärbare Statistik (keine Berücksichtigung von Symptomen, Lebensumständen o. Ä.) und braucht mindestens zwei erfasste Periodenbeginne.
- Screenreader-Bedienung wurde über Semantik-Tests, Richtlinienprüfungen und den Accessibility-Baum (uiautomator) geprüft, nicht mit einer menschlichen TalkBack-Sitzung.
- Die Release-Signatur ist ein lokal erzeugter Schlüssel (nicht für Store-Veröffentlichung, die ohnehin nicht Teil des Auftrags ist). Die APK enthält drei ABIs (≈ 54 MB).
- `mh`: eingefrorene Uhr bei `--now`; ein Prozess pro Datenverzeichnis (Dateisperre).
