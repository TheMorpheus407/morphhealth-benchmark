import 'civil.dart';
import 'cycle.dart';

/// Datum als Text für Erklärungen: `12.09.2026` (de) beziehungsweise
/// `12 Sep 2026` (en).
String formatDayText(Day d, String lang) {
  if (lang == 'en') {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

String _num(double v, int decimals, String lang) {
  final s = v.toStringAsFixed(decimals);
  return lang == 'en' ? s : s.replaceAll('.', ',');
}

String _days(int n, String lang) => lang == 'en' ? (n == 1 ? '1 day' : '$n days') : (n == 1 ? '1 Tag' : '$n Tage');

/// Die verständliche Erklärung der Einschätzung als Liste kurzer Absätze.
/// Deutsch (`de`) oder Englisch (`en`).
List<String> explainForecast(Forecast f, String lang) {
  final en = lang == 'en';
  final out = <String>[];
  String d(Day x) => formatDayText(x, lang);

  switch (f.status) {
    case ForecastStatus.disabled:
      return [
        en
            ? 'The forecast is switched off. The cycle area works as a diary only.'
            : 'Die Prognose ist ausgeschaltet. Der Zyklusbereich arbeitet nur als Tagebuch.',
      ];
    case ForecastStatus.noData:
      return [
        en ? 'No periods have been recorded yet.' : 'Es sind noch keine Perioden erfasst.',
        en
            ? 'As soon as two period start dates are recorded, MorphHealth works out your typical cycle length from them and estimates the next start.'
            : 'Sobald zwei Periodenbeginne vorliegen, ermittelt MorphHealth daraus deine typische Zykluslänge und schätzt den nächsten Beginn.',
      ];
    default:
      break;
  }

  if (f.status == ForecastStatus.inPeriod && f.periodDay != null) {
    out.add(en ? 'Today is day ${f.periodDay} of your period.' : 'Heute ist Tag ${f.periodDay} deiner Periode.');
  }

  if (f.lastPeriodStart != null) {
    out.add(
      en
          ? 'Basis: your last recorded period start on ${d(f.lastPeriodStart!)}${f.cycleDay != null ? ' (cycle day ${f.cycleDay})' : ''}.'
          : 'Grundlage: dein letzter erfasster Periodenbeginn am ${d(f.lastPeriodStart!)}${f.cycleDay != null ? ' (Zyklustag ${f.cycleDay})' : ''}.',
    );
  }

  if (f.basis == 'history') {
    final n = f.usedLengths.length;
    final lengths = f.usedLengths.join(', ');
    if (n == 1) {
      out.add(
        en
            ? 'The last cycle (interval between two period starts) lasted $lengths days.'
            : 'Der letzte Zyklus (Abstand zwischen zwei Periodenbeginnen) dauerte $lengths Tage.',
      );
    } else {
      out.add(
        en
            ? 'The last $n cycles (intervals between period starts) lasted $lengths days. Average: ${_num(f.averageCycleDays!, 1, lang)} days, variation: ±${_num(f.spreadDays ?? 0, 1, lang)} days.'
            : 'Die letzten $n Zyklen (Abstände zwischen Periodenbeginnen) dauerten $lengths Tage. Mittelwert: ${_num(f.averageCycleDays!, 1, lang)} Tage, Schwankung: ±${_num(f.spreadDays ?? 0, 1, lang)} Tage.',
      );
    }
  } else if (f.basis == 'manual') {
    out.add(
      en
          ? 'No complete cycle is recorded yet. The cycle length you set in the settings is used: ${_days(f.predictedCycleDays!, lang)}.'
          : 'Es liegt noch kein vollständiger Zyklus vor. Verwendet wird die von dir eingestellte Zykluslänge: ${_days(f.predictedCycleDays!, lang)}.',
    );
  } else {
    // Keine Grundlage.
    if (f.intervals.isEmpty) {
      out.add(
        en
            ? 'One period start is recorded so far. A cycle needs two starts to produce an interval.'
            : 'Bisher ist ein Periodenbeginn erfasst. Ein Zyklus braucht zwei Beginne, damit sich ein Abstand ergibt.',
      );
    } else {
      out.add(
        en
            ? 'The recorded intervals (${f.intervals.map((i) => i.days).join(', ')} days) are outside $kMinCycleDays to $kMaxCycleDays days and are not used. Entries are probably missing.'
            : 'Die erfassten Abstände (${f.intervals.map((i) => i.days).join(', ')} Tage) liegen außerhalb von $kMinCycleDays bis $kMaxCycleDays Tagen und werden nicht verwendet. Vermutlich fehlen Einträge.',
      );
    }
    out.add(
      en
          ? 'Record further periods or set a typical cycle length in the settings.'
          : 'Trage weitere Perioden ein oder lege in den Einstellungen eine typische Zykluslänge fest.',
    );
  }

  final excluded = f.intervals.where((i) => !i.used && i.excludedReason != 'older_than_window').length;
  final older = f.intervals.where((i) => i.excludedReason == 'older_than_window').length;
  if (f.basis != 'none' || f.intervals.isEmpty) {
    if (excluded > 0) {
      out.add(
        en
            ? 'Not used: $excluded interval${excluded == 1 ? '' : 's'} outside $kMinCycleDays to $kMaxCycleDays days (probably missing or duplicate entries).'
            : 'Nicht verwendet: $excluded ${excluded == 1 ? 'Abstand' : 'Abstände'} außerhalb von $kMinCycleDays bis $kMaxCycleDays Tagen (vermutlich fehlende oder doppelte Einträge).',
      );
    }
    if (older > 0) {
      out.add(
        en
            ? 'Older cycles are not included; only the last $kCycleWindow count.'
            : 'Ältere Zyklen fließen nicht ein; es zählen die letzten $kCycleWindow.',
      );
    }
  }

  if (f.predictedStart != null) {
    final k = f.earliest!.daysUntil(f.predictedStart!);
    out.add(
      en
          ? 'The next start is the last start plus ${_days(f.predictedCycleDays!, lang)}: ${d(f.predictedStart!)}.'
          : 'Der nächste Beginn ergibt sich aus dem letzten Beginn plus ${_days(f.predictedCycleDays!, lang)}: ${d(f.predictedStart!)}.',
    );
    out.add(
      en
          ? 'Likely window: ${d(f.earliest!)} to ${d(f.latest!)} (±$k days).${f.basis == 'history' ? ' It follows how much your past cycles vary.' : ''}'
          : 'Wahrscheinliches Zeitfenster: ${d(f.earliest!)} bis ${d(f.latest!)} (±$k Tage).${f.basis == 'history' ? ' Es richtet sich danach, wie stark deine bisherigen Zyklen schwanken.' : ''}',
    );
    if (f.predictedPeriodDays != null) {
      out.add(
        en
            ? 'Typical length of your periods: ${_days(f.predictedPeriodDays!, lang)}.'
            : 'Typische Dauer deiner Perioden: ${_days(f.predictedPeriodDays!, lang)}.',
      );
    }
    final conf = switch (f.confidence) {
      'high' => en ? 'high' : 'hoch',
      'medium' => en ? 'medium' : 'mittel',
      _ => en ? 'low' : 'niedrig',
    };
    out.add(en ? 'Reliability: $conf.' : 'Verlässlichkeit: $conf.');
  }

  if (f.status == ForecastStatus.overdue && f.daysOverdue != null) {
    out.add(
      en
          ? 'The calculated start (${d(f.predictedStart!)}) is ${_days(f.daysOverdue!, lang)} ago and no new period is recorded. Enter the start as soon as it happens and the estimate updates.'
          : 'Der berechnete Beginn (${d(f.predictedStart!)}) liegt ${_days(f.daysOverdue!, lang)} zurück, und es ist noch keine neue Periode erfasst. Trage den Beginn ein, sobald er eintritt, dann aktualisiert sich die Einschätzung.',
    );
  }
  if (f.status == ForecastStatus.stale && f.lastPeriodStart != null) {
    final n = f.lastPeriodStart!.daysUntil(f.on);
    out.add(
      en
          ? 'Your last recorded start is $n days ago (more than $kMaxCycleDays). Entries are probably missing, so there is no current estimate.'
          : 'Dein letzter erfasster Beginn liegt $n Tage zurück (mehr als $kMaxCycleDays). Vermutlich fehlen Einträge, deshalb gibt es keine aktuelle Einschätzung.',
    );
  }

  out.add(
    en
        ? 'This is a statistical estimate from your own records and does not replace medical advice. MorphHealth does not calculate ovulation or fertile days.'
        : 'Das ist eine statistische Einschätzung aus deinen eigenen Aufzeichnungen und ersetzt keine medizinische Beratung. MorphHealth berechnet keinen Eisprung und keine fruchtbaren Tage.',
  );
  return out;
}
