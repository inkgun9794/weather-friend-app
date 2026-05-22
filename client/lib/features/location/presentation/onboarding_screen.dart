import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/core/utils/oklch.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/features/location/data/onboarding_provider.dart';
import 'package:weather_friend/shared/widgets/char_avatar.dart';
import 'package:weather_friend/shared/widgets/character_portrait.dart';
import 'package:weather_friend/shared/widgets/weather_bg.dart';

/// 온보딩 — 4 step: Welcome → Location → Notification → Character.
/// (Schedule 단계는 5/21시 고정 정책이라 제외)
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _step = 0;
  static const _total = 4;

  void _goNext() {
    if (_step < _total - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    await ref.read(onboardingCompleteProvider.notifier).markComplete();
    if (mounted) context.go('/');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _step = i),
        children: [
          _WelcomeStep(onNext: _goNext),
          _LocationStep(onNext: _goNext),
          _NotificationStep(onNext: _goNext),
          _CharacterStep(onFinish: _finish),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────── shared shell
class _Shell extends StatelessWidget {
  const _Shell({
    required this.hour,
    required this.step,
    required this.dark,
    required this.body,
    required this.footer,
  });

  final int hour;
  final int step;
  final bool dark;
  final Widget body;
  final Widget footer;

  static const _total = 4;

  @override
  Widget build(BuildContext context) {
    return WeatherBg(
      hour: hour,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              _StepPips(current: step, total: _total, dark: dark),
              const SizedBox(height: 24),
              Expanded(child: body),
              const SizedBox(height: 16),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}

class _StepPips extends StatelessWidget {
  const _StepPips({
    required this.current,
    required this.total,
    required this.dark,
  });

  final int current;
  final int total;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final filled = dark ? oklch(1, 0, 0, 0.95) : oklch(0.22, 0.02, 250, 0.85);
    final empty = dark ? oklch(1, 0, 0, 0.22) : oklch(0.22, 0.02, 250, 0.18);
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < total - 1 ? 5 : 0),
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: i < current + 1 ? filled : empty,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.primary = true,
    this.dark = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = primary
        ? (dark ? oklch(0.98, 0.005, 250) : oklch(0.22, 0.02, 250))
        : (dark ? oklch(1, 0, 0, 0.18) : oklch(0, 0, 0, 0.05));
    final fg = primary
        ? (dark ? oklch(0.22, 0.02, 250) : oklch(0.98, 0.005, 250))
        : (dark ? oklch(0.98, 0.005, 250) : AppColors.ink);
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        elevation: primary ? 4 : 0,
        shadowColor: oklch(0, 0, 0, 0.18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.01,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────── Step 0. Welcome
class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final paperish = oklch(0.99, 0.005, 80);
    final subtle = oklch(0.98, 0.005, 250, 0.8);
    return _Shell(
      hour: 6,
      step: 0,
      dark: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [oklch(0.86, 0.13, 65), oklch(0.78, 0.18, 25)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: oklch(0, 0, 0, 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Text('☀', style: TextStyle(fontSize: 38)),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '날 씨  친 구',
            style: TextStyle(
              color: subtle,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '매일 아침,\n날씨 한 마디.',
            style: TextStyle(
              color: paperish,
              fontSize: 42,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 280,
            child: Text(
              '네 명의 친구 중 한 명이\n오늘 우산 챙길지 알려줄게요.',
              style: TextStyle(
                color: subtle,
                fontSize: 15,
                height: 1.6,
                letterSpacing: -0.15,
              ),
            ),
          ),
          const Spacer(),
          // mini character pile (overlapping avatars)
          SizedBox(
            height: 50,
            child: Stack(
              children: [
                for (var i = 0; i < CharacterId.values.length; i++)
                  Positioned(
                    left: i * 30.0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: oklch(1, 0, 0, 0.85),
                          width: 2,
                        ),
                      ),
                      child: CharacterPortrait(
                        charId: CharacterId.values[i],
                        size: 44,
                        enableTapToExpand: false,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
      footer: _PillButton(
        label: '시작하기',
        primary: true,
        dark: true,
        onTap: onNext,
      ),
    );
  }
}

// ─────────────────────────────────────────────────── Step 1. Location
class _LocationStep extends ConsumerStatefulWidget {
  const _LocationStep({required this.onNext});

  final VoidCallback onNext;

  @override
  ConsumerState<_LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends ConsumerState<_LocationStep> {
  bool _requested = false;
  bool _requesting = false;
  String _resultCity = '서울';

  @override
  void initState() {
    super.initState();
    // 이미 권한 있으면 자동으로 위치 fetch (사용자가 다시 들어왔을 때)
    _tryResolveSilently();
  }

  Future<void> _tryResolveSilently() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final city = await _resolveCityLabel();
        if (mounted) setState(() => _resultCity = city);
      }
    } catch (_) {/* keep default */}
  }

  Future<String> _resolveCityLabel() async {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 8),
      ),
    );
    final marks =
        await geocoding.placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (marks.isEmpty) return '서울';
    final m = marks.first;
    // 한국 주소 우선: 서울특별시 → 서울, 광진구 → 그대로
    final region = (m.administrativeArea ?? '')
        .replaceAll(RegExp(r'(특별시|광역시|특별자치(시|도)|도)$'), '');
    final sub = m.subLocality?.trim().isNotEmpty == true
        ? m.subLocality!.trim()
        : (m.locality ?? '').trim();
    final parts = [region, sub].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? '서울' : parts.join(' · ');
  }

  Future<void> _request() async {
    setState(() => _requesting = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final granted = perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
      if (granted) {
        final city = await _resolveCityLabel();
        if (mounted) setState(() => _resultCity = city);
      }
    } catch (_) {/* keep default — 서울 fallback */}
    if (mounted) {
      setState(() {
        _requesting = false;
        _requested = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Shell(
      hour: 9,
      step: 1,
      dark: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            '어디 날씨를\n알려드릴까요?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: -0.7,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 280,
            child: Text(
              '위치를 한 번만 알려주시면, 가장 가까운 도시의 날씨를 매일 가져올게요.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.inkSoft,
                height: 1.55,
                letterSpacing: -0.14,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // fake map card
          Container(
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [oklch(0.94, 0.02, 220), oklch(0.88, 0.04, 200)],
              ),
              border: Border.all(color: oklch(1, 0, 0, 0.5)),
              boxShadow: [
                BoxShadow(
                  color: oklch(0, 0, 0, 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: CustomPaint(
                painter: _MapRingsPainter(),
                child: Stack(
                  children: [
                    // pin
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Icon(
                          Icons.location_on,
                          color: oklch(0.55, 0.14, 25),
                          size: 40,
                        ),
                      ),
                    ),
                    // city pill
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 18,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: oklch(1, 0, 0, 0.9),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: oklch(0, 0, 0, 0.1),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: oklch(0.65, 0.2, 25),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _resultCity,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                  letterSpacing: -0.14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      footer: Column(
        children: [
          _PillButton(
            label: _requested ? '계속' : (_requesting ? '확인 중…' : '위치 허용하고 계속'),
            primary: true,
            onTap: _requesting
                ? null
                : (_requested ? widget.onNext : _request),
          ),
          const SizedBox(height: 14),
          Text(
            '나중에 설정에서 바꿀 수 있어요',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.inkMute,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (final entry in [(40.0, 0.30), (70.0, 0.22), (100.0, 0.15), (130.0, 0.08)]) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = oklch(0.55, 0.10, 240, entry.$2);
      canvas.drawCircle(Offset(cx, cy), entry.$1, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────── Step 2. Notification
class _NotificationStep extends StatefulWidget {
  const _NotificationStep({required this.onNext});

  final VoidCallback onNext;

  @override
  State<_NotificationStep> createState() => _NotificationStepState();
}

class _NotificationStepState extends State<_NotificationStep> {
  bool? _granted;
  bool _requesting = false;

  Future<void> _request() async {
    setState(() => _requesting = true);
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final iOS = plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ok = await iOS?.requestPermissions(alert: true, badge: true, sound: true) ??
          await android?.requestNotificationsPermission() ??
          false;
      setState(() {
        _granted = ok;
        _requesting = false;
      });
    } catch (_) {
      setState(() {
        _granted = false;
        _requesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Shell(
      hour: 10,
      step: 2,
      dark: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            '알람 받으셔야\n친구가 알려줘요.',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: -0.7,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '하루에 두 번, 정해진 시간에만 보내요. 광고는 절대 안 보내요.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.inkSoft,
              height: 1.55,
              letterSpacing: -0.14,
            ),
          ),
          const SizedBox(height: 28),
          // notification stack (3 cards)
          SizedBox(
            height: 250,
            child: Stack(
              children: [
                for (final depth in [2, 1, 0])
                  Positioned(
                    left: depth * 6,
                    right: depth * 6,
                    top: depth * 16.0,
                    child: Opacity(
                      opacity: 1 - depth * 0.15,
                      child: Transform.scale(
                        scale: 1 - depth * 0.04,
                        alignment: Alignment.topCenter,
                        child: _NotifPreview(
                          time: _previewData[depth].$1,
                          name: _previewData[depth].$2,
                          msg: _previewData[depth].$3,
                          charId: _previewData[depth].$4,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // bottom note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: oklch(1, 0, 0, 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: oklch(0, 0, 0, 0.04)),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    size: 18, color: oklch(0.55, 0.10, 240)),
                const SizedBox(width: 10),
                Text(
                  '아침·저녁 하루 2번 · 광고 0회',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkSoft,
                    letterSpacing: -0.125,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      footer: Column(
        children: [
          _PillButton(
            label: _granted == null
                ? (_requesting ? '확인 중…' : '알림 허용')
                : '계속',
            primary: true,
            onTap: _requesting
                ? null
                : (_granted == null ? _request : widget.onNext),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onNext,
            child: Text(
              '나중에 할래요',
              style: TextStyle(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// (time, name, msg, charId) — 시원 옛 인터넷어투는 새 페르소나에 맞게 자연 반말로 변경
const _previewData = <(String, String, String, CharacterId)>[
  ('오전 6:00', '지영', '일어났어? 오늘 우산은 안 가져가도 돼.', CharacterId.jiyoung),
  ('오후 10:00', '시원', '내일 정말 추워질 거야. 두꺼운 옷 꺼내!', CharacterId.siwon),
  ('오전 6:00', '지훈', '오늘 최저 14도, 바람 2m/s. 가볍게 입어도 돼.', CharacterId.jihoon),
];

class _NotifPreview extends StatelessWidget {
  const _NotifPreview({
    required this.time,
    required this.name,
    required this.msg,
    required this.charId,
  });

  final String time;
  final String name;
  final String msg;
  final CharacterId charId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: oklch(1, 0, 0, 0.92),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: oklch(0, 0, 0, 0.1),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CharAvatar(charId: charId, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        letterSpacing: -0.13,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.inkMute,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  msg,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.inkSoft,
                    height: 1.4,
                    letterSpacing: -0.13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────── Step 3. Character
class _CharacterStep extends ConsumerWidget {
  const _CharacterStep({required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCharacterProvider);
    return _Shell(
      hour: 11,
      step: 3,
      dark: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            '어떤 날사친이 좋으세요?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: -0.7,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '캐릭터마다 말투가 달라요.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.inkSoft,
              height: 1.55,
              letterSpacing: -0.14,
            ),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.78,
              padding: EdgeInsets.zero,
              children: [
                for (final char in Character.all)
                  _OnboardCharCard(
                    character: char,
                    isSelected: char.id == selected,
                    onTap: () => ref
                        .read(selectedCharacterProvider.notifier)
                        .set(char.id),
                  ),
              ],
            ),
          ),
        ],
      ),
      footer: Column(
        children: [
          _PillButton(
            label: '다음',
            primary: true,
            onTap: onFinish,
          ),
          const SizedBox(height: 14),
          Text(
            '언제든지 다른 친구로 바꿀 수 있어요',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.inkMute,
              letterSpacing: -0.12,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardCharCard extends StatelessWidget {
  const _OnboardCharCard({
    required this.character,
    required this.isSelected,
    required this.onTap,
  });

  final Character character;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = visualFor(character.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [oklch(1, 0, 0, 0.98), v.colorSoft],
                  )
                : null,
            color: isSelected ? null : oklch(1, 0, 0, 0.65),
            border: Border.all(
              color: isSelected ? v.color : oklch(0, 0, 0, 0.05),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: v.color.withValues(alpha: 0.45),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: oklch(0, 0, 0, 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CharacterPortrait(
                    charId: character.id,
                    size: 52,
                    enableTapToExpand: false,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _tag(character.id),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: v.colorDeep,
                      letterSpacing: -0.11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    character.displayName.split(' ').last,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.36,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: oklch(0, 0, 0, 0.08),
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _quote(character.id),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.inkMute,
                        fontStyle: FontStyle.italic,
                        height: 1.45,
                        letterSpacing: -0.115,
                      ),
                    ),
                  ),
                ],
              ),
              if (isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: v.color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _tag(CharacterId id) => switch (id) {
    CharacterId.jiyoung => '다정한 누나',
    CharacterId.sohee => '시크한 누나',
    CharacterId.jihoon => '듬직한 오빠',
    CharacterId.siwon => '활발한 동생',
  };

  String _quote(CharacterId id) => switch (id) {
    CharacterId.jiyoung => '"오늘 우산 꼭 챙겨야 해 알겠지?"',
    CharacterId.sohee => '"비 와. 알아서 챙겨."',
    CharacterId.jihoon => '"최고 22도. 셔츠 한 장이면 충분."',
    CharacterId.siwon => '"와 정말 더워! 반팔 입어!"',
  };
}
