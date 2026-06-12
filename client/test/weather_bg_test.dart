import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_friend/shared/widgets/weather_bg.dart';

void main() {
  Widget wrap(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: child,
      ),
    );
  }

  testWidgets('비 조건 → 애니메이션 강수 레이어가 붙고 프레임이 진행된다', (tester) async {
    await tester.pumpWidget(
      wrap(const WeatherBg(hour: 15, condition: WeatherCondition.rain)),
    );
    expect(find.byType(PrecipitationLayer), findsOneWidget);
    expect(find.byKey(const Key('rain-anim')), findsOneWidget);

    // repeat 애니메이션이라 pumpAndSettle은 금지 — 프레임만 전진시켜 크래시 없음 확인.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('눈 조건 → 눈 레이어', (tester) async {
    await tester.pumpWidget(
      wrap(const WeatherBg(hour: 9, condition: WeatherCondition.snow)),
    );
    expect(find.byKey(const Key('snow-anim')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('맑음/흐림 → 강수 레이어 없음', (tester) async {
    await tester.pumpWidget(
      wrap(const WeatherBg(hour: 12, condition: WeatherCondition.clear)),
    );
    expect(find.byType(PrecipitationLayer), findsNothing);

    await tester.pumpWidget(
      wrap(const WeatherBg(hour: 12, condition: WeatherCondition.cloudy)),
    );
    expect(find.byType(PrecipitationLayer), findsNothing);
    // 애니메이션이 없으니 settle 가능해야 한다 (무한 ticker 누수 방지 확인).
    await tester.pumpAndSettle();
  });

  testWidgets('모션 최소화 설정 → 정적 빗줄기 폴백', (tester) async {
    await tester.pumpWidget(
      wrap(
        const WeatherBg(hour: 15, condition: WeatherCondition.rain),
        disableAnimations: true,
      ),
    );
    expect(find.byKey(const Key('static-rain')), findsOneWidget);
    expect(find.byKey(const Key('rain-anim')), findsNothing);
    await tester.pumpAndSettle(); // 정적이라 settle돼야 함
  });

  testWidgets('조건 변경(비→눈) 시 레이어 교체', (tester) async {
    await tester.pumpWidget(
      wrap(const WeatherBg(hour: 15, condition: WeatherCondition.rain)),
    );
    expect(find.byKey(const Key('rain-anim')), findsOneWidget);

    await tester.pumpWidget(
      wrap(const WeatherBg(hour: 15, condition: WeatherCondition.snow)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('snow-anim')), findsOneWidget);
    expect(find.byKey(const Key('rain-anim')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
