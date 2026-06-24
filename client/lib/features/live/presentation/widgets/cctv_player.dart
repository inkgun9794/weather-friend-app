import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:weather_friend/app/theme/app_type.dart';
import 'package:weather_friend/features/live/data/cctv_camera.dart';

/// 한 CCTV의 실시간 HLS 영상을 재생한다.
///
/// 부모는 카메라가 바뀌면 `ValueKey(streamUrl)`로 새 인스턴스를 만들어 컨트롤러
/// 수명을 단순화한다(이전 인스턴스 dispose → 새 컨트롤러 생성).
///
/// 자체 에러 UI는 두지 않는다 — 초기화/재생에 실패하면 [onFailed]를 1회 호출하고,
/// 화면(부모)이 토큰 갱신 또는 다음 카메라 전환으로 이 위젯을 교체한다. 교체 전까지는
/// 로딩 스피너를 유지한다.
class CctvPlayer extends StatefulWidget {
  const CctvPlayer({
    required this.camera,
    required this.active,
    required this.onFailed,
    super.key,
  });

  final CctvCamera camera;

  /// 라이브 탭이 화면에 보이는 동안만 true. false면 영상을 멈춰 데이터·배터리 절약.
  final bool active;

  /// 초기화 타임아웃/재생 오류로 영상을 못 띄울 때 1회 호출. 화면이 복구를 결정한다.
  final VoidCallback onFailed;

  @override
  State<CctvPlayer> createState() => _CctvPlayerState();
}

class _CctvPlayerState extends State<CctvPlayer> with WidgetsBindingObserver {
  // 죽은 카메라에서 무한 로딩하지 않도록 — 이 시간 안에 못 열면 실패로 본다.
  static const _initTimeout = Duration(seconds: 10);

  VideoPlayerController? _controller;
  bool _appResumed = true;
  bool _notifiedFailure = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    // ITS의 cctvurl은 확장자 없는 토큰 URL이라(.m3u8 미포함) 플레이어가 HLS를
    // 자동 감지하지 못한다 — formatHint로 강제. 접속 시 302로 실제 playlist.m3u8
    // (같은 호스트 :8081)로 리다이렉트되며 플레이어가 따라간다.
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.camera.streamUrl),
      formatHint: VideoFormat.hls,
    );
    _controller = controller;
    try {
      await controller.initialize().timeout(_initTimeout);
      await controller.setLooping(true);
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.addListener(_onValueChanged);
      _syncPlayback();
      setState(() {});
    } catch (_) {
      await _safeDispose(controller);
      if (!mounted) return;
      _controller = null;
      _reportFailure();
    }
  }

  /// 초기화는 됐지만 재생 중 디코드/네트워크 오류가 난 경우도 실패로 처리.
  void _onValueChanged() {
    final c = _controller;
    if (c == null || _notifiedFailure) return;
    if (c.value.hasError) {
      _controller = null;
      _reportFailure();
      _safeDispose(c);
    }
  }

  void _reportFailure() {
    if (_notifiedFailure) return;
    _notifiedFailure = true;
    if (mounted) setState(() {}); // 컨트롤러 null → 스피너. 곧 부모가 교체한다.
    widget.onFailed();
  }

  @override
  void didUpdateWidget(CctvPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  void _syncPlayback() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final shouldPlay = widget.active && _appResumed;
    if (shouldPlay && !c.value.isPlaying) {
      c.play();
    } else if (!shouldPlay && c.value.isPlaying) {
      c.pause();
    }
  }

  Future<void> _safeDispose(VideoPlayerController c) async {
    c.removeListener(_onValueChanged);
    try {
      await c.dispose();
    } catch (_) {
      // 초기화 중 dispose는 드물게 throw — 무시.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onValueChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(color: Colors.black, child: _content()),
    );
  }

  Widget _content() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      // 로딩/실패-복구대기 공통 — 부모가 곧 교체하거나 다음 카메라로 넘긴다.
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Colors.white70,
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(c),
          ),
        ),
        if (widget.active)
          const Positioned(top: 10, left: 10, child: _LiveBadge()),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFFFF4D4F),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: AppType.micro2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
