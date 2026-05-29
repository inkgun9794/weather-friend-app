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
    required this.isLunar,
    required this.gender,
  });

  final String name;            // "나", "엄마", "철수" 등
  final SajuRelation relation;  // 본인/가족/친구/연인/기타
  final int year;
  final int month;
  final int day;
  final int hour;   // 0~23 (KST 출생시간)
  final bool isLunar;
  final SajuGender gender;

  Map<String, dynamic> toJson() => {
        'name': name,
        'relation': relation.name,
        'year': year,
        'month': month,
        'day': day,
        'hour': hour,
        'isLunar': isLunar,
        'gender': gender.name,
      };

  /// 기존 데이터 호환 — name/relation 없으면 default ('나' / 본인).
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
        isLunar: json['isLunar'] as bool,
        gender: SajuGender.values.firstWhere(
          (g) => g.name == json['gender'],
          orElse: () => SajuGender.male,
        ),
      );

  SajuProfile copyWith({
    String? name,
    SajuRelation? relation,
    int? year, int? month, int? day, int? hour,
    bool? isLunar,
    SajuGender? gender,
  }) =>
      SajuProfile(
        name: name ?? this.name,
        relation: relation ?? this.relation,
        year: year ?? this.year,
        month: month ?? this.month,
        day: day ?? this.day,
        hour: hour ?? this.hour,
        isLunar: isLunar ?? this.isLunar,
        gender: gender ?? this.gender,
      );

  /// 캐시 키 — 같은 사주 = 같은 키 (라벨은 제외).
  /// 명리학적으로 같은 사주는 같은 운세라서, 같은 키면 캐시 공유 정당.
  String get cacheKey {
    final cal = isLunar ? 'L' : 'S';
    return '$cal${year.toString().padLeft(4, '0')}'
        '${month.toString().padLeft(2, '0')}'
        '${day.toString().padLeft(2, '0')}'
        '${hour.toString().padLeft(2, '0')}'
        '_${gender.name}';
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
    final birth = tz.TZDateTime(loc, y, m, d, profile.hour, 0);

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
