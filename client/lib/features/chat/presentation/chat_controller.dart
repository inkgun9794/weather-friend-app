import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/services/notification_service.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/core/utils/kst.dart';
import 'package:weather_friend/features/briefing/domain/briefing.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/features/chat/data/chat_repository.dart';
import 'package:weather_friend/features/chat/data/foundation_model_service.dart';
import 'package:weather_friend/features/chat/domain/briefing_delivery_policy.dart';
import 'package:weather_friend/features/chat/domain/chat_message.dart';

const chatReplyDelaySeconds = int.fromEnvironment(
  'CHAT_REPLY_DELAY_SECONDS',
  defaultValue: 0,
);
const _chatNudgeDelay = Duration(minutes: 45);
const _attentionPrefixCooldown = Duration(hours: 4);
const _chatNudgeNotificationBaseId = 7300;

class ChatState {
  const ChatState({
    required this.characterId,
    required this.messages,
    this.availability,
    this.isCheckingAvailability = true,
    this.isGenerating = false,
    this.secondsUntilReply,
    this.errorMessage,
  });

  final CharacterId characterId;
  final List<ChatMessage> messages;
  final FoundationModelAvailability? availability;
  final bool isCheckingAvailability;
  final bool isGenerating;
  final int? secondsUntilReply;
  final String? errorMessage;

  bool get hasPendingMessages {
    final latestUser = messages
        .where((message) => message.sender == ChatSender.user)
        .lastOrNull;
    if (latestUser == null) return false;

    final latestReply = messages
        .where(
          (message) =>
              message.sender == ChatSender.character &&
              message.kind == ChatMessageKind.conversation,
        )
        .lastOrNull;
    return latestReply == null ||
        latestUser.createdAt.isAfter(latestReply.createdAt);
  }

  ChatState copyWith({
    List<ChatMessage>? messages,
    FoundationModelAvailability? availability,
    bool? isCheckingAvailability,
    bool? isGenerating,
    int? secondsUntilReply,
    bool clearCountdown = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatState(
      characterId: characterId,
      messages: messages ?? this.messages,
      availability: availability ?? this.availability,
      isCheckingAvailability:
          isCheckingAvailability ?? this.isCheckingAvailability,
      isGenerating: isGenerating ?? this.isGenerating,
      secondsUntilReply: clearCountdown
          ? null
          : (secondsUntilReply ?? this.secondsUntilReply),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ChatController extends Notifier<ChatState> {
  Timer? _replyTimer;
  Timer? _countdownTimer;
  Timer? _nudgeTimer;
  Timer? _deferredBriefingTimer;
  late ChatRepository _repository;
  late FoundationModelService _modelService;
  late NotificationService _notifications;
  PendingChatNudge? _pendingNudge;
  List<DeferredChatBriefing> _deferredBriefings = const [];
  Set<String> _suppressedBriefingIds = <String>{};
  bool _isBackgrounded = false;

  @override
  ChatState build() {
    final characterId = ref.watch(selectedCharacterProvider);
    _repository = ChatRepository(ref.read(sharedPreferencesProvider));
    _modelService = ref.read(foundationModelServiceProvider);
    _notifications = ref.read(notificationServiceProvider);
    _deferredBriefings = _repository.loadDeferredBriefings(characterId);
    _suppressedBriefingIds = _repository.loadSuppressedBriefingIds(characterId);
    ref.onDispose(() {
      _cancelTimers();
      _deferredBriefingTimer?.cancel();
      unawaited(_notifications.cancel(_chatNudgeNotificationId));
    });

    final messages = _repository.load(characterId);
    ref.listen<AsyncValue<Map<int, Briefing>>>(todayBriefingsProvider, (
      previous,
      next,
    ) {
      next.whenData(
        (briefings) => Future<void>.microtask(() => _syncBriefings(briefings)),
      );
    }, fireImmediately: true);
    Future<void>.microtask(_refreshAvailability);
    Future<void>.microtask(_restorePendingNudge);
    Future<void>.microtask(_restoreDeferredBriefings);
    return ChatState(characterId: characterId, messages: messages);
  }

  Future<void> send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || state.isGenerating) return;

    await _cancelPendingNudge();
    final now = DateTime.now();
    final message = ChatMessage(
      id: '${now.microsecondsSinceEpoch}-user',
      sender: ChatSender.user,
      text: text,
      createdAt: now,
    );
    final messages = [...state.messages, message];
    state = state.copyWith(
      messages: messages,
      secondsUntilReply: chatReplyDelaySeconds > 0
          ? chatReplyDelaySeconds
          : null,
      clearCountdown: chatReplyDelaySeconds <= 0,
      clearError: true,
    );
    await _repository.save(state.characterId, messages);
    await _rescheduleDeferredBriefings(now);
    _scheduleReply();
  }

  Future<void> generateNow() => _generateReply();

  Future<void> onAppLeavingForeground() async {
    _isBackgrounded = true;
    if (state.hasPendingMessages && !state.isGenerating) {
      await _generateReply();
      return;
    }
    await _schedulePendingNudgeNotification();
  }

  Future<void> onAppResumed() async {
    _isBackgrounded = false;
    await _notifications.cancel(_chatNudgeNotificationId);
    await _restorePendingNudge();
    await _restoreDeferredBriefings();
  }

  Future<void> retry() => _generateReply();

  Future<void> clearConversation() async {
    _cancelTimers();
    _deferredBriefingTimer?.cancel();
    await _cancelPendingNudge();
    _deferredBriefings = const [];
    _suppressedBriefingIds = <String>{};
    await _repository.saveDeferredBriefings(state.characterId, const []);
    await _repository.saveSuppressedBriefingIds(
      state.characterId,
      _suppressedBriefingIds,
    );
    await _repository.clear(state.characterId);
    state = ChatState(
      characterId: state.characterId,
      messages: const [],
      availability: state.availability,
      isCheckingAvailability: false,
    );
  }

  Future<void> _refreshAvailability() async {
    final availability = await _modelService.checkAvailability();
    if (!ref.mounted) return;

    state = state.copyWith(
      availability: availability,
      isCheckingAvailability: false,
    );
    if (availability.isAvailable && state.hasPendingMessages) {
      _scheduleReply(initialSeconds: chatReplyDelaySeconds);
    }
  }

  Future<void> _syncBriefings(Map<int, Briefing> briefings) async {
    if (!ref.mounted || briefings.isEmpty) return;

    final characterId = state.characterId;
    final lastSync = _repository.loadLastBriefingSync(characterId);
    final existingIds = state.messages.map((message) => message.id).toSet();
    final deferredIds = _deferredBriefings
        .map((briefing) => briefing.message.id)
        .toSet();
    final cutoff = currentHourKst() < kstCycleStartHour ? 24 : currentHourKst();
    final incoming =
        briefings.values.where((briefing) => briefing.hour <= cutoff).where((
          briefing,
        ) {
          final id = _briefingMessageId(briefing);
          return !existingIds.contains(id) &&
              !deferredIds.contains(id) &&
              !_suppressedBriefingIds.contains(id);
        }).toList()..sort((a, b) => a.hour.compareTo(b.hour));

    var messages = [...state.messages]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final addedMessages = <ChatMessage>[];
    var addedAttention = false;
    var deferredChanged = false;
    var suppressedChanged = false;
    final now = DateTime.now();

    for (final briefing in incoming) {
      final message = _chatMessageFromBriefing(briefing);
      final isNewSinceLastSync =
          lastSync != null && message.createdAt.isAfter(lastSync);
      final delivery = isNewSinceLastSync
          ? decideBriefingDelivery(
              briefing: briefing,
              messages: messages,
              now: now,
            )
          : BriefingDelivery.deliverNow;

      if (delivery == BriefingDelivery.skip) {
        _suppressedBriefingIds.add(message.id);
        suppressedChanged = true;
        continue;
      }
      if (delivery == BriefingDelivery.defer) {
        final lastActivity = latestConversationActivity(messages) ?? now;
        _deferredBriefings = [
          ..._deferredBriefings,
          DeferredChatBriefing(
            message: message,
            dueAt: lastActivity.add(activeConversationWindow),
          ),
        ];
        deferredChanged = true;
        continue;
      }

      final shouldNudge =
          isNewSinceLastSync && _shouldAddAttentionPrefix(messages, message);
      final shouldTransition =
          delivery == BriefingDelivery.deliverWithTransition;
      final delivered = ChatMessage(
        id: message.id,
        sender: message.sender,
        text:
            '${_briefingPrefix(characterId, isImportant: shouldTransition, afterSilence: shouldNudge, delayed: false)}${message.text}',
        createdAt: shouldTransition ? now : message.createdAt,
        kind: message.kind,
        audioUrl: message.audioUrl,
        isAttentionNudge: shouldNudge,
      );
      messages.add(delivered);
      addedMessages.add(delivered);
      addedAttention = addedAttention || shouldNudge;
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    if (addedMessages.isNotEmpty) {
      state = state.copyWith(messages: messages);
      await _repository.save(characterId, messages);
      if (addedAttention) await _cancelPendingNudge();

      final latestIncoming = addedMessages.last;
      if (lastSync != null &&
          _pendingNudge == null &&
          _canStartNudgeSequence(messages, latestIncoming)) {
        await _scheduleNudgeAfter(latestIncoming);
      }
    }
    if (deferredChanged) {
      await _repository.saveDeferredBriefings(characterId, _deferredBriefings);
      _armDeferredBriefingTimer();
    }
    if (suppressedChanged) {
      await _repository.saveSuppressedBriefingIds(
        characterId,
        _suppressedBriefingIds,
      );
    }
    await _repository.saveLastBriefingSync(characterId, DateTime.now());
  }

  String _briefingMessageId(Briefing briefing) =>
      'briefing_${briefing.date}_${briefing.hour}_${briefing.characterId}';

  ChatMessage _chatMessageFromBriefing(Briefing briefing) {
    final date = DateTime.tryParse(briefing.date) ?? DateTime.now();
    return ChatMessage(
      id: _briefingMessageId(briefing),
      sender: ChatSender.character,
      text: briefing.transcript,
      createdAt: DateTime(date.year, date.month, date.day, briefing.hour),
      kind: ChatMessageKind.briefing,
      audioUrl: briefing.audioUrl,
    );
  }

  bool _shouldAddAttentionPrefix(
    List<ChatMessage> messages,
    ChatMessage incoming,
  ) {
    final lastUserIndex = messages.lastIndexWhere(
      (message) => message.sender == ChatSender.user,
    );
    if (lastUserIndex < 0) return false;

    final afterUser = messages.sublist(lastUserIndex + 1);
    final latestInvitation = afterUser
        .where(
          (message) =>
              message.sender == ChatSender.character &&
              messageInvitesReply(message.text),
        )
        .lastOrNull;
    if (latestInvitation == null ||
        incoming.createdAt.difference(latestInvitation.createdAt) <
            _chatNudgeDelay) {
      return false;
    }

    final latestAttention = afterUser
        .where((message) => message.isAttentionNudge)
        .lastOrNull;
    return latestAttention == null ||
        incoming.createdAt.difference(latestAttention.createdAt) >=
            _attentionPrefixCooldown;
  }

  bool _canStartNudgeSequence(List<ChatMessage> messages, ChatMessage trigger) {
    if (!messageInvitesReply(trigger.text)) return false;

    final lastUserIndex = messages.lastIndexWhere(
      (message) => message.sender == ChatSender.user,
    );
    if (lastUserIndex < 0) return false;
    final lastUser = messages[lastUserIndex];
    if (!trigger.createdAt.isAfter(lastUser.createdAt)) return false;
    return !messages
        .sublist(lastUserIndex + 1)
        .any((message) => message.isAttentionNudge);
  }

  void _scheduleReply({int initialSeconds = chatReplyDelaySeconds}) {
    if (state.availability?.isAvailable != true) return;

    _cancelTimers();
    if (initialSeconds <= 0) {
      state = state.copyWith(clearCountdown: true);
      Future<void>.microtask(_generateReply);
      return;
    }

    state = state.copyWith(secondsUntilReply: initialSeconds);
    _replyTimer = Timer(Duration(seconds: initialSeconds), _generateReply);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!ref.mounted) {
        timer.cancel();
        return;
      }
      final remaining = state.secondsUntilReply;
      if (remaining == null || remaining <= 1) {
        timer.cancel();
        state = state.copyWith(clearCountdown: true);
        return;
      }
      state = state.copyWith(secondsUntilReply: remaining - 1);
    });
  }

  Future<void> _generateReply() async {
    if (state.isGenerating ||
        !state.hasPendingMessages ||
        state.availability?.isAvailable != true) {
      return;
    }

    _cancelTimers();
    final latestReply = state.messages
        .where(
          (message) =>
              message.sender == ChatSender.character &&
              message.kind == ChatMessageKind.conversation,
        )
        .lastOrNull;
    final currentMessages = state.messages
        .where(
          (message) =>
              message.sender == ChatSender.user &&
              (latestReply == null ||
                  message.createdAt.isAfter(latestReply.createdAt)),
        )
        .toList(growable: false);
    if (currentMessages.isEmpty) return;

    final firstCurrentAt = currentMessages.first.createdAt;
    final history = state.messages
        .where((message) => message.createdAt.isBefore(firstCurrentAt))
        .toList(growable: false);
    final characterId = state.characterId;
    state = state.copyWith(
      isGenerating: true,
      clearCountdown: true,
      clearError: true,
    );

    try {
      final reply = await _modelService.generateReply(
        characterId: characterId,
        history: history,
        currentMessages: currentMessages,
      );
      if (!ref.mounted) return;
      if (state.characterId != characterId) return;

      final now = DateTime.now();
      final message = ChatMessage(
        id: '${now.microsecondsSinceEpoch}-character',
        sender: ChatSender.character,
        text: reply,
        createdAt: now,
      );
      final messages = [...state.messages, message]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(messages: messages, isGenerating: false);
      await _repository.save(characterId, messages);
      await _scheduleNudgeAfter(message);
    } on PlatformException catch (error) {
      debugPrint(
        '[Chat] Foundation Models error: '
        '${error.code} ${error.message ?? ''} ${error.details ?? ''}',
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        isGenerating: false,
        errorMessage: _friendlyError(error.code),
      );
    } catch (error, stackTrace) {
      debugPrint('[Chat] Reply generation failed: $error\n$stackTrace');
      if (!ref.mounted) return;
      state = state.copyWith(
        isGenerating: false,
        errorMessage: '답장을 만들지 못했어. 잠시 뒤 다시 해볼게.',
      );
    }
  }

  void _cancelTimers() {
    _replyTimer?.cancel();
    _countdownTimer?.cancel();
    _nudgeTimer?.cancel();
    _replyTimer = null;
    _countdownTimer = null;
    _nudgeTimer = null;
  }

  Future<void> _scheduleNudgeAfter(ChatMessage message) async {
    if (!messageInvitesReply(message.text)) return;

    _nudgeTimer?.cancel();
    final nudge = PendingChatNudge(
      messageId: message.id,
      dueAt: DateTime.now().add(_chatNudgeDelay),
    );
    _pendingNudge = nudge;
    await _repository.savePendingNudge(state.characterId, nudge);
    _armNudgeTimer(nudge);
    if (_isBackgrounded) await _schedulePendingNudgeNotification();
  }

  Future<void> _restorePendingNudge() async {
    if (!ref.mounted) return;
    final nudge =
        _pendingNudge ?? _repository.loadPendingNudge(state.characterId);
    if (nudge == null) return;
    _pendingNudge = nudge;

    if (!_canSendNudge(nudge)) {
      await _cancelPendingNudge();
      return;
    }
    if (!nudge.dueAt.isAfter(DateTime.now())) {
      await _appendNudge(nudge);
      return;
    }
    _armNudgeTimer(nudge);
  }

  void _armNudgeTimer(PendingChatNudge nudge) {
    _nudgeTimer?.cancel();
    final delay = nudge.dueAt.difference(DateTime.now());
    if (delay <= Duration.zero) {
      Future<void>.microtask(() => _appendNudge(nudge));
      return;
    }
    _nudgeTimer = Timer(delay, () => _appendNudge(nudge));
  }

  bool _canSendNudge(PendingChatNudge nudge) {
    final trigger = state.messages
        .where((message) => message.id == nudge.messageId)
        .firstOrNull;
    if (trigger == null) return false;
    return !state.messages.any(
      (message) =>
          message.sender == ChatSender.user &&
          message.createdAt.isAfter(trigger.createdAt),
    );
  }

  Future<void> _appendNudge(PendingChatNudge nudge) async {
    if (!ref.mounted || !_canSendNudge(nudge)) {
      await _cancelPendingNudge();
      return;
    }
    final id = 'nudge_${nudge.messageId}';
    if (state.messages.any((message) => message.id == id)) {
      await _cancelPendingNudge();
      return;
    }

    final message = ChatMessage(
      id: id,
      sender: ChatSender.character,
      text: _unansweredFollowUp(state.characterId, nudge.messageId),
      createdAt: DateTime.now(),
      kind: ChatMessageKind.nudge,
      isAttentionNudge: true,
    );
    final messages = [...state.messages, message]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = state.copyWith(messages: messages);
    await _repository.save(state.characterId, messages);
    await _cancelPendingNudge();
  }

  Future<void> _schedulePendingNudgeNotification() async {
    final nudge = _pendingNudge;
    if (nudge == null ||
        !_canSendNudge(nudge) ||
        !nudge.dueAt.isAfter(DateTime.now())) {
      return;
    }
    await _notifications.scheduleOneShot(
      id: _chatNudgeNotificationId,
      title: Character.byId(state.characterId).displayName,
      body: _unansweredFollowUp(state.characterId, nudge.messageId),
      scheduledAt: nudge.dueAt,
    );
  }

  Future<void> _cancelPendingNudge() async {
    _nudgeTimer?.cancel();
    _nudgeTimer = null;
    _pendingNudge = null;
    await _repository.clearPendingNudge(state.characterId);
    await _notifications.cancel(_chatNudgeNotificationId);
  }

  int get _chatNudgeNotificationId =>
      _chatNudgeNotificationBaseId + state.characterId.index;

  Future<void> _rescheduleDeferredBriefings(DateTime lastActivity) async {
    if (_deferredBriefings.isEmpty) return;
    _deferredBriefings = [
      for (final briefing in _deferredBriefings)
        DeferredChatBriefing(
          message: briefing.message,
          dueAt: lastActivity.add(activeConversationWindow),
        ),
    ];
    await _repository.saveDeferredBriefings(
      state.characterId,
      _deferredBriefings,
    );
    _armDeferredBriefingTimer();
  }

  Future<void> _restoreDeferredBriefings() async {
    if (!ref.mounted) return;
    if (_deferredBriefings.isEmpty) {
      _deferredBriefings = _repository.loadDeferredBriefings(state.characterId);
    }
    if (_deferredBriefings.isEmpty) return;

    final now = DateTime.now();
    final lastActivity = latestConversationActivity(state.messages);
    final activeUntil = lastActivity?.add(activeConversationWindow);
    final due = <DeferredChatBriefing>[];
    final waiting = <DeferredChatBriefing>[];

    for (final briefing in _deferredBriefings) {
      if (activeUntil != null && activeUntil.isAfter(now)) {
        waiting.add(
          DeferredChatBriefing(message: briefing.message, dueAt: activeUntil),
        );
      } else if (!briefing.dueAt.isAfter(now)) {
        due.add(briefing);
      } else {
        waiting.add(briefing);
      }
    }

    _deferredBriefings = waiting;
    if (due.isNotEmpty) {
      final existingIds = state.messages.map((message) => message.id).toSet();
      final delivered = due
          .where((briefing) => !existingIds.contains(briefing.message.id))
          .map((briefing) {
            final message = briefing.message;
            return ChatMessage(
              id: message.id,
              sender: message.sender,
              text:
                  '${_briefingPrefix(state.characterId, isImportant: false, afterSilence: false, delayed: true)}${message.text}',
              createdAt: DateTime.now(),
              kind: message.kind,
              audioUrl: message.audioUrl,
            );
          })
          .toList();
      if (delivered.isNotEmpty) {
        final messages = [...state.messages, ...delivered]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        state = state.copyWith(messages: messages);
        await _repository.save(state.characterId, messages);
      }
    }

    await _repository.saveDeferredBriefings(
      state.characterId,
      _deferredBriefings,
    );
    _armDeferredBriefingTimer();
  }

  void _armDeferredBriefingTimer() {
    _deferredBriefingTimer?.cancel();
    if (_deferredBriefings.isEmpty) return;

    final next = _deferredBriefings
        .map((briefing) => briefing.dueAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final delay = next.difference(DateTime.now());
    _deferredBriefingTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => _restoreDeferredBriefings(),
    );
  }

  String _friendlyError(String code) => switch (code) {
    'rate_limited' || 'concurrent_requests' => '지금 잠깐 생각이 꼬였어. 다시 해볼게.',
    'context_too_large' => '대화가 길어져서 잠깐 정리가 필요해.',
    'guardrail_violation' || 'refusal' => '그 얘기에는 조심스럽게 답해야 할 것 같아.',
    'model_unavailable' => '지금은 기기 안의 대화 모델을 사용할 수 없어.',
    'model_service_failed' =>
      'Apple Intelligence 모델이 응답하지 않아. Mac을 재시동한 뒤 다시 시도해줘.',
    'unsupported_language' => '현재 설정된 언어로는 아직 답장을 만들 수 없어.',
    'generation_failed' => '기기 안의 대화 모델이 응답을 마치지 못했어. 다시 시도해줘.',
    _ => '답장을 만들지 못했어. 잠시 뒤 다시 해볼게.',
  };
}

String _unansweredFollowUp(CharacterId characterId, String seed) {
  final variants = switch (characterId) {
    CharacterId.jiyoung => const [
      '또 답이 없네. 바쁜 거야? 나중에라도 한마디 해줘.',
      '나 또 혼자 말한 거야? 시간 나면 답해줘.',
      '조용하네. 바쁜 건 알겠는데, 나중에 답은 해줘.',
    ],
    CharacterId.sohee => const [
      '아직 답변을 기다리고 있습니다. 편하실 때 말씀해 주세요.',
      '잠시 자리를 비우신 것 같습니다. 돌아오시면 이어서 말씀해 주세요.',
      '답변은 천천히 주셔도 괜찮습니다. 기다리고 있겠습니다.',
    ],
    CharacterId.jihoon => const [
      '아가씨, 잠시 자리를 비우셨군요. 편해지시면 말씀해 주십시오.',
      '아가씨, 바쁜 일이 있으신 듯합니다. 돌아오시면 이어서 말씀하시지요.',
      '아가씨, 답변은 서두르지 않으셔도 됩니다. 이곳에서 기다리겠습니다.',
    ],
    CharacterId.siwon => const [
      '또 무시하네. 이제 무시하지 말아줘!',
      '나 또 혼자 얘기한 거야? 이번엔 답해줘.',
      '또 조용하네. 바빠도 나중엔 답해줘!',
    ],
  };
  final index = seed.codeUnits.fold<int>(0, (sum, value) => sum + value);
  return variants[index % variants.length];
}

String _briefingPrefix(
  CharacterId characterId, {
  required bool isImportant,
  required bool afterSilence,
  required bool delayed,
}) {
  if (delayed) {
    return switch (characterId) {
      CharacterId.jiyoung => '아까 말하려다 대화 끊을까 봐 기다렸는데, ',
      CharacterId.sohee => '앞서 전해드리려던 내용입니다. ',
      CharacterId.jihoon => '대화를 방해하지 않으려 잠시 기다렸습니다. ',
      CharacterId.siwon => '아까 말하려다 기다렸어. ',
    };
  }

  if (afterSilence && isImportant) {
    return switch (characterId) {
      CharacterId.jiyoung => '또 답이 없네. 그래도 이건 꼭 말해줘야겠다. ',
      CharacterId.sohee => '답변 전 꼭 확인하실 내용부터 전해드립니다. ',
      CharacterId.jihoon => '아직 답을 듣지 못했지만, 이것만은 챙기셔야 합니다. ',
      CharacterId.siwon => '또 무시하네. 그래도 이건 말해줘야 해! ',
    };
  }

  if (isImportant) {
    return switch (characterId) {
      CharacterId.jiyoung => '아 맞다, 이건 꼭 말해줘야겠다. ',
      CharacterId.sohee => '중요한 내용부터 전해드리겠습니다. ',
      CharacterId.jihoon => '말씀 중 죄송하지만, 이것만은 꼭 챙기셔야 합니다. ',
      CharacterId.siwon => '아 맞다, 이건 말해줘야 해! ',
    };
  }

  if (afterSilence) {
    return switch (characterId) {
      CharacterId.jiyoung => '또 답이 없네. 바쁜가 봐. ',
      CharacterId.sohee => '잠시 자리를 비우신 것 같습니다. ',
      CharacterId.jihoon => '잠시 자리를 비우신 듯합니다. ',
      CharacterId.siwon => '또 무시하네. 이번엔 답해줘. ',
    };
  }

  return '';
}

final foundationModelServiceProvider = Provider<FoundationModelService>(
  (ref) => FoundationModelService(),
);

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);
