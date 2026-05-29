import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/fortune/data/fortune_api.dart';
import 'package:weather_friend/features/fortune/data/fortune_score_history.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';

/// 점수 + 미니 꺾은선 차트 카드.
/// - 점수: 어떤 프로필이든 표시
/// - 차트: 내 프로필일 때만 (시계열 의미 있는 건 본인 운세 변화)
class ScoreChartCard extends ConsumerWidget {
  const ScoreChartCard({
    super.key,
    required this.profile,
    required this.isMyProfile,
  });

  final SajuProfile profile;
  final bool isMyProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFortune = ref.watch(fortuneForProfileProvider(profile));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.inkMute.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: asyncFortune.when(
        loading: () => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Text(
          '점수를 불러올 수 없어요',
          style: TextStyle(color: AppColors.inkMute, fontSize: 13),
        ),
        data: (fortune) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScoreDisplay(score: fortune.score),
            if (isMyProfile) ...[
              const SizedBox(height: 18),
              const _MiniChart(days: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreDisplay extends StatelessWidget {
  const _ScoreDisplay({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    final label = _scoreLabel(score);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '오늘의 점수',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMute,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$score',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.0,
                letterSpacing: -2,
              ),
            ),
            Text(
              '점',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _scoreLabel(int s) {
    if (s >= 85) return '매우 좋음';
    if (s >= 70) return '좋음';
    if (s >= 50) return '평범';
    if (s >= 30) return '주의';
    return '어려움';
  }

  Color _scoreColor(int s) {
    if (s >= 85) return const Color(0xFF15803D); // green-700
    if (s >= 70) return const Color(0xFF0369A1); // sky-700
    if (s >= 50) return const Color(0xFFB45309); // amber-700
    if (s >= 30) return const Color(0xFFEA580C); // orange-600
    return const Color(0xFFDC2626); // red-600
  }
}

/// 미니 꺾은선 차트 — 본 날만 vertex, 안 본 날은 X축 위에 표시 X.
class _MiniChart extends ConsumerWidget {
  const _MiniChart({required this.days});
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(myScoreHistoryProvider);
    final entries = asyncHistory.value ?? const <ScoreEntry>[];

    if (entries.isEmpty) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        child: Text(
          '운세를 본 날부터 점수 흐름이 표시돼요',
          style: TextStyle(fontSize: 12, color: AppColors.inkMute),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최근 $days일 점수 흐름',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.inkMute,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: CustomPaint(
            size: const Size(double.infinity, 100),
            painter: _LineChartPainter(entries: entries, days: days),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${days - 1}일 전',
              style: TextStyle(fontSize: 10, color: AppColors.inkFaint),
            ),
            Text(
              '오늘',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.inkMute,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.entries, required this.days});

  final List<ScoreEntry> entries;
  final int days;

  static const double _hPad = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final today = _dayStart(DateTime.now());
    final startDate = today.subtract(Duration(days: days - 1));
    final innerW = w - _hPad * 2;

    // Y축 격자선 (50점) — 점선
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final midY = h * 0.5;
    _drawDashedLine(canvas, Offset(0, midY), Offset(w, midY), gridPaint);

    // X 좌표 계산 함수
    double xOf(DateTime date) {
      final diff = _dayStart(date).difference(startDate).inDays;
      if (days <= 1) return _hPad;
      return _hPad + (diff / (days - 1)) * innerW;
    }

    // Y 좌표 (0=하단, 100=상단)
    double yOf(int score) => h - (score / 100) * h;

    // 범위 내 entry만 추출 + 정렬
    final visible = <ScoreEntry>[];
    for (final e in entries) {
      final d = _dayStart(e.date);
      if (d.isBefore(startDate) || d.isAfter(today)) continue;
      visible.add(e);
    }
    visible.sort((a, b) => a.date.compareTo(b.date));

    if (visible.isEmpty) return;

    // 좌표 변환
    final points = visible
        .map((e) => Offset(xOf(e.date), yOf(e.score)))
        .toList();

    // 선 (vertex 2개 이상일 때만)
    if (points.length >= 2) {
      final linePaint = Paint()
        ..color = const Color(0xFF0369A1)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // vertex 점 — 외곽 흰색 + 내부 색깔
    for (final p in points) {
      canvas.drawCircle(p, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, Paint()..color = const Color(0xFF0369A1));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0, gap = 4.0;
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final dist = (dx * dx + dy * dy).abs().toDouble();
    final len = dist <= 0 ? 0.0 : dist == 0 ? 0.0 : (dx.abs() + dy.abs());
    if (len == 0) return;
    final steps = (len / (dash + gap)).floor();
    final ux = dx / len, uy = dy / len;
    var x = a.dx, y = a.dy;
    for (var i = 0; i < steps; i++) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x + ux * dash, y + uy * dash),
        paint,
      );
      x += ux * (dash + gap);
      y += uy * (dash + gap);
    }
  }

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.entries != entries || old.days != days;
}
