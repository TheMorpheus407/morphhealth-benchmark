# MorphHealth – Sicherheitskonzept

## Schutzziele und Annahmen

MorphHealth speichert Gesundheitsdaten (Ernährung, Zyklus, Gewicht, Symptome) ausschließlich lokal.

- **Vertraulichkeit im Ruhezustand:** Alle Gesundheitsdaten liegen nur verschlüsselt auf dem Datenträger – auch Einstellungen und Dateistruktur (Sammlungsnamen, Anzahl der Einträge) sind nicht im Klartext erkennbar.
- **Integrität:** Jede gespeicherte Einheit ist authentifiziert (AEAD). Manipulation, falscher Schlüssel und Beschädigung werden erkannt und unterschieden, nicht stillschweigend übernommen.
- **Verfügbarkeit bei Abbrüchen:** Absturz oder Stromverlust während eines Schreibvorgangs verliert höchstens die gerade geschriebene Änderung.
- **Datensparsamkeit:** kein Konto, kein Backend, keine Telemetrie, keine Werbung, keine KI-Dienste, keine Plattform-Gesundheitsberechtigungen. Die einzige Netzwerkverbindung ist die optionale, abschaltbare Lebensmittelsuche.
- **Portabilität unter Kontrolle des Nutzers:** Export nur nach ausdrücklicher Bestätigung; Sicherungen sind passphrasen-verschlüsselt und geräteunabhängig.

Nicht abgedeckt: ein kompromittiertes/gerootetes Gerät oder Malware mit Zugriff auf den laufenden App-Prozess, physischer Zugriff auf ein entsperrtes Gerät (kein App-eigener Sperrbildschirm), Seitenkanäle.

## Schlüsselverwaltung

**Android-App.** Beim ersten Start erzeugt `KeyVault.kt` einen zufälligen 256-Bit-Hauptschlüssel (`SecureRandom`). Er wird ausschließlich *eingewickelt* gespeichert: AES-256-GCM mit einem nicht exportierbaren Schlüssel im **Android Keystore** (Alias `morphhealth.master.wrap.v1`, `PURPOSE_ENCRYPT|DECRYPT`, GCM, zufällige IV). Die eingewickelte Form liegt in `noBackupFilesDir` (nie Teil von Gerätesicherungen). Der Hauptschlüssel verlässt das Gerät nie und wird nur im Prozessspeicher entpackt.

**Wartungsprozess `mh`.** Der Hauptschlüssel sind die 32 rohen Bytes der `--key-file`. Die Datei muss außerhalb des Datenverzeichnisses liegen (erzwungen); bei Lesbarkeit für andere Nutzer warnt `mh` auf stderr. Der Starter setzt `umask 077`, sodass angelegte Speicherdateien nur für den Eigentümer lesbar sind.

**Speicherschlüssel.** Aus dem Hauptschlüssel wird je Datenbestand ein eigener AES-256-Schlüssel abgeleitet: `HKDF-SHA256(IKM = Hauptschlüssel, salt = store_id (128 Bit, zufällig), info = "morphhealth/store/v1")`. Ein Prüfwert `HMAC-SHA256(Speicherschlüssel, "morphhealth key check v1")[0..16]` im Kopf erlaubt die eindeutige Meldung „falscher Schlüssel“ (`store_wrong_key`) statt „beschädigt“.

**Löschen.** „Alle Daten löschen“ entfernt Snapshot, Journal und Sicherungskopien beschädigter Journale **und vernichtet den Hauptschlüssel samt Keystore-Schlüssel** (Crypto-Shredding); danach werden ein neuer Schlüssel und ein leerer Speicher angelegt.

## Lokaler Speicher (`morphhealth.store` v1)

Verzeichnis `files/morphhealth_store/` (App) bzw. `--data-dir` (`mh`):

| Datei | Aufbau |
|---|---|
| `morphhealth.snapshot` | `"MHSTORE1"` ‖ `u32` Kopflänge ‖ Kopf (JSON: Format, Version, `store_id`, Generation, Zeitstempel, Algorithmen, Schlüsselprüfwert) ‖ Nonce (12 B) ‖ AES-256-GCM-Chiffrat von `gzip(JSON)` ‖ Tag (16 B). **AAD = Magic + Kopflänge + Kopf** – der Klartextkopf ist damit authentifiziert. Inhalt: `morphhealth.portable`-Dokument und Gerätestatus (Einführung erledigt, gewählter Lebensmittelserver). |
| `morphhealth.journal` | `"MHJRNL01"` ‖ `u32` Kopflänge ‖ Kopf (`store_id`, Generation) ‖ Einträge `u32 Länge ‖ Nonce ‖ Chiffrat ‖ Tag`. Jeder Eintrag ist eine Änderung (Datensatz setzen/löschen, Einstellungen, atomarer Stapel). **AAD = Magic ‖ store_id ‖ Generation (u64) ‖ Sequenznummer (u64)** – Einträge lassen sich weder vertauschen noch aus anderen Journalen/Generationen einschleusen. |
| `morphhealth.lock` | exklusive Dateisperre, solange ein Prozess den Speicher geöffnet hat (`store_locked`). |

Nonces sind 96 Bit zufällig und werden je Verschlüsselung neu erzeugt (weit unter der Grenze von 2³² Nachrichten je Schlüssel).

**Schreibpfad:** Jede Änderung wird zuerst vollständig validiert, dann verschlüsselt ans Journal angehängt und mit `fsync` (`RandomAccessFile.flush`) dauerhaft gemacht, erst danach im Speicher angewendet. Ab 400 Journaleinträgen (und beim Import) wird ein neuer Snapshot in eine temporäre Datei geschrieben, synchronisiert und atomar umbenannt; danach ein leeres Journal der neuen Generation. Ein Journal älterer Generation (Abbruch zwischen beiden Schritten) wird als bereits enthalten erkannt.

**Wiederherstellung:** Ein unvollständiger letzter Journaleintrag (Schreibabbruch) wird abgeschnitten. Ein vollständiger, aber nicht authentifizierbarer Eintrag beendet das Einspielen: frühere Änderungen bleiben erhalten, das Journal wird als `*.damaged-<Zeit>` beiseitegelegt, ein neuer Snapshot geschrieben und eine Warnung ausgegeben. Ein nicht authentifizierbarer Snapshot führt zu `store_corrupted`; die App bietet dann „Erneut versuchen“ oder „Mit leeren Daten neu beginnen“ an (Wiederherstellung aus einer Sicherung möglich).

Auf Android ist das Verzeichnis zusätzlich durch die App-Sandbox geschützt. `android:allowBackup="false"`, `fullBackupContent="false"` und `dataExtractionRules` (Cloud-Backup und Geräteübertragung: alles ausgeschlossen) verhindern, dass verschlüsselte Daten ohne Schlüssel auf andere Geräte gelangen.

## Verschlüsselte Sicherung (`morphhealth.backup` v1, `*.mhbackup`)

```json
{"format":"morphhealth.backup","version":1,"created_at":"…",
 "kdf":{"algorithm":"argon2id","version":19,"memory_kib":65536,"iterations":3,"parallelism":1,"salt":"<Base64, 16 B>"},
 "cipher":{"algorithm":"aes-256-gcm"},"compression":"gzip",
 "payload":"<Base64(Nonce 12 B ‖ Chiffrat ‖ Tag 16 B)>"}
```

- Schlüssel = **Argon2id**(Passphrase, Salz; 64 MiB, 3 Durchläufe, 1 Spur, 32 Byte) – über der OWASP-Mindestempfehlung (19 MiB/2). Passphrase mindestens 10 Zeichen; die App weist darauf hin, dass sie nicht wiederherstellbar ist.
- **AAD = kanonisches JSON aller Kopffelder** außer `payload`: Parameter (z. B. geschwächte KDF-Werte) oder Datum lassen sich nicht unbemerkt ändern.
- Klartext = `gzip(morphhealth.portable)`; unabhängig vom Gerätschlüssel und daher für eine frische Installation geeignet (auf dem Referenzgerät mit Deinstallation/Neuinstallation geprüft).
- Beim Einlesen werden KDF-Parameter auf plausible Grenzen geprüft (8 MiB–1 GiB, 1–20 Durchläufe, 1–8 Spuren), um Ressourcenmissbrauch durch präparierte Dateien zu verhindern. Falsche Passphrase und manipulierte Datei ergeben dieselbe Meldung.
- Schlüsselableitung, Entschlüsselung und Validierung laufen in einem Hintergrund-Isolate.

## Unverschlüsselter Export

`Daten exportieren (JSON)` bzw. `portable.export` erzeugen das vollständige Klartextdokument nur nach ausdrücklicher Bestätigung (Warnhinweis in der App, `ack_plaintext: true` im Protokoll). Speicherort wählt der Nutzer über das Android-Dokumentsystem (SAF); die App benötigt keine Speicherberechtigung. Import (`confirm_replace: true`) validiert das Dokument vollständig, bevor es den Bestand ersetzt.

## Netzwerk

- Einzige Gegenstelle: der konfigurierte Open-Food-Facts-kompatible Server, **nur lesend** (`GET /api/v3.6/product/{barcode}.json`, `GET /cgi/search.pl?…`). Übertragen werden nur Suchbegriff bzw. Barcode, Seite, Feldprojektion und der User-Agent – keine Tagebuchdaten, keine Kennungen.
- Nur **HTTPS**; die TLS-Zertifikatsprüfung des Systems bleibt aktiv (keine Ausnahmen, kein Pinning-Bypass). Server-Adressen werden auf HTTPS-Origins geprüft.
- Anfragen nur auf ausdrückliche Nutzeraktion; die Online-Suche lässt sich in der Einführung und in den Einstellungen abschalten (dann keinerlei Netzwerkzugriff; auch `mh` respektiert die Einstellung des Datenbestands).
- Keine Produktbilder, keine Analyse-, Absturz- oder Werbe-SDKs. Einzige Android-Berechtigung: `INTERNET` (die von AndroidX automatisch ergänzte `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` ist eine interne Signaturberechtigung). Exportiert sind nur die Start-Activity und der von AndroidX eingebrachte `ProfileInstallReceiver` (Laufzeitprofile, nur mit der Systemberechtigung `DUMP` aufrufbar).

## Verwendete Bibliotheken

| Bibliothek | Version (`pubspec.lock`) | Zweck |
|---|---|---|
| Flutter SDK / Dart SDK | 3.41.9 / 3.11.5 | Oberfläche, `dart:io` (Dateien, HTTP/TLS, gzip) |
| `cryptography` | 2.9.0 | AES-256-GCM (`DartAesGcm`), Argon2id (`DartArgon2id`) – reine Dart-Implementierung, identisch auf Android und Linux |
| `crypto` (dart-lang) | 3.0.7 | SHA-256/HMAC für HKDF (RFC 5869) und Schlüsselprüfwert |
| `http` (dart-lang) | 1.6.0 | HTTP-Client für Open Food Facts |
| `intl` | 0.20.2 | Datums- und Zahlenformate DE/EN |
| `flutter_localizations` | SDK | Material-Texte DE/EN |
| Android Keystore, SAF | Android-Plattform | Schlüsselschutz, Dateiauswahl (eigener schlanker Kotlin-Code, keine Plugins) |

Die Korrektheit der verwendeten Primitive wird in `app/test/core/basics_test.dart` gegen offizielle Testvektoren geprüft: HKDF (RFC 5869, Fall 1), AES-256-GCM (NIST SP 800-38D, `gcmEncryptExtIV256` Count 0), Argon2id (RFC 9106, 5.3). Weitere Tests decken Manipulations-, Abbruch- und Falschschlüssel-Fälle ab (`store_test.dart`, `portable_test.dart`) sowie – auf dem Referenzgerät – dass die App-Dateien keine Klartextdaten enthalten (`integration_test/app_flow_test.dart`).

## Bekannte Grenzen

- Kein App-eigener Sperrbildschirm und kein `FLAG_SECURE`: Wer das entsperrte Gerät in der Hand hat, sieht die Daten; Bildschirmfotos und die App-Vorschau sind möglich.
- Während die App läuft, liegen Daten und Hauptschlüssel entschlüsselt im Arbeitsspeicher (Dart hat keine sichere Speicherlöschung).
- Die reine Dart-Kryptografie ist nicht gegen Seitenkanäle (z. B. Timing) gehärtet; für ein lokales Einzelnutzer-Tagebuch ohne Angreifer im selben Prozess ist das vertretbar.
- Das Abschneiden des Journals um vollständige letzte Einträge durch einen Angreifer mit Schreibzugriff wäre nicht erkennbar (Rollback der letzten Änderungen); Vertraulichkeit bleibt gewahrt.
- Verliert der Keystore den Schlüssel (Gerät zurückgesetzt, Nutzerprofil entfernt), sind lokale Daten unwiederbringlich – Absicht, aber ein Verfügbarkeitsrisiko. Abhilfe ist die verschlüsselte Sicherung.
- Der unverschlüsselte Export ist nach dem Speichern außerhalb der Kontrolle der App.
- Für `mh` liegt die Verantwortung für die Schlüsseldatei beim Aufrufer (Dateirechte, Aufbewahrung außerhalb des Datenverzeichnisses).
