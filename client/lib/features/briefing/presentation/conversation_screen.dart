import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/app/router/main_shell.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/shared/widgets/audio_bubble.dart';
import 'package:weather_friend/shared/widgets/character_portrait.dart';

/// 오늘 사이클의 모든 메시지를 시간순으로 누적 표시.
/// 카카오톡 스타일 — 같은 발신자 연속 메시지는 프로필/이름 한 번만, 시간은 버블 옆.
class ConversationScreen extends ConsumerWidget {
  const ConversationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBriefings = ref.watch(todayBriefingsProvider);
    final hour = currentHourKst();
    // 00~04시는 아직 어제 사이클 — 어제 브리핑(6~21시)은 모두 지났으니 전부 보여준다.
    // 05시부터는 현재 시각까지만 누적 표시.
    final cutoff = hour < kstCycleStartHour ? 24 : hour;

    // 하단 글래스 탭 뒤로 ListView가 흘러들어가도록 — 마지막 버블이 가려지지 않게.
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
                  .where((e) => e.key <= cutoff)
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
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final entry = entries[i];
                final prev = i > 0 ? entries[i - 1].value : null;
                // 같은 캐릭터 연속이면 헤더 (avatar + name) 생략.
                final showHeader = prev?.characterId != entry.value.characterId;
                return _MessageBubble(
                  hour: entry.key,
                  briefing: entry.value,
                  showHeader: showHeader,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.hour,
    required this.briefing,
    required this.showHeader,
  });

  final int hour;
  final Briefing briefing;
  final bool showHeader;

  static const double _avatarSize = 40;
  static const double _gap = 10;
  // 헤더 없는 연속 메시지에서 버블이 시작될 들여쓰기 (avatar 자리만큼).
  static const double _continuationIndent = _avatarSize + _gap;

  @override
  Widget build(BuildContext context) {
    final charId = Character.parseId(briefing.characterId);
    if (charId == null) return const SizedBox.shrink();
    final character = Character.byId(charId);
    final v = visualFor(charId);

    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      decoration: BoxDecoration(
        color: v.colorSoft,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(showHeader ? 4 : 16),
          topRight: const Radius.circular(16),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
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
            AudioBubble(charId: charId, audioUrl: briefing.audioUrl!),
          ],
        ],
      ),
    );

    final bubbleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(child: bubble),
        const SizedBox(width: 6),
        Text(
          _timeLabel(hour),
          style: TextStyle(
            color: AppColors.inkMute,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );

    if (!showHeader) {
      // 연속 메시지 — avatar/name 생략, 들여쓰기 + 위쪽 짧은 간격.
      return Padding(
        padding: const EdgeInsets.only(left: _continuationIndent, top: 4),
        child: bubbleRow,
      );
    }

    // 새 발신자 — avatar + name + 시작 버블. 위쪽 큰 간격.
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CharacterPortrait(
            charId: charId,
            size: _avatarSize,
            enableTapToExpand: false,
          ),
          const SizedBox(width: _gap),
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
                bubbleRow,
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 카카오톡 형식 — "오전 9:00", "오후 2:00".
  /// 브리핑은 시간 단위 해상도라 분은 항상 :00.
  String _timeLabel(int hour) {
    if (hour == 0) return '오전 12:00';
    if (hour < 12) return '오전 $hour:00';
    if (hour == 12) return '낮 12:00';
    return '오후 ${hour - 12}:00';
  }
}
