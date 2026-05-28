import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:weather_friend/features/radar/data/radar_manifest.dart';
import 'package:weather_friend/features/radar/data/user_location.dart';

/// 비구름 지도 — 현재 KMA 레이더(500m) + +2h/+4h/+6h KMA 예보(5km) 4-anchor 하이브리드.
/// 슬라이더 10분 단위 37 포지션은 가장 가까운 anchor + motion shift로 생성.

/// 자동 재생 시 한 프레임이 보이는 시간.
const _kPlaybackInterval = Duration(milliseconds: 700);

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  int _frameIndex = 0;
  bool _isPlaying = false;
  Timer? _playbackTimer;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
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
      final state = switch (ref.read(radarStateProvider)) {
        AsyncData(:final value) => value,
        _ => null,
      };
      final total = state?.frames.length ?? 0;
      if (total == 0) return;
      setState(() => _frameIndex = (_frameIndex + 1) % total);
    });
  }

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _startPlayback();
    } else {
      _playbackTimer?.cancel();
      _playbackTimer = null;
    }
  }

  void _onSliderChanged(int i) {
    setState(() {
      _frameIndex = i;
      _isPlaying = false;
    });
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(radarStateProvider);
    final userLatLng = switch (ref.watch(userLatLngProvider)) {
      AsyncData(:final value) => LatLng(value.lat, value.lon),
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('비구름 이동 예측'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: stateAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '레이더 데이터를 불러올 수 없습니다.\n$e',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (state) {
            if (state == null || state.frames.isEmpty) {
              return const Center(
                child: Text('레이더 데이터가 아직 준비되지 않았어요.'),
              );
            }
            final frames = state.frames;
            final safeIdx = _frameIndex.clamp(0, frames.length - 1);
            final current = frames[safeIdx];
            return Column(
              children: [
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: const MapOptions(
                      initialCenter: LatLng(36.5, 127.8),
                      initialZoom: 7.0,
                      minZoom: 5.5,
                      maxZoom: 15.0,
                    ),
                    children: [
                      // 1) OSM 베이스 타일
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.weatherfriend.app',
                        maxNativeZoom: 19,
                      ),
                      // 2) anchor PNG overlay — motion shift된 bounds 사용.
                      OverlayImageLayer(
                        overlayImages: [
                          OverlayImage(
                            bounds: current.bounds.toLatLngBounds(),
                            opacity: 0.82,
                            imageProvider: NetworkImage(current.anchor.url),
                          ),
                        ],
                      ),
                      // 3) 사용자 위치
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
                      const SimpleAttributionWidget(
                        source: Text(
                          '© OpenStreetMap',
                          style: TextStyle(fontSize: 10),
                        ),
                        backgroundColor: Color(0x99FFFFFF),
                      ),
                    ],
                  ),
                ),
                const _Legend(),
                _TimeSlider(
                  frames: frames,
                  index: safeIdx,
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
    required this.frames,
    required this.index,
    required this.isPlaying,
    required this.onChanged,
    required this.onTogglePlay,
  });

  final List<RadarSliderFrame> frames;
  final int index;
  final bool isPlaying;
  final ValueChanged<int> onChanged;
  final VoidCallback onTogglePlay;

  @override
  Widget build(BuildContext context) {
    final current = frames[index];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatLabel(current),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _kindLabel(current.kind),
                style: TextStyle(
                  fontSize: 12,
                  color: _kindColor(current.kind),
                  fontWeight: FontWeight.w600,
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
                  max: (frames.length - 1).toDouble(),
                  divisions: frames.length - 1,
                  value: index.toDouble(),
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatLabel(RadarSliderFrame f) {
    final now = DateTime.now();
    final hh = f.tm.substring(8, 10);
    final min = f.tm.substring(10, 12);
    final mm = f.tm.substring(4, 6);
    final dd = f.tm.substring(6, 8);
    final isToday = (mm == _two(now.month)) && (dd == _two(now.day));
    return isToday ? '$hh:$min' : '$mm/$dd $hh:$min';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _kindLabel(RadarKind k) => switch (k) {
        RadarKind.observation => '실측',
        RadarKind.extrapolation => '외삽 예측',
        RadarKind.forecast => 'KMA 예보',
      };

  static Color _kindColor(RadarKind k) => switch (k) {
        RadarKind.observation => Colors.blueGrey,
        RadarKind.extrapolation => Colors.deepPurple,
        RadarKind.forecast => Colors.indigo,
      };
}
