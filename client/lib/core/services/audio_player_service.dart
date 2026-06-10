import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

Future<void> configureSpeechAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.speech());
}

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

class AudioPlayerService {
  AudioPlayerService() : _player = AudioPlayer();

  final AudioPlayer _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Duration? get duration => _player.duration;

  Future<void> playUrl(String url) async {
    await configureSpeechAudioSession();
    await _player.setUrl(url);
    await _player.play();
  }

  Future<void> playAsset(String assetPath) async {
    await configureSpeechAudioSession();
    await _player.setAsset(assetPath);
    await _player.play();
  }

  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();

  void dispose() => _player.dispose();
}

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(service.dispose);
  return service;
});

final audioPlayerStateProvider = StreamProvider<PlayerState>((ref) {
  return ref.watch(audioPlayerServiceProvider).playerStateStream;
});

final audioPositionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(audioPlayerServiceProvider).positionStream;
});

final audioDurationProvider = StreamProvider<Duration?>((ref) {
  return ref.watch(audioPlayerServiceProvider).durationStream;
});
