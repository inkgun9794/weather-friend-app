import 'package:weather_friend/features/record/domain/diary_mood.dart';

/// 기록(다이어리) 한 편 — 하늘 사진 + 제목 + 내용 + 기분 날씨.
///
/// [imagePath]는 앱 문서 디렉터리(`diary_images/`)에 복사해 둔 로컬 파일의
/// 절대 경로. SharedPreferences에는 이 경로를 포함한 메타데이터만 JSON으로
/// 저장하고, 실제 이미지 바이트는 파일시스템에 둔다.
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.createdAt,
    this.imagePath,
    required this.title,
    required this.content,
    this.mood,
  });

  /// 생성 시각 밀리초를 그대로 쓴 안정적 식별자 — 이미지 파일명과도 일치.
  final String id;
  final DateTime createdAt;

  /// 하늘 사진의 로컬 파일 경로. 사진 없이 기분만 기록하면 null.
  final String? imagePath;
  final String title;
  final String content;

  /// 작성 시 고른 기분 날씨(선택 안 했으면 null).
  final DiaryMood? mood;

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'imagePath': imagePath,
        'title': title,
        'content': content,
        'mood': mood?.name,
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        imagePath: j['imagePath'] as String?,
        title: (j['title'] as String?) ?? '',
        content: (j['content'] as String?) ?? '',
        mood: DiaryMood.fromName(j['mood'] as String?),
      );
}

/// 같은 달력 날짜인지(연·월·일 일치) — 하루 1개 규칙 판별용.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
