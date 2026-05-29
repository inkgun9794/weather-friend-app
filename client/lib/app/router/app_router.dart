import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:weather_friend/app/router/main_shell.dart';
import 'package:weather_friend/features/briefing/presentation/briefing_screen.dart';
import 'package:weather_friend/features/briefing/presentation/conversation_screen.dart';
import 'package:weather_friend/features/character/presentation/character_select_screen.dart';
import 'package:weather_friend/features/fortune/data/saju_profile.dart';
import 'package:weather_friend/features/fortune/presentation/fortune_report_screen.dart';
import 'package:weather_friend/features/fortune/presentation/fortune_screen.dart';
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
      // 하단바를 가지는 두 메인 탭. 각 브랜치가 자기 navigator를 가지므로
      // 탭 사이를 오갈 때 스크롤/상태가 유지됨.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const BriefingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                builder: (_, _) => const ConversationScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/fortune',
                builder: (_, state) {
                  // 리포트에서 특정 프로필 클릭 시 extra로 받음
                  final extra = state.extra;
                  return FortuneScreen(
                    initialProfile: extra is SajuProfile ? extra : null,
                  );
                },
              ),
            ],
          ),
        ],
      ),
      // 셸 바깥 — push하면 하단바를 덮는 전체 화면으로 뜸.
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
      GoRoute(
        path: '/fortune/report',
        builder: (_, _) => const FortuneReportScreen(),
      ),
      // /radar 라우트 일단 제거 — 비구름 이동 예측 화면 보류 상태.
      // 다시 활성화하려면 radar_screen.dart import + GoRoute 복귀.
    ],
  );
});
