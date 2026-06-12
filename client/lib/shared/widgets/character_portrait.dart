import 'package:flutter/material.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/character/domain/character.dart';

/// 캐릭터 프사 — 원형 썸네일. 탭하면 큰 사진으로 확대된다.
///
/// 앱 번들에 포함된 assets/characters/{id}/{outfit}.png를 바로 표시한다.
class CharacterPortrait extends StatelessWidget {
  const CharacterPortrait({
    required this.charId,
    this.outfit = 'portrait',
    this.size = 48,
    this.enableTapToExpand = true,
    super.key,
  });

  final CharacterId charId;
  final String outfit;
  final double size;
  final bool enableTapToExpand;

  String get _assetPath => 'assets/characters/${charId.name}/$outfit.png';

  String get _heroTag => 'character-portrait-${charId.name}';

  Widget _image(double s) => Image.asset(
    _assetPath,
    width: s,
    height: s,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => ColoredBox(color: visualFor(charId).colorSoft),
  );

  void _showExpanded(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      barrierDismissible: true,
      builder: (ctx) {
        final screen = MediaQuery.of(ctx).size;
        final big = (screen.shortestSide * 0.8).clamp(240.0, 360.0);
        return GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Hero(
              tag: _heroTag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: _image(big),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumb = Hero(
      tag: _heroTag,
      child: ClipOval(
        child: SizedBox(width: size, height: size, child: _image(size)),
      ),
    );

    if (!enableTapToExpand) return thumb;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _showExpanded(context),
        child: thumb,
      ),
    );
  }
}
