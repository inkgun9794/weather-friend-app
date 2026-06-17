import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:weather_friend/app/theme/app_type.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/record/data/diary_repository.dart';
import 'package:weather_friend/features/record/domain/diary_entry.dart';
import 'package:weather_friend/features/record/domain/diary_mood.dart';
import 'package:weather_friend/features/record/presentation/diary_format.dart';
import 'package:weather_friend/features/record/presentation/widgets/image_source_sheet.dart';
import 'package:weather_friend/features/record/presentation/widgets/mood_widgets.dart';

/// 편집 화면 인자 — 신규 작성(갓 고른 이미지 경로)이거나 기존 기록 수정.
class DiaryEditorArgs {
  /// 신규 작성. [imagePath]가 null이면 사진 없이 기분만 기록 시작.
  const DiaryEditorArgs.create([this.imagePath]) : entry = null;
  const DiaryEditorArgs.edit(DiaryEntry this.entry) : imagePath = null;

  /// 신규 작성 시 피커가 준 임시 파일 경로(사진 없이 시작하면 null).
  final String? imagePath;

  /// 수정 시 기존 기록.
  final DiaryEntry? entry;
}

/// 하늘 사진 한 장에 제목·내용을 적는 일기장 화면.
class DiaryEditorScreen extends ConsumerStatefulWidget {
  const DiaryEditorScreen({super.key, required this.args});

  static const routePath = '/record/edit';

  final DiaryEditorArgs args;

  @override
  ConsumerState<DiaryEditorScreen> createState() => _DiaryEditorScreenState();
}

class _DiaryEditorScreenState extends ConsumerState<DiaryEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  DiaryMood? _mood;

  /// 기분 선택 섹션 펼침 여부 — 기분이 정해지면 접고, 사진 위 도장을 눌러 다시 펼친다.
  bool _moodPickerOpen = true;

  /// 저장된 기록(편집 모드). 신규로 시작해도 기분을 탭해 저장되면 여기에 채워진다.
  DiaryEntry? _entry;

  /// 새로 고른 사진(피커 캐시 경로). 저장 시 영구 복사된다.
  String? _imagePathOverride;
  bool _saving = false;

  bool get _isPersisted => _entry != null;
  DateTime get _date => _entry?.createdAt ?? DateTime.now();

  /// 화면에 보여줄 사진 — 새로 고른 것 우선, 없으면 저장본/신규 인자(없으면 null).
  String? get _displayImagePath =>
      _imagePathOverride ?? _entry?.imagePath ?? widget.args.imagePath;

  @override
  void initState() {
    super.initState();
    _entry = widget.args.entry;
    _title = TextEditingController(text: _entry?.title ?? '');
    _content = TextEditingController(text: _entry?.content ?? '');
    _mood = _entry?.mood;
    // 이미 기분이 있으면(편집) 접힌 상태로 시작 — 사진 위 도장으로 다시 펼침.
    _moodPickerOpen = _mood == null;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  /// 현재 입력(사진·제목·내용·기분)을 저장. 저장본이 없으면 생성, 있으면 갱신.
  /// [pop]이면 저장 후 화면을 닫는다(저장 버튼). 기분 탭은 닫지 않고 머문다.
  Future<void> _persist({required bool pop, bool toast = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final notifier = ref.read(diaryListProvider.notifier);
    try {
      final current = _entry;
      final DiaryEntry saved;
      if (current == null) {
        saved = await notifier.add(
          sourceImagePath: _imagePathOverride ?? widget.args.imagePath,
          title: _title.text.trim(),
          content: _content.text.trim(),
          mood: _mood,
        );
      } else {
        saved = await notifier.edit(
          DiaryEntry(
            id: current.id,
            createdAt: current.createdAt,
            imagePath: current.imagePath,
            title: _title.text.trim(),
            content: _content.text.trim(),
            mood: _mood,
          ),
          newImagePath: _imagePathOverride,
        );
      }
      if (!mounted) return;
      if (pop) {
        context.pop();
        return;
      }
      setState(() {
        _entry = saved;
        _imagePathOverride = null;
        _saving = false;
      });
      if (toast) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('기분을 기록했어요'),
              duration: Duration(milliseconds: 1200),
            ),
          );
      }
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장에 실패했어요')),
      );
    }
  }

  /// 기분 날씨는 탭하는 즉시 저장(저장 버튼 불필요) + 선택 섹션은 접는다.
  Future<void> _onMoodSelected(DiaryMood mood) async {
    setState(() {
      _mood = mood;
      _moodPickerOpen = false;
    });
    await _persist(pop: false, toast: true);
  }

  /// 사진 위 기분 도장을 누르면 선택 섹션을 다시 펼친다(다시 누르면 접힘).
  void _toggleMoodPicker() {
    setState(() => _moodPickerOpen = !_moodPickerOpen);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록을 삭제할까요?'),
        content: const Text('사진과 글이 함께 사라져요. 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD2554D)),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(diaryListProvider.notifier).remove(_entry!.id);
    if (!mounted) return;
    context.pop();
  }

  /// 사진 없이 시작했거나 바꾸고 싶을 때 — 갤러리/카메라에서 골라 미리보기에 반영.
  Future<void> _pickPhoto() async {
    final choice = await showImageSourceSheet(context);
    if (choice == null || choice == ImageSourceChoice.moodOnly || !mounted) {
      return;
    }
    try {
      final picked = await ImagePicker().pickImage(
        source: choice == ImageSourceChoice.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;
      setState(() => _imagePathOverride = picked.path);
    } on Exception catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했어요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _isPersisted ? '기록' : '새 기록',
          style: AppType.title.copyWith(color: AppColors.ink),
        ),
        actions: [
          if (_isPersisted)
            IconButton(
              onPressed: _saving ? null : _confirmDelete,
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.inkMute),
              tooltip: '삭제',
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : () => _persist(pop: true),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '저장',
                      style: AppType.subhead.copyWith(color: AppColors.ink),
                    ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          // Scaffold가 키보드 높이만큼 본문을 자동으로 줄여주므로(viewInsets는
          // 여기서 따로 더하지 않는다) 고정 하단 여백만 둔다.
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            if (_displayImagePath != null)
              _Polaroid(
                imagePath: _displayImagePath!,
                dateLabel: DiaryFormat.stamp(_date),
                mood: _mood,
                onMoodTap: _mood != null ? _toggleMoodPicker : null,
              )
            else
              _PhotoPlaceholder(
                onAddPhoto: _pickPhoto,
                mood: _mood,
                onMoodTap: _mood != null ? _toggleMoodPicker : null,
              ),
            // 기분 섹션 — 미선택이거나 도장을 눌러 펼쳤을 때만. 탭하면 즉시 저장 후 접힘.
            if (_moodPickerOpen) ...[
              const SizedBox(height: 16),
              _MoodSection(selected: _mood, onSelected: _onMoodSelected),
            ],
            const SizedBox(height: 16),
            _PageCard(
              date: DiaryFormat.full(_date),
              titleField: TextField(
                controller: _title,
                textInputAction: TextInputAction.next,
                style: AppType.title.copyWith(
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                  height: 1.3,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: '제목',
                  hintStyle: AppType.title.copyWith(
                    color: AppColors.inkFaint,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              contentField: TextField(
                controller: _content,
                // 길이 제한 없이 입력만큼 계속 늘어나고, 페이지(ListView)가 스크롤된다.
                minLines: 5,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: AppType.reading.copyWith(
                  color: AppColors.inkSoft,
                  height: 1.7,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: '오늘 하늘은 어땠나요?\n떠오른 생각을 자유롭게 적어보세요.',
                  hintStyle: AppType.reading.copyWith(
                    color: AppColors.inkFaint,
                    height: 1.7,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 흰 테두리 폴라로이드 프레임 안의 16:9 사진 + 아래 작은 날짜 캡션.
/// [mood]를 고르면 사진 우상단에 도장처럼 얹는다.
class _Polaroid extends StatelessWidget {
  const _Polaroid({
    required this.imagePath,
    required this.dateLabel,
    this.mood,
    this.onMoodTap,
  });

  final String imagePath;
  final String dateLabel;
  final DiaryMood? mood;

  /// non-null이면 기분 도장을 탭 가능하게 + 편집 뱃지 표시.
  final VoidCallback? onMoodTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: AppColors.paper3,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.inkFaint,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  if (mood != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: onMoodTap != null
                          ? _MoodStampButton(mood: mood!, onTap: onMoodTap!)
                          : MoodStamp(mood: mood!, size: 38),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            dateLabel,
            style: AppType.micro.copyWith(
              color: AppColors.inkMute,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// 사진 없이 시작했을 때의 자리 — 탭하면 사진 추가(선택). 기분을 골랐으면
/// 우측상단에 기분 도장(편집 뱃지)을 띄워 다시 선택 섹션을 펼칠 수 있게 한다.
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({
    required this.onAddPhoto,
    this.mood,
    this.onMoodTap,
  });

  final VoidCallback onAddPhoto;
  final DiaryMood? mood;
  final VoidCallback? onMoodTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onAddPhoto,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.paper2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          size: 22,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '사진 추가 (선택)',
                        style: AppType.body.copyWith(color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (mood != null && onMoodTap != null)
            Positioned(
              top: 8,
              right: 8,
              child: _MoodStampButton(mood: mood!, onTap: onMoodTap!),
            ),
        ],
      ),
    );
  }
}

/// 사진 위 기분 도장 + 우측상단 편집 뱃지. 탭하면 기분 선택 섹션을 다시 펼친다.
class _MoodStampButton extends StatelessWidget {
  const _MoodStampButton({required this.mood, required this.onTap});

  final DiaryMood mood;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MoodStamp(mood: mood, size: 38),
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.edit, size: 9, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// "당신의 기분은 현재 어떤 날씨인가요?" — 작성 완료 전 마지막 단계.
class _MoodSection extends StatelessWidget {
  const _MoodSection({required this.selected, required this.onSelected});

  final DiaryMood? selected;
  final ValueChanged<DiaryMood> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '당신의 기분은 현재 어떤 날씨인가요?',
              style: AppType.bodyLg.copyWith(
                color: AppColors.ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 14),
            MoodPicker(selected: selected, onSelected: onSelected),
          ],
        ),
      ),
    );
  }
}

/// 노트 한 페이지 — 날짜 머리글 + 제목/내용 필드. 테두리 없이 흰 카드 + 그림자만.
class _PageCard extends StatelessWidget {
  const _PageCard({
    required this.date,
    required this.titleField,
    required this.contentField,
  });

  final String date;
  final Widget titleField;
  final Widget contentField;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              date,
              style: AppType.caption.copyWith(
                color: AppColors.inkMute,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 14),
            titleField,
            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.hairline),
            const SizedBox(height: 14),
            contentField,
          ],
        ),
      ),
    );
  }
}
