import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/shared/widgets/audio_play_button.dart';

class BriefingScreen extends ConsumerWidget {
  const BriefingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBriefings = ref.watch(todayBriefingsProvider);
    final character = ref.watch(selectedCharacterProvider);
    final currentHour = currentHourKst();

    return Scaffold(
      appBar: AppBar(
        title: Text('날사친 · ${Character.byId(character).displayName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: asyncBriefings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (briefings) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(todayBriefingsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: 24,
            itemBuilder: (context, hour) => _SlotTile(
              hour: hour,
              briefing: briefings[hour],
              isFuture: hour > currentHour,
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.hour,
    required this.briefing,
    required this.isFuture,
  });

  final int hour;
  final Briefing? briefing;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hourLabel = _formatHour(hour);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hourLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isFuture
                  ? theme.colorScheme.outline
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          if (briefing == null)
            _EmptyBubble(isFuture: isFuture)
          else
            _Bubble(briefing: briefing!),
        ],
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '오전 12시';
    if (hour < 12) return '오전 $hour시';
    if (hour == 12) return '오후 12시';
    return '오후 ${hour - 12}시';
  }
}

class _EmptyBubble extends StatelessWidget {
  const _EmptyBubble({required this.isFuture});

  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        isFuture ? '아직' : '—',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.briefing});

  final Briefing briefing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audioUrl = briefing.audioUrl;
    final snap = briefing.weatherSnapshot;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            briefing.transcript,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${snap.temperatureC.round()}° · ${snap.condition} · 강수 ${snap.precipitationProb}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ),
              if (audioUrl != null) AudioPlayButton(audioUrl: audioUrl),
            ],
          ),
        ],
      ),
    );
  }
}
