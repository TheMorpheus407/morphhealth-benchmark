# MorphHealth: Sicherheitskonzept

Stand: Version 1.0.0 (Produktauftrag MH-PERSONAL-3, 1.0-rc3-L1). Dieses Dokument beschreibt, was die Anwendung schützt,
womit sie es schützt, welche Dateiformate und Bibliotheken beteiligt sind und wo die Grenzen liegen. Alle Angaben
lassen sich im Quelltext (`app/lib/core/crypto.dart`, `store.dart`, `backup.dart`,
`app/android/.../MainActivity.kt`) und mit den Tests in `app/test/core/` nachvollziehen.

## 1. Was geschützt wird

Die Anwendung verarbeitet Gesundheitsdaten einer Person pro Installation: Ernährung, Wasser, Koffein, Gewicht,
Perioden, Symptome, dazu Einstellungen und Ziele.

| Ort | Schutz |
|---|---|
| Lokale Ablage auf dem Gerät | AES-256-GCM, Schlüssel im Android Keystore umhüllt (Abschnitt 3) |
| Sicherung (`.mhbackup`) | AES-256-GCM, Schlüssel aus einer Passphrase per Argon2id (Abschnitt 4) |
| Export (`.json`) | unverschlüsselt, nur nach ausdrücklicher Bestätigung (Abschnitt 6) |
| Netzwerk | nur HTTPS zum Lebensmitteldienst, nur Suchbegriff oder Barcode (Abschnitt 7) |
| Wartungszugang `./mh` | Daten wie die App verschlüsselt, Schlüssel aus einer Datei außerhalb des Datenverzeichnisses |

**Bedrohungsmodell.** Geschützt wird gegen das Lesen der Dateien ohne den Schlüssel: verlorene oder entsorgte
Geräte ohne Zugriff auf den Keystore, kopierte Datenverzeichnisse, Cloud-Backups, abgegriffene Sicherungsdateien
und Speicherabbilder des Dateisystems. Ein manipulierter Datenbestand wird erkannt (Authentifizierung durch GCM).

**Nicht geschützt** wird gegen einen Angreifer mit Root-Zugriff auf ein laufendes, entsperrtes Gerät, gegen
Schadsoftware mit Zugriff auf den Prozessspeicher der App, gegen Bildschirmaufnahmen durch den Nutzer selbst und
gegen Seitenkanäle (Abschnitt 8).

## 2. Grundsätze

- Die Anwendung hat kein Konto, keinen eigenen Server, keine Werbung, keine Telemetrie und keine Laufzeit-KI.
- Die einzige Berechtigung ist `INTERNET` für die Lebensmittelsuche. Es gibt keine Plattform-Gesundheitsberechtigungen,
  keinen Speicherzugriff, keine Kamera, keine Benachrichtigungen und keine Verbindung zu Drittanbieterprofilen.
- Kryptografie stammt aus einer geprüften Bibliothek (Abschnitt 5). Die Anwendung enthält keine selbst entwickelten
  Verfahren; eigener Code setzt nur Formate zusammen (Kopfdaten, Nonces, zusätzliche authentifizierte Daten).
- Geheimnisse liegen nie im Klartext im Dateisystem und in keinem Protokoll. Die Schlüsseldatei des Wartungszugangs
  gehört dem Aufrufer.

## 3. Lokale Ablage

### Schlüsselhierarchie

```
Android Keystore                    (nicht exportierbarer AES-256-GCM-Schlüssel, Alias morphhealth_master_wrap_v1)
   │  umhüllt
   ▼
Hauptschlüssel, 32 zufällige Byte   (files/mh-keys/master.wrapped, getrennt vom Datenverzeichnis files/mh-data)
   │  HKDF-SHA-256(Salt = Salt des Snapshots, Info = "MorphHealth/store/v1/aes-256-gcm")
   ▼
Datenschlüssel, 32 Byte             (AES-256-GCM für Snapshot und Journal)
```

- Der Hauptschlüssel entsteht beim ersten Start aus dem Zufallsgenerator des Betriebssystems und wird sofort mit
  dem Keystore-Schlüssel umhüllt. `master.wrapped` enthält `nonce (12) | Chiffretext | Tag (16)`.
- Der Keystore-Schlüssel verlangt keine Nutzerauthentifizierung. Die App liest ihre Daten deshalb auch ohne
  erneute Entsperrung, sobald das Gerät entsperrt gestartet wurde. Ob der Schlüssel in einer Hardware-Umgebung
  (TEE, StrongBox) liegt, entscheidet das Gerät; die App erzwingt es nicht.
- „Alles löschen“ ersetzt die Daten, löscht den Keystore-Schlüssel und erzeugt einen neuen Hauptschlüssel.
  Die alten Daten sind damit auch aus einer kopierten Datei nicht mehr lesbar.
- Beim Wartungszugang ist die 32-Byte-Schlüsseldatei der Hauptschlüssel selbst. Der Rest der Kette ist identisch.

### Dateien

Das Datenverzeichnis enthält genau drei Dateien: `store.mhs` (Snapshot), `store.mhj` (Journal) und `store.lock`
(Sperre gegen gleichzeitigen Zugriff, ohne Inhalt).

**Kopf (44 Byte), gleich für Snapshot und Journal**

| Offset | Länge | Inhalt |
|---|---|---|
| 0 | 4 | Kennung: `MHS1` (Snapshot) oder `MHJ1` (Journal) |
| 4 | 16 | Salt des Snapshots (bei jedem neuen Snapshot zufällig) |
| 20 | 8 | Sequenznummer (Big Endian): beim Snapshot der Stand, beim Journal die Basis |
| 28 | 16 | Schlüsselprüfwert: die ersten 16 Byte von HMAC-SHA-256(Datenschlüssel, `MorphHealth/store/v1/key-check`) |

Der Prüfwert unterscheidet einen falschen Schlüssel (Fehler `wrong_key`) von einem beschädigten Bestand.

**`store.mhs`**: Kopf, dann `nonce (12) | Chiffretext | Tag (16)`. Klartext ist gzip-komprimiertes JSON
`{"format":"morphhealth-store","version":1,"seq":N,"tables":{tabelle:{id:datensatz}}}`.
Zusätzliche authentifizierte Daten (AAD): der Kopf.

**`store.mhj`**: Kopf, dann beliebig viele Einträge `Länge u32 (Big Endian) | nonce (12) | Chiffretext | Tag (16)`.
Klartext eines Eintrags ist JSON `{"ops":[["p",tabelle,id,datensatz],["d",tabelle,id],...]}`.
AAD: Kopf des Journals gefolgt von der Sequenznummer des Eintrags (Basis + laufende Nummer, 8 Byte Big Endian).
Die Sequenznummer verhindert, dass Einträge umgeordnet, gelöscht oder aus einem anderen Journal eingefügt werden.

### Verhalten

- Jede Änderung wird als eigener, einzeln authentifizierter Journal-Eintrag angehängt und mit `flush` gesichert.
  Ein Absturz kann nur den letzten, unvollständigen Eintrag kosten. Dieser wird erkannt und verworfen.
  Ein beschädigter Eintrag in der Mitte ergibt den Fehler `corrupt`.
- Ab 500 Einträgen oder 512 KiB Journal (beim Öffnen ab 200 Einträgen oder 256 KiB) entsteht ein neuer Snapshot
  mit neuem Salt (temporäre Datei, dann Umbenennen). Danach beginnt ein leeres Journal.
- Nonces sind zufällig (12 Byte). Bei einem Schlüssel je Snapshot bleibt die Zahl der Einträge unter der
  Grenze, ab der Zufalls-Nonces bei GCM bedenklich werden.
- Vor jedem Schreiben prüft die Anwendung, dass der Datensatz sich beim Öffnen wieder lesen lässt. Was sich
  speichern lässt, macht den Bestand daher nicht unlesbar (`Db._put`, Test `roundtrip_test.dart`).
- Eine exklusive Dateisperre (`store.lock`) verhindert, dass App und Wartungszugang gleichzeitig dasselbe
  Verzeichnis beschreiben.

## 4. Verschlüsselte Sicherung (`.mhbackup`)

Eine Sicherung enthält das vollständige Exportdokument (Abschnitt 6 der README) und lässt sich auf einer frischen
Installation wiederherstellen. Die Passphrase hat mindestens 8 Zeichen und wird nirgends gespeichert.

| Offset | Länge | Inhalt (alle Zahlen Big Endian) |
|---|---|---|
| 0 | 4 | Kennung `MHB1` |
| 4 | 1 | Ableitungsverfahren, `2` = Argon2id |
| 5 | 4 | Speicher in KiB (Vorgabe 65536 = 64 MiB) |
| 9 | 4 | Durchläufe (Vorgabe 3) |
| 13 | 1 | Parallelität (Vorgabe 1) |
| 14 | 16 | Salt (zufällig je Sicherung) |
| 30 | 12 | Nonce (zufällig) |
| 42 | n | Chiffretext: AES-256-GCM über gzip-komprimiertes JSON (das Exportdokument) |
| 42 + n | 16 | Tag |

Der Schlüssel entsteht aus den UTF-8-Bytes der Passphrase per Argon2id (32 Byte Ausgabe). Die AAD sind die ersten
30 Byte (Kennung, Parameter, Salt): Wer die Parameter herabsetzt, macht die Authentifizierung ungültig.
Beim Lesen fremder Dateien gelten Obergrenzen (höchstens 512 MiB Speicher, 10 Durchläufe, 8 Lanes), damit eine
manipulierte Kopfzeile den Speicher nicht erschöpft. Eine falsche Passphrase und eine beschädigte Datei sind für
die GCM-Prüfung nicht unterscheidbar und ergeben dieselbe Meldung.

Die Passphrase wird nicht Unicode-normalisiert. Dieselbe Passphrase mit einem zusammengesetzten und einem
zerlegten Umlaut ergibt verschiedene Schlüssel.

## 5. Bibliotheken

Alle Versionen stehen in `app/pubspec.lock` und sind mit `flutter pub get --enforce-lockfile` gesperrt.

**Kryptografie**

| Bibliothek | Version | Lizenz | Verwendung |
|---|---|---|---|
| `cryptography` | 2.9.0 | Apache-2.0 | AES-256-GCM, HKDF-SHA-256, HMAC-SHA-256, Argon2id (reines Dart, kein nativer Code) |
| `crypto` | 3.0.7 | BSD-3-Clause | Hashfunktionen als Grundlage von `cryptography` |
| Android Keystore | System | System | Umhüllung des Hauptschlüssels (`AES/GCM/NoPadding`, 256 Bit) |

Die Verfahren sind mit bekannten Testvektoren abgesichert (`app/test/core/store_test.dart`): HKDF nach RFC 5869
(Testfall 1), AES-256-GCM nach dem NIST-Testfall 16 und gegen die JDK-Implementierung gegengeprüft, Argon2id nach
RFC 9106.

**Laufzeit, übrige**

| Bibliothek | Version | Lizenz |
|---|---|---|
| Flutter-Framework und Engine | 3.41.9 (Dart 3.11.5) | BSD-3-Clause |
| `flutter_localizations`, `sky_engine` | wie Flutter | BSD-3-Clause |
| `intl` | 0.20.2 | BSD-3-Clause |
| `characters` | 1.4.1 | BSD-3-Clause |
| `collection` | 1.19.1 | BSD-3-Clause |
| `meta` | 1.17.0 | BSD-3-Clause |
| `typed_data` | 1.4.0 | BSD-3-Clause |
| `path` | 1.9.1 | BSD-3-Clause |
| `clock` | 1.1.2 | Apache-2.0 |
| `material_color_utilities` | 0.13.0 | Apache-2.0 |
| `vector_math` | 2.2.0 | BSD-3-Clause |
| `ffi` | 2.2.0 | BSD-3-Clause |

Die Android-Seite bündelt AndroidX (Activity 1.8.1, Core 1.13.1, Fragment 1.7.1, Lifecycle 2.7.0, Window 1.2.0,
Startup 1.1.1, ProfileInstaller 1.3.1, ExifInterface 1.4.1, Savedstate 1.2.1 und weitere), Kotlin-Coroutines 1.7.1
und die Flutter-Embedding-Klassen (alle Apache-2.0 beziehungsweise BSD-3-Clause). Die Lizenztexte aller Pakete zeigt
die App unter „Einstellungen → Open-Source-Lizenzen“.

**Nur für Entwicklung und Tests** (nicht in der APK): `flutter_test`, `flutter_lints`, `lints`, `matcher`,
`test_api`, `stack_trace`, `leak_tracker` und Verwandte.

Gebaut wird mit Android Gradle Plugin 8.11.1, JetBrains Runtime 21 und Android-SDK 36 (Build-Tools 36.1.0).

## 6. Exportdatei

`Einstellungen → Daten und Sicherung → Exportieren` schreibt ein unverschlüsseltes JSON-Dokument
(Format `morphhealth-portable`, README Abschnitt 6). Die App weist vor dem Speichern darauf hin, dass die Datei alle
Gesundheitsdaten im Klartext enthält. Ziel und Aufbewahrung bestimmt der Nutzer über die Android-Dateiauswahl
(`ACTION_CREATE_DOCUMENT`). Die App erhält dadurch keinen Zugriff auf weitere Dateien. Der Wartungszugang verlangt
für den Export `ack_plaintext: true`.

Beim Import und bei der Wiederherstellung prüft die App das gesamte Dokument, bevor sie etwas ändert. Bei einem
Fehler bleibt der Bestand unverändert. Der Import ersetzt den Bestand nur nach Bestätigung.

## 7. Netzwerk

- Ziel ist ausschließlich der Lebensmitteldienst mit dem Open-Food-Facts-Vertrag (Vorgabe im Build:
  `food_api_base_url` aus `ENVIRONMENT.json`; in der Produktion `https://world.openfoodfacts.org`).
  Der Ursprung muss `https://` verwenden; andere Schemata lehnt die App ab (`usesCleartextTraffic=false`,
  zusätzlich in `food_api.dart` geprüft). Weiterleitungen folgt die App selbst und nur auf `https` beim selben
  Host und Port (höchstens drei); alles andere bricht den Abruf ab.
- Die Zertifikatsprüfung ist nicht abschaltbar. Es gibt keinen `badCertificateCallback`, keine Ausnahmen für
  einzelne Hosts und keinen Eingriff in das Systemvertrauen. Ein vertrauenswürdiges Wurzelzertifikat muss das System
  (oder beim Wartungszugang die Umgebung über `SSL_CERT_FILE`) liefern.
- Übertragen werden nur: der Suchbegriff oder die Barcode-Nummer, die Seitennummer, die Feldliste und der
  User-Agent-Header. Cookies, Kennungen und Gesundheitsdaten gehören nicht dazu, und Produktbilder werden nicht geladen.
- Nutzer können die Online-Suche in den Einstellungen ausschalten. Die App arbeitet dann vollständig lokal.
- Anfragen haben Zeitlimits und eine Größenbegrenzung für Antworten. Antworten werden als Daten behandelt und
  strikt ausgewertet; unbekannte Felder werden ignoriert.

## 8. Android-Konfiguration

Aus dem zusammengeführten Manifest der Release-APK:

- `minSdk 26`, `targetSdk 36`, Package `de.themorpheus.morphhealth.local`, nicht debugbar.
- `allowBackup=false`, `fullBackupContent=false` und `dataExtractionRules`, die Cloud-Backup und
  Gerätewechsel für alle Bereiche ausschließen. Nichts verlässt das Gerät ohne Zutun des Nutzers.
- Berechtigungen: `android.permission.INTERNET`. Zusätzlich fügt AndroidX Core eine app-eigene Signaturberechtigung
  `de.themorpheus.morphhealth.local.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` ein, die nur der App selbst
  zugänglich ist.
- Komponenten: `MainActivity` (Start), `androidx.startup.InitializationProvider` (nicht exportiert) und
  `androidx.profileinstaller.ProfileInstallReceiver` (exportiert, aber durch `android.permission.DUMP` geschützt,
  das nur die Android-Shell und das System halten; dient dem Installieren des Baseline-Profils).
- Optional: „Bildschirmaufnahmen sperren“ setzt `FLAG_SECURE` (verhindert Screenshots und die Vorschau in
  der App-Übersicht).
- Der Brückencode (`MainActivity.kt`) stellt nur den privaten Dateiordner, die Keystore-Umhüllung, die
  Dokumentenauswahl und `FLAG_SECURE` bereit. Beim Öffnen einer Datei gilt eine Obergrenze von 64 MiB.

## 9. Bekannte Grenzen

- **Kein Schutz auf einem kompromittierten Gerät.** Solange die App läuft, liegt der Datenbestand entschlüsselt im
  Arbeitsspeicher. Root-Zugriff, ein Debugger oder Schadsoftware im Prozess können ihn lesen. Für die Keystore-Umhüllung
  gilt: Die Software-Implementierung eines Emulators bietet weniger Schutz als ein Gerät mit TEE oder StrongBox.
- **Keine App-Sperre.** Die App fragt nach dem Start keine PIN und keinen Fingerabdruck. Wer das entsperrte
  Gerät hat, kann die App öffnen. Der Schutz der Ablage beruht auf der Gerätesperre.
- **Kein Schutz vor Zurücksetzen alter Stände.** Wer eine ältere Kopie von `store.mhs` und `store.mhj` sowie
  `master.wrapped` zurückspielt, kann einen früheren Stand herstellen. Eine Erkennung durch einen Zähler außerhalb
  des Datenverzeichnisses gibt es nicht.
- **Metadaten.** Dateigrößen und Änderungszeiten der Ablage sind sichtbar und lassen grobe Rückschlüsse auf die
  Datenmenge zu. Die Kopfdaten des Formats (Kennung, Salt, Sequenz) sind unverschlüsselt.
- **Passphrase.** Die Stärke einer Sicherung ist die Stärke der Passphrase. Argon2id mit 64 MiB und 3 Durchläufen
  bremst Raten, verhindert es aber nicht. Es gibt keine Wiederherstellung einer vergessenen Passphrase.
- **Exportdatei.** Sie ist bewusst unverschlüsselt (maschinenlesbarer Export). Ihr Schutz liegt beim Nutzer.
- **Release-Signatur.** Die APK ist mit dem Debug-Schlüssel des Android-Builds signiert. Sie eignet sich für die
  Prüfung auf dem Referenzgerät und nicht für eine Veröffentlichung in einem Store.
- **Zeitkanäle.** Die GCM- und HKDF-Implementierung von `cryptography` läuft in Dart und verspricht keine
  konstante Laufzeit. Der Vergleich des Schlüsselprüfwerts erfolgt in konstanter Zeit.
- **Wartungszugang.** Die Schlüsseldatei ist ein Klartextgeheimnis im Dateisystem des Aufrufers und gehört mit
  restriktiven Rechten (0600) angelegt. Der Prozess ist für lokale Werkzeuge gedacht und öffnet keinen Port.
