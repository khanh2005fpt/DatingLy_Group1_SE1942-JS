import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../data/repositories/setting_repository.dart';
import 'Views/Screen/welcome_screen.dart';
import 'Views/Screen/login_screen.dart';
import 'Views/Screen/register_screen.dart';
import 'Views/Screen/onboarding_screen.dart';
import 'Views/Screen/discovery_screen.dart';
import 'Views/Screen/discovery_filter_screen.dart';
import 'Views/Screen/who_liked_me_screen.dart';
import 'Views/Screen/notification_center_screen.dart';
import 'Views/Screen/history_rewind_screen.dart';
import 'Views/Screen/match_list_screen.dart';
import 'Views/Screen/chat_screen.dart';
import 'Views/Screen/mini_game_screen.dart';
import 'Views/Screen/profile_screen.dart';
import 'Views/Screen/edit_profile_screen.dart';
import 'Views/Screen/account_settings_screen.dart';
import 'Views/Screen/safety_screen.dart';
import 'Views/Screen/media_gallery_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final path = state.matchedLocation;
      final isAuthPage = path == '/login' || path == '/register';

      // 1. Chưa đăng nhập: lần đầu mở app thì xem màn chào trước
      if (!loggedIn) {
        final isFirstTime =
            SettingRepository.instance?.isFirstTimeUser ?? false;
        if (path == '/welcome') return isFirstTime ? null : '/login';
        if (isFirstTime) return '/welcome';
        return isAuthPage ? null : '/login';
      }

      // 2. Đã đăng nhập: Kiểm tra trạng thái Onboarding (từ SettingRepository)
      final onboardingCompleted =
          SettingRepository.instance?.onboardingCompleted ?? false;

      if (!onboardingCompleted) {
        return path == '/onboarding' ? null : '/onboarding';
      }

      // 3. Đã đăng nhập & hoàn tất onboarding
      if (isAuthPage || path == '/onboarding' || path == '/welcome') {
        return '/discovery';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/discovery',
        builder: (context, state) => const DiscoveryScreen(),
      ),
      GoRoute(
        path: '/likes',
        builder: (context, state) => const WhoLikedMeScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: '/history-rewind',
        builder: (context, state) => const HistoryRewindScreen(),
      ),
      GoRoute(
        path: '/discovery/filter',
        builder: (context, state) => const DiscoveryFilterScreen(),
      ),
      GoRoute(
        path: '/matches',
        builder: (context, state) => const MatchListScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?;
          return ChatScreen(
            matchId: id,
            otherUserName: extra?['otherUserName'] as String?,
            otherAvatarUrl: extra?['otherAvatarUrl'] as String?,
            otherBio: extra?['otherBio'] as String?,
            otherTags: extra?['otherTags'] != null
                ? List<String>.from(extra!['otherTags'])
                : null,
          );
        },
      ),
      GoRoute(
        path: '/minigame',
        builder: (context, state) => const MiniGameScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) {
          final profile = state.extra as Map<String, dynamic>?;
          return EditProfileScreen(initialProfile: profile);
        },
      ),
      // ─── Module 5: Settings ──────────────────────────────────────────────
      GoRoute(
        path: '/settings',
        builder: (context, state) => const AccountSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/safety',
        builder: (context, state) => const SafetyScreen(),
      ),
      GoRoute(
        path: '/settings/safety/report/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId'];
          return SafetyScreen(prefilledUserId: userId);
        },
      ),
      GoRoute(
        path: '/settings/media-gallery/:matchId',
        builder: (context, state) {
          final matchId = state.pathParameters['matchId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return MediaGalleryScreen(
            matchId: matchId,
            otherUserName: extra?['otherUserName'] as String?,
          );
        },
      ),
    ],
  );
}

