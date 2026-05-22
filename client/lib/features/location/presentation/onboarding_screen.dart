import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/features/location/data/onboarding_provider.dart';
import 'package:weather_friend/shared/widgets/char_avatar.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _step = 0;

  void _goNext() {
    if (_step < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
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
      body: SafeArea(
        child: Column(
          children: [
            _StepIndicator(current: _step, total: 3),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _LocationStep(onNext: _goNext),
                  _NotificationStep(onNext: _goNext),
                  _CharacterStep(onFinish: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < total - 1 ? 8 : 0),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= current
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── 1. Location
class _LocationStep extends StatefulWidget {
  const _LocationStep({required this.onNext});

  final VoidCallback onNext;

  @override
  State<_LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<_LocationStep> {
  String? _resultLabel;
  bool _requesting = false;

  Future<void> _request() async {
    setState(() => _requesting = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      setState(() {
        _resultLabel = granted
            ? '현재 위치 기준으로 알려드릴게요.'
            : '서울 기준으로 알려드릴게요. 나중에 설정에서 변경할 수 있어요.';
      });
    } catch (e) {
      setState(() => _resultLabel = '서울 기준으로 알려드릴게요.');
    } finally {
      setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Icon(Icons.location_on_outlined, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text('위치 권한', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            '지금 있는 곳의 날씨를 정확히 받으려면 위치 권한이 필요해요.\n'
            '거부해도 서울 기준으로 작동하니 부담 없이 선택하세요.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const Spacer(),
          if (_resultLabel != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_resultLabel!)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _requesting
                  ? null
                  : (_resultLabel != null ? widget.onNext : _request),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_resultLabel != null ? '다음' : '위치 권한 요청'),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── 2. Notification
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
      final iOS = plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final android = plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final ok = await iOS?.requestPermissions(alert: true, badge: true, sound: true) ??
          await android?.requestNotificationsPermission() ??
          false;
      setState(() => _granted = ok);
    } catch (e) {
      setState(() => _granted = false);
    } finally {
      setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Icon(Icons.notifications_outlined, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text('알림 권한', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            '오전 5시·오후 9시에 캐릭터가 직접 알려주는 푸시를 받을 수 있어요.\n'
            '거부하면 푸시 알림이 오지 않고, 앱을 직접 열어 메시지를 확인하셔야 해요.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const Spacer(),
          if (_granted != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _granted! ? Icons.check_circle : Icons.info_outline,
                    color: _granted!
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _granted!
                          ? '알림으로 알려드릴게요.'
                          : '푸시는 오지 않아요. 앱을 열어서 메시지를 확인해주세요.',
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _requesting
                  ? null
                  : (_granted != null ? widget.onNext : _request),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_granted != null ? '다음' : '알림 권한 요청'),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── 3. Character
class _CharacterStep extends ConsumerWidget {
  const _CharacterStep({required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selected = ref.watch(selectedCharacterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('어떤 날사친이 좋으세요?', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '나중에 설정에서 언제든 바꿀 수 있어요.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
              children: [
                for (final char in Character.all)
                  _OnboardCharacterCard(
                    character: char,
                    isSelected: char.id == selected,
                    onTap: () => ref
                        .read(selectedCharacterProvider.notifier)
                        .set(char.id),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onFinish,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('시작하기'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardCharacterCard extends StatelessWidget {
  const _OnboardCharacterCard({
    required this.character,
    required this.isSelected,
    required this.onTap,
  });

  final Character character;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CharAvatar(charId: character.id, size: 70, ring: isSelected),
              const SizedBox(height: 10),
              Text(character.displayName,
                  style: theme.textTheme.titleSmall, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                _tone(character.id),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _tone(CharacterId id) => switch (id) {
    CharacterId.jiyoung => '따뜻한 누나',
    CharacterId.sohee => '시크한 누나',
    CharacterId.jihoon => '듬직한 오빠',
    CharacterId.siwon => '활발한 동생',
  };
}
