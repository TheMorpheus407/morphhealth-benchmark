// Geschäftsuhr der Anwendung. Die App verwendet die Systemuhr, der
// Wartungszugang (mh) kann über --now eine feste fachliche Uhr erhalten.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now();
}

class FixedClock implements Clock {
  final DateTime _fixed;
  FixedClock(this._fixed);
  @override
  DateTime now() => _fixed;
}
