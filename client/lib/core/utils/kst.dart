DateTime nowKst() => DateTime.now().toUtc().add(const Duration(hours: 9));

/// 하루 사이클의 시작 시각 (KST). 00~04시는 아직 어제 사이클로 본다.
/// 05시에 메세지함이 비워지고 06시 첫 브리핑이 도착한다 — 자정~06시 공백을 없애기 위함.
const int kstCycleStartHour = 5;

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// 사용자 입장의 "오늘 사이클" 시작 날짜.
/// KST 05시를 사이클 경계로 본다 — 00~04시는 아직 어제 사이클 진행 중이라
/// 어제 날짜를 돌려준다. (자정에 메시지가 사라지지 않게.)
String todayKstIso() {
  final n = nowKst();
  final cycleStart =
      n.hour < kstCycleStartHour ? n.subtract(const Duration(days: 1)) : n;
  return _fmtDate(cycleStart);
}

int currentHourKst() => nowKst().hour;

/// 다음 KST 정시까지의 [Duration].
///
/// nowKst()는 UTC 플래그를 단 채 KST 벽시계 값을 갖는다 (절대시각은 +9h 어긋남).
/// 경계도 [DateTime.utc]로 만들어야 둘의 차이가 기기 로컬 타임존과 무관하게 정확하다.
/// (로컬 [DateTime]과 섞으면 오후엔 음수 Duration이 나오던 버그를 수정.)
Duration untilNextKstHour() {
  final n = nowKst();
  final next = DateTime.utc(
    n.year,
    n.month,
    n.day,
    n.hour,
  ).add(const Duration(hours: 1));
  return next.difference(n);
}

/// 다음 사이클 경계(KST 05시)까지의 [Duration]. 이 시점에 메세지함이 초기화된다.
Duration untilNextKstCycleStart() {
  final n = nowKst();
  final base = n.hour < kstCycleStartHour ? n : n.add(const Duration(days: 1));
  final next = DateTime.utc(base.year, base.month, base.day, kstCycleStartHour);
  return next.difference(n);
}
