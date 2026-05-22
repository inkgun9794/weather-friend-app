DateTime nowKst() => DateTime.now().toUtc().add(const Duration(hours: 9));

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// KST 자정 기준 오늘 날짜.
/// 0시가 되면 자동으로 다음 날짜로 전환된다.
String todayKstIso() => _fmtDate(nowKst());

int currentHourKst() => nowKst().hour;

/// 다음 KST 정시까지의 [Duration].
Duration untilNextKstHour() {
  final n = nowKst();
  final next = DateTime(n.year, n.month, n.day, n.hour + 1);
  return next.difference(n);
}

/// 다음 KST 자정까지의 [Duration].
Duration untilNextKstMidnight() {
  final n = nowKst();
  final next = DateTime(n.year, n.month, n.day + 1);
  return next.difference(n);
}
