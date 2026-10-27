# MorphHealth – Sicherheitskonzept

## Schutzziele und Modell

MorphHealth verarbeitet persönliche Gesundheitsdaten für genau einen Nutzer pro Installation. Die Ziele sind:

1. Keine unverschlüsselte dauerhafte Ablage von Gesundheitsdaten durch die App.
2. Keine Übertragung von Tagebuchdaten an einen Dienst.
3. Explizite Nutzerkontrolle über Online-Suche, Klartextexport, Ersatz-Import und Löschung.
4. Vollständige, passphrasegeschützte Übertragbarkeit auf eine frische Installation.

Das Modell schützt vor dem Auslesen der App-Dateien auf einem nicht entsperrten beziehungsweise nicht kompromittierten Gerät und vor unbeabsichtigter Weitergabe. Es schützt nicht gegen einen entsperrten Nutzer, Root/Systemkompromittierung, Speicherzugriff im laufenden Prozess, Screenshots oder eine manipulierte Laufzeitumgebung. Während der Nutzung liegen Daten notwendigerweise entschlüsselt im Prozessspeicher vor.

## Bibliotheken

Direkte, in `app/pubspec.lock` eingelockte Implementierungen:

| Bibliothek | Version | Verwendung |
|---|---:|---|
| `cryptography` | 2.9.0 | AES-256-GCM, PBKDF2-HMAC-SHA256, MAC/SecretBox |
| `flutter_secure_storage` | 9.2.4 | Schutz des Android-Datenbankschlüssels |
| `path_provider` | 2.1.6 | Privates Android-Application-Support-Verzeichnis |
| `http` | 1.6.0 | Ausschließlich lesende HTTPS-Anfragen |
| `file_picker` | 9.2.3 | Android `OPEN_DOCUMENT`/`CREATE_DOCUMENT` für Export und Import |
| `provider` | 6.1.5+1 | UI-Zustand, keine Sicherheitsfunktion |
| `intl` / `flutter_localizations` | 0.20.2 / SDK | Lokalisierte Darstellung |

Es gibt keine Werbe-, Analyse-, Telemetrie-, Konto-, Health-Connect-, Kamera-, Standort- oder Laufzeit-KI-SDKs. Das Android-Manifest verlangt lediglich die Berechtigung `INTERNET` für die ausdrücklich aufgerufene Lebensmittelsuche. Es werden keine Plattform-Gesundheitsberechtigungen verwendet.

## Interner verschlüsselter Datenbestand

Datei im privaten Application-Support-Verzeichnis:

```text
state.enc
```

Beim CLI liegt sie unter `--data-dir/state.enc`.

Envelope:

```json
{
  "format": "morphhealth.encrypted-state.v1",
  "nonce_b64": "Base64, 12 Bytes",
  "ciphertext_b64": "Base64",
  "mac_b64": "Base64, 16 Bytes"
}
```

- Algorithmus: **AES-256-GCM**.
- Schlüssel: 32 zufällige Bytes.
- Nonce: 96 Bit, für jeden Schreibvorgang neu aus `Random.secure()`; kein Nonce-Recycling nach Design.
- Authentikationstag: 128 Bit.
- Additional Authenticated Data: ASCII/UTF-8 `morphhealth.encrypted-state.v1`.
- Klartext: vollständiges versioniertes `AppState`-JSON.
- Jeder Schreibvorgang erfolgt in `state.enc.tmp`, mit Flush und anschließendem atomaren Rename. Repository-Schreibvorgänge sind serialisiert. Ein ungültiger oder falsch authentifizierter Bestand wird nicht stillschweigend durch einen leeren ersetzt.

GCM stellt Vertraulichkeit und Integrität bereit. Eine veränderte Datei oder ein falscher Schlüssel führt zu einem Fehler statt zur Übernahme manipulierter Daten.

## Schlüsselverwaltung

### Android

Beim ersten Start erzeugt die App 32 Bytes mit einem kryptographisch sicheren Zufallsgenerator. Sie werden Base64-kodiert unter `morphhealth_database_key_v1` mit `flutter_secure_storage` abgelegt. Auf Android ist `encryptedSharedPreferences: true` aktiv; `resetOnError` ist bewusst `false`, damit ein Schlüssel-/Entschlüsselungsfehler nicht zum Datenverlust führt. Die Pluginspeicherung wird durch den Android Keystore geschützt.

Der Base64-Text ist nur ein Transportformat des rohen Schlüssels, keine zusätzliche Verschlüsselung. Die APK enthält keinen festen Gesundheitsdatenschlüssel.

Android Cloud Backup und Gerätetransfer sind für App-Daten deaktiviert:

- `android:allowBackup="false"`
- `android:fullBackupContent="false"`
- `data_extraction_rules.xml` schließt interne Dateien, Datenbanken, Shared Preferences und externe App-Daten aus.

Das verhindert ein unbeabsichtigtes Wiederherstellen des Ciphertexts ohne passenden Keystore-Schlüssel und unerwartete Cloud-Kopien.

### CLI

`--key-file` muss eine andere Datei als Teil von `--data-dir` sein und exakt 32 **rohe Bytes** enthalten. Sie ist kein Passwort und keine Hex-/Base64-Datei. Der Aufruf prüft absolute Pfade, Länge und die räumliche Trennung. Die Dateiberechtigungen und die Aufbewahrung liegen beim Betreiber des Linux-Prozesses; die README empfiehlt `umask 077`.

Der CLI-Bestand ist nicht automatisch derselbe Pfad wie der Android-Bestand. Das Format und die produktiven Funktionen sind identisch. Eine Übertragung erfolgt kontrolliert über Portable V1 oder ein Backup, nicht durch Kopieren ohne passenden Schlüssel.

## Passphrasegeschützte Sicherung

Dateiname in der App:

```text
morphhealth-<UTC-Zeit>.encrypted-backup.json
```

Format: `morphhealth.encrypted-backup.v1`

```json
{
  "format": "morphhealth.encrypted-backup.v1",
  "kdf": {
    "name": "PBKDF2-HMAC-SHA256",
    "iterations": 600000,
    "salt_b64": "Base64, 16 Bytes"
  },
  "cipher": "AES-256-GCM",
  "nonce_b64": "Base64, 12 Bytes",
  "mac_b64": "Base64, 16 Bytes",
  "ciphertext_b64": "Base64"
}
```

- KDF: **PBKDF2-HMAC-SHA256 mit 600.000 Iterationen**, 256 Bit Ausgabe.
- Salt: 16 zufällige Bytes je Sicherung.
- Passphrase: UTF-8 ohne heimliche Normalisierung; die Android-Eingabe verlangt mindestens 8 Zeichen und bestätigt sie zweimal.
- Verschlüsselung: AES-256-GCM, 96-Bit-Zufallsnonce und 128-Bit-Tag.
- AAD: `morphhealth.encrypted-backup.v1`.
- Der verschlüsselte Klartext ist ein vollständiges `morphhealth.portable.v1`-Dokument einschließlich Einstellungen, Lebensmitteln und Snapshots.

Der Envelope erlaubt auch beim Import eine Iterationsgrenze von 100.000 bis 5.000.000, damit Parameteränderungen und Denial-of-Service durch absurde Werte beherrscht werden. Salt-, Nonce- und MAC-Längen werden geprüft. Entschlüsselung und Portable-Validierung müssen vor dem Ersatz erfolgreich sein.

Eine Passphrase kann nicht zurückgesetzt werden. Die App speichert sie nicht und überträgt sie nicht. Schwache Passphrasen bleiben trotz KDF grundsätzlich angreifbarer; eine lange, einzigartige Passphrase wird empfohlen.

## Klartextexport und Import

`morphhealth.portable.v1` enthält alle Gesundheitsdaten **unverschlüsselt**. Der Android-Export verlangt eine gesonderte Bestätigung; `portable.export` verlangt `ack_plaintext: true`. Exporte werden ausschließlich über den vom Nutzer gewählten Dokumentzielort geschrieben. Die App veröffentlicht keine Datei selbständig.

Import und Wiederherstellung validieren Formatversion, Typen, IDs, Referenzen, Nährstoff-IDs, Zahlenbereiche und Periodenüberlappungen vollständig. Erst danach ersetzt ein serialisierter, atomarer Schreibvorgang den Bestand. Ein fehlerhafter Import lässt den alten Bestand unverändert. `confirm_replace: true` ist beim CLI zusätzlich vorgeschrieben.

Das Löschen des App-Bestands betrifft den privaten internen Zustand und die Einstellungen. Bereits vom Nutzer exportierte Dateien liegen außerhalb des App-Speichers und bleiben erhalten; sie müssen gegebenenfalls separat am jeweiligen Speicherort gelöscht werden.

## Netzwerk und Open Food Facts

- Nur HTTPS-Origins ohne Benutzerinformationen, Pfad, Query oder Fragment werden akzeptiert.
- Zertifikats- und Hostnameprüfung verwenden den normalen Systemvertrauensspeicher. Es gibt keinen `badCertificateCallback`, kein Deaktivieren von TLS und keine installierte Sondervertrauensregel durch die App.
- Es werden ausschließlich `GET /cgi/search.pl` und `GET /api/v3.6/product/{barcode}.json` aufgerufen.
- Der User-Agent kommt aus der Build-/CLI-Konfiguration. `Accept: application/json` wird gesetzt.
- Übertragen werden Suchtext beziehungsweise Barcode. Tagebuch, Notizen, Symptome, Zeitraumdaten, Schlüssel und Backups werden nicht gesendet.
- Produktbilder werden nicht geladen. Eigene Lebensmittel werden nicht an Open Food Facts hochgeladen.
- Die Online-Freigabe kann deaktiviert werden; UI und CLI respektieren den Schalter. Ohne Freigabe schlagen Food-Operationen mit `online_disabled` fehler beziehungsweise die UI erklärt den Zustand.
- Requests laufen mit 20-Sekunden-Timeout. HTTP-, JSON-, Netzwerk- und Timeoutfehler werden getrennt behandelt.

Open Food Facts ist eine externe Datenquelle. Die Vertraulichkeit eines Suchbegriffs gegenüber diesem Dienst und die Richtigkeit der Crowdsourcedaten liegen außerhalb der lokalen Schutzgarantie.

## Signaturen und Abhängigkeiten

Die Abgabe ist ein Flutter-Release-Build mit x86_64-Unterstützung und wird vor der Auslieferung mit `aapt` und ZIP-Prüfung auf Package-ID und native Bibliotheken kontrolliert. Für die lokale Installation verwendet sie den Debug-/Entwicklungssignaturschlüssel der bereitgestellten Flutter-Umgebung. Das ist keine produktive Store-Signatur; ein organisatorischer Release-Signaturprozess gehört nicht zum Auftrag.

Direkte Versionen sind in `app/pubspec.yaml` fixiert, transitive Versionen vollständig in `app/pubspec.lock` eingeschlossen. Builds verwenden `flutter pub get --enforce-lockfile`.

## Bewusste Grenzen

- Kein Schutz gegen kompromittierte Betriebssysteme, Root, Speicherlesezugriff oder bösartige Eingabemethoden.
- Keine zusätzliche App-Sperre oder biometrische Authentifizierung; die Android-Gerätesperre und der verschlüsselte private Speicher bilden die Zugriffsschicht.
- Keine Screenshot-Sperre; dies würde die geforderte Bildschirmabnahme behindern und ist kein Ersatz für physische Gerätekontrolle.
- Kein Mehrbenutzer- oder Multi-Device-Synchronisationsmodell.
- Sicherungsstärke hängt von der Passphrase ab; Klartextexporte erfordern besondere Sorgfalt am Zielspeicher.
