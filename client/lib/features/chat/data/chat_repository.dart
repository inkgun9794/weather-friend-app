import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/features/character/domain/character.dart';
import 'package:weather_friend/features/chat/domain/chat_message.dart';

class ChatRepository {
  ChatRepository(this._prefs);

  static const _maxStoredMessages = 100;
  static const _keyPrefix = 'character_chat_v1_';
  static const _briefingSyncPrefix = 'character_chat_briefing_sync_v1_';
  static const _nudgePrefix = 'character_chat_nudge_v1_';
  static const _deferredBriefingsPrefix =
      'character_chat_deferred_briefings_v1_';
  static const _suppressedBriefingsPrefix =
      'character_chat_suppressed_briefings_v1_';

  final SharedPreferences _prefs;

  List<ChatMessage> load(CharacterId characterId) {
    final raw = _prefs.getString('$_keyPrefix${characterId.name}');
    if (raw == null) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(ChatMessage.fromJson)
          .whereType<ChatMessage>()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<void> save(CharacterId characterId, List<ChatMessage> messages) async {
    final retained = messages.length > _maxStoredMessages
        ? messages.sublist(messages.length - _maxStoredMessages)
        : messages;
    await _prefs.setString(
      '$_keyPrefix${characterId.name}',
      jsonEncode(retained.map((message) => message.toJson()).toList()),
    );
  }

  Future<void> clear(CharacterId characterId) =>
      _prefs.remove('$_keyPrefix${characterId.name}');

  DateTime? loadLastBriefingSync(CharacterId characterId) {
    final raw = _prefs.getString('$_briefingSyncPrefix${characterId.name}');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveLastBriefingSync(CharacterId characterId, DateTime value) =>
      _prefs.setString(
        '$_briefingSyncPrefix${characterId.name}',
        value.toIso8601String(),
      );

  PendingChatNudge? loadPendingNudge(CharacterId characterId) {
    final raw = _prefs.getString('$_nudgePrefix${characterId.name}');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final messageId = decoded['messageId'];
      final dueAt = decoded['dueAt'];
      if (messageId is! String || dueAt is! String) return null;
      final timestamp = DateTime.tryParse(dueAt);
      if (timestamp == null) return null;
      return PendingChatNudge(messageId: messageId, dueAt: timestamp);
    } on FormatException {
      return null;
    }
  }

  Future<void> savePendingNudge(
    CharacterId characterId,
    PendingChatNudge nudge,
  ) => _prefs.setString(
    '$_nudgePrefix${characterId.name}',
    jsonEncode({
      'messageId': nudge.messageId,
      'dueAt': nudge.dueAt.toIso8601String(),
    }),
  );

  Future<void> clearPendingNudge(CharacterId characterId) =>
      _prefs.remove('$_nudgePrefix${characterId.name}');

  List<DeferredChatBriefing> loadDeferredBriefings(CharacterId characterId) {
    final raw = _prefs.getString(
      '$_deferredBriefingsPrefix${characterId.name}',
    );
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(DeferredChatBriefing.fromJson)
          .whereType<DeferredChatBriefing>()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<void> saveDeferredBriefings(
    CharacterId characterId,
    List<DeferredChatBriefing> briefings,
  ) async {
    final key = '$_deferredBriefingsPrefix${characterId.name}';
    if (briefings.isEmpty) {
      await _prefs.remove(key);
      return;
    }
    await _prefs.setString(
      key,
      jsonEncode(briefings.map((briefing) => briefing.toJson()).toList()),
    );
  }

  Set<String> loadSuppressedBriefingIds(CharacterId characterId) {
    final values = _prefs.getStringList(
      '$_suppressedBriefingsPrefix${characterId.name}',
    );
    return values?.toSet() ?? <String>{};
  }

  Future<void> saveSuppressedBriefingIds(
    CharacterId characterId,
    Set<String> ids,
  ) {
    final retained = ids.length > 50
        ? ids.skip(ids.length - 50).toList(growable: false)
        : ids.toList(growable: false);
    return _prefs.setStringList(
      '$_suppressedBriefingsPrefix${characterId.name}',
      retained,
    );
  }
}

class PendingChatNudge {
  const PendingChatNudge({required this.messageId, required this.dueAt});

  final String messageId;
  final DateTime dueAt;
}

class DeferredChatBriefing {
  const DeferredChatBriefing({required this.message, required this.dueAt});

  final ChatMessage message;
  final DateTime dueAt;

  Map<String, Object?> toJson() => {
    'message': message.toJson(),
    'dueAt': dueAt.toIso8601String(),
  };

  static DeferredChatBriefing? fromJson(Object? value) {
    if (value is! Map) return null;
    final message = ChatMessage.fromJson(value['message']);
    final dueAt = value['dueAt'];
    if (message == null || dueAt is! String) return null;
    final timestamp = DateTime.tryParse(dueAt);
    if (timestamp == null) return null;
    return DeferredChatBriefing(message: message, dueAt: timestamp);
  }
}
