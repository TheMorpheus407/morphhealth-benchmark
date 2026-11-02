# SECURITY.md – Sicherheitskonzept von MorphHealth

**MH-PERSONAL-3 · Fassung 1.0-rc3**

MorphHealth ist ein lokales Gesundheitstagebuch. Es gibt kein Konto, keinen
Backend-Dienst, keine Werbung, keine Telemetrie und keine Laufzeit-KI. Die
gesundheitsbezogenen Daten verlassen das Gerät nur, wenn der Nutzer sie
selbst exportiert, sichert oder weitergibt.

---

## 1. Schutzziele

| Ziel | Maßnahme |
|---|---|
| Lokale Gesundheitsdaten sind verschlüsselt | AES-256-GCM je Datensatz, Schlüssel per HKDF-SHA256 aus einem 32-Byte-Hauptschlüssel abgeleitet |
| Der Hauptschlüssel verlässt die App nicht | Android Keystore (`AndroidKeyStore`, AES/GCM, nicht exportierbar); die App speichert nur das damit verschlüsselte Schlüsselblob |
| Sicherungen sind passphrasengeschützt | Argon2id (19 MiB, 2 Iterationen, 1 Lane) leitet den Schlüssel aus der Passphrase ab, AES-256-GCM schützt das Dokument |
| Kein fremder Zugriff auf den Arbeitsdatenbestand | Schlüsseldatei liegt außerhalb des Datenverzeichnisses, `store.lock` verhindert parallele Schreiber |
| Keine stillen Datenabflüsse | Es existiert keine Telemetrie, keine Werbe- oder Analyse-SDK, keine Cloud-Synchronisation |
| Kein unkontrollierter Netzzugriff | Das einzige Netzwerkziel ist der lesende Open-Food-Facts-Endpunkt; er ist in den Einstellungen sichtbar und überschreibbar |

## 2. Was **nicht** geschützt ist

* **Ein kompromittiertes Gerät** (entsperrtes Display, bösartige App mit
  Root-/Debugger-Rechten) kann den im Speicher liegenden Hauptschlüssel
  auslesen. MorphHealth schützt Daten *at rest*, nicht gegen ein aktives
  Angreifen des laufenden Prozesses.
* **Der Export im Klartext** (`portable.export`, Datei `*.json`) ist
  ausdrücklich *nicht* verschlüsselt. Der Aufrufer muss das mit
  `ack_plaintext: true` bestätigen. Für den Weg über Dateisysteme ist die
  verschlüsselte Sicherung (`*.mhbackup`) vorgesehen.
* **Der Keystore-Schutz des Hauptschlüssels** ist so stark wie die
  Gerätesperre. Die AOSP-Referenz ist ein `userdebug`-Build ohne
  hardwaregestützten Keystore; dort greift die softwaregestützte
  AndroidKeyStore-Implementierung.
* **Der Netzwerkweg zum Lebensmitteldienst** nutzt die Systemzertifikate.
  Die TLS-Prüfung wird nirgends abgeschaltet.

## 3. Kryptografische Bausteine

| Zweck | Verfahren | Parameter |
|---|---|---|
| Datensatzverschlüsselung im lokalen Speicher | AES-256-GCM | 12-Byte-Nonce pro Datensatz, 16-Byte-Tag, AAD = fortlaufender Frame-Index |
| Ableitung des Speicherschlüssels | HKDF-SHA256 | `info = "morphhealth/store/dek/v1"`, 32-Byte-Salt pro Datenverzeichnis |
| Ableitung des Keystore-Schlüssels | Android Keystore AES/GCM | nicht exportierbar, `setRandomizedEncryptionRequired(true)` |
| Ableitung des Sicherungsschlüssels | Argon2id | 19 MiB, 2 Iterationen, 1 Lane, 32 Byte Ausgabe |
| Zufallswerte | `Random.secure()` des Systems | — |

Alle Operationen laufen über `package:cryptography` in der reinen
Dart-Implementierung (kein Native-Code, identisches Verhalten auf Android
und auf dem Linux-Host).

## 4. Verwendete Bibliotheken

| Bibliothek | Version | Zweck | Warum |
|---|---|---|---|
| `cryptography` | 2.9.0 | AES-256-GCM, HKDF, Argon2id | reine Dart-Implementierung, keine Native-Abhängigkeit, auditiert |
| `meta` | 1.17.0 (Flutter-Pin) | Annotationen | Teil des Flutter-SDK |
| `path` | 1.9.1 | Pfadmanipulation | Teil des Flutter-SDK |
| `intl` | 0.20.2 | Datumsformatierung | von `flutter_localizations` vorgegeben |
| `path_provider` | 2.1.6 | App-Verzeichnisse | offizielles Flutter-Plugin |
| `flutter_localizations` | SDK | lokalisierte Material-Dialoge | offizielles Flutter-SDK |

Der Kern (`app/packages/morphhealth_core`) hat **keine** Flutter-Abhängigkeit.
Dadurch läuft exakt derselbe Code in der App und im Wartungszugang `mh`.

Drittanbieter-SDKs für Werbung, Analyse, Crash-Reporting oder Backend gibt es
**nicht**.

## 5. Dateiformate

### 5.1 Lokaler Speicher (Arbeitsdatenbestand)

```text
<data-dir>/
├── manifest.json   Format, Version, KDF, 32-Byte-Salt (Base64) – keine Gesundheitsdaten
├── records.bin     ausschließlich verschlüsselte Datensätze
└── store.lock      Sperrdatei (POSIX-Dateisperre + In-Process-Registry)
```

`records.bin` besteht aus Frames:

```text
[uint32 big endian: Länge der Nutzlast][12 Byte Nonce][Chiffretext][16 Byte GCM-Tag]
```

Die Klartext-Nutzlast ist ein JSON-Objekt:

```json
{"k": "journalEntry", "id": "…", "d": { … }}
{"k": "journalEntry", "id": "…", "x": 1}
```

`"x": 1` ist ein Grabstein (Löschung). Als AAD dient der Frame-Index, damit
ein Datensatz nicht in eine andere Position verschoben werden kann.

Schreibvorgänge werden sofort in das Betriebssystem geschrieben, auf die
Platte erzwungen spätestens alle 500 ms beziehungsweise alle 64 Datensätze
und beim Schließen des Speichers. Ein Stromausfall kann daher die jüngsten
Einträge einer laufenden Sitzung kosten, keine abgeschlossenen Schreibvorgänge
einer geschlossenen Sitzung.

### 5.2 Portables Dokument (Export und Import)

JSON-Objekt, vollständig in `tools`/`app` dokumentiert:

```json
{
  "format": "morphhealth.portable",
  "version": 1,
  "exported_at": "2026-09-23T08:12:00.000Z",
  "app": {"name": "MorphHealth", "version": "1.0-rc3"},
  "counts": {"foods": 12, "journal_entries": 480, "…": 0},
  "foods": [],
  "journal_entries": [],
  "intake_entries": [],
  "periods": [],
  "weights": [],
  "symptoms": [],
  "goals": {},
  "settings": {}
}
```

Masseinheiten im Dokument: Nährwerte in Gramm je 100 g (Energie in kcal und
kJ), Wasser in ml, Koffein in mg, Gewicht in kg, Intensität 0–10.

### 5.3 Verschlüsselte Sicherung (`*.mhbackup`)

Binärer Container, siehe `BackupContainer` in
`app/packages/morphhealth_core/lib/src/portable/backup.dart`:

```text
0   8   Magic "MHBACKUP"
8   1   Containerversion (1)
9   1   KDF-Kennung (1 = Argon2id)
10  4   Argon2id-Speicher in KiB
14  4   Argon2id-Iterationen
18  1   Argon2id-Parallelität
19  1   Saltlänge (16)
20  16  Salt
36  1   Noncelänge (12)
37  12  Nonce
49  4   Chiffretextlänge
53  1   Taglänge (16)
54  16  GCM-Tag
70  n   Chiffretext (AES-256-GCM des portablen Dokuments)
```

Bytes 0–48 (Magic, Parameter, Salt, Nonce) dienen als AAD und sind damit
gegen Manipulation geschützt. Die Sicherung ist vollständig selbständig und
lässt sich auf eine frische Installation übertragen: sie enthält
Datenbestand **und** den zur Entschlüsselung nötigen Schlüssel (aus der
Passphrase).

### 5.4 Schlüsseldatei des Wartungszugangs

32 rohe Bytes, beliebig erzeugbar:

```bash
head -c 32 /dev/urandom > /tmp/morphhealth.key
chmod 600 /tmp/morphhealth.key
```

Die Datei muss **außerhalb** des Datenverzeichnisses liegen; `mh` verweigert
den Betrieb, wenn sie darin liegt.

## 6. Bedrohungsmodell in Kürze

| Angreifer | Ergebnis |
|---|---|
| Finder mit Dateisystemzugriff | sieht nur `manifest.json` und Chiffretext |
| Diebstahl des Geräts (entsperrt) | Keystore schützt den Hauptschlüssel, solange die Gerätesperre aktiv ist |
| Schwaches Passwort | Argon2id verlangsamt das Raten; kurze Passphrasen bleiben schwach |
| Manipulierter Datenbestand | GCM-Tag und AAD-Bindung weisen Manipulation nach |
| Netzwerk-MITM beim Lebensmitteldienst | TLS mit Systemzertifikaten; Zertifikatsprüfung ist nie deaktiviert |

## 7. Prüfungen vor der Auslieferung

* `dart analyze` (Kern) und `flutter analyze` (App): keine Befunde.
* `dart test` (Kern, 33 Tests) und `flutter test` (App, 6 Widget-Tests): bestanden.
* Der Test *„the log file does not contain readable health data"* liest die
  verschlüsselte Datei und stellt sicher, dass der Klartextname eines
  Symptoms nicht auftaucht.
* Der Test *„a wrong key cannot read the store"* belegt, dass ein falscher
  Hauptschlüssel das Öffnen verweigert.
* Der Test *„the encrypted backup needs the right passphrase"* belegt, dass
  die falsche Passphrase abgewiesen wird.
* Die Prüfsumme des Emulators und der API-Konfiguration ist in `README.md`
  dokumentiert.
* Auf dem Referenzgerät wurde geprüft, dass der erzeugte Sicherungscontainer
  `MHBACKUP` **keinen lesbaren Klartext** enthält: kein erfasster Begriff aus
  dem Datenbestand kommt in der Datei vor. Eine Sicherung mit falscher
  Passphrase wird abgewiesen, eine mit richtiger Passphrase stellt den
  Bestand auf einer frischen Installation wieder her.
