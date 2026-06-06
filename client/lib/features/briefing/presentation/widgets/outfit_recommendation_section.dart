import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/briefing/domain/outfit_guide.dart';

class OutfitRecommendationSection extends StatelessWidget {
  const OutfitRecommendationSection({
    required this.temperature,
    required this.guide,
    required this.recommendation,
    required this.sky,
    super.key,
  });

  final int temperature;
  final OutfitGuide guide;
  final OutfitOption recommendation;
  final SkyPalette sky;

  void _showAll(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OutfitGallerySheet(
        temperature: temperature,
        guide: guide,
        recommendation: recommendation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '오늘의 옷 추천',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '체감 $temperature° · ${guide.title}',
                            style: TextStyle(
                              color: AppColors.inkMute,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: '이 온도에 어울리는 옷차림 모두 보기',
                      child: TextButton.icon(
                        onPressed: () => _showAll(context),
                        icon: Icon(
                          Icons.grid_view_rounded,
                          size: 16,
                          color: sky.ink,
                        ),
                        label: Text(
                          '더보기',
                          style: TextStyle(
                            color: sky.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final copy = _OutfitRecommendationCopy(
                      guide: guide,
                      recommendation: recommendation,
                    );
                    if (constraints.maxWidth < 290) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _OutfitRecommendationImage(
                            assetPath: recommendation.assetPath,
                            width: double.infinity,
                            height: 188,
                          ),
                          const SizedBox(height: 12),
                          copy,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _OutfitRecommendationImage(
                          assetPath: recommendation.assetPath,
                          width: 132,
                          height: 172,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 172),
                            child: copy,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutfitRecommendationImage extends StatelessWidget {
  const _OutfitRecommendationImage({
    required this.assetPath,
    required this.width,
    required this.height,
  });

  final String assetPath;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: const Color(0xFFF8F7F4),
        child: SizedBox(
          width: width,
          height: height,
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

class _OutfitRecommendationCopy extends StatelessWidget {
  const _OutfitRecommendationCopy({
    required this.guide,
    required this.recommendation,
  });

  final OutfitGuide guide;
  final OutfitOption recommendation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE9F3EC),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Text(
            '오늘의 코디',
            style: TextStyle(
              color: Color(0xFF3E6B4B),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          recommendation.theme,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            height: 1.25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          recommendation.combination,
          style: TextStyle(
            color: AppColors.inkSoft,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          guide.message,
          style: TextStyle(
            color: AppColors.inkMute,
            fontSize: 11.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

class _OutfitGallerySheet extends StatelessWidget {
  const _OutfitGallerySheet({
    required this.temperature,
    required this.guide,
    required this.recommendation,
  });

  final int temperature;
  final OutfitGuide guide;
  final OutfitOption recommendation;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F7F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
                  child: Column(
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.inkFaint,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '체감 $temperature° 옷차림',
                                  style: TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${guide.temperatureLabel} · ${guide.options.length}가지 코디',
                                  style: TextStyle(
                                    color: AppColors.inkMute,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '닫기',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: AppColors.ink,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 22,
                    mainAxisExtent: 302,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final option = guide.options[index];
                    return _OutfitGalleryItem(
                      option: option,
                      isRecommended: identical(option, recommendation),
                    );
                  }, childCount: guide.options.length),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OutfitGalleryItem extends StatelessWidget {
  const _OutfitGalleryItem({required this.option, required this.isRecommended});

  final OutfitOption option;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 0.8,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F2EE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        option.assetPath,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isRecommended
                            ? const Color(0xFF4F805D)
                            : const Color(0xFFD9D7D0),
                        width: isRecommended ? 1.5 : 1,
                      ),
                    ),
                  ),
                ),
              ),
              if (isRecommended)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E6B4B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '오늘 추천',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Text(
          option.theme,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            height: 1.25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          option.combination,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.inkMute,
            fontSize: 11,
            height: 1.35,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}
