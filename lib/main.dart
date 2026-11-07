import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'data/repositories/app_providers.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/setting_repository.dart';
import 'UI/ViewModels/notification_bootstrap.dart';
import 'UI/ViewModels/preferences_view_model.dart';
import 'UI/app_theme.dart';
import 'UI/app_router.dart';
import 'UI/Views/Widget/app_branding_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Khởi tạo Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp warning/error: $e');
  }

  // 2. Khởi tạo SettingRepository (SharedPreferences)
  final settingRepository = await SettingRepository.init();

  // 3. Khởi tạo Notification Repository (FCM & Local Notifications)
  final notificationRepository = NotificationRepository(settingRepository);
  // Bấm vào thông báo (local hoặc FCM) -> mở đúng màn hình như /chat/{id}, /likes
  notificationRepository.onRoute = (route) => AppRouter.router.push(route);
  try {
    await notificationRepository.init();
  } catch (e) {
    debugPrint('NotificationRepository init warning: $e');
  }

  // 4. Chạy App với Riverpod ProviderScope
  runApp(
    ProviderScope(
      overrides: [
        settingRepositoryProvider.overrideWithValue(settingRepository),
        notificationRepositoryProvider.overrideWithValue(notificationRepository),
      ],
      child: const DatingLyApp(),
    ),
  );

  // App được mở từ thông báo khi đã tắt hẳn: điều hướng sau khi UI đã dựng xong
  WidgetsBinding.instance.addPostFrameCallback((_) {
    notificationRepository.handleInitialMessage();
  });
}

class DatingLyApp extends ConsumerWidget {
  const DatingLyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationBootstrapProvider);

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
