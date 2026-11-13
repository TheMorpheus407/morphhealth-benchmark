# Sicherheitskonzept — MorphHealth

Dieses Dokument beschreibt die Sicherheitsarchitektur, die eingesetzten Bibliotheken, die Schlüsselverwaltung sowie die verschlüsselten Speicher- und Sicherungsformate von MorphHealth (`de.themorpheus.morphhealth.local` und lokaler Wartungszugang `./mh`).

## 1. Sicherheitsziele und Bedrohungsmodell

MorphHealth verarbeitet persönliche Gesundheitsdaten einer einzelnen Person auf deren eigenem Gerät (Ernährungsprotokolle, Wasser- und Koffeinaufnahme, Zyklus- und Blutungsaufzeichnungen, Körpergewicht sowie Symptome).

Die Architektur verfolgt folgende Grundsätze:

- **Vollständige Datenhaltung auf dem Endgerät:** Es existieren weder Benutzerkonten noch eigene Cloud-Dienste, Werbenetzwerke, Telemetrie-Endpunkte oder Laufzeit-KI-Anbindungen.
- **Verschlüsselung ruhender Daten (Encryption at Rest):** Alle lokalen Gesundheitsdaten, eigenen Lebensmittel, Ziele und Einstellungen liegen im Arbeitsverzeichnis ausschließlich authentifiziert verschlüsselt vor (`vault.mhv1` und `vault.wal.mhv1`). Klartextdateien werden im Arbeitsverzeichnis zu keinem Zeitpunkt abgelegt.
- **Kryptografische Trennung zwischen Gerätespeicher und Sicherung:** Der lokale Tresor nutzt einen zufälligen 256-Bit-Hauptschlüssel, während portable Sicherungen über eine vom Nutzer gewählte Passphrase mit `Argon2id` geschützt werden und sich dadurch auf einer frischen Installation unabhängig vom ursprünglichen Geräteschlüssel wiederherstellen lassen.
- **Kontrollierte Netzwerkkommunikation:** Netzwerkzugriffe finden ausschließlich für lesende Produktsuchen und Barcode-Abrufe gegen den konfigurierten Open-Food-Facts-HTTPS-Origin statt und lassen sich in den Datenschutzeinstellungen vollständig deaktivieren.

Ausgenommen vom lokalen Schutzmodell sind Angreifer mit aktivem Root-Zugriff zur Laufzeit der entsperrten Anwendung sowie kompromittierte Betriebssystemkerne, die den Arbeitsspeicher des laufenden Prozesses direkt auslesen können.

---

## 2. Verwendete Bibliotheken und Plattformkomponenten

Alle kryptografischen Verfahren entstammen etablierten Standardbibliotheken und sind in `app/pubspec.lock` festgeschrieben:

| Komponente / Paket | Version | Einsatzbereich |
|---|---|---|
| `package:cryptography` | `2.9.0` | `ChaCha20-Poly1305` (RFC 8439), `HKDF-SHA256` (RFC 5869) und `Argon2id` (RFC 9106) im gemeinsamen Kern für Android und `./mh` |
| `package:crypto` | `3.0.7` | Prüf- und Hash-Hilfsfunktionen |
| `dart:math` (`Random.secure()`) | Dart SDK `3.11.5` | Kryptografisch sichere Zufallszahlen für Nonces, Salts, Epochenkennungen und Schlüsselmaterial |
| `dart:io` (`gzip`, `SecurityContext`) | Dart SDK `3.11.5` | Kompression vor der Verschlüsselung sowie reguläre TLS-Zertifikatsprüfung über den Betriebssystem-Vertrauensspeicher |
| `AndroidKeyStore` (`javax.crypto.Cipher`) | Android API 26–35 | Hardware- bzw. systemgeschützter 256-Bit-AES-GCM-Schlüssel zum Einhüllen des lokalen Tresor-Hauptschlüssels |

Android-App (`app/lib/main.dart`) und Wartungsprozess (`./mh` über `app/bin/mh.dart`) teilen sich identischen Code in `app/lib/core/crypto_vault.dart` und `app/lib/core/store.dart`.

---

## 3. Schlüsselverwaltung und Ableitungshierarchie

### 3.1 Hauptschlüssel unter Android

Beim ersten App-Start erzeugt `MainActivity.kt` über `java.security.SecureRandom` einen 32 Byte (256 Bit) langen Zufallsschlüssel (`rawKey`). Dieser Hauptschlüssel wird unmittelbar mit einem nicht exportierbaren Schlüssel des Android Keystore verschlüsselt:

- **Keystore-Provider:** `AndroidKeyStore`
- **Alias:** `morphhealth_master_wrap_v1`
- **Algorithmus:** `AES/GCM/NoPadding`, Schlüssellänge 256 Bit, Authentifizierungs-Tag 128 Bit
- **Ablageort der eingehüllten Schlüsseldatei:** `Context.noBackupFilesDir/master_key.wrapped`
- **Binäraufbau von `master_key.wrapped`:**
  1. `1 Byte`: Länge des Initialisierungsvektors (`12..16`)
  2. `IV`: vom Keystore-Cipher erzeugter GCM-Initialisierungsvektor
  3. `Ciphertext || Tag`: verschlüsselter 32-Byte-Hauptschlüssel inklusive 16-Byte-GCM-Tag

Zusätzlich unterbindet `AndroidManifest.xml` über `android:allowBackup="false"`, `android:fullBackupContent="false"` und `res/xml/data_extraction_rules.xml` jede unbemerkte Cloud- oder Geräteübertragung der Tresordateien.

### 3.2 Hauptschlüssel im lokalen Wartungszugang (`./mh`)

Der Prozess `./mh` erhält den 32-Byte-Hauptschlüssel explizit über `--key-file ABS`:

- Die Datei muss exakt **32 rohe Bytes** enthalten (`VaultCrypto.masterKeyLength = 32`). Abweichende Dateigrößen werden mit `INVALID_KEY_LENGTH` abgewiesen.
- Vor dem Öffnen des Datenbestands prüft `app/bin/mh.dart` anhand kanonisierter Pfade, dass `--key-file` **außerhalb** von `--data-dir` liegt. Liegt die Schlüsseldatei innerhalb des Datenverzeichnisses, beendet sich `./mh` sofort mit Fehlercode `2`.
- Erzeugung einer geeigneten Schlüsseldatei unter Linux:
  ```bash
  umask 077
  head -c 32 /dev/urandom > /pfad/ausserhalb/data-dir/morphhealth.key
  ```

### 3.3 Teilschlüsselableitung mittels HKDF-SHA256

Aus dem 32-Byte-Hauptschlüssel und einem pro Tresor-Epoche frisch erzeugten 16-Byte-Zufallssalt leitet `VaultCrypto` über `HKDF-SHA256` (RFC 5869, Ausgabelänge 32 Byte) zwei strikt getrennte Teilschlüssel ab:

- **Snapshot-Schlüssel:** `info = "morphhealth.vault.snapshot.v1"`
- **WAL-Schlüssel:** `info = "morphhealth.vault.wal.v1"`

Bei jeder Snapshot-Neuschreibung erzeugt der Speicher eine neue zufällige 16-Byte-`epochId`, ein neues 16-Byte-`salt` und frische 12-Byte-Nonces.

---

## 4. Verschlüsselte Dateiformate im Arbeitsverzeichnis (`data-dir`)

Im Verzeichnis `data-dir` (unter Android `filesDir/vault_data/`) existieren ausschließlich folgende Binärdateien:

### 4.1 Snapshot-Datei `vault.mhv1`

`vault.mhv1` speichert den gesamten Arbeitsdatenbestand Gzip-komprimiert und mit `ChaCha20-Poly1305` (RFC 8439) authentifiziert verschlüsselt.

| Byte-Offset | Länge | Feld | Beschreibung |
|---|---|---|---|
| `0..7` | 8 B | `magic` | ASCII-Kennung `MHVAULT1` |
| `8` | 1 B | `version` | Formatversion `0x01` |
| `9..24` | 16 B | `epoch_id` | Zufällige Kennung der aktuellen Snapshot-Epoche |
| `25..40` | 16 B | `hkdf_salt` | Zufälliges Salt für `HKDF-SHA256` |
| `41..52` | 12 B | `nonce` | Zufällige 96-Bit-Nonce für `ChaCha20-Poly1305` |
| `53..68` | 16 B | `poly1305_tag` | 128-Bit-Authentifizierungs-Tag |
| `69..Ende` | variabel | `ciphertext` | Verschlüsseltes Gzip-Archiv des UTF-8-kodierten Tresor-JSON |

- **Additional Authenticated Data (AAD):** Die gesamten 53 Header-Bytes (`0..52`) werden als AAD übergeben. Jede Veränderung an Header, Version, Epoche, Salt, Nonce oder Chiffrat führt bei der Entschlüsselung sofort zu `VaultSecurityException('AUTH_FAILED')`.
- **Atomare Schreibweise:** Neue Snapshots werden zunächst vollständig nach `vault.mhv1.tmp` geschrieben (`flush: true`) und anschließend atomar auf `vault.mhv1` umbenannt.

### 4.2 Authentifiziertes Journal `vault.wal.mhv1`

Einzelne Mutationen im Alltag (etwa schnelles Wasser-Erfassen oder Bearbeiten eines Eintrags) werden als verschlüsselte Delta-Frames an `vault.wal.mhv1` angehängt. Nach jeweils 40 Journal-Einträgen kompaktiert `MorphHealthStore` den Bestand automatisch in einen frischen `vault.mhv1`-Snapshot und entfernt das Journal.

**Datei-Header (25 Bytes):**

| Byte-Offset | Länge | Feld | Beschreibung |
|---|---|---|---|
| `0..7` | 8 B | `magic` | ASCII-Kennung `MHWAL001` |
| `8` | 1 B | `version` | Formatversion `0x01` |
| `9..24` | 16 B | `epoch_id` | Muss exakt mit `epoch_id` aus `vault.mhv1` übereinstimmen |

**Aufbau jedes folgenden WAL-Frames:**

| Relativer Offset | Länge | Feld | Beschreibung |
|---|---|---|---|
| `0..3` | 4 B | `cipher_len` | Länge des Frame-Chiffrats (`uint32`, Big Endian) |
| `4..11` | 8 B | `sequence` | Lückenlos aufsteigende Sequenznummer ab `1` (`uint64`, Big Endian) |
| `12..23` | 12 B | `nonce` | Frische 96-Bit-Zufallsnonce pro Frame |
| `24..39` | 16 B | `poly1305_tag` | 128-Bit-Authentifizierungs-Tag |
| `40..40+N-1` | `N` B | `ciphertext` | `ChaCha20`-Chiffrat der UTF-8-JSON-Mutationsoperation |

- **Frame-AAD:** `MHWAL001 || version (1 B) || epoch_id (16 B) || sequence (8 B) || nonce (12 B)`.
- **Schutz vor Replay, Kürzung und Umordnung:** Beim Öffnen prüft `VaultCrypto.decryptWalFile`, dass `epoch_id` zur aktuellen Snapshot-Epoche gehört und `sequence` lückenlos bei `1` beginnt und um jeweils `1` steigt. Manipulierte, vertauschte oder abgeschnittene Frames brechen das Laden mit `WAL_SEQUENCE_MISMATCH`, `WAL_AUTH_FAILED` oder `CORRUPT_WAL` ab.

---

## 5. Passphrasengeschützte Sicherung (`morphhealth.encrypted-backup`)

Für den sicheren Transport auf ein neues Gerät oder eine frische Installation erzeugt `EncryptedBackupCodec` JSON-Umschläge mit der Dateierweiterung `.mhbackup.json`:

```json
{
  "format": "morphhealth.encrypted-backup",
  "schema_version": 1,
  "created_at": "2026-09-23T10:00:00+02:00",
  "kdf": {
    "algorithm": "Argon2id",
    "memory_kib": 32768,
    "parallelism": 2,
    "iterations": 3,
    "salt_b64": "<16 Byte Base64>"
  },
  "cipher": {
    "algorithm": "ChaCha20-Poly1305",
    "compression": "gzip",
    "nonce_b64": "<12 Byte Base64>",
    "tag_b64": "<16 Byte Base64>"
  },
  "ciphertext_b64": "<Base64 des verschlüsselten Gzip-Payloads>"
}
```

Sicherheitsmerkmale des Formats:

- **Speicherharte Schlüsselableitung:** `Argon2id` mit `32 MiB` Arbeitsspeicher (`32768 KiB`), `2` Spuren (`parallelism = 2`), `3` Durchläufen (`iterations = 3`) und 16 Byte Zufallssalt erschwert Offline-Wörterbuchangriffe erheblich.
- **Parameter-Grenzen beim Einlesen:** Vor der Ausführung von `Argon2id` validiert der Decoder strikte Obergrenzen (`1024 <= memory_kib <= 524288`, `1 <= parallelism <= 16`, `1 <= iterations <= 32`), um Denial-of-Service-Angriffe durch präparierte Sicherungsdateien auszuschließen.
- **Authentifizierte Metadaten:** Der kanonische String
  `morphhealth.encrypted-backup|v1|Argon2id|<memory_kib>|<parallelism>|<iterations>|<salt_b64>|<nonce_b64>`
  wird als AAD an `ChaCha20-Poly1305` gebunden.

---

## 6. Portabler Klartext-Export, Löschfunktion und Transportsicherheit

- **Bewusste Freigabe bei unverschlüsseltem Export:** Das maschinenlesbare Austauschformat `morphhealth.portable` speichert JSON im Klartext. Sowohl die Android-Oberfläche (Bestätigungsdialog mit Kontrollkästchen) als auch `./mh` (`"ack_plaintext": true`) verlangen vor der Ausgabe eine ausdrückliche Bestätigung. Ebenso erfordert ein ersetzender Import eine explizite Bestätigung (`"confirm_replace": true`).
- **Vollständiges Löschen und Schlüsselwechsel:** Die Funktion *Gesamten lokalen Datenbestand löschen* in den Einstellungen leert sämtliche Tabellen im Arbeitsspeicher, löscht `vault.mhv1` und `vault.wal.mhv1`, rotiert über `rotateMasterKey` den Android-Keystore-Schlüssel samt `master_key.wrapped` und legt einen frischen leeren Tresor unter dem neuen Schlüssel an.
- **Strikte TLS-Prüfung:** `OpenFoodFactsClient` erzwingt das `https`-Schema für alle konfigurierten Origins und verwendet ausnahmslos die reguläre Zertifikatsvalidierung des Betriebssystems ohne benutzerdefinierte `badCertificateCallback`-Ausnahmen.
