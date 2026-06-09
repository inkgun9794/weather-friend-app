import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/shared/widgets/character_intro_button.dart';
import 'package:weather_friend/shared/widgets/character_portrait.dart';

class CharacterSelectScreen extends ConsumerWidget {
  const CharacterSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCharacterProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('캐릭터')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
        children: [
          for (final char in Character.all)
            _CharacterCard(
              character: char,
              isSelected: char.id == selected,
              onTap: () =>
                  ref.read(selectedCharacterProvider.notifier).set(char.id),
            ),
        ],
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
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
          padding: const EdgeInsets.all(16),
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
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CharacterPortrait(
                    charId: character.id,
                    size: 84,
                    enableTapToExpand: false,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    character.displayName,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _toneLabel(character.id),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: isSelected ? 1.0 : 0.0,
                    child: Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              // 미리듣기 스피커 — 카드 우상단
              Positioned(
                top: 0,
                right: 0,
                child: CharacterIntroButton(charId: character.id, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _toneLabel(CharacterId id) => switch (id) {
  CharacterId.jiyoung => '다정한 날사친',
  CharacterId.sohee => '전문 기상캐스터',
  CharacterId.jihoon => '듬직한 날사친',
  CharacterId.siwon => '상냥한 날사친',
};
