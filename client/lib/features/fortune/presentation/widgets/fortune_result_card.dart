import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saju/saju.dart' as saju;
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/fortune/data/fortune_api.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';

/// 사주 원국 + 오늘의 운세 카드. profile을 인자로 받아서 누구 사주든 표시.
/// (내 프로필 / 게스트 / 리포트에서 선택한 것 다)
class FortuneResultCard extends ConsumerWidget {
  const FortuneResultCard({super.key, required this.profile});

  final SajuProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = computeSajuFor(profile);
    if (result == null) {
      return const _ErrorCard(message: '사주 계산에 실패했어요. 다시 시도해주세요.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SajuPillarsCard(profile: profile, result: result),
        const SizedBox(height: 16),
        _DayMasterCard(result: result),
        const SizedBox(height: 16),
        _ElementsCard(result: result),
        const SizedBox(height: 16),
        _FortuneSections(profile: profile),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────

/// 사주 원국 4기둥 표 (시 / 일 / 월 / 년 순서 — 전통 명리학 배열).
class _SajuPillarsCard extends StatelessWidget {
  const _SajuPillarsCard({required this.profile, required this.result});

  final SajuProfile profile;
  final saju.SajuResult result;

  @override
  Widget build(BuildContext context) {
    final pillars = result.pillars;
    // 명리학 전통: 시주 - 일주 - 월주 - 연주 순으로 표시
    final cols = <(String, saju.Pillar)>[
      ('시주', pillars.hour),
      ('일주', pillars.day),
      ('월주', pillars.month),
      ('연주', pillars.year),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('사주 원국', subtitle: _birthLabel(profile)),
          const SizedBox(height: 16),
          // 헤더 (시 / 일 / 월 / 년)
          Row(
            children: [
              for (final (label, _) in cols)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMute,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 천간 row
          Row(
            children: [
              for (final (_, p) in cols)
                Expanded(child: _GanZhiCell(stem: p.stem)),
            ],
          ),
          const SizedBox(height: 4),
          // 지지 row
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
    return '$cal ${p.year}.${p.month.toString().padLeft(2, '0')}.${p.day.toString().padLeft(2, '0')} ${p.hour.toString().padLeft(2, '0')}:00 · ${p.gender.label}';
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            stem.hanja,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stem.korean,
            style: TextStyle(
              fontSize: 11,
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            branch.hanja,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${branch.korean}·${_zodiacKo(branch.zodiac)}',
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

/// 일간 + 신강신약 + 용신.
class _DayMasterCard extends StatelessWidget {
  const _DayMasterCard({required this.result});
  final saju.SajuResult result;

  @override
  Widget build(BuildContext context) {
    final dm = result.pillars.dayMaster;
    final dmColor = _elementColor(dm.element);
    final strength = result.strength;
    final yongShen = result.yongShen;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('일간 · 강약 · 용신'),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: dmColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  dm.hanja,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: dmColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dm.korean}일간 (${dm.element.korean}·${dm.polarity.korean})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strength.level.korean,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.paper2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _miniChip('용신', yongShen.primary.korean,
                        _elementColor(yongShen.primary)),
                    if (yongShen.secondary != null) ...[
                      const SizedBox(width: 8),
                      _miniChip('희신', yongShen.secondary!.korean,
                          _elementColor(yongShen.secondary!)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  yongShen.reasoning,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 오행 분포 막대 그래프.
class _ElementsCard extends StatelessWidget {
  const _ElementsCard({required this.result});
  final saju.SajuResult result;

  @override
  Widget build(BuildContext context) {
    // 천간 4 + 지지 4 = 8자 기준 단순 카운트 (가중치 무시 — MVP).
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

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('오행 분포'),
          const SizedBox(height: 14),
          for (final e in saju.Element.values) ...[
            _ElementBar(
              element: e,
              count: counts[e]!,
              maxCount: maxCount > 0 ? maxCount : 1,
            ),
            const SizedBox(height: 10),
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
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.paper2,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(
                  height: 10,
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

/// 오늘의 운세 — Cloud Run (Gemini) 호출 결과 표시. profile 인자로 family provider 호출.
/// 운세 텍스트를 ## 헤딩 단위로 분리해서 섹션마다 별도 카드로 렌더.
/// 로딩/에러는 단일 카드.
class _FortuneSections extends ConsumerWidget {
  const _FortuneSections({required this.profile});

  final SajuProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFortune = ref.watch(fortuneForProfileProvider(profile));

    return asyncFortune.when(
      loading: () => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle('오늘의 운세', subtitle: _todayLabel()),
            const SizedBox(height: 14),
            const _LoadingState(),
          ],
        ),
      ),
      error: (e, _) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle('오늘의 운세', subtitle: _todayLabel()),
            const SizedBox(height: 14),
            _ErrorState(
              message: e is FortuneApiException ? e.message : '운세를 불러올 수 없어요',
              onRetry: () =>
                  ref.invalidate(fortuneForProfileProvider(profile)),
            ),
          ],
        ),
      ),
      data: (fortune) {
        final sections = _parseSections(fortune.text);
        if (sections.isEmpty) {
          // 파서 실패 폴백 — 한 카드에 raw markdown
          return _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardTitle('오늘의 운세', subtitle: _todayLabel()),
                const SizedBox(height: 14),
                _FortuneMarkdown(text: fortune.text),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              _SectionCard(
                section: sections[i],
                subtitle: i == 0 ? _todayLabel() : null,
              ),
              if (i < sections.length - 1) const SizedBox(height: 12),
            ],
          ],
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

/// 파싱된 한 섹션 = { title, body }.
class _Section {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;
}

/// `## 제목` 단위로 분리. '총평' → '오늘의 운세'로 자동 매핑.
/// '영역별 운' 같은 wrapper 헤딩은 무시 (옛 응답 호환).
/// 첫 ## 이전의 도입 인사말 무시.
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
      var title = line.substring(3).trim();
      if (title == '총평') title = '오늘의 운세';
      if (title == '영역별 운') {
        currentTitle = null; // wrapper 무시
        continue;
      }
      currentTitle = title;
    } else if (currentTitle == null) {
      continue; // 도입 인사말 등 무시
    } else {
      if (body.isNotEmpty) body.write('\n');
      body.write(line);
    }
  }
  flush();
  return sections;
}

/// 한 섹션을 카드로 렌더. 첫 카드는 subtitle에 날짜 표시.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, this.subtitle});
  final _Section section;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(section.title, subtitle: subtitle),
          const SizedBox(height: 12),
          _SectionBody(text: section.body),
        ],
      ),
    );
  }
}

/// 섹션 본문 — 단락 + 글머리표(`- `) + **bold** 처리.
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
        widgets.add(Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in bullets) _BulletItem(text: item),
          ],
        ));
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
        if (paraBuf.isNotEmpty) paraBuf.write('\n');
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
          fontSize: 14,
          height: 1.7,
          color: AppColors.inkSoft,
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
      spans.add(TextSpan(
        text: m.group(1),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ));
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, right: 10),
            child: Container(
              width: 4, height: 4,
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
            width: 28, height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '사주를 분석하고 있어요...',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.inkMute,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '5~10초 정도 걸려요',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.inkFaint,
            ),
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
        color: AppColors.paper2,
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
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.inkSoft,
                  ),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

/// `## 헤딩` + 본문 + `**bold**` 정도만 처리하는 경량 markdown renderer.
/// (flutter_markdown 의존성 안 끌어오려고 인라인 구현.)
class _FortuneMarkdown extends StatelessWidget {
  const _FortuneMarkdown({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          _renderBlock(blocks[i]),
          if (i < blocks.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _renderBlock(_Block b) {
    if (b.headingLevel > 0) {
      // 헤딩 레벨별 다른 폰트 크기. ## = 큰 섹션, ### = 작은 소제목
      final fontSize = b.headingLevel <= 2 ? 15.0 : 14.0;
      final topPad = b.headingLevel <= 2 ? 8.0 : 6.0;
      return Padding(
        padding: EdgeInsets.only(top: topPad, bottom: 4),
        child: Text(
          b.text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.2,
          ),
        ),
      );
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          height: 1.7,
          color: AppColors.inkSoft,
        ),
        children: _parseInline(b.text),
      ),
    );
  }

  /// `# / ## / ###` 헤딩 모두 처리. 같은 섹션 안 여러 문단은 한 블록.
  List<_Block> _parseBlocks(String input) {
    final lines = input.split('\n');
    final blocks = <_Block>[];
    final buffer = StringBuffer();

    void flushBody() {
      final s = buffer.toString().trim();
      if (s.isNotEmpty) {
        blocks.add(_Block(text: s, headingLevel: 0));
      }
      buffer.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.startsWith('### ')) {
        flushBody();
        blocks.add(_Block(text: line.substring(4).trim(), headingLevel: 3));
      } else if (line.startsWith('## ')) {
        flushBody();
        blocks.add(_Block(text: line.substring(3).trim(), headingLevel: 2));
      } else if (line.startsWith('# ')) {
        flushBody();
        blocks.add(_Block(text: line.substring(2).trim(), headingLevel: 1));
      } else {
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(line);
      }
    }
    flushBody();
    return blocks;
  }

  /// `**bold**` 파싱. 다른 인라인 마크다운은 무시.
  List<TextSpan> _parseInline(String input) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var last = 0;
    for (final m in pattern.allMatches(input)) {
      if (m.start > last) {
        spans.add(TextSpan(text: input.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ));
      last = m.end;
    }
    if (last < input.length) {
      spans.add(TextSpan(text: input.substring(last)));
    }
    return spans;
  }
}

class _Block {
  const _Block({required this.text, required this.headingLevel});
  final String text;
  final int headingLevel; // 0=본문, 1=#, 2=##, 3=###
}

// ─────────────────────────────────────────────────────────────────
// Shared building blocks
// ─────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.inkMute.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
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
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMute,
            ),
          ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.inkMute, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────

/// 오행별 색상 — 전통적 매핑 (木青·火赤·土黃·金白(灰)·水黑(藍))을 부드러운 톤으로.
Color _elementColor(saju.Element element) {
  switch (element) {
    case saju.Element.wood:
      return const Color(0xFF15803D); // green-700
    case saju.Element.fire:
      return const Color(0xFFDC2626); // red-600
    case saju.Element.earth:
      return const Color(0xFFB45309); // amber-700
    case saju.Element.metal:
      return const Color(0xFF64748B); // slate-500
    case saju.Element.water:
      return const Color(0xFF0369A1); // sky-700
  }
}

/// 띠 영문 → 한국어. saju 패키지가 Branch.zodiac에 영문으로 주는 걸 한글화.
String _zodiacKo(String en) {
  switch (en) {
    case 'Rat': return '쥐';
    case 'Ox': return '소';
    case 'Tiger': return '호랑이';
    case 'Rabbit': return '토끼';
    case 'Dragon': return '용';
    case 'Snake': return '뱀';
    case 'Horse': return '말';
    case 'Goat': return '양';
    case 'Monkey': return '원숭이';
    case 'Rooster': return '닭';
    case 'Dog': return '개';
    case 'Pig': return '돼지';
    default: return en;
  }
}
