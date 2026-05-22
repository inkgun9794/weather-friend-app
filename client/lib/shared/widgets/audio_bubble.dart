import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/core/services/audio_player_service.dart';
import 'package:weather_friend/features/character/domain/character.dart';

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

const _waveformBars = <double>[
  3, 5, 7, 9, 12, 16, 18, 14, 10, 7,
  5, 8, 12, 15, 18, 20, 17, 13, 9, 11,
  14, 17, 15, 12, 8, 5, 4, 6, 9, 11,
];

class AudioBubble extends ConsumerWidget {
  const AudioBubble({
    required this.charId,
    required this.audioUrl,
    this.duration,
    this.tone = AudioBubbleTone.light,
    super.key,
  });

  final CharacterId charId;
  final String audioUrl;
  final String? duration;
  final AudioBubbleTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = visualFor(charId);
    final playing = ref.watch(currentlyPlayingProvider);
    final isMe = playing == audioUrl;
    final isDark = tone == AudioBubbleTone.dark;

    final bg = isDark ? AppColors.ink : v.colorSoft;
    final barPlayed = isDark ? const Color(0xFFFAFAFC) : v.colorDeep;
    final barIdle = isDark
        ? const Color(0xFFFFFFFF).withValues(alpha: 0.28)
        : v.colorDeep.withValues(alpha: 0.28);
    final durationColor = isDark
        ? const Color(0xFFBDBEC8)
        : AppColors.inkMute;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 290),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(7, 7, 13, 7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PlayButton(
                  color: v.color,
                  playing: isMe,
                  onTap: () async {
                    final service = ref.read(audioPlayerServiceProvider);
                    final notifier = ref.read(
                      currentlyPlayingProvider.notifier,
                    );
                    if (isMe) {
                      await service.pause();
                      notifier.stop();
                    } else {
                      notifier.start(audioUrl);
                      await service.playUrl(audioUrl);
                    }
                  },
                ),
                const SizedBox(width: 11),
                _Waveform(played: barPlayed, idle: barIdle, progress: isMe ? 0.35 : 0.0),
                const SizedBox(width: 8),
                Text(
                  duration ?? '',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: durationColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: -3,
            bottom: 0,
            child: CustomPaint(
              size: const Size(13, 17),
              painter: _BubbleTailPainter(color: bg, flip: false),
            ),
          ),
        ],
      ),
    );
  }
}

enum AudioBubbleTone { light, dark }

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.color,
    required this.playing,
    required this.onTap,
  });

  final Color color;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(
          playing ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.played,
    required this.idle,
    required this.progress,
  });

  final Color played;
  final Color idle;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _waveformBars.length; i++)
            Container(
              width: 2,
              height: _waveformBars[i],
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1.5),
                color: i / _waveformBars.length < progress ? played : idle,
              ),
            ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color, required this.flip});

  final Color color;
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    if (flip) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    final path = Path()
      ..moveTo(w, 0)
      ..cubicTo(w, h * 0.53, w * 0.69, h * 0.82, 0, h)
      ..cubicTo(w * 0.38, h * 0.88, w * 0.62, h * 0.65, w * 0.62, h * 0.29)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.flip != flip;
}
