import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:weather_friend/features/radar/data/lambert.dart';
import 'package:weather_friend/features/radar/data/rain_grid.dart';
import 'package:weather_friend/features/radar/data/user_location.dart';

/// 자동 재생 시 한 슬롯이 보이는 시간.
const _kPlaybackInterval = Duration(milliseconds: 800);

/// 비구름 지도 화면 — OpenStreetMap 진짜 지도 위에 KMA 5km 격자 강수 polygon.
///
/// - 지도: OSM tile (도로/행정구역/지형 자동, 줌별 라벨 LOD)
/// - 강수: PolygonLayer (cell 4 corner 위경도)
/// - 사용자: MarkerLayer (GPS 위경도)
/// - 슬라이더로 1~6시간 전환 + 자동 재생.
class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  int _hourIndex = 0;
  bool _isPlaying = true;
  Timer? _playbackTimer;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _startPlayback();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _mapController.dispose();
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
    final userLatLng = switch (ref.watch(userLatLngProvider)) {
      AsyncData(:final value) => LatLng(value.lat, value.lon),
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('비구름 이동'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: gridAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '비구름 데이터를 불러올 수 없습니다.\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (grid) {
          if (grid == null || grid.hours.isEmpty) {
            return const Center(
              child: Text('비구름 데이터가 아직 준비되지 않았어요.'),
            );
          }
          final safeIndex = _hourIndex.clamp(0, grid.hours.length - 1);
          final current = grid.hours[safeIndex];
          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    // 한반도 중심 + 줌 7 (전국 한눈에)
                    initialCenter: LatLng(36.5, 127.8),
                    initialZoom: 7.0,
                    minZoom: 5.5,
                    maxZoom: 15.0,
                  ),
                  children: [
                    // 1) 진짜 지도 tile (OSM, 무료)
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.weatherfriend.app',
                      maxNativeZoom: 19,
                    ),
                    // 2) 강수 polygon overlay (cell 4 corner 위경도)
                    if (current.cells.isNotEmpty)
                      PolygonLayer(
                        polygons: [
                          for (final c in current.cells)
                            Polygon(
                              points: _cellCorners(c.nx, c.ny),
                              color: _colorFor(c.rn1).withValues(alpha: 0.55),
                              borderStrokeWidth: 0,
                            ),
                        ],
                      ),
                    // 3) 사용자 위치 마커
                    if (userLatLng != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: userLatLng,
                            width: 30,
                            height: 30,
                            child: const _UserMarker(),
                          ),
                        ],
                      ),
                    // OSM attribution (라이선스 의무)
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              ),
              const _Legend(),
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
    );
  }

  /// 격자 cell (nx, ny)의 4 corner 위경도 — Lambert 역변환.
  static List<LatLng> _cellCorners(int nx, int ny) {
    final corners = [
      gridToLatLonFloat(nx - 0.5, ny - 0.5),
      gridToLatLonFloat(nx + 0.5, ny - 0.5),
      gridToLatLonFloat(nx + 0.5, ny + 0.5),
      gridToLatLonFloat(nx - 0.5, ny + 0.5),
    ];
    return [for (final c in corners) LatLng(c.lat, c.lon)];
  }

  Color _colorFor(double rn1) {
    if (rn1 < 1.0) return const Color(0xFF67D4FF);
    if (rn1 < 5.0) return const Color(0xFF3A98FF);
    if (rn1 < 15.0) return const Color(0xFF1B53D6);
    if (rn1 < 30.0) return const Color(0xFF8129D9);
    return const Color(0xFFE63960);
  }
}

class _UserMarker extends StatelessWidget {
  const _UserMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF22C55E).withValues(alpha: 0.3),
      ),
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF22C55E),
            border: Border.all(color: Colors.white, width: 2.5),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                totalCells > 0 ? '강수 $totalCells셀' : '강수 없음',
                style: TextStyle(
                  fontSize: 12,
                  color: totalCells > 0 ? null : Colors.grey,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 28,
                ),
                onPressed: onTogglePlay,
                tooltip: isPlaying ? '일시정지' : '재생',
              ),
              Expanded(
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
        ],
      ),
    );
  }

  String _formatTmef(String tmef) {
    return '${tmef.substring(4, 6)}/${tmef.substring(6, 8)} ${tmef.substring(8, 10)}시';
  }
}
