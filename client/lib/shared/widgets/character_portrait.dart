import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/shared/widgets/char_avatar.dart';

/// 캐릭터 프사 — 원형 썸네일. 탭하면 큰 사진으로 확대된다.
///
/// 이미지 source: https://inkgun9794.github.io/weather-friend-app/characters/{id}/{outfit}.png
/// 사용자가 docs/characters/ 폴더에 png를 올리면 자동 반영. 없으면 CharAvatar(SVG)로 fallback.
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

  static const _baseUrl =
      'https://inkgun9794.github.io/weather-friend-app/characters';

  String get _url => '$_baseUrl/${charId.name}/$outfit.png';

  String get _heroTag => 'character-portrait-${charId.name}';

  Widget _fallback(double s) =>
      CharAvatar(charId: charId, size: s, ring: false);

  Widget _image(double s) => CachedNetworkImage(
    imageUrl: _url,
    width: s,
    height: s,
    fit: BoxFit.cover,
    placeholder: (_, _) => _fallback(s),
    errorWidget: (_, _, _) => _fallback(s),
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
