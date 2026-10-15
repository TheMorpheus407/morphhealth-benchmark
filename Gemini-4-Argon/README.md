# MorphHealth

MorphHealth ist eine lokal arbeitende, zweisprachige (**Deutsch / Englisch**, Standard: Deutsch) Android-Anwendung in Flutter (`de.themorpheus.morphhealth.local`) mit einem gemeinsamen Fachkern für:

1. **Ernährungstagebuch mit Open-Food-Facts-Anbindung** (einschließlich Wasser, Koffein, eigenen Lebensmitteln, Favoriten, Wiedererfassung und allen 31 Makro-/Mikronährstoffen)
2. **Persönlicher Periodentracker** (Erfassung mit Blutungsstärke inkl. Spotting, interaktiver Monatskalender, Historie und statistische Auswertung der eigenen Zyklushistorie mit transparenter Erklärung)
3. **Gewicht (`kg` / `lb`) und Symptome (`0–10`)**
4. **Gemeinsame Übersicht, 7-/28-Tage-Verläufe und durchsuchbare Historie** (ausgelegt auf bis zu 10.000 Tagebucheinträge)
5. **Lokale AES-256-GCM-Verschlüsselung, passphrasengeschützte Sicherungen (`.mhb`) sowie portabler JSON-Export/-Import**
6. **Lokaler JSON-Lines-Wartungszugang (`./mh`)** auf Basis exakt derselben produktiven Fachmodule

---

## 1. Build, Prüfung und Start

### Voraussetzungen
Die Umgebung ist in `ENVIRONMENT.json` dokumentiert (Flutter `3.41.9`, Dart `3.11.5`, Android SDK `/home/morpheus/Android/Sdk`, Referenzgerät `emulator-5560` mit Android 15 / API 35 `x86_64`).

### Gesamtes Projekt bauen (`./build.sh`)
Erzeugt sowohl das native Linux-Binary für `./mh` (`app/build/mh_cli/mh_bin`) als auch die signierte, installierbare Android-Release-APK unter `artifacts/morphhealth.apk` (inkl. `x86_64`-Unterstützung):

```bash
./build.sh
```

### Statische Analyse, Tests und Wartungszugang prüfen (`./check.sh`)
Führt `flutter analyze`, `flutter test` (Unit-, Kryptographie-, Zyklus-, 10.000-Einträge-Performance- und Widget-Tests) sowie einen End-to-End-Integrationstest von `./mh` gegen den Open-Food-Facts-Endpunkt aus:

```bash
./check.sh
```

### Installation und Start auf dem Android-Referenzgerät (`emulator-5560`)

```bash
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 install -r artifacts/morphhealth.apk
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 shell am start -n de.themorpheus.morphhealth.local/.MainActivity
```

---

## 2. Bedienung der Android-Anwendung

Die App ist in fünf Hauptreiter am unteren Bildschirmrand sowie eine globale Datums- und Sprachleiste am oberen Bildschirmrand gegliedert:

- **Kopfleiste**:
  - Tag vor/zurück (`<` / `>`), Datumsauswahl per Kalenderdialog (`YYYY-MM-DD`), Sprung auf `Heute` sowie Sprachumschalter (`DE` / `EN`).
- **Tab 1 — Übersicht (`Overview`)**:
  - Ein- und Ausblenden der vier Bereiche (`Ernährung`, `Zyklus`, `Gewicht`, `Symptome`) über Filter-Chips.
  - **Gemeinsames Tagesdetail**: Führt Kalorien, Makronährstoffe, Wasser, Koffein, Periodenstatus/Zyklustag, Gewicht und Symptome des gewählten Tages zusammen, inklusive Direktaktionen (`Lebensmittel erfassen`, `+250 ml`, `+ Koffein`, `Periode erfassen`, `Gewicht erfassen`, `Symptom erfassen`).
  - **Verläufe über 7 und 28 Tage**: Umschaltbar zwischen `7 Tage` und `28 Tage`, mit auswählbarem Nährstoffverlauf (Wasser + alle 31 Nährstoffe), Gewichtsverlauf und Symptomverlauf.
- **Tab 2 — Ernährung (`Nutrition`)**:
  - Tagesbilanz mit Hauptmakros (`Kalorien`, `Protein`, `Kohlenhydrate`, `Fett`), freiwilligen Tageszielen (`Freiwillige Tagesziele`) und aufklappbarer Gesamttabelle für **alle 31 Nährstoffe** (6 erweiterte Angaben, 13 Vitamine, 8 Mineralstoffe).
  - **Wasser & Koffein**: Schnellerfassung für häufige Wassermengen (`+150 ml`, `+250 ml`, `+330 ml`, `+500 ml`, `Eigene Menge`) sowie Koffein-Schnellerfassung (`Espresso 60 mg`, `Filterkaffee 100 mg`, `Tee 40 mg` oder frei wählbar). Alle Einträge sind nachträglich bearbeitbar und löschbar.
  - **Mahlzeiten (`Frühstück`, `Mittagessen`, `Abendessen`, `Snack`)**: Zeigt alle Verzehreinträge mit Menge in `g`, `ml` oder `Portion`, Kalorien und Makros. Jeder Eintrag lässt sich antippen (Detailansicht aller 31 Nährstoffe & Bearbeitung), per **Erneut erfassen (`Replay`)** mit einem Tippen erneut protokollieren oder löschen.
  - **Lebensmittelkatalog (`Lebensmittel erfassen`)**:
    1. *Open Food Facts*: Namenssuche (`GET /cgi/search.pl`) mit Seitennavigation und direkter Barcode-Abruf (`GET /api/v3.6/product/{barcode}.json`).
    2. *Zuletzt erfasst*: Schnelles erneutes Erfassen früherer Verzehreinträge.
    3. *Favoriten*: Mit Stern markierte Lebensmittel.
    4. *Eigenes Lebensmittel*: Anlegen, Bearbeiten und Löschen eigener Lebensmittel inklusive aller 31 Nährstoffe pro `100 g` bzw. `100 ml` und frei definierbarer Portionsgröße.
- **Tab 3 — Zyklus (`Cycle`)**:
  - **Interaktiver Monatskalender**: Navigation durch beliebige vergangene und zukünftige Monate; farbliche Kennzeichnung erfasster Periodentage nach Blutungsstärke (`Schmierblutung / Spotting`, `Leicht`, `Mittel`, `Stark`), Anzeige des erwarteten Planungsfensters und Punktmarkierung für Tage mit Symptomen.
  - **Tageskontext**: Direkt unter dem Kalender sind für den gewählten Tag sowohl die Periodenaufzeichnung als auch die **Symptome dieses Tages** einsehbar, neu erfassbar und bearbeitbar.
  - **Persönliche Zykluseinschätzung & Erklärung**: Zeigt aktuellen Zyklustag, nächsten erwarteten Periodenbeginn, Planungsfenster, gewichtete und durchschnittliche Zykluslänge, Spannweite, Streuung und eine verständliche textliche Erklärung der Berechnung. Über den Schalter `Prognose` kann der Periodentracker auch rein als Tagebuch ohne Vorhersagen genutzt werden.
- **Tab 4 — Gewicht & Symptome (`Weight & Symptoms`)**:
  - **Gewicht**: Umschaltung und Eingabe in `kg` oder `lb` (exakte Umrechnung `1 kg = 2,20462262185 lb`), Verlauf über 7 oder 28 Tage sowie Bearbeitung und Löschung.
  - **Symptome**: Frei wählbarer Symptomname (plus Schnellauswahl-Vorschläge), Intensität von `0` bis `10`, Datum/Uhrzeit und optionale Notiz. Der **Symptomverlauf** lässt sich über das Auswahlmenü gezielt nach jedem erfassten Symptom filtern.
- **Tab 5 — Historie & Daten (`History & Data`)**:
  - **Durchsuchbare Historie**: Bereichsübergreifende Suche mit Filtern nach Freitext (`Name`, `Marke`, `Notiz`, `Mahlzeit`), Datumsbereich (`Von` / `Bis`) und Bereich (`Alle`, `Ernährung`, `Zyklus`, `Gewicht`, `Symptome`). Einträge lassen sich durch Antippen direkt öffnen und bearbeiten.
  - **Daten & Einstellungen**: Sprachwahl (`Deutsch` / `English`), Gewichtseinheit (`kg` / `lb`), Online-Lebensmittelsuche ein/aus, passphrasengeschützte verschlüsselte Sicherung & Wiederherstellung (`.mhb` über Android-Dateiauswahl `com.android.documentsui` oder lokal), maschinenlesbarer JSON-Export & -Import (`morphhealth.portable.v1`), Laden eines Beispieldatensatzes, Generieren von 10.000 Einträgen zu Testzwecken sowie vollständiges Löschen aller lokalen Daten.

---

## 3. Lokaler Wartungszugang (`./mh`)

Der Wartungszugang `./mh` läuft als lokaler Linux-Prozess, nutzt exakt dieselben Dart-Fachklassen (`app/lib/src/core/`) wie die Android-App und kommuniziert über **JSON Lines** (`stdin` / `stdout`, Zeilen-Flush nach jeder Antwort, keine Banner auf `stdout`, Beendigung bei `EOF`).

### Aufruf

```bash
./mh --data-dir ABS --key-file ABS [--now RFC3339] \
     [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]
```

- `--data-dir ABS`: Absoluter Pfad zum Arbeitsdatenverzeichnis (enthält die AES-256-GCM-verschlüsselte `vault.mhv`).
- `--key-file ABS`: Absoluter Pfad zur 32-Byte-Schlüsseldatei **außerhalb** von `--data-dir` (z. B. erzeugt mit `head -c 32 /dev/urandom > /pfad/master.key`).
- `--now RFC3339`: Optionale fachliche Uhrzeit für deterministische Auswertungen (z. B. `2026-10-15T10:00:00+02:00`).
- `--food-base-url HTTPS_ORIGIN`: Optionaler Origin für Open Food Facts (Standard: `food_api_base_url` aus `ENVIRONMENT.json`).
- `--food-user-agent STRING`: Optionaler User-Agent (Standard: `food_api_user_agent` aus `ENVIRONMENT.json`).

### Anfrage- und Antwortformat

- **Anfrage**:
  ```json
  {"request_id": "1", "op": "<operation>", ...}
  ```
  *(Zusätzliche Parameter können direkt auf oberster Ebene der Anfrage oder optional in einem Objekt `"params"` übergeben werden.)*
- **Erfolgsantwort**:
  ```json
  {"request_id": "1", "ok": true, "data": { ... }}
  ```
- **Fehlerantwort**:
  ```json
  {"request_id": "1", "ok": false, "error": {"code": "<error_code>", "message": "<beschreibung>"}}
  ```

### Unterstützte Operationen (`op`)

| `op` | Parameter | Rückgabe in `data` |
|---|---|---|
| `describe` | keine | Vollständige Formatbeschreibung (`schema_version`, `nutrients`, `portable_format`, `encryption`, `operations`) sowie `example_document` (direkt für `portable.import` geeignet). |
| `portable.export` | `"ack_plaintext": true` | Vollständiger Datenexport im Format `morphhealth.portable.v1`. |
| `portable.import` | `"document": {...}, "confirm_replace": true` | Ersetzt den Arbeitsdatenbestand durch `document` und liefert `{"replaced": true, "schema_version": "morphhealth.portable.v1", "counts": {...}}`. |
| `nutrition.day` | `"date": "YYYY-MM-DD"` | Vollständige Tagesauswertung: `calories_kcal`, `water_ml`, `caffeine_mg`, `caffeine_from_food_mg`, `caffeine_from_drinks_mg`, `nutrients` (alle 31 Nährstoffe), `macros`, `extended`, `vitamins`, `minerals`, `goals`, `meals` (`breakfast`, `lunch`, `dinner`, `snack`), `food_entries`, `water_entries`, `caffeine_entries`. |
| `cycle.forecast` | `"on": "YYYY-MM-DD"` | Persönliche Zykluseinschätzung zum Stichtag `on`: `status`, `current_cycle_day`, `last_period_start`, `expected_start_date`, `expected_end_date`, `window_start_date`, `window_end_date`, `days_until_expected_start`, `confidence`, `statistics` (`average_cycle_length_days`, `weighted_cycle_length_days`, `median_cycle_length_days`, `min_cycle_length_days`, `max_cycle_length_days`, `cycle_variability_days`, `average_period_duration_days`, `cycle_lengths_history_days`) sowie `explanation` (`de` / `en`) und `disclaimer`. |
| `food.search` | `"q": "<suchbegriff>", "page": 1` | Paginierte Open-Food-Facts-Suchergebnisse (`query`, `page`, `page_size`, `total_count`, `products` mit normierten `FoodItem`-Objekten inkl. `nutrients_per_100g`). |
| `food.lookup` | `"barcode": "<code_str>"` | Normiertes Produkt vom Endpunkt `/api/v3.6/product/{barcode}.json` (Felder sowohl direkt auf oberster Ebene von `data` als auch unter `data.product`, inkl. `nutrients_per_100g`). |

---

## 4. Datenformate und Nährstoffkatalog

### 4.1 Portables Dokumentformat (`morphhealth.portable.v1`)

```json
{
  "schema_version": "morphhealth.portable.v1",
  "application": "MorphHealth",
  "exported_at": "2026-10-15T08:00:00Z",
  "settings": {
    "language": "de",
    "weight_unit": "kg",
    "online_food_search_enabled": true,
    "cycle_predictions_enabled": true,
    "visible_modules": {
      "nutrition": true,
      "cycle": true,
      "weight": true,
      "symptoms": true
    },
    "goals": {
      "water_ml": 2000.0,
      "calories_kcal": 2100.0,
      "protein_g": 90.0,
      "carbohydrates_g": 240.0,
      "fat_g": 70.0
    }
  },
  "custom_foods": [ ... ],
  "favorite_foods": [ ... ],
  "food_entries": [ ... ],
  "water_entries": [ ... ],
  "caffeine_entries": [ ... ],
  "period_entries": [ ... ],
  "weight_entries": [ ... ],
  "symptom_entries": [ ... ]
}
```

### 4.2 Alle 31 unterstützten Nährstoffe (`NutrientCatalog`)

Alle Werte in `nutrients_per_100g` beziehen sich auf `100 g` bzw. `100 ml` des Lebensmittels:

- **Hauptmakronährstoffe (4)**:
  `calories_kcal` (`kcal`), `protein_g` (`g`), `carbohydrates_g` (`g`), `fat_g` (`g`)
- **Erweiterte Angaben (6)**:
  `saturated_fat_g` (`g`), `sugars_g` (`g`), `fiber_g` (`g`), `salt_g` (`g`), `sodium_mg` (`mg`), `caffeine_mg` (`mg`)
- **Vitamine (13)**:
  `vitamin_a_ug` (`µg`), `vitamin_c_mg` (`mg`), `vitamin_d_ug` (`µg`), `vitamin_e_mg` (`mg`), `vitamin_k_ug` (`µg`), `vitamin_b1_mg` (`mg`), `vitamin_b2_mg` (`mg`), `vitamin_b3_mg` (`mg`), `vitamin_b5_mg` (`mg`), `vitamin_b6_mg` (`mg`), `vitamin_b7_ug` (`µg`), `vitamin_b9_ug` (`µg`), `vitamin_b12_ug` (`µg`)
- **Mineralstoffe (8)**:
  `calcium_mg` (`mg`), `iron_mg` (`mg`), `magnesium_mg` (`mg`), `potassium_mg` (`mg`), `zinc_mg` (`mg`), `selenium_ug` (`µg`), `iodine_ug` (`µg`), `phosphorus_mg` (`mg`)

---

## 5. Wesentliche Architekturentscheidungen

1. **Dual-Schema Open-Food-Facts-Parser (`nutrients.dart`)**:
   Die Analyse des bereitgestellten Open-Food-Facts-Endpunkts zeigte, dass `/cgi/search.pl` Nährwerte im klassischen `nutriments`-Objekt (`<key>_100g`, `<key>_unit`) liefert, während `/api/v3.6/product/{barcode}.json` (Schema 1004) Nährwerte primär unter `nutrition.aggregated_set.nutrients` und `nutrition.input_sets` ausgibt (und `nutriments` dort leer sein kann). Unser Parser wertet daher beide Schemata nahtlos aus und rechnet Einheiten (`g`, `mg`, `µg`, `kcal`, `kJ`) sowie Synonyme (`vitamin-pp` -> Vitamin B3, `pantothenic-acid` -> Vitamin B5, `biotin`/`vitamin-b8` -> Vitamin B7, `phylloquinone` -> Vitamin K, `folates` -> Vitamin B9) automatisch um.
2. **Gemeinsamer reiner Dart-Kern für Android und CLI**:
   Alle Domänenmodelle, Berechnungen (`NutritionEngine`, `CycleForecastEngine`), die Open-Food-Facts-Anbindung (`OpenFoodFactsClient`) und die AES-256-GCM-Persistenz (`CryptoVault`, `MorphHealthRepository`) sind ohne Flutter-UI-Abhängigkeit in `app/lib/src/core/` implementiert. Dadurch rufen Android-App und `./mh` identischen Produktivcode auf.
3. **Statistische Zyklusauswertung mit Ausreißerfilterung**:
   `CycleForecastEngine` berechnet aus den chronologischen Periodenstarts persönliche Zyklusintervalle, filtert unplausible Erfassungslücken (`> 90` Tage, z. B. bei pausierter Nutzung) heraus, bildet ein linear gewichtetes Mittel zugunsten jüngerer Zyklen sowie Median, Spannweite und Standardabweichung, leitet daraus das individuelle Planungsfenster ab und generiert eine vollständige zweisprachige Erklärung.
4. **Performance bei 10.000 Tagebucheinträgen**:
   Durch Datums-Indizierung (`_foodByDate`, `_waterByDate`, `_caffeineByDate`, `_weightByDate`, `_symptomsByDate`), `gzip`-Komprimierung vor der AES-256-GCM-Verschlüsselung und virtualisierte Listen (`ListView.separated`) bleiben Tagesansichten, 7-/28-Tage-Verläufe und die bereichsübergreifende Volltextsuche auch bei 10.000 Einträgen im Millisekundenbereich.

---

## 6. Durchgeführte Tests und bekannte Grenzen

### Tatsächliche Tests
- **Statische Analyse**: `flutter analyze` ohne Warnungen oder Fehler.
- **Automatisierte Tests (`flutter test`)**:
  - Prüfung aller 31 Nährstoffe, Einheitenumrechnungen und des Open-Food-Facts-Parsers (`v3.6` und `v1/v2`).
  - Prüfung der Zyklusprognose inkl. Ausreißerbehandlung und zweisprachiger Erklärung.
  - Kryptographietests für `MHV1` (AES-256-GCM) und `.mhb`-Sicherungen (PBKDF2-HMAC-SHA256 + AES-256-GCM) inklusive Manipulationserkennung.
  - Lasttest mit **10.000 Tagebucheinträgen** (Generierung, Verschlüsselung, Tagessummierung und Volltext-Historiensuche).
  - Widget-Test der kompletten Android-Oberfläche (Standard Deutsch, Sprachwechsel Deutsch/Englisch, Navigation über alle 5 Hauptbereiche).
- **Wartungszugang (`./check.sh`)**: End-to-End-Prüfung aller 7 Operationen von `./mh` gegen den lokalen Open-Food-Facts-HTTPS-Dienst (`https://localhost:8788`).
- **Geräteprüfung auf `emulator-5560`**: Bau, Installation und Laufzeitprüfung der Release-APK `artifacts/morphhealth.apk` auf dem Android-15-Referenzemulator.

### Bekannte Grenzen
- **Vollständigkeit externer Produktdaten**: Viele Produkte in Open Food Facts weisen in den Herstellerdaten nur Hauptmakronährstoffe und ausgewählte Vitamine/Mineralstoffe aus; nicht vom Hersteller gemeldete Mikronährstoffe werden mit `0` übernommen und können bei Bedarf über eigene Lebensmittel ergänzt werden.
- **Keine medizinische Zweckbestimmung**: Die Zyklusprognose basiert ausschließlich auf den selbst protokollierten Blutungsdaten und ist nicht zur Empfängnisverhütung, Eisprungberechnung oder medizinischen Diagnose bestimmt.
