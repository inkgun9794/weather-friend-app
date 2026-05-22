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
        ],
      ),
    );
  }
}
