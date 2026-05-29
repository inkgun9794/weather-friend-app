import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/fortune/data/pending_fortune.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';

/// 입력 모드 — primary는 SharedPreferences에 저장, guest는 임시 (당일 리포트만).
enum BirthInputMode { primary, guest }

/// 사주 입력 form. 이름/관계/생년월일/시/성별/양력음력 입력.
/// 저장 시 mode에 따라 처리:
///   - primary: '내 프로필'로 영구 저장 + sajuProfileProvider 업데이트
///   - guest:   영구 저장 X — 단지 fetch만 (fortuneForProfileProvider가 FortuneReport에 저장)
class BirthInputForm extends ConsumerStatefulWidget {
  const BirthInputForm({
    super.key,
    required this.mode,
    required this.onSaved,
    this.waitForFortune = false,
    this.initialProfile,
  });

  final BirthInputMode mode;

  /// 저장 + (옵션) 운세 fetch 완료 후 호출.
  final void Function(SajuProfile profile) onSaved;

  /// true면 운세 fetch 완료까지 버튼 비활성화 유지.
  final bool waitForFortune;

  /// 폼 prefill용 — 없으면 default 값.
  final SajuProfile? initialProfile;

  @override
  ConsumerState<BirthInputForm> createState() => _BirthInputFormState();
}

class _BirthInputFormState extends ConsumerState<BirthInputForm> {
  late TextEditingController _nameCtrl;
  late SajuRelation _relation;
  late DateTime _date;
  late int _hour;
  late bool _isLunar;
  late SajuGender _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialProfile;
    _nameCtrl = TextEditingController(
      text: init?.name ?? (widget.mode == BirthInputMode.primary ? '나' : ''),
    );
    _relation = init?.relation ??
        (widget.mode == BirthInputMode.primary
            ? SajuRelation.self
            : SajuRelation.family);
    _date = init != null
        ? DateTime(init.year, init.month, init.day)
        : DateTime(1990, 1, 1);
    _hour = init?.hour ?? 12;
    _isLunar = init?.isLunar ?? false;
    _gender = init?.gender ?? SajuGender.male;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: '생년월일',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickHour() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HourPickerSheet(initial: _hour),
    );
    if (picked != null) setState(() => _hour = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요')),
      );
      return;
    }

    setState(() => _saving = true);

    final profile = SajuProfile(
      name: name,
      relation: _relation,
      year: _date.year,
      month: _date.month,
      day: _date.day,
      hour: _hour,
      isLunar: _isLunar,
      gender: _gender,
    );

    // primary 모드면 SharedPreferences + provider 업데이트
    if (widget.mode == BirthInputMode.primary) {
      final repo = await ref.read(sajuProfileRepositoryProvider.future);
      await repo.save(profile);
      if (!mounted) return;
      ref.read(sajuProfileProvider.notifier).set(profile);
    }

    // 운세 fetch — 백그라운드로. await 안 함.
    // pendingFortuneProvider가 상태 관리 → UI 어디서든 watch해서 로딩/툴팁 처리.
    // (await으로 form 살려두면 form dispose 타이밍 race가 발생함)
    // ignore: discarded_futures
    ref.read(pendingFortuneProvider.notifier).start(profile);

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 이름
        _SectionLabel(label: '이름'),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          textInputAction: TextInputAction.done,
          maxLength: 20,
          decoration: InputDecoration(
            hintText: widget.mode == BirthInputMode.primary
                ? '예: 나, 본인'
                : '예: 엄마, 철수',
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.inkMute.withValues(alpha: 0.25),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.inkMute.withValues(alpha: 0.25),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.ink),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 관계
        _SectionLabel(label: '관계'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in SajuRelation.values)
              _ChoiceChip(
                label: r.label,
                selected: _relation == r,
                onTap: () => setState(() => _relation = r),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // 양력/음력
        _SectionLabel(label: '달력'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ToggleButton(
                label: '양력',
                selected: !_isLunar,
                onTap: () => setState(() => _isLunar = false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ToggleButton(
                label: '음력',
                selected: _isLunar,
                onTap: () => setState(() => _isLunar = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _SectionLabel(label: '생년월일'),
        const SizedBox(height: 8),
        _FieldButton(
          icon: Icons.calendar_today_rounded,
          text: '${_date.year}년 ${_date.month}월 ${_date.day}일',
          onTap: _pickDate,
        ),
        const SizedBox(height: 20),

        _SectionLabel(label: '태어난 시간'),
        const SizedBox(height: 8),
        _FieldButton(
          icon: Icons.access_time_rounded,
          text: _hourLabel(_hour),
          onTap: _pickHour,
        ),
        const SizedBox(height: 20),

        _SectionLabel(label: '성별'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ToggleButton(
                label: '남성',
                selected: _gender == SajuGender.male,
                onTap: () => setState(() => _gender = SajuGender.male),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ToggleButton(
                label: '여성',
                selected: _gender == SajuGender.female,
                onTap: () => setState(() => _gender = SajuGender.female),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // 저장 버튼
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _saving
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        '사주 분석 중...',
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : Text(
                    widget.mode == BirthInputMode.primary
                        ? '오늘의 운세 보기'
                        : '운세 보기',
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  static String _hourLabel(int hour) {
    const branchLabels = [
      '자', '축', '인', '묘', '진', '사',
      '오', '미', '신', '유', '술', '해',
    ];
    final idx = ((hour + 1) ~/ 2) % 12;
    return '${hour.toString().padLeft(2, '0')}:00 (${branchLabels[idx]}시)';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.inkMute,
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? AppColors.ink
                  : AppColors.inkMute.withValues(alpha: 0.25),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? AppColors.ink
                  : AppColors.inkMute.withValues(alpha: 0.25),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.inkMute.withValues(alpha: 0.25),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.inkMute, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkMute,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HourPickerSheet extends StatelessWidget {
  const _HourPickerSheet({required this.initial});
  final int initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.inkMute.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '태어난 시간',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: 24,
                itemBuilder: (_, hour) {
                  final selected = hour == initial;
                  return ListTile(
                    title: Text(_BirthInputFormState._hourLabel(hour)),
                    selected: selected,
                    trailing: selected
                        ? Icon(Icons.check_rounded, color: AppColors.ink)
                        : null,
                    onTap: () => Navigator.of(context).pop(hour),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
