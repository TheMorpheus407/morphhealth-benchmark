# Sicherheit und Datenschutz

MorphHealth speichert persönliche Daten lokal und verschlüsselt. Die Android-App
und der lokale Wartungszugang benutzen dieselbe Dart-Implementierung für
Datenmodell, Validierung, Berechnung und Speicherung. Es gibt kein Konto, keinen
eigenen Backend-Dienst, keine Telemetrie, Werbung oder Laufzeit-KI.

Diese Datei beschreibt die tatsächliche Implementierung und ihre Grenzen. Die
exakten Dateihüllen, authentifizierten Header, Parameter und Größenlimits stehen
in [docs/SECURITY-CORE.md](docs/SECURITY-CORE.md); das vollständige portable Schema
und das JSON-Lines-Protokoll in [docs/FORMAT.md](docs/FORMAT.md). Die Prüfung im
Rahmen dieser Abgabe ersetzt kein unabhängiges Sicherheitsaudit.

## Verschlüsselter Android-Datenbestand

Beim ersten Start erzeugt die App mit `Random.secure` einen zufälligen Schlüssel
mit 32 Byte. Dieser separate Datenschlüssel verschlüsselt den gesamten
Datenbestand, einschließlich Einstellungen, Lebensmittel, Tagebücher und Notizen,
mit AES-256-GCM. Jeder Schreibvorgang verwendet eine neue zufällige 12-Byte-Nonce
und einen 16-Byte-Authentifizierungstag. Die Datei `vault/health.mhenc` im privaten
Anwendungsverzeichnis enthält eine versionierte JSON-Hülle mit Base64-kodiertem
Chiffrat, keinen Klartext-Datenbestand. Format, Version, Typ und Cipher sind durch
die Prüfung und die zusätzlichen authentifizierten Daten gebunden.

Neue lokale Dateien und Sicherungen komprimieren den vollständigen JSON-Inhalt
vor der Verschlüsselung mit gzip. Das optionale v1-Hüllenfeld
`compression:"gzip"` ist durch den AAD-Zusatz `|compression=gzip` authentifiziert.
Ältere Dateien ohne dieses Feld werden weiterhin mit dem ursprünglichen
unkomprimierten Format gelesen. Die Dekompression erfolgt erst nach erfolgreicher
Authentifizierung, in kleinen Eingabeblöcken und mit einer harten Ausgabegrenze
von 64 MiB. Diese Grenze wird beim Schreiben bereits vor der Kompression geprüft;
Kompression lockert die Größenbeschränkung nicht. Das reduziert die Größe und
die Verarbeitungszeit wiederholter Lebensmittel-Snapshots erheblich.

Der Datenschlüssel wird unter `morphhealth-data-key` mit
`flutter_secure_storage` **11.2.0** gespeichert. Die verwendete Android-Konfiguration
nutzt standardmäßig `RSA/ECB/OAEPWithSHA-256AndMGF1Padding` für das Wrapping des
Speicherschlüssels durch AndroidKeyStore und `AES/GCM/NoPadding` für die
verschlüsselten SharedPreferences-Werte. Der App-Datenschlüssel ist ein solcher
verschlüsselter Wert; er ist getrennt vom internen Schlüssel des Plugins. Das
ist keine Behauptung, dass sämtliche Schlüssel im Dart-Prozess dauerhaft
hardwareisoliert bleiben. Die Standardverfahren sind in der
[Dokumentation der festgelegten Plugin-Version](https://pub.dev/packages/flutter_secure_storage/versions/11.2.0)
beschrieben.

`AndroidOptions(resetOnError: false)` verhindert das automatische Zurücksetzen
des Plugin-Speichers bei einem Entschlüsselungsfehler. Zusätzlich verweigert der
App-Start eine automatische Schlüsselerzeugung, wenn bereits ein nichtleerer
Tresor existiert, dessen Schlüssel fehlt. Ein falscher Schlüssel, beschädigte
Daten oder eine fehlgeschlagene Authentifizierung führen zu einem Fehlerbildschirm;
der vorhandene Datenbestand wird nicht durch einen leeren ersetzt.

Androids automatische Datensicherung ist über `allowBackup="false"` und
`fullBackupContent="false"` deaktiviert. Die eingebundenen
[dataExtractionRules](app/android/app/src/main/res/xml/data_extraction_rules.xml)
schließen die Datenbereiche zusätzlich sowohl von Cloud-Backup als auch vom
Android-Gerätetransfer aus. Der vorgesehene Weg für eine Übernahme ist eine
bewusst erstellte MorphHealth-Sicherung mit eigener Passphrase.

## Schreibvorgänge, Fehler und Löschen

Der Speicher serialisiert Änderungen und hält eine kooperative exklusive
Dateisperre. Eine Transaktion erzeugt zunächst einen vollständig verschlüsselten
neuen Stand in `health.mhenc.pending`, flusht diese Datei und ersetzt die
Hauptdatei durch atomisches Umbenennen. Erst danach wird der sichtbare
Arbeitsspeicherstand geändert. Ein ungültiger Import wird vor dem Ersetzen
abgewiesen. Nicht abgeschlossene temporäre Dateien enthalten ausschließlich
Chiffrat und werden beim erfolgreichen Öffnen verworfen.

Das Dateiverzeichnis wird nach dem Umbenennen nicht gesondert per `fsync`
synchronisiert. Atomisches Ersetzen verhindert gemischte Dateistände; das
Verhalten bei einem vollständigen Stromausfall hängt zusätzlich vom Dateisystem
ab. Ein älterer, gültig verschlüsselter Stand kann nicht als absichtliches
Zurückrollen erkannt werden. Die Dateisperre schützt kooperierende Prozesse,
keinen Angriff mit privilegiertem Dateizugriff.

„Alle lokalen Daten löschen“ ersetzt die Inhalte durch einen leeren,
verschlüsselten Datenbestand. Dabei wird der bestehende Installationsschlüssel
beibehalten. Die Funktion garantiert keine physische Vernichtung alter
Flash-Blöcke, Betriebssystem-Snapshots oder bereits exportierter Dateien.

## Export, Sicherung und Wiederherstellung

Der portable JSON-Export enthält **alle Daten im Klartext**. Die Android-App
verlangt davor eine ausdrückliche Bestätigung. Der CLI-Export erfordert
`ack_plaintext:true`. Export und Import enthalten denselben vollständigen
Datenstand: Einstellungen, Lebensmittel samt Favoriten, Mahlzeiten mit
Lebensmittel-Snapshots, Wasser/Koffein, Perioden, Gewicht und Symptome.

Verschlüsselte Sicherungen haben `format:"morphhealth-encrypted"`,
`kind:"backup"` und `version:1`. Sie nutzen AES-256-GCM mit eigener zufälliger
Nonce. Der Schlüssel wird aus der exakten UTF-8-Passphrase durch
PBKDF2-HMAC-SHA256 mit **600.000 Iterationen**, zufälligem 16-Byte-Salt und
256-Bit-Ausgabe abgeleitet. Die Oberfläche verlangt beim Erstellen mindestens
zehn Zeichen und eine Wiederholung; der Core akzeptiert 10–1024 Dart-String-
Codeeinheiten, ohne Normalisierung oder Kürzung. Eine lange, einzigartige
Passphrase ist entscheidend, weil eine kopierte Sicherung offline angegriffen
werden kann.

Der Backup-Schlüssel hängt nicht vom ursprünglichen Geräteschlüssel ab. Eine
frische Installation kann die Sicherung mit der Passphrase authentifizieren,
entschlüsseln und unter ihrem neuen Installationsschlüssel speichern. Ein falsches
Kennwort, verändertes Chiffrat oder nicht unterstützte KDF-Parameter werden
abgewiesen. Vor einer Übernahme wird das vollständige Schema geprüft; der Nutzer
bestätigt das Ersetzen des vorhandenen Bestands.

Dateien werden über Androids Storage Access Framework an einem vom Nutzer
gewählten Ort geöffnet oder gespeichert. Die App benötigt dafür keine pauschale
Dateisystemberechtigung. Ein ausgewählter Dokumentanbieter kann seinerseits ein
Cloud-Speicher sein. Die Behandlung einer dort gespeicherten Datei richtet sich
nach diesem Anbieter; eine unverschlüsselte Exportdatei bleibt unverschlüsselt.
Dateien, die bereits exportiert wurden, werden beim lokalen Löschen nicht entfernt.

Geht der Installationsschlüssel verloren, kann die vorhandene lokale Datei ohne
diesen Schlüssel nicht wiederhergestellt werden. Die App bewahrt sie auf und
versucht keine automatische Reparatur durch Überschreiben. Eine zuvor erstellte,
passphrasengeschützte Sicherung kann nach einer frischen Installation
wiederhergestellt werden. Ohne Schlüssel und ohne lesbare Sicherung gibt es
keine Wiederherstellung oder Kontowiederherstellung.

## Lokaler Wartungszugang

`mh` startet einen separaten Linux-Prozess mit JSON-Lines-Ein-/Ausgabe. Es gibt
keinen öffentlich erreichbaren Wartungsdienst. Der Aufrufer bestimmt einen
absoluten Datenordner und eine Datei mit genau 32 rohen Schlüsselbytes außerhalb
dieses Ordners. Die Prüfung löst symbolische Links auf. Der Starter setzt
`umask 077`; bestehende Dateiberechtigungen werden dadurch nicht nachträglich
verschärft. Die Schlüsseldatei sollte ausschließlich für ihren Besitzer lesbar
sein, beispielsweise mit Modus 0600 und einem privaten Elternverzeichnis.

Der CLI-Datenordner ist eine eigene Instanz desselben produktiven Speichers und
verwendet dieselben Funktionen wie Android. Es gibt **keinen automatischen Zugriff
auf den gerade geöffneten Android-Tresor** und keine implizite Synchronisation.
Ein vollständiger portabler Export/Import verbindet beide Instanzen. Das
ermöglicht überprüfbare Wartung, ohne den Android-Schlüssel über ein Netzwerk oder
eine öffentliche Schnittstelle freizugeben.

## Netzwerk und Berechtigungen

Die App deklariert als eigene Funktionsberechtigung ausschließlich `INTERNET`.
Kamera, Standort, Kontakte, Plattform-Gesundheitsdaten und biometrische
Berechtigungen werden nicht benötigt. Die Lebensmittelsuche ist standardmäßig
ausgeschaltet und wird vom Nutzer aktiviert. Bei einer Suche oder einem
Barcode-Abruf verlassen ausschließlich der Suchbegriff beziehungsweise Barcode
sowie der konfigurierte User-Agent die App. Persönliche Tagebuchdaten werden
nicht an den Lebensmitteldienst übertragen.

Der Origin und der User-Agent sind konfiguriert, für diese Abgabe aus den
Umgebungswerten. Es werden nur lesende HTTPS-Anfragen verwendet. Zertifikate
werden mit dem regulären Vertrauensspeicher geprüft; es gibt keinen
`badCertificateCallback`, keine Zertifikatsausnahme und keinen unverschlüsselten
HTTP-Fallback. Automatische Weiterleitungen sind deaktiviert. Zeit- und
Antwortgrößenlimits begrenzen fehlgeschlagene Abrufe. Lokale Gesundheitsfunktionen
benötigen keine Netzwerkverbindung.

## Schutzgrenzen und Abgabe

Ein entsperrtes Gerät beziehungsweise eine bereits geöffnete App erlaubt Zugriff
auf die sichtbaren Einträge. Es gibt keine zusätzliche App-PIN, biometrische
Freigabe oder Screenshot-Sperre. Bildschirmaufnahmen und die Android-Übersicht
zuletzt geöffneter Apps werden nicht durch `FLAG_SECURE` blockiert. Gerätesperre
und Kontrolle über das Benutzerkonto bleiben daher Teil des Schutzes.

Root-Zugriff, ein kompromittiertes Betriebssystem, privilegierte Debug-Werkzeuge,
Schadsoftware im Prozess oder physischer Zugriff auf ein entsperrtes Gerät liegen
außerhalb des Schutzversprechens. Klartext und Schlüssel werden während der
Verwendung im Prozess benötigt. Dart-Speicherverwaltung, Strings und Kopien in
Bibliotheken/Isolates erlauben keine vollständige Garantie für Speicherlöschung.
Die Verschlüsselung verbirgt außerdem weder Dateigröße noch Änderungszeitpunkte.

Die APK ist ein Android-Release-Build für lokale Installation und mit der lokalen
Debug-Signierkonfiguration signiert. Sie ist keine Store-Veröffentlichung und
keine Abgabe mit einem verwalteten Produktions-Signierschlüssel. Eine künftige
Veröffentlichung braucht ein entsprechendes Signier- und Updateverfahren.

Die maßgeblichen Abhängigkeiten sind durch `app/pubspec.lock` festgelegt:
`cryptography` 2.9.0 für AES-GCM und PBKDF2/HMAC/SHA-256,
`flutter_secure_storage` 11.2.0 für Android-Schlüsselspeicherung und
`path_provider` für den privaten App-Datenpfad. Native Dateiauswahl verwendet
Androids Storage Access Framework; HTTPS verwendet Darts `HttpClient`.

Automatisierte Prüfungen behandeln falsche Schlüssel, manipuliertes Chiffrat,
veränderte KDF-Parameter, fehlgeschlagene Importe ohne Datenverlust, parallele
Änderungen, Wiederherstellung unter einem anderen Schlüssel, Formatgrenzen und
den Bestand mit 10.000 Einträgen. Der Android-Datenbestand und eine über die App
erstellte Sicherung wurden zusätzlich als verschlüsselte Hüllen überprüft;
Belege liegen in `artifacts/android-at-rest.mhenc` und
`artifacts/android-test.mhbackup.json`. Die Dateien stammen aus Testdaten.
Weitere tatsächlich ausgeführte Produktprüfungen und Build-Ergebnisse stehen in
[README.md](README.md) und den Prüfprotokollen unter `artifacts/`.
