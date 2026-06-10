import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_friend/core/services/shared_prefs_provider.dart';
import 'package:weather_friend/features/record/domain/diary_entry.dart';
import 'package:weather_friend/features/record/domain/diary_mood.dart';

/// 다이어리 기록을 로컬에 영구 저장.
///
/// - 메타데이터(제목·내용·생성시각·이미지경로)는 SharedPreferences에 JSON 배열로.
/// - 이미지 원본은 앱 문서 디렉터리 `diary_images/<id>.<ext>`에 복사해 둔다.
///   (피커가 주는 캐시 경로는 OS가 임의로 비우므로 그대로 두면 안 됨)
class DiaryRepository {
  DiaryRepository(this._prefs);

  static const _key = 'diary_entries_v1';

  final SharedPreferences _prefs;

  /// 최신순(생성 역순) 정렬된 전체 기록.
  List<DiaryEntry> loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final list = json.decode(raw) as List;
      return list
          .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist(List<DiaryEntry> entries) async {
    await _prefs.setString(
      _key,
      json.encode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<Directory> _imageDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'diary_images'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 피커가 준 임시 파일을 문서 디렉터리로 복사하고 영구 경로를 돌려준다.
  Future<String> persistImage({
    required String sourcePath,
    required String id,
  }) async {
    final dir = await _imageDir();
    final ext = p.extension(sourcePath);
    final dest = p.join(dir.path, '$id${ext.isEmpty ? '.jpg' : ext}');
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// 새 기록 생성 — 사진이 있으면 영구 복사한 뒤 메타데이터를 저장한다.
  /// [sourceImagePath]가 null이면 사진 없이 기분만 기록.
  Future<DiaryEntry> create({
    String? sourceImagePath,
    required String title,
    required String content,
    DiaryMood? mood,
  }) async {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();
    final imagePath = sourceImagePath == null
        ? null
        : await persistImage(sourcePath: sourceImagePath, id: id);
    final entry = DiaryEntry(
      id: id,
      createdAt: now,
      imagePath: imagePath,
      title: title,
      content: content,
      mood: mood,
    );
    await _persist([entry, ...loadAll()]);
    return entry;
  }

  /// 기존 기록의 제목·내용 수정(이미지는 유지).
  Future<void> update(DiaryEntry entry) async {
    final all = loadAll();
    final idx = all.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      all[idx] = entry;
    } else {
      all.insert(0, entry);
    }
    await _persist(all);
  }

  /// 기록 삭제 — 메타데이터와 이미지 파일을 함께 제거.
  Future<void> delete(String id) async {
    final all = loadAll();
    final idx = all.indexWhere((e) => e.id == id);
    final removed = idx >= 0 ? all[idx] : null;
    all.removeWhere((e) => e.id == id);
    await _persist(all);
    if (removed != null && removed.hasImage) {
      final file = File(removed.imagePath!);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {
          // 파일이 이미 없거나 권한 문제여도 메타는 이미 지워졌으니 무시.
        }
      }
    }
  }
}

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepository(ref.watch(sharedPreferencesProvider));
});

/// 화면이 구독하는 기록 목록 상태. prefs 로드가 동기라 [Notifier]로 충분하다.
/// 추가·수정·삭제 후 repo에서 다시 읽어 상태를 교체한다.
class DiaryListNotifier extends Notifier<List<DiaryEntry>> {
  DiaryRepository get _repo => ref.read(diaryRepositoryProvider);

  @override
  List<DiaryEntry> build() => _repo.loadAll();

  Future<DiaryEntry> add({
    String? sourceImagePath,
    required String title,
    required String content,
    DiaryMood? mood,
  }) async {
    final entry = await _repo.create(
      sourceImagePath: sourceImagePath,
      title: title,
      content: content,
      mood: mood,
    );
    state = _repo.loadAll();
    return entry;
  }

  /// 기존 기록 수정. [newImagePath]가 있으면(편집 중 사진 추가/교체) 영구 복사 후 반영.
  /// 최종 반영된 엔트리를 돌려준다(이미지 경로 등이 갱신된 상태).
  Future<DiaryEntry> edit(DiaryEntry entry, {String? newImagePath}) async {
    var updated = entry;
    if (newImagePath != null) {
      final path = await _repo.persistImage(
        sourcePath: newImagePath,
        id: entry.id,
      );
      updated = DiaryEntry(
        id: entry.id,
        createdAt: entry.createdAt,
        imagePath: path,
        title: entry.title,
        content: entry.content,
        mood: entry.mood,
      );
    }
    await _repo.update(updated);
    state = _repo.loadAll();
    return updated;
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    state = _repo.loadAll();
  }
}

final diaryListProvider =
    NotifierProvider<DiaryListNotifier, List<DiaryEntry>>(DiaryListNotifier.new);
