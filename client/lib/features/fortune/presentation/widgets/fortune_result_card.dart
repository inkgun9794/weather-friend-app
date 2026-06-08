import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saju/saju.dart' as saju;
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/fortune/data/fortune_api.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';

// ─────────────────────────────────────────────────────────────────
// Public widgets
// ─────────────────────────────────────────────────────────────────

/// 날씨 앱에서 빠르게 읽는 세 가지 핵심 운세.
///   ## 오늘의 운세 / 챙길 점 / 한 줄 조언
class FortuneTodayCards extends ConsumerWidget {
  const FortuneTodayCards({super.key, required this.profile});

  final SajuProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFortune = ref.watch(fortuneForProfileProvider(profile));

    return asyncFortune.when(
      loading: () => _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle('오늘의 운세', subtitle: _todayLabel()),
            const SizedBox(height: 14),
            const _LoadingState(),
          ],
        ),
      ),
      error: (e, _) => _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle('오늘의 운세', subtitle: _todayLabel()),
            const SizedBox(height: 14),
            _ErrorState(
              message: e is FortuneApiException ? e.message : '운세를 불러올 수 없어요',
              onRetry: () => ref.invalidate(fortuneForProfileProvider(profile)),
            ),
          ],
        ),
      ),
      data: (fortune) {
        final sections = _selectConciseSections(fortune.text);
        if (sections.isEmpty) {
          return _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardTitle('오늘의 운세', subtitle: _todayLabel()),
                const SizedBox(height: 14),
                _SectionBody(text: fortune.text),
              ],
            ),
          );
        }
        return _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle('오늘의 운세', subtitle: _todayLabel()),
              const SizedBox(height: 12),
              for (var i = 0; i < sections.length; i++) ...[
                _ConciseSection(section: sections[i]),
                if (i < sections.length - 1) ...[
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: AppColors.ink.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  static String _todayLabel() {
    final d = DateTime.now();
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

/// 사주 원국 + 오행 분포 — 화면 하단 "참고" 영역.
class SajuReferenceCards extends StatelessWidget {
  const SajuReferenceCards({super.key, required this.profile});

  final SajuProfile profile;

  @override
  Widget build(BuildContext context) {
    final result = computeSajuFor(profile);
    if (result == null) {
      return _GlassCard(
        child: Text(
          '사주 계산에 실패했어요',
          style: TextStyle(color: AppColors.inkMute, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppColors.inkMute,
              ),
              const SizedBox(width: 6),
              Text(
                '참고 — 사주 자료',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkMute,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
        _SajuPillarsCard(profile: profile, result: result),
        const SizedBox(height: 12),
        _ElementsCard(result: result),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Saju cards (참고)
// ─────────────────────────────────────────────────────────────────

class _SajuPillarsCard extends StatelessWidget {
  const _SajuPillarsCard({required this.profile, required this.result});

  final SajuProfile profile;
  final saju.SajuResult result;

  @override
  Widget build(BuildContext context) {
    final pillars = result.pillars;
    // 시 - 일 - 월 - 년 (전통 명리학 배열)
    final cols = <(String, saju.Pillar)>[
      ('시', pillars.hour),
      ('일', pillars.day),
      ('월', pillars.month),
      ('년', pillars.year),
    ];

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('사주 원국', subtitle: _birthLabel(profile)),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (label, _) in cols)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMute,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final (_, p) in cols)
                Expanded(child: _GanZhiCell(stem: p.stem)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final (_, p) in cols)
                Expanded(child: _BranchCell(branch: p.branch)),
            ],
          ),
        ],
      ),
    );
  }

  String _birthLabel(SajuProfile p) {
    final cal = p.isLunar ? '음력' : '양력';
    return '$cal ${p.year}.${p.month.toString().padLeft(2, '0')}.${p.day.toString().padLeft(2, '0')} '
        '${p.hour.toString().padLeft(2, '0')}:${p.minute.toString().padLeft(2, '0')} · ${p.gender.label}';
  }
}

class _GanZhiCell extends StatelessWidget {
  const _GanZhiCell({required this.stem});
  final saju.Stem stem;

  @override
  Widget build(BuildContext context) {
    final color = _elementColor(stem.element);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            stem.hanja,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stem.korean,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchCell extends StatelessWidget {
  const _BranchCell({required this.branch});
  final saju.Branch branch;

  @override
  Widget build(BuildContext context) {
    final color = _elementColor(branch.element);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            branch.hanja,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${branch.korean}·${_zodiacKo(branch.zodiac)}',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _ElementsCard extends StatelessWidget {
  const _ElementsCard({required this.result});
  final saju.SajuResult result;

  @override
  Widget build(BuildContext context) {
    final counts = <saju.Element, int>{
      for (final e in saju.Element.values) e: 0,
    };
    for (final s in result.pillars.stems) {
      counts[s.element] = counts[s.element]! + 1;
    }
    for (final b in result.pillars.branches) {
      counts[b.element] = counts[b.element]! + 1;
    }
    final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b);

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('오행 분포'),
          const SizedBox(height: 12),
          for (final e in saju.Element.values) ...[
            _ElementBar(
              element: e,
              count: counts[e]!,
              maxCount: maxCount > 0 ? maxCount : 1,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ElementBar extends StatelessWidget {
  const _ElementBar({
    required this.element,
    required this.count,
    required this.maxCount,
  });

  final saju.Element element;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final color = _elementColor(element);
    final ratio = count / maxCount;
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            '${element.hanja} ${element.korean}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.inkMute.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 20,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Section parsing + rendering
// ─────────────────────────────────────────────────────────────────

class _Section {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;
}

/// `## 제목` 단위로 분리.
/// '영역별 운' 같은 wrapper 헤딩 무시. 첫 ## 이전 도입 인사말 무시.
List<_Section> _parseSections(String raw) {
  final lines = raw.split('\n');
  final sections = <_Section>[];
  String? currentTitle;
  final body = StringBuffer();

  void flush() {
    final t = currentTitle;
    if (t != null) {
      sections.add(_Section(title: t, body: body.toString().trim()));
      body.clear();
    }
  }

  for (final raw in lines) {
    final line = raw.trimRight();
    if (line.startsWith('## ')) {
      flush();
      final title = _normalizeSectionTitle(line.substring(3).trim());
      if (title == '영역별 운') {
        currentTitle = null;
        continue;
      }
      currentTitle = title;
    } else if (currentTitle == null) {
      continue;
    } else {
      if (body.isNotEmpty) body.write('\n');
      body.write(line);
    }
  }
  flush();
  return sections;
}

String _normalizeSectionTitle(String title) {
  return switch (title.replaceAll(' ', '')) {
    '총평' || '오늘의운세' => '오늘의 운세',
    '챙길점' => '챙길 점',
    '한줄조언' => '한 줄 조언',
    _ => title,
  };
}

List<_Section> _selectConciseSections(String raw) {
  const order = ['오늘의 운세', '챙길 점', '한 줄 조언'];
  final parsed = _parseSections(raw);
  if (parsed.isEmpty) return const [];

  final byTitle = <String, _Section>{};
  for (final section in parsed) {
    final title = _normalizeSectionTitle(section.title);
    if (order.contains(title) && section.body.trim().isNotEmpty) {
      byTitle.putIfAbsent(
        title,
        () => _Section(title: title, body: section.body),
      );
    }
  }
  return [for (final title in order) ?byTitle[title]];
}

class _ConciseSection extends StatelessWidget {
  const _ConciseSection({required this.section});
  final _Section section;

  @override
  Widget build(BuildContext context) {
    final showTitle = section.title != '오늘의 운세';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            section.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.inkMute,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 6),
        ],
        _SectionBody(text: section.body),
      ],
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          blocks[i],
          if (i < blocks.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  List<Widget> _parseBlocks(String text) {
    final lines = text.split('\n');
    final widgets = <Widget>[];
    final paraBuf = StringBuffer();
    final bullets = <String>[];

    void flushPara() {
      final s = paraBuf.toString().trim();
      if (s.isNotEmpty) widgets.add(_Paragraph(text: s));
      paraBuf.clear();
    }

    void flushBullets() {
      if (bullets.isNotEmpty) {
        widgets.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final item in bullets) _BulletItem(text: item)],
          ),
        );
        bullets.clear();
      }
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('- ') || line.startsWith('* ')) {
        flushPara();
        bullets.add(line.substring(2).trim());
      } else if (line.isEmpty) {
        flushPara();
        flushBullets();
      } else {
        flushBullets();
        if (paraBuf.isNotEmpty) paraBuf.write(' ');
        paraBuf.write(line);
      }
    }
    flushPara();
    flushBullets();

    return widgets;
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14.5,
          height: 1.65,
          color: AppColors.ink,
          letterSpacing: -0.1,
        ),
        children: _parseInline(text),
      ),
    );
  }

  List<TextSpan> _parseInline(String input) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var last = 0;
    for (final m in pattern.allMatches(input)) {
      if (m.start > last) {
        spans.add(TextSpan(text: input.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
      );
      last = m.end;
    }
    if (last < input.length) {
      spans.add(TextSpan(text: input.substring(last)));
    }
    return spans;
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, right: 10),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.inkMute,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: _Paragraph(text: text)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Loading / Error states
// ─────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '오늘의 운세를 준비하고 있어요...',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.inkMute,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '5~10초 정도 걸려요',
            style: TextStyle(fontSize: 11, color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inkMute.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: AppColors.inkMute,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('다시 시도'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Shared building blocks — 글래스 카드 (날씨 탭과 동일 톤)
// ─────────────────────────────────────────────────────────────────

/// 반투명 흰색 + backdrop blur. WeatherBg 위에 얹혔을 때 글래스 효과.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title, {this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMute,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────

Color _elementColor(saju.Element element) {
  switch (element) {
    case saju.Element.wood:
      return const Color(0xFF15803D);
    case saju.Element.fire:
      return const Color(0xFFDC2626);
    case saju.Element.earth:
      return const Color(0xFFB45309);
    case saju.Element.metal:
      return const Color(0xFF64748B);
    case saju.Element.water:
      return const Color(0xFF0369A1);
  }
}

String _zodiacKo(String en) {
  switch (en) {
    case 'Rat':
      return '쥐';
    case 'Ox':
      return '소';
    case 'Tiger':
      return '호랑이';
    case 'Rabbit':
      return '토끼';
    case 'Dragon':
      return '용';
    case 'Snake':
      return '뱀';
    case 'Horse':
      return '말';
    case 'Goat':
      return '양';
    case 'Monkey':
      return '원숭이';
    case 'Rooster':
      return '닭';
    case 'Dog':
      return '개';
    case 'Pig':
      return '돼지';
    default:
      return en;
  }
}
