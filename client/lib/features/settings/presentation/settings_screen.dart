import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.face_outlined),
            title: const Text('캐릭터'),
            onTap: () => context.push('/character'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('알림'),
            onTap: () => context.push('/schedule'),
          ),
          const Divider(height: 32),
          const _DataAttribution(),
        ],
      ),
    );
  }
}

/// 데이터 출처 표시 (공공누리 제1유형 의무 준수).
/// 기상청 데이터를 활용하는 모든 앱이 이 정보를 표기해야 함.
class _DataAttribution extends StatelessWidget {
  const _DataAttribution();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '데이터 출처',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _Source(
            icon: Icons.cloud_outlined,
            title: '기상청',
            subtitle: '단기·중기·초단기 예보',
            tail: 'data.go.kr · apihub.kma.go.kr',
            muted: muted,
          ),
          const SizedBox(height: 10),
          _Source(
            icon: Icons.public,
            title: 'Open-Meteo',
            subtitle: '백업 (기상청 데이터 일시 사용 불가 시)',
            tail: 'open-meteo.com',
            muted: muted,
          ),
          const SizedBox(height: 10),
          _Source(
            icon: Icons.map_outlined,
            title: '한국 행정구역 outline',
            subtitle: '비구름 지도 시·군·구 경계',
            tail: 'github.com/southkorea/southkorea-maps · BSD License',
            muted: muted,
          ),
          const SizedBox(height: 16),
          Text(
            '기상청 자료는 공공누리 제1유형(출처표시)에 따라 제공받아 사용 중.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _Source extends StatelessWidget {
  const _Source({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tail,
    required this.muted,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String tail;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 2),
              Text(
                tail,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
