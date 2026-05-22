import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/shared/widgets/char_avatar.dart';

/// 캐릭터 일러스트를 GitHub Pages에서 로드.
///
/// URL: https://inkgun9794.github.io/weather-friend-app/characters/{id}/{outfit}.png
///
/// 일러스트가 아직 없거나 네트워크 실패 시 기존 CharAvatar(SVG)로 fallback —
/// 한 캐릭터씩 점진적으로 채워가도 화면이 깨지지 않음.
///
/// 지금은 outfit='portrait' 단일 템플릿. 추후 옷차림(summer/cold 등) 다양화 시
/// outfit 인자만 바꿔서 같은 URL 패턴으로 확장 가능.
class CharacterPortrait extends StatelessWidget {
  const CharacterPortrait({
    required this.charId,
    this.outfit = 'portrait',
    this.size = 200,
    super.key,
  });

  final CharacterId charId;
  final String outfit;
  final double size;

  static const _baseUrl =
      'https://inkgun9794.github.io/weather-friend-app/characters';

  String get _url => '$_baseUrl/${charId.name}/$outfit.png';

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholder: (ctx, _) => Center(
        child: CharAvatar(charId: charId, size: size * 0.7, ring: true),
      ),
      errorWidget: (ctx, _, _) => Center(
        child: CharAvatar(charId: charId, size: size * 0.7, ring: true),
      ),
    );
  }
}
