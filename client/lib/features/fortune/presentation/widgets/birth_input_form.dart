import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/app/theme/app_type.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/fortune/data/pending_fortune.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';
import 'package:weather_friend/features/fortune/presentation/widgets/birth_wheel_pickers.dart';

/// 입력 모드 — primary는 SharedPreferences에 저장, guest는 임시 (당일 리포트만).
enum BirthInputMode { primary, guest }

/// 사주 입력 form. 이름/관계/생년월일(양·음력 포함)/시/성별 입력.
/// 생년월일·시간은 휠 피커 바텀시트로 고른다 (달력/시계 다이얼로그 X).
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
    this.style,
  });

  final BirthInputMode mode;

  /// 저장 + (옵션) 운세 fetch 완료 후 호출.
  final void Function(SajuProfile profile) onSaved;

  /// true면 운세 fetch 완료까지 버튼 비활성화 유지.
  final bool waitForFortune;

  /// 폼 prefill용 — 없으면 default 값.
  final SajuProfile? initialProfile;

  /// 배경에 맞춘 입력 폼 색상. null이면 종이 배경용 기본 스타일.
  final BirthInputFormStyle? style;

  @override
  ConsumerState<BirthInputForm> createState() => _BirthInputFormState();
}

class BirthInputFormStyle {
  const BirthInputFormStyle({
    required this.labelColor,
    required this.fieldFill,
    required this.fieldBorder,
    required this.fieldFocusedBorder,
    required this.fieldText,
    required this.fieldHint,
    required this.icon,
    required this.selectedFill,
    required this.selectedBorder,
    required this.selectedText,
    required this.unselectedText,
    required this.primaryFill,
    required this.primaryText,
    required this.shadow,
    this.labelShadows,
  });

  factory BirthInputFormStyle.standard() {
    return BirthInputFormStyle(
      labelColor: AppColors.inkMute,
      fieldFill: Colors.white,
      fieldBorder: AppColors.inkMute.withValues(alpha: 0.25),
      fieldFocusedBorder: AppColors.ink,
      fieldText: AppColors.ink,
      fieldHint: AppColors.inkMute,
      icon: AppColors.inkMute,
      selectedFill: AppColors.fortuneAccent,
      selectedBorder: AppColors.fortuneAccent,
      selectedText: AppColors.ink,
      unselectedText: AppColors.ink,
      primaryFill: AppColors.fortuneAccent,
      primaryText: AppColors.ink,
      shadow: Colors.black.withValues(alpha: 0.06),
    );
  }

  factory BirthInputFormStyle.onSky(SkyPalette sky) {
    final lightText = sky.ink.computeLuminance() > 0.55;
    final primaryFill = sky.sun;
    return BirthInputFormStyle(
      labelColor: sky.inkSoft.withValues(alpha: lightText ? 0.95 : 0.86),
      fieldFill: Colors.white.withValues(alpha: lightText ? 0.86 : 0.88),
      fieldBorder: Colors.white.withValues(alpha: lightText ? 0.48 : 0.7),
      fieldFocusedBorder: lightText
          ? Colors.white.withValues(alpha: 0.96)
          : AppColors.ink,
      fieldText: AppColors.ink,
      fieldHint: AppColors.inkMute,
      icon: AppColors.inkSoft,
      selectedFill: sky.sun.withValues(alpha: lightText ? 0.92 : 0.96),
      selectedBorder: sky.sun.withValues(alpha: 0.98),
      selectedText: AppColors.ink,
      unselectedText: AppColors.ink,
      primaryFill: primaryFill,
      primaryText: AppColors.ink,
      shadow: Colors.black.withValues(alpha: lightText ? 0.14 : 0.08),
      labelShadows: [
        Shadow(
          color: (lightText ? Colors.black : Colors.white).withValues(
            alpha: lightText ? 0.22 : 0.18,
          ),
          blurRadius: 10,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  final Color labelColor;
  final Color fieldFill;
  final Color fieldBorder;
  final Color fieldFocusedBorder;
  final Color fieldText;
  final Color fieldHint;
  final Color icon;
  final Color selectedFill;
  final Color selectedBorder;
  final Color selectedText;
  final Color unselectedText;
  final Color primaryFill;
  final Color primaryText;
  final Color shadow;
  final List<Shadow>? labelShadows;
}

class _BirthInputFormState extends ConsumerState<BirthInputForm> {
  late TextEditingController _nameCtrl;
  late SajuRelation _relation;
  late DateTime _date;
  late int _hour;
  late int _minute;
  late bool _timeUnknown;
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
    _relation =
        init?.relation ??
        (widget.mode == BirthInputMode.primary
            ? SajuRelation.self
            : SajuRelation.family);
    _date = init != null
        ? DateTime(init.year, init.month, init.day)
        : DateTime(1990, 1, 1);
    _hour = init?.hour ?? 12;
    _minute = init?.minute ?? 0;
    _timeUnknown = init?.timeUnknown ?? false;
    _isLunar = init?.isLunar ?? false;
    _gender = init?.gender ?? SajuGender.male;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showBirthDateWheelSheet(
      context,
      initial: _date,
      initialIsLunar: _isLunar,
    );
    if (picked != null) {
      setState(() {
        _date = picked.date;
        _isLunar = picked.isLunar;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showBirthTimeWheelSheet(
      context,
      initialHour: _hour,
      initialMinute: _minute,
      initialUnknown: _timeUnknown,
    );
    if (picked != null) {
      setState(() {
        _timeUnknown = picked.unknown;
        if (!picked.unknown) {
          _hour = picked.hour;
          _minute = picked.minute;
        }
      });
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이름을 입력해주세요')));
      return;
    }

    setState(() => _saving = true);

    final profile = SajuProfile(
      name: name,
      relation: _relation,
      year: _date.year,
      month: _date.month,
      day: _date.day,
      hour: _timeUnknown ? 12 : _hour,
      minute: _timeUnknown ? 0 : _minute,
      isLunar: _isLunar,
      gender: _gender,
      timeUnknown: _timeUnknown,
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
    final style = widget.style ?? BirthInputFormStyle.standard();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 이름
        _SectionLabel(label: '이름', style: style),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          textInputAction: TextInputAction.done,
          maxLength: 20,
          style: AppType.headline.copyWith(color: style.fieldText),
          decoration: InputDecoration(
            hintText: widget.mode == BirthInputMode.primary
                ? '예: 나, 본인'
                : '예: 엄마, 철수',
            hintStyle: TextStyle(
              color: style.fieldHint,
              fontWeight: FontWeight.w500,
            ),
            counterText: '',
            filled: true,
            fillColor: style.fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: style.fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: style.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: style.fieldFocusedBorder),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 관계
        _SectionLabel(label: '관계', style: style),
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
                style: style,
              ),
          ],
        ),
        const SizedBox(height: 20),

        // 생년월일 — 양/음력 토글은 휠 피커 시트 안에 함께 있다.
        _SectionLabel(label: '생년월일', style: style),
        const SizedBox(height: 8),
        _FieldButton(
          icon: Icons.calendar_today_rounded,
          text:
              '${_isLunar ? '음력' : '양력'} '
              '${_date.year}년 ${_date.month}월 ${_date.day}일',
          onTap: _pickDate,
          style: style,
        ),
        const SizedBox(height: 20),

        _SectionLabel(label: '태어난 시간', style: style),
        const SizedBox(height: 8),
        _FieldButton(
          icon: Icons.access_time_rounded,
          text: _timeUnknown
              ? '시간 모름'
              : '${_hour.toString().padLeft(2, '0')}:'
                    '${_minute.toString().padLeft(2, '0')}'
                    ' (${sijinFor(_hour).name})',
          onTap: _pickTime,
          style: style,
        ),
        const SizedBox(height: 20),

        _SectionLabel(label: '성별', style: style),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ToggleButton(
                label: '남성',
                selected: _gender == SajuGender.male,
                onTap: () => setState(() => _gender = SajuGender.male),
                style: style,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ToggleButton(
                label: '여성',
                selected: _gender == SajuGender.female,
                onTap: () => setState(() => _gender = SajuGender.female),
                style: style,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // 저장 버튼
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: style.primaryFill,
              foregroundColor: style.primaryText,
              disabledBackgroundColor: style.primaryFill.withValues(alpha: 0.7),
              disabledForegroundColor: style.primaryText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _saving
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: style.primaryText,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '사주 분석 중...',
                        style: AppType.headline,
                      ),
                    ],
                  )
                : Text(
                    widget.mode == BirthInputMode.primary
                        ? '오늘의 운세 보기'
                        : '운세 보기',
                    style: AppType.headline,
                  ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.style});

  final String label;
  final BirthInputFormStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppType.body.copyWith(
        color: style.labelColor,
        shadows: style.labelShadows,
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.style,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final BirthInputFormStyle style;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? style.selectedFill : style.fieldFill,
      borderRadius: BorderRadius.circular(16),
      elevation: selected ? 0 : 1,
      shadowColor: style.shadow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? style.selectedBorder : style.fieldBorder,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: AppType.bodyLg.copyWith(
                  color: selected ? style.selectedText : style.unselectedText,
                ),
              ),
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
    required this.style,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final BirthInputFormStyle style;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? style.selectedFill : style.fieldFill,
      borderRadius: BorderRadius.circular(18),
      elevation: selected ? 0 : 1,
      shadowColor: style.shadow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? style.selectedBorder : style.fieldBorder,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppType.headline.copyWith(
                color: selected ? style.selectedText : style.unselectedText,
              ),
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
    required this.style,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final BirthInputFormStyle style;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: style.fieldFill,
      borderRadius: BorderRadius.circular(18),
      elevation: 1,
      shadowColor: style.shadow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            border: Border.all(color: style.fieldBorder),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icon, color: style.icon, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.headline.copyWith(color: style.fieldText),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: style.icon, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
