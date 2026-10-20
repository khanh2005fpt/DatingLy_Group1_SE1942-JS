import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/discovery/presentation/screens/discovery_screen.dart';
import '../../features/chat/presentation/screens/match_list_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/mini_game_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/activity/presentation/screens/notification_center_screen.dart';
import '../../features/activity/presentation/screens/who_liked_me_screen.dart';
import '../../features/activity/presentation/screens/history_rewind_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/login',
    // Đã đăng nhập Firebase thì bỏ qua màn login/register
    redirect: (context, state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final path = state.matchedLocation;
      final isAuthPage = path == '/login' || path == '/register';
      if (loggedIn && isAuthPage) return '/discovery';
      if (!loggedIn && !isAuthPage) return '/login';
      return null;
    },
    routes: [
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
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: '/who-liked-me',
        builder: (context, state) => const WhoLikedMeScreen(),
      ),
      GoRoute(
        path: '/history-rewind',
        builder: (context, state) => const HistoryRewindScreen(),
      ),
    ],
  );
}
