import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/core/services/fcm_service.dart';
import 'package:weather_friend/core/services/notification_service.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_providers.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  bool? _hasPermission;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final ok = await ref.read(fcmServiceProvider).hasPermission();
    if (!mounted) return;
    setState(() => _hasPermission = ok);
  }

  Future<void> _requestPermission() async {
    setState(() => _busy = true);
    final fcm = ref.read(fcmServiceProvider);
    final ok = await fcm.requestPermissions();
    if (ok) {
      await fcm.syncSubscriptions(ref.read(selectedCharacterProvider));
    }
    if (!mounted) return;
    setState(() {
      _hasPermission = ok;
      _busy = false;
    });
    _toast(ok ? '알림이 켜졌어요' : '알림 권한이 거절됐어요');
  }

  Future<void> _resync() async {
    setState(() => _busy = true);
    final fcm = ref.read(fcmServiceProvider);
    await fcm.syncSubscriptions(ref.read(selectedCharacterProvider));
    if (!mounted) return;
    setState(() => _busy = false);
    _toast('현재 캐릭터 토픽을 다시 구독했어요');
  }

  Future<void> _sendTest() async {
    await ref.read(notificationServiceProvider).showTestNotification();
    _toast('테스트 알림을 보냈어요');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permission = _hasPermission;
    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('알림 시간'),
            subtitle: Text('오전 5시 · 오후 9시 (고정)'),
          ),
          const Divider(height: 0),
          ListTile(
            title: const Text('권한 상태'),
            subtitle: Text(
              permission == null
                  ? '확인 중…'
                  : (permission ? '허용됨' : '거절됨 — 설정에서 켤 수 있어요'),
            ),
            trailing: permission == false
                ? FilledButton(
                    onPressed: _busy ? null : _requestPermission,
                    child: const Text('권한 요청'),
                  )
                : null,
          ),
          const Divider(height: 0),
          ListTile(
            title: const Text('토픽 재구독'),
            subtitle: const Text('선택한 캐릭터의 morning/evening 토픽을 다시 구독'),
            onTap: _busy || permission != true ? null : _resync,
            trailing: const Icon(Icons.refresh),
          ),
          const Divider(height: 0),
          ListTile(
            title: const Text('테스트 알림 보내기'),
            subtitle: const Text('즉시 알림 한 번 발사해 동작을 확인해요'),
            onTap: _busy || permission != true ? null : _sendTest,
            trailing: const Icon(Icons.notifications_active_outlined),
          ),
        ],
      ),
    );
  }
}
