# SECURITY.md — MorphHealth

Sicherheitskonzept, verwendete Bibliotheken und Dateiformate der Android-App
MorphHealth (Version 1.0.0+1, Package-ID `de.themorpheus.morphhealth.local`).
Auftrag: MH-PERSONAL-3, Fassung 1.0-rc3 (P07, P09, P10).

## 1. Sicherheitskonzept (Überblick)

MorphHealth verarbeitet Gesundheitsdaten (Ernährung, Zyklus, Gewicht, Symptome)
lokal auf dem Gerät eines einzelnen Nutzers. Die Leitlinien:

- **Lokal und ohne Konto.** Kein Backend, keine Registrierung, keine
  Multi-Device-Synchronisation. Der persönliche Gesundheitsbereich funktioniert
  vollständig ohne Internetverbindung.
- **Verschlüsselung at rest.** Der gesamte lokale Datenbestand liegt als
  AES-256-GCM-verschlüsselter Container vor. Passphrasengeschützte Sicherungen
  sind zusätzlich mit PBKDF2-HMAC-SHA256 (600.000 Iterationen) abgeleitet und
  AES-256-GCM-verschlüsselt.
- **Schlüsseltrennung.** Der 32-Byte-AES-Schlüssel liegt als `master.key` **außerhalb**
  des Datenverzeichnisses und wird niemals exportiert (weder im Klartext-Export
  noch in Sicherungen).
- **Keine Telemetrie, keine Werbung, keine Laufzeit-KI** (P07). Die App sendet
  Daten ausschließlich als lesende HTTPS-Abfragen an den konfigurierten
  Open-Food-Facts-Origin (Produktsuche/-abruf, P08).
- **Minimale Berechtigungen.** Nur `INTERNET` (Manifest). Keine Health-/Speicher-/
  Kamera-/Standortberechtigungen. Datei-Ex-/Import läuft über das Storage Access
  Framework (SAF) des Systems, nicht über direkten Speicherzugriff.
- **TLS wird nie umgangen.** Die HTTPS-Verifikation bleibt aktiv; das
  Zertifikatsvertrauen wird durch die Arbeitsumgebung bereitgestellt
  (`ENVIRONMENT.json: certificate_trust`).
- **Kein App-Backup durch das System:** `android:allowBackup="false"` — weder
  Android-Backup noch ADB-Backup können den Datenbestand unbemerkt mitnehmen.

## 2. Datenablage und Schlüssel

Auf dem Gerät (path_provider 2.x, `getApplicationSupportDirectory` → `files/`):

```text
/data/data/de.themorpheus.morphhealth.local/files/morphhealth/
├── master.key                  32 rohe Bytes (AES-256-Schlüssel), chmod 600 (best effort)
└── data/
    └── morphhealth.store       verschlüsselter Gesamtdatenbestand (MHST-Container)
```

- Beide Verzeichnisse liegen im app-privaten Speicher (eigene Linux-UID des Pakets,
  nicht world-readable; zusätzlich durch die Android-App-Sandbox/SELinux geschützt).
- Die App legt Schlüssel und Store beim ersten Start selbst an
  (`KeyFile.loadOrCreate`). Der Wartungszugang `mh` verlangt dagegen eine
  **bestehende** Schlüsseldatiei mit exakt 32 Bytes (`--key-file`, außerhalb des
  Datenverzeichnisses) und legt nichts an.
- Schreibzugriffe auf den Store sind **atomar** (tmp-Datei + `rename`), sodass ein
  Absturz keinen halb geschriebenen Bestand hinterlässt.
- „Alles löschen" (Einstellungen → Daten) löscht das gesamte Datenverzeichnis
  rekursiv; die Schlüsseldatiei bleibt bewusst liegen (sie enthält keine Daten).

## 3. Kryptografie

Implementierung: `app/lib/src/crypto/crypto.dart` (reines Dart,
`package:cryptography` 2.9.0 — dasselbe Verfahren in App und AOT-CLI).

| Zweck | Verfahren | Parameter |
|---|---|---|
| Lokaler Speicher | AES-256-GCM | 12-Byte-Nonce (zufällig pro Schreibvorgang), 16-Byte-MAC (AEAD) |
| Sicherungsschlüssel | PBKDF2-HMAC-SHA256 | 600.000 Iterationen (OWASP-Richtwert), 16-Byte-Salt (zufällig), 256-Bit-Schlüssel |
| Sicherung | AES-256-GCM | 12-Byte-Nonce, 16-Byte-MAC |
| Schlüsseldatei | — | 32 rohe Bytes aus dem CSPRNG des Systems |

Anmerkungen:

- GCM-Nonce wird pro Verschlüsselung neu zufällig erzeugt (keine Nonce-Wiederverwendung).
- Authentifizierungsfehler (Manipulation, falscher Schlüssel, falsche Passphrase)
  werden als Fachfehler gemeldet (`crypto.decrypt_failed`,
  `backup.wrong_passphrase`); es gibt keine Entschlüsselung-ohne-Verifikation.
- Es werden keine selbstgebauten Krypto-Primitive verwendet.

## 4. Netzwerkverkehr

- **Nur lesende GET-Anfragen** (P08) an den konfigurierten Open-Food-Facts-Origin:
  - `GET {base}/api/v3.6/product/{barcode}.json`
  - `GET {base}/cgi/search.pl?search_terms={q}&search_simple=1&action=process&json=1&page={p}&page_size=20`
- HTTP-Client: `package:http` 1.6.0 auf `dart:io` — verwendet den
  System-Trust-Store von Android (keine eigene Zertifikatsliste, keine Pinning-
  Abschaltung, TLS-Verifikation aktiv).
- Der Origin ist per `--dart-define` einkompiliert (`FOOD_API_BASE_URL`,
  `FOOD_API_USER_AGENT`; Werte aus `ENVIRONMENT.json`, Produkt-Default
  `https://world.openfoodfacts.org`). Der Fachcode enthält keine harte URL.
- Es werden **keine** Nutzerdaten (Tagebuch, Gewicht, Symptome, Zyklus) an den
  Food-API-Endpunkt gesendet — ausschließlich Suchbegriffe und Barcodes.
- Produktbilder werden von OFF bereitgestellten URLs (`images.openfoodfacts.org`)
  referenziert; die App lädt Bilder nicht selbst nach (kein WebView).

## 5. Berechtigungen und Manifest

`app/android/app/src/main/AndroidManifest.xml`:

- `INTERNET` — einzige Berechtigung (lesende Food-API-Abfragen).
- `allowBackup="false"` — kein System-/Cloud-Backup des Datenbestands.
- `localeConfig` (de, en) — Sprachwahl ohne Berechtigung.
- Keine `READ/WRITE_EXTERNAL_STORAGE`, keine Health-/Fitness-Berechtigungen, keine
  Kamera, kein Standort, keine Kontakte, keine Health-Connect-/HealthKit-Anbindung.
- SAF (`file_picker`) für Export/Import/Sicherung: der Nutzer wählt Dateien über
  den System-Document-Provider; die App erhält nur Zugriff auf die gewählte Datei.

## 6. Build und Signierung

- Release-APK (`artifacts/morphhealth.apk`), gebaut mit `./build.sh`
  (`flutter build apk --release --target-platform android-x64`).
- **Debug-signiert** (Android-Debug-Key, `CN=Android Debug`): Es ist kein
  Release-Keystore Bestandteil des Auftrags und Store-Veröffentlichung ist
  P11-Nichtumfang; die Debug-Signatur macht die APK lokal installierbar.
  `apksigner verify` besteht. Für eine Produktveröffentlichung müsste ein
  Release-Keystore ergänzt werden (nicht Teil dieser Abgabe).
- R8-Shrinking ist im Release aktiv (Flutter-Gradle-Plugin). Konsequenz (siehe
  README „Wesentliche Entscheidungen"): `MainActivity` muss im Paket des
  Manifest-Namespace liegen, damit sie nicht entfernt wird.
- Reproduzierbarkeit: `./build.sh` setzt JAVA_HOME (JBR 21 laut ENVIRONMENT.json,
  Fallback System-JDK), ANDROID_HOME/SDK_ROOT und löst Flutter über PATH oder
  `/run/current-system/sw/bin/flutter`.

## 7. Verwendete Bibliotheken (mit Versionen)

Direkte Abhängigkeiten (`app/pubspec.yaml`, Versionen aus `pubspec.lock`):

| Bibliothek | Version | Zweck |
|---|---|---|
| flutter (SDK) | 3.41.9 | Framework |
| flutter_localizations (SDK) | — | Lokalisierung |
| http | 1.6.0 | HTTPS-Client (dart:io, System-Trust-Store) |
| path_provider | 2.1.6 | app-private Verzeichnisse (Daten + Schlüssel) |
| file_picker | 13.1.0 | SAF-Dateiwähler (Export/Import/Sicherung) |
| cryptography | 2.9.0 | AES-256-GCM, PBKDF2-HMAC-SHA256 (reines Dart) |
| cupertino_icons | 1.0.9 | Icon-Font |
| flutter_lints (dev) | 6.0.0 | Lint-Regeln |

Wesentliche transitive Abhängigkeiten (Auswahl, Versionen aus `pubspec.lock`):

| Bibliothek | Version | Anmerkung |
|---|---|---|
| crypto | 3.0.7 | Hash-Funktionen (von cryptography genutzt) |
| collection | 1.19.1 | Collections |
| typed_data | 1.4.0 | Byte-Puffer |
| meta | 1.17.0 | Annotationen |
| http_parser | 4.1.2 | HTTP-Parsing (von http) |
| path | 1.9.1 | Pfad-Utilities |
| ffi / win32 | 2.2.0 / 6.4.0 | Dart-FFI-Bindings (Desktop-Plugins, ungenutzt auf Android) |
| path_provider_android | 2.3.1 | Android-Implementierung (MethodChannel) |
| file_picker_platform_interface | 4.0.0 | file_picker-Schnittstelle |
| plugin_platform_interface | 2.1.8 | Plugin-Schnittstelle |
| matcher / test_api / fake_async / clock / stack_trace | 0.12.19 / 0.7.10 / 1.3.3 / 1.1.2 / 1.12.1 | Test-Framework |
| material_color_utilities | 0.13.0 | Material-3-Farben |
| vector_math | 2.2.0 | Mathe (Flutter) |
| intl | 0.20.2 | Formatierung (flutter_localizations) |
| args | 2.7.0 | CLI-Argumentparser (mh) |

Es werden keine Analyse-/Tracking-/Werbe-SDKs und keine LLM-Laufzeitbibliotheken
eingesetzt. Die vollständige, gepinnte Liste steht in `app/pubspec.lock`.

## 8. Dateiformate

### 8.1 Lokaler Speicher — `MHST` (AES-256-GCM-Container)

Datei: `morphhealth.store` im Datenverzeichnis.

```text
Offset  Länge  Inhalt
0       4      Magic "MHST"
4       2      version  u16 LE (= 1)
6       2      reserved u16 LE (= 0)
8       12     nonce (zufällig pro Schreibvorgang)
20      …      ciphertext (AES-256-GCM, Länge = Klartextlänge)
end-16  16     MAC (GCM-Authentifizierungs-Tag)
```

Klartext: UTF-8-JSON des Daten-Dokuments (Struktur siehe 8.3, dort unter `data`).

### 8.2 Passphrasengeschützte Sicherung — `MHBK`

Vom Nutzer per SAF gewählte Datei (Endung frei, Inhalt binär).

```text
Offset  Länge  Inhalt
0       4      Magic "MHBK"
4       2      version  u16 LE (= 1)
6       1      kdfId    u8 (= 1 → PBKDF2-HMAC-SHA256)
7       4      iterations u32 LE (= 600000)
11      16     salt (zufällig)
27      12     nonce
39      …      ciphertext (AES-256-GCM)
end-16  16     MAC
```

Schlüssel = PBKDF2-HMAC-SHA256(passphrase, salt, iterations, 256 Bit).
Klartext: UTF-8-JSON des **portablen Dokuments** (8.3) — eine Sicherung ist damit
zur Übernahme auf eine frische Installation geeignet (neues Gerät, neue App-
Installation, gleicher Datenbestand nach Entschlüsselung + Import).

### 8.3 Portables Dokument — `morphhealth.portable` v1 (Klartext-JSON)

Top-Level-Felder: `format` („morphhealth.portable"), `format_version` (1),
`generator` (App/CLI-Name + Version), `data`.

`data`-Felder (alle Einträge mit eigener `id`, Zeitstempel `created_at`;
Änderungen über `updated_at` bei Lebensmitteln):

| Feld | Inhalt |
|---|---|
| `settings` | `language` (de\|en\|null), `weight_unit` (kg\|lb), `visible_areas`, `goals` (Wasser ml, kcal, Protein/Kohlenhydrate/Fett g; null = kein Ziel) |
| `foods` | `id`, `name`, `brand`, `barcode`, `source` (custom\|off), `per100` (31 Nährstoffe, kanonisch pro 100 g), `serving`, `is_favorite`, `image_url`, `off_origin`, `created_at`, `updated_at` |
| `nutrition_entries` | `id`, `food_id`, `food_name`, `food_per100` (Schnappschuss), `food_serving_grams`, `date` (YYYY-MM-DD), `time` (HH:MM\|null), `meal` (breakfast\|lunch\|dinner\|snack), `quantity`, `unit` (g\|ml\|portion), `note`, `created_at` |
| `water_entries` | `id`, `date`, `time`, `amount_ml`, `note` |
| `caffeine_entries` | `id`, `date`, `time`, `amount_mg`, `note` |
| `periods` | `id`, `start` (YYYY-MM-DD), `end` (YYYY-MM-DD\|null = läuft), `flow` (spotting\|light\|medium\|heavy), `flow_by_day` (Datum → 0..3), `note` |
| `weight_entries` | `id`, `date`, `time`, `weight_kg` (kanonisch kg), `note` |
| `symptom_entries` | `id`, `name`, `intensity` (0..10), `date`, `time`, `note` |

Nährstoffschlüssel (31, kanonisch pro 100 g): `energy_kcal` (kcal),
`protein_g`, `carbohydrates_g`, `fat_g`, `saturated_fat_g`, `sugars_g`, `fiber_g`,
`salt_g` (g), `sodium_mg`, `caffeine_mg` (mg), `vitamin_a_ug`, `vitamin_d_ug`,
`vitamin_k_ug`, `vitamin_b7_ug`, `vitamin_b9_ug`, `vitamin_b12_ug`, `selenium_ug`,
`iodine_ug` (µg), `vitamin_c_mg`, `vitamin_e_mg`, `vitamin_b1_mg`, `vitamin_b2_mg`,
`vitamin_b3_mg`, `vitamin_b5_mg`, `vitamin_b6_mg`, `calcium_mg`, `iron_mg`,
`magnesium_mg`, `potassium_mg`, `zinc_mg`, `phosphorus_mg` (mg).
Mengeneinheiten: `g` (Gramm), `ml` (Milliliter, Dichte 1 g/ml),
`portion` (1 Portion = `serving.grams`, sonst 100 g).

### 8.4 Wartungszugang `mh` — JSON Lines (P10)

- Anfrage (eine Zeile stdin): `{"request_id": <any>, "op": "<op>", …parameter}`
- Antwort (eine Zeile stdout, sofort geflusht):
  `{"request_id": <echo>, "ok": true, "data": …}` bzw.
  `{"request_id": <echo>, "ok": false, "error": {"code": "…", "message": "…"}}`
- Operationen: `describe`, `portable.export` (erfordert `ack_plaintext: true`),
  `portable.import` (`document` + `confirm_replace: true`),
  `nutrition.day` (`date`), `cycle.forecast` (`on`), `food.search` (`q`, `page`),
  `food.lookup` (`barcode`).
- Kein Banner auf stdout; EOF beendet den Prozess. Details und ein
  importierbares Beispieldokument liefert `describe` zur Laufzeit.

## 9. Grenzen des Sicherheitsmodells (ehrlich benannt)

- **Kein Schutz gegen physikalischen Zugriff auf ein entsperrtes Gerät.** Der
  Schlüssel liegt auf dem Gerät; wer das Gerät und die App öffnen kann, liest die
  Daten. Gegenmaßnahme für den Nutzer: Gerätesperre (PIN/Biometrie) — außerhalb der
  App, aber die wirksamste Maßnahme.
- **Debug-signierte APK** (siehe 6): nicht für öffentliche Verteilung gedacht.
- **Klartext-Export** ist bewusst unverschlüsselt (Portabilität, P07) und erfordert
  eine explizite Bestätigung in der App bzw. `ack_plaintext: true` im mh-Protokoll;
  die exportierte Datei liegt anschließend in der Verantwortung des Nutzers (SAF-Ziel).
- **PBKDF2 mit 600.000 Iterationen** ist der aktuelle OWASP-Richtwert, aber ein
  schwaches Passphrase bleibt der Schwachpunkt einer Sicherung — die Stärke der
  Passphrase wird nicht erzwungen (UX-Entscheidung), das Iterationsziel schon.
- **Zyklus-/Gesundheitsdaten sind keine medizinischen Daten im engeren Sinne**,
  werden aber mit derselben Sorgfalt wie Gesundheitsdaten behandelt (P07).
