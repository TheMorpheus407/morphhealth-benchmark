# MorphHealth

Lokale Android-App (Flutter): Ernährungstagebuch mit Open Food Facts,
persönlicher Periodentracker, Gewicht und Symptome. Ohne Konto, ohne
Telemetrie, ohne Werbung. Alle Gesundheitsdaten bleiben auf dem Gerät und
werden verschlüsselt abgelegt.

## Artefakte (SPEC P09)

- `app/` — Flutter-Quellen, Assets, `pubspec.lock`; Einstieg `app/lib/main.dart`
- `artifacts/morphhealth.apk` — Release-APK (x86_64), Package-ID
  `de.themorpheus.morphhealth.local`
- `build.sh`, `check.sh`, `mh` — ausfuehrbar
- `README.md`, `SECURITY.md` — dieses Dokument

## Anforderungen an den Build-Host

Flutter 3.41.9, Dart 3.11.5, Android SDK (API 35 Build-Tools), JDK 17/21,
`adb`. Konkrete Werte stehen in der schreibgeschützten `ENVIRONMENT.json`.
Referenzgerät: Android 15/API 35, x86_64, Emulator `morphhealth_ref_api35`
(adb-serial `emulator-5560`; nie den anderen Emulator benutzen).

## Bauen und Starten

```sh
# Abhaengigkeiten auflosen, APK bauen, nach artifacts/ kopieren
./build.sh

# APK auf das Referenzgeraet installieren und starten
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 install -r artifacts/morphhealth.apk
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 shell am start -n de.themorpheus.morphhealth.local/de.themorpheus.morphhealth.local.MainActivity

# Statische Analyse und Tests
./check.sh
```

Die App laesst sich auch mit `flutter run` vom Host aus starten (Emulator
muss laufen).

## Bedienung (kurz)

Die App öffnet auf der **Übersicht** (heute). Unten wechselt man zwischen
Übersicht, Ernährung, Zyklus und Gewicht. Oben rechts gelangt man in die
Einstellungen.

- **Ernährung**: Lebensmittel nach Name suchen oder per eingegebener
  Barcode-Nummer in Open Food Facts nachschlagen (lesender Vertrag P08),
  Menge in g/ml/Portionen, Mahlzeit wählen, speichern. Einträge sind
  korrigier- und löschbar (Wischen). Wasser und Koffein mit schneller
  Erfassung (250 ml, 500 ml, Koffein-Eintrag).
- **Zyklus**: Monatskalender (Blutungstage farbig), Perioden mit Beginn,
  Ende, Blutungsstärke (Spotting/leicht/mittel/stark) und Notiz. Persönliche
  Einschätzung der nächsten Periode basierend auf der eigenen Historie
  (Durchschnitt der Zykluslängen), mit Erklärung. Keine medizinische
  Diagnose, keine Eisprung- oder Verhütungsvorhersage.
- **Gewicht**: Einträge in kg oder lb, Verlauf als Kurve.
- **Symptome**: freier Name, Intensität 0–10, Datum/Uhrzeit, Notiz; erreichbar
  aus der Übersicht und dem Zykluskontext.
- **Historie**: durchsuchbar über alle Bereiche (Datum, Bereich, Freitext),
  Einträge öffnen und bearbeiten.
- **Einstellungen**: Sprache (Deutsch/English), sichtbare Bereiche,
  Tagesziele (Wasser, Kalorien, Makros), Export/Import, verschlüsselte
  Sicherung, Alle Daten löschen, Daten-Schlüssel-Info.

Alle Texte sind auf Deutsch und Englisch verfügbar (Deutsch voreingestellt).

## Lokaler Wartungszugang (P10)

`mh` ist ein Linux-Prozess, der dieselbe Core-Implementierung wie die App
nutzt:

```sh
./mh --data-dir /pfad/zum/datenbestand --key-file /pfad/zu/schluessel \
     [--now 2026-09-23T12:00:00+02:00] \
     [--food-base-url https://localhost:8788] \
     [--food-user-agent "MorphHealth/1.0-rc3 (benchmark build)"]
```

Schluesseldatei: genau 32 Rohbyte, z. B. `head -c 32 /dev/urandom > keyfile`.
Prozeß liest JSON-Requests von stdin und schreibt JSON-Antworten auf stdout
(keine Banner). Operationen: `describe`, `portable.export`,
`portable.import`, `nutrition.day`, `cycle.forecast`, `food.search`,
`food.lookup` (siehe SPEC P10).

## Datenformate

Der portablen Format (auch für `portable.export`/`portable.import`) ist
`morphhealth.v1`: ein JSON-Dokument mit den Feldern `format`,
`createdAt` und `document`. `document` enthält den vollständigen
Gesundheitsdatenbestand: `localFoods`, `cachedProducts`,
`nutritionEntries`, `waterEntries`, `caffeineEntries`, `cycleEntries`,
`symptomEntries`, `weightEntries`, `goals`, `settings`. Kalendertage sind
`YYYY-MM-DD`, Zeitstempel ISO-8601 mit Ortszeit.

Der laufende Datenbestand wird als einzelne verschlüsselte Datei
(`data.json.enc`) abgelegt: AES-256-CBC mit zufälligem IV, darüber
HMAC-SHA256 über IV||Ciphertext (JSON-Umschlag mit `iv`, `data`, `mac`,
alle Base64Url). Der 32 Byte-Schluessel wird von der App im sicheren
Schluesselspeicher des Betriebssystems verwaltet; das `mh`-CLI liest ihn aus
`--key-file`.

Nährwerte sind pro 100 g gespeichert (Energie kcal, Makros/Cellulose/Salz/
Natrium g, Koffein mg, Vitamine µg, Mineralstoffe mg). Alle Mikronährstoffe
aus dem Auftrag (Vitamine A, C, D, E, K, B1, B2, B3, B5, B6, B7, B9, B12;
Kalzium, Eisen, Magnesium, Kalium, Zink, Selen, Jod, Phosphor) werden
erfasst und angezeigt.

## Entscheidungen und Grenzen (dokumentiert, SPEC P12)

- Keine Kamera/Barcode-Scanner (Nichtumfang P11); Barcode-Nummer kann
  manuell eingegeben werden.
- Open Food Facts wird nur zum Lesen benutzt; der Origin und User-Agent
  kommen aus `ENVIRONMENT.json` (`food_api_base_url`,
  `food_api_user_agent`), nicht fest eingebaut.
- Keine externen KI-Dienste, keine Telemetrie, keine Werbung, keine Konten.
- Flüssige Mengen werden mengenmäßig 1:1 zu Gramm gewertet
  (Dokumentationsvereinfachung).
- Verschlüsselung schützt den Datenbestand im Dateisystem; der
  Daten-Schluessel der App liegt im App-Internen Schlüsselspeicher.
  Fuer den `mh`-Zugang wird eine separate Schlüsseldatei mit 32 Rohbyte
  verlangt.
- Der Periodentracker schätzt die nächste Periode ausschließlich aus der
  aufgezeichneten Historie (Durchschnitt der Zyklus- und Blutungslaengen).
  Das ist keine medizinische Diagnose, keine Verhütungs- und keine
  Eisprungvorhersage.
- Der Build produziert eine x86_64-APK (Referenzgeraet). Andere ABIs werden
  nicht gebaut.
- Getestet auf dem Referenz-Emulator (API 35, x86_64) und mittels Unit-Tests
  fuer die Core-Logik (`flutter test`).

## Tests

```sh
./check.sh   # flutter analyze + flutter test
```

Unit-Tests liegen in `app/test/core/` und decken den Datenspeicher
(Import/Export-Rundgang, Prognose, Lebensmittel, Löschen) ab.