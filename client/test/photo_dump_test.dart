import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/app/theme/design_tokens.dart';
import 'package:weather_friend/features/record/domain/diary_entry.dart';
import 'package:weather_friend/features/record/presentation/widgets/photo_dump.dart';

void main() {
  testWidgets('spreads photos full screen and collects them on the next tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final entries = [
      DiaryEntry(
        id: '1',
        createdAt: DateTime(2026, 6, 10),
        imagePath: '/missing/one.jpg',
        title: '',
        content: '',
      ),
      DiaryEntry(
        id: '2',
        createdAt: DateTime(2026, 6, 9),
        imagePath: '/missing/two.jpg',
        title: '',
        content: '',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoDumpLauncher(entries: entries, sky: skyFor(12)),
        ),
      ),
    );

    expect(find.byKey(const Key('photo-dump-launcher')), findsOneWidget);
    expect(find.byKey(const Key('photo-dump-canvas')), findsNothing);
    expect(find.text('하늘 포토덤프'), findsNothing);
    expect(find.textContaining('눌러서 흩뿌리고'), findsNothing);

    await tester.tap(find.byKey(const Key('photo-dump-launcher')));
    await tester.pump();
    final firstPhoto = find.byKey(const ValueKey('photo-dump-photo-1'));
    final stackedPosition = tester.getTopLeft(firstPhoto);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byKey(const Key('photo-dump-canvas')), findsOneWidget);
    expect(firstPhoto, findsOneWidget);
    expect(find.byKey(const ValueKey('photo-dump-photo-2')), findsOneWidget);
    final spreadPosition = tester.getTopLeft(firstPhoto);
    expect((spreadPosition - stackedPosition).distance, greaterThan(50));

    await tester.tap(find.byKey(const Key('photo-dump-canvas')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const Key('photo-dump-canvas')), findsNothing);
    expect(find.byKey(const Key('photo-dump-launcher')), findsOneWidget);
  });
}
