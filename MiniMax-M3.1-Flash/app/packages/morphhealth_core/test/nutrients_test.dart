import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:test/test.dart';

void main() {
  group('nutrient registry', () {
    test('covers the whole scope of the product order', () {
      const List<String> vitamins = <String>[
        'vitamin_a',
        'vitamin_c',
        'vitamin_d',
        'vitamin_e',
        'vitamin_k',
        'vitamin_b1',
        'vitamin_b2',
        'vitamin_b3',
        'vitamin_b5',
        'vitamin_b6',
        'vitamin_b7',
        'vitamin_b9',
        'vitamin_b12',
      ];
      const List<String> minerals = <String>[
        'calcium',
        'iron',
        'magnesium',
        'potassium',
        'zinc',
        'selenium',
        'iodine',
        'phosphorus',
      ];
      const List<String> extended = <String>[
        'saturated_fat',
        'sugars',
        'fiber',
        'salt',
        'sodium',
        'caffeine',
      ];

      for (final String id in <String>[
        ...vitamins,
        ...minerals,
        ...extended,
        'energy_kcal',
        'protein',
        'carbohydrates',
        'fat',
      ]) {
        expect(Nutrients.specOf(id), isNotNull, reason: 'missing $id');
      }
      expect(Nutrients.vitamins, hasLength(13));
      expect(Nutrients.minerals, hasLength(8));
      expect(Nutrients.extended, hasLength(6));
      expect(Nutrients.macros, hasLength(3));
    });

    test('every nutrient has a German and an English label', () {
      for (final NutrientSpec spec in Nutrients.all) {
        expect(spec.deLabel, isNotEmpty);
        expect(spec.enLabel, isNotEmpty);
        expect(spec.label('de'), isNotEmpty);
        expect(spec.label('en'), isNotEmpty);
      }
    });

    test('display units convert from grams', () {
      final NutrientSpec vitaminC = Nutrients.specOf(Nutrients.vitaminC)!;
      expect(vitaminC.unit, NutrientUnit.mg);
      expect(vitaminC.toDisplay(0.05), closeTo(50, 1e-9));
      final NutrientSpec protein = Nutrients.specOf(Nutrients.protein)!;
      expect(protein.toDisplay(12), closeTo(12, 1e-9));
    });

    test('profiles scale and add up', () {
      const NutrientProfile a = NutrientProfile(<String, double>{
        Nutrients.protein: 10,
        Nutrients.fat: 5,
      });
      final NutrientProfile half = a.scaled(0.5);
      expect(half[Nutrients.protein], 5);
      final NutrientProfile sum = a + half;
      expect(sum[Nutrients.protein], 15);
      expect(sum[Nutrients.fat], 7.5);
    });
  });

  group('date helpers', () {
    test('formats and parses calendar days', () {
      expect(DateMath.format(DateTime(2026, 9, 23)), '2026-09-23');
      expect(DateMath.parse('2026-09-23').year, 2026);
    });

    test('counts days between two calendar days', () {
      expect(DateMath.dayDiff('2026-09-01', '2026-09-23'), 22);
      expect(DateMath.dayDiff('2026-09-23', '2026-09-01'), -22);
    });

    test('builds inclusive ranges', () {
      final List<String> range = DateMath.range('2026-09-21', '2026-09-23');
      expect(range, <String>['2026-09-21', '2026-09-22', '2026-09-23']);
    });

    test('adds days across month borders', () {
      expect(DateMath.addDays('2026-09-30', 1), '2026-10-01');
      expect(DateMath.addDays('2026-03-01', -1), '2026-02-28');
    });
  });

  group('translations', () {
    test('German and English cover the same keys', () {
      final Set<String> german = Strings.de.t('nav.overview') == 'Übersicht'
          ? const <String>{'nav.overview'}
          : const <String>{};
      expect(german, isNotEmpty, reason: 'German must be the default');
      expect(Strings.en.t('nav.overview'), 'Overview');
      expect(Strings.de.t('nav.overview'), 'Übersicht');
    });

    test('every German key also exists in English', () {
      final Set<String> german = Strings.allKeys;
      expect(german, isNotEmpty);
      for (final String key in german) {
        expect(
          Strings.en.t(key),
          isNot(equals(key)),
          reason: 'missing English translation for $key',
        );
      }
    });

    test('every placeholder can be substituted', () {
      for (final String key in Strings.allKeys) {
        final String german = Strings.de.t(key);
        final RegExpMatch? match =
            RegExp(r'\{([a-z_]+)\}').firstMatch(german);
        if (match == null) {
          expect(Strings.en.t(key).contains('{'), isFalse, reason: '$key (en)');
          continue;
        }
        final Map<String, String> params = <String, String>{
          for (final RegExpMatch m in RegExp(r'\{([a-z_]+)\}')
              .allMatches(german))
            m.group(1)!: '1',
        };
        expect(
          Strings.de.t(key, params).contains('{'),
          isFalse,
          reason: '$key (de)',
        );
        expect(
          Strings.en.t(key, params).contains('{'),
          isFalse,
          reason: '$key (en)',
        );
      }
    });

    test('fills placeholders', () {
      expect(
        Strings.de.t('cycle.cycle_day', <String, String>{'day': '7'}),
        'Zyklustag 7',
      );
      expect(
        Strings.en.t('cycle.cycle_day', <String, String>{'day': '7'}),
        'Cycle day 7',
      );
    });
  });
}
