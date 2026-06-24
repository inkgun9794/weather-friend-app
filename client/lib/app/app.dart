import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/app/router/app_router.dart';
import 'package:weather_friend/app/theme/app_theme.dart';
import 'package:weather_friend/core/services/location_coordinator.dart';
import 'package:weather_friend/core/services/notification_coordinator.dart';

class WeatherFriendApp extends ConsumerWidget {
  const WeatherFriendApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LocationCoordinator(
      child: NotificationCoordinator(
        child: MaterialApp.router(
          title: '날사친',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          routerConfig: ref.watch(appRouterProvider),
          debugShowCheckedModeBanner: false,
          scrollBehavior: const _AppScrollBehavior(),
          // DatePicker가 한글 표시되려면 MaterialLocalizations(ko) 필요.
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
          locale: const Locale('ko', 'KR'),
        ),
      ),
    );
  }
}

/// 안드로이드 12+ stretch 오버스크롤은 화면을 레이어로 떠서 늘이는데, 그동안
/// BackdropFilter(글래스 카드·칩)가 진짜 배경을 못 읽어 최상단에서 잠깐 딤처럼
/// 보인다. 오버스크롤 인디케이터를 없애 가장자리에서 그냥 멈추게 한다.
/// (iOS 바운스는 physics 기반이라 영향 없음.)
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
