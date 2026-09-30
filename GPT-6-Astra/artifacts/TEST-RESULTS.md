# MorphHealth – tatsächlicher Abschlussprüfstand

Datum: 26.09.2026. Auftrag: MH-PERSONAL-3 / 1.0-rc3-L1.

## Abgabe

- `morphhealth.apk`: Release, Version 1.0.0 / Code 1, Package `de.themorpheus.morphhealth.local`.
- ABIs: `arm64-v8a`, `x86_64`; minSdk 24, targetSdk 36.
- SHA-256: `06e2f172a7ff092ac18079867e46cc24da5db93bdabd0c709ef413478f67dcbc`.
- APK gebaut, abschließend auf `emulator-5560` installiert und gestartet.
- `SPEC.md` und `ENVIRONMENT.json` unverändert; SHA-256 geprüft.

## Automatisierte Prüfungen

- `./check.sh`: statische Analyse ohne Befund; **49 Tests bestanden**.
- Zusätzlich **15 CLI-Prozessprüfungen** bestanden, einschließlich echtem HTTPS-Abruf am bereitgestellten Origin, Flush, EOF und verschlüsselter Persistenz.
- Protokoll: [check.log](check.log), [cli-check.json](cli-check.json).
- Build: [build.log](build.log); Prüfsumme: [morphhealth.apk.sha256](morphhealth.apk.sha256).

## Tatsächlich auf Android bedient

- Online-Suche „Hafer“, Produktdetail und Tagebucherfassung.
- JSON-Import über den nativen Dateidialog.
- Verschlüsselte Sicherung; Wiederherstellung nach vollständiger Deinstallation und frischer Installation.
- Kalender, persönliche Zykluseinschätzung, gemeinsame Tageswerte.
- Import eines synthetischen Bestands mit 10.000 Mahlzeiten über mehrere Jahre.
- Historien-Freitextsuche, Öffnen des Eintrags vom 23.11.2019 und Korrektur von 125 auf 130 ml.
- Sieben- und 28-Tage-Verlauf; Erhalt der Daten nach Prozessneustart.
- Öffnen des älteren unkomprimierten Tresors und erneutes verschlüsseltes Speichern mit gzip; 250 ml Wasser ergänzt.
- Deutsche und englische Oberfläche.
- Neue native Sicherung des großen Bestands; auf Linux ohne Android-Schlüssel entschlüsselt: 10.000 Mahlzeiten, drei Getränke, Sprache `en`. Ergebnis: [android-backup-check.json](android-backup-check.json).
- Abschließend sämtlichen lokalen Datenbestand über die App gelöscht; leerer deutscher Startzustand nach Prozessneustart bestätigt. Die finale APK bleibt installiert.

## Gemessene Größen

| Prüfung | Ergebnis |
|---|---:|
| Host: 28 Tagesauswertungen / 10.000 Mahlzeiten | 12 ms |
| Host: gefilterte Historienseite | 18 ms |
| Host: verschlüsseltes Speichern / Öffnen | 468 / 235 ms |
| Host: verschlüsselter Testbestand | 96.773 Byte |
| Android: komprimierter verschlüsselter Testbestand | 187.213 Byte |
| Android: Prozessneustart mit diesem Bestand (`am start -W`) | 1.513 ms |
| Android: native verschlüsselte Sicherung des großen Bestands | 187.304 Byte |

Dies sind einzelne Messungen auf der bereitgestellten Umgebung, keine zugesicherten Maximalzeiten. Der Android-Bestand enthält individuelle Notizen und unterscheidet sich deshalb vom Host-Testbestand. Siehe [android-performance.json](android-performance.json) und [Screenshots](screenshots).

Die archivierten Sicherungen und Testdateien enthalten ausschließlich synthetische Daten. Ihre Testpassphrase lautet `MorphHealth-test-2026`. Der native große Export kann mit `dart --packages=app/.dart_tool/package_config.json artifacts/verify-native-backup.dart` vom Projektverzeichnis aus erneut geprüft werden.

## Verbleibende Grenzen

Die Release-APK ist lokal mit der Android-Debug-Signatur signiert. Stärke und Notiz einer Periode gelten für die ganze Episode. Persönliche Einschätzungen benötigen mindestens drei geeignete Periodenbeginne. Der Store speichert einen vollständigen Snapshot (maximal 64 MiB Klartext / 100.000 Datensätze). Weitere Grenzen und das Sicherheitsmodell stehen in [README.md](../README.md) und [SECURITY.md](../SECURITY.md).
