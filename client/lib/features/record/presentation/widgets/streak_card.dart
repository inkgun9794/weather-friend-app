import 'package:flutter/material.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/record/domain/diary_entry.dart';
import 'package:weather_friend/features/record/domain/diary_mood.dart';

/// 깃허브 잔디심기처럼 — 하루도 빠짐없이 기록했는지 한눈에 보여 지속성을 만든다.
/// 7행(요일) × 13열(주) 격자에서 기록한 날엔 그날의 '기분 날씨' 심볼이 심긴다.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.entries});

  final List<DiaryEntry> entries;

  static const _weeks = 13;
  static const _gap = 4.0;
  static const _leaf = Color(0xFF6CC174); // 헤더 아이콘
  static const _flame = Color(0xFFEF7A3D); // 연속 streak
  static const _emptyCell = Color(0xFFECEEF0); // 미기록 칸
  // 기록한 칸 바탕 — 연한 초록(잔디). 하늘색으로 바꾸려면 0xFFCDE6F5.
  static const _fill = Color(0xFFC4E9CC);

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 달력 기반 일자 가감 — Duration 대신 써서 DST 경계에서 칸이 어긋나지 않게.
  static DateTime _addDays(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day + n);

  @override
  Widget build(BuildContext context) {
    // dayKey -> 그날 기분(없으면 null). 키 존재 = 그날 기록함.
    final moods = <String, DiaryMood?>{
      for (final e in entries) _dayKey(e.createdAt): e.mood,
    };
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayDone = moods.containsKey(_dayKey(today));

    // 연속 일수 — 오늘 안 썼으면 어제부터 카운트(아직 살아있는 streak).
    var streak = 0;
    var cursor = todayDone ? today : _addDays(today, -1);
    while (moods.containsKey(_dayKey(cursor))) {
      streak++;
      cursor = _addDays(cursor, -1);
    }
    final total = moods.length;
    final startMonday = _addDays(today, -((today.weekday - 1) + (_weeks - 1) * 7));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.eco_rounded, size: 18, color: _leaf),
                const SizedBox(width: 7),
                Text(
                  '일기 챌린지',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                _StreakPill(streak: streak),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, _) => Column(
                children: [
                  for (var r = 0; r < 7; r++) ...[
                    if (r > 0) const SizedBox(height: _gap),
                    Row(
                      children: [
                        for (var col = 0; col < _weeks; col++) ...[
                          if (col > 0) const SizedBox(width: _gap),
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: _Cell(
                                date: _addDays(startMonday, col * 7 + r),
                                today: today,
                                moods: moods,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              todayDone
                  ? '오늘 기분을 심었어요 🌱  ·  총 $total일 기록'
                  : (streak > 0
                        ? '$streak일 연속 중! 오늘도 이어가 보세요.'
                        : '오늘의 기분을 기록해 첫 칸을 채워보세요.'),
              style: TextStyle(
                color: AppColors.inkMute,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 격자 한 칸 — 미래는 빈칸, 미기록은 옅은 칸, 기록한 날은 그날의 기분 심볼.
class _Cell extends StatelessWidget {
  const _Cell({required this.date, required this.today, required this.moods});

  final DateTime date;
  final DateTime today;
  final Map<String, DiaryMood?> moods;

  @override
  Widget build(BuildContext context) {
    if (date.isAfter(today)) return const SizedBox.shrink();

    final key = StreakCard._dayKey(date);
    final recorded = moods.containsKey(key);
    final mood = recorded ? moods[key] : null;

    // 미기록은 옅은 회색 칸, 기록한 날은 채워진(초록) 칸 + 그날의 기분 심볼.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: recorded ? StreakCard._fill : StreakCard._emptyCell,
        borderRadius: BorderRadius.circular(3),
      ),
      child: mood == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(1.5),
              child: Image.asset(
                mood.asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: StreakCard._flame.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 14,
            color: StreakCard._flame,
          ),
          const SizedBox(width: 3),
          Text(
            '연속 $streak일',
            style: const TextStyle(
              color: Color(0xFFB85420),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
