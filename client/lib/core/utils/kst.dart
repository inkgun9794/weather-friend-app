DateTime nowKst() => DateTime.now().toUtc().add(const Duration(hours: 9));

String todayKstIso() {
  final n = nowKst();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

int currentHourKst() => nowKst().hour;
