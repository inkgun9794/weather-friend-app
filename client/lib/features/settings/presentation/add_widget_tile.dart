import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:weather_friend/core/services/weather_widget_service.dart';

/// Settings entry that adds the home-screen weather widget.
///
/// - Android: asks the launcher to show its native "add to home screen" dialog
///   (one tap for the user). Falls back to the manual guide if unsupported.
/// - iOS: Apple has no programmatic add, so we show an illustrated how-to.
class AddWidgetTile extends StatelessWidget {
  const AddWidgetTile({super.key});

  static const _service = WeatherWidgetService();

  Future<void> _onTap(BuildContext context) async {
    if (await _service.canRequestPin()) {
      await _service.requestPin();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('홈 화면에서 위젯 추가를 확인해 주세요.')),
        );
      }
      return;
    }
    if (context.mounted) {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const _AddWidgetGuide(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.widgets_outlined),
      title: const Text('홈 화면 위젯'),
      subtitle: const Text('현재 날씨를 홈 화면에서 바로 보기'),
      onTap: () => _onTap(context),
    );
  }
}

/// Manual how-to shown on iOS (and Android launchers that can't pin).
class _AddWidgetGuide extends StatelessWidget {
  const _AddWidgetGuide();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    final steps = isIOS
        ? const [
            '홈 화면의 빈 곳을 길게 누르세요.',
            '왼쪽 위 "＋" 버튼을 누르세요.',
            '목록에서 "날사친"을 찾아 선택하세요.',
            '"위젯 추가"를 누르고 원하는 위치에 놓으세요.',
          ]
        : const [
            '홈 화면의 빈 곳을 길게 누르세요.',
            '"위젯"을 누르세요.',
            '목록에서 "날사친"을 찾으세요.',
            '위젯을 길게 눌러 홈 화면에 끌어다 놓으세요.',
          ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.widgets_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  '홈 화면에 위젯 추가하기',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < steps.length; i++) ...[
              _Step(index: i + 1, text: steps[i]),
              if (i < steps.length - 1) const SizedBox(height: 14),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ),
      ],
    );
  }
}
