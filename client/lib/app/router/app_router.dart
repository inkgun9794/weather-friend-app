import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_screen.dart';
import 'package:weather_friend/features/briefing/presentation/conversation_screen.dart';
import 'package:weather_friend/features/character/presentation/character_select_screen.dart';
import 'package:weather_friend/features/location/data/onboarding_provider.dart';
import 'package:weather_friend/features/location/presentation/onboarding_screen.dart';
import 'package:weather_friend/features/schedule/presentation/schedule_screen.dart';
import 'package:weather_friend/features/settings/presentation/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // 첫 실행이면 /onboarding으로. 완료 후엔 일반 라우팅.
      final isOnboarded = ref.read(onboardingCompleteProvider);
      final goingToOnboarding = state.matchedLocation == '/onboarding';
      if (!isOnboarded && !goingToOnboarding) {
        return '/onboarding';
      }
      if (isOnboarded && goingToOnboarding) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const BriefingScreen(),
      ),
      GoRoute(
        path: '/conversation',
        builder: (_, _) => const ConversationScreen(),
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
