DateTime nowKst() => DateTime.now().toUtc().add(const Duration(hours: 9));

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// 사용자 입장의 "오늘 사이클"의 시작 날짜.
/// KST 05시를 사이클 경계로 본다 — 00~04시는 아직 어제 사이클 진행 중.
String todayKstIso() {
  final n = nowKst();
  final cycleStart = n.hour < 5 ? n.subtract(const Duration(days: 1)) : n;
  return _fmtDate(cycleStart);
}

int currentHourKst() => nowKst().hour;
