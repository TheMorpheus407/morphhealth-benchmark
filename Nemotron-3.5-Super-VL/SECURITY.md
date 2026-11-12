# MorphHealth — Sicherheitskonzept

## Grundsatz

MorphHealth speichert alle Gesundheitsdaten nur lokal auf dem Gerät. Es gibt
kein Konto, kein Backend, keine Telemetrie, keine Werbung und keine
Laufzeit-KI. Die Online-Anbindung beschränkt sich auf die lesende
Lebensmittelsuche (Open Food Facts Vertrag P08) und ist vom Nutzer
steuerbar.

## Verschluesselung

Der laufende Datenbestand wird als einzelne Datei verschluesselt abgelegt:

- Algorithmus: AES-256-CBC mit zufallsprinzip IV (pro Schreiben neu).
- Integritaet: HMAC-SHA256 über IV || Ciphertext, bei jedem Lesen
  geprueft. Falscher Schluessel oder manipulierte Datei fuehrt zu einem
  Fehler statt zu stillschweigend korrupten Daten.
- Dateiformat: JSON-Umschlag `{iv, data, mac}` (alle Base64Url kodiert).
- Schluessel: genau 32 Rohbyte (AES-256).

Die App erzeugt den Schluessel beim ersten Start und verwaltet ihn im
sicheren Schlüsselspeicher des Betriebssystems (Android). Der `mh`-CLI-Zugang
verlangt eine separate Schlüsseldatei mit 32 Rohbyte (`--key-file`),
ausserhalb des Datenverzeichnisses, und verwendet dieselbe
En-/Entschluesselung wie die App (gleiche Core-Implementierung).

Sicherungen (`build.sh`/`Einstellungen -> Sichern`) kopieren die
verschlüsselte Datei; der portable Datenexport (`portable.export`) liefert
das JSON-Dokument des Formats `morphhealth.v1` (geklaerter Text, deshalb
`ack_plaintext: true` erforderlich) und darf nur vertrauenswürdig
weitergegeben werden.

## Bibliotheken (App)

- Flutter SDK 3.41.9 / Dart 3.11.5 (Framework)
- `http` — lesende Open-Food-Facts-Anfragen
- `intl`, `flutter_localizations` — Datumsformatierung, Deutsch/Englisch
- `encrypt` 5.x (AES-256, reine Dart-Implementierung) + `crypto`
  (HMAC-SHA256) — Verschluesselung/Integritaet
- `path_provider` — Anwendungsspeicher
- `flutter_secure_storage` — Daten-Schluessel im sicheren Schlüsselspeicher
- `file_picker` — Export/Import/Sicherung über Dokumenten-Auswahl
- `fluttertoast` — Ruckmeldungen

Alle Abhaengigkeiten sind in `app/pubspec.yaml` festgeschrieben
(`pubspec.lock`).

## Dateiformate

- Laufender Bestand: verschluesselte Datei `data.json.enc`
  (App-Datenverzeichnis).
- Portables Format `morphhealth.v1`: JSON-Dokument mit `format`,
  `createdAt`, `document`; `document` enthaelt den vollen
  Gesundheitsdatenbestand (`localFoods`, `cachedProducts`,
  `nutritionEntries`, `waterEntries`, `caffeineEntries`, `cycleEntries`,
  `symptomEntries`, `weightEntries`, `goals`, `settings`).

## Praktische Einschränkungen (dokumentiert)

- Der Daten-Schluessel der App liegt im App-Internen Schlüsselspeicher.
  Bei Verlust des Schlüssels ist der Datenbestand nicht
  wiederherzustellen. Das `mh`-CLI erfordert eine eigene, vom Nutzer
  verwaltete Schlüsseldatei.
- Verschluesselung schuetzt den Datenbestand im Dateisystem, nicht vor
  einem Angreifer mit Zugriff auf das laufende Gerät/Prozessspeicher.
- Keine Plattform-Gesundheitsberechtigungen (Health Connect o. ä.), keine
  Zertifikats-Pinning; TLS-Vertrauen wird durch die bereitgestellte
  Umgebung gestellt (ENVIRONMENT.json `certificate_trust`).
- Keine medizinische Diagnose, keine Verhütungs-/Eisprungvorhersage.