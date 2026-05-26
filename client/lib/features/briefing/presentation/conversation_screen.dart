import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/app/router/main_shell.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/shared/widgets/audio_bubble.dart';
import 'package:weather_friend/shared/widgets/char_avatar.dart';

/// 오늘 사이클의 모든 메시지를 시간순으로 누적 표시.
/// 메인 화면에선 5시 또는 9시 카드만 보이고, 그 외(10~21시 포함)는 여기서만.
class ConversationScreen extends ConsumerWidget {
  const ConversationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBriefings = ref.watch(todayBriefingsProvider);
    final currentHour = currentHourKst();

    // 하단 글래스 탭 뒤로 ListView가 흘러들어가도록 — 마지막 버블이 가려지지 않게
    // 바 높이 + 시스템 safe area + 약간의 숨 공간만큼 ListView 바닥 패딩 확보.
    final bottomInset =
        kGlassNavBarHeight + MediaQuery.paddingOf(context).bottom + 16;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '메세지',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: asyncBriefings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (briefings) {
          final entries =
              briefings.entries
                  .where((e) => e.key <= currentHour)
                  .toList()
                ..sort((a, b) => a.key.compareTo(b.key));

          if (entries.isEmpty) {
            return Center(
              child: Text(
                '아직 메시지가 없어요',
                style: TextStyle(color: AppColors.inkMute, fontSize: 14),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(todayBriefingsProvider),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, i) =>
                  _MessageBubble(hour: entries[i].key, briefing: entries[i].value),
            ),
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.hour, required this.briefing});

  final int hour;
  final Briefing briefing;

  @override
  Widget build(BuildContext context) {
    final charId = Character.parseId(briefing.characterId);
    if (charId == null) return const SizedBox.shrink();
    final character = Character.byId(charId);
    final v = visualFor(charId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 50, bottom: 4),
          child: Text(
            _timeLabel(hour),
            style: TextStyle(
              color: AppColors.inkMute,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CharAvatar(
              charId: charId,
              size: 40,
              variant: CharAvatarVariant.photo,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.displayName.split(' ').last,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                    decoration: BoxDecoration(
                      color: v.colorSoft,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          briefing.transcript,
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 14,
                            height: 1.5,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (briefing.audioUrl != null) ...[
                          const SizedBox(height: 10),
                          AudioBubble(
                            charId: charId,
                            audioUrl: briefing.audioUrl!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _timeLabel(int hour) {
    if (hour == 0) return '오전 12시';
    if (hour < 12) return '오전 $hour시';
    if (hour == 12) return '낮 12시';
    return '오후 ${hour - 12}시';
  }
}
