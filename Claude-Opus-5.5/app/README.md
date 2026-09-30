# MorphHealth – Flutter-Projekt

Dokumentation, Bedienung, Build und Datenformate: [`../README.md`](../README.md),
Sicherheitskonzept: [`../SECURITY.md`](../SECURITY.md).

- `lib/main.dart` – Einstieg der Android-App
- `lib/core/` – Fachkern in reinem Dart (von App und `bin/mh.dart` gemeinsam genutzt)
- `lib/ui/` – Oberfläche
- `bin/mh.dart` – Wartungsprozess (`../mh`)
- `test/`, `integration_test/` – Tests (`../check.sh`, `../check.sh --device`)
- `tool/generate_sample_data.dart` – erzeugt den Beispieldatensatz mit > 10.000 Einträgen
- `test/fixtures/` – echte Antworten des bereitgestellten Open-Food-Facts-Servers (Daten: Open Food Facts, ODbL)
