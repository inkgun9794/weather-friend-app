import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_screen.dart';
import 'package:weather_friend/features/character/presentation/character_select_screen.dart';
import 'package:weather_friend/features/location/presentation/onboarding_screen.dart';
import 'package:weather_friend/features/schedule/presentation/schedule_screen.dart';
import 'package:weather_friend/features/settings/presentation/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const BriefingScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/character',
        builder: (_, _) => const CharacterSelectScreen(),
      ),
      GoRoute(
        path: '/schedule',
        builder: (_, _) => const ScheduleScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
      ),
    ],
  );
});
