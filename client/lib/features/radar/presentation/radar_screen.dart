import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/features/radar/data/rain_grid.dart';

/// 비구름 지도 화면 — 한반도 격자에 1~6시간 강수 예측 색칠.
///
/// 데이터: Firestore `kma_grid_rain/latest` (Worker가 30분마다 갱신).
/// 슬라이더로 1~6시간 사이 전환 → 비구름 이동 경향 시각화.
class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  int _hourIndex = 0;

  @override
  Widget build(BuildContext context) {
    final gridAsync = ref.watch(rainGridProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1620),
      appBar: AppBar(
        title: const Text('비구름 이동'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      extendBodyBehindAppBar: true,
      body: gridAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '비구름 데이터를 불러올 수 없습니다.\n$e',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (grid) {
          if (grid == null || grid.hours.isEmpty) {
            return const Center(
              child: Text(
                '비구름 데이터가 아직 준비되지 않았어요.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          final safeIndex = _hourIndex.clamp(0, grid.hours.length - 1);
          final currentHour = grid.hours[safeIndex];
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AspectRatio(
                      aspectRatio: grid.nx / grid.ny,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CustomPaint(
                          painter: _RainPainter(
                            grid: grid,
                            cells: currentHour.cells,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                ),
                _Legend(),
                _TimeSlider(
                  hours: grid.hours,
                  index: safeIndex,
                  onChanged: (i) => setState(() => _hourIndex = i),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RainPainter extends CustomPainter {
  _RainPainter({required this.grid, required this.cells});

  final RainGrid grid;
  final List<RainCell> cells;

  @override
  void paint(Canvas canvas, Size size) {
    // 배경 (어두운 청회색 — 한반도 영역 placeholder)
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF1B2230),
    );

    // 격자 한 셀의 화면상 크기 (1-based → 화면 좌표)
    final cellW = size.width / grid.nx;
    final cellH = size.height / grid.ny;

    // 강수 셀 색칠
    for (final c in cells) {
      // 좌측하단 origin (KMA 격자) → 좌측상단 origin (화면) 변환.
      final screenX = (c.nx - 1) * cellW;
      final screenY = (grid.ny - c.ny) * cellH;
      canvas.drawRect(
        Rect.fromLTWH(screenX, screenY, cellW + 0.5, cellH + 0.5),
        Paint()..color = _colorFor(c.rn1),
      );
    }

    // 한반도 영역 frame (placeholder — 정확한 outline은 추후 SVG로 교체)
    final framePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(Offset.zero & size, framePaint);
  }

  /// RN1 (mm/h) 기준 색 매핑.
  Color _colorFor(double rn1) {
    if (rn1 < 1.0) return const Color(0xFF80D0FF); // 약한 비
    if (rn1 < 5.0) return const Color(0xFF40A0FF); // 보통 비
    if (rn1 < 15.0) return const Color(0xFF2060E0); // 강한 비
    if (rn1 < 30.0) return const Color(0xFF8020E0); // 매우 강한 비
    return const Color(0xFFE02060); // 폭우
  }

  @override
  bool shouldRepaint(_RainPainter old) =>
      old.cells != cells || old.grid != grid;
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          _LegendItem(color: Color(0xFF80D0FF), label: '약'),
          _LegendItem(color: Color(0xFF40A0FF), label: '보통'),
          _LegendItem(color: Color(0xFF2060E0), label: '강'),
          _LegendItem(color: Color(0xFF8020E0), label: '매우 강'),
          _LegendItem(color: Color(0xFFE02060), label: '폭우'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _TimeSlider extends StatelessWidget {
  const _TimeSlider({
    required this.hours,
    required this.index,
    required this.onChanged,
  });

  final List<RainHour> hours;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = hours[index];
    final totalCells = current.cells.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '+${current.offset}시간 후 (${_formatTmef(current.tmef)})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                totalCells > 0 ? '강수 $totalCells셀' : '강수 없음',
                style: TextStyle(
                  color: totalCells > 0 ? Colors.white : Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
            ),
            child: Slider(
              min: 0,
              max: (hours.length - 1).toDouble(),
              divisions: hours.length - 1,
              value: index.toDouble(),
              label: '+${current.offset}h',
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTmef(String tmef) {
    // YYYYMMDDHH → "MM/DD HH시"
    return '${tmef.substring(4, 6)}/${tmef.substring(6, 8)} ${tmef.substring(8, 10)}시';
  }
}
