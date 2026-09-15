class Throttler {
  final Duration interval;
  DateTime? _lastRun;

  Throttler({this.interval = const Duration(milliseconds: 400)});

  bool canRun() {
    final now = DateTime.now();
    if (_lastRun == null || now.difference(_lastRun!) >= interval) {
      _lastRun = now;
      return true;
    }
    return false;
  }
}