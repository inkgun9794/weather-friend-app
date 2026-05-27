import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/features/radar/data/korea_mask.dart';
import 'package:weather_friend/features/radar/data/rain_grid.dart';

/// 자동 재생 시 한 슬롯이 보이는 시간.
const _kPlaybackInterval = Duration(milliseconds: 800);

/// 비구름 지도 화면 — 한반도 격자에 1~6시간 강수 예측 색칠.
///
/// 데이터:
/// - `kma_grid_mask/korea`: 한반도 영역 격자 (정적, 한반도 모양 표현)
/// - `kma_grid_rain/latest`: 1~6시간 강수 격자 (sparse, 30분마다 갱신)
///
/// 슬라이더로 1~6시간 사이 전환 → 비구름 이동 경향 시각화.
class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  int _hourIndex = 0;
  bool _isPlaying = true;
  Timer? _playbackTimer;

  /// 핀치 줌/팬용 변환 컨트롤러. 초기 1.3배 확대로 시작.
  late final TransformationController _viewerCtrl;

  @override
  void initState() {
    super.initState();
    _viewerCtrl = TransformationController()..value = Matrix4.identity();
    // 첫 프레임 후 화면 중앙 기준 1.3배 줌.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewerCtrl.value = Matrix4.identity()..scaleByDouble(1.3, 1.3, 1, 1);
    });
    _startPlayback();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _viewerCtrl.dispose();
    super.dispose();
  }

  void _startPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(_kPlaybackInterval, (_) {
      if (!mounted || !_isPlaying) return;
      final grid = switch (ref.read(rainGridProvider)) {
        AsyncData(:final value) => value,
        _ => null,
      };
      final count = grid?.hours.length ?? 0;
      if (count == 0) return;
      setState(() => _hourIndex = (_hourIndex + 1) % count);
    });
  }

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
  }

  void _onSliderChanged(int i) {
    setState(() {
      _hourIndex = i;
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gridAsync = ref.watch(rainGridProvider);
    final maskAsync = ref.watch(koreaMaskProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A1020),
      appBar: AppBar(
        title: const Text('비구름 이동'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: gridAsync.when(
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

            // mask는 보조 — 없어도 강수 셀만 그려짐 (한반도 모양 X).
            final mask = switch (maskAsync) {
              AsyncData(:final value) => value,
              _ => null,
            };

            final safeIndex = _hourIndex.clamp(0, grid.hours.length - 1);
            final currentHour = grid.hours[safeIndex];

            return Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF0F1A2E), Color(0xFF1A2540)],
                          ),
                        ),
                        child: InteractiveViewer(
                          transformationController: _viewerCtrl,
                          minScale: 0.8,
                          maxScale: 6.0,
                          // 무한 boundaryMargin → 자유 팬 (잘려도 끝까지 움직임)
                          boundaryMargin: const EdgeInsets.all(
                            double.infinity,
                          ),
                          child: AspectRatio(
                            aspectRatio: grid.nx / grid.ny,
                            child: CustomPaint(
                              painter: _RadarPainter(
                                gridNx: grid.nx,
                                gridNy: grid.ny,
                                maskCells: mask?.cells ?? const [],
                                rainCells: currentHour.cells,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _Legend(),
                _TimeSlider(
                  hours: grid.hours,
                  index: safeIndex,
                  isPlaying: _isPlaying,
                  onChanged: _onSliderChanged,
                  onTogglePlay: _togglePlay,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 한반도 mask + 강수 격자를 같은 캔버스에 그리는 painter.
///
/// - mask: 옅은 회색 dot (한반도 영역 표시 — 강수가 없어도 한반도 모양 보임)
/// - rain: RN1 강도별 색 dot + blur (자연스러운 비구름 느낌)
class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.gridNx,
    required this.gridNy,
    required this.maskCells,
    required this.rainCells,
  });

  final int gridNx;
  final int gridNy;
  final List<KoreaMaskCell> maskCells;
  final List<RainCell> rainCells;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / gridNx;
    final cellH = size.height / gridNy;
    final cellSize = math.max(cellW, cellH);

    // ── 1) 한반도 mask — 옅은 회색 dot ──
    final maskPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 0.6);
    for (final c in maskCells) {
      final cx = (c.nx - 0.5) * cellW;
      final cy = (gridNy - c.ny + 0.5) * cellH;
      canvas.drawCircle(Offset(cx, cy), cellSize * 0.6, maskPaint);
    }

    // ── 2) 강수 셀 — 강도별 색 + blur ──
    for (final c in rainCells) {
      final cx = (c.nx - 0.5) * cellW;
      final cy = (gridNy - c.ny + 0.5) * cellH;
      final color = _colorFor(c.rn1);
      // 약한 비는 작게/투명하게, 폭우는 크고 진하게
      final intensity = (c.rn1 / 15.0).clamp(0.3, 1.0);
      final radius = cellSize * (1.0 + intensity * 0.8);
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.6 + intensity * 0.3)
          ..maskFilter = ui.MaskFilter.blur(
            ui.BlurStyle.normal,
            cellSize * 0.5,
          ),
      );
    }
  }

  Color _colorFor(double rn1) {
    if (rn1 < 1.0) return const Color(0xFF67D4FF);
    if (rn1 < 5.0) return const Color(0xFF3A98FF);
    if (rn1 < 15.0) return const Color(0xFF1B53D6);
    if (rn1 < 30.0) return const Color(0xFF8129D9);
    return const Color(0xFFE63960);
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.rainCells != rainCells ||
      old.maskCells != maskCells ||
      old.gridNx != gridNx ||
      old.gridNy != gridNy;
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          _LegendItem(color: Color(0xFF67D4FF), label: '약'),
          _LegendItem(color: Color(0xFF3A98FF), label: '보통'),
          _LegendItem(color: Color(0xFF1B53D6), label: '강'),
          _LegendItem(color: Color(0xFF8129D9), label: '매우 강'),
          _LegendItem(color: Color(0xFFE63960), label: '폭우'),
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
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
          ),
        ),
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
    required this.isPlaying,
    required this.onChanged,
    required this.onTogglePlay,
  });

  final List<RainHour> hours;
  final int index;
  final bool isPlaying;
  final ValueChanged<int> onChanged;
  final VoidCallback onTogglePlay;

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
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: onTogglePlay,
                tooltip: isPlaying ? '일시정지' : '재생',
              ),
              Expanded(
                child: SliderTheme(
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTmef(String tmef) {
    return '${tmef.substring(4, 6)}/${tmef.substring(6, 8)} ${tmef.substring(8, 10)}시';
  }
}
