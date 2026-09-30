# MorphHealth

MorphHealth ist eine native Flutter-App für Android: Ernährungstagebuch,
persönliches Periodentagebuch, Gewicht und Symptome in einem lokalen Datenbestand.
Deutsch ist voreingestellt; die gesamte eigene Oberfläche lässt sich in den
Einstellungen auf Englisch umstellen. Es gibt kein Konto, keine Werbung,
Telemetrie oder Laufzeit-KI. Für die persönlichen Gesundheitsdaten ist keine
Internetverbindung erforderlich.

Die installierbare Release-APK liegt unter
[artifacts/morphhealth.apk](artifacts/morphhealth.apk), die Prüfsumme unter
[artifacts/morphhealth.apk.sha256](artifacts/morphhealth.apk.sha256).
Paket-ID: `de.themorpheus.morphhealth.local`. Der Build enthält x86_64 und arm64.
Der Flutter-Einstieg ist [app/lib/main.dart](app/lib/main.dart).

## Bauen, prüfen und starten

Alle folgenden Befehle werden im Ordner dieser README ausgeführt. Die
bereitgestellte Toolchain und der Lebensmittel-Endpunkt stehen im
schreibgeschützten [ENVIRONMENT.json](ENVIRONMENT.json). Der Auftrag steht
unverändert in [SPEC.md](SPEC.md).

```bash
./build.sh
./check.sh
```

`build.sh` liest den Lebensmittel-Origin und User-Agent aus `ENVIRONMENT.json`,
erzeugt daraus `app/build-config.json`, verwendet `pubspec.lock` mit
`--enforce-lockfile` und baut die Release-APK. `check.sh` führt statische Analyse,
Flutter-Tests und anschließend die Prozess-/API-Prüfung des Wartungszugangs aus.
Der letzte Schritt benötigt den bereitgestellten HTTPS-Lebensmitteldienst;
lokale Gesundheitsfunktionen und deren Tests benötigen ihn nicht.

Installation und Start auf dem bereitgestellten Android-15-Referenzgerät:

```bash
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 reverse tcp:8788 tcp:8788
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 install -r artifacts/morphhealth.apk
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 shell am start -n de.themorpheus.morphhealth.local/.MainActivity
```

Immer den SDK-`adb` und ausdrücklich `-s emulator-5560` verwenden. Der andere
Emulator gehört nicht zu dieser Abgabe. `adb reverse` macht den in dieser
Umgebung konfigurierten Origin `https://localhost:8788` im Referenzgerät
erreichbar; nach einem Geräte-Neustart kann die Weiterleitung erneut nötig sein.
Zertifikatsprüfung und Systemvertrauen bleiben unverändert aktiviert.

Der Origin ist konfigurierbar, nicht in der Fachlogik festgeschrieben.
`build.sh` verwendet für diese Abgabe ausschließlich das Manifest. Für eine
andere Installation können beim Flutter-Build die Dart-Defines
`FOOD_API_BASE_URL` und `FOOD_API_USER_AGENT` gesetzt werden. Der normale
Produkt-Origin ist `https://world.openfoodfacts.org`; diese Abgabe und ihre
Netzwerktests verwenden den bereitgestellten Dienst.

## Bedienung

### Übersicht, Datum und persönliche Auswahl

Die Navigation unten führt zu **Übersicht**, **Ernährung**, **Zyklus**,
**Verläufe** und **Historie**. Über das Einstellungssymbol oben lassen sich die
vier Bereiche in der Übersicht unabhängig ein- oder ausblenden. Ernährung und
Zyklus können unabhängig voneinander genutzt werden.

Datumspfeile wechseln den gewählten Tag. Ein Tipp auf das Datum öffnet die
Datumsauswahl, auch für frühere Monate; **Heute** springt zurück. Der gewählte
Tag wird zwischen den Bereichen geteilt. **Gemeinsames Tagesdetail** führt die
Mahlzeiten, Wasser-/Koffeineinträge, Gewichte, Perioden und Symptome dieses Tages
zusammen. Dort lassen sich neue Einträge anlegen und bestehende zum Bearbeiten
öffnen. Das Ausblenden eines Übersichtsbereichs löscht keine Daten.

### Ernährung und Lebensmittel

1. In **Ernährung → Lebensmittel erfassen** ein Lebensmittel auswählen.
   **Meine** enthält eigene Lebensmittel, Favoriten und zuletzt erfasste
   Lebensmittel. **Suche** sucht nach Namen/Marke; **Barcode** nimmt eine
   eingegebene Nummer entgegen. Ein Kamerascanner ist nicht enthalten.
2. Die Online-Suche muss einmal ausdrücklich aktiviert werden. Sie sendet nur
   den aktiv eingegebenen Suchbegriff beziehungsweise Barcode und den
   konfigurierten User-Agent an den Lebensmitteldienst. Sie lässt sich in den
   Einstellungen wieder ausschalten.
3. Die Detailansicht zeigt alle verfügbaren Nährstoffe. Der Stern speichert
   einen Favoriten. **Dieses Lebensmittel verwenden** öffnet die Erfassung.
4. Menge, Einheit, Datum/Uhrzeit und Frühstück, Mittagessen, Abendessen oder
   Snack wählen. Bei Portionen ist die Größe einer Portion in g oder ml
   erforderlich. Die Vorschau zeigt die Nährwerte der gewählten Menge.
5. Ein Tagebucheintrag öffnet sich durch Antippen. Sein Menü bietet auch
   **Erneut erfassen**, alle Nährstoffe und Löschen. Beim erneuten Erfassen
   bleiben Menge und Lebensmittel als Vorschlag erhalten; der Zeitpunkt wird
   auf den gewählten Tag gesetzt und kann vor dem Speichern geändert werden.

**Meine Lebensmittel verwalten → Eigenes Lebensmittel anlegen** funktioniert
offline. Eigene Lebensmittel haben eine Basis von 100 g oder 100 ml und eine
optionale Portionsgröße. Neben Energie und Makronährstoffen sind gesättigte
Fettsäuren, Zucker, Ballaststoffe, Salz, Natrium, Koffein sowie alle geforderten
Vitamine und Mineralstoffe erfassbar. Die Eingabefelder nennen jeweils die
Einheit. Eigene Lebensmittel lassen sich in ihrer Detailansicht bearbeiten
oder löschen.

Die **Tagesbilanz → Alle** zeigt sämtliche Tagesnährstoffe. Ein Gedankenstrich
bedeutet unbekannt; Teilsummen können unvollständig sein. Unter **Wasser &
Koffein** erfassen die Schaltflächen direkt 150, 250 oder 500 ml Wasser.
**Eigene Menge** erlaubt eine andere Menge und einen anderen Zeitpunkt.
Zusätzliches Koffein wird in mg erfasst und mit bekannten Koffeinwerten der
Lebensmittel addiert. Wasser-/Koffeineinträge sind ebenfalls bearbeitbar und
löschbar.

Unter **Einstellungen → Freiwillige Tagesziele** lassen sich eigene Ziele für
Wasser, Kalorien, Protein, Kohlenhydrate und Fett setzen. Ein leeres Feld
entfernt das jeweilige Ziel. Es gibt keine automatisch vorgeschriebenen Ziele.

### Periodentagebuch und persönliche Einschätzung

In **Zyklus → Periode erfassen** Beginn, Ende oder **Noch nicht beendet**,
Blutungsstärke einschließlich Spotting und eine optionale Notiz wählen. Auch
vergangene Perioden lassen sich erfassen. Ende und Beginn zählen zum Zeitraum.
Nicht als Spotting markierte Perioden dürfen sich nicht überschneiden; eine
offene Periode muss vor einer späteren Periode beendet werden.

Der Monatskalender lässt sich mit den Pfeilen und über seine Monatsüberschrift
navigieren. Markierungen unterscheiden aufgezeichnete Perioden, Symptome und
das geschätzte Zeitfenster. Ein gewählter Tag zeigt seine Perioden- und
Symptomeinträge; Antippen öffnet die Bearbeitung. Neue Symptome können direkt
für diesen Tag erfasst werden. Die Periodenhistorie darunter bietet Bearbeitung
und Löschung aller aufgezeichneten Perioden.

Die persönliche Einschätzung benötigt mindestens drei Periodenbeginne mit zwei
auswertbaren Abständen. Sie erläutert die verwendete Historie, Streuung und
Unsicherheit. **Persönliche Einschätzung** ausschalten aktiviert den reinen
Tagebuchmodus; die Aufzeichnungen bleiben erhalten. Die Funktion dient der
persönlichen Dokumentation und Planung, nicht Diagnose, Eisprungberechnung,
Verhütung oder Behandlung.

### Gewicht und Symptome

**Übersicht → Gewicht → Verlauf** öffnet die Gewichtsverwaltung. Datum, Gewicht
in kg oder lb und eine optionale Notiz erfassen. Die Anzeigeeinheit kann dort
oder in den Einstellungen gewechselt werden. Intern bleiben Gewichte in kg
gespeichert. Ein Tipp auf einen Eintrag erlaubt Korrektur oder Löschung.
Notizänderungen und reine Einheitenwechsel runden den gespeicherten Messwert
nicht neu.

**Übersicht → Symptome → Verlauf** öffnet die Symptomverwaltung. Der Name ist
frei wählbar; vorhandene Namen werden bei der Erfassung angeboten. Intensität
von 0 bis 10, Datum/Uhrzeit und optionale Notiz sind bearbeitbar. Für das Diagramm
lässt sich ein bestimmtes Symptom auswählen; die Liste kann weiterhin alle
Symptome zeigen. Beide Verwaltungen bieten 7 Tage, 28 Tage und den gesamten
Verlauf. Diagramme werden durch lesbare Zahlen und Eintragslisten ergänzt.

### Verläufe und durchsuchbare Historie

**Verläufe** zeigt wahlweise 7 oder 28 Tage bis zum gewählten Tag. Zur Auswahl
stehen alle Nährstoffe, Wasser, Gewicht, eine Symptomintensität und
Blutungsstärke. **Tageswerte anzeigen** öffnet die dazugehörigen Zahlen.
Gewicht verwendet den letzten Tageswert, Symptome die höchste Intensität des
gewählten Symptoms am Tag. Fehlende Nährstoff-, Gewichts- und Symptommessungen
werden nicht als Nullmessungen eingezeichnet.

**Historie** kombiniert Freitext, Bereich und einen Von-/Bis-Datumsbereich.
Gesucht wird unter anderem in Namen, Notizen, Mahlzeiten, Marken und Barcodes.
**Weitere Einträge laden** erweitert die Ergebnisliste. Jeder Treffer öffnet
den tatsächlichen Eintrag zur Bearbeitung; Änderungen werden im gemeinsamen
Datenbestand gespeichert.

## Daten exportieren, sichern und übernehmen

Unter **Einstellungen → Daten & Sicherung** stehen vier Dateifunktionen bereit.
Alle verwenden den nativen Android-Dateidialog; Speicherort und Datei werden
vom Nutzer gewählt.

| Funktion | Inhalt und Verwendung |
|---|---|
| Verschlüsselte Sicherung erstellen | Vollständiger Datenbestand als `.mhbackup`, geschützt mit einer mindestens 10 Zeichen langen, bestätigten Passphrase. |
| Sicherung wiederherstellen | Passphrase eingeben, Sicherungsdatei wählen und den vollständigen Ersatz der lokalen Daten bestätigen. |
| Vollständiger JSON-Export | Maschinenlesbares, unverschlüsseltes Dokument nach ausdrücklicher Bestätigung. Enthält auch Notizen und Einstellungen. |
| JSON-Import | Ein Dokument im MorphHealth-Format wählen und den vollständigen Ersatz bestätigen. Ungültige Daten werden vor dem Schreiben abgewiesen. |

Für einen Gerätewechsel die verschlüsselte Sicherung auf einen erreichbaren
Speicherort übertragen, MorphHealth frisch installieren und dort **Sicherung
wiederherstellen** verwenden. Die ursprüngliche Installation und ihr
Geräteschlüssel werden dafür nicht benötigt; erforderlich sind Sicherungsdatei
und Passphrase. Ein Import ist ein vollständiger Ersatz, kein Zusammenführen.
Ungültige Daten oder eine falsche Passphrase verändern den bisherigen Bestand
nicht.

**Alle lokalen Daten löschen** entfernt nach Bestätigung Einträge,
Lebensmittel, Favoriten und Einstellungen aus dem aktiven lokalen Datenbestand.
Exportierte Dateien bleiben an ihrem gewählten Speicherort. Für Schlüssel,
Verschlüsselung und Grenzen der Löschung siehe [SECURITY.md](SECURITY.md).

Das portable Format ist UTF-8-JSON mit `format: "morphhealth"` und `version: 1`.
Es enthält `settings` sowie die Arrays `foods`, `meals`, `drinks`, `periods`,
`weights` und `symptoms`. Das vollständige Schema, alle Nährstoffeinheiten,
Validierungsregeln und Fachresultate stehen in [docs/FORMAT.md](docs/FORMAT.md).

## Lokaler Wartungszugang `mh`

`mh` startet einen lokalen Linux-Prozess mit JSON-Lines auf stdin/stdout. Er
öffnet dieselbe Store-Implementierung und verwendet dieselben Berechnungen wie
Android. Das angegebene Verzeichnis ist eine eigene persistente Instanz;
es greift nicht heimlich auf den privaten Android-App-Ordner zu. JSON-Export
und -Import übertragen Daten zwischen diesen Instanzen.

Einmalig einen Beispieldatenbestand und einen Schlüssel **innerhalb dieses
Arbeitsordners**, aber in getrennten Unterverzeichnissen, vorbereiten:

```bash
umask 077
mkdir -p .local/cli-data .local/keys
python3 - <<'PY'
from pathlib import Path
import secrets
with Path('.local/keys/maintenance.key').open('xb') as key:
    key.write(secrets.token_bytes(32))
PY
```

Die Schlüsseldatei enthält genau **32 rohe Bytes**, keinen Hex- oder
Base64-Text. `xb` verhindert, dass ein vorhandener Schlüssel überschrieben wird.
Für spätere Aufrufe denselben Schlüssel behalten. Er muss außerhalb von
`--data-dir` liegen; ohne ihn ist dieser Datenbestand nicht entschlüsselbar.

```bash
./mh --data-dir "$(pwd)/.local/cli-data" \
     --key-file "$(pwd)/.local/keys/maintenance.key" \
     --now '2026-09-26T10:15:00+02:00' <<'JSONL'
{"request_id":"schema","op":"describe"}
{"request_id":"tag","op":"nutrition.day","date":"2026-09-26"}
{"request_id":"zyklus","op":"cycle.forecast","on":"2026-09-26"}
JSONL
```

`--now` ist optional und setzt die fachliche Uhr dieses Prozesses. Ohne diese
Option gilt die Systemuhr. Optional überschreiben `--food-base-url HTTPS_ORIGIN`
und `--food-user-agent STRING` die Werte aus `ENVIRONMENT.json`.

| Operation | Zusätzliche Anfragefelder |
|---|---|
| `describe` | keine; enthält Schema, Resultatbeschreibungen und ein direkt importierbares `exampleDocument` |
| `portable.export` | `"ack_plaintext": true` |
| `portable.import` | `"document": {…}`, `"confirm_replace": true` |
| `nutrition.day` | `"date": "YYYY-MM-DD"` |
| `cycle.forecast` | `"on": "YYYY-MM-DD"` |
| `food.search` | `"q": "Hafer"`, `"page": 1` |
| `food.lookup` | `"barcode": "5411188115366"` |

Jede Antwort enthält dieselbe `request_id`, `ok` und entweder `data` oder ein
`error`-Objekt mit `code` und `message`. Jede Antwort wird sofort ausgegeben und
geflusht; stdout enthält keine Banner. EOF beendet den Prozess. Explizite
`food.*`-Anfragen veranlassen einen lesenden Netzwerkzugriff; die Android-Option
für die Online-Suche ist keine zusätzliche CLI-Sperre. Weitere Beispiele und
die vollständigen Ein-/Ausgaben stehen in [docs/FORMAT.md](docs/FORMAT.md).

## Architektur und wesentliche Entscheidungen

- [app/lib/core](app/lib/core) enthält die produktive reine Dart-Fachlogik:
  Schema/Validierung, Ernährungssummen, Zykluseinschätzung, Historienfilter,
  Open-Food-Facts-Adapter und verschlüsselten Store. Android und `mh` importieren
  diese Bibliothek gemeinsam.
- Verzehreinträge enthalten einen vollständigen Lebensmittel-Snapshot. Spätere
  Änderungen oder Löschungen eines Katalog-Lebensmittels verändern bereits
  aufgezeichnete Mahlzeiten nicht.
- Fehlende Nährwerte bleiben `null`; eine bekannte Null bleibt `0`. Summen
  enthalten nur bekannte Beiträge, mit Angaben zur Vollständigkeit. Alle 31
  Nährstofffelder sind Teil desselben Datenmodells.
- g und ml werden ohne Dichteangabe nicht ineinander umgerechnet. Portionen
  beziehen sich auf die erklärte g-/ml-Basis. Bei OFF-Produkten bleibt die
  deklarierte Nährwertbasis maßgeblich, auch wenn die Packungsgröße eine andere
  Einheit nennt.
- Einträge gehören zum eingegebenen Kalenderdatum. Ein importierter ISO-Zeitstempel
  mit Offset verschiebt den Tagebucheintrag nicht auf einen anderen Tag.
  Zyklusabstände rechnen mit zivilen Tagen ohne Sommerzeit-Verkürzung.
- Die Prognose verwendet maximal zwölf vergangene Startabstände, einen
  persönlichen Median und ein Streuungsfenster. Spotting, zukünftige Beginne
  und ausgewiesene auffällige Abstände werden nicht als normale Zyklusabstände
  behandelt. Ein abgelaufenes Zeitfenster wird nicht als erfundener neuer Zyklus
  fortgeschrieben. Die Erklärung nennt Unsicherheit und Ausschlüsse.
- Der lokale Store komprimiert den JSON-Gesamtstand mit gzip und speichert ihn authentifiziert verschlüsselt
  mit serialisierten, atomaren Dateiersetzungen. Verschlüsselung und
  Entschlüsselung laufen in einem Dart-Isolate. Die Dateiauswahl verwendet einen
  schmalen nativen Android-Kanal; Gesundheits- oder Kamera-Berechtigungen werden
  nicht benötigt.

## Tatsächliche Prüfungen und Prüfstand

Der abschließende gemeinsame `./check.sh`-Lauf hat **49 Tests bestanden**. Die statische Analyse meldet keine Befunde:

| Gruppe | Anzahl | Geprüfte Beispiele |
|---|---:|---|
| Shared Core | 27 | Alle Nährstoffeinheiten, fehlende Werte, OFF-Schemata, zivile Tage/Sommerzeit, persönliche Prognose, Überlappungen, Importvalidierung, falsche Schlüssel/Passphrasen, verschlüsselte Persistenz, Datensatzgrenzen und 10.000 Einträge. |
| Health-Oberfläche | 9 | Perioden-, Gewichts- und Symptom-CRUD, kg/lb-Präzision, Kalendernavigation, Prognose/Tagebuchmodus, Offset-Zeitstempel, Importwechsel, große Schrift sowie parallele Einstellungen mit echtem Store. |
| Ernährungsoberfläche | 7 | Lebensmittelverwaltung und Tagebucheinträge einschließlich Mengen, Einheiten, Wiederverwendung, Nährstoffanzeigen und Bedienung. |
| Gemeinsame Oberfläche | 4 | Navigation, Sprachenwechsel, gemeinsames Tagesdetail, Historienfilter/Bearbeitung, große Schrift und kleine Nährstoffwerte. |
| Datenoberfläche | 2 | Sichtbare Fortschrittsanzeige, Passphrase-Dialog und nativer Dateidialog-Abbruch in Deutsch und Englisch. |

Der reale JSON-Lines-Prozess wurde zusätzlich mit **15 Anfragen** geprüft:
sofortige Antworten, Beschreibungsbeispiel, Import/Export, Fachresultate,
erwartete Fehler, Persistenz nach Neustart sowie echte HTTPS-Suche und
v3.6-Produktabruf am bereitgestellten Origin.
[artifacts/cli-check.json](artifacts/cli-check.json) enthält die Ergebnisse;
`ok: false` steht dort bei gezielt ungültigen Anfragen und ist Teil der Prüfung.

Auf dem Android-Referenzgerät wurden die App gebaut, installiert und gestartet,
eine echte Online-Lebensmittelsuche mit anschließender Tagebucherfassung,
JSON-Import über den nativen Dateidialog und die Erstellung einer verschlüsselten
Sicherung tatsächlich durchgeführt. Screenshots liegen in
[artifacts/screenshots](artifacts/screenshots).

Die Wiederherstellung wurde nach vollständiger Deinstallation und frischer
Android-Installation durchgeführt. Die gesicherten Einträge und Tagessummen
wurden wieder angezeigt. Ein synthetischer Bestand mit 10.000 Mahlzeiten über
mehrere Jahre wurde über den nativen Dateidialog importiert. Ein Eintrag vom
23.11.2019 wurde per Freitext gefunden, geöffnet und von 125 auf 130 ml korrigiert.
Tageswerte und Verläufe über sieben sowie 28 Tage wurden auf Android geprüft;
der gesamte Bestand blieb nach einem Prozessneustart erhalten.

Der gemeinsame Host-Test mit 10.000 vollständig beschriebenen Mahlzeiten maß
12 ms für 28 Tagesauswertungen, 18 ms für eine gefilterte Historienseite,
468 ms für verschlüsseltes Speichern und 235 ms für erneutes Öffnen. Dies sind
Host-Messungen, keine Android-Bildraten. Durch gzip vor AES-GCM belegt dieser
Testbestand 96.773 Byte statt zuvor 8.786.552 Byte; die Daten bleiben vollständig
erhalten. Alte unkomprimierte Speicher und Sicherungen werden weiterhin gelesen.
Auf Android wurde der vorhandene unkomprimierte Bestand geöffnet, um einen
Wassereintrag ergänzt und komprimiert erneut gespeichert. Der anschließende
Prozessneustart mit 10.000 Mahlzeiten benötigte laut `am start -W` 1.513 ms.
Dieser Android-Testbestand enthält zusätzlich individuelle Notizen und belegt
187.213 verschlüsselte Byte.

Mit dem finalen Build wurden außerdem der Sprachwechsel auf Englisch und eine
neue verschlüsselte Sicherung der 10.000 Mahlzeiten über den Android-Dateidialog
geprüft. Die 187.304 Byte große Datei ließ sich auf dem Host allein mit der
Testpassphrase entschlüsseln; alle 10.000 Mahlzeiten, drei Getränke und die
englische Spracheinstellung waren enthalten. Nach „Delete all local data“ und
einem Prozessneustart war die App wieder leer und deutsch voreingestellt.
Die APK bleibt auf dem Referenzgerät installiert, ohne synthetische Testeinträge.

Protokolle: [artifacts/check.log](artifacts/check.log),
[artifacts/build.log](artifacts/build.log),
[artifacts/android-performance.json](artifacts/android-performance.json),
[artifacts/android-backup-check.json](artifacts/android-backup-check.json) und
[artifacts/TEST-RESULTS.md](artifacts/TEST-RESULTS.md).
Die Android-UI-Zeiten enthalten den Aufwand von ADB/UIAutomator und sind keine
isolierten Rechenzeitmessungen. Testdateien und Screenshots enthalten ausschließlich
synthetische Daten.

## Bekannte Grenzen

- Periodenstärke und Notiz gelten jeweils für einen gesamten Periodeneintrag;
  es gibt keine zusätzliche täglich wechselnde Blutungsstärken-Tabelle.
- Die Einschätzung ist erst ab drei geeigneten Periodenbeginnen verfügbar und
  bleibt bei wenigen oder stark schwankenden Aufzeichnungen unsicher. Das
  Zeitfenster ist keine medizinische oder kalibrierte Wahrscheinlichkeitsaussage.
- Speicherung als vollständiger verschlüsselter Snapshot: maximal 64 MiB
  Klartext und 100.000 Datensätze insgesamt. Verschlüsselte Eingabedateien sind
  auf 100 MiB begrenzt. Es gibt keine Datenbankindizes; Filter arbeiten im
  Speicher, Listen verwenden begrenzte beziehungsweise nachladbare Ansichten.
  Mehrjährige 10.000-Einträge-Bestände wurden auf dem Host und auf Android
  geprüft; jedes Speichern komprimiert und verschlüsselt dennoch den gesamten
  Stand neu.
- Die Release-APK verwendet die lokale Android-Debug-Signatur. Sie ist für die
  Installation in dieser Umgebung bestimmt; ein eigener dauerhaft verwalteter
  Signaturschlüssel wäre für eine Produktverteilung erforderlich.
- Der hier konfigurierte `localhost`-Dienst benötigt die oben gezeigte
  Weiterleitung. Ohne erreichbaren Dienst bleibt die lokale App nutzbar;
  neue Online-Suchergebnisse können dann nicht geladen werden.
- OFF-Daten können unvollständig sein. Produktnamen sind Quelldaten und werden
  nicht automatisch übersetzt. Unbekannte Einheiten und nicht exakt angegebene
  Nährwerte werden nicht durch erfundene Werte ersetzt.
- Ein verlorener Geräteschlüssel lässt sich nicht aus den lokalen Daten
  rekonstruieren. Für eine unabhängige Wiederherstellung wird eine zuvor
  angelegte Sicherung samt Passphrase benötigt. Physische Löschung alter
  Flash-Blöcke und Schutz gegen ein kompromittiertes Betriebssystem werden
  nicht zugesichert; Einzelheiten stehen in [SECURITY.md](SECURITY.md).
