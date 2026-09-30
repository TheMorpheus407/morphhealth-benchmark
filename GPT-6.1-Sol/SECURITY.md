# Sicherheitskonzept

MorphHealth ist eine lokale Einzelbenutzer-App. Persönliche Gesundheitsdaten verlassen die Installation nur durch einen ausdrücklich ausgewählten Export oder eine Sicherung über den Android-Dateidialog. Online-Suche ist standardmäßig ausgeschaltet. Sie sendet Suchtext/Barcode und den konfigurierten User-Agent an den konfigurierten HTTPS-Origin. Es gibt keine Werbung, Telemetrie, Laufzeit-KI, Konten oder Gesundheitsplattform-Anbindung.

## Lokaler Bestand

`app/lib/core/storage.dart` verwendet **AES-256-GCM** aus [cryptography 2.9.0](https://pub.dev/packages/cryptography/versions/2.9.0). Jede Speicherung bekommt einen kryptografisch zufälligen 12-Byte-Nonce und einen 16-Byte-Authentifizierungstag. Der gesamte portable JSON-Bestand, einschließlich Einstellungen, Lebensmittel, Favoriten, Notizen und Zeitangaben, liegt innerhalb des Ciphertexts. Auch Indizes existieren nur im Arbeitsspeicher.

Die Datei `health.mhv` ist UTF-8-JSON:

```json
{
  "format": "morphhealth-vault",
  "version": 1,
  "cipher": "AES-256-GCM",
  "kdf": null,
  "nonce": "<Base64, 12 Bytes>",
  "ciphertext": "<Base64>",
  "tag": "<Base64, 16 Bytes>"
}
```

Die Additional Authenticated Data sind die kompakte UTF-8-JSON-Codierung der vier Headerfelder in dieser Reihenfolge: `format`, `version`, `cipher`, `kdf`. Der GCM-Tag schützt Ciphertext und Header. Unbekanntes Format, falscher Schlüssel und Manipulation führen zu einem Fehler. Die App erzeugt bei einer beschädigten Datei keinen stillen Ersatzbestand.

Schreibvorgänge werden im Controller serialisiert. Der validierte neue Bestand wird in einem Hintergrund-Isolate verschlüsselt, nach `health.mhv.tmp` geschrieben und geflusht; die temporäre Datei enthält ebenfalls ausschließlich Ciphertext. Rename ersetzt anschließend `health.mhv`. Erst nach erfolgreicher Speicherung wird der Arbeitsspeicherbestand gewechselt. Im Linux-Prozess sorgt ein exklusiver Dateilock für einen einzelnen Schreiber; die Gesundheitsdatei bekommt Modus 0600.

## Android-Schlüssel und Berechtigungen

Kotlin generiert einen zufälligen 32-Byte-Datenschlüssel. Dieser wird mit einem AES-256-GCM-Schlüssel des [Android Keystore](https://developer.android.com/privacy-and-security/keystore) unter dem Alias `morphhealth-wrapping-v1` verschlüsselt. Der Keystore-Schlüssel ist nicht exportierbar. `files/vault-key.wrapped` enthält 12 Bytes IV, 32 Bytes verschlüsselten Datenschlüssel und 16 Bytes GCM-Tag; der rohe Datenschlüssel wird nie als Datei gespeichert.

Der entschlüsselte Datenschlüssel gelangt zum gemeinsamen Dart-Kern und bleibt während der Nutzung im Prozessspeicher. Die Hardwarebindung des Keystore-Schlüssels hängt vom Gerät ab; für den AOSP-Emulator wird keine Hardware-Schutzgarantie behauptet. Schlüsselbenutzung erfordert keine zusätzliche App-Authentifizierung, damit wiederkehrende Erfassungen ohne Dialog möglich sind. Der Gerätebildschirm sollte geschützt sein.

Der Bestand liegt in `files/morphhealth/health.mhv` im privaten Android-App-Speicher. Android Auto Backup ist abgeschaltet. Es werden weder Kamerazugriff, Gesundheitsberechtigungen noch allgemeine Dateisystem-/Profilrechte angefordert. Die Release-App ist nicht debuggable. Die Internetberechtigung ermöglicht ausschließlich die vom Nutzer aktivierte Lebensmittelanbindung. Benutzer wählen Import-/Exportdateien mit `OPEN_DOCUMENT` und `CREATE_DOCUMENT`. Dateiinhalte werden im Speicher übertragen; es gibt keine temporäre Klartextdatei im App-Verzeichnis.

Die geprüfte APK verlangt als einzige Android-Systemberechtigung `INTERNET`.
AndroidX ergänzt eine app-eigene Signaturberechtigung für nicht exportierte
dynamische Receiver. Sie gibt der App keinen Zugriff auf persönliche
Plattformdaten. Das tatsächliche Release-Manifest und die Signaturprüfung liegen
unter `artifacts/apk-manifest.xml` und `artifacts/apk-signature.txt`.

## Geschützte Sicherung

Eine Sicherung enthält denselben vollständigen portable Bestand und benötigt keinen ursprünglichen Geräte- oder Datenschlüssel. Daher ist sie auf einer frischen Installation wiederherstellbar.

Dateiformat: UTF-8-JSON, Standardendung `.mhbackup.json`:

```json
{
  "format": "morphhealth-backup",
  "version": 1,
  "cipher": "AES-256-GCM",
  "kdf": {
    "name": "PBKDF2-HMAC-SHA256",
    "iterations": 600000,
    "salt": "<Base64, 16 zufällige Bytes>"
  },
  "nonce": "<Base64, 12 zufällige Bytes>",
  "ciphertext": "<Base64 des verschlüsselten portablen JSON>",
  "tag": "<Base64, 16 Bytes>"
}
```

`cryptography` implementiert PBKDF2-HMAC-SHA256, 600.000 Iterationen und 256 abgeleitete Schlüsselbits. Passwort-Bytes sind UTF-8 ohne Trimmen oder Normalisierung. Beim Erstellen sind mindestens zehn Unicode-Zeichen und identische Bestätigung erforderlich. Es gibt keine Wiederherstellung einer verlorenen Passphrase.

Die Headerfelder einschließlich KDF-Parameter und Salt sind als AAD authentifiziert. Wiederherstellung akzeptiert ausschließlich diese feste KDF-Konfiguration und die dokumentierten Nonce-/Salt-/Taggrößen. Fremde Iterationszahlen können deshalb keine unkontrollierte KDF-Arbeit auslösen. Entschlüsselung und vollständige Datenschemavalidierung passieren vor einer Ersatzbestätigung und Änderung des Arbeitsbestands. Die Passphrase wird weder gespeichert noch protokolliert.

## Portabler Klartext und Linux

Das portable `morphhealth`-Format ist dokumentiert in [FORMAT.md](docs/FORMAT.md). JSON-Export ist absichtlich Klartext und verlangt in der Oberfläche einen ausdrücklichen Hinweis beziehungsweise im Wartungszugang `ack_plaintext:true`. Ein Import verlangt `confirm_replace:true` beziehungsweise eine Bestätigung mit Eintragszahlen.

Linux bekommt den Datenschlüssel aus einer externen Datei mit exakt 32 rohen Bytes. Datenverzeichnis und Schlüsseldatei müssen absolute Pfade sein; Symlinks werden aufgelöst, und die Schlüsseldatei darf nicht im Datenverzeichnis liegen. Der Betreiber schützt die Schlüsseldatei mit passenden Dateirechten, zum Beispiel 0600. Ihr Verlust macht den Bestand ohne einen zuvor angefertigten portablen Export oder eine Sicherung unlesbar.

Der lokale JSONL-Prozess bindet keinen Netzwerksocket und führt keine eingelesenen Befehle aus. Er gibt nur angeforderte Ergebnisse auf stdout aus. Die Lebensmittelfunktionen sind explizite lesende Netzwerkanfragen; Tagebuch, Ernährungsauswertung und Zyklus sind offline.

## HTTPS und Abhängigkeiten

`dart:io HttpClient` verwendet normales Zertifikatsvertrauen. Es gibt keinen `badCertificateCallback`, keinen HTTP-Fallback und keine Veränderung des System-Vertrauensspeichers. In der bereitgestellten Umgebung funktionieren die installierte lokale CA und `adb reverse`. API-Origin und User-Agent werden injiziert. Die Implementierung setzt ausschließlich GET ein und begrenzt Netzwerkantwortgröße und Wartezeit.

Direkte Laufzeitabhängigkeiten sind Flutter, Flutter-Lokalisierungen, [intl 0.20.2](https://pub.dev/packages/intl/versions/0.20.2) und cryptography 2.9.0. Transitiver Stand ist vollständig in `app/pubspec.lock` gesperrt. Android-Schlüssel/Dateidialoge verwenden Plattform-APIs über einen schmalen MethodChannel. Die lokale Release-Signatur liegt separat in `.signing/` und wird von `build.sh` erzeugt beziehungsweise wiederverwendet.

## Grenzen und Nachweise

Verschlüsselung schützt gespeicherte Dateien und erkennt Manipulation. Sie verhindert weder Zugriff durch einen kompromittierten laufenden App-Prozess beziehungsweise entsperrtes Gerät noch Screenshots durch den Nutzer. Die UI ist bewusst ohne zusätzliche App-PIN verwendbar. Root-/OS-Kompromittierung, kompromittierte Tastaturen, absichtlich erzeugte Klartextexporte und die Sicherheit eines vom Nutzer gewählten Dokumentanbieters liegen außerhalb dieses Dateischutzes.

„Alle lokalen Daten löschen“ ersetzt alle Gesundheitsdaten, Lebensmittel und Einstellungen durch einen leeren authentifiziert verschlüsselten Bestand. Exportierte Dateien und Sicherungen bleiben am gewählten Speicherort. Das ist eine logische Löschung; eine forensische Löschung alter Flash-Blöcke wird nicht versprochen.

Tests prüfen Roundtrip, abweichenden Schlüssel, geänderten Ciphertext, falsche Passphrase, geschützte Header/KDF-Konfiguration, ungültigen Import ohne Änderung des Arbeitsbestands, verschlüsselte Dateien ohne Namen/Notizen im Klartext und Wiederherstellung auf einer neuen Installation mit anderem Datenschlüssel. Die Android-Geräteprüfung benutzt ausschließlich synthetische Daten.
