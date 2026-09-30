import 'dart:convert';
import 'model.dart';
import 'nutrients.dart';
import 'storage.dart';

class BusinessClock {
  final DateTime? fixed;
  const BusinessClock([this.fixed]);
  DateTime get now => fixed ?? DateTime.now();
  String get today => dateKey(now);
}

class HealthEngine {
  final VaultStore store;
  final BusinessClock clock;
  HealthData data;
  final _days = <String, Map<String, List<Json>>>{};
  final _nutrition = <String, Json>{};
  HealthEngine(this.store, this.data, {this.clock = const BusinessClock()}) {
    _indexDays();
  }
  void _indexDays() {
    _days.clear();
    _nutrition.clear();
    for (final table in [
      'consumption',
      'drinks',
      'weights',
      'symptoms',
      'bleeding',
    ]) {
      final index = <String, List<Json>>{};
      for (final row in data[table]) {
        final day =
            (row['at'] as String?)?.substring(0, 10) ?? row['date'] as String;
        index.putIfAbsent(day, () => []).add(row);
      }
      _days[table] = index;
    }
  }

  static Future<HealthEngine> open(
    VaultStore store, {
    BusinessClock clock = const BusinessClock(),
  }) async => HealthEngine(store, await store.read(), clock: clock);
  Future<void> replace(dynamic document) async {
    final candidate = HealthData.import(jsonDecode(jsonEncode(document)));
    await store.write(candidate);
    data = candidate;
    _indexDays();
  }

  Future<void> change(void Function(HealthData) mutation) async {
    final candidate = data.copy();
    mutation(candidate);
    await replace(candidate.export(clock.now));
  }

  Json export() => data.export(clock.now);
  List<Json> on(String table, String date) => _days[table]?[date] ?? [];
  Json nutritionDay(String date) {
    parseDay(date);
    if (_nutrition.containsKey(date)) return _nutrition[date]!;
    final entries = on('consumption', date), drinks = on('drinks', date);
    final totals = <String, dynamic>{for (final n in nutrients) n.id: null};
    final coverage = <String, dynamic>{for (final n in nutrients) n.id: 0};
    final calculated = <Json>[];
    for (final e in entries) {
      final values = scaledNutrients(
        e['food'],
        number(e['amount'])!,
        e['unit'],
      );
      for (final n in nutrients) {
        final v = number(values[n.id]);
        if (v != null) {
          totals[n.id] = (number(totals[n.id]) ?? 0) + v;
          coverage[n.id] = (coverage[n.id] as int) + 1;
        }
      }
      calculated.add({
        ...e,
        'base_amount': baseQuantity(e['food'], number(e['amount'])!, e['unit']),
        'nutrients': values,
      });
    }
    double water = 0, caffeine = 0;
    for (final d in drinks) {
      if (d['kind'] == 'water') {
        water += number(d['amount'])!;
      } else {
        caffeine += number(d['amount'])!;
      }
    }
    if (drinks.any((d) => d['kind'] == 'caffeine')) {
      totals['caffeine'] = (number(totals['caffeine']) ?? 0) + caffeine;
    }
    final result = <String, dynamic>{
      'date': date,
      'nutrients': totals,
      'units': {for (final n in nutrients) n.id: n.unit},
      'known_food_count': coverage,
      'food_count': entries.length,
      'incomplete_nutrients': nutrients
          .where((n) => coverage[n.id] < entries.length)
          .map((n) => n.id)
          .toList(),
      'water_ml': water,
      'additional_caffeine_mg': caffeine,
      'goals': data.settings['goals'],
      'entries': calculated,
      'drinks': drinks,
    };
    if (_nutrition.length >= 64) _nutrition.remove(_nutrition.keys.first);
    _nutrition[date] = result;
    return result;
  }

  Json? periodOn(String date) {
    for (final p in data['periods']) {
      if ((p['start'] as String).compareTo(date) <= 0 &&
          ((p['end'] ?? clock.today) as String).compareTo(date) >= 0) {
        return p;
      }
    }
    return null;
  }

  Json? bleedingOn(String date) {
    final explicit = on('bleeding', date);
    if (explicit.isNotEmpty) return explicit.first;
    final p = periodOn(date);
    return p == null
        ? null
        : {
            'date': date,
            'strength': p['strength'],
            'note': p['note'],
            'period_id': p['id'],
          };
  }

  Json cycleForecast(String onDay) {
    parseDay(onDay);
    final periods =
        data['periods']
            .where(
              (p) =>
                  p['strength'] != 'spotting' &&
                  (p['start'] as String).compareTo(onDay) <= 0,
            )
            .toList()
          ..sort((a, b) => (a['start'] as String).compareTo(b['start']));
    final intervals = <int>[];
    for (var i = 1; i < periods.length; i++) {
      intervals.add(
        dayDifference(periods[i]['start'], periods[i - 1]['start']),
      );
    }
    final sample = intervals
        .skip(intervals.length > 6 ? intervals.length - 6 : 0)
        .toList();
    final durations = periods
        .where(
          (p) => p['end'] != null && (p['end'] as String).compareTo(onDay) <= 0,
        )
        .map((p) => dayDifference(p['end'], p['start']) + 1)
        .toList();
    final durationSample = durations
        .skip(durations.length > 6 ? durations.length - 6 : 0)
        .toList();
    final enabled = data.settings['cycle_prediction'] as bool;
    final last = periods.isEmpty ? null : periods.last['start'] as String;
    final median = sample.isEmpty
        ? null
        : medianOf(sample.map((e) => e.toDouble()).toList());
    final mad = median == null
        ? null
        : medianOf(sample.map((e) => (e - median).abs()).toList());
    final spread = mad == null ? null : (mad * 1.5).ceil().clamp(2, 10000);
    final predicted = !enabled || median == null
        ? null
        : addDays(last!, median.round());
    final windowStart = predicted == null ? null : addDays(predicted, -spread!);
    final windowEnd = predicted == null ? null : addDays(predicted, spread!);
    final duration = durationSample.isEmpty
        ? null
        : medianOf(durationSample.map((e) => e.toDouble()).toList()).round();
    return {
      'on': onDay,
      'enabled': enabled,
      'method': enabled ? 'median_last_6_start_intervals' : 'journal_only',
      'recorded_starts': periods.length,
      'intervals_days': sample,
      'sample_count': sample.length,
      'median_cycle_days': median,
      'median_absolute_deviation_days': mad,
      'observed_min_days': sample.isEmpty ? null : ([...sample]..sort()).first,
      'observed_max_days': sample.isEmpty ? null : ([...sample]..sort()).last,
      'median_bleeding_days': duration,
      'latest_start': last,
      'cycle_day': last == null ? null : dayDifference(onDay, last) + 1,
      'predicted_start': predicted,
      'window_start': windowStart,
      'window_end': windowEnd,
      'estimated_end': predicted == null || duration == null
          ? null
          : addDays(predicted, duration - 1),
      'recorded_period': periodOn(onDay),
      'status': !enabled
          ? 'journal_only'
          : predicted == null
          ? 'insufficient_history'
          : onDay.compareTo(windowEnd!) > 0
          ? 'past_window'
          : onDay.compareTo(windowStart!) >= 0
          ? 'in_window'
          : 'upcoming',
      'variability': sample.isEmpty
          ? 'unknown'
          : sample.length < 3
          ? 'limited_history'
          : (sample.reduce((a, b) => a > b ? a : b) -
                    sample.reduce((a, b) => a < b ? a : b)) >
                7
          ? 'variable'
          : 'more_consistent',
      'explanation': {
        'uses_recorded_starts_only': true,
        'excludes_future_and_spotting_starts': true,
        'window_rule':
            'median ± max(2, ceil(1.5 × median absolute deviation)); planning range, not a probability interval',
        'missed_prediction_is_not_advanced': true,
      },
    };
  }

  List<Json> history({
    String q = '',
    String? from,
    String? to,
    Set<String>? areas,
  }) {
    if (from != null) parseDay(from);
    if (to != null) parseDay(to);
    final query = q.toLowerCase().trim(), result = <Json>[];
    const area = {
      'consumption': 'nutrition',
      'drinks': 'nutrition',
      'weights': 'weight',
      'periods': 'cycle',
      'bleeding': 'cycle',
      'symptoms': 'symptoms',
    };
    for (final t in area.keys) {
      if (areas != null && !areas.contains(area[t])) continue;
      for (final r in data[t]) {
        final day =
            (r['at'] as String?)?.substring(0, 10) ?? r['date'] ?? r['start'];
        final end = t == 'periods' ? r['end'] ?? '9999-12-31' : day;
        if (from != null && (end as String).compareTo(from) < 0) continue;
        if (to != null && (day as String).compareTo(to) > 0) continue;
        final title = t == 'consumption'
            ? r['food']['name']
            : t == 'symptoms'
            ? r['name']
            : t == 'drinks'
            ? r['kind']
            : t;
        if (query.isNotEmpty) {
          const labels = {
            'consumption': 'Ernährung Nutrition Lebensmittel food',
            'drinks': 'Ernährung Nutrition',
            'weights': 'Gewicht weight kg lb',
            'periods': 'Periode period Zyklus cycle',
            'bleeding': 'Blutung bleeding Zyklus cycle',
            'symptoms': 'Symptom Symptome symptoms',
          };
          final food = r['food'];
          final searchable = [
            title,
            labels[t],
            r['note'],
            r['name'],
            r['meal'],
            r['strength'],
            food is Map ? food['name_en'] : null,
            food is Map ? food['brand'] : null,
            food is Map ? food['barcode'] : null,
            r['amount'],
            r['kg'],
            r['intensity'],
            r['unit'],
            r['kind'] == 'water'
                ? 'Wasser water'
                : r['kind'] == 'caffeine'
                ? 'Koffein caffeine'
                : null,
            const {
              'breakfast': 'Frühstück',
              'lunch': 'Mittagessen',
              'dinner': 'Abendessen',
              'snack': 'Snack',
            }[r['meal']],
            const {
              'none': 'Keine Blutung',
              'light': 'Leicht',
              'medium': 'Mittel',
              'heavy': 'Stark',
              'spotting': 'Spotting',
            }[r['strength']],
            day,
          ].whereType<Object>().join(' ').toLowerCase();
          if (!searchable.contains(query)) continue;
        }
        result.add({
          'table': t,
          'area': area[t],
          'date': day,
          'sort_at': r['at'] ?? day,
          'title': title,
          'record': r,
        });
      }
    }
    result.sort((a, b) => (b['sort_at'] as String).compareTo(a['sort_at']));
    return result;
  }
}

double medianOf(List<double> values) {
  final sorted = [...values]..sort(), middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}
