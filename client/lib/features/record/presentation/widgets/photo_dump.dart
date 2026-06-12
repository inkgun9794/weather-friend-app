import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/record/domain/diary_entry.dart';
import 'package:weather_friend/features/record/presentation/diary_format.dart';

/// 최근 하늘 사진을 쌓아 두었다가 전체 화면에 흩뿌리는 포토덤프 런처.
class PhotoDumpLauncher extends StatefulWidget {
  const PhotoDumpLauncher({
    super.key,
    required this.entries,
    required this.sky,
  });

  final List<DiaryEntry> entries;
  final SkyPalette sky;

  @override
  State<PhotoDumpLauncher> createState() => _PhotoDumpLauncherState();
}

class _PhotoDumpLauncherState extends State<PhotoDumpLauncher> {
  static const _maxPhotos = 12;

  final _pileKey = GlobalKey();
  bool _opening = false;

  List<DiaryEntry> get _photos => widget.entries
      .where((entry) => entry.hasImage)
      .take(_maxPhotos)
      .toList(growable: false);

  Future<void> _openDump() async {
    if (_opening || _photos.isEmpty) return;

    final pileBox = _pileKey.currentContext?.findRenderObject();
    if (pileBox is! RenderBox || !pileBox.hasSize) return;

    setState(() => _opening = true);
    final origin = pileBox.localToGlobal(Offset.zero) & pileBox.size;
    final seed = DateTime.now().microsecondsSinceEpoch;

    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => _PhotoDumpCanvas(
        entries: _photos,
        origin: origin,
        sky: widget.sky,
        seed: seed,
      ),
    );

    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    if (photos.isEmpty) return const SizedBox.shrink();

    return Semantics(
      key: const Key('photo-dump-launcher'),
      button: true,
      label: '하늘 포토덤프 펼치기',
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _openDump,
        child: Center(
          child: _PhotoPile(
            key: _pileKey,
            entries: photos.take(4).toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _PhotoPile extends StatelessWidget {
  const _PhotoPile({super.key, required this.entries});

  final List<DiaryEntry> entries;

  static const _angles = [-0.16, 0.13, -0.07, 0.08];

  @override
  Widget build(BuildContext context) {
    final layered = entries.reversed.toList(growable: false);

    return SizedBox(
      key: const Key('photo-dump-pile'),
      width: 220,
      height: 132,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          for (var index = 0; index < layered.length; index++)
            Transform.translate(
              offset: Offset(
                (index - (layered.length - 1) / 2) * 13,
                index * 1.5,
              ),
              child: Transform.rotate(
                angle: _angles[index % _angles.length],
                child: _MiniPolaroid(entry: layered[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniPolaroid extends StatelessWidget {
  const _MiniPolaroid({required this.entry});

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 98,
      height: 120,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE8E5DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: _PhotoFile(path: entry.imagePath!),
      ),
    );
  }
}

class _PhotoDumpCanvas extends StatefulWidget {
  const _PhotoDumpCanvas({
    required this.entries,
    required this.origin,
    required this.sky,
    required this.seed,
  });

  final List<DiaryEntry> entries;
  final Rect origin;
  final SkyPalette sky;
  final int seed;

  @override
  State<_PhotoDumpCanvas> createState() => _PhotoDumpCanvasState();
}

class _PhotoDumpCanvasState extends State<_PhotoDumpCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
      reverseDuration: const Duration(milliseconds: 620),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _collect() async {
    if (_closing) return;
    setState(() => _closing = true);
    await _controller.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  double _progressFor(int index) {
    final delay = math.min(index * 0.025, 0.24);
    final raw = ((_controller.value - delay) / (1 - delay)).clamp(0.0, 1.0);
    if (_controller.status == AnimationStatus.reverse) {
      return Curves.easeInCubic.transform(raw);
    }
    return Curves.easeOutBack.transform(raw);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final placements = _placementsFor(
      screenSize: size,
      safePadding: safePadding,
      count: widget.entries.length,
      seed: widget.seed,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _collect();
      },
      child: Semantics(
        button: true,
        label: '포토덤프 모으기',
        hint: '화면을 누르면 사진이 원래 위치로 돌아갑니다',
        child: GestureDetector(
          key: const Key('photo-dump-canvas'),
          behavior: HitTestBehavior.opaque,
          onTap: _collect,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [widget.sky.top, widget.sky.mid, widget.sky.bot],
                stops: const [0, 0.5, 1],
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var index = 0; index < widget.entries.length; index++)
                      _AnimatedDumpPhoto(
                        key: ValueKey(
                          'photo-dump-photo-${widget.entries[index].id}',
                        ),
                        entry: widget.entries[index],
                        startRect: _startRect(index),
                        placement: placements[index],
                        progress: _progressFor(index),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Rect _startRect(int index) {
    const cardWidth = 98.0;
    const cardHeight = 120.0;
    final layer = index % 4;
    final center =
        widget.origin.center + Offset((layer - 1.5) * 13, layer * 1.5);
    return Rect.fromCenter(
      center: center,
      width: cardWidth,
      height: cardHeight,
    );
  }
}

class _AnimatedDumpPhoto extends StatelessWidget {
  const _AnimatedDumpPhoto({
    super.key,
    required this.entry,
    required this.startRect,
    required this.placement,
    required this.progress,
  });

  final DiaryEntry entry;
  final Rect startRect;
  final _DumpPlacement placement;
  final double progress;

  static const _stackAngles = [-0.16, 0.13, -0.07, 0.08];

  @override
  Widget build(BuildContext context) {
    final rect = Rect.lerp(startRect, placement.rect, progress)!;
    final startAngle = _stackAngles[entry.createdAt.millisecond % 4];
    final angle = startAngle + (placement.angle - startAngle) * progress;

    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: angle,
          child: RepaintBoundary(child: _DumpPolaroid(entry: entry)),
        ),
      ),
    );
  }
}

class _DumpPolaroid extends StatelessWidget {
  const _DumpPolaroid({required this.entry});

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFA),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE8E5DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: _PhotoFile(path: entry.imagePath!),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            DiaryFormat.stamp(entry.createdAt),
            maxLines: 1,
            overflow: TextOverflow.fade,
            textAlign: TextAlign.center,
            softWrap: false,
            style: TextStyle(
              color: AppColors.inkMute,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoFile extends StatelessWidget {
  const _PhotoFile({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => ColoredBox(
        color: AppColors.paper3,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: AppColors.inkFaint,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _DumpPlacement {
  const _DumpPlacement({required this.rect, required this.angle});

  final Rect rect;
  final double angle;
}

List<_DumpPlacement> _placementsFor({
  required Size screenSize,
  required EdgeInsets safePadding,
  required int count,
  required int seed,
}) {
  final random = math.Random(seed);
  final slots = <Offset>[
    const Offset(0.18, 0.14),
    const Offset(0.50, 0.12),
    const Offset(0.82, 0.17),
    const Offset(0.29, 0.36),
    const Offset(0.68, 0.36),
    const Offset(0.12, 0.58),
    const Offset(0.48, 0.58),
    const Offset(0.84, 0.60),
    const Offset(0.26, 0.80),
    const Offset(0.63, 0.82),
    const Offset(0.08, 0.88),
    const Offset(0.90, 0.87),
  ]..shuffle(random);

  final top = safePadding.top + 8;
  final bottom = screenSize.height - safePadding.bottom - 8;
  final usableHeight = bottom - top;

  return List.generate(count, (index) {
    final slot = slots[index % slots.length];
    final widthFactor = 0.27 + random.nextDouble() * 0.1;
    final cardWidth = (screenSize.width * widthFactor).clamp(100.0, 156.0);
    final cardHeight = cardWidth * 1.24;
    final jitterX = (random.nextDouble() - 0.5) * 34;
    final jitterY = (random.nextDouble() - 0.5) * 30;
    final center = Offset(
      screenSize.width * slot.dx + jitterX,
      top + usableHeight * slot.dy + jitterY,
    );
    final left = (center.dx - cardWidth / 2).clamp(
      -cardWidth * 0.12,
      screenSize.width - cardWidth * 0.88,
    );
    final cardTop = (center.dy - cardHeight / 2).clamp(
      top - cardHeight * 0.08,
      bottom - cardHeight * 0.92,
    );
    final angle = (random.nextDouble() * 2 - 1) * math.pi / 3;

    return _DumpPlacement(
      rect: Rect.fromLTWH(left, cardTop, cardWidth, cardHeight),
      angle: angle,
    );
  });
}
