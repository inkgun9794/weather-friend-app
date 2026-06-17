import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lunar/lunar.dart' as lunar_pkg;
import 'package:weather_friend/app/theme/app_type.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';

/// 생년월일 휠 피커 결과 — 양/음력 선택을 시트 안으로 합쳤다.
typedef BirthDateSelection = ({DateTime date, bool isLunar});

/// 태어난 시간 휠 피커 결과 — unknown이면 hour/minute은 무시.
typedef BirthTimeSelection = ({int hour, int minute, bool unknown});

/// 시진(時辰) 이름/범위 — saju 패키지의 시주 경계와 동일하게 정각(23시) 기준.
/// (standardPreset은 경도 미지정 시 솔라타임 보정이 0분이라 분(分)은 시진에 영향 없음)
({String name, String range}) sijinFor(int hour) {
  const names = [
    '자시', '축시', '인시', '묘시', '진시', '사시',
    '오시', '미시', '신시', '유시', '술시', '해시',
  ];
  final index = ((hour + 1) ~/ 2) % 12;
  final start = (23 + index * 2) % 24;
  final end = (start + 1) % 24;
  String hh(int h) => h.toString().padLeft(2, '0');
  return (name: names[index], range: '${hh(start)}:00~${hh(end)}:59');
}

/// 생년월일 선택 바텀시트 — 년/월/일 드럼 휠 + 양/음력 토글.
/// 달력 다이얼로그 대신 휠을 쓰는 이유: 생일은 수십 년 전 날짜라
/// 달력 네비게이션(년 선택 → 월 이동 → 일 탭)이 과하게 느리다.
Future<BirthDateSelection?> showBirthDateWheelSheet(
  BuildContext context, {
  required DateTime initial,
  required bool initialIsLunar,
}) {
  return showModalBottomSheet<BirthDateSelection>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) =>
        _BirthDateSheet(initial: initial, initialIsLunar: initialIsLunar),
  );
}

/// 태어난 시간 선택 바텀시트 — 시/분 드럼 휠 + 시진 안내 + "시간 모름".
Future<BirthTimeSelection?> showBirthTimeWheelSheet(
  BuildContext context, {
  required int initialHour,
  required int initialMinute,
  required bool initialUnknown,
}) {
  return showModalBottomSheet<BirthTimeSelection>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _BirthTimeSheet(
      initialHour: initialHour,
      initialMinute: initialMinute,
      initialUnknown: initialUnknown,
    ),
  );
}

class _BirthDateSheet extends StatefulWidget {
  const _BirthDateSheet({required this.initial, required this.initialIsLunar});

  final DateTime initial;
  final bool initialIsLunar;

  @override
  State<_BirthDateSheet> createState() => _BirthDateSheetState();
}

class _BirthDateSheetState extends State<_BirthDateSheet> {
  static const int _minYear = 1900;

  late final DateTime _today = DateTime.now();
  late int _year = widget.initial.year.clamp(_minYear, _today.year);
  late int _month = widget.initial.month;
  late int _day = widget.initial.day;
  late bool _isLunar = widget.initialIsLunar;

  late final FixedExtentScrollController _yearCtrl =
      FixedExtentScrollController(initialItem: _year - _minYear);
  late final FixedExtentScrollController _monthCtrl =
      FixedExtentScrollController(initialItem: _month - 1);
  late final FixedExtentScrollController _dayCtrl =
      FixedExtentScrollController(initialItem: _day - 1);

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  int get _monthCount => _year == _today.year ? _today.month : 12;

  int get _dayCount {
    if (_isLunar) {
      // 음력은 월마다 29/30일 — lunar 패키지가 정확한 일수를 안다.
      return lunar_pkg.LunarMonth.fromYm(_year, _month)?.getDayCount() ?? 30;
    }
    final inMonth = DateTime(_year, _month + 1, 0).day;
    final isThisMonth = _year == _today.year && _month == _today.month;
    return isThisMonth ? _today.day : inMonth;
  }

  /// 년/월/양음력이 바뀌어 월·일 범위가 줄면 선택을 범위 안으로 끌어온다.
  void _clampWheels() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_month > _monthCount) {
        _monthCtrl.animateToItem(
          _monthCount - 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      if (_day > _dayCount) {
        _dayCtrl.animateToItem(
          _dayCount - 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _confirm() {
    final day = _day.clamp(1, _dayCount);
    Navigator.of(context).pop((
      date: DateTime(_year, _month, day),
      isLunar: _isLunar,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: '생년월일',
      onConfirm: _confirm,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _SegChip(
                  label: '양력',
                  selected: !_isLunar,
                  onTap: () {
                    if (!_isLunar) return;
                    setState(() => _isLunar = false);
                    _clampWheels();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SegChip(
                  label: '음력',
                  selected: _isLunar,
                  onTap: () {
                    if (_isLunar) return;
                    setState(() => _isLunar = true);
                    _clampWheels();
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _WheelArea(
          wheels: [
            _Wheel(
              key: const Key('birth-year-wheel'),
              controller: _yearCtrl,
              count: _today.year - _minYear + 1,
              labelFor: (i) => '${_minYear + i}년',
              flex: 4,
              onChanged: (i) {
                setState(() => _year = _minYear + i);
                _clampWheels();
              },
            ),
            _Wheel(
              key: const Key('birth-month-wheel'),
              controller: _monthCtrl,
              count: _monthCount,
              labelFor: (i) => '${i + 1}월',
              flex: 3,
              onChanged: (i) {
                setState(() => _month = i + 1);
                _clampWheels();
              },
            ),
            _Wheel(
              key: const Key('birth-day-wheel'),
              controller: _dayCtrl,
              count: _dayCount,
              labelFor: (i) => '${i + 1}일',
              flex: 3,
              onChanged: (i) => setState(() => _day = i + 1),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _isLunar ? '음력 생일은 윤달 없이 평달 기준으로 풀이해요' : '주민등록상 생일이 아닌 실제 태어난 날짜를 선택해요',
          style: AppType.caption.copyWith(color: AppColors.inkMute),
        ),
      ],
    );
  }
}

class _BirthTimeSheet extends StatefulWidget {
  const _BirthTimeSheet({
    required this.initialHour,
    required this.initialMinute,
    required this.initialUnknown,
  });

  final int initialHour;
  final int initialMinute;
  final bool initialUnknown;

  @override
  State<_BirthTimeSheet> createState() => _BirthTimeSheetState();
}

class _BirthTimeSheetState extends State<_BirthTimeSheet> {
  late int _hour = widget.initialHour;
  late int _minute = widget.initialMinute;
  late bool _unknown = widget.initialUnknown;

  late final FixedExtentScrollController _hourCtrl =
      FixedExtentScrollController(initialItem: _hour);
  late final FixedExtentScrollController _minuteCtrl =
      FixedExtentScrollController(initialItem: _minute);

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.of(
      context,
    ).pop((hour: _hour, minute: _minute, unknown: _unknown));
  }

  @override
  Widget build(BuildContext context) {
    final sijin = sijinFor(_hour);
    return _SheetScaffold(
      title: '태어난 시간',
      onConfirm: _confirm,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SegChip(
            key: const Key('birth-time-unknown'),
            label: '태어난 시간을 몰라요',
            selected: _unknown,
            leading: _unknown
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            onTap: () => setState(() => _unknown = !_unknown),
          ),
        ),
        const SizedBox(height: 6),
        IgnorePointer(
          ignoring: _unknown,
          child: AnimatedOpacity(
            opacity: _unknown ? 0.3 : 1,
            duration: const Duration(milliseconds: 150),
            child: _WheelArea(
              wheels: [
                _Wheel(
                  key: const Key('birth-hour-wheel'),
                  controller: _hourCtrl,
                  count: 24,
                  labelFor: (i) => '${i.toString().padLeft(2, '0')}시',
                  onChanged: (i) => setState(() => _hour = i),
                ),
                _Wheel(
                  key: const Key('birth-minute-wheel'),
                  controller: _minuteCtrl,
                  count: 60,
                  labelFor: (i) => '${i.toString().padLeft(2, '0')}분',
                  onChanged: (i) => setState(() => _minute = i),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _unknown ? '시(時)를 빼고 세 기둥으로 풀이해요' : '${sijin.name} (${sijin.range})',
          key: const Key('birth-time-caption'),
          style: AppType.caption.copyWith(color: AppColors.inkMute),
        ),
      ],
    );
  }
}

/// 시트 공통 골격 — 핸들 + 타이틀 + 내용 + 확인 버튼.
class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.children,
    required this.onConfirm,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: bottomPad > 0 ? bottomPad : 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.inkMute.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppType.title.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 14),
          ...children,
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.fortuneAccent,
                  foregroundColor: AppColors.ink,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: AppType.headline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 휠들 뒤에 공통 선택 밴드를 깔아주는 영역.
class _WheelArea extends StatelessWidget {
  const _WheelArea({required this.wheels});

  final List<Widget> wheels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Container(
              height: _Wheel.itemExtent,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: wheels),
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    super.key,
    required this.controller,
    required this.count,
    required this.labelFor,
    required this.onChanged,
    this.flex = 1,
  });

  static const double itemExtent = 44;

  final FixedExtentScrollController controller;
  final int count;
  final String Function(int index) labelFor;
  final ValueChanged<int> onChanged;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: itemExtent,
        useMagnifier: true,
        magnification: 1.06,
        squeeze: 1.18,
        selectionOverlay: const SizedBox.shrink(),
        onSelectedItemChanged: (i) {
          HapticFeedback.selectionClick();
          onChanged(i);
        },
        children: [
          for (var i = 0; i < count; i++)
            Center(
              child: Text(
                labelFor(i),
                style: AppType.title.copyWith(color: AppColors.ink),
              ),
            ),
        ],
      ),
    );
  }
}

/// 양력/음력·시간모름 토글 칩 — 폼의 _ToggleButton과 같은 시각 언어.
class _SegChip extends StatelessWidget {
  const _SegChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.fortuneAccent : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.fortuneAccent : AppColors.line,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                Icon(
                  leading,
                  size: 18,
                  color: selected
                      ? AppColors.ink
                      : AppColors.inkMute,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppType.bodyLg.copyWith(color: AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
