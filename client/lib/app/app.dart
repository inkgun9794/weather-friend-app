import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_friend/app/router/app_router.dart';
import 'package:weather_friend/app/theme/app_theme.dart';
import 'package:weather_friend/core/services/location_coordinator.dart';
import 'package:weather_friend/core/services/notification_coordinator.dart';
import 'package:weather_friend/features/record/presentation/record_reminder_coordinator.dart';

class WeatherFriendApp extends ConsumerWidget {
  const WeatherFriendApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LocationCoordinator(
      child: NotificationCoordinator(
        child: RecordReminderCoordinator(
          child: MaterialApp.router(
            title: '날사친',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            routerConfig: ref.watch(appRouterProvider),
            debugShowCheckedModeBanner: false,
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
      ),
    );
  }
}
