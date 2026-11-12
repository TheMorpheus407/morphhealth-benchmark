# MorphHealth — Produktauftrag

**MH-PERSONAL-3 · Fassung 1.0-rc3 · 17. September 2026**

*Lokale Fassung 1.0-rc3-L1 (23. September 2026): Es gibt kein Zeitlimit mehr. Auftrag und alle Produktanforderungen sind unverändert.*

## P01 · Auftrag

Entwickle MorphHealth als vollständige, benutzbare Android-App in Flutter. MorphHealth verbindet ein Ernährungstagebuch mit Open Food Facts, einen intelligenten persönlichen Periodentracker, Gewicht und Symptome. Die Anwendung soll sich im Alltag verwenden lassen, nicht nur eine Produktidee demonstrieren.

Beginne im bereitgestellten leeren Arbeitsverzeichnis. Dieser Auftrag ersetzt alle früheren MorphHealth-Aufträge. Vorhandener MorphHealth- oder MorphCook-Code gehört nicht zur Aufgabe. Arbeite eigenständig bis zu einer ausführbaren Abgabe: konzipieren, implementieren, bauen, ausprobieren und verbessern. Allgemeine Bibliotheken und Dokumentation dürfen verwendet werden. Zusätzliche externe KI-Dienste sind nicht Bestandteil der Anwendung oder deiner Werkzeuge.

Es gibt keine Begrenzung von Arbeitszeit, Tokens, Kosten oder Iterationen. Arbeite, bis das Ergebnis so gut ist, wie du es machen kannst. Die Grundumgebung ist bereits eingerichtet. Triff nicht festgelegte Produkt- und Implementierungsentscheidungen selbst. Dokumentiere wesentliche Entscheidungen und tatsächliche Einschränkungen in der Abgabe. Ändere diesen Auftrag nicht.

## P02 · Produkt und Bedienung

Die App ist für einen Nutzer pro Installation gedacht. Ernährung und Zyklus müssen unabhängig voneinander verwendbar sein. Gewicht und Symptome ergänzen beide Bereiche. Wasser und Koffein gehören in das Ernährungstagebuch und sind keine zusätzlichen Hauptmodule.

Gestalte ein ruhiges, zusammenhängendes Werkzeug mit verständlicher Navigation und schnellen wiederkehrenden Erfassungen. Keine Registrierung, keine Werbebotschaften, keine künstlichen Streaks, keine Essens- oder Gewichtsbeschämung. Ziele werden vom Nutzer gewählt. Die vier Bereiche lassen sich in der Übersicht ein- und ausblenden.

Die gesamte eigene Oberfläche muss auf **Deutsch und Englisch** nutzbar sein; Deutsch ist voreingestellt. Beachte die üblichen Anforderungen an eine zugängliche Android-Anwendung. Es gibt kein vorgegebenes Layout und keine vorgeschriebene Stilmarke.

## P03 · Ernährungstagebuch

Nutzer sollen Lebensmittel nach Namen suchen oder über eine eingegebene Barcode-Nummer in **Open Food Facts** finden und ihrem Tagebuch hinzufügen können. Ein echter Datenbankabruf ist erforderlich. Ein Kamerascanner ist nicht Teil dieses Auftrags.

Das Tagebuch unterstützt eigene Lebensmittel, Favoriten und das erneute Erfassen eines bereits protokollierten Verzehreintrags. Eigene Lebensmittel sind bearbeitbar. Verzehreinträge enthalten Lebensmittel, Menge, Datum beziehungsweise Uhrzeit und eine Mahlzeitenzuordnung zu Frühstück, Mittagessen, Abendessen oder Snack. Sie sind nachträglich korrigierbar und löschbar. Mengen in Gramm, Millilitern und Portionen müssen verwendbar sein.

Zeige Kalorien sowie Protein, Kohlenhydrate und Fett pro Eintrag und für einen ausgewählten Tag. Unterstütze außerdem gesättigte Fettsäuren, Zucker, Ballaststoffe, Salz, Natrium und Koffein. Für Mikronährstoffe umfasst der Auftrag:

- Vitamine A, C, D, E, K, B1, B2, B3, B5, B6, B7, B9 und B12.
- Kalzium, Eisen, Magnesium, Kalium, Zink, Selen, Jod und Phosphor.

Diese Angaben müssen sowohl für eigene Lebensmittel erfassbar als auch in den Lebensmittel- und Tagesansichten verwendbar sein. Alle Mikronährstoffe gehören zur Funktion, nicht nur drei beispielhafte Platzhalter.

Wasser und zusätzlich aufgenommenes Koffein lassen sich unmittelbar im Ernährungstagebuch erfassen. Biete eine Schnellerfassung für häufige Wassermengen an. Nutzer können freiwillige Tagesziele für Wasser, Kalorien und die drei Makronährstoffe verwalten.

## P04 · Persönlicher Periodentracker

Nutzer können ihre vergangenen und aktuellen Perioden mit Beginn und Ende erfassen, korrigieren und löschen. Unterstütze die Erfassung der Blutungsstärke einschließlich Spotting sowie Notizen.

Ein Monatskalender und eine Historie machen den Verlauf verständlich. Der Tracker soll die persönliche aufgezeichnete Historie auswerten und damit bei der Planung der nächsten Periode helfen. Eine bloße statische Kalenderdarstellung erfüllt diesen Teil nicht. Biete eine verständliche Erklärung der angezeigten persönlichen Einschätzung an.

Symptome müssen im Zykluskalender und im gewählten Tageskontext erreichbar sein. Nutzer können den Periodentracker auch ausschließlich als Tagebuch verwenden.

Es geht um persönliche Dokumentation und Planung, nicht um Diagnosen, Eisprungberechnung, Verhütung oder medizinische Behandlung.

## P05 · Gewicht und Symptome

Gewicht: Einträge für ein gewähltes Datum, Bearbeitung und Löschung, Eingabe und Anzeige in kg oder lb sowie ein Verlauf.

Symptome: frei wählbarer Name, Intensität von 0 bis 10, Datum beziehungsweise Uhrzeit und optionale Notiz. Einträge sind bearbeitbar und löschbar. Ein Symptomverlauf soll sich nach dem gewählten Symptom betrachten lassen.

## P06 · Gemeinsame Übersicht und Historie

Eine Übersicht zeigt die vom Nutzer gewählten Bereiche. Ein gemeinsames Tagesdetail führt Ernährung, Wasser/Koffein, Gewicht, Periodenaufzeichnungen und Symptome dieses Tages zusammen.

Biete Tagesansichten sowie Verläufe über sieben und 28 Tage an. Für Nährstoffe genügt ein auswählbarer Verlauf statt vieler gleichzeitig geöffneter Diagramme. Kalendernavigation erlaubt auch die Betrachtung älterer Monate.

Eine durchsuchbare Historie macht Einträge über die vier Bereiche hinweg auffindbar. Datumsbereich, Bereich und Freitext sind nutzbare Filter. Einträge lassen sich von dort öffnen und bearbeiten. Die Anwendung soll einen mehrjährigen täglichen Datenbestand mit bis zu **10.000 Tagebucheinträgen** zügig bedienen können.

## P07 · Lokale Daten, Privatsphäre und Portabilität

MorphHealth ist lokal nutzbar, ohne Konto, eigenen Backend-Dienst oder laufende Internetverbindung für den persönlichen Gesundheitsbereich. Die Online-Lebensmittelsuche ergänzt die lokale Nutzung. Nutzer behalten die Kontrolle über ihre Daten und die Nutzung der Online-Anbindung.

Lokale Gesundheitsdaten und passphrasengeschützte Sicherungen müssen verschlüsselt sein. Biete einen vollständigen, dokumentierten, maschinenlesbaren Datenexport und -import sowie verschlüsselte Sicherung und Wiederherstellung an. Eine Sicherung muss zur Übernahme auf eine frische Installation geeignet sein. Auch das Löschen des gesamten lokalen Datenbestands ist bedienbar.

Keine Werbung, Telemetrie oder Laufzeit-KI. Die App benötigt keine medizinischen Konten, keine Plattform-Gesundheitsberechtigungen und keine Verbindung zu persönlichen Drittanbieterprofilen.

## P08 · Technische Lebensmittelanbindung

Verwende für dieses Release den lesenden Open-Food-Facts-Vertrag mit folgenden Einstiegspunkten:

```text
GET {base}/api/v3.6/product/{barcode}.json
GET {base}/cgi/search.pl?search_terms={q}&search_simple=1&action=process&json=1&page={p}&page_size=20
```

Feldprojektionen nach dem dokumentierten API-Vertrag sind erlaubt. Die offizielle API-Dokumentation ist die externe technische Referenz:

<https://openfoodfacts.github.io/openfoodfacts-server/api/>

`ENVIRONMENT.json` enthält `food_api_base_url` und `food_api_user_agent`. Verwende diese Werte, statt den Dienst unveränderlich in Fachcode einzubauen. Der Origin ist ein bereitgestellter HTTPS-Endpunkt desselben Datenvertrags. Benötigtes Zertifikatsvertrauen wird durch die Arbeitsumgebung bereitgestellt. Für eine normale Produktinstallation ist der Origin `https://world.openfoodfacts.org`. Es werden ausschließlich lesende Anfragen benötigt. Eigene Lebensmittel sind lokale Nutzerdaten; eine Beitragsfunktion für die öffentliche Datenbank ist nicht verlangt.

Die Integration muss ohne Änderungen an der Fachlogik an einem anderen bereitgestellten Origin desselben Vertrags laufen. Ein notwendiger technischer Zugang oder eine installierte Toolversion steht im Umgebungsmanifest und muss nicht geraten werden.

## P09 · Zielumgebung und Abgabe

Die grafische Zielplattform ist **Android**, mit Flutter, nicht eine Webseite in einem WebView. Referenzgerät: Android 15/API 35 AOSP, x86_64, vier virtuelle CPU-Kerne, 4 GiB RAM, 1080 × 2400 Pixel bei 420 dpi.

Der Linux-Host stellt Bash, Git, Python 3.12, JDK 17, Flutter/Dart, Android SDK, adb sowie Zugriff auf Emulatorbildschirm und Eingaben bereit. Konkrete installierte Versionen und Umgebungswerte stehen im schreibgeschützten `ENVIRONMENT.json`. Verwende die installierte Toolchain und sperre zusätzliche Abhängigkeiten.

Liefere:

- `app/` mit Flutter-Quellen, Assets und `pubspec.lock`; Einstieg `app/lib/main.dart`.
- `artifacts/morphhealth.apk`: installierbare Release-APK mit x86_64-Unterstützung, Package-ID `de.themorpheus.morphhealth.local`.
- Ausführbare `build.sh`, `check.sh` und den lokalen Starter `mh` aus P10.
- `README.md`: Bedienung, Build/Start, wesentliche Entscheidungen, Datenformate, tatsächliche Tests und bekannte Grenzen.
- `SECURITY.md`: Sicherheitskonzept, verwendete Bibliotheken und Dateiformate.

Alle Produktfunktionen müssen über Android bedienbar sein. Der folgende Wartungszugang ersetzt keine Produktoberfläche.

## P10 · Lokaler Wartungszugang

Stelle einen schmalen lokalen JSON-Lines-Zugang zu den **tatsächlichen Daten und Funktionen derselben Anwendung** bereit. Er läuft als gesonderter Linux-Prozess, nicht als öffentlich erreichbarer Dienst.

```text
./mh --data-dir ABS --key-file ABS [--now RFC3339]
     [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]
```

`data-dir` bezeichnet einen persistenten Arbeitsdatenbestand. Die Schlüsseldatei enthält 32 rohe Bytes und liegt außerhalb dieses Verzeichnisses; dokumentiere ihre Verwendung. `--now` setzt die fachliche Uhr für diesen Prozess. Ohne diese Option wird die Systemuhr verwendet.

Eine Anfrage ist eine JSON-Zeile mit `request_id` und `op`. Eine Antwort enthält dieselbe `request_id`, `ok` und entweder `data` oder `error`. Antwort nach jeder Anfrage ausgeben und flushen; keine Banner auf stdout. EOF beendet den Prozess.

| `op` | Weitere Eingabe | Inhalt von `data` |
|---|---|---|
| `describe` | keine | Beschreibung der verwendeten Datenformate und der folgenden Ein-/Ausgaben, einschließlich eines für Import geeigneten Beispieldokuments. |
| `portable.export` | `ack_plaintext: true` | Der vollständige Datenexport im eigenen dokumentierten Format. |
| `portable.import` | `document`, `confirm_replace: true` | Übernahme dieses Formats als Ersatz des Arbeitsdatenbestands; Ergebnisbericht. |
| `nutrition.day` | `date` als `YYYY-MM-DD` | Die Ernährungsangaben, die die Anwendung für diesen Tag ausgibt. |
| `cycle.forecast` | `on` als `YYYY-MM-DD` | Die persönliche Zykluseinschätzung der Anwendung für diesen Betrachtungstag. |
| `food.search` | `q`, `page` | Die Ergebnisse der implementierten Lebensmittelsuche. |
| `food.lookup` | `barcode` | Das Ergebnis des implementierten Produktabrufs. |

Datenmodell, fachliche JSON-Felder, Datentypen der Fachresultate und interne Architektur sind nicht vorgegeben. Dokumentiere sie so, dass ein anderer Entwickler den Zugang ohne Rückfragen verwenden kann. Der Zugang ist eine weitere Aufrufmöglichkeit der produktiven Funktionen, keine zweite unabhängige Implementierung. Eine zusätzliche grafische Desktop-App ist nicht erforderlich.

## P11 · Nichtumfang

Nicht zu implementieren sind Schlaf, Schritte, Watch-/Wearable-Anbindungen, Geräte-Replay, Health Connect/HealthKit, BLE, Custom-Tracker, Konten, Backend, Multi-Device-Synchronisation, iOS, medizinische Dokumente, OCR, Foto-Kalorienschätzung, Barcode-Kamera, Laufzeit-LLMs, Medikamentenverwaltung, automatische Ernährungspläne, ein Rezepteditor, Benachrichtigungen oder Store-Veröffentlichung.

Auch spezielle Importformate früherer MorphHealth-Entwürfe gehören nicht zum Auftrag. Implementiere den beschriebenen Umfang statt ihn durch zusätzliche Produkte zu ersetzen.

## P12 · Abschluss

Baue und starte die Anwendung selbst. Führe statische Analyse und eigene Tests aus und prüfe die von dir implementierten Produktabläufe. Liefere den tatsächlichen Arbeitsstand mit nachvollziehbaren Ergebnissen, nicht nur geplante Befehle oder behauptete Fertigstellung. Die finale Nachricht nennt die erzeugten Artefakte und verbleibenden Einschränkungen.
