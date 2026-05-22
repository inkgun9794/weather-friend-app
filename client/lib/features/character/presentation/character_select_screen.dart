import 'package:flutter/material.dart';

class CharacterSelectScreen extends StatelessWidget {
  const CharacterSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('캐릭터 선택')),
      body: const Center(child: Text('Character — TODO')),
    );
  }
}
