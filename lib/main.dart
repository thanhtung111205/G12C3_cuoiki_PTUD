import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/location_cleanup_service.dart';
import 'screens/auth/login_register_screen.dart';
import 'screens/home/home_dashboard_screen.dart';
import 'utils/app_colors.dart';
import 'firebase_options.dart';
import 'translation/translation_demo_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with a shorter timeout and better error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8)); // Reduced from 12s to 8s
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
    // We still continue to runApp, screens will handle missing Firebase state
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final ValueNotifier<ThemeMode> _themeModeNotifier = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  @override
  void initState() {
    super.initState();
    // Lắng nghe các thay đổi app lifecycle
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Xóa listener khi MyApp bị hủy
    WidgetsBinding.instance.removeObserver(this);
    _themeModeNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    debugPrint('[AppLifecycle] State changed: $state');

    switch (state) {
      case AppLifecycleState.detached:
        // App đã bị tắt hoàn toàn - xóa vị trí khỏi Firebase
        debugPrint('[AppLifecycle] DETACHED: App is being terminated');
        _clearUserLocation(currentUser.uid);
        break;
      case AppLifecycleState.paused:
        // App chuyển sang background - XÓA vị trí vì không biết khi nào sẽ mở lại
        // Cách này bảo đảm vị trí sẽ bị xóa ngay khi user tắt app
        debugPrint('[AppLifecycle] PAUSED: App entered background');
        _clearUserLocation(currentUser.uid);
        break;
      case AppLifecycleState.resumed:
        // App quay trở lại foreground - NearbyMapScreen sẽ tự cập nhật vị trí
        debugPrint('[AppLifecycle] RESUMED: App came to foreground');
        break;
      case AppLifecycleState.inactive:
        // App đang chuyển đổi trạng thái
        debugPrint('[AppLifecycle] INACTIVE: App transitioning');
        break;
      case AppLifecycleState.hidden:
        // App được ẩn nhưng không bị tắt (Android 12+)
        debugPrint('[AppLifecycle] HIDDEN: App is hidden');
        break;
    }
  }

  /// Xóa vị trí người dùng khỏi Firebase khi app tắt
  /// Gọi đồng bộ và không đợi kết quả để tránh delay
  Future<void> _clearUserLocation(String userId) async {
    try {
      debugPrint('[AppLifecycle] Attempting to clear location for user: $userId');

      // Dùng LocationCleanupService với async=true khi app đóng
      // (Fire and forget - không đợi kết quả)
      await LocationCleanupService().clearUserLocation(
        userId,
        async: true, // Fire and forget - không block app shutdown
      );

      debugPrint('[AppLifecycle] ✅ Location clear initiated');
    } catch (error) {
      debugPrint('[AppLifecycle] ❌ Lỗi xóa vị trí: $error');
      // Bỏ qua lỗi - không ảnh hưởng đến app shutdown
    }
  }

  void _toggleTheme() {
    _themeModeNotifier.value = _themeModeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
  }


  ThemeData _buildLightTheme() {
    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.deepPurple,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.deepPurple,
          secondary: AppColors.periwinkle,
          tertiary: AppColors.lavender,
          surface: Colors.white,
          onSurface: const Color(0xFF231A3D),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(elevation: 0),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: Colors.white,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.deepPurple,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.periwinkle,
          secondary: AppColors.deepPurple,
          tertiary: const Color(0xFF2A223D),
          surface: const Color(0xFF121212),
          onSurface: const Color(0xFFEDE7FF),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF101014),
      appBarTheme: const AppBarTheme(elevation: 0),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF2A223D),
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: Colors.white,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Smart Document & Vocab',
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: themeMode,
          // App home — use auth state to pick Home or Auth screen.
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                return HomeScreen(
                  isDarkMode: themeMode == ThemeMode.dark,
                  onToggleTheme: _toggleTheme,
                );
              }
              return const AuthScreen();
            },
          ),
          routes: {'/translate_demo': (_) => const TranslationDemoScreen()},
        );
      },
    );
  }
}
