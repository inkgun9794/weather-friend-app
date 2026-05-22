import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/services/audio_player_service.dart';

class CurrentlyPlayingNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void start(String url) => state = url;
  void stop() => state = null;
}

final currentlyPlayingProvider =
    NotifierProvider<CurrentlyPlayingNotifier, String?>(
      CurrentlyPlayingNotifier.new,
    );

class AudioPlayButton extends ConsumerWidget {
  const AudioPlayButton({required this.audioUrl, super.key});

  final String audioUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(currentlyPlayingProvider);
    final isMe = playing == audioUrl;
    return IconButton.filledTonal(
      onPressed: () async {
        final service = ref.read(audioPlayerServiceProvider);
        final notifier = ref.read(currentlyPlayingProvider.notifier);
        if (isMe) {
          await service.pause();
          notifier.stop();
        } else {
          notifier.start(audioUrl);
          await service.playUrl(audioUrl);
        }
      },
      icon: Icon(isMe ? Icons.pause : Icons.play_arrow),
    );
  }
}
