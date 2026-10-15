# MorphHealth — Sicherheitskonzept (`SECURITY.md`)

## 1. Sicherheitsarchitektur und Grundsätze

MorphHealth ist als vollständig lokale Einzelplatz-Anwendung ohne Benutzerkonto, ohne eigenen Backend-Dienst, ohne Telemetrie, ohne Werbe-SDKs und ohne Laufzeit-KI konzipiert:

1. **Vollständige Verschlüsselung im Ruhezustand (Encryption at Rest)**:
   Alle persönlichen Gesundheits- und Tagebuchdaten im Arbeitsverzeichnis (`data-dir`) werden ausschließlich verschlüsselt in der Datei `vault.mhv` mittels **AES-256-GCM** (Authenticated Encryption with Associated Data, NIST SP 800-38D) abgelegt. Es werden zu keinem Zeitpunkt unverschlüsselte Gesundheitsdaten in `data-dir` gespeichert.
2. **Strikte Trennung von Datenbestand und Schlüsselmaterial**:
   Der 256-Bit-Hauptschlüssel (32 rohe Bytes) liegt außerhalb des Arbeitsdatenverzeichnisses (`data-dir`):
   - **Android**: Der 32-Byte-Schlüssel wird beim ersten Start über den kryptographisch sicheren Zufallszahlengenerator (`Random.secure()`) erzeugt und in `Context.noBackupFilesDir/morphhealth_master.key` abgelegt, getrennt vom Arbeitsverzeichnis `Context.filesDir/morphhealth_data`. Zusätzlich sind in `AndroidManifest.xml` `android:allowBackup="false"` und `android:fullBackupContent="false"` gesetzt.
   - **Lokaler Wartungszugang (`./mh`)**: Der Pfad zur Schlüsseldatei wird über `--key-file ABS` übergeben. `CryptoVault.loadOrCreateMasterKey` prüft vor jedem Zugriff, dass `--key-file` **außerhalb** von `--data-dir` liegt und exakt **32 rohe Bytes** umfasst. Liegt die Schlüsseldatei innerhalb von `--data-dir`, hat sie eine abweichende Länge oder schlägt die GCM-Authentifizierung einer bestehenden `vault.mhv` fehl, bricht der Prozess sofort mit einem Fehlercode ungleich `0` ab.
3. **Lesende, abschaltbare Online-Lebensmittelanbindung**:
   Netzwerkzugriffe erfolgen ausschließlich lesend (`GET`) an den konfigurierten Open-Food-Facts-Origin (`food_api_base_url` aus `ENVIRONMENT.json`). Persönliche Gesundheitsdaten (Gewicht, Zyklus, Symptome, Tagebucheinträge) verlassen das Gerät nie. Die Online-Lebensmittelsuche lässt sich in den Einstellungen jederzeit deaktivieren.
4. **Unveränderte TLS-Zertifikatsprüfung**:
   Sowohl die Android-Anwendung als auch `./mh` verwenden die reguläre TLS-Zertifikatsprüfung des Betriebssystems ohne Deaktivierung oder Umgehung von Zertifikatsprüfungen.

---

## 2. Verwendete Bibliotheken

Die kryptographischen Verfahren sind in reinem Dart implementiert und werden identisch im Android-Build und im Linux-Wartungszugang (`./mh`) ausgeführt (Versionen in `app/pubspec.lock` gesperrt):

| Bibliothek | Gesperrte Version | Zweck |
|---|---|---|
| `cryptography` | `2.9.0` | `AesGcm.with256bits()` für AES-256-GCM (Vault-Verschlüsselung & Backup-Verschlüsselung) sowie `Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256)` für passphrasengeschützte Sicherungen |
| `crypto` | `3.0.7` | Kryptographische Hash- und HMAC-Primitiven (SHA-256) |
| `dart:math` (`Random.secure()`) | Dart SDK `3.11.5` | Kryptographisch sicherer Zufallszahlengenerator des Betriebssystems (`/dev/urandom`) für Schlüssel (32 B), Nonces (12 B) und Salts (16 B) |
| `dart:io` (`gzip`) | Dart SDK `3.11.5` | Verlustfreie Komprimierung des JSON-Payloads vor der AES-256-GCM-Verschlüsselung |

---

## 3. Verwendung der Schlüsseldatei (`--key-file`)

Die Schlüsseldatei enthält exakt **32 rohe Bytes** (256 Bit) ohne Zeilenumbruch oder Textkodierung und muss außerhalb von `--data-dir` liegen.

### Erzeugen einer neuen 32-Byte-Schlüsseldatei

```bash
head -c 32 /dev/urandom > /pfad/ausserhalb/data-dir/master.key
chmod 600 /pfad/ausserhalb/data-dir/master.key
```

### Aufruf mit `./mh`

```bash
./mh --data-dir /pfad/zu/data-dir --key-file /pfad/ausserhalb/data-dir/master.key
```

- Existiert `vault.mhv` in `--data-dir` bereits, muss `--key-file` exakt den zugehörigen 32-Byte-Schlüssel enthalten; andernfalls schlägt die AES-GCM-Authentifizierung fehl.
- Existiert in einem frischen `--data-dir` noch keine `vault.mhv` und `--key-file` ist bereits als 32-Byte-Datei vorhanden, wird dieser Schlüssel verwendet.

---

## 4. Dateiformate

### 4.1 Verschlüsselter Arbeitsdatenbestand (`<data-dir>/vault.mhv`)

Die Datei `vault.mhv` ist ein binäres AEAD-Containerformat (`MHV1`). Schreibvorgänge erfolgen atomar über `<data-dir>/vault.mhv.tmp` mit anschließendem `rename` auf `<data-dir>/vault.mhv`.

| Byte-Offset | Länge | Inhalt | Beschreibung |
|---|---|---|---|
| `0..3` | 4 Bytes | `0x4D 0x48 0x56 0x31` | ASCII-Magic `"MHV1"` |
| `4` | 1 Byte | `0x01` | Formatversion `1` |
| `5` | 1 Byte | `0x01` | Flags (`Bit 0 = 1`: Payload ist `gzip`-komprimiert) |
| `6..17` | 12 Bytes | `Nonce` | 96-Bit zufälliger Initialisierungsvektor (`Random.secure()`), bei jedem Speichern neu erzeugt |
| `18..33` | 16 Bytes | `GCM Tag` | 128-Bit AES-GCM Authentifizierungs-Tag (MAC) |
| `34..Ende` | variabel | `Ciphertext` | AES-256-GCM-verschlüsselter, `gzip`-komprimierter UTF-8-JSON-Datenbestand (`morphhealth.portable.v1`) |

- **Associated Authenticated Data (AAD)**: Die ersten 6 Header-Bytes (`0..5`: Magic, Version, Flags) werden als AAD in AES-256-GCM authentifiziert. Jede Manipulation an Header, Nonce, Tag oder Ciphertext führt beim Entschlüsseln deterministisch zu einer `VaultCryptoException`.

### 4.2 Passphrasengeschützte verschlüsselte Sicherung (`.mhb` / `morphhealth.encrypted_backup.v1`)

Für die sichere Übernahme auf eine frische Installation (P07) erzeugt MorphHealth eine selbstbeschreibende JSON-Hülle, deren Nutzdaten vollständig mit einem aus der Nutzer-Passphrase abgeleiteten Schlüssel verschlüsselt sind:

- **Schlüsselableitung (KDF)**: `PBKDF2-HMAC-SHA256` mit `100.000` Iterationen und einem zufälligen 16-Byte-Salt (`salt_b64`).
- **Verschlüsselung (AEAD)**: `AES-256-GCM` mit zufälligem 12-Byte-Nonce (`nonce_b64`), 16-Byte-Authentifizierungs-Tag (`tag_b64`) und AAD `"morphhealth.encrypted_backup.v1"`.
- **Komprimierung**: Der vollständige portable JSON-Export (`morphhealth.portable.v1`) wird vor der Verschlüsselung mit `gzip` komprimiert.

```json
{
  "format": "morphhealth.encrypted_backup.v1",
  "kdf": "PBKDF2-HMAC-SHA256",
  "kdf_iterations": 100000,
  "salt_b64": "<16 Bytes Base64>",
  "cipher": "AES-256-GCM",
  "compression": "gzip",
  "nonce_b64": "<12 Bytes Base64>",
  "tag_b64": "<16 Bytes Base64>",
  "ciphertext_b64": "<AES-256-GCM Ciphertext Base64>",
  "created_at": "2026-10-15T10:00:00.000Z"
}
```

### 4.3 Maschinenlesbarer Datenexport und -import (`morphhealth.portable.v1`)

Der dokumentierte Klartext-Export (`portable.export`) erfordert explizit die Bestätigung `ack_plaintext: true` (sowohl im Wartungszugang `./mh` als auch als Bestätigungsdialog in der Android-Oberfläche). Das Übernehmen eines Dokuments (`portable.import`) erfordert explizit `confirm_replace: true`, bevor der vorhandene Arbeitsdatenbestand ersetzt wird.
