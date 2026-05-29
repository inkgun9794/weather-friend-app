import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/fortune/data/fortune_report.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';

/// 오늘 본 운세 리포트 목록 화면. /fortune/report.
/// 자정 reset 됨. 탭하면 해당 결과 재표시 (광고 없이, 캐시).
class FortuneReportScreen extends ConsumerWidget {
  const FortuneReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncReports = ref.watch(fortuneReportsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '오늘 본 운세 리포트',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.3,
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.ink),
      ),
      body: asyncReports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('리포트를 불러올 수 없어요: $e',
              style: TextStyle(color: AppColors.inkSoft)),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '오늘 본 운세가 없어요',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.inkMute,
                  ),
                ),
              ),
            );
          }
          // 가장 최근에 본 게 위로
          final sorted = [...reports]
            ..sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ReportTile(report: sorted[i]),
          );
        },
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});
  final FortuneReport report;

  @override
  Widget build(BuildContext context) {
    final p = report.profile;
    final cal = p.isLunar ? '음력' : '양력';
    final birthLine =
        '$cal ${p.year}.${p.month.toString().padLeft(2, '0')}.${p.day.toString().padLeft(2, '0')} '
        '${p.hour.toString().padLeft(2, '0')}:00 · ${p.gender.label}';
    final viewedTime =
        '${report.viewedAt.hour.toString().padLeft(2, '0')}:${report.viewedAt.minute.toString().padLeft(2, '0')}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        // 해당 프로필로 결과 화면 다시 진입 (캐시된 운세 표시)
        onTap: () => context.go('/fortune', extra: p),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.inkMute.withValues(alpha: 0.18),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.inkMute.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            p.relation.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$viewedTime 봄',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      birthLine,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMute,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
