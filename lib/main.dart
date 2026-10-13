import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'core/providers/app_providers.dart';
import 'core/providers/notification_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/widgets/app_branding.dart';
import 'data/services/preferences_service.dart';
import 'data/services/notification_service.dart';
import 'features/profile/presentation/viewmodels/preferences_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Khởi tạo Firebase (Hỗ trợ Web, Android, iOS)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp warning/error: $e');
  }

  // 2. Khởi tạo SharedPreferences Service
  final preferencesService = await PreferencesService.init();

  // 3. Khởi tạo Notification Service (FCM & Local Notifications)
  final notificationService = NotificationService(preferencesService);
  try {
    await notificationService.init();
  } catch (e) {
    debugPrint('NotificationService init warning: $e');
  }

  // 4. Chạy App với Riverpod ProviderScope
  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(preferencesService),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const DatingLyApp(),
    ),
  );
}

class DatingLyApp extends ConsumerWidget {
  const DatingLyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kích hoạt đồng bộ FCM token + thông báo match/tin nhắn mới
    ref.watch(notificationBootstrapProvider);

    // Lắng nghe trạng thái Dark Mode từ SharedPreferences thông qua Riverpod
    final isDarkMode = ref.watch(
      preferencesViewModelProvider.select((state) => state.isDarkMode),
    );

    return MaterialApp.router(
      title: AppBranding.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
    );
  }
}
