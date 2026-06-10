import 'dart:ui' show Color;

/// 다이어리 공통 강조색 — 노트 여백선·오늘 카드 테두리(따뜻한 탠).
const kDiaryAccent = Color(0xFFE0B07A);

/// 다이어리 화면들이 공유하는 날짜 표기 헬퍼.
class DiaryFormat {
  DiaryFormat._();

  static const _kr = ['월', '화', '수', '목', '금', '토', '일'];
  static const _en = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  /// 본문용 — "2026년 6월 10일 화요일".
  static String full(DateTime d) =>
      '${d.year}년 ${d.month}월 ${d.day}일 ${_kr[d.weekday - 1]}요일';

  /// 카드 모서리 스탬프용 — "2026.06.10 · WED".
  static String stamp(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}.$mm.$dd · ${_en[d.weekday - 1]}';
  }
}
