import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';

const _kDefaultTitle = '오늘의 기록';

/// 서버(Gemini) 미수신/오프라인 시 쓰는 내장 문구 풀.
const _kDefaultMessages = <String>[
  '오늘 당신의 날씨 기분은 어땠나요? 지금 기록해보세요.',
  '하루가 저물기 전에, 오늘의 하늘을 남겨볼까요?',
  '오늘 마음의 날씨를 한 컷으로 기록해보세요.',
  '아직 오늘의 기록이 비어 있어요. 잠깐 들러볼까요?',
  '오늘은 어떤 하늘이었나요? 기분과 함께 남겨봐요.',
  '하루 한 장, 오늘의 기분 날씨를 기록할 시간이에요.',
  '오늘의 잔디, 아직 안 심었어요 🌱 지금 채워볼까요?',
];

/// 리마인더 알림에 쓸 제목 + 문구 풀.
class ReminderContent {
  const ReminderContent({required this.title, required this.messages});

  final String title;
  final List<String> messages;

  static const fallback = ReminderContent(
    title: _kDefaultTitle,
    messages: _kDefaultMessages,
  );

  /// 날짜별로 안정적으로 다른 문구를 고른다(같은 날엔 항상 같은 문구).
  String messageFor(DateTime date) {
    final pool = messages.isNotEmpty ? messages : _kDefaultMessages;
    final dayIndex = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(2020)).inDays;
    return pool[dayIndex % pool.length];
  }

  Map<String, dynamic> toJson() => {'title': title, 'messages': messages};

  factory ReminderContent.fromJson(Map<String, dynamic> j) {
    final rawTitle = (j['title'] as String?)?.trim();
    final messages =
        (j['messages'] as List?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];
    return ReminderContent(
      title: (rawTitle == null || rawTitle.isEmpty) ? _kDefaultTitle : rawTitle,
      messages: messages,
    );
  }
}

/// 리마인더 문구 공급 — Firestore 최신본 → prefs 캐시 → 내장 기본 순으로 회복.
///
/// 서버(worker)가 `record_reminder/daily` 문서에 매일 1회 Gemini로 생성해 둔다.
class ReminderRepository {
  ReminderRepository(this._db, this._prefs);

  static const _cacheKey = 'reminder_content_v1';

  final FirebaseFirestore _db;
  final SharedPreferences _prefs;

  Future<ReminderContent> load() async {
    // 1) Firestore 최신본 시도 (성공 시 캐시 갱신).
    try {
      final snap = await _db
          .collection('record_reminder')
          .doc('daily')
          .get()
          .timeout(const Duration(seconds: 5));
      final data = snap.data();
      if (data != null) {
        final content = ReminderContent.fromJson(data);
        if (content.messages.isNotEmpty) {
          await _prefs.setString(_cacheKey, json.encode(content.toJson()));
          return content;
        }
      }
    } catch (_) {
      // 네트워크/권한 실패 — 캐시/기본으로 폴백.
    }

    // 2) 마지막으로 받아둔 캐시.
    final cached = _prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        final content = ReminderContent.fromJson(
          json.decode(cached) as Map<String, dynamic>,
        );
        if (content.messages.isNotEmpty) return content;
      } catch (_) {
        // 손상된 캐시 — 무시하고 기본으로.
      }
    }

    // 3) 내장 기본 풀.
    return ReminderContent.fallback;
  }
}

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(
    FirebaseFirestore.instance,
    ref.watch(sharedPreferencesProvider),
  );
});
