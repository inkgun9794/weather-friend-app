import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/fortune/data/pending_fortune.dart';

/// 본문 내용이 글래스 바 뒤로 비치도록 — 화면들은 `MediaQuery.paddingOf(context).bottom`로
/// 마지막 컨텐츠 아래 여백을 잡아주면 가려지지 않음.
const double kGlassNavBarHeight = 58;

/// 운세 탭 인덱스 — pending fortune 풍선 위치 판단용.
const int _kFortuneTabIndex = 2;

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _GlassNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(
          i,
          // 활성 탭을 다시 누르면 그 브랜치의 초기 위치로 리셋
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _GlassNavBar extends ConsumerWidget {
  const _GlassNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingFortuneProvider);
    final showFortuneBubble =
        pending.status == PendingFortuneStatus.ready &&
            currentIndex != _kFortuneTabIndex;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.62),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.55),
                width: 0.6,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: kGlassNavBarHeight,
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.cloud_outlined,
                    iconActive: Icons.cloud,
                    label: '날씨',
                    active: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    icon: Icons.chat_bubble_outline,
                    iconActive: Icons.chat_bubble,
                    label: '메세지',
                    active: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  _NavItem(
                    icon: Icons.auto_awesome_outlined,
                    iconActive: Icons.auto_awesome,
                    label: '운세',
                    active: currentIndex == _kFortuneTabIndex,
                    bubble: showFortuneBubble ? '결과 확인' : null,
                    onTap: () => onTap(_kFortuneTabIndex),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.active,
    required this.onTap,
    this.bubble,
  });

  final IconData icon;
  final IconData iconActive;
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// non-null이면 아이콘 위에 말꼬리 풍선 표시.
  final String? bubble;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.ink : AppColors.inkMute;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(active ? iconActive : icon, color: color, size: 22),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 10.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
              if (bubble != null)
                Positioned(
                  top: -28,
                  child: _SpeechBubble(text: bubble!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 둥근 직사각형 본체 + 아래쪽 작은 삼각형 꼬리.
class _SpeechBubble extends StatefulWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  State<_SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<_SpeechBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bobCtrl;
  late final Animation<double> _bob;

  @override
  void initState() {
    super.initState();
    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _bob = Tween<double>(begin: 0, end: -3).animate(
      CurvedAnimation(parent: _bobCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bobCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _bob.value),
        child: child,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              widget.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ),
          // 꼬리 삼각형
          CustomPaint(
            size: const Size(10, 5),
            painter: _BubbleTailPainter(color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter old) => old.color != color;
}
