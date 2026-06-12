import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:weather_friend/app/router/main_shell.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/record/data/diary_repository.dart';
import 'package:weather_friend/features/record/domain/diary_entry.dart';
import 'package:weather_friend/features/record/presentation/diary_editor_screen.dart';
import 'package:weather_friend/features/record/presentation/diary_format.dart';
import 'package:weather_friend/features/record/presentation/widgets/image_source_sheet.dart';
import 'package:weather_friend/features/record/presentation/widgets/mood_widgets.dart';
import 'package:weather_friend/features/record/presentation/widgets/photo_dump.dart';
import 'package:weather_friend/features/record/presentation/widgets/streak_card.dart';
import 'package:weather_friend/shared/widgets/weather_bg.dart';

/// 기록(다이어리) 탭 — 상단 "오늘의 하늘" 추가 영역 + 지난 기록 목록.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 다음날 앱을 다시 열면 '오늘 슬롯'이 새 날짜 기준으로 갱신되도록.
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _scheduleMidnightRefresh();
    }
  }

  /// 자정에 한 번 리빌드 — 앱을 켜둔 채 날짜가 바뀌어도 오늘 슬롯이 리셋된다.
  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (mounted) setState(() {});
      _scheduleMidnightRefresh();
    });
  }

  /// 목록에서 오늘 날짜로 작성된 기록을 찾는다(없으면 null).
  DiaryEntry? _todayEntry(List<DiaryEntry> entries) {
    final now = DateTime.now();
    for (final entry in entries) {
      if (isSameDay(entry.createdAt, now)) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(diaryListProvider);
    final today = _todayEntry(entries);
    // 오늘 기록은 상단 슬롯에서 따로 보여주므로 아래 목록에선 뺀다.
    final past = today == null
        ? entries
        : entries.where((e) => e.id != today.id).toList();
    final hasPhotos = entries.any((entry) => entry.hasImage);
    final bottomInset =
        kGlassNavBarHeight + MediaQuery.paddingOf(context).bottom + 16;

    // 날씨·운세 탭과 같은 시간대 그라데이션 배경(WeatherBg)으로 일관성 유지.
    final hourAsync = ref.watch(kstHourProvider);
    final currentHour = switch (hourAsync) {
      AsyncData(:final value) => value,
      _ => currentHourKst(),
    };
    final sky = skyFor(currentHour);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WeatherBg(
        hour: currentHour,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.only(bottom: bottomInset),
            children: [
              _Masthead(sky: sky),
              if (hasPhotos)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: PhotoDumpLauncher(entries: entries, sky: sky),
                ),
              // 잔디심기 챌린지 — 기록이 하나라도 있을 때만(빈 격자 방지).
              if (entries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: StreakCard(entries: entries),
                ),
              // 오늘 슬롯 — 아직 없으면 점선 업로드 카드, 있으면 오늘 기록(수정 전용).
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: today == null
                    ? _SkyPhotoCta(sky: sky)
                    : _DiaryCard(entry: today, isToday: true),
              ),
              if (past.isNotEmpty) ...[
                _SectionLabel(sky: sky),
                for (final entry in past)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _DiaryCard(entry: entry),
                  ),
              ] else if (today == null)
                _EmptyHint(sky: sky),
            ],
          ),
        ),
      ),
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.sky});

  final SkyPalette sky;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.auto_stories_rounded, size: 24, color: sky.ink),
              const SizedBox(width: 9),
              Text(
                '일기',
                style: TextStyle(
                  color: sky.ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            DiaryFormat.full(DateTime.now()),
            style: TextStyle(
              color: sky.inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 점선 16:9 박스 + 가운데 카메라 버튼. 탭하면 갤러리/카메라 선택 →
/// 이미지 선택 후 편집 화면으로 이동.
class _SkyPhotoCta extends ConsumerStatefulWidget {
  const _SkyPhotoCta({required this.sky});

  final SkyPalette sky;

  @override
  ConsumerState<_SkyPhotoCta> createState() => _SkyPhotoCtaState();
}

class _SkyPhotoCtaState extends ConsumerState<_SkyPhotoCta> {
  bool _busy = false;

  Future<void> _pickAndCompose() async {
    if (_busy) return;
    final choice = await showImageSourceSheet(context, includeMoodOnly: true);
    if (choice == null || !mounted) return;

    // 사진 없이 기분만 — 바로 편집 화면으로(이미지 경로 null).
    if (choice == ImageSourceChoice.moodOnly) {
      await context.push(
        DiaryEditorScreen.routePath,
        extra: const DiaryEditorArgs.create(),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: choice == ImageSourceChoice.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;
      await context.push(
        DiaryEditorScreen.routePath,
        extra: DiaryEditorArgs.create(picked.path),
      );
    } on Exception catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진을 불러오지 못했어요')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickAndCompose,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: widget.sky.ink.withValues(alpha: 0.45),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(17),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.photo_camera_rounded,
                          size: 26,
                          color: AppColors.ink,
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  '오늘의 하늘 사진을 남겨보세요!',
                  style: TextStyle(
                    color: widget.sky.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.sky});

  final SkyPalette sky;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Text(
            '지난 기록',
            style: TextStyle(
              color: sky.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(height: 1, color: sky.ink.withValues(alpha: 0.15)),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.sky});

  final SkyPalette sky;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Center(
        child: Text(
          '아직 남긴 기록이 없어요.\n위 카드를 눌러 첫 하늘을 담아보세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: sky.inkSoft,
            fontSize: 13,
            height: 1.6,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 저장된 기록 한 편 — 흰 매트를 두른 폴라로이드 사진 + 날짜 스탬프 + 제목 + 내용.
/// [isToday]면 강조 테두리·"오늘" 배지·"눌러서 수정" 푸터를 붙여 오늘 슬롯으로 쓴다.
class _DiaryCard extends StatelessWidget {
  const _DiaryCard({required this.entry, this.isToday = false});

  final DiaryEntry entry;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    // 오늘 카드도 균일한 얇은 테두리(둥근 모서리 안 어긋나게). 구분은 '오늘' 배지·푸터.
    final border = Border.all(color: AppColors.line);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(
          DiaryEditorScreen.routePath,
          extra: DiaryEditorArgs.edit(entry),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: border,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 폴라로이드 매트 — 사진 둘레에 흰 여백. 사진 없으면 기분 히어로.
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: entry.hasImage
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              _DiaryImage(path: entry.imagePath!),
                              if (entry.mood != null)
                                Positioned(
                                  top: 7,
                                  right: 7,
                                  child: MoodStamp(mood: entry.mood!, size: 30),
                                ),
                            ],
                          )
                        : MoodHero(mood: entry.mood),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          DiaryFormat.stamp(entry.createdAt),
                          style: TextStyle(
                            color: AppColors.inkMute,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          const _TodayBadge(),
                        ],
                      ],
                    ),
                    if (entry.title.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                    // 내용은 카드에 미리보기로 노출하지 않는다 — 탭해서 편집 화면에서만.
                    if (isToday) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: AppColors.inkMute,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '눌러서 수정',
                            style: TextStyle(
                              color: AppColors.inkMute,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.inkFaint,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 오늘 슬롯 카드의 "오늘" 배지.
class _TodayBadge extends StatelessWidget {
  const _TodayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: kDiaryAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        '오늘',
        style: TextStyle(
          color: Color(0xFF8A5A22),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// 로컬 파일 이미지. 파일이 사라졌으면(데이터 삭제 등) 회색 플레이스홀더.
class _DiaryImage extends StatelessWidget {
  const _DiaryImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => ColoredBox(
        color: AppColors.paper3,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: AppColors.inkFaint,
            size: 28,
          ),
        ),
      ),
    );
  }
}

/// 점선 둥근 사각형 테두리.
class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color});

  final Color color;

  static const _radius = 18.0;
  static const _dash = 7.0;
  static const _gap = 5.0;
  static const _strokeWidth = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(_radius)),
      );
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = dist + _dash;
        canvas.drawPath(
          metric.extractPath(dist, next.clamp(0.0, metric.length)),
          paint,
        );
        dist = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => old.color != color;
}
