import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/features/radar/data/korea_geojson.dart';
import 'package:weather_friend/features/radar/data/korea_label.dart';
import 'package:weather_friend/features/radar/data/korea_mask.dart';
import 'package:weather_friend/features/radar/data/rain_grid.dart';

/// 자동 재생 시 한 슬롯이 보이는 시간.
const _kPlaybackInterval = Duration(milliseconds: 800);

// 화면 표시 viewport — 남한 위주 (38선 살짝 위 ~ 제주 살짝 아래) + 인근 해상.
// 격자 좌표는 (1,1)=(31.79°N, 123.76°E), (149,253)=(43.39°N, 132.78°E) 기준.
// 서해/동해 강수도 보이도록 좌우 약간 넓힘.
const _kViewportNxMin = 1;
const _kViewportNxMax = 149;
const _kViewportNyMin = 20;
const _kViewportNyMax = 175;
const _kViewportNx = _kViewportNxMax - _kViewportNxMin + 1; // 149
const _kViewportNy = _kViewportNyMax - _kViewportNyMin + 1; // 156

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
  double _currentScale = 1.3;

  @override
  void initState() {
    super.initState();
    _viewerCtrl = TransformationController()..value = Matrix4.identity();
    _viewerCtrl.addListener(_onTransform);
    // 첫 프레임 후 화면 중앙 기준 1.3배 줌.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewerCtrl.value = Matrix4.identity()..scaleByDouble(1.3, 1.3, 1, 1);
    });
    _startPlayback();
  }

  @override
  void dispose() {
    _viewerCtrl.removeListener(_onTransform);
    _playbackTimer?.cancel();
    _viewerCtrl.dispose();
    super.dispose();
  }

  void _onTransform() {
    final scale = _viewerCtrl.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.05) {
      setState(() => _currentScale = scale);
    }
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
            final labels = switch (ref.watch(koreaLabelsProvider)) {
              AsyncData(:final value) => value,
              _ => const <KoreaLabel>[],
            };
            final polygons = switch (ref.watch(koreaMunicipalitiesProvider)) {
              AsyncData(:final value) => value,
              _ => const <MunicipalityShape>[],
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
                            aspectRatio: _kViewportNx / _kViewportNy,
                            child: CustomPaint(
                              painter: _RadarPainter(
                                maskCells: mask?.cells ?? const [],
                                rainCells: currentHour.cells,
                                labels: labels,
                                polygons: polygons,
                                scale: _currentScale,
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

/// 한반도 mask + 강수 격자 + 행정구역 라벨을 같은 캔버스에 그리는 painter.
///
/// viewport 좌표계 — _kViewport* 범위만 화면에 그림. 그 밖은 무시.
/// 라벨은 줌 스케일에 따라 단계적으로 노출 (광역시·도 → 시·군·구).
class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.maskCells,
    required this.rainCells,
    required this.labels,
    required this.polygons,
    required this.scale,
  });

  final List<KoreaMaskCell> maskCells;
  final List<RainCell> rainCells;
  final List<KoreaLabel> labels;
  final List<MunicipalityShape> polygons;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / _kViewportNx;
    final cellH = size.height / _kViewportNy;
    final overdraw = cellW < 1 ? 0.5 : 0.3;

    // ── 1) 한반도 + 근해 mask ──
    // KMA 레이더 관측영역(-99 아닌 셀) 전체 표시 → 한반도 + 서해/동해 일부 영역 명확.
    // alpha 진하게 (0.25) 해서 본토만 두드러지지 않게.
    final maskPaint = Paint()..color = Colors.white.withValues(alpha: 0.25);
    for (final c in maskCells) {
      if (!_inViewport(c.nx, c.ny)) continue;
      final sx = (c.nx - _kViewportNxMin) * cellW;
      final sy = (_kViewportNyMax - c.ny) * cellH;
      canvas.drawRect(
        Rect.fromLTWH(sx, sy, cellW + overdraw, cellH + overdraw),
        maskPaint,
      );
    }

    // ── 2) 강수 셀 — 격자 정렬 사각형 ──
    for (final c in rainCells) {
      if (!_inViewport(c.nx, c.ny)) continue;
      final sx = (c.nx - _kViewportNxMin) * cellW;
      final sy = (_kViewportNyMax - c.ny) * cellH;
      canvas.drawRect(
        Rect.fromLTWH(sx, sy, cellW + overdraw, cellH + overdraw),
        Paint()..color = _colorFor(c.rn1).withValues(alpha: 0.95),
      );
    }

    // ── 3) 시·군·구 outline ──
    // polygon은 격자 좌표(1-based)로 저장되어 있음. Matrix4로 viewport→화면 변환.
    if (polygons.isNotEmpty) {
      final matrix = Matrix4.identity()
        ..setEntry(0, 0, cellW)
        ..setEntry(1, 1, -cellH)
        ..setEntry(0, 3, -_kViewportNxMin * cellW)
        ..setEntry(1, 3, _kViewportNyMax * cellH);

      // 줌 보정 — 화면 stroke 두께를 일정하게 (scale 커지면 가늘게).
      final invScale = 1.0 / scale.clamp(0.5, 6.0);
      final outlinePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * invScale;

      canvas.save();
      canvas.transform(matrix.storage);
      for (final p in polygons) {
        canvas.drawPath(p.path, outlinePaint);
      }
      canvas.restore();
    }

    // ── 3) 라벨 — 줌 단계별 ──
    // scale < 1.6: 광역시·도만 (적은 라벨 = 한눈에 보기)
    // scale ≥ 1.6: 시·군·구도 함께
    final showDistrict = scale >= 1.6;
    // 라벨은 InteractiveViewer가 zoom으로 확대해버리므로 painter에서는
    // scale의 역수만큼 작게 그려 화면상 항상 같은 픽셀 크기로 보이게 함.
    final invScale = 1.0 / scale.clamp(0.5, 6.0);
    final metroFontSize = 12.0 * invScale;
    final districtFontSize = 9.0 * invScale;

    for (final label in labels) {
      if (label.level == LabelLevel.district && !showDistrict) continue;
      if (!_inViewport(label.nx, label.ny)) continue;
      final sx = (label.nx - _kViewportNxMin + 0.5) * cellW;
      final sy = (_kViewportNyMax - label.ny + 0.5) * cellH;
      _drawLabel(
        canvas,
        label.name,
        Offset(sx, sy),
        label.level == LabelLevel.metro ? metroFontSize : districtFontSize,
        label.level == LabelLevel.metro
            ? Colors.white
            : Colors.white.withValues(alpha: 0.75),
        label.level == LabelLevel.metro ? FontWeight.w700 : FontWeight.w500,
      );
    }
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    Color color,
    FontWeight weight,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          shadows: const [
            // 어두운 그림자로 어떤 색 위에서든 가독성 확보.
            Shadow(color: Color(0xCC000000), blurRadius: 3),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  static bool _inViewport(int nx, int ny) {
    return nx >= _kViewportNxMin &&
        nx <= _kViewportNxMax &&
        ny >= _kViewportNyMin &&
        ny <= _kViewportNyMax;
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
      old.labels != labels ||
      old.polygons != polygons ||
      old.scale != scale;
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
