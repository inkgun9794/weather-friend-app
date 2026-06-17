import 'package:flutter/material.dart';
import 'package:weather_friend/app/theme/app_type.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/record/domain/diary_mood.dart';
import 'package:weather_friend/features/record/presentation/diary_format.dart';

/// 사진 위에 도장처럼 얹는 기분 날씨 배지 — 흰 원 안에 카와이 글리프.
class MoodStamp extends StatelessWidget {
  const MoodStamp({super.key, required this.mood, this.size = 34});

  final DiaryMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Image.asset(
        mood.asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

/// 사진 없이 기분만 기록한 항목의 히어로 — 부드러운 배경 + 큰 기분 글리프.
/// 부모가 크기를 정하도록 자체 AspectRatio는 두지 않는다(호출부에서 16:9로 감쌈).
class MoodHero extends StatelessWidget {
  const MoodHero({super.key, this.mood});

  final DiaryMood? mood;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, AppColors.paper2],
        ),
      ),
      child: Center(
        child: mood != null
            ? Image.asset(
                mood!.asset,
                width: 60,
                height: 60,
                filterQuality: FilterQuality.medium,
              )
            : Icon(
                Icons.wb_cloudy_outlined,
                size: 38,
                color: AppColors.inkFaint,
              ),
      ),
    );
  }
}

/// "당신의 기분은 현재 어떤 날씨인가요?" — 6개 날씨 타일에서 하나 선택.
/// 균등 폭으로 한 줄에 모두 보이고, 선택 시 강조색 테두리가 켜진다.
class MoodPicker extends StatelessWidget {
  const MoodPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final DiaryMood? selected;
  final ValueChanged<DiaryMood> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final mood in DiaryMood.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _MoodTile(
                mood: mood,
                selected: mood == selected,
                onTap: () => onSelected(mood),
              ),
            ),
          ),
      ],
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final DiaryMood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? kDiaryAccent.withValues(alpha: 0.14)
              : AppColors.paper2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kDiaryAccent : AppColors.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              mood.asset,
              width: 30,
              height: 30,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                mood.label,
                style: AppType.micro2.copyWith(
                  color: selected ? AppColors.ink : AppColors.inkMute,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
