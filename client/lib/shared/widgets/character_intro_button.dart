import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/services/audio_player_service.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/shared/widgets/audio_bubble.dart'
    show currentlyPlayingProvider;

/// 작은 스피커 버튼 — 캐릭터 자기소개 mp3를 재생/일시정지.
/// 같은 currentlyPlayingProvider를 공유해서 다른 카드 누르면 자동 stop.
class CharacterIntroButton extends ConsumerWidget {
  const CharacterIntroButton({
    required this.charId,
    this.size = 28,
    this.color,
    super.key,
  });

  final CharacterId charId;
  final double size;
  final Color? color;

  String get _asset => 'assets/character_intros/${charId.name}.mp3';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(currentlyPlayingProvider);
    final isMe = playing == _asset;
    final tint = color ?? Theme.of(context).colorScheme.primary;

    return InkResponse(
      onTap: () async {
        final service = ref.read(audioPlayerServiceProvider);
        final notifier = ref.read(currentlyPlayingProvider.notifier);
        if (isMe) {
          await service.pause();
          notifier.stop();
        } else {
          notifier.start(_asset);
          try {
            await service.playAsset(_asset);
          } catch (_) {
            notifier.stop();
          }
        }
      },
      radius: size,
      child: Container(
        width: size + 8,
        height: size + 8,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: isMe ? 0.18 : 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isMe ? Icons.pause_rounded : Icons.volume_up_rounded,
          size: size * 0.7,
          color: tint,
        ),
      ),
    );
  }
}
