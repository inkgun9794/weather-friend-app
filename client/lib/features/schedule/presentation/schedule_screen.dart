import 'package:flutter/material.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: ListView(
        children: const [
          ListTile(
            title: Text('알림 시간'),
            subtitle: Text('오전 5시 · 오후 9시 (고정)'),
          ),
        ],
      ),
    );
  }
}
