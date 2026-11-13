# MorphHealth – Sicherheitskonzept

Dieses Dokument beschreibt, was MorphHealth schützt, wovor, womit und wo die Grenzen liegen. Es nennt die verwendeten
Bibliotheken und beschreibt die Dateiformate so genau, dass sich Bestand und Sicherung ohne die App lesen lassen,
wenn man den Schlüssel beziehungsweise die Passphrase hat.

## Schutzziele und Annahmen

MorphHealth speichert Gesundheitsdaten einer Person: Ernährung, Zyklus, Gewicht, Symptome.

| Ziel | Umsetzung |
|---|---|
| Die Daten verlassen das Gerät nur auf ausdrücklichen Wunsch. | Kein Konto, kein Server, keine Telemetrie, keine Werbung, keine Analysebibliothek. Android-Sicherung und Geräteübertragung sind für die App ausgeschaltet. Ins Netz geht ausschließlich die Lebensmittelsuche, und erst nach Einwilligung. |
| Wer an die Dateien der App gelangt, kann sie nicht lesen und nicht unbemerkt verändern. | Alle Dateien des Bestands sind mit XChaCha20-Poly1305 verschlüsselt und authentifiziert. Der Schlüssel liegt nur in verpackter Form vor, verpackt mit einem Schlüssel aus dem Android Keystore. |
| Eine Sicherung ist ohne Passphrase wertlos. | Argon2id leitet den Schlüssel aus der Passphrase ab; Inhalt und Kopfdaten sind authentifiziert. |
| Der Nutzer kann alles mitnehmen und alles löschen. | Vollständiger Export, verschlüsselte Sicherung, Löschen des gesamten Bestands einschließlich des Schlüssels. |

Angenommen wird ein Gerät, dessen Betriebssystem die privaten Verzeichnisse der Apps voneinander trennt und dessen
Keystore Schlüssel nicht herausgibt. Geschützt wird gegen: andere Apps, das Auslesen von Sicherungen und
Geräteübertragungen, Kopien der Dateien (zum Beispiel aus einem Abbild des Speichers) und gegen Mitlesen auf dem
Netzweg. Nicht geschützt wird gegen jemanden, der das entsperrte Gerät in der Hand hat, und nicht gegen ein Gerät mit
Systemrechten in fremder Hand, solange die App läuft (siehe »Grenzen«).

## Was wo liegt

| Ort | Inhalt | Schutz |
|---|---|---|
| `no_backup/store/morphhealth.snapshot` | vollständiger Bestand zum Zeitpunkt der letzten Verdichtung | verschlüsselt |
| `no_backup/store/morphhealth.journal` | Änderungen seit dem Schnappschuss | verschlüsselt, je Änderung ein Satz |
| `no_backup/store/morphhealth.lock` | leer; Sperre zwischen Prozessen | – |
| `no_backup/master.key` | der Hauptschlüssel, verpackt mit einem Keystore-Schlüssel (61 Bytes) | AES-256-GCM |
| Android Keystore, Alias `morphhealth_master_wrap_v1` | Schlüssel zum Verpacken; nicht exportierbar | Keystore |
| vom Nutzer gewählter Ort | `*.mhbackup` (verschlüsselt) und `morphhealth-export-*.json` (Klartext) | Passphrase beziehungsweise keiner |

Die Pfade liegen im privaten Verzeichnis der App (`/data/data/de.themorpheus.morphhealth.local/`). Andere Dateien mit
Nutzerdaten legt die App nicht an: keine Datenbank, keine Shared Preferences, kein Cache mit Inhalten, keine Protokolle.
Der Gerätetest (`tools/device_check.py`) prüft das nach echten Eingaben mit Systemrechten und sucht in allen privaten
Dateien nach Klartext aus den Einträgen.

## Kryptografie

Es gibt keine selbst entworfenen Verfahren. Alle Primitive stammen aus der Bibliothek `cryptography` 2.9.0 (reines
Dart); die Tests des Fachkerns prüfen sie gegen veröffentlichte Testvektoren (XChaCha20-Poly1305:
draft-irtf-cfrg-xchacha-03 A.3.1, HKDF-SHA-256: RFC 5869 Testfall 1, Argon2id: RFC 9106 Abschnitt 5.3).

| Zweck | Verfahren | Parameter |
|---|---|---|
| Verschlüsselung mit Authentifizierung | XChaCha20-Poly1305 | Schlüssel 256 Bit, Nonce 192 Bit zufällig je Verschlüsselung, Tag 128 Bit |
| Schlüsseltrennung | HKDF-SHA-256 (RFC 5869) | Salt `MorphHealth`, Info `morphhealth/store/v1`, Ausgabe 32 Bytes |
| Schlüssel aus Passphrase | Argon2id Version 1.3 (RFC 9106, zweite empfohlene Option) | 64 MiB Speicher, 3 Durchläufe, 4 Bahnen, Salt 16 Bytes zufällig, Ausgabe 32 Bytes |
| Verpacken des Hauptschlüssels auf Android | AES-256-GCM im Android Keystore | IV 96 Bit vom Keystore, Tag 128 Bit |
| Zufall | `Random.secure()` in Dart, `SecureRandom` in Kotlin | – |

Die 192 Bit lange Zufalls-Nonce von XChaCha20 macht Wiederholungen auch bei sehr vielen Journalsätzen praktisch
unmöglich; ein Zähler, der Abstürze überstehen müsste, ist damit unnötig.

## Lokaler Bestand

Der Bestand ist ein Verzeichnis mit drei Dateien. Dasselbe Format verwenden die App und der Wartungszugang
(`--data-dir`). Der Dateischlüssel ist `HKDF-SHA-256(Hauptschlüssel, Salt "MorphHealth", Info "morphhealth/store/v1")`.

**`morphhealth.snapshot`**

```text
"MHSNAP1\n"            8 Bytes Kennung
Generation             16 zufällige Bytes, neu bei jedem Schnappschuss
Nonce                  24 Bytes
Chiffrat || Tag        Tag 16 Bytes
```

Zugehörige Daten (AAD) sind die ersten 24 Bytes (Kennung und Generation). Der Klartext ist
`gzip(JSON {"schema": 1, "document": <Exportdokument>, "local": {…}})`. `local` enthält zwei Angaben, die nicht zum
Export gehören: ob die Begrüßung abgeschlossen ist und eine in der App gewählte Adresse des Lebensmitteldienstes.
Ein neuer Schnappschuss wird in eine temporäre Datei geschrieben, auf den Datenträger gesichert und dann umbenannt.

**`morphhealth.journal`**

```text
"MHJRNL1\n" || Generation                      24 Bytes Kopf
je Satz:  Länge (uint32, big endian) || Nonce (24) || Chiffrat || Tag (16)
```

AAD des Satzes Nummer n ist `"MHJRNL1\n" || Generation || n (uint64, big endian)`. Der Klartext ist ein JSON-Array von
Änderungen `{op: put | set | del, c: Sammlung, v: Datensatz | id: Schlüssel}`. Jede Änderung der Daten ist genau ein
Satz und wird vor der Bestätigung auf den Datenträger gesichert.

Daraus folgt:

- Ein Journal passt nur zu dem Schnappschuss mit derselben Generation. Ein Journal einer anderen Generation wird
  ignoriert.
- Sätze lassen sich nicht vertauschen, verdoppeln, auslassen oder zwischen Bestandsständen verschieben, ohne dass die
  Authentifizierung fehlschlägt, weil ihre Position in die AAD eingeht.
- Ein unvollständiger letzter Satz (Absturz während des Schreibens) wird verworfen; alles davor bleibt gültig.
- Nach 256 Sätzen oder 512 KiB wird das Journal in einen neuen Schnappschuss eingearbeitet.
- Ein falscher Schlüssel und veränderte Dateien führen zu einem klaren Fehler (`wrong_key`, `corrupt`); die App zeigt
  dann einen Problembildschirm und bietet an, es erneut zu versuchen oder den lokalen Bestand zurückzusetzen. Sie
  überschreibt in diesem Zustand nichts von sich aus.
- Mehrere Prozesse auf demselben Verzeichnis (zum Beispiel zwei `mh`-Aufrufe) sperren sich über `morphhealth.lock`
  gegenseitig aus und lesen vor jeder Änderung den aktuellen Stand nach.

## Schlüssel

**Android.** Beim ersten Start erzeugt die App 32 zufällige Bytes als Hauptschlüssel und einen AES-256-GCM-Schlüssel
im Android Keystore (`KeyVault.kt`). Der Hauptschlüssel wird mit dem Keystore-Schlüssel verschlüsselt und so in
`no_backup/master.key` abgelegt:

```text
Version (1 Byte, Wert 1) || IV (12 Bytes) || Chiffrat und Tag (48 Bytes);  AAD "MorphHealth master key v1"
```

Der Keystore-Schlüssel verlässt den Keystore nie; auf Geräten mit entsprechender Hardware liegt er in der
geschützten Umgebung des Geräts. Eine Kopie von `master.key` ist auf einem anderen Gerät deshalb nutzlos. Der
Hauptschlüssel selbst befindet sich nur im Arbeitsspeicher der laufenden App.

Es gibt bewusst keine zusätzliche App-Sperre mit PIN oder Fingerabdruck. Der Zugriffsschutz ist die Bildschirmsperre
des Geräts. Eine eigene Sperre hätte den Start jeder Schnellerfassung verlangsamt und ohne Bindung des Schlüssels an
die Entsperrung keine kryptografische Wirkung gehabt.

**Wartungszugang.** `--key-file` nennt eine Datei mit genau 32 rohen Bytes, dem Hauptschlüssel des Verzeichnisses
`--data-dir`. Die Datei wird vom Aufrufer angelegt (`head -c 32 /dev/urandom > mh.key`), muss außerhalb des
Datenordners liegen und wird von `mh` nur gelesen. Der Schlüssel erscheint weder im Datenordner noch auf stdout oder
stderr. Liegt die Datei im Datenordner oder hat sie eine andere Länge, verweigert `mh` die Arbeit mit
`key_file_invalid`.

## Sicherung (`*.mhbackup`)

Format `morphhealth-backup`, Version 1: ein JSON-Objekt (UTF-8) mit lesbaren Kopfdaten und verschlüsseltem Inhalt.

```json
{
 "format": "morphhealth-backup",
 "version": 1,
 "created_at": "2026-11-10T02:11:59+01:00",
 "app_version": "1.0.0",
 "kdf": {"algorithm": "argon2id", "version": 19, "memory_kib": 65536,
         "iterations": 3, "parallelism": 4, "salt": "<Base64, 16 Bytes>"},
 "cipher": "xchacha20-poly1305",
 "compression": "gzip",
 "data": "<Base64 von Nonce (24) || Chiffrat || Tag (16)>"
}
```

- Schlüssel: `Argon2id(Passphrase als UTF-8, Salt)` mit den Parametern aus `kdf`, 32 Bytes.
- Klartext: `gzip(UTF-8-JSON eines Exportdokuments)`; das Format steht in README.md.
- AAD: die Werte `format`, `version`, `created_at`, `app_version`, `kdf.algorithm`, `kdf.version`, `kdf.memory_kib`,
  `kdf.iterations`, `kdf.parallelism`, `kdf.salt`, `cipher`, `compression`, in dieser Reihenfolge mit Zeilenumbruch
  verbunden. Wer Kopfdaten ändert, etwa die Kosten der Schlüsselableitung, macht die Sicherung unlesbar.
- Die Passphrase braucht mindestens 8 Zeichen; die App empfiehlt einen langen Satz und sagt, dass die Passphrase
  nirgends gespeichert wird und eine Sicherung ohne sie verloren ist.
- Beim Lesen werden die Parameter begrenzt (8 MiB bis 1 GiB Speicher, 1 bis 16 Durchläufe, 1 bis 16 Bahnen), damit
  eine manipulierte Datei keine unvernünftigen Ressourcen verlangen kann. Dateien über 128 MiB liest die App nicht.
- Eine falsche Passphrase und eine veränderte Datei sind nicht zu unterscheiden; beides meldet die App als »Die
  Passphrase passt nicht zu dieser Sicherung«.
- Die Schlüsselableitung läuft in der App in einem Hintergrund-Isolate und dauert auf dem Referenzgerät etwa zwei
  Sekunden.
- Vor dem Ersetzen zeigt die App, was die Sicherung enthält und was derzeit gespeichert ist. Der Import ist atomar.

Unabhängige Kontrolle: `dart run tool/open_backup.dart DATEI.mhbackup` im Ordner `app/packages/morphhealth_core` liest
die Passphrase von stdin oder aus `MH_PASSPHRASE` und gibt eine Zusammenfassung oder mit `--json` das Dokument aus.

## Export

Der Export ist absichtlich unverschlüsselt, damit er maschinenlesbar und ohne MorphHealth verwendbar ist. Die App warnt
vor dem Speichern ausdrücklich und verweist auf die verschlüsselte Sicherung. Im Wartungszugang verlangt
`portable.export` das Feld `ack_plaintext: true`. Gespeichert wird über den Systemdialog an einem Ort, den der Nutzer
wählt; die App braucht dafür keine Speicherberechtigung und erhält Zugriff auf genau dieses eine Dokument.

## Löschen

*Alle Daten löschen* verlangt eine ausdrückliche Bestätigung mit Häkchen. Danach löscht die App die Dateien des
Bestands, die Datei `master.key` und den Schlüssel im Keystore, erzeugt einen neuen Schlüssel und startet mit dem
Begrüßungsbildschirm. Mit dem alten Schlüssel sind auch Reste der alten Dateien auf dem Datenträger unlesbar.
Exporte und Sicherungen, die der Nutzer anderswo gespeichert hat, bleiben bestehen; die App sagt das im Dialog.

## Netzwerk

- Die einzige Verbindung der App ist die Lebensmittelsuche. Sie ist anfangs unentschieden: Vor der ersten Anfrage
  erklärt ein Dialog, was gesendet wird, und erst die Zustimmung schaltet sie ein. In den Einstellungen lässt sie
  sich jederzeit ausschalten. Gesendet wird nur auf Knopfdruck.
- Übertragen werden der Suchbegriff oder der Barcode, die Seitennummer, die Feldliste und der konfigurierte
  `User-Agent`. Tagebuchinhalte, Kennungen des Geräts oder des Nutzers werden nie gesendet; die App erzeugt keine
  solche Kennung.
- Nur HTTPS. Unverschlüsselter Verkehr ist im Manifest verboten (`usesCleartextTraffic=false`), und der Fachkern
  lehnt Adressen ohne `https` ab. Zertifikate werden mit dem Vertrauensspeicher des Systems geprüft; es gibt keinen
  eigenen `badCertificateCallback` und keine Ausnahme für einzelne Hosts.
- Weiterleitungen auf einen anderen Host werden nicht befolgt, damit ein Dienst Suchbegriffe nicht an Dritte umlenken
  kann.
- Antworten des Dienstes sind fremde Daten: Größe, Typen und Wertebereiche werden geprüft, bevor etwas gespeichert
  wird. Texte aus Open Food Facts werden nur als Text angezeigt.
- Produktbilder werden nicht geladen.
- Der Wartungszugang öffnet keinen Anschluss. Er verbindet sich ausschließlich für `food.search` und `food.lookup` mit
  dem konfigurierten Dienst und beachtet die gespeicherte Einstellung »Online-Suche aus«.

## Android

- Einzige Berechtigung: `android.permission.INTERNET`. Keine Gesundheits-, Standort-, Kamera-, Kontakt-, Speicher-
  oder Benachrichtigungsberechtigung. Die im Manifest zusätzlich sichtbare Berechtigung
  `…DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` legt die Bibliothek androidx.core für die App selbst an
  (Schutzstufe `signature`); sie gewährt keinen Zugriff auf irgendetwas.
- `allowBackup=false`, `fullBackupContent=false` und `dataExtractionRules` schließen alle Bereiche von Cloud-Sicherung
  und Geräteübertragung aus. Die Daten liegen zusätzlich im `no_backup`-Verzeichnis.
- Von außen ansprechbar ist nur der Startbildschirm. Der Empfänger, den die Bibliothek `androidx.profileinstaller`
  für Entwicklerwerkzeuge einträgt, ist aus dem Manifest entfernt.
- Kein WebView, keine dynamisch nachgeladenen Programmteile.
- Alle Textfelder schalten das Lernen der Tastatur ab (`enableIMEPersonalizedLearning: false`), damit Symptome,
  Notizen und Lebensmittel nicht im Wörterbuch der Tastatur landen. Die Felder für die Passphrase schalten zusätzlich
  Vorschläge und Autokorrektur ab und zeigen die Eingabe verdeckt.
- Die App schreibt keine Inhalte in das Systemprotokoll.
- Bildschirmfotos sind erlaubt (kein `FLAG_SECURE`). Das ist eine Entscheidung für den Nutzer, der einen Verlauf zeigen
  oder weitergeben möchte; die Vorschau in der Übersicht der zuletzt verwendeten Apps zeigt dadurch den zuletzt
  sichtbaren Bildschirm.

## Signatur der APK

Die APK ist mit dem Schlüssel des lokalen Builds signiert (`app/android/app/morphhealth-local.jks`, Alias und
Passwörter `morphhealth-local`, RSA 3072, Signaturschema v2). Dieser Schlüssel gehört absichtlich zum Projekt und ist
kein Geheimnis: Er sorgt dafür, dass wiederholte Builds dieselbe Signatur tragen und sich über eine vorhandene
Installation installieren lassen, ohne deren Daten zu verlieren. Er sagt nichts über die Herkunft einer APK aus. Für
eine Veröffentlichung gehört ein eigener, geheim gehaltener Schlüssel in `android/app/build.gradle.kts`. Fehlt die
Datei, legt `build.sh` einen neuen Schlüssel an; eine bereits installierte App muss dann vor der Installation
entfernt werden.

## Verwendete Bibliotheken

Laufzeit der App und des Wartungszugangs, Versionen laut `app/pubspec.lock`:

| Paket | Version | Zweck |
|---|---|---|
| Flutter SDK (`flutter`, `flutter_localizations`) | 3.41.9 | Oberfläche, Lokalisierung der Systemtexte |
| Dart SDK | 3.11.5 | Sprache und Standardbibliothek (`dart:io` für Dateien und HTTPS, `dart:convert`, gzip) |
| `intl` | 0.20.2 | Datums- und Zahlenformate |
| `cryptography` | 2.9.0 | XChaCha20-Poly1305, HKDF-SHA-256, Argon2id |
| transitiv: `crypto` 3.0.8, `ffi` 2.2.0, `typed_data` 1.4.0, `collection` 1.19.1, `meta` 1.17.0, `clock` 1.1.2, `path` 1.9.1, `characters` 1.4.1, `material_color_utilities` 0.13.0, `vector_math` 2.2.0 | | Abhängigkeiten der genannten Pakete |

Android-Seite: Flutter-Embedding und die von ihm mitgebrachten androidx-Bibliotheken, Kotlin-Standardbibliothek, der
Android Keystore des Systems. Es gibt keine Flutter-Plugins und keine eigenen nativen Bibliotheken außer der
Flutter-Engine.

Nur für Entwicklung und Test: `flutter_test`, `flutter_lints` 6.0.0, `lints`, `test` 1.30.0 und deren Abhängigkeiten.
Die Prüfskripte in `tools/` verwenden ausschließlich die Standardbibliothek von Python 3.

## Grenzen

- **Entsperrtes Gerät.** Wer das entsperrte Gerät benutzt, sieht die Daten. Eine eigene App-Sperre gibt es nicht.
- **Systemrechte.** Auf einem Gerät mit Root-Zugriff kann ein Angreifer die laufende App beobachten oder den
  Keystore-Schlüssel im Namen der App benutzen. Die Verschlüsselung schützt Kopien der Dateien; gegen ein
  kompromittiertes Betriebssystem hilft sie nicht.
- **Zurückspielen alter Stände.** Jede Datei ist authentifiziert und Journal und Schnappschuss sind aneinander
  gebunden. Ersetzt jemand mit Schreibzugriff auf das private Verzeichnis beide Dateien durch eine ältere,
  zusammengehörige Fassung, bemerkt die App das nicht. Ebenso lässt sich das Journal am Ende um vollständige Sätze
  kürzen. Ein Zähler außerhalb der Dateien (zum Beispiel im Keystore) würde das verhindern und ist nicht umgesetzt.
- **Arbeitsspeicher.** Der Hauptschlüssel und der entschlüsselte Bestand liegen im Speicher der laufenden App. Dart
  bietet kein verlässliches Überschreiben von Speicher; Passphrasen und Schlüssel werden nicht aktiv gelöscht.
- **Reines Dart.** Die Kryptografie läuft in Dart ohne zugesicherte Laufzeitkonstanz. Für lokal gespeicherte Dateien
  ohne Netzdienst, der Zeitmessungen zuließe, ist das hinnehmbar.
- **Größe und Zeitpunkte.** Dateigrößen und Änderungszeiten verraten, dass und ungefähr wie viel eingetragen wurde.
- **Exportdateien** sind Klartext und liegen dort, wo der Nutzer sie speichert, zum Beispiel in einem Ordner, den
  andere Apps lesen dürfen.
- **Passphrase.** Die Stärke einer Sicherung hängt an der Passphrase. Argon2id verteuert das Raten, ersetzt aber keine
  gute Passphrase. Eine vergessene Passphrase lässt sich nicht zurücksetzen.
- **Schlüsselverlust.** Löscht das System den Keystore-Schlüssel (zum Beispiel beim Zurücksetzen des Geräts) oder wird
  die App deinstalliert, sind die lokalen Daten ohne Sicherung verloren. Die App erklärt das auf dem
  Problembildschirm.
- **Lebensmitteldienst.** Der Betreiber des konfigurierten Dienstes sieht Suchbegriffe, Barcodes, IP-Adresse und
  Zeitpunkt der Anfragen. Wer das nicht möchte, lässt die Online-Suche ausgeschaltet und verwendet eigene
  Lebensmittel.
- **Signierschlüssel.** Der mitgelieferte Schlüssel beweist keine Herkunft (siehe oben).

## Prüfungen

- Tests des Fachkerns: Testvektoren der Primitive; jede Art von Veränderung an Chiffrat, Nonce, Tag und AAD wird
  erkannt; falscher Schlüssel; abgebrochener Schreibvorgang im Journal; vertauschte und fremde Journalsätze;
  Sicherung mit falscher Passphrase, veränderten Kopfdaten und unzulässigen Parametern; Ablehnung von Adressen ohne
  HTTPS und von Weiterleitungen auf fremde Hosts.
- `tools/mh_check.py`: falscher Schlüssel, zu kurze Schlüsseldatei, Schlüsseldatei im Datenordner, kein Klartext im
  Datenordner.
- `tools/apk_check.py`: Berechtigungen, Sicherungs- und Netzwerkeinstellungen des Manifests, von außen erreichbare
  Komponenten, Signatur.
- `tools/device_check.py`: nach echten Eingaben auf dem Referenzgerät liegen im privaten Verzeichnis genau die vier
  erwarteten Dateien, und keine private Datei enthält Klartext aus den Einträgen.
