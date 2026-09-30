# MorphHealth · Flutter-Anwendung

Einstieg: `lib/main.dart`. Die gemeinsame Fachlogik für Android und den
Linux-Wartungszugang liegt in `lib/core/`, die Oberfläche in `lib/ui/`.
`tool/mh.dart` verwendet dieselben Validatoren, Berechnungen, API- und
Verschlüsselungsfunktionen.

Build und Prüfung erfolgen vom übergeordneten Abgabeordner mit
`./build.sh` beziehungsweise `./check.sh`. Bedienung, Ergebnisse und Grenzen
stehen in der [README](../README.md), Feldtypen im
[Datenvertrag](../docs/FORMAT.md), Dateischutz im
[Sicherheitskonzept](../SECURITY.md).
