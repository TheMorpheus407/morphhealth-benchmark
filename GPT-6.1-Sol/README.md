# MorphHealth

Benutzbare lokale Android-App für Ernährung, Perioden, Gewicht und Symptome, umgesetzt in Flutter für **MH-PERSONAL-3 / SPEC.md**. Die Installation braucht kein Konto. Deutsch ist voreingestellt; die eigene Oberfläche lässt sich vollständig auf Englisch umstellen.

## Abgabe und Start

- [Release-APK](artifacts/morphhealth.apk), Package-ID `de.themorpheus.morphhealth.local`, native ABIs `x86_64` und `arm64-v8a`, Android ab API 26.
- [Flutter-Quellen](app/lib/main.dart) mit [gesperrten Abhängigkeiten](app/pubspec.lock).
- `./build.sh` baut APK und Linux-Wartungsprogramm; `./check.sh` prüft Formatierung, Analyse, Tests, API und Wartungszugang.
- `./mh` ist der JSON-Lines-Starter.
- [Datenvertrag](docs/FORMAT.md), [Sicherheitskonzept](SECURITY.md) und [Screenshots](artifacts/screenshots/).

Alle Befehle vom Abgabeordner aus:

```bash
./build.sh
./check.sh
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 reverse tcp:8788 tcp:8788
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 install -r artifacts/morphhealth.apk
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 shell am start \
  -n de.themorpheus.morphhealth.local/.MainActivity
```

`ENVIRONMENT.json` wird ausschließlich gelesen. Build und Starter übernehmen daraus den Lebensmittel-Origin und User-Agent. Insbesondere benötigt diese Abgabe `adb reverse` für den bereitgestellten Origin `https://localhost:8788`. Persönliche Funktionen, gespeicherte Lebensmittel und Favoriten funktionieren ohne diese Verbindung.

Die installierte Flutter-/Dart-Toolchain, Android-SDK und JDK aus dem Manifest werden verwendet. Pub-, Gradle- und Flutter-Konfigurationsdateien liegen im Abgabeordner unter `.cache/`. Die lokal erzeugte Release-Signatur liegt in `.signing/`; diese Dateien behalten, um nachfolgende APKs als Update derselben Installation einzuspielen. Die private Signatur und ihre Passphrase gehören nicht in ein öffentliches Repository.

Eine reguläre Installation verwendet `https://world.openfoodfacts.org`. Das gemeinsame `FoodApi` erhält Origin und User-Agent als Konstruktorparameter. Android übernimmt `FOOD_BASE_URL` und `FOOD_USER_AGENT` aus Dart-Defines, Linux aus den Startoptionen. Ein anderer Origin desselben HTTPS-Vertrags erfordert keine Änderung an der Fachlogik. In dieser Umgebung wurde ausschließlich der bereitgestellte Lebensmittel-Origin verwendet.

## Bedienung

Die Übersicht und das gemeinsame Tagesdetail verwenden dasselbe gewählte Datum. Pfeile wechseln den Tag; die Datumsfläche öffnet den Kalender. „Heute“ führt zurück zum aktuellen Tag. Der Button „Erfassen“ in der Übersicht bietet direkten Zugriff auf die wiederkehrenden Erfassungen.

**Ernährung:** „Lebensmittel erfassen“ öffnet lokale Lebensmittel, Favoriten, zuletzt verwendete Lebensmittel und die Online-Suche. Die Online-Anbindung ist anfangs ausgeschaltet und lässt sich dort oder in den Einstellungen aktivieren. Gesendet werden Suchtext beziehungsweise Barcode, keine Tagebucheinträge. Namenssuche bietet Folgeseiten; die Barcode-Suche benutzt eine eingegebene Nummer, ohne Kamera.

Ein eigenes Lebensmittel enthält Nährwerte pro 100 g oder 100 ml. Leere Felder bleiben unbekannt, 0 ist ein tatsächlicher Nullwert. „Alle Vitamine und Mineralstoffe“ öffnet die vollständigen 21 Mikronährstofffelder. Eigene Lebensmittel sind bearbeitbar und löschbar. Vorhandene Verzehre bewahren ihren damaligen Lebensmittel-Snapshot; eine Änderung eines Lebensmittels gilt für neue Erfassungen.

Ein Verzehr enthält Menge, Einheit, Datum, Uhrzeit, Mahlzeit und optional eine Notiz. Gramm, Milliliter und Portionen sind verwendbar. Eine Portion benötigt ihre Größe in der Nährwert-Basiseinheit. Für g ↔ ml benötigt die App eine selbst angegebene Dichte in g/ml; sie unterstellt keine Dichte. Die Vorschau zeigt die Werte für die tatsächliche Menge. Tagesansicht und Eintragsansicht enthalten Energie, Makros und alle zusätzlichen Nährstoffe. Fehlende Angaben werden angezeigt und unvollständige Tagessummen gekennzeichnet.

Die Eintragsaktionen bieten Bearbeiten, Löschen und „Erneut erfassen“. Die Plus-Buttons an einer Mahlzeit übernehmen deren Zuordnung. Wasser hat Schnellmengen von 150, 250 und 500 ml, eine freie Menge und eine Rückgängig-Aktion. Zusätzliches Koffein wird in mg erfasst und mit Lebensmittel-Koffein summiert. Wasser und Koffein sind Teil des Ernährungstagebuchs.

**Zyklus:** Perioden können mit Beginn, einschließlich zählendem Ende beziehungsweise „läuft noch“, Blutungsstärke und Notiz erfasst werden. Bestehende Perioden lassen sich korrigieren und löschen. Separate Tagesaufzeichnungen können die Stärke einer Periode an einem Tag überschreiben, einschließlich keiner Blutung und Spotting. Sie erzeugen keinen zusätzlichen Periodenbeginn. Überschneidende Perioden werden vor dem Speichern zurückgewiesen.

Der Monatskalender unterscheidet aufgezeichnete Blutung, das persönliche Planungsfenster und Symptomtage. Monatsnavigation funktioniert auch für alte Monate. Der gewählte Tag zeigt Blutung und Symptome mit direkter Erfassung und Bearbeitung. Darunter liegt die bearbeitbare Periodenhistorie.

Eine laufende Periode wird nur bis zum heutigen Tag als aufgezeichnete Blutung angezeigt. Ihr Ende bleibt offen; die App trägt keine künftigen Blutungstage vorab ein.

Die persönliche Einschätzung verwendet den Median der letzten bis zu sechs beobachteten Startabstände, ohne zukünftige oder reine Spotting-Perioden. Das Fenster hat beidseitig `max(2, ceil(1,5 × MAD))` Tage; MAD ist die mediane absolute Abweichung. Es ist ein Planungskorridor ohne garantierte Wahrscheinlichkeit. Die letzten abgeschlossenen Blutungsdauern bestimmen die geschätzte Dauer. Ohne zwei aufgezeichnete Beginne erscheint kein erfundenes Startdatum. Vergangene Fenster werden nicht durch imaginierte Zyklen weitergeschoben. Die Erklärung zeigt Stichprobe, Median, beobachtete Spanne und Einschränkungen. „Persönliche Zykluseinschätzung“ lässt sich für reinen Tagebuchmodus ausschalten.

**Gewicht und Symptome:** Gewicht wird intern in kg gespeichert; kg und lb sind zur Eingabe und Anzeige verfügbar. Die Umrechnung verwendet exakt `1 lb = 0,45359237 kg`. Symptome haben einen frei gewählten Namen, eine ganzzahlige Intensität 0–10, Datum, Uhrzeit und optionale Notiz. Beide Arten lassen sich hinzufügen, bearbeiten und löschen.

**Historie und Verläufe:** Freitext, ein inklusiver Datumsbereich und die vier Bereiche sind kombinierbare Filter. Perioden werden bei zeitlicher Überlappung gefunden. Treffer öffnen den tatsächlichen Editor. Die Liste baut nur sichtbare Einträge auf. Tagesdetails führen alle Bereiche zusammen, unabhängig von ausgeblendeten Übersichtskarten. Verläufe zeigen einen Tag, sieben oder 28 Tage bis zum gewählten Datum. Für Ernährung sind sämtliche Nährstoffe sowie Wasser auswählbar; Gewicht zeigt das Tagesmittel, Symptome die höchste tägliche Intensität des gewählten Namens, Zyklus die dokumentierte Stärke. Lücken bleiben sichtbar. Die Tagesliste unter dem Diagramm bietet konkrete Werte und öffnet das Tagesdetail.

**Einstellungen:** Sprache, Gewichtseinheit, vier Übersichtskarten, freiwillige Ziele für Wasser/Energie/Protein/Kohlenhydrate/Fett, Online-Anbindung und Tagebuchmodus sind unabhängig einstellbar. Ausblenden löscht keine Einträge. Ziele sind anfangs leer.

**Datenverwaltung:** JSON-Export enthält den gesamten Bestand und die Einstellungen im dokumentierten maschinenlesbaren Format. Die App weist auf Klartext hin. JSON-Import zeigt die validierten Eintragszahlen und ersetzt nach Bestätigung den Bestand. Eine verschlüsselte Sicherung enthält denselben vollständigen Bestand, geschützt durch eine eigene Passphrase mit mindestens zehn Zeichen. Auf einem neuen Gerät dieselbe APK installieren, „Sicherung wiederherstellen“, Datei und Passphrase angeben und den Ersatz bestätigen. Der Android-Dateidialog bestimmt den Speicherort; Standardendung ist `.mhbackup.json`. Datei und Passphrase getrennt aufbewahren. Auch alle lokalen Daten lassen sich über die Oberfläche löschen.

## Wartungszugang

Der Linux-Prozess benutzt **dieselben** Dateien unter `app/lib/core/` wie Android: Datenvalidierung, Ernährung, Zyklus, Lebensmittelanbindung und Verschlüsselung. Er bindet keinen Port und startet keinen Dienst.

```bash
mkdir -p artifacts/my-maintenance-data
python3 - <<'PY'
import os, pathlib
p = pathlib.Path('artifacts/my-maintenance-key.raw')
p.write_bytes(os.urandom(32))
os.chmod(p, 0o600)
PY
./mh --data-dir "$PWD/artifacts/my-maintenance-data" \
  --key-file "$PWD/artifacts/my-maintenance-key.raw" \
  --now 2026-09-20T12:00:00+02:00
```

Die Schlüsseldatei enthält **32 rohe Bytes**, kein Hex/Base64 und keine Passphrase. Sie liegt außerhalb von `data-dir` und wird weder ausgegeben noch in diesem Verzeichnis gespeichert. Schlüssel und Verzeichnis dauerhaft aufbewahren; mit einem anderen Schlüssel lässt sich derselbe Bestand nicht öffnen. Das Beispiel erzeugt einen neuen Schlüssel und ist deshalb nur für einen neuen Datenbestand geeignet. Ein exklusiver Prozess-Lock verhindert gleichzeitige Schreiber.

Anfragen sind UTF-8-JSON, eine Zeile pro Anfrage. Beispiel:

```json
{"request_id":"contract","op":"describe"}
{"request_id":"export","op":"portable.export","ack_plaintext":true}
{"request_id":"day","op":"nutrition.day","date":"2026-09-20"}
{"request_id":"cycle","op":"cycle.forecast","on":"2026-09-20"}
{"request_id":"search","op":"food.search","q":"milch","page":1}
{"request_id":"barcode","op":"food.lookup","barcode":"5411188112709"}
```

`describe` enthält `example_document`, das direkt als `document` in `portable.import` mit `confirm_replace:true` verwendet werden kann. Jede Antwort enthält unveränderte `request_id`, `ok` und `data` oder `error`. Sie wird sofort geflusht. Fehler einer Anfrage beenden den Prozess nicht; EOF beendet ihn. Startfehler gehen auf stderr mit Exitstatus 2. Ohne `--now` gilt die Systemuhr; mit der Option gelten die angegebenen lokalen Kalender-/Uhrzeitfelder. `--food-base-url HTTPS_ORIGIN` und `--food-user-agent STRING` überschreiben die Manifestwerte. Vollständige Feldnamen, Typen und Beispiele stehen in [FORMAT.md](docs/FORMAT.md).

## Entscheidungen und Prüfungen

Es gibt einen gemeinsamen Dart-Kern, eine native Flutter-Oberfläche und einen kleinen Kotlin-Zugang für Android Keystore und Storage Access Framework. Allgemeine Bibliotheken sind exakt gesperrt: `cryptography 2.9.0`, `intl 0.20.2` und SDK-Lokalisierungen; die gesamte Abhängigkeitsauflösung steht im Lockfile. Bilder, Telemetrie, Werbung, Konten und Laufzeit-KI werden nicht eingebunden.

Der persistente Bestand ist ein authentifiziert verschlüsselter Snapshot. Tagesindizes und ein kleiner Cache beschleunigen wiederholte Abfragen; die Historie rendert sichtbar benötigte Zeilen. Speichern erfolgt seriell und atomar über eine ausschließlich verschlüsselte temporäre Datei. Datensicherung und große Verschlüsselungsarbeiten laufen außerhalb des Flutter-UI-Isolates.

Tatsächlich ausgeführt:

- Release-Build und Installation/Start auf dem AOSP-Referenzgerät API 35 / x86_64.
- `flutter analyze` ohne Befund; Formatierungsprüfung und 14 bestandene Fach-/Widgettests, einschließlich vollständiger Nährstoffe, Menge/Einheiten, Snapshots, Importvalidierung, Forecast, Verschlüsselung, Manipulation/falschem Schlüssel, Sicherung auf neuem Schlüssel, Oberfläche und vergrößerter Schrift.
- JSONL-Ende-zu-Ende-Prüfung einschließlich echter HTTPS-Namenssuche, Folgeseite und v3.6-Barcodeabruf, Fehlerantworten, Neustart und 10.000 Einträgen.
- 17 bestandene Android-Abläufe: echter Dateidialog, Korrekturen in allen Bereichen, Wasser/Koffein, echte Namens- und Barcodesuche, Favorit, Backup und Wiederherstellung nach `pm clear` mit neuem Geräteschlüssel, vollständiger Export, Neustart, 10.000 Einträge, englische Oberfläche, Schriftgröße 170 % und vollständiges Löschen. Der vorher geänderte Verzehr kam als 2 Portionen / 296 kcal zurück.
- Die endgültige APK wurde erneut installiert und gestartet. Eine zusätzliche Geräteprüfung bestätigt die persönliche Einschätzung, die Darstellung laufender Perioden ohne erfundene Zukunftsblutung und präzise Achsenbeschriftungen bei kleinen Wertunterschieden. Anschließend wurden die synthetischen Daten gelöscht.
- Zwei gleichzeitige Wartungsprozesse geprüft: Der zweite Schreiber wird mit Exitstatus 2 ohne stdout abgelehnt; EOF beendet den ersten regulär.

Die Ergebnisdateien sind [check.log](artifacts/check.log), [build.log](artifacts/build.log), [CLI-Messungen](artifacts/cli-tests.json), [Geräteprüfung](artifacts/device-tests.json), [abschließende Geräteprüfung](artifacts/chart-device-check.log), [Prozesslock](artifacts/cli-lock-test.json) und [APK-Identität](artifacts/apk-identity.json). Die umfassende Geräteprüfung ist mit `./check.sh --device` wiederholbar: **Sie setzt ausschließlich das Testpaket auf emulator-5560 zurück und verwendet synthetische Daten.** Sie benötigt die gestartete Referenzumgebung und erzeugt Screenshots sowie den Gerätebericht. Die zusätzliche Darstellungskontrolle lässt sich danach mit `python3 scripts/check_chart.py` wiederholen.

Beim zuletzt abgeschlossenen Host-Test: Import von 10.000 Einträgen etwa 0,67 s, 28 Tagesabfragen zusammen 0,004 s, vollständiger Export etwa 0,13 s; verschlüsselter Bestand rund 10,36 MB. Exakte Messungen stehen im JSON-Bericht. Der Android-Import benötigte einschließlich adb/UI-Automator-Wartezeiten etwa 5,2 s; der gemessene PSS beim geladenen 10.000-Einträge-Verlauf lag bei rund 183 MiB, siehe [Speicherbericht](artifacts/android-memory.txt).

## Tatsächliche Grenzen

Die Zyklusplanung hängt vollständig von der eingegebenen Historie ab. Unvollständige oder stark wechselnde Abstände verringern ihren Nutzen. Sie ist keine Diagnose, Eisprungberechnung oder Verhütungsmethode.

Open Food Facts kann unbekannte, fehlerhafte, geschätzte oder mit Vergleichszeichen versehene Nährwerte liefern. Qualifizierte Werte werden als numerischer Quellenwert verwendet und gekennzeichnet; sie sind keine exakten Messungen. Kein Produktfoto und kein Kamerascanner werden geladen. Einheiten werden nicht anhand des Produktnamens geraten.

Die App schützt gespeicherte Dateien. Auf einem entsperrten Gerät kann man das Tagebuch öffnen; es gibt keine zusätzliche App-PIN oder Biometriesperre. Ein Klartextexport ist bewusst unverschlüsselt. Geht die Passphrase einer Sicherung verloren, kann sie nicht zurückgesetzt werden. Details und Bedrohungsgrenzen stehen in [SECURITY.md](SECURITY.md).

Schreibvorgänge ersetzen den vollständigen verschlüsselten Snapshot. Für den geforderten Bestand von 10.000 Einträgen wurde geprüft; wesentlich größere Bestände und ein physisches ARM64-Gerät wurden nicht vermessen. Die APK enthält ARM64, die grafische Referenzprüfung läuft auf x86_64. Es wird eine lokale Release-Signatur verwendet; eine Store-Veröffentlichung gehört nicht zur Abgabe.
