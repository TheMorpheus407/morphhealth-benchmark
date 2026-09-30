import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/issues.dart';
import 'package:morphhealth/core/portable.dart';
import 'package:morphhealth/ui/issue_text.dart';

void main() {
  test('Prüfmeldungen des Imports gibt es auf Deutsch und Englisch', () {
    expect(issueMessage('de', 'Pflichtfeld fehlt'), 'Pflichtfeld fehlt');
    expect(issueMessage('en', 'Pflichtfeld fehlt'), 'required field missing');
    expect(issueMessage('en', 'höchstens 200 Zeichen erlaubt'), 'at most 200 characters allowed');
    expect(issueMessage('en', 'muss größer als 0 sein'), 'must be greater than 0');
    expect(issueMessage('en', 'Eine Periode darf höchstens 60 Tage umfassen'), 'a period can span at most 60 days');
  });

  test('Kein deutscher Rest in den englischen Meldungen eines kaputten Dokuments', () {
    final doc = {
      'format': 'anderes-format',
      'version': 99,
      'settings': {
        'language': 'fr',
        'weight_unit': 5,
        'areas': 'alle',
        'expected_cycle_length_days': 3.5,
        'unbekannt': 1,
      },
      'goals': {'water_ml': -1, 'energy_kcal': 'viel'},
      'foods': [
        {
          'id': 'a',
          'name': '',
          'nutrients': {'energy_kcal': -5, 'protein_g': 'x'},
          'serving': {'amount': 0},
        },
        {'id': 'a', 'name': 'x' * 300, 'basis': 'liter'},
        {'brand': 'ohne Namen'},
      ],
      'food_entries': [
        {
          'id': 'e',
          'at': 'gestern',
          'amount': 0,
          'unit': 'portion',
          'food': {'name': 'x'},
        },
        {'id': 'f', 'at': '2026-09-28T07:00', 'amount': 1, 'meal': 'brunch', 'food_id': 'gibtsnicht'},
        {'at': '2026-09-28T07:00', 'amount': 1},
      ],
      'water_entries': [
        {'at': '2026-09-28', 'ml': 'viel'},
        {'at': 5, 'ml': 99999},
      ],
      'weight_entries': [
        {'at': '2026-09-28T07:00', 'kg': 0.2},
      ],
      'periods': [
        {'start': '2026-09-01', 'end': '2026-08-01'},
        {'start': '2026-01-01', 'end': '2026-12-31'},
        {
          'start': '2026-05-01',
          'end': '2026-05-03',
          'day_flows': {'2026-05-09': 'heavy', 'kein-datum': 'light'},
        },
        {'start': '2026-05-02', 'end': '2026-05-04'},
      ],
      'symptom_entries': [
        {'name': '', 'intensity': 11, 'at': '2026-09-28T07:00'},
        {'name': 'x', 'intensity': 2.5, 'at': '2026-09-28T07:00'},
      ],
      'caffeine_entries': 'kaffee',
    };
    late List<Issue> issues;
    try {
      final parsed = parsePortable(doc);
      issues = parsed.report.warnings;
    } on ValidationException catch (e) {
      issues = e.issues;
    }
    expect(issues.length, greaterThan(15), reason: 'das Dokument soll viele verschiedene Meldungen auslösen');
    // Typische deutsche Wörter der Kernmeldungen dürfen nach der Übersetzung nicht mehr vorkommen.
    final german = RegExp(
      r'erwartet|Pflichtfeld|höchstens|mindestens|muss |darf |ungültig|Zeichen|Periode|liegt|fehlt|nicht|oder|sind:|kommt|Schlüssel|Liste|Objekt|Zahl|Datum|Zeitpunkt|Feld ignoriert',
    );
    for (final i in issues) {
      final en = issueMessage('en', i.message);
      expect(german.hasMatch(en), isFalse, reason: '${i.path}: "${i.message}" -> "$en"');
    }
  });
}
