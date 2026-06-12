import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunar/lunar.dart' as lunar_pkg;
import 'package:saju/saju.dart' as saju;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// 프로필 관계 — 결과 화면/리포트에서 한눈에 누구 사주인지 구분용.
enum SajuRelation {
  self('본인'),
  family('가족'),
  friend('친구'),
  partner('연인'),
  other('기타');

  const SajuRelation(this.label);
  final String label;
}

/// 사용자가 입력한 생년월일시 + 성별 + 라벨(이름/관계).
/// 본인 프로필은 SharedPreferences에 영구 저장. 다른 사람 프로필은 FortuneReport에 당일만 저장.
class SajuProfile {
  const SajuProfile({
    required this.name,
    required this.relation,
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.isLunar,
    required this.gender,
    this.timeUnknown = false,
  });

  final String name;            // "나", "엄마", "철수" 등
  final SajuRelation relation;  // 본인/가족/친구/연인/기타
  final int year;
  final int month;
  final int day;
  final int hour;    // 0~23 (KST 출생시간)
  final int minute;  // 0~59 (출생 분)
  final bool isLunar;
  final SajuGender gender;

  /// 출생 시간 모름 — true면 hour/minute은 계산용 placeholder(12:00).
  /// 시주는 결과 카드에서 가리고, LLM에도 '모름'으로 전달한다.
  final bool timeUnknown;

  Map<String, dynamic> toJson() => {
        'name': name,
        'relation': relation.name,
        'year': year,
        'month': month,
        'day': day,
        'hour': hour,
        'minute': minute,
        'isLunar': isLunar,
        'gender': gender.name,
        'timeUnknown': timeUnknown,
      };

  /// 기존 데이터 호환 — name/relation 없으면 default ('나' / 본인). minute 없으면 0.
  factory SajuProfile.fromJson(Map<String, dynamic> json) => SajuProfile(
        name: json['name'] as String? ?? '나',
        relation: SajuRelation.values.firstWhere(
          (r) => r.name == json['relation'],
          orElse: () => SajuRelation.self,
        ),
        year: json['year'] as int,
        month: json['month'] as int,
        day: json['day'] as int,
        hour: json['hour'] as int,
        minute: (json['minute'] as int?) ?? 0,
        isLunar: json['isLunar'] as bool,
        gender: SajuGender.values.firstWhere(
          (g) => g.name == json['gender'],
          orElse: () => SajuGender.male,
        ),
        timeUnknown: json['timeUnknown'] as bool? ?? false,
      );

  SajuProfile copyWith({
    String? name,
    SajuRelation? relation,
    int? year, int? month, int? day, int? hour, int? minute,
    bool? isLunar,
    SajuGender? gender,
    bool? timeUnknown,
  }) =>
      SajuProfile(
        name: name ?? this.name,
        relation: relation ?? this.relation,
        year: year ?? this.year,
        month: month ?? this.month,
        day: day ?? this.day,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        isLunar: isLunar ?? this.isLunar,
        gender: gender ?? this.gender,
        timeUnknown: timeUnknown ?? this.timeUnknown,
      );

  /// 캐시 키 — 같은 사주 = 같은 키 (라벨은 제외).
  /// 명리학적으로 같은 사주는 같은 운세라서, 같은 키면 캐시 공유 정당.
  /// minute 포함 (시 경계에 가까운 분이면 시주 달라질 수 있음).
  /// 시간 모름이면 시각 자리를 'UNKN'으로 — 12:00 입력 프로필과 캐시가 섞이지 않게.
  String get cacheKey {
    final cal = isLunar ? 'L' : 'S';
    final time = timeUnknown
        ? 'UNKN'
        : '${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}';
    return '$cal${year.toString().padLeft(4, '0')}'
        '${month.toString().padLeft(2, '0')}'
        '${day.toString().padLeft(2, '0')}'
        '$time'
        '_${gender.name}';
  }

  /// 결과/리포트 화면 공용 한 줄 요약.
  /// 예: "양력 1990.01.15 07:30 · 남성" / 시간 모름이면 "양력 1990.01.15 시간모름 · 남성"
  String get birthSummary {
    final cal = isLunar ? '음력' : '양력';
    final time = timeUnknown
        ? '시간모름'
        : '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return '$cal $year.${month.toString().padLeft(2, '0')}.'
        '${day.toString().padLeft(2, '0')} $time · ${gender.label}';
  }
}

enum SajuGender { male, female }

extension SajuGenderLabel on SajuGender {
  String get label => this == SajuGender.male ? '남성' : '여성';
}

/// "내 프로필" 1건만 SharedPreferences에 영구 저장.
/// 다른 사람 프로필은 FortuneReport repository가 따로 관리.
class SajuProfileRepository {
  SajuProfileRepository(this._prefs);

  static const _key = 'saju_profile_v1';

  final SharedPreferences _prefs;

  SajuProfile? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return SajuProfile.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SajuProfile profile) async {
    await _prefs.setString(_key, json.encode(profile.toJson()));
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final sajuProfileRepositoryProvider =
    FutureProvider<SajuProfileRepository>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SajuProfileRepository(prefs);
});

/// 현재 저장된 "내 프로필" — 없으면 입력 form 표시.
class SajuProfileNotifier extends Notifier<SajuProfile?> {
  @override
  SajuProfile? build() => null;

  void set(SajuProfile? profile) {
    state = profile;
  }
}

final sajuProfileProvider =
    NotifierProvider<SajuProfileNotifier, SajuProfile?>(SajuProfileNotifier.new);

/// 사주 프로필 → 만세력 결과. profile 명시적으로 받아서 가족/친구 사주도 계산 가능.
saju.SajuResult? computeSajuFor(SajuProfile profile) {
  try {
    int y = profile.year, m = profile.month, d = profile.day;
    if (profile.isLunar) {
      final l = lunar_pkg.Lunar.fromYmd(y, m, d);
      final s = l.getSolar();
      y = s.getYear();
      m = s.getMonth();
      d = s.getDay();
    }

    final loc = tz.getLocation('Asia/Seoul');
    // 시간 모름이면 정오(12:00)로 계산 — 시주는 카드에서 가리고 프롬프트에도 '모름'으로 보낸다.
    final hour = profile.timeUnknown ? 12 : profile.hour;
    final minute = profile.timeUnknown ? 0 : profile.minute;
    final birth = tz.TZDateTime(loc, y, m, d, hour, minute);

    return saju.getSaju(
      birth,
      gender: profile.gender == SajuGender.male
          ? saju.Gender.male
          : saju.Gender.female,
    );
  } catch (e) {
    // ignore: avoid_print
    print('saju 계산 실패: $e');
    return null;
  }
}

/// "내 프로필"의 사주 계산 (기존 호환용).
final sajuComputationProvider = Provider<saju.SajuResult?>((ref) {
  final profile = ref.watch(sajuProfileProvider);
  if (profile == null) return null;
  return computeSajuFor(profile);
});
