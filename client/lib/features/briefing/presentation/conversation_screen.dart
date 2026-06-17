import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/app/router/main_shell.dart';
import 'package:weather_friend/app/theme/app_type.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/features/chat/data/foundation_model_service.dart';
import 'package:weather_friend/features/chat/domain/chat_message.dart';
import 'package:weather_friend/features/chat/presentation/chat_controller.dart';
import 'package:weather_friend/shared/widgets/audio_bubble.dart';
import 'package:weather_friend/shared/widgets/character_portrait.dart';
import 'package:weather_friend/shared/widgets/weather_bg.dart';

const bool _enableOnDeviceChat = bool.fromEnvironment(
  'ENABLE_ON_DEVICE_CHAT',
  defaultValue: false,
);

class ConversationScreen extends ConsumerWidget {
  const ConversationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    late final Widget screen;

    if (!_enableOnDeviceChat) {
      screen = const _BriefingConversationScreen(
        availability: null,
        showChatNotice: false,
      );
    } else {
      final chat = ref.watch(chatControllerProvider);
      if (chat.isCheckingAvailability) {
        screen = const Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(child: Center(child: CircularProgressIndicator())),
        );
      } else if (chat.availability?.isAvailable == true) {
        screen = const _CharacterChatScreen();
      } else {
        screen = _BriefingConversationScreen(availability: chat.availability);
      }
    }

    return _MessagesDayBackground(child: screen);
  }
}

class _MessagesDayBackground extends ConsumerWidget {
  const _MessagesDayBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 날씨·기록·운세 탭과 같은 시간대 하늘 배경(WeatherBg)으로 일관성 유지.
    final hourAsync = ref.watch(kstHourProvider);
    final currentHour = switch (hourAsync) {
      AsyncData(:final value) => value,
      _ => currentHourKst(),
    };

    return WeatherBg(hour: currentHour, child: child);
  }
}

class _CharacterChatScreen extends ConsumerStatefulWidget {
  const _CharacterChatScreen();

  @override
  ConsumerState<_CharacterChatScreen> createState() =>
      _CharacterChatScreenState();
}

class _CharacterChatScreenState extends ConsumerState<_CharacterChatScreen>
    with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      ref.read(chatControllerProvider.notifier).onAppLeavingForeground();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(chatControllerProvider.notifier).onAppResumed();
    }
  }

  void _send() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    ref.read(chatControllerProvider.notifier).send(text);
    _focusNode.requestFocus();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _confirmClear(Character character) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대화 지우기'),
        content: Text('${character.displayName}과 나눈 대화를 모두 지울까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (shouldClear == true) {
      await ref.read(chatControllerProvider.notifier).clearConversation();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(messageTabSelectionProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    final chat = ref.watch(chatControllerProvider);
    final character = Character.byId(chat.characterId);
    final visual = visualFor(chat.characterId);
    // AppBar·빈 화면 텍스트는 하늘 위에 직접 떠 있으므로 시간대 잉크 색을 쓴다
    // (밤엔 배경이 어두워져 고정 잉크색은 안 보인다).
    final hourAsync = ref.watch(kstHourProvider);
    final currentHour = switch (hourAsync) {
      AsyncData(:final value) => value,
      _ => currentHourKst(),
    };
    final sky = skyFor(currentHour);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final composerBottom = keyboardOpen
        ? 8.0
        : kGlassNavBarHeight + MediaQuery.paddingOf(context).bottom + 8;

    if (chat.messages.length != _lastMessageCount) {
      _lastMessageCount = chat.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            CharacterPortrait(
              charId: chat.characterId,
              size: 36,
              enableTapToExpand: false,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.displayName,
                  style: AppType.headline.copyWith(
                    color: sky.ink,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  chat.isGenerating ? '답장을 생각하는 중' : '기기 안에서 대화 중',
                  style: AppType.micro2.copyWith(
                    color: sky.inkSoft,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '대화 지우기',
            color: sky.ink,
            onPressed: chat.messages.isEmpty
                ? null
                : () => _confirmClear(character),
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: '설정',
            color: sky.ink,
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.menu_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.messages.isEmpty
                ? _EmptyChat(character: character, sky: sky)
                : ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                    itemCount:
                        chat.messages.length + (chat.isGenerating ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chat.messages.length) {
                        return _ThinkingBubble(characterId: chat.characterId);
                      }
                      final message = chat.messages[index];
                      final previous = index == 0
                          ? null
                          : chat.messages[index - 1];
                      return _ChatBubble(
                        message: message,
                        characterId: chat.characterId,
                        showAvatar:
                            message.sender == ChatSender.character &&
                            previous?.sender != ChatSender.character,
                      );
                    },
                  ),
          ),
          if (chat.secondsUntilReply != null)
            _ReplyCountdown(
              seconds: chat.secondsUntilReply!,
              color: visual.colorDeep,
              sky: sky,
              onGenerateNow: () =>
                  ref.read(chatControllerProvider.notifier).generateNow(),
            ),
          if (chat.errorMessage != null)
            _ChatError(
              message: chat.errorMessage!,
              sky: sky,
              onRetry: () => ref.read(chatControllerProvider.notifier).retry(),
            ),
          _ChatComposer(
            controller: _textController,
            focusNode: _focusNode,
            enabled: !chat.isGenerating,
            accent: visual.colorDeep,
            bottomPadding: composerBottom,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.character, required this.sky});

  final Character character;
  final SkyPalette sky;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CharacterPortrait(
              charId: character.id,
              size: 76,
              enableTapToExpand: false,
            ),
            const SizedBox(height: 18),
            Text(
              '${character.displayName}에게 말을 걸어봐',
              style: AppType.title.copyWith(color: sky.ink, letterSpacing: 0),
            ),
            const SizedBox(height: 8),
            Text(
              '여러 번 나눠 보내도 괜찮아.\n마지막 말부터 잠시 기다렸다가 답장할게.',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(
                color: sky.inkSoft,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.characterId,
    required this.showAvatar,
  });

  final ChatMessage message;
  final CharacterId characterId;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == ChatSender.user;
    final visual = visualFor(characterId);
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? AppColors.ink : visual.colorSoft,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(!isUser && showAvatar ? 5 : 17),
          topRight: Radius.circular(isUser ? 5 : 17),
          bottomLeft: const Radius.circular(17),
          bottomRight: const Radius.circular(17),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.text,
            style: AppType.reading.copyWith(
              color: isUser ? Colors.white : AppColors.ink,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
          if (!isUser && message.audioUrl != null) ...[
            const SizedBox(height: 9),
            AudioBubble(charId: characterId, audioUrl: message.audioUrl!),
          ],
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: showAvatar || isUser ? 12 : 4,
        left: isUser ? 44 : 0,
        right: isUser ? 0 : 34,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            SizedBox(
              width: 34,
              child: showAvatar
                  ? CharacterPortrait(
                      charId: characterId,
                      size: 30,
                      enableTapToExpand: false,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble({required this.characterId});

  final CharacterId characterId;

  @override
  Widget build(BuildContext context) {
    final visual = visualFor(characterId);
    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 120),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CharacterPortrait(
            charId: characterId,
            size: 30,
            enableTapToExpand: false,
          ),
          const SizedBox(width: 8),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: visual.colorSoft,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(17),
                bottomLeft: Radius.circular(17),
                bottomRight: Radius.circular(17),
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyCountdown extends StatelessWidget {
  const _ReplyCountdown({
    required this.seconds,
    required this.color,
    required this.sky,
    required this.onGenerateNow,
  });

  final int seconds;
  final Color color;
  final SkyPalette sky;
  final VoidCallback onGenerateNow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 5, 10, 2),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 15, color: sky.inkSoft),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '이어 말하는 걸 기다리는 중 · $seconds초',
              style: AppType.micro.copyWith(
                color: sky.inkSoft,
                letterSpacing: 0,
              ),
            ),
          ),
          TextButton(
            onPressed: onGenerateNow,
            style: TextButton.styleFrom(foregroundColor: color),
            child: const Text('지금 답장'),
          ),
        ],
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({
    required this.message,
    required this.sky,
    required this.onRetry,
  });

  final String message;
  final SkyPalette sky;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 12, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: AppType.micro.copyWith(
                color: sky.inkSoft,
                letterSpacing: 0,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.accent,
    required this.bottomPadding,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final Color accent;
  final double bottomPadding;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.fromLTRB(12, 6, 12, bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: '메세지 보내기',
                hintStyle: TextStyle(
                  color: AppColors.inkFaint,
                  letterSpacing: 0,
                ),
                filled: true,
                fillColor: AppColors.paper2,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: '보내기',
            onPressed: enabled ? onSend : null,
            style: IconButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.paper3,
            ),
            icon: const Icon(Icons.arrow_upward, size: 20),
          ),
        ],
      ),
    );
  }
}

/// 지원되지 않는 기기에서는 로컬에 누적된 브리핑 기록을 보여준다.
class _BriefingConversationScreen extends ConsumerStatefulWidget {
  const _BriefingConversationScreen({
    required this.availability,
    this.showChatNotice = true,
  });

  final FoundationModelAvailability? availability;
  final bool showChatNotice;

  @override
  ConsumerState<_BriefingConversationScreen> createState() =>
      _BriefingConversationScreenState();
}

class _BriefingConversationScreenState
    extends ConsumerState<_BriefingConversationScreen> {
  final _scrollController = ScrollController();
  int _lastVisibleCount = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest({bool animate = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(messageTabSelectionProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToLatest(animate: true),
      );
    });

    final asyncBriefings = ref.watch(todayBriefingsProvider);
    final history = ref.watch(briefingHistoryProvider);
    final hour = currentHourKst();
    // 상단 아이콘·빈 화면·날짜 구분선은 하늘 위에 직접 떠 있으므로 시간대 잉크 색.
    final sky = skyFor(hour);
    final activeDate = todayKstIso();
    // 00~04시는 아직 어제 사이클 — 어제 브리핑(6~21시)은 모두 지났으니 전부 보여준다.
    // 05시부터는 현재 시각까지만 누적 표시.
    final cutoff = hour < kstCycleStartHour ? 24 : hour;
    final visibleHistory = history
        .where((briefing) {
          final dateOrder = briefing.date.compareTo(activeDate);
          return dateOrder < 0 || (dateOrder == 0 && briefing.hour <= cutoff);
        })
        .toList(growable: false);

    if (visibleHistory.length != _lastVisibleCount) {
      _lastVisibleCount = visibleHistory.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }

    // 하단 글래스 탭 뒤로 ListView가 흘러들어가도록 — 마지막 버블이 가려지지 않게.
    final bottomInset =
        kGlassNavBarHeight + MediaQuery.paddingOf(context).bottom + 16;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: '설정',
                onPressed: () => context.push('/settings'),
                icon: Icon(Icons.menu_rounded, color: sky.ink),
              ),
            ),
            Expanded(
              child: asyncBriefings.isLoading && visibleHistory.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : visibleHistory.isEmpty
                  ? Center(
                      child: Text(
                        asyncBriefings.hasError
                            ? '메시지를 불러오지 못했어요'
                            : '아직 메시지가 없어요',
                        style: AppType.bodyLg.copyWith(color: sky.inkSoft),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(todayBriefingsProvider.notifier).refresh(),
                      child: ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset),
                        children: [
                          if (widget.showChatNotice)
                            _UnsupportedChatNotice(
                              availability: widget.availability,
                              sky: sky,
                            ),
                          ..._historyWidgets(
                            visibleHistory,
                            activeDate: activeDate,
                            sky: sky,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _historyWidgets(
  List<Briefing> history, {
  required String activeDate,
  required SkyPalette sky,
}) {
  final widgets = <Widget>[];
  for (var i = 0; i < history.length; i++) {
    final briefing = history[i];
    final previous = i == 0 ? null : history[i - 1];
    final startsNewDay = previous?.date != briefing.date;

    if (startsNewDay) {
      widgets.add(
        _MessageDateDivider(
          date: briefing.date,
          activeDate: activeDate,
          sky: sky,
        ),
      );
    }
    widgets.add(
      _MessageBubble(
        hour: briefing.hour,
        briefing: briefing,
        showHeader:
            startsNewDay || previous?.characterId != briefing.characterId,
      ),
    );
  }
  return widgets;
}

class _MessageDateDivider extends StatelessWidget {
  const _MessageDateDivider({
    required this.date,
    required this.activeDate,
    required this.sky,
  });

  final String date;
  final String activeDate;
  final SkyPalette sky;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            child: Text(
              _dateLabel(date, activeDate),
              style: AppType.micro.copyWith(color: sky.inkSoft),
            ),
          ),
        ),
      ),
    );
  }
}

String _dateLabel(String date, String activeDate) {
  if (date == activeDate) return '오늘';

  final parsed = DateTime.tryParse(date);
  final active = DateTime.tryParse(activeDate);
  if (parsed == null) return date;
  if (active != null &&
      parsed.year == active.subtract(const Duration(days: 1)).year &&
      parsed.month == active.subtract(const Duration(days: 1)).month &&
      parsed.day == active.subtract(const Duration(days: 1)).day) {
    return '어제';
  }

  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${parsed.month}월 ${parsed.day}일 ${weekdays[parsed.weekday - 1]}요일';
}

class _UnsupportedChatNotice extends StatelessWidget {
  const _UnsupportedChatNotice({required this.availability, required this.sky});

  final FoundationModelAvailability? availability;
  final SkyPalette sky;

  @override
  Widget build(BuildContext context) {
    final message = switch (availability?.status) {
      FoundationModelStatus.appleIntelligenceNotEnabled =>
        'Apple Intelligence를 켜면 캐릭터와 기기 안에서 대화할 수 있어요.',
      FoundationModelStatus.modelNotReady =>
        '대화 모델을 준비하고 있어요. 다운로드가 끝나면 대화를 시작할 수 있어요.',
      FoundationModelStatus.unsupportedLanguage =>
        '현재 기기의 Apple Intelligence 언어에서는 한국어 대화를 지원하지 않아요.',
      _ => '지원되는 아이폰에서는 캐릭터와 기기 안에서 대화할 수 있어요.',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 17, color: sky.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppType.caption.copyWith(
                color: sky.inkSoft,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
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
    final outsideTextColor = hour >= 19
        ? Colors.white.withValues(alpha: 0.82)
        : AppColors.inkMute;

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
            style: AppType.reading.copyWith(color: AppColors.ink, height: 1.5),
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
          style: AppType.micro2.copyWith(color: outsideTextColor),
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
                  style: AppType.caption.copyWith(
                    color: hour >= 19 ? Colors.white : AppColors.ink,
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
